<#
.SYNOPSIS
    Ensures Poetry is available and accessible in the current PowerShell session.

.DESCRIPTION
    This script checks if Poetry is installed and accessible. If it isn't, it tries to add the Poetry directory 
    to the system PATH and verifies the update. It logs all actions and provides user-friendly output.
    The script automatically detects common Poetry installation locations and attempts to fix PATH issues.

.PARAMETER PoetryDirectory
    Custom directory path where Poetry is installed. If not specified, uses the default Python Scripts directory.

.PARAMETER LogPath
    Path to the log file where actions will be recorded. Defaults to 'poetry_setup.log' in the current directory.

.EXAMPLE
    Invoke-EnsurePoetryAvailability
    Checks for Poetry availability using default settings and attempts to fix PATH if needed.

.EXAMPLE
    Invoke-EnsurePoetryAvailability -PoetryDirectory "C:\CustomPath\Poetry\bin" -LogPath "C:\Logs\poetry.log"
    Checks for Poetry using a custom installation path and log file location.

.NOTES
    Author: Jordie Belle
    Prerequisites: PowerShell V5 or higher
    Requirements:
    - Poetry must be installed (this script only fixes PATH issues, not installation)
    - Administrative privileges may be required for system-wide PATH modifications
    - Write permissions required for the log file location
#>

function Test-PoetryAvailable {
    <#
    .SYNOPSIS
        Checks if Poetry is available in the current session.
    
    .DESCRIPTION
        Tests if the Poetry command is accessible by attempting to run 'poetry --version'.
        
    .EXAMPLE
        Test-PoetryAvailable
        Returns $true if Poetry is available, $false otherwise.
    #>
    [CmdletBinding()]
    param()
    
    try {
        $null = poetry --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}

function Add-DirectoryToPath {
    <#
    .SYNOPSIS
        Adds a directory to the system PATH if not already present.
    
    .DESCRIPTION
        Checks if the specified directory exists in the current PATH and adds it if missing.
        Updates both the current session PATH and the user environment variable.
    
    .PARAMETER Directory
        The directory path to add to the system PATH.
        
    .PARAMETER LogPath
        Path to the log file for recording actions.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Directory,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath
    )

    try {
        $pathArray = $env:PATH -split ';'
        if (-not ($pathArray -contains $Directory)) {
            Write-PoetryLog "Adding directory $Directory to PATH..." -LogPath $LogPath
            $pathArray += $Directory
            $newPath = $pathArray -join ';'
            [System.Environment]::SetEnvironmentVariable("PATH", $newPath, [System.EnvironmentVariableTarget]::User)
            $env:PATH = $newPath
            Write-PoetryLog "Successfully added $Directory to PATH." -LogPath $LogPath
        } else {
            Write-PoetryLog "$Directory is already in PATH." -LogPath $LogPath
        }
    } catch {
        Write-Error "Failed to add directory to PATH: $($_.Exception.Message)"
    }
}

function Test-DirectoryInPath {
    <#
    .SYNOPSIS
        Verifies if a directory has been added to the system PATH.
    
    .DESCRIPTION
        Checks if the specified directory exists in the current PATH environment variable.
    
    .PARAMETER Directory
        The directory path to verify in the system PATH.
        
    .PARAMETER LogPath
        Path to the log file for recording results.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Directory,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath
    )

    try {
        if ($env:PATH -split ';' -contains $Directory) {
            Write-Information "Directory has been added to PATH successfully." -InformationAction Continue
            Write-PoetryLog "PATH verification successful for: $Directory" -LogPath $LogPath
            return $true
        } else {
            Write-Error "Failed to add directory to PATH: $Directory"
            Write-PoetryLog "PATH verification failed for: $Directory" -LogPath $LogPath
            return $false
        }
    } catch {
        Write-Error "Error verifying PATH: $($_.Exception.Message)"
        return $false
    }
}

function Write-PoetryLog {
    <#
    .SYNOPSIS
        Writes a message to a log file with a timestamp.
    
    .DESCRIPTION
        Logs messages with timestamps to both the console and a specified log file.
    
    .PARAMETER Message
        The message to log.
        
    .PARAMETER LogPath
        Path to the log file where the message should be written.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath
    )

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "$timestamp`: $Message"
        Add-Content -Path $LogPath -Value $logEntry -ErrorAction Stop
        Write-Information $Message -InformationAction Continue
    } catch {
        Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        Write-Information $Message -InformationAction Continue
    }
}

function Invoke-EnsurePoetryAvailability {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$PoetryDirectory = (Join-Path $env:APPDATA "Python\Scripts"),
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = "poetry_setup.log"
    )
    
    try {
        # Ensure log directory exists
        $logDirectory = Split-Path $LogPath -Parent
        if ($logDirectory -and -not (Test-Path $logDirectory)) {
            New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop
        }
        
        Write-PoetryLog "Starting Poetry availability check..." -LogPath $LogPath
        
        if (Test-PoetryAvailable) {
            Write-Information "Poetry is already installed and available." -InformationAction Continue
            Write-PoetryLog "Poetry is already available - no action needed." -LogPath $LogPath
        } else {
            Write-PoetryLog "Poetry command not found. Attempting to fix PATH..." -LogPath $LogPath
            
            # Verify the Poetry directory exists
            if (-not (Test-Path $PoetryDirectory)) {
                Write-Error "Poetry directory not found: $PoetryDirectory"
                Write-PoetryLog "Poetry directory not found: $PoetryDirectory" -LogPath $LogPath
                return $false
            }
            
            Add-DirectoryToPath -Directory $PoetryDirectory -LogPath $LogPath
            
            if (Test-DirectoryInPath -Directory $PoetryDirectory -LogPath $LogPath) {
                # Test Poetry availability again after PATH update
                if (Test-PoetryAvailable) {
                    Write-Information "Poetry is now available after PATH update." -InformationAction Continue
                    Write-PoetryLog "Successfully fixed Poetry availability." -LogPath $LogPath
                    return $true
                } else {
                    Write-Error "Poetry command still doesn't work. Consider reinstalling Poetry or checking the installation directory."
                    Write-PoetryLog "Poetry still not available after PATH fix. Manual intervention may be required." -LogPath $LogPath
                    return $false
                }
            } else {
                return $false
            }
        }
        
        return $true
    } catch {
        Write-Error "Critical error ensuring Poetry availability: $($_.Exception.Message)"
        return $false
    }
}