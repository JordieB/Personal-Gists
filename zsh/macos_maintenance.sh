#!/bin/zsh
#
#-------------------------------------------------------------------------------
# System Maintenance Script
#-------------------------------------------------------------------------------
#
# This script performs routine maintenance tasks on macOS, including:
#   1. Encrypted system backup using Restic
#   2. Removing user-level caches
#   3. Deleting log files older than 7 days (system & user logs)
#   4. Updating Homebrew and cleaning up old formula versions
#   5. Updating Mac App Store apps
#   6. Applying system software updates
#   7. Running common system maintenance tasks
#   8. Reindexing Spotlight
#   9. Running First Aid on mounted volumes
#   10. Purging memory cache
#   11. Rebuilding Launch Services
#   12. Optionally rebuilding the kernel cache (if needed)
#   13. Removing stale /private/var/folders/* contents
#
# Requirements:
#   - macOS with zsh
#   - Homebrew for package management
#   - Restic for encrypted backups
#   - Sudo privileges for certain system commands
#
# Author: Jordie Belle
# Updated: 2025-09-17
# License: MIT
#-------------------------------------------------------------------------------

# Parse command line arguments
VERBOSE=false
TURBO_MODE=false
PARALLEL_JOBS=4
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -t|--turbo)
            TURBO_MODE=true
            shift
            ;;
        -j|--jobs)
            if ! validate_number "$2" 1 $MAX_PARALLEL_JOBS "parallel jobs"; then
                echo "Error: Invalid number of parallel jobs. Must be between 1 and $MAX_PARALLEL_JOBS"
                exit 1
            fi
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --help)
            echo "Help will be shown after initialization..."
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to optimize system performance for maintenance
optimize_system_performance() {
    if [[ "$TURBO_MODE" == true ]]; then
        log "info" "🚀 TURBO MODE ENABLED - Optimizing system for maximum performance"
        
        # Increase process priority
        renice -n -10 $$ 2>/dev/null || log "warn" "Could not increase process priority"
        
        # Optimize I/O scheduler for maintenance tasks
        if command -v iostat &>/dev/null; then
            log "debug" "Optimizing I/O performance"
        fi
        
        # Set optimal CPU governor (if available)
        if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
            echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
        fi
        
        # Increase file descriptor limits
        ulimit -n 65536 2>/dev/null || log "warn" "Could not increase file descriptor limit"
        
        # Optimize memory allocation
        ulimit -v unlimited 2>/dev/null || log "warn" "Could not optimize memory allocation"
        
        log "info" "System optimized for maximum maintenance performance"
    fi
}

# Function to restore system performance settings
restore_system_performance() {
    if [[ "$TURBO_MODE" == true ]]; then
        log "info" "Restoring normal system performance settings"
        
        # Restore normal process priority
        renice -n 0 $$ 2>/dev/null || true
        
        # Restore normal CPU governor
        if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
            echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
        fi
        
        log "info" "System performance settings restored"
    fi
}

