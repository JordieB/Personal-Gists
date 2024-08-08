<#
.SYNOPSIS
    PowerShell profile script to set up the environment with custom functions, aliases, and imported modules.

.DESCRIPTION
    This profile script initializes the PowerShell environment by dot-sourcing personal gists, 
    importing necessary modules, and setting up custom configurations and aliases.

.NOTES
    Author: Jordie Belle
    Ensure all referenced scripts and modules are available in the specified paths.
#>

# Define the directory containing personal gists
$ScriptDirectory = "C:\Users\jordi\projects\_personal_gists\powershell"

# Dot-source personal gists
. "$ScriptDirectory\Create-PythonVirtualEnv.ps1"
. "$ScriptDirectory\Update-PythonDependencies.ps1"
. "$ScriptDirectory\Display-DirectoryTree.ps1"
. "$ScriptDirectory\Start-Albion-Data-Project.ps1"
. "$ScriptDirectory\Maintain-Choco.ps1"

# Import the Chocolatey Profile that contains the necessary code to enable 
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab 
# completion for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# Init jabba
if (Test-Path "$HOME\.jabba\jabba.ps1") { . "$HOME\.jabba\jabba.ps1" }

# Set the environment variable for Python post-processing with Black
$env:PYTHON_POST_PROCESS_FILE = "black"

# Set pipx to use whatever pyenv is set to
$PIPX_DEFAULT_PYTHON = $(pyenv which python)
[System.Environment]::SetEnvironmentVariable('PIPX_DEFAULT_PYTHON', $PIPX_DEFAULT_PYTHON, [System.EnvironmentVariableTarget]::User)
