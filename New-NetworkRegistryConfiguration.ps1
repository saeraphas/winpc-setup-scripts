# Check for Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Run as Administrator."
    exit
}

# Embedded CSV data
$registryData = @"
Name,Type,Value
TcpAckFrequency,DWord,1
TcpNoDelay,DWord,1
"@ | ConvertFrom-Csv

function Set-NetRegistrySetting {
    param (
        [string]$Path,
        [string]$Name,
        [string]$Type,
        [string]$Value
    )

    # Check if value exists and matches
    $currentValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -ne $currentValue -and $currentValue.$Name -eq $Value) {
        Write-Host "Setting '$Name' already configured at $(Split-Path $Path -Leaf)."
        return
    }

    # Attempt to set the value
    try {
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
        Write-Host "Configured '$Name' at $(Split-Path $Path -Leaf)."
    } catch {
        Write-Warning "Failed to set '$Name' at $(Split-Path $Path -Leaf): $($_.Exception.Message)"
    }
}

# Locate all network interfaces
$interfaceBase = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
$interfaces = Get-ChildItem -Path $interfaceBase

# Process each interface for each CSV entry
foreach ($interface in $interfaces) {
    $path = $interface.PSPath
    foreach ($row in $registryData) {
        Set-NetRegistrySetting -Path $path -Name $row.Name -Type $row.Type -Value $row.Value
    }
}