# ============================================================
# Azure Task Manager - Resource Cleanup
#
# Removes the entire Resource Group defined in config.json.
# 
# It will show you exactly what is inside the Resource Group and will require: Confirmation: DELETE
# Only after that will the deletion begin.
#
# After deletion, you can verify: 
# az group exists --name $RESOURCE_GROUP
#
# Usage:
#
#   .\scripts\Remove-AzureTaskManager.ps1
#
#   .\scripts\Remove-AzureTaskManager.ps1 -Config .\config.json
#
# Force mode:
#
#   .\scripts\Remove-AzureTaskManager.ps1 -Force
#
# IMPORTANT:
#
# This permanently deletes the Resource Group and ALL resources inside it including the PostgreSQL Flexible Server defined in config.json.
# The database is NOT backed up before deletion!
# If there's data in PostgreSQL that you need, make a backup.
# 
#
# ============================================================

param(
    [string]$Config = ".\config.json",

    [switch]$Force
)

$ErrorActionPreference = "Stop"

# ============================================================
# Helpers
# ============================================================

function Write-Section {
    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor DarkGray

    Write-Host " $Title" `
        -ForegroundColor Cyan

    Write-Host "============================================================" `
        -ForegroundColor DarkGray

    Write-Host ""
}

function Write-OK {
    param(
        [string]$Message
    )

    Write-Host "  [OK]      $Message" `
        -ForegroundColor Green
}

function Write-WarningStatus {
    param(
        [string]$Message
    )

    Write-Host "  [WARNING] $Message" `
        -ForegroundColor Yellow
}

function Write-Failed {
    param(
        [string]$Message
    )

    Write-Host "  [FAILED]  $Message" `
        -ForegroundColor Red
}

function Test-CommandExists {
    param(
        [string]$Command
    )

    return $null -ne (
        Get-Command $Command `
            -ErrorAction SilentlyContinue
    )
}

function Invoke-AzQuery {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $oldErrorActionPreference = $ErrorActionPreference

    $ErrorActionPreference = "SilentlyContinue"

    try {

        $result = & az @Arguments 2>$null

        if ($LASTEXITCODE -ne 0) {
            return $null
        }

        return $result
    }
    finally {

        $ErrorActionPreference = $oldErrorActionPreference
    }
}

# ============================================================
# Header
# ============================================================

Write-Section "Azure Task Manager - Resource Cleanup"

Write-Host "Configuration:"
Write-Host "  $Config"

# ============================================================
# Azure CLI
# ============================================================

if (-not (Test-CommandExists "az")) {

    Write-Failed `
        "Azure CLI is not installed or not available in PATH"

    throw "Azure CLI is required."
}

Write-OK "Azure CLI available"

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
$LOCATION = $configData.location
$ACR_NAME = $configData.acrName
$ENVIRONMENT_NAME = $configData.environmentName
$BACKEND_APP = $configData.backendApp
$FRONTEND_APP = $configData.frontendApp
$POSTGRES_SERVER = $configData.postgresServer
$POSTGRES_DATABASE = $configData.postgresDatabase

if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) {

    throw "Missing required configuration value: resourceGroup"
}

Write-OK "Configuration loaded"

# ============================================================
# Azure login
# ============================================================

Write-Section "Azure Account"

$accountJson = Invoke-AzQuery @(
    "account",
    "show",
    "--output",
    "json"
)

if (-not $accountJson) {

    Write-Failed "Azure login"

    throw "Azure CLI is not logged in. Run 'az login' first."
}

try {

    $account = $accountJson | ConvertFrom-Json
}
catch {

    throw "Could not parse Azure account information."
}

Write-OK "Azure login"

Write-Host ""
Write-Host "  User:" -ForegroundColor Cyan
Write-Host "    $($account.user.name)"

Write-Host ""
Write-Host "  Subscription:" -ForegroundColor Cyan
Write-Host "    $($account.name)"

Write-Host ""
Write-Host "  Subscription ID:" -ForegroundColor Cyan
Write-Host "    $($account.id)"

# ============================================================
# Resource Group
# ============================================================

Write-Section "Resource Group"

$rgJson = Invoke-AzQuery @(
    "group",
    "show",
    "--name",
    $RESOURCE_GROUP,
    "--output",
    "json"
)

if (-not $rgJson) {

    Write-WarningStatus `
        "Resource Group '$RESOURCE_GROUP' does not exist."

    Write-Host ""
    Write-OK "Nothing to clean up."

    exit 0
}

try {

    $resourceGroup = $rgJson | ConvertFrom-Json
}
catch {

    throw "Could not parse Resource Group information."
}

Write-OK "Resource Group found"

Write-Host ""
Write-Host "  Name:" -ForegroundColor Cyan
Write-Host "    $RESOURCE_GROUP"

Write-Host ""
Write-Host "  Location:" -ForegroundColor Cyan
Write-Host "    $($resourceGroup.location)"

# ============================================================
# Configured resources
# ============================================================

Write-Section "Configured Resources"

