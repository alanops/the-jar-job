#!/bin/bash
set -e

echo "🔧 Fixing Godot Permissions and Setup"
echo "====================================="

# Try to create the directories with different approaches
GODOT_DIR="$HOME/.local/share/godot"
TEMPLATES_DIR="$GODOT_DIR/export_templates/4.4.1.stable"

echo "1. Creating Godot directories..."

# Method 1: Try direct creation
if mkdir -p "$GODOT_DIR/app_userdata" "$TEMPLATES_DIR" 2>/dev/null; then
    echo "✅ Directories created successfully"
else
    echo "⚠️  Permission issues detected. Trying alternative approaches..."
    
    # Method 2: Check if parent directories exist
    if [ ! -d "$HOME/.local" ]; then
        mkdir -p "$HOME/.local"
    fi
    
    if [ ! -d "$HOME/.local/share" ]; then
        mkdir -p "$HOME/.local/share"
    fi
    
    # Try creating godot directory
    if [ ! -d "$GODOT_DIR" ]; then
        mkdir "$GODOT_DIR" || {
            echo "❌ Cannot create $GODOT_DIR"
            echo "   Run: chmod 755 $HOME/.local/share"
            exit 1
        }
    fi
    
    # Create subdirectories
    mkdir -p "$GODOT_DIR/app_userdata" || echo "⚠️  Could not create app_userdata"
    mkdir -p "$TEMPLATES_DIR" || echo "⚠️  Could not create templates dir"
fi

echo ""
echo "2. Checking directory permissions..."
ls -la "$HOME/.local/share/" | grep godot || echo "No godot directory found"

echo ""
echo "3. Downloading and installing export templates..."

TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz"
TEMP_FILE="/tmp/godot_templates.tpz"

if [ ! -f "$TEMPLATES_DIR/web_nothreads_release.zip" ]; then
    echo "📥 Downloading templates (this may take a moment)..."
    
    if curl -L --progress-bar -o "$TEMP_FILE" "$TEMPLATES_URL"; then
        echo "📦 Extracting templates..."
        
        # Extract to temp location first
        TEMP_EXTRACT="/tmp/godot_templates_extract"
        mkdir -p "$TEMP_EXTRACT"
        
        if unzip -q "$TEMP_FILE" -d "$TEMP_EXTRACT"; then
            # Move templates to correct location
            if [ -d "$TEMP_EXTRACT/templates" ]; then
                if [ -w "$GODOT_DIR/export_templates" ]; then
                    mv "$TEMP_EXTRACT/templates"/* "$TEMPLATES_DIR/" 2>/dev/null || {
                        cp -r "$TEMP_EXTRACT/templates"/* "$TEMPLATES_DIR/"
                    }
                    echo "✅ Templates installed successfully"
                else
                    echo "❌ Cannot write to templates directory"
                    echo "   Check permissions on $GODOT_DIR/export_templates"
                fi
            else
                echo "❌ Unexpected template archive structure"
            fi
        else
            echo "❌ Failed to extract templates"
        fi
        
        # Cleanup
        rm -rf "$TEMP_FILE" "$TEMP_EXTRACT"
    else
        echo "❌ Failed to download templates"
        echo "   URL: $TEMPLATES_URL"
    fi
else
    echo "✅ Export templates already present"
fi

echo ""
echo "4. Verification..."
if [ -f "$TEMPLATES_DIR/web_nothreads_release.zip" ]; then
    echo "✅ Web export templates found"
    ls -la "$TEMPLATES_DIR" | grep web
else
    echo "❌ Web export templates missing"
    echo "   Expected: $TEMPLATES_DIR/web_nothreads_release.zip"
fi

echo ""
echo "5. Testing Godot access..."
if godot --version &>/dev/null; then
    echo "✅ Godot executable found"
    
    # Try a quick project scan test
    echo "🧪 Testing project access..."
    if timeout 10 godot --headless --quit &>/dev/null; then
        echo "✅ Godot can access project"
    else
        echo "⚠️  Godot project access test inconclusive"
    fi
else
    echo "❌ Godot not found in PATH"
fi

echo ""
echo "Setup complete! Try running the deployment script again."