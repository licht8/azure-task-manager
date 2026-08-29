# ============================================================
# Deploy-AzurePostgreSQLBackup.ps1
#
# PostgreSQL -> Azure Container Apps Job -> Azure Blob Storage
#
# Configuration:
#   .\config.json
# ============================================================

param(
    [string]$Config = ".\config.json"
)

$ErrorActionPreference = "Stop"

# ============================================================
# Output
# ============================================================

function Section([string]$Title) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================"
}

function Info([string]$Message) {
    Write-Host "[INFO]    $Message" -ForegroundColor DarkGray
}

function Pass([string]$Message) {
    Write-Host "[PASS]    $Message" -ForegroundColor Green
}

function Fail([string]$Message) {
    Write-Host "[FAILED]  $Message" -ForegroundColor Red
}

function Require-Config([string]$Name, [string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Missing config value: $Name"
    }
}

# ============================================================
# Azure CLI wrapper
# ============================================================

function Invoke-AzureCLI {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        $argumentString = ($Arguments | ForEach-Object {
            if ($_ -match '[\s"]') {
                '"' + $_.Replace('"', '\"') + '"'
            }
            else {
                $_
            }
        }) -join ' '

        $process = Start-Process `
            -FilePath "az.cmd" `
            -ArgumentList $argumentString `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $stdoutFile `
            -RedirectStandardError $stderrFile

        [PSCustomObject]@{
            ExitCode = $process.ExitCode
            Output   = if (Test-Path $stdoutFile) {
                [IO.File]::ReadAllText($stdoutFile).Trim()
            } else {
                ""
            }
            Error    = if (Test-Path $stderrFile) {
                [IO.File]::ReadAllText($stderrFile).Trim()
            } else {
                ""
            }
        }
    }
    finally {
        Remove-Item $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Azure JSON helper
# ============================================================

function Get-AzureJson {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [string]$ErrorMessage = "Azure CLI command failed"
    )

    $result = Invoke-AzureCLI $Arguments

    if ($result.ExitCode -ne 0) {
        if ($result.Error) {
            Write-Host $result.Error -ForegroundColor Red
        }

        throw $ErrorMessage
    }

    if ([string]::IsNullOrWhiteSpace($result.Output)) {
        throw "$ErrorMessage. Azure returned empty output."
    }

    try {
        return $result.Output | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "$ErrorMessage. Could not parse Azure CLI response."
    }
}

# ============================================================
# Configuration
# ============================================================

Section "Configuration"

if (-not (Test-Path -LiteralPath $Config)) {
    Fail "Configuration file not found: $Config"
    exit 1
}

try {
    $configData =
        Get-Content -LiteralPath $Config -Raw |
        ConvertFrom-Json -ErrorAction Stop
}
catch {
    Fail "Could not parse config.json"
    throw
}

$LOCATION          = [string]$configData.location
$RESOURCE_GROUP    = [string]$configData.resourceGroup
$ACR_NAME          = [string]$configData.acrName
$ENVIRONMENT_NAME  = [string]$configData.environmentName
$POSTGRES_SERVER   = [string]$configData.postgresServer
$POSTGRES_DATABASE = [string]$configData.postgresDatabase
$POSTGRES_ADMIN    = [string]$configData.postgresAdmin
$STORAGE_ACCOUNT   = [string]$configData.backupStorageAccount
$BACKUP_CONTAINER  = [string]$configData.backupContainer
$JOB_NAME          = [string]$configData.backupJob
$IDENTITY_NAME     = [string]$configData.backupIdentity

@{
    location           = $LOCATION
    resourceGroup      = $RESOURCE_GROUP
    acrName             = $ACR_NAME
    environmentName     = $ENVIRONMENT_NAME
    postgresServer      = $POSTGRES_SERVER
    postgresDatabase    = $POSTGRES_DATABASE
    postgresAdmin       = $POSTGRES_ADMIN
    backupStorageAccount= $STORAGE_ACCOUNT
    backupContainer     = $BACKUP_CONTAINER
    backupJob           = $JOB_NAME
    backupIdentity      = $IDENTITY_NAME
}.GetEnumerator() | ForEach-Object {
    Require-Config $_.Key $_.Value
}

