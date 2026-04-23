## Fireball - Projectile that travels to mouse position
##
## Scene structure:
##   Fireball (Area2D)            ← attach this script
##   ├── AnimatedSprite2D         ← cast, travel, explode animations
##   ├── CollisionShape2D         ← hit detection
##   └── CPUParticles2D (optional)← fire trail
##
## Spawned by player, travels toward mouse, explodes on arrival or wall hit

extends Area2D

@export var travel_speed := 300.0
@export var knockback_force := 100.0
@export var damage := 2
@export var explosion_radius := 50.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D

var target_position := Vector2.ZERO
var direction := Vector2.ZERO
var is_traveling := false
var is_exploding := false
var has_hit := {}  # Track which enemies already hit

enum State { CAST, TRAVEL, EXPLODE }
var current_state := State.CAST

func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Disable collision during cast
	collision_shape.disabled = true
	
	# Start cast animation
	animated_sprite.play("cast")

func setup(start_pos: Vector2, mouse_pos: Vector2) -> void:
	global_position = start_pos
	target_position = mouse_pos
	direction = (target_position - start_pos).normalized()
	
	# Rotate sprite to face direction
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	match current_state:
		State.CAST:
			pass  # Wait for cast animation to finish
		
		State.TRAVEL:
			# Move toward target
			var distance_to_target = global_position.distance_to(target_position)
			
			if distance_to_target <= travel_speed * delta:
				# Reached target
				global_position = target_position
				explode()
			else:
				global_position += direction * travel_speed * delta
		
		State.EXPLODE:
			
			pass  # Wait for explode animation to finish

func start_travel() -> void:
	current_state = State.TRAVEL
	is_traveling = true
	collision_shape.disabled = false
	animated_sprite.play("travel")

func explode() -> void:
	AudioManager.play("fireball")
	if is_exploding:
		return
	
	is_exploding = true
	is_traveling = false
	current_state = State.EXPLODE
	
	# Reset rotation so explosion plays upright
	rotation = 0
	
	# Expand collision for AOE damage
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = explosion_radius
	
	animated_sprite.play("explode")
	
	damage_enemies_in_radius()

func damage_enemies_in_radius() -> void:
	# Get all overlapping bodies and areas
	for body in get_overlapping_bodies():
		_apply_damage_to(body)
	for area in get_overlapping_areas():
		_apply_damage_to(area)

func _apply_damage_to(target: Node2D) -> void:
	var enemy = target
	if target.get_parent() is CharacterBody2D:
		enemy = target.get_parent()
	
	if enemy in has_hit:
		return
	has_hit[enemy] = true
	
	var knockback_dir = (enemy.global_position - global_position).normalized()
	
	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(knockback_dir * knockback_force)
	elif enemy.has_method("take_damage"):
		print("dmg from ball")
		enemy.take_damage(damage)
	
	# Apply burn effect
	if enemy.has_method("apply_burn"):
		print("apply burn")
		enemy.apply_burn(6.0)  # Burns for 3 seconds

func _on_animation_finished() -> void:
	match current_state:
		State.CAST:
			start_travel()
		State.EXPLODE:
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if is_exploding:
		return
	
	# Hit a wall - explode
	if not body.is_in_group("player") and not body.is_in_group("enemy"):
		explode()

func _on_area_entered(area: Area2D) -> void:
	if is_exploding:
		return
	
	# Hit an enemy area - apply damage but keep traveling
	var enemy = area
	if area.get_parent() is CharacterBody2D:
		enemy = area.get_parent()
	
	if enemy in has_hit:
		return
	has_hit[enemy] = true
	
	var knockback_dir = (enemy.global_position - global_position).normalized()
	
	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(knockback_dir * knockback_force)
		
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
	
	if enemy.has_method("apply_burn"):
		print("apply burn")
		enemy.apply_burn(6.0)  # Burns for 3 seconds
