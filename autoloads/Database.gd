extends Node

# Resets all settings to their default values and saves to disk
func reset_settings_to_defaults() -> void:
	var defaults := {
		"fullscreen": false,
		"window_mode": "windowed",
		"window_size": "1280x720",
		"msaa": 0,
		"fxaa": false,
		"vsync": 1,
		"fps_limit": 60,
		"render_scale_3d": 1.0,
		"ui_scale": 1.0,
		"text_size_delta": 0,
		"volume_master": 1.0,
		"volume_music": 0.8,
		"volume_ui": 1.0,
		"volume_sfx": 1.0,
		"mute_all": false,
		"scroll_speed": 1.0,
		"notifications_enabled": true,
		"pomodoro_alerts": true,
		"pomodoro_auto_minimize": true,
		"notification_sound": true,
		"timezone": GameData.DEFAULT_TZ,
		"profile": GameData.current_profile,
		"debug_mode": false,
		"moon_phase_popup_enabled": true,
		"save_location": "appdata"
	}
	for k in defaults.keys():
		_settings[k] = defaults[k]
	_save_settings()

# ─────────────────────────────────────────────────────────────────
# Database.gd – JSON persistence 
# ─────────────────────────────────────────────────────────────────

const SAVE_DIR         := "user://ante_up/"
const TASKS_FILE       := "user://ante_up/tasks.json"
const CURIO_CANISTERS_FILE := "user://ante_up/curio_canisters.json"
const DICE_BOX_STATS_FILE := "user://ante_up/dice_box_stats.json"
const CONTRACTS_FILE   := "user://ante_up/contracts.json"
const CONTRACT_TEMPLATES_FILE := "user://ante_up/contract_templates.json"
const INVENTORY_FILE   := "user://ante_up/inventory.json"
const SETTINGS_FILE    := "user://ante_up/settings.json"
const PROFILES_FILE    := "user://ante_up/profiles.json"
const GARDEN_FILE      := "user://ante_up/garden.json"
const SHOP_OWNED_FILE  := "user://ante_up/shop_owned.json"
const ECONOMY_FILE     := "user://ante_up/economy.json"
const DECORATIONS_FILE   := "user://ante_up/decorations.json"
const INGREDIENTS_FILE   := "user://ante_up/ingredients.json"
const SWEETS_FILE        := "user://ante_up/sweets.json"
const STUDIO_ROOMS_FILE  := "user://ante_up/studio_rooms.json"
const ACHIEVEMENTS_FILE  := "user://ante_up/achievements.json"
const DICE_INVENTORY_FILE := "user://ante_up/dice_inventory.json"
const UPGRADES_FILE := "user://ante_up/upgrades.json"
const CHOCOLATE_COINS_FILE := "user://ante_up/chocolate_coins.json"
const MOONKISSED_PAPERS_FILE := "user://ante_up/moonkissed_papers.json"

const CONTRACT_REWARD_WEIGHTS := {
	"minor": {"common": 56, "uncommon": 28, "rare": 12, "legendary": 4},
	"major": {"common": 34, "uncommon": 34, "rare": 22, "legendary": 10},
}
const TASK_STICKER_SLOT_COUNT := 6

var _tasks:        Array = []
var _curio_canisters:       Array = []
var _dice_box_stats:  Dictionary = {}
var _contracts:    Array = []
var _inventory:    Dictionary = {}
var _settings:     Dictionary = {}
var _profiles:     Array = []
var _garden:       Array = []
var _shop_owned:   Array = []
var _economy:      Dictionary = {}
var _decorations:  Array = []
var _ingredients:   Dictionary = {}   # ingredient_key → count
var _sweets:        Dictionary = {}   # sweet_key → count  +  "discovered" → Array
# room_id (int) → plain dict mirroring StudioRoomData.to_dict()
var _studio_rooms:  Dictionary = {}
var _achievements:  Dictionary = {}
var _dice_inventory: Dictionary = {}
var _upgrades: Dictionary = {}
var _chocolate_coins: Dictionary = {}
var _moonkissed_papers: Array = []

var _next_task_id:        int = 1
var _next_curio_canister_id:       int = 1
var _next_contract_id:    int = 1
var _next_studio_room_id: int = 1

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR.replace("user://", OS.get_user_data_dir() + "/"))
	_load_all()
	_seed_defaults()
	_enforce_single_profile()

# ── Load / Save ───────────────────────────────────────────────────
func _load_all() -> void:
	_tasks      = _load_json(TASKS_FILE, [])
	_curio_canisters     = _load_json(CURIO_CANISTERS_FILE, [])
	_contracts  = _load_json(CONTRACTS_FILE, [])
	_garden     = _load_json(GARDEN_FILE, [])
	_shop_owned = _load_json(SHOP_OWNED_FILE, [])
	_profiles   = _load_json(PROFILES_FILE, [])
	_settings   = _load_json(SETTINGS_FILE, {})
	
	# Migrate old relics.json to curio_canisters.json if needed
	_migrate_relics_to_curio_canisters()
	# Remove prefilled dev sample curio canisters from existing installs.
	_remove_prefilled_curio_canisters()
	# Load contract templates
	_load_contract_templates()
	# Build _studio_rooms int-keyed dict from the persisted array.
	var rooms_arr: Array = _load_json(STUDIO_ROOMS_FILE, [])
	_studio_rooms = {}
	for entry: Variant in rooms_arr:
		if entry is Dictionary:
			var rid := int((entry as Dictionary).get("room_id", -1))
			if rid > 0:
				_studio_rooms[rid] = entry
	_inventory  = _load_json(INVENTORY_FILE, {
		"8":0,
		"10":0,
		"12":0,
		"20":0,
		"cerulean_seeds":0,
		"owned_ritual_stickers":[],
		"owned_consumable_stickers":[],
	})
	_achievements = _load_json(ACHIEVEMENTS_FILE, {})
	_dice_inventory = _load_json(DICE_INVENTORY_FILE, {})
	_upgrades = _load_json(UPGRADES_FILE, {})
	_economy    = _load_json(ECONOMY_FILE, {})
	# Ensure Default profile exists
	if not _economy.has("Default"):
		_economy["Default"] = {"moonpearls":0,"moonpearls_pressed":0,"water_meter":0.0,"meals_today":0,"last_meal_date":"","machine_running":false}
	
	# Migrate existing saves to include ledger fields
	_migrate_economy_ledger()
	
	_decorations = _load_json(DECORATIONS_FILE, [])
	_ingredients = _load_json(INGREDIENTS_FILE, {})
	_sweets      = _load_json(SWEETS_FILE,      {"discovered": []})
	_chocolate_coins = _load_json(CHOCOLATE_COINS_FILE, {"bar": 0, "truffle": 0, "artisan": 0})
	
	var stats_arr: Array = _load_json(DICE_BOX_STATS_FILE, [])
	_dice_box_stats = {}
	for rec in stats_arr:
		var key := "%s:%s" % [rec.get("date",""), rec.get("profile","")]
		_dice_box_stats[key] = rec

	var tasks_dirty: bool = false
	var curio_canisters_dirty: bool = false
	var inventory_dirty: bool = false
	var settings_dirty: bool = false
	if not _inventory.has("owned_ritual_stickers"):
		_inventory["owned_ritual_stickers"] = []
		inventory_dirty = true
	if not _inventory.has("owned_consumable_stickers"):
		_inventory["owned_consumable_stickers"] = []
		inventory_dirty = true
	_inventory["owned_ritual_stickers"] = _normalize_sticker_inventory(_inventory.get("owned_ritual_stickers", []))
	_inventory["owned_consumable_stickers"] = _normalize_sticker_inventory(_inventory.get("owned_consumable_stickers", []))
	for t in _tasks:
		# migrate old tasks without sticker fields
		if not t.has("rituals"):
			t["rituals"] = []
			tasks_dirty = true
		if not t.has("archived"):
			t["archived"] = false
			tasks_dirty = true
		if not t.has("consumables"):
			t["consumables"] = []
			tasks_dirty = true
		var normalized_slots: Array = _normalize_sticker_slots(t.get("sticker_slots", _build_sticker_slots_from_task(t)))
		if normalized_slots != t.get("sticker_slots", []):
			t["sticker_slots"] = normalized_slots
			tasks_dirty = true
		var previous_rituals: Array = t.get("rituals", []).duplicate()
		var previous_consumables: Array = t.get("consumables", []).duplicate()
		_apply_task_sticker_slots(t)
		if previous_rituals != t.get("rituals", []) or previous_consumables != t.get("consumables", []):
			tasks_dirty = true
		if not t.has("card_color"):
			t["card_color"] = "white"
			tasks_dirty = true
		if not t.has("studio_room"):
			t["studio_room"] = _next_studio_room_id
			_next_studio_room_id += 1
			tasks_dirty = true
		elif int(t.get("studio_room", 0)) >= _next_studio_room_id:
			_next_studio_room_id = int(t.get("studio_room", 0)) + 1
		if t.get("id", 0) >= _next_task_id:   _next_task_id   = t.get("id", 0) + 1
	for r in _curio_canisters:
		if not r.has("card_color"):
			r["card_color"] = "white"
			curio_canisters_dirty = true
		if not r.has("archived"):
			r["archived"] = false
			curio_canisters_dirty = true
		if not r.has("studio_room"):
			r["studio_room"] = _next_studio_room_id
			_next_studio_room_id += 1
			curio_canisters_dirty = true
		elif int(r.get("studio_room", 0)) >= _next_studio_room_id:
			_next_studio_room_id = int(r.get("studio_room", 0)) + 1
		if r.get("id", 0) >= _next_curio_canister_id:  _next_curio_canister_id  = r.get("id", 0) + 1
	if tasks_dirty:
		_save_tasks()
	if curio_canisters_dirty:
		_save_curio_canisters()
	if not bool(_settings.get("starter_sticker_book_granted", false)):
		_inventory["owned_ritual_stickers"] = _normalize_sticker_inventory(GameData.RITUAL_STICKERS.keys())
		_inventory["owned_consumable_stickers"] = _normalize_sticker_inventory(GameData.CONSUMABLE_STICKERS.keys())
		_settings["starter_sticker_book_granted"] = true
		inventory_dirty = true
		settings_dirty = true
	if inventory_dirty:
		_save_inventory()
	if settings_dirty:
		_save_settings()
	var contracts_dirty: bool = false
	for c in _contracts:
		if not c.has("subheading"):
			c["subheading"] = ""
			contracts_dirty = true
		if not c.has("subtask_cards"):
			c["subtask_cards"] = _build_blank_subtask_cards(str(c.get("subtasks", "")))
			contracts_dirty = true
		else:
			var normalized_cards: Array = _normalize_subtask_cards(c.get("subtask_cards", []))
			if normalized_cards != c.get("subtask_cards", []):
				c["subtask_cards"] = normalized_cards
				contracts_dirty = true
		if c.get("id", 0) >= _next_contract_id: _next_contract_id = c.get("id", 0) + 1
	if contracts_dirty:
		_save_contracts()
	# Migrate: ensure every task and relic that already exists has a corresponding
	# studio room record.  Rooms loaded from studio_rooms.json are already in
	# _studio_rooms; only create entries for those that are missing.
	var rooms_dirty: bool = false
	for t: Variant in _tasks:
		var td := t as Dictionary
		var rid := int(td.get("studio_room", -1))
		if rid > 0 and not _studio_rooms.has(rid):
			var data := StudioRoomData.new(rid, "task", int(td.get("id", -1)))
			_studio_rooms[rid] = data.to_dict()
			rooms_dirty = true
	for r: Variant in _curio_canisters:
		var rd := r as Dictionary
		var rid := int(rd.get("studio_room", -1))
		if rid > 0 and not _studio_rooms.has(rid):
			var data := StudioRoomData.new(rid, "curio_canister", int(rd.get("id", -1)))
			_studio_rooms[rid] = data.to_dict()
			rooms_dirty = true
	if rooms_dirty:
		_save_studio_rooms()

