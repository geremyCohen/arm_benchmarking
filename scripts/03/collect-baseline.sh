#!/bin/bash
# collect-baseline.sh - Collect baseline performance data for comparison

echo "=== Collecting Baseline Performance Data ==="
echo

# Create results directory
mkdir -p results

# Compile baseline
echo "Building baseline..."
make baseline

echo "Running baseline measurements..."

# Test sizes and collect data
for size in micro small medium; do
    echo "Testing $size..."
    ./baseline_matrix $size > results/baseline_${size}.txt
    
    # Extract key metrics
    gflops=$(grep "Performance:" results/baseline_${size}.txt | awk '{print $2}')
    time=$(grep "Time:" results/baseline_${size}.txt | awk '{print $2}')
    
    echo "$size: ${gflops} GFLOPS (${time}s)" >> results/baseline_summary.txt
done

echo
echo "=== Baseline Results Saved ==="
cat results/baseline_summary.txt
echo
echo "Data saved to results/ directory for comparison with optimizations"
