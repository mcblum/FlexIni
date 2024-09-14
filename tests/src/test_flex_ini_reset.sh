test_flex_ini_reset() {
    local filepath_one=$(create_ini)
    flex_ini_load "$filepath_one"
    flex_ini_update "change" "one"
    expect_success "flex_ini_has_unsaved"
    flex_ini_save || fail "Could not save"

    local filepath_two=$(create_ini)
    flex_ini_load "$filepath_two" "ini_two"
    flex_ini_update "change" "two" "ini_two"
    expect_success "flex_ini_has_unsaved ini_two" 
    flex_ini_save || fail "Could not save ini_two"

    flex_ini_reset

    auto_create_ini_on_load=false
    expect_failure 'flex_ini_update "change" "one"' "default has not-yet been loaded"
    expect_failure 'flex_ini_update "change" "two" "ini_two"' "ini_two has not-yet been loaded"
}

test_flex_ini_reset_after() {
    auto_create_ini_on_load=true
}