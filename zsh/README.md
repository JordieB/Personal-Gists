# macOS maintenance

`macos_maintenance.sh` is the canonical runner. The script under
`snippets/zsh/` forwards to it. The system-maintenance plugin is a separate stub.

Run as your normal user. Version 3.2.1 defaults to **quick maintenance**: conservative cleanup, Homebrew maintenance, App Store updates, a macOS update check, and diagnostics. Use `--dry-run` for a preview. It refuses root execution; only explicitly requested macOS update installation invokes sudo.

```sh
./zsh/macos_maintenance.sh                 # Run quick maintenance
./zsh/macos_maintenance.sh --quick         # Select quick maintenance explicitly
./zsh/macos_maintenance.sh --comprehensive # Add recent shutdown-cause diagnostics
./zsh/macos_maintenance.sh -y              # Quick maintenance; approve Homebrew prompts
./zsh/macos_maintenance.sh -y --verbose    # Also print command details
./zsh/macos_maintenance.sh --brew-autoremove -y
./zsh/macos_maintenance.sh --brew-greedy -y
./zsh/macos_maintenance.sh --backup --brew -y
./zsh/macos_maintenance.sh --help
```

## Homebrew workflow

1. Update metadata; failure stops the Homebrew phase immediately.
2. List outdated formulae and casks; listing failures also stop the phase.
3. Upgrade formulae and casks separately, including greedy casks and respecting
   Homebrew's pinned packages. Default confirmation behavior is left to Homebrew,
   without explicit `--ask`; prompts remain visible. `-y` supplies
   Homebrew's `--no-ask`. Installer password prompts may still occur.
4. Remove unused dependencies even if one or more upgrades fail.
   `--no-brew-autoremove` selects a preview instead.
5. Run normal cleanup even if an upgrade or autoremove fails; each failure still
   keeps the Homebrew phase nonzero.
6. Run doctor once per run, shared with diagnostics (also previewed only once).
   Its warnings are counted once without failing successful upgrades; logging failures remain fatal.

Greedy upgrades include casks marked self-updating or latest by default.
`--no-brew-greedy` excludes this extra coverage. The positive
`--brew-greedy` and `--brew-autoremove` flags remain supported.
Preview mode executes no Homebrew commands, so its plan does not list actual
outdated packages. Applying upgrades can affect running applications and services.

## Logs and failures

Each run creates a private (0600) log in `~/Library/Logs/maintain/` (0700).
Logs contain timestamped phase/status records alongside raw command output.
Command output streams immediately to the console and file, including prompts
without newlines. Stdin remains connected for interactive responses. `--verbose`
adds command details; it is not required to see progress or prompts. Both command
and logging failures are checked. Password environment variables are not dumped.

An EXIT handler writes a final summary, including on handled SIGINT/SIGTERM.
As with any script, SIGKILL or power loss cannot run the handler. Failed required
steps return a nonzero exit. Runs that finish every selected phase report
“completed with failures” when earlier actions failed; stopped/interrupted messages
are reserved for early termination. Missing optional tools count as skipped, not successful.
Health warnings give their phase a WARNING state and are counted separately from
successful phases in the final summary. Preview phases are PLANNED, never counted
as completed.
`--dry-run` takes precedence over `-y` regardless of argument order. The log directory must be writable.

`LOG_LEVEL` controls console filtering (`error`, `warn`, `info`, `debug`).
`LOG_RETENTION_DAYS` defaults to 30. Cleanup prunes only matching old
`maintain-*.log` files from the maintenance log directory, preserving the current
log and other applications' logs. Preview runs still create their own log.

## Other tasks

Quick maintenance includes cleanup, Homebrew, App Store updates, an update check, and diagnostics. Explicit task flags without a preset select only those tasks; with a preset they are additive, and the last preset wins. Downloads cleanup, Restic backup, and OS update installation remain explicit. Cache cleanup removes user cache
direct children except these case-insensitive basename patterns:
`*safari*`, `*firefox*`, `*mozilla*`, `*chrome*`, `*chromium*`, `*brave*`, `*edge*`,
`*arc*`, `*obsidian*`, `*github*`, `restic`, `com.apple.*`, `*cloudkit*`,
`*geoservices*`, `*codex*`, `com.openai.*`, and `ms-playwright*`.
Symlinked cache roots and symlink entries (including dangling links) are skipped.
These are specific exclusions, not a guarantee that every authentication-related cache is protected.
Temporary cleanup requires a dedicated user-owned TMPDIR rather than shared /tmp.
The runner does not broadly delete system logs or `/private/var/folders` and does
not reset system databases or force-unlock backup repositories.

Diagnostics reports current Time Machine status and queries the latest successful
backup via `tmutil latestbackup -t`, without sudo or mounting destinations.
Only a timestamp-shaped result is accepted; empty, unexpected, or mount-error
output is unverified and gives Diagnostics a WARNING state even when `tmutil` exits zero. Unavailable
latest-backup information is not evidence that no backups exist; permissions or
disconnected destinations may prevent retrieval.

Homebrew upgrade output beginning with `Error:` is treated as a failed upgrade
even when Homebrew exits zero. The current machine's pgloader signing error
therefore remains a visible upgrade failure until the package is verified.

A requested backup runs before all other phases. Preflight, backup, or integrity
check failure prevents snapshot pruning; any backup-phase failure skips remaining
maintenance. Configure an existing repository with `RESTIC_REPOSITORY` and
`RESTIC_PASSWORD_FILE` or `RESTIC_PASSWORD`. It does not initialize repositories.
`BACKUP_SOURCE` defaults to your home; `BACKUP_KEEP_LAST` accepts 2 or 3 (default 3).
`BACKUP_MIN_FREE_GB` defaults to 10 and checks the **source filesystem**, not remote
repository capacity. Absolute local repository paths and the password file are
excluded from the backup. A successful backup is followed by `restic check`, then
retention/pruning. `check` checks repository structure; it is not a full data-read
or test restore. Keep an independent recovery copy of your password.

## Installing or updating maintain

Use the repository's absolute path in your shell alias, for example:

```sh
alias maintain='/absolute/path/to/Personal-Gists/zsh/macos_maintenance.sh'
```

Remove stale aliases. To also replace an old `/usr/local/bin/maintain` copy:

```sh
sudo install -m 755 /absolute/path/to/Personal-Gists/zsh/macos_maintenance.sh /usr/local/bin/maintain
```

Run `maintain --help` in a new shell and verify version 3.2.1. Run maintenance
without sudo. Installing a copy requires repeating the install after future edits.

## Validation and sources

Tests mock Homebrew and Time Machine and use temporary homes; they do not upgrade real packages.
Run on macOS with Bash 3.2 or later and bats-core:

```sh
bats tests/zsh/maintenance/maintenance.bats
shellcheck zsh/macos_maintenance.sh snippets/zsh/macos_maintenance.sh
bash -n zsh/macos_maintenance.sh
```

Logging follows [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html#s3-environment)
for stderr and explicit status checks. Homebrew behavior follows the
[official command reference](https://docs.brew.sh/Manpage) and
[FAQ on sudo](https://docs.brew.sh/FAQ#why-does-homebrew-say-sudo-is-bad).
