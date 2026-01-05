#!/usr/bin/env bash
#
# macos_maintenance.sh
#
# Purpose: Safe, conservative macOS maintenance helper intended for scheduled
# or on-demand use. Focuses on light-weight cleanup, health checks, and
# optional software updates without destructive data loss.
#
# Scope:
# - User-level cache/log cleanup in well-defined locations
# - Optional Homebrew and App Store updates
# - Optional macOS software update check (apply only when requested)
# - Basic diagnostics for disk usage and Time Machine status
#
# Safety principles:
# - Never delete user documents or application data directories
# - Never touch system-protected paths (/System, /Library, /usr)
# - Avoid blanket deletion of /private/var/folders or cross-home removes
# - All opt-in destructive actions support --dry-run and are off by default
#
# Supported macOS versions: macOS 12 Monterey and later
# Privileges: Some operations (softwareupdate) require sudo/admin rights
# Example:
#   ./macos_maintenance.sh --cleanup --brew --dry-run
#   ./macos_maintenance.sh --cleanup --apply-os-updates
#   ./macos_maintenance.sh --diagnostics
#
# Change history:
#   2024-06-05: Initial safe rewrite with flag-driven tasks and dry-run support
#
set -euo pipefail
IFS=$'\n\t'

###############################################################################
# Logging helpers
###############################################################################

LOG_LEVEL=${LOG_LEVEL:-info}
DRY_RUN=false
VERBOSE=false

log_msg() {
    local level="$1"; shift
    local message="$*"
    local levels=(error warn info debug)
    local current_index=0
    local level_index=-1

    for idx in "${!levels[@]}"; do
        [[ ${levels[$idx]} == "$LOG_LEVEL" ]] && current_index=$idx
        [[ ${levels[$idx]} == "$level" ]] && level_index=$idx
    done

    if (( level_index <= current_index )); then
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        printf '%s [%5s] %s\n' "$timestamp" "$level" "$message" >&2
    fi
}

log_debug() { log_msg debug "$@"; }
log_info() { log_msg info "$@"; }
log_warn() { log_msg warn "$@"; }
log_error() { log_msg error "$@"; }

run_cmd() {
    local description="$1"; shift
    if $DRY_RUN; then
        log_info "(dry-run) $description"
        return 0
    fi
    log_info "$description"
    "$@"
}

###############################################################################
# Utility helpers
###############################################################################

ensure_macos() {
    if [[ $(uname -s) != "Darwin" ]]; then
        log_error "This script is intended for macOS only."
        exit 1
    fi
}

check_binary() {
    local bin="$1"
    command -v "$bin" >/dev/null 2>&1
}

###############################################################################
# Cleanup routines (safe by default)
###############################################################################

protected_cache_patterns=(
    "${HOME}/Library/Caches/*Firefox*"
    "${HOME}/Library/Caches/*Mozilla*"
    "${HOME}/Library/Caches/*Obsidian*"
    "${HOME}/Library/Caches/*GitHub*"
    "${HOME}/Library/Caches/restic"
)

should_skip_path() {
    local target="$1"
    for pattern in "${protected_cache_patterns[@]}"; do
        if [[ "$target" == $pattern ]]; then
            return 0
        fi
    done
    return 1
}

