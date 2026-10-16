BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot "../SystemAdmin.psd1"
    Import-Module $ModulePath -Force
}

Describe "SystemAdmin Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module SystemAdmin | Should -Not -BeNullOrEmpty
        }
    }

    Context "Invoke-SystemAdminExample" {
        It "Should execute without throwing errors" {
            { Invoke-SystemAdminExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module SystemAdmin -Force -ErrorAction SilentlyContinue
}