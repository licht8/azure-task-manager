# ============================================================
# Azure Task Manager - PostgreSQL On-Demand Backup
#
# Creates an on-demand Azure Managed Backup for PostgreSQL
# Flexible Server when supported.
#
# The script reads the PostgreSQL server and Resource Group
# from config.json.
#
# On-demand backups are not supported for:
#
#   - Burstable compute tier
#   - SSDv2 storage tier
#
# Azure allows up to 7 on-demand backups per server.
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
#       .\scripts\Backup-AzurePostgreSQL.ps1 -Config .\config.json
#
# ============================================================

param(
    [string]$Config = ".\config.json"
)

$ErrorActionPreference = "Stop"

function Section($title) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host " $title" -ForegroundColor Cyan
    Write-Host "============================================================"
}

function Pass($msg) {
    Write-Host "[PASS]    $msg" -ForegroundColor Green
}

function Fail($msg) {
    Write-Host "[FAILED]  $msg" -ForegroundColor Red
}

function Info($msg) {
    Write-Host "[INFO]    $msg" -ForegroundColor DarkGray
}

# ============================================================
# Configuration
# ============================================================

Section "Azure Task Manager - PostgreSQL Backup"

if (-not (Test-Path $Config)) {
    throw "Configuration file not found: $Config"
}

$configData = Get-Content $Config -Raw | ConvertFrom-Json

$ResourceGroup = $configData.resourceGroup
$ServerName    = $configData.postgresServer

if ([string]::IsNullOrWhiteSpace($ResourceGroup) -or
    [string]::IsNullOrWhiteSpace($ServerName)) {
    throw "resourceGroup or postgresServer is missing in config.json"
}

Info "Resource Group: $ResourceGroup"
Info "Server:         $ServerName"

# ============================================================
# Prerequisites
# ============================================================

Section "Prerequisites"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Fail "Azure CLI is not available"
    throw "Azure CLI is required."
}

Pass "Azure CLI available"

$account = az account show --output json 2>$null | ConvertFrom-Json

if (-not $account) {
    Fail "Azure login required"
    throw "Run 'az login' first."
}

Pass "Azure login"
Info "Subscription: $($account.name)"

# ============================================================
# PostgreSQL Server
# ============================================================

Section "PostgreSQL Server"

$server = az postgres flexible-server show `
    --name $ServerName `
    --resource-group $ResourceGroup `
    --output json |
    ConvertFrom-Json

if (-not $server) {
    Fail "PostgreSQL server not found"
    throw "Server '$ServerName' was not found."
}

Pass "PostgreSQL server exists"
Info "State:         $($server.state)"
Info "Compute tier:  $($server.sku.tier)"
Info "Storage tier:  $($server.storage.storageType)"

if ($server.state -ne "Ready") {
    Fail "PostgreSQL server is not Ready"
    throw "Server state is '$($server.state)'."
}

Pass "PostgreSQL server is Ready"

# ============================================================
# Backup Support
# ============================================================

Section "Backup Support"

if ($server.sku.tier -eq "Burstable") {
    Fail "On-demand backup is not supported on Burstable servers"
    Info "Automated Azure backups remain available."
    exit 1
}

Pass "Compute tier supports on-demand backup"

$storageType = $server.storage.storageType

if ($storageType -match "SSDv2") {
    Fail "On-demand backup is not supported on SSDv2 storage"
    Info "Use Premium SSD storage for on-demand backups."
    exit 1
}

Pass "Storage tier supports on-demand backup"

# ============================================================
# Existing On-Demand Backups
# ============================================================

Section "Existing Backups"

$backups = az postgres flexible-server backup list `
    --resource-group $ResourceGroup `
    --name $ServerName `
    --query "[?backupType=='Customer On-Demand']" `
    --output json |
    ConvertFrom-Json

$backupCount = @($backups).Count

Info "Existing on-demand backups: $backupCount"

if ($backupCount -ge 7) {
    Fail "Maximum of 7 on-demand backups already exists"
    Info "Delete an old on-demand backup before creating another."
    exit 1
}

Pass "On-demand backup limit available"

# ============================================================
# Create Backup
# ============================================================

Section "Backup"

$BackupName = "taskmanager-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Info "Backup name: $BackupName"
Info "Starting Azure Managed Backup..."

try {
    $result = az postgres flexible-server backup create `
        --resource-group $ResourceGroup `
        --name $ServerName `
        --backup-name $BackupName `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Fail "Azure backup creation failed"
        Write-Host ($result -join "`n")
        exit 1
    }

    $backup = $result | ConvertFrom-Json
}
catch {
    Fail "Azure backup creation failed"
    throw
}

if (-not $backup) {
    Fail "Azure did not return backup information"
    exit 1
}

Pass "Backup created"

if ($backup.name) {
    Info "Name: $($backup.name)"
}

if ($backup.id) {
    Info "ID:   $($backup.id)"
}

if ($backup.createdTime) {
    Info "Created: $($backup.createdTime)"
}

# ============================================================
# Completed
# ============================================================

Section "Backup Completed"

Pass "PostgreSQL backup is stored in Azure Managed Backup"