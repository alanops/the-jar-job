#!/bin/bash

# Deployment script for itch.io
# Usage: ./scripts/deploy-itch.sh

set -e

PROJECT_NAME="the-jar-job"
ITCH_USER="downfallgames"
BUILD_DIR="builds/web"
GODOT_EXPORT_TEMPLATE="Web"

echo "🚀 Starting deployment to itch.io..."

# Check if butler is installed
if ! command -v butler &> /dev/null; then
    echo "❌ Butler (itch.io CLI) is not installed."
    echo "📥 Install from: https://itch.io/docs/butler/"
    echo "Or run: curl -L -o butler.zip https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default && unzip butler.zip"
    exit 1
fi

# Check if logged into butler
if ! butler status &> /dev/null; then
    echo "❌ Not logged into butler. Run: butler login"
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Export with Godot (headless)
echo "🔨 Exporting game with Godot..."
if command -v godot &> /dev/null; then
    godot --headless --export-release "$GODOT_EXPORT_TEMPLATE" "$BUILD_DIR/index.html"
elif command -v godot4 &> /dev/null; then
    godot4 --headless --export-release "$GODOT_EXPORT_TEMPLATE" "$BUILD_DIR/index.html"
else
    echo "❌ Godot not found in PATH. Please export manually or install Godot CLI."
    echo "Manual export: Project > Export > HTML5 > Export Project"
    exit 1
fi

# Check if export was successful
if [ ! -f "$BUILD_DIR/index.html" ]; then
    echo "❌ Export failed - index.html not found"
    exit 1
fi

# Get version from project.godot
VERSION=$(grep 'config/version=' project.godot | cut -d'"' -f2)
if [ -z "$VERSION" ]; then
    VERSION="0.1.0"
fi

echo "📦 Deploying version $VERSION to itch.io..."

# Push to itch.io
butler push "$BUILD_DIR" "$ITCH_USER/$PROJECT_NAME:html5" --userversion "$VERSION"

echo "✅ Deployment complete!"
echo "🌐 Play at: https://downfallgames.itch.io/$PROJECT_NAME"