func _save_tasks()       -> void: _save_json(TASKS_FILE,        _tasks)
func _save_curio_canisters()      -> void: _save_json(CURIO_CANISTERS_FILE,       _curio_canisters)
func _save_contracts()   -> void: _save_json(CONTRACTS_FILE,    _contracts)
func _save_garden()      -> void: _save_json(GARDEN_FILE,       _garden)
func _save_shop_owned()  -> void: _save_json(SHOP_OWNED_FILE,   _shop_owned)
func _save_profiles()    -> void: _save_json(PROFILES_FILE,     _profiles)
func _save_settings()    -> void: _save_json(SETTINGS_FILE,     _settings)
func _save_studio_rooms() -> void: _save_json(STUDIO_ROOMS_FILE, _studio_rooms.values())
func _save_inventory()  -> void: _save_json(INVENTORY_FILE,   _inventory)

func _migrate_relics_to_curio_canisters() -> void:
	# Check if old relics.json exists and curio_canisters.json is empty
	var old_relics_file := "user://ante_up/relics.json"
	if FileAccess.file_exists(old_relics_file) and _curio_canisters.is_empty():
		var old_relics: Array = _load_json(old_relics_file, [])
		if not old_relics.is_empty():
			print("Migrating ", old_relics.size(), " relics to curio_canisters...")
			_curio_canisters = old_relics.duplicate(true)
			_save_curio_canisters()
			# Delete the old file after successful migration
			var dir := DirAccess.open("user://ante_up/")
			if dir:
				dir.remove("relics.json")
 
func _remove_prefilled_curio_canisters() -> void:
	# Remove curio canisters that exactly match the DEV_SAMPLE_CURIO_CANISTERS
	# entries (title, mult, rarity, emoji). This avoids removing user-added
	# curios that differ in any field.
	if _curio_canisters.is_empty():
		return
	var samples: Array = GameData.DEV_SAMPLE_CURIO_CANISTERS
	var remaining: Array = []
	var removed_count: int = 0
	for r in _curio_canisters:
		var matched: bool = false
		for sample in samples:
			# sample: [title, mult, rarity, emoji]
			if str(r.get("title","")) == str(sample[0]) and str(r.get("rarity","")) == str(sample[2]) and str(r.get("emoji","")) == str(sample[3]):
				var rm: float = float(r.get("mult", 0.0))
				var sm: float = float(sample[1])
				if abs(rm - sm) < 0.0001:
					matched = true
					break
		if matched:
			removed_count += 1
		else:
			remaining.append(r)
	if removed_count > 0:
		_curio_canisters = remaining
		_save_curio_canisters()
		print("Database: removed %d prefilled curio canisters from install." % removed_count)
func _save_dice_box_stats()-> void: _save_json(DICE_BOX_STATS_FILE, _dice_box_stats.values())
func _save_economy()    -> void: _save_json(ECONOMY_FILE,     _economy)
func _save_decorations()-> void: _save_json(DECORATIONS_FILE, _decorations)
func _save_ingredients() -> void: _save_json(INGREDIENTS_FILE, _ingredients)
func _save_sweets()      -> void: _save_json(SWEETS_FILE,      _sweets)
func _save_achievements() -> void: _save_json(ACHIEVEMENTS_FILE, _achievements)
func _save_dice_inventory() -> void: _save_json(DICE_INVENTORY_FILE, _dice_inventory)
func _save_upgrades() -> void: _save_json(UPGRADES_FILE, _upgrades)
func _save_chocolate_coins() -> void: _save_json(CHOCOLATE_COINS_FILE, _chocolate_coins)
func _save_moonkissed_papers() -> void: _save_json(MOONKISSED_PAPERS_FILE, _moonkissed_papers)

# ── Chocolate Coins ───────────────────────────────────────────────
func get_chocolate_coins() -> Dictionary:
	return _chocolate_coins.duplicate()

func save_chocolate_coins(coins: Dictionary) -> void:
	_chocolate_coins = coins.duplicate()
	_save_chocolate_coins()

# ── Moonkissed Papers ─────────────────────────────────────────────
func get_moonkissed_papers(profile: String) -> Array:
	return _moonkissed_papers.filter(func(p): return p.get("profile","Default") == profile)

func add_moonkissed_paper(contract_id: int, contract_name: String, reward_tier: String, profile: String) -> void:
	_moonkissed_papers.append({
		"contract_id": contract_id,
		"contract_name": contract_name,
		"reward_tier": reward_tier,
		"profile": profile,
		"earned_date": _today()
	})
	_save_moonkissed_papers()
	SignalBus.moonkissed_paper_earned.emit({"contract_name": contract_name, "reward_tier": reward_tier})

func redeem_moonkissed_paper(index: int, profile: String) -> Dictionary:
	if index < 0 or index >= _moonkissed_papers.size():
		return {}
	var paper: Dictionary = _moonkissed_papers[index]
	if paper.get("profile","") != profile:
		return {}
	var reward_tier: String = paper.get("reward_tier", "minor")
	var rewards: Dictionary = {}
	match reward_tier:
		"minor":
			GameData.add_chocolate_coin("bar", 5)
			GameData.add_chocolate_coin("truffle", 1)
			add_cerulean_seed(1)
			rewards = {"bar": 5, "truffle": 1, "artisan": 0, "cerulean_seeds": 1}
		"major":
			GameData.add_chocolate_coin("bar", 8)
			GameData.add_chocolate_coin("truffle", 3)
			GameData.add_chocolate_coin("artisan", 1)
			add_cerulean_seed(2)
			rewards = {"bar": 8, "truffle": 3, "artisan": 1, "cerulean_seeds": 2}
	_moonkissed_papers.remove_at(index)
	_save_moonkissed_papers()
	SignalBus.moonkissed_paper_redeemed.emit(paper, rewards)
	return rewards

# ── Economy Ledger Migration ─────────────────────────────────────────────────────
func _migrate_economy_ledger() -> void:
	# Migrate existing saves to include ledger fields
	for profile in _economy.keys():
		var econ_val = _economy[profile]
		var econ: Dictionary = econ_val if econ_val is Dictionary else {}
		# If ledger fields already exist, skip migration
		if econ.has("moonpearls_earned_total") and econ.has("moonpearls_spent_total"):
			continue
		
		# Calculate initial ledger values from existing data
		var current_balance: int = int(econ.get("moonpearls", 0))
		var earned_total: int = int(get_total_moonpearls_earned(profile))
		var spent_total: int = int(max(0, earned_total - current_balance))
		
		# Update economy with ledger fields
		econ["moonpearls_earned_total"] = earned_total
		econ["moonpearls_spent_total"] = spent_total
		_economy[profile] = econ
	
	_save_economy()

func _load_json(path: String, default: Variant) -> Variant:
	if not FileAccess.file_exists(path): return default
	var f := FileAccess.open(path, FileAccess.READ)
	if not f: return default
	var txt := f.get_as_text(); f.close()
	txt = txt.strip_edges()
	if txt.is_empty():
		return default
	# Handle UTF-8 BOM if present; it can break JSON parsing in some saves.
	if txt.unicode_at(0) == 0xfeff:
		txt = txt.substr(1)
		if txt.is_empty():
			return default
	var json := JSON.new()
	if json.parse(txt) != OK:
		push_warning("Database: failed to parse %s (line %d): %s. Using defaults." % [path, json.get_error_line(), json.get_error_message()])
		return default
	return json.data

