#!/bin/bash
set -e

echo "🧪 Simulating CI Environment Locally"
echo "===================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Clean environment to simulate CI
echo "1. Cleaning local cache to simulate fresh CI..."
rm -rf .godot/imported/*
rm -rf .godot/shader_cache/*
echo "✅ Cache cleaned"

# Create test directory
TEST_DIR="ci_test_build"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

echo ""
echo "2. Running headless export with verbose output..."
echo "================================================"

# Run with maximum verbosity
export GODOT_VERBOSE=2

# Test the exact same command as CI
echo "Running: godot --headless --verbose --export-debug \"Web\" \"$TEST_DIR/index.html\""
echo ""

if godot --headless --verbose --export-debug "Web" "$TEST_DIR/index.html" 2>&1 | tee ci_test.log; then
    echo -e "${GREEN}✅ Export succeeded${NC}"
else
    echo -e "${RED}❌ Export failed (same as CI)${NC}"
fi

echo ""
echo "3. Analyzing errors..."
echo "====================="

# Check for texture errors
if grep -q "Parameter.*null\|texture.*null" ci_test.log; then
    echo -e "${RED}❌ Found texture loading errors:${NC}"
    grep -n "Parameter.*null\|texture" ci_test.log | head -10
    echo ""
    echo "Files causing issues:"
    grep -B5 "Parameter.*null" ci_test.log | grep -E "\.blend|\.glb|\.png|\.jpg" | sort -u
fi

# Check for import errors
if grep -q "ERROR.*import\|Failed.*import" ci_test.log; then
    echo -e "${RED}❌ Found import errors:${NC}"
    grep -n "ERROR.*import" ci_test.log | head -10
fi

# Check for specific model errors
echo ""
echo "4. Model-specific issues..."
echo "=========================="
for model in "floor.blend" "floorplan.blend" "floor.glb" "floorplan.glb"; do
    if grep -q "$model" ci_test.log; then
        echo "Found references to $model:"
        grep -C3 "$model" ci_test.log | head -15
        echo "---"
    fi
done

echo ""
echo "5. Debug suggestions..."
echo "======================"
echo "Full log saved to: ci_test.log"
echo ""
echo "To fix texture issues:"
echo "1. Open project in Godot editor"
echo "2. Check each model for missing textures (red icons)"
echo "3. Either fix textures or remove material references"
echo ""
echo "To see more detail, check ci_test.log"