#!/usr/bin/env bash
# macos_maintenance.sh - safe macOS maintenance runner
set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="macos_maintenance.sh"
readonly STANDARD_PLAN=(cleanup brew mas check_os_updates apply_os_updates diagnostics)

LOG_LEVEL=${LOG_LEVEL:-info}
DRY_RUN=true
VERBOSE=false
YES=false
cleanup=false
cleanup_downloads=false
cleanup_downloads_days=30
brew_update=false
mas_update=false
os_update_check=false
os_update_apply=false
diagnostics=false
backup=false
TASK_SELECTED=false

log() {
  local level="$1"; shift
  local message="$*"
  local levels=(error warn info debug)
  local current_index=2 level_index=2 idx
  for idx in "${!levels[@]}"; do
    [[ ${levels[$idx]} == "$LOG_LEVEL" ]] && current_index=$idx
    [[ ${levels[$idx]} == "$level" ]] && level_index=$idx
  done
  if (( level_index <= current_index )); then
    printf '%s [%5s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" >&2
  fi
}
log_debug() { log debug "$@"; }
log_info() { log info "$@"; }
log_warn() { log warn "$@"; }
log_error() { log error "$@"; }

check_binary() { command -v "$1" >/dev/null 2>&1; }

print_help() {
  cat <<USAGE
${SCRIPT_NAME} - safe macOS maintenance
Version: ${SCRIPT_VERSION}

Usage: macos_maintenance.sh [options]

Default:
  sudo maintain        Preview full standard maintenance plan
  sudo maintain -y     Run full standard maintenance plan

Standard plan:
  --cleanup
  --brew
  --mas
  --check-os-updates
  --apply-os-updates
  --diagnostics

Safety:
  Without -y, maintain runs in dry-run mode.
  Backup is opt-in only via --backup.
  Homebrew, user cache cleanup, and mas run as the invoking sudo user when run with sudo.

Options:
  --cleanup                 Conservative user cache/log/tmp cleanup
  --cleanup-downloads DAYS  Remove files older than DAYS in ~/Downloads (off by default)
  --brew                    Run Homebrew update/upgrade/cleanup
  --mas                     Run Mac App Store updates (mas upgrade)
  --check-os-updates        Check available macOS updates
  --apply-os-updates        Apply macOS updates (implies --check-os-updates)
  --diagnostics             Print diagnostic info and known brew conflicts
  --backup                  Opt-in backup placeholder (never part of the standard plan)
  --dry-run                 Preview actions without making changes (default)
  -y, --yes                 Apply selected tasks instead of dry-running
  --verbose                 Enable verbose logging
  --help, -h                Show this help text

Command-resolution note:
  If 'sudo maintain --help' does not show this version/help, sudo is resolving a different
  command than your shell alias. Use the absolute script path or install a root-visible
  wrapper that execs this file; do not continue with the mismatched command.
USAGE
}

is_positive_int() { [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]; }
mark_task() { TASK_SELECTED=true; }

ensure_macos_or_preview() {
  if [[ $(uname -s) != "Darwin" ]]; then
    if $DRY_RUN; then
      log_warn "Non-macOS host detected; continuing because this is a dry-run preview."
      return 0
    fi
    log_error "This script is intended for macOS only. Refusing to apply changes on $(uname -s)."
    exit 1
  fi
}

invoking_user() {
  if [[ ${SUDO_USER:-} && ${SUDO_USER:-root} != root ]]; then
    printf '%s\n' "$SUDO_USER"
  else
    id -un
  fi
}

user_home() {
  local user="$1" home
  if check_binary dscl; then
    home=$(dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}' || true)
  else
    home=$(getent passwd "$user" 2>/dev/null | cut -d: -f6 || true)
  fi
  [[ -n ${home:-} ]] || home=${HOME}
  printf '%s\n' "$home"
}

command_display() {
  local rendered="" arg
  for arg in "$@"; do
    printf -v arg '%q' "$arg"
    rendered+="${rendered:+ }$arg"
  done
  printf '%s' "$rendered"
}

