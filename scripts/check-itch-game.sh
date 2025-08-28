#!/bin/bash

echo "🔍 Checking itch.io game configuration..."
echo ""

# Load API key
if [ -f ".env" ]; then
    source .env
fi

# Test different possible game names
POSSIBLE_GAMES=(
    "downfallgames/the-jar-job"
    "downfallgames/jar-job"
    "downfallgames/thejarjob"
    "alanops/the-jar-job"
    "alanops/jar-job"
    "alanops/thejarjob"
)

echo "Testing possible game identifiers..."

for game in "${POSSIBLE_GAMES[@]}"; do
    echo -n "Testing $game... "
    if butler status "$game" &> /dev/null; then
        echo "✅ FOUND!"
        echo ""
        echo "✅ Working game identifier: $game"
        butler status "$game"
        exit 0
    else
        echo "❌ Not found"
    fi
done

echo ""
echo "❌ No matching games found."
echo ""
echo "Possible solutions:"
echo "1. Create the game on itch.io first at: https://itch.io/game/new"
echo "2. Use the exact game name from your itch.io dashboard"
echo "3. Check if you're using the correct itch.io account"
echo ""
echo "Game URL format: https://USERNAME.itch.io/GAME_NAME"
echo "Butler format: USERNAME/GAME_NAME"