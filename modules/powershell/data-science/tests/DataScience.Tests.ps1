BeforeAll {
    # Import the module being tested
    $ModulePath = Join-Path $PSScriptRoot "../DataScience.psd1"
    Import-Module $ModulePath -Force
}

Describe "DataScience Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module DataScience | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Invoke-DataScienceExample function" {
            Get-Command Invoke-DataScienceExample -Module DataScience | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-DataScienceExample" {
        It "Should have ExampleParam parameter" {
            $command = Get-Command Invoke-DataScienceExample
            $command.Parameters['ExampleParam'] | Should -Not -BeNullOrEmpty
        }
        
        # Smoke test - just verify function doesn't throw
        It "Should execute without throwing errors" {
            { Invoke-DataScienceExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module DataScience -Force -ErrorAction SilentlyContinue
}