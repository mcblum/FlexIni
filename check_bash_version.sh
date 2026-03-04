#!/bin/bash
echo "=== Bash Version Check ==="
echo "BASH_VERSION: $BASH_VERSION"
echo "Shell: $0"
echo "uname: $(uname)"
echo "bash --version:"
bash --version | head -3
echo ""
echo "=== Testing declare flags ==="
echo "Testing declare -g:"
if declare -g test_var 2>/dev/null; then
    echo "✓ declare -g works"
    unset test_var
else
    echo "✗ declare -g not supported"
fi

echo "Testing declare -A:"
if declare -A test_array 2>/dev/null; then
    echo "✓ declare -A works"
    unset test_array
else
    echo "✗ declare -A not supported"
fi

echo "Testing declare -gA:"
if declare -gA test_garray 2>/dev/null; then
    echo "✓ declare -gA works"
    unset test_garray
else
    echo "✗ declare -gA not supported"
fi
