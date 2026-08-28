# ============================================================
# Azure Task Manager - Container App Restart
#
# Script for restarting Azure Container Apps.
#
# The script reads application names and the Resource Group
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
#       .\scripts\Restart-AzureTaskManager.ps1 -Config .\config.json
#
#
# -App
#   Specifies which Container App should be restarted.
#
#   Available values:
#
#       backend   - restart Backend Container App
#       frontend  - restart Frontend Container App
#       all       - restart both applications
#
#   Default:
#
#       all
#
#   Examples:
#
#       .\scripts\Restart-AzureTaskManager.ps1 -App backend
#       .\scripts\Restart-AzureTaskManager.ps1 -App frontend
#       .\scripts\Restart-AzureTaskManager.ps1 -App all
#
# ============================================================

param(
    [string]$Config = ".\config.json",

    [ValidateSet("backend", "frontend", "all")]
    [string]$App = "all"
)

$ErrorActionPreference = "Stop"

# ============================================================
# Output helpers
# ============================================================

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

function Write-Pass {
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

# ============================================================
# Load configuration
# ============================================================

Write-Section "Azure Task Manager - Container App Restart"

Write-Host "Configuration:"
Write-Host "  $Config"

if (-not (Test-Path $Config)) {
    throw "Configuration file not found: $Config"
}

try {
    $configData = Get-Content -Path $Config -Raw | ConvertFrom-Json
}
catch {
    throw "Could not parse configuration file: $Config"
}

$RESOURCE_GROUP = $configData.resourceGroup
$BACKEND_APP = $configData.backendApp
$FRONTEND_APP = $configData.frontendApp

foreach ($item in @{
    "resourceGroup" = $RESOURCE_GROUP
    "backendApp"    = $BACKEND_APP
    "frontendApp"   = $FRONTEND_APP
}.GetEnumerator()) {

    if ([string]::IsNullOrWhiteSpace($item.Value)) {
        throw "Missing required configuration value: $($item.Key)"
    }
}

Write-Pass "Configuration loaded"

Write-Info "Resource Group: $RESOURCE_GROUP"
Write-Info "Backend App:    $BACKEND_APP"
Write-Info "Frontend App:   $FRONTEND_APP"
Write-Info "Application:    $App"

# ============================================================
# Prerequisites
# ============================================================

Write-Section "Prerequisites"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {

    Write-Failed "Azure CLI is not available in PATH"
    throw "Azure CLI is required."
}

Write-Pass "Azure CLI available"

# ============================================================
# Azure login
# ============================================================

Write-Section "Azure Account"

try {
    $account = az account show --output json 2>$null | ConvertFrom-Json
}
catch {
    $account = $null
}

if (-not $account) {

    Write-Failed "Azure CLI is not logged in"

    Write-Host ""
    Write-Host "Run:" -ForegroundColor Yellow
    Write-Host "  az login" -ForegroundColor White
    Write-Host ""

    exit 1
}

Write-Pass "Azure login"

Write-Info "Subscription: $($account.name)"
Write-Info "ID:           $($account.id)"

# ============================================================
# Restart function
# ============================================================

function Restart-ContainerApp {

    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    Write-Section "$DisplayName Container App"

    Write-Info "Application:    $AppName"
    Write-Info "Resource Group: $RESOURCE_GROUP"

    # --------------------------------------------------------
    # Check Container App
    # --------------------------------------------------------

    az containerapp show `
        --name $AppName `
        --resource-group $RESOURCE_GROUP `
        --output none 2>$null

    if ($LASTEXITCODE -ne 0) {

        Write-Failed "Container App '$AppName' was not found"

        return $false
    }

    Write-Pass "Container App exists"

    # --------------------------------------------------------
    # Get active revision
    # --------------------------------------------------------

    try {

        $revisionData = az containerapp revision list `
            --name $AppName `
            --resource-group $RESOURCE_GROUP `
            --output json 2>$null |
            ConvertFrom-Json
    }
    catch {

        Write-Failed "Could not retrieve Container App revisions"

        return $false
    }

    $revision = $revisionData |
        Where-Object {
            $_.properties.active -eq $true
        } |
        Select-Object -First 1

    if (-not $revision) {

        Write-Failed "Could not determine active revision"

        return $false
    }

    $revisionName = $revision.name

    Write-Info "Active revision: $revisionName"

    # --------------------------------------------------------
    # Restart revision
    # --------------------------------------------------------

    Write-Host ""
    Write-Info "Restarting Container App..."

    az containerapp revision restart `
        --name $AppName `
        --resource-group $RESOURCE_GROUP `
        --revision $revisionName `
        --output none

    if ($LASTEXITCODE -ne 0) {

        Write-Failed "Restart failed"

        return $false
    }

    Write-Pass "Restart command completed"

    return $true
}

# ============================================================
# Execute
# ============================================================

$success = $true

switch ($App) {

    "backend" {

        if (-not (Restart-ContainerApp `
            -AppName $BACKEND_APP `
            -DisplayName "Backend")) {

            $success = $false
        }
    }

    "frontend" {

        if (-not (Restart-ContainerApp `
            -AppName $FRONTEND_APP `
            -DisplayName "Frontend")) {

            $success = $false
        }
    }

    "all" {

        if (-not (Restart-ContainerApp `
            -AppName $BACKEND_APP `
            -DisplayName "Backend")) {

            $success = $false
        }

        if (-not (Restart-ContainerApp `
            -AppName $FRONTEND_APP `
            -DisplayName "Frontend")) {

            $success = $false
        }
    }
}

# ============================================================
# Result
# ============================================================

Write-Section "Restart Result"

if ($success) {

    Write-Pass "Azure Task Manager restart completed successfully"

    Write-Info "Application: $App"
}
else {

    Write-Failed "One or more applications could not be restarted"

    exit 1
}

Write-Host ""