func _save_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data, "\t")); f.close()

# ── Seed Defaults ─────────────────────────────────────────────────
func _seed_defaults() -> void:
	# Avoid seeding defaults more than once across runs — persist a flag in settings.
	if bool(_settings.get("defaults_seeded", false)):
		print("Database: defaults_seeded flag present, skipping seed_defaults.")
		return

	if _profiles.is_empty():
		_profiles = [
			{"name": "Default", "created_date": _today(), "is_active": 1},
			{"name": "Dev",     "created_date": _today(), "is_active": 0},
		]
		_save_profiles()
	if _tasks.is_empty():
		for sample in GameData.DEV_SAMPLE_TASKS.slice(0, 8):
			insert_task(sample[0], sample[1], "Default")
	_ensure_default_task("Drink Water", 1, "Default", true)
	_ensure_default_task("Eat Food",    1, "Default", true)
	# Do not prefill curio canisters for new users by default.
	# Only ensure the minimal default tasks exist (Drink Water / Eat Food).
	# Mark that we've seeded defaults so this doesn't run again.
	_settings["defaults_seeded"] = true
	_save_settings()
	print("Database: seeded default profiles/tasks (no curio canisters).")

## Ensure all persisted data is merged into a single profile to avoid multi-profile
## switching complexity. This forces every record to use the single profile name
## stored in settings (or "Default"), and normalizes the saved profiles list.
func _enforce_single_profile() -> void:
	var target: String = str(_settings.get("profile", "Default")).strip_edges()
	if target == "":
		target = "Default"

	# Normalize tasks
	for i in range(_tasks.size()):
		var t := _tasks[i] as Dictionary
		t["profile"] = target
		_tasks[i] = t

	# Normalize curio canisters
	for i in range(_curio_canisters.size()):
		var r := _curio_canisters[i] as Dictionary
		r["profile"] = target
		_curio_canisters[i] = r

	# Normalize garden
	for i in range(_garden.size()):
		var g := _garden[i] as Dictionary
		g["profile"] = target
		_garden[i] = g

	# Normalize shop owned
	for i in range(_shop_owned.size()):
		var s := _shop_owned[i] as Dictionary
		s["profile"] = target
		_shop_owned[i] = s

	# Normalize contracts and templates
	for i in range(_contracts.size()):
		var c := _contracts[i] as Dictionary
		c["profile"] = target
		_contracts[i] = c
	for i in range(_contract_templates.size()):
		var ct := _contract_templates[i] as Dictionary
		ct["profile"] = target
		_contract_templates[i] = ct

	# Normalize dice box stats: rebuild keys with the target profile
	var new_stats := {}
	for rec in _dice_box_stats.values():
		if rec is Dictionary:
			rec["profile"] = target
			var key := "%s:%s" % [rec.get("date", ""), target]
			new_stats[key] = rec
	_dice_box_stats = new_stats

	# Ensure profiles file reflects the single profile
	_profiles = [{"name": target, "created_date": _today(), "is_active": 1}]
	_save_profiles()

	# Purge any lingering economy/profile entries that belong to other profiles.
	# Keep only the canonical `target` profile in saved economy and profile lists.
	var remove_keys: Array = []
	for p in _economy.keys():
		if str(p) != target:
			remove_keys.append(p)
	for p in remove_keys:
		_economy.erase(p)
	# Ensure the canonical profile economy exists
	_get_profile_economy(target)
	_save_economy()

	# Aggressively remove any saved records that belong to other profiles.
	# This helps purge stray artifacts left behind by older installs/profiles.
	_purge_non_primary_profile_artifacts(target)

func _purge_non_primary_profile_artifacts(target: String) -> void:
	var removed_total: int = 0

	# Tasks
	var before_tasks := _tasks.size()
	_tasks = _tasks.filter(func(t): return str(t.get("profile","")) == target)
	if _tasks.size() != before_tasks:
		_save_tasks()
		removed_total += (before_tasks - _tasks.size())

	# Curio canisters
	var before_curio := _curio_canisters.size()
	_curio_canisters = _curio_canisters.filter(func(r): return str(r.get("profile","")) == target)
	if _curio_canisters.size() != before_curio:
		_save_curio_canisters()
		removed_total += (before_curio - _curio_canisters.size())

	# Garden
	var before_garden := _garden.size()
	_garden = _garden.filter(func(g): return str(g.get("profile","")) == target)
	if _garden.size() != before_garden:
		_save_garden()
		removed_total += (before_garden - _garden.size())

	# Shop owned
	var before_shop := _shop_owned.size()
	_shop_owned = _shop_owned.filter(func(s): return str(s.get("profile","")) == target)
	if _shop_owned.size() != before_shop:
		_save_shop_owned()
		removed_total += (before_shop - _shop_owned.size())

	# Contracts and templates
	var before_contracts := _contracts.size()
	_contracts = _contracts.filter(func(c): return str(c.get("profile","")) == target)
	if _contracts.size() != before_contracts:
		_save_contracts()
		removed_total += (before_contracts - _contracts.size())
	var before_templates := _contract_templates.size()
	_contract_templates = _contract_templates.filter(func(ct): return str(ct.get("profile","")) == target)
	if _contract_templates.size() != before_templates:
		_save_contract_templates()
		removed_total += (before_templates - _contract_templates.size())

	# Decorations
	var before_decor := _decorations.size()
	_decorations = _decorations.filter(func(d): return str(d.get("profile","")) == target)
	if _decorations.size() != before_decor:
		_save_decorations()
		removed_total += (before_decor - _decorations.size())

	# Dice box stats: ensure only target remains
	var before_stats := _dice_box_stats.values().size()
	var new_stats := {}
	for rec in _dice_box_stats.values():
		if rec is Dictionary and str(rec.get("profile","")) == target:
			var key := "%s:%s" % [rec.get("date",""), target]
			new_stats[key] = rec
	_dice_box_stats = new_stats
	if _dice_box_stats.values().size() != before_stats:
		_save_dice_box_stats()
		removed_total += (before_stats - _dice_box_stats.values().size())

	if removed_total > 0:
		print("Database: removed %d records belonging to non-primary profiles." % removed_total)


func _purge_unexpected_files() -> void:
	# Remove any files in the save directory that are not part of the
	# expected current save set. This helps clear legacy or stray files
	# left behind by older installs.
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return
	var allowed: Array = [
		TASKS_FILE.get_file(), CURIO_CANISTERS_FILE.get_file(), DICE_BOX_STATS_FILE.get_file(),
		CONTRACTS_FILE.get_file(), CONTRACT_TEMPLATES_FILE.get_file(), INVENTORY_FILE.get_file(),
		SETTINGS_FILE.get_file(), PROFILES_FILE.get_file(), GARDEN_FILE.get_file(),
		SHOP_OWNED_FILE.get_file(), ECONOMY_FILE.get_file(), DECORATIONS_FILE.get_file(),
		INGREDIENTS_FILE.get_file(), SWEETS_FILE.get_file(), STUDIO_ROOMS_FILE.get_file(),
		ACHIEVEMENTS_FILE.get_file(), DICE_INVENTORY_FILE.get_file(), UPGRADES_FILE.get_file()
	]
	dir.list_dir_begin()
	var fname := dir.get_next()
	var removed_files: Array = []
	while fname != "":
		if fname == "." or fname == "..":
			fname = dir.get_next()
			continue
		if dir.current_is_dir():
			fname = dir.get_next()
			continue
		if not allowed.has(fname):
			# Safe remove; ignore errors
			var ok := dir.remove(fname)
			if ok == OK:
				removed_files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	if removed_files.size() > 0:
		print("Database: removed unexpected save files:", removed_files)

# ── Data Integrity Checks ─────────────────────────────────────────────────────
func check_data_integrity(profile: String = "Default") -> Dictionary:
	# Returns a report of data integrity issues found
	var report: Dictionary = {
		"tasks": [],
		"curio_canisters": [],
		"duplicates_found": false,
		"orphaned_studio_rooms": [],
		"total_issues": 0
	}
	
	# Check for duplicate default tasks
	var target_names := ["Drink Water", "Eat Food"]
	for name in target_names:
		var matches: Array = []
		for t in _tasks:
			if str(t.get("task", "")).strip_edges() == name and str(t.get("profile", "")) == profile:
				matches.append(t)
		
		if matches.size() > 1:
			report["duplicates_found"] = true
			report["total_issues"] += matches.size() - 1
			report["tasks"].append({
				"task_name": name,
				"count": matches.size(),
				"expected": 1,
				"duplicate_ids": matches.map(func(t): return t.get("id", -1))
			})
	
	# Check for orphaned studio rooms
	report["orphaned_studio_rooms"] = find_orphaned_studio_rooms()
	if report["orphaned_studio_rooms"].size() > 0:
		report["total_issues"] += report["orphaned_studio_rooms"].size()
	
	return report

func fix_data_integrity_issues(profile: String = "Default") -> Dictionary:
	var report := check_data_integrity(profile)
	if report["total_issues"] == 0:
		return {"fixed": 0, "message": "No data integrity issues found."}
	
	var fixed_count: int = 0
	
	# Fix duplicate tasks
	for task_issue in report["tasks"]:
		var task_name: String = task_issue["task_name"]
		var duplicate_ids: Array = task_issue["duplicate_ids"]
		if duplicate_ids.size() > 1:
			# Keep the first ID, delete the rest
			var keep_id: int = int(duplicate_ids[0])
			for i in range(1, duplicate_ids.size()):
				var delete_id: int = int(duplicate_ids[i])
				delete_task(delete_id)
				fixed_count += 1
	
	# Fix orphaned studio rooms
	for room_id in report["orphaned_studio_rooms"]:
		delete_studio_room_data(room_id)
		fixed_count += 1
	
	return {
		"fixed": fixed_count,
		"message": "Fixed %d data integrity issues." % fixed_count
	}

