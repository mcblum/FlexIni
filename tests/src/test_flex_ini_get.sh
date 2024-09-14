test_flex_ini_get() {
    local filepath_one=$(create_ini)
    flex_ini_load "$filepath_one"

    # It should be blank until it's set
    expect "$(flex_ini_get "hey")" ""
    flex_ini_update "hey" "now"
    expect "$(flex_ini_get "hey")" "now"

    # Saving the file, resetting the arrays,
    # reloading the file, and getting the var
    # should resolve to the same value.
    flex_ini_save
    flex_ini_reset
    flex_ini_load "$filepath_one"
    expect "$(flex_ini_get "hey")" "now"
}