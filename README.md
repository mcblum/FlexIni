# Project Description

FlexIni allows you to load, utilize, and save one or more ini files within your Bash script.
Values from the ini files are stored in an associative array and remain there until you initiate a save operation.
This library was based on the ini/config management feature provided by [Bashly](https://github.com/DannyBen/bashly).
Big thanks to Bashly for making writing Bash scripts significantly more enjoyable!

# Installation

The easiest way to "install" this is just to copy the flex_ini.sh into your project and add the line `source /path/to/flex_ini.sh` to your script to make the functionality available.

# Usage

You'll need to load an ini file and (if using multiple ini files within a script) set the ini id.
The ini id is optional, so if you're only loading one ini file or if you started with one and now need to add a second, you can have some things which omit it, which populates the default_ini array, and some that specify it, which will populate the named array.
Values can be set and read with or without sections:

```
section = nope!
email = email@email.com

[docker]
installed = false

[docker-ce]
installed = true
```

### Load one or more ini files:

```
flex_ini_load "./app/global_settings.ini" "global"
flex_ini_load "./app/tenants/big-corp/settings.ini" "big-corp"
```

### Reload a previously-loaded ini file:

```
flex_ini_reload "your_ini_id"
```

### Clear an ini id from our loaded config:

```
flex_ini_clear "your_ini_id"
```

### Get a value:

```
flex_ini_get "your.key" "your_ini_id"
```

### Check if a key exists in an array:

```
flex_ini_has "your.key" "your_ini_id"
```

### Create/update a value (and save):

```
flex_ini_update "your.key" "the value" "your_ini_id"

# Optional saving of your ini at this stage
flex_ini_save "your_ini_id"
```

Keys may not contain whitespace or `=`, and values may not contain newlines — either would corrupt the file on save, so FlexIni rejects them up front.

### Create/update several values at once (bulk update):

Unlike the other functions, the ini id comes *first* here (pass `""` for the default id), because the changes are variadic.
All pairs are validated before anything is applied, so a bad pair means no changes at all.
If `auto_save_on_changes` is enabled, the file is saved once at the end rather than once per pair.

You can pass the changes as key/value pairs:

```
flex_ini_update_bulk "your_ini_id" \
  "your.key" "the value" \
  "another.key" "another value"
```

Or, usually easier to read and harder to misalign, as the *name* of an associative array:

```
declare -A changes=(
  [your.key]="the value"
  [another.key]="another value"
)
flex_ini_update_bulk "your_ini_id" changes
```

Note that you pass the array's name (`changes`), not its contents (`"${changes[@]}"` would be treated as key/value pairs — which also works, but only until a value is empty or contains characters that confuse the pairing).

### Delete a value (and save):

```
flex_ini_delete "the.key" "your_ini_id"

# Optional saving of your ini at this stage
flex_ini_save "your_ini_id"
```

### Save your ini file:

```
flex_ini_save "your_ini_id"
```

Saving preserves the comments, blank lines, and key order of the existing file.
Updated keys are rewritten in place, new keys are appended to the end of their section, deleted keys are dropped, and brand-new sections are added alphabetically at the end of the file.
Key lines are normalized to `key = value` spacing.

### Save your ini values to a different file (save as):

```
flex_ini_save_as "/path/to/save/as/file.ini" "your_ini_id"
```

### Get the changed status of an array:

```
flex_ini_has_unsaved "your_ini_id"
```

### Reset all of the currently-loaded data (but don't delete the files):

```
flex_ini_reset
```

### Show all the values of a particular array:

```
flex_ini_show "your_ini_id"
```

### Get all the keys in an array:

```
flex_ini_keys "your_ini_id"
```

# Default Settings

If you want to override a default setting, you may change these or, probably better, change them when your script initializes after you source flex_ini.sh.

## Auto-create on load

This setting controls whether we attempt to create an ini file when it is loaded but does not-yet exist on the filesystem.
Most of the time this is probably desirable for ease of use.

```
auto_create_ini_on_load=true
```

### Auto-save on changes

This setting affects whether any change operations will also trigger a save operation.
This can be helpful in cases where you know you're going to be updating only a setting or two, but should be avoided in the case where you are going to be doing tons and tons of single updates.
If you have many values to change, pair this setting with `flex_ini_update_bulk`, which saves once at the end of the batch instead of once per change.

```
auto_save_on_changes=false
```

### Back up saved changes

This setting affects whether we make a your_settings.ini.bak file before we replace what's there.
It's not a foolproof backup system, obviously, but it can help in case something goes wrong while you're testing.

```
back_up_changes_on_save=true
```

### Back up saved changes during save-as

This setting shouldn't really, I don't think, be needed, but I still added it for transparency.
By default, the file you specify during a save-as operation isn't backed up if it already exists.

```
back_up_changes_on_save_as=false
```

### Expand values on load

By default, values are loaded exactly as they appear in the ini file — a value like `$HOME` stays the literal string `$HOME`.
If you enable this setting, shell variable references (`$VAR` and `${VAR}`) in values are expanded from the current environment on load.
Expansion is done with plain bash parameter expansion and never `eval`, so command substitutions (`$(some command)` and backticks) are left as literal text and are never executed — only variable references are substituted. Undefined variables expand to an empty string.

```
expand_values_on_load=false
```

### Reassign file permissions when possible

Sometimes you might need to run FlexIni as root but you may want to keep the file permissions of the ini the same.
Update this to true to make the script attempt to re-assign the original owner/group.

```
reassign_file_permissions_when_possible=false
```

### Temp Directory

This allows you to override the directory used to store the temp files we make before saving.

```
tmp_directory="/tmp"
```

# Requirements

FlexIni requires bash 4.0 or higher (it uses associative arrays).
macOS ships with bash 3.2, so on a Mac you'll want `brew install bash` first.

# Testing

The test suite uses [bats-core](https://github.com/bats-core/bats-core) (1.5.0+) and runs in GitHub Actions on both Ubuntu and macOS, alongside a [shellcheck](https://www.shellcheck.net/) (0.10+) lint job.
To run both locally:

```
# Install the tools first, e.g.:
brew install bats-core shellcheck   # macOS

bats tests
shellcheck flex_ini.sh tests/test_helper.bash tests/*.bats
```
