test_flex_ini_delete() {
    
    filepath_one="${testing_storage_dir}/test_one.ini"
    touch "$filepath_one"
    flex_ini_load "$filepath_one"
    
    flex_ini_update "hey" "now"
    flex_ini_has "hey" || fail "Key 'hey' should have been present but wasn't"
    flex_ini_save

    flex_ini_reset

    flex_ini_load "$filepath_one"
    flex_ini_has "hey" || fail "Key 'hey' should have been present but wasn't"

    flex_ini_delete "hey"
    flex_ini_has "hey" && fail "Key 'hey' should have been deleted, but it was found"
    flex_ini_save

    flex_ini_reset

    flex_ini_load "$filepath_one"
    flex_ini_has "hey" && fail "Key 'hey' should have been deleted, but it was found" ||
        return 0
}