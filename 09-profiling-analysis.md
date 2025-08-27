
## Overview

Profiling and analysis tools are essential for understanding performance bottlenecks and validating optimization effectiveness. Neoverse processors provide sophisticated hardware performance monitoring capabilities through PMU (Performance Monitoring Unit) and SPE (Statistical Profiling Extension).

This section covers Linux perf, SPE profiling, PMU analysis, and Neoverse-specific performance methodologies.

## Linux Perf Fundamentals

### Basic Performance Counter Collection

```bash
# Basic performance statistics
perf stat ./neoverse-tutorial --size=medium

# Detailed hardware counters
perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses \
  ./neoverse-tutorial --size=medium

# Memory hierarchy analysis
perf stat -e L1-dcache-loads,L1-dcache-load-misses,L1-dcache-stores,L1-dcache-store-misses,\
L1-icache-loads,L1-icache-load-misses,LLC-loads,LLC-load-misses,LLC-stores,LLC-store-misses \
  ./neoverse-tutorial --size=large
```

### Advanced Perf Recording and Analysis

```bash
# Record performance data with call graphs
perf record -g --call-graph=dwarf ./neoverse-tutorial --size=medium

# Analyze recorded data
perf report --stdio
perf report --tui  # Interactive TUI

# Generate flame graphs
perf script | stackcollapse-perf.pl | flamegraph.pl > flamegraph.svg

# Memory access profiling
perf mem record ./neoverse-tutorial --size=large
perf mem report --stdio

# Cache-to-cache transfer analysis (requires recent perf)
perf c2c record ./neoverse-tutorial --size=large --threads=16
perf c2c report
```

## Statistical Profiling Extension (SPE)

SPE provides detailed, low-overhead profiling of memory operations and instruction execution.

### SPE Configuration and Usage

```c
// Enable SPE programmatically
#include <sys/syscall.h>
#include <linux/perf_event.h>

int setup_spe_profiling(void) {
    struct perf_event_attr pe = {0};
    
    pe.type = PERF_TYPE_RAW;
    pe.size = sizeof(struct perf_event_attr);
    pe.config = 0x4803;  // SPE event configuration
    pe.sample_period = 1024;  // Sample every 1024 operations
    pe.sample_type = PERF_SAMPLE_IP | PERF_SAMPLE_TID | PERF_SAMPLE_TIME | 
                     PERF_SAMPLE_ADDR | PERF_SAMPLE_CPU;
    pe.disabled = 1;
    pe.exclude_kernel = 1;
    pe.exclude_hv = 1;
    
    int fd = syscall(__NR_perf_event_open, &pe, 0, -1, -1, 0);
    if (fd == -1) {
        perror("perf_event_open");
        return -1;
    }
    
    return fd;
}

// SPE-aware benchmarking function
void benchmark_with_spe(void (*func)(void*), void* arg) {
    int spe_fd = setup_spe_profiling();
    if (spe_fd < 0) {
        printf("SPE not available, falling back to basic timing\n");
        func(arg);
        return;
    }
    
    // Start SPE profiling
    ioctl(spe_fd, PERF_EVENT_IOC_RESET, 0);
    ioctl(spe_fd, PERF_EVENT_IOC_ENABLE, 0);
    
    // Run benchmark
    func(arg);
    
    // Stop SPE profiling
    ioctl(spe_fd, PERF_EVENT_IOC_DISABLE, 0);
    
    close(spe_fd);
    printf("SPE profiling data collected\n");
}
```

### SPE Command Line Usage

```bash
# Check SPE availability
ls /sys/bus/event_source/devices/arm_spe_0/

# Record with SPE
perf record -e arm_spe_0/ts_enable=1,pa_enable=1,load_filter=1,store_filter=1,branch_filter=1/ \
  ./neoverse-tutorial --size=large

# Analyze SPE data
perf report --stdio
perf script --itrace=i1000il  # Instruction trace with 1000 instruction period

# Memory latency analysis with SPE
perf mem record -e arm_spe_0// ./neoverse-tutorial --size=large
perf mem report --sort=mem,symbol,dso
```

