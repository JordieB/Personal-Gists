<#
.SYNOPSIS
Automatically installs software packages using Chocolatey, manages necessary reboots, and schedules weekly updates.

.DESCRIPTION
This script uses Chocolatey to install a predefined list of software packages. If a reboot is required during installation,
it schedules a task to resume the process. After installation, it sets up a weekly task to update all installed packages.

.NOTES
- Run with elevated permissions.
- Ensure Chocolatey is not blocked by any security software.
- Review and modify the software list as per your needs before running.

#>

# Helper function to write a log entry
function Write-ChocoLog {
    param (
        [Parameter(Mandatory)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $global:ChocoLogPath -Value "[$timestamp] $Message"
}

# Installs a single Chocolatey package
function Install-ChocoPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$PackageName
    )

    Write-Host "Installing $PackageName..."
    choco install $PackageName -y | Out-File $global:ChocoLogPath -Append
    Check-RebootRequirement
}

# Checks if a reboot is required and schedules the script to resume after reboot
function Check-RebootRequirement {
    $rebootRequired = (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations') -or
                      (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')

    if ($rebootRequired) {
        Schedule-ResumeAfterReboot
        Write-Host "Restarting computer to complete installation..." -ForegroundColor Yellow
        Restart-Computer -Force
    }
}

# Schedules this script to resume after reboot
function Schedule-ResumeAfterReboot {
    $taskName = "Resume-ChocoInstall"
    $scriptPath = $MyInvocation.MyCommand.Path
    $taskAction = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File '$scriptPath'"
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup -Delay 'PT2M'

    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User $env:USERNAME
    Write-ChocoLog "Scheduled task created to resume installation after reboot."
}

# Installs Chocolatey if not already installed
function Install-Chocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

# Creates a weekly task to update all Chocolatey packages
function Create-WeeklyUpdateTask {
    $taskName = "Weekly Chocolatey Upgrade"
    if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
        $action = New-ScheduledTaskAction -Execute 'C:\ProgramData\chocolatey\bin\choco.exe' -Argument "upgrade all -y | Out-File $global:ChocoLogPath -Append"
        $trigger = New-ScheduledTaskTrigger -At 5pm -Weekly -DaysOfWeek Saturday

        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Upgrades all Chocolatey packages every weekend" -User "NT AUTHORITY\SYSTEM" -RunLevel Highest
        Write-ChocoLog "Weekly update task created."
    } else {
        Write-ChocoLog "Weekly update task already exists."
    }
}

function Install-ChocoSoftware {
    $global:ChocoLogPath = Join-Path $PSScriptRoot "choco-log.txt"
    $softwareToInstall = @(
        # Personal
        "discord",
        "obsidian",
        "spotify",
        "steam",
        # Dev
        "powershell-core",
        "python",
        "pyenv-win",
        "vscode",
        "docker-desktop",
        "nodejs",
        # Dev Project Dependencies
        "visualstudio2019-workload-vctools",
        "cuda", 
        "ffmpeg-full",
        # Utilities
        "bitwarden",
        "protonvpn",
        "ccleaner",
        "calibre",
        "hwinfo",
        "libreoffice-fresh",
        "geforce-experience",
        "audacity",
        "git",
        "powertoys",
        "qbittorrent",
        "malwarebytes",
        "f.lux",
        "zoom",
        "gimp",
        "irfanview",
        "vlc",
        "wireshark",
        # Program Dependencies
        "vcredist-all",
        "directx",
        "dotnet",
        "dotnet-desktopruntime",
        "dotnetfx",
        "openjdk"
    )

    Install-Chocolatey
    choco upgrade chocolatey -y | Out-File $global:ChocoLogPath -Append
    $softwareToInstall | ForEach-Object { Install-ChocoPackage -PackageName $_ }
    Create-WeeklyUpdateTask
}