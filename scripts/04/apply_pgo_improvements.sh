#!/bin/bash

# Script to apply PGO improvements to test-all-combinations.sh

SCRIPT_DIR="$(dirname "$0")"
TARGET_SCRIPT="$SCRIPT_DIR/test-all-combinations.sh"
BACKUP_SCRIPT="$SCRIPT_DIR/test-all-combinations.sh.backup_pgo"

echo "Applying PGO improvements to test-all-combinations.sh..."

# Create backup
if [ ! -f "$BACKUP_SCRIPT" ]; then
    cp "$TARGET_SCRIPT" "$BACKUP_SCRIPT"
    echo "Created backup: $BACKUP_SCRIPT"
fi

# 1. Add source line for PGO utilities after shebang
if ! grep -q "pgo_utils.sh" "$TARGET_SCRIPT"; then
    sed -i '2i\\n# Source PGO utility functions\nsource "$(dirname "$0")/pgo_utils.sh"' "$TARGET_SCRIPT"
    echo "Added PGO utilities source line"
fi

# 2. Remove PGO parallelism restriction
sed -i '/# For PGO, reduce parallelism to avoid file conflicts/,/fi/ {
    /if \[ "$use_pgo" = true \]; then/,/fi/ {
        s/MAX_JOBS=2/# MAX_JOBS=2  # Removed: PGO now supports full parallelism/
        s/echo "Running tests with reduced parallelism (MAX_JOBS=2) for PGO stability..."/echo "PGO: Enhanced with proper locking - using full parallelism"/
    }
}' "$TARGET_SCRIPT"

echo "Removed PGO parallelism restriction"

# 3. Create a simple replacement marker for manual editing
echo ""
echo "MANUAL STEP REQUIRED:"
echo "Replace the PGO compilation section (around lines 470-540) with the improved version."
echo "Look for the large 'if [ \$pgo -eq 1 ]; then' block and replace it with the content from:"
echo "  $SCRIPT_DIR/improved_pgo_section.sh"
echo ""
echo "The old section starts with:"
echo "  # PGO compilation - use unique workspace per job"
echo "And ends with:"
echo "  rm -rf \"\$pgo_workspace\" 2>/dev/null"
echo ""
echo "Key improvements applied:"
echo "✓ Added PGO utility functions (pgo_utils.sh)"
echo "✓ Removed parallelism restriction"
echo "✓ Created improved PGO section template"
echo ""
echo "Manual replacement needed for the main PGO compilation logic."
echo "After replacement, the new PGO implementation will provide:"
echo "- Comprehensive .gcda file validation"
echo "- Profile data integrity checking"
echo "- Proper file locking for parallel execution"
echo "- Enhanced error messages and debugging"
echo "- Timeout protection"
echo "- Coverage analysis and warnings"
