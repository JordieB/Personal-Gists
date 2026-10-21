BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../../modules/powershell/python-tools/PythonTools.psd1'
    Import-Module $ModulePath -Force
}

Describe "PythonTools Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module PythonTools | Should -Not -BeNullOrEmpty
        }
    }

    Context "Invoke-PythonToolsExample" {
        It "Should execute without throwing errors" {
            { Invoke-PythonToolsExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module PythonTools -Force -ErrorAction SilentlyContinue
}