$BACKUP_REPOSITORY = "postgres-backup"

Info "Location:          $LOCATION"
Info "Resource Group:    $RESOURCE_GROUP"
Info "ACR:               $ACR_NAME.azurecr.io"
Info "Backup image:      $ACR_NAME.azurecr.io/$BACKUP_REPOSITORY`:latest"
Info "Environment:       $ENVIRONMENT_NAME"
Info "PostgreSQL:        $POSTGRES_SERVER"
Info "Database:          $POSTGRES_DATABASE"
Info "Storage Account:   $STORAGE_ACCOUNT"
Info "Blob Container:    $BACKUP_CONTAINER"
Info "Backup Job:        $JOB_NAME"
Info "Managed Identity:  $IDENTITY_NAME"

# ============================================================
# Prerequisites / Login
# ============================================================

Section "Prerequisites"

if (
    -not (Get-Command az.cmd -ErrorAction SilentlyContinue) -and
    -not (Get-Command az -ErrorAction SilentlyContinue)
) {
    Fail "Azure CLI is not available"
    throw "Azure CLI is required."
}

Pass "Azure CLI available"

$accountResult = Invoke-AzureCLI @(
    "account", "show", "--output", "json"
)

if ($accountResult.ExitCode -ne 0) {
    Fail "Azure login required"

    if ($accountResult.Error) {
        Write-Host $accountResult.Error -ForegroundColor Red
    }

    throw "Run 'az login' first."
}

$account = $accountResult.Output | ConvertFrom-Json

Pass "Azure login"
Info "Subscription:     $($account.name)"
Info "Subscription ID: $($account.id)"
Info "Tenant ID:        $($account.tenantId)"
Info "User:             $($account.user.name)"

# ============================================================
# PostgreSQL
# ============================================================

Section "PostgreSQL Server"

$server = Get-AzureJson @(
    "postgres",
    "flexible-server",
    "show",
    "--name", $POSTGRES_SERVER,
    "--resource-group", $RESOURCE_GROUP,
    "--output", "json"
) "PostgreSQL server '$POSTGRES_SERVER' was not found."

if ($server.state -ne "Ready") {
    Fail "PostgreSQL server is not Ready"
    throw "PostgreSQL server state: $($server.state)"
}

$POSTGRES_FQDN = [string]$server.fullyQualifiedDomainName

Pass "PostgreSQL server is Ready"
Info "FQDN: $POSTGRES_FQDN"

# ============================================================
# ACR
# ============================================================

Section "Azure Container Registry"

$acr = Get-AzureJson @(
    "acr", "show",
    "--name", $ACR_NAME,
    "--resource-group", $RESOURCE_GROUP,
    "--output", "json"
) "ACR '$ACR_NAME' was not found."

$ACR_ID = [string]$acr.id
$ACR_LOGIN_SERVER = [string]$acr.loginServer

if ([string]::IsNullOrWhiteSpace($ACR_LOGIN_SERVER)) {
    $ACR_LOGIN_SERVER = "$ACR_NAME.azurecr.io"
}

Pass "ACR exists"
Info "Login server: $ACR_LOGIN_SERVER"

# ============================================================
# Backup image
# ============================================================

Section "Backup Docker Image"

$repository = Invoke-AzureCLI @(
    "acr",
    "repository",
    "show",
    "--name", $ACR_NAME,
    "--repository", $BACKUP_REPOSITORY,
    "--output", "json"
)

if ($repository.ExitCode -ne 0) {
    Fail "Repository '$BACKUP_REPOSITORY' not found"

    if ($repository.Error) {
        Write-Host $repository.Error -ForegroundColor Red
    }

    throw "Docker repository does not exist."
}

$tagsResult = Invoke-AzureCLI @(
    "acr",
    "repository",
    "show-tags",
    "--name", $ACR_NAME,
    "--repository", $BACKUP_REPOSITORY,
    "--output", "tsv"
)

if ($tagsResult.ExitCode -ne 0) {
    Fail "Could not read Docker image tags"
    throw "Could not verify backup image."
}

