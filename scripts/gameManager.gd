## GameManager - Autoload Singleton
## Stores player data between scene transitions
##
## Setup: Project → Project Settings → Autoload → Add this script as "GameManager"

extends Node

# Player data that persists between scenes
var player_hp := 5
var player_max_hp := 5
var player_stamina := 100.0
var player_max_stamina := 100.0

# Which spawn point to use after transition
var target_spawn_id := ""

func save_player_data(player: CharacterBody2D) -> void:
	player_hp = player.current_hp
	player_max_hp = player.max_hp
	player_stamina = player.stamina
	player_max_stamina = player.max_stamina
	print("Saved player data - HP: ", player_hp, " Stamina: ", player_stamina)

func load_player_data(player: CharacterBody2D) -> void:
	player.max_hp = player_max_hp
	player.current_hp = player_hp
	player.max_stamina = player_max_stamina
	player.stamina = player_stamina
	player.emit_signal("hp_changed", player.current_hp)
	print("Loaded player data - HP: ", player_hp, " Stamina: ", player_stamina)

func change_scene(scene_path: String, spawn_id: String) -> void:
	# Save player data before switching
	var player = get_tree().get_first_node_in_group("player")
	if player:
		save_player_data(player)
	
	# Set target spawn point
	target_spawn_id = spawn_id
	
	# Switch scene
	get_tree().change_scene_to_file(scene_path)
