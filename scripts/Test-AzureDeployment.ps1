# ============================================================
# Azure Task Manager - Deployment Test
#
# Read-only integration test for checking the Azure deployment.
#
# The script reads application names and the Resource Group
# from config.json.
#
# The script verifies the main Azure infrastructure and
# application components required by Azure Task Manager.
#
# CHECKS
#
#   - Azure CLI availability and login
#   - Resource Group
#   - Azure Container Registry
#   - Backend and Frontend container images
#   - Container Apps Environment
#   - Backend Container App
#   - Frontend Container App
#   - Running and Healthy revisions
#   - PostgreSQL Flexible Server
#   - PostgreSQL database
#   - Backend /health endpoint
#   - Frontend HTTP endpoint
#   - FRONTEND_URL configuration
#
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
#       .\scripts\Test-AzureDeployment.ps1 -Config .\config.json
#
#
# ============================================================

param(
    [string]$Config = ".\config.json"
)

$ErrorActionPreference = "Stop"

$Passed = 0
$Warnings = 0
$Failed = 0

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

function Pass {
    param([string]$Message)

    $script:Passed++

    Write-Host "  [PASS]    $Message" `
        -ForegroundColor Green
}

function Warn {
    param([string]$Message)

    $script:Warnings++

    Write-Host "  [WARNING] $Message" `
        -ForegroundColor Yellow
}

function Fail {
    param([string]$Message)

    $script:Failed++

    Write-Host "  [FAILED]  $Message" `
        -ForegroundColor Red
}

function Info {
    param([string]$Message)

    Write-Host "  [INFO]    $Message" `
        -ForegroundColor DarkGray
}

# ============================================================
# Azure CLI helper
# ============================================================

function Invoke-AzQuery {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $result = & az @Arguments 2>$null

    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    return $result
}

function Test-AzResource {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & az @Arguments *> $null

    return $LASTEXITCODE -eq 0
}

# ============================================================
# HTTP test
# ============================================================