$tags = @(
    $tagsResult.Output -split "`r?`n" |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ }
)

if ($tags -notcontains "latest") {
    Fail "Tag 'latest' was not found"

    if ($tags.Count) {
        Info "Available tags: $($tags -join ', ')"
    }

    throw "Backup image does not exist."
}

$BACKUP_IMAGE = "$ACR_LOGIN_SERVER/$BACKUP_REPOSITORY`:latest"

Pass "Backup Docker image exists"
Info "Image: $BACKUP_IMAGE"

# ============================================================
# Storage Account
# ============================================================

Section "Backup Storage"

$storageResult = Invoke-AzureCLI @(
    "storage", "account", "show",
    "--name", $STORAGE_ACCOUNT,
    "--resource-group", $RESOURCE_GROUP,
    "--output", "json"
)

if ($storageResult.ExitCode -eq 0) {
    $storage = $storageResult.Output | ConvertFrom-Json
    Pass "Storage Account exists"
}
else {
    Info "Storage Account does not exist"
    Info "Creating Storage Account..."

    $createStorage = Invoke-AzureCLI @(
        "storage", "account", "create",
        "--name", $STORAGE_ACCOUNT,
        "--resource-group", $RESOURCE_GROUP,
        "--location", $LOCATION,
        "--sku", "Standard_LRS",
        "--kind", "StorageV2",
        "--allow-blob-public-access", "false",
        "--min-tls-version", "TLS1_2",
        "--output", "json"
    )

    if ($createStorage.ExitCode -ne 0) {
        Fail "Storage Account creation failed"
        Write-Host $createStorage.Error -ForegroundColor Red
        throw "Storage Account creation failed."
    }

    $storage = $createStorage.Output | ConvertFrom-Json
    Pass "Storage Account created"
}

$STORAGE_ID = [string]$storage.id

# ============================================================
# Blob Container
# ============================================================

Section "Blob Container"

$container = Invoke-AzureCLI @(
    "storage", "container", "show",
    "--name", $BACKUP_CONTAINER,
    "--account-name", $STORAGE_ACCOUNT,
    "--auth-mode", "login",
    "--output", "json"
)

if ($container.ExitCode -eq 0) {
    Pass "Blob Container exists"
}
else {
    Info "Creating Blob Container..."

    $createContainer = Invoke-AzureCLI @(
        "storage", "container", "create",
        "--name", $BACKUP_CONTAINER,
        "--account-name", $STORAGE_ACCOUNT,
        "--auth-mode", "login",
        "--public-access", "off",
        "--output", "none"
    )

    if ($createContainer.ExitCode -ne 0) {
        Fail "Blob Container creation failed"
        Write-Host $createContainer.Error -ForegroundColor Red
        throw "Blob Container creation failed."
    }

    Pass "Blob Container created"
}

# ============================================================
# Managed Identity
# ============================================================

Section "Managed Identity"

$identityResult = Invoke-AzureCLI @(
    "identity", "show",
    "--name", $IDENTITY_NAME,
    "--resource-group", $RESOURCE_GROUP,
    "--output", "json"
)

if ($identityResult.ExitCode -eq 0) {
    $identity = $identityResult.Output | ConvertFrom-Json
    Pass "Managed Identity exists"
}
else {
    Info "Creating Managed Identity..."

    $identityResult = Invoke-AzureCLI @(
        "identity", "create",
        "--name", $IDENTITY_NAME,
        "--resource-group", $RESOURCE_GROUP,
        "--location", $LOCATION,
        "--output", "json"
    )

    if ($identityResult.ExitCode -ne 0) {
        Fail "Managed Identity creation failed"
        Write-Host $identityResult.Error -ForegroundColor Red
        throw "Managed Identity creation failed."
    }

    $identity = $identityResult.Output | ConvertFrom-Json

    Pass "Managed Identity created"

    Info "Waiting for identity propagation..."
    Start-Sleep -Seconds 15
}

$IDENTITY_ID = [string]$identity.id
$PRINCIPAL_ID = [string]$identity.principalId
$CLIENT_ID = [string]$identity.clientId

