extends Area2D

@export var target_scene: PackedScene  # Drag scene file here
@export var target_spawn_id: String

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	if target_scene == null:
		push_warning("Door: No target scene set!")
		return
	
	if target_spawn_id == "":
		push_warning("Door: No target spawn ID set!")
		return
	
	print("Door triggered → Spawn: ", target_spawn_id)
	GameManager.target_spawn_id = target_spawn_id
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameManager.save_player_data(player)
	
	get_tree().call_deferred("change_scene_to_packed", target_scene)
