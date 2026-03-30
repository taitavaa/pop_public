extends Node2D

@export var grid_size := Vector2i(8, 8)
@export var cell_size := 64

var grid := []

var bubble_scene = preload("res://scenes/bubble.tscn")

func _ready():
	randomize()
	create_grid()

func _on_grid_size_changed(new_size: Vector2i) -> void:
	grid_size = new_size
	_on_grid_rebuild()


func _on_grid_rebuild() -> void:
	for child in get_children():
		child.queue_free()
	grid.clear()
	create_grid()


func create_grid():
	for x in range(grid_size.x):
		grid.append([])
		for y in range(grid_size.y):
			grid[x].append(null)
			spawn_bubble(x, y)

func spawn_bubble(x: int, y: int):
	# Centers the whole grid in the viewport.
	var grid_width = grid_size.x * cell_size
	var grid_height = grid_size.y * cell_size
	var screen_size = get_viewport().get_visible_rect().size
	position = (screen_size - Vector2(grid_width, grid_height)) / 2

	var bubble = bubble_scene.instantiate()
	bubble.recipe_id = RunManager.roll_bubble_recipe_id() if RunManager else GameData.pick_random_bubble_recipe_id()

	# Assigns per-cell local position and grid coordinates.
	bubble.position = Vector2(x, y) * cell_size
	bubble.grid_position = Vector2i(x, y)

	bubble.popped.connect(_on_bubble_popped)

	## Adds a bubble instance to the grid scene as a child
	add_child(bubble)

	## Basically just (x, y) identifies as a bubble
	grid[x][y] = bubble

func _on_bubble_popped(
	grid_pos: Vector2i,
	recipe_id: String,
	color_id: String,
	effect_ids: Array[String],
	payload_id: String,
	is_chain: bool,
	chain_depth: int = 0
):
	if not is_chain and RunManager.pops_remaining <= 0:
		return

	if not is_chain:
		RunManager.use_pop()

	RunManager.on_bubble_popped(grid_pos, recipe_id, payload_id, is_chain, chain_depth)
	grid[grid_pos.x][grid_pos.y] = null
	_apply_effects(grid_pos, color_id, effect_ids, chain_depth)

func _apply_effects(origin: Vector2i, color_id: String, effect_ids: Array[String], source_chain_depth: int) -> void:
	for effect_id in effect_ids:
		if effect_id == "none":
			continue
		match effect_id:
			"explosion_effect":
				pop_neighbors(origin, source_chain_depth)
			"color_blob_chain_effect":
				pop_connected_color_blob(origin, color_id, source_chain_depth)
			_:
				pass

func pop_connected_color_blob(origin: Vector2i, target_color_id: String, source_chain_depth: int = 0) -> void:
	if target_color_id.is_empty():
		return

	var connected := _collect_connected_blob_from_origin(origin, target_color_id)
	for i in range(connected.size()):
		var cell: Vector2i = connected[i]
		var bubble = grid[cell.x][cell.y]
		if bubble == null:
			continue
		await get_tree().create_timer(0.1).timeout
		if bubble == null:
			continue
		bubble.pop(true, source_chain_depth + 1 + i)

func _collect_connected_blob_from_origin(origin: Vector2i, target_color_id: String) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	var queue: Array[Vector2i] = [origin]
	var visited := {}
	visited[origin] = true

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var next: Vector2i = current + dir
			if not is_valid_cell(next):
				continue
			if visited.has(next):
				continue
			visited[next] = true

			var next_bubble = grid[next.x][next.y]
			if next_bubble == null:
				continue
			if str(next_bubble.color_id) != target_color_id:
				continue

			results.append(next)
			queue.append(next)

	return results

func pop_neighbors(cell: Vector2i, source_chain_depth: int = 0):
	var directions = [
		Vector2i(1,0),
		Vector2i(-1,0),
		Vector2i(0,1),
		Vector2i(0,-1)
	]

	for dir in directions:
		var neighbor = cell + dir
		if is_valid_cell(neighbor):
			var bubble = grid[neighbor.x][neighbor.y]
			if bubble:
				await get_tree().create_timer(0.1).timeout

				# Honorable mention to MagiciansMagics for the optimization
				if bubble == null:
					continue

				bubble.pop(true, source_chain_depth + 1)

func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x \
		and cell.y >= 0 and cell.y < grid_size.y
