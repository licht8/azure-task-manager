# ============================================================
# Azure Task Manager - Azure Deployment V2
#
# Architecture:
#
#   Frontend (TanStack Start / Nitro)
#       |
#       v
#   Backend (FastAPI)
#       |
#       v
#   PostgreSQL Flexible Server
#
# Existing resources are reused when possible.
#
# Important:
#
# Container Apps are initially created using a public Microsoft
# image. Managed Identity + AcrPull are configured first.
# Only after ACR permissions are ready is the real private ACR
# image assigned.
#
# Usage:
#
#   .\setup-azure-v2.ps1
#
# Or:
#
#   .\setup-azure-v2.ps1 -SkipDockerBuild
#
# ============================================================

param(
    [string]$Config = ".\config.json",

    [switch]$SkipDockerBuild
)

$ErrorActionPreference = "Stop"

# ============================================================
# Internal configuration
# ============================================================

# Backend and frontend application ports.
# These are application-level technical constants and are not
# intended to be changed through the deployment configuration.

$BACKEND_PORT = 8000
$FRONTEND_PORT = 3000


# Public bootstrap image.
#
# Container Apps are initially created with a public image.
# Managed Identity and AcrPull permissions are configured before
# the private ACR images are assigned.

$BOOTSTRAP_IMAGE = "mcr.microsoft.com/k8se/quickstart:latest"


# ============================================================
# Deployment configuration
# ============================================================

if (-not (Test-Path $Config)) {
    throw "Configuration file not found: $Config"
}

Write-Host ""
Write-Host "Loading configuration:" -ForegroundColor Cyan
Write-Host "  $Config"

try {

    $configData = Get-Content `
        -Path $Config `
        -Raw |
        ConvertFrom-Json

}
catch {

    throw "Could not read configuration file: $Config"
}


# Azure location

$LOCATION = $configData.location


# Resource Group

$RESOURCE_GROUP = $configData.resourceGroup


# Azure Container Registry

$ACR_NAME = $configData.acrName


# Container Apps Environment

$ENVIRONMENT_NAME = $configData.environmentName


# Container Apps

$BACKEND_APP = $configData.backendApp
$FRONTEND_APP = $configData.frontendApp


# Docker images

$BACKEND_IMAGE = $configData.backendImage
$FRONTEND_IMAGE = $configData.frontendImage


# PostgreSQL

$POSTGRES_SERVER = $configData.postgresServer
$POSTGRES_DATABASE = $configData.postgresDatabase
$POSTGRES_ADMIN = $configData.postgresAdmin


# ============================================================
# Configuration validation
# ============================================================

$requiredConfiguration = @(
    "LOCATION",
    "RESOURCE_GROUP",
    "ACR_NAME",
    "ENVIRONMENT_NAME",
    "BACKEND_APP",
    "FRONTEND_APP",
    "BACKEND_IMAGE",
    "FRONTEND_IMAGE",
    "POSTGRES_SERVER",
    "POSTGRES_DATABASE",
    "POSTGRES_ADMIN"
)

foreach ($variableName in $requiredConfiguration) {

    $value = Get-Variable `
        -Name $variableName `
        -ValueOnly

    if ([string]::IsNullOrWhiteSpace($value)) {

        throw "Missing required configuration value: $variableName"
    }
}


# ============================================================
# Loaded configuration
# ============================================================

Write-Host ""
Write-Host "Deployment configuration:" -ForegroundColor Cyan

Write-Host ""
Write-Host "  Location:             $LOCATION"
Write-Host "  Resource Group:       $RESOURCE_GROUP"
Write-Host "  ACR:                  $ACR_NAME"
Write-Host "  Environment:          $ENVIRONMENT_NAME"

Write-Host ""
Write-Host "  Backend App:          $BACKEND_APP"
Write-Host "  Frontend App:         $FRONTEND_APP"

Write-Host ""
Write-Host "  Backend Image:        $BACKEND_IMAGE"
Write-Host "  Frontend Image:       $FRONTEND_IMAGE"

Write-Host ""
Write-Host "  PostgreSQL Server:    $POSTGRES_SERVER"
Write-Host "  PostgreSQL Database:  $POSTGRES_DATABASE"
Write-Host "  PostgreSQL Admin:     $POSTGRES_ADMIN"

Write-Host ""

# ============================================================
# Helpers
# ============================================================

