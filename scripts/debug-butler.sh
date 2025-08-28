#!/bin/bash

echo "🔍 Butler API Debug Information"
echo "=============================="

# Load API key
if [ -f ".env" ]; then
    source .env
fi

echo "1. Checking Butler version..."
butler version

echo ""
echo "2. Checking authentication status..."
butler login

echo ""
echo "3. Testing basic API access..."
if butler push --dry-run builds/web downfallgames/test-access 2>&1 | grep -q "Would push"; then
    echo "✅ Basic API access works"
else
    echo "❌ Basic API access failed"
fi

echo ""
echo "4. Testing specific game access..."
echo "Game URL: https://downfallgames.itch.io/the-jar-job"
echo "Butler identifier: downfallgames/the-jar-job"
echo ""

# Try to get more detailed error info
echo "Detailed error output:"
butler status downfallgames/the-jar-job -v 2>&1

echo ""
echo "5. Possible issues:"
echo "   • API key belongs to different account"
echo "   • API key lacks permissions for this game"
echo "   • Game privacy/access restrictions"
echo "   • Account name mismatch"
echo ""
echo "6. Solutions to try:"
echo "   • Log into itch.io web interface and verify account"
echo "   • Generate new API key from the correct account"
echo "   • Check game collaborator permissions"