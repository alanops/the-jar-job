# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

"The Jar Job" is a 3D stealth game built with Godot 4.4 for the Brackeys Game Jam 2025.2. The theme "Light is the enemy" is implemented through stealth mechanics where players must avoid detection while attempting to steal biscuits.

## Essential Commands

### Godot Development
```bash
# Open project in Godot editor
godot --editor

# Build for web export (headless)
godot --headless --export-release "Web" builds/web/index.html

# Run the game directly
godot

# Deploy to itch.io (requires Butler CLI)
./scripts/deploy-itch.sh
```

### Game Controls
- **Arrow Keys**: Movement
- **Ctrl**: Crouch (quieter movement)
- **E**: Interact with objects
- **R**: Reset level
- **Tab**: Toggle camera view (High Angle ↔ Medium Angle)
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
- `GameManager` (autoload) handles global game state
- Manages scene transitions and win/lose conditions

#### 3. NPC AI System
- Waypoint-based patrol system
- Sound investigation behavior
- Directional arrow indicators
- Optimized vision cone detection

#### 4. Camera System
- **Dual Camera Views**: High Angle (60° pitch) and Medium Angle (35° pitch) 
- **Toggle System**: Tab key switches between views for better depth perception
- **Camera-Relative Movement**: Player controls automatically adjust to camera orientation
- **Orthogonal Projection**: Maintains isometric top-down feel
- **Wall Fading**: Dynamic transparency for objects blocking player view

#### 5. Audio System
- **AudioManager Singleton**: Centralized audio control with automatic initialization
- **Multi-Bus Architecture**: Separate audio buses for Music, Ambient, SFX, and UI sounds
- **Dynamic Volume Control**: Individual volume controls with master volume override
- **Audio Categories**:
  - Background music with fade in/out capabilities
  - Ambient environmental sounds (looping)
  - Sound effects (footsteps, interactions, alerts)
  - UI sounds (button clicks, menu navigation)
- **Contextual Audio**: Different sounds for walking/crouching, detection states
- **Audio Library Integration**: Supports OGG Vorbis format from `/assets/audio/`
- **Persistent Settings**: Audio preferences saved to user configuration

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

### Audio System Architecture

The game uses a comprehensive audio system built around the `AudioManager` singleton (`scripts/audio_manager.gd`). This system provides:

#### Audio Bus Configuration
```gdscript
# Four separate audio buses for optimal mixing
music_player.bus = "Music"      # Background music
ambient_player.bus = "Ambient"  # Environmental sounds
sfx_player.bus = "SFX"         # Game sound effects
ui_player.bus = "UI"           # User interface sounds
```

#### Audio Categories and Usage
- **Background Music** (`background_music.ogg`)
  - Fade in/out capabilities for smooth transitions
  - Automatically stops during game over sequences
  - Volume: 60% of master by default
  
- **Ambient Sounds** (`ambient.ogg`)
  - Continuous environmental audio
  - Loops automatically when started
  - Volume: 40% of master by default
  
- **Sound Effects**
  - `footstep.ogg` - Triggered by player movement with volume based on movement type
  - `detected.ogg` - Played when NPCs spot the player
  - `alert.ogg` - Warning sounds for heightened security states
  - `item_pickup.ogg` - Item collection feedback
  - `victory.ogg` - Success state audio
  - `door.ogg` - Interaction with doors/elevators
  
- **UI Sounds**
  - `button_click.ogg` - Menu navigation and button presses

#### Integration Points
- **Player Controller** (`player_controller.gd:164`): Footstep audio with contextual volume
  ```gdscript
  var volume_modifier = 1.0
  if is_crouching:
      volume_modifier = 0.3  # Quieter when crouching
  elif is_running:
      volume_modifier = 1.2  # Louder when running
  ```
  
- **Game Manager**: Victory and game over audio sequences
- **NPC System**: Alert and detection audio feedback
- **UI System**: Button click audio for all interactive elements

#### Audio File Requirements
- Format: OGG Vorbis (`.ogg` files)
- Location: `/assets/audio/` directory
- Automatic loading via `load_audio_resources()` function
- Web-compatible compression settings

#### Volume Control System
- **Master Volume**: Global audio level control
- **Category Volumes**: Individual control for Music, SFX, and Ambient
- **Persistent Settings**: Audio preferences saved to `user://audio_settings.cfg`
- **Dynamic Adjustment**: Volume can be changed during gameplay

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
- Version stored in `project.godot` under `config/version`
- Use semantic versioning (e.g., 1.4.2)
- Tag releases with `v` prefix for CI/CD

## Troubleshooting

### Common Issues
- **Export fails**: Ensure Godot 4.4+ is installed
- **Butler not found**: Install from https://itch.io/docs/butler/
- **Performance issues**: Check performance monitor and profiler
- **Web build problems**: Test in multiple browsers

### Development Tips
- Use the built-in performance tools for optimization
- Test stealth mechanics with different patrol patterns
- Verify sound radius visually in editor
- Check vision cone debug visualization

## Important Notes

- Project uses Godot 4.4 engine (not compatible with 3.x)
- Web export is the primary distribution method
- Deployed to https://downfallgames.itch.io/the-jar-job
- No external dependencies beyond Godot engine
- Performance optimizations are critical for web builds