function Write-Step {
    param(
        [string]$Message
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host ""
}

function Invoke-Az {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & az @Arguments

    if ($LASTEXITCODE -ne 0) {

        $safe = $Arguments -join " "

        $safe = $safe -replace `
            "--admin-password\s+\S+", `
            "--admin-password ***"

        $safe = $safe -replace `
            "database-url=\S+", `
            "database-url=***"

        $safe = $safe -replace `
            "jwt-secret-key=\S+", `
            "jwt-secret-key=***"

        throw "Azure CLI command failed: az $safe"
    }
}

function Test-CommandExists {
    param(
        [string]$Command
    )

    return $null -ne (
        Get-Command $Command -ErrorAction SilentlyContinue
    )
}

function Read-Secret {
    param(
        [string]$Prompt
    )

    while ($true) {

        $secure = Read-Host $Prompt -AsSecureString

        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            $secure
        )

        try {

            $value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
                $ptr
            )

        }
        finally {

            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }

        if ([string]::IsNullOrWhiteSpace($value)) {

            Write-Host "Value cannot be empty." `
                -ForegroundColor Yellow

            continue
        }

        return $value
    }
}

function Test-AzureResource {
    param(
        [string[]]$Arguments
    )

    $old = $ErrorActionPreference

    $ErrorActionPreference = "SilentlyContinue"

    try {

        & az @Arguments *> $null

        return $LASTEXITCODE -eq 0

    }
    finally {

        $ErrorActionPreference = $old
    }
}

function Get-ContainerAppProvisioningState {
    param(
        [string]$Name
    )

    return az containerapp show `
        --name $Name `
        --resource-group $RESOURCE_GROUP `
        --query properties.provisioningState `
        --output tsv `
        2>$null
}

function Get-ContainerAppPrincipalId {
    param(
        [string]$Name
    )

    return az containerapp show `
        --name $Name `
        --resource-group $RESOURCE_GROUP `
        --query identity.principalId `
        --output tsv `
        2>$null
}

# ============================================================
# Prerequisites
# ============================================================

Write-Step "Checking prerequisites"

if (-not (Test-CommandExists "az")) {
    throw "Azure CLI is not installed."
}

if (-not (Test-CommandExists "docker")) {
    throw "Docker is not installed or not available in PATH."
}

Write-Host "Azure CLI: OK" -ForegroundColor Green
Write-Host "Docker:    OK" -ForegroundColor Green

docker info *> $null

if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop is not running."
}

Write-Host "Docker daemon: OK" -ForegroundColor Green

# ============================================================
# Azure login
# ============================================================

Write-Step "Checking Azure login"

$account = az account show 2>$null |
    ConvertFrom-Json

if (-not $account) {

    Write-Host "Azure login required." -ForegroundColor Yellow

    Invoke-Az @(
        "login"
    )

    $account = az account show |
        ConvertFrom-Json
}

if (-not $account) {
    throw "Could not retrieve Azure account."
}

Write-Host "Logged in as:" -ForegroundColor Green
Write-Host "  $($account.user.name)"

$subscriptionId = $account.id
$subscriptionName = $account.name

Write-Host "Subscription:" -ForegroundColor Green
Write-Host "  $subscriptionName"

Write-Host "  $subscriptionId"

# ============================================================
# Resource providers
# ============================================================

Write-Step "Checking Azure resource providers"

$providers = @(
    "Microsoft.ContainerRegistry",
    "Microsoft.App",
    "Microsoft.DBforPostgreSQL"
)

foreach ($provider in $providers) {

    $state = az provider show `
        --namespace $provider `
        --query registrationState `
        --output tsv

    if ($state -ne "Registered") {

        Write-Host "$provider is not registered." `
            -ForegroundColor Yellow

        $answer = Read-Host "Register it now? (y/n)"

        if ($answer -notmatch "^(y|yes)$") {

            throw "Required provider $provider is not registered."
        }

        Invoke-Az @(
            "provider",
            "register",
            "--namespace",
            $provider
        )

        Write-Host "Waiting for provider registration..." `
            -ForegroundColor Yellow

        do {

            Start-Sleep -Seconds 5

            $state = az provider show `
                --namespace $provider `
                --query registrationState `
                --output tsv

            Write-Host "  $state"

        }
        while ($state -ne "Registered")
    }

    Write-Host "$provider : Registered" `
        -ForegroundColor Green
}

# ============================================================
# Resource Group
# ============================================================

Write-Step "Resource Group"

$rgExists = az group exists `
    --name $RESOURCE_GROUP

if ($rgExists -eq "true") {

    Write-Host "Using existing Resource Group:" `
        -ForegroundColor Green

    Write-Host "  $RESOURCE_GROUP"

}
else {

    Write-Host "Creating Resource Group..." `
        -ForegroundColor Yellow

    Invoke-Az @(
        "group",
        "create",
        "--name",
        $RESOURCE_GROUP,
        "--location",
        $LOCATION
    )

    Write-Host "Resource Group created." `
        -ForegroundColor Green
}

# ============================================================
# ACR
# ============================================================

Write-Step "Azure Container Registry"

$acrExists = Test-AzureResource @(
    "acr",
    "show",
    "--name",
    $ACR_NAME,
    "--resource-group",
    $RESOURCE_GROUP
)

if ($acrExists) {

    Write-Host "Using existing ACR:" `
        -ForegroundColor Green

    Write-Host "  $ACR_NAME"

}
else {

    Write-Host "Creating ACR..." `
        -ForegroundColor Yellow

    Invoke-Az @(
        "acr",
        "create",
        "--resource-group",
        $RESOURCE_GROUP,
        "--name",
        $ACR_NAME,
        "--location",
        $LOCATION,
        "--sku",
        "Basic",
        "--admin-enabled",
        "false"
    )

    Write-Host "ACR created." `
        -ForegroundColor Green
}

$acrLoginServer = az acr show `
    --name $ACR_NAME `
    --resource-group $RESOURCE_GROUP `
    --query loginServer `
    --output tsv

$acrId = az acr show `
    --name $ACR_NAME `
    --resource-group $RESOURCE_GROUP `
    --query id `
    --output tsv

if ([string]::IsNullOrWhiteSpace($acrId)) {
    throw "Could not determine ACR resource ID."
}

Write-Host "ACR:" -ForegroundColor Green
Write-Host "  $acrLoginServer"

# ============================================================
# Container Apps Environment
# ============================================================

Write-Step "Container Apps Environment"

$environmentExists = Test-AzureResource @(
    "containerapp",
    "env",
    "show",
    "--name",
    $ENVIRONMENT_NAME,
    "--resource-group",
    $RESOURCE_GROUP
)

if ($environmentExists) {

    Write-Host "Using existing Container Apps Environment:" `
        -ForegroundColor Green

    Write-Host "  $ENVIRONMENT_NAME"

}
else {

    Write-Host "Creating Container Apps Environment..." `
        -ForegroundColor Yellow

    Invoke-Az @(
        "containerapp",
        "env",
        "create",
        "--name",
        $ENVIRONMENT_NAME,
        "--resource-group",
        $RESOURCE_GROUP,
        "--location",
        $LOCATION
    )

    Write-Host "Environment created." `
        -ForegroundColor Green
}

$environmentId = az containerapp env show `
    --name $ENVIRONMENT_NAME `
    --resource-group $RESOURCE_GROUP `
    --query id `
    --output tsv

if ([string]::IsNullOrWhiteSpace($environmentId)) {
    throw "Could not determine Container Apps Environment ID."
}

# ============================================================
# PostgreSQL credentials
# ============================================================

Write-Step "PostgreSQL configuration"

$postgresPassword = Read-Secret `
    "PostgreSQL password for $POSTGRES_ADMIN"

$jwtSecret = Read-Secret `
    "JWT_SECRET_KEY"

# ============================================================
# PostgreSQL Flexible Server
# ============================================================

Write-Step "PostgreSQL Flexible Server"

$postgresExists = Test-AzureResource @(
    "postgres",
    "flexible-server",
    "show",
    "--name",
    $POSTGRES_SERVER,
    "--resource-group",
    $RESOURCE_GROUP
)

if ($postgresExists) {

    Write-Host "Using existing PostgreSQL server:" `
        -ForegroundColor Green

    Write-Host "  $POSTGRES_SERVER"

}
else {

    Write-Host "Creating PostgreSQL Flexible Server..." `
        -ForegroundColor Yellow

    Invoke-Az @(
        "postgres",
        "flexible-server",
        "create",
        "--resource-group",
        $RESOURCE_GROUP,
        "--name",
        $POSTGRES_SERVER,
        "--location",
        $LOCATION,
        "--admin-user",
        $POSTGRES_ADMIN,
        "--admin-password",
        $postgresPassword,
        "--sku-name",
        "Standard_B1ms",
        "--tier",
        "Burstable",
        "--storage-size",
        "32",
        "--version",
        "16",
        "--public-access",
        "0.0.0.0"
    )

    Write-Host "PostgreSQL server created." `
        -ForegroundColor Green
}

# ============================================================
# PostgreSQL database
# ============================================================

Write-Step "PostgreSQL database"

$dbExists = Test-AzureResource @(
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

if ($dbExists) {

    Write-Host "Using existing database:" `
        -ForegroundColor Green

    Write-Host "  $POSTGRES_DATABASE"

}
else {

    Write-Host "Creating database..." `
        -ForegroundColor Yellow

    Invoke-Az @(
        "postgres",
        "flexible-server",
        "db",
        "create",
        "--resource-group",
        $RESOURCE_GROUP,
        "--server-name",
        $POSTGRES_SERVER,
        "--name",
        $POSTGRES_DATABASE
    )

    Write-Host "Database created." `
        -ForegroundColor Green
}

$postgresFqdn = az postgres flexible-server show `
    --resource-group $RESOURCE_GROUP `
    --name $POSTGRES_SERVER `
    --query fullyQualifiedDomainName `
    --output tsv

if ([string]::IsNullOrWhiteSpace($postgresFqdn)) {
    throw "Could not determine PostgreSQL FQDN."
}

Write-Host "PostgreSQL FQDN:" `
    -ForegroundColor Green

Write-Host "  $postgresFqdn"

# ============================================================
# DATABASE_URL
# ============================================================

$encodedPassword = [System.Uri]::EscapeDataString(
    $postgresPassword
)

$databaseUrl =
    "postgresql://${POSTGRES_ADMIN}:${encodedPassword}@${postgresFqdn}:5432/${POSTGRES_DATABASE}?sslmode=require"

# ============================================================
# Git commit tag
# ============================================================

Write-Step "Generating image tag"

$backendTag = (
    git rev-parse --short HEAD 2>$null
)

if ([string]::IsNullOrWhiteSpace($backendTag)) {

    $backendTag = Get-Date -Format "yyyyMMddHHmmss"
}

$frontendTag = $backendTag

Write-Host "Image tag:" -ForegroundColor Green
Write-Host "  $backendTag"

# ============================================================
# Backend image
# ============================================================

Write-Step "Backend Docker image"

$backendImageFull =
    "$acrLoginServer/$BACKEND_IMAGE`:$backendTag"

Write-Host "Backend image:" `
    -ForegroundColor Green

Write-Host "  $backendImageFull"

if (-not $SkipDockerBuild) {

    Write-Host "Building backend..." `
        -ForegroundColor Yellow

    docker build `
        -t $backendImageFull `
        .

    if ($LASTEXITCODE -ne 0) {
        throw "Backend Docker build failed."
    }

    Write-Host "Backend image built." `
        -ForegroundColor Green

    Write-Host "Logging into ACR..." `
        -ForegroundColor Yellow

    Invoke-Az @(
        "acr",
        "login",
        "--name",
        $ACR_NAME
    )

    Write-Host "Pushing backend image..." `
        -ForegroundColor Yellow

    docker push $backendImageFull

    if ($LASTEXITCODE -ne 0) {
        throw "Backend image push failed."
    }

    Write-Host "Backend image pushed." `
        -ForegroundColor Green
}

# ============================================================
# Backend Container App
#
# IMPORTANT:
#
# If an existing app is ProvisioningState=Failed, it cannot
# reliably be used for registry configuration.
#
# We delete the failed app and recreate it with the public
# bootstrap image.
# ============================================================

Write-Step "Backend Container App"

$backendExists = Test-AzureResource @(
    "containerapp",
    "show",
    "--name",
    $BACKEND_APP,
    "--resource-group",
    $RESOURCE_GROUP
)

if ($backendExists) {

    $backendProvisioningState =
        Get-ContainerAppProvisioningState $BACKEND_APP

    Write-Host "Existing backend provisioning state:" `
        -ForegroundColor Yellow

    Write-Host "  $backendProvisioningState"

    if ($backendProvisioningState -eq "Failed") {

        Write-Host ""
        Write-Host "Backend Container App is in Failed provisioning state." `
            -ForegroundColor Red

        Write-Host "Deleting failed backend Container App..." `
            -ForegroundColor Yellow

        Invoke-Az @(
            "containerapp",
            "delete",
            "--name",
            $BACKEND_APP,
            "--resource-group",
            $RESOURCE_GROUP,
            "--yes"
        )

        Write-Host "Failed backend Container App deleted." `
            -ForegroundColor Green

        $backendExists = $false
    }
}

