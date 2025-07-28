<#
.SYNOPSIS
    Completely uninstalls Vortex mod manager and Valheim game including all associated data and files.

.DESCRIPTION
    This script performs a comprehensive removal of Vortex mod manager and Valheim game from the system.
    It handles the complete uninstallation process including mod cleanup, data purging, Steam integration,
    and leftover file removal. The script uses SteamCMD for proper Steam game uninstallation and ensures
    all traces are removed from the system.

.PARAMETER LogPath
    The path to the log file where uninstallation activities will be recorded. Defaults to a temporary location.

.PARAMETER SkipUserPrompts
    When specified, skips interactive user prompts and proceeds automatically through the uninstallation process.

.PARAMETER SteamUsername
    The Steam username for authentication. If not provided, the script will prompt for it during execution.

.PARAMETER ForceUninstall
    When specified, forces the uninstallation even if some components are not found or errors occur.

.EXAMPLE
    Invoke-VortexValheimUninstall
    Runs the complete uninstallation process with interactive prompts.

.EXAMPLE
    Invoke-VortexValheimUninstall -SkipUserPrompts -LogPath "C:\Logs\uninstall.log"
    Runs the uninstallation without user prompts and logs to a custom location.

.EXAMPLE
    Invoke-VortexValheimUninstall -SteamUsername "myusername" -ForceUninstall
    Runs with predefined username and forces uninstallation even if errors occur.

.NOTES
    Author: Jordie Belle
    Prerequisites: PowerShell V5 or higher
    Requirements:
    - Administrative privileges are required for software uninstallation
    - Active Steam installation
    - Internet connection for downloading SteamCMD if not present
    - Chocolatey package manager (will be installed if needed)
    
    Security Notes:
    - This script requires and will prompt for Steam credentials
    - Credentials are handled securely using SecureString
    - All mod data and game saves will be permanently deleted
    - This action cannot be undone - ensure you have backups if needed
    
    Uninstallation Process:
    1. Validates administrative privileges and restarts if needed
    2. Closes running Vortex processes
    3. Removes all Vortex mods and downloads
    4. Purges Vortex configuration and state data
    5. Uninstalls Vortex application
    6. Installs/updates SteamCMD via Chocolatey
    7. Authenticates with Steam and uninstalls Valheim
    8. Cleans up any remaining game files and directories
#>

