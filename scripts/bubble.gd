extends Area2D

signal popped(grid_position, recipe_id, color_id, effect_ids, payload_id, is_chain, chain_depth)

@export var recipe_id : String = "ruby_standard"
var grid_position : Vector2i
var popped_already := false
var recipe_data: Dictionary = {}
var color_id: String = "ruby"
var effect_ids: Array[String] = []
var payload_id: String = "standard"

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	input_event.connect(_on_input_event)
	recipe_data = GameData.get_bubble_recipe_data(recipe_id)
	color_id = str(recipe_data.get("color_id", "ruby"))
	effect_ids = GameData.get_recipe_effect_ids(recipe_data)
	payload_id = str(recipe_data.get("payload_id", "standard"))
	var color_data = GameData.get_color_data(color_id)
	if sprite:
		sprite.modulate = color_data.get("color", Color.WHITE)

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if RunManager.pops_remaining <= 0:
			return
		pop()

func pop(is_chain := false, chain_depth := 0):
	if popped_already:
		return
		
	popped_already = true
	emit_signal("popped", grid_position, recipe_id, color_id, effect_ids, payload_id, is_chain, chain_depth)
	scale *= 1.3
	await get_tree().create_timer(0.1).timeout
	queue_free()

func _on_popped(_grid_position, _recipe_id, _color_id, _effect_ids, _payload_id, _is_chain, _chain_depth):
	pass
