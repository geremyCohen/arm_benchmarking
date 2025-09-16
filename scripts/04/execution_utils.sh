#!/bin/bash

# Comprehensive execution function for PGO+BOLT combinations
# This handles all combinations: standard, PGO-only, BOLT-only, PGO+BOLT

execute_combination() {
    local flags="$1"
    local size="$2"
    local combo_id="$3"
    local num_runs="$4"
    local pgo="$5"
    local bolt="$6"
    local verbose="$7"
    
    local gflops_runs=()
    local time_runs=()
    local compile_time_runs=()
    
    # Determine execution strategy based on PGO and BOLT flags
    local base_binary=""
    local bolt_binary=""
    local final_binary=""
    
    # Step 1: Compile base binary (with or without PGO)
    if [ $pgo -eq 1 ]; then
        # PGO compilation
        local pgo_workspace="temp/pgo_workspace_$$_${combo_id}"
        local pgo_base="pgo_${combo_id}"
        local src_path="$(pwd)/src/optimized_matrix.c"
        
        if compile_with_pgo "$flags" "$pgo_workspace" "$pgo_base" "$size" "$verbose" "$src_path"; then
            base_binary="$PGO_BINARY"
            compile_time_runs+=("$PGO_COMPILE_TIME")
            [ "$verbose" = true ] && echo "PGO compilation successful"
        else
            echo "ERROR: PGO compilation failed for $combo_id" >&2
            return 1
        fi
    else
        # Standard compilation
        local exe_name="temp/combo_${combo_id}_$$_${RANDOM}"
        local compile_start compile_end run_compile_time
        
        compile_start=$(date +%s.%N)
        gcc $flags -Wall -o "$exe_name" src/optimized_matrix.c -lm 2>/dev/null
        compile_end=$(date +%s.%N)
        run_compile_time=$(echo "scale=3; $compile_end - $compile_start" | bc -l)
        
        if [ $? -eq 0 ] && [ -x "$exe_name" ]; then
            base_binary="$exe_name"
            compile_time_runs+=("$run_compile_time")
            [ "$verbose" = true ] && echo "Standard compilation successful"
        else
            echo "ERROR: Standard compilation failed for $combo_id" >&2
            return 2
        fi
    fi
    
    # Step 2: Apply BOLT if requested (only on first run)
    if [ $bolt -eq 1 ]; then
        local bolt_workspace="temp/bolt_workspace_$$_${combo_id}"
        mkdir -p "$bolt_workspace"
        bolt_binary="$bolt_workspace/bolt_optimized"
        
        [ "$verbose" = true ] && echo "Applying BOLT optimization..."
        
        if apply_bolt_optimization "$base_binary" "$bolt_binary" "$bolt_workspace" "$size" "$verbose"; then
            final_binary="$bolt_binary"
            [ "$verbose" = true ] && echo "BOLT optimization successful"
        else
            echo "ERROR: BOLT optimization failed for $combo_id" >&2
            # Clean up
            [ $pgo -eq 1 ] && rm -rf "$pgo_workspace" 2>/dev/null
            [ $pgo -eq 0 ] && rm -f "$base_binary" 2>/dev/null
            rm -rf "$bolt_workspace" 2>/dev/null
            return 3
        fi
    else
        final_binary="$base_binary"
    fi
    
    # Step 3: Run the final binary multiple times
    for ((run=1; run<=num_runs; run++)); do
        [ "$verbose" = true ] && echo "Executing run $run/$num_runs for $combo_id"
        
        if [ $bolt -eq 1 ]; then
            # Use BOLT execution function
            if run_bolt_binary "$final_binary" "$size" "$(dirname "$final_binary")"; then
                gflops_runs+=("$BOLT_GFLOPS")
                time_runs+=("$BOLT_TIME")
            else
                echo "ERROR: BOLT binary execution failed on run $run for $combo_id" >&2
                # Don't fail completely, just skip this run
                continue
            fi
        else
            # Standard execution
            local result
            if [ $pgo -eq 1 ]; then
                # PGO binary execution
                if run_pgo_binary "$final_binary" "$size" "$(dirname "$final_binary")"; then
                    gflops_runs+=("$PGO_GFLOPS")
                    time_runs+=("$PGO_TIME")
                else
                    echo "ERROR: PGO binary execution failed on run $run for $combo_id" >&2
                    continue
                fi
            else
                # Standard binary execution
                result=$(timeout 30 "$final_binary" "$size" 2>/dev/null)
                local run_status=$?
                
                if [ $run_status -eq 0 ]; then
                    local run_gflops run_time
                    run_gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                    run_time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                    
                    if [ -n "$run_gflops" ] && [ "$run_gflops" != "0" ]; then
                        gflops_runs+=("$run_gflops")
                        time_runs+=("$run_time")
                    else
                        echo "ERROR: Invalid performance results on run $run for $combo_id" >&2
                        continue
                    fi
                else
                    echo "ERROR: Binary execution failed on run $run for $combo_id (exit code: $run_status)" >&2
                    continue
                fi
            fi
        fi
    done
    
    # Step 4: Calculate results and cleanup
    if [ ${#gflops_runs[@]} -gt 0 ]; then
        local avg_gflops avg_time avg_compile_time
        avg_gflops=$(calculate_trimmed_mean "${gflops_runs[@]}")
        avg_time=$(calculate_trimmed_mean "${time_runs[@]}")
        avg_compile_time=$(calculate_trimmed_mean "${compile_time_runs[@]}")
        
        # Export results for caller
        export EXEC_GFLOPS="$avg_gflops"
        export EXEC_TIME="$avg_time"
        export EXEC_COMPILE_TIME="$avg_compile_time"
        export EXEC_RUNS_DETAIL=$(printf "%s," "${gflops_runs[@]}")
        export EXEC_RUNS_DETAIL=${EXEC_RUNS_DETAIL%,}
        
        [ "$verbose" = true ] && echo "Execution completed: $avg_gflops GFLOPS (${#gflops_runs[@]} successful runs)"
    else
        echo "ERROR: No successful runs for $combo_id" >&2
        # Cleanup and return error
        [ $pgo -eq 1 ] && rm -rf "$pgo_workspace" 2>/dev/null
        [ $pgo -eq 0 ] && [ "$final_binary" != "$bolt_binary" ] && rm -f "$base_binary" 2>/dev/null
        [ $bolt -eq 1 ] && rm -rf "$bolt_workspace" 2>/dev/null
        return 4
    fi
    
    # Cleanup
    [ $pgo -eq 1 ] && rm -rf "$pgo_workspace" 2>/dev/null
    [ $pgo -eq 0 ] && [ "$final_binary" != "$bolt_binary" ] && rm -f "$base_binary" 2>/dev/null
    [ $bolt -eq 1 ] && rm -rf "$bolt_workspace" 2>/dev/null
    
    return 0
}
