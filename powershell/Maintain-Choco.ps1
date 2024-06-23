# Define log file path
$logFile = "$env:USERPROFILE\Desktop\choco_maintenance.log"

# Function to log messages
function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    Write-Output $logEntry
    Add-Content -Path $logFile -Value $logEntry
}

function Choco-Upgrade {
    # Start logging
    Log-Message "Starting Chocolatey package maintenance."

    # Upgrade all Chocolatey packages
    Log-Message "Upgrading all Chocolatey packages."
    try {
        choco upgrade all -y | Out-String | Where-Object { $_ -notmatch "Progress: Downloading" } | ForEach-Object { Log-Message $_ }
        Log-Message "Package upgrade completed."
    } catch {
        Log-Message "Error during package upgrade: $_"
    }

    # End logging
    Log-Message "Chocolatey package maintenance completed."
    Log-Message "See Choco managed logs at: C:\ProgramData\chocolatey\logs\chocolatey.log"
}