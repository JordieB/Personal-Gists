<#
.SYNOPSIS
Creates and activates a new Python virtual environment.

.DESCRIPTION
The Create-PythonVenv function creates a new Python virtual environment in the current directory
using 'pyenv' and activates it. It also ensures pip is up-to-date within the virtual environment.

.PARAMETER VenvDirectory
The name of the directory for the virtual environment. Defaults to 'venv'.

.EXAMPLE
Create-PythonVenv
Creates and activates a Python virtual environment in the current directory using the default 'venv' directory name.

.EXAMPLE
Create-PythonVenv -VenvDirectory "myproject_env"
Creates and activates a Python virtual environment in a custom directory named "myproject_env".

.NOTES
Author: Jordie Belle
Prerequisites: PowerShell V5 or higher
Requirements: 
- Python and pyenv must be installed and accessible
- Ensure 'pyenv' points to a valid Python interpreter
- Current directory must be writable
#>
function Create-PythonVenv {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$VenvDirectory = 'venv'
    )

    # Creates a new virtual environment
    function New-VirtualEnvironment {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Directory
        )

        try {
            $pythonPath = (pyenv which python)
            if (-not $pythonPath) {
                Write-Error "Python path not found. Ensure pyenv is correctly configured."
                return $false
            }

            Write-Information "Creating virtual environment in '$Directory'..." -InformationAction Continue
            & $pythonPath -m venv $Directory
            
            if ($LASTEXITCODE -eq 0) {
                Write-Information "Virtual environment created successfully." -InformationAction Continue
                return $true
            } else {
                Write-Error "Failed to create virtual environment. Exit code: $LASTEXITCODE"
                return $false
            }
        } catch {
            Write-Error "Error creating virtual environment: $($_.Exception.Message)"
            return $false
        }
    }

    # Activates the virtual environment and upgrades pip
    function Activate-VenvAndUpdatePip {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Directory
        )

        try {
            $activateScript = Join-Path $Directory "Scripts\Activate.ps1"
            
            if (-not (Test-Path $activateScript)) {
                Write-Error "Activation script not found at: $activateScript"
                return $false
            }

            Write-Information "Activating virtual environment..." -InformationAction Continue
            & $activateScript

            Write-Information "Upgrading pip..." -InformationAction Continue
            python -m pip install --upgrade pip
            
            if ($LASTEXITCODE -eq 0) {
                Write-Information "Pip upgraded successfully." -InformationAction Continue
                return $true
            } else {
                Write-Warning "Pip upgrade completed with warnings. Exit code: $LASTEXITCODE"
                return $true
            }
        } catch {
            Write-Error "Error activating virtual environment or upgrading pip: $($_.Exception.Message)"
            return $false
        }
    }

    # Main execution
    if (New-VirtualEnvironment -Directory $VenvDirectory) {
        Activate-VenvAndUpdatePip -Directory $VenvDirectory
    } else {
        Write-Error "Failed to create virtual environment. Aborting activation."
    }
}