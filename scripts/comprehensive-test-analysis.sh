#!/bin/bash

# Comprehensive Test Analysis Script
# Runs all combinations and analyzes for compilation issues

echo "=== Comprehensive Test Analysis ==="
echo "Running all combinations with verbose output to detect issues..."
echo

# Create temporary log file
LOG_FILE="/tmp/comprehensive_test_$(date +%s).log"

# Run comprehensive test with all combinations
echo "Starting comprehensive test (this may take several minutes)..."
./scripts/04/test-all-combinations.sh \
    --runs 1,2,3 \
    --opt-levels 0,1,2,3 \
    --arch-flags \
    --sizes 1,2 \
    --extra-flags \
    --pgo \
    --verbose > "$LOG_FILE" 2>&1

TEST_EXIT_CODE=$?

echo "Test completed with exit code: $TEST_EXIT_CODE"
echo "Log saved to: $LOG_FILE"
echo

# Analyze the log for issues
echo "=== ISSUE ANALYSIS ==="
echo

# Count different types of issues
WARNINGS=$(grep -c "warning:" "$LOG_FILE" 2>/dev/null || echo "0")
ERRORS=$(grep -c "error:" "$LOG_FILE" 2>/dev/null || echo "0")
FATAL_ERRORS=$(grep -c "fatal error:" "$LOG_FILE" 2>/dev/null || echo "0")
MISSING_PROFILE=$(grep -c "missing-profile" "$LOG_FILE" 2>/dev/null || echo "0")
COVERAGE_MISMATCH=$(grep -c "coverage-mismatch" "$LOG_FILE" 2>/dev/null || echo "0")
PGO_FAILURES=$(grep -c "PGO.*failed" "$LOG_FILE" 2>/dev/null || echo "0")

echo "Issue Summary:"
echo "- Compilation warnings: $WARNINGS"
echo "- Compilation errors: $ERRORS"
echo "- Fatal errors: $FATAL_ERRORS"
echo "- Missing profile warnings: $MISSING_PROFILE"
echo "- Coverage mismatch warnings: $COVERAGE_MISMATCH"
echo "- PGO failures: $PGO_FAILURES"
echo

# Show specific error patterns
if [ "$ERRORS" -gt 0 ] || [ "$FATAL_ERRORS" -gt 0 ]; then
    echo "=== CRITICAL ERRORS FOUND ==="
    grep -E "(error:|fatal error:)" "$LOG_FILE" | head -10
    echo
fi

if [ "$MISSING_PROFILE" -gt 0 ]; then
    echo "=== PGO PROFILE ISSUES ==="
    grep "missing-profile" "$LOG_FILE" | head -5
    echo
fi

# Check for compilation failures
COMPILATION_FAILURES=$(grep -c "compilation terminated" "$LOG_FILE" 2>/dev/null || echo "0")
if [ "$COMPILATION_FAILURES" -gt 0 ]; then
    echo "=== COMPILATION FAILURES ==="
    echo "Found $COMPILATION_FAILURES compilation failures"
    grep -B2 -A2 "compilation terminated" "$LOG_FILE" | head -20
    echo
fi

# Analyze performance results
TOTAL_COMBINATIONS=$(grep -c "Individual Runs" "$LOG_FILE" 2>/dev/null || echo "0")
SUCCESSFUL_RESULTS=$(grep -c "GFLOPS.*\[" "$LOG_FILE" 2>/dev/null || echo "0")

echo "=== PERFORMANCE ANALYSIS ==="
echo "- Total combinations attempted: $TOTAL_COMBINATIONS"
echo "- Successful results: $SUCCESSFUL_RESULTS"
if [ "$TOTAL_COMBINATIONS" -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=1; $SUCCESSFUL_RESULTS * 100 / $TOTAL_COMBINATIONS" | bc -l 2>/dev/null || echo "N/A")
    echo "- Success rate: $SUCCESS_RATE%"
fi
echo

# Priority recommendations
echo "=== PRIORITY RECOMMENDATIONS ==="
echo

if [ "$TEST_EXIT_CODE" -ne 0 ]; then
    echo "🔴 PRIORITY 1 (CRITICAL): Test script exited with error code $TEST_EXIT_CODE"
    echo "   - Script execution failed - investigate immediately"
    echo
fi

if [ "$FATAL_ERRORS" -gt 0 ] || [ "$ERRORS" -gt 0 ]; then
    echo "🔴 PRIORITY 1 (CRITICAL): Compilation errors found"
    echo "   - $ERRORS compilation errors, $FATAL_ERRORS fatal errors"
    echo "   - Fix compilation issues immediately"
    echo
fi

if [ "$MISSING_PROFILE" -gt 0 ]; then
    echo "🟡 PRIORITY 2 (HIGH): PGO profile issues detected"
    echo "   - $MISSING_PROFILE missing profile warnings"
    echo "   - PGO may not be working correctly"
    echo
fi

if [ "$COVERAGE_MISMATCH" -gt 0 ]; then
    echo "🟡 PRIORITY 2 (HIGH): Coverage mismatch warnings"
    echo "   - $COVERAGE_MISMATCH coverage mismatch warnings"
    echo "   - May indicate PGO profile corruption"
    echo
fi

if [ "$WARNINGS" -gt 50 ]; then
    echo "🟠 PRIORITY 3 (MEDIUM): High warning count"
    echo "   - $WARNINGS total warnings detected"
    echo "   - Consider cleaning up warning sources"
    echo
fi

if [ "$SUCCESS_RATE" != "N/A" ] && [ "$(echo "$SUCCESS_RATE < 95" | bc -l 2>/dev/null)" = "1" ]; then
    echo "🟠 PRIORITY 3 (MEDIUM): Low success rate"
    echo "   - Only $SUCCESS_RATE% of combinations succeeded"
    echo "   - Investigate failed combinations"
    echo
fi

# Show top warning types
echo "=== TOP WARNING TYPES ==="
if [ "$WARNINGS" -gt 0 ]; then
    grep "warning:" "$LOG_FILE" | sed 's/.*warning: //' | cut -d' ' -f1-3 | sort | uniq -c | sort -nr | head -5
else
    echo "No warnings found"
fi
echo

echo "=== ANALYSIS COMPLETE ==="
echo "Full log available at: $LOG_FILE"
echo "Run 'less $LOG_FILE' to view complete output"
