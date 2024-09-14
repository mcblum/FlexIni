# Include our script
source ./flex_ini.sh
source ./tests/_assertions.sh

fail() {
    local msg="$1"
    echo "[ Error ] ${msg}"
    exit 1
}

init() {
    mkdir -p "$testing_storage_dir"
}

create_ini() {
    filepath_one="${testing_storage_dir}/$$.ini"
    touch "$filepath_one"

    echo "$filepath_one"
}

clean() {
    if [ -z "$testing_storage_dir" ]; then
        fail "Testing dir variable undefined!!! Extremely unsafe operation prevented"
    fi
    rm -rf "${testing_storage_dir}"
}