Import-Module PSWindowsUpdate
$categories = @(
"DefinitionUpdates",
"CriticalUpdates",
"SecurityUpdates",
"UpdateRollups",
"Updates"
)

Install-WindowsUpdate -Category $categories -NotTitle "preview" -AcceptAll -IgnoreReboot
