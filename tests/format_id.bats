#!/usr/bin/env bats

setup() {
  load test_helper
  common_setup
}

@test "format_id leaves valid ids untouched" {
  [ "$(private_flex_ini_format_id "fine")" = "fine" ]
  [ "$(private_flex_ini_format_id "also_fine")" = "also_fine" ]
}

@test "format_id defaults to 'default' when no id is given" {
  [ "$(private_flex_ini_format_id)" = "default" ]
  [ "$(private_flex_ini_format_id "")" = "default" ]
}

@test "format_id replaces dashes and spaces" {
  [ "$(private_flex_ini_format_id "remove-dash")" = "remove_dash" ]
  [ "$(private_flex_ini_format_id "remove-dash and spaces")" = "remove_dash_and_spaces" ]
}

@test "format_id sanitizes every character that is invalid in a variable name" {
  [ "$(private_flex_ini_format_id "my.dotted.id")" = "my_dotted_id" ]
  [ "$(private_flex_ini_format_id "path/to/thing")" = "path_to_thing" ]
  [ "$(private_flex_ini_format_id 'we!rd$ch@rs')" = "we_rd_ch_rs" ]
}

@test "format_id prefixes ids that start with a digit" {
  [ "$(private_flex_ini_format_id "9lives")" = "_9lives" ]
}

@test "ids with special characters work end to end" {
  local f
  f=$(create_ini)

  flex_ini_load "$f" "big-corp.settings/v2"
  flex_ini_update "k" "v" "big-corp.settings/v2"
  flex_ini_save "big-corp.settings/v2"
  flex_ini_reset
  flex_ini_load "$f" "big-corp.settings/v2"

  [ "$(flex_ini_get k "big-corp.settings/v2")" = "v" ]
}
