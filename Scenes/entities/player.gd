extends CharacterBody2D
 
@export var speed = 100.0
@onready var animated_sprite = $AnimatedSprite2D
var last_horizontal_direction = 1.0  # 1 for right, -1 for left

# FIREBALL
@export var fireball_scene: PackedScene
@export var fireball_cooldown_duration := 3.0
var fireball_cooldown := 0.0

# RAGE SYSTEM
@export var max_rage := 100.0
@export var rage_per_hit := 35.0
@export var rage_decay_rate := 10.0       # Decreases per second
@export var rage_threshold := 80.0         # 80% to activate
@export var rage_speed_bonus := 0.10       # 10% speed increase
@export var rage_damage_multiplier := 2.0  # Double damage
# RAGE HP REGEN
@export var rage_heal_interval := 3.0
var rage_heal_timer := 0.0
var rage := 0.0
var is_enraged := false

signal rage_changed(current_rage: float, max_rage: float)
signal rage_activated
signal rage_deactivated

# HP SYSTEM
@export var max_hp := 5
var current_hp := 5
var is_invincible := false
var invincible_timer := 0.0
@export var invincible_duration := 1.0           # After taking damage
@export var attack_invincible_duration := 0.6   # After landing an attack

signal hp_changed(new_hp)
signal player_died

@export var full_color := Color(1, 1, 0)    # Yellow when full
@export var empty_color := Color(0.2, 0.2, 0.2)  # Dark gray when empty


# AFTERIMAGE SYSTEM
@export var afterimage_interval := randf_range(0.02, 0.05)
var afterimage_timer := 0.0

var lunge_timer = 0.0
var lunge_duration = 0.2
var last_direction = Vector2.DOWN
var current_animation = ""
var attack_hitbox: Area2D

# Attack system variables
var is_attacking = false
var attack_counter = 1
var hitbox_timer = 0.0

# DASH SYSTEM
@export var dash_speed := 350.0
@export var dash_duration := 0.25
@export var dash_cooldown := 0.3

var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0

# STAMINA SYSTEM
@export var max_stamina := 100.0
@export var stamina_per_dash := 25.0
@export var stamina_regen_rate := 25.0  # 50 stamina per second

var stamina := 100.0

func create_attack_hitbox() -> void:
	attack_hitbox = Area2D.new()
	attack_hitbox.name = "AttackHitbox"
	add_child(attack_hitbox)
	
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = CircleShape2D.new()
	collision_shape.shape.radius = 30
	attack_hitbox.add_child(collision_shape)
	
	attack_hitbox.area_entered.connect(_on_hitbox_hit)
	attack_hitbox.visible = true      # Hidden on start
	attack_hitbox.monitoring = false    # Not detecting on start
	attack_hitbox.z_index = 5

func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	create_attack_hitbox()
	setup_camera_limits()


var knockback_velocity = Vector2.ZERO
@export var knockback_decay = 0.85

func _physics_process(delta: float) -> void:
	
	if fireball_cooldown > 0:
		fireball_cooldown -= delta
		
	# Invincibility frames
	if is_invincible:
		invincible_timer -= delta
		if invincible_timer <= 0:
			is_invincible = false
			
	if rage > 0:
		rage = move_toward(rage, 0.0, rage_decay_rate * delta)
		emit_signal("rage_changed", rage, max_rage)
		
		var was_enraged = is_enraged
		is_enraged = rage >= (max_rage * rage_threshold / 100.0)
		
		if is_enraged and not was_enraged:
			emit_signal("rage_activated")
			rage_heal_timer = rage_heal_interval  # Start heal timer
			print("RAGE ACTIVATED!")
		elif not is_enraged and was_enraged:
			emit_signal("rage_deactivated")
			rage_heal_timer = 0.0  # Reset timer
			print("Rage deactivated")
	
	# RAGE HP REGEN
	if is_enraged:
		rage_heal_timer -= delta
		if rage_heal_timer <= 0:
			if current_hp < max_hp:
				current_hp += 1
				emit_signal("hp_changed", current_hp)
				print("Rage healed! HP: ", current_hp, "/", max_hp)
			rage_heal_timer = rage_heal_interval  # Reset timer
	
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	# STAMINA REGENERATION - only when not dashing
	if not is_dashing:
		var regen_rate = stamina_regen_rate
		if fireball_cooldown > 0:
			regen_rate = stamina_regen_rate * 0.1  # 20% slower during fireball cooldown
		stamina = move_toward(stamina, max_stamina, regen_rate * delta)
	
	# DASH SYSTEM
	if is_dashing:
		dash_timer -= delta
		
		# Spawn afterimage
		afterimage_timer -= delta
		if afterimage_timer <= 0:
			spawn_afterimage()
			afterimage_timer = afterimage_interval
		
		if dash_timer <= 0:
			is_dashing = false
			velocity = Vector2.ZERO
		
		move_and_slide()
		return
	
	# Apply knockback decay
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity *= knockback_decay
		if knockback_velocity.length() < 1:
			knockback_velocity = Vector2.ZERO
			
	if hitbox_timer > 0:
		hitbox_timer -= delta
		if hitbox_timer <= 0:
			attack_hitbox.visible = false
			attack_hitbox.monitoring = false
	
	if is_attacking:
		lunge_timer -= delta
		if lunge_timer <= 0:
			velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input_vector = input_vector.normalized()
	
	if input_vector.x != 0:
			last_horizontal_direction = sign(input_vector.x)
	
	if input_vector != Vector2.ZERO:
		last_direction = input_vector
		var current_speed = speed
		if is_enraged:
			current_speed = speed * (1.0 + rage_speed_bonus)
		velocity = input_vector * current_speed + knockback_velocity
		play_movement_animation()
	else:
		velocity = knockback_velocity
		if knockback_velocity == Vector2.ZERO:
			play_idle_animation()
	
	move_and_slide()
	
	# Handle attack input
	if Input.is_action_just_pressed("attack"):
		
		trigger_attack()
	
	# Handle dash input
	if Input.is_action_just_pressed("dash"):
		trigger_dash()
		
	if Input.is_action_just_pressed("elemental_skill"):  # Or use a key like "skill1"
		cast_fireball()

