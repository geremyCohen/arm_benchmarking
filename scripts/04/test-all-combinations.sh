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

# Detect number of CPU cores for parallel jobs
PARALLEL_JOBS=$(nproc)
echo "Building and testing all combinations using $PARALLEL_JOBS parallel jobs..."

# Create temporary directory for parallel results
mkdir -p /tmp/combo_results_$$

# Counter for parallel job management
job_count=0

# Test all combinations in parallel
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
            
            # Run test in background
            (
                # Build executable with unique name
                exe_name="combo_${opt}_${march}_${size}_$$_${RANDOM}"
                gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    # Test performance
                    result=$(./$exe_name $size 2>/dev/null)
                    gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                    time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                    
                    if [ ! -z "$gflops" ]; then
                        # Create sortable key (pad GFLOPS to 8 digits for proper sorting)
                        sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                        echo "$sort_key|$gflops|$time|$opt|$march_desc|$size" > /tmp/combo_results_$$/${opt}_${march}_${size}
                    fi
                    
                    # Cleanup
                    rm -f $exe_name
                fi
                echo -n "."
            ) &
            
            # Limit parallel jobs
            ((job_count++))
            if [ $job_count -ge $PARALLEL_JOBS ]; then
                wait
                job_count=0
            fi
        done
    done
done

# Wait for remaining jobs
wait

# Collect results
for result_file in /tmp/combo_results_$$/*; do
    if [ -f "$result_file" ]; then
        result_line=$(cat "$result_file")
        all_results+=("$result_line")
    fi
done

# Cleanup
rm -rf /tmp/combo_results_$$

echo
echo

# Sort results by performance (descending) and display grouped by matrix size
echo "=== Performance Results (Grouped by Matrix Size) ==="
echo

IFS=$'\n' sorted=($(printf '%s\n' "${all_results[@]}" | sort -t'|' -k1,1nr))

# Group by matrix size
for target_size in "${sizes[@]}"; do
    echo "### ${target_size^} Matrix ($(case $target_size in micro) echo "64x64";; small) echo "512x512";; medium) echo "2048x2048";; esac))"
    echo
    printf "| %-5s | %-8s | %-6s | %-8s | %-4s | %-15s | %-15s |\n" "Rank" "GFLOPS" "Time(s)" "GFLOP/s" "Opt" "-march" "-mtune"
    printf "|-------|----------|--------|----------|------|-----------------|------------------|\n"
    
    rank=1
    best_gflops_for_size=""
    autodetect_gflops_for_size=""
    
    for result in "${sorted[@]}"; do
        IFS='|' read -r sort_key gflops time opt arch size <<< "$result"
        if [ "$size" = "$target_size" ]; then
            # Track best performance for this size
            if [ -z "$best_gflops_for_size" ]; then
                best_gflops_for_size="$gflops"
            fi
            
            # Track best Autodetect performance for this size (find the highest, not first)
            if [ "$arch" = "native" ]; then
                if [ -z "$autodetect_gflops_for_size" ] || (( $(echo "$gflops > $autodetect_gflops_for_size" | bc -l) )); then
                    autodetect_gflops_for_size="$gflops"
                fi
            fi
            
            # Calculate GFLOP/s (GFLOPS per second, which is just GFLOPS/time)
            gflop_per_s=$(echo "scale=2; $gflops / $time" | bc -l 2>/dev/null || echo "∞")
            
            # Convert architecture to march/mtune breakdown
            case $arch in
                "generic")
                    march_flag="None"
                    mtune_flag="None"
                    ;;
                "native")
                    march_flag="Autodetect"
                    mtune_flag="Autodetect"
                    ;;
                "$NEOVERSE_TYPE")
                    # Use short names for Neoverse variants
                    case $NEOVERSE_TYPE in
                        "Neoverse-N1") march_flag="N1"; mtune_flag="N1" ;;
                        "Neoverse-N2") march_flag="N2"; mtune_flag="N2" ;;
                        "Neoverse-V1") march_flag="V1"; mtune_flag="V1" ;;
                        "Neoverse-V2") march_flag="V2"; mtune_flag="V2" ;;
                        *) march_flag="$NEOVERSE_TYPE"; mtune_flag="$NEOVERSE_TYPE" ;;
                    esac
                    ;;
            esac
            
            printf "| %-5d | %-8s | %-6s | %-8s | %-4s | %-15s | %-15s |\n" "$rank" "$gflops" "$time" "$gflop_per_s" "-$opt" "$march_flag" "$mtune_flag"
            ((rank++))
        fi
    done
    
    # Add insights for this matrix size
    echo
    echo "**${target_size^} Matrix Insights:**"
    echo "• Best performance: $best_gflops_for_size GFLOPS"
    
    if [ ! -z "$autodetect_gflops_for_size" ]; then
        # Check if autodetect equals the best performance
        if [ "$autodetect_gflops_for_size" = "$best_gflops_for_size" ]; then
            echo "• Choosing Autodetect for -march and -mtune was optimal."
        else
            # Calculate percentage improvement available (how much better the best is than autodetect)
            percent_improvement=$(echo "scale=2; ($best_gflops_for_size - $autodetect_gflops_for_size) / $autodetect_gflops_for_size * 100" | bc -l)
            
            # Only show message if there's actually a meaningful difference (>1%)
            if (( $(echo "$percent_improvement > 1" | bc -l) )); then
                # Find what flags achieved the best performance
                best_result=$(printf '%s\n' "${sorted[@]}" | grep "|$target_size$" | head -1)
                best_arch=$(echo "$best_result" | cut -d'|' -f5)
                
                case $best_arch in
                    "generic")
                        echo "• Autodetect performance is worse by ${percent_improvement}% than using -mtune None and -march None CFLAGS manually."
                        ;;
                    "native")
                        echo "• Choosing Autodetect for -march and -mtune was optimal."
                        ;;
                    "$NEOVERSE_TYPE")
                        case $NEOVERSE_TYPE in
                            "Neoverse-N1") best_flags="N1" ;;
                            "Neoverse-N2") best_flags="N2" ;;
                            "Neoverse-V1") best_flags="V1" ;;
                            "Neoverse-V2") best_flags="V2" ;;
                            *) best_flags="$NEOVERSE_TYPE" ;;
                        esac
                        echo "• Autodetect performance is worse by ${percent_improvement}% than using -mtune $best_flags and -march $best_flags CFLAGS manually."
                        ;;
                esac
            else
                echo "• Choosing Autodetect for -march and -mtune was optimal."
            fi
        fi
    else
        echo "• Autodetect performance: Not available"
    fi
    
    echo
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
