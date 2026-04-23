extends EnemyBase2
 
@export var spike_scene: PackedScene
var spawned_spikes := []

func _enemy_ready() -> void:
	is_boss = true
	speed = 120.0
	max_hp = 25
	current_hp = max_hp
	detection_range = 400.0
	attack_range = 70.0
	attack_hitbox_size = Vector2(200, 140)
	attack_hitbox_offset = 50.0
	special_attack_cooldown_duration = 10.0
	
	# Bigger health bar for boss
	health_bar_size = Vector2(64, 6)
	health_bar_offset = Vector2(0, -50)
 
func get_attack_animations() -> Dictionary:
	return {
		"up": "attack_up",
		"down": "attack_down",
		"left": "attack_left",
		"right": "attack_right"
	}
 
func get_attack_frames() -> Dictionary:
	return {
		"attack_up": [6, 7],
		"attack_down": [6, 7],
		"attack_left": [6, 7],
		"attack_right": [6, 7]
	}
	
	
func get_special_attacks() -> Array:
	return [
		{
			"name": "spike_summon",
			"animation": "spikes",          # Use idle or a custom cast animation
			"duration": 3.0,
			"weight": 1.0
		}
	]

func _should_use_special_attack() -> bool:
	var specials = get_special_attacks()
	if specials.is_empty():
		return false
	var distance = global_position.distance_to(player.global_position)
	var hp_percent = float(current_hp) / float(max_hp)
	return distance <= detection_range and hp_percent <= 0.5  # Only at 50% HP or below
var spike_spawn_timer := 0.0
var spike_spawn_interval := 0.7

func _execute_special_attack(attack: Dictionary) -> void:
	
	if attack["name"] == "spike_summon":
		AudioManager.play("angel_scream",-10)
		if not spike_scene:
			print("ERROR: No spike scene assigned!")
			return
		
		spike_spawn_timer = 0.0  # Start spawning immediately
		spawn_spike_batch()

func _process_special_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	
	# Spawn spikes every 0.3 seconds
	spike_spawn_timer -= delta
	if spike_spawn_timer <= 0:
		spawn_spike_batch()
		spike_spawn_timer = spike_spawn_interval

func spawn_spike_batch() -> void:
	if not spike_scene:
		return
	
	# 3 spikes very close to player
	for i in range(3):
		var spike = spike_scene.instantiate()
		var close_offset = Vector2(
			randf_range(-20, 20),
			randf_range(-20, 20)
		)
		get_parent().add_child(spike)
		spike.global_position = player.global_position + close_offset
		spawned_spikes.append(spike)
	
	# 7 spikes further away
	for i in range(7):
		var spike = spike_scene.instantiate()
		var far_offset = Vector2(
			randf_range(-150, 150),
			randf_range(-150, 150)
		)
		get_parent().add_child(spike)
		spike.global_position = player.global_position + far_offset
		spawned_spikes.append(spike)
