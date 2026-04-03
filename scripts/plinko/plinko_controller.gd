extends Node

# ─────────────────────────────────────────────────────────────────
# plinko_controller.gd  —  MOONSEED  v0.10
# Manages the Plinko board, coin drops, and category resolution.
# ─────────────────────────────────────────────────────────────────

signal coin_dropped(coin_type: String)
signal coin_landed(pocket_index: int, category: int)
signal resolution_complete(chocolate_result: Dictionary)

# ── Board Configuration ──────────────────────────────────────────
const BOARD_WIDTH: int = 10
const BOARD_HEIGHT: int = 12
const POCKET_COUNT: int = 10
const PEG_ROWS: int = 8

# ── Category Zone Mapping ────────────────────────────────────────
# Pockets are mapped to category zones
const POCKET_ZONES: Array[int] = [
	0, 0,  # Fruit (left)
	1, 1,  # Crunch (center-left)
	2, 2,  # Floral (center)
	3, 3,  # Spice (center-right)
	4, 4   # Wildcard (right)
]

# ── Influence Weights ────────────────────────────────────────────
var influence_weights: Dictionary = {
	"fruit": 0,
	"crunch": 0,
	"floral": 0,
	"spice": 0,
	"wild": 0
}

# ── Active Coin ──────────────────────────────────────────────────
var active_coin_type: String = "bar"
var active_coin_node: Node2D = null
var is_dropping: bool = false

# ── Board State ──────────────────────────────────────────────────
var current_pocket_index: int = -1
var drop_history: Array = []

# ── Physics Configuration ────────────────────────────────────────
const GRAVITY: float = 980.0
const BOUNCE_DAMPING: float = 0.6
const PEG_RADIUS: float = 8.0
const COIN_RADIUS: float = 12.0

# ── Coin Type Properties ────────────────────────────────────────
const COIN_PROPERTIES: Dictionary = {
	"bar": {
		"mass": 1.0,
		"bounce": 0.7,
		"spread": 1.2,  # wider spread
		"steering": 0.0,
		"glow": false,
		"color": Color("#8B4513")
	},
	"truffle": {
		"mass": 1.3,
		"bounce": 0.5,
		"spread": 0.9,
		"steering": 0.15,  # slight steering
		"glow": false,
		"color": Color("#4a2c2a")
	},
	"artisan": {
		"mass": 1.5,
		"bounce": 0.4,
		"spread": 0.7,
		"steering": 0.3,  # strong control
		"glow": true,
		"color": Color("#ffd700")
	}
}

func _ready() -> void:
	reset_influence()

# ── Influence Management ──────────────────────────────────────────
func add_influence(category: String, amount: int = 1) -> void:
	if influence_weights.has(category):
		influence_weights[category] += amount
		# Cap influence
		influence_weights[category] = min(influence_weights[category], 10)

func reset_influence() -> void:
	for key in influence_weights:
		influence_weights[key] = 0

func get_dominant_category() -> int:
	var max_weight: int = -1
	var dominant: String = "wild"
	
	for category in influence_weights:
		if influence_weights[category] > max_weight:
			max_weight = influence_weights[category]
			dominant = category
	
	# Map string to ChocolateData.Category
	match dominant:
		"fruit": return 0  # Category.FRUIT
		"crunch": return 1  # Category.CRUNCH
		"floral": return 2  # Category.FLORAL
		"spice": return 3  # Category.SPICE
		_: return 4  # Category.WILDCARD

func get_influence_weight(category: String) -> int:
	return influence_weights.get(category, 0)

