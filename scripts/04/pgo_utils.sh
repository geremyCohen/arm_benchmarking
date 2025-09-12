#!/bin/bash

# PGO Utility Functions with Enhanced Error Handling and Parallel Support
# Usage: source this file in test-all-combinations.sh

# Global PGO lock directory
PGO_LOCK_DIR="temp/pgo_locks"
mkdir -p "$PGO_LOCK_DIR"

# Function to acquire PGO workspace lock
acquire_pgo_lock() {
    local lock_name="$1"
    local lock_file="$PGO_LOCK_DIR/${lock_name}.lock"
    local timeout=30
    local count=0
    
    # Clean up stale locks (older than 5 minutes)
    if [ -d "$lock_file" ]; then
        local lock_age=$(($(date +%s) - $(stat -c %Y "$lock_file" 2>/dev/null || echo 0)))
        if [ $lock_age -gt 300 ]; then
            echo "Cleaning up stale lock: $lock_name (age: ${lock_age}s)" >&2
            rm -rf "$lock_file" 2>/dev/null
        fi
    fi
    
    while ! mkdir "$lock_file" 2>/dev/null; do
        sleep 0.1
        count=$((count + 1))
        if [ $count -gt $((timeout * 10)) ]; then
            echo "ERROR: Failed to acquire PGO lock after ${timeout}s: $lock_name" >&2
            return 1
        fi
    done
    echo $$ > "$lock_file/pid"
    return 0
}

# Function to release PGO workspace lock
release_pgo_lock() {
    local lock_name="$1"
    local lock_file="$PGO_LOCK_DIR/${lock_name}.lock"
    
    if [ -d "$lock_file" ]; then
        rm -rf "$lock_file" 2>/dev/null
    fi
}

