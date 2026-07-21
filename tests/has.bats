#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  common_setup
}

@test "has returns 1 for a missing key and 0 once set" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  run ! flex_ini_has "hey"
  flex_ini_update "hey" "now"
  flex_ini_has "hey"
}

@test "has returns 0 for a key with an empty value" {
  local f
  f=$(create_ini)
  printf 'empty =\n' >"$f"
  flex_ini_load "$f"

  flex_ini_has "empty"

  flex_ini_update "also_empty" ""
  flex_ini_has "also_empty"
}

@test "has fails with an error when the id is not loaded" {
  run flex_ini_has "hey"

  [ "$status" -eq 1 ]
  [[ "$output" == *"default has not-yet been loaded"* ]]
}
