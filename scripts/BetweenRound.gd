extends Control

@onready var round_label: Label = $CenterContainer/Panel/VBoxContainer/RoundLabel
@onready var score_label: Label = $CenterContainer/Panel/VBoxContainer/ScoreLabel
@onready var continue_button: Button = $CenterContainer/Panel/VBoxContainer/ContinueButton

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	if RunManager:
		var current_round = RunManager.current_round
		var total_score = RunManager.total_score
		round_label.text = "Round %d Complete" % current_round
		score_label.text = "Total Score: %d" % total_score

func _on_continue_pressed() -> void:
	if RunManager:
		RunManager.start_next_round()
	get_tree().change_scene_to_file("res://scenes/grid.tscn")