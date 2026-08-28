# ============================================================
# Azure Task Manager - Container Registry Images
#
# Read-only script for viewing images stored in Azure Container
# Registry.
#
# The script reads ACR and repository names from config.json.
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
#       .\scripts\Get-AzureImages.ps1 -Config .\config.json
#
#
# -Repository
#   Specifies which image repository should be displayed.
#
#   Available values:
#
#       backend   - show Backend images
#       frontend  - show Frontend images
#       all       - show images from both repositories
#
#   Default:
#
#       all
#
#   Examples:
#
#       .\scripts\Get-AzureImages.ps1 -Repository backend
#       .\scripts\Get-AzureImages.ps1 -Repository frontend
#       .\scripts\Get-AzureImages.ps1 -Repository all
#
#
# -Count
#   Specifies how many recent images should be displayed.
#
#   Default:
#
#       10
#
#   Example:
#
#       .\scripts\Get-AzureImages.ps1 -Repository backend -Count 20
#
#
# -All
#   Displays all available images instead of limiting the output
#   to the number specified by -Count.
#
#   Example:
#
#       .\scripts\Get-AzureImages.ps1 -Repository backend -All
#
# ============================================================

param(
    [string]$Config = ".\config.json",

    [ValidateSet("backend", "frontend", "all")]
    [string]$Repository = "all",

    [int]$Count = 10,

    [switch]$All
)

$ErrorActionPreference = "Stop"

# ============================================================
# Output helpers
# ============================================================

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
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

Write-Section "Azure Task Manager - Container Registry Images"

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
$ACR_NAME       = $configData.acrName
$BACKEND_IMAGE  = $configData.backendImage
$FRONTEND_IMAGE = $configData.frontendImage

foreach ($item in @{
    "resourceGroup" = $RESOURCE_GROUP
    "acrName"       = $ACR_NAME
    "backendImage"  = $BACKEND_IMAGE
    "frontendImage" = $FRONTEND_IMAGE
}.GetEnumerator()) {

    if ([string]::IsNullOrWhiteSpace($item.Value)) {
        throw "Missing required configuration value: $($item.Key)"
    }
}

Write-Pass "Configuration loaded"

Write-Info "Resource Group: $RESOURCE_GROUP"
Write-Info "ACR:            $ACR_NAME"
Write-Info "Repository:     $Repository"

# ============================================================
# Validate parameters
# ============================================================

if ($Count -lt 1) {
    throw "Count must be greater than 0."
}

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
# ACR information
# ============================================================

Write-Section "Azure Container Registry"

$acrLoginServer = az acr show `
    --name $ACR_NAME `
    --resource-group $RESOURCE_GROUP `
    --query "loginServer" `
    --output tsv 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($acrLoginServer)) {

    Write-Failed "Azure Container Registry '$ACR_NAME' was not found"

    exit 1
}

Write-Pass "ACR exists"
Write-Info "Login server: $acrLoginServer"

# ============================================================
# Show repository images
# ============================================================

function Show-Images {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryName,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    Write-Section "$DisplayName Images"

    Write-Info "Repository: $RepositoryName"

    $tags = az acr repository show-tags `
        --name $ACR_NAME `
        --repository $RepositoryName `
        --orderby time_desc `
        --output json 2>$null

    if ($LASTEXITCODE -ne 0) {

        Write-Failed "Repository '$RepositoryName' was not found"

        return
    }

    try {
        $tags = $tags | ConvertFrom-Json
    }
    catch {

        Write-Failed "Could not read image tags"

        return
    }

    if (-not $tags -or $tags.Count -eq 0) {

        Write-Info "No images found"

        return
    }

    if (-not $All) {
        $tags = $tags | Select-Object -First $Count
    }

    Write-Host ""

    Write-Host "  Tag" -ForegroundColor Cyan
    Write-Host "  --------------------------------------------------------" -ForegroundColor DarkGray

    foreach ($tag in $tags) {

        Write-Host "  $tag"
    }

    Write-Host ""

    Write-Info "Images displayed: $($tags.Count)"
}

# ============================================================
# Execute
# ============================================================

switch ($Repository) {

    "backend" {
        Show-Images `
            -RepositoryName $BACKEND_IMAGE `
            -DisplayName "Backend"
    }

    "frontend" {
        Show-Images `
            -RepositoryName $FRONTEND_IMAGE `
            -DisplayName "Frontend"
    }

    "all" {

        Show-Images `
            -RepositoryName $BACKEND_IMAGE `
            -DisplayName "Backend"

        Show-Images `
            -RepositoryName $FRONTEND_IMAGE `
            -DisplayName "Frontend"
    }
}

# ============================================================
# Completed
# ============================================================

Write-Section "Image Check Completed"

Write-Pass "Azure Container Registry image check completed"