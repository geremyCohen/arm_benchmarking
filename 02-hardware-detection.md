# CPU Instruction Set Features

CPU instruction set features are specialized hardware capabilities that extend the base ARM architecture with additional instructions for specific workloads. These features enable significant performance improvements by providing hardware acceleration for common operations like vector math, atomic operations, and cryptography.

The tutorial automatically detects which instruction set features are available on your Neoverse processor and enables corresponding optimization modules. Understanding these features helps you choose the most effective optimization strategies for your specific hardware.

| Processor | Key Features | Typical Use Cases | Cloud Availability |
|-----------|--------------|-------------------|-------------------|
| **Neoverse N1** | NEON, LSE atomics, crypto extensions | Web servers, databases, general compute | **AWS**: Graviton2 (M6g, C6g, R6g, T4g)<br>**Azure**: Ampere Altra (Dpsv5, Dplsv5, Epsv5) and Altra Max (Dpsv6, Dplsv6, Epsv6)<br>**GCP**: Tau T2A instances |
| **Neoverse N2** | NEON, SVE2, LSE atomics, improved crypto | HPC, ML inference, high-performance databases | Not yet commercially available in major cloud offerings |
| **Neoverse V1** | NEON, SVE, wide execution, large caches | Scientific computing, simulation, AI training | **AWS**: Graviton3 (M7g, C7g, R7g, Hpc7g) |
| **Neoverse V2** | NEON, SVE2, enhanced matrix operations | AI/ML workloads, scientific computing | **AWS**: Graviton4 (M8g, C8g, R8g - newer releases) |

### ARM Instruction Set Features Detection

**Detection**: Complete hardware feature detection for all ARM extensions
```bash
./scripts/02/detect-features.sh
```


## CMake Configuration Generation

The configure script generates a `CMakeCache.txt` file that controls which optimizations are built:

```cmake
# Example generated configuration for Neoverse N2
CMAKE_BUILD_TYPE:STRING=Release
CMAKE_C_COMPILER:FILEPATH=/usr/bin/gcc-11
CMAKE_CXX_COMPILER:FILEPATH=/usr/bin/g++-11

# Hardware-specific settings
NEOVERSE_TYPE:STRING=n2
CPU_CORES:STRING=8
HAS_NEON:BOOL=YES
HAS_SVE:BOOL=NO
HAS_SVE2:BOOL=YES
HAS_LSE:BOOL=YES
HAS_CRYPTO:BOOL=YES
SVE_VL:STRING=256
```

## Compiler Flag Selection

Based on your detected hardware, the tutorial automatically selects optimal compiler flags:

### Neoverse N1
```bash
CFLAGS="-march=armv8.2-a+fp16+rcpc+dotprod+crypto -mtune=neoverse-n1"
```

### Neoverse N2
```bash
CFLAGS="-march=armv9-a+sve2+bf16+i8mm -mtune=neoverse-n2"
```

### Neoverse V1
```bash
CFLAGS="-march=armv8.4-a+sve+bf16+i8mm -mtune=neoverse-v1"
```

### Neoverse V2
```bash
CFLAGS="-march=armv9-a+sve2+bf16+i8mm -mtune=neoverse-v2"
```

## Manual Override Options

You can override automatic detection for testing purposes:

```bash
# Force enable SVE even if not detected
cmake -B build -DFORCE_SVE=ON

# Test with different Neoverse target
cmake -B build -DNEOVERSE_TYPE=v1

# Disable specific features
cmake -B build -DDISABLE_CRYPTO=ON
```

## Verification Commands

Verify your hardware detection with these commands:

### CPU Information
```bash
./scripts/02/verify-cpu.sh
```

### Available Features
```bash
./scripts/02/verify-features.sh
```

### Cache Hierarchy
```bash
./scripts/02/verify-cache.sh
```

### NUMA Topology
```bash
./scripts/02/verify-numa.sh
```

## Performance Implications

Different Neoverse processors have varying optimization priorities:

| Processor | Primary Bottleneck | Key Optimizations | Expected Gains |
|-----------|-------------------|-------------------|----------------|
| N1 | Memory bandwidth | Prefetch, alignment, NEON | 2-3x |
| N2 | Instruction throughput | SVE2, compiler opts | 3-4x |
| V1 | Cache utilization | SVE, cache blocking | 4-6x |
| V2 | Vector efficiency | Advanced SVE2, matrix ops | 5-8x |

## Next Steps

Now that hardware detection is complete, you can:

1. **Build the tutorial**: `cmake -B build && cmake --build build`
2. **Run baseline tests**: `./build/neoverse-tutorial --baseline`
3. **Start with compiler optimizations**: Most universal and easiest to implement

> **ℹ️ Hardware Note**: If you're running on a cloud instance, some features (like SVE) may not be available depending on the instance type. The tutorial will automatically adapt to available features.

## Understanding the Output

When you run `./configure`, pay attention to:

- **Neoverse Type**: Determines which processor-specific optimizations are available
- **Feature Availability**: Shows which optimization categories will be enabled
- **Core Count**: Affects threading and NUMA optimization recommendations
- **SVE Vector Length**: Critical for SVE optimization effectiveness

The tutorial uses this information to:
- Enable only relevant optimization modules
- Set appropriate compiler flags
- Configure test parameters for your hardware
- Provide hardware-specific performance guidance

Ready to establish your performance baseline? Continue to [Baseline Performance Measurement](./03-baseline.md).
