BeforeAll {
    # Import the module being tested
    $ModulePath = Join-Path $PSScriptRoot "../PythonTools.psd1"
    Import-Module $ModulePath -Force
}

Describe "PythonTools Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module PythonTools | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Invoke-PythonToolsExample function" {
            Get-Command Invoke-PythonToolsExample -Module PythonTools | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-PythonToolsExample" {
        It "Should have ExampleParam parameter" {
            $command = Get-Command Invoke-PythonToolsExample
            $command.Parameters['ExampleParam'] | Should -Not -BeNullOrEmpty
        }
        
        # Smoke test - just verify function doesn't throw
        It "Should execute without throwing errors" {
            { Invoke-PythonToolsExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module PythonTools -Force -ErrorAction SilentlyContinue
}