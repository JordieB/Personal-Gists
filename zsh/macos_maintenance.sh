#!/usr/bin/env bash
# macos_maintenance.sh - safe macOS maintenance runner
# Phase functions are dispatched through run_phase; finish is an EXIT trap.
# shellcheck disable=SC2329
set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="3.2.0"
readonly SCRIPT_NAME="macos_maintenance.sh"

LOG_LEVEL=${LOG_LEVEL:-info}
DRY_RUN=false
YES=false
cleanup=false
cleanup_downloads=false
cleanup_downloads_days=30
brew_update=false
mas_update=false
os_update_check=false
os_update_apply=false
diagnostics=false
diagnostics_shutdown_cause=false
backup=false
TASK_SELECTED=false
PRESET=""
brew_autoremove=true
brew_greedy=true
LOGFILE=""
RUN_TMP=""
CURRENT_PHASE=startup
RUN_START=$SECONDS
LOG_RETENTION_DAYS=${LOG_RETENTION_DAYS:-30}

# Backup defaults. Backup remains opt-in only via --backup.
BACKUP_KEEP_LAST=${BACKUP_KEEP_LAST:-3}
BACKUP_SOURCE=${BACKUP_SOURCE:-}
BACKUP_MIN_FREE_GB=${BACKUP_MIN_FREE_GB:-10}

TASK_TOTAL=0
TASK_OK=0
TASK_PLANNED=0
HEALTH_WARNINGS=0
TASK_FAIL=0
TASK_SKIP=0
PHASE_INDEX=0
ERROR_SUMMARY=()
SELECTED_PHASES=()
RUN_COMMAND_FAILURE_KIND=""

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

  local entry
  printf -v entry '%s level=%s phase=%q msg=%s' \
    "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$level" "$CURRENT_PHASE" "$message"
  if [[ -n "$LOGFILE" ]]; then
    printf '%s\n' "$entry" >&9 || { printf 'Cannot write maintenance log\n' >&2; exit 1; }
  fi
  if log_should_emit "$level"; then printf '%s\n' "$entry" >&2; fi
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

  while IFS= read -r line || [[ -n "$line" ]]; do
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
  maintain             Run the quick maintenance preset
  maintain -y          Run quick maintenance and approve Homebrew prompts

Quick plan: cleanup, Homebrew, App Store updates, macOS update check, and diagnostics.

Safety:
  Maintenance runs by default. Use --dry-run to preview without execution.
  App upgrades can close/reopen apps and request administrator passwords.
  Backup is opt-in only via --backup.
  Run as your normal user. The script refuses root execution.
  A requested backup runs first; failure skips all remaining tasks.

Options:
  --quick                   Select the default quick maintenance preset
  --comprehensive           Select quick tasks plus recent shutdown-cause diagnostics
  --cleanup                 Run user cache/tmp and maintenance-log cleanup
  --cleanup-downloads DAYS  Remove files older than DAYS in ~/Downloads (off by default)
  --brew                    Run Homebrew update, upgrades, cleanup, and doctor
  --brew-autoremove         Remove unused formula dependencies (default)
  --brew-greedy             Include self-updating/latest casks (default)
  --no-brew-autoremove      Preview unused dependencies instead of removing them
  --no-brew-greedy          Exclude greedy cask upgrades
  --mas                     Run Mac App Store updates (mas upgrade)
  --check-os-updates        Check available macOS updates
  --apply-os-updates        Apply macOS updates (implies --check-os-updates)
  --diagnostics             Check disk usage, Time Machine, and Homebrew health
  --backup                  Opt-in Restic backup; requires restic config/env
  --dry-run                 Preview actions without making changes
  -y, --yes                 Approve Homebrew upgrade confirmations; does not override --dry-run
  --verbose                 Show additional command details; output always streams live
  --help, -h                Show this help text

