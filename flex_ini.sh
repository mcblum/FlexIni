#!/bin/bash
# FlexIni - A flexible INI file parser and manager for Bash
# 
# Copyright 2026 Matt Blum
# Licensed under the Apache License, Version 2.0
# https://www.apache.org/licenses/LICENSE-2.0
#
# Author: Matt Blum
# GitHub: https://github.com/mcblum
# Email:  matt@mattblum.com
#
# For full license text, see the LICENSE file in the repository.

# Defaults
# --
# You may change these here or overwrite them
# within your scripts, whatever works best for
# your use case.
auto_create_ini_on_load=true
auto_save_on_changes=false
back_up_changes_on_save=true
back_up_changes_on_save_as=false
reassign_file_permissions_when_possible=false
# When true, shell variable references ($VAR and ${VAR}) in values are
# expanded on load from the current environment. Expansion is done with
# plain bash parameter expansion, never eval, so command substitution and
# backticks (e.g. "$(some command)" or `some command`) are left as literal
# text and can never be executed. Undefined variables expand to nothing.
expand_values_on_load=false
tmp_directory="/tmp"
# Detect the operating system
if [[ "$(uname)" == "Darwin" ]]; then
    _OS="macos"
elif [[ "$(uname)" == "Linux" ]]; then
    _OS="linux"
else
    _OS="unknown"
fi

# Require bash 4.0+ for associative arrays
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "Error: FlexIni requires bash 4.0 or higher for associative arrays"
    echo "Current bash version: ${BASH_VERSION}"
    echo "On macOS, install newer bash with: brew install bash"
    # The 'return' works when this file is sourced; the 'exit' is the
    # fallback when it is executed directly.
    # shellcheck disable=SC2317
    return 1 2>/dev/null || exit 1
fi

