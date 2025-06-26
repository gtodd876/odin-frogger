# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Frogger clone implemented in Odin programming language using Raylib for graphics and audio. The game is contained in a single `main.odin` file and follows a grid-based coordinate system with entity-component architecture.

## Architecture

### Core Structure
- **Single-file architecture**: All game logic is in `main.odin`
- **Grid-based positioning**: Game uses a 14x16 grid system with 64-pixel cells
- **Entity system**: `Entity` struct contains rectangle, speed, and color for all game objects
- **Render target pattern**: Game renders to an internal texture then scales to window

### Key Components
- **Entity management**: `move_entities()` handles horizontal movement and screen wrapping
- **Collision detection**: Uses Raylib's `CheckCollisionPointRec()` for frog-object interactions  
- **Lerp-based movement**: Frog movement uses timer-based interpolation for smooth hopping
- **Asset loading**: Textures and sounds loaded from embedded byte arrays using `#load`

### Game State
- Frog position tracking with separate start/end positions for interpolation
- Entity arrays for logs, vehicles, and future turtles
- Debug grid toggle (F1 key)

## Development Commands

### Building and Running
```bash
# Compile and run the game
odin run main.odin -file

# Build executable only
odin build main.odin -file -out:frogger
```

### Development Tools
- **Language Server**: OLS (Odin Language Server) configured in `ols.json`
- **Debug features**: Press F1 to toggle grid overlay
- **Audio**: WAV file embedded for collision sound effects

## Asset Requirements
- `frogger_background_modified.png`: Background texture
- `frogger_sprite_sheet_modified.png`: Sprite sheet for game objects
- `squish.wav`: Audio file for collision sound

## Game Features Status
Reference `todo.md` for current implementation status. Key systems include:
- ✅ Basic frog movement and collision
- ✅ Log movement and frog-on-log physics
- ⚠️ Partial vehicle collision
- ❌ Turtle system (placeholder exists)
- ❌ Sprite rendering (currently using colored rectangles)