extends Node

## CurioManager — Autoload managing curio ownership and activation.
##
## Responsibilities:
##   • Store owned curios (per-profile inventory)
##   • Manage active curio slots (max 3)
##   • Apply effects during dice resolution pipeline via SignalBus
##   • Persist curio inventory via Database
##
## Curios are equipped TO curio canisters in the Satchel tab.
## A canister with an equipped curio shows that curio's effects
## when active in the PlayTab right panel.

# Preload dependencies (required because class_name isn't available during autoload)
const CurioResource := preload("res://scripts/curio/curio_resource.gd")
const CurioDatabase := preload("res://scripts/curio/curio_database.gd")

const MAX_ACTIVE_CURIOS := 3
const CURIO_INVENTORY_FILE := "user://ante_up/curio_inventory.json"

signal curio_acquired(curio: CurioResource)
signal curio_equipped(curio_id: String, canister_id: int)
signal curio_unequipped(curio_id: String, canister_id: int)
signal crate_opened(curio: CurioResource)

# ── State ─────────────────────────────────────────────────────
# owned_curios: Array of curio id strings (persisted per-profile)
# equipped_curios: canister_id (int) → curio_id (String)
var _owned_curios: Array = []
var _equipped_curios: Dictionary = {}  # canister_id → curio_id
var _roll_count_this_round: int = 0
var _stalactite_stacks: Dictionary = {}  # curio_instance_key → stacks this round

func _ready() -> void:
	_load_inventory()
	if Engine.has_singleton("SignalBus"):
		SignalBus.dice_settled.connect(_on_dice_settled)

# ── Persistence ───────────────────────────────────────────────
func _get_save_path() -> String:
	return CURIO_INVENTORY_FILE

func _load_inventory() -> void:
	if not FileAccess.file_exists(_get_save_path()):
		_owned_curios = []
		_equipped_curios = {}
		return
	var f := FileAccess.open(_get_save_path(), FileAccess.READ)
	if not f:
		return
	var txt := f.get_as_text().strip_edges()
	f.close()
	if txt.is_empty():
		return
	var json := JSON.new()
	if json.parse(txt) != OK:
		return
	var data: Dictionary = json.data if json.data is Dictionary else {}
	_owned_curios = data.get("owned", [])
	# Convert string keys back to int for equipped
	var raw_equipped: Dictionary = data.get("equipped", {})
	_equipped_curios = {}
	for key in raw_equipped:
		_equipped_curios[int(key)] = str(raw_equipped[key])

func save_inventory() -> void:
	var f := FileAccess.open(_get_save_path(), FileAccess.WRITE)
	if not f:
		return
	# Convert int keys to string for JSON
	var serializable_equipped: Dictionary = {}
	for key in _equipped_curios:
		serializable_equipped[str(key)] = _equipped_curios[key]
	f.store_string(JSON.stringify({
		"owned": _owned_curios,
		"equipped": serializable_equipped,
	}, "\t"))
	f.close()

# ── Owned Curios ──────────────────────────────────────────────
func get_owned_curios() -> Array:
	return _owned_curios.duplicate()

func has_curio(curio_id: String) -> bool:
	return curio_id in _owned_curios

func add_curio(curio_id: String) -> void:
	if curio_id not in _owned_curios:
		_owned_curios.append(curio_id)
		save_inventory()
		var curio := CurioDatabase.get_curio_by_id(curio_id)
		if curio:
			curio_acquired.emit(curio)

func remove_curio(curio_id: String) -> void:
	_owned_curios.erase(curio_id)
	# Unequip from any canister
	var to_remove: Array = []
	for canister_id in _equipped_curios:
		if _equipped_curios[canister_id] == curio_id:
			to_remove.append(canister_id)
	for canister_id in to_remove:
		_equipped_curios.erase(canister_id)
	save_inventory()

func get_curio_resource(curio_id: String) -> CurioResource:
	return CurioDatabase.get_curio_by_id(curio_id)

# ── Equipped Curios ───────────────────────────────────────────
func equip_curio(curio_id: String, canister_id: int) -> bool:
	if curio_id not in _owned_curios:
		return false
	# Unequip any curio already on this canister
	if _equipped_curios.has(canister_id):
		var old_id: String = _equipped_curios[canister_id]
		curio_unequipped.emit(old_id, canister_id)
	# Unequip this curio from any other canister
	for cid in _equipped_curios.keys():
		if _equipped_curios[cid] == curio_id and cid != canister_id:
			_equipped_curios.erase(cid)
			curio_unequipped.emit(curio_id, cid)
	_equipped_curios[canister_id] = curio_id
	save_inventory()
	curio_equipped.emit(curio_id, canister_id)
	return true

func unequip_curio(canister_id: int) -> void:
	if _equipped_curios.has(canister_id):
		var curio_id: String = _equipped_curios[canister_id]
		_equipped_curios.erase(canister_id)
		save_inventory()
		curio_unequipped.emit(curio_id, canister_id)

func get_equipped_curio(canister_id: int) -> String:
	return _equipped_curios.get(canister_id, "")

func get_equipped_curio_resource(canister_id: int) -> CurioResource:
	var curio_id: String = get_equipped_curio(canister_id)
	if curio_id.is_empty():
		return null
	return CurioDatabase.get_curio_by_id(curio_id)

func is_curio_equipped(curio_id: String) -> bool:
	return curio_id in _equipped_curios.values()

func get_all_equipped() -> Dictionary:
	return _equipped_curios.duplicate()

# ── Active Curios (from active canisters in PlayTab) ──────────
## Returns CurioResources for all curios equipped to currently active canisters.
func get_active_curio_resources() -> Array[CurioResource]:
	var result: Array[CurioResource] = []
	for canister in GameData.curio_canisters:
		if not canister.get("active", false):
			continue
		var canister_id: int = int(canister.get("id", -1))
		var curio_id: String = get_equipped_curio(canister_id)
		if curio_id.is_empty():
			continue
		var curio := CurioDatabase.get_curio_by_id(curio_id)
		if curio:
			result.append(curio)
	return result

## Returns active curios filtered by trigger type.
func get_active_by_trigger(trigger_type: String) -> Array[CurioResource]:
	var result: Array[CurioResource] = []
	for curio in get_active_curio_resources():
		if curio.trigger_type == trigger_type:
			result.append(curio)
	return result

# ── Dice Pipeline Integration ─────────────────────────────────
func _on_dice_settled(_results: Dictionary) -> void:
	_roll_count_this_round += 1

func get_roll_count() -> int:
	return _roll_count_this_round

func reset_round_state() -> void:
	_roll_count_this_round = 0
	_stalactite_stacks.clear()

func get_stalactite_stacks(curio_key: String) -> int:
	return _stalactite_stacks.get(curio_key, 0)

func add_stalactite_stack(curio_key: String) -> void:
	_stalactite_stacks[curio_key] = _stalactite_stacks.get(curio_key, 0) + 1

# ── Crate Opening ─────────────────────────────────────────────
func open_crate(rarity_bias: String = "normal") -> CurioResource:
	var curio := CurioDatabase.get_random_curio(rarity_bias)
	if curio:
		add_curio(curio.id)
		crate_opened.emit(curio)
	return curio