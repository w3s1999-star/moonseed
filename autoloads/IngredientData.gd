extends Node

# ─────────────────────────────────────────────────────────────────
# IngredientData.gd  —  MOONSEED  v0.9.0
# GDD §9.3 / §9.5  Static catalog for ingredients + sweets.
# Autoloaded so any system can query INGREDIENTS / SWEETS.
# ─────────────────────────────────────────────────────────────────

# ── Ingredient property tags (§9.4) ──────────────────────────────
const PROPS := {
	"Sweet":   "Sweet",
	"Cosmic":  "Cosmic",
	"Bitter":  "Bitter",
	"Floral":  "Floral",
	"Dark":    "Dark",
}

# ── Ingredient catalog (§9.3) ─────────────────────────────────────
# key → {name, rarity, emoji, desc, props: Array[String]}
const INGREDIENTS: Dictionary = {
	"star_milk": {
		"name":   "Star-milk",
		"rarity": "common",
		"emoji":  "🥛",
		"desc":   "Gathered from moonlit condensation. Base ingredient.",
		"props":  ["Sweet", "Cosmic"],
	},
	"void_cocoa": {
		"name":   "Void Cocoa",
		"rarity": "common",
		"emoji":  "🫘",
		"desc":   "Dark, bitter cacao from the garden's soil layer.",
		"props":  ["Bitter", "Dark"],
	},
	"lunar_sugar": {
		"name":   "Lunar Sugar",
		"rarity": "common",
		"emoji":  "🍬",
		"desc":   "Crystallized moon drop sugar. Adds sweetness to effects.",
		"props":  ["Sweet"],
	},
	"moonbloom_honey": {
		"name":   "Moonbloom Honey",
		"rarity": "uncommon",
		"emoji":  "🍯",
		"desc":   "Extracted from Moonflower blossoms. Required for waxing recipes.",
		"props":  ["Floral", "Sweet"],
	},
	"rare_moon_drop": {
		"name":   "Rare Moon-drop",
		"rarity": "rare",
		"emoji":  "💧",
		"desc":   "Concentrated lunar energy. From full-bloom Lunar plants.",
		"props":  ["Cosmic", "Floral"],
	},
	"obsidian_dust": {
		"name":   "Obsidian Dust",
		"rarity": "rare",
		"emoji":  "⬛",
		"desc":   "Ground from Lunar Bazaar walls. High-risk/high-reward.",
		"props":  ["Dark", "Bitter"],
	},
	"moonpearls_flake": {
		"name":   "Moonpearls Flake",
		"rarity": "epic",
		"emoji":  "✨",
		"desc":   "Crystallized moonpearls. Enables legendary Sweets.",
		"props":  ["Cosmic", "Sweet"],
	},
	"moonmelt_cocoa": {
		"name":   "Moonmelt Cocoa",
		"rarity": "common",
		"emoji":  "🍫",
		"desc":   "Generated from focus sessions. Primary crafting ingredient.",
		"props":  ["Sweet", "Dark"],
	},
}

