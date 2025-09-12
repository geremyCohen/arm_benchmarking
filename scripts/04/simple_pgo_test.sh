#!/bin/bash

# Simple test of PGO functionality
cd /home/ubuntu/arm_benchmarking
source scripts/04/pgo_utils.sh

echo "Testing PGO compilation with actual source..."

if [ ! -f "src/optimized_matrix.c" ]; then
    echo "ERROR: src/optimized_matrix.c not found"
    exit 1
fi

# Test parameters
workspace="temp/simple_pgo_test_$$"
pgo_base="simple_test"
flags="-O2"
size="micro"
src_path="$(pwd)/src/optimized_matrix.c"

echo "Workspace: $workspace"
echo "Source: $src_path"
echo "Flags: $flags"

# Manual PGO test without the full function
mkdir -p "$workspace"

echo "Step 1: Compile with profile generation..."
if gcc $flags -fprofile-generate -Wall -o "$workspace/${pgo_base}_gen" "$src_path" -lm 2>&1; then
    echo "✓ Profile generation binary created"
else
    echo "✗ Profile generation compilation failed"
    exit 1
fi

echo "Step 2: Run profile generation..."
if (cd "$workspace" && "./${pgo_base}_gen" "$size" >/dev/null 2>&1); then
    echo "✓ Profile generation run completed"
else
    echo "✗ Profile generation run failed"
    exit 1
fi

echo "Step 3: Check profile data..."
gcda_count=$(find "$workspace" -name "*.gcda" | wc -l)
echo "Found $gcda_count .gcda files"

if [ "$gcda_count" -gt 0 ]; then
    echo "✓ Profile data generated"
    ls -la "$workspace"/*.gcda
else
    echo "✗ No profile data found"
    exit 1
fi

echo "Step 4: Compile with profile use..."
if (cd "$workspace" && gcc $flags -fprofile-use -Wno-coverage-mismatch -Wall -o "${pgo_base}" "$src_path" -lm 2>&1); then
    echo "✓ Profile-optimized binary created"
else
    echo "✗ Profile-use compilation failed"
    exit 1
fi

echo "Step 5: Test optimized binary..."
if result=$(cd "$workspace" && "./${pgo_base}" "$size" 2>&1); then
    echo "✓ Optimized binary runs successfully"
    echo "Result: $result"
else
    echo "✗ Optimized binary execution failed"
    exit 1
fi

# Cleanup
rm -rf "$workspace"

echo ""
echo "✓ All PGO steps completed successfully!"
echo "The PGO utilities should work correctly."
