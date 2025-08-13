# ApiIntegration (PowerShell)

**Purpose:** Tools for integrating with web APIs and third-party services.

## Install
```powershell
Import-Module ./modules/powershell/api-integration/ApiIntegration.psd1
```

## Usage

### Set-SpotifyPlaylistPrivacy
Makes Spotify playlists private using the Spotify API.

```powershell
Set-SpotifyPlaylistPrivacy -SpotifyUsername 'your_username'
```

## Examples
See the `examples/` directory for complete usage examples.

## Tested Versions
- PowerShell: 5.1/7.x

## Notes
- Requires Spotishell PowerShell module for Spotify integration
- TODO: Add support for other API integrations as needed