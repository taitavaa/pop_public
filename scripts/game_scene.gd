extends Node2D

func _ready() -> void:
	if GridManager:
		GridManager.visible = true
		GridManager._on_grid_rebuild()

	if RunManager:
		RunManager.start_run()