# ── Sweet catalog (§9.5) ─────────────────────────────────────────
# key → {name, emoji, recipe: Array of ingredient keys (with counts),
#         desc, effect_id, effect_duration, effect_value}
# recipe format: Array of {id, qty}
const SWEETS: Dictionary = {
	"comet_truffle": {
		"name":   "Comet Truffle",
		"emoji":  "☄️",
		"recipe": [{"id":"moonmelt_cocoa","qty":2}, {"id":"lunar_sugar","qty":1}],
		"desc":   "All d6s → d8s for next 5 Moondrop rolls.",
		"effect_id": "upgrade_d6_to_d8",
		"effect_value": 5,
		"effect_duration": 0,
	},
	"eclipse_bonbon": {
		"name":   "Eclipse Bonbon",
		"emoji":  "🌑",
		"recipe": [{"id":"moonmelt_cocoa","qty":3}, {"id":"star_milk","qty":1}],
		"desc":   "Instantly advances all growing Garden plants by 4 hours.",
		"effect_id": "advance_garden",
		"effect_value": 4,
		"effect_duration": 0,
	},
	"jackpot_caramel": {
		"name":   "Jackpot Caramel",
		"emoji":  "🍮",
		"recipe": [{"id":"moonmelt_cocoa","qty":1}, {"id":"lunar_sugar","qty":2}, {"id":"rare_moon_drop","qty":1}],
		"desc":   "Next activated Relic triggers its effect twice.",
		"effect_id": "double_relic",
		"effect_value": 1,
		"effect_duration": 0,
	},
	"moonrise_fudge": {
		"name":   "Moonrise Fudge",
		"emoji":  "🌙",
		"recipe": [{"id":"moonbloom_honey","qty":1}, {"id":"star_milk","qty":2}],
		"desc":   "Waxing phase effects doubled for 24 hours.",
		"effect_id": "double_waxing",
		"effect_value": 2,
		"effect_duration": 86400,
	},
	"void_praline": {
		"name":   "Void Praline",
		"emoji":  "🕳️",
		"recipe": [{"id":"moonmelt_cocoa","qty":2}, {"id":"obsidian_dust","qty":1}],
		"desc":   "Next 3 dice rolls: max value always triggers explosion.",
		"effect_id": "force_explosion",
		"effect_value": 3,
		"effect_duration": 0,
	},
	"moonpearls_bark": {
		"name":   "Moonpearls Bark",
		"emoji":  "🌟",
		"recipe": [{"id":"moonpearls_flake","qty":1}, {"id":"lunar_sugar","qty":2}],
		"desc":   "Dice Box Score ×1.5 on next save.",
		"effect_id": "score_multiplier",
		"effect_value": 1.5,
		"effect_duration": 0,
	},
	"silver_fern_cream": {
		"name":   "Silver Fern Cream",
		"emoji":  "🌿",
		"recipe": [{"id":"star_milk","qty":2}, {"id":"moonbloom_honey","qty":1}],
		"desc":   "Forest plant bonuses doubled for this session.",
		"effect_id": "double_forest_bonus",
		"effect_value": 2,
		"effect_duration": 0,
	},
	"lucky_crunch": {
		"name":   "Lucky Crunch",
		"emoji":  "🍀",
		"recipe": [{"id":"lunar_sugar","qty":3}],
		"desc":   "5 moonpearls for every 6 rolled this session.",
		"effect_id": "moonpearls_per_six",
		"effect_value": 5,
		"effect_duration": 0,
	},
	"focus_bonbon": {
		"name":   "Focus Bonbon",
		"emoji":  "🎯",
		"recipe": [{"id":"star_milk","qty":1}, {"id":"obsidian_dust","qty":1}],
		"desc":   "Next Pomodoro session yields double ingredients.",
		"effect_id": "double_ingredients",
		"effect_value": 2,
		"effect_duration": 0,
	},
	"full_moon_ganache": {
		"name":   "Full Moon Ganache",
		"emoji":  "🌕",
		"recipe": [{"id":"rare_moon_drop","qty":2}, {"id":"moonpearls_flake","qty":1}],
		"desc":   "Moon phase bonuses are max-tier regardless of phase.",
		"effect_id": "max_moon_phase",
		"effect_value": 1,
		"effect_duration": 86400,
	},
}

# ── Session yield tables (§9.2) ───────────────────────────────────
# Returns Array of {id: String, qty: int} for a session type.
func get_session_yield(session_type: String, has_bonus: bool = false) -> Array:
	var result: Array = []
	var base_qty: int = 1
	
	# Different session lengths yield different amounts
	match session_type:
		"25min":
			base_qty = 1
		"50min":
			base_qty = 2
		"90min":
			base_qty = 3
	
	# Always yield Moonmelt Cocoa
	result.append({"id": "moonmelt_cocoa", "qty": base_qty})
	
	# Bonus ingredient from relic (if active)
	if has_bonus:
		result.append({"id": "moonmelt_cocoa", "qty": 1})
	
	return result

# ── Chocolate Coin Yield (NEW) ────────────────────────────────────
# Returns Array of {type: String, qty: int} for chocolate coins.
func get_coin_reward(duration_minutes: int) -> Array:
	var result: Array = []
	match duration_minutes:
		25:
			result.append({"type": "bar", "qty": 1})
		50:
			result.append({"type": "truffle", "qty": 1})
			result.append({"type": "bar", "qty": 1})
		90:
			result.append({"type": "artisan", "qty": 1})
			result.append({"type": "truffle", "qty": 1})
	return result

# ── Recipe lookup helpers ─────────────────────────────────────────
func recipe_matches(sweet_key: String, candidate: Array) -> bool:
	# candidate: Array of {id, qty}
	if not SWEETS.has(sweet_key): return false
	var recipe: Array = SWEETS[sweet_key]["recipe"]
	if recipe.size() != candidate.size(): return false
	var recipe_map := {}
	for r in recipe: recipe_map[r["id"]] = r["qty"]
	for c in candidate:
		if not recipe_map.has(c["id"]): return false
		if recipe_map[c["id"]] != c["qty"]: return false
	return true

func try_discover_recipe(candidate: Array) -> String:
	for sweet_key in SWEETS.keys():
		if recipe_matches(sweet_key, candidate):
			return sweet_key
	return ""
