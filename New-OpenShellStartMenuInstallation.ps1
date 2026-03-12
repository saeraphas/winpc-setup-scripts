<#
.SYNOPSIS
    Automates the installation and configuration of Open-Shell Menu.

.DESCRIPTION
    Performs an admin check, sets up standardized logging in C:\Lab\OpenShell, downloads the OpenShell 
    installer, verifies its integrity via SHA256, and applies an embedded XML configuration.
    Installation activity is logged to installation.log via MSI/EXE argument passing.

.PARAMETER SkipHashChecking
    Bypasses the SHA256 integrity check for the downloaded installer.
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
$activity         = "OpenShell"
$deployment       = Join-Path $organization $activity
$automationlog    = Join-Path $deployment "automation.log"
$installationlog  = Join-Path $deployment "installation.log"

if (-not (Test-Path $deployment)) {
    New-Item -Path $deployment -ItemType Directory -Force | Out-Null
}

# Start logging script output
Start-Transcript -Path $automationlog -Append

try {
    # 3. Embedded Configuration (Here-String)
    $xmlSettings = @"
<?xml version="1.0"?>
<Settings component="StartMenu" version="4.4.191">
	<MenuStyle value="Classic2"/>
	<ShiftClick value="Nothing"/>
	<ShiftWin value="Nothing"/>
	<ShiftRight value="1"/>
	<Documents value="Hide"/>
	<UserDocuments value="Hide"/>
	<UserPictures value="Hide"/>
	<Network value="Hide"/>
	<Printers value="Hide"/>
	<ConfirmLogOff value="1"/>
	<Help value="0"/>
	<HideProgramsMetro value="0"/>
	<RecentPrograms value="None"/>
	<EnableJumplists value="0"/>
	<RemoteShutdown value="1"/>
	<StartScreenShortcut value="0"/>
	<HighlightNew value="0"/>
	<CheckWinUpdates value="1"/>
	<EnableAccessibility value="0"/>
	<SearchSubWord value="0"/>
	<SearchFiles value="0"/>
	<SearchInternet value="0"/>
	<SkipMetro value="1"/>
	<MenuItems2>
		<Line>Items=COLUMN_PADDING,ProgramsMenu,AppsMenu,SearchBoxItem,COLUMN_BREAK,UserFilesItem,ComputerItem,SEPARATOR,ControlPanelItem,PCSettingsItem,SecurityItem,SEPARATOR,RunItem,COLUMN_PADDING,SEPARATOR,ShutdownBoxItem</Line>
		<Line>ProgramsMenu.Command=programs</Line>
		<Line>ProgramsMenu.Label=`$Menu.Programs</Line>
		<Line>ProgramsMenu.Icon=shell32.dll,326</Line>
		<Line>AppsMenu.Command=apps</Line>
		<Line>AppsMenu.Label=`$Menu.Apps</Line>
		<Line>AppsMenu.Icon=,2</Line>
		<Line>SearchBoxItem.Command=search_box</Line>
		<Line>SearchBoxItem.Label=`$Menu.SearchBox</Line>
		<Line>SearchBoxItem.Icon=none</Line>
		<Line>SearchBoxItem.Settings=OPEN_UP|TRACK_RECENT</Line>
		<Line>UserFilesItem.Command=user_files</Line>
		<Line>UserFilesItem.Tip=`$Menu.UserFilesTip</Line>
		<Line>ComputerItem.Command=computer</Line>
		<Line>ControlPanelItem.Command=control_panel</Line>
		<Line>ControlPanelItem.Label=`$Menu.ControlPanel</Line>
		<Line>ControlPanelItem.Tip=`$Menu.ControlPanelTip</Line>
		<Line>ControlPanelItem.Icon=shell32.dll,137</Line>
		<Line>ControlPanelItem.Settings=TRACK_RECENT</Line>
		<Line>PCSettingsItem.Command=pc_settings</Line>
		<Line>PCSettingsItem.Label=`$Menu.PCSettings</Line>
		<Line>PCSettingsItem.Icon=%windir%\ImmersiveControlPanel\SystemSettings.exe,10</Line>
		<Line>PCSettingsItem.Settings=TRACK_RECENT</Line>
		<Line>SecurityItem.Command=windows_security</Line>
		<Line>SecurityItem.Label=`$Menu.Security</Line>
		<Line>SecurityItem.Tip=`$Menu.SecurityTip</Line>
		<Line>SecurityItem.Icon=shell32.dll,48</Line>
		<Line>RunItem.Command=run</Line>
		<Line>RunItem.Label=`$Menu.Run</Line>
		<Line>RunItem.Tip=`$Menu.RunTip</Line>
		<Line>RunItem.Icon=shell32.dll,328</Line>
		<Line>ShutdownBoxItem.Items=SwitchUserItem,LogOffItem,LockItem,SEPARATOR,SleepItem,HibernateItem,SEPARATOR,RestartItem,UndockItem,DisconnectItem,ShutdownItem</Line>
		<Line>ShutdownBoxItem.Command=shutdown_box</Line>
		<Line>ShutdownBoxItem.Label=`$Menu.ShutdownBox</Line>
		<Line>ShutdownBoxItem.Icon=shell32.dll,329</Line>
		<Line>ShutdownBoxItem.Settings=SPLIT</Line>
		<Line>SwitchUserItem.Command=switch_user</Line>
		<Line>SwitchUserItem.Label=`$Menu.SwitchUser</Line>
		<Line>SwitchUserItem.Tip=`$Menu.SwitchUserTip</Line>
		<Line>SwitchUserItem.Icon=none</Line>
		<Line>LogOffItem.Command=logoff</Line>
		<Line>LogOffItem.Label=`$Menu.LogOffShort</Line>
		<Line>LogOffItem.Tip=`$Menu.LogOffTip</Line>
		<Line>LogOffItem.Icon=none</Line>
		<Line>LockItem.Command=lock</Line>
		<Line>LockItem.Label=`$Menu.Lock</Line>
		<Line>LockItem.Tip=`$Menu.LockTip</Line>
		<Line>LockItem.Icon=none</Line>
		<Line>SleepItem.Command=sleep</Line>
		<Line>SleepItem.Label=`$Menu.Sleep</Line>
		<Line>SleepItem.Tip=`$Menu.SleepTip</Line>
		<Line>SleepItem.Icon=none</Line>
		<Line>HibernateItem.Command=hibernate</Line>
		<Line>HibernateItem.Label=`$Menu.Hibernate</Line>
		<Line>HibernateItem.Tip=`$Menu.HibernateTip</Line>
		<Line>HibernateItem.Icon=none</Line>
		<Line>RestartItem.Command=restart</Line>
		<Line>RestartItem.Label=`$Menu.Restart</Line>
		<Line>RestartItem.Tip=`$Menu.RestartTip</Line>
		<Line>RestartItem.Icon=none</Line>
		<Line>UndockItem.Command=undock</Line>
		<Line>UndockItem.Label=`$Menu.Undock</Line>
		<Line>UndockItem.Tip=`$Menu.UndockTip</Line>
		<Line>UndockItem.Icon=none</Line>
		<Line>DisconnectItem.Command=disconnect</Line>
		<Line>DisconnectItem.Label=`$Menu.Disconnect</Line>
		<Line>DisconnectItem.Tip=`$Menu.DisconnectTip</Line>
		<Line>DisconnectItem.Icon=none</Line>
		<Line>ShutdownItem.Command=shutdown</Line>
		<Line>ShutdownItem.Label=`$Menu.Shutdown</Line>
		<Line>ShutdownItem.Tip=`$Menu.ShutdownTip</Line>
		<Line>ShutdownItem.Icon=none</Line>
	</MenuItems2>
	<ShowNewFolder value="0"/>
</Settings>
"@
    $xmlPath = Join-Path $deployment "Menu_Settings.xml"
    $xmlSettings | Out-File -FilePath $xmlPath -Encoding utf8

    # 4. Configuration
    $URI = "https://github.com/Open-Shell/Open-Shell-Menu/releases/download/v4.4.196/OpenShellSetup_4_4_196.exe"
    $ExpectedHash = "5A8C5AFAC76973DD0C26B423EDE8453813A01953C28F46B640549F7F2E9AE443"
    
    $fileName = $URI.Split('/')[-1]
    $localPath = Join-Path $deployment $fileName

    $MaxRetries = 3
    $Attempt = 0
    $Verified = $false

    # 5. Download & Verify Loop
    while (-not $Verified -and $Attempt -lt $MaxRetries) {
        $Attempt++
        if (Test-Path $localPath) { Remove-Item $localPath -Force }

        Write-Host "Attempt ${Attempt}: Downloading Open-Shell..." -ForegroundColor Cyan
        
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

        if ($SkipHashChecking) {
            Write-Host "SkipHashChecking enabled. Bypassing integrity check." -ForegroundColor Yellow
            $Verified = $true
        } else {
            Write-Host "Verifying checksum..." -NoNewline
            $actualHash = (Get-FileHash $localPath -Algorithm SHA256).Hash
            if ($actualHash -eq $ExpectedHash) {
                Write-Host " [MATCH]" -ForegroundColor Green
                $Verified = $true
            } else {
                Write-Host " [MISMATCH]" -ForegroundColor Red
            }
        }
    }

    if (-not $Verified) { throw "Verification failed for $localPath." }

    # 6. Installation
    Write-Host "Installing Open-Shell (Logging to $installationlog)..." -ForegroundColor Yellow
    
    # Passing the log path via /L argument to the EXE bootstrapper
    $installerArgs = @(
        "/qn", 
        "ADDLOCAL=StartMenu",
        "/L", "`"$installationlog`""
    )
    
    $process = Start-Process -FilePath $localPath -ArgumentList $installerArgs -Wait -NoNewWindow -PassThru

    if ($process.ExitCode -ne 0) { throw "Installation failed with code $($process.ExitCode)" }

    # 7. Apply Configuration
    Write-Host "Applying XML Configuration..." -ForegroundColor Yellow
    $configExec = "C:\Program Files\Open-Shell\StartMenu.exe"
    
    if (Test-Path $configExec) {
        $configArgs = @("-xml", "`"$xmlPath`"")
        Start-Process -FilePath $configExec -ArgumentList $configArgs -Wait
        Write-Host "Configuration applied successfully." -ForegroundColor Green
    } else {
        Write-Error "StartMenu.exe not found at $configExec. Configuration skipped."
    }

} catch {
    Write-Error "Script failed: $($_.Exception.Message)"
} finally {
    Stop-Transcript
}