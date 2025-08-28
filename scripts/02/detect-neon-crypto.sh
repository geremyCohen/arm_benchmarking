#!/bin/bash
# detect-neon-crypto.sh - Combined detection for NEON and Crypto Extensions

echo "=== NEON and Crypto Extensions Detection ==="
echo

# Check NEON (Advanced SIMD)
if grep -q "asimd" /proc/cpuinfo; then
    echo "✓ NEON (Advanced SIMD): Available"
    echo "  - 128-bit SIMD instructions supported"
    echo "  - Expected performance: 2-4x speedup for suitable workloads"
else
    echo "✗ NEON (Advanced SIMD): Not available"
fi

echo

# Check Crypto Extensions
CRYPTO_FEATURES=$(grep -o -E "(aes|sha1|sha2)" /proc/cpuinfo | sort | uniq)
if [ -n "$CRYPTO_FEATURES" ]; then
    echo "✓ Crypto Extensions: Available"
    echo "  - Hardware-accelerated cryptographic operations"
    echo "  - Supported algorithms: $(echo $CRYPTO_FEATURES | tr '\n' ' ')"
    echo "  - Expected performance: 5-20x speedup for crypto workloads"
else
    echo "✗ Crypto Extensions: Not available"
fi

echo
echo "=== Summary ==="
NEON_STATUS=$(grep -q "asimd" /proc/cpuinfo && echo "YES" || echo "NO")
CRYPTO_STATUS=$(grep -q -E "aes|sha1|sha2" /proc/cpuinfo && echo "YES" || echo "NO")
echo "NEON: $NEON_STATUS | Crypto: $CRYPTO_STATUS"
