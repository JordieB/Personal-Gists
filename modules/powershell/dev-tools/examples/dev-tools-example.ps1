# Example: DevTools Module Usage
# 
# This example demonstrates how to use the DevTools module.

# Import the module
Import-Module ../DevTools.psd1

# Use the example function
try {
    Invoke-DevToolsExample -ExampleParam "test_value"
    Write-Host "✓ Successfully executed dev-tools example"
} catch {
    Write-Error "Failed to execute example: $($_.Exception.Message)"
}