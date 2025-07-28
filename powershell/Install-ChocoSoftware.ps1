<#
.SYNOPSIS
    Automatically installs software packages using Chocolatey, manages necessary reboots, and schedules weekly updates.

.DESCRIPTION
    This script uses Chocolatey to install a predefined list of software packages. If a reboot is required during installation,
    it schedules a task to resume the process. After installation, it sets up a weekly task to update all installed packages.
    The script handles the complete lifecycle of software installation including Chocolatey setup, package installation,
    reboot management, and automated maintenance.

.PARAMETER LogPath
    The path to the log file where installation activities will be recorded. Defaults to 'choco-log.txt' in the script directory.

.PARAMETER SkipWeeklyTask
    When specified, skips the creation of the weekly update scheduled task.

.PARAMETER CustomPackages
    An array of custom package names to install instead of the default software list.

.EXAMPLE
    Invoke-ChocoSoftwareInstallation
    Installs the default software list using Chocolatey with default settings.

.EXAMPLE
    Invoke-ChocoSoftwareInstallation -LogPath "C:\Logs\choco-install.log" -SkipWeeklyTask
    Installs software with custom log path and skips weekly update task creation.

.EXAMPLE
    Invoke-ChocoSoftwareInstallation -CustomPackages @('git', 'vscode', 'nodejs')
    Installs only the specified custom packages instead of the default list.

.NOTES
    Author: Jordie Belle
    Prerequisites: PowerShell V5 or higher
    Requirements:
    - Administrative privileges are required for software installation
    - Internet connection for downloading Chocolatey and packages
    - Sufficient disk space for installed software
    - Windows operating system with task scheduler support
    
    Security Notes:
    - This script temporarily modifies execution policy for Chocolatey installation
    - Ensure Chocolatey is not blocked by any security software
    - Review and modify the software list as per your organizational needs before running
    
    Installation Process:
    1. Checks for and installs Chocolatey if needed
    2. Upgrades Chocolatey to latest version
    3. Installs each software package with automatic reboot handling
    4. Creates a weekly maintenance task for updates
#>

