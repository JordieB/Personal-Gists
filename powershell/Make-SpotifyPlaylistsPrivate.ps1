<#
.SYNOPSIS
    Makes selected Spotify playlists private.

.DESCRIPTION
    This script retrieves the user's public Spotify playlists and sets them to private.
    It requires the Spotishell module and a valid Spotify username. The script outputs the number of playlists processed.

.PARAMETER SpotifyUsername
    The Spotify username for which to manage playlists.

.EXAMPLE
    Set-SpotifyPlaylistsPrivate -SpotifyUsername 'your_username'
    Retrieves public playlists for 'your_username' and sets them to private.

.NOTES
    Requires the Spotishell module.
    Ensure you have the necessary permissions and the module is correctly installed.
#>
function Set-SpotifyPlaylistsPrivate {
    param (
        [string]$SpotifyUsername
    )

    # Validate the username is not empty
    if (-not $SpotifyUsername) {
        Write-Host "SpotifyUsername parameter is required."
        return
    }

    $InformationPreference = "Continue"
    try {
        $public_playlists = Get-UserPlaylists -Id $SpotifyUsername | Where-Object { $_.owner.uri -eq "spotify:user:$SpotifyUsername" -and $_.public }
        Write-Host $("Found {0} public playlists in {1}'s account." -f $public_playlists.Count, $SpotifyUsername)

        # Uncomment to enable playlist selection
        # $selected_playlists = $public_playlists | Out-GridView -OutputMode Multiple

        $selected_playlists = $public_playlists

        $selected_playlists | ForEach-Object {
            Set-Playlist -Id $_.id -Public $false
        }

        Write-Host $("Made {0} public playlists private." -f $selected_playlists.Count)
    } catch {
        Write-Host "An error occurred: $_"
    }

    # Uncomment to provide an option to revert changes
    # Write-Host "To undo, run the script with the -Undo switch."
}
