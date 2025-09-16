#!/bin/bash

# BOLT Utility Functions for Enhanced Post-Link Optimization
# Usage: source this file in test-all-combinations.sh

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
    
    local perf_output
    local abs_input_binary="$(realpath "$input_binary")"
    
    # Try different perf configurations in order of preference
    if perf_output=$(cd "$workspace" && timeout 60 perf record -e cycles:u -j any,u -o perf.data -- "$abs_input_binary" "$size" 2>&1); then
        local perf_status=0
    elif perf_output=$(cd "$workspace" && timeout 60 perf record -e cycles -j any -o perf.data -- "$abs_input_binary" "$size" 2>&1); then
        local perf_status=0
    elif perf_output=$(cd "$workspace" && timeout 60 perf record -e cycles -o perf.data -- "$abs_input_binary" "$size" 2>&1); then
        local perf_status=0
        echo "WARNING: Using perf without branch sampling - BOLT optimization may be less effective" >&2
    else
        local perf_status=1
        echo "WARNING: All perf configurations failed, trying basic profiling..." >&2
        # Last resort: try with minimal options
        if perf_output=$(cd "$workspace" && timeout 60 perf record -o perf.data -- "$abs_input_binary" "$size" 2>&1); then
            local perf_status=0
            echo "WARNING: Using basic perf profiling - BOLT optimization may be limited" >&2
        else
            local perf_status=1
        fi
    fi
    
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
    
    local bolt_output
    local abs_bolt_binary="$(realpath -m "$bolt_binary")"
    
    # Use AArch64-compatible BOLT options
    bolt_output=$(cd "$workspace" && llvm-bolt "$abs_input_binary" -data=perf.data -reorder-blocks=ext-tsp -dyno-stats -o "$abs_bolt_binary" 2>&1)
    local bolt_status=$?
    
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
    
    if [ ! -x "$binary" ]; then
        echo "ERROR: BOLT binary not executable: $binary" >&2
        return 1
    fi
    
    local result
    result=$(cd "$workspace" && timeout 30 "./${binary##*/}" "$size" 2>&1)
    local run_status=$?
    
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
