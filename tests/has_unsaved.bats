#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  common_setup
}

@test "has_unsaved tracks changes across update, save, and save_as" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  # A fresh load has no unsaved changes
  run ! flex_ini_has_unsaved

  flex_ini_update "unsaved" "change"
  flex_ini_has_unsaved

  flex_ini_save
  run ! flex_ini_has_unsaved

  # save_as must NOT clear the unsaved flag on the original id
  flex_ini_update "unsaved" "changed_again"
  flex_ini_save_as "$BATS_TEST_TMPDIR/elsewhere.ini"
  flex_ini_has_unsaved
}

@test "has_unsaved is set after delete" {
  local f
  f=$(create_ini)
  printf 'k = v\n' >"$f"
  flex_ini_load "$f"

  flex_ini_delete "k"

  flex_ini_has_unsaved
}

@test "has_unsaved fails when the id is not loaded" {
  run flex_ini_has_unsaved "never_loaded"

  [ "$status" -eq 1 ]
  [[ "$output" == *"not-yet been loaded"* ]]
}
