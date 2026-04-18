# 1. Check for Admin Privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as Administrator. Elevation required."
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 8. Set Script Directory
$scriptDirectory = Split-Path -Parent $MyBaseName

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
    Load-Module $module
}

# 6. Install Drivers
Write-Host "Installing drivers via PSWindowsUpdate..." -ForegroundColor Cyan
Install-WindowsUpdate -Category "Drivers" -NotTitle "preview" -AcceptAll -IgnoreReboot

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

# 7. WinUtil Shim
Write-Host "Launching Windows Utility..." -ForegroundColor Cyan
Invoke-WebRequest https://christitus.com/win -UseBasicParsing | Invoke-Expression

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