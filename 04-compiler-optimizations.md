
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
- **`-march=native`**: When you ask for native, under-the-hood GCC queries the CPU hardware for the most up-to-date features sets included in the processor and optimizes for them.
- **`-march=custom`**: Let's you cherry-pick the flags available via native.

To see which flags are available on your system if you were to pass a custom set of flags, run:

```bash
gcc -march=native -dM -E - < /dev/null | grep __ARM_FEATURE | sort > native.txt
```
You can then cross reference them with the official ARM architecture extensions list here to derive the actual -march flags you can use:

https://github.com/gcc-mirror/gcc/blob/master/gcc/config/aarch64/aarch64-option-extensions.def

TODO: provide this as a script



### Testing Architecture-Specific Flags

Run the following command to test optimization levels 1 and 2, with the architecture-specific -mtune and -march flags, running each configuration 3 times:

```bash
ubuntu@ip-172-31-16-119:~/arm_benchmarking$ ./scripts/04/test-all-combinations.sh --opt-levels 1,2 --runs 3 --arch-flags --sizes 1,2
```
The output will look like this:

```output
| Matrix Size      | Pending | Running | Complete | Current  | Run#  |
|------------------|---------|---------|----------|----------|-------|
Running tests with maximum 46 parallel jobs...

Processing micro matrices...
| Micro (64x64)    | 12      | 0       | 0        | -        | -     |
| Small (512x512)  | 12      | 0       | 0        | -        | -     |

Processing small matrices...
=== Benchmark Status Dashboard ===
Updated: 05:18:36

| Matrix Size      | Pending | Running | Complete | Current  | Run#  |
|------------------|---------|---------|----------|----------|-------|
| Micro (64x64)    | 0       | 0       | 12       | -        | -     |
| Small (512x512)  | 4       | 8       | 0        | Active   | 1     |

=== Benchmark Status Dashboard ===
Updated: 05:18:37

| Matrix Size      | Pending | Running | Complete | Current  | Run#  |
|------------------|---------|---------|----------|----------|-------|
| Micro (64x64)    | 0       | 0       | 12       | -        | -     |
| Small (512x512)  | 0       | 4       | 8        | Active   | 2     |

=== Benchmark Status Dashboard ===
Updated: 05:18:38

| Matrix Size      | Pending | Running | Complete | Current  | Run#  |
|------------------|---------|---------|----------|----------|-------|
| Micro (64x64)    | 0       | 0       | 12       | -        | -     |
| Small (512x512)  | 0       | 4       | 8        | Active   | 3     |

=== Benchmark Status Dashboard ===
Updated: 05:18:39

| Matrix Size      | Pending | Running | Complete | Current  | Run#  |
|------------------|---------|---------|----------|----------|-------|
| Micro (64x64)    | 0       | 0       | 12       | -        | -     |
| Small (512x512)  | 0       | 0       | 12       | -        | -     |

=== Performance Results (Grouped by Matrix Size) ===

### Micro Matrix (64x64)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | .738     | .001   | .033       | -O0  | None            | None            | F   | [0.7451,0.7336,0.7389] |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| 1     | 4.523    | 0      | .054       | -O3  | None            | native          | F   | [4.5237,4.5570,4.4555] |
| 2     | 4.505    | 0      | .051       | -O2  | native          | native          | F   | [4.5060,4.5059,4.4960] |
| 3     | 4.482    | 0      | .053       | -O3  | None            | None            | F   | [4.4878,4.4822,4.4689] |
| 4     | 4.481    | 0      | .050       | -O2  | None            | None            | F   | [4.5086,4.4583,4.4813] |
| 5     | 4.479    | 0      | .051       | -O2  | None            | native          | F   | [4.3644,4.4798,4.4930] |
| 6     | 4.152    | 0      | .055       | -O3  | native          | native          | F   | [4.4959,4.1527,3.8297] |
| 7     | 3.731    | 0      | .052       | -O2  | native          | None            | F   | [3.7314,3.7320,3.7316] |
| 8     | 3.731    | 0      | .056       | -O3  | native          | None            | F   | [3.7316,3.7317,3.7315] |
| 9     | .737     | .001   | .033       | -O0  | native          | None            | F   | [0.7342,0.7379,0.7374] |
| 10    | .736     | .001   | .033       | -O0  | None            | native          | F   | [0.7379,0.7316,0.7362] |
| 11    | .731     | .001   | .033       | -O0  | native          | native          | F   | [0.7312,0.7366,0.7319] |

### Small Matrix (512x512)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | .653     | .411   | .032       | -O0  | None            | None            | F   | [0.6546,0.6536,0.6521] |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| 1     | 2.586    | .104   | .056       | -O3  | native          | None            | F   | [2.5699,2.5977,2.5865] |
| 2     | 2.575    | .104   | .053       | -O2  | native          | None            | F   | [2.5785,2.5691,2.5751] |
| 3     | 2.374    | .113   | .055       | -O3  | None            | native          | F   | [2.3742,2.3875,2.3421] |
| 4     | 2.360    | .114   | .052       | -O2  | native          | native          | F   | [2.3602,2.3149,2.3634] |
| 5     | 2.354    | .114   | .051       | -O2  | None            | native          | F   | [2.3584,2.3443,2.3544] |
| 6     | 2.348    | .114   | .054       | -O3  | native          | native          | F   | [2.3895,2.3128,2.3481] |
| 7     | 2.344    | .115   | .054       | -O3  | None            | None            | F   | [2.3441,2.3836,2.3381] |
| 8     | 2.332    | .115   | .050       | -O2  | None            | None            | F   | [2.3329,2.3080,2.3488] |
| 9     | .658     | .407   | .032       | -O0  | None            | native          | F   | [0.6591,0.6587,0.6559] |
| 10    | .656     | .409   | .033       | -O0  | native          | None            | F   | [0.6566,0.6548,0.6568] |
| 11    | .654     | .410   | .033       | -O0  | native          | native          | F   | [0.6515,0.6583,0.6544] |

=== Key Insights ===

**Micro Matrix (64x64) Performance:**
-- Best: 510.0% performance **gain** over baseline using -O3, -march None, -mtune native, extra flags None
-- Worst: 410.0% performance **gain** over baseline using -O3, -march native, -mtune None, extra flags None

**Small Matrix (512x512) Performance:**
-- Best: 290.0% performance **gain** over baseline using -O3, -march native, -mtune None, extra flags None
-- Worst: 250.0% performance **gain** over baseline using -O2, -march None, -mtune None, extra flags None
```


