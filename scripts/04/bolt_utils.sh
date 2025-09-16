#!/bin/bash

# BOLT Utility Functions for Enhanced Post-Link Optimization
# Usage: source this file in test-all-combinations.sh

# Global variable to store detected perf capabilities
PERF_EVENTS_DETECTED=""

# Function to detect perf capabilities at script startup
detect_perf_capabilities() {
    if ! command -v perf >/dev/null 2>&1; then
        echo "ERROR: perf not found in PATH" >&2
        return 1
    fi
    
    # Test perf configurations in order of preference
    local test_binary="/bin/true"
    
    # Test 1: cycles:u with branch sampling
    if timeout 2 perf record -e cycles:u -j any,u -o /tmp/perf_test_$$.data -- "$test_binary" >/dev/null 2>&1; then
        PERF_EVENTS_DETECTED="cycles:u -j any,u"
        rm -f /tmp/perf_test_$$.data 2>/dev/null
        return 0
    fi
    
    # Test 2: cycles with branch sampling
    if timeout 2 perf record -e cycles -j any -o /tmp/perf_test_$$.data -- "$test_binary" >/dev/null 2>&1; then
        PERF_EVENTS_DETECTED="cycles -j any"
        rm -f /tmp/perf_test_$$.data 2>/dev/null
        return 0
    fi
    
    # Test 3: cycles only (no branch sampling)
    if timeout 2 perf record -e cycles -o /tmp/perf_test_$$.data -- "$test_binary" >/dev/null 2>&1; then
        PERF_EVENTS_DETECTED="cycles"
        rm -f /tmp/perf_test_$$.data 2>/dev/null
        return 0
    fi
    
    # Test 4: basic perf (fallback)
    if timeout 2 perf record -o /tmp/perf_test_$$.data -- "$test_binary" >/dev/null 2>&1; then
        PERF_EVENTS_DETECTED="basic"
        rm -f /tmp/perf_test_$$.data 2>/dev/null
        return 0
    fi
    
    # Cleanup any remaining test files
    rm -f /tmp/perf_test_$$.data 2>/dev/null
    return 1
}

