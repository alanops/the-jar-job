# Elevator Integration Instructions

This document describes how to add the elevator to the game scene.

## File to modify
- `scenes/game.tscn`

## Steps

1. Open `scenes/game.tscn` in Godot
2. In the scene tree, find the "Office" node
3. Right-click on "Office" and add a new child Node3D
4. Name it "Elevator" 
5. Set its Transform > Position to: X: -9, Y: 0, Z: -9

## Add the elevator scene
1. With the new "Elevator" node selected
2. Click "Instance Child Scene" button (or press Ctrl+Shift+A)
3. Select `environment/elevator.tscn`
4. The elevator should appear at the specified position

## Add the elevator label
1. Right-click on the "Elevator" container node
2. Instance another child scene
3. Select `environment/object_label.tscn`
4. Name it "ElevatorLabel"
5. In the Inspector, set:
   - Label Text: "🔽 LIFT"
   - Show Distance: 6.0

## Save
1. Save the scene (Ctrl+S)
2. The elevator is now integrated!

## Expected result
The elevator should be visible in the back-left corner of the office at position (-9, 0, -9)