run_cmd() {
  local description="$1"; shift
  if $DRY_RUN; then
    log_info "(dry-run) $description"
    log_debug "(dry-run command) $(command_display "$@")"
    return 0
  fi
  log_info "$description"
  "$@"
}

run_as_maintenance_user() {
  local description="$1"; shift
  local user; user=$(invoking_user)
  if [[ $EUID -eq 0 && $user != root ]]; then
    run_cmd "$description (as $user)" sudo -Hu "$user" env HOME="$(user_home "$user")" "$@"
  else
    if [[ $EUID -eq 0 && $DRY_RUN == false ]]; then
      log_error "Refusing to run user-level task as root without SUDO_USER. Re-run as your user or via sudo from an admin account."
      return 1
    fi
    if [[ $EUID -eq 0 && $DRY_RUN == true ]]; then
      run_cmd "$description (as current root context; no SUDO_USER detected for preview)" "$@"
    else
      run_cmd "$description" "$@"
    fi
  fi
}

maintenance_home() { user_home "$(invoking_user)"; }

should_skip_cache_path() {
  local base; base=$(basename "$1")
  case "$base" in
    *Safari*|com.apple.Safari*|*Firefox*|*Mozilla*|*Chrome*|*Chromium*|*Brave*|*Edge*|*Arc*|*Obsidian*|*GitHub*|restic)
      return 0 ;;
    *) return 1 ;;
  esac
}

