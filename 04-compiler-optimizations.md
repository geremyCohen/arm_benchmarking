
## Overview

Compiler optimizations provide the highest return on investment for performance improvements. With minimal code changes, you can typically achieve 15-30% performance gains, and sometimes up to 50% for compute-intensive workloads.

This section covers Neoverse-specific compiler optimizations, from basic flags to advanced techniques like Profile-Guided Optimization (PGO) and Link-Time Optimization (LTO).

## Basic Compiler Flags

### Architecture-Specific Targeting

The most important optimization is targeting your specific Neoverse processor:

```bash
# Neoverse N1
CFLAGS="-march=armv8.2-a+fp16+rcpc+dotprod+crypto -mtune=neoverse-n1"

# Neoverse N2  
CFLAGS="-march=armv9-a+sve2+bf16+i8mm -mtune=neoverse-n2"

# Neoverse V1
CFLAGS="-march=armv8.4-a+sve+bf16+i8mm -mtune=neoverse-v1"

# Neoverse V2
CFLAGS="-march=armv9-a+sve2+bf16+i8mm -mtune=neoverse-v2"
```

**What these flags do:**
- `-march`: Enables instruction set features available on the target
- `-mtune`: Optimizes instruction scheduling for the specific processor
- Feature flags (`+sve2`, `+bf16`, etc.): Enable specific instruction extensions

### Optimization Levels

```bash
# Basic optimization - good balance of compile time and performance
CFLAGS="-O2"

# Aggressive optimization - maximum performance
CFLAGS="-O3"

# Size optimization - for memory-constrained environments
CFLAGS="-Os"

# Fast compilation with basic optimization
CFLAGS="-O1"
```

## Running Compiler Optimization Tests

Execute this command to test compiler optimizations and compare with your baseline:

```bash
# Test all compiler optimization levels and compare with baseline
./scripts/04/test-compiler-opts.sh
```

This automatically:
- Builds the same algorithm with different optimization levels (`-O1`, `-O2`, `-O3`, `-march=native`)
- Tests performance on 512x512 matrices
- Compares results with your baseline from section 03
- Shows speedup ratios for each optimization level

### Understanding the Results

**Example output on Neoverse V2:**
```
=== Performance Comparison ===
  -O1: 2.39 GFLOPS (3.6x speedup)
  -O2: 2.33 GFLOPS (3.5x speedup)  
  -O3: 2.35 GFLOPS (3.5x speedup)
  -arch: 2.34 GFLOPS (3.5x speedup)
```

**Key insights:**
- **-O1 provides most gains**: Often 3-4x improvement over -O0
- **-O2 vs -O3**: Diminishing returns, sometimes -O2 is faster
- **-march=native**: Enables processor-specific instructions (SVE, crypto extensions)
- **Same source code**: Only compilation flags changed, demonstrating compiler impact

### What the Compiler Does

The optimizations transform your code without changing the algorithm:

**-O1 optimizations:**
- Loop unrolling and basic vectorization
- Dead code elimination
- Register allocation improvements

**-O2 optimizations:**
- Aggressive inlining and loop optimizations
- Instruction scheduling for Neoverse pipelines
- Auto-vectorization with NEON instructions

**-O3 optimizations:**
- More aggressive loop transformations
- Function cloning and specialization
- Advanced instruction-level parallelism

**-march=native optimizations:**
- SVE instructions (if available)
- Crypto acceleration instructions
- LSE atomic operations
- Processor-specific instruction scheduling

## Expected Results: Basic Optimizations

### Optimization Level Comparison (2048x2048 matrix, Neoverse N1)

| Optimization | Time (sec) | GFLOPS | Speedup | Compile Time |
|--------------|------------|--------|---------|--------------|
| -O0 (baseline) | 45.23 | 0.38 | 1.0x | 2.1s |
| -O1 | 28.45 | 0.60 | 1.6x | 2.3s |
| -O2 | 18.92 | 0.91 | 2.4x | 3.1s |
| -O3 | 16.78 | 1.02 | 2.7x | 4.2s |
| -Os | 22.34 | 0.77 | 2.0x | 2.8s |

### Architecture-Specific Targeting (with -O3)

