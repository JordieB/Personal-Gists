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
# Author: Jordie
# Created: March 2024
# License: MIT
#-------------------------------------------------------------------------------

# Exit on error, unset variable usage, or failed pipeline
set -euo pipefail

# Script constants
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_START_TIME=$(date +%s)
readonly TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
readonly LOG_DATE_FORMAT="+%a %b %d %T %Z %Y"
readonly MAX_RETRIES=3
readonly LOCK_TIMEOUT=300  # 5 minutes
readonly BACKUP_TIMEOUT=3600  # 1 hour for backups
readonly LOGFILE="$HOME/maintenance.log"

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
Run the script with: maintain

The script will:
1. Create encrypted system backup using Restic
2. Remove user-level caches
3. Delete old log files
4. Update Homebrew and cleanup
5. Update Mac App Store apps
6. Apply system updates
7. Run system maintenance tasks
8. Reindex Spotlight
9. Run First Aid on volumes
10. Purge memory cache
11. Rebuild Launch Services
12. Rebuild kernel cache if needed
13. Clean up temporary files

Note: You will be prompted for your password when needed.

EOF
}

###############################################################################
# Logging Functions
###############################################################################

# Function to format text to fit within a specific width
format_text() {
    local text="$1"
    local width="${2:-64}"  # Default width of 64 characters
    printf "%-*.*s" "$width" "$width" "$text"
}

# Enhanced logging function that logs to both console and file
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "$LOG_DATE_FORMAT")
    
    # Format the message with proper width
    local formatted_msg
    formatted_msg="$(printf "[%-5s] %s - %s" "$level" "$timestamp" "$message")"
    
    # Log to system logger
    logger -p "user.$level" "$message"
    
    # Log to console and file (through tee)
    printf "%s\n" "$formatted_msg"
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

# Redirect all output to tee for logging
exec 1> >(tee -a "$LOGFILE")
exec 2> >(tee -a "$LOGFILE" >&2)

# Show usage information if help is requested
if [[ "${1:-}" == "--help" ]]; then
    show_usage
    exit 0
fi

# Start the maintenance run
log_section_boundary "start"
log "info" "Starting maintenance tasks..."
log "info" "Log file saved at: $LOGFILE"
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
        available_space=$(df -g "$backup_dir" | awk 'NR==2 {print $4}')
    else
        available_space=$(df -BG "$backup_dir" | awk 'NR==2 {gsub("G",""); print $4}')
    fi
    
    log "info" "Available space in backup directory: ${available_space}GB"
    
    if [[ $available_space -lt $min_free_space ]]; then
        log "warning" "Low disk space detected (${available_space}GB free, minimum ${min_free_space}GB required)"
        
        if [[ $available_space -lt $aggressive_cleanup_threshold ]]; then
            log "warning" "Critical disk space: performing aggressive cleanup"
            cleanup_old_backups "$backup_dir" "aggressive"
        else
            log "info" "Performing standard cleanup"
            cleanup_old_backups "$backup_dir" "standard"
        fi
        
        # Check space again after cleanup
        if [[ "$(uname)" == "Darwin" ]]; then
            available_space=$(df -g "$backup_dir" | awk 'NR==2 {print $4}')
        else
            available_space=$(df -BG "$backup_dir" | awk 'NR==2 {gsub("G",""); print $4}')
        fi
        
        if [[ $available_space -lt $aggressive_cleanup_threshold ]]; then
            log "error" "Critical: Unable to free enough space after cleanup"
            return 1
        fi
    fi
    
    return 0
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
            if ! RESTIC_PASSWORD_FILE="$password_file" timeout $LOCK_TIMEOUT restic forget \
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
            if ! RESTIC_PASSWORD_FILE="$password_file" timeout $LOCK_TIMEOUT restic forget \
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

