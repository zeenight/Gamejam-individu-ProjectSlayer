# Project Slayer - Godot 4 Top-Down Action Game

## Overview
A 2D top-down action game built in Godot 4 (GDScript). Inspired by Hyper Light Drifter with fast combat, dashing, and rage mechanics.

## Tech Stack
- **Engine**: Godot 4
- **Language**: GDScript
- **Art**: Aseprite (pixel art, PNG sprites)
- **Audio**: MP3/WAV files

## Project Structure
```
res://
├── Scenes/
│   ├── areas/
│   │   ├── Area1.tscn          # Starting area
│   │   └── Area2.tscn          # Second area
│   ├── main_menu.tscn          # Title screen
│   ├── enemies/                # Enemy scenes
│   └── projectiles/            # Fireball, spike scenes
├── scripts/
│   ├── player.gd               # Player controller
│   ├── enemy_base.gd           # Base class for all enemies (class_name EnemyBase)
│   ├── door.gd                 # Scene transition trigger
│   ├── spawn_point.gd          # Player spawn marker
│   ├── fireball.gd             # Fireball projectile
│   ├── spike_hazard.gd         # Boss spike attack hazard
│   ├── main_menu.gd            # Main menu UI
│   ├── game_manager.gd         # Autoload: persists player data between scenes
│   └── audio_manager.gd        # Autoload: sound effect system
├── assets/                     # Sprites, tilesets
├── audio/
│   └── sfx/                    # Sound effects
└── project.godot
```

## Autoloads (Singletons)
- **GameManager** (`game_manager.gd`) — Saves/loads player HP and stamina between scene transitions, manages spawn point targeting
- **AudioManager** (`audio_manager.gd`) — Pooled audio player system, call `AudioManager.play("sound_name")` from anywhere

## Player System (`player.gd`)
The player is a `CharacterBody2D` with `AnimatedSprite2D` and `Camera2D` as children.

### Player Node Structure
```
Player (CharacterBody2D)        # Group: "player"
├── AnimatedSprite2D
├── Camera2D                    # Has look-ahead script
├── CollisionShape2D
└── AttackHitbox (Area2D)       # Created in code via create_attack_hitbox()
```

### Movement
- 4-directional movement using `ui_left`, `ui_right`, `ui_up`, `ui_down`
- `last_direction` (Vector2) tracks facing direction
- `last_horizontal_direction` tracks left/right for dash animations
- Speed: 100

### Attack System
- Input: `"attack"` action
- Alternating attacks: `attack_counter` toggles between 1 and 2 (using `3 - attack_counter`)
- Directional attacks: `horizontal_atk`, `horizontal_atk_2`, `downwardsattack_1/2`, `front_atk_1/2`
- Lunge forward on attack (`lunge_timer`, `lunge_duration`)
- Attack hitbox: Circle (radius 30), created in code, positioned in `last_direction * 10`
- Hitbox active for 0.5 seconds per attack

### Dash System
- Input: `"dash"` action
- Costs 25 stamina per dash
- Speed: 350, duration: 0.25s, cooldown: 0.3s
- Spawns blue afterimage ghosts during dash
- Dash animation follows `last_horizontal_direction` for vertical dashes

### Stamina System
- Max: 100, cost per dash: 25, regen: 25/second
- Does NOT regen while dashing
- 20% slower regen during fireball cooldown
- Fireball costs 45 stamina

### HP System
- Cell-based HP like Hyper Light Drifter (5 cells)
- Each hit removes 1 cell regardless of damage source
- `take_damage(damage := 1)` — default 1 damage
- Invincibility frames after taking damage AND after landing an attack
- `invincible_duration` for damage, `attack_invincible_duration` for attack (0.5s)
- Death reloads current scene

### Rage System
- Max rage: 100, gain: 35 per hit, decay: 20/second
- Threshold: 80% (80 rage) to activate
- When enraged: speed +10%, damage x2, HP regen every 5 seconds
- Signals: `rage_changed`, `rage_activated`, `rage_deactivated`

### Fireball
- Input: `"fireball"` action
- Costs 45 stamina, 2s cooldown
- Aims at mouse position (`get_global_mouse_position()`)
- States: CAST → TRAVEL → EXPLODE
- Cast plays at player position, travels to mouse, explodes on arrival or wall hit
- Explosion rotation reset to 0 for upright animation
- Applies burn effect to enemies (slow)
- Damage multiplied by rage if enraged

### Knockback
- `knockback_velocity` with `knockback_decay` (0.85 multiplier per frame)
- Applied via `apply_knockback(knockback_vector: Vector2)`

### Player Animations
- Idle: `idle_back`, `idle_front`, `idle_left`, `idle_right`
- Move: `move_up`, `move_down`, `move_left`, `move_right`
- Attack: `horizontal_atk`, `horizontal_atk_2`, `downwardsattack_1/2`, `front_atk_1/2`
- Dash: `dash_left`, `dash_right`

## Enemy System (`enemy_base.gd`)
All enemies extend `EnemyBase` (`class_name EnemyBase`, extends `CharacterBody2D`).

### Enemy Node Structure
```
Enemy (CharacterBody2D)         # Collision layer: 2, mask: 1
├── AnimatedSprite2D
├── CollisionShape2D
├── Area2D                      # Group: "enemy", for touch damage
│   └── CollisionShape2D
└── AttackHitbox (Area2D)       # Created in code
```