func _ensure_default_task(task_name: String, difficulty: int, profile: String, is_default: bool) -> void:
	for t in _tasks:
		if t.get("task","") == task_name and t.get("profile","") == profile:
			if is_default and not t.get("is_default", false):
				t["is_default"] = true
				_save_tasks()
			return
	var room_id := _next_studio_room_id
	_next_studio_room_id += 1
	var rec := {"id": _next_task_id, "task": task_name, "base_points": 5,
				"difficulty": difficulty, "die_sides": 6, "profile": profile,
				"is_default": is_default,
				"rituals": [], "consumables": [], "sticker_slots": [], "card_color": "white", "archived": false,
				"studio_room": room_id}
	_tasks.append(rec); _next_task_id += 1; _save_tasks()
	_persist_new_studio_room("task", rec.id, room_id)

# ── Tasks ─────────────────────────────────────────────────────────
func ensure_default_tasks_for_profile(profile: String) -> void:
	_ensure_default_task("Drink Water", 1, profile, true)
	_ensure_default_task("Eat Food",    1, profile, true)
	# Ensure there are no accidental duplicate default tasks created
	dedupe_default_tasks_for_profile(profile)

func get_tasks(profile: String, archived: bool = false) -> Array:
	return _tasks.filter(func(t): return t.get("profile","Default") == profile and bool(t.get("archived", false)) == archived)

func insert_task(task_name: String, difficulty: int, profile: String) -> int:
	var room_id := _next_studio_room_id
	_next_studio_room_id += 1
	var rec := {"id": _next_task_id, "task": task_name, "base_points": 5,
			"difficulty": difficulty, "die_sides": 6, "profile": profile,
			# stickers attached to this task
			"rituals": [], "consumables": [], "sticker_slots": [], "card_color": "white", "archived": false,
			"studio_room": room_id}
	_tasks.append(rec); _next_task_id += 1; _save_tasks()
	_persist_new_studio_room("task", rec.id, room_id)
	return rec.id

## Remove duplicate instances of important default tasks for a given profile.
## Ensures exactly one instance of each default task exists per profile.
## Keeps the first-created default task and removes all subsequent duplicates (both default and non-default).
func dedupe_default_tasks_for_profile(profile: String) -> void:
	var target_names := ["Drink Water", "Eat Food"]
	var removed_count: int = 0
	
	for name in target_names:
		var matches: Array = []
		for t in _tasks:
			if str(t.get("task", "")).strip_edges() == name and str(t.get("profile", "")) == profile:
				matches.append(t)
		
		if matches.size() <= 1:
			continue
		
		# Find the first default task (preferred) or first task if no defaults exist
		var keep_id: int = -1
		var first_default_found: bool = false
		
		# First pass: look for any default task
		for m in matches:
			if bool(m.get("is_default", false)) and not first_default_found:
				keep_id = int(m.get("id", -1))
				first_default_found = true
				break
		
		# If no default task found, keep the first task
		if keep_id == -1 and matches.size() > 0:
			keep_id = int(matches[0].get("id", -1))
		
		# Second pass: remove all other tasks (both default and non-default)
		for m in matches:
			var m_id: int = int(m.get("id", -1))
			if m_id != keep_id and m_id != -1:
				delete_task(m_id)
				removed_count += 1
	
	if removed_count > 0:
		print("Database: deduped %d duplicate default tasks for profile '%s'" % [removed_count, profile])

func update_task(task_id: int, field: String, value: Variant) -> void:
	for t in _tasks:
		if t.id == task_id: t[field] = value; break
	_save_tasks()

# ── Sticker helpers ─────────────────────────────────────────────
func add_task_sticker(task_id: int, sticker_id: String, type: String) -> void:
	# type is "ritual" or "consumable"
	for t in _tasks:
		if t.id == task_id:
			var key := "rituals" if type == "ritual" else "consumables"
			var arr: Array = t.get(key, [])
			if sticker_id in arr: return
			var slots: Array = _normalize_sticker_slots(t.get("sticker_slots", _build_sticker_slots_from_task(t)))
			if slots.size() < TASK_STICKER_SLOT_COUNT:
				slots.append({"type": type, "id": sticker_id})
			t["sticker_slots"] = slots
			_apply_task_sticker_slots(t)
			_save_tasks(); return

func remove_task_sticker(task_id: int, sticker_id: String, type: String) -> void:
	for t in _tasks:
		if t.id == task_id:
			var slots: Array = _normalize_sticker_slots(t.get("sticker_slots", _build_sticker_slots_from_task(t)))
			var removed: bool = false
			for i in range(slots.size()):
				var slot: Dictionary = slots[i] if slots[i] is Dictionary else {}
				if str(slot.get("type", "")) == type and str(slot.get("id", "")) == sticker_id:
					slots[i] = {}
					removed = true
					break
			if not removed:
				var key := "rituals" if type == "ritual" else "consumables"
				var arr: Array = t.get(key, [])
				if sticker_id in arr:
					arr.erase(sticker_id)
					t[key] = arr
					slots = _build_sticker_slots_from_task(t)
			t["sticker_slots"] = slots
			_apply_task_sticker_slots(t)
			_save_tasks(); return

func delete_task(task_id: int) -> void:
	for t in _tasks:
		if t.id == task_id and t.get("is_default", false):
			return
	var room_id := get_task_studio_room(task_id)
	_tasks = _tasks.filter(func(t): return t.id != task_id)
	_save_tasks()
	if room_id > 0:
		delete_studio_room_data(room_id)

func _normalize_sticker_inventory(raw_value: Variant) -> Array:
	var normalized: Array = []
	if raw_value is Array:
		for item in raw_value:
			var sticker_id := str(item).strip_edges()
			if sticker_id == "" or normalized.has(sticker_id):
				continue
			normalized.append(sticker_id)
	return normalized

func _normalize_sticker_slots(raw_value: Variant) -> Array:
	var normalized: Array = []
	if raw_value is Array:
		for slot_value in raw_value:
			if normalized.size() >= TASK_STICKER_SLOT_COUNT:
				break
			if slot_value is Dictionary:
				var slot: Dictionary = slot_value
				var slot_type := str(slot.get("type", "")).strip_edges()
				var slot_id := str(slot.get("id", "")).strip_edges()
				if (slot_type == "ritual" or slot_type == "consumable") and slot_id != "":
					var norm_x: float = clampf(float(slot.get("x", -1.0)), 0.0, 1.0)
					var norm_y: float = clampf(float(slot.get("y", -1.0)), 0.0, 1.0)
					if norm_x >= 0.0 and norm_y >= 0.0:
						normalized.append({"type": slot_type, "id": slot_id, "x": norm_x, "y": norm_y})
					else:
						normalized.append({"type": slot_type, "id": slot_id})
				else:
					normalized.append({})
			else:
				normalized.append({})
	return normalized

func _build_sticker_slots_from_task(task: Dictionary) -> Array:
	var slots: Array = []
	for sticker_id in task.get("rituals", []):
		if slots.size() >= TASK_STICKER_SLOT_COUNT:
			break
		var clean_id := str(sticker_id).strip_edges()
		if clean_id != "":
			slots.append({"type": "ritual", "id": clean_id})
	for sticker_id in task.get("consumables", []):
		if slots.size() >= TASK_STICKER_SLOT_COUNT:
			break
		var clean_id := str(sticker_id).strip_edges()
		if clean_id != "":
			slots.append({"type": "consumable", "id": clean_id})
	return slots

func _apply_task_sticker_slots(task: Dictionary) -> void:
	var rituals: Array = []
	var consumables: Array = []
	var slots: Array = _normalize_sticker_slots(task.get("sticker_slots", []))
	task["sticker_slots"] = slots
	for slot_value in slots:
		if slot_value is not Dictionary:
			continue
		var slot: Dictionary = slot_value
		if slot.is_empty():
			continue
		var slot_type := str(slot.get("type", ""))
		var slot_id := str(slot.get("id", ""))
		if slot_id == "":
			continue
		if slot_type == "ritual":
			rituals.append(slot_id)
		elif slot_type == "consumable":
			consumables.append(slot_id)
	task["rituals"] = rituals
	task["consumables"] = consumables

func get_owned_stickers(sticker_type: String) -> Array:
	var key := "owned_ritual_stickers" if sticker_type == "ritual" else "owned_consumable_stickers"
	return _normalize_sticker_inventory(_inventory.get(key, []))

func unlock_sticker(sticker_type: String, sticker_id: String) -> void:
	var key := "owned_ritual_stickers" if sticker_type == "ritual" else "owned_consumable_stickers"
	var owned := _normalize_sticker_inventory(_inventory.get(key, []))
	var clean_id := sticker_id.strip_edges()
	if clean_id == "" or owned.has(clean_id):
		return
	owned.append(clean_id)
	_inventory[key] = owned
	_save_inventory()

func add_sticker_to_inventory(sticker_id: String, profile: String) -> void:
	# Determine if it's a ritual or consumable sticker based on which catalog it belongs to
	var sticker_type: String = "ritual" if GameData.RITUAL_STICKERS.has(sticker_id) else "consumable"
	if sticker_type == "consumable" and not GameData.CONSUMABLE_STICKERS.has(sticker_id):
		print("WARNING: Sticker ID '%s' not found in either ritual or consumable catalogs" % sticker_id)
		return
	
	# Use the existing unlock_sticker method which handles normalization and saving
	unlock_sticker(sticker_type, sticker_id)

