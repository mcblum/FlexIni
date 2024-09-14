# Include our script
source $test_parent_dir/../flex_ini.sh
source $test_parent_dir/_assertions.sh

fail() {
    local msg="$1"
    echo "[ Error ] ${msg}"
    exit 1
}

init() {
    mkdir -p "$test_storage_dir"
}

create_ini() {
    filepath_one="${test_storage_dir}/$$.ini"
    touch "$filepath_one"

    echo "$filepath_one"
}

clean() {
    if [ -z "$test_storage_dir" ]; then
        fail "Testing dir variable undefined!!! Extremely unsafe operation prevented"
    fi
    rm -rf "${test_storage_dir}"
}