Backup env:
  RESTIC_REPOSITORY         Required for --backup apply mode
  RESTIC_PASSWORD_FILE      Required unless RESTIC_PASSWORD is set
  RESTIC_PASSWORD           Required unless RESTIC_PASSWORD_FILE is set
  BACKUP_SOURCE             Optional; defaults to invoking user's home
  BACKUP_KEEP_LAST          Optional; must be 2 or 3; defaults to 3
  BACKUP_MIN_FREE_GB        Optional; minimum free space required on backup source filesystem; defaults to 10

Logging:
  Logs: ~/Library/Logs/maintain/maintain-TIMESTAMP-UNIQUE.log (mode 600).
  LOG_LEVEL: error, warn, info (default), debug; file always includes all levels.
  LOG_RETENTION_DAYS: positive integer, defaults to 30; applied whenever cleanup runs.

Selection:
  With no task flags, --quick is selected. Explicit task flags alone select only
  those tasks. With a preset, explicit task flags are additive; the last preset wins.
  Backup, Downloads deletion, and OS update installation are always explicit.

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
  local cmd="${1:-}" status=0 started=$SECONDS
  local failure_level=${COMMAND_FAILURE_LEVEL:-error}
  RUN_COMMAND_FAILURE_KIND=""

  if [[ -z "$cmd" ]]; then
    log_error "Cannot run command for '$description': no command provided."
    record_error "$description: no command provided"
    RUN_COMMAND_FAILURE_KIND="command"
    return 64
  fi

  if ! check_binary "$cmd"; then
    log_error "Cannot run '$cmd': command not found. '$description' was not attempted."
    record_error "$description: command not found: $cmd"
    RUN_COMMAND_FAILURE_KIND="command"
    return 127
  fi

  if $DRY_RUN; then
    log_info "(dry-run) $description"
    log_debug "(dry-run command) $(command_display "$@")"
    return 0
  fi

  log_info "$description"
  log_debug "command=$(command_display "$@")"
  # Keep stdin attached for prompts; stream bytes (including prompts without a
  # newline) immediately. Capture both pipeline statuses before another command.
  local pipeline_status=()
  if "$@" 2>&1 | tee -a "$LOGFILE"; then
    pipeline_status=("${PIPESTATUS[@]}")
  else
    pipeline_status=("${PIPESTATUS[@]}")
  fi
  status=${pipeline_status[0]}
  if ((pipeline_status[1] != 0)); then
    log_error "Failed to save command output: $cmd"
    record_error "$description: output logging failed"
    RUN_COMMAND_FAILURE_KIND="logging"
    return 1
  fi
  if ((status == 0)); then
    log_info "command=$cmd state=SUCCESS exit_status=0 duration_seconds=$((SECONDS - started))"
    return 0
  fi

  log "$failure_level" "command=$cmd state=FAILED exit_status=$status duration_seconds=$((SECONDS - started)): $description"
  if [[ "$failure_level" == error ]]; then record_error "$description: exit_status=$status"; fi
  RUN_COMMAND_FAILURE_KIND="command"
  return "$status"
}

run_as_maintenance_user() {
  run_cmd "$@"
}

capture_as_maintenance_user() {
  local output_file="$1"
  shift
  "$@" >"$output_file" 2>&1
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
    *Safari* | *Firefox* | *Mozilla* | *Chrome* | *Chromium* | *Brave* | *Edge* | *Arc* | *Obsidian* | *GitHub* | restic)
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

    run_as_maintenance_user "Removing cache item: $item" rm -rf "$item" || return $?
    processed=$((processed + 1))
  done < <(find "$cache_root" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

  after=$(bytes_for_path "$cache_root")
  add_cleanup_area_summary "user_caches" "$cache_root" "$before" "$after" "$processed"
}