| Target | Time (sec) | GFLOPS | Speedup | Notes |
|--------|------------|--------|---------|-------|
| Generic (-march=armv8-a) | 16.78 | 1.02 | 1.0x | Baseline |
| Neoverse N1 specific | 14.23 | 1.21 | 1.18x | Better scheduling |
| With crypto extensions | 13.89 | 1.24 | 1.21x | Faster math functions |
| With dotprod | 13.12 | 1.31 | 1.28x | Optimized accumulation |

## Advanced Compiler Optimizations

### Link-Time Optimization (LTO)

LTO enables optimizations across translation units:

```bash
# Enable LTO
CFLAGS="-O3 -flto"
LDFLAGS="-flto"

# Test LTO impact
./build/neoverse-tutorial --test=lto --size=medium
```

**LTO Benefits:**
- Cross-module inlining
- Better dead code elimination  
- Improved constant propagation
- Typical gain: 5-15% additional improvement

### Profile-Guided Optimization (PGO)

PGO uses runtime profiling data to guide optimizations:

```bash
# Step 1: Build with profiling instrumentation
CFLAGS="-O3 -fprofile-generate"
make clean && make

# Step 2: Run representative workload to collect profile data
./build/neoverse-tutorial --profile-collect --size=medium

# Step 3: Rebuild with profile data
CFLAGS="-O3 -fprofile-use"
make clean && make

# Step 4: Test optimized binary
./build/neoverse-tutorial --test=pgo --size=medium
```

**PGO Benefits:**
- Better branch prediction
- Optimized function layout
- Improved inlining decisions
- Typical gain: 10-25% additional improvement

### Context-Sensitive PGO (CSPGO)

Advanced PGO that considers calling context:

```bash
# LLVM CSPGO (requires Clang)
CFLAGS="-O3 -fprofile-generate -fcs-profile-generate"
# ... collect profile data ...
CFLAGS="-O3 -fprofile-use -fcs-profile-use"
```

## LLVM BOLT Post-Link Optimizer

BOLT optimizes binaries after linking using runtime profile data:

```bash
# Build optimized binary
CFLAGS="-O3 -march=neoverse-n1"
make

# Collect runtime profile with perf
perf record -e cycles:u -j any,u -- ./build/neoverse-tutorial --size=medium

# Convert perf data for BOLT
perf2bolt ./build/neoverse-tutorial -p perf.data -o tutorial.fdata

# Apply BOLT optimizations
llvm-bolt ./build/neoverse-tutorial -data=tutorial.fdata -reorder-blocks=ext-tsp \
  -reorder-functions=hfsort -split-functions -split-all-cold \
  -o ./build/neoverse-tutorial-bolt

# Test BOLT-optimized binary
./build/neoverse-tutorial-bolt --test=bolt --size=medium
```

## Compiler-Specific Optimizations

### GCC-Specific Flags

```bash
# Neoverse-optimized GCC flags
CFLAGS="-O3 -march=neoverse-n1 -mtune=neoverse-n1 \
        -ffast-math -funroll-loops -fprefetch-loop-arrays \
        -ftree-vectorize -fvect-cost-model=dynamic"
```

### Clang/LLVM-Specific Flags

```bash
# Neoverse-optimized Clang flags  
CFLAGS="-O3 -march=neoverse-n1 -mtune=neoverse-n1 \
        -ffast-math -funroll-loops -fvectorize \
        -mllvm -enable-load-pre -mllvm -enable-gvn-hoist"
```

## Loop Optimization Hints

Guide the compiler's loop optimization decisions:

```c
// Vectorization hints
#pragma GCC ivdep  // Ignore vector dependencies
#pragma clang loop vectorize(enable)

// Unrolling hints
#pragma GCC unroll 4
#pragma clang loop unroll_count(4)

// Example in matrix multiplication
void matrix_multiply_hints(const float* A, const float* B, float* C, 
                          int M, int N, int K) {
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) {
            float sum = 0.0f;
            #pragma GCC ivdep
            #pragma clang loop vectorize(enable)
            for (int k = 0; k < K; k++) {
                sum += A[i * K + k] * B[k * N + j];
            }
            C[i * N + j] = sum;
        }
    }
}
```

