# ============================================================
# Azure Task Manager - Infrastructure Health Check
#
# Read-only diagnostic script.
#
# Usage:
#
#   .\scripts\Check-AzureHealth.ps1
#
#   .\scripts\Check-AzureHealth.ps11 -Config .\config.json
#
# The script does NOT create, update or delete Azure resources.
#
# ============================================================

param(
    [string]$Config = ".\config.json"
)

$ErrorActionPreference = "Stop"

# ============================================================
# Status counters
# ============================================================

$script:HealthIssues = 0
$script:HealthWarnings = 0

# ============================================================
# Output helpers
# ============================================================

function Write-Section {
    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-OK {
    param(
        [string]$Message
    )

    Write-Host "  [OK]      $Message" -ForegroundColor Green
}

function Write-WarningStatus {
    param(
        [string]$Message
    )

    $script:HealthWarnings++

    Write-Host "  [WARNING] $Message" -ForegroundColor Yellow
}

function Write-Failed {
    param(
        [string]$Message
    )

    $script:HealthIssues++

    Write-Host "  [FAILED]  $Message" -ForegroundColor Red
}

function Write-Info {
    param(
        [string]$Message
    )

    Write-Host "  [INFO]    $Message" -ForegroundColor DarkGray
}

# ============================================================
# Helpers
# ============================================================

function Test-CommandExists {
    param(
        [string]$Command
    )

    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

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

function Test-HttpEndpoint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $response = Invoke-WebRequest `
            -Uri $Url `
            -Method GET `
            -TimeoutSec 15 `
            -UseBasicParsing `
            -ErrorAction Stop

        $statusCode = [int]$response.StatusCode

        if ($statusCode -ge 200 -and $statusCode -lt 400) {
            Write-OK "$Name - HTTP $statusCode"
            return $true
        }

        Write-WarningStatus "$Name - HTTP $statusCode"
        return $false
    }
    catch {
        Write-Failed "$Name - endpoint unavailable"
        Write-Info $_.Exception.Message
        return $false
    }
}

# ============================================================
# Load configuration
# ============================================================

Write-Section "Azure Task Manager - Infrastructure Health"

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

# ============================================================
# Configuration
# ============================================================

$LOCATION = $configData.location
$RESOURCE_GROUP = $configData.resourceGroup
$ACR_NAME = $configData.acrName
$ENVIRONMENT_NAME = $configData.environmentName

$BACKEND_APP = $configData.backendApp
$FRONTEND_APP = $configData.frontendApp

$BACKEND_IMAGE = $configData.backendImage
$FRONTEND_IMAGE = $configData.frontendImage

$POSTGRES_SERVER = $configData.postgresServer
$POSTGRES_DATABASE = $configData.postgresDatabase
$POSTGRES_ADMIN = $configData.postgresAdmin

$requiredConfiguration = @{
    location         = $LOCATION
    resourceGroup    = $RESOURCE_GROUP
    acrName          = $ACR_NAME
    environmentName  = $ENVIRONMENT_NAME
    backendApp       = $BACKEND_APP
    frontendApp      = $FRONTEND_APP
    backendImage     = $BACKEND_IMAGE
    frontendImage    = $FRONTEND_IMAGE
    postgresServer   = $POSTGRES_SERVER
    postgresDatabase = $POSTGRES_DATABASE
    postgresAdmin    = $POSTGRES_ADMIN
}

foreach ($item in $requiredConfiguration.GetEnumerator()) {
    if ([string]::IsNullOrWhiteSpace([string]$item.Value)) {
        throw "Missing required configuration value: $($item.Key)"
    }
}

Write-OK "Configuration loaded"

Write-Info "Location:       $LOCATION"
Write-Info "Resource Group: $RESOURCE_GROUP"
Write-Info "ACR:            $ACR_NAME"
Write-Info "Environment:    $ENVIRONMENT_NAME"
Write-Info "Backend:        $BACKEND_APP"
Write-Info "Frontend:       $FRONTEND_APP"
Write-Info "PostgreSQL:     $POSTGRES_SERVER"

# ============================================================
# Prerequisites
# ============================================================

Write-Section "Prerequisites"

if (-not (Test-CommandExists "az")) {
    Write-Failed "Azure CLI is not installed"
    throw "Azure CLI is required."
}

Write-OK "Azure CLI available"

# ============================================================
# Azure account
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

Write-Info "User:         $($account.user.name)"
Write-Info "Subscription: $($account.name)"
Write-Info "ID:           $($account.id)"

# ============================================================
# Resource Group
# ============================================================

Write-Section "Resource Group"

$rgExists = Test-AzResource @(
    "group",
    "show",
    "--name",
    $RESOURCE_GROUP
)

if ($rgExists) {
    Write-OK "Resource Group: $RESOURCE_GROUP"

    $rgLocation = Invoke-AzQuery @(
        "group",
        "show",
        "--name",
        $RESOURCE_GROUP,
        "--query",
        "location",
        "--output",
        "tsv"
    )

    Write-Info "Location: $rgLocation"

    if ($rgLocation -ne $LOCATION) {
        Write-WarningStatus "Configured location is '$LOCATION', actual location is '$rgLocation'"
    }
}
else {
    Write-Failed "Resource Group '$RESOURCE_GROUP' does not exist"
}

# ============================================================
# ACR
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

$acrLoginServer = $null
$acrId = $null

if ($acrExists) {
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

    $acrId = Invoke-AzQuery @(
        "acr",
        "show",
        "--name",
        $ACR_NAME,
        "--resource-group",
        $RESOURCE_GROUP,
        "--query",
        "id",
        "--output",
        "tsv"
    )

    Write-OK "ACR: $ACR_NAME"
    Write-Info "Login server: $acrLoginServer"
}
else {
    Write-Failed "ACR '$ACR_NAME' does not exist"
}

# ============================================================
# ACR repositories
# ============================================================

if ($acrExists) {

    Write-Section "ACR Images"

    foreach ($repository in @(
        $BACKEND_IMAGE,
        $FRONTEND_IMAGE
    )) {

        $repositoryExists = Test-AzResource @(
            "acr",
            "repository",
            "show",
            "--name",
            $ACR_NAME,
            "--repository",
            $repository
        )

        if ($repositoryExists) {

            Write-OK "Repository: $repository"

            $tags = Invoke-AzQuery @(
                "acr",
                "repository",
                "show-tags",
                "--name",
                $ACR_NAME,
                "--repository",
                $repository,
                "--orderby",
                "time_desc",
                "--top",
                "5",
                "--output",
                "tsv"
            )

            if ($tags) {
                Write-Info "Recent tags:"

                foreach ($tag in $tags) {
                    Write-Host "             $tag" -ForegroundColor DarkGray
                }
            }
            else {
                Write-WarningStatus "Repository '$repository' contains no tags"
            }
        }
        else {
            Write-Failed "Repository '$repository' not found"
        }
    }
}

# ============================================================
# Container Apps Environment
# ============================================================

Write-Section "Container Apps Environment"

$environmentExists = Test-AzResource @(
    "containerapp",
    "env",
    "show",
    "--name",
    $ENVIRONMENT_NAME,
    "--resource-group",
    $RESOURCE_GROUP
)

$environmentProvisioningState = $null

if ($environmentExists) {

    $environmentProvisioningState = Invoke-AzQuery @(
        "containerapp",
        "env",
        "show",
        "--name",
        $ENVIRONMENT_NAME,
        "--resource-group",
        $RESOURCE_GROUP,
        "--query",
        "properties.provisioningState",
        "--output",
        "tsv"
    )

    Write-OK "Environment: $ENVIRONMENT_NAME"
    Write-Info "Provisioning: $environmentProvisioningState"

    if ($environmentProvisioningState -and $environmentProvisioningState -ne "Succeeded") {
        Write-WarningStatus "Environment provisioning state: $environmentProvisioningState"
    }
}
else {
    Write-Failed "Container Apps Environment '$ENVIRONMENT_NAME' not found"
}

# ============================================================
# Container App diagnostic
# ============================================================

function Test-ContainerAppHealth {

    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedRepository
    )

    Write-Host ""
    Write-Host "  $DisplayName" -ForegroundColor Cyan
    Write-Host "  --------------------------------------------------------" -ForegroundColor DarkGray

    $exists = Test-AzResource @(
        "containerapp",
        "show",
        "--name",
        $AppName,
        "--resource-group",
        $RESOURCE_GROUP
    )

    if (-not $exists) {
        Write-Failed "Container App '$AppName' does not exist"
        return $null
    }

    Write-OK "Container App exists"

    # --------------------------------------------------------
    # Basic state
    # --------------------------------------------------------

    $state = Invoke-AzQuery @(
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

    if ($state -eq "Succeeded") {
        Write-OK "Provisioning: Succeeded"
    }
    elseif ($state) {
        Write-Failed "Provisioning: $state"
    }
    else {
        Write-WarningStatus "Could not determine provisioning state"
    }

    $running = Invoke-AzQuery @(
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

    if ($running -eq "Running") {
        Write-OK "Running status: Running"
    }
    elseif ($running) {
        Write-WarningStatus "Running status: $running"
    }
    else {
        Write-WarningStatus "Could not determine running status"
    }

    # --------------------------------------------------------
    # Managed Identity
    # --------------------------------------------------------

    $principalId = Invoke-AzQuery @(
        "containerapp",
        "show",
        "--name",
        $AppName,
        "--resource-group",
        $RESOURCE_GROUP,
        "--query",
        "identity.principalId",
        "--output",
        "tsv"
    )

    if ($principalId) {
        Write-OK "System Managed Identity"
        Write-Info "Principal ID: $principalId"
    }
    else {
        Write-Failed "System Managed Identity not configured"
    }

    # --------------------------------------------------------
    # Registry
    # --------------------------------------------------------

    $registryJson = Invoke-AzQuery @(
        "containerapp",
        "registry",
        "list",
        "--name",
        $AppName,
        "--resource-group",
        $RESOURCE_GROUP,
        "--output",
        "json"
    )

    $registryConfigured = $false

    if ($registryJson) {

        try {
            $registries = $registryJson | ConvertFrom-Json

            foreach ($registry in $registries) {
                if ($registry.server -eq $acrLoginServer) {
                    $registryConfigured = $true
                    break
                }
            }
        }
        catch {
            $registryConfigured = $false
        }
    }

    if ($registryConfigured) {
        Write-OK "ACR registry configured"
        Write-Info "Registry: $acrLoginServer"
    }
    else {
        Write-Failed "ACR registry '$acrLoginServer' is not configured"
    }

    # --------------------------------------------------------
    # AcrPull
    # --------------------------------------------------------

    if ($principalId -and $acrId) {

        $acrPull = Invoke-AzQuery @(
            "role",
            "assignment",
            "list",
            "--assignee-object-id",
            $principalId,
            "--scope",
            $acrId,
            "--query",
            "[?roleDefinitionName=='AcrPull'].id",
            "--output",
            "tsv"
        )

        if ($acrPull) {
            Write-OK "AcrPull role assigned"
        }
        else {
            Write-Failed "AcrPull role not found"
        }
    }

    # --------------------------------------------------------
    # Ingress / URL
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
        $url = "https://$fqdn"

        Write-OK "External ingress configured"
        Write-Info "URL: $url"
    }
    else {
        Write-Failed "External ingress FQDN not found"
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

        if ($currentImage -like "$acrLoginServer/$ExpectedRepository`:*") {
            Write-OK "ACR image configured"
            Write-Info "Image: $currentImage"
        }
        elseif ($currentImage -eq "mcr.microsoft.com/k8se/quickstart:latest") {
            Write-WarningStatus "Bootstrap image is still configured"
            Write-Info "Image: $currentImage"
        }
        else {
            Write-WarningStatus "Unexpected container image"
            Write-Info "Image: $currentImage"
        }
    }
    else {
        Write-WarningStatus "Could not determine current container image"
    }

    return @{
        Url         = $url
        Fqdn        = $fqdn
        PrincipalId = $principalId
    }
}

