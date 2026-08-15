# ============================================================
# Docker Azure Demo - One-Click Azure Installer
#
# This script:
#   1. Logs user into Azure
#   2. Asks for Azure/resource parameters
#   3. Creates Resource Group
#   4. Creates Azure Container Registry
#   5. Builds Docker image locally
#   6. Pushes image to user's ACR
#   7. Creates PostgreSQL Flexible Server
#   8. Creates PostgreSQL database
#   9. Creates Container Apps Environment
#  10. Creates Container App with managed identity
#  11. Grants AcrPull permission
#  12. Configures DATABASE_URL as Container App secret
#  13. Starts the application
#
# GitHub Actions are NOT used by this script.
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Docker Azure Demo - Azure Installer" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

function Test-CommandExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Read-RequiredValue {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )

    while ($true) {
        $value = Read-Host $Prompt

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }

        Write-Host "Value cannot be empty." -ForegroundColor Yellow
    }
}

function Read-PasswordValue {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )

    while ($true) {
        $secure = Read-Host $Prompt -AsSecureString

        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)

        try {
            $value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }

        Write-Host "Password cannot be empty." -ForegroundColor Yellow
    }
}

function Write-Step {
    param (
        [string]$Message
    )

    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
}

function Invoke-Az {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & az @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Arguments -join ' ')"
    }
}

# ------------------------------------------------------------
# Check prerequisites
# ------------------------------------------------------------

Write-Step "Checking prerequisites"

if (-not (Test-CommandExists "az")) {
    Write-Host "Azure CLI is not installed." -ForegroundColor Red
    Write-Host "Install it from:" -ForegroundColor Yellow
    Write-Host "https://learn.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-CommandExists "docker")) {
    Write-Host "Docker is not installed or not available in PATH." -ForegroundColor Red
    Write-Host "Install Docker Desktop and run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "Azure CLI: OK" -ForegroundColor Green
Write-Host "Docker:    OK" -ForegroundColor Green

# ------------------------------------------------------------
# Check Docker daemon
# ------------------------------------------------------------

Write-Step "Checking Docker"

docker info *> $null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Desktop is not running." -ForegroundColor Red
    Write-Host "Start Docker Desktop and run the script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "Docker daemon is running." -ForegroundColor Green

# ------------------------------------------------------------
# Azure login
# ------------------------------------------------------------

Write-Step "Azure login"

$accountJson = az account show 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accountJson)) {
    Write-Host "You are not logged into Azure." -ForegroundColor Yellow
    Write-Host "Opening Azure login..." -ForegroundColor Yellow

    Invoke-Az @("login")
}

$account = az account show | ConvertFrom-Json

Write-Host ""
Write-Host "Logged in as:" -ForegroundColor Green
Write-Host "  $($account.user.name)" -ForegroundColor White
Write-Host ""

# ------------------------------------------------------------
# Subscription selection
# ------------------------------------------------------------

Write-Step "Azure subscription"

$subscriptions = az account list --query "[?state=='Enabled'].{Name:name,Id:id,IsDefault:isDefault}" | ConvertFrom-Json

if (-not $subscriptions) {
    throw "No enabled Azure subscriptions were found."
}

Write-Host "Available subscriptions:" -ForegroundColor Yellow
Write-Host ""

for ($i = 0; $i -lt $subscriptions.Count; $i++) {
    $marker = ""

    if ($subscriptions[$i].IsDefault -eq $true) {
        $marker = " [DEFAULT]"
    }

    Write-Host "[$i] $($subscriptions[$i].Name) - $($subscriptions[$i].Id)$marker"
}

Write-Host ""

$subscriptionIndex = Read-Host "Enter subscription number"

if ($subscriptionIndex -notmatch '^\d+$') {
    throw "Invalid subscription number."
}

$subscriptionIndex = [int]$subscriptionIndex

if ($subscriptionIndex -lt 0 -or $subscriptionIndex -ge $subscriptions.Count) {
    throw "Invalid subscription number."
}

$subscriptionId = $subscriptions[$subscriptionIndex].Id
$subscriptionName = $subscriptions[$subscriptionIndex].Name

Invoke-Az @(
    "account",
    "set",
    "--subscription",
    $subscriptionId
)

Write-Host "Selected subscription: $subscriptionName" -ForegroundColor Green

# ------------------------------------------------------------
# Ask for configuration
# ------------------------------------------------------------

Write-Step "Azure configuration"

Write-Host "Enter names for the Azure resources." -ForegroundColor Yellow
Write-Host "Names must be unique where Azure requires global uniqueness." -ForegroundColor DarkGray
Write-Host ""

