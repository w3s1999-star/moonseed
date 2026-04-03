extends Node

# ─────────────────────────────────────────────────────────────────
# ActiveBuffs.gd  —  MOONSEED  v0.9.0
# Manages consumed Sweet effects currently active on the player.
# Persisted to economy JSON via Database.
# ─────────────────────────────────────────────────────────────────

# buff: {effect_id, value, charges, expires_at_unix (0=charge-based)}
var _buffs: Array = []

func _ready() -> void:
	_load()

func _load() -> void:
	var raw: Variant = Database.get_setting("active_buffs", [])
	if raw is Array: _buffs = raw.duplicate()
	_expire_old()

func _save() -> void:
	Database.save_setting("active_buffs", _buffs)

func _expire_old() -> void:
	var now := int(Time.get_unix_time_from_system())
	_buffs = _buffs.filter(func(b: Dictionary) -> bool:
		if b.get("expires_at_unix", 0) > 0:
			return b["expires_at_unix"] > now
		return b.get("charges", 0) > 0
	)
	_save()

# Add a buff from consuming a sweet
func apply_sweet(sweet_key: String) -> void:
	var data: Dictionary = IngredientData.SWEETS.get(sweet_key, {})
	if data.is_empty(): return
	var buff := {
		"effect_id": data["effect_id"],
		"value":     data["effect_value"],
		"sweet_key": sweet_key,
		"charges":   1 if data["effect_duration"] == 0 else 0,
		"expires_at_unix": (int(Time.get_unix_time_from_system()) + int(data["effect_duration"])
							if data["effect_duration"] > 0 else 0),
	}
	# Some effects use charges not duration
	match data["effect_id"]:
		"upgrade_d6_to_d8":    buff["charges"] = int(data["effect_value"])
		"force_explosion":     buff["charges"] = int(data["effect_value"])
	_buffs.append(buff)
	_save()
	SignalBus.buff_applied.emit(sweet_key)

# Check if a buff effect is active
func has_buff(effect_id: String) -> bool:
	_expire_old()
	for b in _buffs:
		if b["effect_id"] == effect_id: return true
	return false

# Get the value of the first matching active buff
func get_buff_value(effect_id: String) -> float:
	_expire_old()
	for b in _buffs:
		if b["effect_id"] == effect_id:
			return float(b.get("value", 1))
	return 0.0

# Consume one charge of a charge-based buff; returns false if none left
func consume_charge(effect_id: String) -> bool:
	_expire_old()
	for b in _buffs:
		if b["effect_id"] == effect_id and b.get("charges", 0) > 0:
			b["charges"] -= 1
			if b["charges"] <= 0: _buffs.erase(b)
			_save()
			return true
	return false

# Get all active buffs (for UI display)
func get_all_active() -> Array:
	_expire_old()
	return _buffs.duplicate()

func clear_all() -> void:
	_buffs.clear()
	_save()
