BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot "../FileUtilities.psd1"
    Import-Module $ModulePath -Force
}

Describe "FileUtilities Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module FileUtilities | Should -Not -BeNullOrEmpty
        }
    }

    Context "Invoke-FileUtilitiesExample" {
        It "Should execute without throwing errors" {
            { Invoke-FileUtilitiesExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module FileUtilities -Force -ErrorAction SilentlyContinue
}