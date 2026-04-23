## Slime - extends EnemyBase
## Attach this script to your Slime CharacterBody2D
 
extends EnemyBase2
 
func _enemy_ready() -> void:
	speed = 75.0
	max_hp = 2
	current_hp = max_hp
	detection_range = 200.0
	attack_range = 50.0
 
func get_attack_animations() -> Dictionary:
	return {
		"up": "attack_up",
		"down": "attack_down",
		"left": "attack_left",
		"right": "attack_right"
	}
 