# ── Curio Canisters ────────────────────────────────────────────────────────
func get_task_studio_room(task_id: int) -> int:
	for t in _tasks:
		if t.id == task_id:
			return int(t.get("studio_room", -1))
	return -1

func get_curio_canister_studio_room(curio_canister_id: int) -> int:
	for r in _curio_canisters:
		if r.id == curio_canister_id:
			return int(r.get("studio_room", -1))
	return -1

func get_curio_canisters(profile: String, archived: bool = false) -> Array:
	return _curio_canisters.filter(func(r): return r.get("profile","Default") == profile and bool(r.get("archived", false)) == archived)

# Returns true if the given curio canister has a stored last_rolled_date equal
# to the provided date_str (meaning it was used/rolled that day).
func has_curio_rolled_today(curio_id: int, date_str: String, profile: String) -> bool:
	for r in _curio_canisters:
		if int(r.get("id", -1)) == curio_id and str(r.get("profile", "")) == profile:
			return str(r.get("last_rolled_date", "")) == date_str
	return false

# Marks a curio canister as rolled on the given date (sets `last_rolled_date`).
func mark_curio_rolled(curio_id: int, date_str: String, profile: String) -> void:
	var changed: bool = false
	for i in range(_curio_canisters.size()):
		var r := _curio_canisters[i] as Dictionary
		if int(r.get("id", -1)) == curio_id and str(r.get("profile", "")) == profile:
			r["last_rolled_date"] = date_str
			_curio_canisters[i] = r
			changed = true
			break
	if changed:
		_save_curio_canisters()

# Clears the `last_rolled_date` for all curio canisters matching the date and profile.
# Used when resetting a day to allow fresh rolls.
func clear_curio_rolled_flags(date_str: String, profile: String) -> void:
	var changed: bool = false
	for i in range(_curio_canisters.size()):
		var r := _curio_canisters[i] as Dictionary
		if str(r.get("profile", "")) == profile and str(r.get("last_rolled_date", "")) == date_str:
			r["last_rolled_date"] = ""
			_curio_canisters[i] = r
			changed = true
	if changed:
		_save_curio_canisters()

# Convenience helper: returns true if a dice box stat exists for the date/profile.
func has_dice_box_record(date_str: String, profile: String) -> bool:
	var rec: Variant = get_dice_box_stat(date_str, profile)
	if rec != null:
		print("Database: has_dice_box_record true for %s:%s -> %s" % [date_str, profile, str(rec)])
	return rec != null

func insert_curio_canister(title: String, mult: float, rarity: String, profile: String, emoji: String = "✦") -> int:
	var room_id := _next_studio_room_id
	_next_studio_room_id += 1
	var rec := {"id": _next_curio_canister_id, "title": title, "mult": mult,
				"rarity": rarity, "emoji": emoji, "image_path": "default.png", "profile": profile,
				"card_color": "white", "archived": false, "studio_room": room_id}
	_curio_canisters.append(rec); _next_curio_canister_id += 1; _save_curio_canisters()
	_persist_new_studio_room("curio_canister", rec.id, room_id)
	return rec.id

func update_curio_canister(curio_canister_id: int, field: String, value: Variant) -> void:
	for r in _curio_canisters:
		if r.id == curio_canister_id: r[field] = value; break
	_save_curio_canisters()

func delete_curio_canister(curio_canister_id: int) -> void:
	var room_id := get_curio_canister_studio_room(curio_canister_id)
	_curio_canisters = _curio_canisters.filter(func(r): return r.id != curio_canister_id)
	_save_curio_canisters()
	if room_id > 0:
		delete_studio_room_data(room_id)


# ── Daily Stats ───────────────────────────────────────────────────
func get_dice_box_stat(date_str: String, profile: String) -> Variant:
	return _dice_box_stats.get("%s:%s" % [date_str, profile], null)

func delete_dice_box_stat(date_str: String, profile: String) -> void:
	var key := "%s:%s" % [date_str, profile]
	if _dice_box_stats.has(key):
		_dice_box_stats.erase(key)
		_save_dice_box_stats()

func save_dice_box_stat(date_str: String, profile: String, task_rolls: String,
										completed_tasks: String, total_score: int,
										dice_layout: String = "", dice_box_tex: String = "") -> void:
	var key := "%s:%s" % [date_str, profile]
	var existing: Dictionary = _dice_box_stats.get(key, {})
	_dice_box_stats[key] = {date=date_str, profile=profile,
		task_rolls=task_rolls, completed_tasks=completed_tasks, total_score=total_score,
		dice_layout=dice_layout if dice_layout != "" else existing.get("dice_layout", ""),
		dice_box_tex = dice_box_tex if dice_box_tex != "" else existing.get("dice_box_tex", ""),
		moonpearls_awarded=existing.get("moonpearls_awarded", 0),
		award_log=existing.get("award_log", [])}
	_save_dice_box_stats()

func save_dice_box_layout(date_str: String, profile: String, layout_json: String) -> void:
	var key := "%s:%s" % [date_str, profile]
	if _dice_box_stats.has(key):
		_dice_box_stats[key].dice_layout = layout_json
	else:
		_dice_box_stats[key] = {date=date_str, profile=profile,
			task_rolls="", completed_tasks="", total_score=0,
			dice_layout=layout_json}
	_save_dice_box_stats()

func get_dice_box_layout(date_str: String, profile: String) -> String:
	var key := "%s:%s" % [date_str, profile]
	if _dice_box_stats.has(key):
		return _dice_box_stats[key].get("dice_layout", "")
	return ""

func award_dice_box_moonpearls(date_str: String, profile: String, score: int, prev_score_override: int = -1) -> int:
	var key := "%s:%s" % [date_str, profile]
	if not _dice_box_stats.has(key): return 0
	# Use an explicit override when supplied (caller read the previous saved
	# total before updating the DB) — otherwise fall back to the stored value.
	var prev_score: int = prev_score_override if prev_score_override >= 0 else int(_dice_box_stats[key].get("total_score", 0))
	var prev_awarded: int = int(_dice_box_stats[key].get("moonpearls_awarded", 0))
	var delta: int = score - prev_score
	if delta > 0:
		if delta > 100:
			print("Database WARNING: unusually large moonpearls delta %d for %s" % [delta, key])
		var log_entry: Dictionary = {"time": int(Time.get_unix_time_from_system()), "prev_awarded": prev_awarded,
			"prev_score": prev_score, "new_score": score, "delta": delta, "source": "award_dice_box_moonpearls"}
		var existing_log: Array = _dice_box_stats[key].get("award_log", [])
		existing_log.append(log_entry)
		_dice_box_stats[key]["award_log"] = existing_log
		# Update cumulative awarded amount and the recorded total_score.
		_dice_box_stats[key]["moonpearls_awarded"] = prev_awarded + delta
		_dice_box_stats[key]["total_score"] = score
		_save_dice_box_stats()
		# Immediately commit the awarded moonpearls to the canonical wallet so
		# callers do not need to remember to call add_moonpearls separately.
		# This keeps awarding atomic and avoids visual-only/session-only awards.
		add_moonpearls(delta, profile)
		print("Database: awarding %d moonpearls for %s (prev_score %d -> %d)" % [delta, key, prev_score, score])
		# The delta has been committed; return it for presentation layers.
	return delta

func get_all_dice_box_stats(profile: String) -> Array:
	var result := []
	for rec: Dictionary in _dice_box_stats.values():
		if rec.get("profile", "") == profile:
			result.append(rec)
	return result

func get_stats_range(profile: String, from_date: String, to_date: String) -> Array:
	return get_all_dice_box_stats(profile).filter(
		func(r: Dictionary):
			var d: String = r.get("date", "")
			return d >= from_date and d <= to_date
	)

# Returns the sum of all moonpearls ever awarded across all days for a profile.
# Total available = get_total_moonpearls_earned() - get_moonpearls_pressed()

## Returns all daily-stat records for a given year/month.
func get_monthly_stats(year: int, month: int, profile: String) -> Array:
	var from_str: String = "%04d-%02d-01" % [year, month]
	var to_str:   String = "%04d-%02d-31" % [year, month]
	return get_stats_range(profile, from_str, to_str)

## Returns the N most recent daily-stat records, newest first.
func get_recent_stats(profile: String, count: int = 7) -> Array:
	var all_s: Array = get_all_dice_box_stats(profile)
	all_s.sort_custom(func(a, b): return a.get("date","") > b.get("date",""))
	return all_s.slice(0, count)
func get_total_moonpearls_earned(profile: String) -> int:
	var total := 0
	for rec: Dictionary in _dice_box_stats.values():
		if rec.get("profile", "") == profile:
			total += int(rec.get("moonpearls_awarded", 0))
	return total

# ── Contracts ─────────────────────────────────────────────────────
func get_contracts(profile: String, archived: bool = false) -> Array:
	return _contracts.filter(func(c): return c.get("profile","Default") == profile and c.get("archived", false) == archived)

func get_contract_subtask_cards(contract: Dictionary) -> Array:
	var cards: Array = _normalize_subtask_cards(contract.get("subtask_cards", []))
	if cards.is_empty():
		cards = _build_blank_subtask_cards(str(contract.get("subtasks", "")))
	return cards

func count_incomplete_contract_subtasks(contract: Dictionary) -> int:
	var incomplete: int = 0
	for card in get_contract_subtask_cards(contract):
		if not bool(card.get("completed", false)):
			incomplete += 1
	return incomplete

func contract_has_incomplete_subtasks(contract: Dictionary) -> bool:
	return count_incomplete_contract_subtasks(contract) > 0

