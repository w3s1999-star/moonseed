extends Node

# ─────────────────────────────────────────────────────────────────
# ChocolateData.gd  —  MOONSEED  v0.10
# Chocolate categories, flavor pools, and resolution logic
# for the Coin Plinko system.
# ─────────────────────────────────────────────────────────────────

# ── Category Enum ────────────────────────────────────────────────
enum Category {
	FRUIT,
	CRUNCH,
	FLORAL,
	SPICE,
	WILDCARD
}

# ── Category Metadata ────────────────────────────────────────────
const CATEGORY_DATA: Dictionary = {
	Category.FRUIT: {
		"name": "Fruit",
		"emoji": "🍓",
		"color": Color("#ff6b6b"),
		"zone_position": "left",
		"description": "Fresh, juicy flavors"
	},
	Category.CRUNCH: {
		"name": "Crunch",
		"emoji": "🍪",
		"color": Color("#ffd66b"),
		"zone_position": "center",
		"description": "Textured, satisfying bites"
	},
	Category.FLORAL: {
		"name": "Floral",
		"emoji": "🌸",
		"color": Color("#ff9fff"),
		"zone_position": "float",
		"description": "Delicate, aromatic notes"
	},
	Category.SPICE: {
		"name": "Spice",
		"emoji": "🌶️",
		"color": Color("#ff8c42"),
		"zone_position": "fast",
		"description": "Bold, warming sensations"
	},
	Category.WILDCARD: {
		"name": "Wildcard",
		"emoji": "🎲",
		"color": Color("#a855f7"),
		"zone_position": "shifting",
		"description": "Surprise combinations"
	}
}