## Neoverse PMU Analysis

### N1/N2 PMU Events

```c
// Neoverse N1/N2 specific PMU events
typedef struct {
    const char* name;
    uint32_t event_code;
    const char* description;
} neoverse_pmu_event_t;

neoverse_pmu_event_t neoverse_n1_events[] = {
    {"INST_RETIRED", 0x08, "Instructions retired"},
    {"CPU_CYCLES", 0x11, "CPU cycles"},
    {"L1D_CACHE_RD", 0x40, "L1D cache read access"},
    {"L1D_CACHE_REFILL_RD", 0x42, "L1D cache read refill"},
    {"L2D_CACHE_RD", 0x50, "L2D cache read access"},
    {"L2D_CACHE_REFILL_RD", 0x52, "L2D cache read refill"},
    {"BUS_ACCESS_RD", 0x60, "Bus read access"},
    {"MEMORY_ERROR", 0x1A, "Memory error"},
    {"BUS_CYCLES", 0x1D, "Bus cycles"},
    {"CHAIN", 0x1E, "Chained event"},
    // Neoverse N1 specific events
    {"L1D_CACHE_LMISS_RD", 0x139, "L1D cache long-latency read miss"},
    {"L2D_CACHE_LMISS_RD", 0x139, "L2D cache long-latency read miss"},
    {"LDST_ALIGN_LAT", 0x13A, "Load/store alignment latency"},
    {"LD_ALIGN_LAT", 0x13B, "Load alignment latency"},
    {"ST_ALIGN_LAT", 0x13C, "Store alignment latency"},
};

// Setup PMU event monitoring
int setup_pmu_monitoring(const char* event_name) {
    struct perf_event_attr pe = {0};
    
    pe.type = PERF_TYPE_RAW;
    pe.size = sizeof(struct perf_event_attr);
    
    // Find event code
    for (int i = 0; i < sizeof(neoverse_n1_events)/sizeof(neoverse_n1_events[0]); i++) {
        if (strcmp(neoverse_n1_events[i].name, event_name) == 0) {
            pe.config = neoverse_n1_events[i].event_code;
            break;
        }
    }
    
    pe.disabled = 1;
    pe.exclude_kernel = 1;
    pe.exclude_hv = 1;
    
    return syscall(__NR_perf_event_open, &pe, 0, -1, -1, 0);
}
```

### V1/V2 PMU Events

```c
neoverse_pmu_event_t neoverse_v1_events[] = {
    // Standard ARM events
    {"INST_RETIRED", 0x08, "Instructions retired"},
    {"CPU_CYCLES", 0x11, "CPU cycles"},
    {"L1D_CACHE_RD", 0x40, "L1D cache read access"},
    {"L1D_CACHE_REFILL_RD", 0x42, "L1D cache read refill"},
    {"L2D_CACHE_RD", 0x50, "L2D cache read access"},
    {"L2D_CACHE_REFILL_RD", 0x52, "L2D cache read refill"},
    {"L3D_CACHE_RD", 0xA0, "L3D cache read access"},
    {"L3D_CACHE_REFILL_RD", 0xA2, "L3D cache read refill"},
    
    // Neoverse V1 specific events
    {"SVE_INST_RETIRED", 0x8002, "SVE instructions retired"},
    {"SVE_MATH_SPEC", 0x8004, "SVE math operations speculatively executed"},
    {"SVE_FP_SPEC", 0x8005, "SVE FP operations speculatively executed"},
    {"SVE_INT_SPEC", 0x8006, "SVE integer operations speculatively executed"},
    {"SVE_LDST_SPEC", 0x8009, "SVE load/store operations speculatively executed"},
    {"ASE_SVE_INT8_SPEC", 0x800A, "SVE 8-bit integer operations speculatively executed"},
    {"ASE_SVE_INT16_SPEC", 0x800B, "SVE 16-bit integer operations speculatively executed"},
    {"ASE_SVE_INT32_SPEC", 0x800C, "SVE 32-bit integer operations speculatively executed"},
    {"ASE_SVE_INT64_SPEC", 0x800D, "SVE 64-bit integer operations speculatively executed"},
};
```