if (-not $backendExists) {

    Write-Host "Creating backend Container App with bootstrap image..." `
        -ForegroundColor Yellow

    Invoke-Az @(
        "containerapp",
        "create",
        "--name",
        $BACKEND_APP,
        "--resource-group",
        $RESOURCE_GROUP,
        "--environment",
        $environmentId,
        "--image",
        $BOOTSTRAP_IMAGE,
        "--target-port",
        "$BACKEND_PORT",
        "--ingress",
        "external",
        "--transport",
        "auto",
        "--cpu",
        "0.5",
        "--memory",
        "1Gi",
        "--min-replicas",
        "1",
        "--max-replicas",
        "5",
        "--workload-profile-name",
        "Consumption",
        "--system-assigned"
    )

    Write-Host "Backend Container App created." `
        -ForegroundColor Green
}

# ============================================================
# Wait for backend provisioning
# ============================================================

Write-Step "Waiting for backend provisioning"

$backendReady = $false

for ($i = 1; $i -le 24; $i++) {

    $state = Get-ContainerAppProvisioningState $BACKEND_APP

    Write-Host "Attempt $i/24 : $state"

    if ($state -eq "Succeeded") {

        $backendReady = $true
        break
    }

    if ($state -eq "Failed") {
        throw "Backend Container App provisioning failed."
    }

    Start-Sleep -Seconds 5
}

