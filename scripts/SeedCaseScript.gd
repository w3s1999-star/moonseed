## SeedCaseScript.gd
## CS:GO-style case-opening animation for Cerulean Plant Seeds.
## Fixed-width viewport window shows ~7 cards; reel slides under a
## center selection marker. Emits seed_result(plant_id) on collect.

extends Control

# ── Rarity probability weights ────────────────────────────────────
const RARITY_WEIGHTS := {
	"common":    55,
	"uncommon":  28,
	"rare":      13,
	"epic":       3,
	"legendary":  1,
}

const RARITY_COLS := {
	"common":    Color("#aaaaaa"),
	"uncommon":  Color("#44aaff"),
	"rare":      Color("#cc44ff"),
	"epic":      Color("#ff8800"),
	"legendary": Color("#ffdd00"),
}

signal seed_result(plant_id: String)

const SETTING_SEEN_KEY := "seed_wish_seen"

# ── Layout constants ───────────────────────────────────────────────
const CARD_W      := 130
const CARD_H      := 170
const CARD_GAP    := 6
const CARD_STRIDE := CARD_W + CARD_GAP
const VISIBLE_W   := 936      # ~7.2 cards visible at once
const WIN_TARGET  := 60       # which tile index is the winner
const TOTAL_TILES := 80
const SPARKLE_STAR_SHADER_PATH := "res://shaders/seed_wish_sparkling_star.gdshader"
const STARFIELD_SHADER_PATH := "res://shaders/seed_wish_starfield.gdshader"
const USE_NEW_SEED_DROP_VFX := true

# ── Node refs ─────────────────────────────────────────────────────
var _reel_clip:  Control
var _reel_strip: Control
var _marker:     Control
var _panel:      PanelContainer
var _result_lbl: Label
var _rarity_lbl: Label
var _collect_btn: Button
var _timer:      Timer
var _bg:         ColorRect
var _title:      Label

var _wish_layer: Control
var _starfield_rect: ColorRect
var _portal:     Control
var _cloud_ring: Control
var _star:       ColorRect
var _seed_core:  Label
var _trail:      ColorRect
var _impact_flash: ColorRect
var _cloud_spiral_nodes: Array = []
var _loot_vfx_container: SubViewportContainer
var _loot_vfx_viewport: SubViewport
var _loot_vfx_root: Node3D = null

const LOOT_VFX_SCENE_PATH := "res://assets/BinbunVFX/loot_effects/loot_vfx_scene.tscn"

# ── State ─────────────────────────────────────────────────────────
var _tiles:         Array  = []
var _scroll_pos:    float  = 0.0
var _target_scroll: float  = 0.0
var _speed:         float  = 0.0
var _stopped:       bool   = false
var _decelerating:  bool   = false
var _win_plant_id:  String = ""
var _wish_running:  bool   = false
var _skip_requested: bool  = false
var _anim_speed:    float  = 1.0
var _loot_vfx_spawned: bool = false

# ── Build ─────────────────────────────────────────────────────────
func _ready() -> void:
	_build_tiles()
	_build_overlay()
	if bool(Database.get_setting(SETTING_SEEN_KEY, false)):
		_anim_speed = 1.8
	if USE_NEW_SEED_DROP_VFX:
		var won: Dictionary = _tiles[WIN_TARGET]
		_play_loot_vfx(str(won.get("rarity", "common")))
		_start_spin()
		return
	await _play_wish_sequence()
	if not _panel.visible:
		_start_spin()

func _build_tiles() -> void:
	var pool: Array = []
	for plant in GameData.PLANT_CATALOG:
		var w: int = RARITY_WEIGHTS.get(plant.get("rarity","common"), 10)
		for _i in range(w):
			pool.append(plant)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(TOTAL_TILES):
		var plant: Dictionary = pool[rng.randi() % pool.size()]
		_tiles.append({
			emoji    = plant.get("emoji",  "🌱"),
			name     = plant.get("name",   "???"),
			plant_id = plant.get("id",     ""),
			rarity   = plant.get("rarity", "common"),
			col      = RARITY_COLS.get(plant.get("rarity","common"), Color("#aaaaaa")),
		})
	_win_plant_id = _tiles[WIN_TARGET].plant_id

