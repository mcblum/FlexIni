test_flex_ini_load_before() {
    auto_create_ini_on_load=false
}

test_flex_ini_load() {
    local filepath_one=$(create_ini)
    local filepath_two=$(create_ini)

    # Load each file, one with a key and one without
    flex_ini_load "$filepath_one"
    flex_ini_load "$filepath_two" "test_two_id"

    local NO_ID_FORMATTED=$(private_flex_ini_format_id)
    local ID_FORMATTED=$(private_flex_ini_format_id "test_two_id")

    if [ "${ini_loaded["$NO_ID_FORMATTED"]}" != "true" ]; then
        fail "No id ini array should have been marked as loaded, but was not"
    fi

    if [ "${ini_loaded["$ID_FORMATTED"]}" != "true" ]; then
        fail "No id ini array should have been marked as loaded, but was not"
    fi

    flex_ini_update "hello" "there"
    flex_ini_save

    flex_ini_update "my" "my" "test_two_id"
    flex_ini_save "test_two_id"

    # Test auto-create
    auto_create_ini_on_load=true

    local autocreate_filepath="${test_storage_dir}/auto_create.ini"

    flex_ini_load "$autocreate_filepath" "autocreate" || fail "There was a failure in auto-creation"
    expect_file_exists "$autocreate_filepath"
    flex_ini_update "auto" "create" "autocreate"
    flex_ini_save "autocreate" || fail "Could not save auto-created file"

    flex_ini_reset

    flex_ini_load "$autocreate_filepath" "autocreate"
    expect "$(flex_ini_get "auto" "autocreate")" "create"
}

test_flex_ini_load_after() {
    auto_create_ini_on_load=true
}