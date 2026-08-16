# ============================================================
# Azure Task Manager - One-Click Azure Installer
#
# This script:
#   1. Checks Azure CLI and Docker
#   2. Checks Azure login
#   3. Lets the user select an Azure subscription
#   4. Checks required Azure resource providers
#   5. Lets the user reuse or create:
#        - Resource Group
#        - Azure Container Registry
#        - Container Apps Environment
#        - Container App
#   6. Validates PostgreSQL configuration
#   7. Builds Docker image
#   8. Pushes image to ACR
#   9. Creates/reuses PostgreSQL Flexible Server
#  10. Creates/reuses PostgreSQL database
#  11. Creates/reuses Container Apps Environment
#  12. Creates/reuses Container App
#  13. Configures managed identity
#  14. Grants AcrPull permission
#  15. Configures DATABASE_URL as Container App secret
#  16. Configures health probes
#  17. Deploys application image
#  18. Performs final verification
#
# GitHub Actions are NOT required by this script.
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Azure Task Manager - Azure Installer" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Helper functions
# ============================================================

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

        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Host "Password cannot be empty." -ForegroundColor Yellow
            continue
        }

        if ($value.Length -lt 8) {
            Write-Host "Password must contain at least 8 characters." -ForegroundColor Yellow
            continue
        }

        if ($value.Length -gt 128) {
            Write-Host "Password cannot contain more than 128 characters." -ForegroundColor Yellow
            continue
        }

        if ($value -match "\s") {
            Write-Host "Password cannot contain whitespace characters." -ForegroundColor Yellow
            continue
        }

        return $value
    }
}

function Write-Step {
    param (
        [Parameter(Mandatory = $true)]
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

        # Never print PostgreSQL passwords into the terminal/logs.
        $safeArguments = $Arguments -join " "

        if ($safeArguments -match "--admin-password\s+\S+") {
            $safeArguments = $safeArguments -replace `
                "--admin-password\s+\S+", `
                "--admin-password ***"
        }

        if ($safeArguments -match "database-url=\S+") {
            $safeArguments = $safeArguments -replace `
                "database-url=\S+", `
                "database-url=***"
        }

        throw "Azure CLI command failed: az $safeArguments"
    }
}

function Read-Choice {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $true)]
        [int]$Max
    )

    while ($true) {

        $inputValue = Read-Host $Prompt

        if ($inputValue -match "^\d+$") {

            $number = [int]$inputValue

            if ($number -ge 0 -and $number -lt $Max) {
                return $number
            }
        }

        Write-Host "Invalid selection. Please enter a number from 0 to $($Max - 1)." -ForegroundColor Yellow
    }
}

function Test-ProviderRegistered {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Provider
    )

    $state = az provider show `
        --namespace $Provider `
        --query registrationState `
        --output tsv `
        2>$null

    return $state -eq "Registered"
}

function Ensure-ProviderRegistered {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Provider
    )

    if (Test-ProviderRegistered $Provider) {
        Write-Host "$Provider : Registered" -ForegroundColor Green
        return
    }

    $state = az provider show `
        --namespace $Provider `
        --query registrationState `
        --output tsv `
        2>$null

    if ([string]::IsNullOrWhiteSpace($state)) {
        Write-Host "$Provider : Not registered" -ForegroundColor Yellow
    }
    else {
        Write-Host "$Provider : $state" -ForegroundColor Yellow
    }

    $answer = Read-Host "Register $Provider now? (y/n)"

    if ($answer -notmatch "^(y|yes)$") {
        throw "Required provider $Provider is not registered."
    }

    Write-Host "Registering $Provider..." -ForegroundColor Yellow

    Invoke-Az @(
        "provider",
        "register",
        "--namespace",
        $Provider
    )

    Write-Host "Waiting for $Provider registration..." -ForegroundColor DarkGray

    for ($i = 0; $i -lt 30; $i++) {

        Start-Sleep -Seconds 5

        if (Test-ProviderRegistered $Provider) {
            Write-Host "$Provider : Registered" -ForegroundColor Green
            return
        }

        Write-Host "." -NoNewline
    }

    Write-Host ""

    throw "Provider $Provider did not become Registered in time."
}