cleanup_logs() {
  local home log_root output_file processed=0 before=0 after=0 status=0
  home=$(maintenance_home)
  log_root="$home/Library/Logs/maintain"

  [[ -d "$log_root" ]] || {
    log_info "No user logs to prune at $log_root."
    return 0
  }

  before=$(bytes_for_path "$log_root")
  output_file=$(mktemp "$RUN_TMP/command.XXXXXX")

  if $DRY_RUN; then
    run_as_maintenance_user "Finding maintenance logs older than $LOG_RETENTION_DAYS days under $log_root" find "$log_root" -type f -name 'maintain-*.log' ! -path "$LOGFILE" -mtime +"$LOG_RETENTION_DAYS" -print
    capture_as_maintenance_user "$output_file" find "$log_root" -type f -name 'maintain-*.log' ! -path "$LOGFILE" -mtime +"$LOG_RETENTION_DAYS" -print || status=$?
  else
    capture_as_maintenance_user "$output_file" find "$log_root" -type f -name 'maintain-*.log' ! -path "$LOGFILE" -mtime +"$LOG_RETENTION_DAYS" -print || status=$?
    ((status == 0)) || { rm -f "$output_file"; return "$status"; }
    run_as_maintenance_user "Deleting maintenance logs older than $LOG_RETENTION_DAYS days under $log_root" find "$log_root" -type f -name 'maintain-*.log' ! -path "$LOGFILE" -mtime +"$LOG_RETENTION_DAYS" -print -delete || status=$?
  fi

  [[ -s "$output_file" ]] && processed=$(wc -l <"$output_file" | tr -d ' ')
  rm -f "$output_file"

  after=$(bytes_for_path "$log_root")
  add_cleanup_area_summary "user_logs" "$log_root" "$before" "$after" "$processed"

  return "$status"
}

cleanup_tmpdir() {
  local tmp_root="${TMPDIR:-/tmp}" output_file processed=0 before=0 after=0 status=0

  if [[ -z ${TMPDIR:-} || "$tmp_root" == /tmp || "$tmp_root" == /private/tmp || ! -O "$tmp_root" ]]; then
    log_warn "Skipping temporary cleanup: no dedicated user-owned TMPDIR."
    return 0
  fi

  [[ -d "$tmp_root" ]] || {
    log_info "TMPDIR $tmp_root not found; skipping."
    return 0
  }

  before=$(bytes_for_path "$tmp_root")
  output_file=$(mktemp "$RUN_TMP/command.XXXXXX")

  if $DRY_RUN; then
    run_as_maintenance_user "Finding temporary files older than 7 days in $tmp_root" find "$tmp_root" -mindepth 1 -maxdepth 2 -type f -mtime +7 -print
    capture_as_maintenance_user "$output_file" find "$tmp_root" -mindepth 1 -maxdepth 2 -type f -mtime +7 -print || status=$?
  else
    capture_as_maintenance_user "$output_file" find "$tmp_root" -mindepth 1 -maxdepth 2 -type f -mtime +7 -print || status=$?
    ((status == 0)) || { rm -f "$output_file"; return "$status"; }
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
  output_file=$(mktemp "$RUN_TMP/command.XXXXXX")

  if $DRY_RUN; then
    run_as_maintenance_user "Finding files older than ${cleanup_downloads_days}d in $downloads_dir" find "$downloads_dir" -type f -mtime +"$cleanup_downloads_days" -print
    capture_as_maintenance_user "$output_file" find "$downloads_dir" -type f -mtime +"$cleanup_downloads_days" -print || status=$?
  else
    capture_as_maintenance_user "$output_file" find "$downloads_dir" -type f -mtime +"$cleanup_downloads_days" -print || status=$?
    ((status == 0)) || { rm -f "$output_file"; return "$status"; }
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

  if $cleanup; then
    cleanup_user_caches || status=$?
    cleanup_logs || status=$?
    cleanup_tmpdir || status=$?
  fi
  if $cleanup_downloads; then cleanup_downloads_run || status=$?; fi

  log_cleanup_summary

  return "$status"
}

