# Project Setup and Dependencies

This tutorial requires an Arm Neoverse-based system running Ubuntu 20+, 8GB+ RAM, and 10GB of disk storage.

## Quick Setup - Run These Scripts in Sequence

Copy and paste each of the following command blocks in order to set up your tutorial environment:

### Step 1: Install Dependencies

```bash
curl -O https://raw.githubusercontent.com/geremyCohen/arm_benchmarking/main/scripts/01/install-deps.sh
chmod +x install-deps.sh && ./install-deps.sh
```

### Step 2: Create Project Structure
This script creates the directory structure for the tutorial.

```bash
curl -O https://raw.githubusercontent.com/geremyCohen/arm_benchmarking/main/scripts/01/setup-project.sh
chmod +x setup-project.sh && ./setup-project.sh
```

### Step 3: Hardware Detection and Configuration

Arm cloud-based instances can run one of four different Neoverse versions.  This script will identify which one you are using, and create a CMake configuration file with the appropriate settings.

```bash
curl -O https://raw.githubusercontent.com/geremyCohen/arm_benchmarking/main/scripts/01/configure
chmod +x configure && ./configure
```

## Expected Output Summary

After running all three steps, you should see:

### Step 1 Output:
```
Installing Neoverse Optimization Tutorial Dependencies...
...
Step 1 Complete: Dependencies installed and verified!
```

### Step 2 Output:
```
Creating Neoverse Tutorial Project Structure...
Step 2 Complete: Project structure ready!
```

### Step 3 Output:
```
=== Neoverse Optimization Tutorial Configuration ===
...
Setup Summary:
  Dependencies installed and verified
  Project structure created  
  Hardware capabilities detected
  Build configuration generated

Ready to proceed with the Neoverse optimization tutorial!
```

## What Each Step Does

### **Step 1: Install Dependencies**
- Updates package lists
- Installs build tools (cmake, ninja, git)
- Installs compilers (GCC 11, Clang 18, LLVM 18)
- Installs performance tools (perf, htop, numactl, stress-ng)
- Installs development libraries (OpenMP, NUMA, hwloc)
- Configures perf permissions automatically
- Verifies all installations

### **Step 2: Create Project Structure**
- Creates the `neoverse-tutorial` directory
- Sets up source code directories (`src/`, `include/`)
- Creates data and documentation directories
- Changes to the project directory for subsequent steps

### **Step 3: Hardware Detection and Configuration**
- Detects your specific Neoverse processor type
- Identifies available instruction set extensions
- Generates CMake configuration with hardware-specific settings
- Provides summary of detected capabilities

## Project Structure Created

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

> **💡 Next Step**: With setup complete, proceed to [Hardware Detection and Configuration](./02-hardware-detection.md) to understand how the tutorial adapts to your specific Neoverse processor capabilities.

## Troubleshooting

**Permission Issues with perf**: The installation script automatically fixes perf permissions. If you still encounter issues:
```bash
echo 'kernel.perf_event_paranoid = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

**Missing Compiler Versions**: The script uses clang-18 and llvm-18 which are available on Ubuntu 24.04. For older systems:
```bash
# Check available versions
apt search clang | grep -E "^clang-[0-9]+"
# Install the highest available version
```

**SVE Not Detected**: SVE is only available on newer Neoverse implementations. The tutorial will automatically disable SVE-specific optimizations if not available.
