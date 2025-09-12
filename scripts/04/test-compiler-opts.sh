#!/bin/bash
# test-compiler-opts.sh - Test compiler optimization levels and compare with baseline

echo "=== Compiler Optimization Testing ==="
echo

# Load baseline results for comparison
if [ ! -f results/baseline_summary.txt ]; then
    echo "Error: Run ./scripts/03/collect-baseline.sh first to establish baseline"
    exit 1
fi

# Detect Neoverse processor type for proper -march/-mtune flags
NEOVERSE_TYPE=$(lscpu | grep "Model name" | awk '{print $3}')
MARCH_FLAGS="-march=native -mtune=native"

echo "Detected: $NEOVERSE_TYPE"
echo "Using flags: $MARCH_FLAGS"
echo

echo "Building optimized versions..."
make opt-O1 opt-O2 opt-O3

# Build with Neoverse-specific flags
echo "Building with Neoverse-specific optimization..."
gcc -O3 $MARCH_FLAGS -Wall -o optimized_neoverse src/optimized_matrix.c -lm

echo
echo "Testing compiler optimizations (small matrix: 512x512)..."
echo

# Clear previous results
> results/compiler_opts_summary.txt

# Test each optimization level
for opt in O1 O2 O3; do
    echo "Testing -$opt optimization..."
    ./optimized_$opt small > results/opt_${opt}_small.txt
    
    # Extract performance
    gflops=$(grep "Performance:" results/opt_${opt}_small.txt | awk '{print $2}')
    time=$(grep "Time:" results/opt_${opt}_small.txt | awk '{print $2}')
    
    echo "$opt: ${gflops} GFLOPS (${time}s)" >> results/compiler_opts_summary.txt
done

# Test Neoverse-specific optimization
echo "Testing Neoverse-specific optimization..."
./optimized_neoverse small > results/opt_neoverse_small.txt
gflops=$(grep "Performance:" results/opt_neoverse_small.txt | awk '{print $2}')
time=$(grep "Time:" results/opt_neoverse_small.txt | awk '{print $2}')
echo "neoverse: ${gflops} GFLOPS (${time}s)" >> results/compiler_opts_summary.txt

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
for opt in O1 O2 O3 neoverse; do
    opt_gflops=$(grep "$opt:" results/compiler_opts_summary.txt | awk '{print $2}')
    speedup=$(echo "scale=1; $opt_gflops / $baseline_gflops" | bc -l)
    if [ "$opt" = "neoverse" ]; then
        echo "  -O3 + Neoverse flags: ${opt_gflops} GFLOPS (${speedup}x speedup)"
    else
        echo "  -$opt: ${opt_gflops} GFLOPS (${speedup}x speedup)"
    fi
done

echo
echo "Neoverse-specific flags used: $MARCH_FLAGS"
echo "Results saved to results/compiler_opts_summary.txt"
