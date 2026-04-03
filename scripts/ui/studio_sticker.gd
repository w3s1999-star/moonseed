class_name StudioSticker
extends Control

# ─────────────────────────────────────────────────────────────────
# studio_sticker.gd – Runtime node for a single placed studio sticker.
#
# One StudioSticker instance represents one entry in
# StudioRoomData.stickers.  It owns its own visual (TextureRect) and
# selection highlight; the parent room controller creates, positions,
# and removes instances as needed.
#
# Coordinate model
#   Position is stored as normalised (0..1) values in the bound
#   StudioStickerEntry.  The controller calls reposition(card_size)
#   whenever the parent container resizes.  build_data() re-derives
#   normalised coords from the current pixel position so in-place
#   drags made by the controller (position = …) are captured
#   without any extra bookkeeping.
#
# Interaction model
#   The node emits signals; it never mutates external state itself.
#     select_requested  – user left-clicked the sticker
#     move_started      – user began a drag on this sticker
#     delete_requested  – user right-clicked (context: delete)
#
# Usage example (room controller)
#   var s := StudioSticker.new()
#   card_root.add_child(s)
#   s.apply_data(entry_dict, card_root.size)
#   s.select_requested.connect(_on_sticker_select)
#   s.delete_requested.connect(_on_sticker_delete)
# ─────────────────────────────────────────────────────────────────

# ── Signals ───────────────────────────────────────────────────────

## Emitted when the user left-clicks this sticker.
## The parent should update selection state for all stickers.
signal select_requested(sticker: StudioSticker)

## Emitted on the first mouse-down that could begin a drag.
## global_pos is the cursor's global position at the moment of press.
## The parent controller is responsible for handling the actual drag
## loop and calling reposition() as the cursor moves.
signal move_started(sticker: StudioSticker, global_pos: Vector2)

## Emitted when the user right-clicks this sticker.
## The parent controller should remove it from the stickers array
## and call queue_free() on this node.
signal delete_requested(sticker: StudioSticker)

## Emitted when the user right-clicks and this sticker is configured to
## show a context menu instead of deleting immediately.
signal context_requested(sticker: StudioSticker, global_pos: Vector2)


# ── Constants ─────────────────────────────────────────────────────

## Default display size in pixels (used as the node's custom_minimum_size).
const DEFAULT_SIZE := Vector2(48.0, 48.0)

## Fallback texture loaded when no asset_path is set and no catalog
## texture can be found.
const DEFAULT_TEXTURE_PATH := "res://assets/textures/stickers/Sticker_default.png"

## Selection highlight colour.
const SELECTION_COLOR := Color("#ffe97a")

## Border width (px) of the selection highlight.
const SELECTION_BORDER_PX := 2

## Dim modulate applied to unselected stickers when any sticker is
## selected (set by the parent via set_dimmed(true)).
const DIM_MODULATE := Color(0.6, 0.6, 0.6, 0.85)

## When true, right-click emits context_requested instead of delete_requested.
## Default false so Satchel behavior ("right-click to remove") is unchanged.
var use_context_menu_on_right_click: bool = false


# ── Public state ──────────────────────────────────────────────────

## The entry that backs this runtime node.  Updated by apply_data()
## and kept in sync by build_data().
var entry: StudioStickerEntry = null


# ── Private nodes ─────────────────────────────────────────────────

var _tex_rect:          TextureRect
var _selection_outline: Panel
var _selected:          bool = false


# ── _ready ────────────────────────────────────────────────────────

func _ready() -> void:
	custom_minimum_size = DEFAULT_SIZE
	size                = DEFAULT_SIZE
	pivot_offset        = DEFAULT_SIZE * 0.5
	mouse_filter        = MOUSE_FILTER_PASS

	# ── Selection outline (drawn behind the texture)
	_selection_outline = Panel.new()
	_selection_outline.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_selection_outline.mouse_filter = MOUSE_FILTER_IGNORE
	_selection_outline.visible      = false
	var sb := StyleBoxFlat.new()
	sb.draw_center       = false
	sb.border_color      = SELECTION_COLOR
	sb.set_border_width_all(SELECTION_BORDER_PX)
	sb.set_corner_radius_all(4)
	_selection_outline.add_theme_stylebox_override("panel", sb)
	add_child(_selection_outline)

	# ── Sticker texture
	_tex_rect = TextureRect.new()
	_tex_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_tex_rect.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_rect.mouse_filter  = MOUSE_FILTER_IGNORE
	add_child(_tex_rect)


# ═══════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════

## Load sticker data from a plain Dictionary (StudioRoomData.stickers entry).
## card_size is needed to convert normalised coords to pixel position.
## Pass Vector2.ZERO to skip positioning (call reposition() later).
func apply_data(d: Dictionary, card_size: Vector2 = Vector2.ZERO) -> void:
	entry = StudioStickerEntry.from_dictionary(d)
	_apply_entry(card_size)


