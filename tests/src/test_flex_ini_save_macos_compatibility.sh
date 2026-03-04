test_flex_ini_save_macos_compatibility() {
    local ini_one=$(create_ini)

    flex_ini_load "$ini_one"
    flex_ini_update "test_key" "test_value"
    
    # Test that save works on both macOS and Linux
    # This specifically tests the stat command compatibility
    # The code should detect the OS and use appropriate stat flags
    flex_ini_save
    
    # Verify the file was saved correctly
    expect "$(flex_ini_get "test_key")" "test_value"
    
    # Test save_as functionality as well
    local save_as_loc="${test_storage_dir}/macos_test_$$"
    flex_ini_save_as "$save_as_loc"
    
    # Verify the save_as file exists and has correct content
    if [ ! -f "$save_as_loc" ]; then
        fail "Save as file was not created"
    fi
    
    # Load the save_as file and verify content
    flex_ini_load "$save_as_loc" "macos_test"
    expect "$(flex_ini_get "test_key" "macos_test")" "test_value"
    
    # Test the specific stat commands used in the code
    local test_file="${test_storage_dir}/stat_test_$$"
    touch "$test_file"
    
    if [ "$_OS" == "macos" ]; then
        # Test macOS stat commands
        local owner=$(stat -f '%Su' "$test_file")
        local group=$(stat -f '%Sg' "$test_file")
        echo "macOS stat: owner=$owner, group=$group"
        [[ -n "$owner" ]] || fail "macOS stat owner command failed"
        [[ -n "$group" ]] || fail "macOS stat group command failed"
    elif [ "$_OS" == "linux" ]; then
        # Test Linux stat commands
        local owner=$(stat --format '%U' "$test_file")
        local group=$(stat --format '%G' "$test_file")
        echo "Linux stat: owner=$owner, group=$group"
        [[ -n "$owner" ]] || fail "Linux stat owner command failed"
        [[ -n "$group" ]] || fail "Linux stat group command failed"
    else
        echo "Unknown OS: $_OS - skipping stat command tests"
    fi
    
    # Clean up
    flex_ini_reset
    rm -f "$save_as_loc" "$test_file"
}
