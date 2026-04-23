## EnemyBase - Base class for ALL enemies
##
## Standard animation names (same for ALL enemies):
##   idle, walk_up, walk_down, walk_left, walk_right, hurt, death
##
## Custom attack animations:
##   Override get_attack_animations() in child script
##
## Attack hitbox:
##   Active only on specific frames defined in get_attack_frames()
##
## Boss special attacks:
##   Override get_special_attacks() and _execute_special_attack()

extends CharacterBody2D
class_name EnemyBase2

# ─── STATUS EFFECTS ───
var is_burning := false
var burn_timer := 0.0
@export var burn_slow_amount := 0.5  # 50% slower

# ─── MOVEMENT ───
@export var speed := 75.0
@export var detection_range := 200.0
@export var attack_range := 50.0

# ─── HP ───
@export var max_hp := 5
var current_hp := 5

# ─── INVINCIBILITY ───
@export var invincible_duration := 1
var is_invincible := false
var invincible_timer := 0.0

# ─── KNOCKBACK ───
@export var knockback_decay_speed := 300.0
var knockback_velocity := Vector2.ZERO

# ─── ATTACK ───
@export var attack_cooldown_duration := 0.5
var attack_cooldown := 0.0

# ─── ATTACK HITBOX ───
@export var attack_hitbox_size := Vector2(30, 20)
@export var attack_hitbox_offset := 40.0
var attack_hitbox: Area2D
var has_hit_player_this_attack := false

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

# ─── SPECIAL ATTACKS (BOSS) ───
@export var is_boss := false
@export var special_attack_cooldown_duration := 5.0
var special_attack_cooldown := 0.0
var is_using_special := false
var _current_special_attack := {}
var _special_attack_timer := 0.0

# ─── STATE ───
enum State { IDLE, CHASE, ATTACK, HURT, DEAD, SPECIAL_ATTACK }
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
signal special_attack_started(attack_name: String)
signal special_attack_ended(attack_name: String)


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
	animated_sprite.frame_changed.connect(_on_frame_changed)
	
	# Connect touch damage
	var area = get_node_or_null("Area2D")
	if area:
		area.body_entered.connect(_on_touch_body_entered)
	
	current_hp = max_hp
	create_health_bar()
	create_attack_hitbox()
	
	_enemy_ready()

## Override in child scripts for additional setup
func _enemy_ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if not player:
		return
	
	if current_state == State.DEAD:
		return
	# Burn effect
	if is_burning:
		burn_timer -= delta
		if burn_timer <= 0:
			is_burning = false
			print("Burn ended")
			
	# Invincibility frames
	if is_invincible:
		invincible_timer -= delta
		if invincible_timer <= 0:
			is_invincible = false
	
	# Timers
	if touch_timer > 0:
		touch_timer -= delta
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if special_attack_cooldown > 0:
		special_attack_cooldown -= delta
	
	update_health_bar()
	
	# Hurt - only knockback
	if is_hurt:
		if knockback_velocity != Vector2.ZERO:
			velocity = knockback_velocity
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay_speed * delta)
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Special attack - skip other logic
	if is_using_special:
		_special_attack_timer -= delta
		if _special_attack_timer <= 0:
			_finish_special_attack()
		else:
			_process_special_attack(delta)
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
	if current_state != State.ATTACK and current_state != State.SPECIAL_ATTACK:
		# Boss special attack check
		if is_boss and special_attack_cooldown <= 0 and _should_use_special_attack():
			_start_special_attack()
			return
		elif distance_to_player <= attack_range and attack_cooldown <= 0 and distance_to_player > 5:
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
	
	var current_speed = speed
	if is_burning:
		current_speed = speed * burn_slow_amount  # 50% slower
	
	velocity = direction * current_speed
	
	var animation := ""
	if abs(direction.y) > abs(direction.x):
		animation = "walk_down" if direction.y > 0 else "walk_up"
	else:
		animation = "walk_left" if direction.x < 0 else "walk_right"
	
	play_animation(animation)


# ═══════════════════════════════════
# ATTACK HITBOX
# ═══════════════════════════════════

func create_attack_hitbox() -> void:
	attack_hitbox = Area2D.new()
	attack_hitbox.name = "AttackHitbox"
	add_child(attack_hitbox)
	
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = attack_hitbox_size
	collision_shape.shape = shape
	attack_hitbox.add_child(collision_shape)
	
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	attack_hitbox.monitoring = false

func enable_attack_hitbox() -> void:
	if not attack_hitbox:
		return
	
	has_hit_player_this_attack = false
	
	# Position hitbox in attack direction
	var direction := Vector2.ZERO
	if abs(last_direction.y) > abs(last_direction.x):
		direction = Vector2.DOWN if last_direction.y > 0 else Vector2.UP
	else:
		direction = Vector2.LEFT if last_direction.x < 0 else Vector2.RIGHT
	
	attack_hitbox.position = direction * attack_hitbox_offset
	attack_hitbox.monitoring = true

func disable_attack_hitbox() -> void:
	if attack_hitbox:
		attack_hitbox.monitoring = false

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if has_hit_player_this_attack:
		return
	
	has_hit_player_this_attack = true
	
	var direction = (body.global_position - global_position).normalized()
	
	if body.has_method("take_damage_player"):
		body.take_damage_player()
	if body.has_method("apply_knockback"):
		body.apply_knockback(direction * touch_knockback_force)