func _build_overlay() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100

	# Dim background
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.82)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Title
	_title = Label.new()
	_title.text = "✨  CERULEAN SEED  ✨"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
	_title.add_theme_color_override("font_color", Color("#88ccff"))
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 70; _title.offset_bottom = 108
	add_child(_title)

	_build_wish_layer()
	if USE_NEW_SEED_DROP_VFX and is_instance_valid(_wish_layer):
		_wish_layer.visible = false
	_build_loot_vfx_layer()

	# ── Reel clip container ──────────────────────────────────────
	_reel_clip = Control.new()
	_reel_clip.clip_contents = true
	_reel_clip.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reel_clip.offset_left   = -VISIBLE_W / 2
	_reel_clip.offset_right  =  VISIBLE_W / 2
	_reel_clip.offset_top    = -(CARD_H / 2 + 12)
	_reel_clip.offset_bottom =   CARD_H / 2 + 12
	_reel_clip.visible = false
	_reel_clip.modulate.a = 0.0
	add_child(_reel_clip)

	var reel_bg := ColorRect.new()
	reel_bg.color = Color("#0b0b18")
	reel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reel_clip.add_child(reel_bg)

	# Strip — tiles are manually positioned children
	_reel_strip = Control.new()
	_reel_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reel_strip.custom_minimum_size = Vector2(CARD_STRIDE * TOTAL_TILES, CARD_H)
	_reel_strip.position = Vector2(0, 12)
	_reel_clip.add_child(_reel_strip)

	for i in range(_tiles.size()):
		var card := _make_card(_tiles[i])
		card.position = Vector2(i * CARD_STRIDE, 0)
		_reel_strip.add_child(card)

	# ── Center selection marker ──────────────────────────────────
	# Drawn as a layer on top of the reel (not clipped)
	_marker = Control.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_marker.offset_left   = -(CARD_W / 2 + 4)
	_marker.offset_right  =   CARD_W / 2 + 4
	_marker.offset_top    = -(CARD_H / 2 + 16)
	_marker.offset_bottom =   CARD_H / 2 + 16
	_marker.visible = false
	_marker.modulate.a = 0.0
	add_child(_marker)

	# Four edges of the selection box
	for edge in ["top","bottom","left","right"]:
		var cr := ColorRect.new()
		cr.color = Color("#ffdd44")
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match edge:
			"top":
				cr.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
				cr.offset_bottom = 3
			"bottom":
				cr.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				cr.offset_top = -3
			"left":
				cr.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
				cr.offset_right = 3
			"right":
				cr.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
				cr.offset_left = -3
		_marker.add_child(cr)

	# ▼ top arrow
	var arr_top := Label.new()
	arr_top.text = "▼"
	arr_top.add_theme_color_override("font_color", Color("#ffdd44"))
	arr_top.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	arr_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	arr_top.offset_top = -22; arr_top.offset_bottom = 0
	arr_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arr_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.add_child(arr_top)

	# ▲ bottom arrow
	var arr_bot := Label.new()
	arr_bot.text = "▲"
	arr_bot.add_theme_color_override("font_color", Color("#ffdd44"))
	arr_bot.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	arr_bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	arr_bot.offset_top = 0; arr_bot.offset_bottom = 22
	arr_bot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arr_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.add_child(arr_bot)

	# ── Result panel (hidden) ────────────────────────────────────
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.z_index = 90
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -210; _panel.offset_right  = 210
	_panel.offset_top  = -170; _panel.offset_bottom = 170
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("#060610")
	ps.border_color = Color("#44ccff")
	ps.set_border_width_all(2); ps.set_corner_radius_all(14)
	ps.content_margin_left = 24; ps.content_margin_right  = 24
	ps.content_margin_top  = 24; ps.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", ps)
	add_child(_panel)

	var pvbox := VBoxContainer.new()
	pvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pvbox.add_theme_constant_override("separation", 12)
	_panel.add_child(pvbox)

	var got_lbl := Label.new()
	got_lbl.text = "YOU RECEIVED"
	got_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	got_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	got_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	pvbox.add_child(got_lbl)

	_result_lbl = Label.new()
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(30))
	pvbox.add_child(_result_lbl)

	_rarity_lbl = Label.new()
	_rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rarity_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	pvbox.add_child(_rarity_lbl)

	_collect_btn = Button.new()
	_collect_btn.text = "🌱  Plant Seed"
	_collect_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	_collect_btn.custom_minimum_size = Vector2(160, 42)
	_collect_btn.pressed.connect(_on_collect_pressed)
	pvbox.add_child(_collect_btn)

	_timer = Timer.new()
	_timer.wait_time = 0.07
	_timer.autostart = false
	_timer.timeout.connect(_on_timer_tick)
	add_child(_timer)


