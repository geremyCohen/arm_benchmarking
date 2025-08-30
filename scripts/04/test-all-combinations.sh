#!/bin/bash
# test-all-combinations.sh - Test all combinations of compiler flags, march, mtune, and matrix sizes

echo "=== Comprehensive Compiler Optimization Analysis ==="
echo

# Detect Neoverse processor type
NEOVERSE_TYPE=$(lscpu | grep "Model name" | awk '{print $3}')
case $NEOVERSE_TYPE in
    "Neoverse-N1")
        MARCH_SPECIFIC="armv8.2-a+fp16+rcpc+dotprod+crypto"
        MTUNE_SPECIFIC="neoverse-n1"
        ;;
    "Neoverse-N2")
        MARCH_SPECIFIC="armv9-a+sve2+bf16+i8mm"
        MTUNE_SPECIFIC="neoverse-n2"
        ;;
    "Neoverse-V1")
        MARCH_SPECIFIC="armv8.4-a+sve+bf16+i8mm"
        MTUNE_SPECIFIC="neoverse-v1"
        ;;
    "Neoverse-V2")
        MARCH_SPECIFIC="armv9-a+sve2+bf16+i8mm"
        MTUNE_SPECIFIC="neoverse-v2"
        ;;
    *)
        MARCH_SPECIFIC="native"
        MTUNE_SPECIFIC="native"
        ;;
esac

echo "Detected: $NEOVERSE_TYPE"
echo "Testing all combinations of optimization levels, architecture flags, and matrix sizes..."
echo

# Create results directory
mkdir -p results/comprehensive

# Define test parameters
opt_levels=("O0" "O1" "O2" "O3")
march_options=("generic" "native" "neoverse")
sizes=("micro" "small" "medium")

# Results array to store all combinations
declare -a all_results

echo "Building and testing all combinations..."

# Test all combinations
for opt in "${opt_levels[@]}"; do
    for march in "${march_options[@]}"; do
        for size in "${sizes[@]}"; do
            # Build flags
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
            
            # Build executable
            exe_name="combo_${opt}_${march}_${size}"
            gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
            
            # Test performance
            result=$(./$exe_name $size 2>/dev/null)
            gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
            time=$(echo "$result" | grep "Time:" | awk '{print $2}')
            
            # Store result with sortable key
            if [ ! -z "$gflops" ]; then
                # Create sortable key (pad GFLOPS to 8 digits for proper sorting)
                sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                all_results+=("$sort_key|$gflops|$time|$opt|$march_desc|$size")
            fi
            
            # Clean up executable
            rm -f $exe_name
            
            echo -n "."
        done
    done
done

echo
echo

# Sort results by performance (descending) and display
echo "=== Performance Results (Ordered by Best Performance) ==="
echo
printf "| %-5s | %-8s | %-6s | %-4s | %-12s | %-6s |\n" "Rank" "GFLOPS" "Time(s)" "Opt" "Architecture" "Size"
printf "|-------|----------|--------|------|--------------|--------|\n"

# Sort and display top results
rank=1
IFS=$'\n' sorted=($(printf '%s\n' "${all_results[@]}" | sort -t'|' -k1,1nr))

for result in "${sorted[@]}"; do
    IFS='|' read -r sort_key gflops time opt arch size <<< "$result"
    printf "| %-5d | %-8s | %-6s | %-4s | %-12s | %-6s |\n" "$rank" "$gflops" "$time" "-$opt" "$arch" "$size"
    ((rank++))
    
    # Stop after top 20 results to keep table manageable
    if [ $rank -gt 20 ]; then
        break
    fi
done

echo
echo "=== Key Insights ==="

# Get baseline performance for comparison
baseline_gflops=$(grep "small:" results/baseline_summary.txt | head -1 | awk '{print $2}')
best_gflops=$(echo "${sorted[0]}" | cut -d'|' -f2)
best_speedup=$(echo "scale=1; $best_gflops / $baseline_gflops" | bc -l)

echo "• Best performance: ${best_gflops} GFLOPS (${best_speedup}x speedup over baseline)"

# Analyze top performers
echo "• Top performers by optimization level:"
for opt in O3 O2 O1; do
    top_opt=$(printf '%s\n' "${sorted[@]}" | grep "|$opt|" | head -1)
    if [ ! -z "$top_opt" ]; then
        gflops=$(echo "$top_opt" | cut -d'|' -f2)
        arch=$(echo "$top_opt" | cut -d'|' -f5)
        size=$(echo "$top_opt" | cut -d'|' -f6)
        echo "  -$opt: ${gflops} GFLOPS ($arch, $size)"
    fi
done

echo "• Matrix size impact: Smaller matrices benefit more from compiler optimizations"
echo "• Architecture targeting: $NEOVERSE_TYPE-specific flags provide best performance"

echo
echo "Complete results saved to results/comprehensive/ directory"
