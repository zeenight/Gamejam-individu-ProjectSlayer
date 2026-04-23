## SpawnPoint - Marker where the player appears
##
## Scene structure:
##   SpawnPoint (Marker2D)    ← attach this script
##
## Setup:
##   1. Create a Marker2D node
##   2. Attach this script
##   3. Set spawn_id in inspector (e.g., "from_area1", "from_area2")
##   4. Position it where the player should appear
##   5. Add to "spawn_point" group

extends Marker2D

@export var spawn_id: String  # Unique ID (e.g., "from_area1", "from_cave")

func _ready() -> void:
	add_to_group("spawn_point")
