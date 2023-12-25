<#
.SYNOPSIS
Backups specified directories to a designated backup location.

.DESCRIPTION
This script copies all files from specified source directories to a backup destination. It's designed to backup configuration files for reWASD but can be adapted for other purposes.

.EXAMPLE
Backup-ReWASDConfigs

.NOTES
Ensure you have the necessary permissions to read from the source and write to the destination.
#>

function Backup-ReWASDConfigs {
    [CmdletBinding()]
    param (
        [String[]]$SourceDirs = @('C:\Users\Public\Documents\reWASD\Profiles', 'D:\Games\reWASD Configs'),
        [String]$BackupDest = "C:\Backup\reWASD"
    )

    # Inner function to backup files from source to destination
    function Backup-Files {
        param (
            [String]$SourceDir,
            [String]$DestDir
        )
        if (Test-Path -Path $SourceDir) {
            Copy-Item -Path $SourceDir\* -Destination $DestDir -Recurse -Force
            Write-Host "Backup completed for $SourceDir"
        } else {
            Write-Warning "Source directory not found: $SourceDir"
        }
    }

    # Create the backup destination directory if it doesn't exist
    if (!(Test-Path -Path $BackupDest)) {
        New-Item -ItemType Directory -Path $BackupDest
    }

    # Backup each directory
    foreach ($dir in $SourceDirs) {
        $folderName = Split-Path $dir -Leaf
        $destPath = Join-Path $BackupDest $folderName
        Backup-Files -SourceDir $dir -DestDir $destPath
    }
}