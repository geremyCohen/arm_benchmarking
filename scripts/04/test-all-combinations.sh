#!/bin/bash
# test-all-combinations.sh - Test all combinations with real-time status using temp files
# Uses O0/None/None results as baseline for performance comparisons (no separate baseline script needed)

echo "=== Comprehensive Compiler Optimization Analysis ==="
echo

# Prompt for matrix sizes
echo -n "Test sizes: micro+small (default) or all including medium? [micro+small/all]: "
read size_choice
echo

if [[ "$size_choice" == "all" ]]; then
    sizes=("micro" "small" "medium")
    echo "Testing all sizes: micro, small, medium"
else
    sizes=("micro" "small")
    echo "Testing default sizes: micro, small (medium skipped for speed)"
fi

# Prompt for additional optimization flags
echo -n "Include additional optimization flags (-flto, -fomit-frame-pointer, -funroll-loops)? [y/N]: "
read extra_flags_choice
echo

if [ "$extra_flags_choice" = "y" ] || [ "$extra_flags_choice" = "Y" ]; then
    use_extra_flags=true
    extra_flags=("flto" "fomit-frame-pointer" "funroll-loops")
    echo "Including additional optimization flags (8x more combinations: 2^3 flag combinations)"
else
    use_extra_flags=false
    extra_flags=()
    echo "Using standard optimization flags only"
fi

# Prompt for profile-guided optimization
echo -n "Use -fprofile-generate and -fprofile-use? [y/N]: "
read pgo_choice
echo

if [ "$pgo_choice" = "y" ] || [ "$pgo_choice" = "Y" ]; then
    use_pgo=true
    echo "Including profile-guided optimization (2x more combinations: with/without PGO)"
else
    use_pgo=false
    echo "Using standard compilation only"
fi
echo

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

# Initialize status files
for opt in "${opt_levels[@]}"; do
    for march in "${march_options[@]}"; do
        for mtune in "${mtune_options[@]}"; do
            for pgo in $([ "$use_pgo" = true ] && echo "0 1" || echo "0"); do
                if [ "$use_extra_flags" = true ]; then
                    # Generate all combinations of extra flags (2^3 = 8 combinations)
                    for flto in 0 1; do
                        for fomit in 0 1; do
                            for funroll in 0 1; do
                                for size in "${sizes[@]}"; do
                                    if [ $pgo -eq 1 ]; then
                                        echo "Pending" > "$STATUS_DIR/${opt}_${march}_${mtune}_${pgo}_${flto}${fomit}${funroll}_${size}"
                                    else
                                        echo "Pending" > "$STATUS_DIR/${opt}_${march}_${mtune}_${flto}${fomit}${funroll}_${size}"
                                    fi
                                done
                            done
                        done
                    done
                else
                    for size in "${sizes[@]}"; do
                        if [ $pgo -eq 1 ]; then
                            echo "Pending" > "$STATUS_DIR/${opt}_${march}_${mtune}_${pgo}_${size}"
                        else
                            echo "Pending" > "$STATUS_DIR/${opt}_${march}_${mtune}_${size}"
                        fi
                    done
                fi
            done
        done
    done
done

