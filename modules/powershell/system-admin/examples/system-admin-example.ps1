# Example: SystemAdmin Module Usage
# 
# This example demonstrates how to use the SystemAdmin module.

# Import the module
Import-Module ../SystemAdmin.psd1

# Use the example function
try {
    Invoke-SystemAdminExample -ExampleParam "test_value"
    Write-Host "✓ Successfully executed system-admin example"
} catch {
    Write-Error "Failed to execute example: $($_.Exception.Message)"
}