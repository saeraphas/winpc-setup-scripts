<#
.SYNOPSIS
    Automates the download, integrity verification, and silent installation of TightVNC 64-bit.

.DESCRIPTION
    This script performs an administrative privilege check, sets up a standardized logging environment in C:\Lab\TightVNC, 
    and handles the MSI installation with predefined configuration parameters. It includes a retry mechanism for downloads 
    and supports bypassing hash verification via a parameter flag.

.PARAMETER SkipHashChecking
    A switch parameter that, when present, bypasses the SHA256 checksum verification of the downloaded MSI.

.EXAMPLE
    .\New-TightVNCInstallation.ps1
    Standard execution with full hash verification.

.EXAMPLE
    .\New-TightVNCInstallation.ps1 -SkipHashChecking
    Execution bypassing the integrity check (use only if the official hash has changed or is unavailable).
#>

param (
    [Parameter(Mandatory=$false)]
    [switch]$SkipHashChecking
)

# 1. Admin Privilege Check
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

# 2. Directory and Logging Setup
$organization     = Join-Path $env:SystemDrive "Lab"
$activity         = "TightVNC"
$deployment       = Join-Path $organization $activity
$automationlog    = Join-Path $deployment "automation.log"
$installationlog  = Join-Path $deployment "installation.log"

if (-not (Test-Path $deployment)) {
    New-Item -Path $deployment -ItemType Directory -Force | Out-Null
}

# Start logging script output
Start-Transcript -Path $automationlog -Append

try {
    # 3. Secure Password Prompt
    $adminSecure = Read-Host -Prompt "Enter the admin password" -AsSecureString
    $vncSecure   = Read-Host -Prompt "Enter the VNC password" -AsSecureString

    # Convert to plain text for the MSI installer arguments
    $adminstring = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminSecure))
    $vncstring   = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($vncSecure))

    # 4. Configuration
    $URI = "https://www.tightvnc.com/download/2.8.85/tightvnc-2.8.85-gpl-setup-64bit.msi"
    $ExpectedHash = "D8FBED7B27EBAB86DF6F780F6E86F723668F3715CEE521CCAA4568812AEF5F3E"
    $localPath = Join-Path $deployment ($URI.Split('/')[-1])

    $MaxRetries = 3
    $Attempt = 0
    $Verified = $false

    # 5. Download & Verify Loop
    while (-not $Verified -and $Attempt -lt $MaxRetries) {
        $Attempt++
        
        # Ensure a clean state for the download attempt
        if (Test-Path $localPath) { 
            Remove-Item $localPath -Force 
        }

        Write-Host "Attempt ${Attempt}: Downloading installer..." -ForegroundColor Cyan
        
        $OldPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $URI -OutFile $localPath -ErrorAction Stop
        } catch {
            Write-Warning "Download failed: $($_.Exception.Message)"
            continue 
        } finally {
            $ProgressPreference = $OldPreference
        }

        # 5a. Conditional Hash Verification
        if ($SkipHashChecking) {
            Write-Host "SkipHashChecking flag detected. Bypassing integrity check." -ForegroundColor Yellow
            $Verified = $true
        } else {
            Write-Host "Verifying checksum..." -NoNewline
            $actualHash = (Get-FileHash $localPath -Algorithm SHA256).Hash
            
            if ($actualHash -eq $ExpectedHash) {
                Write-Host " [MATCH]" -ForegroundColor Green
                $Verified = $true
            } else {
                Write-Host " [MISMATCH]" -ForegroundColor Red
                Write-Warning "Hash mismatch."
            }
        }
    }

    if (-not $Verified) { throw "Failed to verify installer after $MaxRetries attempts." }

    # 6. Installation (Restored Tested Argument Array)
    Write-Host "Starting Installation (Logging to $installationlog)..." -ForegroundColor Yellow

    $msiexec = "msiexec.exe"
    $msipath = $localPath

    $installerArgs = @(
        "/i $($msipath)",
        "/qn",
        "/L*V `"$installationlog`"",
        "ADDLOCAL=Viewer,Server",
        "SET_USEVNCAUTHENTICATION=1",
        "VALUE_OF_USEVNCAUTHENTICATION=1",
        "SET_PASSWORD=1",
        "VALUE_OF_PASSWORD=$vncstring",
        "SET_USECONTROLAUTHENTICATION=1",
        "VALUE_OF_USECONTROLAUTHENTICATION=1",
        "SET_CONTROLPASSWORD=1",
        "VALUE_OF_CONTROLPASSWORD=$adminstring",
        "SET_ACCEPTHTTPCONNECTIONS=1",
        "VALUE_OF_ACCEPTHTTPCONNECTIONS=0",
        "SET_REMOVEWALLPAPER=1",
        "VALUE_OF_REMOVEWALLPAPER=1",
        "SET_GRABTRANSPARENTWINDOWS=1",
        "VALUE_OF_GRABTRANSPARENTWINDOWS=1",
        "REGISTER_SERVICE=1",
        "SHOW_SYSTRAY_ICON=1",
        "ALWAYSHARED=1"
    )

    $process = Start-Process -FilePath $msiexec -ArgumentList $installerArgs -Wait -NoNewWindow -PassThru

    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
        Write-Host "Finished successfully." -ForegroundColor Green
    } else {
        Write-Error "MSI exited with error code: $($process.ExitCode)"
    }

} catch {
    Write-Error "Script failed: $($_.Exception.Message)"
} finally {
    Stop-Transcript
}