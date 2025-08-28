#!/bin/bash
set -e

echo "🔧 Butler Setup for itch.io Deployment"
echo "====================================="

# Check if butler already exists
if command -v butler &> /dev/null; then
    echo "✅ Butler is already installed"
    butler version
    exit 0
fi

echo "📥 Downloading Butler..."

# Create local bin directory
mkdir -p ~/bin

# Download Butler
cd /tmp
curl -L -o butler.zip https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default
unzip -o butler.zip
chmod +x butler

# Move to local bin
mv butler ~/bin/

# Add to PATH if not already there
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo ""
    echo "📝 Adding ~/bin to PATH..."
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    echo ""
    echo "⚠️  Please run: source ~/.bashrc"
    echo "   Or restart your terminal for PATH changes to take effect"
fi

# Cleanup
rm -f butler.zip

echo ""
echo "✅ Butler installed successfully!"
echo ""
echo "Next steps:"
echo "1. Run: source ~/.bashrc (or restart terminal)"
echo "2. Run: butler login"
echo "3. Then use ./scripts/deploy-local.sh to deploy"