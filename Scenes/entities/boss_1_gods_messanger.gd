extends EnemyBase2
 
func _enemy_ready() -> void:
	is_boss = true
	speed = 120.0
	max_hp = 30
	current_hp = max_hp
	detection_range = 400.0
	attack_range = 70.0
	attack_hitbox_size = Vector2(200, 140)
	attack_hitbox_offset = 50.0
	special_attack_cooldown_duration = 4.0
	
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
