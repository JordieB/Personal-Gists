# Example: MiscTools Module Usage
# 
# This example demonstrates how to use the MiscTools module.

# Import the module
Import-Module ../MiscTools.psd1

# Use the example function
try {
    Invoke-MiscToolsExample -ExampleParam "test_value"
    Write-Host "✓ Successfully executed misc-tools example"
} catch {
    Write-Error "Failed to execute example: $($_.Exception.Message)"
}