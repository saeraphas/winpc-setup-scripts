# 1. Check for Admin Privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as Administrator. Elevation required."
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 8. Set Script Directory
$scriptDirectory = $PSScriptRoot

# 2. Prompt for Machine Name
$newName = Read-Host "Enter the new Computer Name (or press Enter to skip)"
if ($newName) {
    Write-Host "Setting computer name to $newName..." -ForegroundColor Cyan
    Rename-Computer -NewName $newName -ErrorAction SilentlyContinue
}

# 3, 4, & 5. Module Setup & WinGet Prep
Write-Host "Preparing package managers and modules..." -ForegroundColor Cyan
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
$modules = @("Microsoft.WinGet.Client", "PSWindowsUpdate")
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable $module)) {
        Install-Module $module -Force -AllowClobber
    }
    Import-Module $module
}

Set-MpPreference -EnableVulnerableDriverBlocklist $false

# 6. Install Drivers
Write-Host "Installing drivers via PSWindowsUpdate..." -ForegroundColor Cyan
Install-WindowsUpdate -Category "Drivers" -NotTitle "preview" -AcceptAll -IgnoreReboot

### --- Post-Driver Update Connectivity Check --- ###

$maxWaitSeconds = 300
$elapsedSeconds = 0
$retryInterval  = 10
$connectionEstablished = $false

Write-Host "Verifying internet connectivity via www.google.com..." -ForegroundColor Cyan

while ($elapsedSeconds -lt $maxWaitSeconds -and $connectionEstablished -eq $false) {
    
    # Using Test-NetConnection to check TCP availability (more reliable than ICMP/Ping)
    if (Test-NetConnection -ComputerName "www.google.com" -InformationLevel Quiet) {
        $connectionEstablished = $true
    } else {
        Write-Warning "No internet detected. Retrying in $retryInterval seconds... ($elapsedSeconds/$maxWaitSeconds)"
        Start-Sleep -Seconds $retryInterval
        $elapsedSeconds += $retryInterval
    }
}

# Ensure the UI is clean if a progress bar was used by other commands
Write-Progress -Activity "Checking Connection" -Completed

if (-not $connectionEstablished) {
    Write-Error "Critical: Internet connection could not be established within $maxWaitSeconds seconds. Aborting script."
    exit
}

Write-Host "Internet connection confirmed." -ForegroundColor Green


### --- WinGet Maintenance & Tool Launch --- ###

Write-Host "Repairing WinGet Package Manager..." -ForegroundColor Cyan
try {
    # Fixes manifest issues and stale COM objects after system changes
    Repair-WinGetPackageManager -Latest -Force -Verbose
} catch {
    Write-Warning "WinGet repair encountered a non-terminating error. Attempting to proceed..."
}

# New: WinGet Applications Installation
$apps = @(
    "Microsoft.PowerShell",
    "Microsoft.WindowsTerminal",
    "Brave.Brave",
    "7zip.7zip",
    "Realix.HWiNFO",
    "CPUID.CPU-Z",
    "TechPowerUp.GPU-Z",
    "Notepad++.Notepad++",
    "Ookla.Speedtest.CLI"
)

Write-Host "Installing software library via WinGet..." -ForegroundColor Cyan
foreach ($app in $apps) {
    Write-Host "Installing $app..." -ForegroundColor Yellow
    winget install --id $app --silent --accept-package-agreements --accept-source-agreements
}

Write-Host "Launching Chris Titus Tech Tool (Background Process)..." -ForegroundColor Green
# Start-Process without -Wait allows the script to continue immediately
Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"iwr -useb https://christitus.com/win | iex`""

# 9, 10, & 11. Chainload Sub-Scripts
$scriptsToRun = @(
    "New-EdgeConfiguration.ps1",
    "New-OpenShellStartMenuInstallation.ps1",
    "New-TightVNCInstallation.ps1",
    "New-StartMenuItemCleanup.ps1",
    "New-WindowsServiceCleanup.ps1",
    "New-NonStupidUpdate.ps1"
)

foreach ($script in $scriptsToRun) {
    $fullPath = Join-Path $scriptDirectory $script
    if (Test-Path $fullPath) {
        Write-Host "Chainloading: $script" -ForegroundColor Green
        & $fullPath
    }
}

Write-Host "Lab setup sequence complete." -ForegroundColor Green