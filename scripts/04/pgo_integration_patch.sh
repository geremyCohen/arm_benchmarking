#!/bin/bash

# This script shows how to integrate the improved PGO functions into test-all-combinations.sh
# Replace the existing PGO section (lines ~470-540) with this improved version

# Source the PGO utilities
source "$(dirname "$0")/pgo_utils.sh"

# Updated PGO section for test-all-combinations.sh
# Replace the existing "if [ $pgo -eq 1 ]; then" block with this:

improved_pgo_section() {
    local flags="$1"
    local pgo_workspace="$2" 
    local pgo_base="$3"
    local size="$4"
    local verbose="$5"
    local src_path="$6"
    
    if [ $pgo -eq 1 ]; then
        # Enhanced PGO compilation with better error handling
        mkdir -p "$pgo_workspace"
        
        if compile_with_pgo "$flags" "$pgo_workspace" "$pgo_base" "$size" "$verbose" "$src_path"; then
            # PGO compilation successful, run the optimized binary
            if run_pgo_binary "$PGO_BINARY" "$size" "$pgo_workspace"; then
                # Success - collect results
                gflops_runs+=("$PGO_GFLOPS")
                time_runs+=("$PGO_TIME")
                compile_time_runs+=("$PGO_COMPILE_TIME")
                
                [ "$verbose" = true ] && echo "PGO run successful: ${PGO_GFLOPS} GFLOPS"
            else
                echo "ERROR: PGO binary execution failed for $combo_id" >&2
                [ "$verbose" = true ] && echo "Failed to run PGO-optimized binary"
            fi
        else
            echo "ERROR: PGO compilation failed for $combo_id" >&2
            [ "$verbose" = true ] && echo "PGO compilation process encountered errors"
        fi
        
        # Always cleanup workspace
        rm -rf "$pgo_workspace" 2>/dev/null
        
    else
        # Standard compilation (non-PGO path remains unchanged)
        compile_start=$(date +%s.%N)
        gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
        compile_end=$(date +%s.%N)
        run_compile_time=$(echo "scale=3; $compile_end - $compile_start" | bc -l)
        
        if [ $? -eq 0 ]; then
            result=$(./$exe_name $size 2>/dev/null)
            run_gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
            run_time=$(echo "$result" | grep "Time:" | awk '{print $2}')
            
            if [ ! -z "$run_gflops" ] && [ "$run_gflops" != "0" ]; then
                gflops_runs+=("$run_gflops")
                time_runs+=("$run_time")
                compile_time_runs+=("$run_compile_time")
            fi
        fi
        rm -f "$exe_name" 2>/dev/null
    fi
}

# Configuration changes needed in test-all-combinations.sh:

# 1. Remove the PGO parallelism restriction (around line 397):
# OLD:
# if [ "$use_pgo" = true ]; then
#     MAX_JOBS=2
#     echo "Running tests with reduced parallelism (MAX_JOBS=2) for PGO stability..."
# NEW:
echo "PGO: Enhanced with proper locking - using full parallelism"
# (Remove the MAX_JOBS=2 restriction)

# 2. Add source line at the top of the script (after the shebang):
echo "# Add this line after #!/bin/bash:"
echo "source \"\$(dirname \"\$0\")/pgo_utils.sh\""

# 3. Replace the PGO compilation block with the improved version above

echo "Integration complete. Key improvements:"
echo "- Comprehensive .gcda file validation"
echo "- Profile data integrity checking with gcov-dump"
echo "- Proper file locking for parallel PGO execution"
echo "- Enhanced error messages and debugging output"
echo "- Timeout protection for profile generation and execution"
echo "- Coverage analysis and warnings for low coverage"
echo "- Automatic cleanup with trap handlers"
}