func can_complete_contract(contract_id: int) -> bool:
	for c in _contracts:
		if int(c.get("id", 0)) == contract_id:
			return not contract_has_incomplete_subtasks(c)
	return false

func set_contract_subtask_completed(contract_id: int, subtask_id: int, completed: bool) -> bool:
	for c in _contracts:
		if int(c.get("id", 0)) != contract_id:
			continue
		var cards: Array = get_contract_subtask_cards(c)
		var matched: bool = false
		var changed: bool = false
		for i in range(cards.size()):
			var card := cards[i] as Dictionary
			if int(card.get("id", -1)) != subtask_id:
				continue
			matched = true
			if bool(card.get("completed", false)) != completed:
				card["completed"] = completed
				cards[i] = card
				changed = true
			break
		if not matched:
			return false
		c["subtask_cards"] = cards
		if changed:
			_save_contracts()
		return true
	return false

func _normalize_subtask_cards(cards_value: Variant) -> Array:
	var normalized: Array = []
	if cards_value is Array:
		for item in cards_value:
			if item is not Dictionary:
				continue
			var title: String = str(item.get("title", "")).strip_edges()
			if title == "":
				continue
			var modifiers: Array = item.get("modifiers", []) if item.get("modifiers", []) is Array else []
			normalized.append({
				"id": int(item.get("id", normalized.size())),
				"title": title,
				"subheading": str(item.get("subheading", "")).strip_edges(),
				"modifiers": modifiers,
				"completed": bool(item.get("completed", false)),
			})
	return normalized

func _build_blank_subtask_cards(subtasks: String) -> Array:
	var cards: Array = []
	var idx: int = 0
	for raw in subtasks.split(",", false):
		var title: String = raw.strip_edges()
		if title == "":
			continue
		cards.append({"id": idx, "title": title, "subheading": "", "modifiers": [], "completed": false})
		idx += 1
	return cards

func insert_contract(contract_name: String, difficulty: String, deadline: String,
					  subtasks: String, reward_type: String, notes: String = "", profile: String = "") -> int:
	var rec := {id=_next_contract_id, name=contract_name, difficulty=difficulty,
		subheading="", deadline=deadline, completed_date="", subtasks=subtasks,
		subtask_cards=_build_blank_subtask_cards(subtasks),
		reward_type=reward_type, notes=notes, archived=false, profile=profile,
		created_date=_today()}
	_contracts.append(rec); _next_contract_id += 1; _save_contracts()
	return rec.id

func insert_dev_sample_contract(sample: Dictionary, profile: String) -> int:
	var subtasks: String = str(sample.get("subtasks", "")).strip_edges()
	var subtask_cards: Array = _normalize_subtask_cards(sample.get("subtask_cards", []))
	if subtask_cards.is_empty():
		subtask_cards = _build_blank_subtask_cards(subtasks)
	var rec := {
		id = _next_contract_id,
		name = str(sample.get("name", "Contract")).strip_edges(),
		subheading = str(sample.get("subheading", "")).strip_edges(),
		difficulty = str(sample.get("difficulty", "No Priority")).strip_edges(),
		deadline = str(sample.get("deadline", "")).strip_edges(),
		completed_date = "",
		subtasks = subtasks,
		subtask_cards = subtask_cards,
		reward_type = str(sample.get("reward_type", "minor")).strip_edges(),
		notes = str(sample.get("notes", "")).strip_edges(),
		archived = false,
		profile = profile,
		created_date = _today(),
	}
	_contracts.append(rec); _next_contract_id += 1; _save_contracts()
	return rec.id

func complete_contract(contract_id: int) -> bool:
	for c in _contracts:
		if int(c.get("id", 0)) != contract_id:
			continue
		if contract_has_incomplete_subtasks(c):
			return false
		c.completed_date = _today()
		c.archived = true
		_save_contracts()
		return true
	return false

func complete_contract_with_reward(contract_id: int) -> Dictionary:
	for c in _contracts:
		if int(c.get("id", 0)) != contract_id:
			continue
		if contract_has_incomplete_subtasks(c):
			return {}
		c.completed_date = _today()
		c.archived = true
		_save_contracts()
		SignalBus.contract_completed.emit(contract_id)
		return _grant_moonkissed_paper(c)
	return {}

func _grant_contract_reward(contract: Dictionary) -> Dictionary:
	var profile := str(contract.get("profile", "Default")).strip_edges()
	if profile == "":
		profile = "Default"
	var reward_type := str(contract.get("reward_type", "minor")).to_lower()
	var discovered_ids: Array = []
	for planted in get_garden(profile):
		discovered_ids.append(str(planted.get("plant_id", "")))
	var undiscovered: Array = []
	for plant in GameData.PLANT_CATALOG:
		var catalog_plant_id := str(plant.get("id", ""))
		if catalog_plant_id == "":
			continue
		if not discovered_ids.has(catalog_plant_id):
			undiscovered.append(plant)
	var all_plants_discovered: bool = undiscovered.is_empty()
	var reward_pool: Array = undiscovered if not all_plants_discovered else GameData.PLANT_CATALOG
	var awarded_plant: Dictionary = _pick_contract_reward_plant(reward_pool, reward_type)
	if awarded_plant.is_empty():
		add_cerulean_seed(1)
		_save_inventory()
		var fallback_reward := {
			"contract_id": int(contract.get("id", 0)),
			"contract_name": str(contract.get("name", "Contract")),
			"profile": profile,
			"reward_type": reward_type,
			"plant_id": "",
			"plant": {},
			"rarity": "common",
			"is_new": false,
			"seed_refunded": true,
			"all_plants_discovered": true,
		}
		SignalBus.contract_reward_sequence.emit(fallback_reward)
		return fallback_reward
	var plant_id := str(awarded_plant.get("id", ""))
	var is_new := not discovered_ids.has(plant_id)
	if is_new:
		plant_seed(plant_id, profile)
		SignalBus.moonseed_found.emit()
	else:
		add_cerulean_seed(1)
	var reward := {
		"contract_id": int(contract.get("id", 0)),
		"contract_name": str(contract.get("name", "Contract")),
		"profile": profile,
		"reward_type": reward_type,
		"plant_id": plant_id,
		"plant": awarded_plant.duplicate(true),
		"rarity": str(awarded_plant.get("rarity", "common")),
		"is_new": is_new,
		"seed_refunded": not is_new,
		"all_plants_discovered": all_plants_discovered,
	}
	SignalBus.contract_reward_sequence.emit(reward)
	return reward

func _grant_moonkissed_paper(contract: Dictionary) -> Dictionary:
	var profile := str(contract.get("profile", "Default")).strip_edges()
	if profile == "":
		profile = "Default"
	var difficulty := str(contract.get("difficulty", "No Priority")).strip_edges()
	var reward_tier := "minor"
	if difficulty == "Medium Priority" or difficulty == "High Priority":
		reward_tier = "major"
	var contract_name := str(contract.get("name", "Contract"))
	var contract_id := int(contract.get("id", 0))
	add_moonkissed_paper(contract_id, contract_name, reward_tier, profile)
	return {
		"contract_id": contract_id,
		"contract_name": contract_name,
		"profile": profile,
		"reward_tier": reward_tier,
		"moonkissed_paper": true,
	}

func _pick_contract_reward_plant(pool: Array, reward_type: String) -> Dictionary:
	if pool.is_empty():
		return {}
	var rarity_weights: Dictionary = CONTRACT_REWARD_WEIGHTS.get(reward_type, CONTRACT_REWARD_WEIGHTS["minor"])
	var weighted_pool: Array = []
	for entry in pool:
		var plant := entry as Dictionary
		var rarity := str(plant.get("rarity", "common")).to_lower()
		var weight: int = max(int(rarity_weights.get(rarity, 1)), 1)
		for _i in range(weight):
			weighted_pool.append(plant)
	if weighted_pool.is_empty():
		return {}
	return (weighted_pool[randi() % weighted_pool.size()] as Dictionary).duplicate(true)

func delete_contract(contract_id: int) -> void:
	_contracts = _contracts.filter(func(c): return c.id != contract_id)
	_save_contracts()

# ── Contract Templates ─────────────────────────────────────────────────────
var _contract_templates: Array = []

func _load_contract_templates() -> void:
	_contract_templates = _load_json(CONTRACT_TEMPLATES_FILE, [])

func _save_contract_templates() -> void:
	_save_json(CONTRACT_TEMPLATES_FILE, _contract_templates)

func get_contract_templates(profile: String) -> Array:
	return _contract_templates.filter(func(t): return t.get("profile","Default") == profile)

func insert_contract_template(template_name: String, difficulty: String, subtasks: String,
								reward_type: String, notes: String = "", profile: String = "") -> int:
	var rec := {id=_next_contract_id, name=template_name, difficulty=difficulty,
		subheading="", deadline="", completed_date="", subtasks=subtasks,
		subtask_cards=_build_blank_subtask_cards(subtasks),
		reward_type=reward_type, notes=notes, profile=profile,
		created_date=_today()}
	_contract_templates.append(rec); _next_contract_id += 1; _save_contract_templates()
	return rec.id

func update_contract_template(template_id: int, field: String, value: Variant) -> void:
	for t in _contract_templates:
		if t.id == template_id: t[field] = value; break
	_save_contract_templates()

func delete_contract_template(template_id: int) -> void:
	_contract_templates = _contract_templates.filter(func(t): return t.id != template_id)
	_save_contract_templates()

func copy_template_to_contract(template_id: int, profile: String) -> int:
	for t in _contract_templates:
		if t.id == template_id:
			var rec := {id=_next_contract_id, name=t.name, difficulty=t.difficulty,
				subheading=t.get("subheading", ""), deadline="", completed_date="", subtasks=t.subtasks,
				subtask_cards=t.get("subtask_cards", _build_blank_subtask_cards(t.subtasks)),
				reward_type=t.reward_type, notes=t.notes, archived=false, profile=profile,
				created_date=_today()}
			_contracts.append(rec); _next_contract_id += 1; _save_contracts()
			return rec.id
	return -1

