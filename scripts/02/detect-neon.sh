#!/bin/bash
# detect-neon.sh - Detection method for NEON (Advanced SIMD)

grep "asimd" /proc/cpuinfo
