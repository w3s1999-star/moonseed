extends Control
class_name DiceTableArea

# ─────────────────────────────────────────────────────────────────
# DiceTableArea.gd  –  2D physics dice roller
# v0.603+: All dice persist (no history limit), die-die collision,
#          layout save/restore API for per-day persistence.
# ─────────────────────────────────────────────────────────────────

signal roll_finished(total: int, sides: int)
## Emitted when the user finishes dragging a die to a new position.
signal layout_changed

# Each state exists as a named handoff point so later animation polish can
# attach to a stable phase instead of threading conditions through physics code.
enum DiceAnimState {
	IDLE,
	SPAWNING,
	SHAKING,
	ROLLING,
	SLOWING,
	SLAMMING,
	RESULT,
	SCORING,
}

const DIE_STATE_NAMES := {
	DiceAnimState.IDLE: "IDLE",
	DiceAnimState.SPAWNING: "SPAWNING",
	DiceAnimState.SHAKING: "SHAKING",
	DiceAnimState.ROLLING: "ROLLING",
	DiceAnimState.SLOWING: "SLOWING",
	DiceAnimState.SLAMMING: "SLAMMING",
	DiceAnimState.RESULT: "RESULT",
	DiceAnimState.SCORING: "SCORING",
}

class DieEntry:
	extends RefCounted

	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var launch_vel: Vector2 = Vector2.ZERO
	var angle: float = 0.0
	var omega: float = 0.0
	var launch_omega: float = 0.0
	var result: int = 1
	var sides: int = 6
	var die_id: String = ""
	var group_id: int = -1
	var settled: bool = true
	var sleep_timer: float = 0.0
	var task_name: String = ""
	var task_id: int = -1
	var shuffle_seed: float = 0.0
	var state: int = DiceAnimState.IDLE
	var state_time: float = 0.0
	var visual_scale: float = 1.0
	var visual_alpha: float = 1.0
	var visual_offset: Vector2 = Vector2.ZERO
	var anticipation_tween: Tween = null

class RollGroup:
	extends RefCounted

	var total: int = 0
	var count: int = 0
	var settled: int = 0
	var sides: int = 6
	var task_name: String = ""

# ── Physics ───────────────────────────────────────────────────────
const LINEAR_DAMP   := 3.2
const ANGULAR_DAMP  := 4.5
const RESTITUTION   := 0.38
const SLEEP_SPEED   := 14.0
const SLEEP_OMEGA   := 0.06
const SLEEP_HOLD    := 0.28
const THROW_SPEED   := 360.0
const DIE_HALF      := 22.0

# Die-die collision restitution
const DIE_BOUNCE    := 0.25
const MAX_VEL       := 380.0   # velocity cap prevents runaway energy

const SHUFFLE_MIN_MS := 40
const SHUFFLE_MAX_MS := 600
const SLOWING_SPEED_FACTOR := 2.0
const SLOWING_OMEGA_FACTOR := 6.0

# ── Visuals ───────────────────────────────────────────────────────
const FELT_COLOR  := GameData.DICE_TABLE_FELT
const FELT_EDGE   := GameData.DICE_TABLE_EDGE
const FELT_INNER  := GameData.DICE_TABLE_INNER
const SHADOW_COL  := Color(0.0, 0.0, 0.0, 0.28)
const LABEL_IDLE  := Color("#3a2a5a")

# Dice background scene (tinted 1x12 animation)
const DICE_BG_SCENE := preload("res://scenes/dice/DiceBackground.tscn")

# LOOT VFX removed from DiceTableArea — keep asset scene in project if needed elsewhere

# These timings are exposed because anticipation feel is tuned visually and
# benefits from iteration without touching the state logic.
@export_range(0.01, 0.25, 0.01) var spawn_phase_time: float = 0.07
@export_range(0.01, 0.25, 0.01) var shake_phase_time: float = 0.06
@export_range(0.10, 1.00, 0.01) var spawn_start_scale: float = 0.52
@export_range(0.00, 16.00, 0.5) var shake_offset_px: float = 5.0
@export_range(0.90, 1.20, 0.01) var shake_peak_scale: float = 1.05

# ── State ─────────────────────────────────────────────────────────
# Each die keeps its own state so future polish can be added per-die without
# forcing the whole table through one monolithic roll branch.
var _dice:        Array[DieEntry] = []
var _is_rolling:  bool   = false
var _status_text: String = "tap a task's 🎲 to roll"
var _task_name:   String = ""
var _groups:      Dictionary = {}
var _sprite_cache: Dictionary = {}
var _custom_bg_color: Color = Color.TRANSPARENT  # set via set_bg_color()
var _bg_texture: Texture2D = null                 # set via set_bg_texture()

var _puddle_queue: Array = []
var _processing_puddles: bool = false
var _puddles: Array = [] # each: {pos: Vector2, life: float, dur: float, r0: float, r1: float, color: Color}

# ── Drag state ────────────────────────────────────────────────────
var _drag_idx:    int    = -1          # index into _dice, or -1
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_clack_snd: AudioStreamPlayer = null

# Holds a layout JSON that arrived before the Control was sized;
# applied on the first NOTIFICATION_RESIZED with a valid size.
var _pending_layout: String = ""

# ─────────────────────────────────────────────────────────────────
func set_bg_color(color: Color) -> void:
	_custom_bg_color = color
	queue_redraw()

func set_bg_texture(tex: Texture2D) -> void:
	_bg_texture = tex
	queue_redraw()

# Loads a texture from a res:// path, falling back to Image.load_from_file()
# for PNGs that haven't been imported by the editor yet.
func _load_table_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var img := Image.load_from_file(path)
	if img:
		return ImageTexture.create_from_image(img)
	return null

func _on_dice_table_bg_changed(path: String) -> void:
	_bg_texture = _load_table_texture(path)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _pending_layout.is_empty():
		if size.x >= 10 and size.y >= 10:
			var json := _pending_layout
			_pending_layout = ""
			restore_layout(json)

func _ready() -> void:
	set_process(true)
	custom_minimum_size = Vector2(0, 180)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect date change signal for calendar navigation
	get_node("/root/SignalBus").date_changed.connect(load_dice_layout_for_date)
	_preload_sprites()
	_setup_drag_audio()
	# Load background texture (default: dice_table_01.png)
	var tex_path: String = str(get_node("/root/Database").get_setting("dice_table_bg_tex", "res://assets/ui/table/dice_table_01.png"))
	_bg_texture = _load_table_texture(tex_path)
	get_node("/root/SignalBus").dice_table_bg_changed.connect(_on_dice_table_bg_changed)

	# Instance the dice background animation behind dice (if scene available)
	if ResourceLoader.exists("res://scenes/dice/DiceBackground.tscn"):
		var _dice_bg := DICE_BG_SCENE.instantiate()
		_dice_bg.name = "DiceBackground"
		add_child(_dice_bg)
		# center in this Control
		if _dice_bg is Node2D:
			_dice_bg.position = Vector2(size.x * 0.5, size.y * 0.5)
			_dice_bg.z_index = -5

	# (side-panel textures are drawn by the panel controls)
	# Load saved background color from settings
	var saved_bg: String = str(get_node("/root/Database").get_setting("dice_table_bg", ""))
	if not saved_bg.is_empty() and Color.from_string(saved_bg, Color.TRANSPARENT) != Color.TRANSPARENT:
		_custom_bg_color = Color(saved_bg)

