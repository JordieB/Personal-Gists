$ErrorActionPreference = 'Stop'
$failed = $false

Write-Host 'Windows validation'
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "OS: $($PSVersionTable.OS)"
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Error 'UNAVAILABLE: Pester is required; no suite was reported as passed.'
    exit 1
}

$testFiles = @(Get-ChildItem -Path 'modules/powershell' -Recurse -Filter '*.Tests.ps1')
if ($testFiles.Count -eq 0) {
    Write-Error 'UNAVAILABLE: no PowerShell test suites were found.'
    exit 1
}

try {
    $result = Invoke-Pester -Path 'modules/powershell' -PassThru
    if ($result.TotalCount -eq 0 -or $result.FailedCount -gt 0) { $failed = $true }
} catch {
    Write-Error $_
    $failed = $true
}

if ($failed) { exit 1 }
exit 0