## Override to define which frames the hitbox is active
## Return: { "animation_name": [frame1, frame2, ...] }
## Example: { "attack_down": [2, 3], "attack_up": [2, 3] }
func get_attack_frames() -> Dictionary:
	return {}

func _on_frame_changed() -> void:
	var anim = animated_sprite.animation
	var frame = animated_sprite.frame
	var attack_frames = get_attack_frames()
	
	if attack_frames.has(anim):
		if frame in attack_frames[anim]:
			enable_attack_hitbox()
		else:
			disable_attack_hitbox()


# ═══════════════════════════════════
# ATTACK ANIMATIONS
# ═══════════════════════════════════

## Override for custom attack animation names
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
# SPECIAL ATTACKS (BOSS)
# ═══════════════════════════════════

## Override to define available special attacks
## Return array of dictionaries:
## [
##   {
##     "name": "spike_summon",         # unique name
##     "animation": "special_spikes",  # animation to play (optional, "" to skip)
##     "duration": 3.0,                # how long it lasts
##     "weight": 1.0                   # chance weight (higher = more likely)
##   }
## ]
func get_special_attacks() -> Array:
	return []

## Override to decide when to use special attacks
func _should_use_special_attack() -> bool:
	var specials = get_special_attacks()
	if specials.is_empty():
		return false
	var distance = global_position.distance_to(player.global_position)
	return distance <= detection_range

## Override to execute the special attack logic (called once at start)
func _execute_special_attack(attack: Dictionary) -> void:
	pass

## Override to run per-frame logic during special attack
func _process_special_attack(delta: float) -> void:
	velocity = Vector2.ZERO

## Override for custom cleanup when special attack ends
func _end_special_attack_cleanup() -> void:
	pass

func _start_special_attack() -> void:
	var specials = get_special_attacks()
	if specials.is_empty():
		return
	
	var attack = _pick_weighted_attack(specials)
	
	_current_special_attack = attack
	_special_attack_timer = attack.get("duration", 3.0)
	is_using_special = true
	current_state = State.SPECIAL_ATTACK
	velocity = Vector2.ZERO
	
	emit_signal("special_attack_started", attack["name"])
	
	var anim = attack.get("animation", "")
	if anim != "":
		animated_sprite.play(anim)
		current_animation = anim
	
	_execute_special_attack(attack)

func _pick_weighted_attack(attacks: Array) -> Dictionary:
	var total_weight := 0.0
	for attack in attacks:
		total_weight += attack.get("weight", 1.0)
	
	var roll = randf() * total_weight
	var cumulative := 0.0
	for attack in attacks:
		cumulative += attack.get("weight", 1.0)
		if roll <= cumulative:
			return attack
	
	return attacks[0]

func _finish_special_attack() -> void:
	is_using_special = false
	var attack_name = _current_special_attack.get("name", "")
	_current_special_attack = {}
	special_attack_cooldown = special_attack_cooldown_duration
	disable_attack_hitbox()
	
	_end_special_attack_cleanup()
	
	emit_signal("special_attack_ended", attack_name)
	
	current_animation = ""
	var distance = global_position.distance_to(player.global_position)
	if distance <= detection_range:
		change_state(State.CHASE)
	else:
		change_state(State.IDLE)


# ═══════════════════════════════════
# DAMAGE
# ═══════════════════════════════════

func take_damage(damage := 1) -> void:
	if is_hurt or is_invincible or current_state == State.DEAD:
		return
	
	current_hp -= damage
	emit_signal("damaged", current_hp, max_hp)
	update_health_bar_fill()
	
	is_hurt = true
	is_invincible = true
	invincible_timer = invincible_duration
	
	if is_using_special:
		is_using_special = false
		_end_special_attack_cleanup()
	
	animated_sprite.play("hurt")
	current_animation = "hurt"
	disable_attack_hitbox()
	
	if current_hp <= 0:
		die()

func die() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	emit_signal("died")
	
	set_collision_layer(0)
	set_collision_mask(0)
	
	var area = get_node_or_null("Area2D")
	if area:
		area.monitoring = false
	
	disable_attack_hitbox()
	
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
	spawn_blood(knockback_vector)
	if is_hurt or is_invincible or current_state == State.DEAD:
		return
	print("apply knockback on emeny")
	knockback_velocity = knockback_vector
	take_damage()

func spawn_blood(direction: Vector2) -> void:
	if not blood_scene:
		print("bld no scene")
		return
	print("bld")
	
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
	
	if body.has_method("take_damage_player"):
		body.take_damage_player()
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
		disable_attack_hitbox()
		
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= detection_range:
			change_state(State.CHASE)
		else:
			change_state(State.IDLE)
	
	if current_state == State.SPECIAL_ATTACK:
		_finish_special_attack()

func apply_burn(duration := 5.0) -> void:
	burn_timer = duration
	is_burning = true
	
	print("Enemy burning for ", duration, " seconds")
	burn_flash()

func burn_flash() -> void:
	if not is_burning or current_state == State.DEAD:
		return
	
	# Flash orange
	animated_sprite.modulate = Color(1.5, 0.6, 0.2)
	
	# Return to normal after 0.15s
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1), 0.15)
	tween.tween_callback(func():
		# Keep flashing while still burning
		if is_burning:
			burn_flash()
	)