func _setup_drag_audio() -> void:
	_drag_clack_snd = AudioStreamPlayer.new()
	add_child(_drag_clack_snd)
	var clack_paths := [
		"res://assets/audio/dice_sounds/dice_clack_01.wav",
		"res://assets/audio/dice_sounds/dice_clack_02.wav",
		"res://assets/audio/dice_sounds/dice_clack_03.wav",
		"res://assets/audio/dice_sounds/dice_clack_04.wav",
	]
	for path in clack_paths:
		if ResourceLoader.exists(path):
			_drag_clack_snd.stream = load(path)
			break

func _preload_sprites() -> void:
	# Use the skin-folder names that match the textures under assets/textures/dice
	_load_die_sprites(6, "d6_basic", 6)
	_load_die_sprites(8, "d8_basic", 8)
	_load_die_sprites(10, "d10_basic", 10)
	_load_die_sprites(12, "d12_basic", 12)
	_load_die_sprites(20, "d20_basic", 20)

func _resolve_dice_folder(folder: String) -> String:
	var base := "res://assets/dice"
	# Fast path for exact casing.
	if DirAccess.dir_exists_absolute(base.path_join(folder)):
		return folder
	# Case-insensitive lookup for Windows-authored assets (e.g. D8 vs d8).
	var dir := DirAccess.open(base)
	if dir == null:
		return folder
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if dir.current_is_dir() and entry_name.to_lower() == folder.to_lower():
			dir.list_dir_end()
			return entry_name
		entry_name = dir.get_next()
	dir.list_dir_end()
	return folder

func _load_die_sprites(sides: int, folder: String, count: int) -> void:
	var resolved_folder := _resolve_dice_folder(folder)
	for face_idx in range(count):
		var cache_key := "%d_%d" % [sides, face_idx]
		# Check user:// custom override first
		var user_path := "user://ante_up/dice/%s/face_%d.png" % [folder, face_idx]
		if FileAccess.file_exists(user_path):
			var img := Image.load_from_file(user_path)
			if img: _sprite_cache[cache_key] = ImageTexture.create_from_image(img); continue
		# Default res:// sprites (try both 0-indexed and 1-indexed filenames)
		var p0 := "res://assets/dice/%s/spr_dice_%s_%d.png" % [resolved_folder, folder, face_idx]
		var p1 := "res://assets/dice/%s/spr_dice_%s_%d.png" % [resolved_folder, folder, face_idx + 1]
		if ResourceLoader.exists(p0):
			_sprite_cache[cache_key] = load(p0)
		elif ResourceLoader.exists(p1):
			_sprite_cache[cache_key] = load(p1)
		else:
			# Try alternate textures directory and common naming patterns
			# e.g. res://assets/textures/dice/d8_basic/d8_basic_01.png
			var alt1 := "res://assets/textures/dice/%s/%s_%02d.png" % [resolved_folder, resolved_folder, face_idx + 1]
			var alt2 := "res://assets/textures/dice/%s/%s_%02d.png" % [resolved_folder, folder, face_idx + 1]
			var alt3 := "res://assets/textures/dice/%s/%s_%d.png" % [resolved_folder, folder, face_idx + 1]
			var alt4 := "res://assets/textures/dice/%s/spr_%s_%d.png" % [resolved_folder, folder, face_idx + 1]
			var alt5 := "res://assets/textures/dice/%s/%s_%02d.png" % [resolved_folder, resolved_folder.replace("_basic", "" ), face_idx + 1]
			if ResourceLoader.exists(alt1):
				_sprite_cache[cache_key] = load(alt1)
			elif ResourceLoader.exists(alt2):
				_sprite_cache[cache_key] = load(alt2)
			elif ResourceLoader.exists(alt3):
				_sprite_cache[cache_key] = load(alt3)
			elif ResourceLoader.exists(alt4):
				_sprite_cache[cache_key] = load(alt4)
			elif ResourceLoader.exists(alt5):
				_sprite_cache[cache_key] = load(alt5)

func _make_roll_group(task_name: String, sides: int, count: int) -> RollGroup:
	var group := RollGroup.new()
	group.task_name = task_name
	group.sides = sides
	group.count = count
	return group

func _make_die_entry(
	spawn_pos: Vector2,
	launch_velocity: Vector2,
	launch_omega: float,
	result: int,
	sides: int,
	group_id: int,
	task_name: String,
	task_id: int = -1) -> DieEntry:
	var die := DieEntry.new()
	die.pos = spawn_pos
	die.vel = Vector2.ZERO
	die.launch_vel = launch_velocity
	die.angle = randf_range(0.0, TAU)
	die.omega = 0.0
	die.launch_omega = launch_omega
	die.result = result
	die.sides = sides
	die.group_id = group_id
	die.settled = false
	die.sleep_timer = 0.0
	die.task_name = task_name
	die.task_id = task_id
	die.shuffle_seed = float(randi() % 1000)
	die.visual_scale = spawn_start_scale
	die.visual_alpha = 0.0
	die.visual_offset = Vector2.ZERO
	_transition_die_state(die, DiceAnimState.SPAWNING, "created")
	return die

func _state_name(state: int) -> String:
	return str(DIE_STATE_NAMES.get(state, "UNKNOWN"))

func _is_debug_state_logging_enabled() -> bool:
	return OS.is_debug_build() and get_node("/root/GameData").is_debug_mode()

func _log_die_state_transition(die: DieEntry, from_state: int, to_state: int, reason: String) -> void:
	if not _is_debug_state_logging_enabled():
		return
	var suffix := ""
	if reason != "":
		suffix = " (%s)" % reason
	print("[DiceTableArea] %s d%d #%d %s -> %s%s" % [
		die.task_name,
		die.sides,
		die.group_id,
		_state_name(from_state),
		_state_name(to_state),
		suffix,
	])

