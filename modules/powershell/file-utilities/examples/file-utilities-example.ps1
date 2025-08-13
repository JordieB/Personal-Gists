# Example: FileUtilities Module Usage
# 
# This example demonstrates how to use the FileUtilities module.

# Import the module
Import-Module ../FileUtilities.psd1

# Use the example function
try {
    Invoke-FileUtilitiesExample -ExampleParam "test_value"
    Write-Host "✓ Successfully executed file-utilities example"
} catch {
    Write-Error "Failed to execute example: $($_.Exception.Message)"
}