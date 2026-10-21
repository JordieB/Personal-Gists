BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../../modules/powershell/data-science/DataScience.psd1'
    Import-Module $ModulePath -Force
}

Describe "DataScience Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module DataScience | Should -Not -BeNullOrEmpty
        }
    }

    Context "Invoke-DataScienceExample" {
        It "Should execute without throwing errors" {
            { Invoke-DataScienceExample } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module DataScience -Force -ErrorAction SilentlyContinue
}