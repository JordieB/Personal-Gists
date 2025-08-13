# Example: Set Spotify Playlists to Private
# 
# This example demonstrates how to use the ApiIntegration module to 
# make Spotify playlists private.

# Import the module
Import-Module ../ApiIntegration.psd1

# Set playlists to private for a specific user
$username = "your_spotify_username"  # Replace with actual username
$logFile = "spotify_privacy_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

try {
    Set-SpotifyPlaylistPrivacy -SpotifyUsername $username -LogPath $logFile
    Write-Host "✓ Successfully processed playlists for $username"
    Write-Host "Check log file: $logFile"
} catch {
    Write-Error "Failed to process playlists: $($_.Exception.Message)"
}