if (
    [string]::IsNullOrWhiteSpace($CLIENT_ID) -or
    [string]::IsNullOrWhiteSpace($PRINCIPAL_ID)
) {
    $identity = Get-AzureJson @(
        "identity", "show",
        "--name", $IDENTITY_NAME,
        "--resource-group", $RESOURCE_GROUP,
        "--output", "json"
    ) "Could not read Managed Identity."

    $IDENTITY_ID = [string]$identity.id
    $PRINCIPAL_ID = [string]$identity.principalId
    $CLIENT_ID = [string]$identity.clientId
}

Info "Identity ID:  $IDENTITY_ID"
Info "Principal ID: $PRINCIPAL_ID"
Info "Client ID:    $CLIENT_ID"

Pass "Managed Identity information loaded"

# ============================================================
# ACR Role
# ============================================================

Section "ACR Permissions"

$acrRole = Invoke-AzureCLI @(
    "role", "assignment", "list",
    "--assignee-object-id", $PRINCIPAL_ID,
    "--scope", $ACR_ID,
    "--role", "AcrPull",
    "--query", "[].id",
    "--output", "tsv"
)

if (
    $acrRole.ExitCode -eq 0 -and
    $acrRole.Output.Trim()
) {
    Pass "AcrPull already assigned"
}
else {
    Info "Assigning AcrPull..."

    $result = Invoke-AzureCLI @(
        "role", "assignment", "create",
        "--assignee-object-id", $PRINCIPAL_ID,
        "--assignee-principal-type", "ServicePrincipal",
        "--role", "AcrPull",
        "--scope", $ACR_ID,
        "--output", "none"
    )

    if ($result.ExitCode -ne 0) {
        Fail "AcrPull assignment failed"
        Write-Host $result.Error -ForegroundColor Red
        throw "AcrPull assignment failed."
    }

    Pass "AcrPull assigned"

    Info "Waiting for RBAC propagation..."
    Start-Sleep -Seconds 20
}

# ============================================================
# Storage Role for Job
# ============================================================

Section "Storage Permissions"

$storageRole = Invoke-AzureCLI @(
    "role", "assignment", "list",
    "--assignee-object-id", $PRINCIPAL_ID,
    "--scope", $STORAGE_ID,
    "--role", "Storage Blob Data Contributor",
    "--query", "[].id",
    "--output", "tsv"
)

if (
    $storageRole.ExitCode -eq 0 -and
    $storageRole.Output.Trim()
) {
    Pass "Storage Blob Data Contributor already assigned"
}
else {
    Info "Assigning Storage Blob Data Contributor..."

    $result = Invoke-AzureCLI @(
        "role", "assignment", "create",
        "--assignee-object-id", $PRINCIPAL_ID,
        "--assignee-principal-type", "ServicePrincipal",
        "--role", "Storage Blob Data Contributor",
        "--scope", $STORAGE_ID,
        "--output", "none"
    )

    if ($result.ExitCode -ne 0) {
        Fail "Storage role assignment failed"
        Write-Host $result.Error -ForegroundColor Red
        throw "Storage role assignment failed."
    }

    Pass "Storage Blob Data Contributor assigned"

    Info "Waiting for RBAC propagation..."
    Start-Sleep -Seconds 20
}

# ============================================================
# Current User Storage Reader
# ============================================================

Section "Storage Verification Permissions"

$currentUser = Get-AzureJson @(
    "ad",
    "signed-in-user",
    "show",
    "--output", "json"
) "Could not determine current Azure user."

$CURRENT_USER_OBJECT_ID = [string]$currentUser.id
$CURRENT_USER_UPN = [string]$currentUser.userPrincipalName

Pass "Current Azure user detected"
Info "User:      $CURRENT_USER_UPN"
Info "Object ID: $CURRENT_USER_OBJECT_ID"

$currentRole = Invoke-AzureCLI @(
    "role", "assignment", "list",
    "--assignee-object-id", $CURRENT_USER_OBJECT_ID,
    "--scope", $STORAGE_ID,
    "--role", "Storage Blob Data Reader",
    "--query", "[].id",
    "--output", "tsv"
)

