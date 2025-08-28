# Project Setup and Dependencies

This tutorial requires an Arm Neoverse-based system running Ubuntu 20+, 8GB+ RAM, and 10GB of disk storage.

## Quick Setup - Run These Scripts in Sequence

Copy and paste each of the following command blocks in order to set up your tutorial environment:

### Step 1: Install Dependencies
This script installs all necessary dependencies including compilers, build tools, and performance libraries.

```bash
./scripts/01/install-deps.sh
```

> **Note**: You may see a warning about "perf not found for kernel" - this can be safely ignored. The script installs generic perf tools that provide all functionality needed for this tutorial. The warning only indicates that kernel-specific perf modules aren't available, which doesn't affect the benchmarking capabilities.

### Step 2: Create Project Working Directories

Creates the `neoverse-tutorial` working directory with source, data, and documentation folders:

```
neoverse-tutorial/
├── CMakeLists.txt              # Main build configuration (to be created)
├── configure                   # Hardware detection script (created)
├── src/
│   ├── core/                   # Core framework and utilities
│   ├── matrix/                 # Matrix multiplication implementations
│   ├── optimizations/          # Individual optimization modules
│   └── benchmarks/             # Benchmarking and measurement code
├── include/                    # Header files
├── data/                       # Test datasets and results
├── scripts/                    # Utility scripts
└── docs/                       # Generated documentation
```

then navigates (cd) into it for the next steps.


```bash
./scripts/01/setup-project.sh
```

### Step 3: Hardware Detection and Configuration

Arm cloud-based instances can run one of four different Neoverse versions.  This script will identify which one you are using, and create a CMake configuration file with the appropriate settings.  This makes it easy to build and run the tutorial on any Neoverse-based system.


```bash
./scripts/01/configure
```

## Next Steps
With setup complete, proceed to [Hardware Detection and Configuration](./02-hardware-detection.md) to understand how the tutorial adapts to your specific Neoverse processor capabilities.