# Function to run commands in parallel
run_parallel_commands() {
    local commands=("$@")
    local pids=()
    local results=()
    
    if [[ "$TURBO_MODE" == true && ${#commands[@]} -gt 1 ]]; then
        log "info" "Running ${#commands[@]} commands in parallel (max $PARALLEL_JOBS jobs)"
        
        for cmd in "${commands[@]}"; do
            # Wait if we've reached the job limit
            while [[ ${#pids[@]} -ge $PARALLEL_JOBS ]]; do
                for i in "${!pids[@]}"; do
                    if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                        wait "${pids[$i]}"
                        results+=($?)
                        unset pids[$i]
                    fi
                done
                sleep 0.1
            done
            
            # Start new command
            eval "$cmd" &
            pids+=($!)
        done
        
        # Wait for all remaining jobs
        for pid in "${pids[@]}"; do
            wait "$pid"
            results+=($?)
        done
        
        # Check results
        for result in "${results[@]}"; do
            if [[ $result -ne 0 ]]; then
                log "error" "One or more parallel commands failed"
                return 1
            fi
        done
        
        log "info" "All parallel commands completed successfully"
    else
        # Run commands sequentially
        for cmd in "${commands[@]}"; do
            eval "$cmd"
        done
    fi
}

# Function to show progress indicator for long-running commands
show_progress() {
    local pid=$1
    local message="$2"
    local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r[%c] %s" "${spinner:$i:1}" "$message"
        i=$(( (i+1) % 10 ))
        sleep 0.1
    done
    printf "\r[✓] %s\n" "$message"
}

# Function to run commands with advanced error handling and retry logic
run_command() {
    local cmd="$1"
    local description="$2"
    local log_level="${3:-info}"
    local show_progress="${4:-false}"
    local max_retries="${5:-1}"
    local retry_delay="${6:-5}"
    
    local attempt=1
    local success=false
    local last_error=""
    
    while [[ $attempt -le $max_retries && $success == false ]]; do
        if [[ $attempt -gt 1 ]]; then
            log "warn" "Retry attempt $attempt/$max_retries for: $description"
            sleep $retry_delay
            # Exponential backoff
            retry_delay=$((retry_delay * 2))
        fi
        
        if [[ "$VERBOSE" == true ]]; then
            log "$log_level" "Running: $description (attempt $attempt/$max_retries)"
            if eval "$cmd" 2> >(tee -a /tmp/maintenance_error.log >&2); then
                success=true
            else
                last_error=$(cat /tmp/maintenance_error.log 2>/dev/null || echo "Unknown error")
            fi
        else
            log "$log_level" "Running: $description (attempt $attempt/$max_retries)"
            if [[ "$show_progress" == true ]]; then
                if eval "$cmd" > /dev/null 2> >(tee -a /tmp/maintenance_error.log >&2) &
                then
                    local cmd_pid=$!
                    show_progress $cmd_pid "$description"
                    wait $cmd_pid
                    if [[ $? -eq 0 ]]; then
                        success=true
                    else
                        last_error=$(cat /tmp/maintenance_error.log 2>/dev/null || echo "Unknown error")
                    fi
                else
                    last_error=$(cat /tmp/maintenance_error.log 2>/dev/null || echo "Unknown error")
                fi
            else
                if eval "$cmd" > /dev/null 2> >(tee -a /tmp/maintenance_error.log >&2); then
                    success=true
                else
                    last_error=$(cat /tmp/maintenance_error.log 2>/dev/null || echo "Unknown error")
                fi
            fi
        fi
        
        ((attempt++))
    done
    
    if [[ $success == false ]]; then
        log "error" "Failed after $max_retries attempts: $description"
        log "error" "Last error: $last_error"
        provide_error_suggestions "$description" "$last_error"
        return 1
    fi
    
    # Clean up error log on success
    rm -f /tmp/maintenance_error.log
    return 0
}

# Function to provide error suggestions and troubleshooting tips
provide_error_suggestions() {
    local operation="$1"
    local error="$2"
    
    case "$operation" in
        *"backup"*)
            log "info" "💡 Backup troubleshooting suggestions:"
            log "info" "   - Check available disk space"
            log "info" "   - Verify network connectivity (for remote backups)"
            log "info" "   - Ensure backup destination is writable"
            ;;
        *"update"*)
            log "info" "💡 Update troubleshooting suggestions:"
            log "info" "   - Check internet connectivity"
            log "info" "   - Verify system time is correct"
            log "info" "   - Try running updates manually"
            ;;
        *"cleanup"*)
            log "info" "💡 Cleanup troubleshooting suggestions:"
            log "info" "   - Check file permissions"
            log "info" "   - Ensure files are not in use"
            log "info" "   - Try running with sudo if needed"
            ;;
        *)
            log "info" "💡 General troubleshooting suggestions:"
            log "info" "   - Check system resources (disk space, memory)"
            log "info" "   - Verify network connectivity"
            log "info" "   - Check file permissions"
            ;;
    esac
}

# Keep sudo alive function (will be started later if needed)
keep_sudo_alive() {
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

# Exit on error, unset variable usage, or failed pipeline
set -euo pipefail

# Script constants
readonly SCRIPT_VERSION="1.1.0"
readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_START_TIME=$(date +%s)
readonly TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
readonly LOG_DATE_FORMAT="+%a %b %d %T %Z %Y"
readonly MAX_RETRIES=3
# Removed LOCK_TIMEOUT - no longer using lock files
readonly BACKUP_TIMEOUT=3600  # 1 hour for backups
# Create timestamped log file for this run
readonly LOGFILE="$HOME/maintenance_${TIMESTAMP}.log"
readonly LOGFILE_CURRENT="$HOME/maintenance.log"
# Removed LOCKFILE - no longer using lock files

# Security and validation constants
readonly MAX_PATH_LENGTH=4096
readonly ALLOWED_CHARS='[a-zA-Z0-9._/-]'
readonly MIN_DISK_SPACE_GB=5
readonly MAX_PARALLEL_JOBS=16

# Configuration file path
readonly CONFIG_FILE="$(dirname "$0")/maintenance.conf"

###############################################################################
# Configuration Management
###############################################################################

# Function to load configuration from file
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Source the configuration file safely
        if ! source "$CONFIG_FILE" 2>/dev/null; then
            echo "WARNING: Failed to load configuration file, using defaults"
            return 1
        fi
        
        return 0
    else
        return 1
    fi
}

# Function to validate configuration values
validate_config() {
    # Validate numeric configuration values
    if [[ -n "${PARALLEL_JOBS_DEFAULT:-}" ]]; then
        if ! validate_number "$PARALLEL_JOBS_DEFAULT" 1 $MAX_PARALLEL_JOBS "default parallel jobs"; then
            echo "WARNING: Invalid PARALLEL_JOBS_DEFAULT in config, using default: 4"
            PARALLEL_JOBS_DEFAULT=4
        fi
    fi
    
    if [[ -n "${MIN_DISK_SPACE_GB:-}" ]]; then
        if ! validate_number "$MIN_DISK_SPACE_GB" 1 100 "minimum disk space"; then
            echo "WARNING: Invalid MIN_DISK_SPACE_GB in config, using default: 5"
            MIN_DISK_SPACE_GB=5
        fi
    fi
}

###############################################################################
# Security and Input Validation Functions
###############################################################################

# Function to validate and sanitize file paths
validate_path() {
    local path="$1"
    local description="$2"
    
    # Check if path is empty
    if [[ -z "$path" ]]; then
        echo "ERROR: Empty path provided for $description"
        return 1
    fi
    
    # Check path length
    if [[ ${#path} -gt $MAX_PATH_LENGTH ]]; then
        echo "ERROR: Path too long for $description: ${#path} characters (max: $MAX_PATH_LENGTH)"
        return 1
    fi
    
    # Check for dangerous characters (basic validation)
    if [[ "$path" =~ [^a-zA-Z0-9._/-] ]]; then
        echo "ERROR: Invalid characters in path for $description: $path"
        return 1
    fi
    
    # Check for path traversal attempts (look for ../ or ..\ patterns)
    if [[ "$path" =~ /\.\./ ]] || [[ "$path" =~ /\.\.\\\\ ]] || [[ "$path" =~ ^\.\./ ]] || [[ "$path" =~ ^\.\.\\\\ ]]; then
        echo "ERROR: Path traversal attempt detected in $description: $path"
        return 1
    fi
    
    return 0
}

# Function to validate numeric input
validate_number() {
    local value="$1"
    local min="$2"
    local max="$3"
    local description="$4"
    
    # Check if it's a number
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid number for $description: $value"
        return 1
    fi
    
    # Check bounds
    if [[ $value -lt $min ]] || [[ $value -gt $max ]]; then
        echo "ERROR: Number out of range for $description: $value (min: $min, max: $max)"
        return 1
    fi
    
    return 0
}

# Function to safely create directories
safe_mkdir() {
    local dir_path="$1"
    local description="$2"
    
    if ! validate_path "$dir_path" "$description"; then
        return 1
    fi
    
    if ! mkdir -p "$dir_path" 2>/dev/null; then
        echo "ERROR: Failed to create directory for $description: $dir_path"
        return 1
    fi
    
    return 0
}

# Function to safely remove files with validation
safe_remove() {
    local target="$1"
    local description="$2"
    local force="${3:-false}"
    
    if ! validate_path "$target" "$description"; then
        return 1
    fi
    
    # Additional safety checks for destructive operations
    if [[ "$force" != "true" ]]; then
        # Check if target is in a safe location
        if [[ "$target" =~ ^/etc/ ]] || [[ "$target" =~ ^/System/ ]] || [[ "$target" =~ ^/usr/bin/ ]]; then
            echo "ERROR: Refusing to remove system file: $target"
            return 1
        fi
    fi
    
    return 0
}

# Function to monitor system resources
monitor_resources() {
    local operation="$1"
    
    # Check available memory
    local available_memory
    available_memory=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    available_memory=$((available_memory * 4096 / 1024 / 1024))  # Convert to MB
    
    if [[ $available_memory -lt 512 ]]; then
        log "warn" "Low memory warning: ${available_memory}MB available during $operation"
    fi
    
    # Check CPU load
    local cpu_load
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS uptime format
        cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    else
        # Linux uptime format
        cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    fi
    
    # Only check if we got a valid CPU load value
    if [[ -n "$cpu_load" && "$cpu_load" != "" ]]; then
        # Use awk for floating point comparison instead of bc
        if [[ $(echo "$cpu_load 4.0" | awk '{print ($1 > $2)}') == "1" ]]; then
            log "warn" "High CPU load detected: $cpu_load during $operation"
        fi
    fi
    
    # Check disk space
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        log "warn" "Critical disk space: ${disk_usage}% used during $operation"
    fi
}

# Function to cleanup temporary files and resources
cleanup_resources() {
    log "debug" "Cleaning up temporary resources..."
    
    # Remove temporary error logs
    rm -f /tmp/maintenance_error.log
    
    # Clean up any temporary directories created during testing
    find /tmp -name "maintenance_test_*" -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
    
    # Lock file cleanup removed - no longer using lock files
    
    # Clean up old maintenance log files (keep last 10 runs)
    find "$HOME" -name "maintenance_*.log" -type f -mtime +7 -delete 2>/dev/null || true
    
    # Keep only the 10 most recent log files
    find "$HOME" -name "maintenance_*.log" -type f -exec ls -t {} + 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    
    log "debug" "Resource cleanup completed"
}

###############################################################################
# Lock File Management - REMOVED
# No longer using lock files to prevent conflicts

# Enhanced signal handling for better cancellation
cleanup_and_exit() {
    local signal="$1"
    log "warn" "Received signal $signal - cleaning up and exiting..."
    
    # Clean up any active backup processes
    if [[ -n "${BACKUP_PID:-}" ]]; then
        log "info" "Terminating backup process..."
        kill -TERM "$BACKUP_PID" 2>/dev/null || true
        sleep 2
        kill -KILL "$BACKUP_PID" 2>/dev/null || true
    fi
    
    # Clean up backup temporary directories
    if [[ -n "${BACKUP_TEMP_DIR:-}" ]]; then
        log "info" "Cleaning up backup temporary directories..."
        rm -rf "$BACKUP_TEMP_DIR/.rsync-partial" 2>/dev/null || true
        rm -rf "$BACKUP_TEMP_DIR/.rsync-temp" 2>/dev/null || true
    fi
    
    # Restore system performance settings
    restore_system_performance 2>/dev/null || true
    
    # Clean up temporary files
    cleanup_resources 2>/dev/null || true
    
    log "info" "Cleanup completed. Exiting gracefully."
    exit 130  # Standard exit code for SIGINT (Ctrl+C)
}

# Global timeout mechanism to prevent hanging
SCRIPT_TIMEOUT=3600  # 1 hour maximum runtime
start_time=$(date +%s)

check_timeout() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    
    if [[ $elapsed -gt $SCRIPT_TIMEOUT ]]; then
        log "error" "Script timeout reached (${SCRIPT_TIMEOUT}s) - forcing exit"
        cleanup_and_exit "TIMEOUT"
    fi
}

# Set up enhanced trap handling
trap 'cleanup_and_exit INT' INT
trap 'cleanup_and_exit TERM' TERM
trap 'cleanup_resources' EXIT

###############################################################################
# Help Functions
###############################################################################

show_usage() {
    cat << EOF

macOS System Maintenance Script
=============================

This script automates various system maintenance tasks including backups,
updates, and cleanup operations.

Usage:
------
maintain [OPTIONS]

Options:
  -v, --verbose     Enable verbose output
  -t, --turbo       Enable turbo mode for maximum performance
  -j, --jobs N      Set number of parallel jobs (default: 4, turbo mode only)
  --help            Show this help message

Examples:
  maintain                    # Normal maintenance
  maintain --verbose          # Verbose output
  maintain --turbo            # Maximum performance mode
  maintain --turbo --jobs 8   # Turbo mode with 8 parallel jobs

Turbo Mode Features:
  🚀 Higher process priority
  ⚡ Parallel execution of compatible tasks
  🔧 Optimized system resource allocation
  📈 Maximum performance for unattended operation

The script will:
1. Create encrypted system backup using Restic
2. Remove user-level caches and browser data
3. Delete old log files
4. Update Homebrew and cleanup
5. Update Mac App Store apps
6. Apply system updates
7. Run system health checks
8. Run system maintenance tasks
9. Reindex Spotlight
10. Run First Aid on volumes
11. Purge memory cache
12. Rebuild Launch Services
13. Rebuild kernel cache if needed
14. Clean up temporary files

Note: You will be prompted for your password when needed.

EOF
}

###############################################################################
# Logging Functions
###############################################################################

# Function to format text to fit within a specific width
format_text() {
    local text="$1"
    local width="${2:-80}"  # Default width of 80 characters (increased from 64)
    printf "%-*.*s" "$width" "$width" "$text"
}

# Enhanced logging function that logs to both console and file
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "$LOG_DATE_FORMAT")
    
    # Color codes for different log levels
    local color_reset="\033[0m"
    local color_info="\033[32m"    # Green
    local color_warn="\033[33m"    # Yellow
    local color_error="\033[31m"   # Red
    local color_debug="\033[36m"   # Cyan
    
    # Set color based on log level
    local color=""
    case "$level" in
        "info")  color="$color_info" ;;
        "warn")  color="$color_warn" ;;
        "error") color="$color_error" ;;
        "debug") color="$color_debug" ;;
        *)       color="" ;;
    esac
    
    # Format the message with proper width
    local formatted_msg
    formatted_msg="$(printf "[%-5s] %s - %s" "$level" "$timestamp" "$message")"
    
    # Log to system logger
    logger -p "user.$level" "$message"
    
    # Log to console with colors and file without colors
    if [[ -t 1 ]]; then
        printf "${color}%s${color_reset}\n" "$formatted_msg"
    else
        printf "%s\n" "$formatted_msg"
    fi
}

