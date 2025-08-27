
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

## Test Dataset Sizes

The tutorial tests across multiple matrix sizes to understand performance characteristics:

### Micro (64x64)
- **Total elements**: 4,096 per matrix
- **Memory usage**: ~48KB total
- **Cache behavior**: Fits entirely in L1 cache
- **Purpose**: Test instruction-level optimizations

### Small (512x512)
- **Total elements**: 262,144 per matrix
- **Memory usage**: ~3MB total  
- **Cache behavior**: Fits in L2 cache
- **Purpose**: Test L1/L2 cache optimization

### Medium (2048x2048)
- **Total elements**: 4,194,304 per matrix
- **Memory usage**: ~48MB total
- **Cache behavior**: Fits in L3 cache
- **Purpose**: Test L2/L3 cache optimization

### Large (8192x8192)
- **Total elements**: 67,108,864 per matrix
- **Memory usage**: ~768MB total
- **Cache behavior**: Exceeds most L3 caches
- **Purpose**: Test memory bandwidth optimization

### Huge (16384x16384)
- **Total elements**: 268,435,456 per matrix
- **Memory usage**: ~3GB total
- **Cache behavior**: Tests virtual memory system
- **Purpose**: Test THP and NUMA optimization

## Running Baseline Tests

Build and run the baseline measurement:

```bash
# Build the tutorial
cmake -B build
cmake --build build

# Run baseline tests across all sizes
./build/neoverse-tutorial --baseline --all-sizes

# Run specific size for detailed analysis
./build/neoverse-tutorial --baseline --size=medium --verbose
```

## Expected Baseline Output

```
=== Neoverse Optimization Tutorial - Baseline Measurement ===

Hardware: Neoverse N1, 4 cores, 8GB RAM
Compiler: GCC 11.2.0, flags: -O0 -g

Matrix Size: 2048x2048 (Medium)
Memory Usage: 48.0 MB
Iterations: 5

Running baseline matrix multiplication...

Results:
  Average Time: 45.23 seconds
  Throughput: 0.38 GFLOPS
  Memory Bandwidth: 2.1 GB/s
  
Performance Counters:
  Instructions: 34,359,738,368
  Cycles: 108,589,934,592
  IPC: 0.32
  L1 Cache Misses: 67,108,864 (25.0%)
  L2 Cache Misses: 16,777,216 (6.25%)
  L3 Cache Misses: 4,194,304 (1.56%)
  Branch Mispredictions: 1,048,576 (0.39%)

Cache Analysis:
  L1D Hit Rate: 75.0%
  L2 Hit Rate: 93.75%
  L3 Hit Rate: 98.44%
  Memory Stall Cycles: 54,294,967,296 (50.0%)

Memory Access Pattern:
  Sequential Access: 25%
  Random Access: 75%
  Prefetch Effectiveness: 12%
```

## Understanding Baseline Metrics

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

## Profiling Integration

The baseline measurement includes integrated profiling:

```bash
# Run with detailed profiling
./build/neoverse-tutorial --baseline --profile=detailed

# Generate performance report
./build/neoverse-tutorial --baseline --report=html
```

This creates detailed reports showing:
- **Hotspot analysis**: Which functions consume the most time
- **Cache behavior**: Miss rates and access patterns
- **Branch prediction**: Misprediction rates and patterns
- **Memory access**: Bandwidth utilization and stall analysis

## Next Steps

With your baseline established, you're ready to start optimizing. The recommended progression:

1. **[Compiler Optimizations](./)**: Easy wins with build flags
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
