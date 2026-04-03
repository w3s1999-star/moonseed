class_name StudioRoomCompositor
extends RefCounted

# ─────────────────────────────────────────────────────────────────
# StudioRoomCompositor.gd
#
# Pure composition utility: builds a single ImageTexture from one
# StudioRoomData record.  No scene nodes; no state.  Call
# compose_room() from any context that needs the rendered result.
#
# Composition order (bottom → top)
#   1. Card base texture   – determined by room_data["card_color"]
#   2. Paint layer         – room_data["paint_data"] PNG-base64 image
#   3. Sticker layer       – each entry in room_data["stickers"]
#
# Output resolution
#   The compositor always works at CANVAS_SIZE (460 × 640 px) — the
#   same internal resolution used by StudioPaintCanvas.  Callers that
#   need a different display size let the engine scale the texture.
#
# Fallback behaviour
#   - Missing card base → solid mid-tone rectangle
#   - Missing / invalid paint_data → layer is skipped (transparent)
#   - Missing / invalid sticker texture → sticker is skipped
#   If ALL layers are absent or empty a recognisable placeholder is
#   drawn so callers never receive a null texture (requirement #5).
# ─────────────────────────────────────────────────────────────────


# ══════════════════════════════════════════════════════════════════
# CONSTANTS
# ══════════════════════════════════════════════════════════════════

const CANVAS_WIDTH  := 460
const CANVAS_HEIGHT := 640

const CARD_BASE_TEXTURES := {
	"white": "res://assets/textures/Card Base/Card_Base_White.png",
	"blue":  "res://assets/textures/Card Base/Card_Base_Blue.png",
	"green": "res://assets/textures/Card Base/Card_Base_Green.png",
	"brown": "res://assets/textures/Card Base/Card_Base_Brown.png",
}

## Fallback colours when a named card texture does not exist on disk.
const FALLBACK_CARD_COLORS := {
	"white": Color("#d6c9a8"),
	"blue":  Color("#7ca4c0"),
	"green": Color("#7aaa66"),
	"brown": Color("#8a5c30"),
}

const DEFAULT_FALLBACK_COLOR   := Color("#c4a46a")
const STICKER_DEFAULT_PATH     := "res://assets/textures/stickers/Sticker_default.png"
## Pixel size budget for one sticker when stamped onto the canvas.
const STICKER_STAMP_SIZE       := Vector2(80.0, 80.0)


# ══════════════════════════════════════════════════════════════════
# MODULE-LEVEL TEXTURE CACHE (shared across all instances / calls)
# ══════════════════════════════════════════════════════════════════

## Caches loaded Texture2D resources to avoid redundant disk reads
## within the same session.  Keys are res:// paths; values are arrays
## [attempts, Texture2D|null].  A null value means the path was tried
## and was not found; we do not retry those.
static var _tex_cache: Dictionary = {}


# ══════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════

## Compose a full-resolution ImageTexture from a raw room-data dict.
## Returns a valid ImageTexture every time — never null.
## Pass an empty/invalid dict to get the no-content placeholder.
static func compose_room(room_data: Dictionary) -> ImageTexture:
	var canvas := _make_canvas()

	var any_content := false
	any_content = _draw_base_layer(canvas, room_data) or any_content
	any_content = _draw_paint_layer(canvas, room_data) or any_content
	any_content = _draw_sticker_layer(canvas, room_data) or any_content

	if not any_content:
		_draw_empty_fallback(canvas, room_data)

	return ImageTexture.create_from_image(canvas)


## Returns true when room_data contains at least one non-default visual.
## Useful for deciding whether to show a placeholder banner.
static func has_content(room_data: Dictionary) -> bool:
	if not room_data.is_empty():
		var pd: Variant = room_data.get("paint_data", {})
		if pd is Dictionary and not (pd as Dictionary).is_empty():
			return true
		var st: Variant = room_data.get("stickers", [])
		if st is Array:
			for entry in (st as Array):
				if entry is Dictionary and not (entry as Dictionary).is_empty():
					return true
	return false


# ══════════════════════════════════════════════════════════════════
# LAYER RENDERERS
# ══════════════════════════════════════════════════════════════════

static func _draw_base_layer(canvas: Image, room_data: Dictionary) -> bool:
	var color_key: String = str(room_data.get("card_color", "white"))
	var tex_path: String = CARD_BASE_TEXTURES.get(color_key, CARD_BASE_TEXTURES["white"])

	var base_tex := _load_texture(tex_path)
	if base_tex != null:
		var base_img := base_tex.get_image()
		if base_img != null:
			base_img.resize(CANVAS_WIDTH, CANVAS_HEIGHT, Image.INTERPOLATE_BILINEAR)
			canvas.blend_rect(base_img, Rect2i(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT), Vector2i.ZERO)
			return true

	# Fallback: fill with a flat colour matching the card variant.
	var fill: Color = FALLBACK_CARD_COLORS.get(color_key, DEFAULT_FALLBACK_COLOR)
	canvas.fill(fill)
	# A flat colour on its own does count as a base; return true so the
	# empty-fallback watermark is not drawn on top of a valid colour card.
	return true


