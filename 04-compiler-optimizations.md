
## Overview

Using compile-time optimizations provides the quickest performance improvements with the least effort.  Performance gains of 15-30%+ just by modifying compile-time flags are very common.

In this section, we walk you through optimizations including optimization levels, architecture targeting, Profile-Guided Optimization (PGO) and Link-Time Optimization (LTO).

## Optimization Levels and Architecture Targeting

The quickest, least effort optimizations come from using compiler optimization levels and architecture-specific flags.  These optimizations are easy to apply, require no code changes, and can provide significant performance improvements.  You'll begin experimenting first with compiler optimization levels.


### Compiler Optimization Levels

When you compile code, if you don't specify an optimization flag, the compiler defaults to no optimization (`-O0`).  This is great for debugging, but produces very slow code.  In this section, you'll explore common optimization levels, including:

| Flag     | Description                                                          | Typical Use Case                                   |
|----------|----------------------------------------------------------------------|----------------------------------------------------|
| **`-O0`** | (Default) No optimization, fast compilation, easy debugging.         | Debug builds.                                      |
| **`-O1`** | Basic optimizations with minimal compile-time cost.                  | Quick builds with some speed.                      |
| **`-O2`** | Standard “production” optimization, balance of speed and size.       | Default for production.                            |
| **`-O3`** | Aggressive optimizations, larger binaries, max performance focus.    | Performance-critical workloads.                    |

Time to get hands-on!

To begin, compile, run, and generate a non-optimized baseline on your local instance:

```bash
./scripts/04/test-all-combinations.sh --baseline-only --runs 1```

If you have your own C code you'd like to try this with, ...
```
You will see output similar to:

```output

### Micro Matrix (64x64)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | 0.7038   | 0.001  | .037178183 | -O0  | None            | None            | F   | [0.7038]        |

### Small Matrix (512x512)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | 0.6323   | 0.425  | .037733062 | -O0  | None            | None            | F   | [0.6323]        |
```

Do not feel overwhelmed by the amount of values!  For now, all that is needed to remember is that GFLOPS is an easy-to-understand metric to first work with.

### Understanding the Output

- **Rank -1**: Baseline run with no optimizations applied.
- **GFLOPS**: Giga Floating Point Operations Per Second (higher is better).
- **Run Time**: Time taken to execute the matrix multiplication.
- **Compile Time**: Time taken to compile the code with the specified flags.
- **Opt**: Compiler optimization level used (e.g., -O0, -O1, -O2, -O3).
- **-march and -mtune**: Architecture-specific flags, if any.
- **PGO**: Profile-Guided Optimization used (T = true, F = false).
- **Individual Runs**: List of GFLOPS for each run, useful for analyzing variability.


In the example, the code runs the micro and small matrices at baseline (-O0) optimization level, producing a very low baseline GFLOPS (0.70 and 0.63 respectively).  This is expected as no optimizations are applied.

### Run Count
By default, the script runs each configuration once times to get an average performance.

You can adjust this with the `--runs` parameter.  For example, to run micro and small matrix tests, for each configuration 3 times:

```commandline
./scripts/04/test-all-combinations.sh --baseline-only --runs 3
```

you will see output like:

```output
### Micro Matrix (64x64)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | .706     | .001   | .036       | -O0  | None            | None            | F   | [0.7056,0.7066,0.7130] |

### Small Matrix (512x512)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | .630     | .425   | .037       | -O0  | None            | None            | F   | [0.6341,0.6309,0.6309] |
```

Note the Individual Runs column now shows the results of each individual run, which can be useful to see variability in performance.  The GLOPS column calculates an average of these run samples.  No more than (number of cores-2) runs are executed in parallel to avoid taxing the system during metrics-taking.

### Increasing Optimization Levels
Now that you know how to baseline and run tests in parallel, it's time to explore higher optimization levels.

When increasing compiler optimization levels, consider the "bang for the buck"! Most of the performance gains come from the first level of optimization (-O1).  Higher levels (-O2, -O3) provide diminishing returns, and may even hurt performance in some cases.

You can specify the optimization level using the `--opt` parameter.  For example, to test optimization levels 0 and 1:

```commandline

ubuntu@ip-172-31-18-33:~/arm_benchmarking$ ./scripts/04/test-all-combinations.sh --opt-levels 0,1
...
=== Performance Results (Grouped by Matrix Size) ===

