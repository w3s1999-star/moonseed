class_name CurioDatabase
extends RefCounted

## CurioDatabase — Static registry of all Curios from the design pool.
## Provides weighted random selection, filtering, and lookup.

const RARITY_WEIGHTS := {
	"common": 60,
	"uncommon": 25,
	"rare": 10,
	"exotic": 5,
}

# ── Starter Curios (15) ──────────────────────────────────────────
# Populated from CURIO_DESIGN_POOL.md starter set.
static var _curios: Array[CurioResource] = []
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_curios = [
		# ── ROLL_SHAPING ──────────────────────────────────────
		CurioResource.create(
			"gentle_polishing_stone",
			"Gentle Polishing Stone",
			"Each die rolls minimum 2 instead of 1.",
			"ROLL_SHAPING", "common", "passive",
			"min_roll_floor", "🪨",
			"Floor raiser. Softens worst-case rolls without breaking ceiling."
		),
		CurioResource.create(
			"lunar_drift_charm",
			"Lunar Drift Charm",
			"+1 to one random die each roll.",
			"ROLL_SHAPING", "common", "on_roll_resolved",
			"random_boost", "🌙",
			"Small consistent boost. Encourages rolling more dice."
		),
		CurioResource.create(
			"cratered_moonstone",
			"Cratered Moonstone",
			"Set one die to 4 after rolling. (Once per roll.)",
			"ROLL_SHAPING", "uncommon", "on_roll_resolved",
			"set_to_four", "🌕",
			"Precision tool. Enables specific pattern builds."
		),

		# ── REROLL_CONTROL ────────────────────────────────────
		CurioResource.create(
			"echo_chamber",
			"Echo Chamber",
			"Gain +1 reroll at the start of each roll phase.",
			"REROLL_CONTROL", "common", "on_roll_start",
			"flat_reroll_gain", "🔔",
			"Baseline reroll economy. Foundational Curio."
		),
		CurioResource.create(
			"scattered_star_chart",
			"Scattered Star Chart",
			"+1 reroll if you rolled at least one 6.",
			"REROLL_CONTROL", "common", "on_roll_resolved",
			"reroll_on_six", "🗺️",
			"Rewards high-rolling. Shifts from anti-duplicate to pro-high-roll."
		),
		CurioResource.create(
			"hollow_die_frame",
			"Hollow Die Frame",
			"Lock one die after rolling. Locked dice can't be rerolled but give +2 Moondrops.",
			"REROLL_CONTROL", "uncommon", "on_roll_resolved",
			"lock_with_payoff", "🔲",
			"Strategic lock. Trade flexibility for guaranteed value."
		),

		# ── TRIGGER ──────────────────────────────────────────
		CurioResource.create(
			"cracked_moon_fragment",
			"Cracked Moon Fragment",
			"If any die shows 6, gain +3 bonus Moondrops.",
			"TRIGGER", "common", "on_roll_resolved",
			"bonus_on_six", "🌑",
			"Jackpot incentive. Makes 6s exciting beyond their base value."
		),
		CurioResource.create(
			"whispering_quartz",
			"Whispering Quartz",
			"If the total roll is 7 or less, gain +1 reroll.",
			"TRIGGER", "common", "on_roll_resolved",
			"low_roll_consolation", "💎",
			"Consolation prize. Low rolls aren't wasted."
		),
		CurioResource.create(
			"cavern_echo",
			"Cavern Echo",
			"First roll of each round: +2 Moondrops.",
			"TRIGGER", "common", "on_first_roll",
			"first_roll_bonus", "🏔️",
			"Opening advantage. Rewards getting it right early."
		),

		# ── PATTERN ──────────────────────────────────────────
		CurioResource.create(
			"twin_hollows",
			"Twin Hollows",
			"+3 Moondrops if any two dice match.",
			"PATTERN", "common", "on_roll_resolved",
			"pair_bonus", "👯",
			"Basic pair reward. Accessible pattern Curio."
		),
		CurioResource.create(
			"even_moonstone",
			"Even Moonstone",
			"+1 Moondrop for each even-value die.",
			"PATTERN", "common", "on_roll_resolved",
			"even_bonus", "🔵",
			"Parity reward. Simple, stacks with multiple dice."
		),

		# ── FLOW ─────────────────────────────────────────────
		CurioResource.create(
			"orbital_residue",
			"Orbital Residue",
			"After rerolling, each die that didn't change gives +1 Moondrop.",
			"FLOW", "common", "on_reroll_resolved",
			"unchanged_die_bonus", "🌀",
			"Reroll insurance. Kept dice still contribute."
		),

		# ── SCALING ──────────────────────────────────────────
		CurioResource.create(
			"selenite_lattice",
			"Selenite Lattice",
			"+1 Moondrop per roll made this round. (Resets each round.)",
			"SCALING", "uncommon", "on_roll_resolved",
			"per_roll_scaling", "🔷",
			"Snowball within round. Rewards multiple rolls."
		),
		CurioResource.create(
			"stalactite_growth",
			"Stalactite Growth",
			"Each time you roll a 1, this Curio gains +1 Moondrop bonus. (Resets each round.)",
			"SCALING", "uncommon", "on_roll_resolved",
			"low_roll_investment", "🪨",
			"Turns bad rolls into investment. Emotional rescue."
		),

		# ── TRIGGER (uncommon) ───────────────────────────────
		CurioResource.create(
			"glacial_resonance",
			"Glacial Resonance",
			"If you roll exactly 3 dice, gain +4 Moondrops.",
			"TRIGGER", "uncommon", "on_roll_resolved",
			"dice_count_trigger", "❄️",
			"Dice count incentive. Shapes pool-building decisions."
		),
	]

static func get_all_curios() -> Array[CurioResource]:
	_ensure_initialized()
	return _curios

static func get_curio_by_id(curio_id: String) -> CurioResource:
	_ensure_initialized()
	for c in _curios:
		if c.id == curio_id:
			return c
	return null

static func get_curios_by_family(family: String) -> Array[CurioResource]:
	_ensure_initialized()
	var result: Array[CurioResource] = []
	for c in _curios:
		if c.family == family:
			result.append(c)
	return result

static func get_curios_by_rarity(rarity: String) -> Array[CurioResource]:
	_ensure_initialized()
	var result: Array[CurioResource] = []
	for c in _curios:
		if c.rarity == rarity:
			result.append(c)
	return result

static func get_random_curio(rarity_bias: String = "normal") -> CurioResource:
	_ensure_initialized()
	var pool := _build_weighted_pool(rarity_bias)
	if pool.is_empty():
		return _curios[0] if not _curios.is_empty() else null
	return pool[randi() % pool.size()]

static func _build_weighted_pool(rarity_bias: String) -> Array[CurioResource]:
	var pool: Array[CurioResource] = []
	for c in _curios:
		var weight: int = RARITY_WEIGHTS.get(c.rarity, 10)
		# Adjust weights based on crate type
		match rarity_bias:
			"rare_focused":
				if c.rarity == "rare" or c.rarity == "exotic":
					weight *= 3
				elif c.rarity == "common":
					weight = max(1, weight / 3)
			"common_focused":
				if c.rarity == "common":
					weight *= 2
				elif c.rarity == "rare" or c.rarity == "exotic":
					weight = max(1, weight / 2)
		for _i in range(weight):
			pool.append(c)
	return pool