# ── Inventory ─────────────────────────────────────────────────────
func get_inventory() -> Dictionary: return _inventory.duplicate()

func add_dice(sides: int, qty: int = 1) -> void:
	var key := str(sides)
	_inventory[key] = _inventory.get(key, 0) + qty
	_save_inventory()

func use_dice(sides: int) -> bool:
	var key := str(sides)
	if _inventory.get(key, 0) > 0:
		_inventory[key] -= 1; _save_inventory(); return true
	return false

func get_cerulean_seeds() -> int:
	return int(_inventory.get("cerulean_seeds", 0))

func add_cerulean_seed(qty: int = 1) -> void:
	_inventory["cerulean_seeds"] = int(_inventory.get("cerulean_seeds", 0)) + qty
	_save_inventory()

func use_cerulean_seed() -> bool:
	var count: int = int(_inventory.get("cerulean_seeds", 0))
	if count > 0:
		_inventory["cerulean_seeds"] = count - 1
		_save_inventory()
		return true
	return false

# ── Shop Owned ────────────────────────────────────────────────────
func get_shop_owned(profile: String) -> Array:
	return _shop_owned.filter(func(i): return i.get("profile","Default") == profile)

func add_shop_item(item_id: String, profile: String) -> void:
	_shop_owned.append({item_id=item_id, profile=profile, date=_today()})
	_save_shop_owned()

func remove_shop_item(item_id: String, profile: String) -> void:
	_shop_owned = _shop_owned.filter(func(i):
		return not (i.item_id == item_id and i.get("profile","Default") == profile))
	_save_shop_owned()

func has_shop_item(item_id: String, profile: String) -> bool:
	for i in _shop_owned:
		if i.item_id == item_id and i.get("profile","Default") == profile: return true
	return false

# ── Garden Constants ──────────────────────────────────────────────
const GARDEN_W := 18.0
const GARDEN_H := 14.0

# ── Garden ────────────────────────────────────────────────────────
func get_garden(profile: String) -> Array:
	return _garden.filter(func(g): return g.get("profile","Default") == profile)

func plant_seed(plant_id: String, profile: String,
				pos_x: float = -999.0, pos_z: float = -999.0) -> void:
	if not _garden.any(func(g): return g.plant_id == plant_id and g.get("profile","") == profile):
		# Convert world coordinates to normalized (0.0 to 1.0) for consistent storage
		var nx: float = pos_x if pos_x != -999.0 else randf_range(-7.0, 7.0)
		var nz: float = pos_z if pos_z != -999.0 else randf_range(-7.0, 7.0)
		var norm_x: float = clampf(inverse_lerp(-GARDEN_W * 0.5, GARDEN_W * 0.5, nx), 0.0, 1.0)
		var norm_z: float = clampf(inverse_lerp(-GARDEN_H * 0.5, GARDEN_H * 0.5, nz), 0.0, 1.0)
		_garden.append({plant_id=plant_id, profile=profile, planted_date=_today(),
			stage=0, pos_x=norm_x, pos_z=norm_z})
		_save_garden()

func move_plant(plant_id: String, profile: String, pos_x: float, pos_z: float) -> void:
	for i in range(_garden.size()):
		var g := _garden[i] as Dictionary
		if str(g.get("plant_id", "")) == plant_id and str(g.get("profile", "")) == profile:
			# pos_x and pos_z are already normalized (0.0 to 1.0) from UI
			g["pos_x"] = clampf(pos_x, 0.0, 1.0)
			g["pos_z"] = clampf(pos_z, 0.0, 1.0)
			_garden[i] = g
			_save_garden()
			return

func water_plant(plant_id: String, profile: String) -> bool:
	var today := _today()
	for g in _garden:
		if g.plant_id == plant_id and g.get("profile","") == profile:
			if g.get("last_watered","") == today:
				return false
			g.stage = min(g.get("stage",0) + 1, 2)
			g.last_watered = today
			_save_garden()
			SignalBus.garden_plant_watered.emit(plant_id, int(g.stage))
			return true
	return false

func remove_plant(plant_id: String, profile: String) -> void:
	_garden = _garden.filter(func(g):
		return not (g.plant_id == plant_id and g.get("profile","") == profile))
	_save_garden()

# ── Garden Migration ──────────────────────────────────────────────
func migrate_garden_coordinates() -> void:
	var migrated: bool = false
	for i in range(_garden.size()):
		var g := _garden[i] as Dictionary
		var px: float = float(g.get("pos_x", 0.5))
		var pz: float = float(g.get("pos_z", 0.5))
		
		# Check if coordinates are in world range (likely -9 to 9) instead of normalized (0 to 1)
		if px < -0.1 or px > 1.1 or pz < -0.1 or pz > 1.1:
			# Convert world coordinates to normalized
			var norm_x: float = clampf(inverse_lerp(-GARDEN_W * 0.5, GARDEN_W * 0.5, px), 0.0, 1.0)
			var norm_z: float = clampf(inverse_lerp(-GARDEN_H * 0.5, GARDEN_H * 0.5, pz), 0.0, 1.0)
			g["pos_x"] = norm_x
			g["pos_z"] = norm_z
			_garden[i] = g
			migrated = true
	
	if migrated:
		_save_garden()
		print("Database: migrated garden plant coordinates to normalized system")

# ── Settings / Profiles ───────────────────────────────────────────
func get_setting(key: String, default: Variant = null) -> Variant:
	return _settings.get(key, default)

func get_bool(key: String, default: bool=false) -> bool:
	var v: Variant = _settings.get(key, default)
	if typeof(v) == TYPE_BOOL:
		return bool(v)
	if typeof(v) == TYPE_STRING:
		var s: String = String(v).strip_edges().to_lower()
		return s == "true" or s == "1" or s == "yes"
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v) != 0
	return default

func save_setting(key: String, value: Variant) -> void:
	_settings[key] = value; _save_settings()

func get_profiles() -> Array: return _profiles.duplicate()

func add_profile(profile_name: String) -> void:
	var name := str(profile_name).strip_edges()
	if name == "": return
	# In single-profile mode treat add_profile as renaming/changing the single profile name.
	_profiles = [{"name": name, "created_date": _today(), "is_active": 1}]
	save_setting("profile", name)
	_enforce_single_profile()
	_save_profiles()

func delete_profile(profile_name: String) -> void:
	# Profile deletion is disabled in single-profile mode. If user requests to reset,
	# revert to the "Default" profile name and normalize data.
	if str(profile_name).strip_edges() == "Default":
		return
	save_setting("profile", "Default")
	_enforce_single_profile()
	_save_profiles()

# ── Studio Rooms ────────────────────────────────────────────────
## Return the raw data dict for room_id, or {} if it does not exist.
func get_studio_room_data(room_id: int) -> Dictionary:
	var entry: Variant = _studio_rooms.get(room_id, {})
	if entry is Dictionary:
		return (entry as Dictionary).duplicate()
	return {}

## Persist an updated StudioRoomData record, stamping last_modified.
func upsert_studio_room_data(data: StudioRoomData) -> void:
	data.touch()
	_studio_rooms[data.room_id] = data.to_dict()
	_save_studio_rooms()

## Delete the data record for room_id and emit studio_room_deleted.
## Called automatically by delete_task(), delete_relic(), and delete_profile().
func delete_studio_room_data(room_id: int) -> void:
	if not _studio_rooms.has(room_id):
		return
	_studio_rooms.erase(room_id)
	_save_studio_rooms()
	SignalBus.studio_room_deleted.emit(room_id)

## All persisted room data records as an Array of plain Dictionaries.
func get_all_studio_room_data() -> Array:
	return _studio_rooms.values().duplicate()

## Room IDs whose owner task or relic no longer exists in any profile.
## Useful for garbage-collecting stale data during debug or migration.
func find_orphaned_studio_rooms() -> Array:
	var live_task_ids:  Array = _tasks.map(func(t): return int(t.get("id", -1)))
	var live_curio_canister_ids: Array = _curio_canisters.map(func(r): return int(r.get("id", -1)))
	var orphans: Array = []
	for room_id: Variant in _studio_rooms:
		var room: Dictionary = _studio_rooms[room_id] as Dictionary
		var otype := str(room.get("owner_type", ""))
		var oid   := int(room.get("owner_id",   -1))
		match otype:
			"task":
				if oid not in live_task_ids:
					orphans.append(int(room_id))
			"curio_canister":
				if oid not in live_curio_canister_ids:
					orphans.append(int(room_id))
			_:
				orphans.append(int(room_id))
	return orphans

## Public: allocate a new room id, persist the entry, and emit studio_room_created.
## Use this only when creating a room outside normal task/relic insertion.
## The normal path is insert_task() / insert_relic() which call _persist_new_studio_room().
## Duplicate guard: if an entry for this owner_type + owner_id already exists, its
## room_id is returned immediately and no new record is created.
func create_studio_room(owner_type: String, owner_id: int) -> int:
	# Guard against duplicate room creation for the same owner.
	for rid: Variant in _studio_rooms:
		var rec: Dictionary = _studio_rooms[rid] as Dictionary
		if str(rec.get("owner_type", "")) == owner_type and int(rec.get("owner_id", -1)) == owner_id:
			return int(rid)
	var room_id := _next_studio_room_id
	_next_studio_room_id += 1
	_persist_new_studio_room(owner_type, owner_id, room_id)
	return room_id

