<#
.SYNOPSIS
    Performs maintenance on Chocolatey packages by upgrading all installed packages.

.DESCRIPTION
    This function upgrades all Chocolatey packages to their latest versions and logs the process.
    It provides comprehensive logging of the upgrade process and handles errors gracefully.

.PARAMETER LogPath
    The path where the maintenance log file will be stored. Defaults to the user's desktop.

.PARAMETER Verbose
    When specified, includes detailed output from Chocolatey operations in the log.

.EXAMPLE
    Invoke-ChocoMaintenance
    Performs Chocolatey maintenance using default settings and logs to the desktop.

.EXAMPLE
    Invoke-ChocoMaintenance -LogPath "C:\Logs\choco_maintenance.log" -Verbose
    Performs maintenance with custom log path and verbose output.

.NOTES
    Author: Jordie Belle
    Prerequisites: PowerShell V5 or higher
    Requirements:
    - Chocolatey must be installed and accessible from PowerShell
    - Administrative privileges may be required for some package upgrades
    - Internet connection required for downloading package updates
#>

function Invoke-ChocoMaintenance {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = "$env:USERPROFILE\Desktop\choco_maintenance.log",
        
        [Parameter()]
        [switch]$IncludeProgressOutput
    )

    # Function to log messages with timestamps
    function Write-MaintenanceLog {
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
        $logEntry = "$timestamp - $Message"
        
        # Output to console based on level
        switch ($Level) {
            'Information' { Write-Information $logEntry -InformationAction Continue }
            'Warning' { Write-Warning $logEntry }
            'Error' { Write-Error $logEntry }
        }
        
        # Always log to file
        try {
            Add-Content -Path $LogPath -Value $logEntry -ErrorAction Stop
        } catch {
            Write-Error "Failed to write to log file: $($_.Exception.Message)"
        }
    }

    # Main maintenance function
    function Start-PackageUpgrade {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string]$LogPath,
            
            [Parameter()]
            [bool]$IncludeProgress
        )

        Write-MaintenanceLog "Starting Chocolatey package maintenance." -Level Information

        # Check if Chocolatey is available
        try {
            $chocoVersion = choco --version 2>$null
            if (-not $chocoVersion) {
                Write-MaintenanceLog "Chocolatey is not installed or not accessible from PATH." -Level Error
                return $false
            }
            Write-MaintenanceLog "Chocolatey version: $chocoVersion" -Level Information
        } catch {
            Write-MaintenanceLog "Error checking Chocolatey version: $($_.Exception.Message)" -Level Error
            return $false
        }

        # Upgrade all Chocolatey packages
        Write-MaintenanceLog "Upgrading all Chocolatey packages..." -Level Information
        try {
            $upgradeOutput = if ($IncludeProgress) {
                choco upgrade all -y 2>&1
            } else {
                choco upgrade all -y 2>&1 | Where-Object { $_ -notmatch "Progress: Downloading" }
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-MaintenanceLog "Package upgrade completed successfully." -Level Information
                
                # Log the upgrade output
                $upgradeOutput | ForEach-Object { 
                    Write-MaintenanceLog "CHOCO: $_" -Level Information
                }
                return $true
            } else {
                Write-MaintenanceLog "Package upgrade completed with errors. Exit code: $LASTEXITCODE" -Level Warning
                $upgradeOutput | ForEach-Object { 
                    Write-MaintenanceLog "CHOCO: $_" -Level Warning
                }
                return $false
            }
        } catch {
            Write-MaintenanceLog "Error during package upgrade: $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    # Main execution
    try {
        # Ensure log directory exists
        $logDirectory = Split-Path $LogPath -Parent
        if (-not (Test-Path $logDirectory)) {
            New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop
            Write-Information "Created log directory: $logDirectory" -InformationAction Continue
        }

        # Start the maintenance process
        $success = Start-PackageUpgrade -LogPath $LogPath -IncludeProgress $IncludeProgressOutput.IsPresent

        # Final logging
        Write-MaintenanceLog "Chocolatey package maintenance completed." -Level Information
        Write-MaintenanceLog "See Chocolatey managed logs at: C:\ProgramData\chocolatey\logs\chocolatey.log" -Level Information
        
        if ($success) {
            Write-Information "Maintenance completed successfully. Log saved to: $LogPath" -InformationAction Continue
        } else {
            Write-Warning "Maintenance completed with issues. Check log for details: $LogPath"
        }
        
        return $success
    } catch {
        Write-Error "Critical error during maintenance: $($_.Exception.Message)"
        return $false
    }
}