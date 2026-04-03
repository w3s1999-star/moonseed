extends Control

# GardenTab.gd  –  Isometric 3D garden  v0.64 + theme support

const GARDEN_W      := 18.0
const GARDEN_H      := 14.0
const GRASS_COUNT   := 4800
const BLADE_W       := 0.5
const BLADE_H       := 1
const GRASS_CLEAR_R := 0.9  # smaller gap around plants, grass sits nearer
const CAM_SIZE  := 10.0
const CAM_POS   := Vector3(0.0, 12.0, 9.0)
const CAM_ROT_X := -54.0
const METABALL_SPLASH_SHADER_PATH := "res://shaders/procedural_metaball_splash.gdshader"
const STAGE_MAX := 2
const MAX_PLANTS  := 12
const WATER_SPLASH_DURATION := 0.85
const WATER_SPLASH_MESH_SIZE := 3.4
const GROWTH_STAGES: Array[String] = ["🌱", "🌿", "🌻"]
const STAGE_NAMES:   Array[String] = ["Seedling", "Growing", "Bloomed"]

const SIDE_PANEL_SCRIPT := preload("res://scripts/ui/side_panel_bg.gd")


# ── Contracts side panel (left of garden field) ──────────────────
var _contracts_panel:       PanelContainer
var _contracts_scroll:      VBoxContainer
var _section_boss_items:    VBoxContainer
var _section_mini_items:    VBoxContainer
var _section_reminder_items:VBoxContainer
var _section_boss_coll:     bool = false
var _section_mini_coll:     bool = false
var _section_reminder_coll: bool = false
var _badge_boss:            Label
var _badge_mini:            Label
var _badge_reminder:        Label
var _cp_panel_count:        Label

var _svc:        SubViewportContainer
var _viewport:   SubViewport
var _camera:     Camera3D
var _plant_root: Node3D
var _grass_node: MultiMeshInstance3D
var _grass_shadow_node: MultiMeshInstance3D

# Catalog UI mode
var _catalog_mode: String = "plants"
var _cat_label: Label
var _cat_left_btn: Button
var _cat_right_btn: Button

var _selected_id:     String  = ""
var _drag_mode:       bool    = false
var _mouse_world_pos: Vector2 = Vector2.ZERO
var _status_lbl:      Label
var _effects_label:   Label
var _seed_info_label: Label
var _catalog_list:    VBoxContainer
var _debug_panel:     PopupPanel

# Drag and drop system
var _is_dragging: bool = false
var _drag_plant_id: String = ""
var _drag_ghost_node: Node3D = null
var _drag_ghost: Control = null
var _hovered_slot: Node = null
var _sky_layer: CanvasLayer
var _sky_view:  Control
var _sky_open:  bool = false
var _plant_nodes: Dictionary = {}
var _snd_plant: AudioStreamPlayer
var _snd_water: AudioStreamPlayer

const PAN_SPEED := 0.6  # camera pan speed in world units


# Water meter
var _water_lbl:     Label
var _water_bar:     ProgressBar



# Day/night cycle (gradient sky)
var _sky_rect:       TextureRect        # gradient overlay
var _sky_gradient:   Gradient           # two-stop gradient (top → bottom)
var _sky_texture:    GradientTexture2D  # drives _sky_rect
var _sky_top_col:    Color = Color(0,0,0,0)
var _sky_bot_col:    Color = Color(0,0,0,0)
var _sky_tween:      Tween
var _day_night_timer: Timer

# God rays (sun during day, moon during night)
var _sun_rays_rect:  TextureRect
var _moon_rays_rect: TextureRect
var _rays_tween:     Tween

# Fireflies (night only) and bug paths (day only, debug red dots)
var _firefly_layer:  Control
var _fireflies:      Array = []
var _firefly_timer:  Timer
var _bug_layer:      Control
var _bug_nodes:      Array = []
var _bug_timer:      Timer
const MAX_FIREFLIES := 18
const MAX_BUGS      := 5
var _current_ambience_mode: String = ""
const HOVER_TILT_SCRIPT := preload("res://scripts/HoverCardTilt.gd")

func _ready() -> void:
	GameData.state_changed.connect(_refresh)
	if has_node("/root/SignalBus"):
		SignalBus.theme_changed.connect(_on_theme_changed_garden)
	GameData.debug_mode_changed.connect(_on_debug_mode_changed_garden)
	GameData.contract_data_changed.connect(_refresh_contracts_panel)
	SignalBus.garden_plant_watered.connect(_on_garden_plant_watered)
	_setup_audio()
	_build_ui()
	_build_3d_scene()
	call_deferred("_refresh")
	call_deferred("_setup_feedback")
	call_deferred("_refresh_contracts_panel")
	set_process(false)
	_start_day_night_timer()
	call_deferred("_migrate_garden_coordinates")


func _on_theme_changed_garden() -> void:
	if is_instance_valid(_status_lbl):
		_status_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
	if is_instance_valid(_effects_label):
		_effects_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	_build_catalog()
	_refresh_debug_visibility()

func _on_debug_mode_changed_garden(on: bool) -> void:
	if not on and is_instance_valid(_debug_panel):
		_debug_panel.hide()

func _process(_delta: float) -> void:
	var hit_v: Variant = _unproject_to_ground(_viewport.get_mouse_position(), true)
	if hit_v == null:
		return
	var hit: Vector3 = hit_v as Vector3
	_mouse_world_pos.x = clampf(hit.x / (GARDEN_W * 0.5), -1.0, 1.0)
	_mouse_world_pos.y = clampf(hit.z / (GARDEN_H * 0.5), -1.0, 1.0)
	_update_grass_mouse()

func _update_grass_mouse() -> void:
	var world_x: float = _mouse_world_pos.x * GARDEN_W * 0.5
	var world_z: float = _mouse_world_pos.y * GARDEN_H * 0.5
	for node in [_grass_node, _grass_shadow_node]:
		if is_instance_valid(node) and node.material_override is ShaderMaterial:
			var mat := node.material_override as ShaderMaterial
			mat.set_shader_parameter("mouse_world_xz", Vector2(world_x, world_z))
			mat.set_shader_parameter("mouse_brush_radius", 3.0)
			mat.set_shader_parameter("mouse_influence", _mouse_world_pos * 1.2)

# populate shader with current plant obstacle positions
func _update_grass_obstacles() -> void:
	var pts: Array = []
	
	# Add all plant positions (convert normalized 0-1 coordinates to world space)
	for g: Dictionary in Database.get_garden(GameData.current_profile):
		# Stored coordinates are normalized (0..1) — convert back to world-space
		var nx: float = float(g.get("pos_x",0.5))
		var nz: float = float(g.get("pos_z",0.5))
		var wx: float = lerp(-GARDEN_W*0.5, GARDEN_W*0.5, nx)
		var wz: float = lerp(-GARDEN_H*0.5, GARDEN_H*0.5, nz)
		pts.append(Vector2(wx, wz))
	for node in [_grass_node, _grass_shadow_node]:
		if is_instance_valid(node) and node.material_override is ShaderMaterial:
			var mat := node.material_override as ShaderMaterial
			mat.set_shader_parameter("obstacle_count", pts.size())
			var arr: Array = []
			for i in range(32):
				arr.append(pts[i] if i < pts.size() else Vector2.ZERO)
			mat.set_shader_parameter("obstacles", arr)

func _setup_feedback() -> void:
	if has_node("/root/ButtonFeedback"):
		get_node("/root/ButtonFeedback").setup_recursive(self)

func _attach_hover_tilt(ctrl: Control, tilt_deg: float = 5.6, scale_mul: float = 1.02) -> void:
	if ctrl == null:
		return
	ctrl.set_script(HOVER_TILT_SCRIPT)
	ctrl.set("max_tilt_degrees", tilt_deg)
	ctrl.set("hover_scale", scale_mul)

func _setup_audio() -> void:
	_snd_plant = AudioStreamPlayer.new()
	_snd_water = AudioStreamPlayer.new()
	add_child(_snd_plant); add_child(_snd_water)
	var pp := "res://assets/audio/garden/planting_plant.wav"
	var pw := "res://assets/audio/garden/plant_water.wav"
	if ResourceLoader.exists(pp): _snd_plant.stream = load(pp)
	if ResourceLoader.exists(pw): _snd_water.stream = load(pw)

func _play_plant_sound() -> void:
	if _snd_plant.stream: _snd_plant.play()
func _play_water_sound() -> void:
	if _snd_water.stream: _snd_water.play()

func _on_garden_plant_watered(plant_id: String, _new_stage: int) -> void:
	call_deferred("_play_water_splash_for_plant", plant_id)

func _play_water_splash_for_plant(plant_id: String) -> void:
	var plant_entry := _plant_nodes.get(plant_id, {}) as Dictionary
	if plant_entry.is_empty():
		return
	var root := plant_entry.get("root", null) as Node3D
	if not is_instance_valid(root):
		return
	var splash_material := _make_metaball_splash_material("water")
	if splash_material == null:
		return
	var old_fx := root.get_node_or_null("WaterSplashFX")
	if is_instance_valid(old_fx):
		old_fx.queue_free()
	var splash := MeshInstance3D.new()
	splash.name = "WaterSplashFX"
	var quad := QuadMesh.new()
	quad.size = Vector2(WATER_SPLASH_MESH_SIZE, WATER_SPLASH_MESH_SIZE)
	splash.mesh = quad
	splash.material_override = splash_material
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	splash.position = Vector3(0.0, 0.14, 0.0)
	root.add_child(splash)
	splash_material.set_shader_parameter("progress", 0.0)
	var tween := create_tween()
	tween.tween_method(_set_metaball_progress.bind(splash_material), 0.0, 1.0, WATER_SPLASH_DURATION)
	var cleanup_timer := Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = WATER_SPLASH_DURATION + 0.12
	cleanup_timer.timeout.connect(splash.queue_free)
	splash.add_child(cleanup_timer)
	cleanup_timer.start()

