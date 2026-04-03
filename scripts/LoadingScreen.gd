extends CanvasLayer

# ─────────────────────────────────────────────────────────────────
# LoadingScreen.gd  —  Simple Moonseed Loading Screen
# Moon center, moondrops drift inward, loading bar, fade transition
# ─────────────────────────────────────────────────────────────────

# ── Configuration ─────────────────────────────────────────────────
@export var moondrop_count: int = 10
@export var moondrop_speed: float = 0.8
@export var moon_pulse_speed: float = 1.5
@export var fade_duration: float = 0.6
@export var post_load_hold: float = 1.0
@export var loading_messages: Array[String] = [
	"calling the moon…",
	"gathering moondrops…",
	"setting the table…",
	"almost ready…",
]

# Colors
const BG_COLOR := Color(0.06, 0.02, 0.16, 1.0)  # Dark purple
const MOON_COLOR := Color(0.85, 0.92, 1.0, 0.9)  # Pale silver-blue
const MOON_GLOW_COLOR := Color(0.4, 0.6, 1.0, 0.3)  # Soft blue glow
const DROPLET_COLOR := Color(0.3, 0.75, 0.95, 0.8)  # Teal
const DROPLET_GLOW_COLOR := Color(0.5, 0.85, 1.0, 0.3)  # Soft teal glow

# ── State ─────────────────────────────────────────────────────────
var _load_percent: float = 0.0
var _is_loaded: bool = false
var _hold_timer: float = 0.0
var _droplets: Array[Node2D] = []
var _target_scene_path: String = ""
var _viewport_size: Vector2 = Vector2(1920, 1080)
var _async_loader: Node = null

# ── Node References ───────────────────────────────────────────────
@onready var _background: ColorRect = $Background
@onready var _moon_center: Node2D = $MoonCenter
@onready var _moon_circle: Control = $MoonCenter/MoonCircle
@onready var _moon_glow: ColorRect = $MoonCenter/MoonGlow
@onready var _moondrop_layer: Node2D = $MoondropLayer
@onready var _loading_bar: ProgressBar = $LoadingBar
@onready var _loading_label: Label = $LoadingLabel
@onready var _fade_overlay: ColorRect = $FadeOverlay

signal main_game_ready

# ── Initialization ────────────────────────────────────────────────
func _ready() -> void:
	# Cache viewport size
	var vp := get_viewport()
	if vp:
		_viewport_size = vp.get_visible_rect().size
	
	# Setup UI styling
	_setup_background()
	_setup_moon()
	_setup_loading_bar()
	_setup_loading_label()
	_setup_fade_overlay()
	
	# Start animations
	_start_moon_pulse()
	_spawn_initial_droplets()

	# Start background async preloads (non-blocking)
	var loader_scr := load("res://autoloads/AsyncLoader.gd")
	if loader_scr:
		var loader = loader_scr.new()
		add_child(loader)
		_async_loader = loader
		# Preload a prioritized set of heavy scenes/scripts/textures
		var preload_paths := [
			"res://assets/textures/Moondrop_spritesheet.png",
			"res://scenes/PlayTab.tscn",
			"res://scripts/garden/GardenTab.gd",
			"res://scenes/ConfectioneryTab.tscn",
			"res://scenes/BazaarTab.tscn",
			"res://scripts/CalendarTab.gd",
			"res://scenes/SatchelTab.tscn",
			"res://scenes/ui/StudioRoom.tscn",
			"res://scripts/settings/SettingsTab.gd",
		]
		_async_loader.preload_paths(preload_paths)
	
	# Begin fade in
	if is_instance_valid(_fade_overlay):
		_fade_overlay.modulate.a = 1.0
		var fade_in := create_tween()
		fade_in.tween_property(_fade_overlay, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE)
	
	# If no scene is being loaded, auto-transition after a brief splash hold
	if _target_scene_path == "":
		await get_tree().create_timer(post_load_hold).timeout
		_start_transition()

# ── Setup Helpers ─────────────────────────────────────────────────
func _setup_background() -> void:
	if not is_instance_valid(_background):
		return
	_background.color = BG_COLOR

func _setup_moon() -> void:
	if not is_instance_valid(_moon_circle):
		return
	
	# Create moon circle using StyleBox
	var moon_sb := StyleBoxFlat.new()
	moon_sb.bg_color = MOON_COLOR
	moon_sb.set_corner_radius_all(60)  # Make it circular
	_moon_circle.add_theme_stylebox_override("panel", moon_sb)
	
	# MoonGlow color is set directly in the scene file

func _setup_loading_bar() -> void:
	if not is_instance_valid(_loading_bar):
		return
	
	# Style the loading bar
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.1, 0.05, 0.25, 0.6)
	bg_sb.set_corner_radius_all(4)
	_loading_bar.add_theme_stylebox_override("background", bg_sb)
	
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = DROPLET_COLOR
	fill_sb.set_corner_radius_all(4)
	_loading_bar.add_theme_stylebox_override("fill", fill_sb)
	
	# Hide percentage text
	_loading_bar.show_percentage = false

func _setup_loading_label() -> void:
	if not is_instance_valid(_loading_label):
		return
	
	_loading_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	_loading_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.8))
	_update_loading_message(0.0)

func _setup_fade_overlay() -> void:
	if not is_instance_valid(_fade_overlay):
		return
	
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0)

