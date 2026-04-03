class_name StudioStickerEntry
extends RefCounted

# ─────────────────────────────────────────────────────────────────
# StudioStickerEntry.gd
#
# Typed data record for a single sticker placed inside a studio room.
# This is saved state only — no scene nodes, no textures, no signals.
#
# Relationship to existing types
#   StudioRoomData.stickers is an Array of plain Dictionaries.
#   StudioStickerEntry serialises to / deserialises from exactly that
#   format, so existing save files and StudioRoomController code need
#   no changes to be compatible.
#
# JSON key mapping (for backward compatibility with legacy slot dicts)
#   asset_id     ←→  "id"
#   type         ←→  "type"
#   pos_x        ←→  "x"
#   pos_y        ←→  "y"
#   rotation_deg ←→  "rot"    (new; absent in old saves → defaults to 0.0)
#   scale_x      ←→  "sx"     (new; absent in old saves → defaults to 1.0)
#   scale_y      ←→  "sy"     (new; absent in old saves → defaults to 1.0)
#   z_index      ←→  "z"      (new; absent in old saves → defaults to 0)
#   asset_path   ←→  "path"   (new; absent in old saves → defaults to "")
#   meta         ←→  "meta"   (new; absent in old saves → defaults to {})
# ─────────────────────────────────────────────────────────────────


# ═══════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════

const VALID_TYPES: Array[String] = ["ritual", "consumable"]


# ═══════════════════════════════════════════════════════════════════
# FIELDS
# ═══════════════════════════════════════════════════════════════════

## Catalog identifier for the sticker (e.g. "ritual_binding_twine").
## This is the primary lookup key used by IngredientData and the sticker
## catalog. Serialised as "id" to stay compatible with existing slot dicts.
var asset_id: String = ""

## "ritual" or "consumable" — determines which catalog table to look up.
var type: String = ""

## Optional direct res:// texture path. When non-empty, the runtime loader
## uses this path instead of deriving a path from asset_id + type.
## Leave empty for all catalog-backed stickers; only needed for one-off
## image assets that do not appear in the sticker catalog.
var asset_path: String = ""

## Horizontal position inside the card, normalised to [0.0, 1.0].
## 0.0 = left edge, 1.0 = right edge.
var pos_x: float = 0.5

## Vertical position inside the card, normalised to [0.0, 1.0].
## 0.0 = top edge, 1.0 = bottom edge.
var pos_y: float = 0.5

## Rotation in degrees, clockwise positive (matches Control.rotation).
## Stored as degrees for human-readable JSON; convert to radians when
## applying to a node via deg_to_rad(rotation_deg).
var rotation_deg: float = 0.0

## Horizontal scale factor. 1.0 = original size.
var scale_x: float = 1.0

## Vertical scale factor. 1.0 = original size.
var scale_y: float = 1.0

## Stacking order within the card surface. Higher values render on top.
## Analogous to CanvasItem.z_index.
var z_index: int = 0

## Open-ended extension dictionary for future data (tint color, flip flags,
## animation state, etc.). Never accessed by core serialisation logic;
## consumers own any schema stored here.
var meta: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════
# CONSTRUCTORS
# ═══════════════════════════════════════════════════════════════════

## Minimal constructor. Prefer the static factory helpers below.
func _init(p_asset_id: String = "", p_type: String = "") -> void:
	asset_id = p_asset_id
	type     = p_type


# ═══════════════════════════════════════════════════════════════════
# STATIC FACTORIES
# ═══════════════════════════════════════════════════════════════════

## Deserialise from a plain Dictionary (loaded from JSON or from a legacy
## slot dict {type, id, x, y}).  Missing new fields fall back to defaults.
static func from_dictionary(d: Dictionary) -> StudioStickerEntry:
	var e := StudioStickerEntry.new()
	# Accept both "asset_id" and the legacy key "id".
	e.asset_id    = str(d.get("asset_id", d.get("id", ""))).strip_edges()
	e.type        = str(d.get("type",     "")).strip_edges()
	e.asset_path  = str(d.get("path",     ""))
	e.pos_x       = clampf(float(d.get("x",   0.5)), 0.0, 1.0)
	e.pos_y       = clampf(float(d.get("y",   0.5)), 0.0, 1.0)
	e.rotation_deg = float(d.get("rot",  0.0))
	e.scale_x     = maxf(0.01, float(d.get("sx", 1.0)))
	e.scale_y     = maxf(0.01, float(d.get("sy", 1.0)))
	e.z_index     = int(d.get("z",    0))
	var raw_meta: Variant = d.get("meta", {})
	e.meta = (raw_meta as Dictionary).duplicate(true) if raw_meta is Dictionary else {}
	return e


