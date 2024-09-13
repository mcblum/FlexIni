test_flex_ini_has() {
    filepath_one="${testing_storage_dir}/test_one.ini"
    touch "$filepath_one"
    flex_ini_load "$filepath_one"

    # It should not yet be there
    flex_ini_has "hey" && fail "Key 'hey' is present when it should *not* be"

    # Now it is set and should be there
    flex_ini_update "hey" "now"
    flex_ini_has "hey" || fail "Key 'hey' not present when it should be"
}