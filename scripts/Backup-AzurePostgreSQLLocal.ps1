# ============================================================
# Azure Task Manager - PostgreSQL Backup
#
# Creates a local backup of the Azure PostgreSQL database.
#
# The script automatically:
#
#   - Finds pg_dump
#   - Gets the current public IP
#   - Temporarily allows this IP in PostgreSQL Firewall
#   - Tests PostgreSQL connectivity
#   - Creates the database backup
#   - Removes the temporary Firewall rule
#
# The Firewall rule is removed automatically even if the backup
# fails or the script encounters an error.
#
# Configuration is loaded from config.json.
# PostgreSQL password is requested securely and is NOT stored
# in the configuration file.
#
# PARAMETERS
#
# -Config
#   Path to the Azure Task Manager configuration file.
#
#   Default:
#
#       .\config.json
#
#   Example:
#
#       .\scripts\Backup-AzurePostgreSQLLocal.ps1 -Config .\config.json
#
#
# -OutputPath
#   Directory where the backup file will be saved.
#
#   Default:
#
#       .\backups
#
#   Example:
#
#       .\scripts\Backup-AzurePostgreSQLLocal.ps1 -OutputPath .\backups
#
#
# REQUIREMENTS
#
#   - Azure CLI
#   - PostgreSQL client tools (pg_dump)
#   - Internet access
#   - Azure CLI login
#
# This script does NOT permanently modify Azure resources.
# ============================================================

param(
    [string]$Config = ".\config.json",
    [string]$OutputPath = ".\backups"
)

$ErrorActionPreference = "Stop"

$FIREWALL_RULE = "Allow-Backup-PC"
$FIREWALL_CREATED = $false
$backupFile = $null

# ============================================================
# Output helpers
# ============================================================

function Write-OK {
    param([string]$Message)
    Write-Host "  [PASS]    $Message" -ForegroundColor Green
}

function Write-Failed {
    param([string]$Message)
    Write-Host "  [FAILED]  $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [INFO]    $Message" -ForegroundColor DarkGray
}

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor DarkGray
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" `
        -ForegroundColor DarkGray
    Write-Host ""
}

function Test-CommandExists {
    param([string]$Command)

    return $null -ne (
        Get-Command $Command -ErrorAction SilentlyContinue
    )
}

# ============================================================
# Find pg_dump
# ============================================================

function Find-PgDump {

    $command = Get-Command pg_dump `
        -ErrorAction SilentlyContinue

    if ($command) {
        return $command.Source
    }

    $roots = @(
        "C:\Program Files\PostgreSQL",
        "C:\Program Files (x86)\PostgreSQL"
    )

    foreach ($root in $roots) {

        if (-not (Test-Path $root)) {
            continue
        }

        $versions = Get-ChildItem `
            -Path $root `
            -Directory `
            -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending

        foreach ($version in $versions) {

            $candidate = Join-Path `
                $version.FullName `
                "bin\pg_dump.exe"

            if (Test-Path $candidate) {
                return $candidate
            }
        }
    }

    return $null
}

# ============================================================
# Get public IP
# ============================================================

