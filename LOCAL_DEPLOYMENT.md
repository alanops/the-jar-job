# Local Deployment Guide

This guide helps you deploy The Jar Job directly to itch.io from your local development environment, bypassing CI issues.

## Quick Start

```bash
# 1. Test your export locally
./scripts/test-export.sh

# 2. Deploy to itch.io
./scripts/deploy-local.sh
```

## Prerequisites

### 1. Godot 4.4+
Make sure Godot is installed and in your PATH:
```bash
godot --version
```

### 2. Butler (itch.io CLI)
Install Butler if you haven't already:
```bash
./scripts/setup-butler.sh
source ~/.bashrc
butler login
```

## Scripts Overview

### `test-export.sh`
Tests the export process locally and catches errors before deployment:
- Runs headless Godot export
- Checks for errors and warnings
- Validates output files
- Reports file count and size

### `deploy-local.sh`
Complete deployment pipeline:
- Checks prerequisites
- Exports the game
- Uploads to itch.io via Butler
- Shows deployment URL

### `setup-butler.sh`
One-time setup for Butler:
- Downloads and installs Butler
- Adds to PATH
- Prepares for itch.io authentication

## Workflow

### First Time Setup
```bash
# 1. Install Butler
./scripts/setup-butler.sh
source ~/.bashrc

# 2. Login to itch.io
butler login
```

### Regular Deployment
```bash
# 1. Test locally first
./scripts/test-export.sh

# 2. Fix any errors shown

# 3. Deploy when ready
./scripts/deploy-local.sh
```

## Troubleshooting

### "Godot not found"
- Install Godot 4.4+ from https://godotengine.org
- Or add to PATH: `export PATH="/path/to/godot:$PATH"`

### "Butler not found"
- Run `./scripts/setup-butler.sh`
- Then `source ~/.bashrc` or restart terminal

### Export Errors
- Run `./scripts/test-export.sh` first
- Check the generated `test_export.log`
- Common fixes:
  - Remove problematic .blend files
  - Fix missing resources
  - Update export presets

### Too Many Files (>1000)
Edit `export_presets.cfg` and add more exclusions:
```
exclude_filter="*.blend,*.blend1,addons/*,.godot/*,*.tmp"
```

## Benefits

- **Immediate feedback** - See errors instantly
- **Local testing** - Validate before deploying
- **Direct control** - No CI pipeline delays
- **Quick iteration** - Deploy in seconds

## Deployment Info

- **User:** downfallgames
- **Game:** the-jar-job  
- **Channel:** html5
- **URL:** https://downfallgames.itch.io/the-jar-job