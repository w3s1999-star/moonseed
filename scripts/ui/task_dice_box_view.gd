extends Control

class_name TaskDiceBoxView

signal activated(task_id: int)
signal hover_changed(is_hovered: bool)

const DEFAULT_CAMERA_SIZE := 1.78
const ACCENT_TINTS := {
	"white": Color("#d6b58a"),
	"blue": Color("#8daec8"),
	"green": Color("#8baa77"),
	"brown": Color("#9a6840"),
}
const BASE_TOP_COLOR := Color("#c4843a")
const BASE_FRONT_COLOR := Color("#a86830")
const BASE_SIDE_COLOR := Color("#8c5422")
const BASE_DARK_COLOR := Color("#6b3a12")
const OUTLINE_COLOR := Color("#f8f3ea")
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.20)
const STICKER_TEXTURE_PATH := "res://assets/textures/stickers/Sticker_default.png"
const STICKER_SCROLL_SPEED := Vector2(0.13, -0.08)
const STICKER_UV_SCALE := 0.0065
const DIE_FACE_PATHS := {
	6: "res://assets/textures/dice/d6_basic/d6_basic_%02d.png",
	8: "res://assets/textures/dice/d8_basic/d8_basic_%02d.png",
	10: "res://assets/textures/dice/d10_basic/d10_basic_%02d.png",
	12: "res://assets/textures/dice/d12_basic/d12_basic_%02d.png",
	20: "res://assets/textures/dice/d20_basic/d20_basic_%02d.png",
}
const NAME_LINE_LIMIT := 14
const NAME_LINE_COUNT := 2
const PEARLESCENT_SHADER_PATH := "res://shaders/pearlescent.gdshader"

static var _die_icon_cache: Dictionary = {}
static var _sticker_texture: Texture2D

var _pearlescent_rect: ColorRect = null

## TextureRect that renders the room composition behind the prism drawing.
var _room_bg_tex_rect: TextureRect = null

var _frame: PanelContainer
var _indicator_label: Label
var _name_label: Label
var _difficulty_label: Label
var _die_type_label: Label
var _die_icon: TextureRect
var _task_data: Dictionary = {}
var _hovered: bool = false
var _selected: bool = false
var _completed: bool = false
var _indicator_visible: bool = false
var _camera_size: float = DEFAULT_CAMERA_SIZE
var _preview_scale: float = 1.0
var _task_id: int = -1
var _sticker_uv_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_ensure_sticker_texture()
	_build_ui()
	# Apply theme colours and update on theme change
	if GameData != null and GameData.has_method("apply_theme"):
		if has_node("/root/SignalBus"):
			SignalBus.theme_changed.connect(_on_theme_changed_taskdiceview)
		_apply_label_theme()
	mouse_exited.connect(_on_mouse_exited)
	_refresh_content()

func _process(delta: float) -> void:
	# Guard: skip when not visible or completed (no sticker scroll needed)
	if not visible or _completed:
		return
	_sticker_uv_offset += STICKER_SCROLL_SPEED * delta
	queue_redraw()

	# Advance pearlescent shader time when visible and selected
	if _selected and is_instance_valid(_pearlescent_rect) and _pearlescent_rect.material:
		var mat := _pearlescent_rect.material as ShaderMaterial
		mat.set_shader_parameter("time", float(Time.get_ticks_msec()) / 1000.0)

func set_task(task_data: Dictionary) -> void:
	_task_id = int(task_data.get("id", -1))
	_task_data = task_data.duplicate(true)
	_refresh_content()

## Apply a room composition texture as the card background.
## Pass null to remove any room background (shows the default frame style).
func set_room_composition(tex: Texture2D) -> void:
	if not is_instance_valid(_room_bg_tex_rect):
		return
	if tex == null:
		_room_bg_tex_rect.texture = null
		_room_bg_tex_rect.visible = false
	else:
		_room_bg_tex_rect.texture = tex
		_room_bg_tex_rect.visible = true

func set_selected(value: bool) -> void:
	_selected = value
	_apply_frame_style()
	queue_redraw()

func set_completed(value: bool) -> void:
	_completed = value
	_apply_frame_style()
	queue_redraw()

