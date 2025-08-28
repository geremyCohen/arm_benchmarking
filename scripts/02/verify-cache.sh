#!/bin/bash
# verify-cache.sh - Show cache hierarchy

lscpu | grep -E "L1d|L1i|L2|L3"
