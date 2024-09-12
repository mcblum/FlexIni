test_flex_ini_get() {
    filepath_one="${testing_storage_dir}/test_one.ini"
    touch "$filepath_one"

    flex_ini_load "$filepath_one"

    flex_ini_update "hey" "now"
}