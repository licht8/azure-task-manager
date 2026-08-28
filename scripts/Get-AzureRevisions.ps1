# ============================================================
# Azure Task Manager - Container App Revisions
#
# Read-only script for viewing Azure Container App revisions.
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
#       .\scripts\Get-AzureRevisions.ps1 -Config .\config.json
#
#
# -App
#   Specifies which Container App revisions should be displayed.
#
#   Available values:
#
#       backend   - show Backend revisions
#       frontend  - show Frontend revisions
#       all       - show revisions from both applications
#
#   Default:
#
#       all
#
#   Examples:
#
#       .\scripts\Get-AzureRevisions.ps1 -App backend
#       .\scripts\Get-AzureRevisions.ps1 -App frontend
#       .\scripts\Get-AzureRevisions.ps1 -App all
#
#
# -All
#   Shows all available revisions.
#
#   Without -All, only the latest 10 revisions are displayed.
#
#   Example:
#
#       .\scripts\Get-AzureRevisions.ps1 -App backend -All
#
# ============================================================


param(
    [string]$Config = ".\config.json",

    [ValidateSet("backend", "frontend", "all")]
    [string]$App = "backend",

    [ValidateRange(1, 100)]
    [int]$Count = 5
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

function Show-Revisions {
    param(
        [string]$AppName,
        [string]$DisplayName
    )

    Write-Section "$DisplayName Revisions"

    Write-Host "  Application:    $AppName"
    Write-Host "  Resource Group: $RESOURCE_GROUP"
    Write-Host "  Showing:        $Count latest revisions"
    Write-Host ""

    try {
        $revisions = az containerapp revision list `
            --name $AppName `
            --resource-group $RESOURCE_GROUP `
            --output json 2>$null | ConvertFrom-Json
    }
    catch {
        Write-Host "  [FAILED] Could not retrieve revisions." -ForegroundColor Red
        return
    }

    if (-not $revisions) {
        Write-Host "  [FAILED] Container App or revisions not found." -ForegroundColor Red
        return
    }

    $revisions = $revisions |
        Sort-Object {
            [datetime]$_.properties.createdTime
        } -Descending |
        Select-Object -First $Count

    foreach ($revision in $revisions) {

        $name     = $revision.name
        $state    = $revision.properties.runningState
        $active   = $revision.properties.active
        $replicas = $revision.properties.replicas
        $created  = $revision.properties.createdTime
        $traffic  = $revision.properties.trafficWeight

        if ($state -eq "Running") {
            $stateColor = "Green"
        }
        elseif ($state -match "Failed|Degraded|Unhealthy") {
            $stateColor = "Red"
        }
        else {
            $stateColor = "Yellow"
        }

        Write-Host "  --------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  Revision:  $name" -ForegroundColor Cyan
        Write-Host "  State:     $state" -ForegroundColor $stateColor
        Write-Host "  Active:    $active"
        Write-Host "  Replicas:  $replicas"
        Write-Host "  Traffic:   $traffic%"
        Write-Host "  Created:   $created"
    }

    Write-Host ""
}

# ============================================================
# Load configuration
# ============================================================

Write-Section "Azure Task Manager - Container App Revisions"

if (-not (Test-Path $Config)) {
    throw "Configuration file not found: $Config"
}

try {
    $configData = Get-Content $Config -Raw | ConvertFrom-Json
}
catch {
    throw "Could not parse configuration file: $Config"
}

$RESOURCE_GROUP = $configData.resourceGroup
$BACKEND_APP    = $configData.backendApp
$FRONTEND_APP   = $configData.frontendApp

foreach ($item in @{
    resourceGroup = $RESOURCE_GROUP
    backendApp    = $BACKEND_APP
    frontendApp   = $FRONTEND_APP
}.GetEnumerator()) {

    if ([string]::IsNullOrWhiteSpace($item.Value)) {
        throw "Missing required configuration value: $($item.Key)"
    }
}

# ============================================================
# Prerequisites
# ============================================================

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI is required."
}

try {
    az account show --output none 2>$null
}
catch {
    throw "Azure CLI is not logged in. Run 'az login' first."
}

Write-Host "  [OK] Azure CLI available" -ForegroundColor Green
Write-Host "  [OK] Azure login" -ForegroundColor Green
Write-Host "  [INFO] Resource Group: $RESOURCE_GROUP" -ForegroundColor DarkGray
Write-Host "  [INFO] Application:    $App" -ForegroundColor DarkGray
Write-Host "  [INFO] Revisions:     $Count" -ForegroundColor DarkGray

# ============================================================
# Display revisions
# ============================================================

switch ($App) {

    "backend" {
        Show-Revisions $BACKEND_APP "Backend"
    }

    "frontend" {
        Show-Revisions $FRONTEND_APP "Frontend"
    }

    "all" {
        Show-Revisions $BACKEND_APP "Backend"
        Show-Revisions $FRONTEND_APP "Frontend"
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkGray
Write-Host " Revision check completed " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor DarkGray
Write-Host ""