# Function to validate profile data completeness
validate_profile_data() {
    local workspace="$1"
    local expected_functions="$2"  # Number of expected functions to be profiled
    
    # Check if .gcda files exist
    local gcda_files=$(find "$workspace" -name "*.gcda" 2>/dev/null | wc -l)
    if [ "$gcda_files" -eq 0 ]; then
        echo "ERROR: No .gcda profile files found in $workspace" >&2
        return 1
    fi
    
    # Check if .gcno files exist (may be in workspace or current directory)
    local gcno_files=$(find "$workspace" . -maxdepth 1 -name "*.gcno" 2>/dev/null | wc -l)
    if [ "$gcno_files" -eq 0 ]; then
        echo "WARNING: No .gcno profile metadata files found" >&2
        # Don't fail on missing .gcno files as they might be in a different location
    fi
    
    # Validate profile data integrity using gcov-dump if available
    if command -v gcov-dump >/dev/null 2>&1; then
        for gcda_file in "$workspace"/*.gcda; do
            if [ -f "$gcda_file" ]; then
                if ! gcov-dump -l "$gcda_file" >/dev/null 2>&1; then
                    echo "ERROR: Corrupted profile data in $gcda_file" >&2
                    return 3
                fi
            fi
        done
    fi
    
    # Check file sizes (profile files should not be empty)
    for gcda_file in "$workspace"/*.gcda; do
        if [ -f "$gcda_file" ] && [ ! -s "$gcda_file" ]; then
            echo "ERROR: Empty profile data file: $gcda_file" >&2
            return 4
        fi
    done
    
    return 0
}

# Function to check profile coverage
check_profile_coverage() {
    local workspace="$1"
    local binary="$2"
    
    # Use gcov to check coverage if available
    if command -v gcov >/dev/null 2>&1; then
        local coverage_output
        coverage_output=$(cd "$workspace" && gcov -n optimized_matrix.c 2>/dev/null | grep "Lines executed" | head -1)
        
        if [ -n "$coverage_output" ]; then
            local coverage_percent=$(echo "$coverage_output" | grep -o '[0-9.]*%' | head -1 | tr -d '%')
            if [ -n "$coverage_percent" ]; then
                # Warn if coverage is very low (less than 50%)
                if (( $(echo "$coverage_percent < 50" | bc -l) )); then
                    echo "WARNING: Low profile coverage: ${coverage_percent}% in $workspace" >&2
                    return 1
                fi
            fi
        fi
    fi
    
    return 0
}

# Enhanced PGO compilation function
compile_with_pgo() {
    local flags="$1"
    local workspace="$2"
    local pgo_base="$3"
    local size="$4"
    local verbose="$5"
    local src_path="$6"
    
    # Create workspace directory
    mkdir -p "$workspace"
    if [ ! -d "$workspace" ]; then
        echo "ERROR: Failed to create PGO workspace: $workspace" >&2
        return 1
    fi
    
    # Acquire lock for this specific configuration to prevent conflicts
    local lock_name="pgo_$(echo "${flags}_${size}" | tr ' /' '_')"
    if ! acquire_pgo_lock "$lock_name"; then
        echo "ERROR: Failed to acquire PGO lock" >&2
        return 1
    fi
    
    # Cleanup function to ensure lock is always released
    cleanup_pgo() {
        release_pgo_lock "$lock_name"
        if [ -n "$workspace" ] && [ -d "$workspace" ]; then
            rm -rf "$workspace" 2>/dev/null
        fi
    }
    trap cleanup_pgo EXIT
    
    # Phase 1: Compile with profile generation
    local compile1_start compile1_end compile1_time
    compile1_start=$(date +%s.%N)
    
    local compile1_output
    compile1_output=$(gcc $flags -fprofile-generate -Wall -o "$workspace/${pgo_base}_gen" "$src_path" -lm 2>&1)
    local compile1_status=$?
    
    compile1_end=$(date +%s.%N)
    compile1_time=$(echo "scale=3; $compile1_end - $compile1_start" | bc -l)
    
    if [ $compile1_status -ne 0 ] || [ ! -x "$workspace/${pgo_base}_gen" ]; then
        echo "ERROR: PGO profile generation compilation failed" >&2
        [ "$verbose" = true ] && echo "Compile output: $compile1_output" >&2
        return 2
    fi
    
    # Phase 2: Run profile generation
    local profile_start profile_end profile_time
    profile_start=$(date +%s.%N)
    
    local profile_output profile_status
    profile_output=$(cd "$workspace" && timeout 60 "./${pgo_base}_gen" "$size" 2>&1)
    profile_status=$?
    
    profile_end=$(date +%s.%N)
    profile_time=$(echo "scale=3; $profile_end - $profile_start" | bc -l)
    
    if [ $profile_status -ne 0 ]; then
        echo "ERROR: Profile generation run failed (exit code: $profile_status)" >&2
        [ "$verbose" = true ] && echo "Profile output: $profile_output" >&2
        return 3
    fi
    
    # Phase 3: Validate profile data
    if ! validate_profile_data "$workspace" 5; then
        echo "ERROR: Profile data validation failed" >&2
        return 4
    fi
    
    # Check profile coverage (warning only)
    check_profile_coverage "$workspace" "${pgo_base}_gen"
    
    # Phase 4: Compile with profile data
    # Note: GCC expects the profile files to match the source file name
    # Copy .gcda files to match expected naming pattern
    for gcda_file in "$workspace"/*.gcda; do
        if [ -f "$gcda_file" ]; then
            # Extract the base name and create the expected profile file name
            base_name=$(basename "$gcda_file" .gcda)
            expected_name="${pgo_base}-optimized_matrix.gcda"
            if [ "$gcda_file" != "$workspace/$expected_name" ]; then
                cp "$gcda_file" "$workspace/$expected_name" 2>/dev/null || true
            fi
        fi
    done
    
    local compile2_start compile2_end compile2_time
    compile2_start=$(date +%s.%N)
    
    local compile2_output
    compile2_output=$(cd "$workspace" && gcc $flags -fprofile-use -Wno-coverage-mismatch -Wall -o "${pgo_base}" "$src_path" -lm 2>&1)
    local compile2_status=$?
    
    compile2_end=$(date +%s.%N)
    compile2_time=$(echo "scale=3; $compile2_end - $compile2_start" | bc -l)
    
    # Enhanced error detection for profile usage
    if [ $compile2_status -ne 0 ]; then
        echo "ERROR: PGO profile-use compilation failed (exit code: $compile2_status)" >&2
        [ "$verbose" = true ] && echo "Compile output: $compile2_output" >&2
        return 5
    fi
    
    if echo "$compile2_output" | grep -q "profile count data file not found\|missing profile data\|no profile data available"; then
        echo "ERROR: Profile data not found during compilation" >&2
        [ "$verbose" = true ] && echo "Compile output: $compile2_output" >&2
        return 6
    fi
    
    if echo "$compile2_output" | grep -q "profile data may be out of date\|profile data may be corrupted"; then
        echo "WARNING: Profile data may be stale or corrupted" >&2
        [ "$verbose" = true ] && echo "Compile output: $compile2_output" >&2
    fi
    
    if [ ! -x "$workspace/${pgo_base}" ]; then
        echo "ERROR: PGO optimized binary not created or not executable" >&2
        return 7
    fi
    
    # Calculate total compile time
    local total_compile_time
    total_compile_time=$(echo "scale=3; $compile1_time + $profile_time + $compile2_time" | bc -l)
    
    # Export results for caller
    export PGO_COMPILE_TIME="$total_compile_time"
    export PGO_BINARY="$workspace/${pgo_base}"
    
    # Don't cleanup here - let caller handle it
    trap - EXIT
    release_pgo_lock "$lock_name"
    
    return 0
}

# Function to run PGO-optimized binary and collect results
run_pgo_binary() {
    local binary="$1"
    local size="$2"
    local workspace="$3"
    
    if [ ! -x "$binary" ]; then
        echo "ERROR: PGO binary not executable: $binary" >&2
        return 1
    fi
    
    local result
    result=$(cd "$workspace" && timeout 30 "./${binary##*/}" "$size" 2>&1)
    local run_status=$?
    
    if [ $run_status -ne 0 ]; then
        echo "ERROR: PGO binary execution failed (exit code: $run_status)" >&2
        return 2
    fi
    
    local run_gflops run_time
    run_gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
    run_time=$(echo "$result" | grep "Time:" | awk '{print $2}')
    
    if [ -z "$run_gflops" ] || [ "$run_gflops" = "0" ] || [ -z "$run_time" ]; then
        echo "ERROR: Invalid performance results from PGO binary" >&2
        return 3
    fi
    
    # Export results for caller
    export PGO_GFLOPS="$run_gflops"
    export PGO_TIME="$run_time"
    
    return 0
}
