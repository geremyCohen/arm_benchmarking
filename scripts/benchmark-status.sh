#!/bin/bash
# benchmark-status.sh - Real-time benchmark status dashboard

# Status tracking files
STATUS_DIR="/tmp/benchmark_status_$$"
mkdir -p "$STATUS_DIR"

# Initialize status tracking
init_status() {
    local test_type=$1
    > "$STATUS_DIR/combinations.txt"
    
    if [ "$test_type" = "baseline" ]; then
        # Baseline combinations: just different matrix sizes
        for size in micro small medium; do
            echo "baseline|$size|Undefined" >> "$STATUS_DIR/combinations.txt"
        done
    else
        # Comprehensive combinations: opt × arch × size
        for opt in O0 O1 O2 O3; do
            for arch in generic native neoverse; do
                for size in micro small medium; do
                    echo "$opt|$arch|$size|Undefined" >> "$STATUS_DIR/combinations.txt"
                done
            done
        done
    fi
}

# Update status for a specific combination
update_status() {
    local combo_id=$1
    local new_status=$2
    
    # Update the status file
    sed -i "s/|${combo_id}|.*$/|${combo_id}|${new_status}/" "$STATUS_DIR/combinations.txt"
}

# Display status table
display_status() {
    clear
    echo "=== Benchmark Status Dashboard ==="
    echo "Updated: $(date '+%H:%M:%S')"
    echo
    
    # Count status
    local total=$(wc -l < "$STATUS_DIR/combinations.txt")
    local undefined=$(grep "|Undefined$" "$STATUS_DIR/combinations.txt" | wc -l)
    local running=$(grep "|Running$" "$STATUS_DIR/combinations.txt" | wc -l)
    local complete=$(grep "|Complete$" "$STATUS_DIR/combinations.txt" | wc -l)
    
    echo "Progress: $complete/$total complete, $running running, $undefined pending"
    echo
    
    # Display table header
    printf "| %-12s | %-12s | %-8s | %-10s |\n" "Optimization" "Architecture" "Size" "Status"
    printf "|--------------|--------------|----------|------------|\n"
    
    # Display combinations
    while IFS='|' read -r opt arch size status; do
        # Format display names
        case $arch in
            "generic") arch_display="None" ;;
            "native") arch_display="Autodetect" ;;
            "neoverse") arch_display="family" ;;
            *) arch_display="$arch" ;;
        esac
        
        case $opt in
            "baseline") opt_display="Baseline" ;;
            *) opt_display="-$opt" ;;
        esac
        
        # Color coding for status
        case $status in
            "Undefined") status_display="⏳ Pending" ;;
            "Running") status_display="🔄 Running" ;;
            "Complete") status_display="✅ Complete" ;;
        esac
        
        printf "| %-12s | %-12s | %-8s | %-10s |\n" "$opt_display" "$arch_display" "$size" "$status_display"
    done < "$STATUS_DIR/combinations.txt"
    
    echo
}

# Background status updater
start_status_monitor() {
    while [ -f "$STATUS_DIR/combinations.txt" ]; do
        display_status
        sleep 1
    done &
    echo $! > "$STATUS_DIR/monitor_pid"
}

# Stop status monitor
stop_status_monitor() {
    if [ -f "$STATUS_DIR/monitor_pid" ]; then
        kill $(cat "$STATUS_DIR/monitor_pid") 2>/dev/null
    fi
    rm -rf "$STATUS_DIR"
}

# Export functions for use by other scripts
export -f update_status
export STATUS_DIR

# If called directly, show usage
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Usage: source benchmark-status.sh"
    echo "Functions available:"
    echo "  init_status <baseline|comprehensive>"
    echo "  start_status_monitor"
    echo "  update_status <combo_id> <status>"
    echo "  stop_status_monitor"
fi
