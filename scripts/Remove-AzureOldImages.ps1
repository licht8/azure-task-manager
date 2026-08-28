# ============================================================
# Azure Task Manager - Remove Old Container Images
#
# Removes old images from Azure Container Registry.
#
# The script reads ACR and repository names from config.json.
#
# IMPORTANT:
#
#   - The latest images are preserved.
#   - Images used by active Container App revisions are preserved.
#   - Without -Force, the script asks for confirmation.
#   - Use -WhatIf to preview what would be deleted.
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
#       .\scripts\Remove-AzureOldImages.ps1 -Config .\config.json
#
#
# -Repository
#   Specifies which image repository should be cleaned.
#
#   Available values:
#
#       backend   - clean Backend images
#       frontend  - clean Frontend images
#       all       - clean both repositories
#
#   Default:
#
#       all
#
#   Examples:
#
#       .\scripts\Remove-AzureOldImages.ps1 -Repository backend
#       .\scripts\Remove-AzureOldImages.ps1 -Repository frontend
#       .\scripts\Remove-AzureOldImages.ps1 -Repository all
#
#
# -Keep
#   Specifies how many latest images should be preserved.
#
#   Default:
#
#       10
#
#   Example:
#
#       .\scripts\Remove-AzureOldImages.ps1 -Keep 5
#
#
# -WhatIf
#   Shows which images would be deleted without deleting anything.
#
#   Example:
#
#       .\scripts\Remove-AzureOldImages.ps1 -WhatIf
#
#
# -Force
#   Deletes old images without asking for confirmation.
#
#   Use with caution.
#
#   Example:
#
#       .\scripts\Remove-AzureOldImages.ps1 -Keep 5 -Force
#
# ============================================================

param(
    [string]$Config = ".\config.json",

    [ValidateSet("backend", "frontend", "all")]
    [string]$Repository = "all",

    [int]$Keep = 10,

    [switch]$WhatIf,

    [switch]$Force
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

function Write-WarningStatus {
    param([string]$Message)

    Write-Host "  [WARNING] $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)

    Write-Host "  [INFO]    $Message" -ForegroundColor DarkGray
}

# ============================================================
# Load configuration
# ============================================================

Write-Section "Azure Task Manager - Remove Old Images"

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

if ($Keep -lt 1) {
    throw "Keep must be greater than 0."
}

Write-Pass "Configuration loaded"

Write-Info "Resource Group: $RESOURCE_GROUP"
Write-Info "ACR:            $ACR_NAME"
Write-Info "Repository:     $Repository"
Write-Info "Keep:            $Keep"

if ($WhatIf) {
    Write-Info "Mode:            WhatIf"
}
elseif ($Force) {
    Write-WarningStatus "Mode:            Force"
}
else {
    Write-Info "Mode:            Confirmation required"
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

# ============================================================
# Get active images
# ============================================================

function Get-ActiveImage {
    param(
        [string]$AppName
    )

    try {

        $app = az containerapp show `
            --name $AppName `
            --resource-group $RESOURCE_GROUP `
            --output json 2>$null |
            ConvertFrom-Json

        if (-not $app) {
            return $null
        }

        return $app.properties.template.containers[0].image
    }
    catch {
        return $null
    }
}

$activeBackendImage  = Get-ActiveImage $configData.backendApp
$activeFrontendImage = Get-ActiveImage $configData.frontendApp

# ============================================================
# Cleanup function
# ============================================================

function Remove-OldImages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryName,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [string]$ActiveImage
    )

    Write-Section "$DisplayName Image Cleanup"

    Write-Info "Repository: $RepositoryName"

    $tagsJson = az acr repository show-tags `
        --name $ACR_NAME `
        --repository $RepositoryName `
        --orderby time_desc `
        --output json 2>$null

    if ($LASTEXITCODE -ne 0) {

        Write-Failed "Repository '$RepositoryName' was not found"

        return
    }

    try {
        $tags = $tagsJson | ConvertFrom-Json
    }
    catch {

        Write-Failed "Could not retrieve image tags"

        return
    }

    if (-not $tags -or $tags.Count -le $Keep) {

        Write-Pass "Nothing to remove"

        return
    }

    $oldTags = @(
        $tags | Select-Object -Skip $Keep
    )

    Write-Info "Images found: $($tags.Count)"
    Write-Info "Images kept:  $Keep"
    Write-Info "Candidates:   $($oldTags.Count)"

    # --------------------------------------------------------
    # Protect currently deployed image
    # --------------------------------------------------------

    $protectedTag = $null

    if ($ActiveImage) {

        $protectedTag = ($ActiveImage -split ":")[-1]

        Write-Info "Active image: $ActiveImage"
    }

    $deleteTags = @()

    foreach ($tag in $oldTags) {

        if ($tag -eq $protectedTag) {

            Write-WarningStatus "Keeping active image: $tag"

            continue
        }

        $deleteTags += $tag
    }

    if ($deleteTags.Count -eq 0) {

        Write-Pass "No removable images found"

        return
    }

    # --------------------------------------------------------
    # Display candidates
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Images to remove:" -ForegroundColor Yellow

    foreach ($tag in $deleteTags) {
        Write-Host "  $tag"
    }

    # --------------------------------------------------------
    # WhatIf
    # --------------------------------------------------------

    if ($WhatIf) {

        Write-Host ""
        Write-Info "WhatIf mode: no images were deleted"

        return
    }

    # --------------------------------------------------------
    # Confirmation
    # --------------------------------------------------------

    if (-not $Force) {

        Write-Host ""

        $confirmation = Read-Host "Delete these images? [Y/N]"

        if ($confirmation -notmatch "^(Y|y)$") {

            Write-Info "Operation cancelled"

            return
        }
    }

    # --------------------------------------------------------
    # Delete images
    # --------------------------------------------------------

    foreach ($tag in $deleteTags) {

        Write-Info "Deleting: $RepositoryName`:$tag"

        az acr repository delete `
            --name $ACR_NAME `
            --image "$RepositoryName`:$tag" `
            --yes `
            --output none

        if ($LASTEXITCODE -eq 0) {

            Write-Pass "Deleted: $tag"
        }
        else {

            Write-Failed "Could not delete: $tag"
        }
    }
}

# ============================================================
# Execute
# ============================================================

switch ($Repository) {

    "backend" {

        Remove-OldImages `
            -RepositoryName $BACKEND_IMAGE `
            -DisplayName "Backend" `
            -ActiveImage $activeBackendImage
    }

    "frontend" {

        Remove-OldImages `
            -RepositoryName $FRONTEND_IMAGE `
            -DisplayName "Frontend" `
            -ActiveImage $activeFrontendImage
    }

    "all" {

        Remove-OldImages `
            -RepositoryName $BACKEND_IMAGE `
            -DisplayName "Backend" `
            -ActiveImage $activeBackendImage

        Remove-OldImages `
            -RepositoryName $FRONTEND_IMAGE `
            -DisplayName "Frontend" `
            -ActiveImage $activeFrontendImage
    }
}

# ============================================================
# Completed
# ============================================================

Write-Section "Image Cleanup Completed"

if ($WhatIf) {
    Write-Info "No changes were made."
}
else {
    Write-Pass "Image cleanup completed"
}