# 1. Define the Download URL based on Architecture
$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -eq "AMD64") {
    $url = "https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7AndW2K8R2-KB3191566-x64.zip"
    $fileName = "WMF51_x64.zip"
} else {
    $url = "https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7-KB3191566-x86.zip"
    $fileName = "WMF51_x86.zip"
}

$workDir = "C:\WMF51_Update"
if (!(Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir }

$zipPath = Join-Path $workDir $fileName
$extractPath = Join-Path $workDir "Extracted"

# 2. Download the file using .NET WebClient (PS 2.0 compatible)
Write-Host "Downloading WMF 5.1..."
$webClient = New-Object System.Net.WebClient
$webClient.DownloadFile($url, $zipPath)

# 3. Extract the ZIP (PS 2.0 lacks Expand-Archive, so we use Shell.Application)
Write-Host "Extracting files..."
if (!(Test-Path $extractPath)) { New-Item -ItemType Directory -Path $extractPath }
$shell = New-Object -ComObject Shell.Application
$zipFile = $shell.NameSpace($zipPath)
$destination = $shell.NameSpace($extractPath)
$destination.CopyHere($zipFile.Items(), 0x10)

# 4. Execute the Installation
# The ZIP contains an MSU file. We use wusa.exe to install it silently.
Write-Host "Installing WMF 5.1 (this may take several minutes)..."
$msuFile = Get-ChildItem -Path $extractPath -Filter "*.msu" | Select-Object -First 1

if ($msuFile) {
    $installArgs = "$($msuFile.FullName) /quiet /norestart"
    Start-Process -FilePath "wusa.exe" -ArgumentList $installArgs -Wait
    Write-Host "Installation complete. Please restart your computer to apply changes."
} else {
    Write-Error "MSU file not found in the extracted folder."
}