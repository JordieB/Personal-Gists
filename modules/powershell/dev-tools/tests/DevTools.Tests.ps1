BeforeAll {
    # Import the module being tested
    $ModulePath = Join-Path $PSScriptRoot "../DevTools.psd1"
    Import-Module $ModulePath -Force
}

Describe "DevTools Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module DevTools | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Invoke-DevToolsExample function" {
            Get-Command Invoke-DevToolsExample -Module DevTools | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-DevToolsExample" {
        It "Should have ExampleParam parameter" {
            $command = Get-Command Invoke-DevToolsExample
            $command.Parameters['ExampleParam'] | Should -Not -BeNullOrEmpty
        }
        
        # Smoke test - just verify function doesn't throw
        It "Should execute without throwing errors" {
            { Invoke-DevToolsExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module DevTools -Force -ErrorAction SilentlyContinue
}