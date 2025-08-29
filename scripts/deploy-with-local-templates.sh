#!/bin/bash
set -e

echo "🚀 Local Deployment with Portable Templates"
echo "==========================================="

# Configuration
ITCH_USER="downfallgames"
ITCH_GAME="the-jar-job"
ITCH_CHANNEL="html5"
BUILD_DIR="builds/web"
LOCAL_TEMPLATES_DIR="./godot_templates"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load API key
if [ -f ".env" ]; then
    source .env
fi

if [ -z "$BUTLER_API_KEY" ]; then
    echo -e "${RED}❌ BUTLER_API_KEY not set${NC}"
    exit 1
fi

export BUTLER_API_KEY

echo "📋 Setting up portable Godot templates..."

# Create local templates directory
mkdir -p "$LOCAL_TEMPLATES_DIR"

# Download templates if needed
TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz"
WEB_RELEASE_TEMPLATE="$LOCAL_TEMPLATES_DIR/web_nothreads_release.zip"

if [ ! -f "$WEB_RELEASE_TEMPLATE" ]; then
    echo "📥 Downloading export templates..."
    TEMP_FILE="/tmp/templates.tpz"
    
    if curl -L -o "$TEMP_FILE" "$TEMPLATES_URL"; then
        echo "📦 Extracting templates..."
        TEMP_EXTRACT="/tmp/template_extract"
        mkdir -p "$TEMP_EXTRACT"
        
        if unzip -q "$TEMP_FILE" -d "$TEMP_EXTRACT"; then
            # Copy just the web templates we need
            if [ -d "$TEMP_EXTRACT/templates" ]; then
                cp "$TEMP_EXTRACT/templates"/web_* "$LOCAL_TEMPLATES_DIR/" 2>/dev/null || {
                    echo "⚠️  Could not find web templates in archive"
                }
            fi
        fi
        
        rm -rf "$TEMP_FILE" "$TEMP_EXTRACT"
    else
        echo "❌ Failed to download templates"
        exit 1
    fi
fi

# Create a custom export script that uses local templates
echo "📝 Creating custom export configuration..."

# Set up environment to use local templates
export GODOT_EXPORT_TEMPLATES_PATH="$PWD/$LOCAL_TEMPLATES_DIR"

# Create temporary export preset that uses our local templates
cat > export_presets_local.cfg << 'EOF'
[preset.0]

name="Web Local"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="addons/*,.godot/*,models/*.blend,models/*.blend1,*.import,builds/*,tmp/*,godot_templates/*"
export_path="builds/web/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
vram_texture_compression/for_desktop=false
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
progressive_web_app/offline_page=""
progressive_web_app/display=1
progressive_web_app/orientation=0
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)
EOF

echo "📦 Attempting export with local templates..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Try export with custom preset
if godot --headless --export-release "Web Local" "$BUILD_DIR/index.html" 2>&1 | tee export.log; then
    if [ -f "$BUILD_DIR/index.html" ]; then
        echo -e "${GREEN}✅ Export successful!${NC}"
        
        # Deploy to itch.io
        echo ""
        echo "☁️  Deploying to itch.io..."
        if butler push "$BUILD_DIR" "$ITCH_USER/$ITCH_GAME:$ITCH_CHANNEL"; then
            echo -e "${GREEN}✅ Successfully deployed!${NC}"
            echo ""
            echo "🎮 Play at: https://$ITCH_USER.itch.io/$ITCH_GAME"
        else
            echo -e "${RED}❌ Deployment failed${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Export failed - no output generated${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Export command failed${NC}"
    echo ""
    echo "Last 20 lines of export log:"
    tail -20 export.log
    exit 1
fi

# Cleanup
rm -f export_presets_local.cfg export.log