if (-not $backendReady) {
    throw "Backend Container App did not reach Succeeded provisioning state."
}

# ============================================================
# Backend managed identity
# ============================================================

Write-Step "Backend managed identity"

$backendPrincipalId =
    Get-ContainerAppPrincipalId $BACKEND_APP

if ([string]::IsNullOrWhiteSpace($backendPrincipalId)) {

    Write-Host "Assigning system managed identity..." `
        -ForegroundColor Yellow

    Invoke-Az @(
        "containerapp",
        "identity",
        "assign",
        "--name",
        $BACKEND_APP,
        "--resource-group",
        $RESOURCE_GROUP,
        "--system-assigned"
    )

    Start-Sleep -Seconds 5

    $backendPrincipalId =
        Get-ContainerAppPrincipalId $BACKEND_APP
}

if ([string]::IsNullOrWhiteSpace($backendPrincipalId)) {
    throw "Could not obtain backend managed identity."
}

Write-Host "Backend Principal ID:" `
    -ForegroundColor Green

Write-Host "  $backendPrincipalId"

# ============================================================
# Backend AcrPull
# ============================================================

Write-Step "Backend ACR permissions"

Write-Host "Checking AcrPull permission..." `
    -ForegroundColor Yellow

$backendRole = az role assignment list `
    --assignee-object-id $backendPrincipalId `
    --scope $acrId `
    --query "[?roleDefinitionName=='AcrPull'].id" `
    --output tsv `
    2>$null

if ([string]::IsNullOrWhiteSpace($backendRole)) {

    Write-Host "AcrPull not found. Granting permission..." `
        -ForegroundColor Yellow

    Invoke-Az @(
        "role",
        "assignment",
        "create",
        "--assignee-object-id",
        $backendPrincipalId,
        "--assignee-principal-type",
        "ServicePrincipal",
        "--role",
        "AcrPull",
        "--scope",
        $acrId
    )

    Write-Host "AcrPull granted to backend." `
        -ForegroundColor Green
}
else {

    Write-Host "Backend already has AcrPull." `
        -ForegroundColor Green
}

Write-Host "Waiting for RBAC propagation..." `
    -ForegroundColor DarkGray

Start-Sleep -Seconds 20

# ============================================================
# Backend registry configuration
# ============================================================

Write-Step "Configuring backend ACR"

Invoke-Az @(
    "containerapp",
    "registry",
    "set",
    "--name",
    $BACKEND_APP,
    "--resource-group",
    $RESOURCE_GROUP,
    "--server",
    $acrLoginServer,
    "--identity",
    "system"
)

Write-Host "Backend ACR configured." `
    -ForegroundColor Green

# ============================================================
# Backend real image
# ============================================================

Write-Step "Deploying backend image"

Invoke-Az @(
    "containerapp",
    "update",
    "--name",
    $BACKEND_APP,
    "--resource-group",
    $RESOURCE_GROUP,
    "--image",
    $backendImageFull
)

Write-Host "Backend image deployed." `
    -ForegroundColor Green

# ============================================================
# Backend secrets
# ============================================================

Write-Step "Backend secrets"

Invoke-Az @(
    "containerapp",
    "secret",
    "set",
    "--name",
    $BACKEND_APP,
    "--resource-group",
    $RESOURCE_GROUP,
    "--secrets",
    "database-url=$databaseUrl",
    "jwt-secret-key=$jwtSecret"
)

Write-Host "Backend secrets configured." `
    -ForegroundColor Green

# ============================================================
# Backend environment variables
# ============================================================

Write-Step "Backend environment variables"

Invoke-Az @(
    "containerapp",
    "update",
    "--name",
    $BACKEND_APP,
    "--resource-group",
    $RESOURCE_GROUP,
    "--set-env-vars",
    "DATABASE_URL=secretref:database-url",
    "JWT_SECRET_KEY=secretref:jwt-secret-key"
)

# ============================================================
# Backend URL
# ============================================================

Write-Step "Getting backend URL"

$backendFqdn = az containerapp show `
    --name $BACKEND_APP `
    --resource-group $RESOURCE_GROUP `
    --query properties.configuration.ingress.fqdn `
    --output tsv

if ([string]::IsNullOrWhiteSpace($backendFqdn)) {
    throw "Could not determine backend Container App FQDN."
}

$backendUrl = "https://$backendFqdn"

Write-Host "Backend URL:" `
    -ForegroundColor Green

Write-Host "  $backendUrl"

# ============================================================
# Frontend image
# ============================================================

Write-Step "Frontend Docker image"

$frontendImageFull =
    "$acrLoginServer/$FRONTEND_IMAGE`:$frontendTag"

Write-Host "Frontend image:" `
    -ForegroundColor Green

Write-Host "  $frontendImageFull"

if (-not $SkipDockerBuild) {

    Write-Host "Building frontend..." `
        -ForegroundColor Yellow

    docker build `
        --build-arg "VITE_API_URL=$backendUrl" `
        -t $frontendImageFull `
        ./frontend

    if ($LASTEXITCODE -ne 0) {
        throw "Frontend Docker build failed."
    }

    Write-Host "Frontend image built." `
        -ForegroundColor Green

    Write-Host "Pushing frontend image..." `
        -ForegroundColor Yellow

    docker push $frontendImageFull

    if ($LASTEXITCODE -ne 0) {
        throw "Frontend image push failed."
    }

    Write-Host "Frontend image pushed." `
        -ForegroundColor Green
}

# ============================================================
# Frontend Container App
# ============================================================

Write-Step "Frontend Container App"

$frontendExists = Test-AzureResource @(
    "containerapp",
    "show",
    "--name",
    $FRONTEND_APP,
    "--resource-group",
    $RESOURCE_GROUP
)

if ($frontendExists) {

    $frontendProvisioningState =
        Get-ContainerAppProvisioningState $FRONTEND_APP

    Write-Host "Existing frontend provisioning state:" `
        -ForegroundColor Yellow

    Write-Host "  $frontendProvisioningState"

    if ($frontendProvisioningState -eq "Failed") {

        Write-Host ""
        Write-Host "Frontend Container App is in Failed provisioning state." `
            -ForegroundColor Red

        Write-Host "Deleting failed frontend Container App..." `
            -ForegroundColor Yellow

        Invoke-Az @(
            "containerapp",
            "delete",
            "--name",
            $FRONTEND_APP,
            "--resource-group",
            $RESOURCE_GROUP,
            "--yes"
        )

        Write-Host "Failed frontend Container App deleted." `
            -ForegroundColor Green

        $frontendExists = $false
    }
}