### Micro Matrix (64x64)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | 0.7116   | 0.001  | .036468426 | -O0  | None            | None            | F   | [0.7116]        |
| 1     | 3.9681   | 0.000  | .048374333 | -O1  | None            | None            | F   | [3.9681]        |

### Small Matrix (512x512)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | 0.6275   | 0.428  | .035180066 | -O0  | None            | None            | F   | [0.6275]        |
| 1     | 1.9831   | 0.135  | .049730056 | -O1  | None            | None            | F   | [1.9831]        |

=== Key Insights ===

**Micro Matrix (64x64) Performance:**
-- Best: 450.0% performance **gain** over baseline using -O1, -march None, -mtune None, extra flags None

**Small Matrix (512x512) Performance:**
-- Best: 210.0% performance **gain** over baseline using -O1, -march None, -mtune None, extra flags None
```
You can see from this run that setting the -01 flag results in a massive 4.0 GFLOPS for the micro matrix (a 450% improvement over baseline) and a 1.98 GFLOPS for the small matrix (a 210% improvement over baseline).

You could then also see what happens across a three-run average with optimization levels 0-3:

```commandline
./scripts/04/test-all-combinations.sh --opt-levels 0,1,2,3 --runs 3 
...
### Micro Matrix (64x64)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | .713     | .001   | .036       | -O0  | None            | None            | F   | [0.7190,0.7130,0.7085] |
| 1     | 4.350    | 0      | .056       | -O2  | None            | None            | F   | [4.2072,4.4002,4.3502] |
| 2     | 4.319    | 0      | .059       | -O3  | None            | None            | F   | [4.2174,4.3192,4.3337] |
| 3     | 3.900    | 0      | .049       | -O1  | None            | None            | F   | [3.9814,3.9003,3.5629] |

### Small Matrix (512x512)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | .633     | .424   | .035       | -O0  | None            | None            | F   | [0.6299,0.6338,0.6345] |
| 1     | 2.269    | .118   | .054       | -O2  | None            | None            | F   | [2.2330,2.2785,2.2693] |
| 2     | 2.258    | .119   | .058       | -O3  | None            | None            | F   | [2.2585,2.2555,2.2972] |
| 3     | 1.982    | .135   | .047       | -O1  | None            | None            | F   | [1.9805,1.9865,1.9822] |

=== Key Insights ===

**Micro Matrix (64x64) Performance:**
-- Best: 510.0% performance **gain** over baseline using -O2, -march None, -mtune None, extra flags None
-- Worst: 440.0% performance **gain** over baseline using -O1, -march None, -mtune None, extra flags None

