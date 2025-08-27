#!/bin/bash
# quick-start.sh - Get started with Neoverse optimization tutorial

set -e

echo "🚀 Neoverse Optimization Tutorial - Quick Start"
echo "=============================================="
echo

# Check if we're on an ARM system
if [ "$(uname -m)" != "aarch64" ]; then
    echo "⚠️  Warning: This tutorial is designed for ARM64/AArch64 systems."
    echo "   You're running on $(uname -m). Some optimizations may not be available."
    echo
fi

# Step 1: Install dependencies
echo "📦 Step 1: Installing dependencies..."
if [ -f "./scripts/install-deps.sh" ]; then
    ./scripts/install-deps.sh
else
    echo "❌ Error: install-deps.sh not found. Please run from the repository root."
    exit 1
fi

echo
echo "✅ Dependencies installed successfully!"
echo

# Step 2: Hardware detection
echo "🔍 Step 2: Detecting hardware capabilities..."
if command -v lscpu >/dev/null 2>&1; then
    echo "CPU Information:"
    lscpu | grep -E "Model name|Architecture|CPU\(s\):|Thread\(s\) per core"
    echo
    
    echo "Available CPU features:"
    if [ -f "/proc/cpuinfo" ]; then
        grep "Features" /proc/cpuinfo | head -1 | cut -d: -f2 | tr ' ' '\n' | grep -E "asimd|sve|sve2|atomics|aes|sha" | sort | uniq
    fi
else
    echo "⚠️  lscpu not available, skipping detailed hardware detection"
fi

echo
echo "✅ Hardware detection complete!"
echo

# Step 3: Quick build test
echo "🔨 Step 3: Testing build system..."
if command -v cmake >/dev/null 2>&1; then
    echo "CMake version: $(cmake --version | head -1)"
    
    # Create a simple test to verify compiler works
    cat > test_build.c << 'EOF'
#include <stdio.h>
#include <arm_neon.h>

int main() {
    printf("✅ Compiler and NEON headers working!\n");
    
    // Test NEON availability
    float32x4_t test = vdupq_n_f32(1.0f);
    float result = vgetq_lane_f32(test, 0);
    printf("✅ NEON test passed: %f\n", result);
    
    return 0;
}
EOF

    if gcc-11 -o test_build test_build.c 2>/dev/null; then
        ./test_build
        rm -f test_build test_build.c
        echo "✅ Build system working!"
    else
        echo "⚠️  Build test failed, but continuing..."
        rm -f test_build test_build.c
    fi
else
    echo "⚠️  CMake not found, skipping build test"
fi

echo
echo "🎯 Quick Start Complete!"
echo "======================="
echo
echo "Next steps:"
echo "1. 📖 Read the tutorial: Start with ./01-setup.md"
echo "2. 🔧 Follow setup guide: Complete the 3-step setup process"
echo "3. 📊 Run benchmarks: Begin with baseline measurements"
echo "4. 🚀 Apply optimizations: Work through each category systematically"
echo
echo "Tutorial structure:"
echo "├── 01-setup.md                 # Project setup (you are here)"
echo "├── 02-hardware-detection.md    # Hardware capabilities"
echo "├── 03-baseline.md              # Performance baseline"
echo "├── 04-compiler-optimizations.md # Compiler flags and LTO"
echo "├── 05-simd-optimizations.md    # NEON and SVE vectorization"
echo "├── 06-memory-optimizations.md  # Cache and memory tuning"
echo "├── 07-concurrency-optimizations.md # Threading and atomics"
echo "├── 08-system-optimizations.md  # OS and runtime tuning"
echo "├── 09-profiling-analysis.md    # Advanced profiling tools"
echo "└── 10-performance-analysis.md  # Deep performance analysis"
echo
echo "💡 Tip: Each section builds on the previous ones, so follow them in order"
echo "    for the best learning experience."
echo
echo "🚀 Ready to optimize? Start with: cat 01-setup.md"