if (-not $frontendExists) {

    Write-Host "Creating frontend Container App with bootstrap image..." `
        -ForegroundColor Yellow

    Invoke-Az @(
        "containerapp",
        "create",
        "--name",
        $FRONTEND_APP,
        "--resource-group",
        $RESOURCE_GROUP,
        "--environment",
        $environmentId,
        "--image",
        $BOOTSTRAP_IMAGE,
        "--target-port",
        "$FRONTEND_PORT",
        "--ingress",
        "external",
        "--transport",
        "auto",
        "--cpu",
        "0.5",
        "--memory",
        "1Gi",
        "--min-replicas",
        "1",
        "--max-replicas",
        "5",
        "--workload-profile-name",
        "Consumption",
        "--system-assigned"
    )

    Write-Host "Frontend Container App created." `
        -ForegroundColor Green
}

# ============================================================
# Wait for frontend provisioning
# ============================================================

Write-Step "Waiting for frontend provisioning"

$frontendReady = $false

for ($i = 1; $i -le 24; $i++) {

    $state = Get-ContainerAppProvisioningState $FRONTEND_APP

    Write-Host "Attempt $i/24 : $state"

    if ($state -eq "Succeeded") {

        $frontendReady = $true
        break
    }

    if ($state -eq "Failed") {
        throw "Frontend Container App provisioning failed."
    }

    Start-Sleep -Seconds 5
}

