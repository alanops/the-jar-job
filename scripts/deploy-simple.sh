#!/bin/bash
set -e

echo "🚀 Simple Local Deployment (No Templates Required)"
echo "================================================"

# Configuration
ITCH_USER="downfallgames"
ITCH_GAME="the-jar-job"
ITCH_CHANNEL="html5"
BUILD_DIR="builds/web"

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

# Export API key for Butler to use
export BUTLER_API_KEY

# Check Butler
if ! command -v butler &> /dev/null; then
    echo -e "${RED}❌ Butler not installed${NC}"
    exit 1
fi

echo "📋 Prerequisites OK"

# Create a minimal HTML5 build manually for testing
echo ""
echo "📦 Creating minimal test build..."
mkdir -p "$BUILD_DIR"

cat > "$BUILD_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>The Jar Job - Coming Soon</title>
    <style>
        body {
            margin: 0;
            background: #222;
            color: #fff;
            font-family: Arial, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            text-align: center;
        }
        .container {
            max-width: 600px;
            padding: 2rem;
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
            color: #4a9eff;
        }
        p {
            font-size: 1.2rem;
            line-height: 1.6;
            margin-bottom: 2rem;
        }
        .status {
            background: #333;
            padding: 1rem;
            border-radius: 8px;
            margin: 1rem 0;
        }
        .working { color: #4CAF50; }
        .issue { color: #ff9800; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🫙 The Jar Job</h1>
        <p>A stealth game where <strong>light is the enemy</strong>.</p>
        
        <div class="status">
            <h3 class="working">✅ Local Deployment: Working</h3>
            <p>This page confirms the deployment pipeline is functional.</p>
        </div>
        
        <div class="status">
            <h3 class="issue">🔧 Game Build: In Progress</h3>
            <p>Full Godot build coming soon once export templates are configured.</p>
        </div>
        
        <p><em>Stay tuned for the complete game experience!</em></p>
        <p><small>Deployed via local pipeline • $(date)</small></p>
    </div>
</body>
</html>
EOF

echo -e "${GREEN}✅ Test build created${NC}"

# Deploy to itch.io
echo ""
echo "☁️  Deploying to itch.io..."
if butler push "$BUILD_DIR" "$ITCH_USER/$ITCH_GAME:$ITCH_CHANNEL"; then
    echo -e "${GREEN}✅ Successfully deployed!${NC}"
    echo ""
    echo "🎮 View at: https://$ITCH_USER.itch.io/$ITCH_GAME"
    echo ""
    echo "This confirms the deployment pipeline works."
    echo "Next: Install Godot export templates for full game deployment."
else
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
fi