#!/bin/bash

# Test BOLT integration with all combinations
cd /home/ubuntu/arm_benchmarking

echo "Testing BOLT integration with all CLI combinations..."
echo "=================================================="

# Test 1: Basic BOLT
echo "Test 1: Basic BOLT (--bolt)"
timeout 30 ./scripts/04/test-all-combinations.sh --bolt --sizes 1 --opt-levels 2 --runs 1 --baseline-only 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ Basic BOLT test passed"
else
    echo "✗ Basic BOLT test failed or timed out"
fi

# Test 2: BOLT + PGO
echo "Test 2: BOLT + PGO (--bolt --pgo)"
timeout 60 ./scripts/04/test-all-combinations.sh --bolt --pgo --sizes 1 --opt-levels 2 --runs 1 --baseline-only 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ BOLT + PGO test passed"
else
    echo "✗ BOLT + PGO test failed or timed out"
fi

# Test 3: BOLT + extra flags
echo "Test 3: BOLT + extra flags (--bolt --extra-flags)"
timeout 30 ./scripts/04/test-all-combinations.sh --bolt --extra-flags --sizes 1 --opt-levels 2 --runs 1 --baseline-only 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ BOLT + extra flags test passed"
else
    echo "✗ BOLT + extra flags test failed or timed out"
fi

# Test 4: All combinations
echo "Test 4: All combinations (--bolt --pgo --extra-flags)"
timeout 90 ./scripts/04/test-all-combinations.sh --bolt --pgo --extra-flags --sizes 1 --opt-levels 2 --runs 1 --baseline-only 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ All combinations test passed"
else
    echo "✗ All combinations test failed or timed out"
fi

# Test 5: Help text
echo "Test 5: Help text includes BOLT"
if ./scripts/04/test-all-combinations.sh --help | grep -q "bolt.*BOLT"; then
    echo "✓ Help text includes BOLT option"
else
    echo "✗ Help text missing BOLT option"
fi

echo ""
echo "BOLT integration testing complete."
echo "Note: Timeouts are expected until BOLT execution logic is fully implemented."