func _set_metaball_progress(value: float, mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("progress", value)

func _make_gradient_texture(stops: Array, width: int = 256) -> GradientTexture1D:
	var gradient := Gradient.new()
	var colors := PackedColorArray()
	var offsets := PackedFloat32Array()
	for stop in stops:
		offsets.append(float(stop[0]))
		var value: Variant = stop[1]
		if value is Color:
			colors.append(value as Color)
		else:
			var gray := float(value)
			colors.append(Color(gray, gray, gray, 1.0))
	gradient.colors = colors
	gradient.offsets = offsets
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = width
	return texture

func _make_cellular_noise_texture(tex_size: int = 256) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 2.2
	noise.fractal_octaves = 1
	var texture := NoiseTexture2D.new()
	texture.width = tex_size
	texture.height = tex_size
	texture.seamless = true
	texture.noise = noise
	return texture

func _make_metaball_splash_material(preset: String = "water") -> ShaderMaterial:
	if not ResourceLoader.exists(METABALL_SPLASH_SHADER_PATH):
		return null
	var mat := ShaderMaterial.new()
	mat.shader = load(METABALL_SPLASH_SHADER_PATH)
	_configure_metaball_splash_material(mat, preset)
	return mat

func _configure_metaball_splash_material(mat: ShaderMaterial, preset: String) -> void:
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("derive_progress", 1)
	mat.set_shader_parameter("ease_progress", 3)
	mat.set_shader_parameter("shading", 3)
	mat.set_shader_parameter("color_gradient", _make_gradient_texture([
		[0.0, Color("#ffffff")],
		[0.671, Color("#a3ffff")],
		[1.0, Color("#a3cfff00")],
	]))
	mat.set_shader_parameter("emission_intensity", 1.5)
	mat.set_shader_parameter("particles", 8)
	mat.set_shader_parameter("particle_size", 0.04)
	mat.set_shader_parameter("size_curve", _make_gradient_texture([
		[0.0, 0.0],
		[0.1, 1.0],
		[1.0, 0.0],
	]))
	mat.set_shader_parameter("randomize_size", Vector2(1.0, 5.0))
	mat.set_shader_parameter("particle_feather", 0.5)
	mat.set_shader_parameter("randomize_feather", Vector2(0.6, 1.0))
	mat.set_shader_parameter("feather_curve", _make_gradient_texture([
		[0.0, 0.0],
		[0.9, 1.0],
		[1.0, 1.0],
	]))
	mat.set_shader_parameter("initial_particle_velocity", -0.3)
	mat.set_shader_parameter("ease_ipv", 1)
	mat.set_shader_parameter("index_shift_randomness", 1)
	mat.set_shader_parameter("emission_dir", Vector2(1.0, 1.0))
	mat.set_shader_parameter("acceleration", Vector4(0.5, 0.5, 0.1, 0.1))
	mat.set_shader_parameter("acceleration_curve", _make_gradient_texture([
		[0.0, 0.0],
		[0.35, 0.0],
		[1.0, 0.5],
	]))
	mat.set_shader_parameter("blob_step", 0.01)
	mat.set_shader_parameter("feather_interpolation", 4)
	mat.set_shader_parameter("custom_feather_interp", _make_gradient_texture([
		[0.0, 0.0],
		[0.125, 0.875],
		[0.25, 0.8],
		[0.75, 0.875],
		[0.875, 0.625],
		[1.0, 1.0],
	]))
	mat.set_shader_parameter("uv_scale", Vector2(1.3, 1.3))
	mat.set_shader_parameter("enable_texture_distortion", 5)
	mat.set_shader_parameter("txdistort_str", 0.1)
	mat.set_shader_parameter("txdistort_a", _make_cellular_noise_texture())
	mat.set_shader_parameter("index_shift_distort_texture", 1)
	mat.set_shader_parameter("alpha_dissolve", 1)
	mat.set_shader_parameter("ease_alpha_dissolve", 1)
	mat.set_shader_parameter("alpha_edge", Vector2(0.99, 1.0))
	mat.set_shader_parameter("proximity_fade_distance", 0.5)
	mat.set_shader_parameter("billboard", 1)
	mat.set_shader_parameter("camera_offset", 0.1)
	mat.set_shader_parameter("generic_curve_A", _make_gradient_texture([
		[0.0, 0.0],
		[0.95, 1.0],
		[1.0, 0.0],
	]))
	match preset:
		"water":
			mat.set_shader_parameter("apply_iridescence", 2)
			mat.set_shader_parameter("iridescence", Vector4(2.0, 0.0, 0.0, 1.0))
			mat.set_shader_parameter("iridescence_size", 0.5)
		_:
			mat.set_shader_parameter("apply_iridescence", 0)

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_A, KEY_LEFT:   _pan_camera(Vector2(-1,0))
			KEY_D, KEY_RIGHT:  _pan_camera(Vector2(1,0))
			KEY_S, KEY_DOWN:   _pan_camera(Vector2(0,1))
			KEY_W, KEY_UP:     _pan_camera(Vector2(0,-1))
			KEY_ESCAPE:        if _selected_id != "": _deselect()

func _build_ui() -> void:
	var root_hbox := HBoxContainer.new()
	root_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_hbox.add_theme_constant_override("separation", 0)
	add_child(root_hbox)

	# ── Contracts side panel (left of garden) ────────────────────
	_contracts_panel = PanelContainer.new()
	_contracts_panel.custom_minimum_size = Vector2(SIDE_PANEL_SCRIPT.SIDE_PANEL_WIDTH, 0)
	var cp_st := StyleBoxFlat.new()
	cp_st.bg_color = Color(GameData.CARD_BG, 0.97)
	cp_st.border_color = GameData.CARD_HL
	cp_st.border_width_right = 1
	_contracts_panel.add_theme_stylebox_override("panel", cp_st)
	# Attach side-panel background drawing script
	if ResourceLoader.exists("res://scripts/ui/side_panel_bg.gd"):
		var sp_script := preload("res://scripts/ui/side_panel_bg.gd")
		_contracts_panel.set_script(sp_script)
		_contracts_panel.set("default_tex_path", "res://assets/ui/table/dice_side_panel_left.png")
		_contracts_panel.set("db_key", "dice_table_left_tex")
	root_hbox.add_child(_contracts_panel)

	var cp_vbox := VBoxContainer.new()
	cp_vbox.add_theme_constant_override("separation", 0)
	cp_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contracts_panel.add_child(cp_vbox)

	# Header row
	var cp_hdr := HBoxContainer.new()
	cp_hdr.add_theme_constant_override("separation", 4)
	cp_hdr.custom_minimum_size = Vector2(0, 32)
	var cp_hdr_st := StyleBoxFlat.new()
	cp_hdr_st.bg_color = Color(GameData.BG_COLOR, 0.92)
	cp_hdr_st.border_color = GameData.CARD_HL
	cp_hdr_st.border_width_bottom = 1
	cp_hdr_st.content_margin_left = 8
	cp_hdr_st.content_margin_right = 6
	var cp_hdr_wrap := PanelContainer.new()
	cp_hdr_wrap.add_theme_stylebox_override("panel", cp_hdr_st)
	cp_vbox.add_child(cp_hdr_wrap)
	cp_hdr_wrap.add_child(cp_hdr)

	var cp_title := Label.new()
	cp_title.text = "📜 CONTRACTS"
	cp_title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	cp_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	cp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cp_hdr.add_child(cp_title)

	_cp_panel_count = Label.new()
	_cp_panel_count.text = "0"
	_cp_panel_count.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.4))
	_cp_panel_count.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	cp_hdr.add_child(_cp_panel_count)

	var cp_new_btn := Button.new()
	cp_new_btn.text = "+"
	cp_new_btn.custom_minimum_size = Vector2(24, 0)
	cp_new_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	cp_new_btn.tooltip_text = "Create contract (Gallery → Contracts)"
	cp_new_btn.pressed.connect(_go_to_gallery_contracts)
	cp_hdr.add_child(cp_new_btn)

	# Scroll area
	var cp_scroll := ScrollContainer.new()
	cp_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cp_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cp_vbox.add_child(cp_scroll)

	_contracts_scroll = VBoxContainer.new()
	_contracts_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contracts_scroll.add_theme_constant_override("separation", 0)
	cp_scroll.add_child(_contracts_scroll)

	# Build the three collapsible sections
	_section_boss_items     = _build_contract_section("💀 HIGH PRIORITY",     Color(0.95,0.12,0.12,1.0), "boss")
	_section_mini_items     = _build_contract_section("⚠ MED PRIORITY",      Color(1.0,0.55,0.1,1.0),  "mini")
	_section_reminder_items = _build_contract_section("📋 LOW PRIORITY",     Color(0.9,0.82,0.1,1.0),  "reminder")

	# ── Left VBox (garden viewport, status bar, etc.) ─────────────
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 0)
	root_hbox.add_child(left_vbox)

	var hdr := HBoxContainer.new()
	hdr.custom_minimum_size = Vector2(0, 32)
	left_vbox.add_child(hdr)
	var title := Label.new(); title.text = "🌿  ENCHANTED GARDEN"
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)

	_status_lbl = Label.new()
	_status_lbl.text = "Click the catalog → then click the garden to plant"
	_status_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
	_status_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(_status_lbl)

	var water_hbox := HBoxContainer.new()
	water_hbox.custom_minimum_size = Vector2(0, 22)
	water_hbox.add_theme_constant_override("separation", 6)
	left_vbox.add_child(water_hbox)
	var water_icon := Label.new(); water_icon.text = "💧"
	water_icon.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	water_hbox.add_child(water_icon)
	_water_lbl = Label.new(); _water_lbl.text = "Water"
	_water_lbl.add_theme_color_override("font_color", Color("#88ccff"))
	_water_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	water_hbox.add_child(_water_lbl)
	_water_bar = ProgressBar.new()
	_water_bar.min_value = 0; _water_bar.max_value = 100
	_water_bar.value = 0
	_water_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_water_bar.custom_minimum_size = Vector2(0, 14)
	_water_bar.show_percentage = false
	water_hbox.add_child(_water_bar)

	_svc = SubViewportContainer.new()
	_svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_svc.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_svc.stretch = true
	_svc.gui_input.connect(_on_garden_input)
	_svc.mouse_entered.connect(func(): set_process(true))
	_svc.mouse_exited.connect(func(): set_process(false); _mouse_world_pos = Vector2.ZERO; _update_grass_mouse())
	_svc.mouse_filter = Control.MOUSE_FILTER_STOP
	left_vbox.add_child(_svc)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(900, 600)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = true
	_svc.add_child(_viewport)

	# ── Gradient sky overlay ─────────────────────────────────────
	_sky_gradient = Gradient.new()
	_sky_gradient.set_color(0, Color(0,0,0,0))
	_sky_gradient.set_color(1, Color(0,0,0,0))
	_sky_gradient.set_offset(0, 0.0)
	_sky_gradient.set_offset(1, 1.0)
	_sky_texture = GradientTexture2D.new()
	_sky_texture.gradient = _sky_gradient
	_sky_texture.fill = GradientTexture2D.FILL_LINEAR
	_sky_texture.fill_from = Vector2(0.5, 0.0)
	_sky_texture.fill_to   = Vector2(0.5, 1.0)
	_sky_rect = TextureRect.new()
	_sky_rect.texture = _sky_texture
	_sky_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_svc.add_child(_sky_rect)

	# God rays — sun (day) and moon (night), hidden initially
	_sun_rays_rect  = _build_god_rays_rect(
		Color(1.0, 0.88, 0.55, 0.75), -0.3, -0.2)
	_moon_rays_rect = _build_god_rays_rect(
		Color(0.45, 0.6, 1.0, 0.6),    0.3,  0.2)
	_sun_rays_rect.modulate.a  = 0.0
	_moon_rays_rect.modulate.a = 0.0
	# Add to the SubViewport canvas so the rays belong to the garden scene,
	# but remain screen-space within that viewport instead of moving with Camera3D.
	_viewport.add_child(_sun_rays_rect)
	_viewport.add_child(_moon_rays_rect)

	# Firefly layer (floats above sky)
	_firefly_layer = Control.new()
	_firefly_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_firefly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_svc.add_child(_firefly_layer)

	# Bug path layer (debug, always visible during day)
	_bug_layer = Control.new()
	_bug_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bug_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_svc.add_child(_bug_layer)

	_effects_label = Label.new()
	_effects_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	_effects_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	_effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effects_label.custom_minimum_size = Vector2(0, 28)
	left_vbox.add_child(_effects_label)

	_build_debug_panel(left_vbox)


	# Catalog panel (right)
	var catalog_panel := PanelContainer.new()
	catalog_panel.custom_minimum_size = Vector2(SIDE_PANEL_SCRIPT.SIDE_PANEL_WIDTH, 0)
	var catalog_st := StyleBoxFlat.new()
	catalog_st.bg_color = Color(GameData.BG_COLOR, 0.95)
	catalog_st.border_color = GameData.CARD_HL; catalog_st.set_border_width_all(1)
	catalog_panel.add_theme_stylebox_override("panel", catalog_st)
	root_hbox.add_child(catalog_panel)
	var rv := VBoxContainer.new()
	rv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_theme_constant_override("separation", 4)
	catalog_panel.add_child(rv)
	# Catalog header
	var cat_hbox := HBoxContainer.new()
	cat_hbox.add_theme_constant_override("separation", 4)
	rv.add_child(cat_hbox)
	_cat_label = Label.new()
	_cat_label.text = "🌱 PLANTS"
	_cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_hbox.add_child(_cat_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(scroll)
	_catalog_list = VBoxContainer.new()
	_catalog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_catalog_list)
	# Show plant catalog by default
	_build_catalog()
	_seed_info_label = Label.new()
	_seed_info_label.add_theme_color_override("font_color", GameData.ACCENT_CURIO_CANISTER)
	_seed_info_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	_seed_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(_seed_info_label)

	_sky_layer = CanvasLayer.new(); _sky_layer.layer = 50
	add_child(_sky_layer)

