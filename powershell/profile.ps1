<#
.SYNOPSIS
    Personal PowerShell profile for development and environment setup.

.DESCRIPTION
    This profile:
    - Loads custom personal utility scripts (gists)
    - Initializes Java version manager (jabba)
    - Sets up code-style tools (e.g., black for Python)
    - Configures pipx to work with pyenv-win if available
    - Applies Cursor-specific terminal fixes (PATH repair and env cleanup)

.AUTHOR
    Jordie Belle

.TESTED
    PowerShell 7.5.1 on Windows 10 and 11
#>

# ── 1. Personal utility scripts (gists) ─────────────────────────────────────
$ScriptDirectory = "D:\projects\_personal_gists\powershell"

foreach ($file in @(
    'Create-PythonVirtualEnv.ps1',
    'Update-PythonDependencies.ps1',
    'Display-DirectoryTree.ps1',
    'Maintain-Choco.ps1',
    'Create-DSProj.ps1'
)) {
    $f = Join-Path $ScriptDirectory $file
    if (Test-Path $f) { . $f }
}

# ── 2. Java version manager (jabba) ────────────────────────────────────────
$JabbaProfile = "$HOME\.jabba\jabba.ps1"
if (Test-Path $JabbaProfile) { . $JabbaProfile }

# ── 3. Code-style tooling defaults ─────────────────────────────────────────
$env:PYTHON_POST_PROCESS_FILE = "black"

# ── 4. pipx + pyenv-win integration ────────────────────────────────────────
# Set up pyenv environment variables if not already set
if (-not $env:PYENV) {
    $env:PYENV = "C:\Users\jordi\.pyenv\pyenv-win\"
    $env:PYENV_ROOT = "C:\Users\jordi\.pyenv\pyenv-win\"
    $env:PYENV_HOME = "C:\Users\jordi\.pyenv\pyenv-win\"
}

# Add pyenv to PATH if not already there
$pyenvBinPath = "C:\Users\jordi\.pyenv\pyenv-win\bin"
$pyenvShimsPath = "C:\Users\jordi\.pyenv\pyenv-win\shims"

if ($env:PATH -notlike "*$pyenvBinPath*") {
    $env:PATH = "$pyenvBinPath;$env:PATH"
}
if ($env:PATH -notlike "*$pyenvShimsPath*") {
    $env:PATH = "$pyenvShimsPath;$env:PATH"
}

if (Get-Command pyenv -ErrorAction SilentlyContinue) {
    try {
        # Test if pyenv is working correctly before setting the environment variable
        $pyenvPython = pyenv which python 2>$null
        if ($pyenvPython -and (Test-Path $pyenvPython)) {
            $env:PIPX_DEFAULT_PYTHON = $pyenvPython
        }
    } catch {
        # Silently ignore pyenv errors to prevent cscript issues
        Write-Debug "pyenv integration failed: $($_.Exception.Message)"
    }
}

# ── 5. Cursor-specific terminal fixes ──────────────────────────────────────
if ($env:CURSOR_TRACE_ID) {
    # Ensure critical system paths are restored for Windows tooling
    $systemPaths = @(
        "C:\Windows\System32",
        "C:\Windows\System32\Wbem",
        "C:\Windows\System32\WindowsPowerShell\v1.0"
    )
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine").Split(";")
    $env:PATH = ($systemPaths + $machinePath) -join ";"

    # Remove rogue pyenv variables injected into Cursor shell
    Remove-Item Env:PYENV_HOME, Env:PYENV_ROOT, Env:PYENV -ErrorAction SilentlyContinue
}
