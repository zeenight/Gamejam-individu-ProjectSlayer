## MainMenu - Starting screen
##
## Scene structure:
##   MainMenu (Control)                ← attach this script
##   ├── ColorRect (background)        ← dark background
##   ├── TextureRect (logo)            ← your game logo
##   ├── VBoxContainer (buttons)
##   │   ├── PlayButton (Button)
##   │   └── CreditsButton (Button)
##   └── CreditsPanel (PanelContainer) ← hidden by default
##       └── VBoxContainer
##           ├── CreditsLabel (RichTextLabel)
##           └── BackButton (Button)

extends Control

@onready var credits_panel = $CreditsPanel
@onready var buttons = $VBoxContainer

func _ready() -> void:
	credits_panel.visible = false

func _on_play_button_pressed() -> void:
	print("play")
	get_tree().change_scene_to_file("res://Scenes/areas/Area1.tscn")

func _on_credits_button_pressed() -> void:
	buttons.visible = false
	credits_panel.visible = true

func _on_back_button_pressed() -> void:
	credits_panel.visible = false
	buttons.visible = true