declare -gA ini_associations
declare -gA ini_unsaved_changes
declare -gA ini_loaded
# Line-format patterns shared by the load parser and the save renderer
_FLEXINI_SECTION_REGEX="^[[:space:]]*\[(.+)\][[:space:]]*$"
_FLEXINI_KEY_REGEX="^[[:space:]]*([^=[:space:]]+)[[:space:]]*=[[:space:]]*(.*)$"
_FLEXINI_COMMENT_REGEX="^[[:space:]]*[;#]"
_FLEXINI_BLANK_REGEX="^[[:space:]]*$"
# Private Functions
# --
# It's best to not call/modify these directly from your codebase
# unless you know what you're doing!
# @private private_flex_ini_error
# --
# Helper method to write consistent error logs
private_flex_ini_error() {
  local msg="$1"
  echo "[ FlexIni Error ] $msg" >&2
}
# @private private_flex_ini_warning
# --
# Helper method to write consistent warning logs
private_flex_ini_warning() {
  local msg="$1"
  echo "[ FlexIni Warning ] $msg" >&2
}
# @private private_flex_ini_mark_as_changed
# --
# Marks an ini array as changed.
private_flex_ini_mark_as_changed() {
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$1")
  ini_unsaved_changes["$ini_identifier"]=true
}
# @private private_flex_ini_mark_as_unchanged
# --
# Marks an ini array as unchanged.
private_flex_ini_mark_as_unchanged() {
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$1")
  ini_unsaved_changes["$ini_identifier"]=false
}
# @private private_flex_ini_required
# --
# Helper function to identify required variables and return 1
# if they are not provided.
private_flex_ini_required() {
  local k="$1"
  local v="$2"
  if [ -z "$v" ]; then
    private_flex_ini_error "value $k is required but was not provided"
    return 1
  fi
}
# @private private_flex_ini_require_loaded
# --
# Function which returns 1 if the ini id has not
# yet beenloaded.
private_flex_ini_require_loaded() {
  local ini_identifier="$1"
  if ! private_flex_ini_has_been_loaded "$ini_identifier"; then
    private_flex_ini_error "the ini id $ini_identifier has not-yet been loaded"
    return 1
  fi
}
# @private private_flex_ini_mark_as_loaded
# --
# Marks an ini array as already loaded.
private_flex_ini_mark_as_loaded() {
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$1")
  ini_loaded["$ini_identifier"]=true
}
# @private private_flex_ini_has_been_loaded
# --
# Returns 0 if the array has already been loaded,
# returns 1 if it has not.
private_flex_ini_has_been_loaded() {
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$1")
  local loaded="${ini_loaded[$ini_identifier]}"
  
  if [ "$loaded" == "true" ]; then
    return 0
  else
    return 1
  fi
}
# @private private_flex_ini_format_id
# --
# Format the supplied ini id to make sure it's
# compatible with naming an array.
private_flex_ini_format_id() {
  local default_ini_array_name="default"
  local ini_identifier="${1:-$default_ini_array_name}"
  local formatted="${ini_identifier//[^a-zA-Z0-9_]/_}"
  # An id starting with a digit would produce an invalid variable name
  [[ $formatted == [0-9]* ]] && formatted="_${formatted}"
  echo "$formatted"
}
# @private private_flex_ini_get_array_name
# --
# Get the name of the array based on the ini id.
private_flex_ini_get_array_name() {
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$1")
  local ini_name="${ini_identifier}_ini"
  echo "$ini_name"
}
# @private private_get_ini_file_path
# --
# Get the file path for a specific ini id.
private_get_ini_file_path() {
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$1")
  local FILE_PATH="${ini_associations[$ini_identifier]}"
  if [ -z "$FILE_PATH" ]; then
    private_flex_ini_error "no file associated with the ini id ${ini_identifier}"
    return 1
  fi
  echo "${FILE_PATH}"
}
# @private private_flex_ini_init
# --
# Initialize an ini file and load it into its array. This
# function must be called initially so that we have an array
# loaded when you try to reference a particular id.
private_flex_ini_init() {
  local ini_file="$1"
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$2")
  local ini
  ini=$(private_flex_ini_get_array_name "$ini_identifier")
  declare -gA "$ini"
  ini_associations["$ini_identifier"]="$ini_file"
}
# @private private_flex_ini_create
# --
# Create an ini file at the specified path.
private_flex_ini_create() {
  local ini_file="$1"

  private_flex_ini_required "ini_file" "$ini_file" || return 1
  touch "$ini_file" || return 1
}
# @private private_flex_ini_expand_value
# --
# Expand shell variable references ($VAR and ${VAR}) in a value using the
# current environment. This deliberately does NOT use eval or command
# substitution: command substitutions ($(...) and backticks) and every
# other shell construct are left untouched as literal text, so a value
# from an untrusted ini file can never be executed as code. Undefined
# variables expand to the empty string, matching normal shell behavior.
# The expanded value is written to the global _flexini_expanded.
private_flex_ini_expand_value() {
  local _value="$1"
  local _out=""
  local _rest="$_value"
  # Only referenced variable NAMES are ever substituted; the value's own
  # characters are never re-parsed by the shell.
  local _re='^([^$]*)[$]([{]([a-zA-Z_][a-zA-Z0-9_]*)[}]|([a-zA-Z_][a-zA-Z0-9_]*))(.*)$'
  while [[ $_rest =~ $_re ]]; do
    local _prefix="${BASH_REMATCH[1]}"
    local _braced_name="${BASH_REMATCH[3]}"
    local _bare_name="${BASH_REMATCH[4]}"
    local _tail="${BASH_REMATCH[5]}"
    local _name="${_braced_name:-$_bare_name}"
    # Indirect expansion by name only -- the referenced variable's own
    # contents are never interpreted, only substituted in as data.
    _out+="${_prefix}${!_name-}"
    _rest="$_tail"
  done
  # A bare '$' not forming a valid reference (and any trailing text) is
  # kept verbatim.
  _flexini_expanded="${_out}${_rest}"
}
# @private private_flex_ini_set
# --
# Assign a value to a key inside the named associative array.
# The key and value are passed to eval as variable references (never
# interpolated into the evaluated string) so their contents cannot be
# executed as code.
private_flex_ini_set() {
  local array_name="$1"
  local key="$2"
  local value="$3"
  eval "${array_name}[\$key]=\"\$value\""
}
# @private private_flex_ini_validate_key
# --
# Keys containing whitespace or '=' cannot survive a save/load
# round-trip, so reject them up front.
private_flex_ini_validate_key() {
  local key="$1"
  if [[ $key =~ [=[:space:]] ]]; then
    private_flex_ini_error "the key '$key' is invalid: keys may not contain whitespace or '='"
    return 1
  fi
}
# @private private_flex_ini_validate_value
# --
# Values containing newlines would corrupt the ini file on save,
# so reject them up front.
private_flex_ini_validate_value() {
  local value="$1"
  if [[ $value == *$'\n'* ]]; then
    private_flex_ini_error "values may not contain newline characters"
    return 1
  fi
}
# @private private_flex_ini_save_flush_blanks
# --
# Write out blank lines that were held back while rendering a save.
# Relies on bash dynamic scoping: reads/updates the caller's
# pending_blanks and ini_file locals.
private_flex_ini_save_flush_blanks() {
  while [ "$pending_blanks" -gt 0 ]; do
    echo >>"$ini_file"
    pending_blanks=$((pending_blanks - 1))
  done
}
# @private private_flex_ini_save_append_section
# --
# Append the still-unwritten keys belonging to the given section
# ('' means the free keys that live above any section header).
# Relies on bash dynamic scoping: reads/updates the caller's
# unwritten, ini_file, and ini_identifier locals.
private_flex_ini_save_append_section() {
  local target_section="$1"
  local matching=()
  local k
  for k in "${!unwritten[@]}"; do
    if [ -z "$target_section" ]; then
      [[ $k == *.* ]] && continue
    else
      [[ $k == "$target_section".* ]] || continue
    fi
    matching+=("$k")
  done
  [ "${#matching[@]}" -gt 0 ] || return 0
  readarray -t matching < <(printf '%s\n' "${matching[@]}" | sort)
  local key_name
  for k in "${matching[@]}"; do
    key_name="$k"
    [ -n "$target_section" ] && key_name="${k#"$target_section".}"
    echo "$key_name = $(flex_ini_get "$k" "$ini_identifier")" >>"$ini_file"
    unset -v 'unwritten[$k]'
  done
}
# Public Functions
# --
# These functions are the ones you want to call from your scripts
# since they are meant to work together and validate various items.
# @public flex_ini_load
# --
# You'll need to call this method first in order to load up your
# current values in your ini file and populate the array.
flex_ini_load() {
  local ini_file="$1"
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$2")
  local force_reload="${3:-false}"
  if [ "$force_reload" != "true" ] && private_flex_ini_has_been_loaded "$ini_identifier"; then
    local already_loaded_path="${ini_associations[$ini_identifier]}"
    if [ -n "$already_loaded_path" ] && [ "$already_loaded_path" != "$ini_file" ]; then
      private_flex_ini_warning "the ini id ${ini_identifier} is already loaded from ${already_loaded_path}; ignoring request to load ${ini_file}. Pass force_reload=true or use a different id."
    fi
    return 0
  fi
  if [ "$force_reload" == "true" ] && private_flex_ini_has_been_loaded "$ini_identifier"; then
    flex_ini_clear "$ini_identifier"
  fi
  if [ ! -f "$ini_file" ]; then
    if [ "$auto_create_ini_on_load" == "true" ]; then
      if ! private_flex_ini_create "$ini_file"; then
        private_flex_ini_error "ini file could not be auto-created at ${ini_file}"
        return 1  
      fi
    else  
      private_flex_ini_error "ini file not found at ${ini_file} and auto_create_ini_on_load was not 'true' so we did not try to create it"
      return 1
    fi
  fi
  private_flex_ini_init "$ini_file" "$ini_identifier"
  local ini
  ini=$(private_flex_ini_get_array_name "$ini_identifier")
  local section=""
  local key=""
  local value=""
  local line=""
  # The '|| [ -n "$line" ]' keeps the final line even when the file
  # has no trailing newline.
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ $_FLEXINI_COMMENT_REGEX ]]; then
      continue
    elif [[ $line =~ $_FLEXINI_SECTION_REGEX ]]; then
      section="${BASH_REMATCH[1]}."
    elif [[ $line =~ $_FLEXINI_KEY_REGEX ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      # trim trailing whitespace from the value
      value="${value%"${value##*[![:space:]]}"}"
      if [ "$expand_values_on_load" == "true" ] && [[ $value == *\$* ]]; then
        # Safe, eval-free variable expansion: command substitution and
        # backticks are left as literal text (see the helper).
        local _flexini_expanded=""
        private_flex_ini_expand_value "$value"
        value="$_flexini_expanded"
      fi
      private_flex_ini_set "$ini" "${section}${key}" "$value"
    fi
  done <"$ini_file"
  private_flex_ini_mark_as_unchanged "$ini_identifier"
  private_flex_ini_mark_as_loaded "$ini_identifier"
}
# @public flex_ini_reload
# --
# Reload an already-loaded ini ID. Please note, if you have not, in
# fact, already loaded the ini ID, this function will fail.
flex_ini_reload() {
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$1")
  local destination_ini_path
  if ! destination_ini_path=$(private_get_ini_file_path "$ini_identifier"); then
    private_flex_ini_error "No INI filepath could be found from which to reload. Are you sure you loaded the config file for ${ini_identifier}?"
    return 1
  fi
  flex_ini_clear "$ini_identifier" || return 1
  flex_ini_load "$destination_ini_path" "$ini_identifier"
}
# @public flex_ini_clear
# -- 
# Clears an ini ID completely from our loaded configs. You
# probably shouldn't need to use this, but it could be helpful
# during debugging.
flex_ini_clear() {
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$1")
  private_flex_ini_require_loaded "$ini_identifier" || return 1
  unset -v 'ini_unsaved_changes[$ini_identifier]'
  unset -v 'ini_loaded[$ini_identifier]'
  local current_array_name
  current_array_name=$(private_flex_ini_get_array_name "$ini_identifier")
  unset "$current_array_name"
}
# @public flex_ini_get
# --
# Fetches a value from the specified ini array.
flex_ini_get() {
  local key="$1"
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$2")
  local array_name
  array_name=$(private_flex_ini_get_array_name "$ini_identifier")
  private_flex_ini_required "key" "$key" || return 1
  local value=""
  eval "value=\"\${${array_name}[\$key]-}\""
  echo "$value"
}
# @public flex_ini_has
# --
# Returns 0 if the key exists, 1 if it does not.
flex_ini_has() {
  local key="$1"
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$2")
  local array_name
  array_name=$(private_flex_ini_get_array_name "$ini_identifier")
  private_flex_ini_required "key" "$key" || return 1
  private_flex_ini_require_loaded "$ini_identifier" || return 1
  local is_set=""
  eval "is_set=\${${array_name}[\$key]+x}"
  [ -n "$is_set" ]
}
# @public flex_ini_update
# --
# This creates or updates a value in your ini array.
# Note: this does not save it, you'll need to call
# that separately.
flex_ini_update() {
  local key="$1"
  local value="$2"
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$3")
  local array_name
  array_name=$(private_flex_ini_get_array_name "$ini_identifier")
  private_flex_ini_required "key" "$key" || return 1
  private_flex_ini_require_loaded "$ini_identifier" || return 1
  private_flex_ini_validate_key "$key" || return 1
  private_flex_ini_validate_value "$value" || return 1
  private_flex_ini_set "$array_name" "$key" "$value" || return 1
  if [ "$auto_save_on_changes" == "true" ]; then
    flex_ini_save "$ini_identifier"
  else
    private_flex_ini_mark_as_changed "$ini_identifier"
  fi
}
# @private private_flex_ini_is_assoc_array
# --
# Returns 0 if the given name refers to a declared associative array.
# The name must be a plain identifier -- that check is also what makes
# it safe to interpolate the name into an eval expression afterward.
# Locals here are _flexini_-prefixed so they cannot shadow a caller's
# array of the same name (bash scoping is dynamic).
private_flex_ini_is_assoc_array() {
  local _flexini_name="$1"
  [[ $_flexini_name =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 1
  local _flexini_declaration
  _flexini_declaration=$(declare -p "$_flexini_name" 2>/dev/null) || return 1
  [[ $_flexini_declaration == "declare -A"* ]]
}
# @public flex_ini_update_bulk
# --
# Create or update several values in a single call. Unlike the other
# public functions, the ini id comes FIRST (pass '' for the default id).
# The changes can be supplied either as variadic key/value pairs or as
# the NAME of an associative array holding key -> value entries:
#
#   flex_ini_update_bulk "my_id" key1 value1 key2 value2 ...
#
#   declare -A changes=([key1]="value1" [section.key2]="value2")
#   flex_ini_update_bulk "my_id" changes
#
# Every key and value is validated before anything is applied, so a bad
# pair means no changes are made at all. When auto_save_on_changes is
# enabled, the file is saved once at the end instead of once per pair.
#
# Locals are _flexini_-prefixed because bash scoping is dynamic: an
# unprefixed local like 'pairs' would shadow a caller's array of the
# same name and make it unreadable here.
flex_ini_update_bulk() {
  local _flexini_ini_identifier
  _flexini_ini_identifier=$(private_flex_ini_format_id "$1")
  shift
  local _flexini_array_name
  _flexini_array_name=$(private_flex_ini_get_array_name "$_flexini_ini_identifier")
  private_flex_ini_require_loaded "$_flexini_ini_identifier" || return 1
  if [ "$#" -eq 0 ]; then
    private_flex_ini_error "at least one key/value pair (or the name of an associative array) is required"
    return 1
  fi
  local _flexini_pairs=()
  if [ "$#" -eq 1 ]; then
    # A single argument is the name of an associative array of changes
    local _flexini_source="$1"
    if ! private_flex_ini_is_assoc_array "$_flexini_source"; then
      private_flex_ini_error "bulk update expects key/value pairs or the name of an associative array, but '$_flexini_source' is not a declared associative array"
      return 1
    fi
    local _flexini_source_keys=()
    # _flexini_source is validated as a plain identifier above, so it
    # is safe to interpolate; keys and values still only travel through
    # eval as variable references.
    eval "_flexini_source_keys=(\"\${!${_flexini_source}[@]}\")"
    if [ "${#_flexini_source_keys[@]}" -eq 0 ]; then
      private_flex_ini_error "the associative array '$_flexini_source' has no entries"
      return 1
    fi
    local _flexini_k
    local _flexini_v
    for _flexini_k in "${_flexini_source_keys[@]}"; do
      eval "_flexini_v=\"\${${_flexini_source}[\$_flexini_k]-}\""
      _flexini_pairs+=("$_flexini_k" "$_flexini_v")
    done
  else
    if [ $(($# % 2)) -ne 0 ]; then
      private_flex_ini_error "bulk update expects key/value pairs, but received an odd number of arguments ($#)"
      return 1
    fi
    _flexini_pairs=("$@")
  fi
  local _flexini_i
  # Validate everything up front so a bad pair means nothing is applied
  for ((_flexini_i = 0; _flexini_i < ${#_flexini_pairs[@]}; _flexini_i += 2)); do
    private_flex_ini_required "key" "${_flexini_pairs[_flexini_i]}" || return 1
    private_flex_ini_validate_key "${_flexini_pairs[_flexini_i]}" || return 1
    private_flex_ini_validate_value "${_flexini_pairs[_flexini_i + 1]}" || return 1
  done
  for ((_flexini_i = 0; _flexini_i < ${#_flexini_pairs[@]}; _flexini_i += 2)); do
    private_flex_ini_set "$_flexini_array_name" "${_flexini_pairs[_flexini_i]}" "${_flexini_pairs[_flexini_i + 1]}" || return 1
  done
  if [ "$auto_save_on_changes" == "true" ]; then
    flex_ini_save "$_flexini_ini_identifier"
  else
    private_flex_ini_mark_as_changed "$_flexini_ini_identifier"
  fi
}
# @public flex_ini_delete
# --
# Remove a value from your ini array.
# Note: this does not save it, you'll need to call
# that separately.
flex_ini_delete() {
  local key="$1"
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$2")
  private_flex_ini_required "key" "$key" || return 1
  private_flex_ini_require_loaded "$ini_identifier" || return 1
  local array_name
  array_name=$(private_flex_ini_get_array_name "$ini_identifier")
  # The single-quoted subscript is expanded by unset itself, so the
  # key's contents are never parsed as code.
  unset -v "${array_name}"'[$key]'
  if [ "$auto_save_on_changes" == "true" ]; then
    flex_ini_save "$ini_identifier"
  else
    private_flex_ini_mark_as_changed "$ini_identifier"
  fi
}
# @public flex_ini_save
# --
# Save the values in the array back to the correct file.
# If using the file you specified when you loaded the ini
# config.
flex_ini_save() {
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$1")
  local override_path="$2"
  private_flex_ini_require_loaded "$ini_identifier" || return 1
  local default_destination_ini_path
  default_destination_ini_path=$(private_get_ini_file_path "$ini_identifier") || return 1
  # The save-as logic path first
  if [ -n "$override_path" ]; then
    # pre-create the file if it doesn't exist just to make sure we
    # are actually able to create a file there.
    if [ ! -f "$override_path" ]; then
      if ! touch "$override_path"; then
        private_flex_ini_error "unable to create file specified at $override_path"
        return 1
      fi
    fi
    # set the destination ini path to whichever new path was specified
    local destination_ini_path="$override_path"
    # use the val from 'save as' to determine whether to back up
    local should_back_up_before_save="${back_up_changes_on_save_as}"
    local is_save_as_operation=true
  else
    # set the destination ini path to the one specified on load
    local destination_ini_path="$default_destination_ini_path"
    # use the val from 'save' to determine whether to back up
    local should_back_up_before_save="${back_up_changes_on_save}"
    local is_save_as_operation=false
  fi
  # If param is true, then fetch the user/group from the current ini
  # file and attempt to re-assign ownership when file is saved if
  # the current user is different from the owner of the file
  local file_owner=""
  local file_group=""
  local should_reassign_file_permissions=false
  if [ "$reassign_file_permissions_when_possible" == "true" ]; then
    if [ "$_OS" == "macos" ]; then
      file_owner=$(stat -f '%Su' "${destination_ini_path}")
      file_group=$(stat -f '%Sg' "${destination_ini_path}")
    elif [ "$_OS" == "linux" ]; then
      file_owner=$(stat --format '%U' "${destination_ini_path}")
      file_group=$(stat --format '%G' "${destination_ini_path}")
    else
      private_flex_ini_warning "File permission reassignment not supported on $_OS"
    fi
    local current_user="${USER:-$(id -un)}"
    if [ -n "$file_owner" ] && [ "$file_owner" != "$current_user" ]; then
      should_reassign_file_permissions=true
    fi
  fi
  # Capture the destination file's mode so we can restore it after the
  # save (mktemp creates the replacement file with 0600 permissions).
  local original_mode=""
  if [ -f "$destination_ini_path" ]; then
    if [ "$_OS" == "macos" ]; then
      original_mode=$(stat -f '%Lp' "$destination_ini_path")
    elif [ "$_OS" == "linux" ]; then
      original_mode=$(stat --format '%a' "$destination_ini_path")
    fi
  fi
  local ini_file
  if ! ini_file=$(mktemp "${tmp_directory}/flexini.XXXXXX"); then
    private_flex_ini_error "could not create a temp file in ${tmp_directory}"
    return 1
  fi
  # Track which in-memory keys still need to be written. Keys that
  # appear in the layout template are rewritten in place; the rest are
  # appended to their section (or to brand-new sections at the end).
  local all_keys=()
  readarray -t all_keys < <(flex_ini_keys "$ini_identifier")
  local -A unwritten=()
  local key
  for key in "${all_keys[@]}"; do
    unwritten["$key"]=1
  done
  # Walk the previously-saved file (if any) so comments, blank lines,
  # unknown lines, and key order are preserved. The file associated
  # with this id is used as the layout template even during save-as,
  # so copies keep their comments too.
  local template_path="$default_destination_ini_path"
  local current_section=""
  local pending_blanks=0
  local line=""
  if [ -f "$template_path" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ $line =~ $_FLEXINI_BLANK_REGEX ]]; then
        # Held back so keys appended to a section land before the
        # section's trailing blank line(s)
        pending_blanks=$((pending_blanks + 1))
      elif [[ $line =~ $_FLEXINI_COMMENT_REGEX ]]; then
        private_flex_ini_save_flush_blanks
        echo "$line" >>"$ini_file"
      elif [[ $line =~ $_FLEXINI_SECTION_REGEX ]]; then
        local next_section="${BASH_REMATCH[1]}"
        # Leaving the current section: append its new keys first
        private_flex_ini_save_append_section "$current_section"
        private_flex_ini_save_flush_blanks
        echo "$line" >>"$ini_file"
        current_section="$next_section"
      elif [[ $line =~ $_FLEXINI_KEY_REGEX ]]; then
        key="${BASH_REMATCH[1]}"
        local qualified_key="$key"
        [ -n "$current_section" ] && qualified_key="${current_section}.${key}"
        if [ -n "${unwritten[$qualified_key]-}" ]; then
          private_flex_ini_save_flush_blanks
          echo "$key = $(flex_ini_get "$qualified_key" "$ini_identifier")" >>"$ini_file"
          unset -v 'unwritten[$qualified_key]'
        fi
        # Keys deleted from memory (or duplicated in the file) are dropped
      else
        # Unrecognized line: preserve it as-is
        private_flex_ini_save_flush_blanks
        echo "$line" >>"$ini_file"
      fi
    done <"$template_path"
  fi
  # Append any new keys belonging to the template's final section (or
  # to the free-key area when the template had no sections at all),
  # then restore the template's trailing blank lines.
  private_flex_ini_save_append_section "$current_section"
  private_flex_ini_save_flush_blanks
  # Whatever is left belongs to brand-new sections; write those in
  # alphabetical order with their keys sorted.
  local -A sections=()
  local section_name
  local key_name
  for key in "${!unwritten[@]}"; do
    [[ $key == *.* ]] || continue
    IFS="." read -r section_name key_name <<<"$key"
    sections["$section_name"]=1
  done
  local sorted_sections=()
  if [ "${#sections[@]}" -gt 0 ]; then
    readarray -t sorted_sections < <(printf '%s\n' "${!sections[@]}" | sort)
  fi
  for section_name in "${sorted_sections[@]}"; do
    [ -s "$ini_file" ] && echo >>"$ini_file"
    echo "[$section_name]" >>"$ini_file"
    private_flex_ini_save_append_section "$section_name"
  done
  # Back up the destination ini file if specified
  if [ "$should_back_up_before_save" == "true" ] && [ -f "$destination_ini_path" ]; then
    cp -f "$destination_ini_path" "${destination_ini_path}.bak" ||
      private_flex_ini_error "could not make the backup copy of the ini file at ${destination_ini_path}"
  fi
  # Replace the destination ini file with the tmp file
  if ! mv -f "$ini_file" "$destination_ini_path"; then
    private_flex_ini_error "could not move tmp ini file to its destination at ${destination_ini_path} -- data was not saved to disk"
    rm -f "$ini_file"
    return 1
  fi
  # Restore the destination file's original mode
  if [ -n "$original_mode" ]; then
    chmod "$original_mode" "$destination_ini_path" ||
      private_flex_ini_error "could not restore mode ${original_mode} on ${destination_ini_path}"
  fi
  # Try to update the permissions of the file, if set
  if [ "$should_reassign_file_permissions" == "true" ]; then
    chown "${file_owner}":"${file_group}" "${destination_ini_path}" ||
      private_flex_ini_error "our attempt to reassign file permissions to '${file_owner}:${file_group}' failed for file at ${destination_ini_path}"
  fi
  # Only mark the ini as unchanged if we saved it to
  # the original file.
  if [ "$is_save_as_operation" != "true" ]; then
    private_flex_ini_mark_as_unchanged "$ini_identifier"
  fi
}
# @public flex_ini_save_as
# --
# A helper function to initiate a save-as.
flex_ini_save_as() {
  local override_path="$1"
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$2")
  private_flex_ini_required "override_path" "$override_path" || return 1
  private_flex_ini_require_loaded "$ini_identifier" || return 1
  flex_ini_save "$ini_identifier" "$override_path" || return 1
}
# @public flex_ini_has_unsaved
# --
# Returns 0 if the array has unsaved changes,
# returns 1 if it does not.
flex_ini_has_unsaved() {
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$1")
  
  private_flex_ini_require_loaded "$ini_identifier" || return 1
  local has_unsaved="${ini_unsaved_changes["$ini_identifier"]}"
  if [ "$has_unsaved" == "true" ]; then
    return 0
  else
    return 1
  fi
}
# @public flex_ini_reset
# --
# Removes all data from the stores. Be careful with this one!
flex_ini_reset() {
  for i in "${!ini_associations[@]}"; do
    local array_name
    array_name=$(private_flex_ini_get_array_name "$i")
    unset "$array_name"
    unset -v 'ini_associations[$i]'
  done
  for i in "${!ini_unsaved_changes[@]}"; do
    unset -v 'ini_unsaved_changes[$i]'
  done
  for i in "${!ini_loaded[@]}"; do
    unset -v 'ini_loaded[$i]'
  done
}
# @public flex_ini_show
# --
# Show all loaded key-value pairs (whether or not they've been saved).
flex_ini_show() {
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$1")
  private_flex_ini_require_loaded "$ini_identifier" || return 1
  echo "[ ${ini_identifier} ]"
  echo "--"
  local keys=()
  readarray -t keys < <(flex_ini_keys "$ini_identifier")
  local key
  for key in "${keys[@]}"; do
    local value
    value=$(flex_ini_get "$key" "$ini_identifier")
    echo "$key = $value"
  done
  echo ""
}
# @public flex_ini_keys
# --
# Get an array of all keys in your ini array (whether or not they)
# have been saved.
flex_ini_keys() {
  local ini_identifier
  ini_identifier=$(private_flex_ini_format_id "$1")
  local array_name
  array_name=$(private_flex_ini_get_array_name "$ini_identifier")
  private_flex_ini_require_loaded "$ini_identifier" || return 1
  local keys=()
  eval "keys=(\"\${!${array_name}[@]}\")"
  [ "${#keys[@]}" -gt 0 ] || return 0
  printf '%s\n' "${keys[@]}" | sort
}