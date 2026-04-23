## EnemyBase - Base class for ALL enemies
##
## All enemies extend this class:
##   extends EnemyBase
##
## Standard animation names (same for ALL enemies):
##   idle, walk_up, walk_down, walk_left, walk_right, hurt, death
##
## Custom attack animations:
##   Override get_attack_animations() in child script
##
## Usage:
##   1. Create enemy scene with CharacterBody2D as root
##   2. Attach a script that extends EnemyBase
##   3. Override get_attack_animations() for custom attacks
##   4. Add to "enemy" group

extends CharacterBody2D
class_name EnemyBase

# ─── MOVEMENT ───
@export var speed := 75.0
@export var detection_range := 200.0
@export var attack_range := 50.0

# ─── HP ───
@export var max_hp := 5
var current_hp := 5

# ─── KNOCKBACK ───
@export var knockback_decay_speed := 300.0
var knockback_velocity := Vector2.ZERO

# ─── ATTACK ───
@export var attack_cooldown_duration := 0.5
var attack_cooldown := 0.0

# ─── TOUCH DAMAGE ───
@export var touch_knockback_force := 350.0
@export var touch_cooldown_duration := 0.5
var touch_timer := 0.0

# ─── BLOOD ───
@export var blood_scene: PackedScene

# ─── HEALTH BAR ───
@export var health_bar_offset := Vector2(0, -30)
@export var health_bar_size := Vector2(32, 4)
@export var health_bar_full_color := Color(0, 1, 0)
@export var health_bar_empty_color := Color(0.8, 0, 0)
@export var health_bar_bg_color := Color(0.2, 0.2, 0.2)

# ─── STATE ───
enum State { IDLE, CHASE, ATTACK, HURT, DEAD }
var current_state := State.IDLE

# ─── INTERNAL ───
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var player: Node2D
var last_direction := Vector2.DOWN
var current_animation := ""
var is_hurt := false

# ─── HEALTH BAR NODES ───
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect

# ─── SIGNALS ───
signal damaged(current_hp: int, max_hp: int)
signal died


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	set_collision_layer(2)
	set_collision_mask(1)
	
	if not player:
		push_error("EnemyBase: No node in 'player' group found!")
	
	if not animated_sprite:
		push_error("EnemyBase: Needs an AnimatedSprite2D child!")
		return
	
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Connect touch damage
	var area = get_node_or_null("Area2D")
	if area:
		area.body_entered.connect(_on_touch_body_entered)
	
	current_hp = max_hp
	create_health_bar()
	
	# Call child setup
	_enemy_ready()

## Override this in child scripts for additional setup
func _enemy_ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if not player:
		return
	
	if current_state == State.DEAD:
		return
	
	# Timers
	if touch_timer > 0:
		touch_timer -= delta
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# Update health bar
	update_health_bar()
	
	# Hurt - only knockback movement
	if is_hurt:
		if knockback_velocity != Vector2.ZERO:
			velocity = knockback_velocity
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay_speed * delta)
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Knockback
	if knockback_velocity != Vector2.ZERO:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay_speed * delta)
		move_and_slide()
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# State machine
	if current_state != State.ATTACK:
		if distance_to_player <= attack_range and attack_cooldown <= 0 and distance_to_player > 5:
			change_state(State.ATTACK)
		elif distance_to_player <= detection_range:
			change_state(State.CHASE)
		else:
			change_state(State.IDLE)
	
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			play_animation("idle")
		State.CHASE:
			_chase_player()
		State.ATTACK:
			velocity = Vector2.ZERO
			_play_attack_animation()
	
	move_and_slide()


# ═══════════════════════════════════
# MOVEMENT
# ═══════════════════════════════════

func _chase_player() -> void:
	var to_player = player.global_position - global_position
	var distance = to_player.length()
	
	if distance < 5:
		velocity = Vector2.ZERO
		return
	
	var direction = to_player / distance
	last_direction = direction
	velocity = direction * speed
	
	var animation := ""
	if abs(direction.y) > abs(direction.x):
		animation = "walk_down" if direction.y > 0 else "walk_up"
	else:
		animation = "walk_left" if direction.x < 0 else "walk_right"
	
	play_animation(animation)


# ═══════════════════════════════════
# ATTACK - Override get_attack_animations() for custom attacks
# ═══════════════════════════════════

## Override this to define custom attack animation names
func get_attack_animations() -> Dictionary:
	return {
		"up": "attack_up",
		"down": "attack_down",
		"left": "attack_left",
		"right": "attack_right"
	}

