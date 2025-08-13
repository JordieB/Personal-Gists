BeforeAll {
    # Import the module being tested
    $ModulePath = Join-Path $PSScriptRoot "../MiscTools.psd1"
    Import-Module $ModulePath -Force
}

Describe "MiscTools Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module MiscTools | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Invoke-MiscToolsExample function" {
            Get-Command Invoke-MiscToolsExample -Module MiscTools | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-MiscToolsExample" {
        It "Should have ExampleParam parameter" {
            $command = Get-Command Invoke-MiscToolsExample
            $command.Parameters['ExampleParam'] | Should -Not -BeNullOrEmpty
        }
        
        # Smoke test - just verify function doesn't throw
        It "Should execute without throwing errors" {
            { Invoke-MiscToolsExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module MiscTools -Force -ErrorAction SilentlyContinue
}