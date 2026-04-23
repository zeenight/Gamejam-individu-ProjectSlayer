extends CanvasLayer

@onready var stamina_bar = $StaminaBar
var player: CharacterBody2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		print("ERROR: Player not found!")
		return
	
	# Set initial bar properties
	stamina_bar.min_value = 0
	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina

func _process(delta: float) -> void:
	if not player:
		print("not in stam")
		return
		print("in stam")
	
	# Update bar value
	stamina_bar.value = player.stamina
