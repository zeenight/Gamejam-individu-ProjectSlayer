extends CharacterBody2D

@export var speed = 75.0
@export var detection_range = 200
@export var attack_range = 50.0
var attack_cooldown = 0.0
var attack_cooldown_duration = 0.2
var knockback_velocity = Vector2.ZERO
@export var knockback_decay = 0.85
@onready var animated_sprite = $AnimatedSprite2D


# HP SYSTEM
@export var max_hp := 5
var current_hp := 5
var is_hurt := false

@export var blood_scene: PackedScene

var player: Node2D
var last_direction = Vector2.DOWN
var current_animation = ""

# State management
enum State { IDLE, CHASE, ATTACK }
var current_state = State.IDLE

func _ready() -> void:
	
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		print("Player ditemukan: ", player.name)
	else:
		print("ERROR: Player tidak ditemukan!")
	
	animated_sprite.animation_finished.connect(_on_animation_finished)


func apply_knockback(knockback_vector: Vector2) -> void:
	print("hit===============:",knockback_vector)
	knockback_velocity = knockback_vector
	spawn_blood(knockback_vector)

func spawn_blood(direction: Vector2) -> void:
	if not blood_scene:
		print("blood not in")
		return
	
	var blood = blood_scene.instantiate()
	get_parent().add_child(blood)
	blood.global_position = global_position
	
	print("blood spawned")
	
	if blood is CPUParticles2D:
		blood.emitting = false
		blood.direction = direction.normalized()
		blood.emitting = true
	
	# Auto delete - timer lives on the blood node itself
	var timer = Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.timeout.connect(blood.queue_free)
	blood.add_child(timer)
	timer.start()

	
func _physics_process(delta: float) -> void:
	if touch_timer > 0:
		touch_timer -= delta
	
	if not player:
		return
	
	# Update attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# Handle knockback with decay
	if knockback_velocity != Vector2.ZERO:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 300 * delta)
	
		move_and_slide()
		return  # Skip other logic while knockbacked
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# State machine - only change state if not attacking
	if current_state != State.ATTACK:
		if distance_to_player <= attack_range and attack_cooldown <= 0 and distance_to_player > 5:
			change_state(State.ATTACK)
			print("atk")
		elif distance_to_player <= detection_range:
			change_state(State.CHASE)
		else:
			change_state(State.IDLE)
	
	# Execute current state
	match current_state:
		State.IDLE:
			
			play_animation("idle")
		
		State.CHASE:
			chase_player()
		
		State.ATTACK:
			play_attack_animation()
	
	move_and_slide()


func chase_player() -> void:
	var to_player = player.global_position - global_position
	var distance = to_player.length()

	# ❗ If too close, STOP instead of normalizing
	if distance < 5:
		velocity = Vector2.ZERO
		return

	var direction = to_player / distance  # safer than normalized()
	last_direction = direction
	velocity = direction * speed
	
	play_walk_animation(direction)

func play_walk_animation(direction: Vector2) -> void:
	var animation = ""
	
	# Determine direction: prioritize vertical
	if abs(direction.y) > abs(direction.x):
		if direction.y < 0:
			animation = "walk_up"
		else:
			animation = "walk_down"
	else:
		if direction.x < 0:
			animation = "walk_left"
		else:
			animation = "walk_right"
	
	play_animation(animation)

func play_attack_animation() -> void:
	if knockback_velocity == Vector2.ZERO:
		velocity = Vector2.ZERO
	var animation = ""
	
	# Determine attack direction: prioritize vertical
	if abs(last_direction.y) > abs(last_direction.x):
		if last_direction.y < 0:
			animation = "attack_up"
		else:
			animation = "attack_down"
	else:
		if last_direction.x < 0:
			animation = "attack_left"
		else:
			animation = "attack_right"
	
	play_animation(animation)

func play_animation(animation: String) -> void:
	if animation != current_animation:
		animated_sprite.play(animation)
		current_animation = animation

func change_state(new_state: State) -> void:
	current_state = new_state

func _on_animation_finished() -> void:
	# Hurt animation finished - resume normal behavior
	if is_hurt:
		is_hurt = false
		current_animation = ""  # Reset so next animation can play
		
		# Return to correct state based on distance
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= attack_range:
			change_state(State.ATTACK)
		elif distance_to_player <= detection_range:
			change_state(State.CHASE)
		else:
			change_state(State.IDLE)
		return
	
	if current_state == State.ATTACK and current_animation.begins_with("attack"):
		attack_cooldown = attack_cooldown_duration
		
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= detection_range:
			change_state(State.CHASE)
		else:
			change_state(State.IDLE)


func apply_knockback_on_player(distance: float) -> void:
	var knockback_direction = (player.global_position - global_position).normalized()
	var knockback_force = 300.0
	print("applied")
	# Push player away
	if player.has_method("apply_knockback"):
		player.apply_knockback(knockback_direction * knockback_force)
	
	# Push slime backward (opposite direction)
	velocity = -knockback_direction * 150.0



var touch_cooldown := 0.2
var touch_timer := 0.0

func _on_area_2d_body_entered(body):
	if not body.is_in_group("player"):
		return
	
	if touch_timer > 0:
		return
	
	var direction = (body.global_position - global_position).normalized()
	if body.has_method("take_damage"):
		body.take_damage()
	# Push player
	if body.has_method("apply_knockback"):
		body.apply_knockback(direction * 350.0)
	
	# Push slime back
	apply_knockback(-direction * 150.0)
	
	touch_timer = touch_cooldown

func take_damage() -> void:
	if is_hurt:
		return
	
	current_hp -= 1
	print("Slime HP: ", current_hp, "/", max_hp)
	
	# Play hurt animation
	is_hurt = true
	animated_sprite.play("hurt")
	current_animation = "hurt"
	
	if current_hp <= 0:
		die()

func die() -> void:
	print("Slime died!")
	current_state = State.IDLE  # Stop all behavior
	velocity = Vector2.ZERO
	animated_sprite.play("death")
	current_animation = "death"
	
	# Disable collision so it can't damage player while dying
	set_collision_layer(0)
	set_collision_mask(0)
	
	# Wait for animation to finish then remove
	await animated_sprite.animation_finished
	queue_free()
