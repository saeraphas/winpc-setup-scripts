# 1. Admin Privilege Check
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

# 2. Directory and Logging Setup
$organization = Join-Path $env:SystemDrive "Lab"
$activity = "Sunshine"
$deployment = Join-Path $organization $activity
$automationlog = Join-Path $deployment "automation.log"
$installationlog = Join-Path $deployment "installation.log"

if (-not (Test-Path $deployment)) { New-Item -Path $deployment -ItemType Directory -Force | Out-Null }

# Start logging script output
Start-Transcript -Path $automationlog -Append

try {
    # 3. Secure Password Prompt
    $sunshineUser = Read-Host -Prompt "Enter the Sunshine username"
    $sunshinePass = Read-Host -Prompt "Enter the Sunshine password" -AsSecureString

    # Convert SecureString to plain text for Sunshine CLI compatibility
    $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sunshinePass))

    # 4. Application and Path Variables
    $applicationID = "LizardByte.Sunshine"
    $process = "C:\Program Files\Sunshine\sunshine.exe"
    $tcpPorts = @("47984", "47989", "48010")
    $udpPorts = @("47998", "47999", "48000", "48002", "48010") 

    # 5. Install or Upgrade via winget
    Write-Output "Processing $applicationID via WinGet..."
    if (-not ((winget list --id $applicationID --exact).id -contains $applicationID)) { 
        winget install --id $applicationID --silent --accept-source-agreements --accept-package-agreements --log $installationlog
    } else { 
        winget upgrade --id $applicationID --silent --log $installationlog
    }

    # 6. Set Credentials
    Write-Output "Configuring credentials..."
    $arguments = @("--creds", $sunshineUser, $password)
    Start-Process $process -ArgumentList $arguments -Wait -WindowStyle Hidden

    # 7. Firewall Configuration
    Write-Output "Applying Firewall Rules..."

    # Get the currently active firewall profile(s)
    $activeProfiles = (Get-NetFirewallProfile | Where-Object { $_.Enabled -eq $true }).Name

    # Loop through each port and create an allow rule for the specified process
    foreach ($port in $tcpPorts) { New-NetFirewallRule -DisplayName "Allow $activity on TCP $port" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow -Enabled True -Profile $activeProfiles -Program $process -ErrorAction SilentlyContinue }
    foreach ($port in $udpPorts) { New-NetFirewallRule -DisplayName "Allow $activity on UDP $port" -Direction Inbound -Protocol UDP -LocalPort $port -Action Allow -Enabled True -Profile $activeProfiles -Program $process -ErrorAction SilentlyContinue }

    $success = $true
}
catch {
    Write-Error "An error occurred during the $activity deployment: $($_.Exception.Message)"
    $success = $false
}
finally {
    # Cleanup of sensitive plain-text password variable if it exists
    $password = $null
}

# 8. Post-Try Exit Output
Stop-Transcript

if ($success) {
    Write-Output "Deployment of $activity completed successfully." -ForegroundColor Green
} else {
    Write-Output "Deployment of $activity failed. Check $automationlog for details." -ForegroundColor Red
}