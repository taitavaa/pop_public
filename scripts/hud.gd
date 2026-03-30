extends CanvasLayer

@onready var pops_label: Label = $PopsLabel
@onready var score_label: Label = $ScoreLabel
@onready var multiplier_label: Label = $MultiplierLabel

func _ready() -> void:
	_update_pops(RunManager.pops_remaining)
	_update_score(RunManager.score)
	_update_multiplier(RunManager.last_score_breakdown)
	
	# Keepx HUD reactive during gameplay.
	RunManager.pops_remaining_changed.connect(_update_pops)
	RunManager.score_changed.connect(_update_score)
	RunManager.last_score_breakdown_changed.connect(_update_multiplier)

func _update_pops(value: int) -> void:
	pops_label.text = "Pops: %d" % value

func _update_score(value: int) -> void:
	score_label.text = "Score: %d" % value

func _update_multiplier(value: String) -> void:
	if value.is_empty():
		multiplier_label.text = "Multiplier: -"
		return
	multiplier_label.text = "Multiplier: %s" % value
