#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function Set-SpotifyPlaylistPrivacy {
<#
.SYNOPSIS
    Makes selected Spotify playlists private.

.DESCRIPTION
    This script retrieves the user's public Spotify playlists and sets them to private using the Spotishell module.
    It checks if the Spotishell module is installed and imports it if available. If the module is not installed, 
    the script prompts the user to install it. Additionally, it validates that a Spotify application is set up.
    Logs the number of playlists processed and any errors encountered.

.PARAMETER SpotifyUsername
    The Spotify username for which to manage playlists. This is required and can be found at: https://www.spotify.com/us/account/profile/

.PARAMETER LogPath
    The path to the log file where actions will be recorded. Defaults to 'SetSpotifyPlaylistsPrivate.log' in the current directory.

.EXAMPLE
    Set-SpotifyPlaylistPrivacy -SpotifyUsername 'your_username'
    Retrieves public playlists for 'your_username' and sets them to private. Prompts to install the Spotishell module 
    if it is not already installed.

.EXAMPLE
    Set-SpotifyPlaylistPrivacy -SpotifyUsername 'myusername' -LogPath 'C:\Logs\spotify.log'
    Sets playlists to private using a custom log file location.

.NOTES
    Author: Jordie Belle
    Prerequisites: PowerShell V5 or higher
    Requirements:
    - Spotishell PowerShell module (will prompt to install if missing)
    - Configured Spotify application with client ID and secret
    - Valid Spotify developer account and application setup
    - Internet connection for Spotify API access
    - Write permissions for the log file location
    
    Setup Instructions:
    1. Create a Spotify app at https://developer.spotify.com/dashboard/applications
    2. Use New-SpotifyApplication cmdlet to configure your client ID and secret
    3. Ensure your Spotify username is correct (visible in your account profile)
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpotifyUsername,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = "SetSpotifyPlaylistsPrivate.log"
    )

    # Function to write timestamped log entries
    function Write-SpotifyLog {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Message,
            
            [Parameter()]
            [ValidateSet('Information', 'Warning', 'Error')]
            [string]$Level = 'Information'
        )
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] $Level`: $Message"
        
        try {
            Add-Content -Path $LogPath -Value $logEntry -ErrorAction Stop
        } catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
        
        # Output to console based on level
        switch ($Level) {
            'Information' { Write-Information $Message -InformationAction Continue }
            'Warning' { Write-Warning $Message }
            'Error' { Write-Error $Message }
        }
    }

    # Function to ensure Spotishell module is available
    function Test-SpotishellModule {
        [CmdletBinding()]
        param()
        
        # Check if the Spotishell module is installed
        if (-not (Get-Module -ListAvailable -Name Spotishell)) {
            Write-SpotifyLog "Spotishell module is not installed." -Level Warning

            $confirmInstall = Read-Host "Would you like to install the Spotishell module? (Y/N)"
            if ($confirmInstall -eq 'Y' -or $confirmInstall -eq 'y') {
                try {
                    Install-Module -Name Spotishell -Scope CurrentUser -Force -ErrorAction Stop
                    Write-SpotifyLog "Spotishell module installed successfully." -Level Information
                } catch {
                    Write-SpotifyLog "Failed to install Spotishell module: $($_.Exception.Message)" -Level Error
                    return $false
                }
            } else {
                Write-Information "Installation cancelled. Exiting script." -InformationAction Continue
                Write-SpotifyLog "User declined Spotishell module installation." -Level Information
                return $false
            }
        }

        # Import the Spotishell module if not already imported
        if (-not (Get-Module -Name Spotishell)) {
            try {
                Import-Module Spotishell -ErrorAction Stop
                Write-SpotifyLog "Spotishell module imported successfully." -Level Information
            } catch {
                Write-SpotifyLog "Failed to import Spotishell module: $($_.Exception.Message)" -Level Error
                return $false
            }
        }
        
        return $true
    }

    # Function to validate Spotify application setup
    function Test-SpotifyApplication {
        [CmdletBinding()]
        param()
        
        try {
            $app = Get-SpotifyApplication -Name 'default' -ErrorAction Stop
            if (-not $app) {
                throw "No Spotify application configured."
            }
            Write-SpotifyLog "Spotify application configuration validated." -Level Information
            return $true
        } catch {
            $errorMsg = "Spotify application is not set up: $($_.Exception.Message)"
            Write-SpotifyLog $errorMsg -Level Error
            Write-Information "Please use New-SpotifyApplication with your client ID and secret." -InformationAction Continue
            return $false
        }
    }

    # Function to process playlists
    function Set-PlaylistsPrivate {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Username
        )
        
        try {
            Write-SpotifyLog "Starting playlist processing for user: $Username" -Level Information

            # Retrieve public playlists
            $publicPlaylists = Get-UserPlaylists -Id $Username | Where-Object { 
                $_.owner.uri -eq "spotify:user:$Username" -and $_.public 
            }

            $playlistCount = if ($publicPlaylists) { $publicPlaylists.Count } else { 0 }
            Write-Information "Found $playlistCount public playlists in $Username's account." -InformationAction Continue
            Write-SpotifyLog "Found $playlistCount public playlists for user: $Username" -Level Information

            # Check if any public playlists were found
            if ($playlistCount -eq 0) {
                Write-SpotifyLog "No public playlists found for user: $Username" -Level Warning
                return $true
            }

            # Process each public playlist
            $successCount = 0
            foreach ($playlist in $publicPlaylists) {
                Write-Information "Processing playlist: Name='$($playlist.name)', ID='$($playlist.id)'" -InformationAction Continue

                try {
                    # Attempt to set the playlist to private
                    $response = Set-Playlist -Id $playlist.id -Public $false -ErrorAction Stop

                    # Verify the playlist is now private
                    $updatedPlaylist = Get-Playlist -Id $playlist.id -ErrorAction Stop
                    if ($updatedPlaylist.public -eq $false) {
                        Write-Information "Playlist '$($playlist.name)' has been successfully set to private." -InformationAction Continue
                        Write-SpotifyLog "Playlist '$($playlist.name)' (ID: $($playlist.id)) set to private." -Level Information
                        $successCount++
                    } else {
                        throw "Playlist '$($playlist.name)' (ID: $($playlist.id)) failed to set to private. It is still public."
                    }
                } catch {
                    $errorMsg = "Error processing playlist '$($playlist.name)' (ID: $($playlist.id)): $($_.Exception.Message)"
                    Write-SpotifyLog $errorMsg -Level Error
                    Write-Error $errorMsg
                }
            }

            Write-Information "Playlist processing completed. Successfully processed $successCount of $playlistCount playlists." -InformationAction Continue
            Write-SpotifyLog "Processing completed: $successCount of $playlistCount playlists set to private." -Level Information
            
            return $successCount -eq $playlistCount
        } catch {
            Write-SpotifyLog "Critical error during playlist processing: $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    # Main execution
    try {
        # Ensure log directory exists
        $logDirectory = Split-Path $LogPath -Parent
        if ($logDirectory -and -not (Test-Path $logDirectory)) {
            New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop
        }
        
        Write-SpotifyLog "=== Starting Spotify Playlist Privacy Update Session ===" -Level Information
        Write-SpotifyLog "Target user: $SpotifyUsername" -Level Information

        # Test and setup Spotishell module
        if (-not (Test-SpotishellModule)) {
            Write-Error "Cannot continue without Spotishell module."
            return $false
        }

        # Validate Spotify application setup
        if (-not (Test-SpotifyApplication)) {
            Write-Error "Cannot continue without proper Spotify application setup."
            return $false
        }

        # Process playlists
        $result = Set-PlaylistsPrivate -Username $SpotifyUsername
        
        if ($result) {
            Write-Information "All operations completed successfully." -InformationAction Continue
            Write-SpotifyLog "Session completed successfully." -Level Information
        } else {
            Write-Warning "Some operations failed. Check the log for details: $LogPath"
            Write-SpotifyLog "Session completed with errors." -Level Warning
        }
        
        Write-SpotifyLog "=== End of Session ===" -Level Information
        return $result
        
    } catch {
        Write-SpotifyLog "Critical error in main execution: $($_.Exception.Message)" -Level Error
        Write-Error "Critical error: $($_.Exception.Message)"
        return $false
    }
}

Export-ModuleMember -Function Set-SpotifyPlaylistPrivacy