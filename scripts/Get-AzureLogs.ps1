# ============================================================
# Azure Task Manager - Container App Logs
#
# Read-only script for viewing logs from Azure Container Apps.
#
# The script reads application names and the Resource Group
# from config.json.
#
# PARAMETERS
#
# -Config
#   Path to the Azure Task Manager configuration file.
#   By default, the script uses:
#
#       .\config.json
#
#   Example:
#
#       .\scripts\Get-AzureLogs.ps1 -Config .\config.json
#
#
# -App
#   Specifies which Container App logs should be displayed.
#
#   Available values:
#
#       backend   - show Backend Container App logs
#       frontend  - show Frontend Container App logs
#       all       - show logs from both applications
#
#   Default:
#
#       backend
#
#   Examples:
#
#       .\scripts\Get-AzureLogs.ps1 -App backend
#       .\scripts\Get-AzureLogs.ps1 -App frontend
#       .\scripts\Get-AzureLogs.ps1 -App all
#
#
# -Lines
#   Specifies how many of the most recent log lines should
#   be requested from Azure Container Apps.
#
#   Default:
#
#       50
#
#   Use a larger value when more historical log information
#   is required.
#
#   Examples:
#
#       .\scripts\Get-AzureLogs.ps1 -App backend -Lines 100
#       .\scripts\Get-AzureLogs.ps1 -App backend -Lines 500
#
#
# -Follow
#   Continuously displays new log entries as they are generated.
#
#   This is useful for monitoring an application in real time
#   while reproducing an error or testing a deployment.
#
#   Example:
#
#       .\scripts\Get-AzureLogs.ps1 -App backend -Follow
#
#
# -ErrorsOnly
#   Displays only log entries that appear to contain errors.
#
#   The filter searches for common error-related words such as:
#
#       error
#       exception
#       failed
#       failure
#       critical
#       fatal
#       traceback
#
#   This is useful when quickly searching for application
#   failures in a large amount of log output.
#
#   Example:
#
#       .\scripts\Get-AzureLogs.ps1 -App backend -ErrorsOnly
#
#
# COMBINING PARAMETERS
#
# Parameters can be combined when required.
#
# Example:
#
#   Display the latest 200 Backend log lines and show only
#   entries that appear to contain errors:
#
#       .\scripts\Get-AzureLogs.ps1 `
#           -App backend `
#           -Lines 200 `
#           -ErrorsOnly
#
#
#   Monitor Backend logs continuously:
#
#       .\scripts\Get-AzureLogs.ps1 `
#           -App backend `
#           -Follow
#
# ============================================================


param(
    [string]$Config = ".\config.json",

    [ValidateSet("backend", "frontend", "all")]
    [string]$App = "backend",

    [ValidateRange(1, 5000)]
    [int]$Lines = 50,

    [switch]$Follow,

    [switch]$ErrorsOnly
)

$ErrorActionPreference = "Stop"


# ============================================================
# Output helpers
# ============================================================

function Write-Section {
    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor DarkGray

    Write-Host " $Title" `
        -ForegroundColor Cyan

    Write-Host "============================================================" `
        -ForegroundColor DarkGray

    Write-Host ""
}


function Write-OK {
    param(
        [string]$Message
    )

    Write-Host "  [OK]      $Message" `
        -ForegroundColor Green
}


function Write-Failed {
    param(
        [string]$Message
    )

    Write-Host "  [FAILED]  $Message" `
        -ForegroundColor Red
}


function Write-Info {
    param(
        [string]$Message
    )

    Write-Host "  [INFO]    $Message" `
        -ForegroundColor DarkGray
}


# ============================================================
# Check command availability
# ============================================================

function Test-CommandExists {
    param(
        [string]$Command
    )

    return $null -ne (
        Get-Command $Command `
            -ErrorAction SilentlyContinue
    )
}


# ============================================================
# Check Container App
# ============================================================