function Invoke-ChocoSoftwareInstallation {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = (Join-Path $PSScriptRoot "choco-log.txt"),
        
        [Parameter()]
        [switch]$SkipWeeklyTask,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$CustomPackages = @()
    )

    # Set script-level log path for global access
    $script:ChocoLogPath = $LogPath

    # Function to write timestamped log entries
    function Write-ChocoLog {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Message,
            
            [Parameter()]
            [ValidateSet('Information', 'Warning', 'Error')]
            [string]$Level = 'Information'
        )

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] $Level`: $Message"
        
        try {
            Add-Content -Path $script:ChocoLogPath -Value $logEntry -ErrorAction Stop
        } catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
        
        # Output to console based on level
        switch ($Level) {
            'Information' { Write-Information $Message -InformationAction Continue }
            'Warning' { Write-Warning $Message }
            'Error' { Write-Error $Message }
        }
    }

    # Function to install a single Chocolatey package
    function Install-ChocoPackage {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$PackageName
        )

        try {
            Write-Information "Installing $PackageName..." -InformationAction Continue
            Write-ChocoLog "Starting installation of package: $PackageName" -Level Information
            
            $output = choco install $PackageName -y 2>&1
            $exitCode = $LASTEXITCODE
            
            # Log the output
            Add-Content -Path $script:ChocoLogPath -Value $output
            
            if ($exitCode -eq 0) {
                Write-ChocoLog "Successfully installed: $PackageName" -Level Information
                Test-RebootRequirement
                return $true
            } else {
                Write-ChocoLog "Installation failed for $PackageName with exit code: $exitCode" -Level Error
                return $false
            }
        } catch {
            Write-ChocoLog "Error installing $PackageName`: $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    # Function to check if a reboot is required and handle it
    function Test-RebootRequirement {
        [CmdletBinding()]
        param()
        
        $rebootRequired = (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations') -or
                         (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')

        if ($rebootRequired) {
            Write-Warning "System reboot is required to complete installation."
            Write-ChocoLog "Reboot required - scheduling resume task" -Level Warning
            
            if (New-ResumeTask) {
                Write-Information "Restarting computer to complete installation..." -InformationAction Continue
                Write-ChocoLog "Initiating system restart" -Level Information
                Restart-Computer -Force
            } else {
                Write-Error "Failed to create resume task. Manual restart may be required."
            }
        }
    }

    # Function to schedule script resumption after reboot
    function New-ResumeTask {
        [CmdletBinding()]
        param()
        
        try {
            $taskName = "Resume-ChocoInstall"
            $scriptPath = $MyInvocation.MyCommand.Path
            
            # Remove existing task if it exists
            if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            }
            
            $taskAction = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File '$scriptPath'"
            $taskTrigger = New-ScheduledTaskTrigger -AtStartup -Delay 'PT2M'
            $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

            Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -User $env:USERNAME -ErrorAction Stop
            Write-ChocoLog "Resume task scheduled successfully" -Level Information
            return $true
        } catch {
            Write-ChocoLog "Failed to create resume task: $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    # Function to install Chocolatey if not present
    function Install-Chocolatey {
        [CmdletBinding()]
        param()
        
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            try {
                Write-Information "Installing Chocolatey package manager..." -InformationAction Continue
                Write-ChocoLog "Chocolatey not found - beginning installation" -Level Information
                
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                
                $installScript = (New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')
                Invoke-Expression $installScript
                
                Write-ChocoLog "Chocolatey installation completed" -Level Information
                return $true
            } catch {
                Write-ChocoLog "Chocolatey installation failed: $($_.Exception.Message)" -Level Error
                return $false
            }
        } else {
            Write-ChocoLog "Chocolatey is already installed" -Level Information
            return $true
        }
    }

    # Function to create weekly update scheduled task
    function New-WeeklyUpdateTask {
        [CmdletBinding()]
        param()
        
        $taskName = "Weekly Chocolatey Upgrade"
        
        try {
            if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
                $action = New-ScheduledTaskAction -Execute 'C:\ProgramData\chocolatey\bin\choco.exe' -Argument "upgrade all -y"
                $trigger = New-ScheduledTaskTrigger -At "5:00 PM" -Weekly -DaysOfWeek Saturday
                $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
                
                Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Upgrades all Chocolatey packages every weekend" -User "NT AUTHORITY\SYSTEM" -RunLevel Highest -Settings $settings -ErrorAction Stop
                
                Write-ChocoLog "Weekly update task created successfully" -Level Information
                return $true
            } else {
                Write-ChocoLog "Weekly update task already exists" -Level Information
                return $true
            }
        } catch {
            Write-ChocoLog "Failed to create weekly update task: $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    # Function to get the default software list
    function Get-DefaultSoftwareList {
        [CmdletBinding()]
        param()
        
        return @(
            # Personal Applications
            "discord", "notion", "spotify", "steam", "Firefox",
            
            # Development Tools
            "powershell-core", "python", "pyenv-win", "vscode", "docker-desktop", 
            "nodejs", "bfg-repo-cleaner", "chromium", "steamcmd", "git",
            
            # Development Dependencies
            "visualstudio2019-workload-vctools", "cuda", "ffmpeg-full", "adb", 
            "openal", "tesseract",
            
            # Utilities
            "bitwarden", "protonvpn", "ccleaner", "calibre", "hwinfo", 
            "libreoffice-fresh", "geforce-experience", "audacity", "powertoys", 
            "qbittorrent", "malwarebytes", "f.lux", "zoom", "gimp", "irfanview", 
            "jpegview", "vlc", "wireshark", "jdownloader", "scrcpy", "speccy", 
            "sunshine", "vortex", "wiztree",
            
            # Runtime Dependencies
            "vcredist-all", "directx", "dotnet", "dotnet-desktopruntime", 
            "dotnetfx", "openjdk", "xna"
        )
    }

    # Main execution function
    try {
        # Ensure log directory exists
        $logDirectory = Split-Path $LogPath -Parent
        if ($logDirectory -and -not (Test-Path $logDirectory)) {
            New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop
        }
        
        Write-ChocoLog "=== Starting Chocolatey Software Installation Session ===" -Level Information
        Write-Information "Starting Chocolatey software installation process..." -InformationAction Continue

        # Install Chocolatey if needed
        if (-not (Install-Chocolatey)) {
            Write-Error "Cannot continue without Chocolatey installation."
            return $false
        }

        # Upgrade Chocolatey to latest version
        Write-Information "Upgrading Chocolatey to latest version..." -InformationAction Continue
        $upgradeOutput = choco upgrade chocolatey -y 2>&1
        Add-Content -Path $LogPath -Value $upgradeOutput
        Write-ChocoLog "Chocolatey upgrade completed" -Level Information

        # Determine software list to install
        $softwareList = if ($CustomPackages.Count -gt 0) {
            Write-ChocoLog "Using custom package list ($($CustomPackages.Count) packages)" -Level Information
            $CustomPackages
        } else {
            $defaultList = Get-DefaultSoftwareList
            Write-ChocoLog "Using default package list ($($defaultList.Count) packages)" -Level Information
            $defaultList
        }

        # Install each package
        $successCount = 0
        foreach ($package in $softwareList) {
            if (Install-ChocoPackage -PackageName $package) {
                $successCount++
            }
        }

        # Create weekly update task if not skipped
        if (-not $SkipWeeklyTask) {
            New-WeeklyUpdateTask | Out-Null
        } else {
            Write-ChocoLog "Skipped weekly update task creation per user request" -Level Information
        }

        # Final summary
        Write-Information "Installation process completed. Successfully installed $successCount of $($softwareList.Count) packages." -InformationAction Continue
        Write-ChocoLog "Session completed successfully: $successCount/$($softwareList.Count) packages installed" -Level Information
        Write-ChocoLog "=== End of Installation Session ===" -Level Information
        
        return $true
        
    } catch {
        Write-ChocoLog "Critical error in main execution: $($_.Exception.Message)" -Level Error
        Write-Error "Critical error during software installation: $($_.Exception.Message)"
        return $false
    }
}

# Execute the function if script is run directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-ChocoSoftwareInstallation
}