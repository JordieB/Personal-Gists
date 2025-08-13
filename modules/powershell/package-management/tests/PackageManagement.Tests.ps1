BeforeAll {
    # Import the module being tested
    $ModulePath = Join-Path $PSScriptRoot "../PackageManagement.psd1"
    Import-Module $ModulePath -Force
}

Describe "PackageManagement Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module PackageManagement | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Invoke-PackageManagementExample function" {
            Get-Command Invoke-PackageManagementExample -Module PackageManagement | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-PackageManagementExample" {
        It "Should have ExampleParam parameter" {
            $command = Get-Command Invoke-PackageManagementExample
            $command.Parameters['ExampleParam'] | Should -Not -BeNullOrEmpty
        }
        
        # Smoke test - just verify function doesn't throw
        It "Should execute without throwing errors" {
            { Invoke-PackageManagementExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module PackageManagement -Force -ErrorAction SilentlyContinue
}