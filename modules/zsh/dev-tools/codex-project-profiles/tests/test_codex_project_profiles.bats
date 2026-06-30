#!/usr/bin/env bats

setup() {
    export TEST_ROOT="$BATS_TEST_TMPDIR/work"
    export HOME="$BATS_TEST_TMPDIR/home"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

    mkdir -p "$TEST_ROOT/sample-repo/.local/codex-home" "$HOME/.codex" "$BATS_TEST_TMPDIR/bin"
    git -C "$TEST_ROOT/sample-repo" init -q
    touch "$HOME/.codex/sample-repo.config.toml"

    cat > "$BATS_TEST_TMPDIR/bin/codex" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$@"
SCRIPT
    chmod +x "$BATS_TEST_TMPDIR/bin/codex"

    source "$BATS_TEST_DIRNAME/../codex-project-profiles.plugin.zsh"
}

@test "uses a profile derived from the Git root" {
    cd "$TEST_ROOT/sample-repo"

    run codex --version

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "--profile" ]
    [ "${lines[1]}" = "sample-repo" ]
    [ "${lines[2]}" = "--version" ]
}

@test "resolves the profile from a Git subdirectory" {
    mkdir -p "$TEST_ROOT/sample-repo/src/nested"
    cd "$TEST_ROOT/sample-repo/src/nested"

    run codex exec test

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "--profile" ]
    [ "${lines[1]}" = "sample-repo" ]
}

@test "supports an explicit marker profile" {
    printf '%s\n' analytics > "$TEST_ROOT/sample-repo/.local/codex-profile"
    touch "$HOME/.codex/analytics.config.toml"
    cd "$TEST_ROOT/sample-repo"

    run codex review

    [ "$status" -eq 0 ]
    [ "${lines[1]}" = "analytics" ]
}

@test "falls back when no profile exists" {
    rm "$HOME/.codex/sample-repo.config.toml"
    cd "$TEST_ROOT/sample-repo"

    run codex --version

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "--version" ]
}

@test "preserves an explicit profile" {
    cd "$TEST_ROOT/sample-repo"

    run codex --profile custom --version

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "--profile" ]
    [ "${lines[1]}" = "custom" ]
    [ "${lines[2]}" = "--version" ]
}

@test "does not attach profiles to management commands" {
    cd "$TEST_ROOT/sample-repo"

    run codex features list

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "features" ]
    [ "${lines[1]}" = "list" ]
}

@test "status reports the selected profile" {
    cd "$TEST_ROOT/sample-repo"

    run codex_project_profile_status

    [ "$status" -eq 0 ]
    [ "$output" = "project profile: sample-repo" ]
}
