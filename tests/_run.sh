#!/opt/homebrew/bin/bash
echo "Running tests for FlexIni..."

testing_storage_dir="$PWD/.tests"
echo ""

test_suites=()
cd ./tests/src
for f in *; do
    fn_name="${f/.sh/''}"
    test_suites+=("$fn_name")
done
cd ../..

source ./tests/_common.sh

for t in "${test_suites[@]}"; do
    init
    source ./tests/src/$t.sh
    echo ""
    echo "[ $t ] running..."
    $t &&
        echo "[ $t ] passed" ||
        fail "Test suite $t has failed"
    clean
    flex_ini_reset
    echo ""
done

echo "Tests passed"