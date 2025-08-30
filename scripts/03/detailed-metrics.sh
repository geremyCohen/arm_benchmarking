#!/bin/bash
# detailed-metrics.sh - Comprehensive performance metrics collection for baseline analysis

echo "=== Detailed Baseline Metrics Collection ==="
echo

if [ $# -eq 0 ]; then
    echo "Usage: $0 <matrix_size>"
    echo "Example: $0 small"
    exit 1
fi

size=$1

# Ensure baseline executable exists
if [ ! -f baseline_matrix ]; then
    echo "Building baseline matrix..."
    make baseline
fi

echo "Collecting comprehensive metrics for $size matrix..."
echo

# Create detailed results directory
mkdir -p results/detailed

# Run comprehensive perf analysis
echo "Running performance counters..."
perf stat -e cycles,instructions,cache-references,cache-misses,L1-dcache-loads,L1-dcache-load-misses,L1-icache-load-misses,LLC-loads,LLC-load-misses,branch-loads,branch-load-misses,stalled-cycles-frontend,stalled-cycles-backend,context-switches,cpu-migrations,page-faults ./baseline_matrix $size 2> results/detailed/metrics_${size}.txt

echo
echo "=== Performance Analysis for $size matrix ==="

# Extract and calculate key metrics
metrics_file="results/detailed/metrics_${size}.txt"

# Basic performance - improved parsing
cycles=$(grep "cycles:u" $metrics_file | awk '{print $1}' | tr -d ',')
instructions=$(grep "instructions:u" $metrics_file | awk '{print $1}' | tr -d ',')

if [ ! -z "$cycles" ] && [ ! -z "$instructions" ] && [ "$cycles" -gt 0 ]; then
    ipc=$(echo "scale=2; $instructions / $cycles" | bc -l)
else
    ipc="N/A"
fi

echo "### Core Performance Metrics"
echo "Instructions Per Cycle (IPC): $ipc"
echo "Total Instructions: $(printf "%'d" $instructions 2>/dev/null || echo $instructions)"
echo "Total Cycles: $(printf "%'d" $cycles 2>/dev/null || echo $cycles)"

# Cache metrics
cache_refs=$(grep "cache-references:u" $metrics_file | awk '{print $1}' | tr -d ',')
cache_misses=$(grep "cache-misses:u" $metrics_file | awk '{print $1}' | tr -d ',')
if [ ! -z "$cache_refs" ] && [ ! -z "$cache_misses" ] && [ "$cache_refs" -gt 0 ]; then
    cache_miss_rate=$(echo "scale=2; $cache_misses * 100 / $cache_refs" | bc -l)
    echo
    echo "### Cache Performance"
    echo "Overall Cache Miss Rate: ${cache_miss_rate}%"
fi

# L1 Data Cache
l1d_loads=$(grep "L1-dcache-loads:u" $metrics_file | awk '{print $1}' | tr -d ',')
l1d_misses=$(grep "L1-dcache-load-misses:u" $metrics_file | awk '{print $1}' | tr -d ',')
if [ ! -z "$l1d_loads" ] && [ ! -z "$l1d_misses" ] && [ "$l1d_loads" -gt 0 ]; then
    l1d_miss_rate=$(echo "scale=2; $l1d_misses * 100 / $l1d_loads" | bc -l)
    l1d_hit_rate=$(echo "scale=2; 100 - $l1d_miss_rate" | bc -l)
    echo "L1 Data Cache Hit Rate: ${l1d_hit_rate}%"
fi

# L1 Instruction Cache
l1i_misses=$(grep "L1-icache-load-misses:u" $metrics_file | awk '{print $1}' | tr -d ',')
if [ ! -z "$l1i_misses" ]; then
    echo "L1 Instruction Cache Misses: $(printf "%'d" $l1i_misses 2>/dev/null || echo $l1i_misses)"
fi

# LLC (Last Level Cache)
llc_loads=$(grep "LLC-loads:u" $metrics_file | awk '{print $1}' | tr -d ',')
llc_misses=$(grep "LLC-load-misses:u" $metrics_file | awk '{print $1}' | tr -d ',')
if [ ! -z "$llc_loads" ] && [ ! -z "$llc_misses" ] && [ "$llc_loads" -gt 0 ]; then
    llc_miss_rate=$(echo "scale=2; $llc_misses * 100 / $llc_loads" | bc -l)
    llc_hit_rate=$(echo "scale=2; 100 - $llc_miss_rate" | bc -l)
    echo "Last Level Cache Hit Rate: ${llc_hit_rate}%"
fi

# Branch prediction
branch_loads=$(grep "branch-loads:u" $metrics_file | awk '{print $1}' | tr -d ',')
branch_misses=$(grep "branch-load-misses:u" $metrics_file | awk '{print $1}' | tr -d ',')
if [ ! -z "$branch_loads" ] && [ ! -z "$branch_misses" ] && [ "$branch_loads" -gt 0 ]; then
    branch_miss_rate=$(echo "scale=2; $branch_misses * 100 / $branch_loads" | bc -l)
    echo
    echo "### Branch Prediction"
    echo "Branch Misprediction Rate: ${branch_miss_rate}%"
fi

# Stall analysis
frontend_stalls=$(grep "stalled-cycles-frontend:u" $metrics_file | awk '{print $1}' | tr -d ',')
backend_stalls=$(grep "stalled-cycles-backend:u" $metrics_file | awk '{print $1}' | tr -d ',')
if [ ! -z "$frontend_stalls" ] && [ ! -z "$backend_stalls" ] && [ ! -z "$cycles" ] && [ "$cycles" -gt 0 ]; then
    frontend_pct=$(echo "scale=2; $frontend_stalls * 100 / $cycles" | bc -l)
    backend_pct=$(echo "scale=2; $backend_stalls * 100 / $cycles" | bc -l)
    echo
    echo "### CPU Stall Analysis"
    echo "Frontend Stalls: ${frontend_pct}% (instruction fetch/decode bottlenecks)"
    echo "Backend Stalls: ${backend_pct}% (memory/execution bottlenecks)"
    
    if (( $(echo "$backend_pct > 30" | bc -l) )); then
        echo "⚠️  High backend stalls indicate memory-bound performance"
    fi
    if (( $(echo "$frontend_pct > 10" | bc -l) )); then
        echo "⚠️  High frontend stalls indicate instruction fetch bottlenecks"
    fi
fi

# System metrics
context_switches=$(grep "context-switches:u" $metrics_file | awk '{print $1}' | tr -d ',')
page_faults=$(grep "page-faults:u" $metrics_file | awk '{print $1}' | tr -d ',')
echo
echo "### System Metrics"
echo "Context Switches: $(printf "%'d" $context_switches 2>/dev/null || echo $context_switches)"
echo "Page Faults: $(printf "%'d" $page_faults 2>/dev/null || echo $page_faults)"

echo
echo "Detailed metrics saved to: results/detailed/metrics_${size}.txt"
