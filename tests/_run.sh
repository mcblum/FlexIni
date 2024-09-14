echo "Running tests for FlexIni..."

test_parent_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
test_storage_dir="$test_parent_dir/.tests"
echo ""

test_suites=()
cd $test_parent_dir/src
for f in *; do
    fn_name="${f/.sh/''}"
    test_suites+=("$fn_name")
done
cd ../..

source $test_parent_dir/_common.sh

for t in "${test_suites[@]}"; do
    init
    source $test_parent_dir/src/$t.sh
    echo ""
    echo "[ $t ] running..."
    ${t}_before >/dev/null 2>&1 && echo "[ $t ] before method found + executed" || true
    $t &&
        echo "[ $t ] passed" ||
        fail "Test suite $t has failed"
    ${t}_after >/dev/null 2>&1 && echo "[ $t ] after method found + executed" || true
    clean
    flex_ini_reset
    echo ""
done

echo "Tests passed"