### State Machine
`enum State { IDLE, CHASE, ATTACK, HURT, DEAD, SPECIAL_ATTACK }`

### Standard Animation Names (ALL enemies use these)
- `idle`, `walk_up`, `walk_down`, `walk_left`, `walk_right`
- `hurt` (Loop OFF), `death` (Loop OFF)
- Attack animations are custom per enemy via `get_attack_animations()`

### Overridable Functions
- `_enemy_ready()` — custom setup (stats, etc.)
- `get_attack_animations()` — returns Dictionary of directional attack animation names
- `get_attack_frames()` — returns Dictionary of which frames the hitbox is active
- `get_special_attacks()` — returns Array of special attack definitions (boss only)
- `_should_use_special_attack()` — when to trigger special attacks
- `_execute_special_attack(attack)` — logic when special starts
- `_process_special_attack(delta)` — per-frame logic during special
- `_end_special_attack_cleanup()` — cleanup when special ends

### Attack Hitbox
- Rectangle shape, positioned in `last_direction * attack_hitbox_offset`
- Active only on specific animation frames defined in `get_attack_frames()`
- Connected via `animated_sprite.frame_changed` signal

### Health Bar
- ColorRect-based, always visible above enemy
- Green to red gradient based on HP percentage
- Auto-created in code

### Touch Damage
- Area2D `body_entered` signal detects player
- Damages player, knockbacks both player and enemy
- Touch cooldown prevents rapid hits

### Knockback
- `apply_knockback()` also calls `take_damage()` and `spawn_blood()`
- Blood: CPUParticles2D scene, spawned at enemy position

### Status Effects
- **Burn**: `apply_burn(duration)` — slows enemy by 50%, orange flash effect
- Invincibility frames after taking damage

### Boss System
- Set `is_boss = true` in `_enemy_ready()`
- Special attacks defined via `get_special_attacks()` returning array of dictionaries:
  ```gdscript
  { "name": "spike_summon", "animation": "", "duration": 3.0, "weight": 1.0 }
  ```
- Weighted random selection for multiple special attacks
- `special_attack_cooldown_duration` controls time between specials

### Creating a New Enemy
```gdscript
extends EnemyBase

func _enemy_ready() -> void:
	speed = 75.0
	max_hp = 5
	current_hp = max_hp
	detection_range = 200.0
	attack_range = 50.0

func get_attack_animations() -> Dictionary:
	return { "up": "attack_up", "down": "attack_down", "left": "attack_left", "right": "attack_right" }

func get_attack_frames() -> Dictionary:
	return { "attack_up": [2, 3], "attack_down": [2, 3], "attack_left": [2, 3], "attack_right": [2, 3] }
```

## Scene Transition System
- **Door** (`door.gd`): Area2D trigger, walks into it to change scene
- **SpawnPoint** (`spawn_point.gd`): Marker2D with `spawn_id`, player teleports here
- **GameManager**: Saves HP/stamina, stores `target_spawn_id`
- Scene change uses `call_deferred` to avoid physics callback errors
- Door uses `PackedScene` export for target scene

### Door Setup
- `target_scene`: PackedScene (drag .tscn file)
- `target_spawn_id`: String matching a SpawnPoint's `spawn_id` in target scene

## Camera System
- Camera2D is child of Player with look-ahead script
- Look-ahead offset clamped to map limits
- `setup_camera_limits()` auto-detects map bounds from Sprite2D in "map" group
- `limit_smoothed = false` for hard stops at edges
- Maps are PNG images (Sprite2D), added to "map" group

## UI Structure
```
Main Scene
├── Player
├── HPUI (CanvasLayer)          # hp_ui.gd
│   └── HPContainer (Control)   # ColorRect cells
├── StaminaUI (CanvasLayer)     # stamina_ui.gd
│   └── StaminaBar (ProgressBar)
└── RageUI (CanvasLayer)
    └── RageBar (ProgressBar)
```

## Audio System
- `AudioManager.play("sound_name", volume_db, pitch, start_at)`
- Pool of 8 AudioStreamPlayers for overlapping sounds
- Sounds preloaded in dictionary
- Use `seek()` for offset start times

## Groups
- `"player"` — Player node
- `"enemy"` — Enemy Area2D nodes
- `"map"` — Map Sprite2D (for camera limits)
- `"spawn_point"` — SpawnPoint markers

## Collision Layers
- **Layer 1**: Environment/walls
- **Layer 2**: Enemies
- Player: Layer 1, Mask 1 (collides with environment only)
- Enemies: Layer 2, Mask 1 (collides with environment only)
- Player and enemies do NOT collide with each other (touch damage via Area2D)

## Input Actions
- `ui_left`, `ui_right`, `ui_up`, `ui_down` — Movement
- `"attack"` — Melee attack
- `"dash"` — Dash
- `"fireball"` — Cast fireball toward mouse

## Key Conventions
- Animation efficiency: `current_animation` string prevents replaying same animation
- Attack animations must have **Loop OFF** for `animation_finished` signal
- Knockback uses `move_toward()` for decay, not multiplier
- `velocity = Vector2.ZERO` in states can override knockback — always check `knockback_velocity` first
- Blood particles: CPUParticles2D with self-destructing Timer
- Sprites drawn facing **right** for rotation-based direction (fireball)