# Function to apply BOLT optimization to a binary
apply_bolt_optimization() {
    local input_binary="$1"
    local output_binary="$2"
    local workspace="$3"
    local size="$4"
    local verbose="$5"
    
    if [ ! -x "$input_binary" ]; then
        echo "ERROR: Input binary not executable: $input_binary" >&2
        return 1
    fi
    
    local perf_data="$workspace/perf.data"
    local bolt_binary="$workspace/$(basename "$output_binary")_bolt"
    
    # Step 1: Collect performance profile with perf
    [ "$verbose" = true ] && echo "BOLT: Collecting performance profile..."
    echo "DEBUG: Starting perf profiling with $PERF_EVENTS_DETECTED" >&2
    
    local perf_output
    local abs_input_binary="$(realpath "$input_binary")"
    
    # Use detected perf capabilities
    case "$PERF_EVENTS_DETECTED" in
        "cycles:u -j any,u")
            perf_output=$(cd "$workspace" && timeout 60 perf record -e cycles:u -j any,u -o perf.data -- "$abs_input_binary" "$size" 2>&1)
            ;;
        "cycles -j any")
            perf_output=$(cd "$workspace" && timeout 60 perf record -e cycles -j any -o perf.data -- "$abs_input_binary" "$size" 2>&1)
            ;;
        "cycles")
            perf_output=$(cd "$workspace" && timeout 60 perf record -e cycles -o perf.data -- "$abs_input_binary" "$size" 2>&1)
            ;;
        "basic")
            perf_output=$(cd "$workspace" && timeout 60 perf record -o perf.data -- "$abs_input_binary" "$size" 2>&1)
            ;;
        *)
            echo "ERROR: No compatible perf configuration detected" >&2
            return 1
            ;;
    esac
    local perf_status=$?
    
    echo "DEBUG: Perf completed with status $perf_status" >&2
    
    if [ $perf_status -ne 0 ]; then
        echo "ERROR: perf record failed (exit code: $perf_status)" >&2
        [ "$verbose" = true ] && echo "perf output: $perf_output" >&2
        return 2
    fi
    
    if [ ! -f "$perf_data" ]; then
        echo "ERROR: perf.data not created" >&2
        return 3
    fi
    
    # Check if perf.data has meaningful data
    local perf_size=$(stat -c%s "$perf_data" 2>/dev/null || echo 0)
    if [ "$perf_size" -lt 1000 ]; then
        echo "ERROR: perf.data too small ($perf_size bytes) - insufficient profiling data" >&2
        return 4
    fi
    
    # Step 2: Apply BOLT optimization
    [ "$verbose" = true ] && echo "BOLT: Optimizing binary layout..."
    echo "DEBUG: Starting llvm-bolt optimization" >&2
    
    local bolt_output
    local abs_bolt_binary="$(realpath -m "$bolt_binary")"
    
    # Use AArch64-compatible BOLT options
    bolt_output=$(cd "$workspace" && llvm-bolt "$abs_input_binary" -data=perf.data -reorder-blocks=ext-tsp -dyno-stats -o "$abs_bolt_binary" 2>&1)
    local bolt_status=$?
    
    echo "DEBUG: llvm-bolt completed with status $bolt_status" >&2
    
    if [ $bolt_status -ne 0 ]; then
        echo "ERROR: llvm-bolt failed (exit code: $bolt_status)" >&2
        [ "$verbose" = true ] && echo "BOLT output: $bolt_output" >&2
        return 5
    fi
    
    if [ ! -x "$bolt_binary" ]; then
        echo "ERROR: BOLT optimized binary not created or not executable" >&2
        return 6
    fi
    
    # Step 3: Move optimized binary to final location
    if ! mv "$bolt_binary" "$output_binary"; then
        echo "ERROR: Failed to move BOLT binary to final location" >&2
        return 7
    fi
    
    [ "$verbose" = true ] && echo "BOLT: Optimization completed successfully"
    echo "DEBUG: BOLT optimization function completed successfully" >&2
    
    # Export BOLT stats if available
    if echo "$bolt_output" | grep -q "BOLT-INFO"; then
        export BOLT_STATS=$(echo "$bolt_output" | grep "BOLT-INFO" | tail -1)
    fi
    
    return 0
}

# Function to run BOLT-optimized binary and collect results
run_bolt_binary() {
    local binary="$1"
    local size="$2"
    local workspace="$3"
    
    echo "DEBUG: Starting BOLT binary execution" >&2
    
    if [ ! -x "$binary" ]; then
        echo "ERROR: BOLT binary not executable: $binary" >&2
        return 1
    fi
    
    local result
    result=$(cd "$workspace" && timeout 30 "./${binary##*/}" "$size" 2>&1)
    local run_status=$?
    
    echo "DEBUG: BOLT binary execution completed with status $run_status" >&2
    
    if [ $run_status -ne 0 ]; then
        echo "ERROR: BOLT binary execution failed (exit code: $run_status)" >&2
        return 2
    fi
    
    local run_gflops run_time
    run_gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
    run_time=$(echo "$result" | grep "Time:" | awk '{print $2}')
    
    if [ -z "$run_gflops" ] || [ "$run_gflops" = "0" ] || [ -z "$run_time" ]; then
        echo "ERROR: Invalid performance results from BOLT binary" >&2
        return 3
    fi
    
    # Export results for caller
    export BOLT_GFLOPS="$run_gflops"
    export BOLT_TIME="$run_time"
    
    return 0
}

# Function to check BOLT prerequisites
check_bolt_prerequisites() {
    if ! command -v llvm-bolt >/dev/null 2>&1; then
        echo "ERROR: llvm-bolt not found in PATH" >&2
        return 1
    fi
    
    if ! command -v perf >/dev/null 2>&1; then
        echo "ERROR: perf not found in PATH" >&2
        return 2
    fi
    
    # Check if we can run perf (some systems require special permissions)
    if ! timeout 2 perf stat -e cycles true >/dev/null 2>&1; then
        echo "WARNING: perf may not have sufficient permissions - BOLT may fail" >&2
        echo "Consider running: echo 0 | sudo tee /proc/sys/kernel/perf_event_paranoid" >&2
    fi
    
    return 0
}