$resourceGroup = Read-RequiredValue "Resource Group name"

$location = Read-RequiredValue "Azure region (example: westeurope, polandcentral)"

$acrName = Read-RequiredValue "ACR name (globally unique, lowercase, e.g. johnazure123)"

$containerAppName = Read-RequiredValue "Container App name"

$postgresServerName = Read-RequiredValue "PostgreSQL server name (globally unique, lowercase)"

$postgresAdmin = Read-RequiredValue "PostgreSQL admin username"

$postgresPassword = Read-PasswordValue "PostgreSQL admin password"

$databaseName = "tasks"

$environmentName = "$($containerAppName)-env"

$imageTag = "v1"

$imageName = $containerAppName

$acrLoginServer = "$acrName.azurecr.io"

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group : $resourceGroup"
Write-Host "  Location       : $location"
Write-Host "  ACR            : $acrName"
Write-Host "  Container App  : $containerAppName"
Write-Host "  Environment    : $environmentName"
Write-Host "  PostgreSQL     : $postgresServerName"
Write-Host "  Database       : $databaseName"
Write-Host "  Image          : $acrLoginServer/$imageName`:$imageTag"
Write-Host ""

$confirmation = Read-Host "Continue? (y/n)"

if ($confirmation -notmatch "^(y|yes)$") {
    Write-Host "Installation cancelled." -ForegroundColor Yellow
    exit 0
}

# ------------------------------------------------------------
# Resource Group
# ------------------------------------------------------------

Write-Step "Creating Resource Group"

$rgExists = az group exists --name $resourceGroup

if ($rgExists -eq "true") {
    Write-Host "Resource Group already exists: $resourceGroup" -ForegroundColor Yellow
}
else {
    Invoke-Az @(
        "group",
        "create",
        "--name",
        $resourceGroup,
        "--location",
        $location
    )

    Write-Host "Resource Group created." -ForegroundColor Green
}

# ------------------------------------------------------------
# Azure Container Registry
# ------------------------------------------------------------

Write-Step "Creating Azure Container Registry"

$acrListJson = az acr list `
    --resource-group $resourceGroup `
    --query "[].name" `
    --output json `
    2>$null

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve Azure Container Registry list."
}

$acrList = $acrListJson | ConvertFrom-Json

$acrExists = $false

if ($acrList) {
    $acrExists = $acrList -contains $acrName
}

if ($acrExists) {

    Write-Host "ACR already exists: $acrName" -ForegroundColor Yellow

}
else {

    Write-Host "ACR does not exist. Creating..." -ForegroundColor Cyan

    Invoke-Az @(
        "acr",
        "create",
        "--resource-group",
        $resourceGroup,
        "--name",
        $acrName,
        "--location",
        $location,
        "--sku",
        "Basic",
        "--admin-enabled",
        "false"
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Azure Container Registry."
    }

    Write-Host "ACR created." -ForegroundColor Green
}

# Get ACR login server
$acrLoginServer = az acr list `
    --resource-group $resourceGroup `
    --query "[?name=='$acrName'].loginServer | [0]" `
    --output tsv `
    2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($acrLoginServer)) {
    throw "Could not determine ACR login server."
}

Write-Host "ACR login server: $acrLoginServer" -ForegroundColor Green



# ------------------------------------------------------------
# Docker build
# ------------------------------------------------------------

Write-Step "Building Docker image"

$imageFullName = "$acrLoginServer/$imageName`:$imageTag"

Write-Host "Building:" -ForegroundColor Yellow
Write-Host "  $imageFullName"

docker build -t $imageFullName .

if ($LASTEXITCODE -ne 0) {
    throw "Docker image build failed."
}

Write-Host "Docker image built successfully." -ForegroundColor Green

# ------------------------------------------------------------
# Login to ACR
# ------------------------------------------------------------

Write-Step "Logging into Azure Container Registry"

Invoke-Az @(
    "acr",
    "login",
    "--name",
    $acrName
)

Write-Host "ACR login successful." -ForegroundColor Green

# ------------------------------------------------------------
# Push image
# ------------------------------------------------------------

Write-Step "Pushing Docker image to ACR"

docker push $imageFullName

if ($LASTEXITCODE -ne 0) {
    throw "Docker image push failed."
}

Write-Host "Image pushed successfully." -ForegroundColor Green


# ------------------------------------------------------------
# PostgreSQL Flexible Server
# ------------------------------------------------------------