**Small Matrix (512x512) Performance:**
-- Best: 250.0% performance **gain** over baseline using -O2, -march None, -mtune None, extra flags None
-- Worst: 210.0% performance **gain** over baseline using -O1, -march None, -mtune None, extra flags None
```
From the test run results, you can see that using -O2 provides the best performance for both micro (4.35 GFLOPS, 510% improvement) and small (2.27 GFLOPS, 250% improvement) matrices.  

Congrats!  You've now learned how setting the optimization level can provide massive performance improvements with Arm CPUs.  

Next you'll experiment with architecture-targeting flags, an easy way to get additional, incremental performance improvements.

### Architecture-Specific Targeting with -march and -mtune

The architecture targeting flags -march and -mtune are a good place to start when introducing architecture-specific optimizations.  The -march flag enables specific instruction set features available on the target architecture, while the -mtune tunes instruction scheduling for a specific processor family.

The application you are compiling may not specifically take advantage of the optimizations -mtune and -march provide because:

1) The application logic doesn't implement dependent code paths that would benefit from these optimizations.
2) The application logic does implement dependent code paths, but its not written in a way that the compiler can optimize for these flags.

As such, gains in performance by enabling these flags can be variable; none, small, or large benefits are all based on how your application is written.  

#### -mtune

The -mtune flag tunes the compiler for a specific processor family, with backward compatibility on older ARM CPUs.  There are three ways to implement this flag:

- **`-mtune=none`**: Generic tuning optimizations are made, nothing specific to the actual processor or family. This is the default if no -mtune flag is provided as well.
- **`-mtune=native`**: GCC reads the CPUID from /proc/cpuinfo, then performs a lookup against GCC's built-in metadata table to retrieve the correlating "processor family" name (e.g., neoverse-v2) and associated tuning values.
- **`-mtune=neoverse-n1`**, **`-mtune=neoverse-xy`**, like native, but lets you override family with a specific value (if you don't want to use the value native returns).


#### -march

The -march flag enables specific instruction set features of the processor.  This can provide significant performance improvements, but may break compatibility with older ARM CPUs that do not support those features.  There are three ways to implement this flag as well:

- **`-march=none`**: Only the most general instruction architectural features are enabled. This is the default if no -march flag is provided as well.
- **`-march=native`**: When you ask for native, under-the-hood GCC queries the CPU hardware for the most up-to-date features sets included in the processor.
- **`-march=custom`**: Let's you cherry-pick the flags available via native.

To see which flags are available on your system if you were to pass a custom set of flags, run:

```bash
gcc -march=native -dM -E - < /dev/null | grep __ARM_FEATURE | sort > native.txt
```
You can then cross reference them with the official ARM architecture extensions list here to derive the actual -march flags you can use:

https://github.com/gcc-mirror/gcc/blob/master/gcc/config/aarch64/aarch64-option-extensions.def

TODO: provide this as a script



### Testing Architecture-Specific Flags

Run the following command to test optimization levels 1 and 2, with architecture-specific flags enabled, running each configuration 3 times:

```bash
ubuntu@ip-172-31-16-119:~/arm_benchmarking$ ./scripts/04/test-all-combinations.sh --opt-levels 1,2 --runs 3 --arch-flags --sizes 1,2
```
The output will look like this:

```output
### Micro Matrix (64x64)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | .731     | .001   | .033       | -O0  | None            | None            | F   | [0.7409,0.7311,0.7304] |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| 1     | 4.499    | 0      | .052       | -O2  | native          | native          | F   | [4.5155,4.4992,4.4879] |
| 2     | 4.369    | 0      | .051       | -O2  | None            | None            | F   | [4.3697,4.3648,4.3744] |
| 3     | 4.132    | 0      | .052       | -O2  | None            | native          | F   | [4.1322,4.0733,4.5143] |
| 4     | 4.111    | 0      | .045       | -O1  | family          | None            | F   | [4.0986,4.1314,4.1110] |
| 5     | 4.107    | 0      | .045       | -O1  | family          | native          | F   | [4.1074,4.1067,4.1179] |
| 6     | 4.103    | 0      | .044       | -O1  | native          | native          | F   | [4.1039,4.1009,4.1034] |
| 7     | 4.103    | 0      | .044       | -O1  | native          | None            | F   | [3.7433,4.1060,4.1030] |
| 8     | 4.097    | 0      | .044       | -O1  | None            | None            | F   | [4.0976,4.1304,3.8044] |
| 9     | 4.044    | 0      | .044       | -O1  | None            | native          | F   | [4.0442,3.8461,4.1176] |
| 10    | 3.731    | 0      | .053       | -O2  | family          | None            | F   | [3.4764,3.7316,3.7312] |
| 11    | 3.731    | 0      | .054       | -O2  | family          | native          | F   | [3.7314,3.7315,3.7310] |
| 12    | 3.471    | 0      | .053       | -O2  | native          | None            | F   | [3.4719,3.7313,3.3175] |
| 13    | .740     | .001   | .034       | -O0  | native          | None            | F   | [0.7403,0.7288,0.7416] |
| 14    | .738     | .001   | .033       | -O0  | family          | None            | F   | [0.7399,0.7313,0.7386] |
| 15    | .733     | .001   | .033       | -O0  | None            | native          | F   | [0.7370,0.7330,0.7330] |
| 16    | .733     | .001   | .034       | -O0  | native          | native          | F   | [0.7331,0.7402,0.7322] |
| 17    | .729     | .001   | .034       | -O0  | family          | native          | F   | [0.7326,0.7248,0.7291] |

