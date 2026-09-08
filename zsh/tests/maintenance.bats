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
  cat > "$BATS_TEST_TMPDIR/bin/softwareupdate" <<'MOCK'
#!/bin/bash
printf 'softwareupdate %s\n' "$*" >> "$CALLS"
if [[ ${FAIL_SOFTWAREUPDATE:-} == true ]]; then exit 9; fi
MOCK
  chmod +x "$BATS_TEST_TMPDIR/bin/"*
}

@test "explicit preview runs no Homebrew commands" {
  run /bin/bash "$SCRIPT" --brew --dry-run
  [ "$status" -eq 0 ]
  [ ! -s "$CALLS" ]
  [[ "$output" == *'preview finished'* ]]
  [[ "$output" != *'Removing cache'* ]]
}

@test "apply runs separate upgrades, removes unused dependencies, and keeps full private logs" {
  run /bin/bash "$SCRIPT" --brew -y
  [ "$status" -eq 0 ]
  expected=$'update\noutdated --formula\noutdated --cask --greedy\nupgrade --formula --no-ask\nupgrade --cask --greedy --no-ask\nautoremove\ncleanup\ndoctor'
  [ "$(cat "$CALLS")" = "$expected" ]
  log_file=$(find "$HOME/Library/Logs/maintain" -name '*.log')
  /usr/bin/grep -q 'stdout for update' "$log_file"
  /usr/bin/grep -q 'stderr for update' "$log_file"
  [ "$(/usr/bin/stat -f '%Lp' "$log_file")" = 600 ]
  /usr/bin/grep -q 'exit_status=0' "$log_file"
}

@test "failed metadata update retains status and stops all later brew commands" {
  export FAIL_COMMAND=update
  run /bin/bash "$SCRIPT" --brew -y
  [ "$status" -eq 1 ]
  [ "$(cat "$CALLS")" = update ]
  [[ "$output" == *'exit_status=42'* ]]
  [[ "$output" == *'failed=1'* ]]
  [[ "$output" != *'completed successfully.'* ]]
}

@test "failed upgrade skips cleanup but still runs doctor" {
  export FAIL_COMMAND='upgrade --formula --no-ask'
  run /bin/bash "$SCRIPT" --brew -y
  [ "$status" -eq 1 ]
  ! /usr/bin/grep -q '^cleanup$' "$CALLS"
  ! /usr/bin/grep -q '^autoremove' "$CALLS"
  /usr/bin/grep -q '^doctor$' "$CALLS"
}

@test "failed Homebrew cleanup fails the phase while retaining doctor output" {
  export FAIL_COMMAND=cleanup
  run /bin/bash "$SCRIPT" --brew -y
  [ "$status" -eq 1 ]
  /usr/bin/grep -q '^doctor$' "$CALLS"
  [[ "$output" == *'exit_status=42'* ]]
  [[ "$output" == *'failed=1'* ]]
}

@test "doctor output logging failure fails the phase and final status" {
  cat >"$BATS_TEST_TMPDIR/bin/tee" <<'MOCK'
#!/bin/bash
output_file=${2:-}
temporary_file=$(mktemp)
/bin/cat >"$temporary_file"
/bin/cat "$temporary_file"
/bin/cat "$temporary_file" >>"$output_file"
if /usr/bin/grep -q 'doctor' "$temporary_file"; then exit 1; fi
MOCK
  chmod +x "$BATS_TEST_TMPDIR/bin/tee"
  run /bin/bash "$SCRIPT" --brew -y
  [ "$status" -eq 1 ]
  [[ "$output" == *'output logging failed'* ]]
  [[ "$output" == *'failed=1'* ]]
  run /bin/bash "$SCRIPT" --diagnostics
  [ "$status" -eq 1 ]
  [[ "$output" == *'output logging failed'* ]]
  [[ "$output" == *'failed=1'* ]]
}

