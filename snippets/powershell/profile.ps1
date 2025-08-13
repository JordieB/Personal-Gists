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
    'Start-Albion-Data-Project.ps1',
    'Maintain-Choco.ps1',
    'Set-SpotifyPlaylistsPrivate.ps1',
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
if (Get-Command pyenv -ErrorAction SilentlyContinue) {
    $env:PIPX_DEFAULT_PYTHON = pyenv which python
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