# ============================================================
# Prerequisites
# ============================================================

Write-Step "Checking prerequisites"

if (-not (Test-CommandExists "az")) {

    Write-Host "Azure CLI is not installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install it from:" -ForegroundColor Yellow
    Write-Host "https://learn.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Yellow

    exit 1
}

if (-not (Test-CommandExists "docker")) {

    Write-Host "Docker is not installed or not available in PATH." -ForegroundColor Red
    Write-Host "Install Docker Desktop and run the script again." -ForegroundColor Yellow

    exit 1
}

Write-Host "Azure CLI: OK" -ForegroundColor Green
Write-Host "Docker:    OK" -ForegroundColor Green

# ============================================================
# Docker daemon
# ============================================================

Write-Step "Checking Docker daemon"

docker info *> $null

if ($LASTEXITCODE -ne 0) {

    Write-Host "Docker Desktop is not running." -ForegroundColor Red
    Write-Host "Start Docker Desktop and run the script again." -ForegroundColor Yellow

    exit 1
}

Write-Host "Docker daemon is running." -ForegroundColor Green

# ============================================================
# Azure login
# ============================================================

Write-Step "Checking Azure login"

$accountJson = az account show 2>$null

if (
    $LASTEXITCODE -ne 0 -or
    [string]::IsNullOrWhiteSpace($accountJson)
) {

    Write-Host "You are not logged into Azure." -ForegroundColor Yellow
    Write-Host "Opening Azure login..." -ForegroundColor Yellow

    Invoke-Az @("login")
}

$account = az account show | ConvertFrom-Json

if (-not $account) {
    throw "Could not retrieve Azure account information."
}

Write-Host ""
Write-Host "Logged in as:" -ForegroundColor Green
Write-Host "  $($account.user.name)" -ForegroundColor White

# ============================================================
# Subscription selection
# ============================================================

Write-Step "Checking Azure subscriptions"

$subscriptionsJson = az account list `
    --query "[?state=='Enabled'].{Name:name,Id:id,IsDefault:isDefault}" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve Azure subscriptions."
}

$subscriptions = $subscriptionsJson | ConvertFrom-Json

if (-not $subscriptions) {
    throw "No enabled Azure subscriptions were found."
}

if ($subscriptions -isnot [System.Array]) {
    $subscriptions = @($subscriptions)
}

Write-Host ""
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

$subscriptionIndex = Read-Choice `
    -Prompt "Select subscription number" `
    -Max $subscriptions.Count

$subscriptionId = $subscriptions[$subscriptionIndex].Id
$subscriptionName = $subscriptions[$subscriptionIndex].Name

Invoke-Az @(
    "account",
    "set",
    "--subscription",
    $subscriptionId
)

Write-Host ""
Write-Host "Selected subscription:" -ForegroundColor Green
Write-Host "  $subscriptionName" -ForegroundColor White
Write-Host "  $subscriptionId" -ForegroundColor DarkGray

# ============================================================
# Required Azure Resource Providers
# ============================================================

Write-Step "Checking required Azure resource providers"

$requiredProviders = @(
    "Microsoft.ContainerRegistry",
    "Microsoft.App",
    "Microsoft.DBforPostgreSQL"
)

foreach ($provider in $requiredProviders) {
    Ensure-ProviderRegistered $provider
}

Write-Host ""
Write-Host "All required resource providers are registered." -ForegroundColor Green

# ============================================================
# Azure region
# ============================================================

Write-Step "Azure region"

$location = Read-RequiredValue `
    "Azure region (example: polandcentral, westeurope)"

# ============================================================
# Resource Group
# ============================================================

Write-Step "Resource Group"

