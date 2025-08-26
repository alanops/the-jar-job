# Second NPC Integration Instructions

This document describes how to add a second security guard to the game.

## Steps

### 1. Add Second NPC Instance
1. Open `scenes/game.tscn` in Godot
2. Find the existing "SecurityGuard" node
3. Instance another `scenes/npc.tscn` 
4. Name it "SecurityGuard2"
5. Set Transform > Position to: X: -3, Y: 0.1, Z: 6

### 2. Add Guard Label
1. Right-click on "SecurityGuard2"
2. Instance `environment/object_label.tscn`
3. Name it "GuardLabel2"
4. Set properties:
   - Label Text: "👮 GUARD 2"
   - Show Distance: 8.0

### 3. Create Patrol Waypoints
1. Create a new Node3D called "PatrolWaypoints2" at root level
2. Add Marker3D children with these positions:
   - Guard2Waypoint1: (3, 0, -3)
   - Guard2Waypoint2: (6, 0, -3)
   - Guard2Waypoint3: (6, 0, 3)
   - Guard2Waypoint4: (3, 0, 6)
   - Guard2Waypoint5: (-3, 0, 6)
   - Guard2Waypoint6: (-3, 0, 3)

### 4. Update game.gd
Add patrol setup for second guard:
```gdscript
# In _ready() after setting up first guard
var security_guard2: NPCController = $SecurityGuard2
if security_guard2:
    var waypoints2: Array[Node3D] = []
    for child in $PatrolWaypoints2.get_children():
        if child is Marker3D:
            waypoints2.append(child)
    security_guard2.patrol_waypoints = waypoints2
```

## Expected Result
- Two guards patrolling different areas
- Guard 1: Main office area
- Guard 2: Kitchen and open space area
- Independent patrol routes