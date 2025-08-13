<#
.SYNOPSIS
Backups specified directories to a designated backup location.

.DESCRIPTION
This script copies all files from specified source directories to a backup destination. It's designed to backup configuration files for reWASD but can be adapted for other purposes.

.PARAMETER SourceDirs
An array of source directory paths to backup. Defaults to common reWASD configuration locations.

.PARAMETER BackupDest
The destination directory where backups will be stored. Defaults to "C:\Backup\reWASD".

.EXAMPLE
Backup-ReWASDConfigs
Backs up reWASD configurations using default source and destination paths.

.EXAMPLE
Backup-ReWASDConfigs -SourceDirs @('C:\Custom\Path1', 'C:\Custom\Path2') -BackupDest 'D:\MyBackups'
Backs up custom directories to a custom backup destination.

.NOTES
Author: Jordie Belle
Prerequisites: PowerShell V5 or higher
Requirements: Read permissions on source directories and write permissions on backup destination
Ensure you have the necessary permissions to read from the source and write to the destination.
#>

function Backup-ReWASDConfigs {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]$SourceDirs = @('C:\Users\Public\Documents\reWASD\Profiles', 'D:\Games\reWASD Configs'),
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$BackupDest = "C:\Backup\reWASD"
    )

    # Inner function to backup files from source to destination
    function Backup-Files {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [String]$SourceDir,
            
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [String]$DestDir
        )
        
        try {
            if (Test-Path -Path $SourceDir) {
                Copy-Item -Path $SourceDir\* -Destination $DestDir -Recurse -Force -ErrorAction Stop
                Write-Information "Backup completed for $SourceDir" -InformationAction Continue
            } else {
                Write-Warning "Source directory not found: $SourceDir"
            }
        } catch {
            Write-Error "Failed to backup $SourceDir to $DestDir`: $($_.Exception.Message)"
        }
    }

    try {
        # Create the backup destination directory if it doesn't exist
        if (!(Test-Path -Path $BackupDest)) {
            New-Item -ItemType Directory -Path $BackupDest -Force -ErrorAction Stop
            Write-Information "Created backup destination directory: $BackupDest" -InformationAction Continue
        }

        # Backup each directory
        foreach ($dir in $SourceDirs) {
            $folderName = Split-Path $dir -Leaf
            $destPath = Join-Path $BackupDest $folderName
            
            # Create destination subdirectory if it doesn't exist
            if (!(Test-Path -Path $destPath)) {
                New-Item -ItemType Directory -Path $destPath -Force -ErrorAction Stop
            }
            
            Backup-Files -SourceDir $dir -DestDir $destPath
        }
        
        Write-Information "Backup operation completed successfully." -InformationAction Continue
    } catch {
        Write-Error "Backup operation failed: $($_.Exception.Message)"
    }
}