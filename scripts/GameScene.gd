extends Node2D

func _ready() -> void:
	if RunManager:
		RunManager.run_ended.connect(_on_round_ended)

	if GridManager:
		GridManager.visible = true
		GridManager._on_grid_rebuild()

func _on_round_ended() -> void:
	get_tree().change_scene_to_file("res://scenes/between_round.tscn")