cleanup_user_caches() {
    local cache_root="$HOME/Library/Caches"
    [[ -d "$cache_root" ]] || { log_info "Cache root $cache_root not found; skipping."; return 0; }

    log_info "Cleaning user caches (preserving browser/Obsidian/GitHub auth caches)."
    local removed=0
    while IFS= read -r -d '' item; do
        if should_skip_path "$item"; then
            log_debug "Skipping protected cache: $item"
            continue
        fi
        run_cmd "Removing cache item: $item" rm -rf "$item"
        ((removed++)) || true
    done < <(find "$cache_root" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
    log_info "Cache cleanup complete (processed $removed entries)."
}

cleanup_logs() {
    local log_root="$HOME/Library/Logs"
    [[ -d "$log_root" ]] || { log_info "No user logs to prune."; return 0; }
    run_cmd "Deleting user logs older than 30 days under $log_root" \
        find "$log_root" -type f -mtime +30 -print -delete
}

cleanup_tmpdir() {
    local tmp_root="${TMPDIR:-/tmp}"
    [[ -d "$tmp_root" ]] || { log_info "TMPDIR $tmp_root not found; skipping."; return 0; }
    run_cmd "Cleaning temporary files in $tmp_root" find "$tmp_root" -mindepth 1 -maxdepth 2 -type f -mtime +7 -print -delete
}

cleanup_downloads=false
cleanup_downloads_days=30
cleanup=false
diagnostics=false
diagnostics_shutdown_cause=false
cleanup_downloads_run() {
    local downloads_dir="$HOME/Downloads"
    [[ -d "$downloads_dir" ]] || { log_info "Downloads directory not found; skipping."; return 0; }
    run_cmd "Removing files older than ${cleanup_downloads_days}d in $downloads_dir" \
        find "$downloads_dir" -type f -mtime +"$cleanup_downloads_days" -print -delete
}

###############################################################################
# Update routines
###############################################################################

brew_update=false
mas_update=false
os_update_check=false
os_update_apply=false

run_brew_updates() {
    if ! check_binary brew; then
        log_warn "Homebrew not installed; skipping brew updates."
        return 0
    fi
    run_cmd "Updating Homebrew metadata" brew update
    run_cmd "Upgrading installed Homebrew packages" brew upgrade
    run_cmd "Cleaning old Homebrew artifacts" brew cleanup
}

run_mas_updates() {
    if ! check_binary mas; then
        log_warn "mas CLI not installed; skipping App Store updates."
        return 0
    fi
    run_cmd "Checking Mac App Store updates" mas upgrade
}

run_os_updates() {
    local args=(--list)
    if $os_update_apply; then
        args=(--install --all)
    fi
    if $DRY_RUN; then
        log_info "(dry-run) softwareupdate ${args[*]}"
        return 0
    fi
    if $os_update_apply; then
        if [[ $EUID -ne 0 ]]; then
            log_warn "softwareupdate install requires sudo; attempting with sudo."
        fi
        run_cmd "Running softwareupdate ${args[*]}" sudo softwareupdate "${args[@]}"
        return 0
    fi
    run_cmd "Running softwareupdate ${args[*]}" softwareupdate "${args[@]}"
}

###############################################################################
# Diagnostics
###############################################################################

run_diagnostics() {
    log_info "Disk usage snapshot:"
    df -h / || true

    if check_binary tmutil; then
        log_info "Time Machine status:"
        tmutil status || true
    fi

    if $diagnostics_shutdown_cause; then
        log_info "Recent system events (last 20 shutdown causes):"
        /usr/bin/log show --predicate 'eventMessage CONTAINS "Previous shutdown cause"' --last 1d --info --debug | tail -n 20 || true
    fi
}

###############################################################################
# Usage
###############################################################################

print_help() {
    cat <<'USAGE'
macos_maintenance.sh - safe macOS maintenance

Usage: macos_maintenance.sh [options]

Options:
  --quick                   Run weekly maintenance (default when no args)
  --comprehensive           Run full maintenance (includes shutdown-cause logs)
  --cleanup                 Run safe cache/log/tmp cleanup
  --cleanup-downloads DAYS  Remove files older than DAYS in ~/Downloads (off by default)
  --brew                    Run Homebrew update/upgrade/cleanup
  --mas                     Run Mac App Store updates (mas upgrade)
  --check-os-updates        Check available macOS updates
  --apply-os-updates        Apply macOS updates (uses sudo; implies check)
  --diagnostics             Print diagnostic info (disk, Time Machine)
  --dry-run                 Show actions without making changes
  --verbose                 Enable verbose logging
  --help                    Show this help text

Default behavior: --quick (weekly maintenance).
If both --quick and --comprehensive are supplied, the last one wins.
USAGE
}

###############################################################################
# Argument parsing
###############################################################################

set_quick_defaults() {
    cleanup=true
    brew_update=true
    mas_update=true
    os_update_check=true
    diagnostics=true
    diagnostics_shutdown_cause=false
}

set_comprehensive_defaults() {
    cleanup=true
    brew_update=true
    mas_update=true
    os_update_check=true
    diagnostics=true
    diagnostics_shutdown_cause=true
}

if [[ $# -eq 0 ]]; then
    set_quick_defaults
fi

is_positive_int() {
    [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --quick)
            set_quick_defaults
            ;;
        --comprehensive)
            set_comprehensive_defaults
            ;;
        --cleanup)
            cleanup=true
            ;;
        --cleanup-downloads)
            if [[ $# -lt 2 ]]; then
                log_error "--cleanup-downloads requires a DAYS argument"
                exit 1
            fi
            cleanup_downloads=true
            cleanup_downloads_days="$2"
            if ! is_positive_int "$cleanup_downloads_days"; then
                log_error "DAYS must be a positive integer"
                exit 1
            fi
            shift 2
            continue
            ;;
        --brew)
            brew_update=true
            ;;
        --mas)
            mas_update=true
            ;;
        --check-os-updates)
            os_update_check=true
            ;;
        --apply-os-updates)
            os_update_check=true
            os_update_apply=true
            ;;
        --diagnostics)
            diagnostics=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --verbose)
            VERBOSE=true
            LOG_LEVEL=debug
            ;;
        --help|-h)
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

###############################################################################
# Main
###############################################################################

ensure_macos

log_info "Starting macOS maintenance (dry-run=$DRY_RUN, verbose=$VERBOSE)."

cleanup=${cleanup:-false}
diagnostics=${diagnostics:-false}

if ${cleanup}; then
    cleanup_user_caches
    cleanup_logs
    cleanup_tmpdir
    if ${cleanup_downloads}; then
        cleanup_downloads_run
    fi
fi

if ${brew_update}; then
    run_brew_updates
fi

if ${mas_update}; then
    run_mas_updates
fi

if ${os_update_check}; then
    run_os_updates
fi

if ${diagnostics}; then
    run_diagnostics
fi

log_info "Maintenance completed."