## Load sticker data directly from a StudioStickerEntry.
## card_size is the pixel size of the parent card container.
## Pass Vector2.ZERO to skip positioning (call reposition() later).
func apply_entry(e: StudioStickerEntry, card_size: Vector2 = Vector2.ZERO) -> void:
	entry = e
	_apply_entry(card_size)


## Serialise the current state back to a plain Dictionary compatible
## with StudioRoomData.stickers.
##
## card_size must be the pixel dimensions of the parent card container
## so that the current pixel position can be normalised correctly.
## If card_size is not provided (or is zero), the stored entry values
## are returned unchanged.
func build_data(card_size: Vector2 = Vector2.ZERO) -> Dictionary:
	if entry == null:
		return {}
	# Re-derive normalised position from the node's current pixel position
	# so that drags applied directly to `position` are captured.
	if card_size.x > 0.0 and card_size.y > 0.0:
		var centre := position + size * 0.5
		entry.pos_x = clampf(centre.x / card_size.x, 0.0, 1.0)
		entry.pos_y = clampf(centre.y / card_size.y, 0.0, 1.0)
	# Sync rotation and scale in case the controller modified them directly.
	entry.rotation_deg = rad_to_deg(rotation)
	entry.scale_x      = scale.x
	entry.scale_y      = scale.y
	entry.z_index      = z_index
	return entry.to_dictionary()


## Update just the pixel position without a full data reload.
## Call this when the parent container is resized.
func reposition(card_size: Vector2) -> void:
	if entry == null or card_size.x <= 0.0 or card_size.y <= 0.0:
		return
	entry.apply_to_node(self, card_size, custom_minimum_size)


## Toggle the selection highlight.  Does NOT emit select_requested.
func set_selected(_is_selected: bool) -> void:
	_selected = _is_selected
	_selection_outline.visible = _is_selected
	# Raise selected sticker above its siblings visually.
	z_index = (entry.z_index + 20) if (_is_selected and entry != null) else (entry.z_index if entry != null else 0)
	modulate = Color.WHITE


## Dim this sticker when a *different* sticker is selected.
## Pass false to restore full opacity.
func set_dimmed(is_dimmed: bool) -> void:
	if _selected:
		return  # never dim the selected sticker
	modulate = DIM_MODULATE if is_dimmed else Color.WHITE


## True when this sticker currently carries the selection.
func is_selected() -> bool:
	return _selected


## Return the catalog info dict for this sticker from GameData, or {}.
func catalog_info() -> Dictionary:
	if entry == null:
		return {}
	if entry.type == "ritual":
		return GameData.RITUAL_STICKERS.get(entry.asset_id, {})
	if entry.type == "consumable":
		return GameData.CONSUMABLE_STICKERS.get(entry.asset_id, {})
	return {}


## Return the display name from the catalog, or the raw asset_id.
func display_name() -> String:
	var info := catalog_info()
	if info.is_empty():
		return entry.asset_id if entry != null else ""
	return str(info.get("name", entry.asset_id))


## Return the emoji for this sticker from the catalog, or "?".
func display_emoji() -> String:
	var info := catalog_info()
	if info.is_empty():
		return "?"
	return str(info.get("emoji", "?"))


# ═══════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				select_requested.emit(self)
				move_started.emit(self, mb.global_position)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				if use_context_menu_on_right_click:
					select_requested.emit(self)
					context_requested.emit(self, mb.global_position)
				else:
					delete_requested.emit(self)
				accept_event()


# ═══════════════════════════════════════════════════════════════════
# PRIVATE HELPERS
# ═══════════════════════════════════════════════════════════════════

func _apply_entry(card_size: Vector2) -> void:
	_load_texture()
	if card_size.x > 0.0 and card_size.y > 0.0:
		entry.apply_to_node(self, card_size, custom_minimum_size)
	else:
		# Apply rotation/scale/z_index even without a known card size.
		rotation = deg_to_rad(entry.rotation_deg)
		scale    = Vector2(entry.scale_x, entry.scale_y)
		z_index  = entry.z_index
	# Restore modulate in case it was dimmed before data reload.
	modulate = Color.WHITE
	_selection_outline.visible = _selected


func _load_texture() -> void:
	if not is_instance_valid(_tex_rect):
		return
	var tex: Texture2D = null
	# 1. Explicit path from entry (one-off image assets).
	if entry != null and not entry.asset_path.is_empty():
		if ResourceLoader.exists(entry.asset_path):
			tex = load(entry.asset_path) as Texture2D
	# 2. Per-sticker path derived from type + asset_id if present on disk.
	if tex == null and entry != null and not entry.asset_id.is_empty():
		var derived := "res://assets/textures/stickers/%s_%s.png" % [entry.type, entry.asset_id]
		if ResourceLoader.exists(derived):
			tex = load(derived) as Texture2D
	# 3. Shared default sticker sprite.
	if tex == null and ResourceLoader.exists(DEFAULT_TEXTURE_PATH):
		tex = load(DEFAULT_TEXTURE_PATH) as Texture2D
	_tex_rect.texture = tex