if (-not $frontendReady) {
    throw "Frontend Container App did not reach Succeeded provisioning state."
}

# ============================================================
# Frontend managed identity
# ============================================================

Write-Step "Frontend managed identity"

$frontendPrincipalId =
    Get-ContainerAppPrincipalId $FRONTEND_APP

if ([string]::IsNullOrWhiteSpace($frontendPrincipalId)) {

    Write-Host "Assigning system managed identity..." `
        -ForegroundColor Yellow

    Invoke-Az @(
        "containerapp",
        "identity",
        "assign",
        "--name",
        $FRONTEND_APP,
        "--resource-group",
        $RESOURCE_GROUP,
        "--system-assigned"
    )

    Start-Sleep -Seconds 5

    $frontendPrincipalId =
        Get-ContainerAppPrincipalId $FRONTEND_APP
}

if ([string]::IsNullOrWhiteSpace($frontendPrincipalId)) {
    throw "Could not obtain frontend managed identity."
}

Write-Host "Frontend Principal ID:" `
    -ForegroundColor Green

Write-Host "  $frontendPrincipalId"

# ============================================================
# Frontend AcrPull
# ============================================================

Write-Step "Frontend ACR permissions"

Write-Host "Checking AcrPull permission..." `
    -ForegroundColor Yellow

$frontendRole = az role assignment list `
    --assignee-object-id $frontendPrincipalId `
    --scope $acrId `
    --query "[?roleDefinitionName=='AcrPull'].id" `
    --output tsv `
    2>$null

if ([string]::IsNullOrWhiteSpace($frontendRole)) {

    Write-Host "AcrPull not found. Granting permission..." `
        -ForegroundColor Yellow

    Invoke-Az @(
        "role",
        "assignment",
        "create",
        "--assignee-object-id",
        $frontendPrincipalId,
        "--assignee-principal-type",
        "ServicePrincipal",
        "--role",
        "AcrPull",
        "--scope",
        $acrId
    )

    Write-Host "AcrPull granted to frontend." `
        -ForegroundColor Green
}
else {

    Write-Host "Frontend already has AcrPull." `
        -ForegroundColor Green
}

Write-Host "Waiting for RBAC propagation..." `
    -ForegroundColor DarkGray

Start-Sleep -Seconds 20

# ============================================================
# Frontend registry configuration
# ============================================================

Write-Step "Configuring frontend ACR"

Invoke-Az @(
    "containerapp",
    "registry",
    "set",
    "--name",
    $FRONTEND_APP,
    "--resource-group",
    $RESOURCE_GROUP,
    "--server",
    $acrLoginServer,
    "--identity",
    "system"
)

Write-Host "Frontend ACR configured." `
    -ForegroundColor Green

# ============================================================
# Frontend real image
# ============================================================

Write-Step "Deploying frontend image"

Invoke-Az @(
    "containerapp",
    "update",
    "--name",
    $FRONTEND_APP,
    "--resource-group",
    $RESOURCE_GROUP,
    "--image",
    $frontendImageFull
)

Write-Host "Frontend image deployed." `
    -ForegroundColor Green

# ============================================================
# Frontend URL
# ============================================================

Write-Step "Getting frontend URL"

$frontendFqdn = az containerapp show `
    --name $FRONTEND_APP `
    --resource-group $RESOURCE_GROUP `
    --query properties.configuration.ingress.fqdn `
    --output tsv

if ([string]::IsNullOrWhiteSpace($frontendFqdn)) {
    throw "Could not determine frontend Container App FQDN."
}

$frontendUrl = "https://$frontendFqdn"

Write-Host "Frontend URL:" `
    -ForegroundColor Green

Write-Host "  $frontendUrl"

# ============================================================
# Backend CORS
# ============================================================

Write-Step "Configuring backend CORS origin"

Invoke-Az @(
    "containerapp",
    "update",
    "--name",
    $BACKEND_APP,
    "--resource-group",
    $RESOURCE_GROUP,
    "--set-env-vars",
    "DATABASE_URL=secretref:database-url",
    "JWT_SECRET_KEY=secretref:jwt-secret-key",
    "FRONTEND_URL=$frontendUrl"
)

Write-Host "Backend CORS configured." `
    -ForegroundColor Green

# ============================================================
# Backend health probes
# ============================================================

Write-Step "Configuring backend health probes"

$backendProbeYaml = @"
properties:
  template:
    containers:
      - name: $BACKEND_APP
        probes:
          - type: Liveness
            httpGet:
              path: /health
              port: 8000
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 15

          - type: Readiness
            httpGet:
              path: /health
              port: 8000
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 15
"@

$backendProbeFile = Join-Path `
    $env:TEMP `
    "azure-task-manager-backend-probes-$([guid]::NewGuid()).yaml"

Set-Content `
    -Path $backendProbeFile `
    -Value $backendProbeYaml `
    -Encoding UTF8

try {

    Invoke-Az @(
        "containerapp",
        "update",
        "--name",
        $BACKEND_APP,
        "--resource-group",
        $RESOURCE_GROUP,
        "--yaml",
        $backendProbeFile
    )

}
finally {

    Remove-Item `
        $backendProbeFile `
        -Force `
        -ErrorAction SilentlyContinue
}

# ============================================================
# Frontend health probe
# ============================================================

Write-Step "Configuring frontend health probe"

$frontendProbeYaml = @"
properties:
  template:
    containers:
      - name: $FRONTEND_APP
        probes:
          - type: Liveness
            httpGet:
              path: /
              port: 3000
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 15

          - type: Readiness
            httpGet:
              path: /
              port: 3000
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 15
"@

$frontendProbeFile = Join-Path `
    $env:TEMP `
    "azure-task-manager-frontend-probes-$([guid]::NewGuid()).yaml"

Set-Content `
    -Path $frontendProbeFile `
    -Value $frontendProbeYaml `
    -Encoding UTF8

try {

    Invoke-Az @(
        "containerapp",
        "update",
        "--name",
        $FRONTEND_APP,
        "--resource-group",
        $RESOURCE_GROUP,
        "--yaml",
        $frontendProbeFile
    )

}
finally {

    Remove-Item `
        $frontendProbeFile `
        -Force `
        -ErrorAction SilentlyContinue
}

