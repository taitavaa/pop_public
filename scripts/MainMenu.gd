extends Control

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	if GridManager:
		GridManager.visible = false ## Fix bug where this enables 2 grids please.

	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	if RunManager:
		RunManager.start_run()
	get_tree().change_scene_to_file("res://scenes/grid.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
