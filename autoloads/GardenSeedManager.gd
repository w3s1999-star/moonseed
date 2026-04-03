extends Node

# ─────────────────────────────────────────────────────────────────
# GardenSeedManager.gd  –  Singleton
# Central hub for deterministic seed generation.
# Wraps GDExtensions with a dynamic-safe pattern.
# ─────────────────────────────────────────────────────────────────

const SEED_VERSION := 1 

signal seeds_updated(daily_seed: int, profile_seed: int)

var daily_seed:   int = 0
var dice_box_seed: int = 0
var profile_seed: int = 0
var _has_seed_ext:      bool = false
var _has_big_number:    bool = false

func _ready() -> void:
	# Check for class existence using strings to stay "dynamic"
	_has_seed_ext   = ClassDB.class_exists("Seed")
	_has_big_number = ClassDB.class_exists("BigNumber")

	if _has_seed_ext:
		print("[GardenSeedManager] Seed GDExtension detected ✓")
	
	if Engine.has_singleton("GameData"):
		GameData.state_changed.connect(_recompute)
	
	_recompute()

func _recompute() -> void:
	var date_str := ""
	var profile  := ""
	
	if Engine.has_singleton("GameData"):
		date_str = GameData.get_date_string()
		profile  = GameData.current_profile
	
	var version_tag := str(SEED_VERSION) + date_str + profile
	var success := false
	
	if _has_seed_ext:
		# Use ClassDB.instantiate() so that compiler doesn't demand 'Seed' exist as a keyword
		var seed_tool = ClassDB.instantiate("Seed")
		
		# Verify method exists on the instance at runtime
		if seed_tool and seed_tool.has_method("from_string"):
			dice_box_seed   = seed_tool.from_string(date_str + str(SEED_VERSION))
			profile_seed = seed_tool.from_string(version_tag)
			success = true

	if not success:
		_use_hash_fallback(date_str, version_tag)

	seeds_updated.emit(dice_box_seed, profile_seed)

func _use_hash_fallback(date_str: String, version_tag: String) -> void:
	# Standard Godot 32-bit hash fallback
	daily_seed   = hash(date_str + str(SEED_VERSION)) & 0x7FFFFFFF
	profile_seed = hash(version_tag) & 0x7FFFFFFF

# ── Public helpers ────────────────────────────────────────────────

## Returns a seeded RNG ready to use for today's garden picks.
func make_daily_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = daily_seed
	return rng

## Returns a seeded RNG tied to the current profile + day.
func make_profile_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = profile_seed
	return rng

## Format a large chip number nicely.
func format_chips(amount: int) -> String:
	if _has_big_number:
		var bn = ClassDB.instantiate("BigNumber")
		if bn and bn.has_method("set_value"):
			bn.set_value(amount)
			return bn.to_string()
	return _fmt_commas(amount)

func _fmt_commas(n: int) -> String:
	var s := str(n)
	var r := ""
	var cnt := 0
	for i in range(s.length()-1, -1, -1):
		if cnt > 0 and cnt % 3 == 0:
			r = "," + r
		r = s[i] + r
		cnt += 1
	return r

## Pick N items from array using the daily seed (deterministic).
func daily_pick(pool: Array, count: int) -> Array:
	var rng := make_daily_rng()
	var copy := pool.duplicate()
	var result: Array = []
	while result.size() < count and copy.size() > 0:
		var idx := rng.randi() % copy.size()
		result.append(copy[idx])
		copy.remove_at(idx)
	return result

## Check extension availability for debug/UI
func get_status() -> Dictionary:
	return {
		"seed_extension": _has_seed_ext,
		"big_number_extension": _has_big_number,
		"daily_seed": daily_seed,
		"profile_seed": profile_seed,
	}
