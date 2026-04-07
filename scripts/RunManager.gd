extends Node

## lifecycle and UI update signals
signal run_started
signal run_ended(final_score)
signal score_changed(value: int)
signal pops_remaining_changed(value: int)
signal active_modifiers_changed(modifier_labels: Array[String])
signal last_score_breakdown_changed(value: String)
signal grid_updated(value: Vector2i)
signal round_changed(value: int)
signal score_finalized

var score : int = 0
var pops_remaining : int = 0
var is_run_active : bool = false
var active_modifiers: Array[GameData.Modifier] = []
var last_score_breakdown : String = ""
var _pending_pop: Array[Dictionary] = []
var _score_batch_scope_depth: int = 0
var bubble_bag = []
var bag_blueprint = [] 
var current_round: int = 1

## Tunable run settings aka. Tunables
@export var grid_size := Vector2i(4, 4)
@export var max_pops : int = 10
@export var points_per_pop : int = 10
@export var chain_score_bonus_base: float = 5.0
@export var chain_multiplier_bonus_base: float = 2.0

func _ready():
	emit_signal("grid_updated", grid_size)

## starts the run
func start_run():
	score = 0
	is_run_active = true
	current_round = 1
	_reset_batch_state()
	build_bubble_bag()
	active_modifiers.clear()
	active_modifiers.append(GameData.SampleDoubleScoreModifier.new())
	emit_signal("active_modifiers_changed", get_active_modifier_labels())
	_reset_breakdown()
	emit_signal("round_changed", current_round)
	set_pops_remaining(max_pops)
	emit_signal("score_changed", score)
	emit_signal("run_started")

func end_round():
	## Ends active run
	end_score_batch_scope()
	emit_signal("run_ended", score)
	is_run_active = false

func start_next_round() -> void:
	current_round += 1
	is_run_active = true
	_reset_batch_state()
	refill_bag()
	_reset_breakdown()
	emit_signal("round_changed", current_round)
	set_pops_remaining(max_pops)

func is_score_batch_active() -> bool:
	return _score_batch_scope_depth > 0

## sets grid size. (Probably breaks so checks this later)
func set_grid_size(value: Vector2i):
	grid_size = Vector2i(max(1, value.x), max(1, value.y))
	emit_signal("grid_updated", grid_size)

func on_bubble_popped(
	grid_position: Vector2i,
	bubble_template,
	is_chain: bool,
	chain_depth: int = 0
):
	if not is_run_active:
		return

	## queue every pop event
	_pending_pop.append({
		"grid_position": grid_position,
		"bubble_template": bubble_template,
		"is_chain": is_chain,
		"chain_depth": chain_depth
	})

func build_bubble_bag() -> void:
	## loads the bag with default tempalte rn
	var preset_grid_size: Vector2i = GameData.get_bag_grid_size()
	if preset_grid_size != Vector2i.ZERO:
		set_grid_size(preset_grid_size)
	bag_blueprint = GameData.get_default_bubble_bag()
	refill_bag()

func refill_bag() -> void:
	## Refill bag
	bubble_bag = []
	for template in bag_blueprint:
		bubble_bag.append(template.duplicate())
	bubble_bag.shuffle()

func draw_bubble_template(): 
	if bubble_bag.is_empty():
		return null
	var index := randi_range(0, bubble_bag.size() - 1)
	var bubble_template = bubble_bag[index]
	bubble_bag.remove_at(index)
	return bubble_template

func add_score(amount: int):
	score += amount
	emit_signal("score_changed", score)

func use_pop():
	## only direct player pops consume run actions.
	set_pops_remaining(pops_remaining - 1)
	if pops_remaining <= 0:
		end_round()

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

func begin_score_batch_scope() -> void:
	_score_batch_scope_depth += 1

func end_score_batch_scope() -> void:
	if _score_batch_scope_depth <= 0:
		return
	_score_batch_scope_depth -= 1
	if _score_batch_scope_depth == 0:
		_finalize_score_batch()

func _reset_batch_state() -> void:
	_pending_pop.clear()
	_score_batch_scope_depth = 0

func _reset_breakdown() -> void:
	last_score_breakdown = ""
	emit_signal("last_score_breakdown_changed", last_score_breakdown)

func _finalize_score_batch() -> void:
	## results in a single packet
	print("[DEBUG] _finalize_score_batch: pending_pop.size=%d, points_per_pop=%d" % [_pending_pop.size(), points_per_pop])
	for i in _pending_pop.size():
		var event = _pending_pop[i]
		var template = event.get("bubble_template")
		print("[DEBUG] pop[%d]: template=%s, is_chain=%s, chain_depth=%d" % [
			i,
			"null" if template == null else template.color_id,
			event.get("is_chain"),
			event.get("chain_depth")
		])
	
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
	_log_score_batch(points, last_score_breakdown)
	emit_signal("score_finalized")

func _log_score_batch(points: int, breakdown: String) -> void:
	var compact_breakdown := breakdown.replace("\n", " | ")
	if compact_breakdown.length() > 5000:
		compact_breakdown = "%s..." % compact_breakdown.substr(0, 5000)
	print("[ScoreBatch] +%d pts | total=%d | round=%d | pops=%d | %s" % [
		points,
		score,
		current_round,
		pops_remaining,
		compact_breakdown
	])

## SCORING FUNCTIONS
func _calculate_batch_score(
	base_points: float,
	chain_score_bonus: float,
	chain_multiplier_bonus: float,
	pop_events: Array[Dictionary]
) -> Dictionary:
	var combined := GameData.ScoreContext.new(0, "batch", Vector2i.ZERO, false)

	for event in pop_events:
		var template = event.get("bubble_template", null)
		if template == null:
			continue
		var pop_context := _build_score_context(
			base_points,
			chain_score_bonus,
			chain_multiplier_bonus,
			Vector2i(event.get("grid_position", Vector2i.ZERO)),
			template,
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
	template, 
	is_chain: bool,
	chain_depth: int
) -> GameData.ScoreContext:
	var context := GameData.ScoreContext.new(base_points, template.color_id, grid_position, is_chain, chain_depth)

	_apply_chain_depth_bonus(
		context,
		chain_depth,
		chain_score_bonus,
		chain_multiplier_bonus
	)

	# apply template effects multiplier || no idea twin
	if not is_zero_approx(template.score_multiplier_bonus):
		context.add_multiplier_bonus(template.score_multiplier_bonus, "Template bonus")

	# apply payload bonuses
	var payload_data = GameData.get_payload_data(template.payload_id)
	var payload_flat_bonus := float(payload_data.get("flat_bonus", 0.0))
	if not is_zero_approx(payload_flat_bonus):
		context.add_flat_bonus(payload_flat_bonus, "%s payload" % template.payload_id)

	var payload_multiplier_bonus := float(payload_data.get("multiplier_bonus", 0.0))
	if not is_zero_approx(payload_multiplier_bonus):
		context.add_multiplier_bonus(payload_multiplier_bonus, "%s payload" % template.payload_id)

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
