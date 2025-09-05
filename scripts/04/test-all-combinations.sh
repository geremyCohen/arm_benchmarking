#!/bin/bash
# test-all-combinations.sh - Test all combinations with real-time status using temp files
# Uses O0/None/None results as baseline for performance comparisons (no separate baseline script needed)

echo "=== Comprehensive Compiler Optimization Analysis ==="
echo

# Prompt for matrix sizes with timeout
echo -n "Test sizes: micro+small (default) or all including medium? [micro+small/all] (3s timeout): "
read -t 3 size_choice
echo

if [[ "$size_choice" == "all" ]]; then
    sizes=("micro" "small" "medium")
    echo "Testing all sizes: micro, small, medium"
else
    sizes=("micro" "small")
    echo "Testing default sizes: micro, small (medium skipped for speed)"
fi

# Prompt for additional optimization flags with timeout
echo -n "Include additional optimization flags (-flto, -fomit-frame-pointer, -funroll-loops, -ffast-math)? [y/N] (3s timeout): "
read -t 3 extra_flags_choice
echo

if [ "$extra_flags_choice" = "y" ] || [ "$extra_flags_choice" = "Y" ]; then
    use_extra_flags=true
    extra_flags=("flto" "fomit-frame-pointer" "funroll-loops" "ffast-math")
    echo "Including additional optimization flags (16x more combinations: 2^4 flag combinations)"
