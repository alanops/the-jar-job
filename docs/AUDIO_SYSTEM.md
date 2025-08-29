# Audio System Documentation

## Overview

"The Jar Job" features a comprehensive audio system built around the `AudioManager` singleton. This system provides immersive audio feedback for stealth gameplay, environmental atmosphere, and user interactions.

## Architecture

### AudioManager Singleton

The `AudioManager` (`scripts/audio_manager.gd`) serves as the central audio controller, automatically initializing on game start as an autoload singleton. It manages all audio playback, volume control, and audio resource loading.

### Audio Bus Configuration

The system uses four separate audio buses for optimal mixing and individual volume control:

```gdscript
# Four separate audio buses for optimal mixing
music_player.bus = "Music"      # Background music
ambient_player.bus = "Ambient"  # Environmental sounds
sfx_player.bus = "SFX"         # Game sound effects
ui_player.bus = "UI"           # User interface sounds
```

Each bus can be controlled independently while respecting the master volume setting.

## Audio Categories

### Background Music
- **File**: `background_music.ogg`
- **Function**: Continuous atmospheric music during gameplay
- **Features**:
  - Fade in/out capabilities for smooth transitions
  - Automatically stops during game over sequences
  - Default Volume: 60% of master volume
  - Looping: Manual control via play/stop functions

**Usage**:
```gdscript
AudioManager.play_background_music()
AudioManager.fade_music_in(2.0)  # 2 second fade in
AudioManager.fade_music_out(1.5) # 1.5 second fade out
```

### Ambient Sounds
- **File**: `ambient.ogg`
- **Function**: Continuous environmental audio
- **Features**:
  - Automatic looping when started
  - Default Volume: 40% of master volume
  - Starts automatically when AudioManager initializes

**Usage**:
```gdscript
AudioManager.play_ambient()
AudioManager.stop_ambient()
```

### Sound Effects (SFX)
Interactive and contextual sound effects that respond to gameplay events:

#### Player Movement Audio
- **File**: `footstep.ogg`
- **Trigger**: Player movement with volume modification based on movement type
- **Volume Modifiers**:
  - Crouching: 30% volume (quieter)
  - Walking: 100% volume (normal)
  - Running: 120% volume (louder)

#### Detection and Alert Audio
- **Files**: `detected.ogg`, `alert.ogg`
- **Usage**: NPC detection system feedback
- **Integration**: Connected to NPC state machine transitions

#### Interaction Audio
- **Files**: 
  - `item_pickup.ogg` - Item collection feedback
  - `door.ogg` - Interaction with doors/elevators
  - `victory.ogg` - Success state audio

### User Interface Sounds
- **File**: `button_click.ogg`
- **Usage**: Menu navigation and button presses
- **Bus**: Separate UI bus for independent volume control

## Integration Points

### Player Controller Integration
Location: `player_controller.gd:164`

The footstep system automatically adjusts audio based on player state:

```gdscript
func _on_footstep() -> void:
    if velocity.length() > 0.1:
        made_noise.emit(global_position, current_noise_radius)
        
        if AudioManager:
            var volume_modifier = 1.0
            if is_crouching:
                volume_modifier = 0.3  # Quieter when crouching
            elif is_running:
                volume_modifier = 1.2  # Louder when running
            
            AudioManager.play_footstep()
```

### Game Manager Integration
- **Victory Sequences**: Automatic music fade-out followed by victory sound
- **Game Over**: All audio stops, replaced with detection/game over audio
- **Scene Transitions**: Coordinated audio state management

### NPC System Integration
- **Alert States**: Audio feedback when NPCs enter different detection states
- **Communication**: Audio cues for NPC-to-NPC communication events
- **Investigation**: Sound effects for NPC investigation behaviors

### UI System Integration
- **Menu Navigation**: Button click audio for all interactive elements
- **Settings**: Real-time audio settings with immediate feedback
- **Volume Sliders**: Live volume adjustment during gameplay

## Technical Specifications

### File Format Requirements
- **Format**: OGG Vorbis (`.ogg` files)
- **Location**: `/assets/audio/` directory
- **Loading**: Automatic loading via `load_audio_resources()` function
- **Web Compatibility**: Optimized compression settings for web builds