Write-Host "  Resource Group:"
Write-Host "    $RESOURCE_GROUP"

Write-Host ""
Write-Host "  Azure Container Registry:"
Write-Host "    $ACR_NAME"

Write-Host ""
Write-Host "  Container Apps Environment:"
Write-Host "    $ENVIRONMENT_NAME"

Write-Host ""
Write-Host "  Backend Container App:"
Write-Host "    $BACKEND_APP"

Write-Host ""
Write-Host "  Frontend Container App:"
Write-Host "    $FRONTEND_APP"

Write-Host ""
Write-Host "  PostgreSQL Server:"
Write-Host "    $POSTGRES_SERVER"

Write-Host ""
Write-Host "  PostgreSQL Database:"
Write-Host "    $POSTGRES_DATABASE"

# ============================================================
# Actual resources
# ============================================================

Write-Section "Resources Inside Resource Group"

$resourcesJson = Invoke-AzQuery @(
    "resource",
    "list",
    "--resource-group",
    $RESOURCE_GROUP,
    "--output",
    "json"
)

if ($resourcesJson) {

    try {

        $resources = @(
            $resourcesJson | ConvertFrom-Json
        )

        if ($resources.Count -eq 0) {

            Write-WarningStatus `
                "Resource Group contains no resources."
        }
        else {

            foreach ($resource in $resources) {

                Write-Host "  $($resource.name)" `
                    -ForegroundColor White

                Write-Host "    Type: $($resource.type)" `
                    -ForegroundColor DarkGray
            }
        }
    }
    catch {

        Write-WarningStatus `
            "Could not parse resource list."
    }
}
else {

    Write-WarningStatus `
        "Could not retrieve resources from Resource Group."
}

# ============================================================
# Destructive operation warning
# ============================================================

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Red

Write-Host "                     WARNING" `
    -ForegroundColor Red

Write-Host "============================================================" `
    -ForegroundColor Red

Write-Host ""

Write-Host "You are about to permanently delete:" `
    -ForegroundColor Yellow

Write-Host ""
Write-Host "  RESOURCE GROUP: $RESOURCE_GROUP" `
    -ForegroundColor Red

Write-Host ""

Write-Host "This will delete ALL resources inside the Resource Group." `
    -ForegroundColor Yellow

Write-Host ""
Write-Host "This operation CANNOT be undone." `
    -ForegroundColor Red

Write-Host ""

# ============================================================
# Confirmation
# ============================================================

if (-not $Force) {

    Write-Host "To continue, type exactly:" `
        -ForegroundColor Yellow

    Write-Host ""
    Write-Host "  DELETE" `
        -ForegroundColor Red

    Write-Host ""

    $confirmation = Read-Host "Confirmation"

    if ($confirmation -cne "DELETE") {

        Write-Host ""
        Write-WarningStatus "Cleanup cancelled."

        exit 0
    }
}
else {

    Write-Host ""
    Write-WarningStatus `
        "Force mode enabled. Confirmation skipped."
}

# ============================================================
# Delete Resource Group
# ============================================================

Write-Section "Deleting Resource Group"

Write-Host "Submitting deletion request..." `
    -ForegroundColor Yellow

& az group delete `
    --name $RESOURCE_GROUP `
    --yes `
    --no-wait

if ($LASTEXITCODE -ne 0) {

    throw "Failed to submit Resource Group deletion request."
}

Write-OK "Deletion request submitted"

Write-Host ""
Write-Host "Azure is deleting the Resource Group in the background." `
    -ForegroundColor DarkGray

# ============================================================
# Wait for deletion
# ============================================================

Write-Section "Waiting for Deletion"

$deleted = $false

for ($i = 1; $i -le 60; $i++) {

    $exists = az group exists `
        --name $RESOURCE_GROUP `
        2>$null

    if ($exists -eq "false") {

        $deleted = $true
        break
    }

    Write-Host "  Attempt $i/60 - Resource Group still exists..." `
        -ForegroundColor DarkGray

    Start-Sleep -Seconds 10
}

# ============================================================
# Final result
# ============================================================

Write-Host ""
Write-Host "============================================================"

if ($deleted) {

    Write-Host " Cleanup completed successfully " `
        -ForegroundColor Green

    Write-Host "============================================================"

    Write-Host ""

    Write-OK `
        "Resource Group '$RESOURCE_GROUP' has been deleted."

    Write-Host ""
    Write-OK "Azure Task Manager infrastructure removed."

}
else {

    Write-Host " Cleanup still in progress " `
        -ForegroundColor Yellow

    Write-Host "============================================================"

    Write-Host ""

    Write-WarningStatus `
        "Resource Group deletion has not completed yet."

    Write-Host ""
    Write-Host "Check the status with:" `
        -ForegroundColor Cyan

    Write-Host ""
    Write-Host "  az group exists --name $RESOURCE_GROUP" `
        -ForegroundColor White

    Write-Host ""

    Write-Host "Azure may still be deleting resources in the background." `
        -ForegroundColor DarkGray

    exit 1
}

Write-Host ""