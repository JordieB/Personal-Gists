<#
.SYNOPSIS
This script installs software packages using Chocolatey, handles necessary
reboots, and sets up a weekly Chocolatey update task.

.NOTES
- Ensure this is ran with elevated permissions.
- Vivalid should be portable on external drive.
- Create index shortcuts for Power Toys Search after running.
- Manually retrieve wdp.app.
- Poetry for Python still needs to be installed separately.
#>

# Define a path for the Chocolatey log
$chocoLogPath = Join-Path $PSScriptRoot "choco-log.txt"

# Function to install software packages with Chocolatey
function Install-ChocoPackage {
    param (
        [string]$packageName
    )

    Write-Host "Installing $packageName..."
    choco install $packageName -y | Out-File $chocoLogPath -Append

    $rebootRequired = (Test-Path `
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\'`
        + 'PendingFileRenameOperations') -or 
                      (Test-Path `
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\'`
        + 'Component Based Servicing\RebootPending')

    if ($rebootRequired) {
        Write-Host "Reboot required. Scheduling task to continue "`
            + "installation after reboot..."

        $taskAction = New-ScheduledTaskAction -Execute 'Powershell.exe' `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File "`
            + "'$($MyInvocation.MyCommand.Path)'"
        $taskTrigger = New-ScheduledTaskTrigger -AtStartup -Delay 'PT1M'  

        Register-ScheduledTask -TaskName 'Resume-ChocoInstall' `
            -Action $taskAction -Trigger $taskTrigger -User $env:USERNAME

        Write-Host "Restarting computer..."
        Restart-Computer -Force
    }
}

# Install Chocolatey if not already installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = `
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString(`
        'https://chocolatey.org/install.ps1'))
}

Write-Host "Upgrading Chocolatey to the latest version..."
choco upgrade chocolatey -y | Out-File $chocoLogPath -Append

# Define a list of software to install
$softwareToInstall = @(
    # [Rest of the software list...]

    # Program Dependencies
    "vcredist-all",
    "directx",
    "dotnet",
    "dotnet-desktopruntime",
    "dotnetfx",
    "openjdk"
)

# Install listed software and handle reboots
$softwareToInstall | ForEach-Object {
    Install-ChocoPackage -packageName $_
}

# Create weekly update task
$taskName = "Weekly Chocolatey Upgrade"
# Check if the task already exists
$existingTask = Get-ScheduledTask | Where-Object {$_.TaskName -like $taskName}
if ($existingTask) {
    Write-Host "Task '$taskName' exists. Skipping creation..."
} else {
    Write-Host "Creating a weekly Chocolatey upgrade task..."
    $action = New-ScheduledTaskAction -Execute `
        'C:\ProgramData\chocolatey\bin\choco.exe' -Argument `
        "upgrade all -y | Out-File $chocoLogPath -Append"
    $trigger = New-ScheduledTaskTrigger -At 5pm -Weekly -DaysOfWeek Saturday
    Register-ScheduledTask -Action $action -Trigger $trigger `
        -TaskName $taskName `
        -Description "Upgrades all Chocolatey packages every weekend" `
        -User "NT AUTHORITY\SYSTEM" -RunLevel Highest
}

Write-Host "Script completed."
