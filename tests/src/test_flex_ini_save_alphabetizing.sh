test_flex_ini_save_alphabetizing() {
    local ini_one=$(create_ini)

    flex_ini_load "$ini_one"

    # Add keys in non-alphabetical order across multiple sections
    flex_ini_update "env_prod.secret_key" "prod_secret"
    flex_ini_update "env_ci.access_key" "ci_access"
    flex_ini_update "env_prodeu.access_key" "prodeu_access"
    flex_ini_update "env_prod.access_key" "prod_access"
    flex_ini_update "env_ci.secret_key" "ci_secret"
    flex_ini_update "env_prodeu.secret_key" "prodeu_secret"
    
    # Save the ini file
    flex_ini_save

    # Read the file content and verify alphabetizing
    local content=$(cat "$ini_one")
    
    # Check that sections are in alphabetical order
    # and keys within each section are alphabetical
    local expected_order=$(cat <<EOF
[env_ci]
access_key = ci_access
secret_key = ci_secret

[env_prod]
access_key = prod_access
secret_key = prod_secret

[env_prodeu]
access_key = prodeu_access
secret_key = prodeu_secret
EOF
)
    
    expect "$content" "$expected_order"

    # Clean up
    flex_ini_reset
}
