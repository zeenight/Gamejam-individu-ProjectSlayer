extends Sprite2D

@export var parallax_strength := 0.1

func _process(delta: float) -> void:
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var camera_offset = camera.get_screen_center_position() - global_position
	offset.x = camera_offset.x * parallax_strength
	offset.y = 0