func _build_loot_vfx_layer() -> void:
	_loot_vfx_container = SubViewportContainer.new()
	_loot_vfx_container.visible = false
	_loot_vfx_container.stretch = true
	_loot_vfx_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loot_vfx_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_loot_vfx_container.offset_left = -280
	_loot_vfx_container.offset_right = 280
	_loot_vfx_container.offset_top = -280
	_loot_vfx_container.offset_bottom = 280
	_loot_vfx_container.z_index = 80
	add_child(_loot_vfx_container)

	_loot_vfx_viewport = SubViewport.new()
	_loot_vfx_viewport.size = Vector2i(560, 560)
	_loot_vfx_viewport.transparent_bg = true
	_loot_vfx_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_loot_vfx_container.add_child(_loot_vfx_viewport)

func _build_wish_layer() -> void:
	_wish_layer = Control.new()
	_wish_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wish_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wish_layer)

	_starfield_rect = ColorRect.new()
	_starfield_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_starfield_rect.color = Color(1, 1, 1, 1)
	_starfield_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(STARFIELD_SHADER_PATH):
		var sf_shader := load(STARFIELD_SHADER_PATH) as Shader
		if sf_shader != null:
			var sf_material := ShaderMaterial.new()
			sf_material.shader = sf_shader
			_starfield_rect.material = sf_material
	_wish_layer.add_child(_starfield_rect)

	_portal = Panel.new()
	_portal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_portal.offset_left = -150
	_portal.offset_top = -150
	_portal.offset_right = 150
	_portal.offset_bottom = 150
	var portal_st := StyleBoxFlat.new()
	portal_st.bg_color = Color(0.1, 0.2, 0.4, 0.35)
	portal_st.border_color = Color("#88ccff")
	portal_st.set_border_width_all(3)
	portal_st.set_corner_radius_all(999)
	_portal.add_theme_stylebox_override("panel", portal_st)
	_portal.scale = Vector2(0.55, 0.55)
	_portal.modulate.a = 0.0
	_wish_layer.add_child(_portal)

	_cloud_ring = Panel.new()
	_cloud_ring.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cloud_ring.offset_left = -210
	_cloud_ring.offset_top = -90
	_cloud_ring.offset_right = 210
	_cloud_ring.offset_bottom = 90
	var ring_st := StyleBoxFlat.new()
	ring_st.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	ring_st.border_color = Color(1.0, 1.0, 1.0, 0.0)
	ring_st.set_border_width_all(4)
	ring_st.set_corner_radius_all(999)
	_cloud_ring.add_theme_stylebox_override("panel", ring_st)
	_wish_layer.add_child(_cloud_ring)

	for i in range(9):
		var cloud := Label.new()
		cloud.text = "☁"
		cloud.add_theme_font_size_override("font_size", GameData.scaled_font_size(30 + (i % 3) * 4))
		cloud.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0, 0.0))
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloud.position = Vector2(-1000, -1000)
		_wish_layer.add_child(cloud)
		_cloud_spiral_nodes.append(cloud)

	_trail = ColorRect.new()
	_trail.custom_minimum_size = Vector2(120, 8)
	_trail.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_trail.color = Color(0.3, 0.6, 1.0, 0.0)
	_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wish_layer.add_child(_trail)

	_star = ColorRect.new()
	_star.custom_minimum_size = Vector2(120, 120)
	_star.size = Vector2(120, 120)
	_star.color = Color(1, 1, 1, 1)
	_star.pivot_offset = Vector2(60, 60)
	_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star.modulate.a = 0.0
	if ResourceLoader.exists(SPARKLE_STAR_SHADER_PATH):
		var star_shader := load(SPARKLE_STAR_SHADER_PATH) as Shader
		if star_shader != null:
			var star_material := ShaderMaterial.new()
			star_material.shader = star_shader
			_star.material = star_material
	_wish_layer.add_child(_star)

	_seed_core = Label.new()
	_seed_core.text = "🌱"
	_seed_core.add_theme_font_size_override("font_size", GameData.scaled_font_size(34))
	_seed_core.add_theme_color_override("font_color", Color("#d7ff88"))
	_seed_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed_core.modulate.a = 0.0
	_seed_core.scale = Vector2(0.45, 0.45)
	_wish_layer.add_child(_seed_core)

	_impact_flash = ColorRect.new()
	_impact_flash.color = Color(1, 1, 1, 0)
	_impact_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_impact_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wish_layer.add_child(_impact_flash)