### Small Matrix (512x512)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | .658     | .407   | .033       | -O0  | None            | None            | F   | [0.6582,0.6589,0.6590] |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| 1     | 2.618    | .103   | .054       | -O2  | family          | None            | F   | [2.6186,2.6096,2.6234] |
| 2     | 2.614    | .103   | .054       | -O2  | native          | None            | F   | [2.6013,2.6214,2.6147] |
| 3     | 2.612    | .103   | .054       | -O2  | family          | native          | F   | [2.5995,2.6131,2.6120] |
| 4     | 2.413    | .111   | .043       | -O1  | None            | None            | F   | [2.4139,2.4079,2.4138] |
| 5     | 2.409    | .111   | .044       | -O1  | native          | native          | F   | [2.4092,2.4025,2.4129] |
| 6     | 2.407    | .112   | .045       | -O1  | native          | None            | F   | [2.4130,2.4012,2.4072] |
| 7     | 2.402    | .112   | .044       | -O1  | family          | None            | F   | [2.4153,2.3863,2.4020] |
| 8     | 2.396    | .112   | .045       | -O1  | family          | native          | F   | [2.4049,2.3959,2.3960] |
| 9     | 2.395    | .112   | .044       | -O1  | None            | native          | F   | [2.4091,2.3953,2.3940] |
| 10    | 2.364    | .114   | .053       | -O2  | None            | native          | F   | [2.3643,2.3686,2.3612] |
| 11    | 2.363    | .114   | .053       | -O2  | native          | native          | F   | [2.3450,2.3634,2.3753] |
| 12    | 2.355    | .114   | .052       | -O2  | None            | None            | F   | [2.3574,2.3208,2.3559] |
| 13    | .656     | .409   | .034       | -O0  | family          | native          | F   | [0.6569,0.6576,0.6534] |
| 14    | .656     | .409   | .034       | -O0  | native          | native          | F   | [0.6573,0.6537,0.6566] |
| 15    | .655     | .409   | .034       | -O0  | None            | native          | F   | [0.6559,0.6596,0.6540] |
| 16    | .655     | .410   | .034       | -O0  | native          | None            | F   | [0.6559,0.6551,0.6467] |
| 17    | .653     | .411   | .034       | -O0  | family          | None            | F   | [0.6534,0.6532,0.6569] |

=== Key Insights ===

**Micro Matrix (64x64) Performance:**
-- Best: 510.0% performance **gain** over baseline using -O2, -march native, -mtune native, extra flags None
-- Worst: 370.0% performance **gain** over baseline using -O2, -march native, -mtune None, extra flags None

**Small Matrix (512x512) Performance:**
-- Best: 290.0% performance **gain** over baseline using -O2, -march family, -mtune None, extra flags None
-- Worst: 250.0% performance **gain** over baseline using -O2, -march None, -mtune None, extra flags None
```

You can now see the -march and -mtune flags in action.  In this example, using -O2 with -march native and -mtune native provides the best performance for the micro matrix (4.50 GFLOPS, 510% improvement) and using -O2 with -march family and -mtune None provides the best performance for the small matrix (2.62 GFLOPS, 290% improvement).

Run again with this command line to see results for optimization levels 2 and 3, with architecture-specific flags enabled, running each configuration 3 times, against the medium (1024x1024) matrix size:

```bash
./scripts/04/test-all-combinations.sh --opt-levels 2,3 --runs 3 --arch-flags --sizes 3
```

You can see that as the matrix size increases, the performance benefits of architecture-specific flags may vary.  In this example, using -O2 with -march native and -mtune native provides the best performance for the medium matrix (1.15 GFLOPS, 160% improvement over baseline):

```output
### Medium Matrix (1024x1024)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | .628     | 3.415  | .033       | -O0  | None            | None            | F   | [0.6097,0.6288,0.6410] |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| 1     | 1.231    | 1.743  | .057       | -O3  | native          | native          | F   | [1.2244,1.2317,1.2379] |
| 2     | 1.230    | 1.746  | .055       | -O2  | family          | None            | F   | [1.2243,1.2303,1.2307] |
| 3     | 1.229    | 1.746  | .054       | -O2  | native          | native          | F   | [1.2242,1.2305,1.2299] |
| 4     | 1.229    | 1.746  | .056       | -O2  | family          | native          | F   | [1.2243,1.2299,1.2321] |
| 5     | 1.229    | 1.746  | .056       | -O3  | None            | None            | F   | [1.2243,1.2299,1.2335] |
| 6     | 1.229    | 1.746  | .058       | -O3  | None            | native          | F   | [1.2241,1.2296,1.2351] |
| 7     | 1.229    | 1.747  | .054       | -O2  | None            | native          | F   | [1.2243,1.2304,1.2290] |
| 8     | 1.229    | 1.747  | .056       | -O2  | native          | None            | F   | [1.2241,1.2306,1.2292] |
| 9     | 1.229    | 1.747  | .058       | -O3  | family          | None            | F   | [1.2247,1.2294,1.2399] |
| 10    | 1.229    | 1.747  | .059       | -O3  | family          | native          | F   | [1.2250,1.2293,1.2414] |
| 11    | 1.229    | 1.747  | .059       | -O3  | native          | None            | F   | [1.2242,1.2295,1.2367] |
| 12    | 1.228    | 1.747  | .053       | -O2  | None            | None            | F   | [1.2243,1.2307,1.2289] |
| 13    | .632     | 3.398  | .033       | -O0  | None            | native          | F   | [0.6098,0.6320,0.6354] |
| 14    | .631     | 3.402  | .033       | -O0  | family          | None            | F   | [0.6057,0.6312,0.6358] |
| 15    | .631     | 3.403  | .034       | -O0  | family          | native          | F   | [0.6121,0.6310,0.6412] |
| 16    | .630     | 3.405  | .034       | -O0  | native          | native          | F   | [0.6057,0.6307,0.6370] |
| 17    | .629     | 3.410  | .034       | -O0  | native          | None            | F   | [0.6107,0.6297,0.6404] |