$existingResourceGroupsJson = az group list `
    --query "[].{Name:name,Location:location}" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve Resource Groups."
}

$existingResourceGroups = $existingResourceGroupsJson | ConvertFrom-Json

if ($existingResourceGroups -and $existingResourceGroups -isnot [System.Array]) {
    $existingResourceGroups = @($existingResourceGroups)
}

Write-Host ""
Write-Host "[0] Create a new Resource Group" -ForegroundColor Cyan

if ($existingResourceGroups) {

    for ($i = 0; $i -lt $existingResourceGroups.Count; $i++) {

        Write-Host "[$($i + 1)] Use '$($existingResourceGroups[$i].Name)' ($($existingResourceGroups[$i].Location))"
    }

    Write-Host ""

    $rgChoice = Read-Choice `
        -Prompt "Select Resource Group option" `
        -Max ($existingResourceGroups.Count + 1)

    if ($rgChoice -eq 0) {

        $resourceGroup = Read-RequiredValue "New Resource Group name"

        $rgExists = az group exists `
            --name $resourceGroup

        if ($rgExists -eq "true") {
            Write-Host "Resource Group already exists." -ForegroundColor Yellow
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

    }
    else {

        $selectedRg = $existingResourceGroups[$rgChoice - 1]

        $resourceGroup = $selectedRg.Name

        Write-Host "Using existing Resource Group: $resourceGroup" -ForegroundColor Green
    }
}
else {

    $resourceGroup = Read-RequiredValue "New Resource Group name"

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

# ============================================================
# ACR selection
# ============================================================

Write-Step "Azure Container Registry"

$allAcrJson = az acr list `
    --query "[].{Name:name,ResourceGroup:resourceGroup,Location:location,LoginServer:loginServer,Sku:sku.name}" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve Azure Container Registries."
}

$allAcrs = $allAcrJson | ConvertFrom-Json

if ($allAcrs -and $allAcrs -isnot [System.Array]) {
    $allAcrs = @($allAcrs)
}

Write-Host ""
Write-Host "[0] Create a new ACR" -ForegroundColor Cyan

if ($allAcrs) {

    for ($i = 0; $i -lt $allAcrs.Count; $i++) {

        Write-Host "[$($i + 1)] Use '$($allAcrs[$i].Name)'"
        Write-Host "    Resource Group: $($allAcrs[$i].ResourceGroup)"
        Write-Host "    Login Server:  $($allAcrs[$i].LoginServer)"
        Write-Host "    SKU:           $($allAcrs[$i].Sku)"
    }

    Write-Host ""

    $acrChoice = Read-Choice `
        -Prompt "Select ACR option" `
        -Max ($allAcrs.Count + 1)

    if ($acrChoice -eq 0) {

        do {

            $acrName = Read-RequiredValue `
                "New ACR name (globally unique, lowercase, alphanumeric)"

            if ($acrName -notmatch "^[a-z0-9]{5,50}$") {

                Write-Host ""
                Write-Host "Invalid ACR name." -ForegroundColor Red
                Write-Host "ACR names must contain only lowercase letters and numbers and be 5-50 characters long." -ForegroundColor Yellow
                continue
            }

            $acrNameCheck = az acr check-name `
                --name $acrName `
                --query nameAvailable `
                --output tsv `
                2>$null

            if ($acrNameCheck -eq "true") {

                Write-Host "ACR name '$acrName' is available." -ForegroundColor Green
                break
            }

            Write-Host "ACR name '$acrName' is already used." -ForegroundColor Red

        } while ($true)

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

        Write-Host "ACR created." -ForegroundColor Green

    }
    else {

        $selectedAcr = $allAcrs[$acrChoice - 1]

        $acrName = $selectedAcr.Name
        $acrLoginServer = $selectedAcr.LoginServer
        $acrResourceGroup = $selectedAcr.ResourceGroup

        Write-Host ""
        Write-Host "Using existing ACR:" -ForegroundColor Green
        Write-Host "  $acrName"
        Write-Host "  Resource Group: $acrResourceGroup"
    }

}
else {

    do {

        $acrName = Read-RequiredValue `
            "New ACR name (globally unique, lowercase, alphanumeric)"

        if ($acrName -notmatch "^[a-z0-9]{5,50}$") {

            Write-Host "Invalid ACR name." -ForegroundColor Red
            continue
        }

        $acrNameCheck = az acr check-name `
            --name $acrName `
            --query nameAvailable `
            --output tsv `
            2>$null

        if ($acrNameCheck -eq "true") {
            break
        }

        Write-Host "ACR name is already used. Choose another." -ForegroundColor Yellow

    } while ($true)

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

    Write-Host "ACR created." -ForegroundColor Green
}

$acrInfoJson = az acr show `
    --name $acrName `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve ACR information."
}

$acrInfo = $acrInfoJson | ConvertFrom-Json

$acrLoginServer = $acrInfo.loginServer
$acrId = $acrInfo.id
$acrResourceGroup = $acrInfo.resourceGroup

Write-Host ""
Write-Host "ACR login server: $acrLoginServer" -ForegroundColor Green

# ============================================================
# Application names
# ============================================================

Write-Step "Application configuration"

$containerAppName = Read-RequiredValue "Container App name"

$postgresServerName = Read-RequiredValue `
    "PostgreSQL server name (globally unique, lowercase)"

$postgresAdmin = Read-RequiredValue "PostgreSQL admin username"

$postgresPassword = Read-PasswordValue `
    "PostgreSQL admin password"

$databaseName = "tasks"

$imageName = $containerAppName

$imageTag = "v1"

$imageFullName = "$acrLoginServer/$imageName`:$imageTag"

# ============================================================
# PostgreSQL name validation
# ============================================================

Write-Step "Checking PostgreSQL server name"

$postgresInSubscriptionJson = az postgres flexible-server list `
    --query "[].{Name:name,ResourceGroup:resourceGroup,Location:location}" `
    --output json `
    2>$null

$postgresInSubscription = $postgresInSubscriptionJson | ConvertFrom-Json

if (
    $postgresInSubscription -and
    $postgresInSubscription -isnot [System.Array]
) {
    $postgresInSubscription = @($postgresInSubscription)
}

$postgresExists = $false

if ($postgresInSubscription) {

    foreach ($server in $postgresInSubscription) {

        if ($server.Name -eq $postgresServerName) {

            $postgresExists = $true

            Write-Host ""
            Write-Host "PostgreSQL server already exists:" -ForegroundColor Yellow
            Write-Host "  Name: $($server.Name)"
            Write-Host "  Resource Group: $($server.ResourceGroup)"
            Write-Host "  Location: $($server.Location)"
        }
    }
}

if ($postgresExists) {

    Write-Host ""
    Write-Host "Existing PostgreSQL server will be reused." -ForegroundColor Yellow
    Write-Host "Make sure the password you entered belongs to this server." -ForegroundColor Yellow

}
else {

    Write-Host ""
    Write-Host "PostgreSQL name is not used in the current subscription." -ForegroundColor Green
    Write-Host "Note: Azure PostgreSQL server names are globally unique." -ForegroundColor DarkGray
}

# ============================================================
# Container Apps Environment
# ============================================================

Write-Step "Container Apps Environment"

$existingEnvironmentsJson = az containerapp env list `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve Container Apps Environments."
}

$existingEnvironments = $existingEnvironmentsJson | ConvertFrom-Json

if (
    $existingEnvironments -and
    $existingEnvironments -isnot [System.Array]
) {
    $existingEnvironments = @($existingEnvironments)
}

Write-Host ""
Write-Host "[0] Create a new Container Apps Environment" -ForegroundColor Cyan

if ($existingEnvironments) {

    for ($i = 0; $i -lt $existingEnvironments.Count; $i++) {

        Write-Host "[$($i + 1)] Use '$($existingEnvironments[$i].name)'"
        Write-Host "    Resource Group: $($existingEnvironments[$i].resourceGroup)"
        Write-Host "    Location:       $($existingEnvironments[$i].location)"
    }

    Write-Host ""

    $environmentChoice = Read-Choice `
        -Prompt "Select Environment option" `
        -Max ($existingEnvironments.Count + 1)

    if ($environmentChoice -eq 0) {

        $environmentName = Read-RequiredValue `
            "New Container Apps Environment name"

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

        $environmentResourceGroup = $resourceGroup

        Write-Host "Container Apps Environment created." -ForegroundColor Green
    }
    else {

        $selectedEnvironment = $existingEnvironments[$environmentChoice - 1]

        $environmentName = $selectedEnvironment.name
        $environmentResourceGroup = $selectedEnvironment.resourceGroup

        Write-Host ""
        Write-Host "Using existing Container Apps Environment:" -ForegroundColor Green
        Write-Host "  $environmentName"
        Write-Host "  Resource Group: $environmentResourceGroup"
    }

}
else {

    $environmentName = Read-RequiredValue `
        "New Container Apps Environment name"

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

    $environmentResourceGroup = $resourceGroup

    Write-Host "Container Apps Environment created." -ForegroundColor Green
}

$environmentId = az containerapp env show `
    --name $environmentName `
    --resource-group $environmentResourceGroup `
    --query id `
    --output tsv

if ([string]::IsNullOrWhiteSpace($environmentId)) {
    throw "Could not determine Container Apps Environment resource ID."
}

# ============================================================
# Container App
# ============================================================

Write-Step "Container App"

$existingAppsJson = az containerapp list `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve Container Apps."
}

$existingApps = $existingAppsJson | ConvertFrom-Json

if ($existingApps -and $existingApps -isnot [System.Array]) {
    $existingApps = @($existingApps)
}

Write-Host ""
Write-Host "[0] Create a new Container App" -ForegroundColor Cyan

if ($existingApps) {

    for ($i = 0; $i -lt $existingApps.Count; $i++) {

        Write-Host "[$($i + 1)] Use '$($existingApps[$i].name)'"
        Write-Host "    Resource Group: $($existingApps[$i].resourceGroup)"
    }

    Write-Host ""

    $appChoice = Read-Choice `
        -Prompt "Select Container App option" `
        -Max ($existingApps.Count + 1)

    if ($appChoice -eq 0) {

        $containerAppName = Read-RequiredValue `
            "New Container App name"

        $containerAppExists = $false

    }
    else {

        $selectedApp = $existingApps[$appChoice - 1]

        $containerAppName = $selectedApp.name
        $containerAppResourceGroup = $selectedApp.resourceGroup
        $containerAppExists = $true

        Write-Host ""
        Write-Host "Using existing Container App:" -ForegroundColor Green
        Write-Host "  $containerAppName"
        Write-Host "  Resource Group: $containerAppResourceGroup"
    }

}
else {

    $containerAppName = Read-RequiredValue `
        "New Container App name"

    $containerAppExists = $false
}

# ============================================================
# Docker image existence
# ============================================================

Write-Step "Checking Docker image in ACR"

$imageExists = $false
$imageRepositoryExists = $false
$imageTagExists = $false

Write-Host "Checking repository '$imageName' in ACR '$acrName'..." -ForegroundColor Cyan

# ------------------------------------------------------------
# Check repository
# ------------------------------------------------------------

$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"

try {

    $repositoryOutput = az acr repository show `
        --name $acrName `
        --repository $imageName `
        --query name `
        --output tsv `
        2>$null

    $repositoryExitCode = $LASTEXITCODE

}
finally {

    $ErrorActionPreference = $oldErrorActionPreference

}