## Remove all studio room records whose owner task or relic no longer exists.
## Delegates actual deletion to delete_studio_room_data() so the signal + view-cull
## chain fires normally for every removed room.
## Called from StudioRoomManager._ready() after data is loaded.
func cleanup_orphaned_studio_rooms() -> void:
	var orphans := find_orphaned_studio_rooms()
	for room_id: Variant in orphans:
		delete_studio_room_data(int(room_id))

## Internal: allocate and persist a new room entry, emit studio_room_created.
## All insert paths (insert_task, insert_relic, _ensure_default_task) call this.
func _persist_new_studio_room(owner_type: String, owner_id: int, room_id: int) -> void:
	var data := StudioRoomData.new(room_id, owner_type, owner_id)
	_studio_rooms[room_id] = data.to_dict()
	_save_studio_rooms()
	SignalBus.studio_room_created.emit(room_id, owner_type, owner_id)

# ── Helpers ───────────────────────────────────────────────────────
func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

# ── Economy (Moonpearls / Stardust / Water) ─────────────────────
## Coins removed: use moonpearls APIs (`get_moonpearls`, `add_moonpearls`, `spend_moonpearls`)

func _get_profile_economy(profile: String) -> Dictionary:
	if not _economy.has(profile):
		_economy[profile] = {"moonpearls":0,"moonpearls_pressed":0,"moonpearls_earned_total":0,"moonpearls_spent_total":0,"water_meter":0.0,"meals_today":0,"last_meal_date":"","machine_running":false}
	return _economy[profile]

func get_water_meter(profile: String = "Default") -> float:
	var econ := _get_profile_economy(profile)
	return float(econ.get("water_meter", 0.0))

func set_water_meter(value: float, profile: String = "Default") -> void:
	var econ := _get_profile_economy(profile)
	econ["water_meter"] = clampf(value, 0.0, 1.0)
	_save_economy()

func get_meals_today(profile: String = "Default") -> int:
	var econ := _get_profile_economy(profile)
	var today := _today()
	if econ.get("last_meal_date", "") != today:
		econ["meals_today"] = 0
		econ["last_meal_date"] = today
		_save_economy()
	return int(econ.get("meals_today", 0))

func set_meals_today(count: int, profile: String = "Default") -> void:
	var econ := _get_profile_economy(profile)
	econ["meals_today"] = clampi(count, 0, 3)
	econ["last_meal_date"] = _today()
	_save_economy()

func get_moonpearls_pressed(profile: String = "Default") -> int:
	var econ := _get_profile_economy(profile)
	return int(econ.get("moonpearls_pressed", 0))

func add_moonpearls_pressed(amount: int, profile: String = "Default") -> void:
	var econ := _get_profile_economy(profile)
	econ["moonpearls_pressed"] = int(econ.get("moonpearls_pressed", 0)) + amount
	_save_economy()

func get_bazaar_service_level(profile: String = "Default") -> int:
	var econ := _get_profile_economy(profile)
	return int(econ.get("bazaar_service_level", 0))

func set_bazaar_service_level(level: int, profile: String = "Default") -> void:
	var econ := _get_profile_economy(profile)
	econ["bazaar_service_level"] = level
	_save_economy()

func get_moonpearls(profile: String = "Default") -> int:
	var econ := _get_profile_economy(profile)
	return int(econ.get("moonpearls", 0))

func get_moonpearls_earned_total(profile: String = "Default") -> int:
	var econ := _get_profile_economy(profile)
	return int(econ.get("moonpearls_earned_total", 0))

func get_moonpearls_spent_total(profile: String = "Default") -> int:
	var econ := _get_profile_economy(profile)
	return int(econ.get("moonpearls_spent_total", 0))

func add_moonpearls(amount: int, profile: String = "Default") -> void:
	var econ := _get_profile_economy(profile)
	var current := int(econ.get("moonpearls", 0))
	var earned_total := int(econ.get("moonpearls_earned_total", 0))
	
	# Update current balance and total earned
	var new_val := current + amount
	econ["moonpearls"] = new_val
	econ["moonpearls_earned_total"] = earned_total + amount
	_save_economy()
	print("Database: add_moonpearls amount=", amount, "profile=", profile, "old=", current, "new=", new_val)
	# Emit canonical change so UI can update. Use SignalBus if available.
	if Engine.has_singleton("SignalBus"):
		SignalBus.moonpearls_changed.emit(get_moonpearls(profile))

func spend_moonpearls(amount: int, profile: String = "Default") -> bool:
	var econ := _get_profile_economy(profile)
	var current := int(econ.get("moonpearls", 0))
	var spent_total := int(econ.get("moonpearls_spent_total", 0))
	
	# Prevent negative balance
	if current < amount: return false
	
	# Deduct from current balance and update spent total
	econ["moonpearls"] = current - amount
	econ["moonpearls_spent_total"] = spent_total + amount
	_save_economy()
	# Emit canonical change so UI can update.
	if Engine.has_singleton("SignalBus"):
		SignalBus.moonpearls_changed.emit(get_moonpearls(profile))
	return true

func get_machine_running(profile: String = "Default") -> bool:
	var econ := _get_profile_economy(profile)
	return bool(econ.get("machine_running", false))

func set_machine_running(state: bool, profile: String = "Default") -> void:
	var econ := _get_profile_economy(profile)
	econ["machine_running"] = state
	_save_economy()

func get_economy(profile: String = "Default") -> Dictionary:
	var econ := _get_profile_economy(profile)
	return econ.duplicate()

# ── Decorations ────────────────────────────────────────────────────
func get_decorations(profile: String) -> Array:
	return _decorations.filter(func(d): return d.get("profile","Default") == profile)

func add_decoration(dec_id: String, profile: String, pos_x: float, pos_y: float) -> void:
	var next_id: int = 1
	for rec in _decorations:
		next_id = maxi(next_id, int((rec as Dictionary).get("id", 0)) + 1)
	_decorations.append({
		id = next_id,
		dec_id = dec_id,
		profile = profile,
		pos_x = pos_x,
		pos_y = pos_y
	})
	_save_decorations()

func move_decoration(inst_id: int, pos_x: float, pos_y: float) -> void:
	for i in range(_decorations.size()):
		var d := _decorations[i] as Dictionary
		if int(d.get("id", -1)) == inst_id:
			d["pos_x"] = pos_x
			d["pos_y"] = pos_y
			_decorations[i] = d
			_save_decorations()
			return

func remove_decoration(inst_id: int) -> void:
	_decorations = _decorations.filter(func(d): return d.get("id",-1) != inst_id)
	_save_decorations()

func reset_moonpearls() -> void:
	_economy["moonpearls"] = 0
	_save_economy()

## coins removed — keep reset_moonpearls only

# ── Ingredients (Confectionery pantry) ───────────────────────────
# Ingredients are earned by completing focus sessions and consumed
# when crafting Sweets. They live in their own file so a corrupt
# economy.json can never silently wipe the player's pantry.

func add_ingredient(key: String, qty: int = 1) -> void:
	_ingredients[key] = int(_ingredients.get(key, 0)) + qty
	_save_ingredients()

func get_ingredient(key: String) -> int:
	return int(_ingredients.get(key, 0))

func get_all_ingredients() -> Dictionary:
	return _ingredients.duplicate()

# Backwards-compatible alias: some callers expect `get_ingredients()`
func get_ingredients() -> Dictionary:
	return get_all_ingredients()

func use_ingredient(key: String, qty: int = 1) -> bool:
	var current: int = int(_ingredients.get(key, 0))
	if current < qty: return false
	_ingredients[key] = current - qty
	_save_ingredients()
	return true

# ── Sweets (Confectionery jar) ────────────────────────────────────
# Sweets are the crafted output of the Confectionery. The "discovered"
# list is stored in the same file so recipe knowledge and inventory
# are always in sync — one atomic save, one atomic load.

func add_sweet(key: String, qty: int = 1) -> void:
	_sweets[key] = int(_sweets.get(key, 0)) + qty
	_save_sweets()

func get_all_sweets() -> Dictionary:
	# The "discovered" key stores an Array, not a count.
	# Exclude it so callers only see sweet_key -> quantity pairs.
	var result: Dictionary = {}
	for k: String in _sweets:
		if k != "discovered":
			result[k] = int(_sweets.get(k, 0))
	return result

func use_sweet(key: String) -> bool:
	var current: int = int(_sweets.get(key, 0))
	if current <= 0: return false
	_sweets[key] = current - 1
	_save_sweets()
	return true

func get_discovered_recipes() -> Array:
	return (_sweets.get("discovered", []) as Array).duplicate()

func discover_recipe(key: String) -> bool:
	# Returns true only on the very first discovery so callers can
	# trigger the "new recipe unlocked" celebration exactly once.
	var disc: Array = _sweets.get("discovered", []) as Array
	if key in disc: return false
	disc.append(key)
	_sweets["discovered"] = disc
	_save_sweets()
	return true

# ── Achievement System ─────────────────────────────────────────────────────────────────────────────────

func get_achievement_progress() -> Dictionary:
	return _achievements.duplicate(true)

func save_achievement_progress(progress: Dictionary) -> void:
	_achievements = progress.duplicate(true)
	_save_achievements()

func get_dice_inventory() -> Dictionary:
	return _dice_inventory.duplicate(true)

func save_dice_inventory(inventory: Dictionary) -> void:
	_dice_inventory = inventory.duplicate(true)
	_save_dice_inventory()

func get_upgrade_levels() -> Dictionary:
	return _upgrades.duplicate(true)

func save_upgrade_levels(upgrades: Dictionary) -> void:
	_upgrades = upgrades.duplicate(true)
	_save_upgrades()