if (
    $currentRole.ExitCode -eq 0 -and
    $currentRole.Output.Trim()
) {
    Pass "Storage Blob Data Reader already assigned"
}
else {
    Info "Assigning Storage Blob Data Reader..."

    $result = Invoke-AzureCLI @(
        "role", "assignment", "create",
        "--assignee-object-id", $CURRENT_USER_OBJECT_ID,
        "--assignee-principal-type", "User",
        "--role", "Storage Blob Data Reader",
        "--scope", $STORAGE_ID,
        "--output", "none"
    )

    if ($result.ExitCode -ne 0) {
        Fail "Storage Blob Data Reader assignment failed"
        Write-Host $result.Error -ForegroundColor Red
        throw "Storage Blob Data Reader assignment failed."
    }

    Pass "Storage Blob Data Reader assigned"

    Info "Waiting for RBAC propagation..."
    Start-Sleep -Seconds 20
}

# ============================================================
# Database Password
# ============================================================

Section "Database Credentials"

Write-Host ""
Write-Host "PostgreSQL password is required." -ForegroundColor Yellow
Write-Host "The password and DATABASE_URL will not be displayed." -ForegroundColor Yellow
Write-Host ""

$securePassword = Read-Host `
    "PostgreSQL password for $POSTGRES_ADMIN" `
    -AsSecureString

$plainPassword = [Net.NetworkCredential]::new(
    "",
    $securePassword
).Password

if ([string]::IsNullOrWhiteSpace($plainPassword)) {
    Fail "PostgreSQL password was not provided"
    throw "Password is required."
}

$encodedPassword = [Uri]::EscapeDataString($plainPassword)

$databaseUrl =
    "postgresql://${POSTGRES_ADMIN}:${encodedPassword}@${POSTGRES_FQDN}:5432/${POSTGRES_DATABASE}?sslmode=require"

Pass "DATABASE_URL generated"

# ============================================================
# Container Apps Environment
# ============================================================

Section "Container Apps Environment"

$environmentResult = Invoke-AzureCLI @(
    "containerapp", "env", "show",
    "--name", $ENVIRONMENT_NAME,
    "--resource-group", $RESOURCE_GROUP,
    "--query", "id",
    "--output", "tsv"
)

if ($environmentResult.ExitCode -ne 0) {
    Fail "Container Apps Environment not found"
    Write-Host $environmentResult.Error -ForegroundColor Red
    throw "Container Apps Environment '$ENVIRONMENT_NAME' was not found."
}

$ENVIRONMENT_ID = $environmentResult.Output.Trim()

Pass "Container Apps Environment exists"
Info "Environment ID: $ENVIRONMENT_ID"

# ============================================================
# Remove old Job
# ============================================================

Section "Container Apps Job"

$existingJob = Invoke-AzureCLI @(
    "containerapp", "job", "show",
    "--name", $JOB_NAME,
    "--resource-group", $RESOURCE_GROUP,
    "--output", "json"
)

if ($existingJob.ExitCode -eq 0) {

    Info "Removing existing backup Job..."

    $deleteJob = Invoke-AzureCLI @(
        "containerapp", "job", "delete",
        "--name", $JOB_NAME,
        "--resource-group", $RESOURCE_GROUP,
        "--yes"
    )

    if ($deleteJob.ExitCode -ne 0) {
        Fail "Could not remove existing Job"
        Write-Host $deleteJob.Error -ForegroundColor Red
        throw "Could not remove existing Job."
    }

    Pass "Existing backup Job removed"

    Start-Sleep -Seconds 10
}
else {
    Info "Container Apps Job does not exist"
}

# ============================================================
# Create Job
# ============================================================

Section "Create Container Apps Job"

Info "Creating backup Job..."

