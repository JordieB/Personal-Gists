$ErrorActionPreference = 'Stop'
$failed = $false
$repoRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath)
$powerShellTests = Join-Path $repoRoot 'tests/powershell'
$commandPromptTest = Join-Path $repoRoot 'tests/command_prompt/dev-tools/test_dev_tools.cmd'

Write-Host 'Windows validation'
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "OS: $($PSVersionTable.OS)"
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]'5.0' })) {
    Write-Error 'UNAVAILABLE: Pester 5 is required; no suite was reported as passed.'
    exit 1
}
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
if (-not (Test-Path -LiteralPath $commandPromptTest)) {
    Write-Error 'UNAVAILABLE: Command Prompt test suite was not found.'
    exit 1
}

$testFiles = @(Get-ChildItem -Path $powerShellTests -Recurse -Filter '*.Tests.ps1')
if ($testFiles.Count -eq 0) {
    Write-Error 'UNAVAILABLE: no PowerShell test suites were found.'
    exit 1
}

try {
    $result = Invoke-Pester -Path $powerShellTests -PassThru
    if ($result.TotalCount -eq 0 -or $result.FailedCount -gt 0) { $failed = $true }
} catch {
    Write-Error $_
    $failed = $true
}

try {
    & $env:ComSpec /d /c $commandPromptTest
    if ($LASTEXITCODE -ne 0) { $failed = $true }
} catch {
    Write-Error $_
    $failed = $true
}

if ($failed) { exit 1 }
exit 0
