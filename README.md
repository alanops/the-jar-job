# The Jar Job

A light-hearted stealth game built in Godot 4 for Brackeys Game Jam 2025.2.

## Overview

Sneak into your neighbor's house and steal their precious biscuit jar! Avoid detection by crouching, moving quietly, and staying out of sight. But beware - the neighbor is patrolling and will spot you if you're not careful!

## How to Play

### Controls
- **Arrow Keys** - Move around
- **Ctrl** - Crouch (move slower but quieter)
- **E** - Interact with objects
- **R** - Reset game
- **Escape** - Pause menu

### Objective
1. Sneak into the house
2. Find and steal the biscuit jar
3. Escape through the exit door
4. Don't get spotted!

## Gameplay Features

- **Stealth Mechanics**: Crouch to reduce noise and move more carefully
- **Vision Cones**: NPCs have visible vision cones showing their field of view
- **Sound System**: Walking makes noise that can alert nearby NPCs
- **Isometric Camera**: Fixed 45° angle with automatic wall fading
- **Patrol AI**: NPCs follow waypoint patterns and investigate noises

## Technical Implementation

### Core Systems
- **Player Controller**: CharacterBody3D with walk/crouch states
- **NPC AI**: State machine (Patrol → Investigate → Chase)
- **Vision Detection**: Dot product FOV check + raycast line of sight
- **Wall Fade**: Automatic transparency for walls between camera and player
- **Modular Environment**: Tile-based house construction

### Architecture
- **Game Manager**: Singleton for game state and scoring
- **Scene Structure**: Main menu → Game scene → Win/Lose states
- **UI System**: HUD with timer, alerts, and objective tracking

## Development Notes

This prototype demonstrates the combination of various Godot demo features:
- Navigation system from navigation demos
- Isometric camera setup inspired by 3D demos
- State machine pattern from AI examples
- UI system adapted from GUI demos

## Future Enhancements

- Multiple house layouts
- Distraction items (throw objects)
- Pet NPCs with different behaviors
- Scoring system with multipliers
- Sound effects and music
- Improved art assets

## Credits

Created for Brackeys Game Jam 2025.2
Theme: "Light is the enemy"
Built with Godot 4.3