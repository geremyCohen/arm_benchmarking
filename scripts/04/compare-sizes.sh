#!/bin/bash
# compare-sizes.sh - Compare baseline vs optimized performance across matrix sizes

echo "=== Baseline vs Optimized Performance Comparison ==="
echo

# Build optimized version if not exists
if [ ! -f optimized_neoverse ]; then
    echo "Building optimized version..."
    NEOVERSE_TYPE=$(lscpu | grep "Model name" | awk '{print $3}')
    case $NEOVERSE_TYPE in
        "Neoverse-V2") MARCH_FLAGS="-march=armv9-a+sve2+bf16+i8mm -mtune=neoverse-v2" ;;
        *) MARCH_FLAGS="-march=native -mtune=native" ;;
    esac
    gcc -O3 $MARCH_FLAGS -Wall -o optimized_neoverse src/optimized_matrix.c -lm
    echo
fi

# Test sizes
sizes=("micro" "small" "medium")
echo "| Size | Baseline (GFLOPS) | Optimized (GFLOPS) | Speedup | Time Reduction |"
echo "|------|-------------------|---------------------|---------|----------------|"

for size in "${sizes[@]}"; do
    # Run baseline
    baseline_out=$(./baseline_matrix $size)
    baseline_gflops=$(echo "$baseline_out" | grep "Performance:" | awk '{print $2}')
    baseline_time=$(echo "$baseline_out" | grep "Time:" | awk '{print $2}')
    
    # Run optimized
    opt_out=$(./optimized_neoverse $size)
    opt_gflops=$(echo "$opt_out" | grep "Performance:" | awk '{print $2}')
    opt_time=$(echo "$opt_out" | grep "Time:" | awk '{print $2}')
    
    # Calculate speedup and time reduction
    speedup=$(echo "scale=1; $opt_gflops / $baseline_gflops" | bc -l)
    time_reduction=$(echo "scale=1; ($baseline_time - $opt_time) / $baseline_time * 100" | bc -l)
    
    printf "| %-4s | %-17s | %-19s | %-7s | %-14s |\n" "$size" "$baseline_gflops" "$opt_gflops" "${speedup}x" "${time_reduction}%"
done

echo
echo "=== Analysis ==="
echo "• Micro/Small matrices: High speedup due to instruction-level optimizations"
echo "• Medium matrices: Lower speedup due to memory bandwidth limitations"
echo "• Larger matrices become increasingly memory-bound, reducing compiler optimization impact"
