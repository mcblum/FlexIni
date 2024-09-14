test_flex_ini_has_unsaved() {
    local filepath_one=$(create_ini)

    flex_ini_load "$filepath_one"
    flex_ini_update "unsaved" "change"
    expect_success "flex_ini_has_unsaved"
    expect_return_code 0 "flex_ini_has_unsaved"

    flex_ini_save || fail "Could not save"
    expect_failure "flex_ini_has_unsaved"
    expect_return_code 1 "flex_ini_has_unsaved"

    flex_ini_update "unsaved" "changed_again"
    local save_as_path="${test_storage_dir}/$$"
    flex_ini_save_as "$save_as_path" || fail "Could not save as"
    expect_success "flex_ini_has_unsaved"
    expect_return_code 0 "flex_ini_has_unsaved"
}