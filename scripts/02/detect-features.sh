#!/bin/bash
# detect-features.sh - Combined detection for all ARM instruction set features

echo "=== ARM Instruction Set Features Detection ==="
echo

# Check NEON (Advanced SIMD)
if grep -q "asimd" /proc/cpuinfo; then
    echo "✓ NEON (Advanced SIMD): Available"
    echo "  - 128-bit SIMD instructions (2-4x speedup)"
else
    echo "✗ NEON (Advanced SIMD): Not available"
fi

echo

# Check SVE (Scalable Vector Extension)
if grep -q "sve" /proc/cpuinfo; then
    echo "✓ SVE (Scalable Vector Extension): Available"
    echo "  - Variable-length vector instructions (2-8x speedup)"
else
    echo "✗ SVE (Scalable Vector Extension): Not available"
fi

echo

# Check SVE2
if grep -q "sve2" /proc/cpuinfo; then
    echo "✓ SVE2 (Enhanced SVE): Available"
    echo "  - Additional 20-50% performance over base SVE"
else
    echo "✗ SVE2 (Enhanced SVE): Not available"
fi

echo

# Check LSE Atomics
if grep -q "atomics" /proc/cpuinfo; then
    echo "✓ LSE Atomics: Available"
    echo "  - Efficient atomic operations (2-10x improvement in high-contention)"
else
    echo "✗ LSE Atomics: Not available"
fi

echo

# Check Crypto Extensions
CRYPTO_FEATURES=$(grep -o -E "(aes|sha1|sha2)" /proc/cpuinfo | sort | uniq)
if [ -n "$CRYPTO_FEATURES" ]; then
    echo "✓ Crypto Extensions: Available"
    echo "  - Hardware-accelerated: $(echo $CRYPTO_FEATURES | tr '\n' ' ')"
    echo "  - Expected performance: 5-20x speedup for crypto workloads"
else
    echo "✗ Crypto Extensions: Not available"
fi

echo
echo "=== Summary ==="
NEON_STATUS=$(grep -q "asimd" /proc/cpuinfo && echo "YES" || echo "NO")
SVE_STATUS=$(grep -q "sve" /proc/cpuinfo && echo "YES" || echo "NO")
SVE2_STATUS=$(grep -q "sve2" /proc/cpuinfo && echo "YES" || echo "NO")
LSE_STATUS=$(grep -q "atomics" /proc/cpuinfo && echo "YES" || echo "NO")
CRYPTO_STATUS=$(grep -q -E "aes|sha1|sha2" /proc/cpuinfo && echo "YES" || echo "NO")
echo "NEON: $NEON_STATUS | SVE: $SVE_STATUS | SVE2: $SVE2_STATUS | LSE: $LSE_STATUS | Crypto: $CRYPTO_STATUS"