@test "greedy and autoremove can be explicitly enabled" {
  run /bin/bash "$SCRIPT" --brew-greedy --brew-autoremove -y
  [ "$status" -eq 0 ]
  /usr/bin/grep -qx 'upgrade --cask --greedy --no-ask' "$CALLS"
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
  [[ "$output" == *'user_logs:'*'items=1'* ]]
}

@test "cleanup preserves protected caches and reports processed items" {
  mkdir -p "$HOME/Library/Caches/Firefox-session" "$HOME/Library/Caches/disposable"
  touch "$HOME/Library/Caches/Firefox-session/keep" "$HOME/Library/Caches/disposable/remove"
  run /bin/bash "$SCRIPT" --cleanup
  [ "$status" -eq 0 ]
  [ -e "$HOME/Library/Caches/Firefox-session/keep" ]
  [ ! -e "$HOME/Library/Caches/disposable" ]
  [[ "$output" == *'user_caches:'*'items=1'* ]]
}

@test "cleanup command failure produces a failed summary" {
  mkdir -p "$HOME/Library/Caches/disposable"
  cat >"$BATS_TEST_TMPDIR/bin/rm" <<'MOCK'
#!/bin/bash
exit 23
MOCK
  chmod +x "$BATS_TEST_TMPDIR/bin/rm"
  run /bin/bash "$SCRIPT" --cleanup
  /bin/rm -f "$BATS_TEST_TMPDIR/bin/rm"
  [ "$status" -eq 1 ]
  [[ "$output" == *'exit_status=23'* ]]
  [[ "$output" == *'failed=1'* ]]
}

@test "termination produces a failure summary and nonzero exit" {
  export INTERRUPT=true
  run /bin/bash "$SCRIPT" --brew -y
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

@test "successful backup checks integrity and applies retention before later tasks" {
  cat >"$BATS_TEST_TMPDIR/bin/restic" <<'MOCK'
#!/bin/bash
printf 'restic %s\n' "$*" >> "$CALLS"
MOCK
  chmod +x "$BATS_TEST_TMPDIR/bin/restic"
  export RESTIC_REPOSITORY="$HOME/repository"
  export RESTIC_PASSWORD=mock-test-password
  export BACKUP_MIN_FREE_GB=1
  run /bin/bash "$SCRIPT" --backup --brew -y
  [ "$status" -eq 0 ]
  backup_line=$(/usr/bin/grep -n '^restic backup' "$CALLS" | cut -d: -f1)
  check_line=$(/usr/bin/grep -n '^restic check$' "$CALLS" | cut -d: -f1)
  retention_line=$(/usr/bin/grep -n '^restic forget --keep-last 3 --prune$' "$CALLS" | cut -d: -f1)
  brew_line=$(/usr/bin/grep -n '^update$' "$CALLS" | cut -d: -f1)
  [ "$backup_line" -lt "$check_line" ]
  [ "$check_line" -lt "$retention_line" ]
  [ "$retention_line" -lt "$brew_line" ]
}

@test "Downloads cleanup does not opt into cache cleanup" {
  mkdir -p "$HOME/Downloads" "$HOME/Library/Caches/example"
  touch -t 202001010000 "$HOME/Downloads/old" "$HOME/Library/Caches/example/keep"
  run /bin/bash "$SCRIPT" --cleanup-downloads 30 -y
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/Downloads/old" ]
  [ -e "$HOME/Library/Caches/example/keep" ]
  [[ "$output" == *'downloads:'*'items=1'* ]]
}

@test "default performs maintenance and preserves upgrade confirmation" {
  run /bin/bash "$SCRIPT"
  [ "$status" -eq 0 ]
  /usr/bin/grep -qx 'upgrade --formula --ask' "$CALLS"
  /usr/bin/grep -qx 'upgrade --cask --greedy --ask' "$CALLS"
  /usr/bin/grep -qx 'autoremove' "$CALLS"
}

@test "exclusions narrow the default scope" {
  run /bin/bash "$SCRIPT" --no-brew-greedy --no-brew-autoremove
  [ "$status" -eq 0 ]
  /usr/bin/grep -qx 'upgrade --cask --ask' "$CALLS"
  /usr/bin/grep -qx 'autoremove --dry-run' "$CALLS"
}

@test "dry run takes precedence over yes and reports planned not completed" {
  run /bin/bash "$SCRIPT" --brew --dry-run -y
  [ "$status" -eq 0 ]
  [ ! -s "$CALLS" ]
  [[ "$output" == *'completed_successfully=0 planned=1'* ]]
  [[ "$output" != *'state=SUCCESS'* ]]
}

@test "doctor health warning is distinct from action success" {
  export DOCTOR_WARN=true
  run /bin/bash "$SCRIPT" --brew -y
  [ "$status" -eq 0 ]
  [[ "$output" == *'doctor reported potential issues'* ]]
  [[ "$output" == *'failed=0'* ]]
  [[ "$output" == *'health_warnings=1'* ]]
  [[ "$output" == *'health warnings require review'* ]]
}

@test "prompt without newline is visible before an answer is supplied" {
  cat > "$BATS_TEST_TMPDIR/bin/brew" <<'MOCK'
#!/bin/bash
if [[ "$1" == upgrade ]]; then
  printf 'Proceed now? '
  read -r answer
  [[ "$answer" == y ]] || exit 42
fi
MOCK
  chmod +x "$BATS_TEST_TMPDIR/bin/brew"
  # A FIFO leaves stdin open while the test waits to see the prompt.
  mkfifo "$BATS_TEST_TMPDIR/input"
  /bin/bash "$SCRIPT" --brew < "$BATS_TEST_TMPDIR/input" > "$BATS_TEST_TMPDIR/output" 2>&1 &
  runner=$!
  exec 8> "$BATS_TEST_TMPDIR/input"
  seen=false
  for i in {1..50}; do
    if /usr/bin/grep -q 'Proceed now?' "$BATS_TEST_TMPDIR/output"; then seen=true; break; fi
    sleep 0.1
  done
  printf 'y\ny\n' >&8
  exec 8>&-
  wait "$runner"
  [ "$seen" = true ]
}

@test "default and explicit quick select the same five phases" {
  run /bin/bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'requested=5'* ]]
  run /bin/bash "$SCRIPT" --quick --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'requested=5'* ]]
}

