#!/usr/bin/env bats

setup() {
  load test_helper
  common_setup
}

@test "save preserves comments, blank lines, and key order" {
  local f
  f=$(create_ini)
  cat >"$f" <<'EOF'
; global settings for the app
# maintained by hand -- edit carefully

zebra = stripes
apple = red

[server]
; port must stay above 1024
port = 8080
host = localhost

[client]
retries = 3
EOF
  flex_ini_load "$f"

  flex_ini_update "server.port" "9090"    # update in place
  flex_ini_update "server.timeout" "30"   # new key in an existing section
  flex_ini_update "banana" "yellow"       # new free key
  flex_ini_update "logging.level" "debug" # brand-new section
  flex_ini_delete "client.retries"        # deletion
  flex_ini_save

  local expected
  expected=$(cat <<'EOF'
; global settings for the app
# maintained by hand -- edit carefully

zebra = stripes
apple = red
banana = yellow

[server]
; port must stay above 1024
port = 9090
host = localhost
timeout = 30

[client]

[logging]
level = debug
EOF
)
  [ "$(cat "$f")" = "$expected" ]
}

@test "saving twice in a row produces identical output" {
  local f
  f=$(create_ini)
  cat >"$f" <<'EOF'
; a comment worth keeping
top = value

[section]
key = one
EOF
  flex_ini_load "$f"
  flex_ini_update "section.key" "two"

  flex_ini_save
  local first_pass
  first_pass=$(cat "$f")

  flex_ini_save
  [ "$(cat "$f")" = "$first_pass" ]
}

@test "save_as carries the original file's comments into the copy" {
  local f
  f=$(create_ini)
  printf '; keep me\nk = v\n' >"$f"
  flex_ini_load "$f"
  flex_ini_update "k" "v2"

  local target="$BATS_TEST_TMPDIR/copy.ini"
  flex_ini_save_as "$target"

  [[ "$(cat "$target")" == *"; keep me"* ]]
  [[ "$(cat "$target")" == *"k = v2"* ]]
  # And the original stays untouched
  [ "$(cat "$f")" = "; keep me
k = v" ]
}

@test "save normalizes key lines to 'key = value' spacing" {
  local f
  f=$(create_ini)
  printf 'k=v\npadded   =   spaced\n' >"$f"
  flex_ini_load "$f"

  flex_ini_save

  [ "$(cat "$f")" = "k = v
padded = spaced" ]
}