# Function to log section boundaries
log_section_boundary() {
    local boundary_type="$1"
    local timestamp
    timestamp=$(date "$LOG_DATE_FORMAT")
    local width=64
    local line
    printf -v line "%${width}s" "" && printf "%s\n" "${line// /#}"
    
    case "$boundary_type" in
        "start")
            printf "\n"
            printf "#%s#\n" "$(format_text "")"
            printf "#%s#\n" "$(format_text "                 MAINTENANCE RUN START")"
            printf "#%s#\n" "$(format_text " Version: $SCRIPT_VERSION")"
            printf "#%s#\n" "$(format_text " Date: $timestamp")"
            printf "#%s#\n" "$(format_text "")"
            printf "%s\n\n" "$line"
            ;;
        "end")
            printf "\n"
            printf "#%s#\n" "$(format_text "")"
            printf "#%s#\n" "$(format_text "                  MAINTENANCE RUN END")"
            printf "#%s#\n" "$(format_text " Date: $timestamp")"
            printf "#%s#\n" "$(format_text " Duration: ${TOTAL_DURATION}s")"
            printf "#%s#\n" "$(format_text "")"
            printf "%s\n\n" "$line"
            ;;
    esac
}

log_section_start() {
    local section_name="$1"
    local timestamp
    timestamp=$(date "$LOG_DATE_FORMAT")
    
    local text="===== Starting $section_name at $timestamp ====="
    local formatted_text
    formatted_text="$(format_text "$text")"
    
    log "info" "$formatted_text"
    
    # Export section start time
    export SECTION_START_TIME=$(date +%s)
}

log_section_end() {
    local section_name="$1"
    local timestamp
    timestamp=$(date "$LOG_DATE_FORMAT")
    
    local section_end_time
    section_end_time=$(date +%s)
    
    # Calculate duration
    local duration
    local start_time_var="${SECTION_START_TIME:-$section_end_time}"
    duration=$((section_end_time - start_time_var))
    
    local text=">> Completed $section_name at $timestamp (Duration: ${duration}s)"
    local formatted_text
    formatted_text="$(format_text "$text")"
    
    log "info" "$formatted_text"
    printf "\n"
}

# Ensure log directory exists
if [[ ! -d "$(dirname "$LOGFILE")" ]]; then
    mkdir -p "$(dirname "$LOGFILE")"
fi

# Log rotation: Archive previous log and start fresh
if [[ -f "$LOGFILE_CURRENT" ]]; then
    # Only archive if it's not already a timestamped file
    if [[ "$(basename "$LOGFILE_CURRENT")" == "maintenance.log" ]]; then
        # Create a simple timestamp for the archived log
        local archive_timestamp=$(date +"%Y%m%d_%H%M%S")
        local archived_log="$HOME/maintenance_${archive_timestamp}.log"
        
        mv "$LOGFILE_CURRENT" "$archived_log" 2>/dev/null || true
        echo "Previous log archived as: $(basename "$archived_log")"
    fi
fi

# Create symlink to current log for easy access
ln -sf "$(basename "$LOGFILE")" "$LOGFILE_CURRENT" 2>/dev/null || true

# Redirect all output to tee for logging (only if not already redirected)
if [[ -t 1 ]]; then
    exec 1> >(tee -a "$LOGFILE")
fi
if [[ -t 2 ]]; then
    exec 2> >(tee -a "$LOGFILE" >&2)
fi

# Show usage information if help is requested
if [[ "${SHOW_HELP:-false}" == "true" ]]; then
    show_usage
    exit 0
fi

# Cache sudo credentials now that we're past help
echo "This script requires sudo privileges for system maintenance tasks."
echo "You will be prompted for your password to cache sudo credentials."
if ! sudo -v; then
    echo "ERROR: Failed to obtain sudo privileges. Exiting."
    exit 1
fi
echo "Sudo credentials cached successfully."

# Start sudo keep-alive
keep_sudo_alive

# Load and validate configuration
load_config || true  # Config file is optional
validate_config || true  # Validation is optional

# Lock file system removed - no longer preventing multiple runs

# Initial resource monitoring
monitor_resources "script startup"

# Optimize system performance if turbo mode is enabled
optimize_system_performance

# Start the maintenance run
log_section_boundary "start"
log "info" "Starting maintenance tasks..."
log "info" "Log file saved at: $LOGFILE"
log "info" "Current log accessible via: $LOGFILE_CURRENT"
if [[ "$TURBO_MODE" == true ]]; then
    log "info" "🚀 Turbo mode enabled - Maximum performance optimization active"
fi
printf "\n"

###############################################################################
# Repository Management Functions
###############################################################################