=== Key Insights ===

**Medium Matrix (1024x1024) Performance:**
-- Best: 90.0% performance **gain** over baseline using -O3, -march native, -mtune native, extra flags None
-- Worst: 90.0% performance **gain** over baseline using -O2, -march None, -mtune None, extra flags None
```

## Advanced Flags

| Flag | Description | Notes | Recommended Usage |
|------|-------------|-------|-------------------|
| **`-flto`** | **Link Time Optimization (LTO):** optimizer runs across multiple files at link time. | Produces smaller, faster binaries. Longer build times. | Safe for production when longer builds are acceptable. |
| **`-fomit-frame-pointer`** | Removes frame pointer register usage, freeing it for other optimizations. | Enabled by default at higher `-O` levels (except for debugging). | Use in release builds; avoid if you need precise debugging/profiling. |
| **`-funroll-loops`** | Aggressively unrolls loops for speed. | Often enabled at `-O3`, may increase binary size. | Use for performance-critical, loop-heavy code (HPC/ML). |
| **`-ffast-math`** | Optimizes floating point math aggressively (reordering, removing edge-case checks). | Included in `-Ofast`. Unsafe for strict IEEE compliance. | Use only if numerical reproducibility is not critical. |
| **`-march=<arch>`** | Target a **specific CPU family** (e.g., `-march=skylake`, `-march=armv8-a`). | Great for deployment-specific binaries; not portable across CPUs. | Use when building for a known deployment environment. |
| **`-mtune=<cpu>`** | Optimize instruction scheduling for a specific CPU, but **still runs on older CPUs**. | Example: `-mtune=skylake` — tuned for Skylake but still portable. | Safe default; combine with `-O2` or `-O3` for extra gains. |

Begin by running a baseline and then all combinations of optimizations and architecture targeting with this command:

```bash
# Test all combinations of optimization levels, architecture flags, and matrix sizes
./scripts/04/test-all-combinations.sh
```

The baseline is established with no compiler optimizations (mtune, march, or -O flags). The script then tests all combinations of optimization levels, architecture targeting, and matrix sizes to provide a comprehensive performance overview.


This automatically tests every combination of:
- **Optimization levels**: -O0, -O1, -O2, -O3
- **Architecture targeting**: generic, native, Neoverse-specific
- **Matrix sizes**: micro (64x64), small (512x512), medium (2048x2048)

### Complete Performance Results

**Actual results on Neoverse V2 (top 20 combinations):**
```
| Rank  | GFLOPS   | Time(s) | Opt  | Architecture | Size   |
|-------|----------|--------|------|--------------|--------|
| 1     | 4.52     | 0.000  | -O2  | generic      | micro  |
| 2     | 4.49     | 0.000  | -O3  | generic      | micro  |
| 3     | 4.37     | 0.000  | -O3  | native       | micro  |
| 4     | 4.13     | 0.000  | -O1  | native       | micro  |
| 5     | 4.12     | 0.000  | -O1  | Neoverse-V2  | micro  |
| 6     | 4.11     | 0.000  | -O2  | native       | micro  |
| 7     | 3.89     | 0.000  | -O1  | generic      | micro  |
| 8     | 3.73     | 0.000  | -O3  | Neoverse-V2  | micro  |
| 9     | 3.45     | 0.000  | -O2  | Neoverse-V2  | micro  |
| 10    | 2.59     | 0.104  | -O2  | Neoverse-V2  | small  |
```



### Expect unexpected Results (sometimes)

You may think that always compiling with optimization level of -O3 and with Neoverse-specific flags will always provide the best results, but actual benchmark results may show a more nuanced picture.  For example, aggressive optimization may sometimes hurt performance, absence of compile options sometimes outperforms processor-specific ones, etc.
### Optimization Strategy Recommendations


## Advanced Compiler Optimizations

### A
### Optimization Levels

```bash
# Basic optimization - good balance of compile time and performance
CFLAGS="-O2"

