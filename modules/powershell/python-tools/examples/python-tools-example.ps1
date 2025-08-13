# Example: PythonTools Module Usage
# 
# This example demonstrates how to use the PythonTools module.

# Import the module
Import-Module ../PythonTools.psd1

# Use the example function
try {
    Invoke-PythonToolsExample -ExampleParam "test_value"
    Write-Host "✓ Successfully executed python-tools example"
} catch {
    Write-Error "Failed to execute example: $($_.Exception.Message)"
}