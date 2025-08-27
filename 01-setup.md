# Project Setup and Dependencies

This tutorial requires an Arm Neoverse-based system running Ubuntu 20+, 8GB+ RAM, and 10GB of disk storage.

## Quick Setup - Run These Scripts in Sequence

Copy and paste each of the following command blocks in order to set up your tutorial environment:

### Step 1: Install Dependencies

```bash
cat > install-deps.sh << 'EOF'
#!/bin/bash
# install-deps.sh - Install required packages for Neoverse optimization tutorial

set -e

echo "Installing Neoverse Optimization Tutorial Dependencies..."

# Update package list
sudo apt update

# Essential build tools
sudo apt install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    pkg-config

# Compilers and toolchain (using available versions)
sudo apt install -y \
    gcc-11 \
    g++-11 \
    clang-18 \
    llvm-18 \
    lld-18

# Performance analysis tools
sudo apt install -y \
    linux-tools-common \
    linux-tools-generic \
    linux-tools-$(uname -r) \
    perf-tools-unstable \
    htop \
    numactl \
    stress-ng

# Development libraries
sudo apt install -y \
    libomp-dev \
    libnuma-dev \
    libhwloc-dev \
    libpfm4-dev

# Optional: Advanced profiling tools
sudo apt install -y \
    valgrind \
    gdb \
    strace

# Fix perf permissions
echo "Configuring perf permissions..."
echo 'kernel.perf_event_paranoid = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "Dependencies installed successfully!"
echo "Verifying installation..."

# Verify key tools
gcc-11 --version | head -1
clang-18 --version | head -1
cmake --version | head -1
perf --version

echo ""
echo "Additional tools verified:"
echo "g++-11: $(g++-11 --version | head -1)"
echo "numactl: $(numactl --version)"
echo "htop: $(htop --version | head -1)"
echo "stress-ng: $(stress-ng --version | head -1)"

echo ""
echo "Testing perf functionality..."
perf stat echo "Perf test successful!" 2>&1 | head -3

echo ""
echo "Step 1 Complete: Dependencies installed and verified!"
echo "Proceed to Step 2: Project Structure Setup"
EOF

chmod +x install-deps.sh && ./install-deps.sh
```

### Step 2: Create Project Structure
This script creates the directory structure for the tutorial.

```bash
cat > setup-project.sh << 'EOF'
#!/bin/bash
# setup-project.sh - Create project directory structure

set -e

echo "Creating Neoverse Tutorial Project Structure..."

# Create main project directory
mkdir -p neoverse-tutorial
cd neoverse-tutorial

# Create source directories
mkdir -p src/{core,matrix,optimizations,benchmarks}
mkdir -p include/{core,matrix,optimizations}
mkdir -p data/{input,results}
mkdir -p scripts
mkdir -p docs

echo "Project structure created successfully!"
echo "Current directory: $(pwd)"
echo ""
echo "Directory structure:"
find . -type d | sort
echo ""
echo "Step 2 Complete: Project structure ready!"
echo "Proceed to Step 3: Hardware Detection"
EOF

chmod +x setup-project.sh && ./setup-project.sh
```

### Step 3: Hardware Detection and Configuration

Arm cloud-based instances can run one of four different Neoverse versions.  This script will identify which one you are using, and create a CMake configuration file with the appropriate settings.

```bash
cat > configure << 'EOF'
#!/bin/bash
# configure - Detect hardware capabilities and generate build configuration

set -e

echo "=== Neoverse Optimization Tutorial Configuration ==="
echo

# Detect CPU information
CPU_INFO=$(lscpu)
CPU_MODEL=$(echo "$CPU_INFO" | grep "Model name" | cut -d: -f2 | xargs)
CPU_ARCH=$(echo "$CPU_INFO" | grep "Architecture" | cut -d: -f2 | xargs)
CPU_CORES=$(echo "$CPU_INFO" | grep "^CPU(s):" | cut -d: -f2 | xargs)

echo "Detected Hardware:"
echo "  CPU Model: $CPU_MODEL"
echo "  Architecture: $CPU_ARCH"
echo "  CPU Cores: $CPU_CORES"
echo

# Detect Neoverse processor type
NEOVERSE_TYPE="unknown"
if echo "$CPU_MODEL" | grep -qi "neoverse.*n1"; then
    NEOVERSE_TYPE="n1"
elif echo "$CPU_MODEL" | grep -qi "neoverse.*n2"; then
    NEOVERSE_TYPE="n2"
elif echo "$CPU_MODEL" | grep -qi "neoverse.*v1"; then
    NEOVERSE_TYPE="v1"
elif echo "$CPU_MODEL" | grep -qi "neoverse.*v2"; then
    NEOVERSE_TYPE="v2"
fi

echo "Neoverse Type: $NEOVERSE_TYPE"

# Detect available features
FEATURES_FILE="/proc/cpuinfo"
HAS_NEON=$(grep -q "asimd" $FEATURES_FILE && echo "YES" || echo "NO")
HAS_SVE=$(grep -q "sve" $FEATURES_FILE && echo "YES" || echo "NO")
HAS_SVE2=$(grep -q "sve2" $FEATURES_FILE && echo "YES" || echo "NO")
HAS_LSE=$(grep -q "atomics" $FEATURES_FILE && echo "YES" || echo "NO")
HAS_CRYPTO=$(grep -q "aes\|sha1\|sha2" $FEATURES_FILE && echo "YES" || echo "NO")

echo
echo "Available Features:"
echo "  NEON (Advanced SIMD): $HAS_NEON"
echo "  SVE: $HAS_SVE"
echo "  SVE2: $HAS_SVE2"
echo "  LSE Atomics: $HAS_LSE"
echo "  Crypto Extensions: $HAS_CRYPTO"

# Detect SVE vector length if available
SVE_VL="0"
if [ "$HAS_SVE" = "YES" ]; then
    # Try to detect SVE vector length
    if command -v getconf >/dev/null 2>&1; then
        SVE_VL=$(getconf LEVEL1_DCACHE_LINESIZE 2>/dev/null || echo "128")
    fi
    echo "  SVE Vector Length: ${SVE_VL} bits"
fi

echo

# Generate CMake configuration
cat > CMakeCache.txt << EOL
# Generated by configure script
CMAKE_BUILD_TYPE:STRING=Release
CMAKE_C_COMPILER:FILEPATH=/usr/bin/gcc-11
CMAKE_CXX_COMPILER:FILEPATH=/usr/bin/g++-11

# Hardware detection results
NEOVERSE_TYPE:STRING=$NEOVERSE_TYPE
CPU_CORES:STRING=$CPU_CORES
HAS_NEON:BOOL=$HAS_NEON
HAS_SVE:BOOL=$HAS_SVE
HAS_SVE2:BOOL=$HAS_SVE2
HAS_LSE:BOOL=$HAS_LSE
HAS_CRYPTO:BOOL=$HAS_CRYPTO
SVE_VL:STRING=$SVE_VL
EOL

echo "Configuration complete!"
echo "Generated CMakeCache.txt with detected hardware capabilities."
echo
echo "Step 3 Complete: Hardware detection finished!"
echo
echo "Setup Summary:"
echo "  Dependencies installed and verified"
echo "  Project structure created"
echo "  Hardware capabilities detected"
echo "  Build configuration generated"
echo
echo "Next steps:"
echo "  1. Run 'cmake -B build' to generate build files"
echo "  2. Run 'cmake --build build' to compile the tutorial"
echo "  3. Run './build/neoverse-tutorial' to start the interactive tutorial"
echo
echo "Ready to proceed with the Neoverse optimization tutorial!"
EOF

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
