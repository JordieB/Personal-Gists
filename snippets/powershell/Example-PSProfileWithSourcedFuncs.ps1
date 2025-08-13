<#
.SYNOPSIS
    Example PowerShell profile that demonstrates dot-sourcing personal utility functions.

.DESCRIPTION
    This script provides an example of how to structure a PowerShell profile that loads personal utility scripts
    via dot-sourcing. It demonstrates the pattern of loading multiple custom functions into the current session
    for immediate availability in all PowerShell sessions.

.PARAMETER ScriptDirectory
    The directory path where personal PowerShell scripts are located. If not specified, uses a placeholder that should be customized.

.EXAMPLE
    . .\Example-PSProfileWithSourcedFuncs.ps1
    Dot-sources this example profile to load the utility functions.

.EXAMPLE
    . .\Example-PSProfileWithSourcedFuncs.ps1 -ScriptDirectory "C:\MyScripts\PowerShell"
    Loads utility functions from a custom directory path.

.NOTES
    Author: Jordie Belle
    Prerequisites: PowerShell V5 or higher
    Requirements:
    - Target utility scripts must exist in the specified directory
    - Read permissions on the script directory
    - This is an example template that should be customized for actual use
    
    Usage: Copy this template and modify the ScriptDirectory and script list for your environment.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$ScriptDirectory = "[CUSTOMIZE_THIS_PATH]"  # Replace with actual path to your scripts
)

# Validate script directory
if ($ScriptDirectory -eq "[CUSTOMIZE_THIS_PATH]") {
    Write-Warning "This is an example profile. Please customize the ScriptDirectory parameter with your actual script path."
    Write-Information "Example usage: Modify ScriptDirectory to point to your personal PowerShell scripts folder." -InformationAction Continue
    return
}

# List of personal utility scripts to dot-source
$utilityScripts = @(
    'Create-PythonVirtualEnv.ps1',
    'Update-PythonDependencies.ps1',
    'Display-DirectoryTree.ps1'
)

# Dot-source each utility script if it exists
foreach ($scriptName in $utilityScripts) {
    $scriptPath = Join-Path $ScriptDirectory $scriptName
    
    if (Test-Path $scriptPath) {
        try {
            . $scriptPath
            Write-Verbose "Successfully loaded: $scriptName"
        } catch {
            Write-Warning "Failed to load $scriptName`: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "Script not found: $scriptPath"
    }
}

Write-Information "Personal utility functions loaded from: $ScriptDirectory" -InformationAction Continue