@test "comprehensive adds shutdown diagnostics and uses the absolute log executable" {
  run /bin/bash "$SCRIPT" --comprehensive --dry-run --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *'/usr/bin/log show'* ]]
}

@test "explicit tasks stay narrow and presets are additive with last preset winning" {
  run /bin/bash "$SCRIPT" --diagnostics --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'requested=1'* ]]
  mkdir -p "$HOME/Downloads"
  touch "$HOME/Downloads/example"
  run /bin/bash "$SCRIPT" --comprehensive --cleanup-downloads 30 --quick --dry-run --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *'requested=5'* ]]
  [[ "$output" == *'Finding files older than 30d'* ]]
  [[ "$output" != *'/usr/bin/log show'* ]]
  run /bin/bash "$SCRIPT" --quick --comprehensive --dry-run --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *'/usr/bin/log show'* ]]
}

@test "OS update listing avoids sudo and installation uses sudo" {
  run /bin/bash "$SCRIPT" --check-os-updates
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = 'softwareupdate --list' ]
  cat >"$BATS_TEST_TMPDIR/bin/sudo" <<'MOCK'
#!/bin/bash
printf 'sudo %s\n' "$*" >> "$CALLS"
MOCK
  chmod +x "$BATS_TEST_TMPDIR/bin/sudo"
  : >"$CALLS"
  run /bin/bash "$SCRIPT" --apply-os-updates
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = 'sudo softwareupdate --install --all' ]
}

@test "OS update command failure produces nonzero final status" {
  export FAIL_SOFTWAREUPDATE=true
  run /bin/bash "$SCRIPT" --check-os-updates
  [ "$status" -eq 1 ]
  [[ "$output" == *'exit_status=9'* ]]
  [[ "$output" == *'failed=1'* ]]
}