Write-Step "Creating PostgreSQL Flexible Server"

$postgresListJson = az postgres flexible-server list `
    --resource-group $resourceGroup `
    --query "[].name" `
    --output json `
    2>$null

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve PostgreSQL Flexible Server list."
}

$postgresList = $postgresListJson | ConvertFrom-Json

$postgresExists = $false

if ($postgresList) {
    $postgresExists = $postgresList -contains $postgresServerName
}

if ($postgresExists) {

    Write-Host "PostgreSQL server already exists: $postgresServerName" -ForegroundColor Yellow

}
else {

    Write-Host "Creating PostgreSQL Flexible Server..." -ForegroundColor Yellow
    Write-Host "This can take several minutes." -ForegroundColor DarkGray

    Invoke-Az @(
        "postgres",
        "flexible-server",
        "create",
        "--resource-group",
        $resourceGroup,
        "--name",
        $postgresServerName,
        "--location",
        $location,
        "--admin-user",
        $postgresAdmin,
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
        "0.0.0.0",
        "--yes"
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create PostgreSQL Flexible Server."
    }

    Write-Host "PostgreSQL server created." -ForegroundColor Green
}


# ------------------------------------------------------------
# PostgreSQL database
# ------------------------------------------------------------

Write-Step "Creating PostgreSQL database"

