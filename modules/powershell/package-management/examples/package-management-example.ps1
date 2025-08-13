# Example: PackageManagement Module Usage
# 
# This example demonstrates how to use the PackageManagement module.

# Import the module
Import-Module ../PackageManagement.psd1

# Use the example function
try {
    Invoke-PackageManagementExample -ExampleParam "test_value"
    Write-Host "✓ Successfully executed package-management example"
} catch {
    Write-Error "Failed to execute example: $($_.Exception.Message)"
}