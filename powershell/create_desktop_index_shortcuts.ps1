<#
.SYNOPSIS
Creates desktop shortcuts for "Device Manager", "Add or Remove Programs",
"Edit the system environment variables", "Calculator", and "Default Apps"
within a folder named "Index Shortcuts". This script enhances the ease of
finding essential settings and utilities using Windows' PowerToys Search
program, providing quick access to frequently used tools.

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
        $shortcut.WorkingDirectory = `
            (Get-Item $targetPath).DirectoryName
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

# Create a shortcut for "Add or Remove Programs" if it doesn't exist
$addOrRemoveProgramsPath = "ms-settings:appsfeatures"
$addOrRemoveProgramsShortcutPath = Join-Path $shortcutFolderPath `
    "Add or Remove Programs.lnk"

if (-not (Test-Path $addOrRemoveProgramsShortcutPath)) {
    Log "Creating Add or Remove Programs shortcut"
    CreateShortcut -targetPath "explorer.exe" `
                   -shortcutPath $addOrRemoveProgramsShortcutPath `
                   -name "Add or Remove Programs" `
                   -description "Shortcut for Add or Remove Programs"
    
    $WScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $WScriptShell.CreateShortcut(`
        $addOrRemoveProgramsShortcutPath)
    $shortcut.Arguments = $addOrRemoveProgramsPath
    $shortcut.IconLocation = "$env:SystemRoot\System32\" `
        + "SystemSettingsAdminFlows.exe,0"
    $shortcut.Save()
} else {
    Log "Add or Remove Programs shortcut already exists"
}

# Create a shortcut for "Edit the system environment variables" if it doesn't
# exist
$editEnvVarsPath = "$env:SystemRoot\System32\rundll32.exe"
$editEnvVarsShortcutPath = Join-Path $shortcutFolderPath `
    "Edit Environment Variables.lnk"
$editEnvVarsArgs = "sysdm.cpl,EditEnvironmentVariables"

if (-not (Test-Path $editEnvVarsShortcutPath)) {
    Log "Creating Edit Environment Variables shortcut"
    CreateShortcut -targetPath $editEnvVarsPath `
                   -shortcutPath $editEnvVarsShortcutPath `
                   -name "Edit Environment Variables" `
                   -description "Shortcut for Edit Environment Variables"
    
    $WScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $WScriptShell.CreateShortcut(`
        $editEnvVarsShortcutPath)
    $shortcut.Arguments = $editEnvVarsArgs
    $shortcut.IconLocation = "$env:SystemRoot\System32\" `
        + "SystemPropertiesAdvanced.exe,0"
    $shortcut.Save()
} else {
    Log "Edit Environment Variables shortcut already exists"
}

# Additional code for "Calculator" shortcut
$calculatorPath = "$env:SystemRoot\System32\calc.exe"
$calculatorShortcutPath = Join-Path $shortcutFolderPath "Calculator.lnk"

if (-not (Test-Path $calculatorShortcutPath)) {
    Log "Creating Calculator shortcut"
    CreateShortcut -targetPath $calculatorPath `
                   -shortcutPath $calculatorShortcutPath `
                   -name "Calculator" `
                   -description "Shortcut for Calculator"
} else {
    Log "Calculator shortcut already exists"
}

# Additional code for "Default Apps" shortcut
$defaultAppsPath = "ms-settings:defaultapps"
$defaultAppsShortcutPath = Join-Path $shortcutFolderPath "Default Apps.lnk"

if (-not (Test-Path $defaultAppsShortcutPath)) {
    Log "Creating Default Apps shortcut"
    CreateShortcut -targetPath "explorer.exe" `
                   -shortcutPath $defaultAppsShortcutPath `
                   -name "Default Apps" `
                   -description "Shortcut for Default Apps"
    
    $WScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $WScriptShell.CreateShortcut(`
        $defaultAppsShortcutPath)
    $shortcut.Arguments = $defaultAppsPath
    $shortcut.IconLocation = "$env:SystemRoot\System32\" `
        + "SystemSettingsAdminFlows.exe,0"
    $shortcut.Save()
} else {
    Log "Default Apps shortcut already exists"
}