# ── Flavor Pools (6 per category) ────────────────────────────────
# Each flavor has: name, emoji, rarity, description, ingredients
const FLAVOR_POOLS: Dictionary = {
	Category.FRUIT: [
		{"name": "Lunar Berry Truffle", "emoji": "🫐", "rarity": "common", "desc": "Moon-kissed berry filling", "ingredients": ["moonmelt_cocoa", "star_milk"]},
		{"name": "Cosmic Citrus Bark", "emoji": "🍊", "rarity": "common", "desc": "Tangy stardust crystals", "ingredients": ["moonmelt_cocoa", "lunar_sugar"]},
		{"name": "Nebula Nectar Bonbon", "emoji": "🍑", "rarity": "uncommon", "desc": "Peach-infused cosmic nectar", "ingredients": ["moonmelt_cocoa", "moonbloom_honey"]},
		{"name": "Starfruit Ganache", "emoji": "⭐", "rarity": "uncommon", "desc": "Tropical starlight cream", "ingredients": ["moonmelt_cocoa", "rare_moon_drop"]},
		{"name": "Eclipse Plum Praline", "emoji": "🍇", "rarity": "rare", "desc": "Dark fruit during totality", "ingredients": ["moonmelt_cocoa", "obsidian_dust"]},
		{"name": "Moonrise Melon Melt", "emoji": "🍈", "rarity": "rare", "desc": "Refreshing lunar melon", "ingredients": ["moonmelt_cocoa", "moonpearls_flake"]}
	],
	Category.CRUNCH: [
		{"name": "Crater Cookie Cluster", "emoji": "🍪", "rarity": "common", "desc": "Crunchy moon rock bits", "ingredients": ["moonmelt_cocoa", "star_milk"]},
		{"name": "Stardust Brittle", "emoji": "✨", "rarity": "common", "desc": "Snap-crackle cosmic candy", "ingredients": ["moonmelt_cocoa", "lunar_sugar"]},
		{"name": "Orbital Wafer Stack", "emoji": "🛸", "rarity": "uncommon", "desc": "Layered orbital crunch", "ingredients": ["moonmelt_cocoa", "moonbloom_honey"]},
		{"name": "Meteorite Meringue", "emoji": "☄️", "rarity": "uncommon", "desc": "Light, airy space meringue", "ingredients": ["moonmelt_cocoa", "rare_moon_drop"]},
		{"name": "Void Crackle Bar", "emoji": "🌑", "rarity": "rare", "desc": "Dark matter crunch", "ingredients": ["moonmelt_cocoa", "obsidian_dust"]},
		{"name": "Pearl Puffed Puffs", "emoji": "💫", "rarity": "rare", "desc": "Puffed moonpearl clusters", "ingredients": ["moonmelt_cocoa", "moonpearls_flake"]}
	],
	Category.FLORAL: [
		{"name": "Moonflower Cream", "emoji": "🌸", "rarity": "common", "desc": "Delicate lunar blossom", "ingredients": ["moonmelt_cocoa", "star_milk"]},
		{"name": "Rose Quartz Ganache", "emoji": "💎", "rarity": "common", "desc": "Pink crystal rose filling", "ingredients": ["moonmelt_cocoa", "lunar_sugar"]},
		{"name": "Lavender Lunar Kiss", "emoji": "💜", "rarity": "uncommon", "desc": "Calming night bloom", "ingredients": ["moonmelt_cocoa", "moonbloom_honey"]},
		{"name": "Orchid Eclipse", "emoji": "🌺", "rarity": "uncommon", "desc": "Rare orchid during totality", "ingredients": ["moonmelt_cocoa", "rare_moon_drop"]},
		{"name": "Narcissus Noir", "emoji": "🌷", "rarity": "rare", "desc": "Dark narcissus infusion", "ingredients": ["moonmelt_cocoa", "obsidian_dust"]},
		{"name": "Pearl Petal Praline", "emoji": "🌼", "rarity": "rare", "desc": "Pearl-dusted flower petals", "ingredients": ["moonmelt_cocoa", "moonpearls_flake"]}
	],
	Category.SPICE: [
		{"name": "Cinnamon Orbit", "emoji": "🫚", "rarity": "common", "desc": "Warm orbital spice", "ingredients": ["moonmelt_cocoa", "star_milk"]},
		{"name": "Ginger Galaxy Snap", "emoji": "🫚", "rarity": "common", "desc": "Zesty cosmic ginger", "ingredients": ["moonmelt_cocoa", "lunar_sugar"]},
		{"name": "Cardamom Comet", "emoji": "💫", "rarity": "uncommon", "desc": "Aromatic comet trail", "ingredients": ["moonmelt_cocoa", "moonbloom_honey"]},
		{"name": "Saffron Supernova", "emoji": "🌟", "rarity": "uncommon", "desc": "Golden explosion of flavor", "ingredients": ["moonmelt_cocoa", "rare_moon_drop"]},
		{"name": "Black Pepper Void", "emoji": "⚫", "rarity": "rare", "desc": "Intense void spice", "ingredients": ["moonmelt_cocoa", "obsidian_dust"]},
		{"name": "Pearl Pepper Praline", "emoji": "✨", "rarity": "rare", "desc": "Peppered moonpearl crunch", "ingredients": ["moonmelt_cocoa", "moonpearls_flake"]}
	],
	Category.WILDCARD: [
		{"name": "Chaos Crunch", "emoji": "🌀", "rarity": "common", "desc": "Unpredictable texture mix", "ingredients": ["moonmelt_cocoa", "star_milk"]},
		{"name": "Quantum Quenelle", "emoji": "⚛️", "rarity": "common", "desc": "Exists in multiple flavors", "ingredients": ["moonmelt_cocoa", "lunar_sugar"]},
		{"name": "Paradox Praline", "emoji": "🔄", "rarity": "uncommon", "desc": "Sweet and savory contradiction", "ingredients": ["moonmelt_cocoa", "moonbloom_honey"]},
		{"name": "Entropy Eclair", "emoji": "💥", "rarity": "uncommon", "desc": "Disordered deliciousness", "ingredients": ["moonmelt_cocoa", "rare_moon_drop"]},
		{"name": "Anomaly Bonbon", "emoji": "❓", "rarity": "rare", "desc": "Tastes different each time", "ingredients": ["moonmelt_cocoa", "obsidian_dust"]},
		{"name": "Infinity Ganache", "emoji": "♾️", "rarity": "rare", "desc": "Endless layers of flavor", "ingredients": ["moonmelt_cocoa", "moonpearls_flake"]}
	]
}

