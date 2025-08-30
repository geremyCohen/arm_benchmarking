#!/bin/bash
# collect-baseline.sh - Complete baseline collection: compile, test, profile, and save results

echo "=== Collecting Baseline Performance Data ==="
echo

# Create results directory
mkdir -p results

# Clear previous results to prevent duplicates
> results/baseline_summary.txt
> results/baseline_analysis.txt

# Compile baseline
echo "Building baseline matrix multiplication..."
make baseline

echo "Running baseline measurements and profiling..."
echo

# Test sizes and collect data
for size in micro small medium; do
    echo "Testing $size matrix..."
    
    # Run performance test
    ./baseline_matrix $size > results/baseline_${size}.txt
    
    # Run profiling (only for small to avoid long waits)
    if [ "$size" = "small" ]; then
        echo "Profiling $size matrix for optimization insights..."
        perf stat -e cycles,instructions,stalled-cycles-backend ./baseline_matrix $size 2> results/baseline_profile.txt
        
        # Extract key profiling metrics
        backend_stalls=$(grep "stalled-cycles-backend" results/baseline_profile.txt | awk '{print $4}' | sed 's/%//')
        ipc=$(grep "insn per cycle" results/baseline_profile.txt | awk '{print $4}')
        
        echo "Backend stalls: ${backend_stalls}% (>50% indicates memory-bound)" >> results/baseline_analysis.txt
        echo "Instructions per cycle: ${ipc}" >> results/baseline_analysis.txt
    fi
    
    # Extract key metrics
    gflops=$(grep "Performance:" results/baseline_${size}.txt | awk '{print $2}')
    time=$(grep "Time:" results/baseline_${size}.txt | awk '{print $2}')
    
    echo "$size: ${gflops} GFLOPS (${time}s)" >> results/baseline_summary.txt
done

echo
echo "=== Baseline Results Saved ==="
cat results/baseline_summary.txt

echo
echo "=== Performance Analysis ==="
if [ -f results/baseline_analysis.txt ]; then
    cat results/baseline_analysis.txt
    echo
fi

echo "✓ Baseline data saved to results/ directory"
echo "✓ Ready for compiler optimization comparisons in section 04"