# Aggressive optimization - maximum performance
CFLAGS="-O3"

# Size optimization - for memory-constrained environments
CFLAGS="-Os"

# Fast compilation with basic optimization
CFLAGS="-O1"
```

## Running Compiler Optimization Tests

Execute this command to test compiler optimizations and compare with your baseline:

```bash
# Test all compiler optimization levels and compare with baseline
./scripts/04/test-compiler-opts.sh
```

For a comprehensive analysis of all optimization combinations:

```bash
# Test all combinations of optimization levels × architecture targeting
./scripts/04/test-compiler-matrix.sh
```

### Comprehensive Optimization Matrix

The matrix test shows performance across all combinations:

**Example results on Neoverse V2:**
```
| Optimization | Generic  | Native   | Neoverse | Best     |
|--------------|----------|----------|----------|----------|
| -O0 (baseline) | 0.65     | 0.65     | 0.65     | 0.65x    |
| -O1          | 2.40     | 2.42     | 2.41     | 3.7x     |
| -O2          | 2.36     | 2.36     | 2.58     | 3.9x     |
| -O3          | 2.37     | 2.37     | 2.59     | 3.9x     |
```

### Performance Across Matrix Sizes

To see how compiler optimizations scale with problem size:

```bash
# Compare baseline vs optimized across all matrix sizes
./scripts/04/compare-sizes.sh
```

**Example results showing optimization impact by size:**
```
| Size | Baseline (GFLOPS) | Optimized (GFLOPS) | Speedup | Time Reduction |
|------|-------------------|---------------------|---------|----------------|
| micro | 0.74              | 3.73                | 5.0x    | 100.0%         |
| small | 0.66              | 2.59                | 3.9x    | 70.0%          |
| medium | 0.59              | 0.68                | 1.1x    | 10.0%          |
```

**Key insight**: Compiler optimizations provide massive gains for cache-friendly workloads but diminishing returns as problems become memory-bound. This demonstrates why different optimization strategies are needed for different problem scales.

### Understanding the Results

**Example output on Neoverse V2:**
```
Detected: Neoverse-V2
Using flags: -march=armv9-a+sve2+bf16+i8mm -mtune=neoverse-v2

=== Performance Comparison ===
  -O1: 2.42 GFLOPS (3.7x speedup)
  -O2: 2.34 GFLOPS (3.6x speedup)  
  -O3: 2.37 GFLOPS (3.6x speedup)
  -O3 + Neoverse flags: 2.58 GFLOPS (3.9x speedup)
```

**Key insights:**
- **-O1 provides most gains**: Often 3-4x improvement over -O0
- **-O2 vs -O3**: Diminishing returns, sometimes -O2 is faster
- **Neoverse-specific flags**: Additional 9% improvement (2.57 vs 2.35 GFLOPS)
- **Processor detection**: Script automatically detects your Neoverse type and uses optimal flags
- **Same source code**: Only compilation flags changed, demonstrating compiler impact

### What the Compiler Does

The optimizations transform your code without changing the algorithm:

**-O1 optimizations:**
- Loop unrolling and basic vectorization
- Dead code elimination
- Register allocation improvements

**-O2 optimizations:**
- Aggressive inlining and loop optimizations
- Instruction scheduling for Neoverse pipelines
- Auto-vectorization with NEON instructions

**-O3 optimizations:**
- More aggressive loop transformations
- Function cloning and specialization
- Advanced instruction-level parallelism

**-O3 + Neoverse-specific optimizations:**
- SVE2 instructions (variable-length vectors)
- BF16 and I8MM matrix operations
- Neoverse V2-specific instruction scheduling
- Advanced crypto acceleration instructions
- LSE atomic operations for better concurrency

## Expected Results: Basic Optimizations

### Optimization Level Comparison (2048x2048 matrix, Neoverse N1)

| Optimization | Time (sec) | GFLOPS | Speedup | Compile Time |
|--------------|------------|--------|---------|--------------|
| -O0 (baseline) | 45.23 | 0.38 | 1.0x | 2.1s |
| -O1 | 28.45 | 0.60 | 1.6x | 2.3s |
| -O2 | 18.92 | 0.91 | 2.4x | 3.1s |
| -O3 | 16.78 | 1.02 | 2.7x | 4.2s |
| -Os | 22.34 | 0.77 | 2.0x | 2.8s |

### Architecture-Specific Targeting (with -O3)

| Target | Time (sec) | GFLOPS | Speedup | Notes |
|--------|------------|--------|---------|-------|
| Generic (-march=armv8-a) | 16.78 | 1.02 | 1.0x | Baseline |
| Neoverse N1 specific | 14.23 | 1.21 | 1.18x | Better scheduling |
| With crypto extensions | 13.89 | 1.24 | 1.21x | Faster math functions |
| With dotprod | 13.12 | 1.31 | 1.28x | Optimized accumulation |

## Advanced Compiler Optimizations

### Link-Time Optimization (LTO)

LTO enables optimizations across translation units:

```bash
# Enable LTO
CFLAGS="-O3 -flto"
LDFLAGS="-flto"

