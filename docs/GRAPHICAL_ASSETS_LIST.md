# Graphical Assets List - The Jar Job

This document provides a comprehensive list of all graphical assets required for "The Jar Job" stealth game.

## 3D Models

### Characters
- **Player Character**
  - Full body humanoid model
  - Rigged for walking/crouching animations
  - Business casual attire (office worker)
  
- **NPC Security Guards** (3 variations)
  - Standard security guard uniform
  - Rigged for walking/idle animations
  - Flashlight attachment point
  
- **Boss NPC**
  - Business suit attire
  - More imposing stature
  - Red color theme
  
- **Admin Officer NPC**
  - Administrative/manager attire
  - Blue color theme
  - Clipboard or tablet accessory
  
- **Angry Coworker NPC**
  - Casual office wear
  - Yellow/orange color theme
  - Disheveled appearance

### Environment - Modular Pieces
- **Walls**
  - Standard office wall sections
  - Wall with window variant
  - Wall with door frame
  - Corner pieces (inner/outer)
  
- **Floors**
  - Office carpet tiles
  - Kitchen/break room tile
  - Elevator floor
  
- **Doors**
  - Standard office door
  - Glass door variant
  - Elevator doors (animated)
  - Exit/emergency door

### Furniture & Props
- **Office Furniture**
  - Office desks (multiple styles)
  - Office chairs (swivel)
  - Conference table
  - Conference chairs
  - Filing cabinets
  - Cubicle dividers
  
- **Electronics**
  - Computer monitors
  - Keyboards
  - Desktop towers
  - Printers/copiers
  
- **Break Room**
  - Kitchen counter
  - Refrigerator
  - Microwave
  - Coffee machine
  - Water cooler
  
- **Decorative**
  - Office plants (3-4 varieties)
  - Wall clocks
  - Picture frames
  - Bulletin boards
  - Trash bins

### Interactive Objects
- **Primary Objective**
  - Biscuit jar (glass/ceramic)
  - Jar lid (separate for animation)
  
- **Collectibles**
  - Biscuit cookies (5 variations)
  - Coffee cups (common secret)
  - USB drives (rare secret)
  - Golden stapler (legendary secret)

## Textures

### Material Textures
- **Floor Textures**
  - Office carpet (neutral gray/blue)
  - Kitchen tiles (white/checkered)
  - Elevator floor (metallic/rubber)
  
- **Wall Textures**
  - Office wall (off-white/beige)
  - Glass (for windows/doors)
  - Metal (for elevator/fixtures)
  
- **Furniture Textures**
  - Wood grain (desks/tables)
  - Fabric (office chairs)
  - Metal (filing cabinets)
  - Plastic (electronics)

### Special Effect Textures
- **Vision Cone**
  - Semi-transparent gradient
  - Red alert state variant
  - Yellow suspicious state variant
  
- **Noise Radius**
  - Circular gradient rings
  - Different colors for walk/run/crouch

## UI Elements

### HUD Components
- **Timer Display**
  - Digital clock style numbers
  - Background panel
  
- **Objective Tracker**
  - Checkbox icons
  - Text background panel
  
- **Interaction Prompt**
  - "Press E" icon
  - Circular background
  
- **Detection Indicator**
  - Eye icon
  - Progress bar fill
  - Alert states (white/yellow/red)

### Menu Screens
- **Main Menu**
  - Game logo/title
  - Button backgrounds
  - Menu background image
  
- **Pause Menu**
  - Semi-transparent overlay
  - Button styles
  
- **Game Over Screen**
  - "CAUGHT!" text styling
  - Retry button
  - Menu button
  
- **Victory Screen**
  - "SUCCESS!" text styling
  - Score display elements
  - Star rating icons
  
- **Stats Screen**
  - Panel backgrounds
  - Icon set for different stats
  - Progress bars

### Debug UI
- **Performance Monitor**
  - Graph backgrounds
  - FPS counter styling
  
- **Debug Console**
  - Console background
  - Text formatting

## Particle Effects & VFX

### Environmental Effects
- **Lighting**
  - Flashlight cone effect
  - Office lighting (fluorescent)
  - Emergency exit signs (green glow)
  
- **Collectible Effects**
  - Sparkle/shine particles
  - Collection burst effect
  - Floating animation

### Gameplay Feedback
- **Detection Effects**
  - Exclamation mark (!)
  - Question mark (?)
  - Alert rings/pulses
  
- **Sound Visualization**
  - Ripple effects for footsteps
  - Noise radius indicators

## Animations

### Character Animations
- **Player**
  - Walk cycle
  - Crouch walk
  - Idle stance
  - Interaction (reaching)
  
- **NPCs**
  - Walk cycle
  - Idle/standing
  - Turn animations
  - Alert/searching poses

### Object Animations
- **Doors**
  - Open/close
  - Locked jiggle
  
- **Collectibles**
  - Floating bob
  - Rotation idle
  - Collection disappear
  
- **Elevator**
  - Doors open/close
  - Floor indicator

## Icons & Symbols

### Game Icons
- Application icon (multiple resolutions)
- Achievement badges
- Collectible type icons

### In-Game Symbols
- Direction arrows (for NPCs)
- Interaction symbols
- Warning/alert icons
- Camera view mode icons

## Color Palette Requirements

### Primary Colors
- **Stealth Blue** - Main UI theme
- **Alert Red** - Detection/danger
- **Caution Yellow** - Suspicious state
- **Success Green** - Objectives/exit
- **Office Neutral** - Environment base

### NPC Identity Colors
- **Standard Guard** - Navy blue
- **Boss** - Deep red
- **Admin Officer** - Royal blue
- **Angry Coworker** - Yellow/orange

## Technical Specifications

### Model Requirements
- **Polycount**: 500-2000 tris for props, 2000-5000 for characters
- **Texture Resolution**: 512x512 for props, 1024x1024 for characters
- **File Formats**: GLTF 2.0, FBX, or Godot native

### Texture Requirements
- **Format**: PNG for transparency, JPG for opaque
- **Normal Maps**: Where applicable for detail
- **PBR Workflow**: Albedo, Normal, Roughness, Metallic

### Animation Requirements
- **Frame Rate**: 30 FPS
- **Rig Type**: Humanoid for characters
- **Export Format**: GLTF with animations

## Asset Priorities

### Critical (Must Have)
1. Player character model
2. Basic NPC guard model
3. Modular wall/floor pieces
4. Biscuit jar
5. Basic furniture (desk, chair)
6. UI elements (HUD, menus)

### Important (Should Have)
1. NPC personality variants
2. Full furniture set
3. All collectible types
4. Particle effects
5. Animated doors

### Nice to Have
1. Multiple player skins
2. Seasonal decorations
3. Additional prop variations
4. Enhanced VFX
5. Cutscene assets

## Style Guide

The game follows a **low-poly, stylized** art direction with:
- Clean, geometric shapes
- Flat shading with subtle gradients
- Bright, readable colors
- Clear visual hierarchy
- Consistent proportions (slightly cartoonish)

Similar visual references:
- Overcooked's character style
- Two Point Hospital's environment design
- Untitled Goose Game's clean aesthetic