#!/usr/bin/env bats

setup() {
  load test_helper
  common_setup
}

@test "reset unloads every id" {
  local f1
  f1=$(create_ini one)
  local f2
  f2=$(create_ini two)
  flex_ini_load "$f1"
  flex_ini_load "$f2" "ini_two"
  flex_ini_update "change" "one"
  flex_ini_update "change" "two" "ini_two"

  flex_ini_reset

  auto_create_ini_on_load=false
  run flex_ini_update "change" "one"
  [ "$status" -eq 1 ]
  [[ "$output" == *"default has not-yet been loaded"* ]]

  run flex_ini_update "change" "two" "ini_two"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ini_two has not-yet been loaded"* ]]
}

@test "reset does not delete the files on disk" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"
  flex_ini_update "k" "v"
  flex_ini_save

  flex_ini_reset

  [ -f "$f" ]
  flex_ini_load "$f"
  [ "$(flex_ini_get k)" = "v" ]
}