# ── Animations ────────────────────────────────────────────────────
func _start_moon_pulse() -> void:
	if not is_instance_valid(_moon_circle):
		return
	
	var pulse_tw := create_tween()
	pulse_tw.set_loops()
	pulse_tw.tween_property(_moon_circle, "scale", Vector2(1.05, 1.05), moon_pulse_speed * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tw.tween_property(_moon_circle, "scale", Vector2(1.0, 1.0), moon_pulse_speed * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ── Moondrop System ───────────────────────────────────────────────
func _spawn_initial_droplets() -> void:
	for i in range(moondrop_count):
		_spawn_moondrop()

func _spawn_moondrop() -> void:
	var drop := _create_moondrop()
	_moondrop_layer.add_child(drop)
	_droplets.append(drop)

func _create_moondrop() -> Node2D:
	var drop := Node2D.new()
	
	# Random spawn position around screen edges
	var spawn_pos := _get_random_edge_position()
	drop.position = spawn_pos
	
	# Glow circle (ColorRect — color set directly, no stylebox needed)
	var glow := ColorRect.new()
	var glow_size := randf_range(12.0, 18.0)
	glow.size = Vector2(glow_size, glow_size)
	glow.position = -glow.size * 0.5
	glow.color = DROPLET_GLOW_COLOR
	drop.add_child(glow)
	
	# Core sprite
	var core := TextureRect.new()
	var core_size := randf_range(8.0, 12.0)
	core.custom_minimum_size = Vector2(core_size, core_size)
	core.size = core.custom_minimum_size
	core.position = -core.size * 0.5
	core.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	core.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	# Try to use existing moondrop spritesheet
	var md_path := "res://assets/textures/Moondrop_spritesheet.png"
	var tex: Texture2D = null
	if _async_loader != null and _async_loader.has_method("is_loaded") and _async_loader.is_loaded(md_path):
		tex = _async_loader.get_cached(md_path) as Texture2D
	elif ResourceLoader.exists(md_path) and _async_loader == null:
		# Fallback synchronous load if AsyncLoader unavailable
		tex = load(md_path) as Texture2D
	if tex:
		core.texture = tex
	
	drop.add_child(core)
	
	# Animate drift toward center
	var center := _viewport_size * 0.5
	var duration := randf_range(3.0, 5.0) / moondrop_speed
	var delay := randf_range(0.0, 2.0)
	
	# Use WeakRef to safely reference drop in lambda
	var drop_ref = weakref(drop)
	var drift_tw := create_tween()
	drift_tw.tween_interval(delay)
	drift_tw.tween_property(drop, "position", center, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift_tw.tween_callback(func():
		# Safely remove when reaches center
		var drop_variant: Variant = drop_ref.get_ref()
		if drop_variant != null:
			var drop_node: Node2D = drop_variant as Node2D
			if is_instance_valid(drop_node):
				var idx := _droplets.find(drop_node)
				if idx >= 0:
					_droplets.remove_at(idx)
				drop_node.queue_free()
		# Spawn replacement
		call_deferred("_spawn_moondrop")
	)
	
	return drop

func _get_random_edge_position() -> Vector2:
	var edge := randi() % 4
	var pos := Vector2.ZERO
	
	match edge:
		0:  # Left
			pos = Vector2(-50.0, randf_range(100.0, _viewport_size.y - 100.0))
		1:  # Right
			pos = Vector2(_viewport_size.x + 50.0, randf_range(100.0, _viewport_size.y - 100.0))
		2:  # Top
			pos = Vector2(randf_range(200.0, _viewport_size.x - 200.0), -50.0)
		3:  # Bottom
			pos = Vector2(randf_range(200.0, _viewport_size.x - 200.0), _viewport_size.y + 50.0)
	
	return pos

# ── Loading Progress ──────────────────────────────────────────────
func set_load_progress(percent: float) -> void:
	_load_percent = clampf(percent, 0.0, 1.0)
	
	# Update loading bar
	if is_instance_valid(_loading_bar):
		_loading_bar.value = _load_percent * 100.0
	
	# Update message based on progress band
	_update_loading_message(_load_percent)

func _update_loading_message(percent: float) -> void:
	if not is_instance_valid(_loading_label):
		return
	
	var band := int(percent * loading_messages.size())
	band = mini(band, loading_messages.size() - 1)
	
	if band < loading_messages.size():
		_loading_label.text = loading_messages[band]

# ── Loading Flow ──────────────────────────────────────────────────
func start_loading(scene_path: String) -> void:
	_target_scene_path = scene_path
	
	# Start threaded load request
	ResourceLoader.load_threaded_request(_target_scene_path)

func _process(delta: float) -> void:
	if _target_scene_path == "":
		return
	
	# Poll loading progress
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_target_scene_path, progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			if not _is_loaded:
				_is_loaded = true
				_load_percent = 1.0
				set_load_progress(1.0)
				SignalBus.load_progress_updated.emit(1.0)
				# Start post-load hold
				_hold_timer = post_load_hold
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress.size() > 0:
				set_load_progress(progress[0])
				SignalBus.load_progress_updated.emit(progress[0])
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Loading failed for: " + _target_scene_path)
	
	# Handle post-load hold
	if _is_loaded and _hold_timer > 0.0:
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			_start_transition()

func _start_transition() -> void:
	# Clear droplets
	for drop in _droplets:
		if is_instance_valid(drop):
			drop.queue_free()
	_droplets.clear()
	
	# Fade out
	var fade_out := create_tween()
	fade_out.tween_property(_fade_overlay, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE)
	await fade_out.finished
	
	# Signal ready
	emit_signal("main_game_ready")

# ── Public API ────────────────────────────────────────────────────
func get_loaded_scene() -> PackedScene:
	if _is_loaded and _target_scene_path != "":
		return ResourceLoader.load_threaded_get(_target_scene_path)
	return null