You can see that as the matrix size increases, the performance benefits of architecture-specific flags may vary.  

In this example, using -O2 with -march native and -mtune native provides the best performance for the medium matrix (1.15 GFLOPS, 160% improvement over baseline):


```bash
./scripts/04/test-all-combinations.sh --opt-levels 2,3 --runs 3 --arch-flags --sizes 3
```

```output
### Medium Matrix (1024x1024)

| Rank  | GFLOPS   | Run    | Compile    | Opt  | -march          | -mtune          | PGO | Individual Runs |
|       |          | Time   | Time       |      |                 |                |     |                 |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| -1    | .640     | 3.351  | .033       | -O0  | None            | None            | F   | [0.6167,0.6439,0.6409] |
|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|
| 1     | 1.268    | 1.693  | .056       | -O3  | None            | native          | F   | [1.2620,1.2682,1.2749] |
| 2     | 1.268    | 1.693  | .057       | -O3  | native          | native          | F   | [1.2628,1.2686,1.2761] |
| 3     | 1.268    | 1.693  | .058       | -O3  | native          | None            | F   | [1.2626,1.2685,1.2751] |
| 4     | 1.268    | 1.694  | .053       | -O2  | None            | native          | F   | [1.2613,1.2680,1.2738] |
| 5     | 1.268    | 1.694  | .054       | -O2  | native          | native          | F   | [1.2614,1.2681,1.2743] |
| 6     | 1.268    | 1.694  | .055       | -O2  | native          | None            | F   | [1.2612,1.2681,1.2740] |
| 7     | 1.268    | 1.694  | .055       | -O3  | None            | None            | F   | [1.2614,1.2680,1.2747] |
| 8     | 1.267    | 1.694  | .053       | -O2  | None            | None            | F   | [1.2616,1.2679,1.2737] |
| 9     | .640     | 3.351  | .033       | -O0  | None            | native          | F   | [0.6168,0.6443,0.6408] |
| 10    | .640     | 3.354  | .034       | -O0  | native          | None            | F   | [0.6170,0.6444,0.6403] |
| 11    | .640     | 3.355  | .034       | -O0  | native          | native          | F   | [0.6175,0.6405,0.6401] |

=== Key Insights ===

**Medium Matrix (1024x1024) Performance:**
-- Best: 90.0% performance **gain** over baseline using -O3, -march None, -mtune native, extra flags None
-- Worst: 90.0% performance **gain** over baseline using -O2, -march None, -mtune None, extra flags None

TODO: bug on best/worst calculation here
```


### Expect unexpected Results (sometimes)

You may think that always compiling with optimization level of -O3 and with Neoverse-specific flags will always provide the best results, but actual benchmark results may show a more nuanced picture.  For example, aggressive optimization may sometimes hurt performance, absence of compile options sometimes outperforms processor-specific ones, etc.

## Profile-Guided Optimization (PGO)

