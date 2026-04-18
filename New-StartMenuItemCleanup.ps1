$TargetPaths = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
    "$env:AppData\Microsoft\Windows\Start Menu\Programs",
    "$env:Public\Desktop",
    "$env:UserProfile\Desktop"
)

$UnwantedKeywords = @("*uninstall*", "*help*", "*website*", "*web site*")

$ItemsToDelete = foreach ($Path in $TargetPaths) {
    if (Test-Path $Path) {
        # Check if we are currently processing a Desktop folder
        $IsDesktop = $Path -like "*Desktop*"

        Get-ChildItem -Path $Path -Recurse:$false -Include *.lnk, *.url | 
            Where-Object { 
                $itemName = $_.Name
                $match = $false
                
                if ($IsDesktop) {
                    # On Desktop, we flag all .lnk and .url files
                    $match = $true
                } else {
                    # In Start Menu, we only flag based on keywords
                    foreach ($word in $UnwantedKeywords) {
                        if ($itemName -like $word) { $match = $true; break }
                    }
                }
                $match
            }
    }
}

if ($ItemsToDelete) {
    Write-Host "The following launchers/shortcuts have been flagged for removal:" -ForegroundColor Cyan
    $ItemsToDelete | Select-Object @{Name="Type"; Expression={$_.Extension}}, @{Name="Name"; Expression={$_.Name}}, @{Name="Folder"; Expression={$_.DirectoryName}} | Out-String | Write-Host

    $Confirmation = Read-Host "Proceed with deletion? (Y/N)"

    if ($Confirmation -eq 'Y') {
        foreach ($Item in $ItemsToDelete) {
            try {
                Remove-Item -Path $Item.FullName -Force -ErrorAction Stop
                Write-Host "Deleted: $($Item.Name)" -ForegroundColor Gray
            } catch {
                Write-Warning "Failed to delete: $($Item.Name). Check permissions."
            }
        }
        Write-Host "`nCleanup finished successfully." -ForegroundColor Green
    } else {
        Write-Host "Cleanup cancelled. No files were harmed." -ForegroundColor Yellow
    }
} else {
    Write-Host "No matching shortcuts found. Your environment is already clean!" -ForegroundColor Green
}