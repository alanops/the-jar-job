#!/bin/bash
set -e

echo "📥 Installing Godot Export Templates"
echo "=================================="

TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz"
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/4.4.1.stable"
TEMP_FILE="/tmp/export_templates.tpz"

# Create directories with proper permissions
echo "📁 Creating directories..."
mkdir -p "$HOME/.local/share/godot/export_templates"
mkdir -p "$HOME/.local/share/godot/app_userdata"

# Download templates if not already present
if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "📥 Downloading export templates..."
    curl -L --progress-bar -o "$TEMP_FILE" "$TEMPLATES_URL"
    
    echo "📦 Extracting templates..."
    cd "$HOME/.local/share/godot/export_templates"
    unzip -q "$TEMP_FILE"
    
    # The zip creates a 'templates' folder, rename it to the version
    if [ -d "templates" ]; then
        mv templates "4.4.1.stable"
    fi
    
    # Cleanup
    rm -f "$TEMP_FILE"
    
    echo "✅ Export templates installed successfully"
else
    echo "✅ Export templates already installed"
fi

# Verify installation
echo ""
echo "📊 Installed templates:"
ls -la "$TEMPLATES_DIR" | head -5

echo ""
echo "✅ Ready for Godot exports!"