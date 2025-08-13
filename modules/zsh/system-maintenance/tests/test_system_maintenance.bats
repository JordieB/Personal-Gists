#!/usr/bin/env bats

setup() {
    # Source the plugin before each test
    source "$BATS_TEST_DIRNAME/../system-maintenance.plugin.zsh"
}

@test "system_maintenance_example function exists" {
    # Check if function is defined
    type system_maintenance_example
}

@test "system_maintenance_example runs without error" {
    # Smoke test - just verify function doesn't error
    run system_maintenance_example
    [ "$status" -eq 0 ]
}
