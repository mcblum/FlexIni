# FlexIni — Agent Guide

FlexIni is a **single-file bash library** (`flex_ini.sh`) for loading, reading,
editing, and saving INI files from bash scripts. There is no build step, no
package manager, and no other source file. Consumers `source flex_ini.sh` and
call the public functions.

## Repository layout

| Path | Purpose |
|------|---------|
| `flex_ini.sh` | The entire library. All changes to behavior happen here. |
| `tests/*.bats` | Test suite ([bats-core](https://github.com/bats-core/bats-core), one file per public function/feature). |
| `tests/test_helper.bash` | Shared test setup (`common_setup`, `create_ini`, `file_mode`). |
| `tests/.shellcheckrc` | Shellcheck disables that only apply to the test files. |
| `.github/workflows/test.yml` | CI: bats on Ubuntu + macOS, plus a shellcheck job. |

## Commands

```bash
# Run the full test suite (required before considering any change done)
bats tests

# Run one file / one test
bats tests/save.bats
bats tests/save.bats --filter "permissions"

# Lint (CI enforces a clean run; shellcheck must be 0.10+ for .bats support)
shellcheck flex_ini.sh tests/test_helper.bash tests/*.bats

# Syntax-only sanity check
bash -n flex_ini.sh
```

On macOS, everything must run under Homebrew bash (5.x), **not** the system
`/bin/bash` (3.2). The library requires bash **4.0+** and must keep working on
bash 4.2 (CentOS 7) — so **namerefs (`local -n`, bash 4.3+) are not allowed**.

## How the library works (read before editing)

### State model

- Each loaded INI file gets an id (the "ini id"); omitting it means `default`.
- `private_flex_ini_format_id` sanitizes ids: every character outside
  `[a-zA-Z0-9_]` becomes `_`, and a leading digit gets a `_` prefix.
  Example: `big-corp.settings/v2` → `big_corp_settings_v2`.
- Values live in a **dynamically named global associative array** per id,
  named `<formatted_id>_ini` (e.g. `default_ini`). Section keys are stored
  flat as `section.key`; keys with no section are stored as-is ("free keys").
- Three bookkeeping globals map formatted ids to metadata:
  `ini_associations` (id → file path), `ini_loaded` (id → "true"),
  `ini_unsaved_changes` (id → "true"/"false").
- User-tunable settings are plain globals near the top of the file
  (`auto_create_ini_on_load`, `auto_save_on_changes`, `back_up_changes_on_save`,
  `back_up_changes_on_save_as`, `reassign_file_permissions_when_possible`,
  `expand_values_on_load`, `tmp_directory`).

### CRITICAL: eval safety rules

Because array names are dynamic, some operations must use `eval`. **Never
interpolate a key or value into an eval'd string.** Keys and values must only
ever reach `eval` as *variable references* (`\$key`, `\$value`) so their
contents are expanded once by the shell and never parsed as code:

```bash
# CORRECT — the eval'd text is literally: default_ini[$key]="$value"
eval "${array_name}[\$key]=\"\$value\""

# CORRECT — subscript in single quotes is expanded by unset itself
unset -v "${array_name}"'[$key]'

# WRONG — value/key contents get parsed as shell code (command injection)
eval "${array_name}[\"$key\"]=\"$value\""
```

Use the existing helpers (`private_flex_ini_set`, and the patterns in
`flex_ini_get` / `flex_ini_has` / `flex_ini_keys`) instead of writing new eval
expressions. There are regression tests that feed `$(...)`, backticks, quotes,
and globs through every path — they must stay literal.

When `expand_values_on_load=true` (default `false`), values containing `$`
have their variable references (`$VAR`/`${VAR}`) expanded on load by
`private_flex_ini_expand_value`. That helper uses plain bash parameter
expansion (indirect `${!name}`) and deliberately **never** `eval`s the value:
command substitution (`$(...)`, backticks) and every other shell construct are
left as literal text and cannot execute. Do not "simplify" this back into
`eval "value=\"$value\""` — that reintroduces a command-injection sink
(CWE-78/CWE-95) on any untrusted ini file.

Two related rules when a *caller-supplied name* (not a key/value) must be
interpolated into an eval expression, as in `flex_ini_update_bulk`'s
associative-array form:

1. Validate the name as a plain identifier first
   (`private_flex_ini_is_assoc_array` does this) — otherwise the name itself
   is an injection vector.
2. Because bash scoping is dynamic, locals in the reading function can shadow
   the caller's array (a local named `pairs` would hide a caller array named
   `pairs`). Functions that read caller-named variables must prefix all their
   locals (`_flexini_*`).

### Input constraints (enforced, do not relax)

- Keys: no whitespace, no `=` (`private_flex_ini_validate_key`).
- Values: no newlines (`private_flex_ini_validate_value`).
- Both rules exist because violating them corrupts the save/load round trip.

### Parsing (flex_ini_load)

- Shared regexes live in the `_FLEXINI_*_REGEX` globals — load and save must
  keep using the same ones or files will parse differently than they render.
- Comments start with `;` or `#`. Lines may be indented. Trailing whitespace
  is trimmed from values. The read loop uses `|| [ -n "$line" ]` to keep a
  final line that has no trailing newline — do not remove that.

### Saving (flex_ini_save) — layout preservation

Save does **not** regenerate the file from scratch. It walks the previously
saved file as a *layout template* and preserves comments, blank lines, unknown
lines, and key order:

- Existing keys are rewritten in place (normalized to `key = value`).
- Keys deleted from memory are dropped from the output.
- New keys are appended at the end of their section (blank lines at a section
  boundary are held back via `pending_blanks` so appended keys land before
  them).
- Brand-new sections are appended alphabetically at the end of the file.
- The template is always the file *associated with the id* — so `save_as`
  copies inherit the original's comments.
- The rendered temp file replaces the destination with `mv`; the destination's
  original permission mode is captured first and restored after.

Two save helpers (`private_flex_ini_save_flush_blanks`,
`private_flex_ini_save_append_section`) intentionally rely on **bash dynamic
scoping**: they read/modify the caller's `pending_blanks`, `unwritten`,
`ini_file`, and `ini_identifier` locals. If you rename those locals in
`flex_ini_save`, the helpers break silently.

### Error handling conventions

- All errors go through `private_flex_ini_error`, warnings through
  `private_flex_ini_warning` — both write to **stderr** (stdout is reserved
  for data, since callers use `$(flex_ini_get ...)`).
- Public functions return `1` on failure, `0` on success. Never `exit` from
  library code (it runs in the caller's shell).
- Assign command substitutions separately from `local` declarations
  (`local x; x=$(...) || return 1`) so failures are not masked — shellcheck
  SC2155 enforces this.

## Testing conventions

- Framework: bats-core, minimum 1.5.0 (`run --separate-stderr` and `run !`).
- Every `.bats` file starts with `setup() { load test_helper; common_setup; }`.
  Each test runs in its own process, so sourcing `flex_ini.sh` per test gives
  clean state — never share state between tests.
- Create files with `create_ini` (uses `BATS_TEST_TMPDIR`, auto-cleaned).
- **Never use a bare `! command` assertion mid-test** — in bats it does not
  fail the test. Use `run ! command` instead (shellcheck SC2314 catches this).
- Mutating calls (`flex_ini_update`, `flex_ini_load`, ...) must be called
  directly when later assertions depend on their state; `run` executes in a
  subshell and discards state changes. Use `run` only to assert on
  status/output.
- New behavior requires tests, including a negative/error-path case.

## Things that look wrong but are intentional

- `eval` usage: safe by the pattern rules above; do not "clean it up" into
  namerefs (breaks bash < 4.3).
- Dynamic scoping in the save helpers (documented in their comments).
- `flex_ini_clear` leaves `ini_associations` intact — `flex_ini_reload`
  depends on the association surviving a clear.
- `tests/.shellcheckrc` disables SC2034/SC2154/SC2016/SC1091 for test files
  only (settings globals are defined in `flex_ini.sh`, which shellcheck cannot
  see when checking a `.bats` file standalone).