if ($repositoryExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($repositoryOutput)) {

    $imageRepositoryExists = $true

    Write-Host "Repository exists:" -ForegroundColor Green
    Write-Host "  $imageName" -ForegroundColor White

}
else {

    Write-Host ""
    Write-Host "Docker repository does not exist in ACR." -ForegroundColor Yellow
    Write-Host "  Repository: $imageName" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "This is normal for a first installation." -ForegroundColor Cyan

}

# ------------------------------------------------------------
# Check image tag
# ------------------------------------------------------------

if ($imageRepositoryExists) {

    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {

        $tagOutput = az acr repository show-tags `
            --name $acrName `
            --repository $imageName `
            --query "[?@=='$imageTag']" `
            --output tsv `
            2>$null

        $tagExitCode = $LASTEXITCODE

    }
    finally {

        $ErrorActionPreference = $oldErrorActionPreference

    }

    if ($tagExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($tagOutput)) {

        $imageTagExists = $true
        $imageExists = $true

        Write-Host "Docker image exists:" -ForegroundColor Green
        Write-Host "  $imageFullName" -ForegroundColor White

    }
    else {

        Write-Host ""
        Write-Host "Repository exists, but image tag '$imageTag' was not found." -ForegroundColor Yellow
        Write-Host "A new image will be built and pushed." -ForegroundColor Cyan

    }
}

# ------------------------------------------------------------
# Decide whether to build image
# ------------------------------------------------------------

if ($imageExists) {

    Write-Host ""
    Write-Host "Docker image already exists:" -ForegroundColor Yellow
    Write-Host "  $imageFullName"
    Write-Host ""

    $imageChoice = Read-Host "Use existing image? (y/n)"

    if ($imageChoice -match "^(y|yes)$") {

        $buildImage = $false

        Write-Host "Existing image will be used." -ForegroundColor Green

    }
    else {

        $buildImage = $true

        Write-Host "Image will be rebuilt and pushed." -ForegroundColor Yellow

    }

}
else {

    $buildImage = $true

    Write-Host ""
    Write-Host "Docker image is not available in ACR." -ForegroundColor Yellow
    Write-Host "A new image will be built and pushed." -ForegroundColor Green

}

# ============================================================
# Configuration summary
# ============================================================

Write-Step "Configuration summary"

Write-Host "Resource Group : $resourceGroup"
Write-Host "Location       : $location"
Write-Host "ACR            : $acrName"
Write-Host "ACR Server     : $acrLoginServer"
Write-Host "Environment    : $environmentName"
Write-Host "Container App  : $containerAppName"
Write-Host "PostgreSQL     : $postgresServerName"
Write-Host "Database       : $databaseName"
Write-Host "Image          : $imageFullName"
Write-Host "Build Image    : $buildImage"

Write-Host ""

$confirmation = Read-Host "Continue with deployment? (y/n)"

if ($confirmation -notmatch "^(y|yes)$") {

    Write-Host "Installation cancelled." -ForegroundColor Yellow
    exit 0
}

# ============================================================
# Docker build and push
# ============================================================

if ($buildImage) {

    Write-Step "Building Docker image"

    Write-Host "Building:"
    Write-Host "  $imageFullName"

    docker build `
        -t $imageFullName .

    if ($LASTEXITCODE -ne 0) {
        throw "Docker image build failed."
    }

    Write-Host "Docker image built successfully." -ForegroundColor Green

    Write-Step "Logging into Azure Container Registry"

    Invoke-Az @(
        "acr",
        "login",
        "--name",
        $acrName
    )

    Write-Host "ACR login successful." -ForegroundColor Green

    Write-Step "Pushing Docker image to ACR"

    docker push $imageFullName

    if ($LASTEXITCODE -ne 0) {
        throw "Docker image push failed."
    }

    Write-Host "Image pushed successfully." -ForegroundColor Green

}
else {

    Write-Host ""
    Write-Host "Skipping Docker build and push." -ForegroundColor Yellow

}


# ============================================================
# PostgreSQL Flexible Server
# ============================================================

Write-Step "PostgreSQL Flexible Server"

if ($postgresExists) {

    Write-Host "Using existing PostgreSQL server: $postgresServerName" -ForegroundColor Yellow

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

    Write-Host "PostgreSQL server created." -ForegroundColor Green
}

# ============================================================
# PostgreSQL database
# ============================================================

Write-Step "PostgreSQL database"

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

if ($dbList -and $dbList -isnot [System.Array]) {
    $dbList = @($dbList)
}

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

    Write-Host "Database created." -ForegroundColor Green
}

