#!/usr/bin/env bash
# macos_maintenance.sh - safe macOS maintenance runner
set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2.1.0"
readonly SCRIPT_NAME="macos_maintenance.sh"
readonly STANDARD_PLAN=(cleanup brew mas check_os_updates diagnostics)

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

# Backup defaults. Backup remains opt-in only via --backup.
BACKUP_KEEP_LAST=${BACKUP_KEEP_LAST:-3}
BACKUP_SOURCE=${BACKUP_SOURCE:-}
BACKUP_MIN_FREE_GB=${BACKUP_MIN_FREE_GB:-10}

TASK_TOTAL=0
TASK_OK=0
TASK_FAIL=0
TASK_SKIP=0
PHASE_INDEX=0
ERROR_SUMMARY=()
SELECTED_PHASES=()

CLEANUP_AREAS=()
CLEANUP_ITEMS=0
CLEANUP_BYTES_BEFORE=0
CLEANUP_BYTES_AFTER=0

log_should_emit() {
  local level="$1"
  local levels=(error warn info debug)
  local current_index=2 level_index=2 idx

  for idx in "${!levels[@]}"; do
    [[ ${levels[$idx]} == "$LOG_LEVEL" ]] && current_index=$idx
    [[ ${levels[$idx]} == "$level" ]] && level_index=$idx
  done

  ((level_index <= current_index))
}

check_binary() { command -v "$1" >/dev/null 2>&1; }

invoking_user() {
  if [[ ${SUDO_USER:-} && ${SUDO_USER:-root} != root ]]; then
    printf '%s\n' "$SUDO_USER"
  else
    id -un
  fi
}

log() {
  local level="$1"
  shift
  local message="$*"

  log_should_emit "$level" || return 0

  printf '%s script=%s version=%s level=%s pid=%s user=%s dry_run=%s msg=%q\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S%z')" \
    "$SCRIPT_NAME" \
    "$SCRIPT_VERSION" \
    "$level" \
    "$$" \
    "$(invoking_user 2>/dev/null || id -un)" \
    "$DRY_RUN" \
    "$message" >&2
}

log_debug() { log debug "$@"; }
log_info() { log info "$@"; }
log_warn() { log warn "$@"; }
log_error() { log error "$@"; }

record_error() {
  local message="$*"
  ERROR_SUMMARY+=("$message")
}

command_display() {
  local rendered="" arg
  for arg in "$@"; do
    printf -v arg '%q' "$arg"
    rendered+="${rendered:+ }$arg"
  done
  printf '%s' "$rendered"
}

log_command_output() {
  local level="$1" command_name="$2" output_file="$3" line

  [[ -s "$output_file" ]] || return 0

  while IFS= read -r line; do
    log "$level" "command=$command_name output=$line"
  done <"$output_file"
}

progress_bar() {
  local current="$1" total="$2" width=20 filled empty

  if ((total <= 0)); then total=1; fi

  filled=$((current * width / total))
  empty=$((width - filled))

  printf '['
  printf '%*s' "$filled" '' | tr ' ' '#'
  printf '%*s' "$empty" '' | tr ' ' '-'
  printf '] %s/%s' "$current" "$total"
}

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
  --backup                  Opt-in Restic backup; requires restic config/env
  --dry-run                 Preview actions without making changes (default)
  -y, --yes                 Apply selected tasks instead of dry-running
  --verbose                 Enable verbose logging
  --help, -h                Show this help text

Backup env:
  RESTIC_REPOSITORY         Required for --backup apply mode
  RESTIC_PASSWORD_FILE      Required unless RESTIC_PASSWORD is set
  RESTIC_PASSWORD           Required unless RESTIC_PASSWORD_FILE is set
  BACKUP_SOURCE             Optional; defaults to invoking user's home
  BACKUP_KEEP_LAST          Optional; must be 2 or 3; defaults to 3
  BACKUP_MIN_FREE_GB        Optional; minimum free space required on backup source filesystem; defaults to 10

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

