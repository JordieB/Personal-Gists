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
    Get-Tree -rootPath "C:\" -maxDepth 3
    Displays the directory tree of the C: drive up to 3 levels deep, without files.

.EXAMPLE
    Get-Tree -rootPath "C:\" -maxDepth 3 -IncludeFiles $true
    Displays the directory tree of the C: drive up to 3 levels deep, including files.

.EXAMPLE
    Get-Tree -rootPath "C:\" -maxDepth 3 -ExcludeDirs @('.mypy_cache', '.venv', '.git')
    Displays the directory tree of the C: drive up to 3 levels deep, excluding directories named '.mypy_cache' and '.venv'.

.NOTES
    This function is a custom PowerShell implementation and does not use the 'tree' command.
    It's designed to provide more control over the depth, content, and exclusion of the directory tree displayed.
#>

function Get-Tree {
    param (
        [string]$rootPath = ".",
        [int]$maxDepth = 3,
        [bool]$IncludeFiles = $false,
        [string[]]$ExcludeDirs = @()
    )

    $currentDepth = 1

    function innerGet-Tree {
        param (
            [string]$path,
            [int]$depth
        )
        if ($depth -le $maxDepth) {
            $childItems = if ($IncludeFiles) {
                Get-ChildItem -Path $path -Force
            } else {
                Get-ChildItem -Directory -Path $path -Force
            }

            foreach ($item in $childItems) {
                # Skip excluded directories
                if ($item.PSIsContainer -and $ExcludeDirs -contains $item.Name) {
                    continue
                }

                $indent = '  ' * ($depth - 1)
                if ($item.PSIsContainer) {
                    Write-Host "$indent+- [D] $item"
                } else {
                    Write-Host "$indent+- [F] $item"
                }
                if ($item.PSIsContainer) {
                    innerGet-Tree -path $item.FullName -depth ($depth + 1)
                }
            }
        }
    }

    innerGet-Tree -path $rootPath -depth $currentDepth
}
