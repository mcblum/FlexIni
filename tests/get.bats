#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  common_setup
}

@test "get returns empty for an unset key and the value once set" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  [ "$(flex_ini_get hey)" = "" ]
  flex_ini_update "hey" "now"
  [ "$(flex_ini_get hey)" = "now" ]
}

@test "get survives a save, reset, and reload round trip" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"
  flex_ini_update "hey" "now"
  flex_ini_save

  flex_ini_reset
  flex_ini_load "$f"

  [ "$(flex_ini_get hey)" = "now" ]
}

@test "get keeps values with quotes, dollars, globs, and spaces literal" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"
  local tricky='he said "hi" `id` $(id) * $HOME  double  spaces'

  flex_ini_update "tricky" "$tricky"

  [ "$(flex_ini_get tricky)" = "$tricky" ]
}

@test "get keeps ids isolated from each other" {
  local f1
  f1=$(create_ini one)
  local f2
  f2=$(create_ini two)
  flex_ini_load "$f1"
  flex_ini_load "$f2" "other"

  flex_ini_update "k" "default_value"
  flex_ini_update "k" "other_value" "other"

  [ "$(flex_ini_get k)" = "default_value" ]
  [ "$(flex_ini_get k other)" = "other_value" ]
}

@test "get with a missing key argument fails and writes nothing to stdout" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  run --separate-stderr flex_ini_get ""

  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"required"* ]]
}
