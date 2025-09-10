#!/bin/bash
# test-all-combinations.sh - Test all combinations with consolidated logic for all matrix sizes

# Check for help flags anywhere in arguments
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --runs N         Number of runs per combination for accuracy (1-7, default: 1)"
    echo "  --opt-levels L   Optimization levels to test (0,1,2,3 combinations, default: 0,1,2,3)"
    echo "  --arch-flags     Enable march/mtune combination testing (default: disabled)"
    echo "  --sizes S        Matrix sizes to test (1,2,3 combinations, default: 1,2)"
    echo "                   1=micro (64x64), 2=small (512x512), 3=medium (1024x1024)"
    echo "  --extra-flags    Include extra optimization flags (default: disabled)"
    echo "                   Adds -flto, -fomit-frame-pointer, -funroll-loops"
    echo "  --pgo            Use profile-guided optimization (default: disabled)"
    echo "                   Adds -fprofile-generate and -fprofile-use"
    echo "  --verbose        Show compiler commands and output (default: disabled)"
    echo "  --baseline-only  Run only baseline configuration (-O0, no march/mtune, PGO=F)"
    echo "  -h, --help       Show this help message"
    echo
    echo "Examples:"
    echo "  $0                                    # Default: 1 run, micro+small, no extra flags"
    echo "  $0 --runs 3 --sizes 1,2,3 --extra-flags --pgo"
    echo "  $0 --runs 5 --sizes 1 --opt-levels 2,3   # 5 runs, micro only, O2+O3 only"
    echo "  $0 --sizes 2,3 --extra-flags --arch-flags # Small+medium with extra flags and arch testing"
    echo "  $0 --baseline-only --runs 3           # Baseline only, 3 runs"
    exit 0
    fi
done

