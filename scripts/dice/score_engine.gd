extends RefCounted
class_name ScoreEngine

## Scoring logic separated from GameData.
## Builds roll packets, computes moondrops, applies multipliers, yields moonpearls.

# ── Moondrop Constants ────────────────────────────────────────────
const MOONDROPS_PER_FACE: int = 5  # base moondrops per die face value
const MAX_ROLL_BONUS: int = 10     # bonus moondrops for rolling max
const MIN_ROLL_PENALTY: int = 0    # no penalty for rolling 1

# ── Moonpearl Conversion ─────────────────────────────────────────
const MOONPEARL_THRESHOLD: int = 50  # moondrops needed per pearl
const MIN_MOONPEARLS: int = 1        # always at least 1 pearl if any score

# ── Roll Packet Builder ──────────────────────────────────────────
## Creates a mutable roll packet from dice entries.
## Each entry: {task_id, task_name, sides, results[], final_roll, peak_roll}
func build_roll_packet(entries: Array, roll_id: String = "") -> Dictionary:
	var dice: Array = []
	var flat_total: int = 0

	for entry in entries:
		var task_id: int = int(entry.get("task_id", -1))
		var task_name: String = str(entry.get("task_name", ""))
		var sides: int = int(entry.get("sides", 6))
		var results: Array = entry.get("results", [])
		var final_roll: int = int(entry.get("final_roll", 0))
		var peak_roll: int = int(entry.get("peak_roll", 0))
		var is_max: bool = peak_roll == sides and sides > 1
		var base_moondrops: int = final_roll * MOONDROPS_PER_FACE

		if is_max:
			base_moondrops += MAX_ROLL_BONUS

		flat_total += base_moondrops

		dice.append({
			"die_id": "d%d_%d" % [sides, task_id],
			"task_id": task_id,
			"task_name": task_name,
			"face_value": final_roll,
			"peak_roll": peak_roll,
			"sides": sides,
			"is_max": is_max,
			"base_moondrops": base_moondrops,
			"bonus_moondrops": 0,
			"mult_tags": [],
			"effect_tags": ["explosion"] if is_max else [],
			"results": results,
		})

	if roll_id.is_empty():
		roll_id = "roll_%d" % Time.get_ticks_msec()

	return {
		"roll_id": roll_id,
		"dice": dice,
		"clusters": [],
		"relic_deltas": [],
		"die_effect_deltas": [],
		"strength_sources": [],
		"flat_total": flat_total,
		"multiplied_total": flat_total,
		"moonpearls_gained": 0,
	}

# ── Base Moondrop Computation ────────────────────────────────────
## Computes raw moondrop amounts per die. Already done in build_roll_packet,
## but separated here for clarity and future modifications.
func compute_base_moondrops(packet: Dictionary) -> void:
	var total: int = 0
	for die in packet.get("dice", []):
		var base: int = int(die.get("base_moondrops", 0))
		var bonus: int = int(die.get("bonus_moondrops", 0))
		total += base + bonus
	# Add curio bonus moondrops (from active curio effects)
	var curio_bonus: int = int(packet.get("curio_bonus_moondrops", 0))
	total += curio_bonus
	packet["flat_total"] = total
	packet["multiplied_total"] = total

# ── Multiplier Application ───────────────────────────────────────
## Applies strength sources AFTER merge (not before).
## Each source: {source_id, multiplier, flat_bonus}
func apply_multipliers(packet: Dictionary) -> void:
	var base: float = float(packet.get("flat_total", 0))
	var total_multiplier: float = 1.0
	var flat_bonus: int = 0
	var sources: Array = packet.get("strength_sources", [])

	for source in sources:
		var mult: float = float(source.get("multiplier", 1.0))
		var bonus: int = int(source.get("flat_bonus", 0))
		total_multiplier *= mult
		flat_bonus += bonus

	var multiplied: int = int(base * total_multiplier) + flat_bonus
	packet["multiplied_total"] = multiplied

