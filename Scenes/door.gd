extends Area2D

@export var target_scene: PackedScene  # Drag scene file here
@export var target_spawn_id: String

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node2D) -> void:
	
	if not body.is_in_group("player"):
		return
	
	if not target_scene:
		push_warning("Door: No target scene set!")
		return
	
	if target_spawn_id == "":
		push_warning("Door: No target spawn ID set!")
		return
	
	print("Door triggered → Spawn: ", target_spawn_id)
	GameManager.target_spawn_id = target_spawn_id
	
	# Save player data
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameManager.save_player_data(player)
	print("reacheed door")
	get_tree().change_scene_to_packed(target_scene)