## Build a StudioStickerEntry from a live Control node that has already been
## added to the tree and laid out.
##
## card_size — pixel dimensions of the parent card Control used to normalise
##             the node's screen position into [0, 1] coordinates.
## p_asset_id / p_type — catalog identity for the sticker (cannot be inferred
##             from the node itself).
##
## Example:
##   var entry := StudioStickerEntry.create_from_node(btn, "ritual_twine", "ritual", card_root.size)
static func create_from_node(
	node:        Control,
	p_asset_id:  String,
	p_type:      String,
	card_size:   Vector2,
	p_asset_path: String = "",
) -> StudioStickerEntry:
	var e := StudioStickerEntry.new(p_asset_id, p_type)
	e.asset_path  = p_asset_path
	# Use the node's AABB centre so position is independent of node pivot.
	var node_size := node.size if node.size.x > 0.0 else node.custom_minimum_size
	var centre    := node.position + node_size * 0.5
	e.pos_x       = clampf(centre.x / maxf(card_size.x, 1.0), 0.0, 1.0)
	e.pos_y       = clampf(centre.y / maxf(card_size.y, 1.0), 0.0, 1.0)
	e.rotation_deg = rad_to_deg(node.rotation)
	e.scale_x     = node.scale.x
	e.scale_y     = node.scale.y
	e.z_index     = node.z_index
	return e


# ═══════════════════════════════════════════════════════════════════
# SERIALISATION
# ═══════════════════════════════════════════════════════════════════

## Serialise to a plain Dictionary suitable for JSON storage.
## The output is a strict superset of the legacy {type, id, x, y} format,
## so existing readers (StudioRoomController, satchel_tab) load it without
## modification.
func to_dictionary() -> Dictionary:
	var d: Dictionary = {
		"id":   asset_id,   # legacy key – keep for backward compat readers
		"type": type,
		"x":    pos_x,
		"y":    pos_y,
	}
	# Only write new fields when they differ from their defaults, to keep old
	# save files small and avoid polluting legacy slot dicts with noise.
	if not is_zero_approx(rotation_deg):
		d["rot"] = rotation_deg
	if not is_equal_approx(scale_x, 1.0) or not is_equal_approx(scale_y, 1.0):
		d["sx"] = scale_x
		d["sy"] = scale_y
	if z_index != 0:
		d["z"] = z_index
	if not asset_path.is_empty():
		d["path"] = asset_path
	if not meta.is_empty():
		d["meta"] = meta.duplicate(true)
	return d


# ═══════════════════════════════════════════════════════════════════
# NODE INTEGRATION
# ═══════════════════════════════════════════════════════════════════

## Apply the saved transform to a live Control node.
##
## card_size — pixel dimensions of the parent card Control, used to convert
##             normalised pos back to pixel coordinates.
## node_size — optional override for the node's size used when centering.
##             Pass node.custom_minimum_size when calling before layout.
##             When omitted, node.size is used.
##
## This method sets position, rotation, scale, and z_index.
## It does NOT set the node's texture or other visual properties; the caller
## is responsible for loading and applying the correct Texture2D.
##
## Example:
##   entry.apply_to_node(btn, card_root.size, btn.custom_minimum_size)
func apply_to_node(node: Control, card_size: Vector2, node_size: Vector2 = Vector2.ZERO) -> void:
	node.rotation = deg_to_rad(rotation_deg)
	node.scale    = Vector2(scale_x, scale_y)
	node.z_index  = z_index
	# Determine an accurate size for the centering offset. Prefer the live
	# size; fall back to the caller-supplied hint; fall back to (0, 0).
	var sz: Vector2 = node.size if node.size.x > 0.0 else node_size
	var centre := Vector2(pos_x * card_size.x, pos_y * card_size.y)
	node.position = centre - sz * 0.5


# ═══════════════════════════════════════════════════════════════════
# CONVENIENCE HELPERS
# ═══════════════════════════════════════════════════════════════════

## Normalised position as a Vector2.
func position() -> Vector2:
	return Vector2(pos_x, pos_y)


## Scale as a Vector2.
func scale() -> Vector2:
	return Vector2(scale_x, scale_y)


## True when this entry carries enough data to be saved and reloaded.
##
## Two valid configurations:
##   Catalog-backed  — asset_id and type are both non-empty, type is legal.
##   Path-only       — asset_path is non-empty (catalog identity not required).
##
## In both cases, pos_x / pos_y must be in the normalised [0, 1] range.
func is_valid() -> bool:
	var pos_ok := pos_x >= 0.0 and pos_x <= 1.0 and pos_y >= 0.0 and pos_y <= 1.0
	# Path-only sticker: direct file reference bypasses the catalog.
	if not asset_path.is_empty():
		return pos_ok
	# Catalog-backed sticker: requires a valid type and non-empty id.
	return not asset_id.is_empty() and type in VALID_TYPES and pos_ok


## True when all transform fields match their default values (identity).
func is_identity_transform() -> bool:
	return is_zero_approx(rotation_deg) \
		and is_equal_approx(scale_x, 1.0) \
		and is_equal_approx(scale_y, 1.0) \
		and z_index == 0


## Return a deep copy of this entry.
func duplicate_entry() -> StudioStickerEntry:
	return StudioStickerEntry.from_dictionary(to_dictionary())
