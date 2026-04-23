extends CanvasLayer

@onready var hp_container = $HPContainer
var player: CharacterBody2D
var hp_icons := []

@export var full_color := Color(1.0, 0.132, 0.299, 1.0)    # Yellow when full
@export var empty_color := Color(0.2, 0.2, 0.2)  # Dark gray when empty

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		print("ERROR: Player not found!")
		return
	hp_container.position = Vector2(20, 70)  # Top-left corner
	player.hp_changed.connect(_on_hp_changed)
	build_hp_icons()

func build_hp_icons() -> void:
	# Clear existing icons
	for icon in hp_icons:
		icon.queue_free()
	hp_icons.clear()
	
	
	# Create one icon per HP cell
	for i in range(player.max_hp):
		var icon = ColorRect.new()
		icon.size = Vector2(32, 32)  # Size of each cell
		icon.position = Vector2(i * 39, 0)  # Space between cells
		icon.color = full_color
		hp_container.add_child(icon)
		hp_icons.append(icon)

func _on_hp_changed(new_hp: int) -> void:
	for i in range(hp_icons.size()):
		if i < new_hp:
			hp_icons[i].color = full_color   # Full cell
		else:
			hp_icons[i].color = empty_color  # Empty cell