func _play_attack_animation() -> void:
	if knockback_velocity == Vector2.ZERO:
		velocity = Vector2.ZERO
	
	var attacks = get_attack_animations()
	var animation := ""
	
	if abs(last_direction.y) > abs(last_direction.x):
		animation = attacks["up"] if last_direction.y < 0 else attacks["down"]
	else:
		animation = attacks["left"] if last_direction.x < 0 else attacks["right"]
	
	play_animation(animation)


# ═══════════════════════════════════
# DAMAGE
# ═══════════════════════════════════

func take_damage() -> void:
	if is_hurt or current_state == State.DEAD:
		return
	
	current_hp -= 1
	print("damaged==", current_hp)
	emit_signal("damaged", current_hp, max_hp)
	update_health_bar_fill()
	
	is_hurt = true
	animated_sprite.play("hurt")
	current_animation = "hurt"
	
	if current_hp <= 0:
		die()

func die() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	emit_signal("died")
	
	# Disable all collision
	set_collision_layer(0)
	set_collision_mask(0)
	
	var area = get_node_or_null("Area2D")
	if area:
		area.monitoring = false
	
	# Hide health bar
	if health_bar_bg:
		health_bar_bg.visible = false
	if health_bar_fill:
		health_bar_fill.visible = false
	
	animated_sprite.play("death")
	current_animation = "death"
	
	await animated_sprite.animation_finished
	queue_free()


# ═══════════════════════════════════
# KNOCKBACK
# ═══════════════════════════════════

func apply_knockback(knockback_vector: Vector2) -> void:
	knockback_velocity = knockback_vector
	spawn_blood(knockback_vector)
	take_damage()

func spawn_blood(direction: Vector2) -> void:
	if not blood_scene:
		return
	
	var blood = blood_scene.instantiate()
	get_parent().add_child(blood)
	blood.global_position = global_position
	
	if blood is CPUParticles2D:
		blood.emitting = false
		blood.direction = direction.normalized()
		blood.emitting = true
	
	var timer = Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.timeout.connect(blood.queue_free)
	blood.add_child(timer)
	timer.start()


# ═══════════════════════════════════
# TOUCH DAMAGE
# ═══════════════════════════════════

func _on_touch_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if touch_timer > 0:
		return
	
	var direction = (body.global_position - global_position).normalized()
	
	if body.has_method("take_damage") and State:
		body.take_damage()
	if body.has_method("apply_knockback"):
		body.apply_knockback(direction * touch_knockback_force)
	
	knockback_velocity = -direction * 150.0
	touch_timer = touch_cooldown_duration


# ═══════════════════════════════════
# HEALTH BAR
# ═══════════════════════════════════

func create_health_bar() -> void:
	health_bar_bg = ColorRect.new()
	health_bar_bg.size = health_bar_size
	health_bar_bg.color = health_bar_bg_color
	health_bar_bg.z_index = 10
	add_child(health_bar_bg)
	
	health_bar_fill = ColorRect.new()
	health_bar_fill.size = health_bar_size
	health_bar_fill.color = health_bar_full_color
	health_bar_fill.z_index = 11
	add_child(health_bar_fill)
	
	update_health_bar()

func update_health_bar() -> void:
	if not health_bar_bg or not health_bar_fill:
		return
	var bar_pos = health_bar_offset - Vector2(health_bar_size.x / 2, 0)
	health_bar_bg.position = bar_pos
	health_bar_fill.position = bar_pos

func update_health_bar_fill() -> void:
	if not health_bar_fill:
		return
	var hp_percent = float(current_hp) / float(max_hp)
	health_bar_fill.size.x = health_bar_size.x * hp_percent
	health_bar_fill.color = health_bar_full_color.lerp(health_bar_empty_color, 1.0 - hp_percent)


# ═══════════════════════════════════
# ANIMATION
# ═══════════════════════════════════

func play_animation(animation: String) -> void:
	if animation != current_animation:
		animated_sprite.play(animation)
		current_animation = animation

func change_state(new_state: State) -> void:
	current_state = new_state

func _on_animation_finished() -> void:
	if is_hurt:
		is_hurt = false
		current_animation = ""
		
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= attack_range:
			change_state(State.ATTACK)
		elif distance_to_player <= detection_range:
			change_state(State.CHASE)
		else:
			change_state(State.IDLE)
		return
	
	if current_state == State.ATTACK:
		attack_cooldown = attack_cooldown_duration
		current_animation = ""
		
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= detection_range:
			change_state(State.CHASE)
		else:
			change_state(State.IDLE)
