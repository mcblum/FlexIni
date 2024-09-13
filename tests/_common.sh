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

expect_contains() {
    local received="$1"
    local str="$2"

    if [[ ! $received == *"$str"* ]]; then
        fail "We expected '${received}' to contain '${str}' but it did not."
    fi
}

expect_file_exists() {
    local filepath="$1"

    if [ ! -f "$filepath" ]; then
        fail "We expected the file at '${filepath}' to exist, but it did not."
    fi
}

expect_error() {
    if [ $? == 0 ]; then
        fail "We expected an error but none was found"
    fi
}