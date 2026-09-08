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

## Platform requirement
- PowerShell 5.1 or newer; not verified in the current macOS validation environment

## Notes
- Requires Spotishell PowerShell module for Spotify integration
- Future implementations may add support for other API integrations as needed