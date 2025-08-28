#!/bin/bash
set -e

echo "🚀 Local Deployment to itch.io"
echo "=============================="

# Configuration
ITCH_USER="downfallgames"
ITCH_GAME="the-jar-job"
ITCH_CHANNEL="html5"
BUILD_DIR="builds/web"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check prerequisites
check_prerequisites() {
    echo "📋 Checking prerequisites..."
    
    # Check if Godot is installed
    if ! command -v godot &> /dev/null; then
        echo -e "${RED}❌ Godot is not installed or not in PATH${NC}"
        echo "   Please install Godot 4.4+ or add it to your PATH"
        exit 1
    fi
    
    # Check for export templates
    TEMPLATE_PATH="$HOME/.local/share/godot/export_templates/4.4.1.stable"
    if [ ! -d "$TEMPLATE_PATH" ]; then
        echo -e "${YELLOW}⚠️  Export templates not found${NC}"
        echo "   To install:"
        echo "   1. Open Godot Editor"
        echo "   2. Go to Editor > Manage Export Templates"
        echo "   3. Download and install templates for version 4.4.1"
        echo ""
        echo "   Or download manually from:"
        echo "   https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check if Butler is installed
    if ! command -v butler &> /dev/null; then
        echo -e "${RED}❌ Butler is not installed${NC}"
        echo "   Install from: https://itch.io/docs/butler/"
        echo "   Or run: curl -L -o butler.zip https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default && unzip butler.zip"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites installed${NC}"
}

# Function to export the game
export_game() {
    echo ""
    echo "📦 Exporting game..."
    
    # Clean previous build
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Export with Godot
    echo "Running Godot export..."
    if godot --headless --export-release "Web" "$BUILD_DIR/index.html" 2>&1 | tee export.log; then
        # Check for errors in log
        if grep -q "ERROR:" export.log; then
            echo -e "${RED}❌ Export completed with errors:${NC}"
            grep "ERROR:" export.log
            echo ""
            read -p "Continue deployment anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            echo -e "${GREEN}✅ Export completed successfully${NC}"
        fi
    else
        echo -e "${RED}❌ Export failed${NC}"
        exit 1
    fi
    
    # Verify build output
    if [ ! -f "$BUILD_DIR/index.html" ]; then
        echo -e "${RED}❌ Build failed: index.html not found${NC}"
        exit 1
    fi
    
    # Show build size
    BUILD_SIZE=$(du -sh "$BUILD_DIR" | cut -f1)
    echo "📊 Build size: $BUILD_SIZE"
}

# Function to deploy to itch.io
deploy_to_itch() {
    echo ""
    echo "☁️  Deploying to itch.io..."
    
    # Check Butler login
    if ! butler status "$ITCH_USER/$ITCH_GAME" &> /dev/null; then
        echo -e "${YELLOW}🔑 Butler authentication required${NC}"
        echo "   Running 'butler login'..."
        butler login
    fi
    
    # Push to itch.io
    echo "Pushing to $ITCH_USER/$ITCH_GAME:$ITCH_CHANNEL..."
    if butler push "$BUILD_DIR" "$ITCH_USER/$ITCH_GAME:$ITCH_CHANNEL"; then
        echo -e "${GREEN}✅ Successfully deployed to itch.io!${NC}"
        echo ""
        echo "🎮 Play at: https://$ITCH_USER.itch.io/$ITCH_GAME"
    else
        echo -e "${RED}❌ Deployment failed${NC}"
        exit 1
    fi
}

# Main execution
main() {
    echo "Starting local deployment process..."
    echo ""
    
    check_prerequisites
    export_game
    deploy_to_itch
    
    echo ""
    echo -e "${GREEN}🎉 Deployment complete!${NC}"
    
    # Cleanup
    rm -f export.log
}

# Run main function
main