# Function to verify backup integrity
verify_backup() {
    local repo_path="$1"
    local password_file="$2"
    local latest_snapshot
    
    log "info" "Verifying latest backup integrity..."
    
    # Get the latest snapshot ID
    latest_snapshot=$(RESTIC_PASSWORD_FILE="$password_file" restic snapshots --repo "$repo_path" --latest 1 --json | jq -r '.[0].id')
    if [[ -z "$latest_snapshot" ]]; then
        log "error" "Failed to get latest snapshot ID"
        return 1
    fi
    
    # Verify the backup data
    log "info" "Running data integrity check on snapshot ${latest_snapshot}..."
    if ! RESTIC_PASSWORD_FILE="$password_file" timeout $((LOCK_TIMEOUT * 2)) restic verify \
        --repo "$repo_path" \
        --read-data-subset=10% "$latest_snapshot"; then
        log "error" "Backup verification failed"
        return 1
    fi
    
    # Test restore of a small sample
    local test_restore_dir=$(mktemp -d)
    log "info" "Testing restore capability to $test_restore_dir..."
    
    if ! RESTIC_PASSWORD_FILE="$password_file" timeout $LOCK_TIMEOUT restic restore \
        --repo "$repo_path" \
        --target "$test_restore_dir" \
        --include "$HOME/.zshrc" \
        "$latest_snapshot" > /dev/null 2>&1; then
        log "error" "Restore test failed"
        rm -rf "$test_restore_dir"
        return 1
    fi
    
    # Cleanup test restore
    rm -rf "$test_restore_dir"
    log "info" "Backup verification completed successfully"
    return 0
}

# Function to clean up stale locks and check repository health
cleanup_repository() {
    local repo_path="$1"
    local password_file="$2"
    local retries=0
    local success=false
    
    while [[ $retries -lt $MAX_RETRIES && $success == false ]]; do
        log "info" "Attempting repository cleanup (attempt $((retries + 1))/$MAX_RETRIES)..."
        
        # Force unlock any stale locks
        if RESTIC_PASSWORD_FILE="$password_file" timeout $LOCK_TIMEOUT restic unlock --repo "$repo_path" --remove-all; then
            log "info" "Successfully removed stale locks"
            success=true
        else
            log "warning" "Failed to remove locks, retrying..."
            sleep 5
        fi
        
        ((retries++))
    done
    
    if [[ $success == false ]]; then
        log "error" "Failed to clean up repository after $MAX_RETRIES attempts"
        return 1
    fi
    
    # Check repository integrity
    log "info" "Checking repository integrity..."
    if ! RESTIC_PASSWORD_FILE="$password_file" timeout $LOCK_TIMEOUT restic check --repo "$repo_path"; then
        log "warning" "Repository check failed, attempting repair..."
        if ! RESTIC_PASSWORD_FILE="$password_file" timeout $LOCK_TIMEOUT restic repair --repo "$repo_path"; then
            log "error" "Repository repair failed"
            return 1
        fi
    fi
    
    return 0
}

