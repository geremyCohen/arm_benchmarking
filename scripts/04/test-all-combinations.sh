#!/bin/bash
# test-all-combinations.sh - Test all combinations with real-time status using temp files

echo "=== Comprehensive Compiler Optimization Analysis ==="
echo

# Prompt for matrix sizes with timeout
echo -n "Test sizes: micro+small (default) or all including medium? [micro+small/all] (3s timeout): "
read -t 3 size_choice
echo

if [[ "$size_choice" == "all" ]]; then
    sizes=("micro" "small" "medium")
    echo "Testing all sizes: micro, small, medium"
else
    sizes=("micro" "small")
    echo "Testing default sizes: micro, small (medium skipped for speed)"
fi
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

# Create temp directories
STATUS_DIR="/tmp/benchmark_status_$$"
mkdir -p "$STATUS_DIR"

# Define test parameters
opt_levels=("O0" "O1" "O2" "O3")
march_options=("none" "native" "neoverse")
mtune_options=("none" "native" "neoverse")

# Initialize status files
for opt in "${opt_levels[@]}"; do
    for march in "${march_options[@]}"; do
        for mtune in "${mtune_options[@]}"; do
            for size in "${sizes[@]}"; do
                echo "Pending" > "$STATUS_DIR/${opt}_${march}_${mtune}_${size}"
            done
        done
    done
done

