extends Node

## lifecycle and UI update signals
signal run_started
signal run_ended(final_score)
signal score_changed(value: int)
signal pops_remaining_changed(value: int)
signal active_modifiers_changed(modifier_labels: Array[String])
signal last_score_breakdown_changed(value: String)
signal grid_updated(value: Vector2i)

var score : int = 0
var pops_remaining : int = 0
var is_run_active : bool = false
var active_modifiers: Array[GameData.Modifier] = []
var last_score_breakdown : String = ""
var _pending_pop: Array[Dictionary] = []
var _batch_finalize_token: int = 0
var bubble_sheet_weights: Dictionary = {}

## Tunable run settings aka. Tunables
@export var grid_size := Vector2i(4, 4)
@export var max_pops : int = 10
@export var points_per_pop : int = 10
@export var chain_score_bonus_base: float = 5.0
@export var chain_multiplier_bonus_base: float = 2.0
@export var score_batch_timer: float = 0.2

func _ready():
	emit_signal("grid_updated", grid_size)
	start_run()

## starts the run
func start_run():
	score = 0
	is_run_active = true
	_pending_pop.clear()
	_batch_finalize_token += 1
	bubble_sheet_weights = GameData.get_default_bubble_sheet()
	active_modifiers.clear()
	active_modifiers.append(GameData.SampleDoubleScoreModifier.new())
	emit_signal("active_modifiers_changed", get_active_modifier_labels())
	last_score_breakdown = ""
	emit_signal("last_score_breakdown_changed", last_score_breakdown)
	set_pops_remaining(max_pops)
	emit_signal("score_changed", score)
	emit_signal("run_started")

func end_run():
	## Finalizes scores before ending a run
	_finalize_score_batch()
	is_run_active = false
	emit_signal("run_ended", score)

## sets grid size. (Probably breaks so checks this later)
func set_grid_size(value: Vector2i):
	grid_size = Vector2i(max(1, value.x), max(1, value.y))
	emit_signal("grid_updated", grid_size)

func on_bubble_popped(
	grid_position: Vector2i,
	recipe_id: String,
	payload_id: String,
	is_chain: bool,
	chain_depth: int = 0
):
	if not is_run_active:
		return

	## queue every pop event
	_pending_pop.append({
		"grid_position": grid_position,
		"recipe_id": recipe_id,
		"payload_id": payload_id,
		"is_chain": is_chain,
		"chain_depth": chain_depth
	})
	_schedule_score_batch_finalize()

func set_bubble_sheet_weight(recipe_id: String, weight: int) -> void:
	if not recipe_id in GameData.BUBBLE_RECIPES:
		return
	bubble_sheet_weights[recipe_id] = max(0, weight)

func roll_bubble_recipe_id() -> String:
	return GameData.pick_random_bubble_recipe_from_sheet(bubble_sheet_weights)

func add_score(amount: int):
	score += amount
	emit_signal("score_changed", score)

func use_pop():
	## only direct player pops consume run actions.
	set_pops_remaining(pops_remaining - 1)
	if pops_remaining <= 0:
		end_run()

func set_pops_remaining(value: int):
	pops_remaining = value
	emit_signal("pops_remaining_changed", pops_remaining)

func register_score_modifier(modifier: GameData.Modifier) -> void:
	## Runtime modifier add (shop/reward functions later).
	active_modifiers.append(modifier)
	active_modifiers.sort_custom(_sort_modifiers)
	emit_signal("active_modifiers_changed", get_active_modifier_labels())

func unregister_score_modifier(modifier_id: String) -> void:
	## Runtime modifier remove (selling/removal effects later).
	for i in range(active_modifiers.size() - 1, -1, -1):
		if active_modifiers[i].id == modifier_id:
			active_modifiers.remove_at(i)
	emit_signal("active_modifiers_changed", get_active_modifier_labels())

func get_active_modifier_labels() -> Array[String]:
	var labels: Array[String] = []
	for modifier in active_modifiers:
		labels.append(modifier.get_debug_label())
	return labels

func _schedule_score_batch_finalize() -> void:
	_batch_finalize_token += 1
	var token := _batch_finalize_token
	_after_timer_score(token)

