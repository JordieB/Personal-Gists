BeforeAll {
    # Import the module being tested
    $ModulePath = Join-Path $PSScriptRoot "../SoftwareManagement.psd1"
    Import-Module $ModulePath -Force
}

Describe "SoftwareManagement Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module SoftwareManagement | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Invoke-SoftwareManagementExample function" {
            Get-Command Invoke-SoftwareManagementExample -Module SoftwareManagement | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-SoftwareManagementExample" {
        It "Should have ExampleParam parameter" {
            $command = Get-Command Invoke-SoftwareManagementExample
            $command.Parameters['ExampleParam'] | Should -Not -BeNullOrEmpty
        }
        
        # Smoke test - just verify function doesn't throw
        It "Should execute without throwing errors" {
            { Invoke-SoftwareManagementExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module SoftwareManagement -Force -ErrorAction SilentlyContinue
}