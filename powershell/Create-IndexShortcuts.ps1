<#
.SYNOPSIS
Creates desktop shortcuts for essential Windows utilities within a folder named "Index Shortcuts".

.DESCRIPTION
This script enhances ease of access to frequently used tools like "Device Manager", "Add or Remove Programs",
"Edit the system environment variables", "Calculator", "Default Apps", and "Game Controllers" using Windows' PowerToys Search.

.NOTES
Author         : Jordie Belle
Prerequisite   : PowerShell V5 or higher (for COM object support)
#>

# Check for PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "This script requires PowerShell version 5 or higher."
    exit
}

# Define script-level variables
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ShortcutFolderPath = Join-Path $DesktopPath "Index Shortcuts"
$LogFilePath = Join-Path $ShortcutFolderPath 'IndexShortcuts.log'

# Logging function
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Output $logMessage
    Add-Content -Path $LogFilePath -Value $logMessage
}

# Function to create a shortcut
function New-Shortcut {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$TargetPath,

        [Parameter(Mandatory)]
        [string]$ShortcutPath,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Description,

        [string]$Arguments = $null,

        [string]$IconLocation = $null
    )

    try {
        $WScriptShell = New-Object -ComObject WScript.Shell
        $shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
        $shortcut.TargetPath = $TargetPath
        $shortcut.Description = $Description
        $shortcut.WorkingDirectory = if ($TargetPath -eq "explorer.exe") { "$env:SystemRoot\System32" } else { (Get-Item $TargetPath).DirectoryName }

        if ($Arguments) { $shortcut.Arguments = $Arguments }
        if ($IconLocation) { $shortcut.IconLocation = $IconLocation } else { $shortcut.IconLocation = $TargetPath }

        $shortcut.Save()
        Write-Log "Created shortcut for $Name."
    }
    catch {
        Write-Log "Error creating shortcut for $Name: $_"
    }
}

function Create-IndexShortcuts {
    # Ensure the "Index Shortcuts" directory exists
    if (-not (Test-Path $ShortcutFolderPath)) {
        New-Item -Path $ShortcutFolderPath -ItemType Directory | Out-Null
        Write-Log "Created directory: $ShortcutFolderPath"
    }

    # Shortcut creation details
    $shortcuts = @(
        @{
            Name = "Add or Remove Programs"
            Path = "explorer.exe"
            Description = "Shortcut for Add or Remove Programs"
            Args = "ms-settings:appsfeatures"
            Icon = "$env:SystemRoot\System32\SystemSettingsAdminFlows.exe,0"
        },
        @{
            Name = "Edit Environment Variables"
            Path = "$env:SystemRoot\System32\rundll32.exe"
            Description = "Shortcut for Edit Environment Variables"
            Args = "sysdm.cpl,EditEnvironmentVariables"
            Icon = "$env:SystemRoot\System32\SystemPropertiesAdvanced.exe,0"
        },
        @{
            Name = "Calculator"
            Path = "$env:SystemRoot\System32\calc.exe"
            Description = "Shortcut for Calculator"
        },
        @{
            Name = "Default Apps"
            Path = "explorer.exe"
            Description = "Shortcut for Default Apps"
            Args = "ms-settings:defaultapps"
            Icon = "$env:SystemRoot\System32\SystemSettingsAdminFlows.exe,0"
        },
        @{
            Name = "Game Controllers"
            Path = "$env:SystemRoot\System32\control.exe"
            Description = "Shortcut for Game Controllers"
            Args = "joy.cpl"
            Icon = "$env:SystemRoot\System32\control.exe,0"
        },
        @{
            Name = "Device Manager"
            Path = "$env:SystemRoot\System32\devmgmt.msc"
            Description = "Shortcut for Device Manager"
            Icon = "$env:SystemRoot\System32\devmgmt.msc,0"
        }
    )

    # Iterate through each shortcut detail and create it
    foreach ($shortcut in $shortcuts) {
        $shortcutPath = Join-Path $ShortcutFolderPath "$($shortcut.Name).lnk"

        if (-not (Test-Path $shortcutPath)) {
            New-Shortcut -TargetPath $shortcut.Path -ShortcutPath $shortcutPath -Name $shortcut.Name -Description $shortcut.Description -Arguments $shortcut.Args -IconLocation $shortcut.Icon
        } else {
            Write-Log "$($shortcut.Name) shortcut already exists"
        }
    }
}

# Main function
function Main {
    Create-IndexShortcuts
}

# Execute main function
Main