func _can_transition_die_state(die: DieEntry, next_state: int) -> bool:
	var current_state: int = die.state
	if current_state == next_state:
		return false
	if next_state == DiceAnimState.IDLE:
		return current_state in [DiceAnimState.SCORING, DiceAnimState.RESULT, DiceAnimState.IDLE]
	if next_state == DiceAnimState.SPAWNING:
		return current_state == DiceAnimState.IDLE
	if next_state == DiceAnimState.SHAKING:
		return current_state == DiceAnimState.SPAWNING
	if next_state == DiceAnimState.ROLLING:
		return current_state in [
			DiceAnimState.SHAKING,
			DiceAnimState.SLOWING,
			DiceAnimState.IDLE,
			DiceAnimState.RESULT,
		]
	if next_state == DiceAnimState.SLOWING:
		return current_state in [DiceAnimState.SHAKING, DiceAnimState.ROLLING]
	if next_state == DiceAnimState.SLAMMING:
		return current_state in [DiceAnimState.SLOWING, DiceAnimState.ROLLING, DiceAnimState.SHAKING]
	if next_state == DiceAnimState.RESULT:
		return current_state == DiceAnimState.SLAMMING
	if next_state == DiceAnimState.SCORING:
		return current_state == DiceAnimState.RESULT
	return false

func _transition_die_state(die: DieEntry, next_state: int, reason: String = "") -> bool:
	if not _can_transition_die_state(die, next_state):
		return false
	var previous_state: int = die.state
	die.state = next_state
	die.state_time = 0.0
	match next_state:
		DiceAnimState.IDLE:
			die.settled = true
		DiceAnimState.RESULT, DiceAnimState.SCORING, DiceAnimState.SLAMMING:
			die.settled = true
		_:
			die.settled = false
	_log_die_state_transition(die, previous_state, next_state, reason)
	return true

func _force_die_state(die: DieEntry, next_state: int, reason: String = "") -> void:
	if die.state == next_state:
		return
	var previous_state: int = die.state
	die.state = next_state
	die.state_time = 0.0
	match next_state:
		DiceAnimState.IDLE:
			die.settled = true
		DiceAnimState.RESULT, DiceAnimState.SCORING, DiceAnimState.SLAMMING:
			die.settled = true
		_:
			die.settled = false
	_log_die_state_transition(die, previous_state, next_state, reason)

func _is_die_in_anticipation_state(die: DieEntry) -> bool:
	return die.state in [
		DiceAnimState.SPAWNING,
		DiceAnimState.SHAKING,
	]

func _is_die_in_motion_state(die: DieEntry) -> bool:
	return die.state in [
		DiceAnimState.ROLLING,
		DiceAnimState.SLOWING,
	]

func _is_die_visually_active(die: DieEntry) -> bool:
	return _is_die_in_anticipation_state(die) or _is_die_in_motion_state(die)

func _is_die_shuffling_state(die: DieEntry) -> bool:
	return die.state in [
		DiceAnimState.SHAKING,
		DiceAnimState.ROLLING,
		DiceAnimState.SLOWING,
	]

func _anticipation_duration() -> float:
	return spawn_phase_time + shake_phase_time

func _clear_die_anticipation_tween(die: DieEntry) -> void:
	if die.anticipation_tween != null:
		die.anticipation_tween.kill()
		die.anticipation_tween = null

func _set_die_visual_scale(die: DieEntry, value: float) -> void:
	die.visual_scale = value
	queue_redraw()

func _set_die_visual_alpha(die: DieEntry, value: float) -> void:
	die.visual_alpha = value
	queue_redraw()

func _set_die_visual_offset(die: DieEntry, value: Vector2) -> void:
	die.visual_offset = value
	queue_redraw()

# Spawn exists so the die can visually arrive before physics takes over;
# that keeps anticipation extensible without leaking presentation concerns
# into the actual roll resolution.
func _start_die_spawn(die: DieEntry) -> void:
	_clear_die_anticipation_tween(die)
	_set_die_visual_scale(die, spawn_start_scale)
	_set_die_visual_alpha(die, 0.0)
	_set_die_visual_offset(die, Vector2.ZERO)
	var tw := create_tween()
	die.anticipation_tween = tw
	tw.set_parallel(true)
	tw.tween_method(func(v: float) -> void:
		_set_die_visual_scale(die, v),
		spawn_start_scale, 1.0, spawn_phase_time
	)
	tw.tween_method(func(v: float) -> void:
		_set_die_visual_alpha(die, v),
		0.0, 1.0, spawn_phase_time * 0.8
	)
	tw.finished.connect(func() -> void:
		die.anticipation_tween = null
		if die.state == DiceAnimState.SPAWNING:
			_start_die_shake(die)
	)

# Shake exists to telegraph the launch moment and make the throw feel earned;
# the actual roll begins only after this short pre-motion beat completes.
func _start_die_shake(die: DieEntry) -> void:
	if not _transition_die_state(die, DiceAnimState.SHAKING, "spawn complete"):
		return
	_clear_die_anticipation_tween(die)
	var amplitude: float = shake_offset_px * randf_range(0.85, 1.15)
	var base_dir := Vector2.RIGHT.rotated(randf() * TAU)
	var side_dir := base_dir.orthogonal() * randf_range(0.18, 0.35)
	var offset_a: Vector2 = base_dir * amplitude + side_dir * amplitude * 0.35
	var offset_b: Vector2 = -base_dir * amplitude * 0.9 + side_dir * amplitude * 0.2
	var offset_c: Vector2 = base_dir * amplitude * 0.45 - side_dir * amplitude * 0.25
	var seg_a: float = shake_phase_time * 0.34
	var seg_b: float = shake_phase_time * 0.33
	var seg_c: float = shake_phase_time * 0.33
	var tw := create_tween()
	die.anticipation_tween = tw
	tw.tween_method(func(v: Vector2) -> void:
		_set_die_visual_offset(die, v),
		Vector2.ZERO, offset_a, seg_a
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float) -> void:
		_set_die_visual_scale(die, v),
		1.0, shake_peak_scale, seg_a
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: Vector2) -> void:
		_set_die_visual_offset(die, v),
		offset_a, offset_b, seg_b
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_method(func(v: float) -> void:
		_set_die_visual_scale(die, v),
		shake_peak_scale, 0.98, seg_b
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: Vector2) -> void:
		_set_die_visual_offset(die, v),
		offset_b, offset_c, seg_c * 0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float) -> void:
		_set_die_visual_scale(die, v),
		0.98, 1.02, seg_c * 0.5
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: Vector2) -> void:
		_set_die_visual_offset(die, v),
		offset_c, Vector2.ZERO, seg_c * 0.5
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float) -> void:
		_set_die_visual_scale(die, v),
		1.02, 1.0, seg_c * 0.5
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		die.anticipation_tween = null
		if die.state == DiceAnimState.SHAKING:
			_begin_die_roll(die)
	)