function Get-PublicIP {

    $ip = (
        Invoke-RestMethod `
            -Uri "https://api.ipify.org" `
            -TimeoutSec 10
    ).Trim()

    if ($ip -notmatch `
        "^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$") {

        throw "Invalid public IP address returned."
    }

    return $ip
}

# ============================================================
# Start
# ============================================================

Write-Section "Azure Task Manager - PostgreSQL Backup"

Write-Info "Configuration: $Config"
Write-Info "Output path:   $OutputPath"

# ============================================================
# Configuration
# ============================================================

if (-not (Test-Path $Config)) {
    throw "Configuration file not found: $Config"
}

try {

    $configData = Get-Content `
        -Path $Config `
        -Raw |
        ConvertFrom-Json
}
catch {

    throw "Could not parse configuration file: $Config"
}

$RESOURCE_GROUP = $configData.resourceGroup
$POSTGRES_SERVER = $configData.postgresServer
$POSTGRES_DATABASE = $configData.postgresDatabase
$POSTGRES_ADMIN = $configData.postgresAdmin

$required = @{
    resourceGroup    = $RESOURCE_GROUP
    postgresServer   = $POSTGRES_SERVER
    postgresDatabase = $POSTGRES_DATABASE
    postgresAdmin    = $POSTGRES_ADMIN
}

foreach ($item in $required.GetEnumerator()) {

    if ([string]::IsNullOrWhiteSpace($item.Value)) {

        throw "Missing required configuration value: $($item.Key)"
    }
}

Write-OK "Configuration loaded"

Write-Info "Resource Group: $RESOURCE_GROUP"
Write-Info "Server:         $POSTGRES_SERVER"
Write-Info "Database:       $POSTGRES_DATABASE"
Write-Info "Admin:          $POSTGRES_ADMIN"

# ============================================================
# Prerequisites
# ============================================================

Write-Section "Prerequisites"

if (-not (Test-CommandExists "az")) {

    Write-Failed "Azure CLI is not available"
    throw "Azure CLI is required."
}

Write-OK "Azure CLI available"

$pgDumpPath = Find-PgDump

if (-not $pgDumpPath) {

    Write-Failed "pg_dump was not found"
    throw "PostgreSQL client tools with pg_dump are required."
}

Write-OK "pg_dump available"
Write-Info "Path: $pgDumpPath"

# ============================================================
# Azure login
# ============================================================

Write-Section "Azure Account"

try {

    $account = az account show `
        --output json `
        2>$null |
        ConvertFrom-Json
}
catch {

    $account = $null
}

if (-not $account) {

    Write-Failed "Azure CLI is not logged in"

    Write-Host ""
    Write-Host "Run: az login" -ForegroundColor Yellow
    exit 1
}

Write-OK "Azure login"

Write-Info "Subscription: $($account.name)"
Write-Info "ID:           $($account.id)"

# ============================================================
# PostgreSQL server
# ============================================================

Write-Section "PostgreSQL Server"

try {

    $server = az postgres flexible-server show `
        --name $POSTGRES_SERVER `
        --resource-group $RESOURCE_GROUP `
        --output json `
        2>$null |
        ConvertFrom-Json
}
catch {

    $server = $null
}

if (-not $server) {

    Write-Failed "PostgreSQL server not found"
    exit 1
}

Write-OK "PostgreSQL server exists"

if ($server.state -ne "Ready") {

    Write-Failed "PostgreSQL server state: $($server.state)"
    exit 1
}

Write-OK "PostgreSQL server is Ready"

$POSTGRES_FQDN = $server.fullyQualifiedDomainName

Write-Info "FQDN: $POSTGRES_FQDN"

# ============================================================
# Main operation
# ============================================================

try {

    # --------------------------------------------------------
    # Get public IP
    # --------------------------------------------------------

    Write-Section "Firewall"

    $PUBLIC_IP = Get-PublicIP

    Write-OK "Public IP detected"
    Write-Info "IP: $PUBLIC_IP"

    # --------------------------------------------------------
    # Create temporary firewall rule
    # --------------------------------------------------------

    Write-Info "Creating temporary Firewall rule..."

    az postgres flexible-server firewall-rule create `
        --resource-group $RESOURCE_GROUP `
        --server-name $POSTGRES_SERVER `
        --name $FIREWALL_RULE `
        --start-ip-address $PUBLIC_IP `
        --end-ip-address $PUBLIC_IP `
        --output none

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed to create Firewall rule."
    }

    $FIREWALL_CREATED = $true

    Write-OK "Temporary Firewall rule created"
    Write-Info "Rule: $FIREWALL_RULE"

    # --------------------------------------------------------
    # Test connectivity
    # --------------------------------------------------------

    Write-Section "Connectivity"

    Write-Info "Testing TCP connection to PostgreSQL..."

    $connection = Test-NetConnection `
        -ComputerName $POSTGRES_FQDN `
        -Port 5432 `
        -WarningAction SilentlyContinue

    if (-not $connection.TcpTestSucceeded) {

        throw "TCP connection to PostgreSQL port 5432 failed."
    }

    Write-OK "PostgreSQL port 5432 is reachable"

    # --------------------------------------------------------
    # Backup directory
    # --------------------------------------------------------

    Write-Section "Backup"

    if (-not (Test-Path $OutputPath)) {

        New-Item `
            -ItemType Directory `
            -Path $OutputPath `
            -Force |
            Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"

    $backupFile = Join-Path `
        $OutputPath `
        "${POSTGRES_DATABASE}_${timestamp}.dump"

    Write-Info "Database: $POSTGRES_DATABASE"
    Write-Info "Backup:   $backupFile"

    # --------------------------------------------------------
    # PostgreSQL password
    # --------------------------------------------------------

    $credential = Get-Credential `
        -UserName $POSTGRES_ADMIN `
        -Message "Enter PostgreSQL password"

    if (-not $credential) {
        throw "Password was not provided."
    }

    $password = $credential.GetNetworkCredential().Password

    if ([string]::IsNullOrWhiteSpace($password)) {
        throw "Password cannot be empty."
    }

    # --------------------------------------------------------
    # Create backup
    # --------------------------------------------------------

    Write-Info "Creating PostgreSQL backup..."

    $env:PGPASSWORD = $password

    try {

        & $pgDumpPath `
            --host="$POSTGRES_FQDN" `
            --port=5432 `
            --username="$POSTGRES_ADMIN" `
            --dbname="$POSTGRES_DATABASE" `
            --format=custom `
            --file="$backupFile" `
            --no-owner `
            --no-privileges

        if ($LASTEXITCODE -ne 0) {

            throw "pg_dump returned exit code $LASTEXITCODE"
        }

        if (-not (Test-Path $backupFile)) {

            throw "Backup file was not created."
        }

        $file = Get-Item $backupFile

        if ($file.Length -eq 0) {

            throw "Backup file is empty."
        }

        $sizeKB = [math]::Round(
            $file.Length / 1KB,
            2
        )

        Write-OK "Backup completed"

        Write-Info "File: $($file.FullName)"
        Write-Info "Size: $sizeKB KB"
    }
    finally {

        Remove-Item Env:PGPASSWORD `
            -ErrorAction SilentlyContinue
    }
}
finally {

    # ========================================================
    # Firewall cleanup
    # ========================================================

    if ($FIREWALL_CREATED) {

        Write-Section "Firewall Cleanup"

        Write-Info "Removing temporary Firewall rule..."

        try {

            az postgres flexible-server firewall-rule delete `
                --resource-group $RESOURCE_GROUP `
                --server-name $POSTGRES_SERVER `
                --name $FIREWALL_RULE `
                --yes `
                --output none

            if ($LASTEXITCODE -eq 0) {

                Write-OK "Temporary Firewall rule removed"
            }
            else {

                Write-Failed `
                    "Could not remove temporary Firewall rule"

                Write-Info `
                    "Remove it manually: $FIREWALL_RULE"
            }
        }
        catch {

            Write-Failed "Firewall cleanup failed"

            Write-Info $_.Exception.Message

            Write-Info `
                "Remove the rule manually: $FIREWALL_RULE"
        }
    }
}

# ============================================================
# Completed
# ============================================================

Write-Host ""

Write-Host "============================================================" `
    -ForegroundColor DarkGray

Write-Host " PostgreSQL backup completed successfully " `
    -ForegroundColor Green

Write-Host "============================================================" `
    -ForegroundColor DarkGray

Write-Host ""

Write-Host "Backup:"
Write-Host "  $backupFile" -ForegroundColor White

Write-Host ""