func set_hand_indicator_visible(value: bool) -> void:
	_indicator_visible = value
	if is_instance_valid(_indicator_label):
		_indicator_label.visible = value

func set_preview_scale(value: float) -> void:
	_preview_scale = maxf(0.4, value)
	_refresh_content()

func set_camera_size(value: float) -> void:
	_camera_size = maxf(0.5, value)
	_refresh_content()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_set_hovered(_preview_rect().has_point(motion.position))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _preview_rect().has_point(mb.position):
			activated.emit(_task_id)
			get_viewport().set_input_as_handled()

func _build_ui() -> void:
	# Room composition background — sits below the frame and prism drawing.
	_room_bg_tex_rect = TextureRect.new()
	_room_bg_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room_bg_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_room_bg_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_room_bg_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room_bg_tex_rect.visible = false
	add_child(_room_bg_tex_rect)

	_frame = PanelContainer.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)

	# Pearlescent overlay for selected state
	_pearlescent_rect = ColorRect.new()
	_pearlescent_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pearlescent_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pearlescent_rect.visible = false
	_pearlescent_rect.z_index = 8
	add_child(_pearlescent_rect)
	if ResourceLoader.exists(PEARLESCENT_SHADER_PATH):
		var sh := load(PEARLESCENT_SHADER_PATH) as Shader
		if sh:
			var mat := ShaderMaterial.new()
			mat.shader = sh
			mat.set_shader_parameter("intensity", 0.18)
			_pearlescent_rect.material = mat

	_indicator_label = Label.new()
	_indicator_label.text = "🎲"
	_indicator_label.visible = false
	_indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_indicator_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	_indicator_label.add_theme_color_override("font_color", Color("#f6cd63"))
	_indicator_label.anchor_left = 1.0
	_indicator_label.anchor_top = 0.0
	_indicator_label.anchor_right = 1.0
	_indicator_label.anchor_bottom = 0.0
	_indicator_label.offset_left = -40
	_indicator_label.offset_top = 10
	_indicator_label.offset_right = -8
	_indicator_label.offset_bottom = 38
	_indicator_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_indicator_label)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	_name_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_difficulty_label = Label.new()
	# Difficulty is shown on the 3D TaskDiceBox; hide the view-level difficulty
	_difficulty_label.visible = false
	add_child(_difficulty_label)

	_die_type_label = Label.new()
	_die_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_die_type_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	_die_type_label.add_theme_color_override("font_color", Color("#2a1a0d"))
	_die_type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_die_type_label)

	_die_icon = TextureRect.new()
	_die_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_die_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_die_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_die_icon)

	_apply_frame_style()

func _on_theme_changed_taskdiceview() -> void:
	_apply_label_theme()

func _apply_label_theme() -> void:
	if is_instance_valid(_name_label):
		_name_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)

func _refresh_content() -> void:
	if not is_node_ready():
		return
	var task_name := str(_task_data.get("task", "Untitled Task"))
	if _is_water_task(task_name):
		task_name += "  💧"
	elif _is_eat_task(task_name):
		task_name += "  🍽"
	_name_label.text = _wrap_task_name(task_name)
	# Difficulty emblems are shown on the 3D TaskDiceBox; skip here
	var sides := int(_task_data.get("die_sides", 6))
	_die_type_label.text = "d%d" % sides
	var die_icon_texture := _load_die_icon(sides)
	_die_icon.texture = die_icon_texture
	_die_icon.visible = die_icon_texture != null
	_layout_overlay()
	queue_redraw()

func set_name_label_visible(value: bool) -> void:
	if is_instance_valid(_name_label):
		_name_label.visible = value