func _begin_die_roll(die: DieEntry) -> void:
	if not _transition_die_state(die, DiceAnimState.ROLLING, "anticipation complete"):
		return
	_set_die_visual_scale(die, 1.0)
	_set_die_visual_alpha(die, 1.0)
	_set_die_visual_offset(die, Vector2.ZERO)
	die.sleep_timer = 0.0
	die.vel = die.launch_vel
	die.omega = die.launch_omega

func _advance_die_motion_state(die: DieEntry, speed: float) -> void:
	var slowing_speed: float = SLEEP_SPEED * SLOWING_SPEED_FACTOR
	var slowing_omega: float = SLEEP_OMEGA * SLOWING_OMEGA_FACTOR
	if die.state == DiceAnimState.ROLLING:
		if speed < slowing_speed and absf(die.omega) < slowing_omega:
			_transition_die_state(die, DiceAnimState.SLOWING, "energy dropping")
	elif die.state == DiceAnimState.SLOWING:
		if speed >= slowing_speed or absf(die.omega) >= slowing_omega:
			_transition_die_state(die, DiceAnimState.ROLLING, "collision wake")

# ── Public API ────────────────────────────────────────────────────

## Throw N dice for one task. Results stay pre-computed so this refactor only
## changes animation architecture, not gameplay authority.
## `results` is intentionally untyped so callers that build plain Array via
## .append() (or pass through .call()) don't hit a typed-array mismatch.
func throw_task_dice(task_name: String, sides: int,
	count: int, results: Array, task_id: int = -1) -> void:
	print("[DiceTableArea] throw_task_dice called: task=", task_name, " sides=", sides, " count=", count, " task_id=", task_id)
	_task_name   = task_name
	_is_rolling  = true
	_status_text = "ROLLING…"

	var group_id: int = randi()
	_groups[group_id] = _make_roll_group(task_name, sides, count)

	var bounds: Rect2 = _play_bounds()
	for i in range(count):
		var spawn: Dictionary = _random_edge_spawn(bounds, i, count)
		var dir: Vector2 = _inward_dir(spawn, bounds)
		var spin_dir: float = 1.0 if randf() > 0.5 else -1.0
		var die := _make_die_entry(
			spawn.pos,
			dir * THROW_SPEED * randf_range(0.82, 1.18),
			spin_dir * randf_range(12.0, 22.0),
			int(results[i]),
			sides,
			group_id,
			task_name,
			task_id
		)
		_dice.append(die)
		print("[DiceTableArea] appended die: gid=", group_id, " total_dice=", _dice.size())
		_start_die_spawn(die)
	queue_redraw()

	# Force-stop all dice in this group after 3.5 seconds to prevent infinite rolling
	var force_timer := get_tree().create_timer(3.5 + _anticipation_duration())
	force_timer.timeout.connect(func(): _force_settle_group(group_id))

func throw_die(task_name: String, sides: int, result: int) -> void:
	throw_task_dice(task_name, sides, 1, [result])

func start_roll(task_name: String, _sides: int) -> void:
	_task_name   = task_name
	_status_text = "ROLLING…"

func show_result(value: int, sides: int) -> void:
	throw_die(_task_name, sides, value)

func reset_table() -> void:
	_drag_idx = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	for die: DieEntry in _dice:
		_clear_die_anticipation_tween(die)
	_dice.clear()
	_groups.clear()
	_is_rolling  = false
	_status_text = "tap a task's 🎲 to roll"
	_task_name   = ""
	queue_redraw()


## PUDDLE QUEUE / PROCESSOR
func _enqueue_puddle(world_pos: Vector2, color: Color, final_radius: float = 0.0) -> void:
	if final_radius <= 0.0:
		final_radius = DIE_HALF
	_puddle_queue.append({"pos": world_pos, "color": color, "r1": final_radius})
	if not _processing_puddles:
		_process_puddle_queue()

func _process_puddle_queue() -> void:
	_processing_puddles = true
	while not _puddle_queue.is_empty():
		var item = _puddle_queue[0]
		_puddle_queue.remove_at(0)
		var local_pos: Vector2 = item.pos - global_position
		var final_r: float = float(item.r1)
		var p = {"pos": local_pos, "life": 0.0, "dur": 0.6, "r0": maxf(2.0, final_r * 0.25), "r1": final_r, "color": item.color}
		_puddles.append(p)
		queue_redraw()
		await get_tree().create_timer(0.5).timeout
	_processing_puddles = false
	

# ── Layout persistence API ────────────────────────────────────────

## Returns JSON string of all settled dice (for save-to-DB)
func get_layout() -> String:
	var entries: Array = []
	for d: DieEntry in _dice:
		if d.settled:
			var ent := {
				px=d.pos.x, py=d.pos.y,
				angle=d.angle,
				result=d.result,
				sides=d.sides,
				task=d.task_name,
			}
			if d.task_id != null and int(d.task_id) >= 0:
				ent["task_id"] = int(d.task_id)
			entries.append(ent)
	return JSON.stringify(entries)

## Auto-save dice layout when all dice settle
func _auto_save_dice_layout() -> void:
	# Get current layout and save to database for calendar persistence
	var layout_json = get_layout()
	if not layout_json.is_empty():
		# Save to database with current in-game date key and profile.
		# layout_json already includes each settled die's x/y positions, sides, angle, and result.
		var game_date_key: String = get_node("/root/GameData").get_date_string()
		get_node("/root/Database").save_dice_box_layout(game_date_key, get_node("/root/GameData").current_profile, layout_json)
		print("Auto-saved dice layout for game date: ", game_date_key, " profile: ", get_node("/root/GameData").current_profile)

## Load dice layout for specific date (for calendar navigation)
func load_dice_layout_for_date(date_dict: Dictionary) -> void:
	var date_key = "%04d-%02d-%02d" % [date_dict.year, date_dict.month, date_dict.day]
	var layout_json = get_node("/root/Database").get_dice_box_layout(date_key, get_node("/root/GameData").current_profile)
	if not layout_json.is_empty():
		restore_layout(layout_json)
		print("Loaded dice layout for date: ", date_key, " profile: ", get_node("/root/GameData").current_profile)
	else:
		print("No saved dice layout found for date: ", date_key)

