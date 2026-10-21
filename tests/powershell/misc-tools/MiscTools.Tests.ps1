BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../../modules/powershell/misc-tools/MiscTools.psd1'
    Import-Module $ModulePath -Force
}

Describe "MiscTools Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module MiscTools | Should -Not -BeNullOrEmpty
        }
    }

    Context "Invoke-MiscToolsExample" {
        It "Should execute without throwing errors" {
            { Invoke-MiscToolsExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module MiscTools -Force -ErrorAction SilentlyContinue
}