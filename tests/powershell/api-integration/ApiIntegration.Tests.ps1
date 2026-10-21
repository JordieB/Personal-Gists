BeforeAll {
    function global:Get-SpotifyApplication { [CmdletBinding()] param([string]$Name) }
    function global:Get-UserPlaylists { [CmdletBinding()] param([string]$Id) }
    function global:Set-Playlist { [CmdletBinding()] param([string]$Id, [bool]$Public) }
    function global:Get-Playlist { [CmdletBinding()] param([string]$Id) }
    $ModulePath = Join-Path $PSScriptRoot '../../../modules/powershell/api-integration/ApiIntegration.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Set-SpotifyPlaylistPrivacy' {
    BeforeEach {
        Mock Get-Module { [pscustomobject]@{ Name = 'Spotishell' } } -ModuleName ApiIntegration
        Mock Add-Content {} -ModuleName ApiIntegration
        Mock Get-SpotifyApplication { [pscustomobject]@{ Name = 'default' } } -ModuleName ApiIntegration
        Mock Get-UserPlaylists { @() } -ModuleName ApiIntegration
        Mock Set-Playlist {} -ModuleName ApiIntegration
        Mock Get-Playlist { [pscustomobject]@{ public = $false } } -ModuleName ApiIntegration
    }

    It 'returns success when there are no owned public playlists' {
        $result = Set-SpotifyPlaylistPrivacy -SpotifyUsername 'owner' -LogPath "$TestDrive/spotify.log"
        $result | Should -BeTrue
        Should -Invoke Set-Playlist -Times 0 -ModuleName ApiIntegration
    }

    It 'changes and verifies only owned public playlists' {
        Mock Get-UserPlaylists {
            @(
                [pscustomobject]@{ id = 'owned'; name = 'Owned'; public = $true; owner = [pscustomobject]@{ uri = 'spotify:user:owner' } }
                [pscustomobject]@{ id = 'private'; name = 'Private'; public = $false; owner = [pscustomobject]@{ uri = 'spotify:user:owner' } }
                [pscustomobject]@{ id = 'foreign'; name = 'Foreign'; public = $true; owner = [pscustomobject]@{ uri = 'spotify:user:other' } }
            )
        } -ModuleName ApiIntegration

        $result = Set-SpotifyPlaylistPrivacy -SpotifyUsername 'owner' -LogPath "$TestDrive/spotify.log"

        $result | Should -BeTrue
        Should -Invoke Set-Playlist -Times 1 -ModuleName ApiIntegration -ParameterFilter { $Id -eq 'owned' -and $Public -eq $false }
        Should -Invoke Get-Playlist -Times 1 -ModuleName ApiIntegration -ParameterFilter { $Id -eq 'owned' }
    }

    It 'returns failure when privacy verification fails' {
        Mock Get-UserPlaylists {
            @([pscustomobject]@{ id = 'owned'; name = 'Owned'; public = $true; owner = [pscustomobject]@{ uri = 'spotify:user:owner' } })
        } -ModuleName ApiIntegration
        Mock Get-Playlist { [pscustomobject]@{ public = $true } } -ModuleName ApiIntegration

        $result = Set-SpotifyPlaylistPrivacy -SpotifyUsername 'owner' -LogPath "$TestDrive/spotify.log" 2>$null
        $result | Should -BeFalse
    }

    It 'stops before account calls when the dependency is declined' {
        Mock Get-Module { $null } -ModuleName ApiIntegration
        Mock Read-Host { 'N' } -ModuleName ApiIntegration

        $result = Set-SpotifyPlaylistPrivacy -SpotifyUsername 'owner' -LogPath "$TestDrive/spotify.log" 2>$null

        $result | Should -BeFalse
        Should -Invoke Get-SpotifyApplication -Times 0 -ModuleName ApiIntegration
        Should -Invoke Get-UserPlaylists -Times 0 -ModuleName ApiIntegration
    }

    It 'stops before account calls when the dependency cannot be imported' {
        Mock Get-Module {
            if ($ListAvailable) { [pscustomobject]@{ Name = 'Spotishell' } } else { $null }
        } -ModuleName ApiIntegration
        Mock Import-Module { throw 'import failed' } -ModuleName ApiIntegration

        $result = Set-SpotifyPlaylistPrivacy -SpotifyUsername 'owner' -LogPath "$TestDrive/spotify.log" 2>$null

        $result | Should -BeFalse
        Should -Invoke Get-SpotifyApplication -Times 0 -ModuleName ApiIntegration
        Should -Invoke Get-UserPlaylists -Times 0 -ModuleName ApiIntegration
    }

    It 'stops before playlist calls when authentication is unavailable' {
        Mock Get-SpotifyApplication { throw 'not configured' } -ModuleName ApiIntegration

        $result = Set-SpotifyPlaylistPrivacy -SpotifyUsername 'owner' -LogPath "$TestDrive/spotify.log" 2>$null

        $result | Should -BeFalse
        Should -Invoke Get-UserPlaylists -Times 0 -ModuleName ApiIntegration
    }
}

AfterAll {
    Remove-Module ApiIntegration -Force -ErrorAction SilentlyContinue
    Remove-Item Function:/Get-SpotifyApplication, Function:/Get-UserPlaylists, Function:/Set-Playlist, Function:/Get-Playlist -ErrorAction SilentlyContinue
}
