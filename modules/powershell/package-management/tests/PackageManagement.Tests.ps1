BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot "../PackageManagement.psd1"
    Import-Module $ModulePath -Force
}

Describe "PackageManagement Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module PackageManagement | Should -Not -BeNullOrEmpty
        }
    }

    Context "Invoke-PackageManagementExample" {
        It "Should execute without throwing errors" {
            { Invoke-PackageManagementExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module PackageManagement -Force -ErrorAction SilentlyContinue
}