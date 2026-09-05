# macOS maintenance

`macos_maintenance.sh` is the canonical runner. The script under
`snippets/zsh/` forwards to it. The system-maintenance plugin is a separate stub.

Run as your normal user, without `sudo`. Version 3.1 defaults to **interactive Homebrew maintenance**, including greedy
cask upgrades and unused-dependency removal. Use `--dry-run` for a preview. It refuses root execution; explicitly
requested macOS updates invoke sudo for the system command.

```sh
./zsh/macos_maintenance.sh                 # Run interactive Homebrew maintenance
./zsh/macos_maintenance.sh -y              # Approve Homebrew upgrade confirmations
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
   Homebrew's pinned packages. Confirmation prompts remain visible; `-y` supplies
   Homebrew's `--no-ask`. Installer password prompts may still occur.
4. Remove unused dependencies. `--no-brew-autoremove` selects a preview instead.
5. Run normal cleanup only when upgrades and the dependency step succeeded.
6. Run doctor. Its warnings are recorded without failing successful upgrades.

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
steps return a nonzero exit. Missing optional tools count as skipped, not successful.
`brew doctor` warnings remain warnings and are counted separately in the final
health summary. Preview phases are PLANNED, never counted as completed.
`--dry-run` takes precedence over `-y` regardless of argument order. The log directory must be writable.

`LOG_LEVEL` controls console filtering (`error`, `warn`, `info`, `debug`).
`LOG_RETENTION_DAYS` defaults to 30. `--cleanup -y` prunes only matching old
`maintain-*.log` files from the maintenance log directory, preserving the current
log and other applications' logs. Preview runs still create their own log.

## Other tasks

Cleanup, App Store updates, macOS updates, diagnostics, Downloads cleanup, and
Restic backup are explicit options; see `--help`. Cache cleanup removes user cache
entries except the protected browser/session entries, so select it deliberately.
Temporary cleanup requires a dedicated user-owned TMPDIR rather than shared /tmp.
The runner does not broadly delete system logs or `/private/var/folders` and does
not reset system databases or force-unlock backup repositories.

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

The root-level `maintenance.conf` is legacy configuration and is not loaded by
this runner. Use documented command-line options and environment variables.

## Installing or updating maintain

Use the repository's absolute path in your shell alias, for example:

```sh
alias maintain='/absolute/path/to/Personal-Gists/zsh/macos_maintenance.sh'
```

Remove stale aliases. To also replace an old `/usr/local/bin/maintain` copy:

```sh
sudo install -m 755 /absolute/path/to/Personal-Gists/zsh/macos_maintenance.sh /usr/local/bin/maintain
```

Run `maintain --help` in a new shell and verify version 3.1.0. Run maintenance
without sudo. Installing a copy requires repeating the install after future edits.

## Validation and sources

Tests mock Homebrew and use temporary homes; they do not upgrade real packages.
Run on macOS with Bash 3.2 or later and bats-core:

```sh
bats zsh/tests/maintenance.bats
shellcheck zsh/macos_maintenance.sh snippets/zsh/macos_maintenance.sh
bash -n zsh/macos_maintenance.sh
```

Logging follows [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html#s3-environment)
for stderr and explicit status checks. Homebrew behavior follows the
[official command reference](https://docs.brew.sh/Manpage) and
[FAQ on sudo](https://docs.brew.sh/FAQ#why-does-homebrew-say-sudo-is-bad).