function Test-HttpEndpoint {
    param(
        [string]$Url,
        [string]$Name
    )

    try {

        $response = Invoke-WebRequest `
            -Uri $Url `
            -Method GET `
            -TimeoutSec 15 `
            -UseBasicParsing `
            -ErrorAction Stop

        $code = [int]$response.StatusCode

        if ($code -ge 200 -and $code -lt 400) {
            Pass "$Name - HTTP $code"
            return
        }

        Fail "$Name - HTTP $code"
    }
    catch {

        Fail "$Name - endpoint unavailable"
        Info $_.Exception.Message
    }
}

# ============================================================
# Container App test
# ============================================================

function Test-ContainerApp {
    param(
        [string]$AppName,
        [string]$DisplayName,
        [string]$ExpectedRepository
    )

    Write-Section "$DisplayName Container App"

    if (-not (Test-AzResource @(
        "containerapp",
        "show",
        "--name",
        $AppName,
        "--resource-group",
        $RESOURCE_GROUP
    ))) {

        Fail "$DisplayName Container App does not exist"

        return $null
    }

    Pass "$DisplayName Container App exists"

    # --------------------------------------------------------
    # Provisioning state
    # --------------------------------------------------------

    $provisioningState = Invoke-AzQuery @(
        "containerapp",
        "show",
        "--name",
        $AppName,
        "--resource-group",
        $RESOURCE_GROUP,
        "--query",
        "properties.provisioningState",
        "--output",
        "tsv"
    )

    if ($provisioningState -eq "Succeeded") {
        Pass "Provisioning: Succeeded"
    }
    else {
        Fail "Provisioning: $provisioningState"
    }

    # --------------------------------------------------------
    # Running status
    # --------------------------------------------------------

    $runningStatus = Invoke-AzQuery @(
        "containerapp",
        "show",
        "--name",
        $AppName,
        "--resource-group",
        $RESOURCE_GROUP,
        "--query",
        "properties.runningStatus",
        "--output",
        "tsv"
    )

    if ($runningStatus -eq "Running") {
        Pass "Running status: Running"
    }
    else {
        Fail "Running status: $runningStatus"
    }

    # --------------------------------------------------------
    # Ingress
    # --------------------------------------------------------

    $fqdn = Invoke-AzQuery @(
        "containerapp",
        "show",
        "--name",
        $AppName,
        "--resource-group",
        $RESOURCE_GROUP,
        "--query",
        "properties.configuration.ingress.fqdn",
        "--output",
        "tsv"
    )

    if ($fqdn) {

        Pass "External ingress configured"

        $url = "https://$fqdn"

        Info "URL: $url"
    }
    else {

        Fail "External ingress not configured"

        $url = $null
    }

    # --------------------------------------------------------
    # Current image
    # --------------------------------------------------------

    $currentImage = Invoke-AzQuery @(
        "containerapp",
        "show",
        "--name",
        $AppName,
        "--resource-group",
        $RESOURCE_GROUP,
        "--query",
        "properties.template.containers[0].image",
        "--output",
        "tsv"
    )

    if ($currentImage) {

        # Remove image tag before comparison.
        # Example:
        #
        # taskmanager.azurecr.io/app:abc123
        #
        # becomes:
        #
        # taskmanager.azurecr.io/app
        #
        $imageRepository = $currentImage -replace ":[^/:]+$", ""

        if ($imageRepository -eq $ExpectedRepository) {

            Pass "Correct container image"

            Info "Image: $currentImage"
        }
        else {

            Fail "Unexpected container image"

            Info "Image: $currentImage"
            Info "Expected repository: $ExpectedRepository"
        }
    }
    else {

        Fail "Could not determine current container image"
    }

    # --------------------------------------------------------
    # Current revision
    # --------------------------------------------------------

    $revisionJson = Invoke-AzQuery @(
        "containerapp",
        "revision",
        "list",
        "--name",
        $AppName,
        "--resource-group",
        $RESOURCE_GROUP,
        "--output",
        "json"
    )

    $revision = $null

    if ($revisionJson) {

        try {

            $revisions = $revisionJson | ConvertFrom-Json

            if ($revisions) {

                $revision = $revisions |
                    Sort-Object {
                        [datetime]$_.properties.createdTime
                    } -Descending |
                    Select-Object -First 1
            }
        }
        catch {
            $revision = $null
        }
    }

    if ($revision) {

        $revisionName = $revision.name
        $revisionProperties = $revision.properties

        Pass "Current revision: $revisionName"

        # ----------------------------------------------------
        # Revision health
        # ----------------------------------------------------

        if ($revisionProperties.healthState -eq "Healthy") {

            Pass "Revision health: Healthy"
        }
        else {

            Fail "Revision health: $($revisionProperties.healthState)"
        }

        # ----------------------------------------------------
        # Revision provisioning
        # ----------------------------------------------------

        if ($revisionProperties.provisioningState -eq "Provisioned") {

            Pass "Revision state: Provisioned"
        }
        else {

            Fail "Revision state: $($revisionProperties.provisioningState)"
        }

        # ----------------------------------------------------
        # Revision running state
        # ----------------------------------------------------

        if ($revisionProperties.runningState -eq "Running") {

            Pass "Revision running: Running"
        }
        else {

            Fail "Revision running: $($revisionProperties.runningState)"
        }

        # ----------------------------------------------------
        # Active state
        # ----------------------------------------------------

        if ($revisionProperties.active -eq $true) {

            Pass "Revision active: True"
        }
        else {

            Warn "Revision active: False"
        }

        # ----------------------------------------------------
        # Traffic
        # ----------------------------------------------------

        $traffic = [int]$revisionProperties.trafficWeight

        if ($traffic -eq 100) {

            Pass "Revision traffic: 100%"
        }
        elseif ($traffic -gt 0) {

            Warn "Revision traffic: $traffic%"
        }
        else {

            Warn "Revision has no traffic"
        }

        Info "Replicas: $($revisionProperties.replicas)"
        Info "Created:  $($revisionProperties.createdTime)"

    }
    else {

        Fail "Could not determine current revision"
    }

    return @{
        Url   = $url
        Image = $currentImage
        Revision = $revisionName
    }
}

# ============================================================
# Load configuration
# ============================================================

Write-Section "Azure Task Manager - Deployment Test"

Write-Host "Configuration:"
Write-Host "  $Config"

if (-not (Test-Path $Config)) {
    throw "Configuration file not found: $Config"
}

try {

    $configData = Get-Content `
        -Path $Config `
        -Raw |
        ConvertFrom-Json

    Pass "Configuration loaded"
}
catch {

    throw "Could not parse configuration file: $Config"
}

# ============================================================
# Configuration
# ============================================================

$RESOURCE_GROUP  = $configData.resourceGroup
$ACR_NAME        = $configData.acrName
$ENVIRONMENT_NAME = $configData.environmentName

$BACKEND_APP     = $configData.backendApp
$FRONTEND_APP    = $configData.frontendApp

$BACKEND_IMAGE   = $configData.backendImage
$FRONTEND_IMAGE  = $configData.frontendImage

$POSTGRES_SERVER   = $configData.postgresServer
$POSTGRES_DATABASE = $configData.postgresDatabase

$required = @{
    "resourceGroup"    = $RESOURCE_GROUP
    "acrName"          = $ACR_NAME
    "environmentName"  = $ENVIRONMENT_NAME
    "backendApp"       = $BACKEND_APP
    "frontendApp"      = $FRONTEND_APP
    "backendImage"     = $BACKEND_IMAGE
    "frontendImage"    = $FRONTEND_IMAGE
    "postgresServer"   = $POSTGRES_SERVER
    "postgresDatabase" = $POSTGRES_DATABASE
}

foreach ($item in $required.GetEnumerator()) {

    if ([string]::IsNullOrWhiteSpace($item.Value)) {

        throw "Missing required configuration value: $($item.Key)"
    }
}

# ============================================================
# Prerequisites
# ============================================================

Write-Section "Prerequisites"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {

    Fail "Azure CLI is not installed or not available in PATH"

    exit 1
}

Pass "Azure CLI available"

# ============================================================
# Azure login
# ============================================================

$accountJson = Invoke-AzQuery @(
    "account",
    "show",
    "--output",
    "json"
)

if (-not $accountJson) {

    Fail "Azure CLI is not logged in"

    exit 1
}

try {

    $account = $accountJson | ConvertFrom-Json
}
catch {

    Fail "Could not parse Azure account information"

    exit 1
}

Pass "Azure login"

Info "Subscription: $($account.name)"
Info "ID:           $($account.id)"

# ============================================================
# Resource Group
# ============================================================

Write-Section "Resource Group"

if (Test-AzResource @(
    "group",
    "show",
    "--name",
    $RESOURCE_GROUP
)) {

    Pass "Resource Group exists"
}
else {

    Fail "Resource Group does not exist"
}

# ============================================================
# Azure Container Registry
# ============================================================

Write-Section "Azure Container Registry"

$acrExists = Test-AzResource @(
    "acr",
    "show",
    "--name",
    $ACR_NAME,
    "--resource-group",
    $RESOURCE_GROUP
)

if ($acrExists) {

    Pass "ACR exists"

    $acrLoginServer = Invoke-AzQuery @(
        "acr",
        "show",
        "--name",
        $ACR_NAME,
        "--resource-group",
        $RESOURCE_GROUP,
        "--query",
        "loginServer",
        "--output",
        "tsv"
    )

    Info "Login server: $acrLoginServer"
}
else {

    Fail "ACR does not exist"

    $acrLoginServer = $null
}

# ============================================================
# Container Images
# ============================================================

Write-Section "Container Images"

if ($acrExists) {

    if (Test-AzResource @(
        "acr",
        "repository",
        "show",
        "--name",
        $ACR_NAME,
        "--repository",
        $BACKEND_IMAGE
    )) {

        Pass "Backend image repository exists"
    }
    else {

        Fail "Backend image repository does not exist"
    }

    if (Test-AzResource @(
        "acr",
        "repository",
        "show",
        "--name",
        $ACR_NAME,
        "--repository",
        $FRONTEND_IMAGE
    )) {

        Pass "Frontend image repository exists"
    }
    else {

        Fail "Frontend image repository does not exist"
    }
}

# ============================================================
# Container Apps Environment
# ============================================================

Write-Section "Container Apps Environment"

if (Test-AzResource @(
    "containerapp",
    "env",
    "show",
    "--name",
    $ENVIRONMENT_NAME,
    "--resource-group",
    $RESOURCE_GROUP
)) {

    Pass "Container Apps Environment exists"
}
else {

    Fail "Container Apps Environment does not exist"
}

# ============================================================
# Backend
# ============================================================

$backend = Test-ContainerApp `
    -AppName $BACKEND_APP `
    -DisplayName "Backend" `
    -ExpectedRepository "$acrLoginServer/$BACKEND_IMAGE"

# ============================================================
# Frontend
# ============================================================

$frontend = Test-ContainerApp `
    -AppName $FRONTEND_APP `
    -DisplayName "Frontend" `
    -ExpectedRepository "$acrLoginServer/$FRONTEND_IMAGE"

# ============================================================
# PostgreSQL
# ============================================================

Write-Section "PostgreSQL"

$postgresExists = Test-AzResource @(
    "postgres",
    "flexible-server",
    "show",
    "--name",
    $POSTGRES_SERVER,
    "--resource-group",
    $RESOURCE_GROUP
)

if ($postgresExists) {

    Pass "PostgreSQL server exists"

    $postgresState = Invoke-AzQuery @(
        "postgres",
        "flexible-server",
        "show",
        "--name",
        $POSTGRES_SERVER,
        "--resource-group",
        $RESOURCE_GROUP,
        "--query",
        "state",
        "--output",
        "tsv"
    )

    if ($postgresState -eq "Ready") {

        Pass "PostgreSQL state: Ready"
    }
    else {

        Fail "PostgreSQL state: $postgresState"
    }

    $databaseExists = Test-AzResource @(
        "postgres",
        "flexible-server",
        "db",
        "show",
        "--resource-group",
        $RESOURCE_GROUP,
        "--server-name",
        $POSTGRES_SERVER,
        "--name",
        $POSTGRES_DATABASE
    )

    if ($databaseExists) {

        Pass "PostgreSQL database exists"
    }
    else {

        Fail "PostgreSQL database does not exist"
    }
}
else {

    Fail "PostgreSQL server does not exist"
}

# ============================================================
# HTTP Tests
# ============================================================

Write-Section "HTTP Tests"

if ($backend -and $backend.Url) {

    Test-HttpEndpoint `
        -Url "$($backend.Url)/health" `
        -Name "Backend /health"
}
else {

    Fail "Backend /health cannot be tested"
}

if ($frontend -and $frontend.Url) {

    Test-HttpEndpoint `
        -Url $frontend.Url `
        -Name "Frontend /"
}
else {

    Fail "Frontend cannot be tested"
}

# ============================================================
# Application Configuration
# ============================================================

Write-Section "Application Configuration"

$frontendUrlConfigured = Invoke-AzQuery @(
    "containerapp",
    "show",
    "--name",
    $BACKEND_APP,
    "--resource-group",
    $RESOURCE_GROUP,
    "--query",
    "properties.template.containers[0].env[?name=='FRONTEND_URL'].value",
    "--output",
    "tsv"
)

if ($frontendUrlConfigured -and
    $frontend -and
    $frontend.Url) {

    if ($frontendUrlConfigured -eq $frontend.Url) {

        Pass "FRONTEND_URL matches Frontend URL"

        Info "FRONTEND_URL: $frontendUrlConfigured"
    }
    else {

        Fail "FRONTEND_URL does not match Frontend URL"

        Info "Configured: $frontendUrlConfigured"
        Info "Expected:   $($frontend.Url)"
    }
}
else {

    Warn "Could not determine FRONTEND_URL"
}

# ============================================================
# Result
# ============================================================

Write-Section "Deployment Test Result"

Write-Host "  Passed:   $Passed"
Write-Host "  Warnings: $Warnings"
Write-Host "  Failed:   $Failed"

Write-Host ""

if ($Failed -eq 0 -and $Warnings -eq 0) {

    Write-Host "  Overall status: DEPLOYMENT HEALTHY" `
        -ForegroundColor Green
}
elseif ($Failed -eq 0) {

    Write-Host "  Overall status: HEALTHY WITH WARNINGS" `
        -ForegroundColor Yellow
}
else {

    Write-Host "  Overall status: DEPLOYMENT FAILED" `
        -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================================"

if ($backend -and $backend.Url) {

    Write-Host ""
    Write-Host "Backend:" -ForegroundColor Cyan
    Write-Host "  $($backend.Url)"
    Write-Host "  $($backend.Url)/docs"
    Write-Host "  $($backend.Url)/health"
}

if ($frontend -and $frontend.Url) {

    Write-Host ""
    Write-Host "Frontend:" -ForegroundColor Cyan
    Write-Host "  $($frontend.Url)"
}

Write-Host ""

if ($Failed -gt 0) {
    exit 1
}

exit 0