user_home() {
  local user="$1" home=""

  if check_binary dscl; then
    home=$(dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}' || true)
  elif check_binary getent; then
    home=$(getent passwd "$user" 2>/dev/null | cut -d: -f6 || true)
  fi

  [[ -n ${home:-} ]] || home=${HOME}
  printf '%s\n' "$home"
}

maintenance_home() { user_home "$(invoking_user)"; }

run_cmd() {
  local description="$1"
  shift
  local cmd="${1:-}" output_file status=0

  if [[ -z "$cmd" ]]; then
    log_error "Cannot run command for '$description': no command provided."
    record_error "$description: no command provided"
    return 64
  fi

  if ! check_binary "$cmd"; then
    log_error "Cannot run '$cmd': command not found. '$description' was not attempted."
    record_error "$description: command not found: $cmd"
    return 127
  fi

  if $DRY_RUN; then
    log_info "(dry-run) $description"
    log_debug "(dry-run command) $(command_display "$@")"
    return 0
  fi

  output_file=$(mktemp)
  log_info "$description"
  log_debug "command=$(command_display "$@")"

  if "$@" >"$output_file" 2>&1; then
    log_command_output debug "$cmd" "$output_file"
    rm -f "$output_file"
    return 0
  fi

  status=$?
  log_command_output warn "$cmd" "$output_file"
  rm -f "$output_file"

  log_error "Command failed with exit_status=$status: $description"
  record_error "$description: exit_status=$status"
  return "$status"
}

run_as_maintenance_user() {
  local description="$1"
  shift
  local user
  user=$(invoking_user)

  if [[ $EUID -eq 0 && $user != root ]]; then
    run_cmd "$description (as $user)" sudo -Hu "$user" env HOME="$(user_home "$user")" "$@"
  else
    if [[ $EUID -eq 0 && $DRY_RUN == false ]]; then
      log_error "Refusing to run user-level task as root without SUDO_USER. Re-run as your user or via sudo from an admin account."
      record_error "$description: refused root user-level execution without SUDO_USER"
      return 1
    fi

    if [[ $EUID -eq 0 && $DRY_RUN == true ]]; then
      run_cmd "$description (as current root context; no SUDO_USER detected for preview)" "$@"
    else
      run_cmd "$description" "$@"
    fi
  fi
}

capture_as_maintenance_user() {
  local output_file="$1"
  shift
  local user status=0
  user=$(invoking_user)

  if [[ $EUID -eq 0 && $user != root ]]; then
    sudo -Hu "$user" env HOME="$(user_home "$user")" "$@" >"$output_file" 2>&1 || status=$?
  else
    "$@" >"$output_file" 2>&1 || status=$?
  fi

  return "$status"
}

bytes_for_path() {
  local path="$1"

  if [[ ! -e "$path" ]]; then
    printf '0\n'
    return 0
  fi

  du -sk "$path" 2>/dev/null | awk '{print $1 * 1024}' || printf '0\n'
}

add_cleanup_area_summary() {
  local name="$1" path="$2" before="$3" after="$4" count="$5" reclaimed
  reclaimed=$((before - after))
  ((reclaimed < 0)) && reclaimed=0

  CLEANUP_AREAS+=("$name:$path:items=$count:before_bytes=$before:after_bytes=$after:reclaimed_bytes=$reclaimed")
  CLEANUP_ITEMS=$((CLEANUP_ITEMS + count))
  CLEANUP_BYTES_BEFORE=$((CLEANUP_BYTES_BEFORE + before))
  CLEANUP_BYTES_AFTER=$((CLEANUP_BYTES_AFTER + after))
}

should_skip_cache_path() {
  local base
  base=$(basename "$1")

  case "$base" in
    *Safari* | com.apple.Safari* | *Firefox* | *Mozilla* | *Chrome* | *Chromium* | *Brave* | *Edge* | *Arc* | *Obsidian* | *GitHub* | restic)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