function Test-ContainerAppExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName
    )

    $oldPreference = $ErrorActionPreference

    $ErrorActionPreference = "SilentlyContinue"

    try {

        & az containerapp show `
            --name $AppName `
            --resource-group $RESOURCE_GROUP `
            *> $null

        return $LASTEXITCODE -eq 0
    }
    finally {

        $ErrorActionPreference = $oldPreference
    }
}


# ============================================================
# Display Container App logs
# ============================================================

function Show-ContainerAppLogs {

    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    Write-Section "$DisplayName Container App Logs"

    Write-Info "Application:   $AppName"
    Write-Info "Resource Group: $RESOURCE_GROUP"
    Write-Info "Lines:         $Lines"

    if ($Follow) {
        Write-Info "Mode:          Follow"
    }
    else {
        Write-Info "Mode:          Snapshot"
    }

    if ($ErrorsOnly) {
        Write-Info "Filter:        Errors only"
    }

    Write-Host ""

    # --------------------------------------------------------
    # Verify Container App
    # --------------------------------------------------------

    if (-not (Test-ContainerAppExists $AppName)) {

        Write-Failed `
            "Container App '$AppName' was not found."

        return $false
    }

    Write-OK "Container App exists"


    # --------------------------------------------------------
    # Build Azure CLI command
    # --------------------------------------------------------

    $arguments = @(
        "containerapp",
        "logs",
        "show",
        "--name",
        $AppName,
        "--resource-group",
        $RESOURCE_GROUP,
        "--tail",
        "$Lines"
    )

    if ($Follow) {

        $arguments += "--follow"
    }


    # --------------------------------------------------------
    # Retrieve logs
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "------------------------------------------------------------" `
        -ForegroundColor DarkGray

    Write-Host " Logs" `
        -ForegroundColor Cyan

    Write-Host "------------------------------------------------------------" `
        -ForegroundColor DarkGray

    Write-Host ""

    try {

        # In Follow mode Azure CLI continuously writes to the
        # console until the user interrupts the process.
        #
        # Ctrl+C is handled by the console and stops the
        # Azure CLI log stream.

        if ($Follow) {

            & az @arguments

            return ($LASTEXITCODE -eq 0)
        }


        # ----------------------------------------------------
        # Snapshot mode
        # ----------------------------------------------------

        $logs = & az @arguments 2>&1

        if ($LASTEXITCODE -ne 0) {

            Write-Failed `
                "Azure CLI could not retrieve logs."

            foreach ($line in $logs) {

                Write-Host "  $line" `
                    -ForegroundColor Red
            }

            return $false
        }


        if (-not $logs) {

            Write-Info "No logs returned."

            return $true
        }


        # ----------------------------------------------------
        # Error filtering
        # ----------------------------------------------------

        if ($ErrorsOnly) {

            $logs = $logs | Where-Object {

                $_ -match `
                    "(?i)error|exception|failed|failure|critical|fatal|traceback"
            }

            if (-not $logs) {

                Write-OK `
                    "No obvious errors found in the returned logs."

                return $true
            }
        }


        # ----------------------------------------------------
        # Display logs
        # ----------------------------------------------------

        foreach ($line in $logs) {

            $text = [string]$line

            if ($text -match `
                "(?i)error|exception|failed|failure|critical|fatal|traceback") {

                Write-Host $text `
                    -ForegroundColor Red
            }
            elseif ($text -match `
                "(?i)warning|warn") {

                Write-Host $text `
                    -ForegroundColor Yellow
            }
            else {

                Write-Host $text
            }
        }

        return $true
    }
    catch {

        Write-Failed "Failed to retrieve logs."

        Write-Info $_.Exception.Message

        return $false
    }
}


# ============================================================
# Load configuration
# ============================================================

Write-Section "Azure Task Manager - Container App Logs"

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
}
catch {

    throw "Could not parse configuration file: $Config"
}


# ============================================================
# Configuration values
# ============================================================

$RESOURCE_GROUP = $configData.resourceGroup

$BACKEND_APP = $configData.backendApp

$FRONTEND_APP = $configData.frontendApp


# ============================================================
# Validate configuration
# ============================================================

$requiredConfiguration = @{
    "resourceGroup" = $RESOURCE_GROUP
    "backendApp"    = $BACKEND_APP
    "frontendApp"   = $FRONTEND_APP
}

foreach ($item in $requiredConfiguration.GetEnumerator()) {

    if ([string]::IsNullOrWhiteSpace($item.Value)) {

        throw `
            "Missing required configuration value: $($item.Key)"
    }
}

Write-OK "Configuration loaded"

Write-Info "Resource Group: $RESOURCE_GROUP"
Write-Info "Backend App:    $BACKEND_APP"
Write-Info "Frontend App:   $FRONTEND_APP"


# ============================================================
# Prerequisites
# ============================================================

Write-Section "Prerequisites"

if (-not (Test-CommandExists "az")) {

    Write-Failed `
        "Azure CLI is not installed or not available in PATH"

    throw "Azure CLI is required."
}

Write-OK "Azure CLI available"


# ============================================================
# Azure account
# ============================================================

Write-Section "Azure Account"

$account = $null

try {

    $account = az account show `
        --output json `
        2>$null |
        ConvertFrom-Json
}
catch {

    $account = $null
}

if (-not $account) {

    Write-Failed "Azure CLI is not logged in."

    Write-Host ""
    Write-Host "Run:" `
        -ForegroundColor Yellow

    Write-Host "  az login" `
        -ForegroundColor White

    Write-Host ""

    exit 1
}

Write-OK "Azure login"

Write-Info "User:         $($account.user.name)"
Write-Info "Subscription: $($account.name)"
Write-Info "ID:           $($account.id)"


# ============================================================
# Selected log configuration
# ============================================================

Write-Section "Log Configuration"

Write-Info "Application: $App"
Write-Info "Lines:       $Lines"

if ($Follow) {

    Write-Info "Follow:      enabled"
}
else {

    Write-Info "Follow:      disabled"
}

if ($ErrorsOnly) {

    Write-Info "Errors only: enabled"
}
else {

    Write-Info "Errors only: disabled"
}


# ============================================================
# Execute
# ============================================================

switch ($App) {

    "backend" {

        Show-ContainerAppLogs `
            -AppName $BACKEND_APP `
            -DisplayName "Backend"
    }


    "frontend" {

        Show-ContainerAppLogs `
            -AppName $FRONTEND_APP `
            -DisplayName "Frontend"
    }


    "all" {

        if ($Follow) {

            Write-Host ""

            Write-Info `
                "Follow mode with -App all starts with Backend."

            Write-Info `
                "Press Ctrl+C to stop log streaming."

            Write-Host ""

            Show-ContainerAppLogs `
                -AppName $BACKEND_APP `
                -DisplayName "Backend"

        }
        else {

            Show-ContainerAppLogs `
                -AppName $BACKEND_APP `
                -DisplayName "Backend"

            Show-ContainerAppLogs `
                -AppName $FRONTEND_APP `
                -DisplayName "Frontend"
        }
    }
}


# ============================================================
# Completed
# ============================================================

if (-not $Follow) {

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor DarkGray

    Write-Host " Log check completed " `
        -ForegroundColor Green

    Write-Host "============================================================" `
        -ForegroundColor DarkGray

    Write-Host ""
}