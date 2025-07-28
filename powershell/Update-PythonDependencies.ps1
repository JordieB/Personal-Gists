<#
.SYNOPSIS
Updates Python packages and maintains a requirements.txt file.

.DESCRIPTION
The Update-PythonPackages function updates specified Python packages using pip and
records the updated package versions in a requirements.txt file. It's designed to help
maintain an up-to-date record of Python package dependencies.

.PARAMETER PackageNames
An array of Python package names to be updated. All packages should be valid PyPI package names.

.EXAMPLE
Update-PythonPackages -PackageNames 'requests', 'python-dotenv', 'pandas', 'ipykernel'
Updates the specified packages and records their versions in requirements.txt.

.EXAMPLE
Update-PythonPackages -PackageNames @('numpy', 'matplotlib')
Updates numpy and matplotlib packages and records their versions.

.NOTES
Author: Jordie Belle
Prerequisites: PowerShell V5 or higher
Requirements:
- Python and pip must be installed and accessible from the PowerShell environment
- Current directory must be writable for requirements.txt file
- Active Python virtual environment recommended for isolated package management
#>
function Update-PythonPackages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$PackageNames
    )

    # Updates a single Python package and records its version
    function Update-SinglePackage {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$PackageName
        )

        Write-Information "Updating $PackageName..." -InformationAction Continue
        try {
            $updateCommand = "python -m pip install --upgrade $PackageName"
            $updateOutput = Invoke-Expression $updateCommand 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Information "Successfully updated $PackageName" -InformationAction Continue
                Write-Verbose "Update output for $PackageName`: $updateOutput"
                return $true
            } else {
                Write-Error "Failed to update $PackageName. Exit code: $LASTEXITCODE"
                Write-Verbose "Error output: $updateOutput"
                return $false
            }
        } catch {
            Write-Error "Error updating $PackageName`: $($_.Exception.Message)"
            return $false
        }
    }

    # Appends the package version to requirements.txt
    function Append-PackageToRequirements {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$PackageName
        )

        try {
            $freezeOutput = python -m pip freeze | Select-String "^$PackageName=="
            
            if ($freezeOutput) {
                Add-Content -Path "requirements.txt" -Value $freezeOutput -ErrorAction Stop
                Write-Information "Recorded $PackageName in requirements.txt" -InformationAction Continue
                return $true
            } else {
                Write-Warning "Could not find $PackageName in pip freeze output. Package may not be installed correctly."
                return $false
            }
        } catch {
            Write-Error "Error recording $PackageName version: $($_.Exception.Message)"
            return $false
        }
    }

    # Main execution
    $successCount = 0
    $totalCount = $PackageNames.Count
    
    Write-Information "Starting Python package updates for $totalCount packages..." -InformationAction Continue
    
    foreach ($Package in $PackageNames) {
        if (Update-SinglePackage -PackageName $Package) {
            if (Append-PackageToRequirements -PackageName $Package) {
                $successCount++
            }
        }
    }

    Write-Information "Python package updates completed. Successfully processed $successCount of $totalCount packages." -InformationAction Continue
    
    if ($successCount -lt $totalCount) {
        Write-Warning "Some packages failed to update. Check the error messages above for details."
    }
}
