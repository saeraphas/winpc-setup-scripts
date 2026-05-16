# 1. Check for Admin Privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as Administrator. Elevation required."
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 1. Unhide the Ultimate Performance scheme (in case it isn't active)
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61

# 2. Set it as the active power plan
powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61