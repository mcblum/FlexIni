#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  common_setup
}

@test "load marks default and named ids as loaded" {
  local f1
  f1=$(create_ini one)
  local f2
  f2=$(create_ini two)

  flex_ini_load "$f1"
  flex_ini_load "$f2" "test_two_id"

  [ "${ini_loaded[default]}" = "true" ]
  [ "${ini_loaded[test_two_id]}" = "true" ]
}

@test "load parses free keys, sections, and comments" {
  local f
  f=$(create_ini)
  cat >"$f" <<'EOF'
; a semicolon comment
# a hash comment
email = email@email.com

[docker]
installed = false

[docker-ce]
installed = true
EOF

  flex_ini_load "$f"

  [ "$(flex_ini_get email)" = "email@email.com" ]
  [ "$(flex_ini_get docker.installed)" = "false" ]
  [ "$(flex_ini_get docker-ce.installed)" = "true" ]
  run ! flex_ini_has "; a semicolon comment"
}

@test "load keeps the final line when the file has no trailing newline" {
  local f
  f=$(create_ini)
  printf 'first = one\nlast = two' >"$f"

  flex_ini_load "$f"

  [ "$(flex_ini_get first)" = "one" ]
  [ "$(flex_ini_get last)" = "two" ]
}

@test "load tolerates indentation and trims trailing whitespace from values" {
  local f
  f=$(create_ini)
  printf '[section]\n  indented = value\npadded = value   \n' >"$f"

  flex_ini_load "$f"

  [ "$(flex_ini_get section.indented)" = "value" ]
  [ "$(flex_ini_get section.padded)" = "value" ]
}

@test "load does not execute or expand values by default" {
  local f
  f=$(create_ini)
  local canary="$BATS_TEST_TMPDIR/injected"
  printf 'cmd = $(touch %s)\nvar = $HOME\ntick = `id`\n' "$canary" >"$f"

  flex_ini_load "$f"

  [ "$(flex_ini_get cmd)" = "\$(touch $canary)" ]
  [ "$(flex_ini_get var)" = '$HOME' ]
  [ "$(flex_ini_get tick)" = '`id`' ]
  [ ! -e "$canary" ]
}

@test "load expands variables when expand_values_on_load is enabled" {
  local f
  f=$(create_ini)
  FLEXINI_TEST_VAR="expanded"
  printf 'var = $FLEXINI_TEST_VAR\nbraced = ${FLEXINI_TEST_VAR}\n' >"$f"

  expand_values_on_load=true
  flex_ini_load "$f"

  [ "$(flex_ini_get var)" = "expanded" ]
  [ "$(flex_ini_get braced)" = "expanded" ]
}

@test "expand_values_on_load expands variables embedded in surrounding text" {
  local f
  f=$(create_ini)
  FLEXINI_TEST_VAR="mid"
  printf 'path = pre-${FLEXINI_TEST_VAR}-post/$FLEXINI_TEST_VAR\n' >"$f"

  expand_values_on_load=true
  flex_ini_load "$f"

  [ "$(flex_ini_get path)" = "pre-mid-post/mid" ]
}

@test "expand_values_on_load leaves undefined variables empty and bare dollars literal" {
  local f
  f=$(create_ini)
  unset FLEXINI_UNDEFINED_VAR
  printf 'gone = [$FLEXINI_UNDEFINED_VAR]\nprice = 100$ each\n' >"$f"

  expand_values_on_load=true
  flex_ini_load "$f"

  [ "$(flex_ini_get gone)" = "[]" ]
  [ "$(flex_ini_get price)" = '100$ each' ]
}

@test "expand_values_on_load never executes command substitution" {
  local f
  f=$(create_ini)
  local canary="$BATS_TEST_TMPDIR/expand_pwned"
  # A command substitution planted in a value must be treated as literal
  # text, not run, even with expansion enabled.
  printf 'cmd = x$(touch %s)x\ntick = `touch %s`\nnested = ${FLEXINI_TEST_VAR:-$(touch %s)}\n' \
    "$canary" "$canary" "$canary" >"$f"

  expand_values_on_load=true
  flex_ini_load "$f"

  [ ! -e "$canary" ]
  [ "$(flex_ini_get cmd)" = 'x$(touch '"$canary"')x' ]
  [ "$(flex_ini_get tick)" = '`touch '"$canary"'`' ]
}

@test "load auto-creates a missing file when auto_create_ini_on_load is true" {
  local f="$BATS_TEST_TMPDIR/does_not_exist_yet.ini"

  flex_ini_load "$f" "autocreate"

  [ -f "$f" ]
  flex_ini_update "auto" "create" "autocreate"
  flex_ini_save "autocreate"
  flex_ini_reset
  flex_ini_load "$f" "autocreate"
  [ "$(flex_ini_get auto autocreate)" = "create" ]
}

@test "load fails on a missing file when auto_create_ini_on_load is false" {
  auto_create_ini_on_load=false

  run flex_ini_load "$BATS_TEST_TMPDIR/missing.ini"

  [ "$status" -eq 1 ]
  [[ "$output" == *"ini file not found"* ]]
}

@test "load warns when the id is already loaded from a different file" {
  local f1
  f1=$(create_ini one)
  local f2
  f2=$(create_ini two)
  flex_ini_load "$f1"

  run flex_ini_load "$f2"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already loaded from"* ]]

  # Loading the same file again stays silent
  run flex_ini_load "$f1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "load twice is a no-op unless force_reload is set" {
  local f
  f=$(create_ini)
  printf 'key = original\n' >"$f"

  flex_ini_load "$f"
  flex_ini_update "key" "modified"

  # A second plain load must not clobber in-memory changes
  flex_ini_load "$f"
  [ "$(flex_ini_get key)" = "modified" ]

  # A forced reload must re-read the file
  flex_ini_load "$f" "" "true"
  [ "$(flex_ini_get key)" = "original" ]
}
