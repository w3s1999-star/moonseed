class_name StudioRoomData
extends RefCounted

# ─────────────────────────────────────────────────────────────────
# StudioRoomData.gd – Persistent data record for one studio room.
#
# Ownership model
#   Every Task and every Relic owns exactly one StudioRoomData,
#   linked by room_id (an integer assigned at the time the entity
#   is created in Database).  owner_type is "task" or "relic";
#   owner_id is the corresponding Database entity id.
#
#   The relationship is single-owner, single-room:
#     Task / Relic  ──1:1──►  StudioRoomData
#
#   When the owning Task or Relic is deleted the room record must
#   be deleted too — Database.delete_task() / delete_relic() handle
#   this automatically.
#
# Persistence
#   Serialised as plain Dictionaries and stored in
#   user://ante_up/studio_rooms.json (an Array of room dicts).
# ─────────────────────────────────────────────────────────────────

## Unique room identifier — assigned by Database._next_studio_room_id.
var room_id: int = -1

## "task" or "relic"
var owner_type: String = ""

## id of the Task or Relic that owns this room.
var owner_id: int = -1

## Placed sticker entries.
## Each entry is a Dictionary with at minimum:
##   { id: String, type: String, x: float, y: float }
var stickers: Array = []

## Paint layer data for this room.  Serialised as a flat PNG encoded in
## base64 so it survives JSON round-trips without loss.
## Schema: { png_b64: String, width: int, height: int }
## Empty dict means no paint has been applied yet.
## The flat-image format was chosen over stroke records for v1 because it
## is self-contained, resolution-independent, and trivially loaded back
## into an Image without replaying every stroke.
## Future layers and undo/redo can layer additional dicts here.
var paint_data: Dictionary = {}

## ISO-8601 date string of the last write, e.g. "2026-03-13".
var last_modified: String = ""


func _init(p_room_id: int, p_owner_type: String, p_owner_id: int) -> void:
	room_id       = p_room_id
	owner_type    = p_owner_type
	owner_id      = p_owner_id
	last_modified = _today()


# ── Serialisation ─────────────────────────────────────────────────

## Deserialise from a plain Dictionary loaded from JSON.
static func from_dict(d: Dictionary) -> StudioRoomData:
	var r := StudioRoomData.new(
		int(d.get("room_id",    -1)),
		str(d.get("owner_type", "")),
		int(d.get("owner_id",   -1)),
	)
	r.stickers      = (d.get("stickers",   []) as Array).duplicate(true)
	r.paint_data    = (d.get("paint_data", {}) as Dictionary).duplicate(true)
	r.last_modified = str(d.get("last_modified", r.last_modified))
	return r


## Serialise to a plain Dictionary suitable for JSON storage.
func to_dict() -> Dictionary:
	return {
		room_id       = room_id,
		owner_type    = owner_type,
		owner_id      = owner_id,
		stickers      = stickers.duplicate(true),
		paint_data    = paint_data.duplicate(true),
		last_modified = last_modified,
	}


# ── Helpers ───────────────────────────────────────────────────────

## Update last_modified to today's date.
func touch() -> void:
	last_modified = _today()


## True when this record refers to a task.
func is_task_room() -> bool:
	return owner_type == "task"


## True when this record refers to a relic.
func is_relic_room() -> bool:
	return owner_type == "relic"


## True when all required fields are present and valid.
func is_valid() -> bool:
	return room_id > 0 and (owner_type == "task" or owner_type == "relic") and owner_id > 0


static func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]
