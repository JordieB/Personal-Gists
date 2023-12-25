<#
.SYNOPSIS
Creates and activates a new Python virtual environment.

.DESCRIPTION
The Create-PythonVenv function creates a new Python virtual environment in the current directory
using 'pyenv' and activates it. It also ensures pip is up-to-date within the virtual environment.

.EXAMPLE
Create-PythonVenv
Creates and activates a Python virtual environment in the current directory.

.NOTES
Requires Python and pyenv to be installed and accessible. Ensure 'pyenv' points to a valid Python interpreter.
#>
function Create-PythonVenv {
    [CmdletBinding()]
    param (
        [string]$VenvDirectory = 'venv'
    )

    # Creates a new virtual environment
    function New-VirtualEnvironment {
        param (
            [Parameter(Mandatory)]
            [string]$Directory
        )

        $pythonPath = (pyenv which python)
        if (-not $pythonPath) {
            Write-Host "Python path not found. Ensure pyenv is correctly configured." -ForegroundColor Red
            return
        }

        Write-Host "Creating virtual environment in '$Directory'..."
        & $pythonPath -m venv $Directory
    }

    # Activates the virtual environment and upgrades pip
    function Activate-VenvAndUpdatePip {
        param (
            [Parameter(Mandatory)]
            [string]$Directory
        )

        Write-Host "Activating virtual environment..."
        & "$Directory\Scripts\Activate.ps1"

        Write-Host "Upgrading pip..."
        python -m pip install --upgrade pip
    }

    New-VirtualEnvironment -Directory $VenvDirectory
    Activate-VenvAndUpdatePip -Directory $VenvDirectory
}