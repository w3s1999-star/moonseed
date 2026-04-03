extends Node

# ─────────────────────────────────────────────────────────────────
# StudioRoomManager.gd – Persistent per-entity studio render rooms
#
# Each task and relic created in Database gets a unique studio_room
# integer.  This manager keeps a persistent Control node alive for
# each room (TaskDiceBoxView for tasks, TextureRect for relics) so
# the sticker-paint studio can re-use the same render context
# across successive openings instead of rebuilding from scratch.
#
# Lifecycle
#   claim_room_view(room_id, kind, data)  → returns the view node,
#       creating it if needed, and syncing data.  The caller is
#       responsible for reparenting the view into their own UI tree.
#   release_room_view(room_id)  → reparents the view back into the
#       off-screen host and marks it invisible.
#   cull_room(room_id)  → permanently frees the view (call when
#       the owning task/relic is deleted).
# ─────────────────────────────────────────────────────────────────

const TASK_DICE_BOX_VIEW_SCRIPT := preload("res://scripts/ui/task_dice_box_view.gd")
const CARD_BASE_TEXTURES := {
	"white": "res://assets/textures/Card Base/Card_Base_White.png",
	"blue":  "res://assets/textures/Card Base/Card_Base_Blue.png",
	"green": "res://assets/textures/Card Base/Card_Base_Green.png",
	"brown": "res://assets/textures/Card Base/Card_Base_Brown.png",
}

# room_id: int -> {kind: String, view: Control, claimed: bool}
var _rooms: Dictionary = {}

# room_id: int -> ImageTexture  (composition cache, invalidated on update)
var _compositions: Dictionary = {}

# Hidden off-screen container – keeps unclaimed room views alive in
# the scene tree (required for _ready and _process to fire).
var _host: Control


func _ready() -> void:
	_host = Control.new()
	_host.name = "StudioRoomHost"
	_host.visible = false
	add_child(_host)
	# Auto-cull view nodes whenever room data is deleted, even if the
	# deletion originates outside this manager (e.g. delete_profile).
	SignalBus.studio_room_deleted.connect(_on_studio_room_deleted)
	# Log whenever a room is created via any insert path.
	SignalBus.studio_room_created.connect(_on_studio_room_created)
	SignalBus.studio_room_updated.connect(_on_studio_room_updated)
	# Purge stale room records left over from deleted tasks/relics.
	cleanup_orphaned_rooms()


func _on_studio_room_created(room_id: int, owner_type: String, owner_id: int) -> void:
	print("[StudioRoomManager] Room created: room_id=%d owner=%s#%d" % [room_id, owner_type, owner_id])


func _on_studio_room_deleted(room_id: int) -> void:
	print("[StudioRoomManager] Room deleted: room_id=%d" % room_id)
	cull_room(room_id)


func _on_studio_room_updated(room_id: int) -> void:
	print("[StudioRoomManager] Room updated: room_id=%d — invalidating composition cache" % room_id)
	_compositions.erase(room_id)


# ── Public API ────────────────────────────────────────────────────

## Return the persistent view for room_id, creating it if required.
## The view is visible and still attached to _host; the caller must
## reparent it into their own layout (e.g. card_root.reparent).
func claim_room_view(room_id: int, kind: String, data: Dictionary) -> Control:
	if not _rooms.has(room_id):
		_create_room(room_id, kind, data)
	else:
		_sync_room(room_id, data)
	var room: Dictionary = _rooms[room_id]
	room["claimed"] = true
	(room["view"] as Control).visible = true
	return room["view"] as Control


## Reparent the view back into the host and hide it.
## Safe to call even if the room was never claimed or doesn't exist.
func release_room_view(room_id: int) -> void:
	if not _rooms.has(room_id):
		return
	var room: Dictionary = _rooms[room_id]
	var view := room["view"] as Control
	if is_instance_valid(view):
		if view.get_parent() != _host:
			view.reparent(_host, false)
		view.visible = false
	room["claimed"] = false


## Permanently free the view – call when the owning task/relic
## is deleted so we don't accumulate orphaned render nodes.
func cull_room(room_id: int) -> void:
	if not _rooms.has(room_id):
		return
	var room: Dictionary = _rooms[room_id]
	var view := room["view"] as Control
	if is_instance_valid(view):
		view.queue_free()
	_rooms.erase(room_id)
	_compositions.erase(room_id)


## Return the composed ImageTexture for room_id.
## Composites from Database on first call; returns a cached result
## on subsequent calls until the room is updated via studio_room_updated.
## Returns a fallback texture when room_id is invalid or has no data.
func get_composition(room_id: int) -> ImageTexture:
	if _compositions.has(room_id):
		return _compositions[room_id] as ImageTexture
	var raw := Database.get_studio_room_data(room_id)
	var tex := StudioRoomCompositor.compose_room(raw)
	_compositions[room_id] = tex
	return tex


