# Shared setup for all bats test files.
#
# Each .bats file calls `common_setup` from its setup() function. Every
# bats test runs in its own process, so sourcing flex_ini.sh here gives
# each test a clean, isolated FlexIni state.

common_setup() {
  FLEXINI_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$FLEXINI_ROOT/flex_ini.sh"
}

# Create an empty ini file inside the auto-cleaned bats tmp dir and
# echo its path.
create_ini() {
  local name="${1:-test}"
  local path="$BATS_TEST_TMPDIR/${name}.ini"
  touch "$path"
  echo "$path"
}

# Echo the octal mode of a file, portable across macOS and Linux.
file_mode() {
  local path="$1"
  if [ "$(uname)" == "Darwin" ]; then
    stat -f '%Lp' "$path"
  else
    stat --format '%a' "$path"
  fi
}