run_brew_updates() {
  local status=0 cask_args=(--cask) upgrade_args=(--ask)
  if $YES; then upgrade_args=(--no-ask); fi
  if ! check_binary brew; then
    log_warn "Homebrew not installed; skipping brew maintenance."
    TASK_SKIP=$((TASK_SKIP + 1))
    return 0
  fi
  if $brew_greedy; then cask_args+=(--greedy); fi
  # Each dependency is checked explicitly: run_phase calls this in a conditional,
  # where Bash errexit does not propagate into function bodies.
  run_cmd "Updating Homebrew metadata" brew update || return $?
  run_cmd "Listing outdated formulae" brew outdated --formula || return $?
  run_cmd "Listing outdated casks" brew outdated "${cask_args[@]}" || return $?
  run_cmd "Upgrading Homebrew formulae" brew upgrade --formula "${upgrade_args[@]}" || status=$?
  run_cmd "Upgrading Homebrew casks" brew upgrade "${cask_args[@]}" "${upgrade_args[@]}" || status=$?
  if ((status == 0)); then
    if $brew_autoremove; then
      run_cmd "Removing unused Homebrew dependencies" brew autoremove || status=$?
    else
      run_cmd "Previewing unused Homebrew dependencies" brew autoremove --dry-run || status=$?
    fi
    if ((status == 0)); then
      run_cmd "Cleaning old Homebrew artifacts" brew cleanup || status=$?
    fi
  else
    log_warn "Skipping Homebrew cleanup and autoremove because an upgrade failed."
  fi
  if ! COMMAND_FAILURE_LEVEL=warn run_cmd "Checking Homebrew health" brew doctor; then
    if [[ "$RUN_COMMAND_FAILURE_KIND" == logging ]]; then return 1; fi
    HEALTH_WARNINGS=$((HEALTH_WARNINGS + 1))
    log_warn "brew doctor reported potential issues; review the log."
  fi
  return "$status"
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

  if $os_update_apply && [[ $EUID -ne 0 ]]; then
    run_cmd "Running softwareupdate ${args[*]} via sudo" sudo softwareupdate "${args[@]}"
  else
    run_cmd "Running softwareupdate ${args[*]}" softwareupdate "${args[@]}"
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
  local source_path keep_last status=0 backup_args=()

  source_path="${BACKUP_SOURCE:-$(maintenance_home)}"
  keep_last="$BACKUP_KEEP_LAST"

  if $DRY_RUN; then
    log_info "(dry-run) backup requested; would run Restic backup for source=$source_path keep_last=$keep_last."
    return 0
  fi

  validate_backup_config || return 1
  check_backup_disk_space "$source_path" "$BACKUP_MIN_FREE_GB" || return 1

  # Do not include a local repository or its password in the backup itself.
  if [[ ${RESTIC_REPOSITORY:-} == /* ]]; then backup_args+=(--exclude "$RESTIC_REPOSITORY"); fi
  if [[ -n ${RESTIC_PASSWORD_FILE:-} ]]; then backup_args+=(--exclude "$RESTIC_PASSWORD_FILE"); fi
  run_cmd "Running encrypted Restic backup for $source_path" restic backup "${backup_args[@]}" "$source_path" || status=$?

  if ((status == 0)); then
    run_cmd "Checking Restic repository integrity" restic check || status=$?
  fi

  if ((status == 0)); then
    run_cmd "Applying Restic retention policy: keep last $keep_last snapshots and prune" restic forget --keep-last "$keep_last" --prune || status=$?
  fi

  if ((status != 0)); then
    log_error "Backup phase ended with red flags; no completion message emitted."
    return "$status"
  fi

  return 0
}

run_diagnostics() {
  local status=0
  run_cmd "Disk usage snapshot" df -h / || status=$?
  if check_binary tmutil; then run_cmd "Time Machine status" tmutil status || status=$?; fi
  if check_binary brew; then
    if ! COMMAND_FAILURE_LEVEL=warn run_cmd "Checking Homebrew health" brew doctor; then
      if [[ "$RUN_COMMAND_FAILURE_KIND" == logging ]]; then return 1; fi
      HEALTH_WARNINGS=$((HEALTH_WARNINGS + 1))
      log_warn "brew doctor reported potential issues; review the log."
    fi
  fi
  if $diagnostics_shutdown_cause; then
    run_cmd "Recent shutdown causes" /usr/bin/log show --predicate 'eventMessage CONTAINS "Previous shutdown cause"' --last 1d --info --debug || status=$?
  fi
  return "$status"
}

apply_standard_plan_if_needed() {
  if [[ -z "$PRESET" ]] && ! $TASK_SELECTED; then PRESET=quick; fi

  if [[ -n "$PRESET" ]]; then
    cleanup=true
    brew_update=true
    mas_update=true
    os_update_check=true
    diagnostics=true
    diagnostics_shutdown_cause=false
    if [[ "$PRESET" == comprehensive ]]; then diagnostics_shutdown_cause=true; fi
  fi
}

build_selected_phases() {
  SELECTED_PHASES=()

  if $backup; then SELECTED_PHASES+=("System Backup"); fi
  if $cleanup || $cleanup_downloads; then SELECTED_PHASES+=("Cleanup"); fi
  if $brew_update; then SELECTED_PHASES+=("Homebrew Maintenance"); fi
  if $mas_update; then SELECTED_PHASES+=("Mac App Store Maintenance"); fi
  if $os_update_check; then SELECTED_PHASES+=("macOS Update Check"); fi
  if $diagnostics; then SELECTED_PHASES+=("Diagnostics"); fi
}

run_phase() {
  local phase="$1"
  shift
  local start end duration status=0 bar skipped_before=$TASK_SKIP
  CURRENT_PHASE="$phase"

  PHASE_INDEX=$((PHASE_INDEX + 1))
  TASK_TOTAL=$((TASK_TOTAL + 1))
  bar=$(progress_bar "$((PHASE_INDEX - 1))" "${#SELECTED_PHASES[@]}")
  start=$(date +%s)

  log_info "progress=$bar phase=$phase state=starting"

  "$@" || status=$?

  end=$(date +%s)
  duration=$((end - start))

  if ((TASK_SKIP > skipped_before)); then
    log_warn "phase=$phase state=SKIPPED duration_seconds=$duration"
  elif ((status == 0)) && $DRY_RUN; then
    TASK_PLANNED=$((TASK_PLANNED + 1))
    log_info "phase=$phase state=PLANNED actions_executed=0"
  elif ((status == 0)); then
    TASK_OK=$((TASK_OK + 1))
    log_info "phase=$phase state=SUCCESS duration_seconds=$duration"
  else
    TASK_FAIL=$((TASK_FAIL + 1))
    log_error "phase=$phase state=FAILED duration_seconds=$duration exit_status=$status"
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

  log_info "summary requested=$TASK_TOTAL completed_successfully=$TASK_OK planned=$TASK_PLANNED health_warnings=$HEALTH_WARNINGS incomplete=$incomplete failed=$TASK_FAIL skipped=$TASK_SKIP errors={$errors_joined}"

  if ((TASK_FAIL > 0 || ${RUN_RESULT:-0} != 0)); then
    log_error "Maintenance ended with incomplete phases. Review red flags above."
    return 1
  fi

  if ((TASK_SKIP > 0)); then
    log_warn "Maintenance finished without failed phases, but some optional/unavailable actions were skipped."
    return 0
  fi

  if $DRY_RUN; then log_info "Maintenance preview finished; no maintenance commands applied."
  elif ((HEALTH_WARNINGS > 0)); then log_warn "Maintenance actions completed; health warnings require review."
  else log_info "Maintenance completed successfully."; fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick)
      PRESET=quick
      ;;
    --comprehensive)
      PRESET=comprehensive
      ;;
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
    --no-brew-autoremove)
      brew_autoremove=false
      brew_update=true
      mark_task
      ;;
    --no-brew-greedy)
      brew_greedy=false
      brew_update=true
      mark_task
      ;;
    --brew-autoremove)
      brew_autoremove=true
      brew_update=true
      mark_task
      ;;
    --brew-greedy)
      brew_greedy=true
      brew_update=true
      mark_task
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
      ;;
    --verbose)
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

# Homebrew and all user data tasks must retain the real user's identity.
if ((EUID == 0)); then
  log_error "Run maintain as your normal user, without sudo. System updates request sudo separately."
  exit 1
fi
case "$LOG_LEVEL" in error|warn|info|debug) ;; *) log_error "Invalid LOG_LEVEL"; exit 64 ;; esac
is_positive_int "$LOG_RETENTION_DAYS" || { log_error "Invalid LOG_RETENTION_DAYS"; exit 64; }
is_positive_int "$BACKUP_MIN_FREE_GB" || { log_error "Invalid BACKUP_MIN_FREE_GB"; exit 64; }
apply_standard_plan_if_needed
build_selected_phases
ensure_macos_or_preview

umask 077
LOGDIR="$(maintenance_home)/Library/Logs/maintain"
if ! mkdir -p "$LOGDIR" || ! chmod 700 "$LOGDIR"; then
  log_error "Cannot create private log directory: $LOGDIR"
  exit 1
fi
LOGFILE=$(mktemp "$LOGDIR/maintain-$(date '+%Y%m%dT%H%M%S')-XXXXXX")
mv "$LOGFILE" "$LOGFILE.log"
LOGFILE="$LOGFILE.log"
exec 9>>"$LOGFILE"
RUN_TMP=$(mktemp -d)

finish() {
  local result=$? pending
  RUN_RESULT=$result
  trap - EXIT
  if ((result != 0)); then
    log_error "Run stopped during phase=$CURRENT_PHASE exit_status=$result"
    for pending in "$RUN_TMP"/command.*; do
      if [[ -f "$pending" ]]; then log_command_output warn interrupted-command "$pending"; fi
    done
    if ((TASK_TOTAL > TASK_OK + TASK_PLANNED + TASK_FAIL + TASK_SKIP)); then
      TASK_FAIL=$((TASK_FAIL + 1))
      record_error "$CURRENT_PHASE: interrupted exit_status=$result"
    fi
    TASK_SKIP=$((TASK_SKIP + ${#SELECTED_PHASES[@]} - TASK_TOTAL))
    TASK_TOTAL=${#SELECTED_PHASES[@]}
  fi
  CURRENT_PHASE=summary
  print_final_summary || { if ((result == 0)); then result=1; fi; }
  log_info "run_exit_status=$result duration_seconds=$((SECONDS - RUN_START)) log=$LOGFILE"
  /bin/rm -rf "$RUN_TMP"
  exit "$result"
}
trap finish EXIT
trap 'log_error "Run interrupted by SIGINT"; exit 130' INT
trap 'log_error "Run interrupted by SIGTERM"; exit 143' TERM

log_info "Starting macOS maintenance version $SCRIPT_VERSION (dry-run=$DRY_RUN, user=$(invoking_user)). Log: $LOGFILE"
$DRY_RUN && log_info "Plan mode: preview only. Omit --dry-run to perform maintenance."

if $backup; then
  run_phase "System Backup" run_backup
  if ((TASK_FAIL > 0)); then
    TASK_SKIP=$((${#SELECTED_PHASES[@]} - 1))
    TASK_TOTAL=${#SELECTED_PHASES[@]}
    log_error "Backup failed; remaining $TASK_SKIP phases SKIPPED."
    exit 1
  fi
fi
if $cleanup || $cleanup_downloads; then run_phase "Cleanup" run_cleanup; fi
if $brew_update; then run_phase "Homebrew Maintenance" run_brew_updates; fi
if $mas_update; then run_phase "Mac App Store Maintenance" run_mas_updates; fi
if $os_update_check; then run_phase "macOS Update Check" run_os_updates; fi
if $diagnostics; then run_phase "Diagnostics" run_diagnostics; fi

if ((TASK_FAIL > 0)); then exit 1; fi
exit 0
