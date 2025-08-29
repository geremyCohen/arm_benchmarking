#!/bin/bash
# verify-system.sh - Combined system verification for CPU, features, cache, and NUMA

echo "=== System Hardware Verification ==="
echo

echo "--- CPU Information ---"
lscpu | grep -E "Model name|Architecture|CPU\(s\):"
echo

echo "--- Available Features ---"
cat /proc/cpuinfo | grep Features | head -1
echo

echo "--- Cache Hierarchy ---"
lscpu | grep -E "L1d|L1i|L2|L3"
echo

echo "--- NUMA Topology ---"
numactl --hardware