## Restores dice from JSON layout string (from DB load).
## If the Control hasn't been laid out yet (size.x / size.y == 0),
## the JSON is stored and applied the moment the first valid resize fires.
## force_settled: if true, all dice are set to IDLE state immediately (for previous day loads)
func restore_layout(layout_json: String, force_settled: bool = false) -> void:
	if layout_json.is_empty():
		return
	# Guard against the layout being called before the parent has sized us;
	# _play_bounds() would return a degenerate rect and clamp all dice to (25,25).
	if size.x < 10 or size.y < 10:
		_pending_layout = layout_json
		return
	_pending_layout = ""
	var parsed = JSON.parse_string(layout_json)
	if not parsed is Array:
		return
	_dice.clear()
	_groups.clear()
	var bounds: Rect2 = _play_bounds()
	for entry in parsed:
		var px: float = entry.get("px", bounds.get_center().x)
		var py: float = entry.get("py", bounds.get_center().y)
		# Clamp to current bounds in case viewport resized
		px = clampf(px, bounds.position.x + DIE_HALF, bounds.end.x - DIE_HALF)
		py = clampf(py, bounds.position.y + DIE_HALF, bounds.end.y - DIE_HALF)
		var die := DieEntry.new()
		die.pos = Vector2(px, py)
		die.vel = Vector2.ZERO
		die.angle = float(entry.get("angle", 0.0))
		die.omega = 0.0
		die.result = int(entry.get("result", 1))
		die.sides = int(entry.get("sides", 6))
		die.group_id = -1
		die.sleep_timer = SLEEP_HOLD
		die.task_name = str(entry.get("task", ""))
		die.task_id = int(entry.get("task_id", -1))
		die.shuffle_seed = 0.0
		die.visual_scale = 1.0
		die.visual_alpha = 1.0
		die.visual_offset = Vector2.ZERO
		if force_settled:
			_force_die_state(die, DiceAnimState.IDLE, "restored from save (settled)")
		else:
			_force_die_state(die, DiceAnimState.IDLE, "restored from save")
		_dice.append(die)
	if not _dice.is_empty():
		_status_text = "Loaded — %d dice" % _dice.size()
	queue_redraw()

# ── Drag API ─────────────────────────────────────────────────────

## Returns the index of the topmost die whose centre is within
## DIE_HALF * 1.2 pixels of `local_pos`, or -1 if none.
func _find_die_at(local_pos: Vector2) -> int:
	for i in range(_dice.size() - 1, -1, -1):
		var die: DieEntry = _dice[i]
		if die.pos.distance_to(local_pos) <= DIE_HALF * 1.2:
			return i
	return -1

## Called when the user releases the mouse after a drag.
func _complete_drag() -> void:
	if _drag_idx < 0:
		return
	if _drag_idx >= _dice.size():
		_drag_idx = -1
		return
	var d: DieEntry = _dice[_drag_idx]
	_clear_die_anticipation_tween(d)
	d.vel    = Vector2.ZERO
	d.omega  = 0.0
	_force_die_state(d, DiceAnimState.IDLE, "drag finished")
	_set_die_visual_scale(d, 1.0)
	_set_die_visual_alpha(d, 1.0)
	_set_die_visual_offset(d, Vector2.ZERO)
	# Slam squish removed: ensure no scale tweens affect the table
	_drag_idx = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	if _drag_clack_snd and _drag_clack_snd.stream:
		_drag_clack_snd.pitch_scale = randf_range(0.88, 1.12)
		_drag_clack_snd.play()
	queue_redraw()
	emit_signal("layout_changed")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and _drag_idx >= 0:
			_complete_drag()
			accept_event()
			return
		if event.pressed and not _is_rolling:
			var local_pos := get_local_mouse_position()
			var idx := _find_die_at(local_pos)
			if idx >= 0:
				_drag_idx    = idx
				_drag_offset = _dice[idx].pos - local_pos
				var die: DieEntry = _dice[idx]
				_clear_die_anticipation_tween(die)
				die.vel = Vector2.ZERO
				die.omega = 0.0
				_force_die_state(die, DiceAnimState.IDLE, "drag start")
				_set_die_visual_scale(die, 1.0)
				_set_die_visual_alpha(die, 1.0)
				_set_die_visual_offset(die, Vector2.ZERO)
				mouse_default_cursor_shape = Control.CURSOR_DRAG
				accept_event()
	elif event is InputEventMouseMotion:
		if _drag_idx < 0:
			var local_pos := get_local_mouse_position()
			mouse_default_cursor_shape = \
				Control.CURSOR_POINTING_HAND if _find_die_at(local_pos) >= 0 \
				else Control.CURSOR_ARROW

# ── Physics ───────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# ── Drag update ──────────────────────────────────────────────
	if _drag_idx >= 0:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_complete_drag()
		else:
			var local_pos := get_local_mouse_position()
			var drag_bounds := _play_bounds()
			var new_pos   := local_pos + _drag_offset
			new_pos.x = clampf(new_pos.x, drag_bounds.position.x + DIE_HALF, drag_bounds.end.x - DIE_HALF)
			new_pos.y = clampf(new_pos.y, drag_bounds.position.y + DIE_HALF, drag_bounds.end.y - DIE_HALF)
			_dice[_drag_idx].pos = new_pos
			queue_redraw()
	if _dice.is_empty():
		return
	var bounds: Rect2 = _play_bounds()
	var any_animating := false
	for die: DieEntry in _dice:
		if _is_die_in_anticipation_state(die):
			die.state_time += delta
			any_animating = true
		if _is_die_in_motion_state(die):
			any_animating = true
			_step(die, delta, bounds)
	# Die-die collision (all pairs, including settled vs moving)
	_resolve_die_collisions()
	if any_animating:
		# Update puddles (life and cleanup)
		if not _puddles.is_empty():
			for i in range(_puddles.size() - 1, -1, -1):
				var p = _puddles[i]
				p.life += delta
				if p.life >= p.dur:
					_puddles.remove_at(i)

		
		queue_redraw()

func _step(die: DieEntry, delta: float, bounds: Rect2) -> void:
	die.state_time += delta
	die.vel   *= maxf(0.0, 1.0 - LINEAR_DAMP  * delta)
	die.omega *= maxf(0.0, 1.0 - ANGULAR_DAMP * delta)
	if die.vel.length() > MAX_VEL: die.vel = die.vel.normalized() * MAX_VEL
	die.pos   += die.vel   * delta
	die.angle += die.omega * delta

	if die.pos.x - DIE_HALF < bounds.position.x:
		die.pos.x = bounds.position.x + DIE_HALF
		die.vel.x = absf(die.vel.x) * RESTITUTION
		die.omega += randf_range(-1.5, 1.5)
	if die.pos.x + DIE_HALF > bounds.end.x:
		die.pos.x = bounds.end.x - DIE_HALF
		die.vel.x = -absf(die.vel.x) * RESTITUTION
		die.omega += randf_range(-1.5, 1.5)
	if die.pos.y - DIE_HALF < bounds.position.y:
		die.pos.y = bounds.position.y + DIE_HALF
		die.vel.y = absf(die.vel.y) * RESTITUTION
		die.omega += randf_range(-1.5, 1.5)
	if die.pos.y + DIE_HALF > bounds.end.y:
		die.pos.y = bounds.end.y - DIE_HALF
		die.vel.y = -absf(die.vel.y) * RESTITUTION
		die.omega += randf_range(-1.5, 1.5)

	var speed: float = die.vel.length()
	_advance_die_motion_state(die, speed)

	if speed < SLEEP_SPEED and absf(die.omega) < SLEEP_OMEGA:
		die.sleep_timer += delta
		if die.sleep_timer >= SLEEP_HOLD:
			_settle(die)
	else:
		die.sleep_timer = 0.0

