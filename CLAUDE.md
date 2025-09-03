# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

"The Jar Job" is a 3D stealth game built with Godot 4.4 for the Brackeys Game Jam 2025.2. The theme "Light is the enemy" is implemented through stealth mechanics where players must avoid detection while attempting to steal biscuits.

## Essential Commands

### Godot Development
```bash
# Open project in Godot editor
godot --editor

# Run the game directly
godot

# Test export locally (validates build integrity)
./scripts/test-export.sh

# Setup deployment prerequisites (Butler CLI + export templates)
./scripts/setup-butler.sh
./scripts/install-export-templates.sh

# Deploy to itch.io (full deployment pipeline)
./scripts/deploy-local.sh

# Simple deployment (requires prerequisites installed)
./scripts/deploy-itch.sh

# Test CI environment locally
./scripts/test-ci-locally.sh
```

### Game Controls
- **Arrow Keys / WASD**: Movement (camera-relative)
- **Ctrl**: Crouch (quieter movement)
- **E**: Interact with objects
- **R**: Reset level
- **Tab**: Toggle camera view (Top Down → Isometric → First Person)
- **Escape**: Pause menu

## Architecture Overview

### Project Structure
- `/assets/` - Audio, fonts, and sprites
- `/builds/` - Export outputs (web builds)
- `/environment/` - Modular level pieces (walls, floors, furniture)
- `/objects/` - Interactive objects (biscuit jar)
- `/scenes/` - Main game scenes and prefabs
- `/scripts/` - GDScript game logic
- `/ui/` - User interface scenes

### Core Systems

#### 1. Stealth Mechanics
- **Sound System**: Walking creates noise radius, crouching reduces it
- **Vision Cones**: NPCs use raycasting for optimized field-of-view detection
- **Detection States**: Patrol → Investigate → Chase state machine

#### 2. Singleton Architecture
Nine autoloaded singletons provide core system services:
- `DebugLogger` - Centralized logging with file output
- `GameConfig` - Game configuration management  
- `VisionSystem` - NPC vision and detection system
- `PerformanceOptimizer` - Runtime performance optimization
- `ErrorHandler` - Global error handling and recovery
- `GameManager` - Core game state and scene transitions
- `ObjectiveManager` - Mission and objective tracking
- `NPCCommunication` - Inter-NPC communication system
- `AudioManager` - Multi-bus audio system with persistent settings

#### 3. NPC AI System
- Waypoint-based patrol system
- Sound investigation behavior
- Directional arrow indicators
- Optimized vision cone detection

#### 4. Camera System
- **Triple Camera Views**: Top Down, Isometric, and First Person perspectives
- **Top Down View**: Perfect strategic overview, 90° straight vertical angle
- **Isometric View**: Classic 30° angle inspired by Theme Hospital
- **First Person View**: Immersive perspective from player's eye level (1.6m height)
- **Toggle System**: Tab key cycles through all three perspectives
- **Camera-Relative Movement**: Player controls automatically adjust to camera orientation
- **Mixed Projection**: Orthogonal for top-down/isometric, perspective for first person
- **Wall Fading**: Dynamic transparency for objects blocking player view (disabled in first person)

#### 5. Audio System
- **AudioManager Singleton**: Centralized audio control with automatic initialization
- **Multi-Bus Architecture**: Separate audio buses for Music, Ambient, SFX, and UI sounds
- **Contextual Audio**: Different sounds for walking/crouching, detection states
- **Persistent Settings**: Audio preferences saved to user configuration
- **Detailed Documentation**: See [Audio System Documentation](docs/AUDIO_SYSTEM.md)

#### 6. Performance Features
- Advanced performance monitoring system
- Auto-occluder setup for optimization
- LOD (Level of Detail) configuration
- Occlusion culling enabled

### Deployment Pipeline
- GitHub Actions workflow on push to main or version tags
- Automated web export using Godot 4.4.1 headless
- Butler CLI integration for itch.io deployment
- Version extracted from `project.godot`

## Key Implementation Details

### Audio System

The game features a comprehensive audio system built around the `AudioManager` singleton. For complete documentation including API reference, integration points, and technical specifications, see [docs/AUDIO_SYSTEM.md](docs/AUDIO_SYSTEM.md).

### Scene Flow
1. Main Menu (`ui/main_menu.tscn`)
2. Game Scene (`scenes/game.tscn`)
3. Win/Lose screens with retry options

### Player Controller
- State-based movement (walk/crouch)
- Interaction system for objects
- Camera with wall transparency

### Environment System
- Modular tile-based construction
- Reusable environment pieces
- GridMap integration

## Development Guidelines

### Working with Godot
1. Use Godot 4.4+ for compatibility
2. Export presets are pre-configured for web builds
3. Test web builds locally before deployment
4. Use the performance monitor for optimization

### Code Standards
- Follow GDScript style guide
- Use typed variables where possible
- Implement proper state machines for complex behaviors
- Keep scenes modular and reusable

### Version Management
- Current version: 0.2.0 (stored in `project.godot` under `config/version`)
- Use semantic versioning for releases
- Tag releases with `v` prefix for CI/CD

## Troubleshooting

### Common Issues
- **Export fails**: Run `./scripts/install-export-templates.sh` to get Godot 4.4.1 templates
- **Butler not found**: Run `./scripts/setup-butler.sh` to install itch.io CLI
- **Build validation**: Use `./scripts/test-export.sh` to check export integrity
- **CI debugging**: Run `./scripts/test-ci-locally.sh` to simulate deployment environment
- **Performance issues**: Check PerformanceOptimizer singleton and built-in profiler

### Development Tips
- Use the built-in performance tools for optimization
- Test stealth mechanics with different patrol patterns
- Verify sound radius visually in editor
- Check vision cone debug visualization

## Important Notes

- Project uses Godot 4.4 engine (not compatible with 3.x)
- Web export is the primary distribution method
- Deployed to https://downfallgames.itch.io/jar-job
- No external dependencies beyond Godot engine
- Performance optimizations are critical for web builds