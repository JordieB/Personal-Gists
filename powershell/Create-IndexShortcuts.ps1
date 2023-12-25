<#
.SYNOPSIS
Creates desktop shortcuts for essential Windows utilities within a folder named "Index Shortcuts".

.DESCRIPTION
This script enhances ease of access to frequently used tools like "Device Manager", "Add or Remove Programs",
"Edit the system environment variables", "Calculator", and "Default Apps" using Windows' PowerToys Search.

.NOTES
Author         : Jordie Belle
Prerequisite   : PowerShell V5 or higher (for ComObject support)
#>

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
    Add-Content -Path "$global:ShortcutFolderPath\IndexShortcuts.log" -Value $logMessage
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

function Create-IndexShortcuts {
    $global:DesktopPath = [Environment]::GetFolderPath("Desktop")
    $global:ShortcutFolderPath = Join-Path $global:DesktopPath "Index Shortcuts"

    # Ensure the "Index Shortcuts" directory exists
    if (-not (Test-Path $global:ShortcutFolderPath)) {
        New-Item -Path $global:ShortcutFolderPath -ItemType Directory | Out-Null
        Write-Log "Created directory: $global:ShortcutFolderPath"
    }

    # Shortcut creation details
    $shortcuts = @(
        @{ Name = "Add or Remove Programs"; Path = "explorer.exe"; Description = "Shortcut for Add or Remove Programs"; Args = "ms-settings:appsfeatures"; Icon = "$env:SystemRoot\System32\SystemSettingsAdminFlows.exe,0" },
        @{ Name = "Edit Environment Variables"; Path = "$env:SystemRoot\System32\rundll32.exe"; Description = "Shortcut for Edit Environment Variables"; Args = "sysdm.cpl,EditEnvironmentVariables"; Icon = "$env:SystemRoot\System32\SystemPropertiesAdvanced.exe,0" },
        @{ Name = "Calculator"; Path = "$env:SystemRoot\System32\calc.exe"; Description = "Shortcut for Calculator" },
        @{ Name = "Default Apps"; Path = "explorer.exe"; Description = "Shortcut for Default Apps"; Args = "ms-settings:defaultapps"; Icon = "$env:SystemRoot\System32\SystemSettingsAdminFlows.exe,0" }
    )

    # Iterate through each shortcut detail and create it
    foreach ($shortcut in $shortcuts) {
        $shortcutPath = Join-Path $global:ShortcutFolderPath "$($shortcut.Name).lnk"

        if (-not (Test-Path $shortcutPath)) {
            New-Shortcut -TargetPath $shortcut.Path -ShortcutPath $shortcutPath -Name $shortcut.Name -Description $shortcut.Description -Arguments $shortcut.Args -IconLocation $shortcut.Icon
        } else {
            Write-Log "$($shortcut.Name) shortcut already exists"
        }
    }
}