func _resolve_die_collisions() -> void:
	var n := _dice.size()
	for i in range(n):
		for j in range(i + 1, n):
			var a: DieEntry = _dice[i]
			var b: DieEntry = _dice[j]
			# Both settled – no physics needed, just separation
			if a.settled and b.settled:
				continue
			var delta_v: Vector2 = b.pos - a.pos
			var dist: float = delta_v.length()
			var min_dist: float = DIE_HALF * 2.1
			if dist < min_dist and dist > 0.001:
				var normal: Vector2 = delta_v / dist
				var overlap: float  = (min_dist - dist) * 0.52
				# Push apart
				if not a.settled: a.pos -= normal * overlap
				if not b.settled: b.pos += normal * overlap
				# Velocity exchange
				var rel_vel: float = (a.vel - b.vel).dot(normal)
				if rel_vel > 0:
					var impulse: float = rel_vel * DIE_BOUNCE
					if not a.settled: a.vel -= normal * impulse
					if not b.settled: b.vel += normal * impulse
					if not a.settled: a.omega += randf_range(-0.8, 0.8)
					if not b.settled: b.omega += randf_range(-0.8, 0.8)
					# Wake a settled die if hit hard enough
					if a.settled and impulse > 20.0:
						a.sleep_timer = 0.0
						a.vel = -normal * impulse * 0.5
						_transition_die_state(a, DiceAnimState.ROLLING, "collision wake")
					if b.settled and impulse > 20.0:
						b.sleep_timer = 0.0
						b.vel = normal * impulse * 0.5
						_transition_die_state(b, DiceAnimState.ROLLING, "collision wake")

					# Play impact audio scaled by impulse (via AudioManager)
					if has_node("/root/AudioManager"):
						var strength: float = clamp(impulse / 48.0, 0.08, 1.0)
						get_node("/root/AudioManager").play_dice_impact(global_position + a.pos * 0.5 + b.pos * 0.5, strength)


func _settle(die: DieEntry) -> void:
	_transition_die_state(die, DiceAnimState.SLAMMING, "rest threshold reached")
	die.vel         = Vector2.ZERO
	die.omega       = 0.0
	die.angle       = 0.0
	queue_redraw()

	# Emit structured settle signal for the resolution pipeline
	var is_max: bool = die.result == die.sides
	SignalBus.die_settled.emit(
		"roll_%d" % die.group_id,
		die.die_id if die.die_id != "" else "d%d_%d" % [die.sides, die.task_id],
		die.task_id,
		die.result,
		die.sides,
		is_max
	)

	# Visual & audio feedback on settle: squash/stretch, screen shake, and result sound
	if has_node("/root/Juice"):
		var _shake_strength: float = min(8.0, lerpf(1.0, 6.0, float(die.result) / max(1.0, float(die.sides))))
		# Extra punch for max-face rolls (the "Balatro lucky hand" moment)
		if is_max:
			_shake_strength = min(14.0, _shake_strength * 2.2)
		# Respect reduce_motion accessibility flag if present
		var reduce_motion: bool = false
		if has_node("/root/GameData"):
			var _rm = get_node("/root/GameData").get("reduce_motion")
			if _rm != null:
				reduce_motion = bool(_rm)
		if not reduce_motion:
			# Screen shake effect use Juice if available
			if has_node("/root/Juice") and is_instance_valid(get_viewport()):
				get_node("/root/Juice").screen_shake(get_viewport(), _shake_strength, 0.22 if is_max else 0.18, 0.75 if is_max else 0.82)
			# Extra burst FX for max rolls
			if is_max and has_node("/root/FXBus"):
				get_node("/root/FXBus").burst_sparkles(global_position + die.pos, 12, GameData.ACCENT_GOLD)
	# Play result audio (via AudioManager)
	if has_node("/root/AudioManager"):
		var is_crit := die.result == die.sides
		get_node("/root/AudioManager").play_dice_result(global_position + die.pos, is_crit)
	_transition_die_state(die, DiceAnimState.RESULT, "face locked")

	# Check for cascade (max roll) - REMOVED: Cascades are no longer supported

	# Score popup at die position
	if has_node("/root/FXBus"):
		var score_col: Color = get_node("/root/GameData").DIE_COLORS.get(die.sides, get_node("/root/GameData").ACCENT_GOLD) as Color
		get_node("/root/FXBus").score_popup(global_position + die.pos, die.result, score_col)

		# Trigger dice background animation at settle
		var _bg := get_node_or_null("DiceBackground")
		if _bg:
			if _bg.has_method("play_at"):
				_bg.play_at(global_position + die.pos)
			elif _bg.has_node("AnimatedSprite2D"):
				var _anim := _bg.get_node("AnimatedSprite2D") as AnimatedSprite2D
				_bg.global_position = global_position + die.pos
				_anim.stop()
				_anim.frame = 0
				_anim.play()

	var gid: int = die.group_id
	if not _groups.has(gid):
		_transition_die_state(die, DiceAnimState.IDLE, "standalone settle")
		_set_die_visual_scale(die, 1.0)
		_set_die_visual_alpha(die, 1.0)
		_set_die_visual_offset(die, Vector2.ZERO)
		return
	_transition_die_state(die, DiceAnimState.SCORING, "settle feedback")
	var g: RollGroup = _groups[gid] as RollGroup
	g.settled += 1
	g.total   += die.result
	_transition_die_state(die, DiceAnimState.IDLE, "scoring complete")
	_set_die_visual_scale(die, 1.0)
	_set_die_visual_alpha(die, 1.0)
	_set_die_visual_offset(die, Vector2.ZERO)

	if g.settled == g.count:
		_is_rolling  = false
		_status_text = _describe(g.total, g.sides, g.count)
		queue_redraw()
		# Short reveal delay to let settle FX and sounds land
		var reduce_motion: bool = false
		if has_node("/root/GameData"):
			var _rm = get_node("/root/GameData").get("reduce_motion")
			if _rm != null:
				reduce_motion = bool(_rm)
		if not reduce_motion:
			await get_tree().create_timer(0.15).timeout
		emit_signal("roll_finished", g.total, g.sides)
		
		# Auto-save dice layout for calendar persistence
		_auto_save_dice_layout()
		
		_groups.erase(gid)