## Force re-composition for room_id on the next get_composition() call.
## Automatically triggered by studio_room_updated; rarely needed directly.
func invalidate_composition(room_id: int) -> void:
	_compositions.erase(room_id)


## True if a room node has already been instantiated for this id.
func has_room(room_id: int) -> bool:
	return _rooms.has(room_id)


# ── Data-layer API ────────────────────────────────────────────────
# These methods operate on the persistent StudioRoomData stored in
# Database.  They are the primary interface for anything that needs
# to read or write room content (stickers, paint_data, etc.) without
# touching the view nodes directly.

## Create a brand-new studio room and save it to Database.
## owner_type must be "task" or "relic"; owner_id is the entity's id.
## Returns the newly allocated room_id.
## Note: insert_task() and insert_relic() call this automatically — you
## only need to call it directly for out-of-band room creation.
func create_room(owner_type: String, owner_id: int) -> int:
	return Database.create_studio_room(owner_type, owner_id)


## Re-assign room_id's ownership to a different entity.
## Useful if two records must swap rooms or an owner id changes.
func assign_room(room_id: int, owner_type: String, owner_id: int) -> void:
	var raw := Database.get_studio_room_data(room_id)
	if raw.is_empty():
		push_warning("StudioRoomManager.assign_room: room_id %d not found" % room_id)
		return
	raw["owner_type"] = owner_type
	raw["owner_id"]   = owner_id
	Database.upsert_studio_room_data(StudioRoomData.from_dict(raw))
	print("[StudioRoomManager] Room assigned: room_id=%d → %s#%d" % [room_id, owner_type, owner_id])


## Return the persisted StudioRoomData dict for room_id, or {} if none.
func load_room_data(room_id: int) -> Dictionary:
	return Database.get_studio_room_data(room_id)


## Delete room data from Database and cull the view node.
## Prefer this over calling cull_room() directly when deleting a room
## permanently, as it also purges saved sticker/paint content.
func delete_room(room_id: int) -> void:
	# Data deletion emits studio_room_deleted → _on_studio_room_deleted → cull_room.
	# The additional cull_room() below is a no-op if the signal fires first,
	# but keeps cleanup synchronous regardless of signal dispatch timing.
	Database.delete_studio_room_data(room_id)
	cull_room(room_id)


## Return IDs of rooms in Database that have no matching task or relic.
func find_orphaned_rooms() -> Array:
	return Database.find_orphaned_studio_rooms()


## Delete the data record and cull the view for every studio room whose owner
## task or relic no longer exists.  Safe to call multiple times — no-ops when
## there are no orphans.  Called once at startup from _ready().
func cleanup_orphaned_rooms() -> void:
	var orphans := find_orphaned_rooms()
	for room_id: Variant in orphans:
		print("[StudioRoomManager] Orphan room removed: room_id=%d" % int(room_id))
		delete_room(int(room_id))


## Return the owner description for room_id as {type: String, id: int},
## or {} if the room does not exist in Database.
func get_room_owner(room_id: int) -> Dictionary:
	var raw := Database.get_studio_room_data(room_id)
	if raw.is_empty():
		return {}
	return {type = str(raw.get("owner_type", "")), id = int(raw.get("owner_id", -1))}


# ── Internal helpers ──────────────────────────────────────────────

func _create_room(room_id: int, kind: String, data: Dictionary) -> void:
	var view: Control
	if kind == "task":
		var task_view: TaskDiceBoxView = TASK_DICE_BOX_VIEW_SCRIPT.new()
		_host.add_child(task_view)
		task_view.set_task(data)
		view = task_view
	else:
		var tex_rect := TextureRect.new()
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_host.add_child(tex_rect)
		_apply_relic_card_texture(tex_rect, data)
		view = tex_rect
	view.visible = false
	_rooms[room_id] = {kind = kind, view = view, claimed = false}


func _sync_room(room_id: int, data: Dictionary) -> void:
	var room: Dictionary = _rooms[room_id]
	var view := room["view"] as Control
	if not is_instance_valid(view):
		_create_room(room_id, room["kind"], data)
		return
	if room["kind"] == "task" and view is TaskDiceBoxView:
		(view as TaskDiceBoxView).set_task(data)
	elif room["kind"] == "relic" and view is TextureRect:
		_apply_relic_card_texture(view as TextureRect, data)


func _apply_relic_card_texture(tex_rect: TextureRect, data: Dictionary) -> void:
	var card_color := str(data.get("card_color", "white"))
	var tex_path: String = CARD_BASE_TEXTURES.get(card_color, CARD_BASE_TEXTURES["white"])
	if ResourceLoader.exists(tex_path):
		tex_rect.texture = load(tex_path)
