class_name StudioPaintCanvas
extends Control

# ─────────────────────────────────────────────────────────────────
# studio_paint_canvas.gd – Free-draw paint overlay for the Card Studio.
#
# Placed as a transparent overlay node on top of card_root in the
# satchel studio popup.  When "Paint Mode" is OFF the node has
# MOUSE_FILTER_IGNORE so sticker slot buttons visible underneath it
# still receive click events normally.  The parent toggles
# mouse_filter to MOUSE_FILTER_STOP to activate painting.
#
# Persistence
#   get_paint_data()   → serialises the canvas Image as PNG base64 in
#                        a plain Dictionary → stored in StudioRoomData.paint_data
#   load_paint_data()  → decodes the PNG base64 back into the live Image
#
# Undo/Redo readiness (requirement 10)
#   Every completed drag stroke is appended to _strokes as a lightweight
#   record.  No undo is wired yet, but the data structure is in place so
#   a future implementation only needs to add a replay-from-strokes pass.
# ─────────────────────────────────────────────────────────────────

## Emitted after every paint action so the parent can mark the room dirty.
signal canvas_modified

## Internal image resolution.  2× the card display size (230×320) gives
## sub-pixel smoothness without heavy memory cost.
const CANVAS_WIDTH  := 460
const CANVAS_HEIGHT := 640

enum Tool { BRUSH, ERASER }

## Active tool; set directly from the paint panel buttons.
var current_tool: Tool = Tool.BRUSH

## Active brush colour; set directly from the palette buttons.
var brush_color: Color = Color("#1a1a1a")

## Brush radius measured in internal canvas pixels.
var brush_size: int = 6

# ── Internal state ────────────────────────────────────────────────
var _image:   Image
var _texture: ImageTexture
var _tex_rect: TextureRect

var _painting: bool = false

## Completed stroke records — reserved for future undo/redo.
## Each entry: { points: Array, color: Color, size: int, eraser: bool }
var _strokes: Array = []
var _current_stroke_points: Array = []


func _ready() -> void:
	_image = Image.create(CANVAS_WIDTH, CANVAS_HEIGHT, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0.0, 0.0, 0.0, 0.0))

	_texture = ImageTexture.create_from_image(_image)

	_tex_rect = TextureRect.new()
	_tex_rect.texture = _texture
	_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex_rect)

	# Starts transparent to input; the parent enables when paint mode is on.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_painting = true
				_current_stroke_points = []
				_paint_at(mb.position)
			else:
				if _painting and not _current_stroke_points.is_empty():
					_strokes.append({
						points = _current_stroke_points.duplicate(),
						color  = brush_color,
						size   = brush_size,
						eraser = (current_tool == Tool.ERASER),
					})
				_painting = false
	elif event is InputEventMouseMotion:
		if _painting:
			_paint_at(event.position)


# ── Public API ────────────────────────────────────────────────────

## Encode the current canvas image as PNG base64 for persistence.
## Returns {} if the image could not be encoded.
func get_paint_data() -> Dictionary:
	var png_bytes := _image.save_png_to_buffer()
	if png_bytes.is_empty():
		return {}
	return {
		png_b64 = Marshalls.raw_to_base64(png_bytes),
		width   = CANVAS_WIDTH,
		height  = CANVAS_HEIGHT,
	}


## Restore the canvas from a previously saved paint_data dictionary.
## Safe to call with an empty dict (no-op).
func load_paint_data(d: Dictionary) -> void:
	if d.is_empty() or not d.has("png_b64"):
		return
	var raw: PackedByteArray = Marshalls.base64_to_raw(str(d.get("png_b64", "")))
	if raw.is_empty():
		return
	var img := Image.new()
	if img.load_png_from_buffer(raw) != OK:
		push_warning("StudioPaintCanvas.load_paint_data: failed to decode PNG")
		return
	_image = img
	_texture.update(_image)
	_strokes.clear()


## Fill the canvas with full transparency.
func clear_canvas() -> void:
	_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_texture.update(_image)
	_strokes.clear()
	_current_stroke_points.clear()
	canvas_modified.emit()


# ── Internal helpers ──────────────────────────────────────────────

func _paint_at(local_pos: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	# Map local pixel position → internal canvas coordinates.
	var cx: float = local_pos.x / size.x * float(CANVAS_WIDTH)
	var cy: float = local_pos.y / size.y * float(CANVAS_HEIGHT)
	var ix := int(cx)
	var iy := int(cy)

	var erase := (current_tool == Tool.ERASER)
	var c     := brush_color if not erase else Color(0.0, 0.0, 0.0, 0.0)
	var r     := brush_size

	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				var px := ix + dx
				var py := iy + dy
				if px >= 0 and px < CANVAS_WIDTH and py >= 0 and py < CANVAS_HEIGHT:
					_image.set_pixel(px, py, c)

	_current_stroke_points.append({x = cx, y = cy})
	_texture.update(_image)
	canvas_modified.emit()
