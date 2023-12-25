<#
.SYNOPSIS
Updates Python packages and maintains a requirements.txt file.

.DESCRIPTION
The Update-PythonPackages function updates specified Python packages using pip and
records the updated package versions in a requirements.txt file. It's designed to help
maintain an up-to-date record of Python package dependencies.

.PARAMETER PackageNames
An array of Python package names to be updated.

.EXAMPLE
Update-PythonPackages -PackageNames 'requests', 'python-dotenv', 'pandas', 'ipykernel'
Updates the packages and records their versions in requirements.txt.

.NOTES
Requires Python and pip to be installed and accessible from the PowerShell environment.
#>
function Update-PythonPackages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$PackageNames
    )

    # Updates a single Python package and records its version
    function Update-SinglePackage {
        param (
            [string]$PackageName
        )

        Write-Host "Updating  ${PackageName}..."
        try {
            $updateCommand = "python -m pip install --upgrade  ${PackageName}"
            $updateOutput = Invoke-Expression $updateCommand 2>&1
            Write-Host "Update output for ${PackageName}:`n$updateOutput"
        } catch {
            Write-Host "Error updating  ${PackageName}:`n$($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Appends the package version to requirements.txt
    function Append-PackageToRequirements {
        param (
            [string]$PackageName
        )

        try {
            $freezeOutput = python -m pip freeze | Select-String $PackageName
            Add-Content -Path "requirements.txt" -Value $freezeOutput
            Write-Host "Recorded  ${PackageName} in requirements.txt"
        } catch {
            Write-Host "Error recording  ${PackageName} version:`n$($_.Exception.Message)" -ForegroundColor Red
        }
    }

    foreach ($Package in $PackageNames) {
        Update-SinglePackage -PackageName $Package
        Append-PackageToRequirements -PackageName $Package
    }

    Write-Host "Python package updates completed."
}
