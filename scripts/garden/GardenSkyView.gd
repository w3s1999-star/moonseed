extends Control
class_name GardenSkyView

const MOON_PHASE_DISPLAY_SCRIPT := preload("res://scripts/MoonPhaseDisplay.gd")

# ─────────────────────────────────────────────────────────────────
# GardenSkyView.gd  –  Full-screen starry sky with moving moon
# Open:  W / Up Arrow / button in GardenTab
# Close: Escape / S / Down Arrow / any click
# ─────────────────────────────────────────────────────────────────

signal close_requested

var _stars:      Array = []
var _moon_t:     float = 0.0
var _fade_alpha: float = 0.0
var _closing:    bool  = false
var _font:       Font
var _moon_node:  Control

const MOON_SPEED := 0.018
const STAR_COUNT := 220
const SKY_TOP    := Color("#030510")
const SKY_HOR    := Color("#180a0a")

func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode   = Control.FOCUS_ALL
	grab_focus()
	_moon_node = MOON_PHASE_DISPLAY_SCRIPT.new()
	_moon_node.custom_minimum_size = Vector2(56, 56)
	add_child(_moon_node)
	_generate_stars()
	var tw := create_tween()
	tw.tween_method(func(v: float): _fade_alpha = v; queue_redraw(), 0.0, 1.0, 0.6)

func _generate_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 88442
	for _i in range(STAR_COUNT):
		_stars.append([
			rng.randf(),
			rng.randf() * 0.82,
			rng.randf_range(0.8, 2.6),
			rng.randf() * TAU,
			rng.randf_range(0.5, 1.0)
		])

func _process(delta: float) -> void:
	_moon_t = fmod(_moon_t + MOON_SPEED * delta, 1.0)
	_update_moon_node()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ESCAPE, KEY_S, KEY_DOWN]:
			_do_close()
	elif event is InputEventMouseButton and event.pressed:
		_do_close()

func _do_close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_method(func(v: float): _fade_alpha = v; queue_redraw(), 1.0, 0.0, 0.45)
	tw.tween_callback(func(): close_requested.emit())

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y

	# Sky gradient bands
	for i in range(28):
		var t: float = float(i) / 27.0
		draw_rect(Rect2(0.0, t * h, w, h / 27.0 + 1.0),
			SKY_TOP.lerp(SKY_HOR, pow(t, 1.8)))

	# Nebula wisps
	draw_circle(Vector2(0.2 * w, 0.25 * h), 180.0, Color(0.18, 0.1, 0.45, 0.06 * _fade_alpha))
	draw_circle(Vector2(0.65 * w, 0.38 * h), 140.0, Color(0.1, 0.22, 0.55, 0.05 * _fade_alpha))
	draw_circle(Vector2(0.45 * w, 0.15 * h), 220.0, Color(0.3, 0.08, 0.35, 0.04 * _fade_alpha))

	# Stars
	var t_ms: float = Time.get_ticks_msec() * 0.001
	for s in _stars:
		var sx: float = float(s[0]) * w
		var sy: float = float(s[1]) * h
		var twinkle: float = sin(t_ms * 1.3 + float(s[3])) * 0.22 + 0.78
		var bright: float = float(s[4]) * twinkle * _fade_alpha
		var c: Color
		if float(s[3]) < 1.5:
			c = Color(1.0, 0.92, 0.75, bright)
		elif float(s[3]) < 3.5:
			c = Color(0.8, 0.9, 1.0, bright)
		else:
			c = Color(1.0, 1.0, 1.0, bright)
		draw_circle(Vector2(sx, sy), float(s[2]) * 2.5, Color(c, bright * 0.18))
		draw_circle(Vector2(sx, sy), float(s[2]), c)

	# Shooting star (every ~11s, lasts ~0.8s)
	var cycle: float = fmod(t_ms, 11.0)
	if cycle <= 0.8:
		var prog: float = cycle / 0.8
		var sx: float = lerp(w * 0.15, w * 0.55, prog)
		var sy: float = lerp(h * 0.08, h * 0.35, prog)
		var alpha: float = sin(prog * PI) * _fade_alpha
		draw_line(
			Vector2(sx - 60.0 * 0.72, sy - 60.0 * 0.48),
			Vector2(sx, sy),
			Color(1.0, 0.95, 0.8, alpha),
			1.5
		)
		draw_circle(Vector2(sx, sy), 2.0, Color(1.0, 1.0, 0.9, alpha))

	# Horizon glow
	for i in range(8):
		var band_a: float = 0.12 * (1.0 - float(i) / 8.0) * _fade_alpha
		draw_rect(Rect2(0.0, h * 0.82 + i * 7.0, w, 8.0), Color(0.55, 0.12, 0.04, band_a))

	# Moon phase label
	var moon_data: Dictionary = GameData.get_moon_phase(Time.get_date_dict_from_system())
	draw_string(
		_font,
		Vector2(w * 0.5 - 48.0, 28.0),
		moon_data.get("name", ""),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(1.0, 0.95, 0.7, 0.75 * _fade_alpha)
	)

	# Close hint
	draw_string(
		_font,
		Vector2(w * 0.5 - 90.0, h - 18.0),
		"[ ESC / S / ↓  to close ]",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.8, 0.8, 1.0, (sin(t_ms * 0.9) * 0.3 + 0.55) * _fade_alpha)
	)

func _update_moon_node() -> void:
	if not is_instance_valid(_moon_node):
		return
	var w: float = size.x
	var h: float = size.y
	var arc_x: float = sin(_moon_t * PI)
	var mx: float = lerp(w * 0.08, w * 0.92, _moon_t)
	var my: float = clampf(
		lerp(h * 0.78, h * 0.12, arc_x) + (1.0 - arc_x) * h * 0.08,
		h * 0.08, h * 0.82
	)
	var moon_data: Dictionary = GameData.get_moon_phase(Time.get_date_dict_from_system())
	_moon_node.size = Vector2(56, 56)
	_moon_node.position = Vector2(mx - 28.0, my - 28.0)
	_moon_node.modulate = Color(1.0, 1.0, 1.0, _fade_alpha)
	_moon_node.set_phase_data(moon_data)