$jobArguments = @(
    "containerapp", "job", "create",

    "--name", $JOB_NAME,
    "--resource-group", $RESOURCE_GROUP,
    "--environment", $ENVIRONMENT_ID,

    "--trigger-type", "Manual",

    "--image", $BACKUP_IMAGE,
    "--container-name", "postgres-backup",

    "--cpu", "0.5",
    "--memory", "1Gi",

    "--replica-timeout", "1800",
    "--replica-retry-limit", "0",
    "--replica-completion-count", "1",
    "--parallelism", "1",

    "--mi-user-assigned", $IDENTITY_ID,

    "--registry-server", $ACR_LOGIN_SERVER,
    "--registry-identity", $IDENTITY_ID,

    "--secrets",
    "database-url=$databaseUrl",

    "--env-vars",
    "DATABASE_URL=secretref:database-url",
    "AZURE_CLIENT_ID=$CLIENT_ID",
    "STORAGE_ACCOUNT=$STORAGE_ACCOUNT",
    "BACKUP_CONTAINER=$BACKUP_CONTAINER",

    "--output", "none"
)

$jobCreate = Invoke-AzureCLI $jobArguments

if ($jobCreate.ExitCode -ne 0) {
    Fail "Container Apps Job creation failed"

    if ($jobCreate.Error) {
        Write-Host $jobCreate.Error -ForegroundColor Red
    }

    throw "Container Apps Job creation failed."
}

Pass "Container Apps Job created"

# ============================================================
# Verify Job
# ============================================================

Section "Verify Job Configuration"

$job = Get-AzureJson @(
    "containerapp", "job", "show",
    "--name", $JOB_NAME,
    "--resource-group", $RESOURCE_GROUP,
    "--output", "json"
) "Could not verify Container Apps Job."

# Managed Identity
$jobIdentityIds = @()

if ($job.identity.userAssignedIdentities) {
    $jobIdentityIds = @(
        $job.identity.userAssignedIdentities.PSObject.Properties |
        ForEach-Object { $_.Name }
    )
}

if ($jobIdentityIds -contains $IDENTITY_ID) {
    Pass "Managed Identity attached"
}
else {
    Fail "Managed Identity is not attached"
    throw "Managed Identity verification failed."
}

# Environment variables
$jobEnv = @(
    $job.properties.template.containers[0].env
)

$clientIdEnv = $jobEnv |
    Where-Object { $_.name -eq "AZURE_CLIENT_ID" } |
    Select-Object -First 1

if (
    $null -eq $clientIdEnv -or
    [string]::IsNullOrWhiteSpace($clientIdEnv.value)
) {
    Fail "AZURE_CLIENT_ID is missing"
    throw "AZURE_CLIENT_ID verification failed."
}

if ($clientIdEnv.value -ne $CLIENT_ID) {
    Fail "AZURE_CLIENT_ID does not match Managed Identity"
    throw "AZURE_CLIENT_ID verification failed."
}

Pass "AZURE_CLIENT_ID configured correctly"

# DATABASE_URL
$databaseEnv = $jobEnv |
    Where-Object { $_.name -eq "DATABASE_URL" } |
    Select-Object -First 1

if (
    $null -eq $databaseEnv -or
    $databaseEnv.secretRef -ne "database-url"
) {
    Fail "DATABASE_URL secret reference is incorrect"
    throw "DATABASE_URL verification failed."
}

Pass "DATABASE_URL secret configured correctly"

# Clear credentials
$securePassword = $null
$plainPassword = $null
$encodedPassword = $null
$databaseUrl = $null

# ============================================================
# Start Backup
# ============================================================

Section "Backup"

Info "Starting backup Job..."

$jobStart = Invoke-AzureCLI @(
    "containerapp", "job", "start",
    "--name", $JOB_NAME,
    "--resource-group", $RESOURCE_GROUP,
    "--output", "json"
)

if ($jobStart.ExitCode -ne 0) {
    Fail "Backup Job failed to start"

    if ($jobStart.Error) {
        Write-Host $jobStart.Error -ForegroundColor Red
    }

    throw "Backup Job failed to start."
}

try {
    $startResponse = $jobStart.Output | ConvertFrom-Json
}
catch {
    Fail "Could not parse Job start response"
    Write-Host $jobStart.Output -ForegroundColor Yellow
    throw
}

$executionName = [string]$startResponse.name