# Clean previous results
rm -rf results/comprehensive/*
rm -rf temp/*

# Default values
num_runs=1
opt_levels_arg="0,1,2,3"
matrix_sizes_arg="1,2"
use_extra_flags=false
use_pgo=false
baseline_only=false
use_arch_flags=false
verbose=false

# Parse named arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --runs)
            num_runs="$2"
            shift 2
            ;;
        --opt-levels)
            opt_levels_arg="$2"
            shift 2
            ;;
        --sizes)
            matrix_sizes_arg="$2"
            shift 2
            ;;
        --arch-flags)
            use_arch_flags=true
            shift
            ;;
        --extra-flags)
            use_extra_flags=true
            shift
            ;;
        --pgo)
            use_pgo=true
            shift
            ;;
        --verbose)
            verbose=true
            shift
            ;;
        --baseline-only)
            baseline_only=true
            shift
            ;;
        *)
            echo "Error: Unknown option $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validate numRuns
if [[ ! "$num_runs" =~ ^[1-7]$ ]]; then
    echo "Error: --runs must be 1-7, got: $num_runs"
    exit 1
fi

# Parse and validate opt levels
IFS=',' read -ra OPT_LEVELS <<< "$opt_levels_arg"
for level in "${OPT_LEVELS[@]}"; do
    if [[ ! "$level" =~ ^[0-3]$ ]]; then
        echo "Error: --opt-levels must contain only 0,1,2,3, got: $level"
        exit 1
    fi
done

echo "=== Comprehensive Compiler Optimization Analysis ==="
echo
echo "=== Test Configuration ==="
if [ "$num_runs" -gt 1 ]; then
    echo "Running each combination $num_runs times (using trimmed mean to remove outliers)"
else
    echo "Running each combination once (single run)"
fi

echo "Runs: $num_runs"
echo "Optimization levels: $opt_levels_arg"
if [ "$use_arch_flags" = true ]; then
    echo "Architecture flags: Enabled"
else
    echo "Architecture flags: Disabled"
fi

# Parse matrix sizes
sizes=()
IFS=',' read -ra SIZE_ARRAY <<< "$matrix_sizes_arg"
for size_num in "${SIZE_ARRAY[@]}"; do
    case $size_num in
        1) sizes+=("micro") ;;
        2) sizes+=("small") ;;
        3) sizes+=("medium") ;;
        *) echo "Error: Invalid matrix size: $size_num (valid: 1,2,3)"; exit 1 ;;
    esac
done

if [ ${#sizes[@]} -eq 0 ]; then
    echo "Error: No valid matrix sizes specified"
    exit 1
fi

# Convert sizes array to readable format
size_names=()
for size in "${sizes[@]}"; do
    case $size in
        "micro") size_names+=("micro (64x64)") ;;
        "small") size_names+=("small (512x512)") ;;
        "medium") size_names+=("medium (1024x1024)") ;;
    esac
done
size_display=$(IFS=', '; echo "${size_names[*]}")
echo "Matrix sizes: $size_display"

# Display baseline-only mode message
if [ "$baseline_only" = true ]; then
    echo "Running baseline-only mode (-O0, no march/mtune, PGO=F)"
    use_extra_flags=false
    use_pgo=false
fi

# Set extra optimization flags
if [ "$use_extra_flags" = true ]; then
    extra_flags=("flto" "fomit-frame-pointer" "funroll-loops")
    echo "Extra flags: Enabled (8x more combinations: 2^3 flag combinations)"
else
    extra_flags=()
    echo "Extra flags: Disabled"
fi

# Set profile-guided optimization
if [ "$use_pgo" = true ]; then
    echo "PGO: Enabled (2x more combinations: with/without PGO)"
else
    echo "PGO: Disabled"
fi
if [ "$verbose" = true ]; then
    echo "Verbose: Enabled (showing compiler commands and output)"
else
    echo "Verbose: Disabled"
fi

# Detect Neoverse processor type
NEOVERSE_TYPE=$(lscpu | grep "Model name" | awk '{print $3}')
case $NEOVERSE_TYPE in
    "Neoverse-N1")
        MARCH_SPECIFIC="armv8.2-a+fp16+rcpc+dotprod+crypto"
        MTUNE_SPECIFIC="neoverse-n1"
        ;;
    "Neoverse-N2")
        MARCH_SPECIFIC="armv9-a+sve2+bf16+i8mm"
        MTUNE_SPECIFIC="neoverse-n2"
        ;;
    "Neoverse-V1")
        MARCH_SPECIFIC="armv8.4-a+sve+bf16+i8mm"
        MTUNE_SPECIFIC="neoverse-v1"
        ;;
    "Neoverse-V2")
        MARCH_SPECIFIC="armv9-a+sve2+bf16+i8mm"
        MTUNE_SPECIFIC="neoverse-v2"
        ;;
    *)
        MARCH_SPECIFIC="native"
        MTUNE_SPECIFIC="native"
        ;;
esac

echo "Detected: $NEOVERSE_TYPE"

# Detect what native would resolve to
NATIVE_MTUNE=$(gcc -march=native -mtune=native -Q --help=target 2>/dev/null | grep -E "^\s*-mtune=" | awk -F= '{print $2}' | tr -d ' ')
if [ -z "$NATIVE_MTUNE" ]; then
    # Try alternative method
    NATIVE_MTUNE=$(echo | gcc -march=native -mtune=native -E -v - 2>&1 | grep -o "mtune=[^ ]*" | cut -d= -f2 | head -1)
fi
if [ -z "$NATIVE_MTUNE" ]; then
    NATIVE_MTUNE="detection_failed"
fi

NATIVE_MARCH=$(gcc -march=native -Q --help=target 2>/dev/null | grep -E "^\s*-march=" | awk -F= '{print $2}' | tr -d ' \t')
if [ -z "$NATIVE_MARCH" ]; then
    # Try mcpu instead as it shows the actual detected processor
    NATIVE_MARCH=$(gcc -march=native -Q --help=target 2>/dev/null | grep -E "^\s*-mcpu=" | awk -F= '{print $2}' | tr -d ' \t')
fi
if [ -z "$NATIVE_MARCH" ]; then
    NATIVE_MARCH="detection_failed"
fi

echo "-march HW detected: $NATIVE_MARCH"
echo "-march predefined: $MARCH_SPECIFIC"
echo "Testing all combinations of optimization levels, architecture flags, and matrix sizes..."
echo

# Function to calculate trimmed mean (removes outliers)
calculate_trimmed_mean() {
    local values=("$@")
    local count=${#values[@]}
    
    if [ $count -eq 1 ]; then
        echo "${values[0]}"
        return
    fi
    
    if [ $count -eq 2 ]; then
        # For 2 values, just take the average
        local sum=$(echo "scale=6; ${values[0]} + ${values[1]}" | bc -l)
        echo "scale=3; $sum / 2" | bc -l
        return
    fi
    
    # Sort values
    IFS=$'\n' sorted=($(printf '%s\n' "${values[@]}" | sort -n))
    
    # Remove outliers (top/bottom 20% or 1 value if <5 runs)
    local remove_count=1
    if [ $count -ge 5 ]; then
        remove_count=$((count / 5))
    fi
    
    # Calculate trimmed mean
    local sum=0
    local used_count=0
    for ((i=remove_count; i<count-remove_count; i++)); do
        sum=$(echo "scale=6; $sum + ${sorted[i]}" | bc -l)
        ((used_count++))
    done
    
    # Prevent divide by zero
    if [ $used_count -eq 0 ]; then
        echo "0"
    else
        echo "scale=3; $sum / $used_count" | bc -l
    fi
}
echo

# Create temp directories
STATUS_DIR="/tmp/benchmark_status_$$"
mkdir -p "$STATUS_DIR"

# Define test parameters
if [ "$baseline_only" = true ]; then
    opt_levels=("O0")
    march_options=("none")
    mtune_options=("none")
else
    # Convert parsed opt levels to array with O prefix
    opt_levels=()
    for level in "${OPT_LEVELS[@]}"; do
        opt_levels+=("O$level")
    done
    
    if [ "$use_arch_flags" = true ]; then
        march_options=("none" "native")
        mtune_options=("none" "native")
    else
        march_options=("none")
        mtune_options=("none")
    fi
fi

# Initialize status files for all combinations
for size in "${sizes[@]}"; do
    for opt in "${opt_levels[@]}"; do
        for march in "${march_options[@]}"; do
            for mtune in "${mtune_options[@]}"; do
                for pgo in $([ "$use_pgo" = true ] && echo "0 1" || echo "0"); do
                    if [ "$use_extra_flags" = true ]; then
                        for flto in 0 1; do
                            for fomit in 0 1; do
                                for funroll in 0 1; do
                                    if [ $pgo -eq 1 ]; then
                                        combo_id="${opt}_${march}_${mtune}_${pgo}_${flto}${fomit}${funroll}_${size}"
                                    else
                                        combo_id="${opt}_${march}_${mtune}_${flto}${fomit}${funroll}_${size}"
                                    fi
                                    echo "Pending" > "$STATUS_DIR/$combo_id"
                                done
                            done
                        done
                    else
                        if [ $pgo -eq 1 ]; then
                            combo_id="${opt}_${march}_${mtune}_${pgo}_${size}"
                        else
                            combo_id="${opt}_${march}_${mtune}_${size}"
                        fi
                        echo "Pending" > "$STATUS_DIR/$combo_id"
                    fi
                done
            done
        done
    done
done

# Start status monitor in background
(
    while [ -d "$STATUS_DIR" ]; do
        printf "\033[2J\033[H"
        echo "=== Benchmark Status Dashboard ==="
        echo "Updated: $(date '+%H:%M:%S')"
        echo
        
        # Table header
        printf "| %-12s | %-8s | %-8s | %-8s | %-8s |\n" "Matrix Size" "Pending" "Running" "Complete" "Current"
        printf "|--------------|----------|----------|----------|----------|\n"
        
        for size in "${sizes[@]}"; do
            size_pending=$(find "$STATUS_DIR" -name "*_${size}" -exec grep -l "Pending" {} \; 2>/dev/null | wc -l)
            size_running=$(find "$STATUS_DIR" -name "*_${size}" -exec grep -l "Running" {} \; 2>/dev/null | wc -l)
            size_complete=$(find "$STATUS_DIR" -name "*_${size}" -exec grep -l "Complete" {} \; 2>/dev/null | wc -l)
            
            current_run=""
            if [ $size_running -gt 0 ]; then
                running_status=$(find "$STATUS_DIR" -name "*_${size}" -exec grep "Running" {} \; 2>/dev/null | head -1)
                if [[ "$running_status" =~ Running\ \(([0-9]+)/[0-9]+\) ]]; then
                    current_run="Run ${BASH_REMATCH[1]}"
                else
                    current_run="Run 1"
                fi
            else
                current_run="-"
            fi
            
            # Convert size to readable name
            case $size in
                "micro") size_name="Micro (64x64)" ;;
                "small") size_name="Small (512x512)" ;;
                *) size_name="$size" ;;
            esac
            
            printf "| %-12s | %-8s | %-8s | %-8s | %-8s |\n" "$size_name" "$size_pending" "$size_running" "$size_complete" "$current_run"
        done
        echo
        
        total=$(ls "$STATUS_DIR" 2>/dev/null | wc -l)
        complete=$(grep -l "Complete" "$STATUS_DIR"/* 2>/dev/null | wc -l)
        if [ $complete -eq $total ]; then
            break
        fi
        
        sleep 1
    done
) &
MONITOR_PID=$!

# Create results and temp directories
mkdir -p results/comprehensive
mkdir -p temp
mkdir -p /tmp/combo_results_$$

# Calculate max parallel jobs (ncpu - 2, minimum 1)
MAX_JOBS=$(($(nproc) - 2))
if [ $MAX_JOBS -lt 1 ]; then
    MAX_JOBS=1
fi

# For PGO, reduce parallelism to avoid file conflicts
if [ "$use_pgo" = true ]; then
    MAX_JOBS=2
    echo "Running tests with reduced parallelism (MAX_JOBS=2) for PGO stability..."
else
    echo "Running tests with maximum $MAX_JOBS parallel jobs..."
fi
echo

# Function to wait for job slots
wait_for_slot() {
    while [ $(grep -l "Running" "$STATUS_DIR"/* 2>/dev/null | wc -l) -ge $MAX_JOBS ]; do
        sleep 0.2
    done
    sleep 0.05
}

declare -a all_results

# UNIFIED EXECUTION LOGIC FOR ALL MATRIX SIZES
for size in "${sizes[@]}"; do
    echo "Processing $size matrices..."
    
    for opt in "${opt_levels[@]}"; do
        for march in "${march_options[@]}"; do
            for mtune in "${mtune_options[@]}"; do
                for pgo in $([ "$use_pgo" = true ] && echo "0 1" || echo "0"); do
                    if [ "$use_extra_flags" = true ]; then
                        for flto in 0 1; do
                            for fomit in 0 1; do
                                for funroll in 0 1; do
                                    # Build flags
                                    flags="-$opt"
                                    
                                    case $march in
                                        "native") flags="$flags -march=native" ;;
                                        "neoverse") flags="$flags -march=$MARCH_SPECIFIC" ;;
                                    esac
                                    
                                    case $mtune in
                                        "native") flags="$flags -mtune=native" ;;
                                        "neoverse") flags="$flags -mtune=$MTUNE_SPECIFIC" ;;
                                    esac
                                    
                                    # Add extra flags
                                    extra_desc=""
                                    [ $flto -eq 1 ] && flags="$flags -flto" && extra_desc="${extra_desc}flto,"
                                    [ $fomit -eq 1 ] && flags="$flags -fomit-frame-pointer" && extra_desc="${extra_desc}fomit-frame-pointer,"
                                    [ $funroll -eq 1 ] && flags="$flags -funroll-loops" && extra_desc="${extra_desc}funroll-loops,"
                                    extra_desc=${extra_desc%,}
                                    
                                    march_desc="$march"
                                    mtune_desc="$mtune"
                                    
                                    wait_for_slot
                                    
                                    # Run test in background
                                    (
                                        if [ $pgo -eq 1 ]; then
                                            combo_id="${opt}_${march}_${mtune}_${pgo}_${flto}${fomit}${funroll}_${size}"
                                        else
                                            combo_id="${opt}_${march}_${mtune}_${flto}${fomit}${funroll}_${size}"
                                        fi
                                        echo "Running" > "$STATUS_DIR/$combo_id"
                                        
                                        # Arrays to store multiple run results
                                        gflops_runs=()
                                        time_runs=()
                                        compile_time_runs=()
                                        
                                        # Run multiple times
                                        for ((run=1; run<=num_runs; run++)); do
                                            echo "Running ($run/$num_runs)" > "$STATUS_DIR/$combo_id"
                                            
                                            exe_name="temp/combo_${opt}_${march}_${mtune}_${pgo}_${flto}${fomit}${funroll}_${size}_$$_${RANDOM}_${run}"
                                            
                                            if [ $pgo -eq 1 ]; then
                                                # PGO compilation - use unique workspace per job
                                                compile1_start=$(date +%s.%N)
                                                pgo_workspace="temp/pgo_workspace_$$_${combo_id}_${run}"
                                                mkdir -p "$pgo_workspace"
                                                pgo_base="pgo_${combo_id}_${run}"
                                                
                                                if [ "$verbose" = true ]; then
                                                    echo "gcc $flags -fprofile-generate -Wall -o $pgo_workspace/${pgo_base}_gen src/optimized_matrix.c -lm"
                                                    gcc $flags -fprofile-generate -Wall -o $pgo_workspace/${pgo_base}_gen src/optimized_matrix.c -lm
                                                else
                                                    gcc $flags -fprofile-generate -Wall -o $pgo_workspace/${pgo_base}_gen src/optimized_matrix.c -lm 2>/dev/null
                                                fi
                                                compile1_end=$(date +%s.%N)
                                                compile1_time=$(echo "scale=3; $compile1_end - $compile1_start" | bc -l)
                                                
                                                if [ $? -eq 0 ] && [ -x "$pgo_workspace/${pgo_base}_gen" ]; then
                                                    # Run profile generation in isolated workspace
                                                    profile_start=$(date +%s.%N)
                                                    if [ "$verbose" = true ]; then
                                                        echo "cd $pgo_workspace && ./${pgo_base}_gen $size"
                                                        (cd $pgo_workspace && ./${pgo_base}_gen $size >/dev/null)
                                                    else
                                                        (cd $pgo_workspace && ./${pgo_base}_gen $size >/dev/null 2>&1)
                                                    fi
                                                    profile_end=$(date +%s.%N)
                                                    profile_time=$(echo "scale=3; $profile_end - $profile_start" | bc -l)
                                                    
                                                    # Check if profile data was generated (look for any .gcda files)
                                                    if [ $? -eq 0 ] && [ -n "$(find $pgo_workspace -name "*.gcda" 2>/dev/null)" ]; then
                                                        # Copy profile data to expected name for compilation
                                                        for gcda_file in $pgo_workspace/*.gcda; do
                                                            if [ -f "$gcda_file" ]; then
                                                                cp "$gcda_file" "$pgo_workspace/${pgo_base}-optimized_matrix.gcda"
                                                                break
                                                            fi
                                                        done
                                                        
                                                        # Compile with profile data in workspace
                                                        compile2_start=$(date +%s.%N)
                                                        src_path="$(pwd)/src/optimized_matrix.c"
                                                        if [ "$verbose" = true ]; then
                                                            echo "cd $pgo_workspace && gcc $flags -fprofile-use -Wno-coverage-mismatch -Wall -o ${pgo_base} $src_path -lm"
                                                            compile_output=$(cd $pgo_workspace && gcc $flags -fprofile-use -Wno-coverage-mismatch -Wall -o ${pgo_base} "$src_path" -lm 2>&1)
                                                            echo "$compile_output"
                                                            if echo "$compile_output" | grep -q "missing-profile"; then
                                                                echo "ERROR: PGO profile data not found despite .gcda files existing. PGO is not working correctly."
                                                                exit 1
                                                            fi
                                                        else
                                                            compile_output=$(cd $pgo_workspace && gcc $flags -fprofile-use -Wno-coverage-mismatch -Wall -o ${pgo_base} "$src_path" -lm 2>&1)
                                                            if echo "$compile_output" | grep -q "missing-profile"; then
                                                                echo "ERROR: PGO profile data not found. PGO is not working correctly."
                                                                exit 1
                                                            fi
                                                        fi
                                                        compile2_end=$(date +%s.%N)
                                                        compile2_time=$(echo "scale=3; $compile2_end - $compile2_start" | bc -l)
                                                        
                                                        total_compile_time=$(echo "scale=3; $compile1_time + $profile_time + $compile2_time" | bc -l)
                                                        
                                                        if [ $? -eq 0 ] && [ -x "$pgo_workspace/${pgo_base}" ]; then
                                                            result=$(cd $pgo_workspace && ./${pgo_base} $size 2>/dev/null)
                                                            run_gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                                            run_time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                                            
                                                            if [ ! -z "$run_gflops" ] && [ "$run_gflops" != "0" ]; then
                                                                gflops_runs+=("$run_gflops")
                                                                time_runs+=("$run_time")
                                                                compile_time_runs+=("$total_compile_time")
                                                            elif [ "$verbose" = true ]; then
                                                                echo "PGO run failed: no valid performance result"
                                                            fi
                                                        elif [ "$verbose" = true ]; then
                                                            echo "PGO compilation failed: final binary not executable"
                                                        fi
                                                    elif [ "$verbose" = true ]; then
                                                        echo "Profile generation failed: no .gcda files found"
                                                    fi
                                                    rm -rf "$pgo_workspace" 2>/dev/null
                                                elif [ "$verbose" = true ]; then
                                                    echo "PGO profile generation binary compilation failed"
                                                    rm -rf "$pgo_workspace" 2>/dev/null
                                                fi
                                            else
                                                # Standard compilation
                                                compile_start=$(date +%s.%N)
                                                if [ "$verbose" = true ]; then
                                                    echo "gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm"
                                                    gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm
                                                else
                                                    gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                                                fi
                                                compile_end=$(date +%s.%N)
                                                run_compile_time=$(echo "scale=3; $compile_end - $compile_start" | bc -l)
                                                
                                                if [ $? -eq 0 ]; then
                                                    result=$(./$exe_name $size 2>/dev/null)
                                                    run_gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                                    run_time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                                    
                                                    if [ ! -z "$run_gflops" ]; then
                                                        gflops_runs+=("$run_gflops")
                                                        time_runs+=("$run_time")
                                                        compile_time_runs+=("$run_compile_time")
                                                    fi
                                                    rm -f $exe_name 2>/dev/null
                                                fi
                                            fi
                                        done
                                        
                                        # Calculate trimmed means
                                        if [ ${#gflops_runs[@]} -gt 0 ]; then
                                            avg_gflops=$(calculate_trimmed_mean "${gflops_runs[@]}")
                                            avg_time=$(calculate_trimmed_mean "${time_runs[@]}")
                                            avg_compile_time=$(calculate_trimmed_mean "${compile_time_runs[@]}")
                                            
                                            sort_key=$(printf "%010.4f" "$avg_gflops")
                                            runs_detail=$(printf "%s," "${gflops_runs[@]}")
                                            runs_detail=${runs_detail%,}
                                            
                                            # Use unique filename with timestamp to prevent race conditions
                                            result_file="/tmp/combo_results_$$/$(date +%s%N)_${combo_id}"
                                            if [ $pgo -eq 1 ]; then
                                                echo "$sort_key|$avg_gflops|$avg_time|$avg_compile_time|$opt|$march_desc|$mtune_desc|$extra_desc+PGO|$size|[$runs_detail]" > "$result_file"
                                            else
                                                echo "$sort_key|$avg_gflops|$avg_time|$avg_compile_time|$opt|$march_desc|$mtune_desc|$extra_desc|$size|[$runs_detail]" > "$result_file"
                                            fi
                                        fi
                                        
                                        echo "Complete" > "$STATUS_DIR/$combo_id"
                                    ) &
                                done
                            done
                        done
                    else
                        # Standard flags only
                        flags="-$opt"
                        
                        case $march in
                            "native") flags="$flags -march=native" ;;
                            "neoverse") flags="$flags -march=$MARCH_SPECIFIC" ;;
                        esac
                        
                        case $mtune in
                            "native") flags="$flags -mtune=native" ;;
                            "neoverse") flags="$flags -mtune=$MTUNE_SPECIFIC" ;;
                        esac
                        
                        march_desc="$march"
                        mtune_desc="$mtune"
                        
                        wait_for_slot
                        
                        # Run test in background
                        (
                            if [ $pgo -eq 1 ]; then
                                combo_id="${opt}_${march}_${mtune}_${pgo}_${size}"
                            else
                                combo_id="${opt}_${march}_${mtune}_${size}"
                            fi
                            echo "Running" > "$STATUS_DIR/$combo_id"
                            
                            # Arrays to store multiple run results
                            gflops_runs=()
                            time_runs=()
                            compile_time_runs=()
                            
                            # Run multiple times
                            for ((run=1; run<=num_runs; run++)); do
                                echo "Running ($run/$num_runs)" > "$STATUS_DIR/$combo_id"
                                
                                exe_name="temp/combo_${opt}_${march}_${mtune}_${pgo}_${size}_$$_${RANDOM}_${run}"
                                
                                if [ $pgo -eq 1 ]; then
                                    # PGO compilation - use unique workspace per job
                                    compile1_start=$(date +%s.%N)
                                    pgo_workspace="temp/pgo_workspace_$$_${combo_id}_${run}"
                                    mkdir -p "$pgo_workspace"
                                    pgo_base="pgo_${combo_id}_${run}"
                                    
                                    if [ "$verbose" = true ]; then
                                        echo "gcc $flags -fprofile-generate -Wall -o $pgo_workspace/${pgo_base}_gen src/optimized_matrix.c -lm"
                                        gcc $flags -fprofile-generate -Wall -o $pgo_workspace/${pgo_base}_gen src/optimized_matrix.c -lm
                                    else
                                        gcc $flags -fprofile-generate -Wall -o $pgo_workspace/${pgo_base}_gen src/optimized_matrix.c -lm 2>/dev/null
                                    fi
                                    compile1_end=$(date +%s.%N)
                                    compile1_time=$(echo "scale=3; $compile1_end - $compile1_start" | bc -l)
                                    
                                    if [ $? -eq 0 ] && [ -x "$pgo_workspace/${pgo_base}_gen" ]; then
                                        # Run profile generation in isolated workspace
                                        profile_start=$(date +%s.%N)
                                        if [ "$verbose" = true ]; then
                                            echo "cd $pgo_workspace && ./${pgo_base}_gen $size"
                                            (cd $pgo_workspace && ./${pgo_base}_gen $size >/dev/null)
                                        else
                                            (cd $pgo_workspace && ./${pgo_base}_gen $size >/dev/null 2>&1)
                                        fi
                                        profile_end=$(date +%s.%N)
                                        profile_time=$(echo "scale=3; $profile_end - $profile_start" | bc -l)
                                        
                                        # Check if profile data was generated (look for any .gcda files)
                                        if [ $? -eq 0 ] && [ -n "$(find $pgo_workspace -name "*.gcda" 2>/dev/null)" ]; then
                                            # Copy profile data to expected name for compilation
                                            for gcda_file in $pgo_workspace/*.gcda; do
                                                if [ -f "$gcda_file" ]; then
                                                    cp "$gcda_file" "$pgo_workspace/${pgo_base}-optimized_matrix.gcda"
                                                    break
                                                fi
                                            done
                                            
                                            # Compile with profile data in workspace
                                            compile2_start=$(date +%s.%N)
                                            src_path="$(pwd)/src/optimized_matrix.c"
                                            if [ "$verbose" = true ]; then
                                                echo "cd $pgo_workspace && gcc $flags -fprofile-use -Wno-coverage-mismatch -Wall -o ${pgo_base} $src_path -lm"
                                                compile_output=$(cd $pgo_workspace && gcc $flags -fprofile-use -Wno-coverage-mismatch -Wall -o ${pgo_base} "$src_path" -lm 2>&1)
                                                echo "$compile_output"
                                                if echo "$compile_output" | grep -q "missing-profile"; then
                                                    echo "ERROR: PGO profile data not found despite .gcda files existing. PGO is not working correctly."
                                                    exit 1
                                                fi
                                            else
                                                compile_output=$(cd $pgo_workspace && gcc $flags -fprofile-use -Wno-coverage-mismatch -Wall -o ${pgo_base} "$src_path" -lm 2>&1)
                                                if echo "$compile_output" | grep -q "missing-profile"; then
                                                    echo "ERROR: PGO profile data not found. PGO is not working correctly."
                                                    exit 1
                                                fi
                                            fi
                                            compile2_end=$(date +%s.%N)
                                            compile2_time=$(echo "scale=3; $compile2_end - $compile2_start" | bc -l)
                                            
                                            total_compile_time=$(echo "scale=3; $compile1_time + $profile_time + $compile2_time" | bc -l)
                                            
                                            if [ $? -eq 0 ] && [ -x "$pgo_workspace/${pgo_base}" ]; then
                                                result=$(cd $pgo_workspace && ./${pgo_base} $size 2>/dev/null)
                                                run_gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                                run_time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                                
                                                if [ ! -z "$run_gflops" ] && [ "$run_gflops" != "0" ]; then
                                                    gflops_runs+=("$run_gflops")
                                                    time_runs+=("$run_time")
                                                    compile_time_runs+=("$total_compile_time")
                                                elif [ "$verbose" = true ]; then
                                                    echo "PGO run failed: no valid performance result"
                                                fi
                                            elif [ "$verbose" = true ]; then
                                                echo "PGO compilation failed: final binary not executable"
                                            fi
                                        elif [ "$verbose" = true ]; then
                                            echo "Profile generation failed: no .gcda files found"
                                        fi
                                        rm -rf "$pgo_workspace" 2>/dev/null
                                    elif [ "$verbose" = true ]; then
                                        echo "PGO profile generation binary compilation failed"
                                        rm -rf "$pgo_workspace" 2>/dev/null
                                    fi
                                else
                                    # Standard compilation
                                    compile_start=$(date +%s.%N)
                                    if [ "$verbose" = true ]; then
                                        echo "gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm"
                                        gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm
                                    else
                                        gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                                    fi
                                    compile_end=$(date +%s.%N)
                                    run_compile_time=$(echo "scale=3; $compile_end - $compile_start" | bc -l)
                                    
                                    if [ $? -eq 0 ]; then
                                        result=$(./$exe_name $size 2>/dev/null)
                                        run_gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                        run_time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                        
                                        if [ ! -z "$run_gflops" ]; then
                                            gflops_runs+=("$run_gflops")
                                            time_runs+=("$run_time")
                                            compile_time_runs+=("$run_compile_time")
                                        fi
                                        rm -f $exe_name 2>/dev/null
                                    fi
                                fi
                            done
                            
                            # Calculate trimmed means
                            if [ ${#gflops_runs[@]} -gt 0 ]; then
                                avg_gflops=$(calculate_trimmed_mean "${gflops_runs[@]}")
                                avg_time=$(calculate_trimmed_mean "${time_runs[@]}")
                                avg_compile_time=$(calculate_trimmed_mean "${compile_time_runs[@]}")
                                
                                sort_key=$(printf "%010.4f" "$avg_gflops")
                                runs_detail=$(printf "%s," "${gflops_runs[@]}")
                                runs_detail=${runs_detail%,}
                                
                                # Use unique filename with timestamp to prevent race conditions
                                result_file="/tmp/combo_results_$$/$(date +%s%N)_${combo_id}"
                                if [ $pgo -eq 1 ]; then
                                    echo "$sort_key|$avg_gflops|$avg_time|$avg_compile_time|$opt|$march_desc|$mtune_desc|PGO|$size|[$runs_detail]" > "$result_file"
                                else
                                    echo "$sort_key|$avg_gflops|$avg_time|$avg_compile_time|$opt|$march_desc|$mtune_desc||$size|[$runs_detail]" > "$result_file"
                                fi
                            fi
                            
                            echo "Complete" > "$STATUS_DIR/$combo_id"
                        ) &
                    fi
                done
            done
        done
    done
done

# Wait for all jobs to complete
wait
kill $MONITOR_PID 2>/dev/null
wait $MONITOR_PID 2>/dev/null
sleep 1
rm -rf "$STATUS_DIR"
printf "\033[2J\033[H"

# Collect results
for result_file in /tmp/combo_results_$$/*; do
    if [ -f "$result_file" ]; then
        result_line=$(cat "$result_file")
        all_results+=("$result_line")
    fi
done

# Cleanup
rm -rf /tmp/combo_results_$$

# Sort results by performance (descending) and display grouped by matrix size
echo "=== Performance Results (Grouped by Matrix Size) ==="
echo

IFS=$'\n' sorted=($(printf '%s\n' "${all_results[@]}" | sort -t'|' -k1,1nr))

# Group by matrix size
for target_size in "${sizes[@]}"; do
    echo "### ${target_size^} Matrix ($(case $target_size in micro) echo "64x64";; small) echo "512x512";; medium) echo "1024x1024";; esac))"
    echo
    if [ "$use_extra_flags" = true ]; then
        printf "| %-5s | %-8s | %-6s | %-10s | %-4s | %-15s | %-15s | %-20s | %-3s | %-15s |\n" "Rank" "GFLOPS" "Run" "Compile" "Opt" "-march" "-mtune" "Extra Flags" "PGO" "Individual Runs"
        printf "|       |          | %-6s | %-10s |      |                 |                 |                      |     |                 |\n" "Time" "Time"
        printf "|-------|----------|--------|------------|------|-----------------|-----------------|----------------------|-----|-----------------|\n"
    else
        printf "| %-5s | %-8s | %-6s | %-10s | %-4s | %-15s | %-15s | %-3s | %-15s |\n" "Rank" "GFLOPS" "Run" "Compile" "Opt" "-march" "-mtune" "PGO" "Individual Runs"
        printf "|       |          | %-6s | %-10s |      |                 |                |     |                 |\n" "Time" "Time"
        printf "|-------|----------|--------|------------|------|-----------------|----------------|-----|-----------------|\n"
    fi
    
    rank=1
    best_gflops_for_size=""
    best_opt_for_size=""
    best_march_for_size=""
    best_mtune_for_size=""
    best_extra_for_size=""
    worst_gflops_for_size=""
    worst_opt_for_size=""
    worst_march_for_size=""
    worst_mtune_for_size=""
    worst_extra_for_size=""
    autodetect_gflops_for_size=""
    
    # First, display baseline (-O0/None/None/F) as rank -1
    for result in "${sorted[@]}"; do
        IFS='|' read -r sort_key gflops time compile_time opt march mtune extra_flags size runs_detail <<< "$result"
        
        if [ "$size" = "$target_size" ] && [ "$opt" = "O0" ] && [ "$march" = "none" ] && [ "$mtune" = "none" ] && [ "$extra_flags" = "" ]; then
            if [ "$use_extra_flags" = true ]; then
                printf "| %-5s | %-8s | %-6s | %-10s | %-4s | %-15s | %-15s | %-20s | %-3s | %-15s |\n" "-1" "$gflops" "$time" "$compile_time" "-$opt" "None" "None" "None" "F" "$runs_detail"
            else
                printf "| %-5s | %-8s | %-6s | %-10s | %-4s | %-15s | %-15s | %-3s | %-15s |\n" "-1" "$gflops" "$time" "$compile_time" "-$opt" "None" "None" "F" "$runs_detail"
            fi
            break
        fi
    done
    
    for result in "${sorted[@]}"; do
        IFS='|' read -r sort_key gflops time compile_time opt march mtune extra_flags size runs_detail <<< "$result"
        
        if [ "$size" = "$target_size" ]; then
            # Skip baseline entry (already displayed as rank -1)
            if [ "$opt" = "O0" ] && [ "$march" = "none" ] && [ "$mtune" = "none" ] && [ "$extra_flags" = "" ]; then
                continue
            fi
            
            # Track best performance for this size
            if [ -z "$best_gflops_for_size" ]; then
                best_gflops_for_size="$gflops"
                best_opt_for_size="$opt"
                best_march_for_size="$march"
                best_mtune_for_size="$mtune"
                best_extra_for_size="$extra_flags"
            fi
            
            # Track worst performance for this size (last non-O0 result)
            if [ "$opt" != "O0" ]; then
                worst_gflops_for_size="$gflops"
                worst_opt_for_size="$opt"
                worst_march_for_size="$march"
                worst_mtune_for_size="$mtune"
                worst_extra_for_size="$extra_flags"
            fi
            
            # Track best Autodetect performance for this size (both march and mtune native)
            if [ "$march" = "native" ] && [ "$mtune" = "native" ]; then
                if [ -z "$autodetect_gflops_for_size" ] || (( $(echo "$gflops > $autodetect_gflops_for_size" | bc -l) )); then
                    autodetect_gflops_for_size="$gflops"
                fi
            fi
            
            # Convert march/mtune to display names
            case $march in
                "none") march_flag="None" ;;
                "native") march_flag="native" ;;
                "neoverse") march_flag="V2" ;;
            esac
            
            case $mtune in
                "none") mtune_flag="None" ;;
                "native") mtune_flag="native" ;;
                "neoverse") mtune_flag="V2" ;;
            esac
            
            # Detect PGO usage
            pgo_display="F"
            if [[ "$extra_flags" == *"PGO"* ]]; then
                pgo_display="T"
            fi
            
            # Format extra flags for display
            if [ "$use_extra_flags" = true ]; then
                extra_display=""
                if [[ "$extra_flags" == *"flto"* ]]; then extra_display="${extra_display}lto,"; fi
                if [[ "$extra_flags" == *"fomit-frame-pointer"* ]]; then extra_display="${extra_display}omit-fp,"; fi
                if [[ "$extra_flags" == *"funroll-loops"* ]]; then extra_display="${extra_display}unroll,"; fi
                extra_display=${extra_display%,}  # Remove trailing comma
                [ -z "$extra_display" ] && extra_display="None"
                
                printf "| %-5d | %-8s | %-6s | %-10s | %-4s | %-15s | %-15s | %-20s | %-3s | %-15s |\n" "$rank" "$gflops" "$time" "$compile_time" "-$opt" "$march_flag" "$mtune_flag" "$extra_display" "$pgo_display" "$runs_detail"
            else
                printf "| %-5d | %-8s | %-6s | %-10s | %-4s | %-15s | %-15s | %-3s | %-15s |\n" "$rank" "$gflops" "$time" "$compile_time" "-$opt" "$march_flag" "$mtune_flag" "$pgo_display" "$runs_detail"
            fi
            ((rank++))
        fi
    done
    
    # Store data for consolidated insights
    eval "${target_size}_best_gflops=\"$best_gflops_for_size\""
    eval "${target_size}_best_opt=\"$best_opt_for_size\""
    eval "${target_size}_best_march=\"$best_march_for_size\""
    eval "${target_size}_best_mtune=\"$best_mtune_for_size\""
    eval "${target_size}_best_extra=\"$best_extra_for_size\""
    eval "${target_size}_worst_gflops=\"$worst_gflops_for_size\""
    eval "${target_size}_worst_opt=\"$worst_opt_for_size\""
    eval "${target_size}_worst_march=\"$worst_march_for_size\""
    eval "${target_size}_worst_mtune=\"$worst_mtune_for_size\""
    eval "${target_size}_worst_extra=\"$worst_extra_for_size\""
    eval "${target_size}_autodetect_gflops=\"$autodetect_gflops_for_size\""
    
    echo
done

echo "=== Key Insights ==="

# Get baseline performance from O0 results in our test data
if [ "$use_arch_flags" = true ]; then
    # When arch flags are enabled, look for O0|native|native
    baseline_pattern="|O0|native|native|"
else
    # When arch flags are disabled, look for O0|none|none
    baseline_pattern="|O0|none|none|"
fi

if [ "$use_extra_flags" = true ]; then
    baseline_micro=$(printf '%s\n' "${sorted[@]}" | grep "${baseline_pattern}|micro|" | head -1 | cut -d'|' -f2)
    baseline_small=$(printf '%s\n' "${sorted[@]}" | grep "${baseline_pattern}|small|" | head -1 | cut -d'|' -f2)
    baseline_medium=$(printf '%s\n' "${sorted[@]}" | grep "${baseline_pattern}|medium|" | head -1 | cut -d'|' -f2)
else
    baseline_micro=$(printf '%s\n' "${sorted[@]}" | grep "${baseline_pattern}|micro|" | head -1 | cut -d'|' -f2)
    baseline_small=$(printf '%s\n' "${sorted[@]}" | grep "${baseline_pattern}|small|" | head -1 | cut -d'|' -f2)
    baseline_medium=$(printf '%s\n' "${sorted[@]}" | grep "${baseline_pattern}|medium|" | head -1 | cut -d'|' -f2)
fi

# Function to convert arch names to readable format
get_arch_name() {
    case $1 in
        "none") echo "None" ;;
        "native") echo "native" ;;
        "neoverse") echo "V2" ;;
        *) echo "$1" ;;
    esac
}

for size in "${sizes[@]}"; do
    case $size in
        "micro") baseline=$baseline_micro; size_desc="64x64" ;;
        "small") baseline=$baseline_small; size_desc="512x512" ;;
        "medium") baseline=$baseline_medium; size_desc="1024x1024" ;;
    esac
    
    # Get stored values
    eval "best_gflops=\$${size}_best_gflops"
    eval "best_opt=\$${size}_best_opt"
    eval "best_march=\$${size}_best_march"
    eval "best_mtune=\$${size}_best_mtune"
    eval "best_extra=\$${size}_best_extra"
    eval "worst_gflops=\$${size}_worst_gflops"
    eval "worst_opt=\$${size}_worst_opt"
    eval "worst_march=\$${size}_worst_march"
    eval "worst_mtune=\$${size}_worst_mtune"
    eval "worst_extra=\$${size}_worst_extra"
    
    if [ ! -z "$best_gflops" ] && [ "$best_gflops" != "" ] && [ ! -z "$baseline" ] && [ "$baseline" != "" ]; then
        echo
        echo "**${size^} Matrix ($size_desc) Performance:**"
        
        # Best performance
        if [ ! -z "$baseline" ] && [ "$baseline" != "0" ] && [ "$baseline" != "" ]; then
            best_speedup=$(echo "scale=1; ($best_gflops - $baseline) / $baseline * 100" | bc -l 2>/dev/null || echo "0")
        else
            best_speedup="0"
        fi
        best_march_name=$(get_arch_name "$best_march")
        best_mtune_name=$(get_arch_name "$best_mtune")
        best_extra_display=$([ -z "$best_extra" ] && echo "None" || echo "$best_extra")
        
        # Format best performance message
        if (( $(echo "$best_speedup < 0" | bc -l 2>/dev/null) )); then
            best_speedup_abs=${best_speedup#-}
            best_msg="-- Best: ${best_speedup_abs}% performance **hit** over baseline using -$best_opt, -march $best_march_name, -mtune $best_mtune_name, extra flags $best_extra_display"
        else
            best_msg="-- Best: ${best_speedup}% performance **gain** over baseline using -$best_opt, -march $best_march_name, -mtune $best_mtune_name, extra flags $best_extra_display"
        fi
        echo "$best_msg"
        
        # Worst performance (if different from best)
        if [ ! -z "$worst_gflops" ] && [ "$worst_gflops" != "$best_gflops" ] && [ "$worst_gflops" != "" ]; then
            if [ ! -z "$baseline" ] && [ "$baseline" != "0" ] && [ "$baseline" != "" ]; then
                worst_speedup=$(echo "scale=1; ($worst_gflops - $baseline) / $baseline * 100" | bc -l 2>/dev/null || echo "0")
            else
                worst_speedup="0"
            fi
            worst_march_name=$(get_arch_name "$worst_march")
            worst_mtune_name=$(get_arch_name "$worst_mtune")
            worst_extra_display=$([ -z "$worst_extra" ] && echo "None" || echo "$worst_extra")
            
            # Format worst performance message
            if (( $(echo "$worst_speedup < 0" | bc -l 2>/dev/null) )); then
                worst_speedup_abs=${worst_speedup#-}
                worst_msg="-- Worst: ${worst_speedup_abs}% performance **hit** over baseline using -$worst_opt, -march $worst_march_name, -mtune $worst_mtune_name, extra flags $worst_extra_display"
            else
                worst_msg="-- Worst: ${worst_speedup}% performance **gain** over baseline using -$worst_opt, -march $worst_march_name, -mtune $worst_mtune_name, extra flags $worst_extra_display"
            fi
            echo "$worst_msg"
        fi
    fi
done

echo
echo "Complete results saved to results/comprehensive/ directory"
