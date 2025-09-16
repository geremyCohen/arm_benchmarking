#!/bin/bash

# Minimal BOLT test to isolate the issue
cd /home/ubuntu/arm_benchmarking

# Source BOLT utilities
source scripts/04/bolt_utils.sh

# Detect perf capabilities
detect_perf_capabilities
echo "Perf detected: $PERF_EVENTS_DETECTED"

# Compile test binary
gcc -O2 -o test_binary src/optimized_matrix.c -lm
echo "Binary compiled"

# Create workspace
mkdir -p temp/bolt_test
echo "Workspace created"

# Test BOLT optimization
echo "Starting BOLT optimization..."
if apply_bolt_optimization test_binary temp/bolt_test/bolt_binary temp/bolt_test 64 true; then
    echo "BOLT optimization successful"
    
    # Test execution
    echo "Testing BOLT binary execution..."
    if run_bolt_binary temp/bolt_test/bolt_binary 64 temp/bolt_test; then
        echo "BOLT binary execution successful: $BOLT_GFLOPS GFLOPS, $BOLT_TIME seconds"
    else
        echo "BOLT binary execution failed"
    fi
else
    echo "BOLT optimization failed"
fi

# Cleanup
rm -f test_binary
rm -rf temp/bolt_test
echo "Test complete"
