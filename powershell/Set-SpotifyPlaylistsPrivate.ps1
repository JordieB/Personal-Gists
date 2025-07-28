<#
.SYNOPSIS
    Makes selected Spotify playlists private.

.DESCRIPTION
    This script retrieves the user's public Spotify playlists and sets them to private using the Spotishell module.
    It checks if the Spotishell module is installed and imports it if available. If the module is not installed, 
    the script prompts the user to install it. Additionally, it validates that a Spotify application is set up.
    Logs the number of playlists processed and any errors encountered.

.PARAMETER SpotifyUsername
    The Spotify username for which to manage playlists. Can be found at: https://www.spotify.com/us/account/profile/

.EXAMPLE
    Set-SpotifyPlaylistsPrivate -SpotifyUsername 'your_username'
    Retrieves public playlists for 'your_username' and sets them to private. Prompts to install the Spotishell module 
    if it is not already installed.

.NOTES
    Requires the Spotishell module and a configured Spotify app.
    Log file: SetSpotifyPlaylistsPrivate.log, which records all actions and errors.
#>

function Set-SpotifyPlaylistsPrivate {
    param (
        [string]$SpotifyUsername
    )

    $LogFile = "SetSpotifyPlaylistsPrivate.log"
    $InformationPreference = "Continue"

    # Check if the Spotishell module is installed
    if (-not (Get-Module -ListAvailable -Name Spotishell)) {
        Write-Warning "Spotishell module is not installed."
        Add-Content -Path $LogFile -Value "[$(Get-Date)] WARNING: Spotishell module is not installed."

        $confirmInstall = Read-Host "Would you like to install the Spotishell module? (Y/N)"
        if ($confirmInstall -eq 'Y') {
            try {
                Install-Module -Name Spotishell -Scope CurrentUser -Force -ErrorAction Stop
                Write-Information "Spotishell module installed successfully." -InformationAction Continue
                Add-Content -Path $LogFile -Value "[$(Get-Date)] INFO: Spotishell module installed successfully."
            }
            catch {
                Write-Error "Failed to install Spotishell module: $_"
                Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to install Spotishell module: $_"
                return
            }
        } else {
            Write-Host "Installation cancelled. Exiting script."
            Add-Content -Path $LogFile -Value "[$(Get-Date)] INFO: User declined Spotishell module installation."
            return
        }
    }

    # Import the Spotishell module if not already imported
    if (-not (Get-Module -Name Spotishell)) {
        try {
            Import-Module Spotishell -ErrorAction Stop
            Write-Information "Spotishell module imported successfully." -InformationAction Continue
            Add-Content -Path $LogFile -Value "[$(Get-Date)] INFO: Spotishell module imported successfully."
        }
        catch {
            Write-Error "Failed to import Spotishell module: $_"
            Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to import Spotishell module: $_"
            return
        }
    }

    # Validate Spotify Application
    try {
        $app = Get-SpotifyApplication -Name 'default'
        if (-not $app) {
            throw "No Spotify application configured. Please set up a Spotify application in your developer dashboard."
        }
    }
    catch {
        Write-Error "Spotify application is not set up: $_"
        Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Spotify application is not set up: $_"
        Write-Host "Please use New-SpotifyApplication with your client ID and secret."
        return
    }

    # Validate the username is not empty
    if (-not $SpotifyUsername) {
        Write-Error "SpotifyUsername parameter is required."
        return
    }

    # Process the privacy status of playlists
    try {
        Write-Information "Starting process for user: $SpotifyUsername" -InformationAction Continue
        Add-Content -Path $LogFile -Value "[$(Get-Date)] INFO: Starting process for user: $SpotifyUsername"

        # Retrieve public playlists
        $public_playlists = Get-UserPlaylists -Id $SpotifyUsername | Where-Object { 
            $_.owner.uri -eq "spotify:user:$SpotifyUsername" -and $_.public 
        }

        Write-Information $("Found {0} public playlists in {1}'s account." -f $public_playlists.Count, $SpotifyUsername)
        Add-Content -Path $LogFile -Value "[$(Get-Date)] INFO: Found $($public_playlists.Count) public playlists for user: $SpotifyUsername"

        # Check if any public playlists were found
        if ($public_playlists.Count -eq 0) {
            Write-Warning "No public playlists found for user $SpotifyUsername."
            Add-Content -Path $LogFile -Value "[$(Get-Date)] WARNING: No public playlists found for user: $SpotifyUsername"
            return
        }

        # Process each public playlist
        $public_playlists | ForEach-Object {
            Write-Host "Processing playlist: Name='$($_.name)', ID='$($_.id)'" -ForegroundColor Cyan

            try {
                # Attempt to set the playlist to private and capture the response
                $response = Set-Playlist -Id $_.id -Public $false

                # Log the response for debugging
                Write-Verbose "Response from Set-Playlist: $($response | Out-String)"

                # Verify the playlist is now private
                $updatedPlaylist = Get-Playlist -Id $_.id
                if ($updatedPlaylist.public -eq $false) {
                    Write-Host "Playlist '$($_.name)' has been successfully set to private." -ForegroundColor Green
                    Add-Content -Path $LogFile -Value "[$(Get-Date)] INFO: Playlist '$($_.name)' (ID: $($_.id)) set to private."
                } else {
                    throw "Playlist '$($_.name)' (ID: $($_.id)) failed to set to private. It is still public."
                }
            } catch {
                Write-Error "Error processing playlist '$($_.name)' (ID: $($_.id)): $_"
                Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Playlist '$($_.name)' failed: $_"
                throw  # Stop processing but keep the terminal session open
            }
        }


    } catch {
        Write-Error "An error occurred: $_"
        Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: An error occurred: $_"
    }
}