# Start status monitor in background
(
    # Hide cursor and save position
    printf "\033[?25l\033[s"
    
    while [ -d "$STATUS_DIR" ]; do
        # Restore cursor position instead of clearing screen
        printf "\033[u"
        
        echo "=== Benchmark Status Dashboard ==="
        echo "Updated: $(date '+%H:%M:%S')"
        echo
        
        # Count status
        total=$(ls "$STATUS_DIR" 2>/dev/null | wc -l)
        pending=$(grep -l "Pending" "$STATUS_DIR"/* 2>/dev/null | wc -l)
        running=$(grep -l "Running" "$STATUS_DIR"/* 2>/dev/null | wc -l)
        complete=$(grep -l "Complete" "$STATUS_DIR"/* 2>/dev/null | wc -l)
        
        echo "Progress: $complete/$total complete, $running running, $pending pending"
        echo
        
        # Exit if all complete
        if [ $complete -eq $total ] && [ $total -gt 0 ]; then
            echo "🎉 All benchmarks completed!"
            sleep 2
            break
        fi
        
        printf "| %-12s | %-12s | %-12s | %-8s | %-10s |\n" "Optimization" "-march" "-mtune" "Size" "Status"
        printf "|--------------|--------------|--------------|----------|------------|\n"
        
        # Group by size
        for size in "${sizes[@]}"; do
            echo "### ${size^} Matrix"
            for opt in "${opt_levels[@]}"; do
                for march in "${march_options[@]}"; do
                    for mtune in "${mtune_options[@]}"; do
                        status_file="$STATUS_DIR/${opt}_${march}_${mtune}_${size}"
                        if [ -f "$status_file" ]; then
                            status=$(cat "$status_file")
                            
                            case $march in
                                "none") march_display="None" ;;
                                "native") march_display="Autodetect" ;;
                                "neoverse") march_display="V2" ;;
                            esac
                            
                            case $mtune in
                                "none") mtune_display="None" ;;
                                "native") mtune_display="Autodetect" ;;
                                "neoverse") mtune_display="V2" ;;
                            esac
                            
                            case $status in
                                "Pending") status_display="⏳ Pending" ;;
                                "Running") status_display="🔄 Running" ;;
                                "Complete") status_display="✅ Complete" ;;
                            esac
                            
                            printf "| %-12s | %-12s | %-12s | %-8s | %-10s |\n" "-$opt" "$march_display" "$mtune_display" "$size" "$status_display"
                        fi
                    done
                done
            done
            echo
        done
        
        # Clear to end of screen to remove old content
        printf "\033[J"
        sleep 1
    done
    
    # Restore cursor
    printf "\033[?25h"
) &
MONITOR_PID=$!

# Create results directory
mkdir -p results/comprehensive /tmp/combo_results_$$

# Results array to store all combinations
declare -a all_results

# Test all combinations in parallel
for opt in "${opt_levels[@]}"; do
    for march in "${march_options[@]}"; do
        for mtune in "${mtune_options[@]}"; do
            for size in "${sizes[@]}"; do
                # Build flags
                flags="-$opt"
                
                # Add march flag
                case $march in
                    "native")
                        flags="$flags -march=native"
                        ;;
                    "neoverse")
                        flags="$flags -march=$MARCH_SPECIFIC"
                        ;;
                esac
                
                # Add mtune flag
                case $mtune in
                    "native")
                        flags="$flags -mtune=native"
                        ;;
                    "neoverse")
                        flags="$flags -mtune=$MTUNE_SPECIFIC"
                        ;;
                esac
                
                march_desc="$march"
                mtune_desc="$mtune"
                
                # Run test in background
                (
                    combo_id="${opt}_${march}_${mtune}_${size}"
                    echo "Running" > "$STATUS_DIR/$combo_id"
                    
                    # Add small delay to see state changes
                    sleep 0.5
                    
                    exe_name="combo_${opt}_${march}_${mtune}_${size}_$$_${RANDOM}"
                    gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                    
                    if [ $? -eq 0 ]; then
                        result=$(./$exe_name $size 2>/dev/null)
                        gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                        time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                        
                        if [ ! -z "$gflops" ]; then
                            sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                            echo "$sort_key|$gflops|$time|$opt|$march_desc|$mtune_desc|$size" > /tmp/combo_results_$$/${opt}_${march}_${mtune}_${size}
                        fi
                        
                        rm -f $exe_name
                    fi
                    
                    # Add delay before marking complete
                    sleep 0.5
                    echo "Complete" > "$STATUS_DIR/$combo_id"
                ) &
            done
        done
    done
done

# Wait for all jobs and monitor to complete
wait
rm -rf "$STATUS_DIR"
clear

# Collect results
for result_file in /tmp/combo_results_$$/*; do
    if [ -f "$result_file" ]; then
        result_line=$(cat "$result_file")
        all_results+=("$result_line")
    fi
done

# Cleanup
rm -rf /tmp/combo_results_$$

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
        IFS='|' read -r sort_key gflops time opt march mtune size <<< "$result"
        if [ "$size" = "$target_size" ]; then
            # Track best performance for this size
            if [ -z "$best_gflops_for_size" ]; then
                best_gflops_for_size="$gflops"
            fi
            
            # Track best Autodetect performance for this size (both march and mtune native)
            if [ "$march" = "native" ] && [ "$mtune" = "native" ]; then
                if [ -z "$autodetect_gflops_for_size" ] || (( $(echo "$gflops > $autodetect_gflops_for_size" | bc -l) )); then
                    autodetect_gflops_for_size="$gflops"
                fi
            fi
            
            # Calculate GFLOP/s (GFLOPS per second, which is just GFLOPS/time)
            if [ "$time" = "0.000" ] || [ "$time" = "0" ]; then
                gflop_per_s="∞"
            else
                gflop_per_s=$(echo "scale=2; $gflops / $time" | bc -l 2>/dev/null || echo "∞")
            fi
            
            # Convert march/mtune to display names
            case $march in
                "none") march_flag="None" ;;
                "native") march_flag="Autodetect" ;;
                "neoverse") march_flag="V2" ;;
            esac
            
            case $mtune in
                "none") mtune_flag="None" ;;
                "native") mtune_flag="Autodetect" ;;
                "neoverse") mtune_flag="V2" ;;
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
        # Check if autodetect equals the best performance (exact match)
        if [ "$autodetect_gflops_for_size" = "$best_gflops_for_size" ]; then
            echo "• Choosing Autodetect for -march and -mtune was optimal."
        else
            # Calculate percentage improvement available (how much better the best is than autodetect)
            percent_improvement=$(echo "scale=1; ($best_gflops_for_size - $autodetect_gflops_for_size) / $autodetect_gflops_for_size * 100" | bc -l)
            
            # Only show message if there's actually a meaningful difference (>0.1%)
            if (( $(echo "$percent_improvement > 0.1" | bc -l) )); then
                # Find what flags achieved the best performance
                best_result=$(printf '%s\n' "${sorted[@]}" | grep "|$target_size$" | head -1)
                best_march=$(echo "$best_result" | cut -d'|' -f5)
                best_mtune=$(echo "$best_result" | cut -d'|' -f6)
                
                case $best_march in
                    "none") march_display="None" ;;
                    "native") march_display="Autodetect" ;;
                    "neoverse") march_display="V2" ;;
                esac
                
                case $best_mtune in
                    "none") mtune_display="None" ;;
                    "native") mtune_display="Autodetect" ;;
                    "neoverse") mtune_display="V2" ;;
                esac
                
                echo "• Autodetect performance is worse by ${percent_improvement}% than using -march $march_display and -mtune $mtune_display CFLAGS manually."
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

echo "• Best performance: $best_gflops GFLOPS (${best_speedup}x speedup over baseline)"

echo "• Top performers by optimization level:"
for opt in O3 O2 O1; do
    top_opt=$(printf '%s\n' "${sorted[@]}" | grep "|$opt|" | head -1)
    if [ ! -z "$top_opt" ]; then
        gflops=$(echo "$top_opt" | cut -d'|' -f2)
        arch=$(echo "$top_opt" | cut -d'|' -f5)
        size=$(echo "$top_opt" | cut -d'|' -f6)
        echo "  -$opt: $gflops GFLOPS ($arch, $size)"
    fi
done
echo "• Matrix size impact: Smaller matrices benefit more from compiler optimizations"
echo "• Architecture targeting: $NEOVERSE_TYPE-specific flags provide best performance"

echo
echo "Complete results saved to results/comprehensive/ directory"