## Top-Down Performance Analysis

### Neoverse N2 Top-Down Methodology

```c
typedef struct {
    uint64_t frontend_bound;
    uint64_t backend_bound;
    uint64_t bad_speculation;
    uint64_t retiring;
    uint64_t total_slots;
} topdown_metrics_t;

topdown_metrics_t collect_topdown_metrics(void (*workload)(void*), void* arg) {
    topdown_metrics_t metrics = {0};
    
    // Setup performance counters for top-down analysis
    int fd_slots = setup_pmu_event("CPU_CYCLES");
    int fd_frontend_stall = setup_pmu_event("STALL_FRONTEND");
    int fd_backend_stall = setup_pmu_event("STALL_BACKEND");
    int fd_bad_spec = setup_pmu_event("BR_MIS_PRED_RETIRED");
    int fd_retiring = setup_pmu_event("INST_RETIRED");
    
    // Start counters
    ioctl(fd_slots, PERF_EVENT_IOC_RESET, 0);
    ioctl(fd_frontend_stall, PERF_EVENT_IOC_RESET, 0);
    ioctl(fd_backend_stall, PERF_EVENT_IOC_RESET, 0);
    ioctl(fd_bad_spec, PERF_EVENT_IOC_RESET, 0);
    ioctl(fd_retiring, PERF_EVENT_IOC_RESET, 0);
    
    ioctl(fd_slots, PERF_EVENT_IOC_ENABLE, 0);
    ioctl(fd_frontend_stall, PERF_EVENT_IOC_ENABLE, 0);
    ioctl(fd_backend_stall, PERF_EVENT_IOC_ENABLE, 0);
    ioctl(fd_bad_spec, PERF_EVENT_IOC_ENABLE, 0);
    ioctl(fd_retiring, PERF_EVENT_IOC_ENABLE, 0);
    
    // Run workload
    workload(arg);
    
    // Stop counters and read values
    ioctl(fd_slots, PERF_EVENT_IOC_DISABLE, 0);
    ioctl(fd_frontend_stall, PERF_EVENT_IOC_DISABLE, 0);
    ioctl(fd_backend_stall, PERF_EVENT_IOC_DISABLE, 0);
    ioctl(fd_bad_spec, PERF_EVENT_IOC_DISABLE, 0);
    ioctl(fd_retiring, PERF_EVENT_IOC_DISABLE, 0);
    
    read(fd_slots, &metrics.total_slots, sizeof(uint64_t));
    read(fd_frontend_stall, &metrics.frontend_bound, sizeof(uint64_t));
    read(fd_backend_stall, &metrics.backend_bound, sizeof(uint64_t));
    read(fd_bad_spec, &metrics.bad_speculation, sizeof(uint64_t));
    read(fd_retiring, &metrics.retiring, sizeof(uint64_t));
    
    // Close file descriptors
    close(fd_slots);
    close(fd_frontend_stall);
    close(fd_backend_stall);
    close(fd_bad_spec);
    close(fd_retiring);
    
    return metrics;
}

void analyze_topdown_metrics(topdown_metrics_t* metrics) {
    double total = metrics->total_slots;
    
    printf("Top-Down Performance Analysis:\n");
    printf("Frontend Bound: %.1f%% - CPU starved for instructions\n",
           (metrics->frontend_bound / total) * 100);
    printf("Backend Bound: %.1f%% - CPU starved for resources\n",
           (metrics->backend_bound / total) * 100);
    printf("Bad Speculation: %.1f%% - Wasted work due to misprediction\n",
           (metrics->bad_speculation / total) * 100);
    printf("Retiring: %.1f%% - Useful work completed\n",
           (metrics->retiring / total) * 100);
    
    // Provide optimization guidance
    if (metrics->frontend_bound / total > 0.2) {
        printf("Recommendation: Optimize instruction fetch (I-cache, branch prediction)\n");
    }
    if (metrics->backend_bound / total > 0.2) {
        printf("Recommendation: Optimize execution resources (memory, functional units)\n");
    }
    if (metrics->bad_speculation / total > 0.1) {
        printf("Recommendation: Improve branch predictability\n");
    }
}
```

