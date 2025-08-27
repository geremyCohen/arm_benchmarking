# Neoverse Optimization Benchmarking Tutorial

A comprehensive benchmarking tutorial demonstrating how to optimize C/C++ applications for Arm Neoverse processors through hands-on matrix multiplication examples. You'll learn to identify, implement, and measure the performance impact of key optimizations across all major categories.

## What You'll Learn

- **50+ Neoverse-specific optimizations** with before/after code comparisons
- **Performance measurement techniques** using Linux perf and hardware counters
- **Scaling analysis** across different thread counts, memory sizes, and system configurations
- **Cost-benefit analysis** of each optimization approach
- **When and how to apply** each optimization technique

## Tutorial Structure

This tutorial uses a **modular framework** where you can:
- Run all optimizations sequentially for comprehensive analysis
- Focus on specific optimization categories
- Compare different approaches side-by-side
- Scale tests from cache-friendly to memory-intensive workloads

## Prerequisites

- Arm Neoverse-based system (N1, N2, V1, V2)
- Basic C/C++ programming knowledge
- Linux command line familiarity
- Ubuntu 20.04+ or compatible distribution

## Learning Path

> **💡 Recommended Approach**: Start with compiler optimizations for immediate 15-30% performance gains, then progress through vectorization, memory, and system optimizations based on your application's bottlenecks.

### Foundation Level
1. [Project Setup and Dependencies](./01-setup.md)
2. [Hardware Detection and Configuration](./02-hardware-detection.md)
3. [Baseline Performance Measurement](./03-baseline.md)

### Optimization Categories
4. [Build and Compiler Optimizations](./04-compiler-optimizations.md)
5. [SIMD and Vectorization](./05-simd-optimizations.md)
6. [Memory Access Optimizations](./06-memory-optimizations.md)
7. [Concurrency and Synchronization](./07-concurrency-optimizations.md)
8. [System and Runtime Tuning](./08-system-optimizations.md)
9. [Advanced Profiling and Analysis](./09-profiling-analysis.md)

### Advanced Topics
10. [Performance Analysis Deep Dive](./10-performance-analysis.md)

## Key Features

**Auto Hardware Detection**: The tutorial automatically detects your Neoverse processor type and available features, enabling only relevant optimizations.

**Multi-Scale Testing**: Each optimization is tested across datasets ranging from L1 cache-sized (64x64 matrices) to memory-intensive (16384x16384 matrices).

**Comprehensive Metrics**: Beyond basic timing, you'll see cache hit rates, instruction throughput, memory bandwidth utilization, and energy efficiency.

**Educational Integration**: Each section includes theory, implementation details, and practical guidance on when to apply each technique.

## Expected Performance Gains

| Optimization Category | Typical Improvement | Best Case | Implementation Effort |
|----------------------|-------------------|-----------|---------------------|
| Compiler Flags | 15-30% | 50% | Low |
| NEON Vectorization | 2-4x | 8x | Medium |
| SVE Optimization | 2-6x | 12x | High |
| Memory Optimization | 20-50% | 200% | Medium |
| System Tuning | 5-20% | 40% | Low |

> **📝 Performance Note**: Actual improvements depend heavily on workload characteristics, system configuration, and baseline code quality. This tutorial helps you identify which optimizations provide the best return on investment for your specific use case.

## Getting Started

Ready to begin optimizing? Start with [Project Setup](./01-setup.md) to configure your development environment and run your first benchmark.

## Repository Structure

```
arm_benchmarking/
├── README.md                    # This file
├── 01-setup.md                 # Project setup and dependencies
├── 02-hardware-detection.md    # Hardware detection and configuration
├── 03-baseline.md              # Baseline performance measurement
├── 04-compiler-optimizations.md # Build and compiler optimizations
├── 05-simd-optimizations.md    # SIMD and vectorization
├── 06-memory-optimizations.md  # Memory access optimizations
├── 07-concurrency-optimizations.md # Concurrency and synchronization
├── 08-system-optimizations.md  # System and runtime tuning
├── 09-profiling-analysis.md    # Advanced profiling and analysis
├── 10-performance-analysis.md  # Performance analysis deep dive
├── scripts/                    # Utility scripts
│   └── install-deps.sh         # Dependency installation script
└── src/                        # Source code examples
    ├── baseline/               # Baseline implementations
    ├── optimized/              # Optimized implementations
    └── benchmarks/             # Benchmarking code
```

## Quick Start

```bash
# Clone the repository
git clone https://github.com/your-org/arm_benchmarking.git
cd arm_benchmarking

# Install dependencies
./scripts/install-deps.sh

# Run hardware detection
./scripts/configure

# Build and run first benchmark
make baseline
./bin/baseline-benchmark
```

## Contributing

Contributions are welcome! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on how to submit improvements, bug fixes, or new optimization techniques.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