# ============================================================
# PostgreSQL FQDN
# ============================================================

$postgresFqdn = az postgres flexible-server show `
    --resource-group $resourceGroup `
    --name $postgresServerName `
    --query fullyQualifiedDomainName `
    --output tsv

if ([string]::IsNullOrWhiteSpace($postgresFqdn)) {
    throw "Could not determine PostgreSQL FQDN."
}

Write-Host "PostgreSQL FQDN: $postgresFqdn" -ForegroundColor Green

# ============================================================
# Container App creation
# ============================================================

Write-Step "Container App"

if ($containerAppExists) {

    Write-Host "Using existing Container App: $containerAppName" -ForegroundColor Yellow

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

    Write-Host "Container App created." -ForegroundColor Green
}

# ============================================================
# Managed identity
# ============================================================

Write-Step "Configuring Container App managed identity"

$principalId = az containerapp show `
    --name $containerAppName `
    --resource-group $resourceGroup `
    --query identity.principalId `
    --output tsv

if ([string]::IsNullOrWhiteSpace($principalId)) {

    Write-Host "Container App does not have a managed identity." -ForegroundColor Yellow
    Write-Host "Enabling system-assigned managed identity..." -ForegroundColor Yellow

    Invoke-Az @(
        "containerapp",
        "identity",
        "assign",
        "--name",
        $containerAppName,
        "--resource-group",
        $resourceGroup,
        "--system-assigned"
    )

    $principalId = az containerapp show `
        --name $containerAppName `
        --resource-group $resourceGroup `
        --query identity.principalId `
        --output tsv
}