cleanup_user_caches() {
  local home cache_root item processed=0
  home=$(maintenance_home); cache_root="$home/Library/Caches"
  [[ -d "$cache_root" ]] || { log_info "Cache root $cache_root not found; skipping."; return 0; }
  log_info "Conservative cache cleanup: preserving browser/session/auth-sensitive caches."
  while IFS= read -r -d '' item; do
    if should_skip_cache_path "$item"; then
      log_debug "Skipping protected cache: $item"
      continue
    fi
    run_as_maintenance_user "Removing cache item: $item" rm -rf "$item"
    ((processed+=1))
  done < <(find "$cache_root" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  log_info "Cache cleanup complete (processed $processed unprotected entries)."
}

cleanup_logs() {
  local home log_root
  home=$(maintenance_home); log_root="$home/Library/Logs"
  [[ -d "$log_root" ]] || { log_info "No user logs to prune at $log_root."; return 0; }
  run_as_maintenance_user "Deleting user logs older than 30 days under $log_root" find "$log_root" -type f -mtime +30 -print -delete
}

cleanup_tmpdir() {
  local tmp_root="${TMPDIR:-/tmp}"
  [[ -d "$tmp_root" ]] || { log_info "TMPDIR $tmp_root not found; skipping."; return 0; }
  run_as_maintenance_user "Deleting temporary files older than 7 days in $tmp_root" find "$tmp_root" -mindepth 1 -maxdepth 2 -type f -mtime +7 -print -delete
}

cleanup_downloads_run() {
  local home downloads_dir
  home=$(maintenance_home); downloads_dir="$home/Downloads"
  [[ -d "$downloads_dir" ]] || { log_info "Downloads directory not found at $downloads_dir; skipping."; return 0; }
  run_as_maintenance_user "Removing files older than ${cleanup_downloads_days}d in $downloads_dir" find "$downloads_dir" -type f -mtime +"$cleanup_downloads_days" -print -delete
}

run_cleanup() {
  cleanup_user_caches
  cleanup_logs
  cleanup_tmpdir
  if $cleanup_downloads; then cleanup_downloads_run; fi
}

run_brew_updates() {
  if ! check_binary brew; then log_warn "Homebrew not installed; skipping brew maintenance."; return 0; fi
  local status=0
  run_as_maintenance_user "Updating Homebrew metadata" brew update || status=$?
  run_as_maintenance_user "Upgrading installed Homebrew packages" brew upgrade || status=$?
  run_as_maintenance_user "Cleaning old Homebrew artifacts" brew cleanup || status=$?
  if (( status != 0 )); then
    log_error "Homebrew maintenance finished with failures (exit $status). Review brew output for packages requiring manual action."
    return "$status"
  fi
  log_info "Homebrew maintenance completed successfully."
}

run_mas_updates() {
  if ! check_binary mas; then log_warn "mas CLI not installed; skipping Mac App Store updates."; return 0; fi
  run_as_maintenance_user "Running Mac App Store updates" mas upgrade
}

run_os_updates() {
  local args=(--list)
  $os_update_apply && args=(--install --all)
  if $DRY_RUN; then log_info "(dry-run) $(command_display softwareupdate "${args[@]}")"; return 0; fi
  if [[ $EUID -eq 0 ]]; then
    run_cmd "Running softwareupdate ${args[*]}" softwareupdate "${args[@]}"
  else
    run_cmd "Running softwareupdate ${args[*]} via sudo" sudo softwareupdate "${args[@]}"
  fi
}

run_backup() {
  if $DRY_RUN; then
    log_info "(dry-run) backup requested via --backup; no backup is part of the standard plan."
    return 0
  fi
  log_error "Backup execution is intentionally not wired into the standard maintenance flow. Run your dedicated backup tool/script explicitly."
  return 2
}

run_brew_conflict_diagnostics() {
  if ! check_binary brew; then log_info "Brew diagnostics: brew not found."; return 0; fi
  log_info "Brew diagnostics: checking deprecated/conflicting Docker completion formulae."
  if brew list --formula 2>/dev/null | grep -qx 'docker-completion'; then
    log_warn "docker-completion is installed and may conflict with 'brew link docker'. Suggested manual review: brew unlink docker-completion && brew link docker"
  fi
  brew doctor || log_warn "brew doctor reported issues; review output above."
}

run_diagnostics() {
  log_info "Disk usage snapshot:"
  df -h / || true
  if check_binary tmutil; then log_info "Time Machine status:"; tmutil status || true; fi
  if check_binary log && [[ $(uname -s) == Darwin ]]; then
    log_info "Recent shutdown causes:"
    log show --predicate 'eventMessage CONTAINS "Previous shutdown cause"' --last 1d --info --debug | tail -n 20 || true
  fi
  run_brew_conflict_diagnostics
}

apply_standard_plan_if_needed() {
  if ! $TASK_SELECTED; then
    cleanup=true; brew_update=true; mas_update=true; os_update_check=true; os_update_apply=true; diagnostics=true
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cleanup) cleanup=true; mark_task ;;
    --cleanup-downloads)
      [[ $# -ge 2 ]] || { log_error "--cleanup-downloads requires a DAYS argument"; exit 1; }
      cleanup_downloads=true; cleanup_downloads_days="$2"; mark_task
      is_positive_int "$cleanup_downloads_days" || { log_error "DAYS must be a positive integer"; exit 1; }
      shift ;;
    --brew) brew_update=true; mark_task ;;
    --mas) mas_update=true; mark_task ;;
    --check-os-updates) os_update_check=true; mark_task ;;
    --apply-os-updates) os_update_check=true; os_update_apply=true; mark_task ;;
    --diagnostics) diagnostics=true; mark_task ;;
    --backup|--include-backup) backup=true; mark_task ;;
    --dry-run) DRY_RUN=true ;;
    -y|--yes) YES=true; DRY_RUN=false ;;
    --verbose) VERBOSE=true; LOG_LEVEL=debug ;;
    --help|-h) print_help; exit 0 ;;
    *) log_error "Unknown option: $1"; print_help; exit 1 ;;
  esac
  shift
done

apply_standard_plan_if_needed
ensure_macos_or_preview

log_info "Starting macOS maintenance version $SCRIPT_VERSION (dry-run=$DRY_RUN, verbose=$VERBOSE, user=$(invoking_user))."
$DRY_RUN && log_info "Plan mode: preview only. Re-run with -y/--yes to apply."

if $cleanup; then run_cleanup; fi
if $brew_update; then run_brew_updates; fi
if $mas_update; then run_mas_updates; fi
if $os_update_check; then run_os_updates; fi
if $diagnostics; then run_diagnostics; fi
if $backup; then run_backup; fi

log_info "Maintenance completed."
