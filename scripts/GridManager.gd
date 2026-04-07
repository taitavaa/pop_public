extends Node2D

@export var grid_size := Vector2i(8, 8)
@export var cell_size := 64

var grid := []
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]

var bubble_scene = preload("res://scenes/bubble.tscn")
@onready var bubble_container: Node = get_node_or_null("BoardContainer/BubbleContainer")
@onready var board_panel: Control = get_node_or_null("BoardContainer/BoardPanel") as Control

func _ready():
	randomize()
	if RunManager:
		RunManager.grid_updated.connect(_on_grid_size_changed)
		RunManager.score_finalized.connect(_on_score_finalized)
		_on_grid_size_changed(RunManager.grid_size)
	else:
		create_grid()

func _on_grid_size_changed(new_size: Vector2i) -> void:
	grid_size = new_size
	_on_grid_rebuild()


func _on_grid_rebuild() -> void:
	var clear_root: Node = bubble_container if bubble_container != null else self
	for child in clear_root.get_children():
		child.queue_free()
	grid.clear()
	create_grid()


func create_grid():
	for x in range(grid_size.x):
		grid.append([])
		for y in range(grid_size.y):
			grid[x].append(null)

	var fill_order := _build_center_out_side_fill_order(grid_size)
	for cell in fill_order:
		if not spawn_bubble(cell.x, cell.y):
			break

func spawn_bubble(x: int, y: int) -> bool:
	var template = RunManager.draw_bubble_template() if RunManager else null
	if template == null:
		grid[x][y] = null
		return false

	var bubble = bubble_scene.instantiate()
	bubble.bubble_template = template

	# Spawn coordinates are centered around the board container center.
	bubble.position = _grid_to_local_position(Vector2i(x, y))
	bubble.grid_position = Vector2i(x, y)

	bubble.popped.connect(_on_bubble_popped)

	## Adds a bubble instance to the grid scene as a child
	if bubble_container != null:
		bubble_container.add_child(bubble)
	else:
		add_child(bubble)

	## Basically just (x, y) identifies as a bubble
	grid[x][y] = bubble
	return true

func _grid_to_local_position(cell: Vector2i) -> Vector2:
	var center_index := Vector2((grid_size.x - 1) * 0.5, (grid_size.y - 1) * 0.5)
	var offset_cells := Vector2(cell.x, cell.y) - center_index
	var board_center := _get_board_center_in_spawn_space()
	return board_center + (offset_cells * float(cell_size))

func _get_board_center_in_spawn_space() -> Vector2:
	var board_size := _get_board_size()
	var board_center := board_size * 0.5
	if bubble_container is Node2D:
		return board_center - (bubble_container as Node2D).position
	return board_center

func _get_board_size() -> Vector2:
	if board_panel != null and board_panel.size != Vector2.ZERO:
		return board_panel.size
	# Max design size: 15 cells x 10 cells.
	return Vector2(15 * cell_size, 10 * cell_size)

func _build_center_out_side_fill_order(size: Vector2i) -> Array[Vector2i]:
	var order: Array[Vector2i] = []
	if size.x <= 0 or size.y <= 0:
		return order

	var visited := {}
	var center := Vector2i((size.x - 1) / 2, (size.y - 1) / 2)

	## keskikohta ensin
	_append_unique_cell(order, visited, center, size)

	# Grow outwards in segments going from left, to top, to right, to bottom, then corners, then repeat for the entire grid.
	var max_ring := maxi(maxi(center.x, size.x - 1 - center.x), maxi(center.y, size.y - 1 - center.y))
	for ring in range(1, max_ring + 1):
		var left_x := center.x - ring
		var right_x := center.x + ring
		var top_y := center.y - ring
		var bottom_y := center.y + ring

		## Left side
		for y in range(top_y + 1, bottom_y):
			_append_unique_cell(order, visited, Vector2i(left_x, y), size)

		## Top side
		for x in range(left_x + 1, right_x):
			_append_unique_cell(order, visited, Vector2i(x, top_y), size)

		## Right side
		for y in range(top_y + 1, bottom_y):
			_append_unique_cell(order, visited, Vector2i(right_x, y), size)

		## Bottom side
		for x in range(left_x + 1, right_x):
			_append_unique_cell(order, visited, Vector2i(x, bottom_y), size)

		# Corners after all sides, looks cooler tbh
		_append_unique_cell(order, visited, Vector2i(left_x, top_y), size)
		_append_unique_cell(order, visited, Vector2i(right_x, top_y), size)
		_append_unique_cell(order, visited, Vector2i(right_x, bottom_y), size)
		_append_unique_cell(order, visited, Vector2i(left_x, bottom_y), size)


	return order