if ([string]::IsNullOrWhiteSpace($principalId)) {
    throw "Could not retrieve Container App managed identity."
}

Write-Host "Managed Identity Principal ID: $principalId" -ForegroundColor Green

# ============================================================
# AcrPull permission
# ============================================================

Write-Step "Checking AcrPull permission"

$existingRole = az role assignment list `
    --assignee-object-id $principalId `
    --scope $acrId `
    --query "[?roleDefinitionName=='AcrPull'].id" `
    --output tsv `
    2>$null

if ([string]::IsNullOrWhiteSpace($existingRole)) {

    Write-Host "AcrPull permission not found." -ForegroundColor Yellow
    Write-Host "Granting AcrPull..." -ForegroundColor Yellow

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

    Write-Host "Waiting for RBAC propagation..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 15

}
else {

    Write-Host "AcrPull permission already exists." -ForegroundColor Green
}

# ============================================================
# Container App registry
# ============================================================

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

Write-Host "Container App registry configured." -ForegroundColor Green

# ============================================================
# DATABASE_URL
# ============================================================

Write-Step "Validating PostgreSQL connection"

if ([string]::IsNullOrWhiteSpace($postgresAdmin)) {
    throw "PostgreSQL administrator username is empty."
}

if ([string]::IsNullOrWhiteSpace($postgresPassword)) {
    throw "PostgreSQL password is empty."
}

if ([string]::IsNullOrWhiteSpace($postgresFqdn)) {
    throw "PostgreSQL FQDN is empty."
}

if ([string]::IsNullOrWhiteSpace($databaseName)) {
    throw "Database name is empty."
}

$encodedPassword = [System.Uri]::EscapeDataString($postgresPassword)

$databaseUrl = "postgresql://${postgresAdmin}:${encodedPassword}@${postgresFqdn}:5432/${databaseName}?sslmode=require"

# Validate URL structure.
try {

    $databaseUri = [System.Uri]$databaseUrl

    if (
        $databaseUri.Scheme -ne "postgresql" -or
        [string]::IsNullOrWhiteSpace($databaseUri.Host) -or
        $databaseUri.Port -ne 5432
    ) {
        throw "Invalid PostgreSQL connection URL."
    }

}
catch {

    throw "DATABASE_URL validation failed."
}

Write-Host ""
Write-Host "DATABASE_URL validation: OK" -ForegroundColor Green
Write-Host "  Scheme   : postgresql"
Write-Host "  Host     : $postgresFqdn"
Write-Host "  Port     : 5432"
Write-Host "  Database : $databaseName"
Write-Host "  SSL      : require"

# ============================================================
# Container App secret
# ============================================================

Write-Step "Configuring DATABASE_URL secret"

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

Write-Host "DATABASE_URL stored as Container App secret." -ForegroundColor Green

# ============================================================
# DATABASE_URL environment variable
# ============================================================

Write-Step "Configuring DATABASE_URL environment variable"

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

Write-Host "DATABASE_URL environment variable configured." -ForegroundColor Green

# ============================================================
# Health probes
# ============================================================

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

$tempProbeFile = Join-Path `
    $env:TEMP `
    "azure-task-manager-probes-$([guid]::NewGuid()).yaml"

Set-Content `
    -Path $tempProbeFile `
    -Value $probeYaml `
    -Encoding UTF8

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

    Remove-Item `
        $tempProbeFile `
        -Force `
        -ErrorAction SilentlyContinue
}

Write-Host "Health probes configured." -ForegroundColor Green

# ============================================================
# Deploy application image
# ============================================================

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

# ============================================================
# Get application URL
# ============================================================

Write-Step "Getting application URL"

$fqdn = az containerapp show `
    --name $containerAppName `
    --resource-group $resourceGroup `
    --query "properties.configuration.ingress.fqdn" `
    --output tsv

if ([string]::IsNullOrWhiteSpace($fqdn)) {

    Write-Host "Could not determine application URL." -ForegroundColor Yellow

}
else {

    $appUrl = "https://$fqdn"

    Write-Host ""
    Write-Host "Application URL:" -ForegroundColor Green
    Write-Host "  $appUrl" -ForegroundColor White
}

# ============================================================
# Final verification
# ============================================================

Write-Step "Final deployment verification"

Write-Host ""
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

Write-Host ""
Write-Host "DATABASE_URL environment variable:" -ForegroundColor Yellow

az containerapp show `
    --name $containerAppName `
    --resource-group $resourceGroup `
    --query "properties.template.containers[0].env[?name=='DATABASE_URL']" `
    -o table

# ============================================================
# Final output
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " INSTALLATION COMPLETED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

if ($appUrl) {

    Write-Host "Application:" -ForegroundColor Cyan
    Write-Host "  $appUrl" -ForegroundColor White
    Write-Host ""
    Write-Host "Swagger:" -ForegroundColor Cyan
    Write-Host "  $appUrl/docs" -ForegroundColor White
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
Write-Host "Checks passed:" -ForegroundColor Green
Write-Host "  Azure CLI"
Write-Host "  Docker"
Write-Host "  Docker daemon"
Write-Host "  Azure login"
Write-Host "  Azure subscription"
Write-Host "  Required resource providers"
Write-Host "  PostgreSQL configuration"
Write-Host "  DATABASE_URL validation"
Write-Host "  Container App managed identity"
Write-Host "  ACR authentication"
Write-Host "  AcrPull permission"
Write-Host "  Application deployment"

Write-Host ""
Write-Host "Important:" -ForegroundColor Yellow
Write-Host "The PostgreSQL password was entered only during this installation."
Write-Host "DATABASE_URL is stored as a Container App secret."
Write-Host "GitHub Actions are NOT required for this installation."

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green