## Force all unsettled dice in a group to stop (prevents infinite rolling)
func _force_settle_group(group_id: int) -> void:
	if not _groups.has(group_id): return  # already done naturally
	for die: DieEntry in _dice:
		if die.group_id == group_id and _is_die_in_motion_state(die):
			die.vel   = Vector2.ZERO
			die.omega = 0.0
			_settle(die)

# ── Rendering ─────────────────────────────────────────────────────
func _draw() -> void:
	var bounds := _play_bounds()
	if _bg_texture != null:
		draw_texture_rect(_bg_texture, bounds, false)
	else:
		var bg_col: Color = _custom_bg_color if _custom_bg_color.a > 0.01 else FELT_COLOR
		draw_rect(bounds, bg_col)

	# side panels are drawn by the LeftPanel/RightPanel controls now
	draw_rect(bounds.grow(-3.0), FELT_INNER, false, 1.0)
	draw_rect(bounds, FELT_EDGE, false, 2.0)
	_draw_corner_marks(bounds)

	# Loot shine removed — no SubViewport drawing here

	# Draw puddles behind dice
	if not _puddles.is_empty():
		for p in _puddles:
			var t: float = clampf(p.life / p.dur, 0.0, 1.0)
			var r: float = lerpf(p.r0, p.r1, t)
			var c: Color = Color(p.color.r, p.color.g, p.color.b, p.color.a * (1.0 - t))
			draw_circle(p.pos, r, c)

	for die: DieEntry in _dice:
		# Motion-trail ghosting for fast dice (skippable via reduce_motion)
		var do_trails := true
		if has_node("/root/GameData"):
			var _gd_rm = get_node("/root/GameData").get("reduce_motion")
			if _gd_rm != null:
				do_trails = not bool(_gd_rm)
		var vlen := die.vel.length()
		if do_trails and vlen > 120.0:
			var dir := die.vel.normalized()
			for i in range(1, 4):
				# temporarily adjust visual offset/alpha for ghost frame
				var bak_off := die.visual_offset
				var bak_alpha := die.visual_alpha
				die.visual_offset = bak_off - dir * i * 6.0
				die.visual_alpha = bak_alpha * lerpf(0.18, 0.05, float(i) / 4.0)
				_draw_die(die, 1.0)
				# restore
				die.visual_offset = bak_off
				die.visual_alpha = bak_alpha
		# draw main die
		_draw_die(die, 1.0)

	var font  := ThemeDB.fallback_font
	var scol: Color = get_node("/root/GameData").ACCENT_GOLD if _is_rolling else LABEL_IDLE
	if not _dice.is_empty():
		for d: DieEntry in _dice:
			if d.settled:
				scol = _result_color(d.result, d.sides)
				break
	draw_string(font, Vector2(bounds.position.x + 6, bounds.end.y - 5),
		_status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, scol)
	if _task_name != "":
		draw_string(font, Vector2(bounds.position.x + 6, bounds.position.y + 13),
			_task_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(get_node("/root/GameData").FG_COLOR, 0.4))

func _draw_corner_marks(bounds: Rect2) -> void:
	var font  := ThemeDB.fallback_font
	var col   := Color(FELT_EDGE, 0.22)
	var suits := ["♠", "♥", "♦", "♣"]
	var pts   := [
		bounds.position + Vector2(4, 13),
		Vector2(bounds.end.x - 13, bounds.position.y + 13),
		bounds.end - Vector2(13, 4),
		Vector2(bounds.position.x + 4, bounds.end.y - 4),
	]
	for i in range(4):
		draw_string(font, pts[i], suits[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)

func _draw_die(die: DieEntry, alpha: float) -> void:
	var render_alpha: float = alpha * die.visual_alpha
	var render_pos: Vector2 = die.pos + die.visual_offset
	var render_scale := Vector2.ONE * die.visual_scale
	var display_val: int = _display_value_for_die(die)
	var sprite_key := "%d_%d" % [die.sides, display_val - 1]
	var has_sprite: bool = display_val > 0 and _sprite_cache.has(sprite_key)
	var show_wireframe: bool = get_node("/root/GameData").is_debug_mode() or not has_sprite

	var die_col: Color = get_node("/root/GameData").DIE_COLORS.get(die.sides, get_node("/root/GameData").FG_COLOR) as Color
	
	var body    := die_col.darkened(0.58); body.a    = render_alpha
	var border  := die_col.lightened(0.12); border.a  = render_alpha
	var shad    := SHADOW_COL;              shad.a   *= render_alpha

	if show_wireframe:
		draw_set_transform(render_pos + Vector2(4, 5), 0.0, render_scale)
		draw_colored_polygon(_die_poly(die.sides, DIE_HALF + 1.5, 0.0), shad)
		draw_set_transform(Vector2.ZERO)

		draw_set_transform(render_pos, die.angle, render_scale)
		draw_colored_polygon(_die_poly(die.sides, DIE_HALF, 0.0), body)
		var outline := _die_poly(die.sides, DIE_HALF, 0.0)
		draw_polyline(PackedVector2Array(Array(outline) + [outline[0]]), border, 1.5)
		_draw_face(die, render_alpha, display_val)
		draw_set_transform(Vector2.ZERO)
		return

	draw_set_transform(render_pos, die.angle, render_scale)
	_draw_face(die, render_alpha, display_val)
	draw_set_transform(Vector2.ZERO)

func _display_value_for_die(die: DieEntry) -> int:
	if die.settled:
		# For settled dice, always return the actual face value for texture purposes
		return die.result

	# Shuffling dice: show random face based on time and shuffle seed
	var t_ms: float        = Time.get_ticks_msec()
	var sleep_t: float     = clampf(die.sleep_timer / SLEEP_HOLD, 0.0, 1.0)
	var interval_ms: float = lerpf(SHUFFLE_MIN_MS, SHUFFLE_MAX_MS, sleep_t * sleep_t)
	var frame: int         = int(t_ms / interval_ms)
	var h: float           = fmod(die.shuffle_seed * 137.508 + frame * 31.41, float(die.sides))
	var display_val: int   = int(h) + 1
	return display_val

func _get_display_text_for_die(die: DieEntry) -> String:
	# Get the text to display on the die face
	if die.settled:
		# For settled dice, always show the actual face value
		return str(die.result)
	
	# For shuffling dice, return empty string (texture will show the face)
	return ""

func _draw_face(die: DieEntry, alpha: float, display_val: int = -1) -> void:
	if display_val < 0:
		display_val = _display_value_for_die(die)

	if display_val <= 0:
		return

	var tcol := Color(1.0, 1.0, 1.0, alpha * (0.92 if die.settled else 0.7))

	var sprite_key := "%d_%d" % [die.sides, display_val - 1]
	if _sprite_cache.has(sprite_key):
		var tex: Texture2D = _sprite_cache[sprite_key]
		var tex_size: Vector2 = tex.get_size()
		var width: float = float(tex_size.x)
		var height: float = float(tex_size.y)
		var max_dim: float = maxf(width, height)
		if max_dim < 1.0:
			max_dim = 1.0
		var target_max: float = float(DIE_HALF) * 3.2
		# Expand d8 dice art slightly so it can extend beyond wireframe edges.
		if die.sides == 8:
			target_max *= 1.2
		var draw_scale: float = target_max / max_dim
		var draw_size: Vector2 = tex_size * draw_scale
		var draw_rect_obj: Rect2 = Rect2(Vector2(-draw_size.x * 0.5, -draw_size.y * 0.5), draw_size)
		draw_texture_rect(tex, draw_rect_obj, false, Color(1, 1, 1, alpha))
		
		return

	# Always draw a fallback face when an art file is missing, so die type
	# changes remain visible even with incomplete sprite packs.
	if die.sides == 6:
		_draw_pips(display_val, alpha)
	else:
		var font := ThemeDB.fallback_font
		var txt  := _get_display_text_for_die(die)
		if txt.is_empty():
			txt = str(display_val)  # Fallback to face value
		var fs   := 18 if int(txt) < 10 else 14
		var tw   := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(-tw * 0.5, float(fs) * 0.38),
			txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)