# ─────────────────────────────────────────────────────────────────
#  Contracts Side Panel
# ─────────────────────────────────────────────────────────────────

# Builds one collapsible section, appends to _contracts_scroll, returns items VBox
func _build_contract_section(title: String, col: Color, key: String) -> VBoxContainer:
	var section_wrap := VBoxContainer.new()
	section_wrap.add_theme_constant_override("separation", 0)
	section_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contracts_scroll.add_child(section_wrap)

	# Toggle header row
	var hdr_btn := Button.new()
	hdr_btn.flat = true
	hdr_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hdr_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	hdr_btn.add_theme_color_override("font_color", col)
	hdr_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var badge := Label.new()
	badge.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	badge.add_theme_color_override("font_color", col)
	badge.custom_minimum_size = Vector2(22, 0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var hdr_hbox := HBoxContainer.new()
	hdr_hbox.add_theme_constant_override("separation", 0)
	hdr_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hdr_st := StyleBoxFlat.new()
	hdr_st.bg_color = Color(col, 0.08)
	hdr_st.border_color = Color(col, 0.25)
	hdr_st.border_width_bottom = 1
	hdr_st.content_margin_left = 8; hdr_st.content_margin_right = 6
	hdr_st.content_margin_top = 5; hdr_st.content_margin_bottom = 5
	var hdr_wrap := PanelContainer.new()
	hdr_wrap.add_theme_stylebox_override("panel", hdr_st)
	hdr_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_wrap.add_child(hdr_wrap)
	hdr_wrap.add_child(hdr_hbox)
	hdr_hbox.add_child(hdr_btn)
	hdr_hbox.add_child(badge)

	# Items container
	var items_vbox := VBoxContainer.new()
	items_vbox.add_theme_constant_override("separation", 2)
	items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_wrap.add_child(items_vbox)

	# Store references for later update
	match key:
		"boss":
			_badge_boss = badge
			hdr_btn.text = "▾  " + title
			hdr_btn.pressed.connect(func():
				_section_boss_coll = not _section_boss_coll
				hdr_btn.text = ("▸  " if _section_boss_coll else "▾  ") + title
				_section_boss_items.visible = not _section_boss_coll)
		"mini":
			_badge_mini = badge
			hdr_btn.text = "▾  " + title
			hdr_btn.pressed.connect(func():
				_section_mini_coll = not _section_mini_coll
				hdr_btn.text = ("▸  " if _section_mini_coll else "▾  ") + title
				_section_mini_items.visible = not _section_mini_coll)
		"reminder":
			_badge_reminder = badge
			hdr_btn.text = "▾  " + title
			hdr_btn.pressed.connect(func():
				_section_reminder_coll = not _section_reminder_coll
				hdr_btn.text = ("▸  " if _section_reminder_coll else "▾  ") + title
				_section_reminder_items.visible = not _section_reminder_coll)

	return items_vbox


func _refresh_contracts_panel() -> void:
	if not is_instance_valid(_contracts_scroll): return
	var active: Array = Database.get_contracts(GameData.current_profile, false)
	active.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pri := {"High Priority": 0, "Med Priority": 1, "Low Priority": 2, "No Priority": 3}
		var pa: int = pri.get(a.get("difficulty","No Priority"), 3)
		var pb: int = pri.get(b.get("difficulty","No Priority"), 3)
		if pa != pb: return pa < pb
		var da: String = a.get("deadline",""); var db: String = b.get("deadline","")
		if da != "" and db != "": return da < db
		return da != ""
	)
	var high_priority   := active.filter(func(c): return c.get("difficulty","") == "High Priority")
	var med_priority    := active.filter(func(c): return c.get("difficulty","") == "Med Priority")
	var low_priority    := active.filter(func(c): return c.get("difficulty","") == "Low Priority")
	var no_priority     := active.filter(func(c): return c.get("difficulty","") == "No Priority")

	_fill_section(_section_boss_items,     high_priority,    Color(0.95,0.12,0.12,1.0))
	_fill_section(_section_mini_items,     med_priority,     Color(1.0,0.55,0.1,1.0))
	_fill_section(_section_reminder_items, low_priority,     Color(0.9,0.82,0.1,1.0))

	if is_instance_valid(_badge_boss):     _badge_boss.text     = str(high_priority.size())
	if is_instance_valid(_badge_mini):     _badge_mini.text     = str(med_priority.size())
	if is_instance_valid(_badge_reminder): _badge_reminder.text = str(low_priority.size())
	if is_instance_valid(_cp_panel_count): _cp_panel_count.text = str(active.size())


func _fill_section(container: VBoxContainer, contracts: Array, col: Color) -> void:
	if not is_instance_valid(container): return
	for c in container.get_children(): c.queue_free()

	if contracts.is_empty():
		var empty := Label.new()
		empty.text = "  —"
		empty.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.25))
		empty.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		container.add_child(empty)
		return

	for contract: Dictionary in contracts:
		container.add_child(_make_cp_pill(contract, col))


func _contract_incomplete_subtask_count(contract: Dictionary) -> int:
	return Database.count_incomplete_contract_subtasks(contract)


func _make_cp_pill(contract: Dictionary, col: Color) -> PanelContainer:
	var cid: int = int(contract.get("id", 0))
	var subtask_cards: Array = Database.get_contract_subtask_cards(contract)
	var incomplete_subtasks: int = _contract_incomplete_subtask_count(contract)
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attach_hover_tilt(pill, 5.6, 1.02)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(col, 0.10)
	st.border_color = Color(col, 0.50)
	st.set_border_width_all(1); st.set_corner_radius_all(4)
	st.content_margin_left = 7; st.content_margin_right = 6
	st.content_margin_top = 4;  st.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", st)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	pill.add_child(vbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)

	# Dot
	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", GameData.scaled_font_size(7))
	dot.add_theme_color_override("font_color", col)
	dot.custom_minimum_size = Vector2(10, 0)
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(dot)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = contract.get("name", "?")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	hbox.add_child(name_lbl)

	# Deadline indicator (if set)
	var dl: String = contract.get("deadline", "")
	if dl != "":
		var days := _cp_days_between(GameData.get_date_string(), dl)
		var dl_lbl := Label.new()
		dl_lbl.text = "%dd" % days
		dl_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(8))
		dl_lbl.add_theme_color_override("font_color", GameData.get_deadline_color(days))
		hbox.add_child(dl_lbl)

	if incomplete_subtasks > 0:
		var card_lbl := Label.new()
		card_lbl.text = "☐%d" % incomplete_subtasks
		card_lbl.tooltip_text = "Incomplete subtasks"
		card_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(8))
		card_lbl.add_theme_color_override("font_color", Color(GameData.ACCENT_BLUE, 0.75))
		hbox.add_child(card_lbl)

	if not subtask_cards.is_empty():
		var st_panel := PanelContainer.new()
		st_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st_st := StyleBoxFlat.new()
		st_st.bg_color = Color(GameData.BG_COLOR, 0.26)
		st_st.border_color = Color(col, 0.18)
		st_st.set_border_width_all(1)
		st_st.set_corner_radius_all(4)
		st_st.content_margin_left = 4
		st_st.content_margin_right = 4
		st_st.content_margin_top = 3
		st_st.content_margin_bottom = 3
		st_panel.add_theme_stylebox_override("panel", st_st)
		vbox.add_child(st_panel)

		var st_vbox := VBoxContainer.new()
		st_vbox.add_theme_constant_override("separation", 2)
		st_panel.add_child(st_vbox)
		for card in subtask_cards:
			var card_id: int = int(card.get("id", 0))
			var checked: bool = bool(card.get("completed", false))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 3)
			st_vbox.add_child(row)

			var cb := CheckBox.new()
			cb.button_pressed = checked
			row.add_child(cb)

			var subtask_lbl := Label.new()
			subtask_lbl.text = str(card.get("title", "")).strip_edges()
			subtask_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			subtask_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			subtask_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
			subtask_lbl.add_theme_color_override("font_color",
				Color(GameData.ACCENT_GOLD, 0.55) if checked else Color(GameData.FG_COLOR, 0.85))
			row.add_child(subtask_lbl)

			cb.toggled.connect(func(on: bool):
				Database.set_contract_subtask_completed(cid, card_id, on)
				subtask_lbl.add_theme_color_override("font_color",
					Color(GameData.ACCENT_GOLD, 0.55) if on else Color(GameData.FG_COLOR, 0.85))
				GameData.contract_data_changed.emit())

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 4)
	vbox.add_child(action_row)
	var complete_btn := Button.new()
	complete_btn.text = "✅ Complete"
	complete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	complete_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	complete_btn.disabled = incomplete_subtasks > 0
	if incomplete_subtasks > 0:
		complete_btn.tooltip_text = "Complete all subtasks first (%d remaining)" % incomplete_subtasks
	complete_btn.pressed.connect(func(): _complete_contract_from_garden(cid))
	action_row.add_child(complete_btn)

	return pill


func _cp_days_between(from_str: String, to_str: String) -> int:
	var fmt := func(s: String) -> Dictionary:
		var parts := s.split("-")
		return {year=int(parts[0]), month=int(parts[1]), day=int(parts[2]), hour=0, minute=0, second=0}
	return int((Time.get_unix_time_from_datetime_dict(fmt.call(to_str))
		- Time.get_unix_time_from_datetime_dict(fmt.call(from_str))) / 86400.0)


func _go_to_gallery_contracts() -> void:
	var main: Node = get_tree().get_root().get_node_or_null("Main")
	if main and main.has_method("switch_to_tab_by_key"):
		main.switch_to_tab_by_key("gallery")
		await get_tree().process_frame
		if main.has_method("get_tab_node"):
			var gallery: Control = main.get_tab_node("gallery")
			if gallery and gallery.has_method("open_section"):
				gallery.open_section("contracts")

func _complete_contract_from_garden(contract_id: int) -> void:
	var reward := Database.complete_contract_with_reward(contract_id)
	if reward.is_empty():
		_show_contract_subtask_gate_notice()
		return
	GameData.contract_data_changed.emit()
	GameData.state_changed.emit()
	_refresh_contracts_panel()
	_show_moonkissed_paper_reward(reward)

