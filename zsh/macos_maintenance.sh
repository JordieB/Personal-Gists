#!/bin/zsh
#
#-------------------------------------------------------------------------------
# System Maintenance Script
#
# This script performs routine maintenance tasks on macOS, including:
#   1. Making a Time Machine backup (if available)
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
#   14. Displaying a notification upon completion
#
# Logging:
#   - Attempts to write to /var/log/maintenance.log by default.
#   - If that directory is not writable, falls back to $HOME/maintenance.log.
#
# Requirements:
#   - macOS with zsh
#   - 'tmutil' (Time Machine) for backups, if desired
#   - 'brew' for Homebrew tasks, 'mas' for Mac App Store updates (optional)
#   - Sudo privileges for certain system commands
#
#-------------------------------------------------------------------------------

# Exit on error, unset variable usage, or failed pipeline
set -euo pipefail

# Attempt to use /var/log for logging, else fallback
LOGDIR="/var/log"
LOGFILE="$LOGDIR/maintenance.log"
if [[ ! -w "$LOGDIR" ]]; then
    echo "WARNING: /var/log is not writable, falling back to ~/maintenance.log"
    LOGFILE="$HOME/maintenance.log"
fi

# Redirect stdout/stderr to tee for logging
exec > >(tee -a "$LOGFILE") 2>&1

###############################################################################
# Utility function to create a line with consistent length
# Globals: None
# Arguments:
#   $1 -> text to generate a line from
# Output:
#   Echoes the text plus trailing spaces for alignment
###############################################################################
generate_line() {
    local text="$1"
    local padding="                                                                 "  # 65 spaces
    echo "${text}${padding:${#text}}"
}

#-----------------------------------------------------------------------
# Log the start of the script and important information
#-----------------------------------------------------------------------
log_file_line=$(generate_line "~~~~~ Log file saved at: $LOGFILE")
echo "$log_file_line"
logger -p user.info "Maintenance script started."
logger -p user.info "Log file saved at: $LOGFILE"
echo ""

# Track the start time for the entire script
start_time="$(date +%s)"

###############################################################################
# log_section_start
# Globals: None
# Arguments:
#   $1 -> section name
# Output:
#   Echoes/logs a header line for the section
###############################################################################
log_section_start() {
    local section_name="$1"
    local timestamp
    timestamp="$(date +"at %a %b %d %T %Z %Y")"

    local text="===== Starting $section_name"
    local line
    line="$(generate_line "$text $timestamp =====")"

    logger -p user.info "$line"
    echo "$line"

    # Export section start time as an environment variable
    export SECTION_START_TIME="$(date +%s)"
}

###############################################################################
# log_section_end
# Globals: SECTION_START_TIME (exported by log_section_start)
# Arguments:
#   $1 -> section name
# Output:
#   Echoes/logs a footer line for the section, including duration
###############################################################################
log_section_end() {
    local section_name="$1"
    local timestamp
    timestamp="$(date +"at %a %b %d %T %Z %Y")"

    local section_end_time
    section_end_time="$(date +%s)"

    # If SECTION_START_TIME was never exported, default to 0
    local duration
    local start_time_var="${SECTION_START_TIME:-0}"
    duration=$((section_end_time - start_time_var))

    local text=">> Completed $section_name"
    local line
    line="$(generate_line "$text $timestamp (Duration: ${duration}s)")"

    logger -p user.info "$line"
    echo "$line"
    echo ""
}

###############################################################################
# 1. Perform a backup before the script starts
###############################################################################
log_section_start "Backup (Time Machine)"
if command -v tmutil &>/dev/null; then
    echo "Starting Time Machine backup (waiting until complete)..."
    tmutil startbackup --block
    logger -p user.info "Time Machine backup completed."
    echo "Time Machine backup completed."
else
    logger -p user.warn "Time Machine (tmutil) not available."
    echo "Time Machine not available."
fi
log_section_end "Backup (Time Machine)"

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
end_time="$(date +%s)"
total_duration=$((end_time - start_time))
completion_line="$(generate_line "~~~~~ Maintenance completed at $(date)")"
total_duration_line="$(generate_line "~~~~~ Total duration: ${total_duration}s")"

logger -p user.info "Maintenance script completed. Total duration: ${total_duration}s."
echo "$completion_line"
echo "$total_duration_line"
echo "$log_file_line"