$dbListJson = az postgres flexible-server db list `
    --resource-group $resourceGroup `
    --server-name $postgresServerName `
    --query "[].name" `
    --output json `
    2>$null

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve PostgreSQL database list."
}

$dbList = $dbListJson | ConvertFrom-Json

$dbExists = $false

if ($dbList) {
    $dbExists = $dbList -contains $databaseName
}

if ($dbExists) {

    Write-Host "Database already exists: $databaseName" -ForegroundColor Yellow

}
else {

    Write-Host "Creating database: $databaseName" -ForegroundColor Yellow

    Invoke-Az @(
        "postgres",
        "flexible-server",
        "db",
        "create",
        "--resource-group",
        $resourceGroup,
        "--server-name",
        $postgresServerName,
        "--name",
        $databaseName
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create PostgreSQL database."
    }

    Write-Host "Database created." -ForegroundColor Green
}

# ------------------------------------------------------------
# Get PostgreSQL FQDN
# ------------------------------------------------------------

$postgresFqdn = az postgres flexible-server show `
    --resource-group $resourceGroup `
    --name $postgresServerName `
    --query fullyQualifiedDomainName `
    --output tsv

if ([string]::IsNullOrWhiteSpace($postgresFqdn)) {
    throw "Could not determine PostgreSQL FQDN."
}

Write-Host "PostgreSQL FQDN: $postgresFqdn" -ForegroundColor Green

# ------------------------------------------------------------
# Create Container Apps Environment
# ------------------------------------------------------------

Write-Step "Creating Container Apps Environment"

$environmentJson = az containerapp env list `
    --output json `
    2>$null

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve Container Apps Environment list."
}

$environments = $environmentJson | ConvertFrom-Json

$existingEnvironment = $null

if ($environments) {

    foreach ($env in $environments) {

        $envLocation = $env.location.ToLower().Replace(" ", "")

        if ($envLocation -eq $location.ToLower().Replace(" ", "")) {
            $existingEnvironment = $env
            break
        }
    }
}

if ($existingEnvironment) {

    $environmentName = $existingEnvironment.name
    $environmentResourceGroup = $existingEnvironment.resourceGroup
    $environmentId = $existingEnvironment.id

    Write-Host "Using existing Container Apps Environment:" -ForegroundColor Yellow
    Write-Host "  $environmentName" -ForegroundColor Green
    Write-Host "  Location: $($existingEnvironment.location)" -ForegroundColor DarkGray
    Write-Host "  Resource Group: $environmentResourceGroup" -ForegroundColor DarkGray

}
else {

    Write-Host "No Container Apps Environment found in $location." -ForegroundColor Cyan
    Write-Host "Creating: $environmentName" -ForegroundColor Cyan

    Invoke-Az @(
        "containerapp",
        "env",
        "create",
        "--name",
        $environmentName,
        "--resource-group",
        $resourceGroup,
        "--location",
        $location
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Container Apps Environment."
    }

    $environmentResourceGroup = $resourceGroup

    $environmentId = az containerapp env show `
        --name $environmentName `
        --resource-group $environmentResourceGroup `
        --query id `
        --output tsv

    if ([string]::IsNullOrWhiteSpace($environmentId)) {
        throw "Could not determine Container Apps Environment resource ID."
    }

    Write-Host "Container Apps Environment created." -ForegroundColor Green
}


# ------------------------------------------------------------
# Create Container App
# ------------------------------------------------------------

Write-Step "Creating Container App"

$containerAppListJson = az containerapp list `
    --resource-group $resourceGroup `
    --query "[].name" `
    --output json `
    2>$null

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve Container Apps list."
}

$containerAppList = $containerAppListJson | ConvertFrom-Json

$containerAppExists = $false

if ($containerAppList) {
    $containerAppExists = $containerAppList -contains $containerAppName
}

if ($containerAppExists) {

    Write-Host "Container App already exists: $containerAppName" -ForegroundColor Yellow

}
else {

    Write-Host "Creating Container App with managed identity..." -ForegroundColor Yellow

	Invoke-Az @(
		"containerapp",
		"create",
		"--name",
		$containerAppName,
		"--resource-group",
		$resourceGroup,
		"--environment",
		$environmentId,
		"--image",
		"mcr.microsoft.com/k8se/quickstart:latest",
		"--target-port",
		"8000",
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
		"10",
		"--workload-profile-name",
		"Consumption",
		"--system-assigned"
	)

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Container App."
    }

    Write-Host "Container App created." -ForegroundColor Green
}



# ------------------------------------------------------------
# Get Container App managed identity
# ------------------------------------------------------------

Write-Step "Configuring Container App managed identity"

$principalId = az containerapp show `
    --name $containerAppName `
    --resource-group $resourceGroup `
    --query identity.principalId `
    --output tsv

if ([string]::IsNullOrWhiteSpace($principalId)) {
    throw "Could not retrieve Container App managed identity."
}

Write-Host "Managed Identity Principal ID: $principalId" -ForegroundColor Green

# ------------------------------------------------------------
# Grant AcrPull
# ------------------------------------------------------------

Write-Step "Granting AcrPull permission"

$acrId = az acr show `
    --name $acrName `
    --resource-group $resourceGroup `
    --query id `
    --output tsv

if ([string]::IsNullOrWhiteSpace($acrId)) {
    throw "Could not retrieve ACR resource ID."
}

$existingRole = az role assignment list `
    --assignee $principalId `
    --scope $acrId `
    --query "[?roleDefinitionName=='AcrPull'].id" `
    --output tsv

if ([string]::IsNullOrWhiteSpace($existingRole)) {

    Invoke-Az @(
        "role",
        "assignment",
        "create",
        "--assignee-object-id",
        $principalId,
        "--assignee-principal-type",
        "ServicePrincipal",
        "--role",
        "AcrPull",
        "--scope",
        $acrId
    )

    Write-Host "AcrPull permission granted." -ForegroundColor Green

    # Give RBAC a short moment to propagate.
    Write-Host "Waiting for Azure RBAC propagation..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 15
}
else {
    Write-Host "AcrPull permission already exists." -ForegroundColor Yellow
}

# ------------------------------------------------------------
# Configure registry authentication
# ------------------------------------------------------------

Write-Step "Configuring Container App registry"

Invoke-Az @(
    "containerapp",
    "registry",
    "set",
    "--name",
    $containerAppName,
    "--resource-group",
    $resourceGroup,
    "--server",
    $acrLoginServer,
    "--identity",
    "system"
)

Write-Host "Container App can now pull images using managed identity." -ForegroundColor Green

# ------------------------------------------------------------
# Build DATABASE_URL
# ------------------------------------------------------------

Write-Step "Configuring PostgreSQL connection"

$encodedPassword = [System.Uri]::EscapeDataString($postgresPassword)

$databaseUrl = "postgresql://${postgresAdmin}:${encodedPassword}@${postgresFqdn}:5432/${databaseName}?sslmode=require"

Write-Host ""
Write-Host "DATABASE_URL DEBUG:" -ForegroundColor Cyan
Write-Host "  Admin    : $postgresAdmin"
Write-Host "  FQDN     : $postgresFqdn"
Write-Host "  Database : $databaseName"
Write-Host "  URL      : postgresql://${postgresAdmin}:***@${postgresFqdn}:5432/${databaseName}?sslmode=require" -ForegroundColor DarkGray
Write-Host ""

# ------------------------------------------------------------
# Configure Container App secret
# ------------------------------------------------------------

Write-Host "Saving DATABASE_URL as Azure Container App secret..." -ForegroundColor Yellow

Invoke-Az @(
    "containerapp",
    "secret",
    "set",
    "--name",
    $containerAppName,
    "--resource-group",
    $resourceGroup,
    "--secrets",
    "database-url=$databaseUrl"
)

# ------------------------------------------------------------
# Configure DATABASE_URL environment variable
# ------------------------------------------------------------

Write-Host "Configuring DATABASE_URL environment variable..." -ForegroundColor Yellow

Invoke-Az @(
    "containerapp",
    "update",
    "--name",
    $containerAppName,
    "--resource-group",
    $resourceGroup,
    "--set-env-vars",
    "DATABASE_URL=secretref:database-url"
)

Write-Host "DATABASE_URL configured." -ForegroundColor Green

Write-Host "Applying updated secrets to Container App..." -ForegroundColor Yellow

Invoke-Az @(
    "containerapp",
    "update",
    "--name",
    $containerAppName,
    "--resource-group",
    $resourceGroup,
    "--set-env-vars",
    "DATABASE_URL=secretref:database-url"
)

Write-Host "Updated secret applied." -ForegroundColor Green

# ------------------------------------------------------------
# Configure health probes
# ------------------------------------------------------------

Write-Step "Configuring application health probes"

$probeYaml = @"
properties:
  template:
    containers:
      - name: $containerAppName
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

$tempProbeFile = Join-Path $env:TEMP "azure-demo-probes-$([guid]::NewGuid()).yaml"

Set-Content -Path $tempProbeFile -Value $probeYaml -Encoding UTF8

try {
    Invoke-Az @(
        "containerapp",
        "update",
        "--name",
        $containerAppName,
        "--resource-group",
        $resourceGroup,
        "--yaml",
        $tempProbeFile
    )
}
finally {
    Remove-Item $tempProbeFile -Force -ErrorAction SilentlyContinue
}

Write-Host "Health probes configured." -ForegroundColor Green

# ------------------------------------------------------------
# Deploy application image
# ------------------------------------------------------------

Write-Step "Deploying application image"

Invoke-Az @(
    "containerapp",
    "update",
    "--name",
    $containerAppName,
    "--resource-group",
    $resourceGroup,
    "--image",
    $imageFullName
)

Write-Host "Application image deployed." -ForegroundColor Green

# ------------------------------------------------------------
# Get application URL
# ------------------------------------------------------------

Write-Step "Getting application URL"

$fqdn = az containerapp show `
    --name $containerAppName `
    --resource-group $resourceGroup `
    --query "properties.configuration.ingress.fqdn" `
    --output tsv

if ([string]::IsNullOrWhiteSpace($fqdn)) {
    Write-Host "Could not determine application URL yet." -ForegroundColor Yellow
}
else {
    $appUrl = "https://$fqdn"
}

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------

Write-Step "Verifying deployment"

Write-Host "Container App:" -ForegroundColor Yellow

az containerapp show `
    --name $containerAppName `
    --resource-group $resourceGroup `
    --query "{name:name,provisioningState:properties.provisioningState,runningState:properties.runningStatus,fqdn:properties.configuration.ingress.fqdn}" `
    -o table

Write-Host ""
Write-Host "PostgreSQL:" -ForegroundColor Yellow

az postgres flexible-server show `
    --name $postgresServerName `
    --resource-group $resourceGroup `
    --query "{name:name,state:state,version:version,fqdn:fullyQualifiedDomainName}" `
    -o table

# ------------------------------------------------------------
# Final output
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " INSTALLATION COMPLETED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

if ($appUrl) {
    Write-Host "Application:" -ForegroundColor Cyan
    Write-Host "  $appUrl" -ForegroundColor White
}

Write-Host ""
Write-Host "Azure resources:" -ForegroundColor Cyan
Write-Host "  Resource Group : $resourceGroup"
Write-Host "  ACR            : $acrLoginServer"
Write-Host "  Container App  : $containerAppName"
Write-Host "  Environment    : $environmentName"
Write-Host "  PostgreSQL     : $postgresFqdn"
Write-Host "  Database       : $databaseName"

Write-Host ""
Write-Host "The application uses PostgreSQL in THIS Azure subscription." -ForegroundColor Green
Write-Host "GitHub Actions are NOT required for this installation." -ForegroundColor Green
Write-Host ""

Write-Host "Important:" -ForegroundColor Yellow
Write-Host "The PostgreSQL password was entered only during this installation." -ForegroundColor Yellow
Write-Host "DATABASE_URL is stored as a Container App secret." -ForegroundColor Yellow
Write-Host ""

Write-Host "============================================================" -ForegroundColor Green