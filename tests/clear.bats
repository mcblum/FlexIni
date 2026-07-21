#!/usr/bin/env bats

setup() {
  load test_helper
  common_setup
}

@test "clear wipes one id without touching others" {
  local f1
  f1=$(create_ini one)
  local f2
  f2=$(create_ini two)
  flex_ini_load "$f1"
  flex_ini_load "$f2" "test_two_id"
  flex_ini_update "k" "value"
  flex_ini_update "k2" "value2" "test_two_id"

  flex_ini_clear

  [ "$(flex_ini_get k)" = "" ]
  [ "$(flex_ini_get k2 test_two_id)" = "value2" ]
}

@test "clear fails when the id is not loaded" {
  run flex_ini_clear "never_loaded"

  [ "$status" -eq 1 ]
  [[ "$output" == *"not-yet been loaded"* ]]
}
