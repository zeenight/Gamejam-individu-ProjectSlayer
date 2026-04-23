extends Camera2D
@export var look_ahead_distance := 40
@export var smoothing := 5
var target_offset := Vector2.ZERO

func _process(delta):
	var player = get_parent()
	var velocity = player.velocity
	if velocity.length() > 0:
		target_offset = velocity.normalized() * look_ahead_distance
	else:
		target_offset = target_offset.lerp(Vector2.ZERO, delta * smoothing)
	offset = offset.lerp(target_offset, delta * smoothing)
	
	# Clamp offset so camera doesn't go past limits
	var screen_size = get_viewport_rect().size / zoom
	var cam_pos = get_screen_center_position()
	
	if cam_pos.x + offset.x - screen_size.x / 2 < limit_left:
		offset.x = limit_left - cam_pos.x + screen_size.x / 2
	if cam_pos.x + offset.x + screen_size.x / 2 > limit_right:
		offset.x = limit_right - cam_pos.x - screen_size.x / 2
	if cam_pos.y + offset.y - screen_size.y / 2 < limit_top:
		offset.y = limit_top - cam_pos.y + screen_size.y / 2
	if cam_pos.y + offset.y + screen_size.y / 2 > limit_bottom:
		offset.y = limit_bottom - cam_pos.y - screen_size.y / 2