# ============================================================
# Backend
# ============================================================

Write-Section "Backend Container App"

$backendHealth = Test-ContainerAppHealth `
    -AppName $BACKEND_APP `
    -DisplayName "Backend" `
    -ExpectedRepository $BACKEND_IMAGE

# ============================================================
# Frontend
# ============================================================

Write-Section "Frontend Container App"

$frontendHealth = Test-ContainerAppHealth `
    -AppName $FRONTEND_APP `
    -DisplayName "Frontend" `
    -ExpectedRepository $FRONTEND_IMAGE

# ============================================================
# PostgreSQL
# ============================================================

Write-Section "PostgreSQL Flexible Server"

$postgresExists = Test-AzResource @(
    "postgres",
    "flexible-server",
    "show",
    "--name",
    $POSTGRES_SERVER,
    "--resource-group",
    $RESOURCE_GROUP
)

$postgresFqdn = $null

if ($postgresExists) {

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

    $postgresVersion = Invoke-AzQuery @(
        "postgres",
        "flexible-server",
        "show",
        "--name",
        $POSTGRES_SERVER,
        "--resource-group",
        $RESOURCE_GROUP,
        "--query",
        "version",
        "--output",
        "tsv"
    )

    $postgresFqdn = Invoke-AzQuery @(
        "postgres",
        "flexible-server",
        "show",
        "--name",
        $POSTGRES_SERVER,
        "--resource-group",
        $RESOURCE_GROUP,
        "--query",
        "fullyQualifiedDomainName",
        "--output",
        "tsv"
    )

    if ($postgresState -eq "Ready") {
        Write-OK "PostgreSQL server: Ready"
    }
    else {
        Write-WarningStatus "PostgreSQL state: $postgresState"
    }

    Write-Info "Server:  $POSTGRES_SERVER"
    Write-Info "Version: $postgresVersion"
    Write-Info "FQDN:    $postgresFqdn"
}
else {
    Write-Failed "PostgreSQL server '$POSTGRES_SERVER' does not exist"
}

