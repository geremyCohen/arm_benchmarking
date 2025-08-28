#!/bin/bash
# verify-features.sh - Show available CPU features

cat /proc/cpuinfo | grep Features | head -1