Profile-Guided Optimization (PGO) is a compiler technique that uses real program execution data to make informed optimization decisions at compile time.  By tailoring the binary to perform optimally against actual runtime logic, PGO improves performance, reduces instruction-cache misses, and lowers branch mispredictions.
 

To do this, the compiler first builds an instrumented binary that profiles how the program behaves during runtime.  The instrumented program is run, outputting profiling data, which is then fed back into a second compilation pass, enabling the compiler to optimize specifically for real-world execution scenarios. 


Testing this across all the matrix examples using only architecture-specific flags and optimization levels can provide significant performance improvements:

```bash
./scripts/04/test-all-combinations.sh --opt-levels 2,3 --sizes 1,2,3 --runs 3 --arch-flags
```
yields:
```output
=== Key Insights ===

**Micro Matrix (64x64) Performance:**
-- Best: 510.0% performance **gain** over baseline using -O2, -march native, -mtune native, extra flags None
-- Worst: 400.0% performance **gain** over baseline using -O3, -march native, -mtune None, extra flags None

**Small Matrix (512x512) Performance:**
-- Best: 290.0% performance **gain** over baseline using -O3, -march native, -mtune None, extra flags None
-- Worst: 250.0% performance **gain** over baseline using -O2, -march native, -mtune native, extra flags None

**Medium Matrix (1024x1024) Performance:**
-- Best: 90.0% performance **gain** over baseline using -O3, -march native, -mtune native, extra flags None
-- Worst: 90.0% performance **gain** over baseline using -O3, -march None, -mtune native, extra flags None
```

Adding PGO to the mix can optimize even further:

```bash
./scripts/04/test-all-combinations.sh --opt-levels 2,3 --sizes 1,2,3 --runs 3 --arch-flags --pgo
```
yields:
```output
=== Key Insights ===

**Micro Matrix (64x64) Performance:**
-- Best: 570.0% performance **gain** over baseline using -O2, -march None, -mtune None, extra flags PGO
-- Worst: 370.0% performance **gain** over baseline using -O2, -march native, -mtune None, extra flags PGO

**Small Matrix (512x512) Performance:**
-- Best: 290.0% performance **gain** over baseline using -O3, -march native, -mtune None, extra flags None
-- Worst: 250.0% performance **gain** over baseline using -O3, -march None, -mtune None, extra flags PGO

**Medium Matrix (1024x1024) Performance:**
-- Best: 110.0% performance **gain** over baseline using -O3, -march native, -mtune native, extra flags PGO
-- Worst: 90.0% performance **gain** over baseline using -O2, -march None, -mtune None, extra flags None
```

PGO has the potential may provide additional performance improvements on top of existing optimizations in many cases.  It works best on larger, more complex applications where the compiler can make more informed decisions based on real-world execution data.






## LLVM BOLT Post-Link Optimizer

BOLT optimizes binaries after linking using runtime profile data.

NOTE:  To continue with this section, you will need to have `perf` and `llvm-bolt` [installed on your system](https://learn.arm.com/install-guides/bolt/).  If the directions to install the actual perf binary on AWS EC2 do not work for you in the install guide, try the following (assumes you are on kernel 6.14): 

```bash
# 1) Grab upstream v6.14 perf (works fine with your 6.14.0-1012-aws kernel)
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux/tools/perf
git checkout v6.14

# 2) Install deps (if you haven’t already)
sudo apt-get install -y build-essential libelf-dev libdw-dev libdebuginfod-dev \
  systemtap-sdt-dev libbpf-dev libslang2-dev libperl-dev llvm-dev \
  liblzma-dev zlib1g-dev libzstd-dev libbabeltrace-dev libcapstone-dev \
  libtraceevent-dev libtracefs-dev libunwind-dev libnuma-dev

# 3) Build and install perf
make -j"$(nproc)"
sudo make install-bin   # installs 'perf' into /usr/local/bin
sudo cp perf /usr/bin  # make sure it's in your PATH
```








## Implementation Difficulty vs. Performance Gain

| Optimization | Implementation Effort | Typical Speedup | Compile Time Impact |
|--------------|----------------------|-----------------|-------------------|
| -O2/-O3 | Trivial | 2-3x | Low |
| Architecture flags | Trivial | +15-25% | None |
| LTO | Easy | +5-15% | Medium |
| Loop hints | Medium | +10-30% | Low |
| PGO | Medium | +10-25% | High |
| BOLT | Hard | +5-15% | High |


> **💡 Tip**:
**Optimization Strategy**: Modern compilers are sophisticated, and you may find that `-O3` with the right flags gets you 80% of the performance with 5% of the effort.


## Next Steps

Compiler optimizations provide excellent baseline performance improvements. With these optimizations in place, you're ready to explore:

1. **[SIMD Optimizations](./)**: Hand-coded vectorization for compute kernels
2. **[Memory Optimizations](./)**: Cache-friendly data structures and access patterns



