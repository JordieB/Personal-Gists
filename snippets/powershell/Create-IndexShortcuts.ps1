<#
.SYNOPSIS
Creates desktop shortcuts for essential Windows utilities within a folder named "Index Shortcuts".

.DESCRIPTION
This script enhances ease of access to frequently used tools like "Device Manager", "Add or Remove Programs",
"Edit the system environment variables", "Calculator", "Default Apps", "Game Controllers" and "Bluetooth Settings"
using Windows' PowerToys Search. The shortcuts are organized in a dedicated folder on the desktop for easy access.

.PARAMETER ShortcutFolderName
The name of the folder to create on the desktop for organizing shortcuts. Defaults to "Index Shortcuts".

.PARAMETER LogToFile
Whether to log actions to a file. Defaults to $true.

.EXAMPLE
Invoke-CreateIndexShortcuts
Creates shortcuts using default settings in the "Index Shortcuts" folder on the desktop.

.EXAMPLE
Invoke-CreateIndexShortcuts -ShortcutFolderName "My Utilities" -LogToFile $false
Creates shortcuts in a custom folder without file logging.

.NOTES
Author: Jordie Belle
Prerequisites: PowerShell V5 or higher (for COM object support)
Requirements:
- Write permissions on the desktop
- COM object support for creating shortcuts
- Windows operating system with standard system utilities
#>

function Invoke-CreateIndexShortcuts {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ShortcutFolderName = "Index Shortcuts",
        
        [Parameter()]
        [bool]$LogToFile = $true
    )

    # Check for PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "This script requires PowerShell version 5 or higher."
        return $false
    }

    # Define script-level variables
    $DesktopPath = [Environment]::GetFolderPath("Desktop")
    $ShortcutFolderPath = Join-Path $DesktopPath $ShortcutFolderName
    $LogFilePath = Join-Path $ShortcutFolderPath 'IndexShortcuts.log'

    # Logging function
    function Write-ShortcutLog {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Message
        )

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] $Message"
        Write-Information $logMessage -InformationAction Continue
        
        if ($LogToFile) {
            try {
                Add-Content -Path $LogFilePath -Value $logMessage -ErrorAction Stop
            } catch {
                Write-Warning "Failed to write to log file: $($_.Exception.Message)"
            }
        }
    }

    # Function to create a shortcut
    function New-UtilityShortcut {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$TargetPath,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$ShortcutPath,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Name,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Description,

            [Parameter()]
            [string]$Arguments = $null,

            [Parameter()]
            [string]$IconLocation = $null
        )

        try {
            $WScriptShell = New-Object -ComObject WScript.Shell
            $shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
            $shortcut.TargetPath = $TargetPath
            $shortcut.Description = $Description
            $shortcut.WorkingDirectory = if ($TargetPath -eq "explorer.exe") {
                "$env:SystemRoot\System32"
            } else {
                (Get-Item $TargetPath -ErrorAction SilentlyContinue)?.DirectoryName ?? "$env:SystemRoot\System32"
            }

            if ($Arguments)   { $shortcut.Arguments   = $Arguments }
            if ($IconLocation){ $shortcut.IconLocation = $IconLocation }
            else              { $shortcut.IconLocation = $TargetPath }

            $shortcut.Save()
            Write-ShortcutLog "Created shortcut for $Name."
            return $true
        }
        catch {
            Write-ShortcutLog "Error creating shortcut for $Name`: $($_.Exception.Message)"
            Write-Error "Failed to create shortcut for $Name`: $($_.Exception.Message)"
            return $false
        }
    }

    function New-IndexShortcuts {
        [CmdletBinding()]
        param()
        
        # Ensure the shortcuts directory exists
        try {
            if (-not (Test-Path $ShortcutFolderPath)) {
                New-Item -Path $ShortcutFolderPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-ShortcutLog "Created directory: $ShortcutFolderPath"
            }
        } catch {
            Write-Error "Failed to create shortcuts directory: $($_.Exception.Message)"
            return $false
        }

        # Shortcut creation details
        $shortcuts = @(
            @{
                Name        = "Add or Remove Programs"
                Path        = "explorer.exe"
                Description = "Shortcut for Add or Remove Programs"
                Args        = "ms-settings:appsfeatures"
                Icon        = "$env:SystemRoot\System32\SystemSettingsAdminFlows.exe,0"
            },
            @{
                Name        = "Edit Environment Variables"
                Path        = "$env:SystemRoot\System32\rundll32.exe"
                Description = "Shortcut for Edit Environment Variables"
                Args        = "sysdm.cpl,EditEnvironmentVariables"
                Icon        = "$env:SystemRoot\System32\SystemPropertiesAdvanced.exe,0"
            },
            @{
                Name        = "Calculator"
                Path        = "$env:SystemRoot\System32\calc.exe"
                Description = "Shortcut for Calculator"
            },
            @{
                Name        = "Default Apps"
                Path        = "explorer.exe"
                Description = "Shortcut for Default Apps"
                Args        = "ms-settings:defaultapps"
                Icon        = "$env:SystemRoot\System32\SystemSettingsAdminFlows.exe,0"
            },
            @{
                Name        = "Game Controllers"
                Path        = "$env:SystemRoot\System32\control.exe"
                Description = "Shortcut for Game Controllers"
                Args        = "joy.cpl"
                Icon        = "$env:SystemRoot\System32\control.exe,0"
            },
            @{
                Name        = "Device Manager"
                Path        = "$env:SystemRoot\System32\devmgmt.msc"
                Description = "Shortcut for Device Manager"
                Icon        = "$env:SystemRoot\System32\devmgmt.msc,0"
            },
            @{
                Name        = "Bluetooth Settings"
                Path        = "explorer.exe"
                Description = "Shortcut for Bluetooth Settings"
                Args        = "ms-settings:bluetooth"
                Icon        = "$env:SystemRoot\System32\SystemSettingsAdminFlows.exe,0"
            }
        )

        # Iterate through each shortcut detail and create it
        $successCount = 0
        foreach ($shortcut in $shortcuts) {
            $shortcutPath = Join-Path $ShortcutFolderPath "$($shortcut.Name).lnk"

            if (-not (Test-Path $shortcutPath)) {
                if (New-UtilityShortcut `
                    -TargetPath   $shortcut.Path `
                    -ShortcutPath $shortcutPath `
                    -Name         $shortcut.Name `
                    -Description  $shortcut.Description `
                    -Arguments    $shortcut.Args `
                    -IconLocation $shortcut.Icon) {
                    $successCount++
                }
            }
            else {
                Write-ShortcutLog "$($shortcut.Name) shortcut already exists"
                $successCount++
            }
        }
        
        Write-ShortcutLog "Shortcut creation completed. Successfully processed $successCount of $($shortcuts.Count) shortcuts."
        return $successCount -eq $shortcuts.Count
    }

    # Main execution
    try {
        Write-ShortcutLog "Starting Index Shortcuts creation..."
        $result = New-IndexShortcuts
        
        if ($result) {
            Write-Information "Index shortcuts created successfully in: $ShortcutFolderPath" -InformationAction Continue
        } else {
            Write-Warning "Some shortcuts may not have been created successfully. Check the log for details."
        }
        
        return $result
    } catch {
        Write-Error "Critical error during shortcut creation: $($_.Exception.Message)"
        return $false
    }
}

# Execute the function if script is run directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-CreateIndexShortcuts
}
