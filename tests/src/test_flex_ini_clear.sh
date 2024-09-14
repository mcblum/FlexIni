test_flex_ini_clear() {
    local filepath_one=$(create_ini)
    local filepath_two=$(create_ini)

    # Load each file, one with a k and one without
    flex_ini_load "$filepath_one"
    flex_ini_load "$filepath_two" "test_two_id"

    flex_ini_update "k" "value"
    flex_ini_update "k2" "value2" "test_two_id"

    expect "$(flex_ini_get k)" "value"
    expect "$(flex_ini_get k2 test_two_id)" "value2"

    flex_ini_clear

    expect "$(flex_ini_get k)" ""
    expect "$(flex_ini_get k2 test_two_id)" "value2"
}