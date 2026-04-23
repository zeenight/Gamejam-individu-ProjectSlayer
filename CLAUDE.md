# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**individu_Slayer** is a top-down 2D action game built with **Godot 4.6** using **GDScript**. No build system — open the project folder in Godot 4.6 and press F5 to run.

- Main scene: `Scenes/Area1.tscn`
- Physics: Jolt (2D, gravity = 0 for top-down)
- Rendering: Direct3D 12 / Forward Plus

## Running the Game

Open this folder in the Godot 4.6 editor, then:
- **Play game:** F5
- **Play current scene:** F6
- **Run from command line:** `godot --path . res://Scenes/Area1.tscn`

## Architecture

### Scene Structure

```
Area1.tscn          ← main scene, contains world + entities
├── Player.tscn     ← player character (CharacterBody2D)
├── SlimeIce.tscn   ← enemy (CharacterBody2D)
└── background sprites (Startingarea, Trees)
```

### Player (`Scenes/entities/player.gd`)

`CharacterBody2D` with three primary systems:

- **Movement:** WASD/arrow keys at 100 units/sec; knockback decays at 0.85x per frame
- **Attack:** Left-click triggers directional melee combo (2-hit); spawns a temporary `Area2D` hitbox (radius 20, visible 0.5s) and lunges at 200 units/sec for 0.2s; calls `apply_knockback()` on enemies in group `"enemy"`
- **Dash:** Shift key, 350 units/sec for 0.25s, 0.3s cooldown; spawns blue-tinted afterimage sprites

Animation states follow the pattern: `idle_<dir>`, `move_<dir>`, `<dir>_atk_<n>`, `dash_<dir>` where dir is front/back/left/right.

### Enemy (`Scenes/entities/slime_ice.gd`)

`CharacterBody2D` with a three-state machine:

```
IDLE ──(player within 200 units)──► CHASE ──(within 50 units)──► ATTACK
									  ▲                               │
									  └───────────────────────────────┘
```

- Patrol speed: 75 units/sec
- On contact: applies 350 units/sec knockback to player, 0.2s cooldown between contacts
- On hit: spawns `blood_particle.tscn` (32 particles, 0.25s lifetime)
- Must expose `apply_knockback(direction: Vector2, force: float)` method and belong to group `"enemy"`

### Camera (`Scenes/camera_2d.gd`)

Attached to `Camera2D` (zoom 2.5x). Smooth-follows player with 40-unit velocity look-ahead, smoothing factor 5.

### Entity Communication

- Player detects enemies via hitbox `Area2D` overlap → calls `apply_knockback()` directly
- Enemies use `get_node("/root/...")` or groups to find the player
- Blood particles are instantiated at runtime and added to the scene tree

## Input Map

Defined in `project.godot`:

| Action | Binding |
|--------|---------|
| `ui_left/right/up/down` | WASD + arrow keys + gamepad left stick |
| `attack` | Left mouse button |
| `dash` | Shift |

## Key Conventions

- All game entities are `CharacterBody2D`; use `move_and_slide()` for movement
- Enemies must be in the `"enemy"` group and implement `apply_knockback(dir: Vector2, force: float)`
- Temporary nodes (hitboxes, particles) are instantiated via `preload()` and freed via `queue_free()` after use
- Directions are tracked as a `Vector2` (e.g., `facing = Vector2(1, 0)`) and mapped to animation names
