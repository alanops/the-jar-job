# Glass Windows Integration Instructions

This document describes how to add glass windows to the office.

## File to modify
- `scenes/game.tscn`

## Glass Window Locations

### Manager's Office Windows
1. **Glass Wall 1**: Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -3, 0, 1)
2. **Glass Wall 2**: Transform3D(-4.37114e-08, 0, 1, 0, 1, 0, -1, 0, -4.37114e-08, -1, 0, 3)

### Top Wall Windows (North side)
Replace some solid walls with glass:
1. **GlassTop1**: Transform3D(-4.37114e-08, 0, 1, 0, 1, 0, -1, 0, -4.37114e-08, 0, 0, -11)
2. **GlassTop2**: Transform3D(-4.37114e-08, 0, 1, 0, 1, 0, -1, 0, -4.37114e-08, 4, 0, -11)

### Right Wall Windows (East side)
Replace some solid walls with glass:
1. **GlassRight1**: Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 11, 0, -4)
2. **GlassRight2**: Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 11, 0, 0)
3. **GlassRight3**: Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 11, 0, 4)

## Steps

1. Open `scenes/game.tscn` in Godot
2. Find the "Office/OuterWalls" node
3. For each glass window position:
   - Instance `environment/glass_window.tscn`
   - Set the transform as specified above
   - Name appropriately (e.g., "GlassTop1", "GlassRight1")

## Manager's Office
1. Find or create "Office/ManagerOffice" node at transform (6, 0, -6)
2. Add glass windows as specified above for a modern office look

## Expected Result
- Transparent blue-tinted glass windows
- Modern office aesthetic
- Natural light coming through windows