test_flex_ini_keys() {
    local filepath_one=$(create_ini)
    flex_ini_load "$filepath_one"
    flex_ini_update "test" "one"
    flex_ini_update "testing" "two"
    flex_ini_update "tested" "three"

    local res=($(flex_ini_keys))
    expect "${#res[@]}" 3

    expect_array_contains "test" "${res[@]}"
    expect_array_contains "testing" "${res[@]}"
    expect_array_contains "tested" "${res[@]}"
}