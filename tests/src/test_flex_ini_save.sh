test_flex_ini_save() {
    local ini_one=$(create_ini)

    flex_ini_load "$ini_one"

    flex_ini_update "save" "test"
    flex_ini_save

    flex_ini_reset

    flex_ini_load "$ini_one"
    expect "$(flex_ini_get "save")" "test"
    
    # Update the value of 'save_as' in the ini array
    # but only save it as, leaving the original untouched.
    flex_ini_update "save_as" "test"
    local save_as_loc="${test_storage_dir}/$$"
    flex_ini_save_as "$save_as_loc"

    flex_ini_reset
    
    # Load ini one and make sure it doesn't have the save_as
    # value we added.
    flex_ini_load "$ini_one"
    expect "$(flex_ini_get "save_as")" ""
    expect "$(flex_ini_get "save")" "test"

    # Load ini two (save_as_loc) and make sure it does have both
    # the original value and the save_as value.
    flex_ini_load "$save_as_loc" "as"
    expect "$(flex_ini_get "save_as" "as")" "test"
    expect "$(flex_ini_get "save" "as")" "test"
}