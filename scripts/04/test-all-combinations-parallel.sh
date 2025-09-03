#!/bin/bash
# test-all-combinations-parallel.sh - Parallel testing of all compiler combinations

# Detect number of CPU cores for parallel jobs
PARALLEL_JOBS=$(nproc)
echo "Using $PARALLEL_JOBS parallel jobs"

# Create temporary directory for parallel results
mkdir -p /tmp/combo_results

# Function to test a single combination
test_combination() {
    local opt=$1
    local march=$2  
    local size=$3
    local flags=$4
    local march_desc=$5
    
    # Build executable
    exe_name="combo_${opt}_${march}_${size}_$$"
    gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
    
    if [ $? -eq 0 ]; then
        # Test performance
        result=$(./$exe_name $size 2>/dev/null)
        gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
        time=$(echo "$result" | grep "Time:" | awk '{print $2}')
        
        # Save result to temp file
        echo "${gflops}|${gflops}|${time}|${opt}|${march_desc}|${size}" > /tmp/combo_results/${opt}_${march}_${size}
        
        # Cleanup
        rm -f $exe_name
    fi
}

# Export function for parallel execution
export -f test_combination

# Build argument list for parallel execution
args_file="/tmp/test_args"
> $args_file

for opt in "${opt_levels[@]}"; do
    for march in "${march_options[@]}"; do
        for size in "${sizes[@]}"; do
            # Build flags based on march option
            case $march in
                "generic")
                    flags="-$opt"
                    march_desc="generic"
                    ;;
                "native")
                    flags="-$opt -march=native -mtune=native"
                    march_desc="native"
                    ;;
                "neoverse")
                    flags="-$opt -march=$MARCH_SPECIFIC -mtune=$MTUNE_SPECIFIC"
                    march_desc="$NEOVERSE_TYPE"
                    ;;
            esac
            
            echo "$opt $march $size \"$flags\" $march_desc" >> $args_file
        done
    done
done

# Run tests in parallel
echo "Running $(wc -l < $args_file) combinations in parallel..."
cat $args_file | xargs -n 5 -P $PARALLEL_JOBS bash -c 'test_combination "$@"' _

# Collect results
for result_file in /tmp/combo_results/*; do
    if [ -f "$result_file" ]; then
        cat "$result_file" >> /tmp/all_results
    fi
done

# Cleanup
rm -rf /tmp/combo_results $args_file