static func _draw_paint_layer(canvas: Image, room_data: Dictionary) -> bool:
	var pd: Variant = room_data.get("paint_data", {})
	if pd is not Dictionary:
		return false
	var paint: Dictionary = pd as Dictionary
	if paint.is_empty() or not paint.has("png_b64"):
		return false

	var raw: PackedByteArray = Marshalls.base64_to_raw(str(paint.get("png_b64", "")))
	if raw.is_empty():
		return false

	var img := Image.new()
	if img.load_png_from_buffer(raw) != OK:
		push_warning("StudioRoomCompositor: failed to decode paint PNG")
		return false

	img.resize(CANVAS_WIDTH, CANVAS_HEIGHT, Image.INTERPOLATE_BILINEAR)
	canvas.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
	return true


static func _draw_sticker_layer(canvas: Image, room_data: Dictionary) -> bool:
	var raw_stickers: Variant = room_data.get("stickers", [])
	if raw_stickers is not Array:
		return false
	var stickers: Array = raw_stickers as Array
	if stickers.is_empty():
		return false

	var drew_any := false
	for entry_var in stickers:
		if entry_var is not Dictionary:
			continue
		var entry: Dictionary = entry_var as Dictionary
		if entry.is_empty():
			continue
		if _stamp_sticker(canvas, entry):
			drew_any = true
	return drew_any


static func _stamp_sticker(canvas: Image, entry: Dictionary) -> bool:
	# Resolve the texture.  StudioStickerEntry serialises asset_path as "path".
	var asset_path := str(entry.get("path", "")).strip_edges()
	var sticker_tex: Texture2D = null

	if asset_path != "":
		sticker_tex = _load_texture(asset_path)

	if sticker_tex == null:
		var s_type := str(entry.get("type", "")).strip_edges()
		var s_id   := str(entry.get("id",   "")).strip_edges()
		if s_type != "" and s_id != "":
			var derived := "res://assets/textures/stickers/%s_%s.png" % [s_type, s_id]
			sticker_tex = _load_texture(derived)

	if sticker_tex == null:
		sticker_tex = _load_texture(STICKER_DEFAULT_PATH)

	if sticker_tex == null:
		return false

	var sticker_img := sticker_tex.get_image()
	if sticker_img == null:
		return false

	# Normalised position (0..1 relative to canvas).
	# "x"/"y" are the serialised keys in StudioRoomController's slot dicts
	# and StudioStickerEntry.  Fall back to 0.5/0.5 (centre) if missing.
	var norm_x := clampf(float(entry.get("x", 0.5)), 0.0, 1.0)
	var norm_y := clampf(float(entry.get("y", 0.5)), 0.0, 1.0)

	var scale_x := clampf(float(entry.get("sx", 1.0)), 0.1, 4.0)
	var scale_y := clampf(float(entry.get("sy", 1.0)), 0.1, 4.0)

	var stamp_w := int(STICKER_STAMP_SIZE.x * scale_x)
	var stamp_h := int(STICKER_STAMP_SIZE.y * scale_y)

	var s_copy := sticker_img.duplicate() as Image
	s_copy.resize(stamp_w, stamp_h, Image.INTERPOLATE_BILINEAR)

	var dest_x := int(norm_x * CANVAS_WIDTH  - stamp_w * 0.5)
	var dest_y := int(norm_y * CANVAS_HEIGHT - stamp_h * 0.5)
	# Clamp to canvas bounds so blend_rect never receives out-of-range coords.
	dest_x = clampi(dest_x, 0, CANVAS_WIDTH  - 1)
	dest_y = clampi(dest_y, 0, CANVAS_HEIGHT - 1)

	var blit_w := mini(stamp_w, CANVAS_WIDTH  - dest_x)
	var blit_h := mini(stamp_h, CANVAS_HEIGHT - dest_y)
	canvas.blend_rect(
		s_copy,
		Rect2i(0, 0, blit_w, blit_h),
		Vector2i(dest_x, dest_y)
	)
	return true


## Draws a subtle "no content" placeholder so the texture is never blank.
static func _draw_empty_fallback(canvas: Image, room_data: Dictionary) -> void:
	var color_key: String = str(room_data.get("card_color", "white"))
	var fill: Color = FALLBACK_CARD_COLORS.get(color_key, DEFAULT_FALLBACK_COLOR)
	# Lighter version of the card colour so it reads as "empty / undecorated".
	canvas.fill(fill.lightened(0.14))

	# Draw a simple dotted border pattern to signal "editable but empty".
	var dot_color := Color(fill.darkened(0.22), 0.55)
	var step := 14
	for x in range(0, CANVAS_WIDTH, step):
		canvas.set_pixel(x, 4,              dot_color)
		canvas.set_pixel(x, CANVAS_HEIGHT - 5, dot_color)
	for y in range(0, CANVAS_HEIGHT, step):
		canvas.set_pixel(4,              y, dot_color)
		canvas.set_pixel(CANVAS_WIDTH - 5, y, dot_color)


# ══════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════

static func _make_canvas() -> Image:
	var img := Image.create(CANVAS_WIDTH, CANVAS_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	return img


## Load a Texture2D from a res:// path, using the module-level cache.
## Returns null when the resource does not exist or cannot be loaded.
static func _load_texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D

	if not ResourceLoader.exists(path, "Texture2D"):
		_tex_cache[path] = null
		return null

	var res: Variant = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	var tex: Texture2D = res as Texture2D
	_tex_cache[path] = tex
	return tex
