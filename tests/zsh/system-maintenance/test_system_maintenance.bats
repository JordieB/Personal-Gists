#!/usr/bin/env bats

@test "system_maintenance_example runs without error" {
    run zsh -f -c 'source "$1"; system_maintenance_example' zsh "$BATS_TEST_DIRNAME/../../../modules/zsh/system-maintenance/system-maintenance.plugin.zsh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Example system maintenance function"* ]]
}
