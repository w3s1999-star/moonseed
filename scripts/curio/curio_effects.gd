class_name CurioEffects
extends RefCounted

## CurioEffects — Static handler mapping effect_key strings to gameplay logic.
##
## Each handler receives a mutable context Dictionary and modifies it
## to apply the curio's effect during the dice resolution pipeline.
##
## Context fields (vary by trigger phase):
##   "dice_results"    : Array[int]  — current face values
##   "dice_sides"      : int         — sides of the dice
##   "dice_count"      : int         — number of dice
##   "moondrops"       : int         — accumulated moondrops (mutable)
##   "rerolls_gained"  : int         — bonus rerolls to grant (mutable)
##   "roll_count"      : int         — rolls this round
##   "is_first_roll"   : bool        — true if this is the first roll of the round

static func apply(effect_key: String, ctx: Dictionary) -> void:
	match effect_key:
		# ── ROLL_SHAPING ──────────────────────────────────────
		"min_roll_floor":
			_min_roll_floor(ctx)
		"random_boost":
			_random_boost(ctx)
		"set_to_four":
			_set_to_four(ctx)

		# ── REROLL_CONTROL ────────────────────────────────────
		"flat_reroll_gain":
			_flat_reroll_gain(ctx)
		"reroll_on_six":
			_reroll_on_six(ctx)
		"lock_with_payoff":
			_lock_with_payoff(ctx)

		# ── TRIGGER ──────────────────────────────────────────
		"bonus_on_six":
			_bonus_on_six(ctx)
		"low_roll_consolation":
			_low_roll_consolation(ctx)
		"first_roll_bonus":
			_first_roll_bonus(ctx)
		"dice_count_trigger":
			_dice_count_trigger(ctx)

		# ── PATTERN ──────────────────────────────────────────
		"pair_bonus":
			_pair_bonus(ctx)
		"even_bonus":
			_even_bonus(ctx)

		# ── FLOW ─────────────────────────────────────────────
		"unchanged_die_bonus":
			_unchanged_die_bonus(ctx)

		# ── SCALING ──────────────────────────────────────────
		"per_roll_scaling":
			_per_roll_scaling(ctx)
		"low_roll_investment":
			_low_roll_investment(ctx)

		_:
			push_warning("CurioEffects: unknown effect_key '%s'" % effect_key)

# ══════════════════════════════════════════════════════════════
#  EFFECT HANDLERS
# ══════════════════════════════════════════════════════════════

# ── ROLL_SHAPING ──────────────────────────────────────────────

## Gentle Polishing Stone: Each die rolls minimum 2 instead of 1.
static func _min_roll_floor(ctx: Dictionary) -> void:
	var results: Array = ctx.get("dice_results", [])
	for i in range(results.size()):
		if results[i] < 2:
			results[i] = 2
	ctx["dice_results"] = results

## Lunar Drift Charm: +1 to one random die each roll.
static func _random_boost(ctx: Dictionary) -> void:
	var results: Array = ctx.get("dice_results", [])
	if results.is_empty():
		return
	var idx := randi() % results.size()
	var sides: int = ctx.get("dice_sides", 6)
	results[idx] = mini(results[idx] + 1, sides)
	ctx["dice_results"] = results

## Cratered Moonstone: Set one die to 4 after rolling. (Once per roll.)
static func _set_to_four(ctx: Dictionary) -> void:
	var results: Array = ctx.get("dice_results", [])
	if results.is_empty():
		return
	# Pick the lowest die (most useful to set to 4)
	var min_idx := 0
	var min_val: int = results[0]
	for i in range(1, results.size()):
		if results[i] < min_val:
			min_val = results[i]
			min_idx = i
	if min_val < 4:
		results[min_idx] = 4
	ctx["dice_results"] = results

# ── REROLL_CONTROL ────────────────────────────────────────────

## Echo Chamber: Gain +1 reroll at the start of each roll phase.
static func _flat_reroll_gain(ctx: Dictionary) -> void:
	ctx["rerolls_gained"] = int(ctx.get("rerolls_gained", 0)) + 1

## Scattered Star Chart: +1 reroll if you rolled at least one 6.
static func _reroll_on_six(ctx: Dictionary) -> void:
	var results: Array = ctx.get("dice_results", [])
	var sides: int = ctx.get("dice_sides", 6)
	if results.has(sides):
		ctx["rerolls_gained"] = int(ctx.get("rerolls_gained", 0)) + 1