func _show_moonkissed_paper_reward(reward: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "📜 Moonkissed Paper Earned!"
	var tier: String = reward.get("reward_tier", "minor")
	var tier_label: String = "Minor" if tier == "minor" else "Major"
	var tier_color: String = "blue" if tier == "minor" else "gold"
	dialog.dialog_text = "Contract completed!\n\nYou received a Moonkissed Paper Fragment (%s reward tier).\n\nVisit the Selenic Exchange to redeem your moonkissed papers for chocolate coins and cerulean seeds!" % tier_label
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _show_contract_subtask_gate_notice() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Subtasks Remaining"
	dialog.dialog_text = "Complete every subtask before finishing this contract."
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())


func _build_debug_panel(_parent: VBoxContainer) -> void:
	if is_instance_valid(_debug_panel):
		_debug_panel.queue_free()
	_debug_panel = PopupPanel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(GameData.BG_COLOR, 0.98); st.border_color = GameData.ACCENT_RED
	st.set_border_width_all(1); st.set_corner_radius_all(6)
	_debug_panel.add_theme_stylebox_override("panel", st)
	add_child(_debug_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_debug_panel.add_child(margin)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 3)
	margin.add_child(vb)
	var lbl := Label.new(); lbl.text = "🔧  DEBUG GARDEN"
	lbl.add_theme_color_override("font_color", GameData.ACCENT_RED)
	lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(lbl)
	# Garden actions
	_dbg_row(vb, [["💧 Water All", _debug_water_all],   ["🚫 Unwater All", _debug_unwater_all]])
	_dbg_row(vb, [["⬆ Grow All",  _debug_grow_all],    ["⬇ Degrow All",  _debug_degrow_all]])
	_dbg_row(vb, [["🌱 Plant All", _debug_plant_all],   ["🔥 Unplant All", _debug_unplant_all]])
	_dbg_row(vb, [["✥ Shuffle Positions", _debug_shuffle]])
	_dbg_row(vb, [["🌱 Add Random Plant", _debug_add_random], ["🗑 Remove Random", _debug_remove_random]])
	# Time of day controls
	var tod_lbl := Label.new(); tod_lbl.text = "🌅  TIME OF DAY"
	tod_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	tod_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); vb.add_child(tod_lbl)
	_dbg_row(vb, [["🌅 Sunrise", func(): _debug_set_time(6, 0)], ["☀ Day", func(): _debug_set_time(10, 0)]])
	_dbg_row(vb, [["🌇 Sunset", func(): _debug_set_time(18, 0)], ["🌙 Night", func(): _debug_set_time(22, 0)]])
	_dbg_row(vb, [["🔄 Real Time", _debug_reset_real_time]])
	# GDD §2: Garden debug extras
	var gdd_lbl := Label.new(); gdd_lbl.text = "⏱  GDD TOOLS"
	gdd_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	gdd_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); vb.add_child(gdd_lbl)
	_dbg_row(vb, [["⏩ +1 Day Growth", _debug_time_warp_day], ["⏩⏩ +7 Days", _debug_time_warp_week]])
	_dbg_row(vb, [["💧 Fill Water", _debug_fill_water], ["🌸 Force Bloom All", _debug_force_bloom]])
	_dbg_row(vb, [["🌟 Spawn Rare Seed", _debug_spawn_rare_seed]])
	# Forced-rarity seed drop — fires the full cinematic overlay at requested rarity
	var force_lbl := Label.new(); force_lbl.text = "🎴  FORCE SEED DROP"
	force_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	force_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); vb.add_child(force_lbl)
	_dbg_row(vb, [["◦ Common",   func(): _debug_force_seed_drop("common")],
				 ["◦ Uncommon", func(): _debug_force_seed_drop("uncommon")]])
	_dbg_row(vb, [["◈ Rare",     func(): _debug_force_seed_drop("rare")],
				 ["◈ Epic",     func(): _debug_force_seed_drop("epic")]])
	_dbg_row(vb, [["★ Legendary", func(): _debug_force_seed_drop("legendary")],
				 ["☯ Exotic",    func(): _debug_force_seed_drop("exotic")]])

func _dbg_row(parent: VBoxContainer, entries: Array) -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	for e: Array in entries:
		var b := Button.new(); b.text = e[0] as String
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		b.pressed.connect(e[1] as Callable); row.add_child(b)

func show_dev_popup() -> void:
	if not GameData.is_debug_mode(): return
	if not is_instance_valid(_debug_panel):
		_build_debug_panel(null)
	_debug_panel.popup_centered()

func _toggle_debug() -> void:
	if not GameData.is_debug_mode(): return
	show_dev_popup()

func _refresh_debug_visibility() -> void:
	pass  # replaced by popup; kept for call-site compat

func _build_3d_scene() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color("#10201a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color("#2a4a30")
	env.ambient_light_energy = 0.6
	we.environment = env; _viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-65.0, -30.0, 0.0)
	sun.light_color = Color("#fff5e8"); sun.light_energy = 0.4  # softened from 1.4, reduced further
	sun.shadow_enabled = false; _viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAM_SIZE; _camera.position = CAM_POS
	_camera.rotation_degrees = Vector3(CAM_ROT_X, 0.0, 0.0)
	_camera.near = 0.1; _camera.far = 100.0; _viewport.add_child(_camera)
	var ground := MeshInstance3D.new()
	var plane  := PlaneMesh.new(); plane.size = Vector2(GARDEN_W+2.0, GARDEN_H+2.0)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#1a3018"); gm.roughness = 0.92
	ground.material_override = gm; _viewport.add_child(ground)
	_add_border_ring()
	_plant_root = Node3D.new(); _viewport.add_child(_plant_root)
	_rebuild_grass(true)

func _add_border_ring() -> void:
	var c: Array[Vector3] = [
		Vector3(-GARDEN_W*.5,.02,-GARDEN_H*.5), Vector3(GARDEN_W*.5,.02,-GARDEN_H*.5),
		Vector3(GARDEN_W*.5,.02,GARDEN_H*.5),   Vector3(-GARDEN_W*.5,.02,GARDEN_H*.5)]
	for i in range(4):
		var a: Vector3 = c[i]; var b: Vector3 = c[(i+1)%4]
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06; cyl.bottom_radius = 0.06; cyl.height = (b-a).length()
		seg.mesh = cyl
		var sm := StandardMaterial3D.new(); sm.albedo_color = Color("#3a6030")
		seg.material_override = sm; seg.position = (a+b)*0.5
		var dir: Vector3 = (b-a).normalized()
		seg.basis = Basis(dir.cross(Vector3.UP).normalized(), Vector3.UP, -dir).orthonormalized()
		seg.rotate_object_local(Vector3.RIGHT, PI*0.5)
		_viewport.add_child(seg)

func _rebuild_grass(force: bool = false) -> void:
	if not force and is_instance_valid(_grass_node): return  # already built; skip on tab re-open
	if is_instance_valid(_grass_shadow_node): _grass_shadow_node.queue_free(); _grass_shadow_node = null
	if is_instance_valid(_grass_node): _grass_node.queue_free(); _grass_node = null
	if not is_instance_valid(_plant_root): return
	var plant_excl: Array[Vector2] = []
	# avoid grass near plants
	for g: Dictionary in Database.get_garden(GameData.current_profile):
		# Convert normalized coordinates (0..1) to world-space for exclusion
		var nx: float = float(g.get("pos_x", 0.5))
		var nz: float = float(g.get("pos_z", 0.5))
		var wx: float = lerp(-GARDEN_W*0.5, GARDEN_W*0.5, nx)
		var wz: float = lerp(-GARDEN_H*0.5, GARDEN_H*0.5, nz)
		plant_excl.append(Vector2(wx, wz))
	var quad := PlaneMesh.new()
	quad.size = Vector2(BLADE_W, BLADE_H); quad.orientation = PlaneMesh.FACE_Z; quad.subdivide_depth = 3
	var mm := MultiMesh.new(); mm.mesh = quad; mm.transform_format = MultiMesh.TRANSFORM_3D
	var positions: Array[Vector3] = []
	var rng := RandomNumberGenerator.new(); rng.seed = 20250604
	var attempts := 0
	while positions.size() < GRASS_COUNT and attempts < GRASS_COUNT * 7:
		attempts += 1
		var x: float = rng.randf_range(-GARDEN_W*0.48, GARDEN_W*0.48)
		var z: float = rng.randf_range(-GARDEN_H*0.48, GARDEN_H*0.48)
		var ok := true
		for ep: Vector2 in plant_excl:
			if Vector2(x,z).distance_to(ep) < GRASS_CLEAR_R: ok = false; break
		if ok: positions.append(Vector3(x, BLADE_H*0.5, z))
	mm.instance_count = positions.size()
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 20250604
	for i in range(positions.size()):
		var t := Transform3D()
		t.origin = positions[i]; t.basis = Basis(Vector3.UP, rng2.randf()*TAU)
		mm.set_instance_transform(i, t)

	# ── Shadow pass (rendered first = behind grass) ──────────────
	_grass_shadow_node = MultiMeshInstance3D.new(); _grass_shadow_node.multimesh = mm
	var smat := _make_grass_shadow_material()
	if smat: _grass_shadow_node.material_override = smat
	# ensure grass draws behind planters and plants
	_grass_shadow_node.sorting_offset = 0
	_viewport.add_child(_grass_shadow_node)
	_viewport.move_child(_grass_shadow_node, _plant_root.get_index())

	# ── Grass pass ───────────────────────────────────────────────
	_grass_node = MultiMeshInstance3D.new(); _grass_node.multimesh = mm
	var gmat := _make_grass_material()
	if gmat: _grass_node.material_override = gmat
	else:
		var fb := StandardMaterial3D.new(); fb.albedo_color = Color("#2d7a2d")
		fb.cull_mode = BaseMaterial3D.CULL_DISABLED; _grass_node.material_override = fb
	_viewport.add_child(_grass_node)
	_viewport.move_child(_grass_node, _plant_root.get_index())
	# ensure grass draws behind planters and plants
	_grass_node.sorting_offset = 0