else
    use_extra_flags=false
    extra_flags=()
    echo "Using standard optimization flags only"
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
            if [ "$use_extra_flags" = true ]; then
                # Generate all combinations of extra flags (2^4 = 16 combinations)
                for flto in 0 1; do
                    for fomit in 0 1; do
                        for funroll in 0 1; do
                            for ffast in 0 1; do
                                for size in "${sizes[@]}"; do
                                    echo "Pending" > "$STATUS_DIR/${opt}_${march}_${mtune}_${flto}${fomit}${funroll}${ffast}_${size}"
                                done
                            done
                        done
                    done
                done
            else
                for size in "${sizes[@]}"; do
                    echo "Pending" > "$STATUS_DIR/${opt}_${march}_${mtune}_${size}"
                done
            fi
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
        
        # Count status
        total=$(ls "$STATUS_DIR" 2>/dev/null | wc -l)
        pending=$(grep -l "Pending" "$STATUS_DIR"/* 2>/dev/null | wc -l)
        running=$(grep -l "Running" "$STATUS_DIR"/* 2>/dev/null | wc -l)
        complete=$(grep -l "Complete" "$STATUS_DIR"/* 2>/dev/null | wc -l)
        
        echo "Progress: $complete/$total complete, $running running, $pending pending"
        echo
        
        # Exit if all tests are complete
        if [ $complete -eq $total ] && [ $running -eq 0 ] && [ $pending -eq 0 ]; then
            break
        fi
        
        printf "| %-12s | %-12s | %-12s | %-8s | %-10s | %-12s |\n" "Optimization" "-march" "-mtune" "Size" "Status" "Elapsed Time"
        printf "|--------------|--------------|--------------|----------|------------|--------------|\n"
        
        # Group by size
        for size in "${sizes[@]}"; do
            # Check if there are any active (non-complete) tests for this size first
            has_active_tests=false
            for opt in "${opt_levels[@]}"; do
                for march in "${march_options[@]}"; do
                    for mtune in "${mtune_options[@]}"; do
                        status_file="$STATUS_DIR/${opt}_${march}_${mtune}_${size}"
                        if [ -f "$status_file" ]; then
                            status=$(cat "$status_file")
                            if [ "$status" != "Complete" ]; then
                                has_active_tests=true
                                break 3
                            fi
                        fi
                    done
                done
            done
            
            # Only show heading and tests if there are active tests
            if [ "$has_active_tests" = true ]; then
                echo "### ${size^} Matrix"
            fi
            
            for opt in "${opt_levels[@]}"; do
                for march in "${march_options[@]}"; do
                    for mtune in "${mtune_options[@]}"; do
                        status_file="$STATUS_DIR/${opt}_${march}_${mtune}_${size}"
                        if [ -f "$status_file" ]; then
                            status=$(cat "$status_file")
                            
                            # Only show pending and running, skip completed
                            if [ "$status" != "Complete" ]; then
                                case $march in
                                    "none") march_display="None" ;;
                                    "native") march_display="Autodetect" ;;
                                    "neoverse") march_display="V2" ;;
                                esac
                                
                                case $mtune in
                                    "none") mtune_display="None" ;;
                                    "native") mtune_display="Autodetect" ;;
                                    "neoverse") mtune_display="V2" ;;
                                esac
                                
                                # Calculate elapsed time
                                if [ "$status" = "Pending" ]; then
                                    elapsed_time="0s"
                                    status_display="⏳ Pending"
                                elif [ "$status" = "Running" ]; then
                                    # Get start time from file modification time
                                    start_time=$(stat -c %Y "$status_file" 2>/dev/null || echo $(date +%s))
                                    current_time=$(date +%s)
                                    elapsed=$((current_time - start_time))
                                    elapsed_time="${elapsed}s"
                                    status_display="🔄 Running"
                                fi
                                
                                printf "| %-12s | %-12s | %-12s | %-8s | %-10s | %-12s |\n" "-$opt" "$march_display" "$mtune_display" "$size" "$status_display" "$elapsed_time"
                            fi
                        fi
                    done
                done
            done
            echo
        done
        
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
                    if [ "$use_extra_flags" = true ]; then
                        # Test all 16 combinations of extra flags (2^4)
                        for flto in 0 1; do
                            for fomit in 0 1; do
                                for funroll in 0 1; do
                                    for ffast in 0 1; do
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
                                        [ $ffast -eq 1 ] && flags="$flags -ffast-math" && extra_desc="${extra_desc}ffast-math,"
                                        extra_desc=${extra_desc%,}  # Remove trailing comma
                                        
                                        march_desc="$march"
                                        mtune_desc="$mtune"
                                        
                                        # Wait for available job slot
                                        wait_for_slot
                                        
                                        # Run test in background
                                        (
                                            combo_id="${opt}_${march}_${mtune}_${flto}${fomit}${funroll}${ffast}_${size}"
                                            echo "Running" > "$STATUS_DIR/$combo_id"
                                            
                                            # Add small delay to see state changes
                                            sleep 0.5
                                            
                                            exe_name="combo_${opt}_${march}_${mtune}_${flto}${fomit}${funroll}${ffast}_${size}_$$_${RANDOM}"
                                            gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                                            
                                            if [ $? -eq 0 ]; then
                                                result=$(./$exe_name $size 2>/dev/null)
                                                gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                                time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                                
                                                if [ ! -z "$gflops" ]; then
                                                    sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                                                    echo "$sort_key|$gflops|$time|$opt|$march_desc|$mtune_desc|$extra_desc|$size" > /tmp/combo_results_$$/${combo_id} 2>/dev/null
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
                            combo_id="${opt}_${march}_${mtune}_${size}"
                            echo "Running" > "$STATUS_DIR/$combo_id"
                            
                            # Add small delay to see state changes
                            sleep 0.5
                            
                            exe_name="combo_${opt}_${march}_${mtune}_${size}_$$_${RANDOM}"
                            gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                            
                            if [ $? -eq 0 ]; then
                                result=$(./$exe_name $size 2>/dev/null)
                                gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                
                                if [ ! -z "$gflops" ]; then
                                    sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                                    echo "$sort_key|$gflops|$time|$opt|$march_desc|$mtune_desc|$size" > /tmp/combo_results_$$/${opt}_${march}_${mtune}_${size} 2>/dev/null
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
            
            # Count status
            total=$(ls "$STATUS_DIR" 2>/dev/null | wc -l)
            pending=$(grep -l "Pending" "$STATUS_DIR"/* 2>/dev/null | wc -l)
            running=$(grep -l "Running" "$STATUS_DIR"/* 2>/dev/null | wc -l)
            complete=$(grep -l "Complete" "$STATUS_DIR"/* 2>/dev/null | wc -l)
            
            echo "Progress: $complete/$total complete, $running running, $pending pending"
            echo
            
            # Exit if all tests are complete
            if [ $complete -eq $total ] && [ $running -eq 0 ] && [ $pending -eq 0 ]; then
                break
            fi
            
            printf "| %-12s | %-12s | %-12s | %-8s | %-10s | %-12s |\n" "Optimization" "-march" "-mtune" "Size" "Status" "Elapsed Time"
            printf "|--------------|--------------|--------------|----------|------------|--------------|\n"
            
            # Group by size
            for size in "${sizes[@]}"; do
                # Check if there are any active (non-complete) tests for this size first
                has_active_tests=false
                for opt in "${opt_levels[@]}"; do
                    for march in "${march_options[@]}"; do
                        for mtune in "${mtune_options[@]}"; do
                            status_file="$STATUS_DIR/${opt}_${march}_${mtune}_${size}"
                            if [ -f "$status_file" ]; then
                                status=$(cat "$status_file")
                                if [ "$status" != "Complete" ]; then
                                    has_active_tests=true
                                    break 3
                                fi
                            fi
                        done
                    done
                done
                
                # Only show heading and tests if there are active tests
                if [ "$has_active_tests" = true ]; then
                    echo "### ${size^} Matrix"
                fi
                
                for opt in "${opt_levels[@]}"; do
                    for march in "${march_options[@]}"; do
                        for mtune in "${mtune_options[@]}"; do
                            status_file="$STATUS_DIR/${opt}_${march}_${mtune}_${size}"
                            if [ -f "$status_file" ]; then
                                status=$(cat "$status_file")
                                
                                # Only show pending and running, skip completed
                                if [ "$status" != "Complete" ]; then
                                    case $march in
                                        "none") march_display="None" ;;
                                        "native") march_display="Autodetect" ;;
                                        "neoverse") march_display="V2" ;;
                                    esac
                                    
                                    case $mtune in
                                        "none") mtune_display="None" ;;
                                        "native") mtune_display="Autodetect" ;;
                                        "neoverse") mtune_display="V2" ;;
                                    esac
                                    
                                    # Calculate elapsed time
                                    if [ "$status" = "Pending" ]; then
                                        elapsed_time="0s"
                                        status_display="⏳ Pending"
                                    elif [ "$status" = "Running" ]; then
                                        # Get start time from file modification time
                                        start_time=$(stat -c %Y "$status_file" 2>/dev/null || echo $(date +%s))
                                        current_time=$(date +%s)
                                        elapsed=$((current_time - start_time))
                                        elapsed_time="${elapsed}s"
                                        status_display="🔄 Running"
                                    fi
                                    
                                    printf "| %-12s | %-12s | %-12s | %-8s | %-10s | %-12s |\n" "-$opt" "$march_display" "$mtune_display" "$size" "$status_display" "$elapsed_time"
                                fi
                            fi
                        done
                    done
                done
            done
            
            echo
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
                                for ffast in 0 1; do
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
                                    [ $ffast -eq 1 ] && flags="$flags -ffast-math" && extra_desc="${extra_desc}ffast-math,"
                                    extra_desc=${extra_desc%,}  # Remove trailing comma
                                    
                                    march_desc="$march"
                                    mtune_desc="$mtune"
                                    
                                    # Wait for available job slot
                                    wait_for_slot
                                    
                                    # Run test in background
                                    (
                                        combo_id="${opt}_${march}_${mtune}_${flto}${fomit}${funroll}${ffast}_medium"
                                        echo "Running" > "$STATUS_DIR/$combo_id"
                                        
                                        # Add small delay to see state changes
                                        sleep 0.5
                                        
                                        exe_name="combo_${opt}_${march}_${mtune}_${flto}${fomit}${funroll}${ffast}_medium_$$_${RANDOM}"
                                        gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                                        
                                        if [ $? -eq 0 ]; then
                                            result=$(./$exe_name medium 2>/dev/null)
                                            gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                                            time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                                            
                                            if [ ! -z "$gflops" ]; then
                                                sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                                                echo "$sort_key|$gflops|$time|$opt|$march_desc|$mtune_desc|$extra_desc|medium" > /tmp/combo_results_$$/${combo_id} 2>/dev/null
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
                        gcc $flags -Wall -o $exe_name src/optimized_matrix.c -lm 2>/dev/null
                        
                        if [ $? -eq 0 ]; then
                            result=$(./$exe_name medium 2>/dev/null)
                            gflops=$(echo "$result" | grep "Performance:" | awk '{print $2}')
                            time=$(echo "$result" | grep "Time:" | awk '{print $2}')
                            
                            if [ ! -z "$gflops" ]; then
                                sort_key=$(printf "%08.2f" $(echo "$gflops * 100" | bc -l) | tr '.' '_')
                                echo "$sort_key|$gflops|$time|$opt|$march_desc|$mtune_desc|medium" > /tmp/combo_results_$$/${opt}_${march}_${mtune}_medium 2>/dev/null
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
        printf "| %-5s | %-8s | %-6s | %-8s | %-4s | %-15s | %-15s | %-20s |\n" "Rank" "GFLOPS" "Time(s)" "GFLOP/s" "Opt" "-march" "-mtune" "Extra Flags"
        printf "|-------|----------|--------|----------|------|-----------------|------------------|----------------------|\n"
    else
        printf "| %-5s | %-8s | %-6s | %-8s | %-4s | %-15s | %-15s |\n" "Rank" "GFLOPS" "Time(s)" "GFLOP/s" "Opt" "-march" "-mtune"
        printf "|-------|----------|--------|----------|------|-----------------|------------------|\n"
    fi
    
    rank=1
    best_gflops_for_size=""
    best_opt_for_size=""
    best_march_for_size=""
    best_mtune_for_size=""
    worst_gflops_for_size=""
    worst_opt_for_size=""
    worst_march_for_size=""
    worst_mtune_for_size=""
    autodetect_gflops_for_size=""
    
    for result in "${sorted[@]}"; do
        if [ "$use_extra_flags" = true ]; then
            IFS='|' read -r sort_key gflops time opt march mtune extra_flags size <<< "$result"
        else
            IFS='|' read -r sort_key gflops time opt march mtune size <<< "$result"
            extra_flags=""
        fi
        if [ "$size" = "$target_size" ]; then
            # Track best performance for this size
            if [ -z "$best_gflops_for_size" ]; then
                best_gflops_for_size="$gflops"
                best_opt_for_size="$opt"
                best_march_for_size="$march"
                best_mtune_for_size="$mtune"
            fi
            
            # Track worst performance for this size (last non-O0 result)
            if [ "$opt" != "O0" ]; then
                worst_gflops_for_size="$gflops"
                worst_opt_for_size="$opt"
                worst_march_for_size="$march"
                worst_mtune_for_size="$mtune"
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
            
            # Format extra flags for display
            if [ "$use_extra_flags" = true ]; then
                extra_display=""
                if [[ "$extra_flags" == *"flto"* ]]; then extra_display="${extra_display}lto,"; fi
                if [[ "$extra_flags" == *"fomit-frame-pointer"* ]]; then extra_display="${extra_display}omit-fp,"; fi
                if [[ "$extra_flags" == *"funroll-loops"* ]]; then extra_display="${extra_display}unroll,"; fi
                if [[ "$extra_flags" == *"ffast-math"* ]]; then extra_display="${extra_display}fast-math,"; fi
                extra_display=${extra_display%,}  # Remove trailing comma
                [ -z "$extra_display" ] && extra_display="None"
                
                printf "| %-5d | %-8s | %-6s | %-8s | %-4s | %-15s | %-15s | %-20s |\n" "$rank" "$gflops" "$time" "$gflop_per_s" "-$opt" "$march_flag" "$mtune_flag" "$extra_display"
            else
                printf "| %-5d | %-8s | %-6s | %-8s | %-4s | %-15s | %-15s |\n" "$rank" "$gflops" "$time" "$gflop_per_s" "-$opt" "$march_flag" "$mtune_flag"
            fi
            ((rank++))
        fi
    done
    
    # Store data for consolidated insights
    eval "${target_size}_best_gflops=\"$best_gflops_for_size\""
    eval "${target_size}_best_opt=\"$best_opt_for_size\""
    eval "${target_size}_best_march=\"$best_march_for_size\""
    eval "${target_size}_best_mtune=\"$best_mtune_for_size\""
    eval "${target_size}_worst_gflops=\"$worst_gflops_for_size\""
    eval "${target_size}_worst_opt=\"$worst_opt_for_size\""
    eval "${target_size}_worst_march=\"$worst_march_for_size\""
    eval "${target_size}_worst_mtune=\"$worst_mtune_for_size\""
    eval "${target_size}_autodetect_gflops=\"$autodetect_gflops_for_size\""
    
    echo
done

echo "=== Key Insights ==="

# Get baseline performance from O0/None/None results in our test data
if [ "$use_extra_flags" = true ]; then
    baseline_micro=$(printf '%s\n' "${sorted[@]}" | grep "|O0|none|none||micro$" | head -1 | cut -d'|' -f2)
    baseline_small=$(printf '%s\n' "${sorted[@]}" | grep "|O0|none|none||small$" | head -1 | cut -d'|' -f2)
    baseline_medium=$(printf '%s\n' "${sorted[@]}" | grep "|O0|none|none||medium$" | head -1 | cut -d'|' -f2)
else
    baseline_micro=$(printf '%s\n' "${sorted[@]}" | grep "|O0|none|none|micro$" | head -1 | cut -d'|' -f2)
    baseline_small=$(printf '%s\n' "${sorted[@]}" | grep "|O0|none|none|small$" | head -1 | cut -d'|' -f2)
    baseline_medium=$(printf '%s\n' "${sorted[@]}" | grep "|O0|none|none|medium$" | head -1 | cut -d'|' -f2)
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
    eval "worst_gflops=\$${size}_worst_gflops"
    eval "worst_opt=\$${size}_worst_opt"
    eval "worst_march=\$${size}_worst_march"
    eval "worst_mtune=\$${size}_worst_mtune"
    
    if [ ! -z "$best_gflops" ] && [ "$best_gflops" != "" ] && [ ! -z "$baseline" ] && [ "$baseline" != "" ]; then
        echo
        echo "**${size^} Matrix ($size_desc) Performance:**"
        
        # Best performance
        best_speedup=$(echo "scale=1; ($best_gflops - $baseline) / $baseline * 100" | bc -l 2>/dev/null || echo "0")
        best_march_name=$(get_arch_name "$best_march")
        best_mtune_name=$(get_arch_name "$best_mtune")
        
        # Format best performance message
        if (( $(echo "$best_speedup < 0" | bc -l 2>/dev/null) )); then
            best_speedup_abs=${best_speedup#-}
            best_msg="-- Best: ${best_speedup_abs}% performance **hit** over baseline using -$best_opt, -march $best_march_name, -mtune $best_mtune_name"
        else
            best_msg="-- Best: ${best_speedup}% performance **gain** over baseline using -$best_opt, -march $best_march_name, -mtune $best_mtune_name"
        fi
        echo "$best_msg"
        
        # Worst performance (if different from best)
        if [ ! -z "$worst_gflops" ] && [ "$worst_gflops" != "$best_gflops" ] && [ "$worst_gflops" != "" ]; then
            worst_speedup=$(echo "scale=1; ($worst_gflops - $baseline) / $baseline * 100" | bc -l 2>/dev/null || echo "0")
            worst_march_name=$(get_arch_name "$worst_march")
            worst_mtune_name=$(get_arch_name "$worst_mtune")
            
            # Format worst performance message
            if (( $(echo "$worst_speedup < 0" | bc -l 2>/dev/null) )); then
                worst_speedup_abs=${worst_speedup#-}
                worst_msg="-- Worst: ${worst_speedup_abs}% performance **hit** over baseline using -$worst_opt, -march $worst_march_name, -mtune $worst_mtune_name"
            else
                worst_msg="-- Worst: ${worst_speedup}% performance **gain** over baseline using -$worst_opt, -march $worst_march_name, -mtune $worst_mtune_name"
            fi
            echo "$worst_msg"
        fi
    fi
done

echo
echo "Complete results saved to results/comprehensive/ directory"
