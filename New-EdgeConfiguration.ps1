# ============================
# Microsoft Edge De-Bloat Script (Enhanced)
# ============================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run as Administrator."
    Exit
}

$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$SubKeys = @(
    $RegPath,
    "$RegPath\ExtensionInstallForcelist",
    "$RegPath\RestoreOnStartupURLs"
)

foreach ($Key in $SubKeys) { if (-not (Test-Path $Key)) { New-Item -Path $Key -Force | Out-Null } }

$Policies = @{
    # ---- Startup & Identity ----
    "HideFirstRunExperience"              = 1
    "BrowserSignin"                       = 0
    "BrowserAddProfileEnabled"            = 0
    "DefaultBrowserSettingEnabled"        = 0
    "RestoreOnStartup"                    = 4 # Open specific URLs
    "StartupBoostEnabled"                 = 0 # Faster startup often keeps Edge in background; disable it
    
    # ---- New Tab & Home ----
    "HomepageIsNewTabPage"                = 0
    "HomepageLocation"                    = "about:blank"
    "NewTabPageLocation"                  = "about:blank"
    "NewTabPageContentEnabled"            = 0
    "NewTabPageQuickLinksEnabled"         = 0
    "PromotionalTabsEnabled"              = 0
    "ShowRecommendationsEnabled"          = 0
    "NewTabPageBackgroundImageEnabled"    = 0
    "NewTabPageAllowedBackgroundTypes"    = 3

    # ---- AI & Copilot (The most annoying part) ----
    "ComposeEnabled"                      = 0
    "DiscoverPageContextEnabled"          = 0    # Stops Edge from "reading" your page for AI
    "EdgeCopilotEnabled"                  = 0    # The main switch for Edge AI
    "EdgeDiscoverEnabled"                 = 0    # Obsolete but still good for older versions
    "EdgeSidebarAppSet"                   = ""
    "HubsSidebarEnabled"                  = 0    # Kills the sidebar entirely
    "Microsoft365CopilotChatIconEnabled"  = 0    # Specific icon toggle for Entra/M365 accounts

    # ---- Privacy & Telemetry ----
    "MicrosoftRewardsUserStatusEnabled"   = 0
    "EdgeShoppingAssistantEnabled"        = 0
    "PersonalizationReportingEnabled"     = 0
    "MetricsReportingEnabled"             = 0
    "SearchSuggestEnabled"                = 0
    "AddressBarTrendingSuggestEnabled"    = 0
    "UserFeedbackAllowed"                 = 0

    # ---- Browser Utilities ----
    "EdgeCollectionsEnabled"              = 0
    "EdgeWalletCheckoutEnabled"           = 0
    "BackgroundModeEnabled"               = 0
    "PasswordManagerEnabled"              = 0 # Optional: prevents "Save Password?" prompts
}

Write-Host "Applying Edge De-Bloat Policies..." -ForegroundColor Cyan

foreach ($Policy in $Policies.GetEnumerator()) {
    $Type = if ($Policy.Value -is [int]) { "DWord" } else { "String" }
    Set-ItemProperty -Path $RegPath -Name $Policy.Key -Value $Policy.Value -Type $Type -Force
}

# ---- Force Startup URL to Blank ----
Set-ItemProperty -Path "$RegPath\RestoreOnStartupURLs" -Name "1" -Value "about:blank" -Type String -Force

# ---- Force uBlock Origin Lite ----
# Uses the Extension ID for uBlock Origin Lite
$uBlockLite = "cimighlppcgcoapaliogpjjdehbnofhn;https://edge.microsoft.com/extensionwebstorebase/v1/crx"
Set-ItemProperty -Path "$RegPath\ExtensionInstallForcelist" -Name "1" -Value $uBlockLite -Type String -Force

# ---- Cleanup & Restart ----
Write-Host "Killing Edge processes..." -ForegroundColor Yellow
Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

Write-Host "Done." -ForegroundColor Green
