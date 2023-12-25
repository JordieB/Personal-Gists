<#
.SYNOPSIS
    This script ensures Poetry is available and, if not, attempts to correct the issue by modifying the PATH.

.DESCRIPTION
    This script checks if Poetry is installed and accessible. If it isn't, it tries to add the Poetry directory to the system PATH and verifies the update. It logs all actions and provides user-friendly output.

.NOTES
    Requires the location of the Poetry executable to be known if not in a standard location.
#>

function Test-PoetryAvailable {
    <#
    .SYNOPSIS
        Checks if Poetry is available in the current session.
    #>
    try {
        poetry --version 2>$null
        $true
    } catch {
        $false
    }
}

function Add-DirectoryToPath {
    <#
    .SYNOPSIS
        Adds a directory to the system PATH if not already present.
    
    .PARAMETER Directory
        The directory to add to the system PATH.
    #>
    param (
        [string]$Directory
    )

    $pathArray = $env:PATH -split ';'
    if (-not ($pathArray -contains $Directory)) {
        Write-Log "Adding directory $Directory to PATH..."
        $pathArray += $Directory
        $newPath = $pathArray -join ';'
        [System.Environment]::SetEnvironmentVariable("PATH", $newPath, [System.EnvironmentVariableTarget]::User)
        $env:PATH = $newPath
    } else {
        Write-Log "$Directory is already in PATH."
    }
}

function Verify-DirectoryInPath {
    <#
    .SYNOPSIS
        Verifies if a directory has been added to the system PATH.
    
    .PARAMETER Directory
        The directory to verify in the system PATH.
    #>
    param (
        [string]$Directory
    )

    if ($env:PATH -split ';' -contains $Directory) {
        Write-Host "Directory has been added to PATH successfully." -ForegroundColor Green
    } else {
        Write-Host "Failed to add directory to PATH." -ForegroundColor Red
        exit
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a message to a log file with a timestamp.
    
    .PARAMETER Message
        The message to log.
    #>
    param (
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path "log.txt" -Value "$timestamp: $Message"
    Write-Host $Message
}

function Ensure-PoetryAvailable {
    if (Test-PoetryAvailable) {
        Write-Host "Poetry is already installed and available." -ForegroundColor Green
    } else {
        Write-Log "Poetry command not found. Attempting to fix..."
        $directoryToAdd = Join-Path $env:APPDATA "Python\Scripts"
        Add-DirectoryToPath -Directory $directoryToAdd
        Verify-DirectoryInPath -Directory $directoryToAdd
        if (-not (Test-PoetryAvailable)) {
            Write-Host "Poetry command still doesn't work. Consider reinstalling Poetry or checking the installation directory." -ForegroundColor Red
        }
    }
}