# ── Moonpearl Yield ──────────────────────────────────────────────
## Converts final moondrop total to moonpearls.
func compute_moonpearl_yield(packet: Dictionary) -> int:
	var total: int = int(packet.get("multiplied_total", 0))
	var pearls: int = maxi(int(total / MOONPEARL_THRESHOLD), 0)
	if total > 0 and pearls == 0:
		pearls = MIN_MOONPEARLS
	packet["moonpearls_gained"] = pearls
	return pearls

# ── Summary Builder ──────────────────────────────────────────────
## Creates a human-readable summary from the final packet.
func build_summary(packet: Dictionary) -> Dictionary:
	return {
		"roll_id": packet.get("roll_id", ""),
		"moondrops": int(packet.get("flat_total", 0)),
		"multiplied_total": int(packet.get("multiplied_total", 0)),
		"moonpearls": int(packet.get("moonpearls_gained", 0)),
		"dice_count": (packet.get("dice", []) as Array).size(),
		"clusters_count": (packet.get("clusters", []) as Array).size(),
		"strength_sources": packet.get("strength_sources", []),
		"curio_moondrops_bonus": int(packet.get("curio_moondrops_bonus", 0)),
	}

# ── Curio Canister Integration ───────────────────────────────────
## Converts active curio canisters into strength sources.
func curios_to_strength_sources(active_curios: Array) -> Array:
	var sources: Array = []
	for curio in active_curios:
		var mult: float = float(curio.get("mult", 0.2))
		sources.append({
			"source_id": "curio_%d" % int(curio.get("id", -1)),
			"source_name": str(curio.get("title", "Curio")),
			"multiplier": 1.0 + mult,
			"flat_bonus": 0,
		})
	return sources

# ── Curio Effect Processing ─────────────────────────────────────
## Processes all active curio effects on the roll packet.
## Modifies dice values, adds bonus moondrops, applies transformations.
## Called BEFORE multiplier application.
func apply_curio_bonuses(packet: Dictionary) -> void:
	var dice: Array = packet.get("dice", [])
	if dice.is_empty():
		return

	# Gather all active curio resources
	var active_curios: Array[CurioResource] = CurioManager.get_active_curio_resources()
	if active_curios.is_empty():
		return

	# Process each curio effect
	for curio in active_curios:
		match curio.effect_key:
			"min_roll_floor":
				_apply_min_roll_floor(dice)
			"random_boost":
				_apply_random_boost(dice)
			"set_to_four":
				_apply_set_to_four(dice)
			"flat_reroll_gain":
				# Reroll effects handled in PlayTab, not here
				pass
			"reroll_on_six":
				# Reroll effects handled in PlayTab, not here
				pass
			"lock_with_payoff":
				_apply_lock_with_payoff(dice, packet)
			"bonus_on_six":
				_apply_bonus_on_six(dice, packet)
			"low_roll_consolation":
				# Reroll effects handled in PlayTab, not here
				pass
			"first_roll_bonus":
				_apply_first_roll_bonus(packet)
			"dice_count_trigger":
				_apply_dice_count_trigger(dice, packet)
			"pair_bonus":
				_apply_pair_bonus(dice, packet)
			"even_bonus":
				_apply_even_bonus(dice, packet)
			"unchanged_die_bonus":
				# Handled during reroll, not initial roll
				pass
			"per_roll_scaling":
				_apply_per_roll_scaling(packet)
			"low_roll_investment":
				_apply_low_roll_investment(dice, packet)

	# Recompute flat total after all curio effects
	compute_base_moondrops(packet)

## Gentle Polishing Stone: Each die rolls minimum 2 instead of 1
func _apply_min_roll_floor(dice: Array) -> void:
	for die in dice:
		var face: int = int(die.get("face_value", 1))
		if face < 2:
			die["face_value"] = 2
			die["base_moondrops"] = 2 * MOONDROPS_PER_FACE