func _after_timer_score(token: int) -> void:
	## waits until timer runs out and then finalizes the score
	await get_tree().create_timer(score_batch_timer).timeout
	if token != _batch_finalize_token:
		return
	_finalize_score_batch()

func _finalize_score_batch() -> void:
	if _pending_pop.is_empty():
		return

	## results in a single packet
	var result = _calculate_batch_score(
		points_per_pop,
		chain_score_bonus_base,
		chain_multiplier_bonus_base,
		_pending_pop
	)
	_pending_pop.clear()

	var points := int(result.get("points", points_per_pop))
	last_score_breakdown = str(result.get("breakdown", ""))
	emit_signal("last_score_breakdown_changed", last_score_breakdown)
	add_score(points)

## SCORING FUNCTIONS
func _calculate_batch_score(
	base_points: float,
	chain_score_bonus: float,
	chain_multiplier_bonus: float,
	pop_events: Array[Dictionary]
) -> Dictionary:
	var combined := GameData.ScoreContext.new(0, "batch", Vector2i.ZERO, false)

	for event in pop_events:
		var pop_context := _build_score_context(
			base_points,
			chain_score_bonus,
			chain_multiplier_bonus,
			Vector2i(event.get("grid_position", Vector2i.ZERO)),
			str(event.get("recipe_id", "ruby_standard")),
			str(event.get("payload_id", "standard")),
			bool(event.get("is_chain", false)),
			int(event.get("chain_depth", 0))
		)
		combined.absorb_context(pop_context, "Pop")

	return {
		"points": combined.resolve_points(),
		"breakdown": combined.get_breakdown_text()
	}

func _build_score_context(
	base_points: float,
	chain_score_bonus: float,
	chain_multiplier_bonus: float,
	grid_position: Vector2i,
	recipe_id: String,
	payload_id: String,
	is_chain: bool,
	chain_depth: int
) -> GameData.ScoreContext:
	var context := GameData.ScoreContext.new(base_points, recipe_id, grid_position, is_chain, chain_depth)

	_apply_chain_depth_bonus(
		context,
		chain_depth,
		chain_score_bonus,
		chain_multiplier_bonus
	)

	var recipe_data = GameData.get_bubble_recipe_data(recipe_id)
	var recipe_multiplier_bonus := float(recipe_data.get("score_multiplier_bonus", 0.0))
	if not is_zero_approx(recipe_multiplier_bonus):
		context.add_multiplier_bonus(recipe_multiplier_bonus, "%s recipe" % recipe_id)

	var payload_data = GameData.get_payload_data(payload_id)
	var payload_flat_bonus := float(payload_data.get("flat_bonus", 0.0))
	if not is_zero_approx(payload_flat_bonus):
		context.add_flat_bonus(payload_flat_bonus, "%s payload" % payload_id)

	var payload_multiplier_bonus := float(payload_data.get("multiplier_bonus", 0.0))
	if not is_zero_approx(payload_multiplier_bonus):
		context.add_multiplier_bonus(payload_multiplier_bonus, "%s payload" % payload_id)

	for modifier in active_modifiers:
		if modifier and modifier.can_apply(context):
			modifier.apply(context)

	return context

func _apply_chain_depth_bonus(
	context: GameData.ScoreContext,
	chain_depth: int,
	chain_score_bonus: float,
	chain_multiplier_bonus: float
) -> void:
	if chain_depth <= 0:
		return

	if chain_depth % 2 == 1:
		var odd_step := float((chain_depth - 1.0) / 2.0)
		var score_bonus := chain_score_bonus * pow(2.0, odd_step)
		context.add_flat_bonus(score_bonus, "Chain %d score" % chain_depth)
		return

	var even_step := float((chain_depth / 2.0) - 1)
	var mult_bonus := chain_multiplier_bonus * pow(2.0, even_step)
	context.add_multiplier_bonus(mult_bonus, "Chain %d mult" % chain_depth)

## Lower priority applies first
func _sort_modifiers(a: GameData.Modifier, b: GameData.Modifier) -> bool:
	return a.priority < b.priority