func _make_grass_material() -> ShaderMaterial:
	var sp := "res://assets/BinbunGrass/shader/grass.gdshader"
	if not ResourceLoader.exists(sp): return null
	var mat := ShaderMaterial.new(); mat.shader = load(sp)

	# ── Sprite sheet atlas (3 cols × 2 rows) ──────────────────────
	var sprite_sheet_path := "res://assets/textures/grass_sprites.png"
	if ResourceLoader.exists(sprite_sheet_path):
		mat.set_shader_parameter("shape_atlas", load(sprite_sheet_path))
		mat.set_shader_parameter("use_atlas", true)
		mat.set_shader_parameter("atlas_cols", 3)
		mat.set_shader_parameter("atlas_rows", 2)
		mat.set_shader_parameter("use_sprite_color", true)
	elif ResourceLoader.exists("res://assets/BinbunGrass/texture/grass_blade.png"):
		mat.set_shader_parameter("shape_texture", load("res://assets/BinbunGrass/texture/grass_blade.png"))
		if ResourceLoader.exists("res://assets/BinbunGrass/texture/grass_atlas.png"):
			mat.set_shader_parameter("shape_atlas", load("res://assets/BinbunGrass/texture/grass_atlas.png"))
			mat.set_shader_parameter("use_atlas", true)
			mat.set_shader_parameter("atlas_cols", 2)
			mat.set_shader_parameter("atlas_rows", 2)
			mat.set_shader_parameter("use_sprite_color", false)

	# ── Noise texture (color variation) ───────────────────────────
	var nf := FastNoiseLite.new(); nf.seed = 42; nf.frequency = 0.008
	var nt := NoiseTexture2D.new(); nt.width=512; nt.height=512; nt.seamless=true; nt.noise=nf
	mat.set_shader_parameter("noise_texture", nt)

	# ── Color gradient (fallback / tint) ──────────────────────────
	var grad := Gradient.new()
	grad.set_color(0, Color("#1a4a10"))
	grad.add_point(0.45, Color("#2d7a1a")); grad.add_point(0.7, Color("#44aa22")); grad.add_point(1.0, Color("#88cc44"))
	var gt := GradientTexture1D.new(); gt.gradient = grad; gt.width = 256
	mat.set_shader_parameter("color_gradient", gt)

	# ── Wind ──────────────────────────────────────────────────────
	mat.set_shader_parameter("wind_speed",     1.1)
	mat.set_shader_parameter("wind_strength",  0.28)
	mat.set_shader_parameter("wind_direction", Vector2(1.0, 0.3))
	mat.set_shader_parameter("height_offset",  0.08)

	# ── Transparency ──────────────────────────────────────────────
	mat.set_shader_parameter("random_variation", 0.06)
	mat.set_shader_parameter("alpha_cut_start",  0.1)
	mat.set_shader_parameter("alpha_cut_end",    0.9)
	mat.set_shader_parameter("alpha_mode",       1)
	mat.set_shader_parameter("is_shadow_pass",   false)
	return mat

func _make_grass_shadow_material() -> ShaderMaterial:
	var sp := "res://assets/BinbunGrass/shader/grass.gdshader"
	if not ResourceLoader.exists(sp): return null
	var mat := ShaderMaterial.new(); mat.shader = load(sp)

	# Same sprite atlas so shadow shape matches exactly
	var sprite_sheet_path := "res://assets/textures/grass_sprites.png"
	if ResourceLoader.exists(sprite_sheet_path):
		mat.set_shader_parameter("shape_atlas", load(sprite_sheet_path))
		mat.set_shader_parameter("use_atlas", true)
		mat.set_shader_parameter("atlas_cols", 3)
		mat.set_shader_parameter("atlas_rows", 2)
		mat.set_shader_parameter("use_sprite_color", false)
	elif ResourceLoader.exists("res://assets/BinbunGrass/texture/grass_blade.png"):
		mat.set_shader_parameter("shape_texture", load("res://assets/BinbunGrass/texture/grass_blade.png"))

	# Dummy noise (not used visually for shadow, but uniform must be set)
	var nf := FastNoiseLite.new(); nf.seed = 1
	var nt := NoiseTexture2D.new(); nt.width=64; nt.height=64; nt.noise=nf
	mat.set_shader_parameter("noise_texture", nt)
	var gt := GradientTexture1D.new(); gt.width = 4
	mat.set_shader_parameter("color_gradient", gt)

	# Wind must match grass so shadow moves with blades
	mat.set_shader_parameter("wind_speed",     1.1)
	mat.set_shader_parameter("wind_strength",  0.28)
	mat.set_shader_parameter("wind_direction", Vector2(1.0, 0.3))
	mat.set_shader_parameter("height_offset",  0.08)

	# Shadow-specific params
	mat.set_shader_parameter("is_shadow_pass",       true)
	mat.set_shader_parameter("shadow_opacity",        0.30)
	mat.set_shader_parameter("shadow_color",          Vector3(0.0, 0.04, 0.01))
	mat.set_shader_parameter("shadow_world_offset",   Vector2(0.20, 0.14))
	mat.set_shader_parameter("shadow_squash",         0.20)

	mat.set_shader_parameter("alpha_cut_start", 0.1)
	mat.set_shader_parameter("alpha_cut_end",   0.9)
	mat.set_shader_parameter("alpha_mode",      1)
	return mat

func _refresh() -> void:
	if not is_inside_tree(): return
	# ensure grass shader knows about obstacles every refresh
	_update_grass_obstacles()
	_build_catalog()
	_build_garden_plants(); _update_effects()
	if is_instance_valid(_seed_info_label):
		_seed_info_label.text = "Profile: %s" % GameData.current_profile
	_refresh_debug_visibility()
	_refresh_water_meter()
	_refresh_contracts_panel()

func _build_catalog() -> void:
	if not is_instance_valid(_catalog_list): return
	for c in _catalog_list.get_children(): c.queue_free()
	# Plant catalog — only show plants that have been grown (received via cerulean seeds)
	var garden_data: Array = Database.get_garden(GameData.current_profile)
	var grown_ids: Array[String] = []
	for g: Dictionary in garden_data: grown_ids.append(g.get("plant_id","") as String)
	if grown_ids.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "🌱 No plants yet!\nOpen a Cerulean Seed to get your first plant."
		empty_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_catalog_list.add_child(empty_lbl)
		return
	for plant: Dictionary in GameData.PLANT_CATALOG:
		if (plant.get("id","") as String) in grown_ids:
			_catalog_list.add_child(_make_catalog_card(plant, true, garden_data))
	call_deferred("_setup_feedback")

func _make_catalog_card(plant: Dictionary, already_grown: bool, garden_data: Array) -> PanelContainer:
	var rarity: String = plant.get("rarity","common") as String
	var rcol:   Color  = GameData.RARITY_COLORS.get(rarity, GameData.FG_COLOR) as Color
	var pid:    String = plant.get("id","") as String
	var card := PanelContainer.new()
	var st   := StyleBoxFlat.new()
	st.bg_color     = GameData.RARITY_BG.get(rarity, GameData.CARD_BG) as Color
	st.border_color = rcol if not already_grown else Color(rcol, 0.28)
	st.set_border_width_all(1); st.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", st)
	var hbox := HBoxContainer.new(); hbox.add_theme_constant_override("separation", 3); card.add_child(hbox)
	var el := Label.new(); el.text = plant.get("emoji","🌱") as String
	el.add_theme_font_size_override("font_size", GameData.scaled_font_size(20)); el.custom_minimum_size = Vector2(26,0); hbox.add_child(el)
	var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hbox.add_child(info)
	var nl := Label.new(); nl.text = plant.get("name","") as String
	nl.add_theme_color_override("font_color", rcol if not already_grown else Color(rcol, 0.5))
	nl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11)); nl.clip_text = true; info.add_child(nl)
	var dl := Label.new(); dl.text = plant.get("desc","") as String
	dl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.4))
	dl.add_theme_font_size_override("font_size", GameData.scaled_font_size(8))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.add_child(dl)
	if already_grown:
		for g: Dictionary in garden_data:
			if (g.get("plant_id","") as String) == pid:
				var s: int = mini(int(g.get("stage",0)), STAGE_MAX)
				var sb := Label.new()
				sb.text = "%s %s  (%d/%d)" % [GROWTH_STAGES[s], STAGE_NAMES[s], s, STAGE_MAX]
				sb.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
				sb.add_theme_font_size_override("font_size", GameData.scaled_font_size(8)); info.add_child(sb); break
	var btns := HBoxContainer.new(); btns.add_theme_constant_override("separation", 2); info.add_child(btns)
	if already_grown:
		var dl2 := Label.new(); dl2.text = "✓ Planted"
		dl2.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
		dl2.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); btns.add_child(dl2)
		var mb := Button.new(); mb.text = "✥ Move"; mb.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		mb.pressed.connect(func(): _select_plant_to_move(pid)); btns.add_child(mb)
	elif _selected_id == pid:
		var pl := Label.new(); pl.text = "📍 Click garden…"
		pl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
		pl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); btns.add_child(pl)
		var cb := Button.new(); cb.text = "✕"; cb.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		cb.pressed.connect(_deselect); btns.add_child(cb)
	else:
		var pb := Button.new(); pb.text = "🌱 Plant"; pb.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		pb.pressed.connect(func(): _select_plant_to_place(pid)); btns.add_child(pb)
	return card

func _build_garden_plants() -> void:
	for pid in _plant_nodes:
		var nd: Dictionary = _plant_nodes[pid]
		if nd.has("root") and is_instance_valid(nd.root as Node3D): (nd.root as Node3D).queue_free()
	_plant_nodes.clear()
	for grown: Dictionary in Database.get_garden(GameData.current_profile):
		var pid: String = grown.get("plant_id","") as String
		var pd: Variant = _find_plant(pid)
		if not pd: continue
		# Convert normalized coordinates (0.0-1.0) back to world-space coordinates
		var norm_x: float = float(grown.get("pos_x",0.0))
		var norm_z: float = float(grown.get("pos_z",0.0))
		var world_x: float = lerp(-GARDEN_W * 0.5, GARDEN_W * 0.5, norm_x)
		var world_z: float = lerp(-GARDEN_H * 0.5, GARDEN_H * 0.5, norm_z)
		
		# Debug logging for coordinate conversion
		if GameData.is_debug_mode():
			print("Garden: Plant %s at norm(%.3f, %.3f) -> world(%.3f, %.3f)" % [pid, norm_x, norm_z, world_x, world_z])
		
		_spawn_plant_node(pid, pd as Dictionary,
			Vector3(world_x, 0.0, world_z),
			mini(int(grown.get("stage",0)), STAGE_MAX), grown)

func _spawn_plant_node(plant_id: String, plant: Dictionary, world_pos: Vector3, stage: int, grown: Dictionary) -> void:
	var root := Node3D.new(); root.position = world_pos; _plant_root.add_child(root)
	var rcol: Color = GameData.RARITY_COLORS.get(plant.get("rarity","common"), Color("#44ff88")) as Color
	var ring := MeshInstance3D.new(); var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42 + stage*0.22; cyl.bottom_radius = 0.42 + stage*0.22; cyl.height = 0.05
	ring.mesh = cyl
	var rm := StandardMaterial3D.new(); rm.albedo_color = Color(rcol,0.5)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; rm.emission_enabled = true; rm.emission = rcol*0.22
	ring.material_override = rm; ring.position.y = 0.02; root.add_child(ring)
	var gr: MeshInstance3D = null
	if stage >= STAGE_MAX:
		gr = MeshInstance3D.new(); var gc := CylinderMesh.new()
		gc.top_radius = 0.88; gc.bottom_radius = 0.88; gc.height = 0.03; gr.mesh = gc
		var gm2 := StandardMaterial3D.new(); gm2.albedo_color = Color(rcol,0.15)
		gm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm2.emission_enabled = true; gm2.emission = rcol*0.5
		gr.material_override = gm2; gr.position.y = 0.01; root.add_child(gr)
	var label := Label3D.new()
	label.text = GROWTH_STAGES[stage] + (plant.get("emoji","🌱") as String)
	label.font_size = 22+stage*11; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true; label.position = Vector3(0.0, 0.26+stage*0.28, 0.0); root.add_child(label)
	# Ensure plant visuals render above planters and grass
	label.sorting_offset = 2
	var nl := Label3D.new()
	nl.text = plant.get("name","") as String
	nl.font_size = 9
	nl.modulate = Color(rcol,0.7)
	nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nl.position = Vector3(0.0,-0.06,0.0)
	nl.outline_size = 4
	root.add_child(nl)
	nl.sorting_offset = 2
	var sdots := Label3D.new()
	sdots.text = "◆".repeat(stage+1) + "◇".repeat(STAGE_MAX-stage)
	sdots.font_size = 8
	sdots.modulate = Color(rcol,0.55)
	sdots.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sdots.position = Vector3(0.0,-0.22,0.0)
	root.add_child(sdots)
	sdots.sorting_offset = 2
	if (grown.get("last_watered","") as String) != GameData.get_date_string():
		var wl := Label3D.new()
		wl.text = "💧"
		wl.font_size = 12
		wl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		wl.position = Vector3(0.55, 0.6+stage*0.2, 0.0)
		root.add_child(wl)
		wl.sorting_offset = 2
	# also ensure mesh instances (ring / optional gr) render above grass
	ring.sorting_offset = 2
	if stage >= STAGE_MAX and "gr" in _plant_nodes[plant_id]:
		_plant_nodes[plant_id].gr.sorting_offset = 2
	_plant_nodes[plant_id] = {
		"root": root,
		"ring": ring,
		"gr": gr if stage >= STAGE_MAX else null
	}

