                                            if [ $pgo -eq 1 ]; then
                                                # Enhanced PGO compilation with better error handling and parallel support
                                                pgo_workspace="temp/pgo_workspace_$$_${combo_id}_${run}"
                                                pgo_base="pgo_${combo_id}_${run}"
                                                src_path="$(pwd)/src/optimized_matrix.c"
                                                
                                                # Use improved PGO functions
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
