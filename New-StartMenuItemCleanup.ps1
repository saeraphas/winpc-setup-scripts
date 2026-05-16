$shell = New-Object -ComObject WScript.Shell
$unwantedPaths = New-Object System.Collections.Generic.List[string]
$startMenuPaths = "$env:AppData\Microsoft\Windows\Start Menu\Programs", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"

$startKeywords = @("uninstall*")
$anywhereKeywords = @("*help*", "*website*", "*web site*", "*readme*", "*read me*")

# --- Pass 1: Identify Unwanted Files ---
$allFiles = Get-ChildItem -Path $startMenuPaths -Recurse -Include *.lnk, *.url
foreach ($file in $allFiles) {
    $isUnwanted = $false
    
    if ($file.Extension -eq ".url") {
        $isUnwanted = $true
    }
    else {
        # Rule: .lnk files checked by keyword
        foreach ($word in $startKeywords) { if ($file.Name -like $word) { $isUnwanted = $true; break } }
        
        if (-not $isUnwanted) {
            foreach ($word in $anywhereKeywords) { if ($file.Name -like $word) { $isUnwanted = $true; break } }
        }
        
        # Rule: Check Shortcut Target (Dead links and .pdf files)
        if (-not $isUnwanted) {
            try {
                $target = $shell.CreateShortcut($file.FullName).TargetPath
                
                if (-not [string]::IsNullOrWhiteSpace($target)) {
                    # NEW RULE: Check if the target is a PDF file
                    if ($target -like "*.pdf") {
                        $isUnwanted = $true
                    }
                    # Rule: Check for dead links
                    elseif (-not (Test-Path -Path $target)) {
                        $isUnwanted = $true
                    }
                }
            } catch { 
                # If we can't read the shortcut, it's often safer to ignore, 
                # but you could set $isUnwanted = $true here if you want to be aggressive.
            }
        }
    }

    if ($isUnwanted) { $unwantedPaths.Add($file.FullName) }
}

# --- Pass 2: Identify Empty Directories (Excluding Startup) ---
# WMF 5.1 compatibility: Ensure we handle the list comparison correctly
$allDirs = Get-ChildItem -Path $startMenuPaths -Recurse -Directory | Sort-Object { $_.FullName.Split('\').Count } -Descending
foreach ($dir in $allDirs) {
    if ($dir.Name -eq "Startup") { continue }
    
    $currentFiles = Get-ChildItem -Path $dir.FullName -File
    $currentSubDirs = Get-ChildItem -Path $dir.FullName -Directory
    
    # Check if files in this folder are NOT in our unwanted list
    $remainingItems = $currentFiles | Where-Object { $unwantedPaths -notcontains $_.FullName }
    
    # If no valid files remain and no subdirectories exist, flag folder for removal
    if ($null -eq $remainingItems -and $currentSubDirs.Count -eq 0) {
        $unwantedPaths.Add($dir.FullName)
    }
}

# --- Display and Action ---
if ($unwantedPaths.Count -gt 0) {
    Write-Host "The following items are flagged for removal:" -ForegroundColor Yellow
    $unwantedPaths | ForEach-Object { Write-Host $_ }
    
    $confirm = Read-Host "`nFound $($unwantedPaths.Count) items. Delete all? (y/n)"
    if ($confirm -eq 'y') {
        # Sort by length descending to delete children before parents
        $unwantedPaths | Sort-Object Length -Descending | Remove-Item -Force -Recurse
        Write-Host "Cleanup complete." -ForegroundColor Green
    }
} else {
    Write-Host "No unwanted items detected." -ForegroundColor Cyan
}