func _make_card(tile: Dictionary) -> PanelContainer:
	var rcol: Color = tile.col
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(CARD_W, CARD_H)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var st := StyleBoxFlat.new()
	st.bg_color = Color(rcol.r * 0.07, rcol.g * 0.07, rcol.b * 0.12, 1.0)
	st.border_color = Color(rcol.r * 0.35, rcol.g * 0.35, rcol.b * 0.35, 1.0)
	st.set_border_width_all(1); st.set_corner_radius_all(6)
	st.content_margin_left = 0; st.content_margin_right  = 0
	st.content_margin_top  = 0; st.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", st)

	# Outer VBox so rarity bar can sit flush at bottom
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(outer)

	# Card body with padding
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(body)

	var pad_top := Control.new()
	pad_top.custom_minimum_size = Vector2(0, 12)
	pad_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(pad_top)

	var emoji_lbl := Label.new()
	emoji_lbl.text = tile.emoji
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(42))
	emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(emoji_lbl)

	var name_lbl := Label.new()
	name_lbl.text = tile.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	name_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(name_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(spacer)

	# Rarity colour bar — flush bottom
	var bar := ColorRect.new()
	bar.color = rcol
	bar.custom_minimum_size = Vector2(CARD_W, 7)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(bar)

	return p

# ── Spin logic ────────────────────────────────────────────────────
func _start_spin() -> void:
	# Target: centre of WIN_TARGET tile aligned to centre of viewport
	_target_scroll = WIN_TARGET * CARD_STRIDE + CARD_W / 2.0 - VISIBLE_W / 2.0
	_speed = 95.0 * _anim_speed
	_decelerating = false
	_stopped = false
	_reveal_reel_stage()
	# Begin decel phase after fast spin
	var delay := get_tree().create_timer(2.4 / _anim_speed)
	delay.timeout.connect(func():
		if not _stopped:
			_decelerating = true
			_timer.start()
	)

func _process(delta: float) -> void:
	if _stopped:
		return
	_scroll_pos += _speed * delta * 60.0
	# Clamp overshoot: once decelerating and we've reached or passed target, snap and stop
	if _decelerating:
		if _scroll_pos >= _target_scroll:
			_scroll_pos = _target_scroll
			_stopped = true
			_timer.stop()
			_show_result()
	else:
		# During fast phase: wrap the scroll so the strip never runs out
		var strip_total: float = CARD_STRIDE * TOTAL_TILES
		if _scroll_pos > strip_total - VISIBLE_W - CARD_STRIDE * 20:
			# Too close to the end — nudge target and wrap by shifting back one full loop
			# This should not happen with 80 tiles and WIN_TARGET=60, but guard anyway
			_scroll_pos = fmod(_scroll_pos, strip_total - VISIBLE_W)
	_reel_strip.position.x = -_scroll_pos

func _on_timer_tick() -> void:
	if _stopped: return
	var remaining: float = _target_scroll - _scroll_pos
	if remaining <= 0.0:
		# _process will detect this on next frame and call _show_result
		_timer.stop()
		return
	_speed = max(3.5, remaining * (0.16 * _anim_speed))

func _play_wish_sequence() -> void:
	_wish_running = true
	_skip_requested = false

	var rarity_col := _winner_color()
	var viewport_size := get_viewport_rect().size
	var sky_center := get_viewport_rect().size * Vector2(0.5, 0.26)
	var fall_start := viewport_size * Vector2(0.48, 0.18)
	var drift_mid := viewport_size * Vector2(0.58, 0.24)
	var fall_end := viewport_size * Vector2(0.5, 0.82)
	var star_half := _star.size * 0.5
	var portal_st := _portal.get_theme_stylebox("panel") as StyleBoxFlat
	if portal_st != null:
		portal_st.border_color = rarity_col.lightened(0.25)
	var star_material := _star.material as ShaderMaterial
	if star_material != null:
		star_material.set_shader_parameter("star_color", Color(rarity_col.r, rarity_col.g, rarity_col.b, 1.0))
		star_material.set_shader_parameter("shney_speed", 0.75)
		star_material.set_shader_parameter("twist_speed", 0.9)
		star_material.set_shader_parameter("rota_speed", 1.8)
		star_material.set_shader_parameter("shney_disperse", 1.0)
	_portal.position = Vector2(0, -220)
	_cloud_ring.position = Vector2(0, -220)
	_cloud_ring.modulate.a = 0.0
	_wish_layer.pivot_offset = viewport_size * 0.5
	_wish_layer.scale = Vector2.ONE
	_wish_layer.position = Vector2.ZERO
	_star.scale = Vector2.ONE
	_seed_core.scale = Vector2(0.45, 0.45)
	_seed_core.modulate.a = 0.0

	# Phase 1: Clouds spiral in the sky
	_title.text = "CLOUDS GATHER"
	var intro := create_tween().set_parallel(true)
	intro.tween_property(_bg, "color:a", 0.9, 0.3 / _anim_speed)
	intro.tween_property(_portal, "modulate:a", 1.0, 0.28 / _anim_speed)
	intro.tween_property(_portal, "scale", Vector2.ONE, 0.36 / _anim_speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await intro.finished
	if _skip_requested:
		_skip_to_result()
		return

	for i in range(_cloud_spiral_nodes.size()):
		var cloud := _cloud_spiral_nodes[i] as Label
		if cloud == null:
			continue
		var angle := float(i) * 0.72
		var radius := 320.0 + (i % 3) * 35.0
		var start := sky_center + Vector2(cos(angle), sin(angle)) * radius
		var swirl := sky_center + Vector2(cos(angle + 2.2), sin(angle + 2.2)) * 110.0
		cloud.position = start
		cloud.modulate = Color(1, 1, 1, 0.0)
		var ct := create_tween().set_parallel(true)
		ct.tween_property(cloud, "modulate:a", 0.9, 0.16 / _anim_speed)
		ct.tween_property(cloud, "position", swirl, 0.62 / _anim_speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ct.chain().tween_property(cloud, "modulate:a", 0.15, 0.24 / _anim_speed)
	await get_tree().create_timer(0.68 / _anim_speed).timeout
	if _skip_requested:
		_skip_to_result()
		return

	# Phase 2: Star falls from the cloud ring
	_title.text = "A STAR DESCENDS"
	_trail.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.75)
	_star.position = fall_start - star_half
	_star.modulate.a = 1.0
	_trail.position = fall_start - Vector2(0, 125)
	_trail.modulate.a = 0.0
	_seed_core.position = fall_start

	var ring_st := _cloud_ring.get_theme_stylebox("panel") as StyleBoxFlat
	if ring_st != null:
		ring_st.border_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.95)
	var ring_burst := create_tween().set_parallel(true)
	ring_burst.tween_property(_cloud_ring, "modulate:a", 1.0, 0.08 / _anim_speed)
	ring_burst.tween_property(_cloud_ring, "scale", Vector2(1.12, 1.12), 0.14 / _anim_speed)
	ring_burst.chain().tween_property(_cloud_ring, "modulate:a", 0.0, 0.26 / _anim_speed)
	ring_burst.tween_property(_impact_flash, "color", Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.4), 0.08 / _anim_speed)
	ring_burst.chain().tween_property(_impact_flash, "color", Color(1, 1, 1, 0.0), 0.18 / _anim_speed)

	var fall := create_tween().set_parallel(true)
	fall.tween_property(_star, "position", drift_mid - star_half, 0.36 / _anim_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fall.tween_property(_trail, "position", drift_mid - Vector2(40, 150), 0.36 / _anim_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fall.tween_property(_trail, "modulate:a", 0.85, 0.16 / _anim_speed)
	await fall.finished
	if _skip_requested:
		_skip_to_result()
		return

	if star_material != null:
		star_material.set_shader_parameter("shney_speed", 1.5)
		star_material.set_shader_parameter("twist_speed", 1.35)
		star_material.set_shader_parameter("rota_speed", 3.4)
		star_material.set_shader_parameter("shney_disperse", 0.8)

	var accel := create_tween().set_parallel(true)
	accel.tween_property(_star, "position", fall_end - star_half, 0.44 / _anim_speed).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	accel.tween_property(_trail, "position", fall_end - Vector2(0, 200), 0.44 / _anim_speed).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	accel.tween_property(_trail, "modulate:a", 1.0, 0.08 / _anim_speed)
	accel.tween_property(_star, "scale", Vector2(1.18, 1.18), 0.44 / _anim_speed)
	accel.tween_property(_wish_layer, "scale", Vector2(1.07, 1.07), 0.44 / _anim_speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	accel.tween_property(_wish_layer, "position", Vector2(-viewport_size.x * 0.035, -viewport_size.y * 0.05), 0.44 / _anim_speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await accel.finished
	if _skip_requested:
		_skip_to_result()
		return

	# Phase 3: Camera zoom into star, seed appears inside
	_title.text = "SEED REVEAL"
	_seed_core.text = _tiles[WIN_TARGET].emoji
	_seed_core.position = _star.position + star_half
	var zoom := create_tween().set_parallel(true)
	zoom.tween_property(_star, "position", get_viewport_rect().size * Vector2(0.5, 0.52) - star_half, 0.28 / _anim_speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	zoom.tween_property(_star, "scale", Vector2(7.0, 7.0), 0.42 / _anim_speed).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	zoom.tween_property(_trail, "modulate:a", 0.0, 0.22 / _anim_speed)
	zoom.tween_property(_seed_core, "position", get_viewport_rect().size * Vector2(0.5, 0.52), 0.28 / _anim_speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	zoom.tween_property(_seed_core, "modulate:a", 1.0, 0.24 / _anim_speed).set_delay(0.12 / _anim_speed)
	zoom.tween_property(_seed_core, "scale", Vector2(1.2, 1.2), 0.34 / _anim_speed).set_delay(0.1 / _anim_speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	zoom.tween_property(_wish_layer, "scale", Vector2(1.0, 1.0), 0.24 / _anim_speed)
	zoom.tween_property(_wish_layer, "position", Vector2.ZERO, 0.24 / _anim_speed)
	await zoom.finished
	if _skip_requested:
		_skip_to_result()
		return

	# Phase 4: Impact / transition flash
	var pulse := create_tween().set_parallel(true)
	pulse.tween_property(_seed_core, "scale", Vector2(1.5, 1.5), 0.09 / _anim_speed)
	pulse.tween_property(_star, "modulate:a", 0.25, 0.09 / _anim_speed)
	pulse.chain().tween_property(_seed_core, "scale", Vector2(1.2, 1.2), 0.12 / _anim_speed)
	await pulse.finished

	var flash := create_tween().set_parallel(true)
	flash.tween_property(_impact_flash, "color", Color(1, 1, 1, 0.96), 0.1 / _anim_speed)
	flash.chain().tween_property(_impact_flash, "color", Color(1, 1, 1, 0.0), 0.2 / _anim_speed)
	flash.tween_property(_star, "modulate:a", 0.0, 0.1 / _anim_speed)
	flash.tween_property(_seed_core, "modulate:a", 0.0, 0.1 / _anim_speed)
	flash.tween_property(_trail, "modulate:a", 0.0, 0.1 / _anim_speed)
	await flash.finished

	var outro := create_tween().set_parallel(true)
	outro.tween_property(_portal, "modulate:a", 0.0, 0.18 / _anim_speed)
	outro.tween_property(_wish_layer, "modulate:a", 0.0, 0.18 / _anim_speed)
	await outro.finished

	_wish_running = false
	Database.save_setting(SETTING_SEEN_KEY, true)

func _reveal_reel_stage() -> void:
	_reel_clip.visible = true
	_marker.visible = true
	_title.text = "REWARD PATH"
	var t := create_tween().set_parallel(true)
	t.tween_property(_reel_clip, "modulate:a", 1.0, 0.2 / _anim_speed)
	t.tween_property(_marker, "modulate:a", 1.0, 0.2 / _anim_speed)

func _skip_to_result() -> void:
	_skip_requested = true
	_wish_running = false
	if is_instance_valid(_timer):
		_timer.stop()
	if is_instance_valid(_wish_layer):
		_wish_layer.modulate.a = 0.0
	if is_instance_valid(_portal):
		_portal.modulate.a = 0.0
	if is_instance_valid(_seed_core):
		_seed_core.modulate.a = 0.0

	_target_scroll = WIN_TARGET * CARD_STRIDE + CARD_W / 2.0 - VISIBLE_W / 2.0
	_scroll_pos = _target_scroll
	_reel_strip.position.x = -_scroll_pos
	_reveal_reel_stage()
	_stopped = true
	_decelerating = false
	_show_result()

func _winner_color() -> Color:
	if _tiles.is_empty():
		return Color("#88ccff")
	return _tiles[WIN_TARGET].col


func _play_loot_vfx(rarity: String) -> void:
	if not is_instance_valid(_loot_vfx_container) or not is_instance_valid(_loot_vfx_viewport):
		return
	if not ResourceLoader.exists(LOOT_VFX_SCENE_PATH):
		push_warning("Loot VFX scene missing: " + LOOT_VFX_SCENE_PATH)
		return

	for child in _loot_vfx_viewport.get_children():
		child.queue_free()
	_loot_vfx_root = (load(LOOT_VFX_SCENE_PATH) as PackedScene).instantiate() as Node3D
	_loot_vfx_viewport.add_child(_loot_vfx_root)
	_configure_loot_vfx_root(str(rarity).to_lower())
	_loot_vfx_container.visible = true
	_loot_vfx_spawned = true

	var t := get_tree().create_timer(1.4 / _anim_speed)
	t.timeout.connect(func():
		if is_instance_valid(_loot_vfx_root):
			_loot_vfx_root.queue_free()
		_loot_vfx_root = null
		if is_instance_valid(_loot_vfx_container):
			_loot_vfx_container.visible = false
	)


func _configure_loot_vfx_root(rarity_key: String) -> void:
	if not is_instance_valid(_loot_vfx_root):
		return
	var target_name: String = str({
		"common": "LootVFX_Common",
		"uncommon": "LootVFX_Uncommon",
		"rare": "LootVFX_Rare",
		"epic": "LootVFX_Epic",
		"legendary": "LootVFX_Legendary",
		"mythic": "LootVFX_Mythic",
	}.get(rarity_key, "LootVFX_Common"))

	var floating := _loot_vfx_root.get_node_or_null("Floating") as Node3D
	if floating != null:
		for c in floating.get_children():
			if c is Node3D and c.name != target_name:
				(c as Node3D).queue_free()
		var chosen := floating.get_node_or_null(target_name) as Node3D
		if chosen != null:
			chosen.visible = true
			chosen.position = Vector3(0, 1, 0)
		else:
			push_warning("Loot VFX rarity node not found: " + target_name)
	else:
		push_warning("Loot VFX root missing Floating node")

	var ground := _loot_vfx_root.get_node_or_null("Ground") as Node3D
	if ground != null:
		ground.visible = false

	var env_ground := _loot_vfx_root.get_node_or_null("Environment/StaticBody3D/Ground") as MeshInstance3D
	if env_ground != null:
		env_ground.visible = false

	var we := _loot_vfx_root.get_node_or_null("Environment/WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.background_mode = Environment.BG_COLOR
		we.environment.background_color = Color(0, 0, 0, 0)
		we.environment.sky = null
		we.environment.fog_enabled = false
		we.environment.volumetric_fog_enabled = false


func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		_skip_to_result()
		accept_event()
		return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE):
		_skip_to_result()
		accept_event()

func _show_result() -> void:
	if _panel.visible:
		return
	var won: Dictionary = _tiles[WIN_TARGET]
	_result_lbl.text = "%s  %s" % [won.emoji, won.name]
	_result_lbl.add_theme_color_override("font_color", won.col)
	_rarity_lbl.text = won.rarity.capitalize()
	_rarity_lbl.add_theme_color_override("font_color", won.col)
	_highlight_winner()
	if not USE_NEW_SEED_DROP_VFX or not _loot_vfx_spawned:
		_play_loot_vfx(str(won.get("rarity", "common")))
	await get_tree().create_timer(0.3 / _anim_speed).timeout
	_panel.show()

func _highlight_winner() -> void:
	if WIN_TARGET >= _reel_strip.get_child_count(): return
	var card := _reel_strip.get_child(WIN_TARGET) as PanelContainer
	if not card: return
	var wcol: Color = _tiles[WIN_TARGET].col
	var st := StyleBoxFlat.new()
	st.bg_color = Color(wcol.r * 0.2, wcol.g * 0.2, wcol.b * 0.25, 1.0)
	st.border_color = wcol
	st.set_border_width_all(3); st.set_corner_radius_all(6)
	st.content_margin_left = 0; st.content_margin_right  = 0
	st.content_margin_top  = 0; st.content_margin_bottom = 0
	card.add_theme_stylebox_override("panel", st)

func _on_collect_pressed() -> void:
	seed_result.emit(_win_plant_id)
	if is_instance_valid(_loot_vfx_root):
		_loot_vfx_root.queue_free()
		_loot_vfx_root = null
	if is_instance_valid(_loot_vfx_container):
		_loot_vfx_container.visible = false
	queue_free()
