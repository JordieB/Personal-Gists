function Is-PoetryAvailable {
    try {
        poetry --version 2>$null
        $true
    } catch {
        $false
    }
}

function Add-DirectoryToPath {
    param (
        [string]$directory
    )

    # Get the current PATH as an array of paths
    $pathArray = $env:PATH -split ';'

    # Check if the directory already exists in the PATH
    if (-not ($pathArray -contains $directory)) {
        Write-Log "Adding directory $directory to PATH..."

        # Append the directory to the array
        $pathArray += $directory

        # Convert the array back to a semicolon-separated string
        $newPath = $pathArray -join ';'

        # Update the PATH environment variable
        [System.Environment]::SetEnvironmentVariable("PATH", $newPath, [System.EnvironmentVariableTarget]::User)

        # Refresh the PATH in the current session
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
    } else {
        Write-Log "$directory is already in PATH."
    }
}

function Verify-DirectoryInPath {
    param (
        [string]$directory
    )

    if ($env:PATH -split ';' -contains $directory) {
        Write-Host "Directory has been added to PATH successfully." -ForegroundColor Green
    } else {
        Write-Host "Failed to add directory to PATH." -ForegroundColor Red
        exit
    }
}

function Write-Log {
    param (
        [string]$message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path "log.txt" -Value "$timestamp: $message"
    Write-Host $message
}

# Main script execution

if (Is-PoetryAvailable) {
    Write-Host "Poetry is already installed and available." -ForegroundColor Green
} else {
    Write-Log "Poetry command not found. Attempting to fix..."

    # Construct the full path to the directory you want to add
    $directoryToAdd = Join-Path $env:APPDATA "Python\Scripts"

    Add-DirectoryToPath -directory $directoryToAdd
    Verify-DirectoryInPath -directory $directoryToAdd
    if (-not (Is-PoetryAvailable)) {
        Write-Host "Poetry command still doesn't work. Consider reinstalling Poetry or checking the installation directory." -ForegroundColor Red
    }
}