# Start status monitor in background
(
    # Hide cursor and save position
    printf "\033[?25l\033[s"
    
    while [ -d "$STATUS_DIR" ]; do
        # Restore cursor position instead of clearing screen
        printf "\033[u"
        
        echo "=== Benchmark Status Dashboard ==="
        echo "Updated: $(date '+%H:%M:%S')"
        echo
        
        # Count status by matrix size (only micro and small for first monitor)
        for size in "micro" "small"; do
            if [[ " ${sizes[@]} " =~ " ${size} " ]]; then
                size_pending=$(grep -l "Pending" "$STATUS_DIR"/*_${size} 2>/dev/null | wc -l)
                size_running=$(grep -l "Running" "$STATUS_DIR"/*_${size} 2>/dev/null | wc -l)
                size_complete=$(grep -l "Complete" "$STATUS_DIR"/*_${size} 2>/dev/null | wc -l)
                
                echo "${size} matrix compile runs pending/running/complete ${size_pending}/${size_running}/${size_complete}"
            fi
        done
        echo
        
        # Exit if all tests are complete
        total=$(ls "$STATUS_DIR" 2>/dev/null | wc -l)
        complete=$(grep -l "Complete" "$STATUS_DIR"/* 2>/dev/null | wc -l)
        if [ $complete -eq $total ]; then
            break
        fi
        
        # Clear to end of screen to remove old content
        printf "\033[J"
        sleep 1
    done
    
    # Restore cursor
    printf "\033[?25h"
) &
MONITOR_PID=$!

# Create results directory
mkdir -p results/comprehensive
mkdir -p /tmp/combo_results_$$

# Calculate max parallel jobs (cores - 1, minimum 1)
MAX_JOBS=$(($(nproc) - 1))
if [ $MAX_JOBS -lt 1 ]; then
    MAX_JOBS=1
fi

echo "Running tests with maximum $MAX_JOBS parallel jobs..."
echo

# Function to wait for job slots
wait_for_slot() {
    while [ $(grep -l "Running" "$STATUS_DIR"/* 2>/dev/null | wc -l) -ge $MAX_JOBS ]; do
        sleep 0.1
    done
}

# Results array to store all combinations
declare -a all_results

# Test micro and small sizes first
for size in micro small; do
    if [[ " ${sizes[@]} " =~ " ${size} " ]]; then
        for opt in "${opt_levels[@]}"; do
            for march in "${march_options[@]}"; do
                for mtune in "${mtune_options[@]}"; do
                    for pgo in $([ "$use_pgo" = true ] && echo "0 1" || echo "0"); do
                        if [ "$use_extra_flags" = true ]; then
                        # Test all 16 combinations of extra flags (2^4)
                        for flto in 0 1; do
                            for fomit in 0 1; do
                                for funroll in 0 1; do
                                    # Build flags
                                    flags="-$opt"
                                        
                                        # Add march flag
                                        case $march in
                                            "native")
                                                flags="$flags -march=native"
                                                ;;
                                            "neoverse")
                                                flags="$flags -march=$MARCH_SPECIFIC"
                                                ;;
                                        esac
                                        
                                        # Add mtune flag
                                        case $mtune in
                                            "native")
                                                flags="$flags -mtune=native"
                                                ;;
                                            "neoverse")
                                                flags="$flags -mtune=$MTUNE_SPECIFIC"
                                                ;;
                                        esac
                                        
                                        # Add extra flags
                                        extra_desc=""
                                        [ $flto -eq 1 ] && flags="$flags -flto" && extra_desc="${extra_desc}flto,"
                                        [ $fomit -eq 1 ] && flags="$flags -fomit-frame-pointer" && extra_desc="${extra_desc}fomit-frame-pointer,"
                                        [ $funroll -eq 1 ] && flags="$flags -funroll-loops" && extra_desc="${extra_desc}funroll-loops,"
                                        extra_desc=${extra_desc%,}  # Remove trailing comma
                                        
                                        march_desc="$march"
                                        mtune_desc="$mtune"
                                        
                                        # Wait for available job slot
                                        wait_for_slot
                                        
                                        # Run test in background
                                        (
                                            if [ $pgo -eq 1 ]; then
                                                combo_id="${opt}_${march}_${mtune}_${pgo}_${flto}${fomit}${funroll}_${size}"
                                            else
                                                combo_id="${opt}_${march}_${mtune}_${flto}${fomit}${funroll}_${size}"
                                            fi
                                            echo "Running" > "$STATUS_DIR/$combo_id"
                                            
                                            # Add small delay to see state changes
                                            sleep 0.5
                                            
                                            exe_name="combo_${opt}_${march}_${mtune}_${pgo}_${flto}${fomit}${funroll}_${size}_$$_${RANDOM}"
                                            
                                            if [ $pgo -eq 1 ]; then
                                                # PGO compilation: generate -> run -> use
                                                # Step 1: Compile with -fprofile-generate
                                                compile1_start=$(date +%s.%N)
                                                gcc $flags -fprofile-generate -Wall -o ${exe_name}_gen src/optimized_matrix.c -lm 2>/dev/null
                                                compile1_end=$(date +%s.%N)
                                                compile1_time=$(echo "scale=3; $compile1_end - $compile1_start" | bc -l)
                                                
                                                if [ $? -eq 0 ]; then
                                                    # Step 2: Run to generate profile data
                                                    profile_start=$(date +%s.%N)
                                                    ./${exe_name}_gen $size >/dev/null 2>&1
                                                    profile_end=$(date +%s.%N)
                                                    profile_time=$(echo "scale=3; $profile_end - $profile_start" | bc -l)
                                                    
                                                    # Step 3: Compile with -fprofile-use
                                                    compile2_start=$(date +%s.%N)
                                                    gcc $flags -fprofile-use -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                                                    compile2_end=$(date +%s.%N)
                                                    compile2_time=$(echo "scale=3; $compile2_end - $compile2_start" | bc -l)
                                                    
                                                    total_compile_time=$(echo "scale=3; $compile1_time + $profile_time + $compile2_time" | bc -l)
                                                    
                                                    if [ $? -eq 0 ]; then
                                                        result=$(./$exe_name $size 2>/dev/null)
                                                        gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                                        time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                                        
                                                        if [ ! -z "$gflops" ]; then
                                                            sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                                                            echo "$sort_key|$gflops|$time|$total_compile_time|$opt|$march_desc|$mtune_desc|$extra_desc+PGO|$size" > /tmp/combo_results_$$/${combo_id} 2>/dev/null
                                                        fi
                                                        
                                                        rm -f $exe_name ${exe_name}_gen *.gcda 2>/dev/null
                                                    fi
                                                fi
                                            else
                                                # Standard compilation without PGO
                                                # Time the compilation
                                                compile_start=$(date +%s.%N)
                                                gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                                                compile_end=$(date +%s.%N)
                                                compile_time=$(echo "scale=3; $compile_end - $compile_start" | bc -l)
                                                
                                                if [ $? -eq 0 ]; then
                                                    result=$(./$exe_name $size 2>/dev/null)
                                                    gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                                    time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                                    
                                                    if [ ! -z "$gflops" ]; then
                                                        sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                                                        echo "$sort_key|$gflops|$time|$compile_time|$opt|$march_desc|$mtune_desc|$extra_desc|$size" > /tmp/combo_results_$$/${combo_id} 2>/dev/null
                                                    fi
                                                    
                                                    rm -f $exe_name 2>/dev/null
                                                fi
                                            fi
                                            
                                            # Add delay before marking complete
                                            sleep 0.5
                                            echo "Complete" > "$STATUS_DIR/$combo_id"
                                        ) &
                                done
                            done
                        done
                    else
                        # Original logic without extra flags
                        # Build flags
                        flags="-$opt"
                        
                        # Add march flag
                        case $march in
                            "native")
                                flags="$flags -march=native"
                                ;;
                            "neoverse")
                                flags="$flags -march=$MARCH_SPECIFIC"
                                ;;
                        esac
                        
                        # Add mtune flag
                        case $mtune in
                            "native")
                                flags="$flags -mtune=native"
                                ;;
                            "neoverse")
                                flags="$flags -mtune=$MTUNE_SPECIFIC"
                                ;;
                        esac
                        
                        march_desc="$march"
                        mtune_desc="$mtune"
                        
                        # Wait for available job slot
                        wait_for_slot
                        
                        # Run test in background
                        (
                            if [ $pgo -eq 1 ]; then
                                combo_id="${opt}_${march}_${mtune}_${pgo}_${size}"
                            else
                                combo_id="${opt}_${march}_${mtune}_${size}"
                            fi
                            echo "Running" > "$STATUS_DIR/$combo_id"
                            
                            # Add small delay to see state changes
                            sleep 0.5
                            
                            exe_name="combo_${opt}_${march}_${mtune}_${pgo}_${size}_$$_${RANDOM}"
                            
                            # Time the compilation
                            if [ $pgo -eq 1 ]; then
                                # PGO compilation: generate -> run -> use
                                # Step 1: Compile with -fprofile-generate
                                compile1_start=$(date +%s.%N)
                                gcc $flags -fprofile-generate -Wall -o ${exe_name}_gen src/optimized_matrix.c -lm 2>/dev/null
                                compile1_end=$(date +%s.%N)
                                compile1_time=$(echo "scale=3; $compile1_end - $compile1_start" | bc -l)
                                
                                if [ $? -eq 0 ]; then
                                    # Step 2: Run to generate profile data
                                    profile_start=$(date +%s.%N)
                                    ./${exe_name}_gen $size >/dev/null 2>&1
                                    profile_end=$(date +%s.%N)
                                    profile_time=$(echo "scale=3; $profile_end - $profile_start" | bc -l)
                                    
                                    # Step 3: Compile with -fprofile-use
                                    compile2_start=$(date +%s.%N)
                                    gcc $flags -fprofile-use -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                                    compile2_end=$(date +%s.%N)
                                    compile2_time=$(echo "scale=3; $compile2_end - $compile2_start" | bc -l)
                                    
                                    total_compile_time=$(echo "scale=3; $compile1_time + $profile_time + $compile2_time" | bc -l)
                                    
                                    if [ $? -eq 0 ]; then
                                        result=$(./$exe_name $size 2>/dev/null)
                                        gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                        time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                        
                                        if [ ! -z "$gflops" ]; then
                                            sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                                            echo "$sort_key|$gflops|$time|$total_compile_time|$opt|$march_desc|$mtune_desc|PGO|$size" > /tmp/combo_results_$$/${combo_id} 2>/dev/null
                                        fi
                                        
                                        rm -f $exe_name ${exe_name}_gen *.gcda 2>/dev/null
                                    fi
                                fi
                            else
                                # Standard compilation without PGO
                                compile_start=$(date +%s.%N)
                                gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                                compile_end=$(date +%s.%N)
                                compile_time=$(echo "scale=3; $compile_end - $compile_start" | bc -l)
                                
                                if [ $? -eq 0 ]; then
                                    result=$(./$exe_name $size 2>/dev/null)
                                    gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                    time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                    
                                    if [ ! -z "$gflops" ]; then
                                        sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                                        echo "$sort_key|$gflops|$time|$compile_time|$opt|$march_desc|$mtune_desc||$size" > /tmp/combo_results_$$/${combo_id} 2>/dev/null
                                    fi
                                    
                                    rm -f $exe_name 2>/dev/null
                                fi
                            fi
                            
                            # Add delay before marking complete
                            sleep 0.5
                            echo "Complete" > "$STATUS_DIR/$combo_id"
                        ) &
                    fi
                done
            done
        done
    done
fi
done

# Wait for micro and small to complete
wait

# Kill the monitor process and restart it for medium tests
kill $MONITOR_PID 2>/dev/null
wait $MONITOR_PID 2>/dev/null

# Now run medium if requested
if [[ " ${sizes[@]} " =~ " medium " ]]; then
    # Restart monitor for medium tests
    (
        # Hide cursor and save position
        printf "\033[?25l\033[s"
        
        while [ -d "$STATUS_DIR" ]; do
            # Restore cursor position instead of clearing screen
            printf "\033[u"
            
            echo "=== Benchmark Status Dashboard ==="
            echo "Updated: $(date '+%H:%M:%S')"
            echo
            
            # Count status by matrix size (only for medium tests)
            size_pending=$(grep -l "Pending" "$STATUS_DIR"/*_medium 2>/dev/null | wc -l)
            size_running=$(grep -l "Running" "$STATUS_DIR"/*_medium 2>/dev/null | wc -l)
            size_complete=$(grep -l "Complete" "$STATUS_DIR"/*_medium 2>/dev/null | wc -l)
            
            # Only show if there are any medium status files
            if [ $((size_pending + size_running + size_complete)) -gt 0 ]; then
                echo "medium matrix compile runs pending/running/complete ${size_pending}/${size_running}/${size_complete}"
            fi
            echo
            
            # Exit if all tests are complete
            total=$(ls "$STATUS_DIR" 2>/dev/null | wc -l)
            complete=$(grep -l "Complete" "$STATUS_DIR"/* 2>/dev/null | wc -l)
            if [ $complete -eq $total ]; then
                break
            fi
            
            # Clear to end of screen to remove old content
            printf "\033[J"
            sleep 1
        done
        
        # Restore cursor
        printf "\033[?25h"
    ) &
    MONITOR_PID=$!

    for opt in "${opt_levels[@]}"; do
        for march in "${march_options[@]}"; do
            for mtune in "${mtune_options[@]}"; do
                if [ "$use_extra_flags" = true ]; then
                    # Test all 16 combinations of extra flags (2^4)
                    for flto in 0 1; do
                        for fomit in 0 1; do
                            for funroll in 0 1; do
                                # Build flags
                                flags="-$opt"
                                    
                                    # Add march flag
                                    case $march in
                                        "native")
                                            flags="$flags -march=native"
                                            ;;
                                        "neoverse")
                                            flags="$flags -march=$MARCH_SPECIFIC"
                                            ;;
                                    esac
                                    
                                    # Add mtune flag
                                    case $mtune in
                                        "native")
                                            flags="$flags -mtune=native"
                                            ;;
                                        "neoverse")
                                            flags="$flags -mtune=$MTUNE_SPECIFIC"
                                            ;;
                                    esac
                                    
                                    # Add extra flags
                                    extra_desc=""
                                    [ $flto -eq 1 ] && flags="$flags -flto" && extra_desc="${extra_desc}flto,"
                                    [ $fomit -eq 1 ] && flags="$flags -fomit-frame-pointer" && extra_desc="${extra_desc}fomit-frame-pointer,"
                                    [ $funroll -eq 1 ] && flags="$flags -funroll-loops" && extra_desc="${extra_desc}funroll-loops,"
                                    extra_desc=${extra_desc%,}  # Remove trailing comma
                                    
                                    march_desc="$march"
                                    mtune_desc="$mtune"
                                    
                                    # Wait for available job slot
                                    wait_for_slot
                                    
                                    # Run test in background
                                    (
                                        combo_id="${opt}_${march}_${mtune}_${flto}${fomit}${funroll}_medium"
                                        echo "Running" > "$STATUS_DIR/$combo_id"
                                        
                                        # Add small delay to see state changes
                                        sleep 0.5
                                        
                                        exe_name="combo_${opt}_${march}_${mtune}_${flto}${fomit}${funroll}_medium_$$_${RANDOM}"
                                        
                                        # Time the compilation
                                        compile_start=$(date +%s.%N)
                                        gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                                        compile_end=$(date +%s.%N)
                                        compile_time=$(echo "scale=3; $compile_end - $compile_start" | bc -l)
                                        
                                        if [ $? -eq 0 ]; then
                                            result=$(./$exe_name medium 2>/dev/null)
                                            gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                            time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                            
                                            if [ ! -z "$gflops" ]; then
                                                sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                                                echo "$sort_key|$gflops|$time|$compile_time|$opt|$march_desc|$mtune_desc|$extra_desc|medium" > /tmp/combo_results_$$/${combo_id} 2>/dev/null
                                            fi
                                            
                                            rm -f $exe_name 2>/dev/null
                                        fi
                                        
                                        # Add delay before marking complete
                                        sleep 0.5
                                        echo "Complete" > "$STATUS_DIR/$combo_id"
                                    ) &
                            done
                        done
                    done
                else
                    # Original logic without extra flags
                    # Build flags
                    flags="-$opt"
                    
                    # Add march flag
                    case $march in
                        "native")
                            flags="$flags -march=native"
                            ;;
                        "neoverse")
                            flags="$flags -march=$MARCH_SPECIFIC"
                            ;;
                    esac
                    
                    # Add mtune flag
                    case $mtune in
                        "native")
                            flags="$flags -mtune=native"
                            ;;
                        "neoverse")
                            flags="$flags -mtune=$MTUNE_SPECIFIC"
                            ;;
                    esac
                    
                    march_desc="$march"
                    mtune_desc="$mtune"
                    
                    # Wait for available job slot
                    wait_for_slot
                    
                    # Run test in background
                    (
                        combo_id="${opt}_${march}_${mtune}_medium"
                        echo "Running" > "$STATUS_DIR/$combo_id"
                        
                        # Add small delay to see state changes
                        sleep 0.5
                        
                        exe_name="combo_${opt}_${march}_${mtune}_medium_$$_${RANDOM}"
                        
                        # Time the compilation
                        compile_start=$(date +%s.%N)
                        gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                        compile_end=$(date +%s.%N)
                        compile_time=$(echo "scale=3; $compile_end - $compile_start" | bc -l)
                        
                        if [ $? -eq 0 ]; then
                            result=$(./$exe_name medium 2>/dev/null)
                            gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                            time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                            
                            if [ ! -z "$gflops" ]; then
                                sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                                echo "$sort_key|$gflops|$time|$compile_time|$opt|$march_desc|$mtune_desc|medium" > /tmp/combo_results_$$/${opt}_${march}_${mtune}_medium 2>/dev/null
                            fi
                            
                            rm -f $exe_name 2>/dev/null
                        fi
                        
                        # Add delay before marking complete
                        sleep 0.5
                        echo "Complete" > "$STATUS_DIR/$combo_id"
                    ) &
                fi
            done
        done
    done
else
    # Medium tests skipped, clear MONITOR_PID
    MONITOR_PID=""
fi

# Wait for all jobs and monitor to complete
wait
# Kill any remaining monitor process
if [ ! -z "$MONITOR_PID" ]; then
    kill $MONITOR_PID 2>/dev/null
    wait $MONITOR_PID 2>/dev/null
fi
sleep 1
rm -rf "$STATUS_DIR"
clear

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
    echo "### ${target_size^} Matrix ($(case $target_size in micro) echo "64x64";; small) echo "512x512";; medium) echo "2048x2048";; esac))"
    echo
    if [ "$use_extra_flags" = true ]; then
        printf "| %-5s | %-8s | %-8s | %-15s | %-4s | %-15s | %-15s | %-20s | %-3s |\n" "Rank" "GFLOPS" "GFLOP/s" "Time (seconds)" "Opt" "-march" "-mtune" "Extra Flags" "PGO"
        printf "|       |          |          | %-6s | %-7s |      |                 |                  |                      |     |\n" "Run" "Compile"
        printf "|-------|----------|----------|--------|---------|------|-----------------|------------------|----------------------|-----|\n"
    else
        printf "| %-5s | %-8s | %-8s | %-15s | %-4s | %-15s | %-15s | %-3s |\n" "Rank" "GFLOPS" "GFLOP/s" "Time (seconds)" "Opt" "-march" "-mtune" "PGO"
        printf "|       |          |          | %-6s | %-7s |      |                 |                  |     |\n" "Run" "Compile"
        printf "|-------|----------|----------|--------|---------|------|-----------------|------------------|-----|\n"
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
    
    for result in "${sorted[@]}"; do
        IFS='|' read -r sort_key gflops time compile_time opt march mtune extra_flags size <<< "$result"
        
        if [ "$size" = "$target_size" ]; then
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
            if [ "$time" = "0.000" ] || [ "$time" = "0" ]; then
                gflop_per_s="∞"
            else
                gflop_per_s=$(echo "scale=2; $gflops / $time" | bc -l 2>/dev/null || echo "∞")
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
                
                printf "| %-5d | %-8s | %-8s | %-6s | %-7s | %-4s | %-15s | %-15s | %-20s | %-3s |\n" "$rank" "$gflops" "$gflop_per_s" "$time" "$compile_time" "-$opt" "$march_flag" "$mtune_flag" "$extra_display" "$pgo_display"
            else
                printf "| %-5d | %-8s | %-8s | %-6s | %-7s | %-4s | %-15s | %-15s | %-3s |\n" "$rank" "$gflops" "$gflop_per_s" "$time" "$compile_time" "-$opt" "$march_flag" "$mtune_flag" "$pgo_display"
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
    baseline_micro=$(printf '%s\n' "${sorted[@]}" | grep "|O0|native|native||micro$" | head -1 | cut -d'|' -f2)
    baseline_small=$(printf '%s\n' "${sorted[@]}" | grep "|O0|native|native||small$" | head -1 | cut -d'|' -f2)
    baseline_medium=$(printf '%s\n' "${sorted[@]}" | grep "|O0|native|native||medium$" | head -1 | cut -d'|' -f2)
else
    baseline_micro=$(printf '%s\n' "${sorted[@]}" | grep "|O0|native|native||micro$" | head -1 | cut -d'|' -f2)
    baseline_small=$(printf '%s\n' "${sorted[@]}" | grep "|O0|native|native||small$" | head -1 | cut -d'|' -f2)
    baseline_medium=$(printf '%s\n' "${sorted[@]}" | grep "|O0|native|native||medium$" | head -1 | cut -d'|' -f2)
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

# Function to get default compile performance (O0 with no flags) compared to best
get_default_performance() {
    local size=$1
    local best_gflops=$2
    
    # Find O0 with none/none performance
    local default_gflops=$(printf '%s\n' "${sorted[@]}" | grep "|O0|none|none|$size$" | head -1 | cut -d'|' -f2)
    
    if [ ! -z "$default_gflops" ]; then
        local change=$(echo "scale=1; ($default_gflops - $best_gflops) / $best_gflops * 100" | bc -l)
        if (( $(echo "$change < 0" | bc -l) )); then
            local change_abs=${change#-}
            echo "${change_abs}% performance hit"
        elif (( $(echo "$change > 1" | bc -l) )); then
            echo "${change}% performance gain"
        else
            echo "no significant change"
        fi
    else
        echo "no data available"
    fi
}

for size in "${sizes[@]}"; do
    case $size in
        "micro") baseline=$baseline_micro; size_desc="64x64" ;;
        "small") baseline=$baseline_small; size_desc="512x512" ;;
        "medium") baseline=$baseline_medium; size_desc="2048x2048" ;;
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