# ============================================================
# Final verification
# ============================================================

Write-Step "Final deployment verification"

Write-Host ""
Write-Host "BACKEND" -ForegroundColor Cyan

az containerapp show `
    --name $BACKEND_APP `
    --resource-group $RESOURCE_GROUP `
    --query "{name:name,provisioningState:properties.provisioningState,runningStatus:properties.runningStatus,fqdn:properties.configuration.ingress.fqdn}" `
    -o table

Write-Host ""
Write-Host "FRONTEND" -ForegroundColor Cyan

az containerapp show `
    --name $FRONTEND_APP `
    --resource-group $RESOURCE_GROUP `
    --query "{name:name,provisioningState:properties.provisioningState,runningStatus:properties.runningStatus,fqdn:properties.configuration.ingress.fqdn}" `
    -o table

Write-Host ""
Write-Host "POSTGRESQL" -ForegroundColor Cyan

az postgres flexible-server show `
    --name $POSTGRES_SERVER `
    --resource-group $RESOURCE_GROUP `
    --query "{name:name,state:state,version:version,fqdn:fullyQualifiedDomainName}" `
    -o table

# ============================================================
# Final URLs
# ============================================================

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Green

Write-Host " AZURE TASK MANAGER DEPLOYMENT COMPLETED" `
    -ForegroundColor Green

Write-Host "============================================================" `
    -ForegroundColor Green

Write-Host ""

Write-Host "Frontend:" -ForegroundColor Cyan
Write-Host "  $frontendUrl" -ForegroundColor White

Write-Host ""

Write-Host "Backend:" -ForegroundColor Cyan
Write-Host "  $backendUrl" -ForegroundColor White

Write-Host ""

Write-Host "Swagger:" -ForegroundColor Cyan
Write-Host "  $backendUrl/docs" -ForegroundColor White

Write-Host ""

Write-Host "Health:" -ForegroundColor Cyan
Write-Host "  $backendUrl/health" -ForegroundColor White

Write-Host ""

Write-Host "ACR:" -ForegroundColor Cyan
Write-Host "  $acrLoginServer" -ForegroundColor White

Write-Host ""

Write-Host "Resource Group:" -ForegroundColor Cyan
Write-Host "  $RESOURCE_GROUP" -ForegroundColor White

Write-Host ""