expect() {
    local received="$1"
    local expected="$2"

    if [ "$expected" != "$received" ]; then
        fail "Expected value to be '$expected', but received '$received'"
    fi
}

expect_success() {
    local cmd="$1"

    if ! eval "$cmd"; then
        fail "We expected the command ${cmd} to return 0, but it returned $?"
    fi
}

expect_failure() {
    local cmd="$1"
    local error_msg="$2"

    if eval "$cmd"; then
        fail "We expected the command ${cmd} to return > 0, but it returned 0"
    fi

    if [ -n "$error_msg" ]; then
        local cmd_with_message_getter="${cmd} | tail -n 1"
        expect_contains "$(eval "$cmd_with_message_getter")" "$error_msg"
    fi
}

expect_return_code() {
    local code="$1"
    local cmd="$2"

    eval "$cmd" && local rtn_code="$?" || local rtn_code="$?"
    if [ $rtn_code -ne "$code" ]; then
        fail "We expected the command ${cmd} to return with code ${code}, but it returned $rtn_code"
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

expect_array_contains() {
    local e match="$1"
    shift
    for e; do
        [[ "$e" == "$match" ]] && return 0
    done

    fail "We expected the array to contain ${match} but it did not"
}