## Hollow Die Frame: Lock one die. Locked dice can't be rerolled but give +2 Moondrops.
## Effect: Adds +2 moondrops (locking is a UI concern handled elsewhere).
static func _lock_with_payoff(ctx: Dictionary) -> void:
	ctx["moondrops"] = int(ctx.get("moondrops", 0)) + 2

# ── TRIGGER ──────────────────────────────────────────────────

## Cracked Moon Fragment: If any die shows 6, gain +3 bonus Moondrops.
static func _bonus_on_six(ctx: Dictionary) -> void:
	var results: Array = ctx.get("dice_results", [])
	var sides: int = ctx.get("dice_sides", 6)
	if results.has(sides):
		ctx["moondrops"] = int(ctx.get("moondrops", 0)) + 3

## Whispering Quartz: If the total roll is 7 or less, gain +1 reroll.
static func _low_roll_consolation(ctx: Dictionary) -> void:
	var results: Array = ctx.get("dice_results", [])
	var total := 0
	for v in results:
		total += v
	if total <= 7:
		ctx["rerolls_gained"] = int(ctx.get("rerolls_gained", 0)) + 1

## Cavern Echo: First roll of each round: +2 Moondrops.
static func _first_roll_bonus(ctx: Dictionary) -> void:
	if ctx.get("is_first_roll", false):
		ctx["moondrops"] = int(ctx.get("moondrops", 0)) + 2

## Glacial Resonance: If you roll exactly 3 dice, gain +4 Moondrops.
static func _dice_count_trigger(ctx: Dictionary) -> void:
	var count: int = ctx.get("dice_count", 0)
	if count == 3:
		ctx["moondrops"] = int(ctx.get("moondrops", 0)) + 4

# ── PATTERN ──────────────────────────────────────────────────

## Twin Hollows: +3 Moondrops if any two dice match.
static func _pair_bonus(ctx: Dictionary) -> void:
	var results: Array = ctx.get("dice_results", [])
	var seen := {}
	for v in results:
		if seen.has(v):
			ctx["moondrops"] = int(ctx.get("moondrops", 0)) + 3
			return
		seen[v] = true

## Even Moonstone: +1 Moondrop for each even-value die.
static func _even_bonus(ctx: Dictionary) -> void:
	var results: Array = ctx.get("dice_results", [])
	var bonus := 0
	for v in results:
		if v % 2 == 0:
			bonus += 1
	if bonus > 0:
		ctx["moondrops"] = int(ctx.get("moondrops", 0)) + bonus

# ── FLOW ─────────────────────────────────────────────────────

## Orbital Residue: After rerolling, each die that didn't change gives +1 Moondrop.
## Requires "dice_before_reroll" in context (set by the reroll handler).
static func _unchanged_die_bonus(ctx: Dictionary) -> void:
	var before: Array = ctx.get("dice_before_reroll", [])
	var after: Array = ctx.get("dice_results", [])
	if before.is_empty() or after.is_empty():
		return
	var bonus := 0
	var limit := mini(before.size(), after.size())
	for i in range(limit):
		if before[i] == after[i]:
			bonus += 1
	if bonus > 0:
		ctx["moondrops"] = int(ctx.get("moondrops", 0)) + bonus

# ── SCALING ──────────────────────────────────────────────────

## Selenite Lattice: +1 Moondrop per roll made this round. (Resets each round.)
static func _per_roll_scaling(ctx: Dictionary) -> void:
	var roll_count: int = ctx.get("roll_count", 0)
	if roll_count > 0:
		ctx["moondrops"] = int(ctx.get("moondrops", 0)) + roll_count

## Stalactite Growth: Each time you roll a 1, this Curio gains +1 Moondrop bonus.
## (Resets each round.) Handled via CurioManager tracking.
static func _low_roll_investment(ctx: Dictionary) -> void:
	var results: Array = ctx.get("dice_results", [])
	var stacks: int = ctx.get("stalactite_stacks", 0)
	# Count new 1s this roll
	for v in results:
		if v == 1:
			stacks += 1
	ctx["stalactite_stacks"] = stacks
	if stacks > 0:
		ctx["moondrops"] = int(ctx.get("moondrops", 0)) + stacks