# Automatically select a Codex profile for the current Git repository.
#
# Convention:
#   1. A repository opts in with .local/codex-home/ or .local/codex-profile.
#   2. .local/codex-profile may contain an explicit profile name.
#   3. Otherwise, the sanitized repository directory name is the profile name.
#   4. The profile must exist at $HOME/.codex/<name>.config.toml.

_codex_project_profile_is_management_command() {
  emulate -L zsh

  local arg
  for arg in "$@"; do
    case "$arg" in
      login|logout|plugin|mcp-server|app-server|remote-control|app|cloud|exec-server|features|update|doctor|completion|apply|help)
        return 0
        ;;
    esac
  done

  return 1
}

_codex_project_profile_resolve() {
  emulate -L zsh

  local git_root marker profile profile_file

  git_root="$(command git rev-parse --show-toplevel 2>/dev/null)" || return 1
  [[ -n "$git_root" ]] || return 1

  marker="$git_root/.local/codex-profile"

  if [[ -f "$marker" ]]; then
    profile="$(<"$marker")"
    [[ "$profile" =~ '^[A-Za-z0-9_-]+$' ]] || return 1
  elif [[ -d "$git_root/.local/codex-home" ]]; then
    profile="${git_root:t}"
    profile="${profile//[^[:alnum:]_-]/_}"
  else
    return 1
  fi

  [[ -n "$profile" ]] || return 1
  profile_file="$HOME/.codex/$profile.config.toml"
  [[ -f "$profile_file" ]] || return 1

  print -r -- "$profile"
}

# codex_project_profile_status - show which configuration `codex` will use.
codex_project_profile_status() {
  emulate -L zsh

  local profile

  if [[ -n "${CODEX_HOME:-}" ]]; then
    print -r -- "explicit CODEX_HOME: $CODEX_HOME"
  elif profile="$(_codex_project_profile_resolve)"; then
    print -r -- "project profile: $profile"
  else
    print -r -- "global Codex configuration"
  fi
}

# codex - run Codex with an automatically selected project profile.
codex() {
  emulate -L zsh

  local arg profile

  # Explicit caller configuration always wins.
  if [[ -n "${CODEX_HOME:-}" ]]; then
    command codex "$@"
    return
  fi

  for arg in "$@"; do
    case "$arg" in
      -p|--profile|--profile=*)
        command codex "$@"
        return
        ;;
    esac
  done

  # Codex profiles apply to runtime commands, not management commands.
  if _codex_project_profile_is_management_command "$@"; then
    command codex "$@"
    return
  fi

  if profile="$(_codex_project_profile_resolve)"; then
    command codex --profile "$profile" "$@"
    return
  fi

  command codex "$@"
}