func _select_plant_to_place(plant_id: String) -> void:
	_selected_id = plant_id; _drag_mode = false
	var pl: Variant = _find_plant(plant_id)
	if pl:
		_status_lbl.text = "📍 Click garden to plant: %s" % (pl as Dictionary).get("name","")
		_status_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	_build_catalog()

func _select_plant_to_move(plant_id: String) -> void:
	_selected_id = plant_id; _drag_mode = true
	var pl: Variant = _find_plant(plant_id)
	if pl:
		_status_lbl.text = "✥ Click new position for: %s" % (pl as Dictionary).get("name","")
		_status_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)

func _deselect() -> void:
	_selected_id = ""; _drag_mode = false
	_status_lbl.text = "Click the catalog → then click the garden to plant"
	_status_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
	_build_catalog()

func _on_garden_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hit_v: Variant = _unproject_to_ground(_viewport.get_mouse_position(), true)
		if hit_v == null:
			return
		var hit: Vector3 = hit_v as Vector3
		if _selected_id != "":
			# Keep plants fully inside garden bounds with margin
			hit.x = clampf(hit.x, -GARDEN_W*0.40, GARDEN_W*0.40)
			hit.z = clampf(hit.z, -GARDEN_H*0.40, GARDEN_H*0.40)
			if _drag_mode:
				Database.move_plant(_selected_id, GameData.current_profile, hit.x, hit.z)
			else:
				var cur_count: int = Database.get_garden(GameData.current_profile).size()
				if cur_count >= MAX_PLANTS:
					_status_lbl.text = "🚫 Garden full! (%d/%d plants)" % [cur_count, MAX_PLANTS]
					_status_lbl.add_theme_color_override("font_color", GameData.ACCENT_RED); return
				Database.plant_seed(_selected_id, GameData.current_profile, hit.x, hit.z)
				GameData.state_changed.emit()
			_play_plant_sound(); _deselect(); _rebuild_grass(true); _refresh()
		else:
			_try_water_at(hit)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _selected_id != "": _deselect()

func _unproject_to_ground(screen_pos: Vector2, is_viewport_pos: bool = false) -> Variant:
	if not is_instance_valid(_camera): return null
	var vp_pos: Vector2 = screen_pos
	if not is_viewport_pos:
		var sv: Vector2 = _svc.size
		if sv.x <= 0 or sv.y <= 0: return null
		vp_pos = screen_pos * Vector2(_viewport.size) / sv
	vp_pos.x = clampf(vp_pos.x, 0.0, float(_viewport.size.x))
	vp_pos.y = clampf(vp_pos.y, 0.0, float(_viewport.size.y))
	var ro: Vector3 = _camera.project_ray_origin(vp_pos)
	var rd: Vector3 = _camera.project_ray_normal(vp_pos)
	if absf(rd.y) < 0.001: return null
	var t: float = -ro.y / rd.y
	if t >= 0:
		return ro + rd * t
	return null

func _try_water_at(world_pos: Vector3) -> void:
	var best_dist := 1.3; var best_pid := ""
	for g: Dictionary in Database.get_garden(GameData.current_profile):
		# stored positions are normalized; convert to world-space before distance check
		var nx: float = float(g.get("pos_x", 0.5))
		var nz: float = float(g.get("pos_z", 0.5))
		var wx: float = lerp(-GARDEN_W*0.5, GARDEN_W*0.5, nx)
		var wz: float = lerp(-GARDEN_H*0.5, GARDEN_H*0.5, nz)
		var d := Vector2(world_pos.x - wx, world_pos.z - wz).length()
		if d < best_dist: best_dist = d; best_pid = g.get("plant_id","") as String
	if best_pid != "" and Database.water_plant(best_pid, GameData.current_profile):
		_play_water_sound()
		_status_lbl.text = "💧 Watered!"
		_status_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
		GameData.state_changed.emit()
		await get_tree().create_timer(1.4).timeout
		if is_inside_tree() and _selected_id == "":
			_status_lbl.text = "Click the catalog → then click the garden to plant"
			_status_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE)

func _update_effects() -> void:
	if not is_instance_valid(_effects_label): return
	var garden: Array = Database.get_garden(GameData.current_profile)
	if garden.is_empty(): _effects_label.text = "🌱 Plant seeds to grow garden effects"; return
	var efx: Array[String] = []
	for g: Dictionary in garden:
		var pd: Variant = _find_plant(g.get("plant_id","") as String)
		if pd and int(g.get("stage",0)) >= 1:
			var p: Dictionary = pd as Dictionary
			efx.append((p.get("emoji","") as String) + " " + (p.get("desc","") as String))
	_effects_label.text = ("✨ " + " | ".join(efx)) if not efx.is_empty() else "💧 Water plants to activate effects!"

func _open_sky() -> void:
	# night-sky view removed; stub to satisfy legacy calls
	pass

func _close_sky() -> void:
	_sky_open = false
	if is_instance_valid(_sky_view): _sky_view.queue_free(); _sky_view = null

func _debug_water_all() -> void:
	for g: Dictionary in Database.get_garden(GameData.current_profile):
		Database.water_plant(g.get("plant_id","") as String, GameData.current_profile)
	GameData.state_changed.emit()

func _debug_unwater_all() -> void:
	for g: Dictionary in Database._garden:
		if g.get("profile","") == GameData.current_profile: g.erase("last_watered")
	Database._save_garden(); GameData.state_changed.emit()

func _debug_grow_all() -> void:
	for g: Dictionary in Database._garden:
		if g.get("profile","") == GameData.current_profile:
			g["stage"] = mini(int(g.get("stage",0))+1, STAGE_MAX)
	Database._save_garden(); GameData.state_changed.emit()

func _debug_degrow_all() -> void:
	for g: Dictionary in Database._garden:
		if g.get("profile","") == GameData.current_profile:
			g["stage"] = maxi(int(g.get("stage",0))-1, 0)
	Database._save_garden(); GameData.state_changed.emit()

func _debug_plant_all() -> void:
	for plant: Dictionary in GameData.PLANT_CATALOG:
		Database.plant_seed(plant.get("id","") as String, GameData.current_profile)
	_rebuild_grass(true); GameData.state_changed.emit()

func _debug_unplant_all() -> void:
	for g: Dictionary in Database.get_garden(GameData.current_profile).duplicate():
		Database.remove_plant(g.get("plant_id","") as String, GameData.current_profile)
	_rebuild_grass(true); GameData.state_changed.emit()

func _debug_shuffle() -> void:
	var rng := RandomNumberGenerator.new(); rng.randomize()
	for g: Dictionary in Database._garden:
		if g.get("profile","") == GameData.current_profile:
			g["pos_x"] = rng.randf_range(-GARDEN_W*0.42, GARDEN_W*0.42)
			g["pos_z"] = rng.randf_range(-GARDEN_H*0.42, GARDEN_H*0.42)
	Database._save_garden(); _rebuild_grass(true); GameData.state_changed.emit()

func _debug_add_random() -> void:
	var garden: Array = Database.get_garden(GameData.current_profile)
	if garden.size() >= MAX_PLANTS: return
	var grown_ids: Array = garden.map(func(g: Dictionary) -> String: return g.get("plant_id",""))
	var unplanted: Array = []
	for p: Dictionary in GameData.PLANT_CATALOG:
		if not (p.get("id","") as String in grown_ids): unplanted.append(p)
	if unplanted.is_empty(): return
	var pick: Dictionary = unplanted[randi() % unplanted.size()]
	var rng := RandomNumberGenerator.new(); rng.randomize()
	Database.plant_seed(pick.get("id","") as String, GameData.current_profile,
		rng.randf_range(-GARDEN_W*0.42, GARDEN_W*0.42), rng.randf_range(-GARDEN_H*0.42, GARDEN_H*0.42))
	_rebuild_grass(true); GameData.state_changed.emit()

func _debug_remove_random() -> void:
	var garden: Array = Database.get_garden(GameData.current_profile)
	if garden.is_empty(): return
	Database.remove_plant(garden[randi() % garden.size()].get("plant_id","") as String, GameData.current_profile)
	_rebuild_grass(true); GameData.state_changed.emit()

func _find_plant(plant_id: String) -> Variant:
	for p: Dictionary in GameData.PLANT_CATALOG:
		if (p.get("id","") as String) == plant_id: return p
	return null

# ─────────────────────────────────────────────────────────────────
#  Water Meter
# ─────────────────────────────────────────────────────────────────
func _refresh_water_meter() -> void:
	if not is_instance_valid(_water_bar): return
	var water: float = Database.get_water_meter()
	_water_bar.value = water * 100.0
	_water_lbl.text = "Water: %d%%" % int(water * 100.0)

func _fill_water_meter() -> void:
	Database.set_water_meter(1.0)
	GameData.water_changed.emit(1.0)
	_refresh_water_meter()

func _use_water(amount: float = 0.2) -> bool:
	var current: float = Database.get_water_meter()
	if current < amount: return false
	Database.set_water_meter(current - amount)
	_refresh_water_meter()
	return true



func _pan_camera(dir: Vector2) -> void:
	if not is_instance_valid(_camera): return
	var delta := Vector3(dir.x * PAN_SPEED, 0, dir.y * PAN_SPEED)
	_camera.position += delta
	# clamp to garden bounds
	_camera.position.x = clampf(_camera.position.x, -GARDEN_W * 0.5, GARDEN_W * 0.5)
	_camera.position.z = clampf(_camera.position.z, -GARDEN_H * 0.5, GARDEN_H * 0.5)

# ─────────────────────────────────────────────────────────────────
#  Day / Night Cycle
# ─────────────────────────────────────────────────────────────────
func _start_day_night_timer() -> void:
	_day_night_timer = Timer.new()
	_day_night_timer.wait_time = 30.0  # 30s ticks for smooth gradient blending
	_day_night_timer.autostart = true
	_day_night_timer.timeout.connect(_update_day_night)
	add_child(_day_night_timer)
	call_deferred("_update_day_night")
	call_deferred("_start_firefly_system")
	call_deferred("_start_bug_system")
	call_deferred("_apply_ambience_state")

