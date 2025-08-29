#!/bin/bash
# test-compiler-opts.sh - Test compiler optimization levels and compare with baseline

echo "=== Compiler Optimization Testing ==="
echo

# Load baseline results for comparison
if [ ! -f results/baseline_summary.txt ]; then
    echo "Error: Run ./scripts/03/collect-baseline.sh first to establish baseline"
    exit 1
fi

echo "Building optimized versions..."
make opt-O1 opt-O2 opt-O3 opt-arch

echo
echo "Testing compiler optimizations (small matrix: 512x512)..."
echo

# Clear previous results
> results/compiler_opts_summary.txt

# Test each optimization level
for opt in O1 O2 O3 arch; do
    echo "Testing -$opt optimization..."
    ./optimized_$opt small > results/opt_${opt}_small.txt
    
    # Extract performance
    gflops=$(grep "Performance:" results/opt_${opt}_small.txt | awk '{print $2}')
    time=$(grep "Time:" results/opt_${opt}_small.txt | awk '{print $2}')
    
    echo "$opt: ${gflops} GFLOPS (${time}s)" >> results/compiler_opts_summary.txt
done

echo
echo "=== Compiler Optimization Results ==="
echo "Baseline:"
baseline_gflops=$(grep "small:" results/baseline_summary.txt | head -1 | awk '{print $2}')
echo "  -O0: ${baseline_gflops} GFLOPS"

echo
echo "Optimized versions:"
cat results/compiler_opts_summary.txt

echo
echo "=== Performance Comparison ==="
for opt in O1 O2 O3 arch; do
    opt_gflops=$(grep "$opt:" results/compiler_opts_summary.txt | awk '{print $2}')
    speedup=$(echo "scale=1; $opt_gflops / $baseline_gflops" | bc -l)
    echo "  -$opt: ${opt_gflops} GFLOPS (${speedup}x speedup)"
done

echo
echo "Results saved to results/compiler_opts_summary.txt"