# ============================================================
# PostgreSQL database
# ============================================================

if ($postgresExists) {

    Write-Section "PostgreSQL Database"

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
        Write-OK "Database: $POSTGRES_DATABASE"
    }
    else {
        Write-Failed "Database '$POSTGRES_DATABASE' does not exist"
    }
}

# ============================================================
# HTTP health checks
# ============================================================

Write-Section "HTTP Health Checks"

if ($backendHealth -and $backendHealth.Url) {

    Test-HttpEndpoint `
        -Url "$($backendHealth.Url)/health" `
        -Name "Backend /health"
}
else {
    Write-Failed "Backend /health cannot be tested"
}

if ($frontendHealth -and $frontendHealth.Url) {

    Test-HttpEndpoint `
        -Url $frontendHealth.Url `
        -Name "Frontend /"
}
else {
    Write-Failed "Frontend cannot be tested"
}

# ============================================================
# CORS
# ============================================================

Write-Section "Backend CORS Configuration"

if ($backendHealth -and $frontendHealth -and $frontendHealth.Url) {

    $configuredFrontendUrl = Invoke-AzQuery @(
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

    if ($configuredFrontendUrl -eq $frontendHealth.Url) {

        Write-OK "FRONTEND_URL matches frontend URL"
        Write-Info "FRONTEND_URL: $configuredFrontendUrl"
    }
    elseif ($configuredFrontendUrl) {

        Write-WarningStatus "FRONTEND_URL does not match frontend URL"
        Write-Info "Configured: $configuredFrontendUrl"
        Write-Info "Expected:   $($frontendHealth.Url)"
    }
    else {
        Write-WarningStatus "FRONTEND_URL is not configured"
    }
}

# ============================================================
# Summary
# ============================================================

Write-Section "Infrastructure Summary"

Write-Host "  Resource Group:" -ForegroundColor Cyan

if ($rgExists) {
    Write-Host "    $RESOURCE_GROUP" -ForegroundColor Green
}
else {
    Write-Host "    NOT FOUND" -ForegroundColor Red
}

Write-Host ""
Write-Host "  ACR:" -ForegroundColor Cyan

if ($acrExists) {
    Write-Host "    $acrLoginServer" -ForegroundColor Green
}
else {
    Write-Host "    NOT FOUND" -ForegroundColor Red
}

Write-Host ""
Write-Host "  Container Apps Environment:" -ForegroundColor Cyan

if ($environmentExists) {
    Write-Host "    $ENVIRONMENT_NAME" -ForegroundColor Green
}
else {
    Write-Host "    NOT FOUND" -ForegroundColor Red
}

Write-Host ""
Write-Host "  Backend:" -ForegroundColor Cyan

if ($backendHealth -and $backendHealth.Url) {
    Write-Host "    $($backendHealth.Url)" -ForegroundColor Green
}
else {
    Write-Host "    NOT AVAILABLE" -ForegroundColor Red
}

Write-Host ""
Write-Host "  Frontend:" -ForegroundColor Cyan

if ($frontendHealth -and $frontendHealth.Url) {
    Write-Host "    $($frontendHealth.Url)" -ForegroundColor Green
}
else {
    Write-Host "    NOT AVAILABLE" -ForegroundColor Red
}

Write-Host ""
Write-Host "  PostgreSQL:" -ForegroundColor Cyan

if ($postgresExists) {
    Write-Host "    $POSTGRES_SERVER" -ForegroundColor Green
}
else {
    Write-Host "    NOT AVAILABLE" -ForegroundColor Red
}

# ============================================================
# Final result
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkGray

if ($script:HealthIssues -eq 0 -and $script:HealthWarnings -eq 0) {

    Write-Host " Overall status: HEALTHY " -ForegroundColor Green
}
elseif ($script:HealthIssues -eq 0) {

    Write-Host " Overall status: HEALTHY WITH WARNINGS " -ForegroundColor Yellow
}
else {

    Write-Host " Overall status: UNHEALTHY " -ForegroundColor Red
}

Write-Host "============================================================" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Checks:"
Write-Host "  Failed:   $script:HealthIssues"
Write-Host "  Warnings: $script:HealthWarnings"

# ============================================================
# URLs
# ============================================================

if ($backendHealth -and $backendHealth.Url) {

    Write-Host ""
    Write-Host "Backend:" -ForegroundColor Cyan
    Write-Host "  $($backendHealth.Url)" -ForegroundColor White
    Write-Host "  $($backendHealth.Url)/docs" -ForegroundColor White
    Write-Host "  $($backendHealth.Url)/health" -ForegroundColor White
}

if ($frontendHealth -and $frontendHealth.Url) {

    Write-Host ""
    Write-Host "Frontend:" -ForegroundColor Cyan
    Write-Host "  $($frontendHealth.Url)" -ForegroundColor White
}

Write-Host ""

# ============================================================
# Exit code
# ============================================================

if ($script:HealthIssues -gt 0) {
    exit 1
}

exit 0