func apply_knockback(knockback_vector: Vector2) -> void:
	knockback_velocity = knockback_vector
 
func play_movement_animation() -> void:
	var animation = ""
	
	if last_direction.y < 0:
		animation = "move_up"
	elif last_direction.y > 0:
		animation = "move_down"
	elif last_direction.x < 0:
		animation = "move_left"
	elif last_direction.x > 0:
		animation = "move_right"
	
	if animation != current_animation:
		animated_sprite.play(animation)
		current_animation = animation
 
func play_idle_animation() -> void:
	var animation = ""
	
	if last_direction.y < 0:
		animation = "idle_back"
	elif last_direction.y > 0:
		animation = "idle_front"
	elif last_direction.x < 0:
		animation = "idle_left"
	elif last_direction.x > 0:
		animation = "idle_right"
	
	if animation != current_animation:
		animated_sprite.play(animation)
		current_animation = animation
 
func add_rage(amount: float) -> void:
	rage = min(rage + amount, max_rage)
	emit_signal("rage_changed", rage, max_rage)
	#print("Rage: ", rage, "/", max_rage)
	
func trigger_attack() -> void:
	if stamina < 20:
		return
		
	stamina -= 20
	is_attacking = true
	lunge_timer = lunge_duration
	velocity = last_direction * 200.0
	var attack_animation = get_attack_animation()
	play_attack_animation(attack_animation)
	
	# Enable hitbox during attack
	if attack_hitbox:
		attack_hitbox.position = last_direction * 10
		attack_hitbox.visible = true
		attack_hitbox.monitoring = true
		hitbox_timer = 0.5
 
func get_attack_animation() -> String:
	var animation = ""
	
	if last_direction.x > 0:
		animation = "horizontal_atk"
	elif last_direction.x < 0:
		animation = "horizontal_atk_2"
	elif last_direction.y > 0:
		animation = "downwardsattack_" + str(attack_counter)
	elif last_direction.y < 0:
		animation = "front_atk_" + str(attack_counter)
	
	attack_counter = 3 - attack_counter
	
	return animation
 
func play_attack_animation(animation: String) -> void:
	if animation == "horizontal_atk":
		animated_sprite.flip_h = (last_direction.x < 0)
	
	if animation != current_animation:
		animated_sprite.play(animation)
		current_animation = animation
 
func _on_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		play_idle_animation()
	if is_dashing:
		is_dashing = false
		velocity = Vector2.ZERO
		return

func _on_hitbox_hit(area: Area2D) -> void:
	var knockback_direction = (area.global_position - global_position).normalized()
	var knockback_force = 220.0
	
	if area.is_in_group("enemy"):
		#print("Hit enemy: ", area.name)
		#print("Knockback direction: ", knockback_direction)
		#print("Knockback force: ", knockback_direction * knockback_force)
		is_invincible = true
		invincible_timer = attack_invincible_duration
		var enemy = area
		if area.get_parent() is CharacterBody2D:
			enemy = area.get_parent()
		
		if enemy.has_method("take_damage"):
			if is_enraged:
				add_rage(20)
				enemy.take_damage(2)
				AudioManager.play("fatal_attack",-20.0)
			else:
				add_rage(20)
				#print("Calling take_damage on: ", enemy.name)
				enemy.take_damage()
				AudioManager.play("player_attack")
		
		if enemy.has_method("apply_knockback"):
			#print("Calling apply_knockback on: ", enemy.name)
			enemy.apply_knockback(knockback_direction * knockback_force)
		else:
			print("ERROR: Enemy doesn't have apply_knockback method!")

