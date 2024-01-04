<#
.SYNOPSIS
    Displays a tree of directories and optionally files up to a specified maximum depth.

.DESCRIPTION
    The Get-Tree function lists directories (and optionally files) in a tree-like structure up to a specified maximum depth.
    It's useful for getting a quick overview of a directory's structure without overwhelming detail.

.PARAMETER rootPath
    The root path from where the tree will start.

.PARAMETER maxDepth
    The maximum depth of directories to display.

.PARAMETER IncludeFiles
    A boolean indicating whether to include files in the tree. Defaults to $false.

.EXAMPLE
    Get-Tree -rootPath "C:\" -maxDepth 3
    Displays the directory tree of the C: drive up to 3 levels deep, without files.

.EXAMPLE
    Get-Tree -rootPath "C:\" -maxDepth 3 -IncludeFiles $true
    Displays the directory tree of the C: drive up to 3 levels deep, including files.

.NOTES
    This function is a custom PowerShell implementation and does not use the 'tree' command.
    It's designed to provide more control over the depth and content of the directory tree displayed.
#>
function Get-Tree {
    param (
        [string]$rootPath,
        [int]$maxDepth,
        [bool]$IncludeFiles = $false
    )

    $currentDepth = 1
    function innerGet-Tree {
        param (
            [string]$path,
            [int]$depth
        )
        if ($depth -le $maxDepth) {
            $childItems = if ($IncludeFiles) {
                Get-ChildItem -Path $path
            } else {
                Get-ChildItem -Directory -Path $path
            }

            foreach ($item in $childItems) {
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