if ([string]::IsNullOrWhiteSpace($executionName)) {

    if ($startResponse.properties.name) {
        $executionName = [string]$startResponse.properties.name
    }
}

if ([string]::IsNullOrWhiteSpace($executionName)) {
    Fail "Azure did not return the execution name"

    Write-Host ""
    Write-Host $jobStart.Output -ForegroundColor Yellow
    Write-Host ""

    throw "Could not determine Job execution name."
}

Pass "Backup Job started"

Info "Execution:       $executionName"
Info "PostgreSQL:       $POSTGRES_SERVER"
Info "Database:         $POSTGRES_DATABASE"
Info "Storage Account:  $STORAGE_ACCOUNT"
Info "Container:        $BACKUP_CONTAINER"

# ============================================================
# Wait for execution
# ============================================================

Section "Backup Execution"

Info "Waiting for execution: $executionName"

$maxAttempts = 90
$completed = $false
$succeeded = $false

for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {

    Start-Sleep -Seconds 5

    Info "Checking execution... ($attempt/$maxAttempts)"

    $executionResult = Invoke-AzureCLI @(
        "containerapp", "job", "execution", "show",
        "--name", $JOB_NAME,
        "--resource-group", $RESOURCE_GROUP,
        "--job-execution-name", $executionName,
        "--output", "json"
    )

    if ($executionResult.ExitCode -ne 0) {
        Info "Execution information temporarily unavailable..."
        continue
    }

    try {
        $execution = $executionResult.Output | ConvertFrom-Json
    }
    catch {
        Info "Could not parse execution information..."
        continue
    }

    $status = [string]$execution.properties.status

    Info "Execution: $executionName"
    Info "Status:    $(if ($status) { $status } else { 'unavailable' })"

    switch -Regex ($status) {

        "Succeeded|Completed" {
            $completed = $true
            $succeeded = $true

            Pass "Execution completed successfully"
            break
        }

        "Failed|Error" {
            $completed = $true
            $succeeded = $false

            Fail "Execution failed"
            break
        }

        "Running|Processing|Activating|Pending|Scheduled|Starting" {
            Info "Execution is still running..."
        }

        default {
            Info "Execution is in state: $status"
        }
    }

    if ($completed) {
        break
    }
}

# ============================================================
# Timeout
# ============================================================

if (-not $completed) {

    Section "Backup Submitted"

    Pass "Backup Job is still running"

    Info "Timeout after $maxAttempts checks."
    Info "Execution: $executionName"
    Info "Azure Job continues running."

    Write-Host ""

    Info "Check execution with:"

    Write-Host `
        "az containerapp job execution show --name $JOB_NAME --resource-group $RESOURCE_GROUP --job-execution-name $executionName -o json" `
        -ForegroundColor Yellow

    Write-Host ""

    Info "Check logs with:"

    Write-Host `
        "az containerapp job logs show --name $JOB_NAME --resource-group $RESOURCE_GROUP --execution $executionName --container postgres-backup --tail 200" `
        -ForegroundColor Yellow

    exit 0
}

# ============================================================
# Failure logs
# ============================================================

if (-not $succeeded) {

    Section "Backup Failed"

    Fail "Container Apps Job execution failed"
    Info "Execution: $executionName"

    Write-Host ""
    Info "Retrieving execution logs..."

    $logs = Invoke-AzureCLI @(
        "containerapp", "job", "logs", "show",
        "--name", $JOB_NAME,
        "--resource-group", $RESOURCE_GROUP,
        "--execution", $executionName,
        "--container", "postgres-backup",
        "--tail", "200"
    )

    if ($logs.ExitCode -eq 0) {

        Write-Host ""
        Write-Host "---------------- JOB LOGS ----------------" -ForegroundColor DarkGray

        if ($logs.Output) {
            Write-Host $logs.Output
        }

        Write-Host "------------------------------------------" -ForegroundColor DarkGray
    }
    else {

        Info "Could not retrieve Job logs."

        if ($logs.Error) {
            Write-Host $logs.Error -ForegroundColor Red
        }
    }

    Write-Host ""

    Info "Check execution with:"

    Write-Host `
        "az containerapp job execution show --name $JOB_NAME --resource-group $RESOURCE_GROUP --job-execution-name $executionName -o json" `
        -ForegroundColor Yellow

    Write-Host ""

    Info "Check logs with:"

    Write-Host `
        "az containerapp job logs show --name $JOB_NAME --resource-group $RESOURCE_GROUP --execution $executionName --container postgres-backup --tail 200" `
        -ForegroundColor Yellow

    exit 1
}



