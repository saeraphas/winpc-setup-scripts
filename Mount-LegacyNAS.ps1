<#
.SYNOPSIS
    Mount-LegacyNAS.ps1
    A dual-phase script to install dependencies as Admin and map legacy FTP drives as User.
.EXAMPLE
    .\Mount-LegacyNAS.ps1 -Connect
    .\Mount-LegacyNAS.ps1 -Disconnect
#>
param(
    [switch]$Connect,
    [switch]$Disconnect
)

# --- Configuration ---
$NAS = @(
    @{ Name="NAS_L"; Letter="L:"; Label="Linksys MediaHub 500GB"; IP="192.168.98.101" },
    @{ Name="NAS_W"; Letter="W:"; Label="WD My Book 1TB"; IP="192.168.98.100" }
)

$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# --- Phase 1: Administrator (Install Only) ---
if ($IsAdmin) {
    Write-Host "Elevated session detected. Checking prerequisites..." -ForegroundColor Cyan
    
    # Install WinFsp
    if (-not (Get-Service WinFsp.Launcher -ErrorAction SilentlyContinue)) {
        Write-Host "Installing WinFsp..." -ForegroundColor Cyan
        winget install WinFsp.WinFsp --source winget --accept-package-agreements
    }

    # Install Rclone
    if (-not (Get-Command rclone -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Rclone..." -ForegroundColor Cyan
        winget install Rclone.Rclone --source winget --accept-package-agreements
    }

    Write-Host "`n****************************************************************" -ForegroundColor Yellow
    Write-Host "PREREQUISITES CHECK COMPLETE." -ForegroundColor Green
    Write-Host "Drives will NOT be mounted in this Admin session." -ForegroundColor White
    Write-Host "Please close this window and run the script as a STANDARD USER" -ForegroundColor White
    Write-Host "to map your drives." -ForegroundColor White
    Write-Host "****************************************************************" -ForegroundColor Yellow
    exit
}

# --- Phase 2: Standard User (Connect/Disconnect) ---

# Handle Disconnect
if ($Disconnect) {
    foreach ($n in $NAS) {
        Write-Host "Disconnecting $($n.Label)..." -ForegroundColor Gray
        # Stop the specific job
        Get-Job -Name "Mount_$($n.Name)" -ErrorAction SilentlyContinue | Stop-Job | Remove-Job
        # Immediate letter removal
        net use $($n.Letter) /delete /y 2>$null
    }
    Stop-Process -Name rclone -ErrorAction SilentlyContinue
    Write-Host "All legacy drives cleared." -ForegroundColor Yellow
    exit
}

# Handle Connect
if ($Connect) {
    foreach ($n in $NAS) {
        Write-Host "`n--- Initializing $($n.Label) ---" -ForegroundColor Cyan
        
        # 1. Ping Check
        if (Test-Connection -ComputerName $n.IP -Count 1 -Quiet) {
            Write-Host "[OK] NAS is reachable." -ForegroundColor Green
            
            # 2. Create Config
            rclone config create $($n.Name) ftp host=$($n.IP) user="anonymous" pass="" | Out-Null
            
            # 3. Mount as Job
            Start-Job -Name "Mount_$($n.Name)" -ScriptBlock {
                param($n)
                rclone mount "$($n.Name):" $($n.Letter) --vfs-cache-mode full --volname $($n.Label)
            } -ArgumentList $n

            # 4. Verify Path (5 second poll)
            Write-Host "Waiting for $($n.Letter) to mount..." -NoNewline
            $mounted = $false
            for ($i=1; $i -le 5; $i++) {
                Start-Sleep -Seconds 1
                Write-Host "." -NoNewline
                if (Test-Path $($n.Letter)) { 
                    $mounted = $true; break 
                }
            }
            
            if ($mounted) {
                Write-Host " SUCCESS." -ForegroundColor Green
            } else {
                Write-Host " FAILED. Drive letter did not appear." -ForegroundColor Red
            }
        } else {
            Write-Host "[FAIL] NAS at $($n.IP) is unreachable. Skipping." -ForegroundColor Red
        }
    }
    exit
}

# --- Phase 3: No Parameters ---
Write-Host "Usage: " -NoNewline
Write-Host ".\Mount-LegacyNAS.ps1 -Connect " -ForegroundColor Cyan -NoNewline
Write-Host "OR " -NoNewline
Write-Host "-Disconnect" -ForegroundColor Cyan
exit