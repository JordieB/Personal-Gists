<#
.SYNOPSIS
    Starts the Albion Data Project by starting the NPF service and launching the client.

.DESCRIPTION
    This function starts the NPF (Npcap Packet Filter) service which is required for the Albion Data Client to function properly,
    then launches the Albion Data Client application using a desktop shortcut.

.PARAMETER ShortcutPath
    The path to the Albion Data Client shortcut. Defaults to the standard desktop shortcuts location.

.EXAMPLE
    Start-AlbionDataProject
    Starts the Albion Data Project with default settings.

.EXAMPLE
    Start-AlbionDataProject -ShortcutPath "D:\CustomPath\Albion Data Client.lnk"
    Starts the Albion Data Project using a custom shortcut path.

.NOTES
    Author: Jordie Belle
    Prerequisites: 
    - NPF service must be installed (part of Npcap installation)
    - Albion Data Client shortcut must exist at the specified path
    - Requires administrative privileges to start the NPF service
#>

function Start-AlbionDataProject {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$ShortcutPath = "C:\Users\jordi\Desktop\Index Shortcuts\Albion Data Client.lnk"
    )

    try {
        # Start the npf service
        Write-Information "Starting NPF service..." -InformationAction Continue
        Start-Service -Name npf -ErrorAction Stop
        Write-Information "NPF service started successfully." -InformationAction Continue

        # Check if the shortcut file exists
        if (Test-Path $ShortcutPath) {
            # Start the application using the shortcut
            Write-Information "Launching Albion Data Client from: $ShortcutPath" -InformationAction Continue
            Start-Process -FilePath $ShortcutPath -ErrorAction Stop
            Write-Information "Albion Data Client launched successfully." -InformationAction Continue
        } else {
            Write-Error "Shortcut not found: $ShortcutPath"
        }
    } catch {
        Write-Error "Failed to start Albion Data Project: $($_.Exception.Message)"
    }
}
