class_name GameData
extends RefCounted

const TEMPLATE_SCRIPT = preload("res://scripts/BubbleTemplate.gd")

# bubble model.
const COLORS = {
	"red": {
		"display_name": "Red",
		"color": Color.RED
	},
	"orange": {
		"display_name": "Orange",
		"color": Color.DARK_ORANGE
	},
	"cyan": {
		"display_name": "Cyan",
		"color": Color.CYAN
	}
}

const EFFECTS = {
	"none": {
		"display_name": "None"
	},
	"explosion": {
		"display_name": "Explosion"
	},
	"chain": {
		"display_name": "Chain"
	},
	"directional_clear": {
		"display_name": "Directional Clear"
	},
	"random": {
		"display_name": "Random"
	}
}

## SYNERGIES: When effect combinations are triggered
const SYNERGIES = {
	"explosion_directional": {
		"required_effects": ["explosion", "directional_clear"],
		"result_effect": "explosion_all_directions",
		"bonus_multiplier": 0.3,
		"description": "Explosion in all 4 directions"
	},
	"chain_explosion": {
		"required_effects": ["chain", "explosion"],
		"result_effect": "chain_explosion_cascade",
		"bonus_multiplier": 0.25,
		"description": "Chain spreads explosions"
	}
}

const PAYLOADS = {
	"standard": {
		"display_name": "Standard",
		"flat_bonus": 0.0,
		"multiplier_bonus": 0.0
	},
	"bonus_score": {
		"display_name": "Bonus Score",
		"flat_bonus": 8.0,
		"multiplier_bonus": 0.0
	},
	"high_multiplier": {
		"display_name": "High Mult",
		"flat_bonus": 0.0,
		"multiplier_bonus": 0.25
	}
}

const BAG_PRESETS = {
	"starter": {
		"display_name": "Starter",
		"grid_size": {"x": 10, "y": 10},
		"entries": [
			{
				"count": 42,
				"template": {
					"color_id": "red",
					"effect_ids": ["none"],
					"properties": [],
					"payload_id": "standard",
					"score_multiplier_bonus": 0.0
				}
			},
			{
				"count": 0,
				"template": {
					"color_id": "orange",
					"effect_ids": ["explosion"],
					"properties": [],
					"payload_id": "bonus_score",
					"score_multiplier_bonus": 0.15
				}
			},
			{
				"count": 1,
				"template": {
					"color_id": "cyan",
					"effect_ids": ["chain"],
					"properties": [],
					"payload_id": "high_multiplier",
					"score_multiplier_bonus": 0.2
				}
			}
		]
	}
}

## NEW TEMPLATE SYSTEM - creates tempalte instances for the bag
static func create_bubble_template(
	p_color: String,
	p_effects: Array[String] = [],
	p_properties: Array[String] = [],
	p_payload: String = "standard",
	p_mult: float = 0.0
):
	return TEMPLATE_SCRIPT.new(p_color, p_effects, p_properties, p_payload, p_mult)

## default bag for now, later I'll add more presets and a custom bag builder
static func get_default_bubble_bag(bag_id: String = "starter"):
	var preset: Dictionary = _get_bag_preset(bag_id)
	return _build_bag_from_entries(preset.get("entries", []))

static func get_bag_grid_size(bag_id: String = "starter") -> Vector2i:
	var preset: Dictionary = _get_bag_preset(bag_id)
	var grid_size_data = preset.get("grid_size", null)
	if grid_size_data is Dictionary:
		var grid_dict: Dictionary = grid_size_data
		return Vector2i(int(grid_dict.get("x", 0)), int(grid_dict.get("y", 0)))
	if grid_size_data is Vector2i:
		return grid_size_data
	return Vector2i.ZERO

static func get_available_bag_ids() -> Array[String]:
	return BAG_PRESETS.keys()

static func _get_bag_preset(bag_id: String) -> Dictionary:
	if BAG_PRESETS.has(bag_id):
		return BAG_PRESETS[bag_id]
	return BAG_PRESETS["starter"]

static func _build_bag_from_entries(entries: Array):
	var bag: Array = []

	for entry in entries:
		var count: int = max(0, int(entry.get("count", 0)))
		var template_data: Dictionary = entry.get("template", {})
		for i in range(count):
			bag.append(_create_template_from_data(template_data))

	bag.shuffle()
	return bag

static func _create_template_from_data(template_data: Dictionary):
	var color_id: String = str(template_data.get("color_id", "red"))
	var effect_ids: Array[String] = _to_string_array(template_data.get("effect_ids", []))
	var properties: Array[String] = _to_string_array(template_data.get("properties", []))

	var payload_id: String = str(template_data.get("payload_id", "standard"))
	var score_multiplier_bonus: float = float(template_data.get("score_multiplier_bonus", 0.0))

	return create_bubble_template(color_id, effect_ids, properties, payload_id, score_multiplier_bonus)

static func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


# ITEMS
const ITEMS = {
	"double_pop": {
		"name": "Double Pop",
		"description": "Pop two bubbles at once",
		"effect": "double_pop",
		"cost": 50
	}
}

# UPGRADES
const UPGRADES = {
	"score_boost": {
		"name": "Score Boost",
		"description": "+25% score multiplier",
		"effect": "score_multiplier",
		"value": 1.25,
		"cost": 100
	}
}

