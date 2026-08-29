# ============================================================
# Azure Task Manager - PostgreSQL Backup
#
# Read-only script for checking Azure PostgreSQL backups.
#
# The script reads the PostgreSQL server and Resource Group
# from config.json.
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
#       .\scripts\Get-AzurePostgreSQLBackup.ps1 -Config .\config.json
#
# ============================================================

param(
    [string]$Config = ".\config.json"
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host ""
}

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

function Test-CommandExists {
    param([string]$Command)

    return $null -ne (
        Get-Command $Command -ErrorAction SilentlyContinue
    )
}

# ============================================================
# Header
# ============================================================

Write-Section "Azure Task Manager - PostgreSQL Backup"

Write-Host "Configuration:"
Write-Host "  $Config"

if (-not (Test-Path $Config)) {
    throw "Configuration file not found: $Config"
}

try {
    $configData = Get-Content -Path $Config -Raw |
        ConvertFrom-Json
}
catch {
    throw "Could not parse configuration file: $Config"
}

$RESOURCE_GROUP = $configData.resourceGroup
$POSTGRES_SERVER = $configData.postgresServer

if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) {
    throw "Missing configuration value: resourceGroup"
}

if ([string]::IsNullOrWhiteSpace($POSTGRES_SERVER)) {
    throw "Missing configuration value: postgresServer"
}

Write-OK "Configuration loaded"

# ============================================================
# Prerequisites
# ============================================================

Write-Section "Prerequisites"

if (-not (Test-CommandExists "az")) {
    Write-Failed "Azure CLI is not installed or not available in PATH"
    throw "Azure CLI is required."
}

Write-OK "Azure CLI available"

# ============================================================
# Azure login
# ============================================================

$account = $null

try {
    $account = az account show --output json 2>$null |
        ConvertFrom-Json
}
catch {
    $account = $null
}

if (-not $account) {
    Write-Failed "Azure CLI is not logged in."
    Write-Host ""
    Write-Host "Run:" -ForegroundColor Yellow
    Write-Host "  az login"
    exit 1
}

Write-OK "Azure login"
Write-Info "Subscription: $($account.name)"
Write-Info "ID:           $($account.id)"

# ============================================================
# PostgreSQL Server
# ============================================================

Write-Section "PostgreSQL Server"

$server = az postgres flexible-server show `
    --name $POSTGRES_SERVER `
    --resource-group $RESOURCE_GROUP `
    --output json |
    ConvertFrom-Json

if (-not $server) {
    Write-Failed "PostgreSQL server not found"
    exit 1
}

Write-OK "PostgreSQL server exists"
Write-Info "Server: $POSTGRES_SERVER"
Write-Info "State:  $($server.state)"

# ============================================================
# Backup Configuration
# ============================================================

Write-Section "Backup Configuration"

$backup = $server.backup

if ($backup) {

    $retention = $backup.backupRetentionDays

    if ($retention -and $retention -gt 0) {
        Write-OK "Automated backups enabled"
        Write-Info "Retention: $retention days"
    }
    else {
        Write-Failed "Automated backup retention is not configured"
    }

    if ($backup.geoRedundantBackup) {
        Write-Info "Geo-redundant backup: Enabled"
    }
    else {
        Write-Info "Geo-redundant backup: Disabled"
    }
}
else {
    Write-Failed "Backup configuration could not be read"
}

# ============================================================
# Restore Points
# ============================================================

Write-Section "Restore Points"

try {

    $restorePoints = az postgres flexible-server backup list `
        --resource-group $RESOURCE_GROUP `
        --server-name $POSTGRES_SERVER `
        --output json 2>$null |
        ConvertFrom-Json

    if ($restorePoints) {

        Write-OK "Backup restore points available"

        $restorePoints |
            Sort-Object -Property backupStartTime |
            Select-Object -First 1 |
            ForEach-Object {
                Write-Info "Earliest backup: $($_.backupStartTime)"
            }

        $restorePoints |
            Sort-Object -Property backupStartTime -Descending |
            Select-Object -First 1 |
            ForEach-Object {
                Write-Info "Latest backup:   $($_.backupStartTime)"
            }
    }
    else {
        Write-Info "No backup records returned."
    }
}
catch {
    Write-Info "Restore point information is not available through the current Azure CLI."
}

# ============================================================
# PITR
# ============================================================

Write-Section "Point-in-Time Restore"

if ($backup -and $backup.backupRetentionDays -gt 0) {
    Write-OK "Point-in-time restore is supported"
    Write-Info "Available within the configured backup retention period."
}
else {
    Write-Failed "Point-in-time restore is not available"
}

# ============================================================
# Completed
# ============================================================

Write-Section "Backup Check Completed"

Write-OK "PostgreSQL backup configuration check finished"

Write-Host ""