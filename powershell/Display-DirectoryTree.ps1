<#
.SYNOPSIS
    Displays a tree of directories up to a specified maximum depth.

.DESCRIPTION
    The Get-Tree function lists directories in a tree-like structure up to a specified maximum depth.
    It's useful for getting a quick overview of a directory's structure without overwhelming detail.

.PARAMETER rootPath
    The root path from where the tree will start.

.PARAMETER maxDepth
    The maximum depth of directories to display.

.EXAMPLE
    Get-Tree -rootPath "C:\" -maxDepth 3
    Displays the directory tree of the C: drive up to 3 levels deep.

.NOTES
    This function is a custom PowerShell implementation and does not use the 'tree' command.
    It's designed to provide more control over the depth of the directory tree displayed.
#>
function Get-Tree {
    param (
        [string]$rootPath,
        [int]$maxDepth
    )

    $currentDepth = 1
    function innerGet-Tree {
        param ([string]$path, [int]$depth)
        if ($depth -le $maxDepth) {
            Get-ChildItem -Directory -Path $path | ForEach-Object {
                $dir = $_
                "$('  ' * ($depth - 1))+- $dir"
                innerGet-Tree -path $dir.FullName -depth ($depth + 1)
            }
        }
    }
    innerGet-Tree -path $rootPath -depth $currentDepth
}