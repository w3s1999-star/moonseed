extends Control

const MOON_PHASE_DISPLAY_SCRIPT := preload("res://scripts/MoonPhaseDisplay.gd")

# ─────────────────────────────────────────────────────────────────
# MoonPhaseOverlay.gd
# Full-screen popup: cloud fog shader (purple) + moon info
# • Clicking anywhere fades it away over 2 seconds
# • Emits moon_dismissed when fully gone
# ─────────────────────────────────────────────────────────────────

signal moon_dismissed

var _panel:     PanelContainer
var _cloud_mat: ShaderMaterial
var _fading:    bool = false

func show_moon(phase: Dictionary) -> void:
	_build_ui(phase)

func _dismiss() -> void:
	if _fading: return
	print("MoonPhaseOverlay: _dismiss called.")
	_fading = true
	var tw := create_tween()
	# Fade out all children via CanvasLayer's modulate (layer has no modulate, tween layer children)
	for child in get_children():
		tw.parallel().tween_property(child, "modulate:a", 0.0, 2.0)
	tw.tween_callback(func():
		print("MoonPhaseOverlay: emit_signal moon_dismissed and queue_free.")
		emit_signal("moon_dismissed")
		queue_free())

func _build_ui(phase: Dictionary) -> void:

	# Single full-screen fog background
	var fog_rect := ColorRect.new()
	fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	fog_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	fog_rect.z_index = 0
	var cloud_shader: Shader = load("res://shaders/pixel_clouds.gdshader")
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = cloud_shader
	_cloud_mat.set_shader_parameter("pixelation", Vector2(80.0, 80.0))
	# Increase scroll speeds for a more dynamic fog motion
	_cloud_mat.set_shader_parameter("scroll_speed1", Vector2(0.04, 0.012))
	_cloud_mat.set_shader_parameter("scroll_speed2", Vector2(-0.03, -0.009))
	_cloud_mat.set_shader_parameter("center_pos", Vector2(0.5, 0.5))
	# Intensify fog: stronger positional impact so clouds feel much thicker
	_cloud_mat.set_shader_parameter("position_impact", 0.98)
	_cloud_mat.set_shader_parameter("cloud_noise1",  _make_cloud_noise(0.0))
	_cloud_mat.set_shader_parameter("cloud_noise2",  _make_cloud_noise(3.7))
	_cloud_mat.set_shader_parameter("color_gradient", _make_purple_gradient())
	# Amplify noise for stronger cloud detail (max allowed by shader)
	_cloud_mat.set_shader_parameter("noise_strength", 3.0)
	# Pull fog inward so it's concentrated closer to the center (maxed for strongest effect)
	_cloud_mat.set_shader_parameter("center_focus", 5.0)
	fog_rect.material = _cloud_mat
	add_child(fog_rect)

	# Center popup
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(380, 280)
	_panel.offset_left   = -190; _panel.offset_right  = 190
	_panel.offset_top    = -140; _panel.offset_bottom = 140
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.z_index = 1
	var p_st := StyleBoxFlat.new()
	p_st.bg_color = Color(0.05, 0.01, 0.15, 0.95)
	p_st.border_color = Color(0.43, 0.11, 0.69, 1.0)
	p_st.set_border_width_all(2); p_st.set_corner_radius_all(12)
	_panel.add_theme_stylebox_override("panel", p_st)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.z_index = 2
	_panel.add_child(vbox)

	var moon_display := MOON_PHASE_DISPLAY_SCRIPT.new()
	moon_display.custom_minimum_size = Vector2(112, 112)
	moon_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	moon_display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	moon_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moon_display.z_index = 3
	moon_display.set_phase_data(phase)
	vbox.add_child(moon_display)

	var name_lbl := Label.new()
	name_lbl.text = phase.get("name","Full Moon")
	name_lbl.add_theme_color_override("font_color", Color(0.63, 0.92, 0.67, 1.0))
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(24))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.z_index = 3
	vbox.add_child(name_lbl)

	var pct_lbl := Label.new()
	pct_lbl.text = "Lunar cycle: %.1f%%" % (phase.get("pos", 0.0) * 100.0)
	pct_lbl.add_theme_color_override("font_color", Color(0.04, 0.62, 0.66, 1.0))
	pct_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pct_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pct_lbl.z_index = 3
	vbox.add_child(pct_lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = "[ click anywhere to dismiss ]"
	hint_lbl.add_theme_color_override("font_color", Color(0.5, 0.4, 0.7, 0.7))
	hint_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_lbl.z_index = 3
	vbox.add_child(hint_lbl)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	close_btn.pressed.connect(_dismiss)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.z_index = 3
	vbox.add_child(close_btn)

func _gui_input(ev: InputEvent) -> void:
	print("MoonPhaseOverlay: _gui_input triggered.")
	if ev is InputEventMouseButton and ev.pressed:
		print("MoonPhaseOverlay: Mouse button pressed, dismissing.")
		emit_signal("moon_dismissed")
		_dismiss()

func _make_cloud_noise(cloud_offset: float) -> ImageTexture:
	var tex_size := 128
	var img  := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	for y in range(tex_size):
		for x in range(tex_size):
			var fx: float = float(x) / tex_size
			var fy: float = float(y) / tex_size
			var v: float = 0.0
			v += sin((fx + cloud_offset) * 3.14159 * 4.0) * 0.4
			v += cos((fy + cloud_offset * 0.7) * 3.14159 * 6.0) * 0.3
			v += sin((fx + fy + cloud_offset) * 3.14159 * 8.0) * 0.15
			v += cos((fx * 1.3 + fy * 0.8 + cloud_offset) * 3.14159 * 3.0) * 0.15
			v = (v + 1.0) * 0.5
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)

func _make_purple_gradient() -> ImageTexture:
	# 256×1 gradient: left=dark purple sky, right=bright purple cloud
	var img := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for x in range(256):
		var t: float = float(x) / 255.0
		# Sky (low t) = deep dark purple, Cloud (high t) = bright violet
		var r: float = lerp(0.04, 0.65, t)
		var g: float = lerp(0.00, 0.10, t)
		var b: float = lerp(0.10, 0.90, t)
		# Increase overall alpha range to make fog denser and more vivid
		# Make fog much more opaque to obscure background
		var a: float = lerp(0.45, 1.0, t)
		img.set_pixel(x, 0, Color(r, g, b, a))
	return ImageTexture.create_from_image(img)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
