test_flex_ini_update() {
    local filepath_one=$(create_ini)
    flex_ini_load "$filepath_one"
    
    flex_ini_update "hey" "now"
    flex_ini_has "hey" || fail "Key 'hey' should have been present but wasn't"
    flex_ini_save

    # Reset, reload, make sure it's there, update more stuff
    flex_ini_reset
    
    # Should thrown a "not yet loaded" error
    expect_contains "$(flex_ini_has  "hey" | tail -n 1)" "ini id default has not-yet been loaded"

    flex_ini_load "$filepath_one"
    flex_ini_has "hey" || fail "Key 'hey' should have been present but wasn't"

    flex_ini_update "section.thing" "true"
    expect "$(flex_ini_get "section.thing")" "true"

    flex_ini_save
    flex_ini_load "$filepath_one"
    expect "$(flex_ini_get "section.thing")" "true"

    # Reset, set autosave, make sure it works
    flex_ini_reset
    rm -f "$filepath_one"
    
    local filepath_two=$(create_ini)

    auto_save_on_changes=true
    flex_ini_load "$filepath_two"
    flex_ini_update "auto" "save"
    # Don't call save here, just reset
    flex_ini_reset

    # Load the file again, expect it to have saved
    flex_ini_load "$filepath_two"
    expect "$(flex_ini_get "auto")" "save"
}

test_flex_ini_update_after() {
    auto_save_on_changes=true
}