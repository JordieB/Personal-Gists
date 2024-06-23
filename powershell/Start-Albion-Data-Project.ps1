function Start-AlbionDataProject {
    # Start the npf service
    Start-Service -Name npf

    # Path to the shortcut file
    $shortcutPath = "C:\Users\jordi\Desktop\Index Shortcuts\Albion Data Client.lnk"

    # Check if the shortcut file exists
    if (Test-Path $shortcutPath) {
        # Start the application using the shortcut
        Start-Process -FilePath $shortcutPath
    } else {
        Write-Host "Shortcut not found: $shortcutPath"
    }
}
