#!/bin/bash
set -e

echo "🧪 Testing Local Export"
echo "======================"

BUILD_DIR="test_build"
LOG_FILE="test_export.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Cleanup function
cleanup() {
    rm -rf "$BUILD_DIR" "$LOG_FILE"
}

# Set trap for cleanup
trap cleanup EXIT

echo "📦 Running test export..."
mkdir -p "$BUILD_DIR"

# Run headless export
if godot --headless --export-release "Web" "$BUILD_DIR/index.html" > "$LOG_FILE" 2>&1; then
    echo -e "${GREEN}✅ Export command completed${NC}"
else
    echo -e "${RED}❌ Export command failed${NC}"
    echo "Last 50 lines of log:"
    tail -50 "$LOG_FILE"
    exit 1
fi

# Check for errors
echo ""
echo "🔍 Checking for errors..."

ERROR_COUNT=$(grep -c "ERROR:" "$LOG_FILE" || true)
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${RED}❌ Found $ERROR_COUNT errors:${NC}"
    grep "ERROR:" "$LOG_FILE" | head -20
    echo ""
    echo "Full log saved to: $LOG_FILE"
    echo "Review the log and fix errors before deploying."
    
    # Don't cleanup so user can review log
    trap - EXIT
    exit 1
fi

# Check for warnings
WARNING_COUNT=$(grep -c "WARNING:" "$LOG_FILE" || true)
if [ "$WARNING_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $WARNING_COUNT warnings${NC}"
    echo "First 5 warnings:"
    grep "WARNING:" "$LOG_FILE" | head -5
fi

# Check output
if [ ! -f "$BUILD_DIR/index.html" ]; then
    echo -e "${RED}❌ Export failed - no index.html generated${NC}"
    exit 1
fi

# Check file count
FILE_COUNT=$(find "$BUILD_DIR" -type f | wc -l)
echo ""
echo "📊 Export Statistics:"
echo "   Files: $FILE_COUNT"
echo "   Size: $(du -sh "$BUILD_DIR" | cut -f1)"

if [ "$FILE_COUNT" -gt 1000 ]; then
    echo -e "${YELLOW}⚠️  Warning: $FILE_COUNT files exceeds itch.io limit (1000)${NC}"
fi

echo ""
echo -e "${GREEN}✅ Test export successful!${NC}"
echo ""
echo "Next steps:"
echo "1. Run ./scripts/deploy-local.sh to deploy to itch.io"
echo "2. Or fix any warnings first"