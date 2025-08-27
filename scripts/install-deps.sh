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
echo "Setup complete! You can now proceed to hardware detection."