func _apply_frame_style() -> void:
	if not is_instance_valid(_frame):
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.08, 0.32, 0.95)
	if _completed:
		style.border_color = Color("#9ec9e8")
	elif _selected:
		style.border_color = Color("#f0c96a")
	elif _hovered:
		style.border_color = Color("#dbc9a1")
	else:
		style.border_color = Color(0.92, 0.84, 0.72, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	_frame.add_theme_stylebox_override("panel", style)

	# Toggle pearlescent overlay for selected cards
	if is_instance_valid(_pearlescent_rect):
		_pearlescent_rect.visible = _selected
		if _pearlescent_rect.visible and _pearlescent_rect.material:
			(_pearlescent_rect.material as ShaderMaterial).set_shader_parameter("intensity", 0.18)
		elif is_instance_valid(_pearlescent_rect) and _pearlescent_rect.material:
			(_pearlescent_rect.material as ShaderMaterial).set_shader_parameter("intensity", 0.0)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var prism_rect := _preview_rect()
	if prism_rect.size.x <= 0.0 or prism_rect.size.y <= 0.0:
		return

	var zoom := _preview_scale * clampf(DEFAULT_CAMERA_SIZE / _camera_size, 0.72, 1.35)
	var radius := minf(prism_rect.size.x, prism_rect.size.y) * 0.24 * zoom
	var half_height := radius * 0.62
	var depth := radius * 0.68
	var center := Vector2(prism_rect.get_center().x, prism_rect.position.y + prism_rect.size.y * 0.34)

	var top := PackedVector2Array([
		center + Vector2(radius, 0.0),
		center + Vector2(radius * 0.5, -half_height),
		center + Vector2(-radius * 0.5, -half_height),
		center + Vector2(-radius, 0.0),
		center + Vector2(-radius * 0.5, half_height),
		center + Vector2(radius * 0.5, half_height)
	])
	var bottom := PackedVector2Array()
	for point in top:
		bottom.append(point + Vector2(0.0, depth))

	var top_color := BASE_TOP_COLOR
	var left_color := BASE_SIDE_COLOR
	var front_color := BASE_FRONT_COLOR
	var right_color := BASE_DARK_COLOR
	if _completed:
		top_color = top_color.lightened(0.12)
		left_color = left_color.lightened(0.10)
		front_color = front_color.lightened(0.14)
		right_color = Color("#88a9bd")
	elif _selected:
		top_color = top_color.lightened(0.06)
		front_color = front_color.lightened(0.08)
		right_color = right_color.lightened(0.12)
	elif _hovered:
		top_color = top_color.lightened(0.04)
		front_color = front_color.lightened(0.04)

	var shadow_center := center + Vector2(0.0, depth + half_height * 1.15)
	var shadow_radius_x := radius * 1.02
	var shadow_radius_y := half_height * 0.6
	var shadow_points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		shadow_points.append(shadow_center + Vector2(cos(angle) * shadow_radius_x, sin(angle) * shadow_radius_y))
	draw_colored_polygon(shadow_points, SHADOW_COLOR)

	var left_face := PackedVector2Array([top[3], top[4], bottom[4], bottom[3]])
	var front_face := PackedVector2Array([top[4], top[5], bottom[5], bottom[4]])
	var right_face := PackedVector2Array([top[5], top[0], bottom[0], bottom[5]])
	draw_colored_polygon(left_face, left_color)
	draw_colored_polygon(right_face, right_color)
	draw_colored_polygon(front_face, front_color)
	draw_colored_polygon(top, top_color)
	_draw_sticker_layer(top, 0.30)
	_draw_sticker_layer(front_face, 0.22)
	_draw_sticker_layer(left_face, 0.16)
	_draw_sticker_layer(right_face, 0.14)

	var edge_color := OUTLINE_COLOR if not _completed else Color("#d9f0ff")
	draw_polyline(top + PackedVector2Array([top[0]]), edge_color, 2.0, true)
	draw_polyline(bottom + PackedVector2Array([bottom[0]]), Color(edge_color, 0.45), 2.0, true)
	draw_line(top[3], bottom[3], edge_color, 2.0, true)
	draw_line(top[4], bottom[4], edge_color, 2.0, true)
	draw_line(top[5], bottom[5], edge_color, 2.0, true)
	draw_line(top[0], bottom[0], Color(edge_color, 0.7), 2.0, true)

	var clasp_rect := Rect2(center.x - radius * 0.16, center.y + depth * 0.66, radius * 0.32, depth * 0.18)
	draw_rect(clasp_rect, Color("#8d5a33"))
	draw_rect(clasp_rect.grow(1.5), Color("#f3dec0"), false, 1.5)

func _draw_sticker_layer(face_points: PackedVector2Array, alpha: float) -> void:
	if _sticker_texture == null:
		return
	if face_points.size() < 3:
		return
	var face_colors := PackedColorArray()
	for _i in range(face_points.size()):
		face_colors.append(Color(1.0, 1.0, 1.0, alpha))
	var uvs := _build_sticker_uvs(face_points)
	draw_polygon(face_points, face_colors, uvs, _sticker_texture)

func _build_sticker_uvs(points: PackedVector2Array) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	for p in points:
		uvs.append(Vector2(
			_wrap01(p.x * STICKER_UV_SCALE + _sticker_uv_offset.x),
			_wrap01(p.y * STICKER_UV_SCALE + _sticker_uv_offset.y)
		))
	return uvs

func _wrap01(value: float) -> float:
	return value - floor(value)

func _ensure_sticker_texture() -> void:
	if _sticker_texture != null:
		return
	if not ResourceLoader.exists(STICKER_TEXTURE_PATH):
		return
	_sticker_texture = load(STICKER_TEXTURE_PATH) as Texture2D

func _layout_overlay() -> void:
	if not is_node_ready():
		return
	var prism_rect := _preview_rect()
	# Place the dice/prism preview in the upper area; move the task name below the preview
	var face_y := prism_rect.position.y + prism_rect.size.y * 0.36
	# Place the task name near the bottom of the preview so it remains visible
	var name_y := prism_rect.position.y + prism_rect.size.y * 0.86
	_name_label.position = Vector2(prism_rect.position.x + 12.0, name_y)
	_name_label.size = Vector2(prism_rect.size.x - 24.0, prism_rect.size.y * 0.14)
	# View-level difficulty removed; keep die type and icon placement
	_die_type_label.position = Vector2(prism_rect.position.x + 12.0, face_y + 6.0)
	_die_type_label.size = Vector2(prism_rect.size.x - 24.0, 22.0)
	_die_icon.position = Vector2(prism_rect.get_center().x - 18.0, face_y + 46.0)
	_die_icon.size = Vector2(36.0, 36.0)

func _preview_rect() -> Rect2:
	var margin := 14.0
	var usable := Rect2(margin, margin, maxf(0.0, size.x - margin * 2.0), maxf(0.0, size.y - margin * 2.0))
	var square_size := minf(usable.size.x, usable.size.y)
	return Rect2(usable.position.x, usable.position.y, usable.size.x, square_size)

func _set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	_apply_frame_style()
	queue_redraw()
	hover_changed.emit(value)

func _on_mouse_exited() -> void:
	_set_hovered(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_overlay()
		queue_redraw()

func _load_die_icon(sides: int) -> Texture2D:
	if _die_icon_cache.has(sides):
		return _die_icon_cache[sides] as Texture2D
	if not DIE_FACE_PATHS.has(sides):
		return null
	var face_path := (DIE_FACE_PATHS[sides] as String) % sides
	if not ResourceLoader.exists(face_path):
		return null
	var texture := load(face_path) as Texture2D
	_die_icon_cache[sides] = texture
	return texture

func _wrap_task_name(task_name: String) -> String:
	var words := task_name.split(" ", false)
	if words.size() <= 1 and task_name.length() <= NAME_LINE_LIMIT:
		return task_name
	var lines: Array[String] = []
	var current_line := ""
	for word in words:
		var candidate := word if current_line == "" else "%s %s" % [current_line, word]
		if candidate.length() <= NAME_LINE_LIMIT or current_line == "":
			current_line = candidate
		else:
			lines.append(current_line)
			current_line = word
		if lines.size() >= NAME_LINE_COUNT:
			break
	if current_line != "" and lines.size() < NAME_LINE_COUNT:
		lines.append(current_line)
	if lines.is_empty():
		lines.append(task_name)
	if lines.size() == NAME_LINE_COUNT and words.size() > 0:
		var joined := " ".join(lines)
		if joined.length() < task_name.length():
			lines[lines.size() - 1] = "%s…" % lines[lines.size() - 1].trim_suffix(".")
	return "\n".join(lines)

func _is_water_task(task_name: String) -> bool:
	var lower_name := task_name.to_lower()
	return "water" in lower_name or "hydrat" in lower_name or "drink" in lower_name

func _is_eat_task(task_name: String) -> bool:
	var lower_name := task_name.to_lower()
	return "eat" in lower_name or "food" in lower_name
