
## Overview

Using compile-time optimizations provides the quickest performance improvements with the least effort.  Performance gains of 15-30%+ just by modifying compile-time flags are very common.

In this section, we walk you through optimizations including optimization levels, architecture targeting, Profile-Guided Optimization (PGO) and Link-Time Optimization (LTO).

## Optimization Levels and Architecture Targeting

## 🔹 Compiler Optimization Levels

| Flag     | Description | Typical Use Case |
|----------|-------------|------------------|
| **`-O0`** | No optimization, fast compilation, easy debugging. | Debug builds. |
| **`-O1`** | Basic optimizations with minimal compile-time cost. | Quick builds with some speed. |
| **`-O2`** | Standard “production” optimization, balance of speed and size. | Default for production. |
| **`-O3`** | Aggressive optimizations, larger binaries, max performance focus. | Performance-critical workloads. |
| **`-Ofast`** | Unsafe optimizations, ignores strict standards (e.g., relaxed math). | HPC, simulations, ML code (test correctness carefully). |


Architecture-Specific Targeting

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


## Advanced Flags

| Flag | Description | Notes | Recommended Usage |
|------|-------------|-------|-------------------|
| **`-flto`** | **Link Time Optimization (LTO):** optimizer runs across multiple files at link time. | Produces smaller, faster binaries. Longer build times. | Safe for production when longer builds are acceptable. |
| **`-fomit-frame-pointer`** | Removes frame pointer register usage, freeing it for other optimizations. | Enabled by default at higher `-O` levels (except for debugging). | Use in release builds; avoid if you need precise debugging/profiling. |
| **`-funroll-loops`** | Aggressively unrolls loops for speed. | Often enabled at `-O3`, may increase binary size. | Use for performance-critical, loop-heavy code (HPC/ML). |
| **`-ffast-math`** | Optimizes floating point math aggressively (reordering, removing edge-case checks). | Included in `-Ofast`. Unsafe for strict IEEE compliance. | Use only if numerical reproducibility is not critical. |
| **`-march=<arch>`** | Target a **specific CPU family** (e.g., `-march=skylake`, `-march=armv8-a`). | Great for deployment-specific binaries; not portable across CPUs. | Use when building for a known deployment environment. |
| **`-mtune=<cpu>`** | Optimize instruction scheduling for a specific CPU, but **still runs on older CPUs**. | Example: `-mtune=skylake` — tuned for Skylake but still portable. | Safe default; combine with `-O2` or `-O3` for extra gains. |

Begin by running a baseline and then all combinations of optimizations and architecture targeting with this command:

```bash
# Test all combinations of optimization levels, architecture flags, and matrix sizes
./scripts/04/test-all-combinations.sh
```

The baseline is established with no compiler optimizations (mtune, march, or -O flags). The script then tests all combinations of optimization levels, architecture targeting, and matrix sizes to provide a comprehensive performance overview.


This automatically tests every combination of:
- **Optimization levels**: -O0, -O1, -O2, -O3
- **Architecture targeting**: generic, native, Neoverse-specific
- **Matrix sizes**: micro (64x64), small (512x512), medium (2048x2048)

### Complete Performance Results

**Actual results on Neoverse V2 (top 20 combinations):**
```
| Rank  | GFLOPS   | Time(s) | Opt  | Architecture | Size   |
|-------|----------|--------|------|--------------|--------|
| 1     | 4.52     | 0.000  | -O2  | generic      | micro  |
| 2     | 4.49     | 0.000  | -O3  | generic      | micro  |
| 3     | 4.37     | 0.000  | -O3  | native       | micro  |
| 4     | 4.13     | 0.000  | -O1  | native       | micro  |
| 5     | 4.12     | 0.000  | -O1  | Neoverse-V2  | micro  |
| 6     | 4.11     | 0.000  | -O2  | native       | micro  |
| 7     | 3.89     | 0.000  | -O1  | generic      | micro  |
| 8     | 3.73     | 0.000  | -O3  | Neoverse-V2  | micro  |
| 9     | 3.45     | 0.000  | -O2  | Neoverse-V2  | micro  |
| 10    | 2.59     | 0.104  | -O2  | Neoverse-V2  | small  |
```



### Expect unexpected Results (sometimes)

You may think that always compiling with optimization level of -O3 and with Neoverse-specific flags will always provide the best results, but actual benchmark results may show a more nuanced picture.  For example, aggressive optimization may sometimes hurt performance, absence of compile options sometimes outperforms processor-specific ones, etc.
### Optimization Strategy Recommendations


## Advanced Compiler Optimizations

### A
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

For a comprehensive analysis of all optimization combinations:

```bash
# Test all combinations of optimization levels × architecture targeting
./scripts/04/test-compiler-matrix.sh
```

### Comprehensive Optimization Matrix

The matrix test shows performance across all combinations:

**Example results on Neoverse V2:**
```
| Optimization | Generic  | Native   | Neoverse | Best     |
|--------------|----------|----------|----------|----------|
| -O0 (baseline) | 0.65     | 0.65     | 0.65     | 0.65x    |
| -O1          | 2.40     | 2.42     | 2.41     | 3.7x     |
| -O2          | 2.36     | 2.36     | 2.58     | 3.9x     |
| -O3          | 2.37     | 2.37     | 2.59     | 3.9x     |
```

### Performance Across Matrix Sizes

To see how compiler optimizations scale with problem size:

```bash
# Compare baseline vs optimized across all matrix sizes
./scripts/04/compare-sizes.sh
```

**Example results showing optimization impact by size:**
```
| Size | Baseline (GFLOPS) | Optimized (GFLOPS) | Speedup | Time Reduction |
|------|-------------------|---------------------|---------|----------------|
| micro | 0.74              | 3.73                | 5.0x    | 100.0%         |
| small | 0.66              | 2.59                | 3.9x    | 70.0%          |
| medium | 0.59              | 0.68                | 1.1x    | 10.0%          |
```

**Key insight**: Compiler optimizations provide massive gains for cache-friendly workloads but diminishing returns as problems become memory-bound. This demonstrates why different optimization strategies are needed for different problem scales.

### Understanding the Results

**Example output on Neoverse V2:**
```
Detected: Neoverse-V2
Using flags: -march=armv9-a+sve2+bf16+i8mm -mtune=neoverse-v2

=== Performance Comparison ===
  -O1: 2.42 GFLOPS (3.7x speedup)
  -O2: 2.34 GFLOPS (3.6x speedup)  
  -O3: 2.37 GFLOPS (3.6x speedup)
  -O3 + Neoverse flags: 2.58 GFLOPS (3.9x speedup)
```

**Key insights:**
- **-O1 provides most gains**: Often 3-4x improvement over -O0
- **-O2 vs -O3**: Diminishing returns, sometimes -O2 is faster
- **Neoverse-specific flags**: Additional 9% improvement (2.57 vs 2.35 GFLOPS)
- **Processor detection**: Script automatically detects your Neoverse type and uses optimal flags
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

**-O3 + Neoverse-specific optimizations:**
- SVE2 instructions (variable-length vectors)
- BF16 and I8MM matrix operations
- Neoverse V2-specific instruction scheduling
- Advanced crypto acceleration instructions
- LSE atomic operations for better concurrency

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