cleanup_user_caches() {
  local home cache_root item processed=0 before=0 after=0
  home=$(maintenance_home)
  cache_root="$home/Library/Caches"

  [[ -d "$cache_root" ]] || {
    log_info "Cache root $cache_root not found; skipping."
    return 0
  }

  before=$(bytes_for_path "$cache_root")
  log_info "Conservative cache cleanup: preserving browser/session/auth-sensitive caches."

  while IFS= read -r -d '' item; do
    if should_skip_cache_path "$item"; then
      log_debug "Skipping protected cache: $item"
      continue
    fi

    run_as_maintenance_user "Removing cache item: $item" rm -rf "$item"
    processed=$((processed + 1))
  done < <(find "$cache_root" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

  after=$(bytes_for_path "$cache_root")
  add_cleanup_area_summary "user_caches" "$cache_root" "$before" "$after" "$processed"
}

cleanup_logs() {
  local home log_root output_file processed=0 before=0 after=0 status=0
  home=$(maintenance_home)
  log_root="$home/Library/Logs"

  [[ -d "$log_root" ]] || {
    log_info "No user logs to prune at $log_root."
    return 0
  }

  before=$(bytes_for_path "$log_root")
  output_file=$(mktemp)

  if $DRY_RUN; then
    run_as_maintenance_user "Finding user logs older than 30 days under $log_root" find "$log_root" -type f -mtime +30 -print
    capture_as_maintenance_user "$output_file" find "$log_root" -type f -mtime +30 -print || status=$?
  else
    run_as_maintenance_user "Deleting user logs older than 30 days under $log_root" find "$log_root" -type f -mtime +30 -print -delete || status=$?
  fi

  [[ -s "$output_file" ]] && processed=$(wc -l <"$output_file" | tr -d ' ')
  rm -f "$output_file"

  after=$(bytes_for_path "$log_root")
  add_cleanup_area_summary "user_logs" "$log_root" "$before" "$after" "$processed"

  return "$status"
}

cleanup_tmpdir() {
  local tmp_root="${TMPDIR:-/tmp}" output_file processed=0 before=0 after=0 status=0

  [[ -d "$tmp_root" ]] || {
    log_info "TMPDIR $tmp_root not found; skipping."
    return 0
  }

  before=$(bytes_for_path "$tmp_root")
  output_file=$(mktemp)

  if $DRY_RUN; then
    run_as_maintenance_user "Finding temporary files older than 7 days in $tmp_root" find "$tmp_root" -mindepth 1 -maxdepth 2 -type f -mtime +7 -print
    capture_as_maintenance_user "$output_file" find "$tmp_root" -mindepth 1 -maxdepth 2 -type f -mtime +7 -print || status=$?
  else
    run_as_maintenance_user "Deleting temporary files older than 7 days in $tmp_root" find "$tmp_root" -mindepth 1 -maxdepth 2 -type f -mtime +7 -print -delete || status=$?
  fi

  [[ -s "$output_file" ]] && processed=$(wc -l <"$output_file" | tr -d ' ')
  rm -f "$output_file"

  after=$(bytes_for_path "$tmp_root")
  add_cleanup_area_summary "temporary_files" "$tmp_root" "$before" "$after" "$processed"

  return "$status"
}

cleanup_downloads_run() {
  local home downloads_dir output_file processed=0 before=0 after=0 status=0
  home=$(maintenance_home)
  downloads_dir="$home/Downloads"

  [[ -d "$downloads_dir" ]] || {
    log_info "Downloads directory not found at $downloads_dir; skipping."
    return 0
  }

  before=$(bytes_for_path "$downloads_dir")
  output_file=$(mktemp)

  if $DRY_RUN; then
    run_as_maintenance_user "Finding files older than ${cleanup_downloads_days}d in $downloads_dir" find "$downloads_dir" -type f -mtime +"$cleanup_downloads_days" -print
    capture_as_maintenance_user "$output_file" find "$downloads_dir" -type f -mtime +"$cleanup_downloads_days" -print || status=$?
  else
    run_as_maintenance_user "Removing files older than ${cleanup_downloads_days}d in $downloads_dir" find "$downloads_dir" -type f -mtime +"$cleanup_downloads_days" -print -delete || status=$?
  fi

  [[ -s "$output_file" ]] && processed=$(wc -l <"$output_file" | tr -d ' ')
  rm -f "$output_file"

  after=$(bytes_for_path "$downloads_dir")
  add_cleanup_area_summary "downloads" "$downloads_dir" "$before" "$after" "$processed"

  return "$status"
}

log_cleanup_summary() {
  local area reclaimed
  reclaimed=$((CLEANUP_BYTES_BEFORE - CLEANUP_BYTES_AFTER))
  ((reclaimed < 0)) && reclaimed=0

  log_info "Cleanup summary: areas=${#CLEANUP_AREAS[@]} items=$CLEANUP_ITEMS before_bytes=$CLEANUP_BYTES_BEFORE after_bytes=$CLEANUP_BYTES_AFTER reclaimed_bytes=$reclaimed"

  for area in "${CLEANUP_AREAS[@]}"; do
    log_info "Cleanup detail: $area"
  done
}

run_cleanup() {
  local status=0

  cleanup_user_caches || status=$?
  cleanup_logs || status=$?
  cleanup_tmpdir || status=$?
  if $cleanup_downloads; then cleanup_downloads_run || status=$?; fi

  log_cleanup_summary

  return "$status"
}

run_brew_updates() {
  local status=0 formula_outdated cask_outdated cleanup_preview outdated_count cleanup_count

  if ! check_binary brew; then
    log_warn "Homebrew not installed; skipping brew maintenance."
    TASK_SKIP=$((TASK_SKIP + 1))
    return 0
  fi

  run_as_maintenance_user "Updating Homebrew metadata" brew update || status=$?

  formula_outdated=$(mktemp)
  cask_outdated=$(mktemp)
  cleanup_preview=$(mktemp)

  capture_as_maintenance_user "$formula_outdated" brew outdated --formula --quiet || status=$?
  capture_as_maintenance_user "$cask_outdated" brew outdated --cask --quiet || status=$?
  capture_as_maintenance_user "$cleanup_preview" brew cleanup -n || true

  outdated_count=$(($(wc -l <"$formula_outdated" | tr -d ' ') + $(wc -l <"$cask_outdated" | tr -d ' ')))
  cleanup_count=$(grep -cve '^$' "$cleanup_preview" || true)

  if ((outdated_count == 0 && cleanup_count == 0)); then
    log_info "Homebrew: no upgrade or cleanup actions found."
  else
    log_info "Homebrew action summary: outdated=$outdated_count cleanup_candidates=$cleanup_count"
    run_as_maintenance_user "Upgrading installed Homebrew packages" brew upgrade || status=$?
    run_as_maintenance_user "Cleaning old Homebrew artifacts" brew cleanup || status=$?
  fi

  rm -f "$formula_outdated" "$cask_outdated" "$cleanup_preview"

  if ((status != 0)); then
    log_error "Homebrew maintenance ended with failures."
    return "$status"
  fi

  return 0
}

run_mas_updates() {
  if ! check_binary mas; then
    log_warn "mas CLI not installed; skipping Mac App Store updates."
    TASK_SKIP=$((TASK_SKIP + 1))
    return 0
  fi

  run_as_maintenance_user "Running Mac App Store updates" mas upgrade
}

run_os_updates() {
  local args=(--list)

  $os_update_apply && args=(--install --all)

  if $DRY_RUN; then
    log_info "(dry-run) $(command_display softwareupdate "${args[@]}")"
    return 0
  fi

  if [[ $EUID -eq 0 ]]; then
    run_cmd "Running softwareupdate ${args[*]}" softwareupdate "${args[@]}"
  else
    run_cmd "Running softwareupdate ${args[*]} via sudo" sudo softwareupdate "${args[@]}"
  fi
}

check_backup_disk_space() {
  local path="$1" min_free_gb="$2" available_kb available_gb

  if ! check_binary df; then
    log_error "Backup preflight failed: cannot check disk space because 'df' is unavailable."
    record_error "backup: missing df for disk-space preflight"
    return 1
  fi

  if [[ ! -e "$path" ]]; then
    log_error "Backup preflight failed: backup source does not exist: $path"
    record_error "backup: missing source path: $path"
    return 1
  fi

  available_kb=$(df -Pk "$path" 2>/dev/null | awk 'NR == 2 {print $4}' || true)

  if [[ -z "$available_kb" || ! "$available_kb" =~ ^[0-9]+$ ]]; then
    log_error "Backup preflight failed: disk-space check did not return usable output for $path."
    record_error "backup: disk-space check returned no usable output"
    return 1
  fi

  available_gb=$((available_kb / 1024 / 1024))
  log_info "Backup disk-space preflight: path=$path available_gb=$available_gb min_required_gb=$min_free_gb"

  if ((available_gb < min_free_gb)); then
    log_error "Backup preflight failed: available disk space is below configured threshold."
    record_error "backup: insufficient free space available_gb=$available_gb min_required_gb=$min_free_gb"
    return 1
  fi
}

validate_backup_config() {
  local keep_last="$BACKUP_KEEP_LAST"

  if ! check_binary restic; then
    log_error "Backup preflight failed: restic is not installed."
    record_error "backup: missing restic"
    return 1
  fi

  if [[ -z ${RESTIC_REPOSITORY:-} ]]; then
    log_error "Backup preflight failed: RESTIC_REPOSITORY is not set."
    record_error "backup: RESTIC_REPOSITORY not set"
    return 1
  fi

  if [[ -z ${RESTIC_PASSWORD_FILE:-} && -z ${RESTIC_PASSWORD:-} ]]; then
    log_error "Backup preflight failed: RESTIC_PASSWORD_FILE or RESTIC_PASSWORD is required."
    record_error "backup: missing restic password source"
    return 1
  fi

  if [[ "$keep_last" != "2" && "$keep_last" != "3" ]]; then
    log_error "Backup preflight failed: BACKUP_KEEP_LAST must be 2 or 3."
    record_error "backup: invalid BACKUP_KEEP_LAST=$keep_last"
    return 1
  fi
}

run_backup() {
  local source_path keep_last status=0

  source_path="${BACKUP_SOURCE:-$(maintenance_home)}"
  keep_last="$BACKUP_KEEP_LAST"

  if $DRY_RUN; then
    log_info "(dry-run) backup requested; would run Restic backup for source=$source_path keep_last=$keep_last."
    return 0
  fi

  validate_backup_config || return 1
  check_backup_disk_space "$source_path" "$BACKUP_MIN_FREE_GB" || return 1

  run_cmd "Running encrypted Restic backup for $source_path" restic backup "$source_path" || status=$?

  if ((status == 0)); then
    run_cmd "Applying Restic retention policy: keep last $keep_last snapshots and prune" restic forget --keep-last "$keep_last" --prune || status=$?
  fi

  if ((status != 0)); then
    log_error "Backup phase ended with red flags; no completion message emitted."
    return "$status"
  fi

  return 0
}

run_brew_conflict_diagnostics() {
  if ! check_binary brew; then
    log_info "Brew diagnostics: brew not found."
    return 0
  fi

  log_info "Brew diagnostics: checking deprecated/conflicting Docker completion formulae."

  if brew list --formula 2>/dev/null | grep -qx 'docker-completion'; then
    log_warn "docker-completion is installed and may conflict with 'brew link docker'. Suggested manual review: brew unlink docker-completion && brew link docker"
  fi

  brew doctor || log_warn "brew doctor reported issues; review output above."
}

run_diagnostics() {
  log_info "Disk usage snapshot:"
  df -h / || true

  if check_binary tmutil; then
    log_info "Time Machine status:"
    tmutil status || true
  fi

  if check_binary log && [[ $(uname -s) == Darwin ]]; then
    log_info "Recent shutdown causes:"
    log show --predicate 'eventMessage CONTAINS "Previous shutdown cause"' --last 1d --info --debug | tail -n 20 || true
  fi

  run_brew_conflict_diagnostics
}

apply_standard_plan_if_needed() {
  if ! $TASK_SELECTED; then
    cleanup=true
    brew_update=true
    mas_update=true
    os_update_check=true
    os_update_apply=false
    diagnostics=true
  fi
}

build_selected_phases() {
  SELECTED_PHASES=()

  if $cleanup; then SELECTED_PHASES+=("Cleanup"); fi
  if $brew_update; then SELECTED_PHASES+=("Homebrew Maintenance"); fi
  if $mas_update; then SELECTED_PHASES+=("Mac App Store Maintenance"); fi
  if $os_update_check; then SELECTED_PHASES+=("macOS Update Check"); fi
  if $diagnostics; then SELECTED_PHASES+=("Diagnostics"); fi
  if $backup; then SELECTED_PHASES+=("System Backup"); fi
}

run_phase() {
  local phase="$1"
  shift
  local start end duration status=0 bar

  PHASE_INDEX=$((PHASE_INDEX + 1))
  TASK_TOTAL=$((TASK_TOTAL + 1))
  bar=$(progress_bar "$PHASE_INDEX" "${#SELECTED_PHASES[@]}")
  start=$(date +%s)

  log_info "progress=$bar phase=$phase state=starting"

  "$@" || status=$?

  end=$(date +%s)
  duration=$((end - start))

  if ((status == 0)); then
    TASK_OK=$((TASK_OK + 1))
    log_info "phase=$phase state=completed duration_seconds=$duration"
  else
    TASK_FAIL=$((TASK_FAIL + 1))
    log_error "phase=$phase state=incomplete duration_seconds=$duration exit_status=$status"
  fi

  return 0
}

print_final_summary() {
  local incomplete errors_joined="none" err
  incomplete=$((TASK_FAIL + TASK_SKIP))

  if ((${#ERROR_SUMMARY[@]} > 0)); then
    errors_joined=""
    for err in "${ERROR_SUMMARY[@]}"; do
      errors_joined+="${errors_joined:+; }$err"
    done
  fi

  log_info "summary requested=$TASK_TOTAL completed_successfully=$TASK_OK incomplete=$incomplete failed=$TASK_FAIL skipped=$TASK_SKIP errors={$errors_joined}"

  if ((TASK_FAIL > 0)); then
    log_error "Maintenance ended with incomplete phases. Review red flags above."
    return 1
  fi

  if ((TASK_SKIP > 0)); then
    log_warn "Maintenance finished without failed phases, but some optional/unavailable actions were skipped."
    return 0
  fi

  log_info "Maintenance green across selected phases."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cleanup)
      cleanup=true
      mark_task
      ;;
    --cleanup-downloads)
      [[ $# -ge 2 ]] || {
        log_error "--cleanup-downloads requires a DAYS argument"
        exit 1
      }
      cleanup_downloads=true
      cleanup_downloads_days="$2"
      mark_task
      is_positive_int "$cleanup_downloads_days" || {
        log_error "DAYS must be a positive integer"
        exit 1
      }
      shift
      ;;
    --brew)
      brew_update=true
      mark_task
      ;;
    --mas)
      mas_update=true
      mark_task
      ;;
    --check-os-updates)
      os_update_check=true
      mark_task
      ;;
    --apply-os-updates)
      os_update_check=true
      os_update_apply=true
      mark_task
      ;;
    --diagnostics)
      diagnostics=true
      mark_task
      ;;
    --backup | --include-backup)
      backup=true
      mark_task
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    -y | --yes)
      YES=true
      DRY_RUN=false
      ;;
    --verbose)
      VERBOSE=true
      LOG_LEVEL=debug
      ;;
    --help | -h)
      print_help
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      print_help
      exit 1
      ;;
  esac
  shift
done

apply_standard_plan_if_needed
build_selected_phases
ensure_macos_or_preview

log_info "Starting macOS maintenance version $SCRIPT_VERSION (dry-run=$DRY_RUN, verbose=$VERBOSE, user=$(invoking_user))."
$DRY_RUN && log_info "Plan mode: preview only. Re-run with -y/--yes to apply."

if $cleanup; then run_phase "Cleanup" run_cleanup; fi
if $brew_update; then run_phase "Homebrew Maintenance" run_brew_updates; fi
if $mas_update; then run_phase "Mac App Store Maintenance" run_mas_updates; fi
if $os_update_check; then run_phase "macOS Update Check" run_os_updates; fi
if $diagnostics; then run_phase "Diagnostics" run_diagnostics; fi
if $backup; then run_phase "System Backup" run_backup; fi

print_final_summary