func _draw_pips(face: int, alpha: float) -> void:
	var pip_col := Color(1.0, 1.0, 1.0, alpha * 0.9)
	var r       := DIE_HALF * 0.12
	var o       := DIE_HALF * 0.52
	var pips    := PackedVector2Array()
	match face:
		1: pips = PackedVector2Array([Vector2(0, 0)])
		2: pips = PackedVector2Array([Vector2(-o,-o), Vector2(o,o)])
		3: pips = PackedVector2Array([Vector2(-o,-o), Vector2(0,0), Vector2(o,o)])
		4: pips = PackedVector2Array([Vector2(-o,-o),Vector2(o,-o),Vector2(-o,o),Vector2(o,o)])
		5: pips = PackedVector2Array([Vector2(-o,-o),Vector2(o,-o),Vector2(0,0),Vector2(-o,o),Vector2(o,o)])
		6: pips = PackedVector2Array([Vector2(-o,-o),Vector2(o,-o),Vector2(-o,0),Vector2(o,0),Vector2(-o,o),Vector2(o,o)])
		_: return
	for p in pips:
		draw_circle(p, r, pip_col)

# ── Shapes ────────────────────────────────────────────────────────
func _die_poly(sides: int, half: float, rot: float) -> PackedVector2Array:
	match sides:
		4:  return _ngon(3, half * 1.08, PI * 0.5 + rot)
		6:  return _chamfered_square(half, rot)
		8:  return _ngon(8, half, rot)
		10: return _ngon(10, half, rot)
		12: return _ngon(12, half * 0.95, rot)
		20: return _ngon(6, half, rot)
		_:  return _ngon(8, half, rot)

func _ngon(n: int, half: float, offset: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := offset + i * TAU / float(n)
		pts.append(Vector2(cos(a), sin(a)) * half)
	return pts

func _chamfered_square(half: float, offset: float = 0.0) -> PackedVector2Array:
	var c   := half * 0.28
	var pts := PackedVector2Array()
	for corner in range(4):
		var ca := PI * 0.25 + corner * PI * 0.5 + offset
		var pa := ca - PI * 0.25
		var pb := ca + PI * 0.25
		pts.append(Vector2(cos(pa), sin(pa)) * (half / cos(PI * 0.25) - c))
		pts.append(Vector2(cos(pb), sin(pb)) * (half / cos(PI * 0.25) - c))
	return pts

func _random_edge_spawn(bounds: Rect2, idx: int, _total: int) -> Dictionary:
	var edge: int = (randi() + idx) % 4
	var cx := bounds.get_center().x
	var cy := bounds.get_center().y
	var spread := bounds.size.x * 0.3
	var pos: Vector2
	match edge:
		0: pos = Vector2(cx + randf_range(-spread, spread), bounds.position.y + DIE_HALF + 2)
		1: pos = Vector2(bounds.end.x - DIE_HALF - 2, cy + randf_range(-spread * 0.6, spread * 0.6))
		2: pos = Vector2(cx + randf_range(-spread, spread), bounds.end.y - DIE_HALF - 2)
		_: pos = Vector2(bounds.position.x + DIE_HALF + 2, cy + randf_range(-spread * 0.6, spread * 0.6))
	return {pos = pos, edge = edge}

func _inward_dir(spawn_data: Dictionary, bounds: Rect2) -> Vector2:
	var center: Vector2    = bounds.get_center()
	var spawn_pos: Vector2 = spawn_data.pos
	var toward: Vector2    = (center - spawn_pos).normalized()
	var perp := Vector2(-toward.y, toward.x)
	return (toward + perp * randf_range(-0.35, 0.35)).normalized()

func _play_bounds() -> Rect2:
	return Rect2(Vector2(3, 3), size - Vector2(6, 6))

func _describe(total: int, sides: int, count: int) -> String:
	var max_val := sides * count
	if total == max_val:  return "⭐ PERFECT! — %d" % total
	if total == count:    return "💀 ALL ONES! — %d" % total
	if total >= int(max_val * 0.75): return "Great roll — %d" % total
	if total <= int(max_val * 0.25): return "Low roll — %d"   % total
	return "Solid roll — %d" % total

func _result_color(value: int, sides: int) -> Color:
	if value == sides: return get_node("/root/GameData").ACCENT_GOLD
	if value == 1:     return get_node("/root/GameData").ACCENT_RED
	return get_node("/root/GameData").FG_COLOR

func refresh_sprites() -> void:
	_sprite_cache.clear()
	_preload_sprites()
	queue_redraw()

## Set background by cosmetic key (nebula, ember, ocean, void, aurora, gold, classic)
func set_bg_key(key: String) -> void:
	var shader_map := {
		"nebula":  "res://shaders/bg_nebula.gdshader",
		"ember":   "res://shaders/bg_ember.gdshader",
		"ocean":   "res://shaders/bg_ocean.gdshader",
		"void":    "res://shaders/bg_void.gdshader",
		"aurora":  "res://shaders/bg_aurora.gdshader",
		"gold":    "res://shaders/bg_gold.gdshader",
	}
	if key in shader_map:
		var shader: Shader = load(shader_map[key]) as Shader
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			material = mat
	else:
		material = null
	queue_redraw()