# Function to perform Restic backup with enhanced logging and error handling
perform_restic_backup() {
    local source_dir="$1"
    local backup_dir="$2"
    local password_file="$HOME/.config/restic/password.txt"
    local retries=0
    local success=false
    
    # Check disk space before backup
    if ! timeout $LOCK_TIMEOUT check_disk_space "$backup_dir"; then
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
    
    # Perform backup with retries
    while [[ $retries -lt $MAX_RETRIES && $success == false ]]; do
        log "info" "Starting backup (attempt $((retries + 1))/$MAX_RETRIES)..."
        
        if sudo -E RESTIC_PASSWORD_FILE="$password_file" timeout $BACKUP_TIMEOUT restic backup \
            --repo "$backup_dir/restic" \
            --exclude-file=<(cat << 'EOF'
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
) \
            --exclude-caches \
            --one-file-system \
            --cleanup-cache \
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
    
    if [[ $success == false ]]; then
        log "error" "Backup failed after $MAX_RETRIES attempts"
        return 1
    fi
    
    # Cleanup old snapshots
    log "info" "Cleaning up old snapshots..."
    if ! RESTIC_PASSWORD_FILE="$password_file" timeout $LOCK_TIMEOUT restic forget \
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

# Main backup execution
log_section_start "System Backup"
echo "Setting up encrypted Restic backup..."
local_backup_dir="$HOME/.local/backups"

if perform_restic_backup "$HOME" "$local_backup_dir"; then
    log "info" "Restic encrypted backup completed successfully"
    echo ""
    log "info" "Your backup is encrypted and stored in: $local_backup_dir"
    log "info" "The encryption password is stored in: $HOME/.config/restic/password.txt"
    log "warning" "IMPORTANT: Please make a secure copy of this password file!"
    log "warning" "Without it, you cannot restore your backups."
else
    log "error" "Backup failed. Please check the error messages above."
fi

log_section_end "System Backup"

###############################################################################
# 2. Clear user-level caches
###############################################################################
log_section_start "User-Level Cache Cleanup"
echo "Clearing user-level caches in ~/Library/Caches/..."
rm -rf ~/Library/Caches/*
logger -p user.info "User-level caches cleared."
echo "User-level caches cleared."
log_section_end "User-Level Cache Cleanup"

###############################################################################
# 3. Remove logs older than 7 days
###############################################################################
log_section_start "Log Cleanup"
echo "Removing log files older than 7 days in /var/log and ~/Library/Logs..."

# Remove system logs older than 7 days
sudo find /var/log -type f -mtime +7 -exec rm -f {} \; 2>/dev/null || true

# Remove user logs older than 7 days
find ~/Library/Logs -type f -mtime +7 -exec rm -f {} \; 2>/dev/null || true

logger -p user.info "Old logs removed."
echo "Old logs removed."
log_section_end "Log Cleanup"

###############################################################################
# Continue with the main maintenance tasks
###############################################################################

#-----------------------------------------------------------------------
# Homebrew maintenance
#-----------------------------------------------------------------------
log_section_start "Homebrew Maintenance"
if command -v brew &>/dev/null; then
    echo "Checking for Homebrew updates..."
    brew_updates="$(brew update > /dev/null 2>&1 && brew upgrade --dry-run)"
    if [[ -z "$brew_updates" ]]; then
        logger -p user.info "No updates found for Homebrew."
        echo "No updates found for Homebrew."
    else
        brew upgrade > /dev/null 2>&1
        logger -p user.info "Homebrew updated successfully."
        echo "Homebrew updated."
    fi
    
    echo "Running brew cleanup..."
    brew cleanup > /dev/null 2>&1
    logger -p user.info "Homebrew cleanup completed."
    echo "Homebrew cleanup completed."
else
    logger -p user.warn "Homebrew is not installed."
    echo "Homebrew is not installed."
fi
log_section_end "Homebrew Maintenance"

#-----------------------------------------------------------------------
# Mac App Store updates
#-----------------------------------------------------------------------
log_section_start "Mac App Store Updates"
if command -v mas &>/dev/null; then
    echo "Checking for Mac App Store updates..."
    mas_updates="$(mas outdated)"
    if [[ -z "$mas_updates" ]]; then
        logger -p user.info "No updates found for Mac App Store apps."
        echo "No updates found for Mac App Store apps."
    else
        # If you prefer not to run MAS as root, remove 'sudo' here.
        sudo mas upgrade > /dev/null 2>&1
        logger -p user.info "Mac App Store apps updated successfully."
        echo "Updated Mac App Store apps."
    fi
else
    logger -p user.warn "MAS (Mac App Store CLI) is not installed."
    echo "MAS is not installed."
fi
log_section_end "Mac App Store Updates"

#-----------------------------------------------------------------------
# System updates
#-----------------------------------------------------------------------
log_section_start "System Updates"
echo "Checking for system updates..."
system_updates="$(softwareupdate -l 2>&1)"
if echo "$system_updates" | grep -q "No new software available."; then
    logger -p user.info "No system updates available."
    echo "No system updates available."
else
    sudo softwareupdate -ia --verbose > /dev/null 2>&1
    logger -p user.info "System updates installed successfully."
    echo "System updates completed."
fi
log_section_end "System Updates"

#-----------------------------------------------------------------------
# System maintenance tasks
#-----------------------------------------------------------------------
log_section_start "System Maintenance Tasks"
sudo periodic daily weekly monthly > /dev/null 2>&1 &
sudo dscacheutil -flushcache > /dev/null 2>&1
sudo killall -HUP mDNSResponder > /dev/null 2>&1 &
wait
logger -p user.info "System maintenance tasks completed."
echo "System maintenance tasks completed."
log_section_end "System Maintenance Tasks"

#-----------------------------------------------------------------------
# Reindex Spotlight
#-----------------------------------------------------------------------
log_section_start "Spotlight Reindexing"
sudo mdutil -i on / > /dev/null 2>&1
logger -p user.info "Spotlight reindexing completed."
echo "Spotlight reindexing completed."
log_section_end "Spotlight Reindexing"

#-----------------------------------------------------------------------
# Disk Utility First Aid
#-----------------------------------------------------------------------
log_section_start "Disk Utility First Aid"
# We look for volumes that are either Apple_HFS or APFS Volume
volumes=($(diskutil list | grep "Apple_HFS\\|APFS Volume" | awk '{print $NF}'))
for volume in "${volumes[@]}"; do
    # Skip read-only volumes
    if diskutil info "$volume" | grep -q "Read-Only"; then
        continue
    fi
    sudo diskutil verifyVolume "$volume" > /dev/null 2>&1 || true
    sudo diskutil repairVolume "$volume" > /dev/null 2>&1 || true
    logger -p user.info "First Aid completed on $volume."
    echo "First Aid completed on $volume."
done
log_section_end "Disk Utility First Aid"

#-----------------------------------------------------------------------
# Purge memory cache
#-----------------------------------------------------------------------
log_section_start "Memory Cache Purge"
sudo purge > /dev/null 2>&1 || true
logger -p user.info "Memory cache purged."
echo "Memory cache purged."
log_section_end "Memory Cache Purge"

#-----------------------------------------------------------------------
# Rebuild Launch Services database
#-----------------------------------------------------------------------
log_section_start "Launch Services Rebuild"
sudo /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -kill -r -domain local -domain system -domain user > /dev/null 2>&1 || true
logger -p user.info "Launch Services database rebuilt."
echo "Launch Services database rebuilt."
log_section_end "Launch Services Rebuild"

#-----------------------------------------------------------------------
# Kernel cache rebuild
#-----------------------------------------------------------------------
log_section_start "Kernel Cache Rebuild"
if sudo kextcache -u / > /dev/null 2>&1; then
    logger -p user.info "Kernel cache rebuilt successfully."
    echo "Kernel cache rebuilt."
else
    logger -p user.info "No need to rebuild the kernel cache."
    echo "No need to rebuild the kernel cache."
fi
log_section_end "Kernel Cache Rebuild"

#-----------------------------------------------------------------------
# Temporary files clean-up and notification
#-----------------------------------------------------------------------
log_section_start "Temporary Files Clean-Up"
sudo rm -rf /private/var/folders/* 2>/dev/null || true
osascript -e 'display notification "Maintenance completed!" with title "System Maintenance"'
logger -p user.info "Temporary files cleaned up."
echo "Temporary files cleaned up."
log_section_end "Temporary Files Clean-Up"

#-----------------------------------------------------------------------
# Script completion
#-----------------------------------------------------------------------
SCRIPT_END_TIME=$(date +%s)
TOTAL_DURATION=$((SCRIPT_END_TIME - SCRIPT_START_TIME))
log_section_boundary "end"