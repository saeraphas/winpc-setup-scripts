# Ensure Admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run as Administrator."
    Exit
}

$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$Paths = @($RegPath, "$RegPath\ExtensionInstallForcelist", "$RegPath\RestoreOnStartupURLs")

foreach ($P in $Paths) { if (-not (Test-Path $P)) { New-Item $P -Force | Out-Null } }

$Policies = @{
    # PASSWORD & REWARDS
    "PasswordManagerEnabled"       = 0
    "MicrosoftRewardsUserStatusEnabled" = 0
    
    # BROWSER CHECKS & PROMPTS
    "DefaultBrowserSettingEnabled" = 0
    "HideFirstRunExperience"       = 1
    "BrowserSignin"                = 0
    "BrowserAddProfileEnabled"     = 0
    
    # STARTUP & NAVIGATION
    "RestoreOnStartup"             = 4
    "HomepageLocation"             = "about:blank"
    "HomepageIsNewTabPage"         = 0
    "NewTabPageLocation"           = "about:blank" # Redirects New Tab to about:blank
    "NewTabPageAllowed"            = 0             # Disables the MS News feed
    
    # UI BLOAT
    "HubsSidebarEnabled"           = 0
    "WebWidgetAllowed"             = 0
    "BackgroundModeEnabled"        = 0
    "ShoppingAssistantEnabled"     = 0
}

Write-Host "Applying Registry Policies..." -ForegroundColor Cyan
foreach ($Policy in $Policies.GetEnumerator()) {
    $Type = if ($Policy.Value -is [int]) { "DWord" } else { "String" }
    Set-ItemProperty -Path $RegPath -Name $Policy.Name -Value $Policy.Value -Type $Type -Force
}

# 1. Set Startup URL List (Only about:blank)
# We clear the key first to ensure NO other URLs are in the list
Remove-Item -Path "$RegPath\RestoreOnStartupURLs" -Recurse -ErrorAction SilentlyContinue
New-Item -Path "$RegPath\RestoreOnStartupURLs" -Force | Out-Null
Set-ItemProperty -Path "$RegPath\RestoreOnStartupURLs" -Name "1" -Value "about:blank" -Force

# 2. Force uBlock Origin
$uBlockID = "odfafbeednnidgdbecfnebebebehmhlf;https://edge.microsoft.com/extensionlocation/edge"
Set-ItemProperty -Path "$RegPath\ExtensionInstallForcelist" -Name "1" -Value $uBlockID -Force

Write-Host "Killing Edge processes..." -ForegroundColor Yellow
Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue

Write-Host "Done." -ForegroundColor Green