# ============================================================
# Verify Backup
# ============================================================

Section "Verify Backup"

Info "Checking Azure Blob Storage..."

# ------------------------------------------------------------
# Get backup Blob names
# ------------------------------------------------------------

$blobResult = Invoke-AzureCLI @(
    "storage",
    "blob",
    "list",
    "--account-name", $STORAGE_ACCOUNT,
    "--container-name", $BACKUP_CONTAINER,
    "--prefix", "backups/",
    "--auth-mode", "login",
    "--query", "[].name",
    "--output", "tsv"
)

if ($blobResult.ExitCode -ne 0) {
    Fail "Could not verify backup Blob"

    if ($blobResult.Error) {
        Write-Host $blobResult.Error -ForegroundColor Red
    }

    exit 1
}

if ([string]::IsNullOrWhiteSpace($blobResult.Output)) {
    Fail "No backup Blobs found"
    exit 1
}

# ------------------------------------------------------------
# Convert output to individual Blob names
# ------------------------------------------------------------

$blobNames = @(
    $blobResult.Output -split "`r?`n" |
    ForEach-Object { $_.Trim() } |
    Where-Object {
        $_ -match '^backups/tasks_\d{8}-\d{6}\.dump$'
    }
)

if ($blobNames.Count -eq 0) {
    Fail "No valid backup Blob was found"
    exit 1
}

# ------------------------------------------------------------
# Newest backup
#
# Filename format:
# tasks_YYYYMMDD-HHMMSS.dump
#
# Therefore alphabetical order = chronological order.
# ------------------------------------------------------------

$latestBlobName =
    $blobNames |
    Sort-Object -Descending |
    Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($latestBlobName)) {
    Fail "Could not determine the latest backup Blob"
    exit 1
}

# ------------------------------------------------------------
# Get size of the latest Blob
# ------------------------------------------------------------

$blobInfoResult = Invoke-AzureCLI @(
    "storage",
    "blob",
    "show",
    "--account-name", $STORAGE_ACCOUNT,
    "--container-name", $BACKUP_CONTAINER,
    "--name", $latestBlobName,
    "--auth-mode", "login",
    "--query", "properties.contentLength",
    "--output", "tsv"
)

if ($blobInfoResult.ExitCode -ne 0) {
    Fail "Backup Blob was found but its size could not be read"

    if ($blobInfoResult.Error) {
        Write-Host $blobInfoResult.Error -ForegroundColor Red
    }

    exit 1
}

Pass "Backup Blob found"

Info "Blob: $latestBlobName"

if (-not [string]::IsNullOrWhiteSpace($blobInfoResult.Output)) {

    $blobSize = 0L

    if ([long]::TryParse(
        $blobInfoResult.Output.Trim(),
        [ref]$blobSize
    )) {

        $sizeMB = [math]::Round(
            $blobSize / 1MB,
            2
        )

        Info "Size: $sizeMB MB"
    }
}

# ============================================================
# Completed
# ============================================================

Section "Backup Completed"

Pass "PostgreSQL backup completed successfully"

Info "Backup is stored entirely in Azure."
Info "PostgreSQL:      $POSTGRES_SERVER"
Info "Database:         $POSTGRES_DATABASE"
Info "Storage Account:  $STORAGE_ACCOUNT"
Info "Container:        $BACKUP_CONTAINER"
Info "Blob:             $latestBlobName"
Info "Managed Identity: $IDENTITY_NAME"
Info "Client ID:        $CLIENT_ID"

Write-Host ""

Write-Host "============================================================" -ForegroundColor Green
Write-Host " BACKUP SUCCESSFUL" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
