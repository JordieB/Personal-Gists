BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot "../SoftwareManagement.psd1"
    Import-Module $ModulePath -Force
}

Describe "SoftwareManagement Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module SoftwareManagement | Should -Not -BeNullOrEmpty
        }
    }

    Context "Invoke-SoftwareManagementExample" {
        It "Should execute without throwing errors" {
            { Invoke-SoftwareManagementExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module SoftwareManagement -Force -ErrorAction SilentlyContinue
}