## Lunar Drift Charm: +1 to one random die
func _apply_random_boost(dice: Array) -> void:
	if dice.is_empty():
		return
	var idx: int = randi() % dice.size()
	var die: Dictionary = dice[idx]
	var face: int = int(die.get("face_value", 1))
	var sides: int = int(die.get("sides", 6))
	if face < sides:
		die["face_value"] = face + 1
		die["base_moondrops"] = (face + 1) * MOONDROPS_PER_FACE

## Cratered Moonstone: Set lowest die to 4 (once per roll)
func _apply_set_to_four(dice: Array) -> void:
	if dice.is_empty():
		return
	var lowest_idx: int = 0
	var lowest_val: int = int(dice[0].get("face_value", 6))
	for i in range(1, dice.size()):
		var val: int = int(dice[i].get("face_value", 6))
		if val < lowest_val:
			lowest_val = val
			lowest_idx = i
	if lowest_val < 4:
		dice[lowest_idx]["face_value"] = 4
		dice[lowest_idx]["base_moondrops"] = 4 * MOONDROPS_PER_FACE

## Hollow Die Frame: +2 moondrops flat bonus
func _apply_lock_with_payoff(dice: Array, packet: Dictionary) -> void:
	var bonus: int = int(packet.get("curio_bonus_moondrops", 0))
	packet["curio_bonus_moondrops"] = bonus + 2

## Cracked Moon Fragment: +3 moondrops if any die shows max
func _apply_bonus_on_six(dice: Array, packet: Dictionary) -> void:
	for die in dice:
		if bool(die.get("is_max", false)):
			var bonus: int = int(packet.get("curio_bonus_moondrops", 0))
			packet["curio_bonus_moondrops"] = bonus + 3
			return

## Cavern Echo: +2 moondrops on first roll of the day
func _apply_first_roll_bonus(packet: Dictionary) -> void:
	var bonus: int = int(packet.get("curio_bonus_moondrops", 0))
	packet["curio_bonus_moondrops"] = bonus + 2

## Glacial Resonance: +4 moondrops if exactly 3 dice
func _apply_dice_count_trigger(dice: Array, packet: Dictionary) -> void:
	if dice.size() == 3:
		var bonus: int = int(packet.get("curio_bonus_moondrops", 0))
		packet["curio_bonus_moondrops"] = bonus + 4

## Twin Hollows: +3 moondrops if any two dice match
func _apply_pair_bonus(dice: Array, packet: Dictionary) -> void:
	var seen: Dictionary = {}
	for die in dice:
		var face: int = int(die.get("face_value", 0))
		if seen.has(face):
			var bonus: int = int(packet.get("curio_bonus_moondrops", 0))
			packet["curio_bonus_moondrops"] = bonus + 3
			return
		seen[face] = true

## Even Moonstone: +1 moondrop per even-value die
func _apply_even_bonus(dice: Array, packet: Dictionary) -> void:
	var count: int = 0
	for die in dice:
		var face: int = int(die.get("face_value", 0))
		if face % 2 == 0:
			count += 1
	if count > 0:
		var bonus: int = int(packet.get("curio_bonus_moondrops", 0))
		packet["curio_bonus_moondrops"] = bonus + count

## Selenite Lattice: +1 moondrop per die in this roll
func _apply_per_roll_scaling(packet: Dictionary) -> void:
	var dice: Array = packet.get("dice", [])
	var bonus: int = int(packet.get("curio_bonus_moondrops", 0))
	packet["curio_bonus_moondrops"] = bonus + dice.size()

## Stalactite Growth: +1 moondrop per die showing 1
func _apply_low_roll_investment(dice: Array, packet: Dictionary) -> void:
	var count: int = 0
	for die in dice:
		var face: int = int(die.get("face_value", 0))
		if face == 1:
			count += 1
	if count > 0:
		var bonus: int = int(packet.get("curio_bonus_moondrops", 0))
		packet["curio_bonus_moondrops"] = bonus + count