# Returns {top: Color, bot: Color} for a fractional hour (0.0–24.0)
# Transition windows:  sunset 17:00–17:15, deep dusk 17:15–20:00,
#                      night 20:00–5:00, dawn 5:00–5:15, day 6:00+
func _sky_colors_for_time(fhour: float) -> Dictionary:
	# --- colour anchors ---
	var DAY_TOP  := Color(0.0,  0.0,  0.0,  0.0)
	var DAY_BOT  := Color(0.0,  0.0,  0.0,  0.0)
	var SSET_TOP := Color(0.08, 0.0,  0.18, 0.55)   # deep violet overhead at sunset
	var SSET_BOT := Color(0.65, 0.18, 0.02, 0.45)   # warm amber/orange at horizon
	var NITE_TOP := Color(0.0,  0.01, 0.15, 0.62)   # midnight navy
	var NITE_BOT := Color(0.0,  0.02, 0.18, 0.52)
	var DAWN_TOP := Color(0.06, 0.01, 0.20, 0.40)   # pre-dawn purple
	var DAWN_BOT := Color(0.55, 0.22, 0.05, 0.35)   # warm pink/peach horizon

	if fhour >= 6.0 and fhour < 17.0:
		return {top=DAY_TOP, bot=DAY_BOT}
	elif fhour >= 17.0 and fhour < 17.25:        # 17:00–17:15 → sunset transition
		var t: float = (fhour - 17.0) / 0.25
		return {top=DAY_TOP.lerp(SSET_TOP, t), bot=DAY_BOT.lerp(SSET_BOT, t)}
	elif fhour >= 17.25 and fhour < 20.0:        # 17:15–20:00 → dusk deepening
		var t: float = (fhour - 17.25) / 2.75
		return {top=SSET_TOP.lerp(NITE_TOP, t), bot=SSET_BOT.lerp(NITE_BOT, t)}
	elif fhour >= 20.0 or fhour < 5.0:           # full night
		return {top=NITE_TOP, bot=NITE_BOT}
	elif fhour >= 5.0 and fhour < 5.25:          # 5:00–5:15 → dawn transition
		var t: float = (fhour - 5.0) / 0.25
		return {top=NITE_TOP.lerp(DAWN_TOP, t), bot=NITE_BOT.lerp(DAWN_BOT, t)}
	else:                                          # 5:15–6:00 → sunrise fade to day
		var t: float = (fhour - 5.25) / 0.75
		return {top=DAWN_TOP.lerp(DAY_TOP, t), bot=DAWN_BOT.lerp(DAY_BOT, t)}

func _update_day_night() -> void:
	if _debug_time_override: _update_day_night_debug(); return
	if not is_instance_valid(_sky_rect): return
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var hour: int   = int(now.hour)
	var minute: int = int(now.minute)
	var fhour: float = hour + minute / 60.0

	# Target = sky state 30 s from now (blends continuously into next tick)
	var target_fhour := fhour + 30.0 / 3600.0
	var cols: Dictionary = _sky_colors_for_time(target_fhour)
	var tgt_top: Color = cols.top
	var tgt_bot: Color = cols.bot

	# Kill any running sky tween and start a new 35 s one (slight overlap = no gaps)
	if _sky_tween: _sky_tween.kill()
	_sky_tween = create_tween()
	_sky_tween.set_parallel(true)
	_sky_tween.tween_method(func(c: Color): _sky_gradient.set_color(0, c), _sky_top_col, tgt_top, 35.0)
	_sky_tween.tween_method(func(c: Color): _sky_gradient.set_color(1, c), _sky_bot_col, tgt_bot, 35.0)
	_sky_top_col = tgt_top
	_sky_bot_col = tgt_bot

	if is_instance_valid(_status_lbl) and _status_lbl.text == "":
		if hour >= 20 or hour < 5:
			_status_lbl.text = "🌙 Night time in the garden…"
		elif hour >= 17:
			_status_lbl.text = "🌅 Sunset in the garden"

	_update_god_rays(fhour)
	# update ambience (day/night) whenever sky updates
	_apply_ambience_state()

# ─────────────────────────────────────────────────────────────────
#  Fireflies (night: hours 20–5)
# ─────────────────────────────────────────────────────────────────
func _is_night_time() -> bool:
	if _debug_time_override:
		return _debug_hour >= 20 or _debug_hour < 5
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var h: int = int(now.hour)
	return h >= 20 or h < 5

func _start_firefly_system() -> void:
	_firefly_timer = Timer.new()
	_firefly_timer.wait_time = 1.2
	_firefly_timer.autostart = true
	_firefly_timer.timeout.connect(_tick_fireflies)
	add_child(_firefly_timer)

func _tick_fireflies() -> void:
	if not is_instance_valid(_firefly_layer): return
	var is_night: bool = _is_night_time()
	# Spawn new firefly if night and below cap
	if is_night and _fireflies.size() < MAX_FIREFLIES:
		_spawn_firefly()
	# Kill all fireflies if day just started
	if not is_night and not _fireflies.is_empty():
		for fw in _fireflies:
			if is_instance_valid(fw): fw.queue_free()
		_fireflies.clear()

func _spawn_firefly() -> void:
	if not is_instance_valid(_firefly_layer): return
	var sz: Vector2 = _firefly_layer.size
	if sz.x <= 0: sz = Vector2(600, 400)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(4, 4)
	dot.size = Vector2(4, 4)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Firefly colors: warm yellow-green
	var colors: Array[Color] = [
		Color(0.9, 1.0, 0.3, 0.9),
		Color(0.7, 1.0, 0.2, 0.8),
		Color(1.0, 0.95, 0.1, 0.85),
	]
	dot.color = colors[randi() % colors.size()]
	var start: Vector2 = Vector2(randf_range(0.05, 0.95) * sz.x, randf_range(0.3, 0.85) * sz.y)
	dot.position = start
	_firefly_layer.add_child(dot)
	_fireflies.append(dot)
	_animate_firefly(dot, sz)

func _animate_firefly(dot: ColorRect, sz: Vector2) -> void:
	# Each firefly drifts in a random wandering path, pulsing opacity
	var lifetime: float = randf_range(6.0, 14.0)
	var _elapsed: float = 0.0
	var tw := dot.create_tween()
	tw.set_loops(0)  # will be killed when done
	tw.kill()
	# Build a multi-waypoint drift path
	var wander_tw := dot.create_tween()
	var waypoints: int = int(lifetime / 1.5)
	for _i in range(waypoints):
		var next: Vector2 = dot.position + Vector2(randf_range(-60, 60), randf_range(-40, 40))
		next.x = clampf(next.x, 0.0, sz.x - 4.0)
		next.y = clampf(next.y, sz.y * 0.25, sz.y * 0.9)
		var seg_dur: float = randf_range(1.0, 2.0)
		wander_tw.tween_property(dot, "position", next, seg_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Pulse opacity independently
	var pulse_tw := dot.create_tween()
	pulse_tw.set_loops(int(lifetime / 0.8))
	pulse_tw.tween_property(dot, "modulate:a", 0.1, randf_range(0.3, 0.6))
	pulse_tw.tween_property(dot, "modulate:a", 1.0, randf_range(0.3, 0.6))
	# Remove after lifetime
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(dot):
		wander_tw.kill(); pulse_tw.kill()
		var fade := dot.create_tween()
		fade.tween_property(dot, "modulate:a", 0.0, 0.5)
		fade.tween_callback(func():
			_fireflies.erase(dot)
			dot.queue_free())

# ─────────────────────────────────────────────────────────────────
#  Bug Paths (daytime — red dots wandering random paths)
# ─────────────────────────────────────────────────────────────────
func _start_bug_system() -> void:
	_bug_timer = Timer.new()
	_bug_timer.wait_time = 2.5
	_bug_timer.autostart = true
	_bug_timer.timeout.connect(_tick_bugs)
	add_child(_bug_timer)

func _tick_bugs() -> void:
	if not is_instance_valid(_bug_layer): return
	var is_night: bool = _is_night_time()
	# Hide bug dots at night, show during day
	for bn in _bug_nodes:
		if is_instance_valid(bn): bn.visible = not is_night
	if not is_night and _bug_nodes.size() < MAX_BUGS:
		_spawn_bug()
	if is_night:
		for bn in _bug_nodes:
			if is_instance_valid(bn): bn.queue_free()
		_bug_nodes.clear()

func _spawn_bug() -> void:
	if not is_instance_valid(_bug_layer): return
	var sz: Vector2 = _bug_layer.size
	if sz.x <= 0: sz = Vector2(600, 400)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(5, 5)
	dot.size = Vector2(5, 5)
	dot.color = Color(1.0, 0.1, 0.1, 0.85)  # red placeholder
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var start: Vector2 = Vector2(randf_range(0.1, 0.9) * sz.x, randf_range(0.35, 0.85) * sz.y)
	dot.position = start
	_bug_layer.add_child(dot)
	_bug_nodes.append(dot)
	_animate_bug(dot, sz)

func _animate_bug(dot: ColorRect, sz: Vector2) -> void:
	var lifetime: float = randf_range(8.0, 20.0)
	var wander_tw := dot.create_tween()
	var waypoints: int = int(lifetime / 1.0)
	for _i in range(waypoints):
		var next: Vector2 = dot.position + Vector2(randf_range(-45, 45), randf_range(-30, 30))
		next.x = clampf(next.x, 0.0, sz.x - 5.0)
		next.y = clampf(next.y, sz.y * 0.3, sz.y * 0.92)
		var speed: float = randf_range(0.4, 1.2)
		wander_tw.tween_property(dot, "position", next, speed).set_trans(Tween.TRANS_LINEAR)
		# Occasional pause
		if randf() < 0.25:
			wander_tw.tween_interval(randf_range(0.2, 0.8))
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(dot):
		wander_tw.kill()
		_bug_nodes.erase(dot)
		dot.queue_free()

# ─────────────────────────────────────────────────────────────────
#  Debug: Time of Day Override
# ─────────────────────────────────────────────────────────────────
var _debug_time_override: bool = false
var _debug_hour: int = -1
var _debug_minute: int = 0

func _debug_set_time(hour: int, minute: int) -> void:
	_debug_time_override = true
	_debug_hour = hour
	_debug_minute = minute
	_update_day_night_debug()
	_tick_fireflies()
	_tick_bugs()

func _debug_reset_real_time() -> void:
	_debug_time_override = false
	_debug_hour = -1
	call_deferred("_update_day_night")


# ── GDD §2 Garden Debug Functions ────────────────────────────────
func _debug_time_warp_day() -> void:
	if not GameData.is_debug_mode(): return
	var garden: Array = Database.get_garden(GameData.current_profile)
	for g: Dictionary in garden:
		var pid: String = g.get("plant_id","") as String
		# Force a water event for each plant (simulates a day passing)
		Database.water_plant(pid, GameData.current_profile)
	_show_status("⏩ Simulated 1 day of growth — watered all plants")
	GameData.state_changed.emit()

func _debug_time_warp_week() -> void:
	if not GameData.is_debug_mode(): return
	var garden: Array = Database.get_garden(GameData.current_profile)
	for _day in range(7):
		for g: Dictionary in garden:
			Database.water_plant(g.get("plant_id","") as String, GameData.current_profile)
	_show_status("⏩⏩ Simulated 7 days of growth")
	GameData.state_changed.emit()

func _debug_fill_water() -> void:
	if not GameData.is_debug_mode(): return
	Database.set_water_meter(1.0)
	if is_instance_valid(_water_bar): _water_bar.value = 1.0
	if is_instance_valid(_water_lbl): _water_lbl.text = "100%"
	GameData.water_changed.emit(1.0)
	_show_status("💧 Water meter filled!")

func _debug_force_bloom() -> void:
	if not GameData.is_debug_mode(): return
	var garden: Array = Database.get_garden(GameData.current_profile)
	for g: Dictionary in garden:
		var pid: String = g.get("plant_id","") as String
		# Water 3× to force stage 2 (Mature)
		for _i in range(3): Database.water_plant(pid, GameData.current_profile)
	_show_status("🌸 All plants forced to Mature stage!")
	GameData.state_changed.emit()

func _debug_spawn_rare_seed() -> void:
	if not GameData.is_debug_mode(): return
	# Pick a high-rarity plant from the catalog
	var rare_plants: Array = []
	for plant: Dictionary in GameData.PLANT_CATALOG:
		var rarity: String = plant.get("rarity","common") as String
		if rarity in ["rare","epic","legendary"]: rare_plants.append(plant)
	if rare_plants.is_empty():
		_show_status("⚠ No rare plants in PLANT_CATALOG"); return
	var chosen: Dictionary = rare_plants[randi() % rare_plants.size()]
	var pid: String = chosen.get("id","") as String
	var cx: float = randf_range(-4.0, 4.0)
	var cz: float = randf_range(-3.0, 3.0)
	Database.plant_seed(pid, GameData.current_profile, cx, cz)
	_show_status("🌟 Spawned rare seed: %s" % chosen.get("name","?"))
	GameData.state_changed.emit()

func _debug_force_seed_drop(forced_rarity: String) -> void:
	if not GameData.is_debug_mode(): return
	# Find any plant matching the requested rarity; fall back to any plant if none exists
	var pool: Array = []
	for plant: Dictionary in GameData.PLANT_CATALOG:
		if str(plant.get("rarity","common")).to_lower() == forced_rarity:
			pool.append(plant)
	if pool.is_empty():
		pool = GameData.PLANT_CATALOG.duplicate()
	if pool.is_empty():
		_show_status("⚠ No plants in PLANT_CATALOG"); return
	var chosen: Dictionary = (pool[randi() % pool.size()] as Dictionary).duplicate(true)
	# Override rarity so the overlay renders the requested tier
	chosen["rarity"] = forced_rarity
	var reward := {
		"contract_id":      0,
		"contract_name":    "Debug Drop",
		"profile":          GameData.current_profile,
		"reward_type":      "major" if forced_rarity in ["legendary","exotic"] else "minor",
		"plant_id":         str(chosen.get("id","")),
		"plant":            chosen,
		"rarity":           forced_rarity,
		"is_new":           true,
		"seed_refunded":    false,
		"all_plants_discovered": false,
	}
	_show_status("🎴 Force drop: %s [%s]" % [chosen.get("name","?"), forced_rarity])
	SignalBus.contract_reward_sequence.emit(reward)

func _show_status(msg: String) -> void:
	if is_instance_valid(_status_lbl):
		_status_lbl.text = msg
		_status_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)

