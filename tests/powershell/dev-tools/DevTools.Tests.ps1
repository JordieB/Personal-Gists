BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../../modules/powershell/dev-tools/DevTools.psd1'
    Import-Module $ModulePath -Force
}

Describe "DevTools Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module DevTools | Should -Not -BeNullOrEmpty
        }
    }

    Context "Invoke-DevToolsExample" {
        It "Should execute without throwing errors" {
            { Invoke-DevToolsExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module DevTools -Force -ErrorAction SilentlyContinue
}