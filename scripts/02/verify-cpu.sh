#!/bin/bash
# verify-cpu.sh - Verify CPU information

lscpu | grep -E "Model name|Architecture|CPU\(s\):"
