#!/bin/bash
# test-all-combinations.sh - Test all combinations with consolidated logic for all matrix sizes

# Check for help flags
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --runs N         Number of runs per combination for accuracy (1-7, default: 1)"
    echo "  --sizes S        Matrix sizes to test (1,2,3 combinations, default: 1,2)"
    echo "                   1=micro (64x64), 2=small (512x512), 3=medium (1024x1024)"
    echo "  --extra-flags    Include extra optimization flags (default: disabled)"
    echo "                   Adds -flto, -fomit-frame-pointer, -funroll-loops"
    echo "  --pgo            Use profile-guided optimization (default: disabled)"
    echo "                   Adds -fprofile-generate and -fprofile-use"
    echo "  -h, --help       Show this help message"
    echo
    echo "Examples:"
    echo "  $0                                    # Default: 1 run, micro+small, no extra flags"
    echo "  $0 --runs 3 --sizes 1,2,3 --extra-flags --pgo"
    echo "  $0 --runs 5 --sizes 1                # 5 runs, micro only"
    echo "  $0 --sizes 2,3 --extra-flags         # Small+medium with extra flags"
    exit 0
fi

echo "=== Comprehensive Compiler Optimization Analysis ==="
echo

# Clean previous results
rm -rf results/comprehensive/*
rm -rf temp/*

# Default values
num_runs=1
matrix_sizes_arg="1,2"
use_extra_flags=false
use_pgo=false

# Parse named arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --runs)
            num_runs="$2"
            shift 2
            ;;
        --sizes)
            matrix_sizes_arg="$2"
            shift 2
            ;;
        --extra-flags)
            use_extra_flags=true
            shift
            ;;
        --pgo)
            use_pgo=true
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

if [ "$num_runs" -gt 1 ]; then
    echo "Running each combination $num_runs times (using trimmed mean to remove outliers)"
else
    echo "Running each combination once (single run)"
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

echo "Testing sizes: ${sizes[*]}"

# Set extra optimization flags
if [ "$use_extra_flags" = true ]; then
    extra_flags=("flto" "fomit-frame-pointer" "funroll-loops")
    echo "Including additional optimization flags (8x more combinations: 2^3 flag combinations)"
else
    extra_flags=()
    echo "Using standard optimization flags only"
fi

# Set profile-guided optimization
if [ "$use_pgo" = true ]; then
    echo "Including profile-guided optimization (2x more combinations: with/without PGO)"
else
    echo "Using standard compilation only"
fi
echo

# Function to calculate trimmed mean (removes outliers)
calculate_trimmed_mean() {
    local values=("$@")
    local count=${#values[@]}
    
    if [ $count -eq 1 ]; then
        echo "${values[0]}"
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
    
    echo "scale=3; $sum / $used_count" | bc -l
}

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
echo "Testing all combinations of optimization levels, architecture flags, and matrix sizes..."
echo

# Create temp directories
STATUS_DIR="/tmp/benchmark_status_$$"
mkdir -p "$STATUS_DIR"

# Define test parameters
opt_levels=("O0" "O1" "O2" "O3")
march_options=("none" "native" "neoverse")
mtune_options=("none" "native" "neoverse")

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
        
        for size in "${sizes[@]}"; do
            size_pending=$(find "$STATUS_DIR" -name "*_${size}" -exec grep -l "Pending" {} \; 2>/dev/null | wc -l)
            size_running=$(find "$STATUS_DIR" -name "*_${size}" -exec grep -l "Running" {} \; 2>/dev/null | wc -l)
            size_complete=$(find "$STATUS_DIR" -name "*_${size}" -exec grep -l "Complete" {} \; 2>/dev/null | wc -l)
            
            current_run=""
            if [ $size_running -gt 0 ]; then
                running_status=$(find "$STATUS_DIR" -name "*_${size}" -exec grep "Running" {} \; 2>/dev/null | head -1)
                if [[ "$running_status" =~ Running\ \(([0-9]+)/[0-9]+\) ]]; then
                    current_run="${BASH_REMATCH[1]}"
                else
                    current_run="1"
                fi
            fi
            
            if [ -n "$current_run" ]; then
                echo "${size} matrix compile runs run#/pending/running/complete ${current_run}/${size_pending}/${size_running}/${size_complete}"
            else
                echo "${size} matrix compile runs pending/running/complete ${size_pending}/${size_running}/${size_complete}"
            fi
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

# Calculate max parallel jobs (ncpu - 2)
MAX_JOBS=$(($(nproc) - 2))
if [ $MAX_JOBS -lt 1 ]; then
    MAX_JOBS=1
fi

echo "Running tests with maximum $MAX_JOBS parallel jobs..."
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
                                                # PGO compilation
                                                compile1_start=$(date +%s.%N)
                                                gcc $flags -fprofile-generate -Wall -o ${exe_name}_gen src/optimized_matrix.c -lm 2>/dev/null
                                                compile1_end=$(date +%s.%N)
                                                compile1_time=$(echo "scale=3; $compile1_end - $compile1_start" | bc -l)
                                                
                                                if [ $? -eq 0 ]; then
                                                    profile_start=$(date +%s.%N)
                                                    ./${exe_name}_gen $size >/dev/null 2>&1
                                                    profile_end=$(date +%s.%N)
                                                    profile_time=$(echo "scale=3; $profile_end - $profile_start" | bc -l)
                                                    
                                                    compile2_start=$(date +%s.%N)
                                                    gcc $flags -fprofile-use -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                                                    compile2_end=$(date +%s.%N)
                                                    compile2_time=$(echo "scale=3; $compile2_end - $compile2_start" | bc -l)
                                                    
                                                    total_compile_time=$(echo "scale=3; $compile1_time + $profile_time + $compile2_time" | bc -l)
                                                    
                                                    if [ $? -eq 0 ]; then
                                                        result=$(./$exe_name $size 2>/dev/null)
                                                        run_gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                                        run_time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                                        
                                                        if [ ! -z "$run_gflops" ]; then
                                                            gflops_runs+=("$run_gflops")
                                                            time_runs+=("$run_time")
                                                            compile_time_runs+=("$total_compile_time")
                                                        fi
                                                    fi
                                                    rm -f $exe_name ${exe_name}_gen *.gcda 2>/dev/null
                                                fi
                                            else
                                                # Standard compilation
                                                compile_start=$(date +%s.%N)
                                                gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
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
                                            
                                            sort_key=$(printf "%08.2f" $(echo "$avg_gflops * 100" | bc -l) | tr '.' '_')
                                            runs_detail=$(printf "%s," "${gflops_runs[@]}")
                                            runs_detail=${runs_detail%,}
                                            
                                            if [ $pgo -eq 1 ]; then
                                                echo "$sort_key|$avg_gflops|$avg_time|$avg_compile_time|$opt|$march_desc|$mtune_desc|$extra_desc+PGO|$size|[$runs_detail]" > /tmp/combo_results_$$/${combo_id} 2>/dev/null
                                            else
                                                echo "$sort_key|$avg_gflops|$avg_time|$avg_compile_time|$opt|$march_desc|$mtune_desc|$extra_desc|$size|[$runs_detail]" > /tmp/combo_results_$$/${combo_id} 2>/dev/null
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
                                    # PGO compilation
                                    compile1_start=$(date +%s.%N)
                                    gcc $flags -fprofile-generate -Wall -o ${exe_name}_gen src/optimized_matrix.c -lm 2>/dev/null
                                    compile1_end=$(date +%s.%N)
                                    compile1_time=$(echo "scale=3; $compile1_end - $compile1_start" | bc -l)
                                    
                                    if [ $? -eq 0 ]; then
                                        profile_start=$(date +%s.%N)
                                        ./${exe_name}_gen $size >/dev/null 2>&1
                                        profile_end=$(date +%s.%N)
                                        profile_time=$(echo "scale=3; $profile_end - $profile_start" | bc -l)
                                        
                                        compile2_start=$(date +%s.%N)
                                        gcc $flags -fprofile-use -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                                        compile2_end=$(date +%s.%N)
                                        compile2_time=$(echo "scale=3; $compile2_end - $compile2_start" | bc -l)
                                        
                                        total_compile_time=$(echo "scale=3; $compile1_time + $profile_time + $compile2_time" | bc -l)
                                        
                                        if [ $? -eq 0 ]; then
                                            result=$(./$exe_name $size 2>/dev/null)
                                            run_gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                            run_time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                            
                                            if [ ! -z "$run_gflops" ]; then
                                                gflops_runs+=("$run_gflops")
                                                time_runs+=("$run_time")
                                                compile_time_runs+=("$total_compile_time")
                                            fi
                                        fi
                                        rm -f $exe_name ${exe_name}_gen *.gcda 2>/dev/null
                                    fi
                                else
                                    # Standard compilation
                                    compile_start=$(date +%s.%N)
                                    gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
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
                                
                                sort_key=$(printf "%08.2f" $(echo "$avg_gflops * 100" | bc -l) | tr '.' '_')
                                runs_detail=$(printf "%s," "${gflops_runs[@]}")
                                runs_detail=${runs_detail%,}
                                
                                if [ $pgo -eq 1 ]; then
                                    echo "$sort_key|$avg_gflops|$avg_time|$avg_compile_time|$opt|$march_desc|$mtune_desc|PGO|$size|[$runs_detail]" > /tmp/combo_results_$$/${combo_id} 2>/dev/null
                                else
                                    echo "$sort_key|$avg_gflops|$avg_time|$avg_compile_time|$opt|$march_desc|$mtune_desc||$size|[$runs_detail]" > /tmp/combo_results_$$/${combo_id} 2>/dev/null
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
        printf "| %-5s | %-8s | %-8s | %-15s | %-4s | %-15s | %-15s | %-20s | %-3s | %-15s |\n" "Rank" "GFLOPS" "GFLOP/s" "Time (seconds)" "Opt" "-march" "-mtune" "Extra Flags" "PGO" "Individual Runs"
        printf "|       |          |          | %-6s | %-7s |      |                 |                  |                      |     |                 |\n" "Run" "Compile"
        printf "|-------|----------|----------|--------|---------|------|-----------------|------------------|----------------------|-----|-----------------|\n"
    else
        printf "| %-5s | %-8s | %-8s | %-15s | %-4s | %-15s | %-15s | %-3s | %-15s |\n" "Rank" "GFLOPS" "GFLOP/s" "Time (seconds)" "Opt" "-march" "-mtune" "PGO" "Individual Runs"
        printf "|       |          |          | %-6s | %-7s |      |                 |                  |     |                 |\n" "Run" "Compile"
        printf "|-------|----------|----------|--------|---------|------|-----------------|------------------|-----|-----------------|\n"
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
            if [ -z "$time" ] || [ "$time" = "0" ]; then
                gflop_per_s="∞"
            else
                gflop_per_s=$(echo "scale=2; $gflops / $time" | bc -l 2>/dev/null || echo "∞")
            fi
            
            if [ "$use_extra_flags" = true ]; then
                printf "| %-5s | %-8s | %-8s | %-6s | %-7s | %-4s | %-15s | %-15s | %-20s | %-3s | %-15s |\n" "-1" "$gflops" "$gflop_per_s" "$time" "$compile_time" "-$opt" "None" "None" "None" "F" "$runs_detail"
            else
                printf "| %-5s | %-8s | %-8s | %-6s | %-7s | %-4s | %-15s | %-15s | %-3s | %-15s |\n" "-1" "$gflops" "$gflop_per_s" "$time" "$compile_time" "-$opt" "None" "None" "F" "$runs_detail"
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
            
            # Calculate GFLOP/s (GFLOPS per second, which is just GFLOPS/time)
            if [ "$time" = "0.000" ] || [ "$time" = "0" ] || [ -z "$time" ]; then
                gflop_per_s="∞"
            else
                gflop_per_s=$(echo "scale=2; $gflops / $time" | bc -l 2>/dev/null || echo "∞")
                if [ -z "$gflop_per_s" ]; then
                    gflop_per_s="∞"
                fi
            fi
            
            # Convert march/mtune to display names
            case $march in
                "none") march_flag="None" ;;
                "native") march_flag="Autodetect" ;;
                "neoverse") march_flag="V2" ;;
            esac
            
            case $mtune in
                "none") mtune_flag="None" ;;
                "native") mtune_flag="Autodetect" ;;
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
                
                printf "| %-5d | %-8s | %-8s | %-6s | %-7s | %-4s | %-15s | %-15s | %-20s | %-3s | %-15s |\n" "$rank" "$gflops" "$gflop_per_s" "$time" "$compile_time" "-$opt" "$march_flag" "$mtune_flag" "$extra_display" "$pgo_display" "$runs_detail"
            else
                printf "| %-5d | %-8s | %-8s | %-6s | %-7s | %-4s | %-15s | %-15s | %-3s | %-15s |\n" "$rank" "$gflops" "$gflop_per_s" "$time" "$compile_time" "-$opt" "$march_flag" "$mtune_flag" "$pgo_display" "$runs_detail"
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

# Get baseline performance from O0/native/native results in our test data
if [ "$use_extra_flags" = true ]; then
    baseline_micro=$(printf '%s\n' "${sorted[@]}" | grep "|O0|native|native||micro|" | head -1 | cut -d'|' -f2)
    baseline_small=$(printf '%s\n' "${sorted[@]}" | grep "|O0|native|native||small|" | head -1 | cut -d'|' -f2)
    baseline_medium=$(printf '%s\n' "${sorted[@]}" | grep "|O0|native|native||medium|" | head -1 | cut -d'|' -f2)
else
    baseline_micro=$(printf '%s\n' "${sorted[@]}" | grep "|O0|native|native||micro|" | head -1 | cut -d'|' -f2)
    baseline_small=$(printf '%s\n' "${sorted[@]}" | grep "|O0|native|native||small|" | head -1 | cut -d'|' -f2)
    baseline_medium=$(printf '%s\n' "${sorted[@]}" | grep "|O0|native|native||medium|" | head -1 | cut -d'|' -f2)
fi

# Function to convert arch names to readable format
get_arch_name() {
    case $1 in
        "none") echo "None" ;;
        "native") echo "Autodetect" ;;
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
        best_speedup=$(echo "scale=1; ($best_gflops - $baseline) / $baseline * 100" | bc -l 2>/dev/null || echo "0")
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
            worst_speedup=$(echo "scale=1; ($worst_gflops - $baseline) / $baseline * 100" | bc -l 2>/dev/null || echo "0")
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
