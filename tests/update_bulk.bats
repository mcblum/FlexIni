#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  common_setup
}

@test "update_bulk sets several keys, including section keys, in one call" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  flex_ini_update_bulk "" \
    "alpha" "one" \
    "beta" "two" \
    "section.gamma" "three"

  [ "$(flex_ini_get alpha)" = "one" ]
  [ "$(flex_ini_get beta)" = "two" ]
  [ "$(flex_ini_get section.gamma)" = "three" ]
  flex_ini_has_unsaved
}

@test "update_bulk works with a named id" {
  local f
  f=$(create_ini)
  flex_ini_load "$f" "bulk_id"

  flex_ini_update_bulk "bulk_id" "k1" "v1" "k2" "v2"

  [ "$(flex_ini_get k1 bulk_id)" = "v1" ]
  [ "$(flex_ini_get k2 bulk_id)" = "v2" ]
}

@test "update_bulk survives a save and reload round trip" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  flex_ini_update_bulk "" "one.a" "1" "two.b" "2" "free" "3"
  flex_ini_save
  flex_ini_reset
  flex_ini_load "$f"

  [ "$(flex_ini_get one.a)" = "1" ]
  [ "$(flex_ini_get two.b)" = "2" ]
  [ "$(flex_ini_get free)" = "3" ]
}

@test "update_bulk fails when the id is not loaded" {
  run flex_ini_update_bulk "never_loaded" "k" "v"

  [ "$status" -eq 1 ]
  [[ "$output" == *"not-yet been loaded"* ]]
}

@test "update_bulk requires at least one pair" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  run flex_ini_update_bulk ""

  [ "$status" -eq 1 ]
  [[ "$output" == *"at least one key/value pair"* ]]
}

@test "update_bulk rejects an odd number of arguments and applies nothing" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  run flex_ini_update_bulk "" "k1" "v1" "dangling_key"
  [ "$status" -eq 1 ]
  [[ "$output" == *"odd number of arguments"* ]]

  run ! flex_ini_has "k1"
  run ! flex_ini_has_unsaved
}

@test "update_bulk rejects a bad pair and applies nothing" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  # First pair is fine, second key is invalid: nothing may be applied
  run flex_ini_update_bulk "" "good" "value" "bad key" "value"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid"* ]]

  run ! flex_ini_has "good"
  run ! flex_ini_has_unsaved
}

@test "update_bulk with auto_save_on_changes saves exactly once at the end" {
  local f
  f=$(create_ini)
  printf 'existing = before\n' >"$f"
  auto_save_on_changes=true
  flex_ini_load "$f"

  flex_ini_update_bulk "" "k1" "v1" "k2" "v2"

  # Saved to disk without an explicit flex_ini_save call
  flex_ini_reset
  flex_ini_load "$f"
  [ "$(flex_ini_get k1)" = "v1" ]
  [ "$(flex_ini_get k2)" = "v2" ]

  # The backup proves a single save happened: it must hold the state
  # from before the bulk call. A save per pair would have left an
  # intermediate state (containing k1) in the .bak file.
  [ "$(cat "${f}.bak")" = "existing = before" ]
}
