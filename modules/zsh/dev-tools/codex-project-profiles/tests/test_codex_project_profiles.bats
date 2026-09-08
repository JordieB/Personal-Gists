#!/usr/bin/env bats

setup() {
  export TEST_ROOT="$BATS_TEST_TMPDIR/work"
  export HOME="$BATS_TEST_TMPDIR/home"
  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  export PLUGIN="$BATS_TEST_DIRNAME/../codex-project-profiles.plugin.zsh"
  unset CODEX_HOME
  mkdir -p "$TEST_ROOT/sample-repo/.local/codex-home" "$HOME/.codex" "$BATS_TEST_TMPDIR/bin"
  git -C "$TEST_ROOT/sample-repo" init -q
  touch "$HOME/.codex/sample-repo.config.toml"
  cat >"$BATS_TEST_TMPDIR/bin/codex" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$@"
SCRIPT
  chmod +x "$BATS_TEST_TMPDIR/bin/codex"
}

run_codex() {
  local directory="$1"
  shift
  run zsh -f -c 'source "$PLUGIN"; cd "$1"; shift; codex "$@"' zsh "$directory" "$@"
}

@test "uses a profile derived from the Git root" {
  run_codex "$TEST_ROOT/sample-repo" --version
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = --profile ]
  [ "${lines[1]}" = sample-repo ]
  [ "${lines[2]}" = --version ]
}

@test "resolves the profile from a Git subdirectory" {
  mkdir -p "$TEST_ROOT/sample-repo/src/nested"
  run_codex "$TEST_ROOT/sample-repo/src/nested" exec test
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = --profile ]
  [ "${lines[1]}" = sample-repo ]
}

@test "supports an explicit marker profile" {
  printf '%s\n' analytics >"$TEST_ROOT/sample-repo/.local/codex-profile"
  touch "$HOME/.codex/analytics.config.toml"
  run_codex "$TEST_ROOT/sample-repo" review
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = analytics ]
}

@test "falls back when the selected profile is missing" {
  rm "$HOME/.codex/sample-repo.config.toml"
  run_codex "$TEST_ROOT/sample-repo" --version
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = --version ]
}

@test "falls back when the marker is invalid" {
  printf '%s\n' '../invalid' >"$TEST_ROOT/sample-repo/.local/codex-profile"
  run_codex "$TEST_ROOT/sample-repo" --version
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = --version ]
}

@test "preserves an explicit profile" {
  run_codex "$TEST_ROOT/sample-repo" --profile custom --version
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = --profile ]
  [ "${lines[1]}" = custom ]
}

@test "explicit CODEX_HOME takes precedence" {
  export CODEX_HOME="$BATS_TEST_TMPDIR/explicit-home"
  run_codex "$TEST_ROOT/sample-repo" --version
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = --version ]
}

@test "passes management commands through" {
  run_codex "$TEST_ROOT/sample-repo" features list
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = features ]
  [ "${lines[1]}" = list ]
}

@test "does not treat management words in runtime arguments as commands" {
  run_codex "$TEST_ROOT/sample-repo" exec doctor
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = --profile ]
  [ "${lines[1]}" = sample-repo ]
  [ "${lines[2]}" = exec ]
  [ "${lines[3]}" = doctor ]
}

@test "status reports the selected profile" {
  run zsh -f -c 'source "$PLUGIN"; cd "$TEST_ROOT/sample-repo"; codex_project_profile_status'
  [ "$status" -eq 0 ]
  [ "$output" = "project profile: sample-repo" ]
}
