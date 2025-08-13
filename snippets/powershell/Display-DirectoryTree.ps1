<#
.SYNOPSIS
    Displays a tree of directories and optionally files up to a specified maximum depth.

.DESCRIPTION
    The Get-Tree function lists directories (and optionally files) in a tree-like structure up to a specified maximum depth.
    It allows excluding specified directories from the output for a cleaner view.

.PARAMETER rootPath
    The root path from where the tree will start.

.PARAMETER maxDepth
    The maximum depth of directories to display.

.PARAMETER IncludeFiles
    A boolean indicating whether to include files in the tree. Defaults to $false.

.PARAMETER ExcludeDirs
    An array of directory names to exclude from the tree display.

.EXAMPLE
    Get-Tree -rootPath "." -maxDepth 3 -IncludeFiles $true -ExcludeDirs @('.mypy_cache', '.venv', '.git', '.mypy_cache')
    Displays the directory tree of the current directory up to 3 levels deep, including files and excluding specified directories.

.EXAMPLE
    Get-Tree -rootPath "C:\Projects" -maxDepth 2
    Displays the directory tree of C:\Projects up to 2 levels deep, showing only directories.

.NOTES
    Author: Jordie Belle
    Prerequisites: PowerShell V5 or higher
    Requirements: Read permissions on the target directories
    This function is a custom PowerShell implementation and does not use the 'tree' command.
    It's designed to provide more control over the depth, content, and exclusion of the directory tree displayed.
#>

function Get-Tree {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$rootPath = ".",
        
        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$maxDepth = 3,
        
        [Parameter()]
        [bool]$IncludeFiles = $false,
        
        [Parameter()]
        [string[]]$ExcludeDirs = @()
    )

    $currentDepth = 1

    function innerGet-Tree {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$path,
            
            [Parameter(Mandatory)]
            [ValidateRange(1, [int]::MaxValue)]
            [int]$depth
        )
        
        if ($depth -le $maxDepth) {
            try {
                $childItems = if ($IncludeFiles) {
                    Get-ChildItem -Path $path -Force -ErrorAction Stop
                } else {
                    Get-ChildItem -Directory -Path $path -Force -ErrorAction Stop
                }

                foreach ($item in $childItems) {
                    # Skip excluded directories
                    if ($item.PSIsContainer -and $ExcludeDirs -contains $item.Name) {
                        continue
                    }

                    $indent = '  ' * ($depth - 1)
                    if ($item.PSIsContainer) {
                        Write-Information "$indent+- [D] $item" -InformationAction Continue
                    } else {
                        Write-Information "$indent+- [F] $item" -InformationAction Continue
                    }
                    
                    if ($item.PSIsContainer) {
                        innerGet-Tree -path $item.FullName -depth ($depth + 1)
                    }
                }
            } catch {
                Write-Warning "Cannot access path: $path - $($_.Exception.Message)"
            }
        }
    }

    # Validate root path exists
    if (-not (Test-Path $rootPath)) {
        Write-Error "Root path does not exist: $rootPath"
        return
    }

    Write-Information "Directory tree for: $rootPath (Max depth: $maxDepth)" -InformationAction Continue
    innerGet-Tree -path $rootPath -depth $currentDepth
}
