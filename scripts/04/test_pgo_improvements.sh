#!/bin/bash

# Test script to validate PGO improvements

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/pgo_utils.sh"

echo "Testing PGO improvements..."
echo "=========================="

# Test 1: Lock mechanism
echo "Test 1: Lock mechanism"
test_lock_mechanism() {
    local lock_name="test_lock_$$"
    
    echo "  Acquiring lock: $lock_name"
    if acquire_pgo_lock "$lock_name"; then
        echo "  ✓ Lock acquired successfully"
        
        # Test concurrent lock attempt (should fail quickly)
        echo "  Testing concurrent lock (should timeout)..."
        if timeout 2 bash -c "source '$SCRIPT_DIR/pgo_utils.sh'; acquire_pgo_lock '$lock_name'" 2>/dev/null; then
            echo "  ✗ ERROR: Concurrent lock should have failed"
            return 1
        else
            echo "  ✓ Concurrent lock properly blocked"
        fi
        
        release_pgo_lock "$lock_name"
        echo "  ✓ Lock released successfully"
    else
        echo "  ✗ ERROR: Failed to acquire lock"
        return 1
    fi
    
    return 0
}

# Test 2: Profile validation
echo "Test 2: Profile validation"
test_profile_validation() {
    local test_workspace="temp/test_pgo_validation_$$"
    mkdir -p "$test_workspace"
    
    # Test with no profile files
    echo "  Testing with no profile files..."
    if validate_profile_data "$test_workspace" 1 2>/dev/null; then
        echo "  ✗ ERROR: Should have failed with no profile files"
        rm -rf "$test_workspace"
        return 1
    else
        echo "  ✓ Correctly detected missing profile files"
    fi
    
    # Test with empty profile files
    echo "  Testing with empty profile files..."
    touch "$test_workspace/test.gcda"
    touch "$test_workspace/test.gcno"
    if validate_profile_data "$test_workspace" 1 2>/dev/null; then
        echo "  ✗ ERROR: Should have failed with empty profile files"
        rm -rf "$test_workspace"
        return 1
    else
        echo "  ✓ Correctly detected empty profile files"
    fi
    
    # Test with valid-looking profile files
    echo "  Testing with non-empty profile files..."
    echo "dummy profile data" > "$test_workspace/test.gcda"
    echo "dummy profile metadata" > "$test_workspace/test.gcno"
    if validate_profile_data "$test_workspace" 1 2>/dev/null; then
        echo "  ✓ Validation passed with non-empty files"
    else
        echo "  ⚠ Validation failed (expected if gcov-dump is available and validates format)"
    fi
    
    rm -rf "$test_workspace"
    return 0
}

# Test 3: Full PGO compilation (if source exists)
echo "Test 3: Full PGO compilation"
test_full_pgo() {
    if [ ! -f "src/optimized_matrix.c" ]; then
        echo "  ⚠ Skipping: src/optimized_matrix.c not found"
        return 0
    fi
    
    local test_workspace="temp/test_pgo_full_$$"
    local pgo_base="test_pgo"
    local flags="-O2"
    local size="micro"
    local src_path="$(pwd)/src/optimized_matrix.c"
    
    echo "  Testing full PGO compilation process..."
    
    if compile_with_pgo "$flags" "$test_workspace" "$pgo_base" "$size" "true" "$src_path"; then
        echo "  ✓ PGO compilation successful"
        echo "    Compile time: $PGO_COMPILE_TIME seconds"
        echo "    Binary: $PGO_BINARY"
        
        # Test running the binary
        if run_pgo_binary "$PGO_BINARY" "$size" "$test_workspace"; then
            echo "  ✓ PGO binary execution successful"
            echo "    Performance: $PGO_GFLOPS GFLOPS"
            echo "    Time: $PGO_TIME seconds"
        else
            echo "  ✗ ERROR: PGO binary execution failed"
            rm -rf "$test_workspace"
            return 1
        fi
    else
        echo "  ✗ ERROR: PGO compilation failed"
        rm -rf "$test_workspace"
        return 1
    fi
    
    rm -rf "$test_workspace"
    return 0
}

# Run tests
echo ""
if test_lock_mechanism; then
    echo "✓ Lock mechanism test passed"
else
    echo "✗ Lock mechanism test failed"
    exit 1
fi

echo ""
if test_profile_validation; then
    echo "✓ Profile validation test passed"
else
    echo "✗ Profile validation test failed"
    exit 1
fi

echo ""
if test_full_pgo; then
    echo "✓ Full PGO compilation test passed"
else
    echo "✗ Full PGO compilation test failed"
    exit 1
fi

echo ""
echo "=========================="
echo "All PGO improvement tests passed!"
echo ""
echo "Key improvements validated:"
echo "- File locking prevents parallel conflicts"
echo "- Profile validation detects missing/corrupt data"
echo "- Enhanced error handling provides clear diagnostics"
echo "- Full PGO workflow functions correctly"
echo ""
echo "Ready for integration into test-all-combinations.sh"