## Memory Access Pattern Analysis

### Cache Behavior Analysis

```c
typedef struct {
    uint64_t l1d_accesses;
    uint64_t l1d_misses;
    uint64_t l2_accesses;
    uint64_t l2_misses;
    uint64_t l3_accesses;
    uint64_t l3_misses;
    uint64_t memory_accesses;
    double avg_memory_latency;
} cache_metrics_t;

cache_metrics_t analyze_cache_behavior(void (*workload)(void*), void* arg) {
    cache_metrics_t metrics = {0};
    
    // Setup cache monitoring counters
    int fd_l1d_acc = setup_pmu_event("L1D_CACHE_RD");
    int fd_l1d_miss = setup_pmu_event("L1D_CACHE_REFILL_RD");
    int fd_l2_acc = setup_pmu_event("L2D_CACHE_RD");
    int fd_l2_miss = setup_pmu_event("L2D_CACHE_REFILL_RD");
    int fd_l3_acc = setup_pmu_event("L3D_CACHE_RD");
    int fd_l3_miss = setup_pmu_event("L3D_CACHE_REFILL_RD");
    int fd_mem_acc = setup_pmu_event("BUS_ACCESS_RD");
    
    // Enable counters
    enable_counter(fd_l1d_acc);
    enable_counter(fd_l1d_miss);
    enable_counter(fd_l2_acc);
    enable_counter(fd_l2_miss);
    enable_counter(fd_l3_acc);
    enable_counter(fd_l3_miss);
    enable_counter(fd_mem_acc);
    
    // Run workload
    workload(arg);
    
    // Read results
    read(fd_l1d_acc, &metrics.l1d_accesses, sizeof(uint64_t));
    read(fd_l1d_miss, &metrics.l1d_misses, sizeof(uint64_t));
    read(fd_l2_acc, &metrics.l2_accesses, sizeof(uint64_t));
    read(fd_l2_miss, &metrics.l2_misses, sizeof(uint64_t));
    read(fd_l3_acc, &metrics.l3_accesses, sizeof(uint64_t));
    read(fd_l3_miss, &metrics.l3_misses, sizeof(uint64_t));
    read(fd_mem_acc, &metrics.memory_accesses, sizeof(uint64_t));
    
    // Calculate average memory latency (simplified)
    metrics.avg_memory_latency = estimate_memory_latency(&metrics);
    
    // Close counters
    close_counter(fd_l1d_acc);
    close_counter(fd_l1d_miss);
    close_counter(fd_l2_acc);
    close_counter(fd_l2_miss);
    close_counter(fd_l3_acc);
    close_counter(fd_l3_miss);
    close_counter(fd_mem_acc);
    
    return metrics;
}

void print_cache_analysis(cache_metrics_t* metrics) {
    printf("Cache Hierarchy Analysis:\n");
    printf("L1D Hit Rate: %.2f%% (%lu hits, %lu misses)\n",
           (1.0 - (double)metrics->l1d_misses / metrics->l1d_accesses) * 100,
           metrics->l1d_accesses - metrics->l1d_misses, metrics->l1d_misses);
    
    printf("L2 Hit Rate: %.2f%% (%lu hits, %lu misses)\n",
           (1.0 - (double)metrics->l2_misses / metrics->l2_accesses) * 100,
           metrics->l2_accesses - metrics->l2_misses, metrics->l2_misses);
    
    printf("L3 Hit Rate: %.2f%% (%lu hits, %lu misses)\n",
           (1.0 - (double)metrics->l3_misses / metrics->l3_accesses) * 100,
           metrics->l3_accesses - metrics->l3_misses, metrics->l3_misses);
    
    printf("Average Memory Latency: %.1f cycles\n", metrics->avg_memory_latency);
    
    // Optimization recommendations
    if (metrics->l1d_misses / (double)metrics->l1d_accesses > 0.1) {
        printf("Recommendation: Optimize data locality for L1 cache\n");
    }
    if (metrics->l2_misses / (double)metrics->l2_accesses > 0.05) {
        printf("Recommendation: Consider cache blocking for L2 optimization\n");
    }
    if (metrics->l3_misses / (double)metrics->l3_accesses > 0.02) {
        printf("Recommendation: Optimize memory access patterns\n");
    }
}
```

