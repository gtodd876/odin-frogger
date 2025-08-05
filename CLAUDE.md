# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is a Frogger arcade game clone written in Odin using Raylib. The project implements hot reload functionality for rapid development iteration.

## Build Commands

### Standard Build
```bash
# Build the default version
odin build src/main_default -out:main_default
./main_default
```

### Hot Reload Build
```bash
# macOS/Linux
odin build -build-mode:shared src -out:build/hot_reload/game.dylib
odin build src/main_hot_reload -out:build/hot_reload/hot_reload

# Windows  
odin build -build-mode:shared src -out:build/hot_reload/game.dll
odin build src/main_hot_reload -out:build/hot_reload/hot_reload.exe

# Run with hot reload
./build/hot_reload/hot_reload
```

Press F5 during gameplay to trigger a rebuild and hot reload.

## Architecture

### Hot Reload System
The project uses a sophisticated hot reload architecture:
- `src/main_hot_reload/`: Launcher that loads game logic as a dynamic library
- `src/main_default/`: Simple static launcher for production builds  
- `src/main.odin`: Core game package with exported functions
- Game state preserved across reloads via `Game_Memory` struct passed by pointer

Key exported functions:
- `game_init_platform()`: Initialize window and audio
- `game_init()`: Initialize game state
- `game_update()`: Main game loop (input, logic, rendering)
- `game_hot_reload(mem)`: Restore game memory after reload
- `game_is_build_requested()`: Check if F5 pressed for rebuild

### Game Systems

**Grid-based Rendering** (`src/rl_grid/`):
- 14x16 grid with 64-pixel cells
- Utility functions for sprite and shape rendering on grid
- Entity system with position, speed, color, and sprite data

**Core Game State** (`Game_Memory` struct):
- Frog position with smooth hop interpolation
- Entity arrays (logs, turtles, vehicles)
- Animation system with frame sequences
- Collision detection and game rules
- Debug visualization options (F1 toggles grid)

**Sprite System**:
- Sprite sheet at 16x16 pixel cells
- Rotation support for directional frog movement
- Multi-cell sprites for logs and turtles

## Key Files
- `src/main.odin`: Core game logic, rendering, collision detection
- `src/rl_grid/grid.odin`: Grid-based rendering utilities
- `assets/`: Sprite sheets, background, and font files
- `todo.md`: Feature roadmap and completed tasks

## Development Tips
- Use F1 to toggle debug grid overlay
- The render target fix in `game_init()` is critical - ensure `gmem.game_render_target` is assigned
- Collision detection uses center-point checks against rectangles
- Frog animation plays during hops using a 4-frame sequence