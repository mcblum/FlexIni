# Defaults
# --
# You may change these here or overwrite them
# within your scripts, whatever works best for
# your use case.

back_up_changes_on_save=true
back_up_changes_on_save_as=false
tmp_directory="/tmp"

# Private Functions
# --
# It's best to not call/modify these directly from your codebase
# unless you know what you're doing!

declare -gA ini_associations
declare -gA ini_unsaved_changes

# @private private_flex_ini_mark_as_changed
# --
# Marks an ini array as changed
private_flex_ini_mark_as_changed() {
  local ini_identifier=$(private_flex_ini_format_id "$1")
  ini_unsaved_changes["$ini_identifier"]=true
}

# @private private_flex_ini_mark_as_unchanged
# --
# Marks an ini array as unchanged
private_flex_ini_mark_as_unchanged() {
  local ini_identifier=$(private_flex_ini_format_id "$1")
  ini_unsaved_changes["$ini_identifier"]=false
}

# @private private_flex_ini_format_id
# --
# Format the supplied ini id to make sure it's
# compatible with naming an array
private_flex_ini_format_id() {
  local default_ini_array_name="default"
  local ini_identifier="${1:-$default_ini_array_name}"

  echo $(replace_spaces_with "$1" "_")
}

# @private private_flex_ini_get_array_name
# --
# Get the name of the array based on the ini id
private_flex_ini_get_array_name() {
  local ini_identifier=$(private_flex_ini_format_id "$1")
  local ini_name="${ini_identifier}_ini"

  # Let's re-declare the array here every time so that
  # we never get an error that the array doesn't exist.
  declare -gA "$ini_name"

  echo "$ini_name"
}