### Volume Control System

#### Master Volume Control
Global audio level that affects all categories:
```gdscript
AudioManager.set_master_volume(0.8) # 80% master volume
```

#### Category-Specific Volume
Individual control for each audio category:
```gdscript
AudioManager.set_music_volume(0.6)   # Music at 60%
AudioManager.set_sfx_volume(0.8)     # SFX at 80%
AudioManager.set_ambient_volume(0.4) # Ambient at 40%
```

#### Volume Calculation
Final volume = Master Volume × Category Volume
```gdscript
final_volume_db = linear_to_db(master_volume * category_volume)
```

### Persistent Settings

Audio preferences are automatically saved and restored:
- **Save Location**: `user://audio_settings.cfg`
- **Auto-Save**: Settings saved when changed
- **Auto-Load**: Settings loaded on AudioManager initialization
- **Format**: Godot ConfigFile format

```gdscript
# Example settings file structure
[audio]
master_volume=0.8
music_volume=0.6
sfx_volume=0.8
ambient_volume=0.4
```

## API Reference

### Core Functions

#### Music Control
```gdscript
AudioManager.play_background_music()
AudioManager.stop_background_music()
AudioManager.fade_music_in(duration: float = 2.0)
AudioManager.fade_music_out(duration: float = 2.0)
```

#### Ambient Control
```gdscript
AudioManager.play_ambient()
AudioManager.stop_ambient()
```

#### Sound Effects
```gdscript
AudioManager.play_footstep()
AudioManager.play_button_click()
AudioManager.play_door_sound()
AudioManager.play_item_pickup()
AudioManager.play_victory()
AudioManager.play_alert()
AudioManager.play_detected()
AudioManager.play_game_over()
```

#### Volume Control
```gdscript
AudioManager.set_master_volume(volume: float)
AudioManager.set_music_volume(volume: float)
AudioManager.set_sfx_volume(volume: float)
AudioManager.set_ambient_volume(volume: float)
```

#### Settings Management
```gdscript
AudioManager.save_audio_settings()
AudioManager.load_audio_settings()
```

#### System Control
```gdscript
AudioManager.stop_all_audio()  # Emergency stop for all audio
```

## Audio Library Structure

```
assets/audio/
├── background_music.ogg    # Main game music
├── ambient.ogg            # Environmental sounds
├── footstep.ogg           # Player movement
├── button_click.ogg       # UI interactions
├── door.ogg               # Door/elevator sounds
├── item_pickup.ogg        # Item collection
├── victory.ogg            # Success audio
├── alert.ogg              # NPC alert states
└── detected.ogg           # Detection/game over
```

## Performance Considerations

### Memory Management
- Audio files loaded once at initialization
- Shared AudioStreamPlayer instances for each category
- Automatic garbage collection of temporary audio tweens

### Web Build Optimization
- OGG Vorbis format chosen for web compatibility
- Compressed audio files to minimize download size
- Streaming audio for larger files (background music)

### CPU Optimization
- Single AudioManager instance prevents multiple audio system overhead
- Efficient volume calculation using linear_to_db conversion
- Minimal audio processing during gameplay

## Troubleshooting

### Common Issues

**Audio Not Playing**
- Verify audio files exist in `/assets/audio/`
- Check that AudioManager is properly initialized as singleton
- Ensure audio bus configuration matches AudioManager setup

**Volume Issues**
- Check master volume isn't set to 0
- Verify category-specific volumes are audible levels
- Test with `AudioManager.set_master_volume(1.0)` for debugging

**Performance Issues**
- Monitor audio player count in performance monitor
- Verify audio files are properly compressed for web builds
- Check for audio loading errors in console output

### Debug Commands
```gdscript
# Test audio system
AudioManager.play_footstep()  # Test SFX
AudioManager.set_master_volume(1.0)  # Max volume test
print(AudioManager.master_volume)  # Check volume setting
```

## Future Enhancements

### Planned Features
- **Spatial Audio**: 3D positioned audio for enhanced immersion
- **Audio Occlusion**: Sound dampening through walls
- **Dynamic Music**: Interactive music that responds to gameplay tension
- **Audio Mixing**: Real-time audio effects based on environment
- **Voice Acting**: Character dialogue and narrative audio