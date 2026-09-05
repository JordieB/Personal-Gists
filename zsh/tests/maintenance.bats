#!/usr/bin/env bats

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$HOME" "$TMPDIR" "$BATS_TEST_TMPDIR/bin"
  export CALLS="$BATS_TEST_TMPDIR/calls"
  : > "$CALLS"
  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  export SCRIPT="$BATS_TEST_DIRNAME/../macos_maintenance.sh"
  cat > "$BATS_TEST_TMPDIR/bin/dscl" <<'MOCK'
#!/bin/bash
printf 'NFSHomeDirectory: %s\n' "$HOME"
MOCK
  cat > "$BATS_TEST_TMPDIR/bin/brew" <<'MOCK'
#!/bin/bash
printf '%s\n' "$*" >> "$CALLS"
printf 'stdout for %s\n' "$*"
printf 'stderr for %s' "$*" >&2
if [[ "$*" == "${FAIL_COMMAND:-}" ]]; then exit 42; fi
if [[ "$1" == doctor && ${DOCTOR_WARN:-} == true ]]; then exit 1; fi
if [[ "$1" == update && ${INTERRUPT:-} == true ]]; then kill -TERM "$PPID"; fi
MOCK
  chmod +x "$BATS_TEST_TMPDIR/bin/"*
}

@test "default preview runs no Homebrew commands" {
  run /bin/bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -s "$CALLS" ]
  [[ "$output" == *'preview finished'* ]]
  [[ "$output" != *'Removing cache'* ]]
}

@test "apply runs separate upgrades, previews autoremove, and keeps full private logs" {
  run /bin/bash "$SCRIPT" -y
  [ "$status" -eq 0 ]
  expected=$'update\noutdated --formula\noutdated --cask\nupgrade --formula\nupgrade --cask\nautoremove --dry-run\ncleanup\ndoctor'
  [ "$(cat "$CALLS")" = "$expected" ]
  log_file=$(find "$HOME/Library/Logs/maintain" -name '*.log')
  /usr/bin/grep -q 'stdout for update' "$log_file"
  /usr/bin/grep -q 'stderr for update' "$log_file"
  [ "$(/usr/bin/stat -f '%Lp' "$log_file")" = 600 ]
  /usr/bin/grep -q 'exit_status=0' "$log_file"
}

@test "failed metadata update retains status and stops all later brew commands" {
  export FAIL_COMMAND=update
  run /bin/bash "$SCRIPT" -y
  [ "$status" -eq 1 ]
  [ "$(cat "$CALLS")" = update ]
  [[ "$output" == *'exit_status=42'* ]]
  [[ "$output" == *'failed=1'* ]]
  [[ "$output" != *'completed successfully.'* ]]
}

@test "failed upgrade skips cleanup but still runs doctor" {
  export FAIL_COMMAND='upgrade --formula'
  run /bin/bash "$SCRIPT" -y
  [ "$status" -eq 1 ]
  ! /usr/bin/grep -q '^cleanup$' "$CALLS"
  ! /usr/bin/grep -q '^autoremove' "$CALLS"
  /usr/bin/grep -q '^doctor$' "$CALLS"
}

@test "doctor warnings do not fail successful upgrades" {
  export DOCTOR_WARN=true
  run /bin/bash "$SCRIPT" -y
  [ "$status" -eq 0 ]
  [[ "$output" == *'doctor reported potential issues'* ]]
  [[ "$output" == *'failed=0'* ]]
}

@test "greedy and autoremove are explicit opt-ins" {
  run /bin/bash "$SCRIPT" --brew-greedy --brew-autoremove -y
  [ "$status" -eq 0 ]
  /usr/bin/grep -qx 'upgrade --cask --greedy' "$CALLS"
  /usr/bin/grep -qx 'autoremove' "$CALLS"
}

@test "backup preflight failure skips later tasks" {
  run /bin/bash "$SCRIPT" --backup --brew --cleanup -y
  [ "$status" -eq 1 ]
  [ ! -s "$CALLS" ]
  [[ "$output" == *'remaining 2 phases SKIPPED'* ]]
  [[ "$output" == *'skipped=2'* ]]
}

@test "missing optional tool is skipped rather than also counted successful" {
  run /bin/bash "$SCRIPT" --mas -y
  [ "$status" -eq 0 ]
  [[ "$output" == *'completed_successfully=0'* ]]
  [[ "$output" == *'skipped=1'* ]]
}

@test "log retention touches only old maintenance logs" {
  mkdir -p "$HOME/Library/Logs/maintain" "$HOME/Library/Logs/another-app"
  touch -t 202001010000 "$HOME/Library/Logs/maintain/maintain-old.log" "$HOME/Library/Logs/maintain/unrelated.log" "$HOME/Library/Logs/another-app/old.log"
  run /bin/bash "$SCRIPT" --cleanup -y
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/Library/Logs/maintain/maintain-old.log" ]
  [ -e "$HOME/Library/Logs/maintain/unrelated.log" ]
  [ -e "$HOME/Library/Logs/another-app/old.log" ]
}

@test "termination produces a failure summary and nonzero exit" {
  export INTERRUPT=true
  run /bin/bash "$SCRIPT" -y
  [ "$status" -eq 143 ]
  [[ "$output" == *'Run interrupted by SIGTERM'* ]]
  [[ "$output" == *'run_exit_status=143'* ]]
  [[ "$output" != *'Maintenance completed successfully.'* ]]
}

@test "Restic command failure prevents pruning and Homebrew execution" {
  cat > "$BATS_TEST_TMPDIR/bin/restic" <<'MOCK'
#!/bin/bash
printf 'restic %s\n' "$*" >> "$CALLS"
exit 3
MOCK
  chmod +x "$BATS_TEST_TMPDIR/bin/restic"
  export RESTIC_REPOSITORY="$HOME/repository"
  export RESTIC_PASSWORD=mock-test-password
  export BACKUP_MIN_FREE_GB=1
  run /bin/bash "$SCRIPT" --backup --brew -y
  [ "$status" -eq 1 ]
  /usr/bin/grep -q '^restic backup' "$CALLS"
  ! /usr/bin/grep -q '^restic forget' "$CALLS"
  ! /usr/bin/grep -q '^update$' "$CALLS"
  [[ "$output" == *'exit_status=3'* ]]
  [[ "$output" != *'mock-test-password'* ]]
}

@test "Restic integrity check failure prevents pruning" {
  cat > "$BATS_TEST_TMPDIR/bin/restic" <<'MOCK'
#!/bin/bash
printf 'restic %s\n' "$*" >> "$CALLS"
if [[ "$1" == check ]]; then exit 7; fi
MOCK
  chmod +x "$BATS_TEST_TMPDIR/bin/restic"
  export RESTIC_REPOSITORY="$HOME/repository"
  export RESTIC_PASSWORD=mock-test-password
  export BACKUP_MIN_FREE_GB=1
  run /bin/bash "$SCRIPT" --backup --brew -y
  [ "$status" -eq 1 ]
  /usr/bin/grep -q '^restic check' "$CALLS"
  ! /usr/bin/grep -q '^restic forget' "$CALLS"
  ! /usr/bin/grep -q '^update$' "$CALLS"
}

@test "Downloads cleanup does not opt into cache cleanup" {
  mkdir -p "$HOME/Downloads" "$HOME/Library/Caches/example"
  touch -t 202001010000 "$HOME/Downloads/old" "$HOME/Library/Caches/example/keep"
  run /bin/bash "$SCRIPT" --cleanup-downloads 30 -y
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/Downloads/old" ]
  [ -e "$HOME/Library/Caches/example/keep" ]
}
