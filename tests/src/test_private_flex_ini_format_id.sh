test_private_flex_ini_format_id() {
    expect "$(private_flex_ini_format_id "fine")" "fine"
    expect "$(private_flex_ini_format_id "also_fine")" "also_fine"
    
    expect "$(private_flex_ini_format_id "remove-dash")" "remove_dash"
    expect "$(private_flex_ini_format_id "remove-dash and spaces")" "remove_dash_and_spaces"
}