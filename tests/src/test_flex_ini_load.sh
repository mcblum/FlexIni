test_flex_ini_load() {
    filepath_one="${testing_storage_dir}/test_one.ini"
    filepath_two="${testing_storage_dir}/test_two.ini"
    touch "$filepath_one"
    touch "$filepath_two"

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
}