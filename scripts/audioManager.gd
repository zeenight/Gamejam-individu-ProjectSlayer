extends Node

# Preload all sounds
var sounds := {
	"player_attack": preload("res://audio/player/u_xjrmmgxfru-flesh-impact-266316.mp3"),
	"player_dash": preload("res://audio/player/Sonido Sound Effect.mp3"),
	"player_take_damage": preload("res://audio/player/freesound_community-slash1-94367.mp3"),
	"fatal_attack": preload("res://audio/player/bannythecoolio-impactful-damage-425132.mp3"),
	"fireball": preload("res://audio/dragon-studio-loud-explosion-425457.mp3")
}  

# Pool of AudioStreamPlayer nodes for overlapping sounds
var player_pool := []
var pool_size := 8 

func _ready() -> void:
	for i in range(pool_size):
		var player = AudioStreamPlayer.new()
		add_child(player)
		player_pool.append(player)

func play(sound_name: String, volume_db := 0.0, pitch := 1.0, start_at := 0.0) -> void:
	if not sounds.has(sound_name):
		push_warning("Sound not found: " + sound_name)
		return
	
	for player in player_pool:
		if not player.playing:
			player.stream = sounds[sound_name]
			player.volume_db = volume_db
			player.pitch_scale = pitch
			player.play()
			if start_at > 0.0:
				player.seek(start_at)  # Skip to this time
			return
	
	player_pool[0].stream = sounds[sound_name]
	player_pool[0].volume_db = volume_db
	player_pool[0].pitch_scale = pitch
	player_pool[0].play()
	if start_at > 0.0:
		player_pool[0].seek(start_at)
