# Example: SoftwareManagement Module Usage
# 
# This example demonstrates how to use the SoftwareManagement module.

# Import the module
Import-Module ../SoftwareManagement.psd1

# Use the example function
try {
    Invoke-SoftwareManagementExample -ExampleParam "test_value"
    Write-Host "✓ Successfully executed software-management example"
} catch {
    Write-Error "Failed to execute example: $($_.Exception.Message)"
}