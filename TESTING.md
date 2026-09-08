# Local testing

Validation is intentionally local; this repository does not add GitHub workflows. Run commands from the repository root.

## macOS

Prerequisites are Bash 3.2+, Zsh, Python 3.9+, `bats-core`, `shellcheck`, and `uv`. Run:

```sh
./test-macos.sh
```

The entry point reports tool versions and exits nonzero when a required tool or suite is unavailable. It runs maintenance and profile Bats suites, shell syntax and ShellCheck, and installs each Python package into a clean environment before checking import-driven tests, help, `example`, and `example --option`.

## Windows

Prerequisites are PowerShell 5.1+ and Pester 5. Run:

```powershell
./test-windows.ps1
```

Windows results are separate from macOS results. A missing PowerShell or Pester environment is unavailable, never a pass.

## Mock boundary

Tests replace Homebrew, `sudo`, `softwareupdate`, Restic, Spotify, and related account/application commands. They must never update the real machine, install a Spotify dependency, authenticate to Spotify, or modify a playlist. Real integration is retained for temporary files, installed Python entry points, Git repositories, Zsh processes, and streaming prompts.

## Behavior inventory

- Maintenance: default quick, explicit presets/tasks, combined flags, last-preset precedence, dry-run precedence, command and logging failures, backup ordering, cleanup preservation/counts, OS update privilege routing, streaming prompts, and interruption.
- Profiles: repository/subdirectory discovery, marker handling, missing/invalid profiles, explicit configuration precedence, status, and management-command passthrough.
- Python placeholders: clean installation, imports, help, and both documented example invocations.
- Spotify: owned-public filtering, no matches, successful writes, verification failure, and dependency/authentication failures.

Coverage is a way to locate missed decisions; no percentage is treated as proof of correctness.
