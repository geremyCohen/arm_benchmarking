

### ARM Instruction Set Features Detection

To detect instruction set features available on this system, run: 
```bash
./scripts/02/detect-features.sh
```
Next, CMake is configured based on the detected features. 

## CMake Configuration Generation

The `CMakeCache.txt` file is generated when you run `./scripts/01/configure` during Step 3 of the setup process. This file controls which optimizations are built:

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


## Verification Commands

Verify your hardware detection with this comprehensive system check:

```bash
./scripts/02/verify-system.sh
```

## Next Steps

Now that hardware detection is complete, you can:

1. **Continue to baseline setup**: [Baseline Performance Measurement](./03-baseline.md)
2. **Verify your system**: `./scripts/02/verify-system.sh`
3. **Check detected features**: `./scripts/02/detect-features.sh`

> **ℹ️ Hardware Note**: If you're running on a cloud instance, some features (like SVE) may not be available depending on the instance type. The tutorial will automatically adapt to available features.

Ready to establish your performance baseline? Continue to [Baseline Performance Measurement](./03-baseline.md).

[//]: # (| Processor | Pre-defined Compiler Flags                                          | `-march` Description | `-mtune` Description |)

[//]: # (|-----------|---------------------------------------------------------------------|-------------------------------|-----------------------|)

[//]: # (| **Neoverse N1** | `-march=armv8.2-a+fp16+rcpc+dotprod+crypto`<br>`-mtune=neoverse-n1` | **armv8.2-a**: Baseline ISA with FP16 and atomics enhancements.<br>**+fp16**: Native half-precision floating point ops.<br>**+rcpc**: RCpc atomics for efficient multithreaded memory ordering.<br>**+dotprod**: Dot product instructions for ML/DSP acceleration.<br>**+crypto**: Hardware AES/SHA crypto acceleration. | Tunes instruction scheduling, cache usage, and pipelines for **Neoverse N1**, optimized for cloud/server workloads. |)

[//]: # (| **Neoverse N2** | `-march=armv9-a+sve2+bf16+i8mm`<br>`-mtune=neoverse-n2`             | **armv9-a**: ARMv9 baseline with security and vector upgrades.<br>**+sve2**: Scalable Vector Extension 2, advanced variable-length SIMD.<br>**+bf16**: Brain Floating Point 16 support for AI workloads.<br>**+i8mm**: Int8 matrix multiplication instructions for quantized ML. | Optimizes for **Neoverse N2**, balancing high single-thread performance and power efficiency in cloud compute. |)

[//]: # (| **Neoverse V1** | `-march=armv8.4-a+sve+bf16+i8mm`<br>`-mtune=neoverse-v1`            | **armv8.4-a**: Baseline ISA with stronger memory model and new atomics.<br>**+sve**: First-gen Scalable Vector Extension for variable-length SIMD.<br>**+bf16**: Bfloat16 arithmetic for AI training/inference.<br>**+i8mm**: Int8 matrix multiplication for ML acceleration. | Tunes code generation for **Neoverse V1**, focusing on HPC and vector-heavy workloads with wide SVE pipelines. |)

[//]: # (| **Neoverse V2** | `-march=armv9-a+sve2+bf16+i8mm`<br>`-mtune=neoverse-v2`             | **armv9-a**: Successor to ARMv8 with enhanced security and vector ISA.<br>**+sve2**: Next-gen scalable SIMD for cloud/HPC/AI.<br>**+bf16**: Bfloat16 arithmetic.<br>**+i8mm**: Int8 matrix multiplication. | Optimizes scheduling and code layout for **Neoverse V2**, combining HPC-class SVE2 with cloud-friendly efficiency. |)

[//]: # (If you are brave enough to read that table, you'll see a lot of new vocabulary like SIMD, SVE, and SVE2. You will learn more about them as we proceed in the tutorial, but don't worry about knowing or memorizing those yet.)