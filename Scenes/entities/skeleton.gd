## Slime - Simple enemy example
## Hitbox active only on frames 2 and 3 of attack animations

extends EnemyBase2

func _enemy_ready() -> void:
	speed = 75.0
	max_hp = 5
	current_hp = max_hp
	detection_range = 200.0
	attack_range = 50.0
	attack_hitbox_size = Vector2(30, 20)
	attack_hitbox_offset = 40.0

func get_attack_animations() -> Dictionary:
	return {
		"up": "attack_up",
		"down": "attack_down",
		"left": "attack_left",
		"right": "attack_right"
	}

## Hitbox only active on frames 2 and 3
func get_attack_frames() -> Dictionary:
	return {
		"attack_up": [2, 3],
		"attack_down": [2, 3],
		"attack_left": [2, 3],
		"attack_right": [2, 3]
	}
