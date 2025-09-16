#!/bin/bash

# Simple test of BOLT functionality
cd /home/ubuntu/arm_benchmarking
source scripts/04/bolt_utils.sh

echo "Testing BOLT functionality..."

# Check prerequisites
echo "Checking BOLT prerequisites..."
if check_bolt_prerequisites; then
    echo "✓ BOLT prerequisites satisfied"
else
    echo "✗ BOLT prerequisites not met"
    exit 1
fi

if [ ! -f "src/optimized_matrix.c" ]; then
    echo "ERROR: src/optimized_matrix.c not found"
    exit 1
fi

# Test parameters
workspace="temp/bolt_test_$$"
input_binary="$workspace/test_input"
output_binary="$workspace/test_output"
flags="-O2"
size="micro"

echo "Creating test workspace: $workspace"
mkdir -p "$workspace"

echo "Step 1: Compile test binary..."
if gcc $flags -Wall -o "$input_binary" src/optimized_matrix.c -lm 2>&1; then
    echo "✓ Test binary compiled successfully"
else
    echo "✗ Test binary compilation failed"
    exit 1
fi

echo "Step 2: Test input binary..."
if result=$("$input_binary" "$size" 2>&1); then
    echo "✓ Input binary runs successfully"
    echo "Input result: $result"
else
    echo "✗ Input binary execution failed"
    exit 1
fi

echo "Step 3: Apply BOLT optimization..."
if apply_bolt_optimization "$input_binary" "$output_binary" "$workspace" "$size" "true"; then
    echo "✓ BOLT optimization successful"
else
    echo "✗ BOLT optimization failed"
    exit 1
fi

echo "Step 4: Test BOLT-optimized binary..."
if run_bolt_binary "$output_binary" "$size" "$workspace"; then
    echo "✓ BOLT binary runs successfully"
    echo "BOLT result: Performance: $BOLT_GFLOPS GFLOPS, Time: $BOLT_TIME seconds"
else
    echo "✗ BOLT binary execution failed"
    exit 1
fi

# Cleanup
rm -rf "$workspace"

echo ""
echo "✓ All BOLT tests completed successfully!"
echo "BOLT utilities are working correctly."
