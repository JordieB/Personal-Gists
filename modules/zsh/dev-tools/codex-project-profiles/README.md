# Codex project profiles

Automatically select a user-level Codex profile based on the current Git
repository while preserving normal global authentication, plugins, sessions,
and state.

Codex profiles live at `$CODEX_HOME/<name>.config.toml`; with the default
Codex home, that is `~/.codex/<name>.config.toml`.

## Install

Source the plugin from `.zshrc`:

```zsh
source /path/to/codex-project-profiles.plugin.zsh
```

Start a new shell or reload the file:

```zsh
source ~/.zshrc
```

## Repository setup

Use either convention below. Both files belong in `.local/`, which should be
excluded through the clone-local `.git/info/exclude` when you do not want to
change the shared `.gitignore`.

### Repository-name convention

Create the private standards directory:

```zsh
mkdir -p .local/codex-home
```

If the Git root is `/work/acme-api`, the plugin looks for:

```text
~/.codex/acme-api.config.toml
```

Characters outside letters, numbers, hyphens, and underscores are converted
to underscores.

### Explicit profile marker

To use a different profile name:

```zsh
mkdir -p .local
print -r -- analytics > .local/codex-profile
```

The plugin then looks for:

```text
~/.codex/analytics.config.toml
```

Profile names may contain only letters, numbers, hyphens, and underscores.

## Behavior

- `codex` inside an opted-in repository adds `--profile <name>`.
- Git subdirectories resolve from the repository root.
- An explicit `CODEX_HOME`, `-p`, or `--profile` takes precedence.
- Repositories without a matching profile use normal global Codex.
- Codex management commands such as `login`, `plugin`, `features`, and
  `doctor` use normal global Codex because profiles do not apply to them.

Show the current resolution without starting Codex:

```zsh
codex_project_profile_status
```

## Example profile

```toml
# ~/.codex/acme-api.config.toml
model_reasoning_effort = "low"
approval_policy = "on-request"
sandbox_mode = "workspace-write"
model_instructions_file = "/work/acme-api/.local/codex-home/GUIDANCE.md"

[features]
hooks = true
multi_agent = true
```

Keep credentials and general-purpose configuration in `~/.codex/config.toml`.
The project profile should contain only the overrides needed by that project.

## Requirements

- Zsh 5.x
- Git
- Codex CLI with file-based profiles (`--profile`)

See the official Codex documentation for
[profiles](https://developers.openai.com/codex/config-advanced#profiles) and
[configuration/state locations](https://developers.openai.com/codex/config-advanced#config-and-state-locations).
