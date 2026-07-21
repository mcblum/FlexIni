#!/usr/bin/env bats

setup() {
  load test_helper
  common_setup
}

@test "show prints the id header and every key-value pair" {
  local f
  f=$(create_ini)
  flex_ini_load "$f" "myconfig"
  flex_ini_update "alpha" "one" "myconfig"
  flex_ini_update "section.beta" "two" "myconfig"

  run flex_ini_show "myconfig"

  [ "$status" -eq 0 ]
  [[ "$output" == *"[ myconfig ]"* ]]
  [[ "$output" == *"alpha = one"* ]]
  [[ "$output" == *"section.beta = two"* ]]
}

@test "show fails when the id is not loaded" {
  run flex_ini_show "never_loaded"

  [ "$status" -eq 1 ]
  [[ "$output" == *"not-yet been loaded"* ]]
}
