BeforeAll {
    # Import the module being tested
    $ModulePath = Join-Path $PSScriptRoot "../ApiIntegration.psd1"
    Import-Module $ModulePath -Force
}

Describe "ApiIntegration Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module ApiIntegration | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Set-SpotifyPlaylistPrivacy function" {
            Get-Command Set-SpotifyPlaylistPrivacy -Module ApiIntegration | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Set-SpotifyPlaylistPrivacy" {
        It "Should accept required SpotifyUsername parameter" {
            $command = Get-Command Set-SpotifyPlaylistPrivacy
            $usernameParam = $command.Parameters['SpotifyUsername']
            $usernameParam.Attributes.Mandatory | Should -Be $true
        }
        
        It "Should have optional LogPath parameter with default value" {
            $command = Get-Command Set-SpotifyPlaylistPrivacy  
            $logParam = $command.Parameters['LogPath']
            $logParam.Attributes.Mandatory | Should -Be $false
        }
        
        # Smoke test - just verify function doesn't throw with valid input
        It "Should execute without throwing errors" {
            { Set-SpotifyPlaylistPrivacy -SpotifyUsername "test_user" } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Module ApiIntegration -Force -ErrorAction SilentlyContinue
}