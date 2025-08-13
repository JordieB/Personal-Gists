# Example: DataScience Module Usage
# 
# This example demonstrates how to use the DataScience module.

# Import the module
Import-Module ../DataScience.psd1

# Use the example function
try {
    Invoke-DataScienceExample -ExampleParam "test_value"
    Write-Host "✓ Successfully executed data-science example"
} catch {
    Write-Error "Failed to execute example: $($_.Exception.Message)"
}