## Automated Performance Analysis

### Performance Regression Detection

```c
typedef struct {
    double baseline_performance;
    double current_performance;
    double regression_threshold;
    char* test_name;
} regression_test_t;

typedef struct {
    regression_test_t* tests;
    int num_tests;
    int passed;
    int failed;
} regression_suite_t;

regression_suite_t* create_regression_suite(void) {
    regression_suite_t* suite = malloc(sizeof(regression_suite_t));
    suite->tests = NULL;
    suite->num_tests = 0;
    suite->passed = 0;
    suite->failed = 0;
    return suite;
}

void add_regression_test(regression_suite_t* suite, const char* name,
                        double baseline, double threshold) {
    suite->num_tests++;
    suite->tests = realloc(suite->tests, suite->num_tests * sizeof(regression_test_t));
    
    regression_test_t* test = &suite->tests[suite->num_tests - 1];
    test->test_name = strdup(name);
    test->baseline_performance = baseline;
    test->regression_threshold = threshold;
    test->current_performance = 0.0;
}

void run_regression_test(regression_suite_t* suite, int test_index,
                        void (*benchmark)(void*), void* arg) {
    regression_test_t* test = &suite->tests[test_index];
    
    // Run benchmark multiple times for statistical significance
    double total_time = 0.0;
    int iterations = 5;
    
    for (int i = 0; i < iterations; i++) {
        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);
        
        benchmark(arg);
        
        clock_gettime(CLOCK_MONOTONIC, &end);
        double time = (end.tv_sec - start.tv_sec) + 
                     (end.tv_nsec - start.tv_nsec) / 1e9;
        total_time += time;
    }
    
    test->current_performance = total_time / iterations;
    
    // Check for regression
    double performance_ratio = test->current_performance / test->baseline_performance;
    
    if (performance_ratio > (1.0 + test->regression_threshold)) {
        printf("REGRESSION: %s - %.2fx slower than baseline\n",
               test->test_name, performance_ratio);
        suite->failed++;
    } else if (performance_ratio < (1.0 - test->regression_threshold)) {
        printf("IMPROVEMENT: %s - %.2fx faster than baseline\n",
               test->test_name, 1.0 / performance_ratio);
        suite->passed++;
    } else {
        printf("STABLE: %s - within %.1f%% of baseline\n",
               test->test_name, test->regression_threshold * 100);
        suite->passed++;
    }
}
```

## Profiling Results and Analysis

### SPE Analysis Results

```bash
# Example SPE profiling output analysis
perf report --stdio --sort=symbol,dso | head -20

# Samples: 45K of event 'arm_spe_0/ts_enable=1,pa_enable=1/'
# Event count (approx.): 45234
#
# Overhead  Command          Shared Object      Symbol
# ........  ...............  .................  ............................
#
    23.45%  neoverse-tutorial  neoverse-tutorial  [.] matrix_multiply_baseline
    12.34%  neoverse-tutorial  neoverse-tutorial  [.] matrix_multiply_neon
     8.76%  neoverse-tutorial  libc-2.31.so       [.] __memset_generic
     6.54%  neoverse-tutorial  neoverse-tutorial  [.] allocate_aligned_matrix
     5.43%  neoverse-tutorial  neoverse-tutorial  [.] matrix_multiply_sve
     4.32%  neoverse-tutorial  libc-2.31.so       [.] malloc
     3.21%  neoverse-tutorial  neoverse-tutorial  [.] benchmark_runner
```

