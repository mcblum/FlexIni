#!/usr/bin/env bats

setup() {
  load test_helper
  common_setup
}

@test "keys lists every key, sorted" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"
  flex_ini_update "test" "one"
  flex_ini_update "testing" "two"
  flex_ini_update "tested" "three"

  run flex_ini_keys

  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "test" ]
  [ "${lines[1]}" = "tested" ]
  [ "${lines[2]}" = "testing" ]
}

@test "keys on an empty config outputs nothing and succeeds" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  run flex_ini_keys

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "keys fails when the id is not loaded" {
  run flex_ini_keys "never_loaded"

  [ "$status" -eq 1 ]
  [[ "$output" == *"not-yet been loaded"* ]]
}
