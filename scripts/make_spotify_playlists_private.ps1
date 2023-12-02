#Requires -Module Spotishell
# Install and setup Spotishell
# https://github.com/wardbox/spotishell

$InformationPreference = "Continue"

# Set your spotify username here
$username = ""

$public_playlists = Get-UserPlaylists -Id $username | Where-Object { $_.owner.uri -eq "spotify:user:$username" -and $_.public}
Write-Information $("There are {0} public playlist in {1} account" -f $public_playlists.Count, $username)

$selected_playlists = $public_playlists

# # Uncomment the following line to be able to select some playlist
# # The display is a bit ugly, but it works (on windows)
# # $selected_playlists = $public_playlists | Out-GridView -OutputMode Multiple

$selected_playlists | ForEach-Object { Set-Playlist -Id $_.id -Public $false}

Write-Information $("{0} public playlist have been made private" -f $selected_playlists.Count)

# Uncomment the following line to undo (make all the playlist public)
# $public_playlists | ForEach-Object { Set-Playlist -Id $_.id -Public $true}