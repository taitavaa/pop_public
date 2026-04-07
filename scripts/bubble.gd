extends Area2D

signal popped(grid_position, bubble_template, color_id, effect_ids, is_chain, chain_depth)

var bubble_template  # BubbleTemplate object
var grid_position : Vector2i
var popped_already := false

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	input_event.connect(_on_input_event)
	
	# Set default template if none provided
	if bubble_template == null:
		bubble_template = GameData.create_bubble_template("red", ["chain"], [], "standard")
	
	var color_data = GameData.get_color_data(bubble_template.color_id)
	if sprite:
		sprite.modulate = color_data.get("color", Color.WHITE)

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if RunManager and RunManager.is_score_batch_active():
			return
		if RunManager.pops_remaining <= 0:
			return
		pop()

func pop(is_chain := false, chain_depth := 0):
	if popped_already:
		return
		
	popped_already = true
	emit_signal("popped", grid_position, bubble_template, bubble_template.color_id, bubble_template.effect_ids, is_chain, chain_depth)
	scale *= 1.3
	await get_tree().create_timer(0.1).timeout
	queue_free()

func _on_popped(_grid_position, _bubble_template, _color_id, _effect_ids, _is_chain, _chain_depth):
	pass
