# Wayfinder System Integration Instructions

This document describes how to integrate the wayfinder system (minimap, objectives, waypoint indicator).

## Files to modify
- `scenes/game.tscn`
- `project.godot` (for autoloads)

## Step 1: Add Autoload
In Project Settings > Autoload:
- Add `scripts/objective_manager.gd` as "ObjectiveManager"

## Step 2: Add UI Elements to Game Scene

### Add to GameUI node:
1. Instance `ui/minimap.tscn` as child of GameUI
2. Instance `ui/objectives_panel.tscn` as child of GameUI  
3. Instance `ui/waypoint_indicator.tscn` as child of GameUI

### Position the UI elements:
- **Minimap**: Top-right corner
- **Objectives Panel**: Left side
- **Waypoint Indicator**: Center of screen

## Step 3: Connect in game.gd

Add to _ready():
```gdscript
# Initialize objectives
ObjectiveManager.add_objective("Find the biscuit jar", $BiscuitJar.global_position)
ObjectiveManager.add_objective("Escape through the lift", $ExitElevator.global_position)
```

## Expected Features
- Minimap showing top-down view
- Objective list with checkmarks
- Directional arrow pointing to current objective
- Dynamic objective tracking

## Test plan
- [ ] Minimap appears in top-right
- [ ] Objectives list shows on left
- [ ] Waypoint arrow points to jar
- [ ] Collecting jar updates objectives
- [ ] Arrow then points to exit