# @private private_get_ini_file_path
# --
# Get the file path for a specific ini id
private_get_ini_file_path() {
  local ini_identifier=$(private_flex_ini_format_id "$1")

  local FILE_PATH="${ini_associations[$ini_identifier]}"

  if [ -z "$FILE_PATH" ]; then
    log error "Error, no file associated with the ini id ${ini_identifier}"
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
  local ini_identifier=$(private_flex_ini_format_id "$2")

  local ini=$(private_flex_ini_get_array_name "$ini_identifier")

  declare -gA "$ini"

  ini_associations["$ini_identifier"]="$ini_file"
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
  local ini_identifier=$(private_flex_ini_format_id "$2")

  private_flex_ini_init "$ini_file" "$ini_identifier"
  local ini=$(private_flex_ini_get_array_name "$ini_identifier")

  local section=""
  local key=""
  local value=""
  local section_regex="^\[(.+)\]"
  local key_regex="^([^ =]+) *= *(.*) *$"
  local comment_regex="^;"

  while IFS= read -r line; do
    if [[ $line =~ $comment_regex ]]; then
      continue
    elif [[ $line =~ $section_regex ]]; then
      section="${BASH_REMATCH[1]}."
    elif [[ $line =~ $key_regex ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      [[ $value == *\$* ]] && eval "value=\"$value\""
      local name_var=$ini'["'${section}${key}'"]="'$value'"'
      eval "$name_var"
    fi
  done <"$ini_file"

  private_flex_ini_mark_as_unchanged "$ini_identifier"
}

# @public flex_ini_get
# --
# Fetches a value from the specified ini array.
flex_ini_get() {
  local key="$1"
  local ini_identifier=$(private_flex_ini_format_id "$2")
  local array_name=$(private_flex_ini_get_array_name "$ini_identifier")

  local name_var='${'$array_name'['$key']}'
  local value=$(eval echo "$name_var")
  echo "$value"
}

# @public flex_ini_has
# --
# Returns 0 if the key exists, 1 if it does not.
flex_ini_has() {
  local key="$1"
  local ini_identifier=$(private_flex_ini_format_id "$2")

  [[ $(flex_ini_get "$key" "$ini_identifier") ]]
}

# @public flex_ini_update
# --
# This creates or updates a value in your ini array.
# Note: this does not save it, you'll need to call
# that separately.
flex_ini_update() {
  local key="$1"
  local value="$2"
  local ini_identifier=$(private_flex_ini_format_id "$3")
  local array_name=$(private_flex_ini_get_array_name "$ini_identifier")

  local assign_var=$array_name'["'$key'"]="'"${value}"'"'
  eval "$assign_var"

  private_flex_ini_mark_as_changed "$ini_identifier"
}

# @public flex_ini_delete
# --
# Remove a value from your ini array.
# Note: this does not save it, you'll need to call
# that separately.
flex_ini_delete() {
  local key="$1"
  local ini_identifier=$(private_flex_ini_format_id "$2")

  local array_name=$(private_flex_ini_get_array_name "$ini_identifier")
  local assign_var='unset '$array_name'["'$key'"]'
  eval "$assign_var"

  private_flex_ini_mark_as_changed "$ini_identifier"
}

# @public flex_ini_save
# --
# Save the values in the array back to the correct file.
# If using the file you specified when you loaded the ini
# config, do not pass a second argument.
flex_ini_save() {
  local ini_identifier=$(private_flex_ini_format_id "$1")
  local override_path="$2"
  local default_destination_ini_path=$(private_get_ini_file_path "$ini_identifier")

  # The save-as logic path first
  if [ -n "$override_path" ]; then
    local destination_ini_path="$override_path"

    local back_up_changes_on_save=${back_up_changes_on_save_as}
    local is_save_as_operation=true

    # pre-create the file if it doesn't exist just to make sure we can
    if [ ! -f "$destination_ini_path" ]; then
      touch "$destination_ini_path" ||
        echo "Error -- unable to create file specified at $destination_ini_path" &&
        return 1
    fi
  else
    local destination_ini_path="$default_destination_ini_path"
    local is_save_as_operation=false
  fi

  local current_section=""
  local has_free_keys=false

  local ini_file=$(mktemp "${tmp_directory}/ini-tmp")

  for key in $(flex_ini_keys "$ini_identifier"); do
    [[ $key == *.* ]] && continue
    has_free_keys=true
    local value=$(flex_ini_get "$key" "$ini_identifier")
    echo "$key = $value" >>"$ini_file"
  done

  [[ "${has_free_keys}" == "true" ]] && echo >>"$ini_file"

  for key in $(flex_ini_keys "$ini_identifier"); do
    [[ $key == *.* ]] || continue
    local value=$(flex_ini_get "$key" "$ini_identifier")
    IFS="." read -r section_name key_name <<<"$key"

    if [[ "$current_section" != "$section_name" ]]; then
      [[ $current_section ]] && echo >>"$ini_file"
      echo "[$section_name]" >>"$ini_file"
      current_section="$section_name"
    fi

    echo "$key_name = $value" >>"$ini_file"
  done

  # Back up the destination ini file if specified
  if [ "$back_up_changes_on_save" == "true" ]; then
    cp -f "$destination_ini_path" "${destination_ini_path}.bak"
  fi

  # Replace the destination ini file with the tmp file
  mv -f "$ini_file" "$destination_ini_path"

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
  local ini_identifier=$(private_flex_ini_format_id "$2")

  flex_ini_save "$ini_identifier" "$override_path"
}

# @public flex_ini_has_unsaved
# --
# Returns 0 if the array has unsaved changes.
flex_ini_has_unsaved() {
  local ini_identifier=$(private_flex_ini_format_id "$1")
  local has_unsaved="${ini_unsaved_changes["$ini_identifier"]}"

  if [ "$has_unsaved" == "true" ]; then
    return 0
  else
    return 1
  fi
}

# @public flex_ini_show
# --
# Show all loaded key-value pairs (whether or not they've been saved).
flex_ini_show() {
  local ini_identifier=$(private_flex_ini_format_id "$1")
  local file_path=$(private_get_ini_file_path "$ini_identifier")

  echo "[ ${ini_identifier} ]"
  echo "--"

  for key in $(flex_ini_keys "$ini_identifier"); do
    local value=$(flex_ini_get "$key" "$ini_identifier")
    echo "$key = $value"
  done

  echo ""
}

# @public flex_ini_keys
# --
# Get an array of all keys in your ini array (whether or not they)
# have been saved.
flex_ini_keys() {
  local ini_identifier=$(private_flex_ini_format_id "$1")
  local array_name=$(private_flex_ini_get_array_name "$ini_identifier")

  local name_var='${!'$array_name'[@]}'
  local keys=($(eval echo "$name_var"))
  for a in "${keys[@]}"; do echo "$a"; done | sort
}