func _update_day_night_debug() -> void:
	if not _debug_time_override: return
	if not is_instance_valid(_sky_rect): return
	var fhour: float = _debug_hour + _debug_minute / 60.0
	var cols: Dictionary = _sky_colors_for_time(fhour)
	if _sky_tween: _sky_tween.kill()
	_sky_tween = create_tween()
	_sky_tween.set_parallel(true)
	_sky_tween.tween_method(func(c: Color): _sky_gradient.set_color(0, c), _sky_top_col, cols.top as Color, 0.5)
	_sky_tween.tween_method(func(c: Color): _sky_gradient.set_color(1, c), _sky_bot_col, cols.bot as Color, 0.5)
	_sky_top_col = cols.top
	_sky_bot_col = cols.bot
	_update_god_rays(fhour, true)
	# update ambience in debug mode as well
	_apply_ambience_state()

func _apply_ambience_state() -> void:
	# Decide whether to play day or night ambience and call AudioManager once on change
	var is_night: bool = _is_night_time()
	var desired: String = "night" if is_night else "day"
	if desired == _current_ambience_mode:
		return
	_current_ambience_mode = desired
	if not has_node("/root/AudioManager"):
		return
	var am := get_node("/root/AudioManager")
	if am and am.has_method("play_ambience"):
		am.play_ambience(desired)

# ─────────────────────────────────────────────────────────────────
#  God Rays (sun / moon)
# ─────────────────────────────────────────────────────────────────
func _build_god_rays_rect(ray_color: Color, p_angle: float, p_position: float) -> TextureRect:
	var shader: Shader = load("res://shaders/garden_god_rays.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader

	# Base texture: simple vertical gradient (white → transparent)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.set_offset(0, 0.0)
	grad.set_offset(1, 1.0)
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient    = grad
	grad_tex.width       = 512
	grad_tex.height      = 512
	grad_tex.fill        = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from   = Vector2(0.5, 0.0)
	grad_tex.fill_to     = Vector2(0.5, 1.0)

	# Seamless noise texture for ray pattern
	var noise_tex := NoiseTexture2D.new()
	noise_tex.width    = 512
	noise_tex.height   = 512
	noise_tex.seamless = true
	var fnl := FastNoiseLite.new()
	fnl.frequency      = 0.5
	noise_tex.noise    = fnl

	mat.set_shader_parameter("noiseTex",        noise_tex)
	mat.set_shader_parameter("angle",           p_angle)
	mat.set_shader_parameter("position",        p_position)
	mat.set_shader_parameter("spread",          0.5)
	mat.set_shader_parameter("cutoff",          0.1)
	mat.set_shader_parameter("falloff",         0.22)
	mat.set_shader_parameter("edge_fade",       0.15)
	mat.set_shader_parameter("speed",           0.7)
	mat.set_shader_parameter("ray1_density",    8.0)
	mat.set_shader_parameter("ray2_density",    30.0)
	mat.set_shader_parameter("ray2_intensity",  0.3)
	mat.set_shader_parameter("ray_color",       ray_color)
	mat.set_shader_parameter("hdr",             false)
	mat.set_shader_parameter("seed",            randf_range(0.0, 99.0))
	mat.set_shader_parameter("pixelSizeScale",  2.0)
	mat.set_shader_parameter("quantize_colors", true)
	mat.set_shader_parameter("color_levels",    6)
	mat.set_shader_parameter("dither",          false)
	mat.set_shader_parameter("dither_strength", 0.3)
	mat.set_shader_parameter("opacity",         1.0)
	mat.set_shader_parameter("blend_mode",      0)  # Screen

	var rect := TextureRect.new()
	rect.texture      = grad_tex
	rect.material     = mat
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

# Tweens sun/moon ray opacity to match the current fractional hour.
# instant=true snaps immediately (used by debug time override).
func _update_god_rays(fhour: float, instant: bool = false) -> void:
	if not is_instance_valid(_sun_rays_rect) or not is_instance_valid(_moon_rays_rect):
		return

	# Sun rays: full during 6:00–17:00, fade at dawn (5:15–6:00) and dusk (17:00–17:25)
	var sun_alpha: float = 0.0
	if fhour >= 6.0 and fhour < 17.0:
		sun_alpha = 0.45
	elif fhour >= 5.25 and fhour < 6.0:
		sun_alpha = (fhour - 5.25) / 0.75 * 0.45
	elif fhour >= 17.0 and fhour < 17.25:
		sun_alpha = (1.0 - (fhour - 17.0) / 0.25) * 0.45

	# Moon rays: full during 20:30–5:00, fade at nightfall (20:00–20:30) and dawn (5:00–5:15)
	var moon_alpha: float = 0.0
	if fhour >= 20.5 or fhour < 5.0:
		moon_alpha = 1.0
	elif fhour >= 20.0 and fhour < 20.5:
		moon_alpha = (fhour - 20.0) / 0.5
	elif fhour >= 5.0 and fhour < 5.25:
		moon_alpha = 1.0 - (fhour - 5.0) / 0.25

	var dur: float = 0.4 if instant else 35.0
	if _rays_tween: _rays_tween.kill()
	_rays_tween = create_tween()
	_rays_tween.set_parallel(true)
	_rays_tween.tween_property(_sun_rays_rect,  "modulate:a", sun_alpha,  dur)
	_rays_tween.tween_property(_moon_rays_rect, "modulate:a", moon_alpha, dur)

# ─────────────────────────────────────────────────────────────────
#  Migration: Coordinate System Fix
# ─────────────────────────────────────────────────────────────────
# Migrates existing garden coordinates from world-space to normalized system
# This ensures plants persist correctly after the coordinate system change
func _migrate_garden_coordinates() -> void:
	if not is_instance_valid(Database):
		return
	
	var garden_data: Array = Database.get_garden(GameData.current_profile)
	var migrated: bool = false
	
	for plant_data in garden_data:
		var pos_x: float = float(plant_data.get("pos_x", 0.0))
		var pos_z: float = float(plant_data.get("pos_z", 0.0))
		
		# Check if coordinates are in world-space range (outside normalized 0-1 range)
		if pos_x < -GARDEN_W * 0.5 or pos_x > GARDEN_W * 0.5 or pos_z < -GARDEN_H * 0.5 or pos_z > GARDEN_H * 0.5:
			# This plant needs migration - convert from world-space to normalized
			var norm_x: float = clampf(inverse_lerp(-GARDEN_W * 0.5, GARDEN_W * 0.5, pos_x), 0.0, 1.0)
			var norm_z: float = clampf(inverse_lerp(-GARDEN_H * 0.5, GARDEN_H * 0.5, pos_z), 0.0, 1.0)
			
			# Update the database with normalized coordinates
			Database.move_plant(plant_data.get("plant_id", ""), GameData.current_profile, norm_x, norm_z)
			migrated = true
	
	if migrated:
		# Rebuild grass to clear any old coordinate artifacts
		_rebuild_grass(true)
		# Refresh the garden display
		_refresh()

	# Additional pass: some legacy data was saved as (0.0,0.0) unintentionally.
	# Detect plants stuck at the corner (exact or near 0.0) and relocate them to
	# a safe non-overlapping normalized position inside the garden.
	var corrected := false
	var garden_list := Database.get_garden(GameData.current_profile)
	var occupied_positions: Array = garden_list.map(func(e: Dictionary): return Vector2(float(e.get("pos_x",0.5)), float(e.get("pos_z",0.5))))
	for rec in garden_list:
		var px := float(rec.get("pos_x", 0.5))
		var pz := float(rec.get("pos_z", 0.5))
		# treat extremely small values as accidental corner placements
		if absf(px) <= 0.001 and absf(pz) <= 0.001:
			# find a random free position (try up to 40 times)
			var rng := RandomNumberGenerator.new(); rng.randomize()
			var found := false
			var nx: float = 0.5
			var nz: float = 0.5
			for i in range(40):
				nx = rng.randf_range(0.08, 0.92)
				nz = rng.randf_range(0.08, 0.92)
				var ok := true
				for op in occupied_positions:
					if Vector2(nx, nz).distance_to(op) < 0.07:
						ok = false; break
				if ok:
					found = true; break
			if not found:
				# fallback to center
				nx = 0.5; nz = 0.5
			# commit move
			var pid: String = rec.get("plant_id", "")
			Database.move_plant(pid, GameData.current_profile, nx, nz)
			occupied_positions.append(Vector2(nx, nz))
			corrected = true
			print("Garden: migrated corner plant %s -> norm(%.3f, %.3f)" % [pid, nx, nz])

	if corrected:
		_rebuild_grass(true)
		_refresh()
