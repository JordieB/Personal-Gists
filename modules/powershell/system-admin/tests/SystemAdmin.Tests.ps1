BeforeAll {
    # Import the module being tested
    $ModulePath = Join-Path $PSScriptRoot "../SystemAdmin.psd1"
    Import-Module $ModulePath -Force
}

Describe "SystemAdmin Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module SystemAdmin | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Invoke-SystemAdminExample function" {
            Get-Command Invoke-SystemAdminExample -Module SystemAdmin | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-SystemAdminExample" {
        It "Should have ExampleParam parameter" {
            $command = Get-Command Invoke-SystemAdminExample
            $command.Parameters['ExampleParam'] | Should -Not -BeNullOrEmpty
        }
        
        # Smoke test - just verify function doesn't throw
        It "Should execute without throwing errors" {
            { Invoke-SystemAdminExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module SystemAdmin -Force -ErrorAction SilentlyContinue
}