# ── Coin Drop Logic ──────────────────────────────────────────────
func drop_coin(coin_type: String) -> void:
	if is_dropping:
		return
	
	active_coin_type = coin_type
	is_dropping = true
	
	# Emit signal
	coin_dropped.emit(coin_type)
	
	# Calculate landing pocket with influence
	var pocket_index: int = _calculate_landing_pocket()
	current_pocket_index = pocket_index
	
	# Get category for pocket
	var category: int = POCKET_ZONES[pocket_index] if pocket_index < POCKET_ZONES.size() else 4
	
	# Apply influence bias
	category = _apply_influence_bias(category)
	
	# Record drop
	drop_history.append({
		"coin_type": coin_type,
		"pocket": pocket_index,
		"category": category,
		"influence": influence_weights.duplicate()
	})
	
	# Emit landed signal
	coin_landed.emit(pocket_index, category)
	
	# Reset influence after drop
	reset_influence()
	is_dropping = false

func _calculate_landing_pocket() -> int:
	# Base random pocket
	var base_pocket: int = randi() % POCKET_COUNT
	
	# Apply coin spread modifier
	var props: Dictionary = COIN_PROPERTIES.get(active_coin_type, COIN_PROPERTIES["bar"])
	var spread: float = props.spread
	
	# Wider spread = more variance
	var spread_range: int = int(POCKET_COUNT * spread * 0.3)
	var offset: int = randi() % max(1, spread_range * 2) - spread_range
	
	var final_pocket: int = clampi(base_pocket + offset, 0, POCKET_COUNT - 1)
	
	# Apply influence pull toward dominant category
	var dominant: int = get_dominant_category()
	var target_pockets: Array[int] = []
	for i in range(POCKET_ZONES.size()):
		if POCKET_ZONES[i] == dominant:
			target_pockets.append(i)
	
	if not target_pockets.is_empty() and randf() < 0.3:
		# 30% chance to be pulled toward dominant category
		final_pocket = target_pockets[randi() % target_pockets.size()]
	
	return final_pocket

func _apply_influence_bias(category: int) -> int:
	# Check if influence should override category
	var dominant: int = get_dominant_category()
	var max_weight: int = 0
	for key in influence_weights:
		max_weight = max(max_weight, influence_weights[key])
	
	# If influence is strong enough, override
	if max_weight >= 3 and randf() < 0.6:
		return dominant
	
	# Otherwise, 40% chance to shift toward dominant
	if max_weight >= 1 and randf() < 0.4:
		return dominant
	
	return category

# ── Resolution ────────────────────────────────────────────────────
func resolve_chocolate(session_type: String) -> Dictionary:
	if current_pocket_index < 0:
		return {}
	
	var category: int = POCKET_ZONES[current_pocket_index] if current_pocket_index < POCKET_ZONES.size() else 4
	
	# Apply final influence
	category = _apply_influence_bias(category)
	
	# Use ChocolateData to resolve
	var result: Dictionary = ChocolateData.resolve(category, current_pocket_index, session_type)
	
	# Emit resolution signal
	resolution_complete.emit(result)
	
	# Emit chocolate resolved signal
	SignalBus.chocolate_resolved.emit(result.flavor.name, ChocolateData.get_category_name(category))
	
	return result

# ── Coin Properties ──────────────────────────────────────────────
func get_coin_properties(coin_type: String) -> Dictionary:
	return COIN_PROPERTIES.get(coin_type, COIN_PROPERTIES["bar"])

func get_coin_color(coin_type: String) -> Color:
	var props: Dictionary = get_coin_properties(coin_type)
	return props.color

func get_coin_mass(coin_type: String) -> float:
	var props: Dictionary = get_coin_properties(coin_type)
	return props.mass

func has_coin_glow(coin_type: String) -> bool:
	var props: Dictionary = get_coin_properties(coin_type)
	return props.glow

# ── Zone Interaction ──────────────────────────────────────────────
func on_zone_entered(zone_category: String) -> void:
	# Add influence when coin enters a zone
	add_influence(zone_category, 1)
	SignalBus.plinko_zone_entered.emit(zone_category)

# ── History ───────────────────────────────────────────────────────
func get_drop_history() -> Array:
	return drop_history

func get_last_drop() -> Dictionary:
	if drop_history.is_empty():
		return {}
	return drop_history[-1]

func clear_history() -> void:
	drop_history.clear()