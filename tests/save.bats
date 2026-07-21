#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  common_setup
}

@test "save writes values back to the original file" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"
  flex_ini_update "save" "test"

  flex_ini_save
  flex_ini_reset
  flex_ini_load "$f"

  [ "$(flex_ini_get save)" = "test" ]
}

@test "save creates a .bak backup by default and skips it when disabled" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"
  flex_ini_update "k" "v"

  flex_ini_save
  [ -f "${f}.bak" ]

  rm -f "${f}.bak"
  back_up_changes_on_save=false
  flex_ini_update "k" "v2"
  flex_ini_save
  [ ! -f "${f}.bak" ]
}

@test "save preserves the destination file's permissions" {
  local f
  f=$(create_ini)
  chmod 640 "$f"
  flex_ini_load "$f"
  flex_ini_update "k" "v"

  flex_ini_save

  [ "$(file_mode "$f")" = "640" ]
}

@test "save fails when the id is not loaded" {
  run flex_ini_save "never_loaded"

  [ "$status" -eq 1 ]
  [[ "$output" == *"not-yet been loaded"* ]]
}

@test "save_as writes to the new path and leaves the original untouched" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"
  flex_ini_update "save" "test"
  flex_ini_save

  flex_ini_update "save_as" "test"
  local save_as_loc="$BATS_TEST_TMPDIR/save_as_target.ini"
  flex_ini_save_as "$save_as_loc"

  flex_ini_reset

  # Original must not have the new key
  flex_ini_load "$f"
  [ "$(flex_ini_get save)" = "test" ]
  run ! flex_ini_has "save_as"

  # The save-as target must have both
  flex_ini_load "$save_as_loc" "as"
  [ "$(flex_ini_get save as)" = "test" ]
  [ "$(flex_ini_get save_as as)" = "test" ]
}

@test "save_as requires a destination path" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  run flex_ini_save_as ""

  [ "$status" -eq 1 ]
  [[ "$output" == *"required"* ]]
}

@test "save alphabetizes sections and keys within sections" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  flex_ini_update "env_prod.secret_key" "prod_secret"
  flex_ini_update "env_ci.access_key" "ci_access"
  flex_ini_update "env_prodeu.access_key" "prodeu_access"
  flex_ini_update "env_prod.access_key" "prod_access"
  flex_ini_update "env_ci.secret_key" "ci_secret"
  flex_ini_update "env_prodeu.secret_key" "prodeu_secret"
  flex_ini_save

  local expected
  expected=$(cat <<'EOF'
[env_ci]
access_key = ci_access
secret_key = ci_secret

[env_prod]
access_key = prod_access
secret_key = prod_secret

[env_prodeu]
access_key = prodeu_access
secret_key = prodeu_secret
EOF
)

  [ "$(cat "$f")" = "$expected" ]
}

@test "save writes free keys before sections" {
  local f
  f=$(create_ini)
  flex_ini_load "$f"

  flex_ini_update "zeta" "free"
  flex_ini_update "alpha.key" "sectioned"
  flex_ini_save

  local expected
  expected=$(cat <<'EOF'
zeta = free

[alpha]
key = sectioned
EOF
)

  [ "$(cat "$f")" = "$expected" ]
}

@test "save of an emptied config produces an empty file" {
  local f
  f=$(create_ini)
  printf 'only = key\n' >"$f"
  flex_ini_load "$f"

  flex_ini_delete "only"
  flex_ini_save

  [ ! -s "$f" ]
}