func trigger_dash() -> void:
	if is_attacking:
		return
	
	if dash_cooldown_timer > 0:
		return
	
	# Check if enough stamina
	if stamina < stamina_per_dash:
		#print("Not enough stamina! Need: ", stamina_per_dash, " Have: ", stamina)
		return
	
	# Consume stamina
	stamina -= stamina_per_dash
	#print("Dashed! Stamina: ", stamina, "/", max_stamina)
	
	is_dashing = true
	AudioManager.play("player_dash",0.0, 1.0, 0.2)
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	
	var dash_direction = last_direction.normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.DOWN
	
	velocity = dash_direction * dash_speed
	play_dash_animation()

func play_dash_animation() -> void:
	var animation := ""
	
	# For vertical dashes, use last horizontal direction
	if abs(last_direction.y) > abs(last_direction.x):
		if last_horizontal_direction > 0:
			animation = "dash_right"
		else:
			animation = "dash_left"
	else:
		# For horizontal dashes
		if last_direction.x > 0:
			animation = "dash_right"
		else:
			animation = "dash_left"
	
	if animation != current_animation:
		animated_sprite.play(animation)
		current_animation = animation
		
func spawn_afterimage():
	var ghost = Sprite2D.new()
	ghost.self_modulate = Color(
	randf_range(0.3, 0.7),
	randf_range(0.5, 1.0),
	1.0,
	randf_range(0.5, 0.9)
	)	
	ghost.texture = animated_sprite.sprite_frames.get_frame_texture(
		animated_sprite.animation,
		animated_sprite.frame
	)
	
	ghost.global_position = global_position
	
	ghost.flip_h = animated_sprite.flip_h
	ghost.modulate = Color(0.0, 0.537, 0.78, 0.902)
	ghost.scale = scale * Vector2(1.2, 0.8)
	get_parent().add_child(ghost)
	
	fade_and_destroy(ghost)
	
func fade_and_destroy(node: Node2D):
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.2)
	tween.tween_callback(node.queue_free)
	
func take_damage_player() -> void:
	if is_invincible:
		print("invin")
		return
	AudioManager.play("player_take_damage")
	current_hp -= 1
	emit_signal("hp_changed", current_hp)
	#print("HP: ", current_hp, "/", max_hp)
	
	# Invincibility frames after hit
	is_invincible = true
	invincible_timer = invincible_duration
	
	if current_hp <= 0:
		die()

func die() -> void:
	emit_signal("player_died")
	print("Player died!")
	# Add death logic here (scene reload, game over, etc.)
	get_tree().reload_current_scene()

func setup_camera_limits() -> void:
	var camera = $Camera2D
	
	var map = get_tree().get_first_node_in_group("map")
	if not map or not map is Sprite2D:
		print("ERROR: No map found! Add your map Sprite2D to 'map' group")
		return
	
	var map_size = map.texture.get_size() * map.scale
	var map_pos = map.global_position
	
	if map.centered:
		camera.limit_left = int(map_pos.x - map_size.x / 2)
		camera.limit_top = int(map_pos.y - map_size.y / 2)
		camera.limit_right = int(map_pos.x + map_size.x / 2)
		camera.limit_bottom = int(map_pos.y + map_size.y / 2)
	else:
		camera.limit_left = int(map_pos.x)
		camera.limit_top = int(map_pos.y)
		camera.limit_right = int(map_pos.x + map_size.x)
		camera.limit_bottom = int(map_pos.y + map_size.y)
	camera.limit_smoothed = false
	print("Camera limits: ", camera.limit_left, ", ", camera.limit_top, " to ", camera.limit_right, ", ", camera.limit_bottom)

func cast_fireball() -> void:
	if not fireball_scene:
		print("ERROR: No fireball scene assigned!")
		return
	
	if fireball_cooldown > 0:
		print("Fireball on cooldown!")
		return
	
	# Check stamina
	if stamina < 45:
		print("Not enough stamina! Need: 45 Have: ", stamina)
		return
	
	# Consume stamina
	stamina -= 1
	
	fireball_cooldown = fireball_cooldown_duration
	
	var fireball = fireball_scene.instantiate()
	get_parent().add_child(fireball)
	
	var mouse_pos = get_global_mouse_position()
	fireball.setup(global_position, mouse_pos)
	
	if is_enraged:
		fireball.damage *= rage_damage_multiplier
	
	print("Fireball cast toward: ", mouse_pos)