### Memory Latency Analysis

| Access Type | Average Latency | 95th Percentile | Cache Level |
|-------------|-----------------|-----------------|-------------|
| L1D Hit | 4 cycles | 4 cycles | L1 |
| L2 Hit | 12 cycles | 15 cycles | L2 |
| L3 Hit | 45 cycles | 67 cycles | L3 |
| Memory | 180 cycles | 320 cycles | DRAM |
| Remote NUMA | 280 cycles | 450 cycles | Remote DRAM |

### Top-Down Analysis Results

| Workload | Frontend Bound | Backend Bound | Bad Speculation | Retiring |
|----------|----------------|---------------|-----------------|----------|
| Baseline Matrix | 15% | 45% | 8% | 32% |
| NEON Optimized | 12% | 35% | 6% | 47% |
| SVE Optimized | 10% | 28% | 5% | 57% |
| Cache Blocked | 8% | 25% | 4% | 63% |

## Running Profiling Tests

```bash
# Comprehensive profiling suite
./build/neoverse-tutorial --test=profiling-suite --size=large

# SPE-specific analysis
perf record -e arm_spe_0/ts_enable=1,pa_enable=1,load_filter=1,store_filter=1/ \
  ./build/neoverse-tutorial --size=large
perf report --sort=symbol,mem --stdio

# Top-down analysis
perf stat -M TopdownL1 ./build/neoverse-tutorial --size=medium

# Memory access pattern analysis
perf mem record -a ./build/neoverse-tutorial --size=large
perf mem report --sort=mem,symbol --stdio
```

## Profiling Best Practices

### Measurement Methodology

1. **Run multiple iterations**: Statistical significance requires multiple runs
2. **Control environment**: Disable frequency scaling, background processes
3. **Use appropriate sample rates**: Balance overhead vs. accuracy
4. **Profile representative workloads**: Use realistic data sizes and access patterns

### Tool Selection

1. **perf stat**: High-level performance overview
2. **perf record**: Detailed hotspot analysis
3. **SPE**: Memory access pattern analysis
4. **Top-down**: Systematic bottleneck identification

### Analysis Workflow

1. **Start with perf stat**: Identify major bottlenecks
2. **Use top-down methodology**: Systematic analysis approach
3. **Drill down with perf record**: Identify specific hotspots
4. **Validate with SPE**: Understand memory behavior
5. **Measure optimization impact**: Before/after comparison

## Next Steps

Advanced profiling capabilities are now at your disposal for continuous performance optimization. With these tools and methodologies, you can:

1. **[Performance Analysis Deep Dive](./)**: Apply profiling to identify specific bottlenecks
2. **[Cost-Benefit Analysis](./)**: Quantify the business impact of optimizations

> **💡 Tip**:
**Profiling Strategy**: Start with high-level metrics (perf stat) to identify the primary bottleneck category, then use specialized tools (SPE, top-down) to drill down into specific issues. Always profile before and after optimizations to validate improvements.


## Troubleshooting

**SPE Not Available**:
- Check hardware support: `ls /sys/bus/event_source/devices/ | grep spe`
- Verify kernel support: SPE requires Linux 4.10+
- Check permissions: May require root or `perf_event_paranoid` adjustment

**PMU Events Not Working**:
- Verify event names: `perf list | grep -i neoverse`
- Check hardware support: Some events are processor-specific
- Use raw event codes if symbolic names don't work

**Inconsistent Profiling Results**:
- Disable CPU frequency scaling: `sudo cpupower frequency-set -g performance`
- Stop background services: `sudo systemctl stop <service>`
- Use CPU affinity: `taskset -c 0 perf record ...`

Advanced profiling and analysis capabilities are now established, providing the foundation for data-driven performance optimization and continuous performance monitoring of your Neoverse applications.