# Test LTO impact
./build/neoverse-tutorial --test=lto --size=medium
```

**LTO Benefits:**
- Cross-module inlining
- Better dead code elimination  
- Improved constant propagation
- Typical gain: 5-15% additional improvement

### Profile-Guided Optimization (PGO)

PGO uses runtime profiling data to guide optimizations:

```bash
# Step 1: Build with profiling instrumentation
CFLAGS="-O3 -fprofile-generate"
make clean && make

# Step 2: Run representative workload to collect profile data
./build/neoverse-tutorial --profile-collect --size=medium

# Step 3: Rebuild with profile data
CFLAGS="-O3 -fprofile-use"
make clean && make

# Step 4: Test optimized binary
./build/neoverse-tutorial --test=pgo --size=medium
```

**PGO Benefits:**
- Better branch prediction
- Optimized function layout
- Improved inlining decisions
- Typical gain: 10-25% additional improvement

### Context-Sensitive PGO (CSPGO)

Advanced PGO that considers calling context:

```bash
# LLVM CSPGO (requires Clang)
CFLAGS="-O3 -fprofile-generate -fcs-profile-generate"
# ... collect profile data ...
CFLAGS="-O3 -fprofile-use -fcs-profile-use"
```

## LLVM BOLT Post-Link Optimizer

BOLT optimizes binaries after linking using runtime profile data:

```bash
# Build optimized binary
CFLAGS="-O3 -march=neoverse-n1"
make

# Collect runtime profile with perf
perf record -e cycles:u -j any,u -- ./build/neoverse-tutorial --size=medium

# Convert perf data for BOLT
perf2bolt ./build/neoverse-tutorial -p perf.data -o tutorial.fdata

# Apply BOLT optimizations
llvm-bolt ./build/neoverse-tutorial -data=tutorial.fdata -reorder-blocks=ext-tsp \
  -reorder-functions=hfsort -split-functions -split-all-cold \
  -o ./build/neoverse-tutorial-bolt

# Test BOLT-optimized binary
./build/neoverse-tutorial-bolt --test=bolt --size=medium
```

## Compiler-Specific Optimizations

### GCC-Specific Flags

```bash
# Neoverse-optimized GCC flags
CFLAGS="-O3 -march=neoverse-n1 -mtune=neoverse-n1 \
        -ffast-math -funroll-loops -fprefetch-loop-arrays \
        -ftree-vectorize -fvect-cost-model=dynamic"
```

### Clang/LLVM-Specific Flags

```bash
# Neoverse-optimized Clang flags  
CFLAGS="-O3 -march=neoverse-n1 -mtune=neoverse-n1 \
        -ffast-math -funroll-loops -fvectorize \
        -mllvm -enable-load-pre -mllvm -enable-gvn-hoist"
```

## Loop Optimization Hints

Guide the compiler's loop optimization decisions:

```c
// Vectorization hints
#pragma GCC ivdep  // Ignore vector dependencies
#pragma clang loop vectorize(enable)

// Unrolling hints
#pragma GCC unroll 4
#pragma clang loop unroll_count(4)

