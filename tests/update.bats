#!/usr/bin/env bats

setup() {
  load test_helper
  common_setup
}

@test "update creates and overwrites values, including section keys" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  flex_ini_update "hey" "now"
  [ "$(flex_ini_get hey)" = "now" ]

  flex_ini_update "hey" "later"
  [ "$(flex_ini_get hey)" = "later" ]

  flex_ini_update "section.thing" "true"
  [ "$(flex_ini_get section.thing)" = "true" ]

  flex_ini_save
  flex_ini_reset
  flex_ini_load "$f"
  [ "$(flex_ini_get section.thing)" = "true" ]
}

@test "update fails when the id is not loaded" {
  auto_create_ini_on_load=false

  run flex_ini_update "change" "one"
  [ "$status" -eq 1 ]
  [[ "$output" == *"default has not-yet been loaded"* ]]

  run flex_ini_update "change" "two" "ini_two"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ini_two has not-yet been loaded"* ]]
}

@test "update saves immediately when auto_save_on_changes is true" {
  local f
  f=$(create_ini)
  auto_save_on_changes=true
  flex_ini_load "$f"

  flex_ini_update "auto" "save"
  # No explicit save; reset and reload straight from disk
  flex_ini_reset
  flex_ini_load "$f"

  [ "$(flex_ini_get auto)" = "save" ]
}

@test "update rejects keys containing whitespace or '='" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  run flex_ini_update "bad key" "value"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid"* ]]

  run flex_ini_update "bad=key" "value"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid"* ]]
}

@test "update rejects values containing newlines" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  run flex_ini_update "key" $'line one\nline two'

  [ "$status" -eq 1 ]
  [[ "$output" == *"newline"* ]]
}

@test "update stores shell metacharacters literally without executing them" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"
  local canary="$BATS_TEST_TMPDIR/injected"

  flex_ini_update "cmd" "\$(touch $canary)"
  flex_ini_save
  flex_ini_reset
  flex_ini_load "$f"

  [ "$(flex_ini_get cmd)" = "\$(touch $canary)" ]
  [ ! -e "$canary" ]
}
