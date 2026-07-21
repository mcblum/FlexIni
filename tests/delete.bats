#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  common_setup
}

@test "delete removes a key in memory and on disk after save" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"
  flex_ini_update "hey" "now"
  flex_ini_save

  flex_ini_delete "hey"
  run ! flex_ini_has "hey"

  flex_ini_save
  flex_ini_reset
  flex_ini_load "$f"
  run ! flex_ini_has "hey"
}

@test "delete on a missing key still succeeds" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  flex_ini_delete "never_existed"
}

@test "delete fails when the id is not loaded" {
  run flex_ini_delete "hey"

  [ "$status" -eq 1 ]
  [[ "$output" == *"not-yet been loaded"* ]]
}