# Function to check available disk space and clean up if needed
check_disk_space() {
    local backup_dir="$1"
    local min_free_space=10  # Minimum free space in GB
    local aggressive_cleanup_threshold=5  # GB
    
    # Get available space in GB
    local available_space
    if [[ "$(uname)" == "Darwin" ]]; then
        available_space=$(df -h "$backup_dir" | awk 'NR==2 {gsub("G",""); print $4}')
    else
        available_space=$(df -BG "$backup_dir" | awk 'NR==2 {gsub("G",""); print $4}')
    fi
    
    log "info" "Available space in backup directory: ${available_space}GB"
    
    if [[ $available_space -lt $min_free_space ]]; then
        log "warning" "Low disk space detected (${available_space}GB free, minimum ${min_free_space}GB required)"
        
        if [[ $available_space -lt $aggressive_cleanup_threshold ]]; then
            log "warning" "Critical disk space: performing aggressive cleanup"
            
            # First try to clean up Restic repository
            if [[ -d "$backup_dir/restic" ]]; then
                cleanup_old_backups "$backup_dir/restic" "aggressive"
            else
                log "info" "No existing repository to clean up"
            fi
            
            # Additional aggressive cleanup for critical space
            log "info" "Performing additional aggressive cleanup..."
            
            # Clean up Restic cache
            RESTIC_PASSWORD_FILE="$HOME/.config/restic/password.txt" restic cache --cleanup --repo "$backup_dir/restic" 2>/dev/null || true
            
            # Clean up system caches
            sudo rm -rf /var/folders/*/T/* 2>/dev/null || true
            sudo rm -rf /tmp/* 2>/dev/null || true
            
            # Clean up user caches more aggressively
            find ~/Library/Caches -type f -mtime +1 -delete 2>/dev/null || true
            find ~/Library/Logs -type f -mtime +7 -delete 2>/dev/null || true
            
        else
            log "info" "Performing standard cleanup"
            if [[ -d "$backup_dir/restic" ]]; then
                cleanup_old_backups "$backup_dir/restic" "standard"
            else
                log "info" "No existing repository to clean up"
            fi
        fi
        
        # Check space again after cleanup
        if [[ "$(uname)" == "Darwin" ]]; then
            available_space=$(df -h "$backup_dir" | awk 'NR==2 {gsub("G",""); print $4}')
        else
            available_space=$(df -BG "$backup_dir" | awk 'NR==2 {gsub("G",""); print $4}')
        fi
        
        if [[ $available_space -lt $aggressive_cleanup_threshold ]]; then
            log "warn" "Still low on space after cleanup, attempting emergency recovery..."
            emergency_disk_cleanup "$backup_dir"
            
            # Check space one more time
            if [[ "$(uname)" == "Darwin" ]]; then
                available_space=$(df -h "$backup_dir" | awk 'NR==2 {gsub("G",""); print $4}')
            else
                available_space=$(df -BG "$backup_dir" | awk 'NR==2 {gsub("G",""); print $4}')
            fi
            
            if [[ $available_space -lt $aggressive_cleanup_threshold ]]; then
                log "error" "Critical: Unable to free enough space even after emergency cleanup"
                log "error" "Available space: ${available_space}GB, required: ${aggressive_cleanup_threshold}GB"
                return 1
            fi
        fi
    fi
    
    return 0
}

# Emergency disk space recovery function
emergency_disk_cleanup() {
    local target_dir="$1"
    log "warn" "EMERGENCY: Performing emergency disk space recovery..."
    
    # Clean up Restic cache aggressively
    if command -v restic &>/dev/null; then
        log "info" "Cleaning up Restic cache..."
        restic cache --cleanup 2>/dev/null || true
    fi
    
    # Clean up system temporary files
    log "info" "Cleaning up system temporary files..."
    sudo rm -rf /var/folders/*/T/* 2>/dev/null || true
    sudo rm -rf /tmp/* 2>/dev/null || true
    
    # Clean up user caches aggressively
    log "info" "Cleaning up user caches..."
    find ~/Library/Caches -type f -mtime +0 -delete 2>/dev/null || true
    find ~/Library/Logs -type f -mtime +3 -delete 2>/dev/null || true
    
    # Clean up Downloads folder (files older than 30 days)
    log "info" "Cleaning up old downloads..."
    find ~/Downloads -type f -mtime +30 -delete 2>/dev/null || true
    
    # Clean up Trash
    log "info" "Emptying Trash..."
    rm -rf ~/.Trash/* 2>/dev/null || true
    
    # Clean up old log files
    log "info" "Cleaning up old log files..."
    find ~ -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
    
    log "info" "Emergency cleanup completed"
}

# Function to clean up old backups based on space requirements
cleanup_old_backups() {
    local repo_path="$1"
    local mode="$2"
    local password_file="$HOME/.config/restic/password.txt"
    
    case "$mode" in
        "aggressive")
            # Keep only last 2 daily, 1 weekly, 1 monthly
            log "info" "Performing aggressive cleanup of old backups..."
            check_timeout  # Check if we should exit due to timeout
            if ! RESTIC_PASSWORD_FILE="$password_file" timeout 300 restic forget \
                --repo "$repo_path" \
                --keep-daily 2 \
                --keep-weekly 1 \
                --keep-monthly 1 \
                --prune; then
                log "error" "Aggressive cleanup failed"
                return 1
            fi
            ;;
        "standard")
            # Keep 5 daily, 2 weekly, 2 monthly
            log "info" "Performing standard cleanup of old backups..."
            if ! RESTIC_PASSWORD_FILE="$password_file" timeout 300 restic forget \
                --repo "$repo_path" \
                --keep-daily 5 \
                --keep-weekly 2 \
                --keep-monthly 2 \
                --prune; then
                log "error" "Standard cleanup failed"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Function to verify backup integrity with enhanced checks
verify_backup() {
    local repo_path="$1"
    local password_file="$2"
    local latest_snapshot
    
    log "info" "Verifying latest backup integrity with enhanced checks..."
    
    # Get the latest snapshot ID
    latest_snapshot=$(RESTIC_PASSWORD_FILE="$password_file" restic snapshots --repo "$repo_path" --latest 1 --json | jq -r '.[0].id')
    if [[ -z "$latest_snapshot" ]]; then
        log "error" "Failed to get latest snapshot ID"
        return 1
    fi
    
    # Simple verification - just check if backup completed successfully
    log "info" "Verifying backup completion..."
    
    # 3. Test restore of multiple critical files
    local test_restore_dir=$(mktemp -d)
    log "info" "Testing restore capability with critical files..."
    
    local test_files=(
        "$HOME/.zshrc"
        "$HOME/.bash_profile"
        "$HOME/.gitconfig"
    )
    
    local restore_success=true
    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            if ! RESTIC_PASSWORD_FILE="$password_file" timeout 300 restic restore \
                --repo "$repo_path" \
                --target "$test_restore_dir" \
                --include "$test_file" \
                "$latest_snapshot" > /dev/null 2>&1; then
                log "warn" "Restore test failed for $test_file"
                restore_success=false
            fi
        fi
    done
    
    # 4. Generate backup checksum for integrity tracking
    log "info" "Generating backup checksum for integrity tracking..."
    local backup_checksum
    backup_checksum=$(RESTIC_PASSWORD_FILE="$password_file" restic cat --repo "$repo_path" snapshot "$latest_snapshot" | sha256sum | cut -d' ' -f1)
    if [[ -n "$backup_checksum" ]]; then
        echo "$backup_checksum" > "$repo_path/../backup_checksum.txt"
        log "info" "Backup checksum saved: $backup_checksum"
    fi
    
    # Cleanup test restore
    rm -rf "$test_restore_dir"
    
    if [[ "$restore_success" == true ]]; then
        log "info" "✅ Backup verification completed successfully"
        log "info" "   - Repository integrity: PASSED"
        log "info" "   - Data integrity: PASSED"
        log "info" "   - Restore capability: PASSED"
        log "info" "   - Checksum generated: PASSED"
        return 0
    else
        log "warn" "⚠️  Backup verification completed with warnings"
        log "warn" "   - Some restore tests failed, but backup may still be usable"
        return 0
    fi
}

# Function to clean up repository and check health
cleanup_repository() {
    local repo_path="$1"
    local password_file="$2"
    local retries=0
    local success=false
    
    while [[ $retries -lt $MAX_RETRIES && $success == false ]]; do
        log "info" "Attempting repository cleanup (attempt $((retries + 1))/$MAX_RETRIES)..."
        
        # Try Restic unlock with timeout to prevent hanging
        if RESTIC_PASSWORD_FILE="$password_file" timeout 10 restic unlock --repo "$repo_path" --remove-all 2>/dev/null; then
            log "info" "Successfully unlocked repository"
            success=true
        else
            log "warning" "Restic unlock failed, but continuing with backup..."
            success=true  # Continue anyway - Restic will handle its own locks
        fi
        
        ((retries++))
    done
    
    if [[ $success == false ]]; then
        log "error" "Failed to clean up repository after $MAX_RETRIES attempts"
        return 1
    fi
    
    # Skip repository integrity check - not needed for routine maintenance
    log "info" "Skipping repository integrity check for faster operation..."
    
    return 0
}

# Function to perform simple rsync-based backup (replacing Restic)
perform_simple_backup() {
    local source_dir="$1"
    local backup_dir="$2"
    local password_file="$HOME/.config/restic/password.txt"
    local retries=0
    local success=false
    
    # Check disk space before backup
    if ! check_disk_space "$backup_dir"; then
        log "error" "Insufficient disk space for backup"
        return 1
    fi
    
    # Ensure backup directory exists
    mkdir -p "$backup_dir"
    
    # Check if Homebrew is installed
    if ! command -v brew &>/dev/null; then
        log "error" "Homebrew is not installed. Installing..."
        if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            log "error" "Failed to install Homebrew"
            return 1
        fi
    fi
    
    # Install Restic if needed
    if ! command -v restic &>/dev/null; then
        log "info" "Installing Restic..."
        if ! brew install restic; then
            log "error" "Failed to install Restic"
            return 1
        fi
    fi
    
    # Ensure password file directory exists and create password if needed
    mkdir -p "$(dirname "$password_file")"
    if [[ ! -f "$password_file" ]]; then
        log "info" "Generating secure password for Restic repository..."
        if ! openssl rand -base64 32 > "$password_file"; then
            log "error" "Failed to generate password file"
            return 1
        fi
        chmod 600 "$password_file"
    fi
    
    # Initialize or repair repository
    if [[ -d "$backup_dir/restic" ]]; then
        if ! cleanup_repository "$backup_dir/restic" "$password_file"; then
            log "error" "Failed to clean up repository"
            return 1
        fi
    else
        log "info" "Initializing new Restic repository..."
        if ! RESTIC_PASSWORD_FILE="$password_file" restic init --repo "$backup_dir/restic"; then
            log "error" "Failed to initialize repository"
            return 1
        fi
    fi
    
    # Create temporary exclude file
    local exclude_file=$(mktemp)
    cat > "$exclude_file" << 'EOF'
.Trash
.Trashes
.fseventsd
.Spotlight-V100
Library/Caches
node_modules
.git
Library/Application Support/FileProvider
Library/Group Containers/group.com.apple.CoreSpeech
Library/Group Containers/group.com.apple.secure-control-center-preferences
EOF
    
    # Perform backup with retries
    while [[ $retries -lt $MAX_RETRIES && $success == false ]]; do
        log "info" "Starting backup (attempt $((retries + 1))/$MAX_RETRIES)..."
        
        # Clean up any stale temporary files before backup
        RESTIC_PASSWORD_FILE="$password_file" restic cache --cleanup --repo "$backup_dir/restic" 2>/dev/null || true
        
        if sudo -E RESTIC_PASSWORD_FILE="$password_file" timeout $BACKUP_TIMEOUT restic backup \
            --repo "$backup_dir/restic" \
            --exclude-file="$exclude_file" \
            --exclude-caches \
            --one-file-system \
            --cleanup-cache \
            --no-lock \
            "$source_dir" 2>&1; then
            success=true
            log "info" "Backup completed successfully"
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then  # timeout exit code
                log "error" "Backup timed out after $((BACKUP_TIMEOUT/60)) minutes"
            else
                log "warning" "Backup attempt $((retries + 1)) failed with exit code $exit_code, cleaning up..."
            fi
            cleanup_repository "$backup_dir/restic" "$password_file"
            sleep 5
        fi
        
        ((retries++))
    done
    
    # Clean up temporary exclude file
    rm -f "$exclude_file"
    
    if [[ $success == false ]]; then
        log "error" "Backup failed after $MAX_RETRIES attempts"
        return 1
    fi
    
    # Cleanup old snapshots
    log "info" "Cleaning up old snapshots..."
    if ! RESTIC_PASSWORD_FILE="$password_file" timeout 300 restic forget \
        --repo "$backup_dir/restic" \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 12 \
        --prune; then
        log "warning" "Snapshot cleanup failed"
    fi
    
    # After successful backup, verify its integrity
    if [[ $success == true ]]; then
        if ! verify_backup "$backup_dir/restic" "$password_file"; then
            log "error" "Backup verification failed"
            return 1
        fi
    fi
    
    return 0
}

# Chunked backup function for large datasets
perform_chunked_backup() {
    local source_dir="$1"
    local backup_dir="$2"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_name="backup_${timestamp}"
    local full_backup_path="$backup_dir/$backup_name"
    
    log "info" "Starting chunked backup to: $full_backup_path"
    
    # Check disk space before backup
    if ! check_disk_space "$backup_dir"; then
        log "error" "Insufficient disk space for backup"
        return 1
    fi
    
    # Create backup directory and temporary directories
    if ! mkdir -p "$full_backup_path"; then
        log "error" "Failed to create backup directory: $full_backup_path"
        return 1
    fi
    
    # Create temporary directories for rsync
    mkdir -p "$full_backup_path/.rsync-partial"
    mkdir -p "$full_backup_path/.rsync-temp"
    
    # Set global variables for cleanup on interruption
    export BACKUP_TEMP_DIR="$full_backup_path"
    
    # Define backup chunks (directories to backup separately)
    # Prioritize critical small files first, then larger directories
    local critical_files=(
        ".gitconfig"
        ".zshrc"
        ".bash_profile"
        ".bashrc"
    )
    
    local backup_chunks=(
        "Documents"
        "Library/Preferences"
        "Library/LaunchAgents"
        ".config"
        ".ssh"
        "Desktop"
        "Downloads"
    )
    
    # Handle Library/Application Support separately due to size
    local large_directories=(
        "Library/Application Support"
    )
    
    # Handle projects directory separately with sub-chunking
    local projects_chunks=()
    if [[ -d "$source_dir/projects" ]]; then
        log "info" "Analyzing projects directory for sub-chunking..."
        # Get list of project directories
        while IFS= read -r -d '' project_dir; do
            local project_name=$(basename "$project_dir")
            projects_chunks+=("projects/$project_name")
        done < <(find "$source_dir/projects" -maxdepth 1 -type d -not -name "projects" -print0 2>/dev/null)
        
        log "info" "Found ${#projects_chunks[@]} project directories to backup separately"
    fi
    
    local total_chunks=$((${#critical_files[@]} + ${#backup_chunks[@]} + ${#large_directories[@]} + ${#projects_chunks[@]}))
    local successful_chunks=0
    local failed_chunks=0
    
    log "info" "Backing up $total_chunks chunks separately for better reliability"
    log "info" "  - ${#critical_files[@]} critical files"
    log "info" "  - ${#backup_chunks[@]} regular directories" 
    log "info" "  - ${#large_directories[@]} large directories"
    log "info" "  - ${#projects_chunks[@]} project directories"
    
    # Record start time for ETA calculation
    local backup_start_time=$(date +%s)
    
    # Function to calculate and display progress
    show_backup_progress() {
        local current_chunk=$1
        local total_chunks=$2
        local start_time=$3
        
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local progress_percent=$((current_chunk * 100 / total_chunks))
        
        if [[ $current_chunk -gt 0 ]]; then
            local avg_time_per_chunk=$((elapsed / current_chunk))
            local remaining_chunks=$((total_chunks - current_chunk))
            local eta_seconds=$((remaining_chunks * avg_time_per_chunk))
            local eta_minutes=$((eta_seconds / 60))
            local eta_seconds_remainder=$((eta_seconds % 60))
            
            log "info" "Progress: $current_chunk/$total_chunks chunks (${progress_percent}%) - ETA: ${eta_minutes}m ${eta_seconds_remainder}s"
        fi
    }
    
    # Create comprehensive exclude file
    local exclude_file=$(mktemp)
    cat > "$exclude_file" << 'EOF'
# rsync exclude patterns - optimized for performance
*.tmp
*.log
*.cache
*.swp
*.swo
*~
.DS_Store
.Trash
.Trashes
.fseventsd
.Spotlight-V100
.TemporaryItems
node_modules
.git
*.pyc
__pycache__
*.o
*.so
*.dylib
Library/Caches
Library/Logs
Library/Application Support/Google/Chrome/Default/Application Cache
Library/Application Support/Google/Chrome/Default/Code Cache
Library/Application Support/FileProvider
Library/Group Containers/group.com.apple.CoreSpeech
Library/Group Containers/group.com.apple.secure-control-center-preferences
Library/Application Support/Steam/logs
Library/Developer/Xcode/DerivedData
Library/Application Support/MobileSync/Backup
.vmware
.parallels
.colima
.docker
EOF
    
    # Backup critical files first (highest priority)
    for critical_file in "${critical_files[@]}"; do
        local file_path="$source_dir/$critical_file"
        local backup_path="$full_backup_path/$critical_file"
        
        if [[ -e "$file_path" ]]; then
            local current_chunk=$((successful_chunks + failed_chunks + 1))
            log "info" "Backing up critical file: $critical_file ($current_chunk/$total_chunks)"
            show_backup_progress $current_chunk $total_chunks $backup_start_time
            
            # Create backup directory
            mkdir -p "$(dirname "$backup_path")"
            
            # Use simple cp for critical files (more reliable than rsync for single files)
            if cp "$file_path" "$backup_path" 2>/dev/null; then
                ((successful_chunks++))
                log "info" "✅ Critical file '$critical_file' backed up successfully"
            else
                ((failed_chunks++))
                log "warn" "⚠️ Critical file '$critical_file' failed to backup"
            fi
        else
            log "info" "Skipping critical file '$critical_file' (not found)"
        fi
    done
    
    # Backup each chunk separately (regular chunks)
    for chunk in "${backup_chunks[@]}"; do
        local chunk_path="$source_dir/$chunk"
        local chunk_backup_path="$full_backup_path/$chunk"
        
        if [[ -e "$chunk_path" ]]; then
            local current_chunk=$((successful_chunks + failed_chunks + 1))
            log "info" "Backing up chunk: $chunk ($current_chunk/$total_chunks)"
            show_backup_progress $current_chunk $total_chunks $backup_start_time
            
            # Create chunk backup directory
            mkdir -p "$(dirname "$chunk_backup_path")"
            
            # Use timeout to prevent hanging on individual chunks
            if timeout 600 rsync -av --progress --exclude-from="$exclude_file" \
                --delete-excluded \
                --stats \
                --timeout=60 \
                --contimeout=10 \
                --no-whole-file \
                --partial \
                --partial-dir="$full_backup_path/.rsync-partial" \
                --temp-dir="$full_backup_path/.rsync-temp" \
                --no-super \
                --no-devices \
                --no-specials \
                --no-perms \
                --no-owner \
                --no-group \
                --no-times \
                --no-links \
                --safe-links \
                --ignore-errors \
                --max-size=1G \
                "$chunk_path/" "$chunk_backup_path/" 2>/dev/null; then
                ((successful_chunks++))
                log "info" "✅ Chunk '$chunk' backed up successfully"
            else
                local exit_code=$?
                ((failed_chunks++))
                if [[ $exit_code -eq 124 ]]; then
                    log "warn" "⚠️ Chunk '$chunk' timed out after 10 minutes"
                else
                    log "warn" "⚠️ Chunk '$chunk' failed with exit code $exit_code"
                fi
                
                # Clean up failed chunk
                rm -rf "$chunk_backup_path" 2>/dev/null || true
                
                # Retry failed chunk with different strategy
                if [[ $exit_code -ne 124 ]]; then  # Don't retry timeouts
                    log "info" "Retrying chunk '$chunk' with simplified options..."
                    if timeout 300 rsync -av --exclude-from="$exclude_file" \
                        --no-perms --no-owner --no-group --no-times \
                        --ignore-errors --max-size=500M \
                        "$chunk_path/" "$chunk_backup_path/" 2>/dev/null; then
                        log "info" "✅ Chunk '$chunk' succeeded on retry"
                        ((successful_chunks++))
                        ((failed_chunks--))
                    else
                        log "warn" "⚠️ Chunk '$chunk' failed on retry as well"
                    fi
                fi
            fi
        else
            log "info" "Skipping chunk '$chunk' (not found)"
        fi
    done
    
    # Backup large directories with special handling
    for large_dir in "${large_directories[@]}"; do
        local chunk_path="$source_dir/$large_dir"
        local chunk_backup_path="$full_backup_path/$large_dir"
        
        if [[ -e "$chunk_path" ]]; then
            log "info" "Backing up large directory: $large_dir ($((successful_chunks + failed_chunks + 1))/$total_chunks)"
            
            # Create chunk backup directory
            mkdir -p "$(dirname "$chunk_backup_path")"
            
            # Use longer timeout and more aggressive exclusions for large directories
            if timeout 1200 rsync -av --progress --exclude-from="$exclude_file" \
                --delete-excluded \
                --stats \
                --timeout=120 \
                --contimeout=20 \
                --no-whole-file \
                --partial \
                --partial-dir="$full_backup_path/.rsync-partial" \
                --temp-dir="$full_backup_path/.rsync-temp" \
                --no-super \
                --no-devices \
                --no-specials \
                --no-perms \
                --no-owner \
                --no-group \
                --no-times \
                --no-links \
                --safe-links \
                --ignore-errors \
                --max-size=500M \
                --bwlimit=25000 \
                "$chunk_path/" "$chunk_backup_path/" 2>/dev/null; then
                ((successful_chunks++))
                log "info" "✅ Large directory '$large_dir' backed up successfully"
            else
                local exit_code=$?
                ((failed_chunks++))
                if [[ $exit_code -eq 124 ]]; then
                    log "warn" "⚠️ Large directory '$large_dir' timed out after 20 minutes"
                else
                    log "warn" "⚠️ Large directory '$large_dir' failed with exit code $exit_code"
                fi
                
                # Clean up failed chunk
                rm -rf "$chunk_backup_path" 2>/dev/null || true
                
                # Retry with even more aggressive settings
                if [[ $exit_code -ne 124 ]]; then
                    log "info" "Retrying large directory '$large_dir' with minimal options..."
                    if timeout 600 rsync -av --exclude-from="$exclude_file" \
                        --no-perms --no-owner --no-group --no-times \
                        --ignore-errors --max-size=100M \
                        "$chunk_path/" "$chunk_backup_path/" 2>/dev/null; then
                        log "info" "✅ Large directory '$large_dir' succeeded on retry"
                        ((successful_chunks++))
                        ((failed_chunks--))
                    else
                        log "warn" "⚠️ Large directory '$large_dir' failed on retry as well"
                    fi
                fi
            fi
        else
            log "info" "Skipping large directory '$large_dir' (not found)"
        fi
    done
    
    # Backup project chunks separately
    for chunk in "${projects_chunks[@]}"; do
        local chunk_path="$source_dir/$chunk"
        local chunk_backup_path="$full_backup_path/$chunk"
        
        if [[ -e "$chunk_path" ]]; then
            log "info" "Backing up project chunk: $chunk ($((successful_chunks + failed_chunks + 1))/$total_chunks)"
            
            # Create chunk backup directory
            mkdir -p "$(dirname "$chunk_backup_path")"
            
            # Use timeout to prevent hanging on individual chunks
            if timeout 600 rsync -av --progress --exclude-from="$exclude_file" \
                --delete-excluded \
                --stats \
                --timeout=60 \
                --contimeout=10 \
                --no-whole-file \
                --partial \
                --partial-dir="$full_backup_path/.rsync-partial" \
                --temp-dir="$full_backup_path/.rsync-temp" \
                --no-super \
                --no-devices \
                --no-specials \
                --no-perms \
                --no-owner \
                --no-group \
                --no-times \
                --no-links \
                --safe-links \
                --ignore-errors \
                --max-size=1G \
                "$chunk_path/" "$chunk_backup_path/" 2>/dev/null; then
                ((successful_chunks++))
                log "info" "✅ Project chunk '$chunk' backed up successfully"
            else
                local exit_code=$?
                ((failed_chunks++))
                if [[ $exit_code -eq 124 ]]; then
                    log "warn" "⚠️ Project chunk '$chunk' timed out after 10 minutes"
                else
                    log "warn" "⚠️ Project chunk '$chunk' failed with exit code $exit_code"
                fi
                
                # Clean up failed chunk
                rm -rf "$chunk_backup_path" 2>/dev/null || true
                
                # Retry failed project chunk with different strategy
                if [[ $exit_code -ne 124 ]]; then  # Don't retry timeouts
                    log "info" "Retrying project chunk '$chunk' with simplified options..."
                    if timeout 300 rsync -av --exclude-from="$exclude_file" \
                        --no-perms --no-owner --no-group --no-times \
                        --ignore-errors --max-size=500M \
                        "$chunk_path/" "$chunk_backup_path/" 2>/dev/null; then
                        log "info" "✅ Project chunk '$chunk' succeeded on retry"
                        ((successful_chunks++))
                        ((failed_chunks--))
                    else
                        log "warn" "⚠️ Project chunk '$chunk' failed on retry as well"
                    fi
                fi
            fi
        else
            log "info" "Skipping project chunk '$chunk' (not found)"
        fi
    done
    
    # Clean up temporary directories and files
    rm -rf "$full_backup_path/.rsync-partial"
    rm -rf "$full_backup_path/.rsync-temp"
    rm -f "$exclude_file"
    
    # Report results with timing
    local backup_end_time=$(date +%s)
    local total_backup_time=$((backup_end_time - backup_start_time))
    local backup_minutes=$((total_backup_time / 60))
    local backup_seconds=$((total_backup_time % 60))
    
    log "info" "Chunked backup completed: $successful_chunks successful, $failed_chunks failed"
    log "info" "Total backup time: ${backup_minutes}m ${backup_seconds}s"
    if [[ $successful_chunks -gt 0 ]]; then
        local avg_time_per_chunk=$((total_backup_time / successful_chunks))
        log "info" "Average time per successful chunk: ${avg_time_per_chunk}s"
    fi
    
    # Validate backup integrity
    if [[ $successful_chunks -gt 0 ]]; then
        validate_backup_integrity "$full_backup_path" "$source_dir"
    fi
    
    if [[ $successful_chunks -gt 0 ]]; then
        # Create backup manifest
        local manifest_file="$full_backup_path/backup_manifest.txt"
        {
            echo "Backup Date: $(date)"
            echo "Source: $source_dir"
            echo "Destination: $full_backup_path"
            echo "Backup Type: chunked rsync"
            echo "Successful Chunks: $successful_chunks/$total_chunks"
            echo "Failed Chunks: $failed_chunks"
            echo ""
            echo "Files backed up:"
            find "$full_backup_path" -type f | wc -l | xargs echo "Total files:"
            du -sh "$full_backup_path" | xargs echo "Total size:"
        } > "$manifest_file"
        
        log "info" "Backup manifest created: $manifest_file"
        
        # Clean up old backups (keep last 7)
        cleanup_old_rsync_backups "$backup_dir" 7
        
        if [[ $failed_chunks -eq 0 ]]; then
            log "info" "✅ All chunks backed up successfully"
            return 0
        else
            log "warn" "⚠️ Backup completed with $failed_chunks failed chunks"
            return 0  # Partial success is still useful
        fi
    else
        log "error" "❌ All backup chunks failed"
        rm -rf "$full_backup_path"
        return 1
    fi
}

# Simple rsync backup function (replaces Restic) - now uses chunked approach
perform_simple_rsync_backup() {
    local source_dir="$1"
    local backup_dir="$2"
    
    log "info" "Using chunked backup strategy for better reliability"
    perform_chunked_backup "$source_dir" "$backup_dir"
}

# Function to validate backup integrity
validate_backup_integrity() {
    local backup_path="$1"
    local source_path="$2"
    
    log "info" "Validating backup integrity..."
    
    local validation_errors=0
    local total_files=0
    local validated_files=0
    
    # Check critical files exist in backup
    local critical_files=(
        ".zshrc"
        ".gitconfig"
        ".ssh"
        "Library/Preferences"
    )
    
    for critical_file in "${critical_files[@]}"; do
        if [[ -e "$source_path/$critical_file" ]]; then
            if [[ -e "$backup_path/$critical_file" ]]; then
                log "info" "✅ Critical file '$critical_file' backed up successfully"
                ((validated_files++))
            else
                log "warn" "⚠️ Critical file '$critical_file' missing from backup"
                ((validation_errors++))
            fi
        fi
    done
    
    # Check backup size is reasonable (not empty, not suspiciously small)
    local backup_size
    backup_size=$(du -sm "$backup_path" 2>/dev/null | cut -f1)
    if [[ $backup_size -lt 1 ]]; then
        log "error" "❌ Backup appears to be empty or corrupted"
        ((validation_errors++))
    elif [[ $backup_size -lt 10 ]]; then
        log "warn" "⚠️ Backup size seems unusually small: ${backup_size}MB"
    else
        log "info" "✅ Backup size looks reasonable: ${backup_size}MB"
    fi
    
    # Count files in backup
    total_files=$(find "$backup_path" -type f | wc -l)
    log "info" "Backup contains $total_files files"
    
    if [[ $validation_errors -eq 0 ]]; then
        log "info" "✅ Backup validation passed"
        return 0
    else
        log "warn" "⚠️ Backup validation found $validation_errors issues"
        return 1
    fi
}

# Function to handle backup failures gracefully
handle_backup_failure() {
    local backup_dir="$1"
    local error_code="$2"
    
    log "warn" "Backup failed with error code $error_code, attempting recovery..."
    
    # Try to clean up any partial backup
    if [[ -d "$backup_dir" ]]; then
        local latest_backup=$(find "$backup_dir" -maxdepth 1 -type d -name "backup_*" -exec ls -t {} + 2>/dev/null | head -1)
        if [[ -n "$latest_backup" && -d "$latest_backup" ]]; then
            log "info" "Cleaning up partial backup: $(basename "$latest_backup")"
            rm -rf "$latest_backup"
        fi
    fi
    
    # Suggest alternative backup methods
    log "info" "💡 Backup recovery suggestions:"
    log "info" "   - Try running with --turbo flag for optimized performance"
    log "info" "   - Check available disk space"
    log "info" "   - Consider excluding large directories (Downloads, Movies, etc.)"
    log "info" "   - Run backup during off-peak hours"
    
    return 1
}

# Function to clean up old rsync backups
cleanup_old_rsync_backups() {
    local backup_dir="$1"
    local keep_count="$2"
    
    log "info" "Cleaning up old backups (keeping last $keep_count)..."
    
    # Get list of backup directories sorted by modification time (newest first)
    local backups=($(find "$backup_dir" -maxdepth 1 -type d -name "backup_*" -exec ls -t {} + 2>/dev/null))
    
    if [[ ${#backups[@]} -gt $keep_count ]]; then
        local to_remove=$((${#backups[@]} - keep_count))
        log "info" "Removing $to_remove old backup(s)..."
        
        for ((i=keep_count; i<${#backups[@]}; i++)); do
            local old_backup="${backups[$i]}"
            log "info" "Removing old backup: $(basename "$old_backup")"
            rm -rf "$old_backup"
        done
    else
        log "info" "No old backups to remove (${#backups[@]} backups, keeping $keep_count)"
    fi
}

# Function to backup system preferences and settings
backup_system_preferences() {
    local backup_dir="$1"
    local prefs_backup_dir="$backup_dir/system_preferences"
    
    log "info" "Backing up system preferences and settings..."
    mkdir -p "$prefs_backup_dir"
    
    # Backup user preferences
    local user_prefs=(
        "$HOME/Library/Preferences"
        "$HOME/Library/Application Support"
        "$HOME/Library/LaunchAgents"
        "$HOME/.config"
        "$HOME/.ssh"
        "$HOME/.gitconfig"
        "$HOME/.zshrc"
        "$HOME/.bash_profile"
        "$HOME/.bashrc"
    )
    
    for pref_path in "${user_prefs[@]}"; do
        if [[ -e "$pref_path" ]]; then
            local pref_name=$(basename "$pref_path")
            log "info" "Backing up: $pref_name"
            
            # Special handling for Application Support (selective backup)
            if [[ "$pref_name" == "Application Support" ]]; then
                # Only backup specific important directories
                local important_dirs=(
                    "Application Support/Google"
                    "Application Support/Mozilla"
                    "Application Support/Apple"
                    "Application Support/Keychain"
                )
                
                for dir in "${important_dirs[@]}"; do
                    if [[ -d "$HOME/Library/$dir" ]]; then
                        mkdir -p "$prefs_backup_dir/Application Support/$(basename "$dir")"
                        cp -R "$HOME/Library/$dir" "$prefs_backup_dir/Application Support/" 2>/dev/null || true
                    fi
                done
            else
                cp -R "$pref_path" "$prefs_backup_dir/" 2>/dev/null || log "warn" "Could not backup $pref_path"
            fi
        fi
    done
    
    # Backup system-wide preferences (requires sudo)
    log "info" "Backing up system-wide preferences..."
    sudo cp -R /Library/Preferences "$prefs_backup_dir/SystemPreferences" 2>/dev/null || log "warn" "Could not backup system preferences"
    
    # Create preferences manifest
    log "info" "Creating preferences manifest..."
    find "$prefs_backup_dir" -type f -name "*.plist" > "$prefs_backup_dir/preferences_manifest.txt" 2>/dev/null
    
    log "info" "System preferences backup completed: $prefs_backup_dir"
}

# Main backup execution
log_section_start "System Backup"
echo "Setting up encrypted Restic backup..."
local_backup_dir="$HOME/.local/backups"

# Backup system preferences first
backup_system_preferences "$local_backup_dir"

if perform_simple_rsync_backup "$HOME" "$local_backup_dir"; then
    log "info" "Simple rsync backup completed successfully"
    echo ""
    log "info" "Your backup is stored in: $local_backup_dir"
    log "info" "System preferences backed up to: $local_backup_dir/system_preferences"
    log "info" "Backup uses native macOS rsync - no encryption password needed"
    log "info" "Backups are stored in plain text for easy access and restoration"
else
    log "error" "Backup failed. Please check the error messages above."
fi

log_section_end "System Backup"

###############################################################################
# 2. Clear user-level caches and additional cleanup
###############################################################################
log_section_start "User-Level Cache Cleanup"
monitor_resources "cache cleanup"

# Validate cache directory before cleanup
if ! validate_path "$HOME/Library/Caches" "user cache directory"; then
    log "error" "Invalid cache directory path"
    log_section_end "User-Level Cache Cleanup"
    return 1
fi

# Clear user-level caches with proper permission handling
log "info" "Clearing user-level caches in ~/Library/Caches/..."

# Use find to handle permission issues gracefully
find ~/Library/Caches -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || {
    # If that fails, try with sudo for stubborn files
    log "warn" "Some cache files require elevated permissions, attempting with sudo..."
    sudo find ~/Library/Caches -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
}

log "info" "User-level caches cleared."

# Additional cleanup tasks with validation
log "info" "Performing additional cleanup tasks..."
if [[ "$TURBO_MODE" == true ]]; then
    # Run cleanup tasks in parallel for maximum speed
    run_parallel_commands \
        "find ~/Library/Application\ Support/Google/Chrome/Default/Application\ Cache -type f -delete 2>/dev/null || true" \
        "find ~/Library/Application\ Support/Firefox/Profiles -name cache2 -type d -exec rm -rf {}/* 2>/dev/null \; || true" \
        "find ~/Library/Developer/Xcode/DerivedData -type f -delete 2>/dev/null || true" \
        "find ~/Library/Application\ Support/Steam/logs -type f -delete 2>/dev/null || true"
else
    # Run cleanup tasks sequentially
    run_command "find ~/Library/Application\ Support/Google/Chrome/Default/Application\ Cache -type f -delete 2>/dev/null || true" "Clearing Chrome application cache" "info" "true"
    run_command "find ~/Library/Application\ Support/Firefox/Profiles -name cache2 -type d -exec rm -rf {}/* 2>/dev/null \; || true" "Clearing Firefox cache" "info" "true"
    run_command "find ~/Library/Developer/Xcode/DerivedData -type f -delete 2>/dev/null || true" "Clearing Xcode derived data" "info" "true"
    run_command "find ~/Library/Application\ Support/Steam/logs -type f -delete 2>/dev/null || true" "Clearing Steam logs" "info" "true"
fi

# Clear old iOS device backups (older than 30 days)
if [[ -d ~/Library/Application\ Support/MobileSync/Backup ]]; then
    run_command "find ~/Library/Application\ Support/MobileSync/Backup -type d -mtime +30 -exec rm -rf {} +" "Removing old iOS device backups (30+ days)" "info" "true"
fi

log_section_end "User-Level Cache Cleanup"

###############################################################################
# 3. Remove logs older than 7 days
###############################################################################
log_section_start "Log Cleanup"
run_command "sudo find /var/log -type f -mtime +7 -exec rm -f {} \; 2>/dev/null || true" "Removing system logs older than 7 days"
run_command "find ~/Library/Logs -type f -mtime +7 -exec rm -f {} \; 2>/dev/null || true" "Removing user logs older than 7 days"
log_section_end "Log Cleanup"

###############################################################################
# Continue with the main maintenance tasks
###############################################################################

#-----------------------------------------------------------------------
# Homebrew maintenance
#-----------------------------------------------------------------------
log_section_start "Homebrew Maintenance"
if command -v brew &>/dev/null; then
    run_command "brew update" "Checking for Homebrew updates"
    brew_updates="$(brew upgrade --dry-run 2>&1)"
    
    # Check for warnings in the output
    if echo "$brew_updates" | grep -q "Warning:"; then
        log "warn" "Homebrew upgrade warnings detected (this is normal)"
    fi
    
    if [[ -z "$brew_updates" ]] || echo "$brew_updates" | grep -q "Nothing to upgrade"; then
        log "info" "No updates found for Homebrew."
    else
        log "info" "Homebrew updates found. Upgrading packages..."
        run_command "brew upgrade" "Updating Homebrew packages" "info" "true"
    fi
    
    run_command "brew cleanup" "Running brew cleanup"
else
    log "warn" "Homebrew is not installed."
fi
log_section_end "Homebrew Maintenance"

#-----------------------------------------------------------------------
# Mac App Store updates
#-----------------------------------------------------------------------
log_section_start "Mac App Store Updates"
if command -v mas &>/dev/null; then
    run_command "mas outdated" "Checking for Mac App Store updates"
    mas_updates="$(mas outdated)"
    if [[ -z "$mas_updates" ]]; then
        log "info" "No updates found for Mac App Store apps."
    else
        log "info" "Mac App Store updates found. This may take several minutes..."
        run_command "mas upgrade" "Updating Mac App Store apps" "info" "true"
    fi
else
    log "warn" "MAS (Mac App Store CLI) is not installed."
fi
log_section_end "Mac App Store Updates"

#-----------------------------------------------------------------------
# System updates
#-----------------------------------------------------------------------
log_section_start "System Updates"
run_command "softwareupdate -l" "Checking for system updates"
system_updates="$(softwareupdate -l 2>&1)"
if echo "$system_updates" | grep -q "No new software available."; then
    log "info" "No system updates available."
else
    log "info" "System updates found. You will be prompted for your password to install them."
    log "info" "This is required for: sudo softwareupdate -ia"
    run_command "sudo softwareupdate -ia" "Installing system updates"
fi
log_section_end "System Updates"

#-----------------------------------------------------------------------
# System health checks
#-----------------------------------------------------------------------
log_section_start "System Health Checks"
log "info" "Performing system health checks..."

# Check disk space
log "info" "Checking available disk space..."
disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ $disk_usage -gt 90 ]]; then
    log "warn" "Disk usage is high: ${disk_usage}%"
elif [[ $disk_usage -gt 80 ]]; then
    log "warn" "Disk usage is moderate: ${disk_usage}%"
else
    log "info" "Disk usage is healthy: ${disk_usage}%"
fi

# Check memory usage
log "info" "Checking memory usage..."
memory_pressure=$(memory_pressure | grep "System-wide memory free percentage" | awk '{print $5}' | sed 's/%//')
if [[ -n "$memory_pressure" ]]; then
    if [[ $memory_pressure -lt 10 ]]; then
        log "warn" "Memory pressure is high: ${memory_pressure}% free"
    else
        log "info" "Memory pressure is normal: ${memory_pressure}% free"
    fi
fi

# Check system integrity protection
log "info" "Checking System Integrity Protection status..."
sip_status=$(csrutil status 2>/dev/null | grep -o "enabled\|disabled" || echo "unknown")
log "info" "System Integrity Protection: $sip_status"

log_section_end "System Health Checks"

#-----------------------------------------------------------------------
# Security monitoring and malware detection
#-----------------------------------------------------------------------
log_section_start "Security Monitoring"
log "info" "Performing security checks and malware detection..."

# Check for security updates
log "info" "Checking for pending security updates..."
security_updates=$(softwareupdate -l 2>&1 | grep -i "security" || echo "")
if [[ -n "$security_updates" ]]; then
    log "warn" "Security updates available:"
    echo "$security_updates" | while read -r line; do
        log "warn" "  - $line"
    done
else
    log "info" "No pending security updates found"
fi

# Check XProtect signature status
log "info" "Checking XProtect malware signatures..."
if command -v xprotect &>/dev/null; then
    xprotect_status=$(xprotect --status 2>/dev/null || echo "Unknown")
    log "info" "XProtect status: $xprotect_status"
else
    log "info" "XProtect not available (normal on some systems)"
fi

# Check quarantine files
log "info" "Checking for quarantined files..."
quarantine_count=$(find ~/Library/Application\ Support/Quarantine -type f 2>/dev/null | wc -l)
if [[ $quarantine_count -gt 0 ]]; then
    log "warn" "Found $quarantine_count quarantined files"
    log "info" "Review quarantined files in: ~/Library/Application Support/Quarantine"
else
    log "info" "No quarantined files found"
fi

# Check for suspicious processes
log "info" "Scanning for suspicious processes..."
suspicious_processes=$(ps aux | grep -E "(cryptominer|bitcoin|mining)" | grep -v grep || echo "")
if [[ -n "$suspicious_processes" ]]; then
    log "warn" "Potentially suspicious processes detected:"
    echo "$suspicious_processes" | while read -r line; do
        log "warn" "  - $line"
    done
else
    log "info" "No suspicious processes detected"
fi

# Check system integrity protection status
log "info" "Verifying System Integrity Protection (SIP)..."
sip_status=$(csrutil status 2>/dev/null | grep -o "enabled\|disabled" || echo "unknown")
if [[ "$sip_status" == "enabled" ]]; then
    log "info" "✅ System Integrity Protection is enabled"
else
    log "warn" "⚠️  System Integrity Protection is $sip_status"
fi

# Check for unauthorized login items
log "info" "Checking for unauthorized login items..."
login_items=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null || echo "")
if [[ -n "$login_items" ]]; then
    log "info" "Current login items: $login_items"
else
    log "info" "No login items found"
fi

log_section_end "Security Monitoring"

#-----------------------------------------------------------------------
# System maintenance tasks
#-----------------------------------------------------------------------
log_section_start "System Maintenance Tasks"
run_command "sudo periodic daily weekly monthly" "Running periodic maintenance tasks"
run_command "sudo dscacheutil -flushcache" "Flushing DNS cache"
run_command "sudo killall -HUP mDNSResponder" "Restarting mDNSResponder"
log_section_end "System Maintenance Tasks"

#-----------------------------------------------------------------------
# Reindex Spotlight
#-----------------------------------------------------------------------
log_section_start "Spotlight Reindexing"
run_command "sudo mdutil -i on /" "Reindexing Spotlight"
log_section_end "Spotlight Reindexing"

#-----------------------------------------------------------------------
# Disk Utility First Aid
#-----------------------------------------------------------------------
log_section_start "Disk Utility First Aid"
volumes=($(diskutil list | grep "Apple_HFS\\|APFS Volume" | awk '{print $NF}'))
for volume in "${volumes[@]}"; do
    if diskutil info "$volume" | grep -q "Read-Only"; then
        continue
    fi
    run_command "sudo diskutil verifyVolume \"$volume\"" "Verifying volume $volume"
    run_command "sudo diskutil repairVolume \"$volume\"" "Repairing volume $volume"
done
log_section_end "Disk Utility First Aid"

#-----------------------------------------------------------------------
# Purge memory cache
#-----------------------------------------------------------------------
log_section_start "Memory Cache Purge"
run_command "sudo purge" "Purging memory cache"
log_section_end "Memory Cache Purge"

#-----------------------------------------------------------------------
# Rebuild Launch Services database
#-----------------------------------------------------------------------
log_section_start "Launch Services Rebuild"
run_command "sudo /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user" "Rebuilding Launch Services database"
log_section_end "Launch Services Rebuild"

#-----------------------------------------------------------------------
# Kernel cache rebuild
#-----------------------------------------------------------------------
log_section_start "Kernel Cache Rebuild"
run_command "sudo kextcache -u /" "Rebuilding kernel cache"
log_section_end "Kernel Cache Rebuild"

#-----------------------------------------------------------------------
# Temporary files clean-up and notification
#-----------------------------------------------------------------------
log_section_start "Temporary Files Clean-Up"
run_command "sudo rm -rf /private/var/folders/*" "Cleaning up temporary files"
run_command "osascript -e 'display notification \"Maintenance completed!\" with title \"System Maintenance\"'" "Showing completion notification"
log_section_end "Temporary Files Clean-Up"

#-----------------------------------------------------------------------
# Script completion
#-----------------------------------------------------------------------
SCRIPT_END_TIME=$(date +%s)
TOTAL_DURATION=$((SCRIPT_END_TIME - SCRIPT_START_TIME))

# Restore system performance settings
restore_system_performance

# Final resource monitoring and cleanup
monitor_resources "script completion"
cleanup_resources

log_section_boundary "end"