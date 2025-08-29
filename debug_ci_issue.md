# CI Debug Analysis

## The Problem

The CI is failing/hanging because:

1. **Blender files in the project** - Even though you removed textures from the .blend files, Godot still tries to import them in headless mode
2. **Headless import is strict** - Any material/texture issues cause hard failures in CI that don't happen locally

## Quick Test

Run this to see the issue:
```bash
# This will fail with texture errors
godot --headless --quit

# Check what happens during import
ls -la .godot/imported/ | grep blend
```

## Solutions

### Option 1: Remove Blender Files (Quick Fix)
```bash
# Remove the blend files that are causing issues
git rm models/floor.blend models/floor.blend1 models/floorplan.blend models/floorplan.blend1
git commit -m "Remove problematic Blender files"
git push
```

### Option 2: Use Pre-Exported GLB Files
```bash
# In Blender:
# 1. Open floor.blend
# 2. File > Export > glTF 2.0 (.glb)
# 3. Settings:
#    - Format: glTF Binary
#    - Include > Materials: ✓
#    - Include > Images: ✗ (unchecked - no textures)
# 4. Save as floor.glb
# 5. Repeat for floorplan.blend
# 6. Update your scenes to use the .glb files instead
```

### Option 3: Exclude Models from Export
Update export_presets.cfg:
```
exclude_filter="models/*,.godot/*,*.blend,*.blend1"
```

## Why Local Works but CI Doesn't

- **Local Godot GUI**: Handles missing textures gracefully, shows warnings
- **Headless Godot (CI)**: Crashes on texture loading errors with "Parameter 't' is null"
- **The issue**: Your .blend files have material nodes that reference textures, even if the textures are deleted

## Recommended Fix

The fastest solution is Option 1 - remove the .blend files since they're not needed for the web export.