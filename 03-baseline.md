
## Establishing Your Performance Baseline

Before applying any optimizations, you need to establish a baseline performance measurement. This baseline serves as the reference point for measuring the effectiveness of each optimization technique.

## Matrix Multiplication Workload

The tutorial uses matrix multiplication as the primary workload because it:
- **Exercises multiple optimization types**: Vectorization, memory access, threading
- **Scales predictably**: Performance characteristics change with matrix size
- **Represents real workloads**: Common in scientific computing, ML, graphics
- **Easy to understand**: Simple algorithm with clear performance metrics

## Baseline Implementation

The unoptimized baseline implementation uses the most straightforward approach:

```c
// src/matrix/baseline.c - Unoptimized matrix multiplication
#include "matrix.h"
#include <stdlib.h>
#include <string.h>

void matrix_multiply_baseline(const float* A, const float* B, float* C, 
                             int M, int N, int K) {
    // Clear output matrix
    memset(C, 0, M * N * sizeof(float));
    
    // Triple nested loop - cache-unfriendly order
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) {
            for (int k = 0; k < K; k++) {
                C[i * N + j] += A[i * K + k] * B[k * N + j];
            }
        }
    }
}
```

This implementation deliberately uses:
- **No compiler optimizations** (compiled with -O0)
- **Cache-unfriendly access patterns** (column-major access to B matrix)
- **No vectorization hints** or SIMD instructions
- **Single-threaded execution**
- **No prefetching** or memory optimization

This implements a worst-case scenario tuning-wise for this app, providing the opportuntity to demonstrate hands-on tuning patterns.

## Test Dataset Sizes

The tutorial tests across multiple matrix sizes to understand performance characteristics:

| Size | Dimensions | Elements | Memory Usage | Cache Behavior | Purpose |
|------|------------|----------|--------------|----------------|---------|
| **Micro** | 64x64 | 4,096 | ~48KB | Fits in L1 cache | Test instruction-level optimizations |
| **Small** | 512x512 | 262,144 | ~3MB | Fits in L2 cache | Test L1/L2 cache optimization |
| **Medium** | 2048x2048 | 4,194,304 | ~48MB | Fits in L3 cache | Test L2/L3 cache optimization |
| **Large** | 8192x8192 | 67,108,864 | ~768MB | Exceeds most L3 caches | Test memory bandwidth optimization |
| **Huge** | 16384x16384 | 268,435,456 | ~3GB | Tests virtual memory | Test THP and NUMA optimization |

## Running Baseline Tests

Execute this single command to establish your complete performance baseline:

```bash
# Complete baseline collection: compile, test, profile, and save results
./scripts/03/collect-baseline.sh
```



### Your Baseline Results
After running the collection script, you'll have:
- `results/baseline_summary.txt` - Performance summary for comparison
- Individual result files for detailed analysis
- Profiling data showing optimization opportunities

**Example baseline on Neoverse V2:**
```
micro: 0.73 GFLOPS (0.001s)
small: 0.63 GFLOPS (0.425s)  
medium: [varies by system]
```

> **📝 Next**: These baseline numbers will be automatically compared against optimizations in sections 04+.


## Understanding Baseline Metrics

To see detailed performance metrics referenced below:

```bash
# Get comprehensive performance analysis for any matrix size
./scripts/03/detailed-metrics.sh small
```

This shows all the metrics discussed in this section with actual values from your system.

### Performance Metrics

**GFLOPS (Giga Floating-Point Operations Per Second)**
- Measures computational throughput
- Matrix multiplication: 2×M×N×K operations
- Higher is better

**Memory Bandwidth**
- Rate of data transfer from/to memory
- Critical for large matrices
- Measured in GB/s

**Instructions Per Cycle (IPC)**
- Efficiency of instruction execution
- Baseline typically shows low IPC (0.2-0.4)
- Optimizations should increase IPC

### Cache Behavior

**Cache Hit Rates**
- L1: Should be >90% for optimized code
- L2: Should be >95% for medium matrices
- L3: Should be >98% for large matrices

**Memory Stall Cycles**
- Percentage of time CPU waits for memory
- High values (>30%) indicate memory bottlenecks
- Target for memory optimizations

### Access Patterns

**Sequential vs Random Access**
- Sequential: Cache-friendly, predictable
- Random: Cache-unfriendly, unpredictable
- Optimizations should increase sequential ratio

## Baseline Analysis Questions

After running baseline tests, consider:

1. **Which matrix size shows the biggest performance drop?**
   - Indicates cache size limits
   - Guides cache optimization priorities

2. **What's the primary bottleneck?**
   - Low IPC: Focus on vectorization
   - High cache misses: Focus on memory optimization
   - High memory stalls: Focus on prefetching

3. **How does performance scale with size?**
   - Linear scaling: Memory-bound
   - Cubic scaling: Compute-bound
   - Irregular scaling: Cache effects

## Performance Expectations

Typical baseline performance on different Neoverse processors:

| Processor | Matrix Size | Baseline GFLOPS | Memory BW | Primary Bottleneck |
|-----------|-------------|-----------------|-----------|-------------------|
| N1 | 2048x2048 | 0.3-0.5 | 2-3 GB/s | Memory access pattern |
| N2 | 2048x2048 | 0.4-0.7 | 3-4 GB/s | Instruction throughput |
| V1 | 2048x2048 | 0.5-0.8 | 4-6 GB/s | Cache utilization |
| V2 | 2048x2048 | 0.6-1.0 | 5-7 GB/s | Vector efficiency |

## Next Steps

With baseline data collected in `results/baseline_summary.txt`, continue to:

1. **[Compiler Optimizations](./04-compiler-optimizations.md)**: Easy 2-3x performance gains
2. **Compare results**: Each optimization section will automatically compare against your baseline

Ready to start optimizing? Continue to [Build and Compiler Optimizations](./04-compiler-optimizations.md).
2. **[SIMD Optimizations](./)**: Vectorization for compute performance
3. **[Memory Optimizations](./)**: Cache and access pattern improvements

> **💡 Tip**:
**Baseline Tip**: Save your baseline results! You'll compare all optimizations against these numbers. The tutorial automatically saves results to `data/results/baseline.json` for later comparison.


## Troubleshooting Baseline Issues

**Very Low Performance (<0.1 GFLOPS)**
- Check if running in debug mode (-O0)
- Verify matrix sizes are correct
- Ensure sufficient memory available

**Inconsistent Results**
- Run multiple iterations (--iterations=10)
- Check for background processes
- Verify CPU frequency scaling is disabled

**Missing Performance Counters**
- Ensure perf tools are installed
- Check permissions: `echo 1 | sudo tee /proc/sys/kernel/perf_event_paranoid`
- Some cloud instances may restrict hardware counters

Your baseline measurement is complete! This data will serve as the foundation for measuring optimization effectiveness throughout the tutorial.