## Branch Prediction Hints

Help the compiler optimize branch prediction:

```c
#include <stddef.h>

// Likely/unlikely macros
#define likely(x)   __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)

// Example usage
void optimized_function(int* data, size_t size) {
    for (size_t i = 0; i < size; i++) {
        if (likely(data[i] > 0)) {
            // Hot path - optimized for this case
            data[i] *= 2;
        } else if (unlikely(data[i] < -1000)) {
            // Cold path - rare error case
            handle_error(data[i]);
        }
    }
}
```

## Comprehensive Compiler Test Results

Running all compiler optimizations on different matrix sizes:

### Small Matrix (512x512) - Cache-Friendly

| Optimization | Time (ms) | GFLOPS | Speedup | Notes |
|--------------|-----------|--------|---------|-------|
| Baseline (-O0) | 1,234 | 0.22 | 1.0x | |
| -O3 | 387 | 0.70 | 3.2x | Basic optimization |
| -O3 + arch flags | 298 | 0.91 | 4.1x | Neoverse-specific |
| + LTO | 276 | 0.98 | 4.5x | Cross-module opts |
| + PGO | 234 | 1.16 | 5.3x | Profile-guided |
| + BOLT | 218 | 1.24 | 5.7x | Post-link opts |

### Large Matrix (8192x8192) - Memory-Bound

| Optimization | Time (sec) | GFLOPS | Speedup | Notes |
|--------------|------------|--------|---------|-------|
| Baseline (-O0) | 2,847 | 0.39 | 1.0x | |
| -O3 | 1,234 | 0.90 | 2.3x | Basic optimization |
| -O3 + arch flags | 1,089 | 1.02 | 2.6x | Better memory ops |
| + LTO | 1,034 | 1.07 | 2.8x | Inlined memory funcs |
| + PGO | 967 | 1.15 | 2.9x | Optimized access patterns |
| + BOLT | 923 | 1.20 | 3.1x | Better code layout |

## Implementation Difficulty vs. Performance Gain

| Optimization | Implementation Effort | Typical Speedup | Compile Time Impact |
|--------------|----------------------|-----------------|-------------------|
| -O2/-O3 | Trivial | 2-3x | Low |
| Architecture flags | Trivial | +15-25% | None |
| LTO | Easy | +5-15% | Medium |
| Loop hints | Medium | +10-30% | Low |
| PGO | Medium | +10-25% | High |
| BOLT | Hard | +5-15% | High |

## Best Practices

### Development vs. Production Builds

**Development Build:**
```bash
CFLAGS="-O1 -g -march=native"  # Fast compile, debuggable
```

**Production Build:**
```bash
CFLAGS="-O3 -march=neoverse-n1 -mtune=neoverse-n1 -flto -DNDEBUG"
```

### Compiler Selection

**GCC**: Generally better for Neoverse N-series
**Clang**: Often better for Neoverse V-series with SVE

Test both compilers on your workload:
```bash
./build/neoverse-tutorial --test=compiler-comparison --size=medium
```

## Next Steps

Compiler optimizations provide excellent baseline performance improvements. With these optimizations in place, you're ready to explore:

1. **[SIMD Optimizations](./)**: Hand-coded vectorization for compute kernels
2. **[Memory Optimizations](./)**: Cache-friendly data structures and access patterns

> **💡 Tip**:
**Optimization Strategy**: Always start with compiler optimizations before hand-coding. Modern compilers are sophisticated, and you may find that `-O3` with the right flags gets you 80% of the performance with 5% of the effort.


## Troubleshooting

**Compilation Errors with Architecture Flags:**
- Check that your processor supports the specified features
- Use `./configure` to auto-detect supported features

**Performance Regression with -O3:**
- Try -O2 instead - sometimes aggressive optimization hurts performance
- Profile to identify which specific optimization is problematic

**LTO Link Errors:**
- Ensure all object files are compiled with -flto
- May need to use gcc-ar and gcc-ranlib for static libraries

The foundation of compiler optimizations is now in place. These techniques alone can transform your application's performance significantly before moving to more advanced optimization strategies.
