<#
.SYNOPSIS
Creates desktop shortcuts for "Device Manager" and "Add or Remove Programs" 
within a folder named "Index Shortcuts".

.NOTES
File Name      : create_desktop_index_shortcuts.ps1
Author         : Jordie Belle
Prerequisite   : PowerShell V2

#>

# Function to log updates
function Log {
    param (
        [string]$message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    Write-Output $logMessage
    Add-Content -Path "$desktopPath\IndexShortcuts.log" -Value $logMessage
}

# Function to create shortcuts
function CreateShortcut {
    param (
        [string]$targetPath,
        [string]$shortcutPath,
        [string]$name,
        [string]$description
    )

    $WScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetPath
    $shortcut.Description = $description
    $shortcut.IconLocation = $targetPath

    if ($targetPath -eq "explorer.exe") {
        $shortcut.WorkingDirectory = "$env:SystemRoot\System32"
    } else {
        $shortcut.WorkingDirectory = (Get-Item $targetPath).DirectoryName
    }

    $shortcut.Save()
}

# Main script logic
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutFolderPath = Join-Path $desktopPath "Index Shortcuts"

# Create the "Index Shortcuts" directory if it doesn't exist
if (-not (Test-Path $shortcutFolderPath)) {
    Log "Creating directory: $shortcutFolderPath"
    New-Item -Path $shortcutFolderPath -ItemType Directory
} else {
    Log "Directory $shortcutFolderPath already exists"
}

# Create a shortcut for "Device Manager" if it doesn't exist
$deviceManagerPath = "$env:SystemRoot\System32\devmgmt.msc"
$deviceManagerShortcutPath = Join-Path $shortcutFolderPath "Device Manager.lnk"

if (-not (Test-Path $deviceManagerShortcutPath)) {
    Log "Creating Device Manager shortcut"
    CreateShortcut -targetPath $deviceManagerPath -shortcutPath $deviceManagerShortcutPath -name "Device Manager" -description "Shortcut for Device Manager"
} else {
    Log "Device Manager shortcut already exists"
}

# Create a shortcut for "Add or Remove Programs" if it doesn't exist
$addOrRemoveProgramsPath = "ms-settings:appsfeatures"
$addOrRemoveProgramsShortcutPath = Join-Path $shortcutFolderPath "Add or Remove Programs.lnk"

if (-not (Test-Path $addOrRemoveProgramsShortcutPath)) {
    Log "Creating Add or Remove Programs shortcut"
    CreateShortcut -targetPath "explorer.exe" -shortcutPath $addOrRemoveProgramsShortcutPath -name "Add or Remove Programs" -description "Shortcut for Add or Remove Programs"
    
    $WScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $WScriptShell.CreateShortcut($addOrRemoveProgramsShortcutPath)
    $shortcut.Arguments = $addOrRemoveProgramsPath
    $shortcut.IconLocation = "$env:SystemRoot\System32\SystemSettingsAdminFlows.exe,0"
    $shortcut.Save()
} else {
    Log "Add or Remove Programs shortcut already exists"
}
