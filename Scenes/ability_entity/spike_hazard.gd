## Spike Hazard - Spawned by boss spike_summon attack
##
## Scene structure:
##   Spike (Area2D)            ← attach this script
##   ├── AnimatedSprite2D      ← spike_appear, spike_idle, spike_disappear
##   └── CollisionShape2D      ← damage zone
##
## Behavior:
##   1. Warning indicator appears (0.5s)
##   2. Spike shoots up and damages player
##   3. Spike stays for a duration
##   4. Spike disappears
 
extends Area2D
 
@export var warning_duration := 0.5
@export var active_duration := 0.2
@export var knockback_force := 300.0
 
@onready var animated_sprite = $AnimatedSprite2D
var is_active := false
var has_hit := false
 
func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	
	# Warning phase
	if animated_sprite:
		animated_sprite.play("spike_appear")
	
	await get_tree().create_timer(warning_duration).timeout
	
	# Active phase - can damage player
	is_active = true
	monitoring = true
	if animated_sprite:
		animated_sprite.play("spike_idle")
	
	await get_tree().create_timer(active_duration).timeout
	
	# Disappear phase
	is_active = false
	monitoring = false
	if animated_sprite:
		animated_sprite.play("spike_disappear")
		await animated_sprite.animation_finished
	
	queue_free()
 
func _on_body_entered(body: Node2D) -> void:
	if not is_active or has_hit:
		return
	if not body.is_in_group("player"):
		return
	
	has_hit = true
	
	var direction = (body.global_position - global_position).normalized()
	
	if body.has_method("take_damage_player"):
		body.take_damage_player()
	if body.has_method("apply_knockback"):
		body.apply_knockback(direction * knockback_force)
