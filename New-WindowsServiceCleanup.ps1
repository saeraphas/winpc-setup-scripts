# Define the array of unwanted services
$unwantedServices = @(
    "wsearch",            # Windows Search
    "spooler",            # Print Spooler
    "DiagTrack",          # Connected User Experiences and Telemetry
    "iphlpsvc",           # IP Helper
    "MapsBroker",         # Downloaded Maps Manager
    "TabletInputService", # Touch Keyboard and Handwriting
    "TrkWks"              # Distributed Link Tracking Client
)

function Disable-UnwantedServices {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$ServiceList
    )

    foreach ($serviceName in $ServiceList) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

        if ($service) {
            try {
                Write-Host "Processing: $($service.DisplayName) ($serviceName)" -ForegroundColor Cyan
                
                # Stop the service if it is currently running
                if ($service.Status -eq 'Running') {
                    Write-Host "  Stopping service..." -NoNewline
                    Stop-Service -Name $serviceName -Force -ErrorAction Stop
                    Write-Host " Done." -ForegroundColor Green
                }

                # Disable the service
                Write-Host "  Disabling service..." -NoNewline
                Set-Service -Name $serviceName -StartupType Disabled
                Write-Host " Done." -ForegroundColor Green
            } catch {
                Write-Error " Failed to process $serviceName. Ensure you are running PowerShell as Administrator."
            }
        } else {
            Write-Warning " Service '$serviceName' not found on this system. Skipping."
        }
    }
}

# Run the updated function
Disable-UnwantedServices -ServiceList $unwantedServices