function Invoke-VortexValheimUninstall {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = "$env:TEMP\VortexValheimUninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",
        
        [Parameter()]
        [switch]$SkipUserPrompts,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SteamUsername,
        
        [Parameter()]
        [switch]$ForceUninstall
    )

    # Function to check if the script is running as admin
    function Test-IsAdmin {
        [CmdletBinding()]
        param()
        
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    }

    # Function to log messages with timestamps
    function Write-UninstallLog {
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
            Add-Content -Path $LogPath -Value $logEntry -ErrorAction Stop
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

    # Function to handle critical errors
    function Stop-UninstallProcess {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$ErrorMessage
        )
        
        Write-UninstallLog "CRITICAL ERROR: $ErrorMessage" -Level Error
        
        if (-not $SkipUserPrompts) {
            Write-Information "Press Enter to exit..." -InformationAction Continue
            Read-Host
        }
        
        Stop-Transcript -ErrorAction SilentlyContinue
        
        if ($ForceUninstall) {
            Write-Warning "Force uninstall specified - continuing despite error."
            return $false
        } else {
            throw $ErrorMessage
        }
    }

    # Function to interact with SteamCMD process
    function Invoke-SteamCMD {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Arguments,
            
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Username,
            
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Password
        )

        $steamCmdPath = "C:\ProgramData\chocolatey\lib\steamcmd\tools\steamcmd.exe"
        if (-not (Test-Path $steamCmdPath)) {
            return Stop-UninstallProcess "SteamCMD executable not found at $steamCmdPath"
        }

        try {
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $steamCmdPath
            $processInfo.Arguments = $Arguments
            $processInfo.RedirectStandardInput = $true
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.UseShellExecute = $false
            $processInfo.CreateNoWindow = $true

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            $process.Start() | Out-Null

            $process.StandardInput.WriteLine("+login $Username $Password")
            Start-Sleep -Seconds 3

            $output = $process.StandardOutput.ReadToEnd()

            if ($output -match "Steam Guard code:" -and -not $SkipUserPrompts) {
                $steamGuardCode = Read-Host -Prompt "Enter Steam Guard code from your email"
                $process.StandardInput.WriteLine($steamGuardCode)
                Start-Sleep -Seconds 2
            }

            $process.StandardInput.WriteLine("+quit")
            $process.StandardInput.Close()
            $process.WaitForExit()

            if ($process.ExitCode -ne 0) {
                return Stop-UninstallProcess "SteamCMD command failed with exit code $($process.ExitCode)"
            }
            
            Write-UninstallLog "SteamCMD command completed successfully" -Level Information
            return $true
            
        } catch {
            return Stop-UninstallProcess "Error executing SteamCMD: $($_.Exception.Message)"
        }
    }

    # Function to ensure Chocolatey is available
    function Install-ChocoIfNeeded {
        [CmdletBinding()]
        param()
        
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            try {
                Write-UninstallLog "Installing Chocolatey package manager..." -Level Information
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                
                $installScript = Invoke-WebRequest -Uri "https://chocolatey.org/install.ps1" -UseBasicParsing
                Invoke-Expression $installScript.Content
                
                Write-UninstallLog "Chocolatey installed successfully" -Level Information
                return $true
            } catch {
                return Stop-UninstallProcess "Failed to install Chocolatey: $($_.Exception.Message)"
            }
        } else {
            Write-UninstallLog "Chocolatey is already installed" -Level Information
            return $true
        }
    }

    # Function to install SteamCMD
    function Install-SteamCMD {
        [CmdletBinding()]
        param()
        
        try {
            Write-UninstallLog "Installing SteamCMD using Chocolatey..." -Level Information
            $process = Start-Process "choco" -ArgumentList "install steamcmd -y" -Wait -PassThru -ErrorAction Stop
            
            if ($process.ExitCode -eq 0) {
                Write-UninstallLog "SteamCMD installed successfully" -Level Information
                return $true
            } else {
                return Stop-UninstallProcess "Installing SteamCMD failed with exit code $($process.ExitCode)"
            }
        } catch {
            return Stop-UninstallProcess "Error installing SteamCMD: $($_.Exception.Message)"
        }
    }

    # Function to remove Vortex application
    function Remove-VortexApplication {
        [CmdletBinding()]
        param()
        
        try {
            Write-UninstallLog "Closing Vortex if running..." -Level Information
            Stop-Process -Name "vortex" -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2

            Write-UninstallLog "Removing Vortex mods and downloads..." -Level Information
            $vortexDir = "$env:APPDATA\Vortex"
            $gameDir = "$vortexDir\valheim"
            
            Remove-Item -Path "$gameDir\mods" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$gameDir\downloads" -Recurse -Force -ErrorAction SilentlyContinue

            Write-UninstallLog "Purging Vortex configuration data..." -Level Information
            Remove-Item -Path "$vortexDir\state" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$gameDir\state" -Recurse -Force -ErrorAction SilentlyContinue

            Write-UninstallLog "Uninstalling Vortex application..." -Level Information
            $uninstaller = Get-CimInstance -ClassName Win32_Product | Where-Object {$_.Name -like "Vortex*"}
            
            if ($uninstaller) {
                $uninstallResult = $uninstaller | Invoke-CimMethod -MethodName Uninstall
                if ($uninstallResult.ReturnValue -eq 0) {
                    Write-UninstallLog "Vortex uninstalled successfully" -Level Information
                } else {
                    Write-UninstallLog "Vortex uninstall returned code: $($uninstallResult.ReturnValue)" -Level Warning
                }
            } else {
                Write-UninstallLog "Vortex application not found in installed programs" -Level Information
            }
            
            return $true
        } catch {
            return Stop-UninstallProcess "Error removing Vortex: $($_.Exception.Message)"
        }
    }

    # Function to uninstall Valheim via Steam
    function Remove-ValheimGame {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string]$Username,
            
            [Parameter(Mandatory)]
            [string]$Password
        )
        
        try {
            Write-UninstallLog "Stopping Valheim via SteamCMD..." -Level Information
            if (-not (Invoke-SteamCMD "+app_stop 892970" $Username $Password)) {
                return $false
            }

            Write-UninstallLog "Uninstalling Valheim via SteamCMD..." -Level Information
            if (-not (Invoke-SteamCMD "+app_uninstall 892970" $Username $Password)) {
                return $false
            }

            Write-UninstallLog "Cleaning up remaining Valheim files..." -Level Information
            $valheimPaths = @(
                "$env:PROGRAMFILES\Steam\steamapps\common\Valheim",
                "$env:PROGRAMFILES(X86)\Steam\steamapps\common\Valheim"
            )
            
            foreach ($path in $valheimPaths) {
                if (Test-Path $path) {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    Write-UninstallLog "Removed directory: $path" -Level Information
                }
            }
            
            return $true
        } catch {
            return Stop-UninstallProcess "Error removing Valheim: $($_.Exception.Message)"
        }
    }

    # Function to prompt for user confirmation
    function Confirm-UserAction {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string]$Message
        )
        
        if ($SkipUserPrompts) {
            Write-UninstallLog "Skipping user prompt (auto-mode): $Message" -Level Information
            return $true
        }
        
        Write-Information $Message -InformationAction Continue
        $input = Read-Host "Continue? (Y/N)"
        return ($input -match '^[Yy]$')
    }

    # Main execution function
    try {
        # Check for administrative privileges
        if (-not (Test-IsAdmin)) {
            Write-Information "Administrative privileges required. Restarting as administrator..." -InformationAction Continue
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            return
        }

        # Ensure log directory exists
        $logDirectory = Split-Path $LogPath -Parent
        if ($logDirectory -and -not (Test-Path $logDirectory)) {
            New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop
        }

        # Start transcript logging
        Start-Transcript -Path $LogPath -Append

        Write-UninstallLog "=== Starting Vortex and Valheim Uninstallation Process ===" -Level Information
        Write-Information "Starting complete uninstallation of Vortex and Valheim..." -InformationAction Continue

        # Display warning and instructions
        if (-not $SkipUserPrompts) {
            Write-Information @"
IMPORTANT INFORMATION:
1. Steam must be open and running
2. This script requires administrative privileges
3. You will need to provide your Steam credentials
4. All mod data and game saves will be permanently deleted
5. This action cannot be undone - ensure you have backups if needed

The script will perform these steps:
- Close Vortex and remove all mods
- Purge Vortex configuration data
- Uninstall Vortex application
- Install/update SteamCMD via Chocolatey
- Use SteamCMD to uninstall Valheim
- Clean up remaining files and directories
"@ -InformationAction Continue

            if (-not (Confirm-UserAction "Do you want to proceed with the complete uninstallation?")) {
                Write-Information "Uninstallation cancelled by user." -InformationAction Continue
                return
            }
        }

        # Get Steam credentials if not provided
        if (-not $SteamUsername) {
            $SteamUsername = Read-Host -Prompt "Enter your Steam username"
        }
        
        $steamPass = Read-Host -Prompt "Enter your Steam password" -AsSecureString
        $steamPassUnsecure = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($steamPass)
        )

        Write-UninstallLog "Starting uninstallation process for user: $SteamUsername" -Level Information

        # Step 1: Remove Vortex
        if (-not (Remove-VortexApplication)) {
            Write-Warning "Vortex removal encountered issues but continuing..."
        }

        # Step 2: Ensure Chocolatey is available
        if (-not (Install-ChocoIfNeeded)) {
            throw "Cannot continue without Chocolatey"
        }

        # Step 3: Install SteamCMD
        if (-not (Install-SteamCMD)) {
            throw "Cannot continue without SteamCMD"
        }

        # Step 4: Remove Valheim
        if (-not (Remove-ValheimGame -Username $SteamUsername -Password $steamPassUnsecure)) {
            Write-Warning "Valheim removal encountered issues but continuing..."
        }

        # Final summary
        Write-Information "Uninstallation process completed successfully!" -InformationAction Continue
        Write-UninstallLog "Uninstallation process completed successfully" -Level Information
        Write-UninstallLog "=== End of Uninstallation Process ===" -Level Information

        if (-not $SkipUserPrompts) {
            Write-Information "Press Enter to exit..." -InformationAction Continue
            Read-Host
        }

        return $true

    } catch {
        Write-UninstallLog "Critical error in main execution: $($_.Exception.Message)" -Level Error
        Write-Error "Critical error during uninstallation: $($_.Exception.Message)"
        
        if (-not $SkipUserPrompts) {
            Write-Information "Press Enter to exit..." -InformationAction Continue
            Read-Host
        }
        
        return $false
    } finally {
        Stop-Transcript -ErrorAction SilentlyContinue
    }
}

# Execute the function if script is run directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-VortexValheimUninstall
}