# ── Rarity Weights ────────────────────────────────────────────────
# Pocket index influences rarity distribution
const RARITY_WEIGHTS: Dictionary = {
	"common":    {"base": 0.60, "pocket_bonus": 0.00},
	"uncommon":  {"base": 0.25, "pocket_bonus": 0.05},
	"rare":      {"base": 0.15, "pocket_bonus": 0.10}
}

# ── Resolution Function ───────────────────────────────────────────
# Resolves a chocolate based on category, pocket index, and session type.
func resolve(category: int, pocket_index: int, session_type: String) -> Dictionary:
	# Validate category
	if not CATEGORY_DATA.has(category):
		category = Category.WILDCARD
	
	# Get flavor pool for category
	var flavors: Array = FLAVOR_POOLS.get(category, FLAVOR_POOLS[Category.WILDCARD])
	
	# Determine rarity based on pocket index and session type
	var rarity: String = _determine_rarity(pocket_index, session_type)
	
	# Filter flavors by rarity
	var rarity_flavors: Array = []
	for flavor in flavors:
		if flavor.rarity == rarity:
			rarity_flavors.append(flavor)
	
	# Fallback to common if no flavors match rarity
	if rarity_flavors.is_empty():
		for flavor in flavors:
			if flavor.rarity == "common":
				rarity_flavors.append(flavor)
	
	# Select flavor (deterministic based on pocket index)
	var flavor_index: int = pocket_index % rarity_flavors.size()
	var selected_flavor: Dictionary = rarity_flavors[flavor_index]
	
	# Build result
	return {
		"flavor": selected_flavor,
		"category": CATEGORY_DATA[category],
		"category_id": category,
		"pocket_index": pocket_index,
		"session_type": session_type,
		"rarity": rarity
	}

# ── Rarity Determination ──────────────────────────────────────────
func _determine_rarity(pocket_index: int, session_type: String) -> String:
	# Base weights
	var common_weight: float = RARITY_WEIGHTS.common.base
	var uncommon_weight: float = RARITY_WEIGHTS.uncommon.base
	var rare_weight: float = RARITY_WEIGHTS.rare.base
	
	# Pocket index bonus (edges have higher rare chance)
	var pocket_bonus: float = 0.0
	if pocket_index <= 1 or pocket_index >= 8:
		pocket_bonus = 0.10
	elif pocket_index <= 3 or pocket_index >= 6:
		pocket_bonus = 0.05
	
	rare_weight += pocket_bonus
	
	# Session type bonus
	match session_type:
		"90min":
			uncommon_weight += 0.10
			rare_weight += 0.05
		"50min":
			uncommon_weight += 0.05
	
	# Normalize weights
	var total: float = common_weight + uncommon_weight + rare_weight
	common_weight /= total
	uncommon_weight /= total
	rare_weight /= total
	
	# Roll
	var roll: float = randf()
	if roll < rare_weight:
		return "rare"
	elif roll < rare_weight + uncommon_weight:
		return "uncommon"
	else:
		return "common"

# ── Category Lookup Helpers ───────────────────────────────────────
func get_category_name(category_id: int) -> String:
	if CATEGORY_DATA.has(category_id):
		return CATEGORY_DATA[category_id].name
	return "Unknown"

func get_category_emoji(category_id: int) -> String:
	if CATEGORY_DATA.has(category_id):
		return CATEGORY_DATA[category_id].emoji
	return "❓"

func get_category_color(category_id: int) -> Color:
	if CATEGORY_DATA.has(category_id):
		return CATEGORY_DATA[category_id].color
	return Color.WHITE

func get_all_categories() -> Array:
	return CATEGORY_DATA.keys()

func get_category_from_string(category_str: String) -> int:
	match category_str.to_lower():
		"fruit": return Category.FRUIT
		"crunch": return Category.CRUNCH
		"floral": return Category.FLORAL
		"spice": return Category.SPICE
		"wildcard": return Category.WILDCARD
		_: return Category.WILDCARD