#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  common_setup
}

@test "reload picks up external changes to the file" {
  local f
  f=$(create_ini)
  printf 'k = before\n' >"$f"
  flex_ini_load "$f"
  [ "$(flex_ini_get k)" = "before" ]

  printf 'k = after\n' >"$f"
  flex_ini_reload

  [ "$(flex_ini_get k)" = "after" ]
}

@test "reload discards unsaved in-memory changes" {
  local f
  f=$(create_ini)
  printf 'k = disk\n' >"$f"
  flex_ini_load "$f"
  flex_ini_update "k" "memory"

  flex_ini_reload

  [ "$(flex_ini_get k)" = "disk" ]
  run ! flex_ini_has_unsaved
}

@test "reload fails for an id that was never loaded" {
  run flex_ini_reload "never_loaded"

  [ "$status" -eq 1 ]
  [[ "$output" == *"No INI filepath could be found"* ]]
}
