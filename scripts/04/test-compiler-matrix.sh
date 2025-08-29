#!/bin/bash
# test-compiler-matrix.sh - Test all combinations of optimization levels and architecture flags

echo "=== Comprehensive Compiler Optimization Matrix ==="
echo

# Load baseline for comparison
if [ ! -f results/baseline_summary.txt ]; then
    echo "Error: Run ./scripts/03/collect-baseline.sh first to establish baseline"
    exit 1
fi

baseline_gflops=$(grep "small:" results/baseline_summary.txt | head -1 | awk '{print $2}')

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
echo "Building all optimization combinations..."
echo

# Create results directory
mkdir -p results/matrix

# Test matrix: optimization levels × architecture flags
declare -A results
opt_levels=("O0" "O1" "O2" "O3")
arch_configs=("generic" "native" "neoverse")

for opt in "${opt_levels[@]}"; do
    for arch in "${arch_configs[@]}"; do
        case $arch in
            "generic")
                flags="-$opt"
                ;;
            "native")
                flags="-$opt -march=native -mtune=native"
                ;;
            "neoverse")
                flags="-$opt -march=$MARCH_SPECIFIC -mtune=$MTUNE_SPECIFIC"
                ;;
        esac
        
        # Build executable
        exe_name="matrix_${opt}_${arch}"
        gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm
        
        # Test performance
        ./$exe_name small > results/matrix/${opt}_${arch}.txt 2>/dev/null
        gflops=$(grep "Performance:" results/matrix/${opt}_${arch}.txt | awk '{print $2}')
        
        # Store result
        results["$opt,$arch"]=$gflops
        
        echo "  $opt + $arch: $gflops GFLOPS"
    done
done

echo
echo "=== Optimization Matrix Results ==="
echo

# Create table header
printf "| %-12s | %-8s | %-8s | %-8s | %-8s |\n" "Optimization" "Generic" "Native" "Neoverse" "Best"
printf "|--------------|----------|----------|----------|----------|\n"

# Add baseline row
printf "| %-12s | %-8s | %-8s | %-8s | %-8s |\n" "-O0 (baseline)" "$baseline_gflops" "$baseline_gflops" "$baseline_gflops" "${baseline_gflops}x"

# Add optimization rows
for opt in O1 O2 O3; do
    generic=${results["$opt,generic"]}
    native=${results["$opt,native"]}
    neoverse=${results["$opt,neoverse"]}
    
    # Find best result
    best=$(echo "$generic $native $neoverse" | tr ' ' '\n' | sort -nr | head -1)
    speedup=$(echo "scale=1; $best / $baseline_gflops" | bc -l)
    
    printf "| %-12s | %-8s | %-8s | %-8s | %-8s |\n" "-$opt" "$generic" "$native" "$neoverse" "${speedup}x"
done

echo
echo "=== Key Insights ==="
echo "• Generic: Basic optimization without architecture targeting"
echo "• Native: GCC auto-detects processor features (-march=native -mtune=native)"  
echo "• Neoverse: Explicit $NEOVERSE_TYPE targeting with $MARCH_SPECIFIC"
echo "• Best speedup achieved: $(echo "$generic $native $neoverse" | tr ' ' '\n' | sort -nr | head -1 | xargs -I {} echo "scale=1; {} / $baseline_gflops" | bc -l)x over baseline"

# Cleanup executables
rm -f matrix_O*_*
