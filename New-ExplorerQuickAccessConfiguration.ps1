# Check for Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Run as Administrator."
    exit
}

# CSV for Privacy Settings (Disabling Auto-Add)
$privacyData = @"
Path,Name,Type,Value
HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer,ShowFrequent,DWord,0
HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer,ShowRecent,DWord,0
"@ | ConvertFrom-Csv

# CSV for Unpinning Folders
$unpinData = @"
FolderName
Documents
Pictures
Music
Videos
"@ | ConvertFrom-Csv

function Set-QuickAccessPrivacy {
    param ($Path, $Name, $Type, $Value)
    
    $currentValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -ne $currentValue -and $currentValue.$Name -eq $Value) {
        Write-Host "Privacy setting '$Name' already configured."
        return
    }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
        Write-Host "Configured Privacy setting: $Name."
    } catch {
        Write-Warning "Failed to set '$Name': $($_.Exception.Message)"
    }
}

function Unpin-QuickAccessFolder {
    param ($FolderName)
    
    try {
        $app = New-Object -ComObject Shell.Application
        $quickAccess = $app.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}")
        $item = $quickAccess.Items() | Where-Object { $_.Name -eq $FolderName }

        if ($null -ne $item) {
            $item.InvokeVerb("unpinfromhome")
            Write-Host "Unpinned '$FolderName' from Quick Access."
        } # No else/message if already unpinned to stay terse
    } catch {
        Write-Warning "Error unpinning '$FolderName': $($_.Exception.Message)"
    }
}

# Execute Privacy Loops
foreach ($row in $privacyData) {
    Set-QuickAccessPrivacy -Path $row.Path -Name $row.Name -Type $row.Type -Value $row.Value
}

# Execute Unpin Loops
foreach ($row in $unpinData) {
    Unpin-QuickAccessFolder -FolderName $row.FolderName
}