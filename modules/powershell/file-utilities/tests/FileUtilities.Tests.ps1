BeforeAll {
    # Import the module being tested
    $ModulePath = Join-Path $PSScriptRoot "../FileUtilities.psd1"
    Import-Module $ModulePath -Force
}

Describe "FileUtilities Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module FileUtilities | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Invoke-FileUtilitiesExample function" {
            Get-Command Invoke-FileUtilitiesExample -Module FileUtilities | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-FileUtilitiesExample" {
        It "Should have ExampleParam parameter" {
            $command = Get-Command Invoke-FileUtilitiesExample
            $command.Parameters['ExampleParam'] | Should -Not -BeNullOrEmpty
        }
        
        # Smoke test - just verify function doesn't throw
        It "Should execute without throwing errors" {
            { Invoke-FileUtilitiesExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module FileUtilities -Force -ErrorAction SilentlyContinue
}