func _append_unique_cell(order: Array[Vector2i], visited: Dictionary, cell: Vector2i, size: Vector2i) -> void:
	if cell.x < 0 or cell.x >= size.x or cell.y < 0 or cell.y >= size.y:
		return
	if visited.has(cell):
		return
	visited[cell] = true
	order.append(cell)

func _on_bubble_popped(
	grid_pos: Vector2i,
	bubble_template,  # BubbleTemplate object
	color_id: String,
	effect_ids: Array[String],
	is_chain: bool,
	chain_depth: int = 0
):
	if RunManager == null:
		return

	if not is_chain and RunManager.pops_remaining <= 0:
		return

	RunManager.begin_score_batch_scope()
	RunManager.on_bubble_popped(grid_pos, bubble_template, is_chain, chain_depth)

	if not is_chain:
		RunManager.use_pop()
		if not RunManager.is_run_active:
			RunManager.end_score_batch_scope()
			return

	grid[grid_pos.x][grid_pos.y] = null
	await _apply_effects(grid_pos, color_id, effect_ids, chain_depth)
	RunManager.end_score_batch_scope()

func _on_score_finalized() -> void:
	if RunManager == null or not RunManager.is_run_active:
		return
	_refill_empty_cells()

func _refill_empty_cells() -> void:
	var fill_order := _build_center_out_side_fill_order(grid_size)
	for cell in fill_order:
		if grid[cell.x][cell.y] == null:
			if not spawn_bubble(cell.x, cell.y):
				break

func _apply_effects(origin: Vector2i, color_id: String, effect_ids: Array[String], source_chain_depth: int) -> void:
	for effect_id in effect_ids:
		if effect_id == "none":
			continue
		match effect_id:
			"explosion":
				await pop_neighbors(origin, source_chain_depth)
			"chain":
				await pop_connected_color_blob(origin, color_id, source_chain_depth)
			"directional_clear":
				await pop_direction_clear(origin, source_chain_depth)
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
		for dir in CARDINAL_DIRECTIONS:
			var next: Vector2i = current + dir
			if not is_valid_cell(next):
				continue
			if visited.has(next):
				continue
			visited[next] = true

			var next_bubble = grid[next.x][next.y]
			if next_bubble == null:
				continue
			if next_bubble.bubble_template == null:
				continue
			if str(next_bubble.bubble_template.color_id) != target_color_id:
				continue

			results.append(next)
			queue.append(next)

	return results

func pop_neighbors(cell: Vector2i, source_chain_depth: int = 0):
	for dir in CARDINAL_DIRECTIONS:
		var neighbor = cell + dir
		if is_valid_cell(neighbor):
			var bubble = grid[neighbor.x][neighbor.y]
			if bubble:
				await get_tree().create_timer(0.1).timeout

				# Honorable mention to MagiciansMagics for the optimization
				if bubble == null:
					continue

				bubble.pop(true, source_chain_depth + 1)

func pop_direction_clear(origin: Vector2i, source_chain_depth: int = 0):
	## Pops entire row or column in a random direction
	var chosen_dir = CARDINAL_DIRECTIONS[randi() % CARDINAL_DIRECTIONS.size()]
	
	var current = origin + chosen_dir
	var delay_count = 0
	while is_valid_cell(current):
		var bubble = grid[current.x][current.y]
		if bubble:
			## Timer, kinda poopoo rn.
			await get_tree().create_timer(0.2 * (delay_count + 1)).timeout
			if bubble != null:
				bubble.pop(true, source_chain_depth + 1 + delay_count)
				delay_count += 1
		else:
			break  ## stops at an empty space like a good little effect should
		current += chosen_dir

func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x \
		and cell.y >= 0 and cell.y < grid_size.y