# SCORING SYSTEM
class ScoreContext:
	extends RefCounted

	var base_points: float = 0
	var bubble_type: String = "normal"
	var grid_position: Vector2i = Vector2i.ZERO
	var is_chain: bool = false
	var chain_depth: int = 0
	var multipliers: Array[float] = []
	var multiplier_bonuses: Array[float] = []
	var flat_bonuses: Array[float] = []
	var _multiplier_debug: Array[String] = []
	var _multiplier_bonus_debug: Array[String] = []
	var _bonus_debug: Array[String] = []

	func _init(
		in_base_points: float,
		in_bubble_type: String,
		in_grid_position: Vector2i,
		in_is_chain: bool,
		in_chain_depth: int = 0
	):
		base_points = in_base_points
		bubble_type = in_bubble_type
		grid_position = in_grid_position
		is_chain = in_is_chain
		chain_depth = in_chain_depth

	func add_multiplier(value: float, label: String = "") -> void:
		if value <= 0.0:
			return
		multipliers.append(value)
		_multiplier_debug.append("%s x%.2f" % [label, value] if not label.is_empty() else "x%.2f" % value)

	func add_multiplier_bonus(value: float, label: String = "") -> void:
		if is_zero_approx(value):
			return
		multiplier_bonuses.append(value)
		_multiplier_bonus_debug.append("%s %+.2f mult" % [label, value] if not label.is_empty() else "%+.2f mult" % value)

	func add_flat_bonus(value: float, label: String = "") -> void:
		if is_zero_approx(value):
			return
		flat_bonuses.append(value)
		_bonus_debug.append("%s %+0.2f" % [label, value] if not label.is_empty() else "%+0.2f" % value)

	func resolve_points() -> int:
		var subtotal := float(base_points)
		for bonus in flat_bonuses:
			subtotal += bonus

		var additive_multiplier_bonus := 0.0
		for mult_bonus in multiplier_bonuses:
			additive_multiplier_bonus += mult_bonus

		var total_multiplier := 1.0
		for mult in multipliers:
			total_multiplier *= mult
		total_multiplier *= max(0.0, 1.0 + additive_multiplier_bonus)

		return max(1, int(round(float(subtotal) * total_multiplier)))

	func get_breakdown_text() -> String:
		var chunks: Array[String] = ["Base %.2f" % base_points]
		chunks.append_array(_multiplier_debug)
		chunks.append_array(_multiplier_bonus_debug)
		chunks.append_array(_bonus_debug)
		
		var subtotal := float(base_points)
		for bonus in flat_bonuses:
			subtotal += bonus
		
		var additive_multiplier_bonus := 0.0
		for mult_bonus in multiplier_bonuses:
			additive_multiplier_bonus += mult_bonus
		
		var total_multiplier := 1.0
		for mult in multipliers:
			total_multiplier *= mult
		total_multiplier *= max(0.0, 1.0 + additive_multiplier_bonus)
		
		chunks.append("Subtotal %.2f" % subtotal)
		chunks.append("Additive mult %+0.2f" % additive_multiplier_bonus)
		chunks.append("Total x%.2f" % total_multiplier)
		chunks.append("=> %d" % resolve_points())
		
		return " | ".join(chunks)

	func absorb_context(other: ScoreContext, base_label: String = "") -> void:
		if not is_zero_approx(other.base_points):
			add_flat_bonus(other.base_points, base_label if not base_label.is_empty() else "")

		for i in range(other.multipliers.size()):
			multipliers.append(other.multipliers[i])
			_multiplier_debug.append(other._multiplier_debug[i])

		for i in range(other.multiplier_bonuses.size()):
			multiplier_bonuses.append(other.multiplier_bonuses[i])
			_multiplier_bonus_debug.append(other._multiplier_bonus_debug[i])

		for i in range(other.flat_bonuses.size()):
			flat_bonuses.append(other.flat_bonuses[i])
			_bonus_debug.append(other._bonus_debug[i])

# MODIFIERS
class Modifier:
	extends RefCounted

	var id: String = "modifier"
	var display_name: String = "Modifier"
	var priority: int = 0

	func can_apply(_context: ScoreContext) -> bool:
		return true

	func apply(_context: ScoreContext) -> void:
		pass

	func get_debug_label() -> String:
		return display_name

class SampleDoubleScoreModifier:
	extends Modifier
	
	func _init():
		id = "double_score"
		display_name = "Double Score"
		priority = 0


# HELPER FUNCTIONS

static func get_color_data(color_id: String) -> Dictionary:
	return COLORS.get(color_id, COLORS["red"])

static func get_effect_data(effect_id: String) -> Dictionary:
	return EFFECTS.get(effect_id, EFFECTS["none"])

static func get_payload_data(payload_id: String) -> Dictionary:
	return PAYLOADS.get(payload_id, PAYLOADS["standard"])

## Check if effect IDs trigger a synergy
static func check_synergy(effect_ids: Array[String]) -> Dictionary:
	for synergy_name in SYNERGIES.keys():
		var synergy: Dictionary = SYNERGIES[synergy_name]
		var required: Array = synergy["required_effects"]
		
		# Check if ALL required effects exist
		if required.all(func(e): return e in effect_ids):
			return {
				"triggered": true,
				"synergy_name": synergy_name,
				"result_effect": synergy["result_effect"],
				"bonus_multiplier": synergy["bonus_multiplier"],
				"description": synergy["description"]
			}
	
	return {
		"triggered": false,
		"synergy_name": "",
		"result_effect": "",
		"bonus_multiplier": 0.0,
		"description": ""
	}

static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

static func get_upgrade(upgrade_id: String) -> Dictionary:
	return UPGRADES.get(upgrade_id, {})

static func get_all_items() -> Array[String]:
	return ITEMS.keys()

static func get_all_upgrades() -> Array[String]:
	return UPGRADES.keys()
