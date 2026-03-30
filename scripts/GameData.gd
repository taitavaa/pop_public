class_name GameData
extends RefCounted

# bubble model.
const COLORS = {
	"ruby": {
		"display_name": "Ruby",
		"color": Color.RED
	},
	"amber": {
		"display_name": "Amber",
		"color": Color.DARK_ORANGE
	},
	"teal": {
		"display_name": "Teal",
		"color": Color.CYAN
	}
}

const EFFECTS = {
	"none": {
		"display_name": "None"
	},
	"explosion_effect": {
		"display_name": "Explosion"
	},
	"color_blob_chain_effect": {
		"display_name": "Color Blob Chain"
	},
	"random_effect": {
		"display_name": "Random"
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

const BUBBLE_RECIPES = {
	"ruby_standard": {
		"color_id": "ruby",
		"effect_ids": ["color_blob_chain_effect"],
		"payload_id": "standard",
		"chance": 45,
		"score_multiplier_bonus": 0.0
	},
	"amber_explosive_bonus": {
		"color_id": "amber",
		"effect_ids": ["explosion_effect"],
		"payload_id": "bonus_score",
		"chance": 30,
		"score_multiplier_bonus": 0.15
	},
	"teal_random_mult": {
		"color_id": "teal",
		"effect_ids": ["color_blob_chain_effect"],
		"payload_id": "high_multiplier",
		"chance": 25,
		"score_multiplier_bonus": 0.2
	}
}

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
static func get_bubble_type_data(type_key: String) -> Dictionary:
	if type_key in BUBBLE_RECIPES:
		return get_bubble_recipe_data(type_key)
	return get_bubble_recipe_data("ruby_standard")

static func pick_random_bubble_type() -> String:
	return pick_random_bubble_recipe_id()

static func get_color_data(color_id: String) -> Dictionary:
	if color_id in COLORS:
		return COLORS[color_id]
	return COLORS["ruby"]

static func get_effect_data(effect_id: String) -> Dictionary:
	if effect_id in EFFECTS:
		return EFFECTS[effect_id]
	return EFFECTS["none"]

static func get_payload_data(payload_id: String) -> Dictionary:
	if payload_id in PAYLOADS:
		return PAYLOADS[payload_id]
	return PAYLOADS["standard"]

static func get_bubble_recipe_data(recipe_id: String) -> Dictionary:
	if recipe_id in BUBBLE_RECIPES:
		return BUBBLE_RECIPES[recipe_id]
	return BUBBLE_RECIPES["ruby_standard"]

static func get_recipe_effect_ids(recipe_data: Dictionary) -> Array[String]:
	var resolved: Array[String] = []

	if recipe_data.has("effect_ids"):
		for value in recipe_data.get("effect_ids", []):
			var effect_id := str(value)
			if effect_id in EFFECTS:
				resolved.append(effect_id)

	if resolved.is_empty() and recipe_data.has("effect_id"):
		var legacy_effect_id := str(recipe_data.get("effect_id", "none"))
		if legacy_effect_id in EFFECTS:
			resolved.append(legacy_effect_id)

	if resolved.is_empty():
		resolved.append("none")

	return resolved

static func get_default_bubble_sheet() -> Dictionary:
	var sheet := {}
	for recipe_id in BUBBLE_RECIPES.keys():
		sheet[recipe_id] = int(BUBBLE_RECIPES[recipe_id].get("chance", 0))
	return sheet

static func pick_random_bubble_recipe_id() -> String:
	return pick_random_bubble_recipe_from_sheet(get_default_bubble_sheet())

static func pick_random_bubble_recipe_from_sheet(sheet_weights: Dictionary) -> String:
	var recipe_ids = BUBBLE_RECIPES.keys()
	if recipe_ids.is_empty():
		return "ruby_standard"

	var total := 0
	for recipe_id in recipe_ids:
		var chance := int(sheet_weights.get(recipe_id, 0))
		if chance > 0:
			total += chance

	if total <= 0:
		return "ruby_standard"

	var roll = randi_range(1, total)
	var cumulative := 0

	for recipe_id in recipe_ids:
		var chance := int(sheet_weights.get(recipe_id, 0))
		if chance <= 0:
			continue
		cumulative += chance
		if roll <= cumulative:
			return recipe_id

	return "ruby_standard"

static func get_item(item_id: String) -> Dictionary:
	if item_id in ITEMS:
		return ITEMS[item_id]
	return {}

static func get_upgrade(upgrade_id: String) -> Dictionary:
	if upgrade_id in UPGRADES:
		return UPGRADES[upgrade_id]
	return {}

static func get_all_items() -> Array[String]:
	return ITEMS.keys()

static func get_all_upgrades() -> Array[String]:
	return UPGRADES.keys()
