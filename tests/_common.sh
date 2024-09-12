# Include our script
source ./flex_ini.sh

fail() {
    local msg="$1"
    echo "[ Error ] ${msg}"
    exit 1
}

init() {
    mkdir -p "$testing_storage_dir"
}

clean() {
    if [ -z "$testing_storage_dir" ]; then
        fail "Testing dir variable undefined!!! Extremely unsafe operation prevented"
    fi
    rm -rf "${testing_storage_dir}"
}

expect() {
    local received="$1"
    local expected="$2"

    if [ "$expected" != "$received" ]; then
        fail "Expected value to be '$expected', but received '$received'"
    fi
}