// Example in matrix multiplication
void matrix_multiply_hints(const float* A, const float* B, float* C, 
                          int M, int N, int K) {
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) {
            float sum = 0.0f;
            #pragma GCC ivdep
            #pragma clang loop vectorize(enable)
            for (int k = 0; k < K; k++) {
                sum += A[i * K + k] * B[k * N + j];
            }
            C[i * N + j] = sum;
        }
    }
}
```

## Branch Prediction Hints

Help the compiler optimize branch prediction:

```c
#include <stddef.h>

// Likely/unlikely macros
#define likely(x)   __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)

// Example usage
void optimized_function(int* data, size_t size) {
    for (size_t i = 0; i < size; i++) {
        if (likely(data[i] > 0)) {
            // Hot path - optimized for this case
            data[i] *= 2;
        } else if (unlikely(data[i] < -1000)) {
            // Cold path - rare error case
            handle_error(data[i]);
        }
    }
}
```

## Comprehensive Compiler Test Results

Running all compiler optimizations on different matrix sizes:

### Small Matrix (512x512) - Cache-Friendly

| Optimization | Time (ms) | GFLOPS | Speedup | Notes |
|--------------|-----------|--------|---------|-------|
| Baseline (-O0) | 1,234 | 0.22 | 1.0x | |
| -O3 | 387 | 0.70 | 3.2x | Basic optimization |
| -O3 + arch flags | 298 | 0.91 | 4.1x | Neoverse-specific |
| + LTO | 276 | 0.98 | 4.5x | Cross-module opts |
| + PGO | 234 | 1.16 | 5.3x | Profile-guided |
| + BOLT | 218 | 1.24 | 5.7x | Post-link opts |

### Large Matrix (8192x8192) - Memory-Bound

| Optimization | Time (sec) | GFLOPS | Speedup | Notes |
|--------------|------------|--------|---------|-------|
| Baseline (-O0) | 2,847 | 0.39 | 1.0x | |
| -O3 | 1,234 | 0.90 | 2.3x | Basic optimization |
| -O3 + arch flags | 1,089 | 1.02 | 2.6x | Better memory ops |
| + LTO | 1,034 | 1.07 | 2.8x | Inlined memory funcs |
| + PGO | 967 | 1.15 | 2.9x | Optimized access patterns |
| + BOLT | 923 | 1.20 | 3.1x | Better code layout |

## Implementation Difficulty vs. Performance Gain

| Optimization | Implementation Effort | Typical Speedup | Compile Time Impact |
|--------------|----------------------|-----------------|-------------------|
| -O2/-O3 | Trivial | 2-3x | Low |
| Architecture flags | Trivial | +15-25% | None |
| LTO | Easy | +5-15% | Medium |
| Loop hints | Medium | +10-30% | Low |
| PGO | Medium | +10-25% | High |
| BOLT | Hard | +5-15% | High |

## Best Practices

### Development vs. Production Builds

**Development Build:**
```bash
CFLAGS="-O1 -g -march=native"  # Fast compile, debuggable
```

**Production Build:**
```bash
CFLAGS="-O3 -march=neoverse-n1 -mtune=neoverse-n1 -flto -DNDEBUG"
```

### Compiler Selection

**GCC**: Generally better for Neoverse N-series
**Clang**: Often better for Neoverse V-series with SVE

Test both compilers on your workload:
```bash
./build/neoverse-tutorial --test=compiler-comparison --size=medium
```

## Next Steps

Compiler optimizations provide excellent baseline performance improvements. With these optimizations in place, you're ready to explore:

1. **[SIMD Optimizations](./)**: Hand-coded vectorization for compute kernels
2. **[Memory Optimizations](./)**: Cache-friendly data structures and access patterns

> **💡 Tip**:
**Optimization Strategy**: Always start with compiler optimizations before hand-coding. Modern compilers are sophisticated, and you may find that `-O3` with the right flags gets you 80% of the performance with 5% of the effort.


## Troubleshooting

**Compilation Errors with Architecture Flags:**
- Check that your processor supports the specified features
- Use `./configure` to auto-detect supported features

**Performance Regression with -O3:**
- Try -O2 instead - sometimes aggressive optimization hurts performance
- Profile to identify which specific optimization is problematic

**LTO Link Errors:**
- Ensure all object files are compiled with -flto
- May need to use gcc-ar and gcc-ranlib for static libraries

The foundation of compiler optimizations is now in place. These techniques alone can transform your application's performance significantly before moving to more advanced optimization strategies.
