extends CanvasLayer

@onready var rage_bar = $RageBar
var player: CharacterBody2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	rage_bar.min_value = 0
	rage_bar.max_value = player.max_rage
	rage_bar.value = player.rage
	
	player.rage_changed.connect(_on_rage_changed)

func _on_rage_changed(current_rage: float, max_rage: float) -> void:
	rage_bar.value = current_rage
	
	# Change color when enraged
	var fill_style = rage_bar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		if current_rage >= (max_rage * 0.8):
			fill_style.bg_color = Color(1, 0, 0)       # Red when enraged
		else:
			fill_style.bg_color = Color(1, 0.5, 0)     # Orange normally
