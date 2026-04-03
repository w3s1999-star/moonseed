class_name StudioStickerPlacementController
extends RefCounted

# ─────────────────────────────────────────────────────────────────
# studio_sticker_placement_controller.gd
#
# Centralises all sticker placement behaviour for the card studio.
# Lives as a plain RefCounted — it owns no scene nodes of its own,
# but it creates and manages StudioSticker Control nodes which are
# added as children of the card_container provided at setup time.
#
# Ownership model
#   card_container  (Control, NOT owned) — parent node where sticker
#       nodes live.  Must be set before any other method is called.
#       All spawned StudioSticker nodes are direct children of it.
#
#   _stickers  (Array[StudioSticker]) — the authoritative runtime list.
#       A sticker is in this list for exactly as long as it is alive
#       in the scene.  Entries are removed before queue_free() is called.
#
#   _selected  (StudioSticker | null) — at most one selected sticker.
#       Always a member of _stickers, or null.
#
# Signals
#   selection_changed          — raised after _selected changes.
#   sticker_added(sticker)     — raised after a new node is fully ready.
#   sticker_removed(sticker)   — raised just before queue_free(); node
#                                is still valid at that point.
#   stickers_cleared           — raised when all stickers are wiped.
#
# Saving / loading
#   serialize_stickers()  → Array of plain Dictionaries, ready to be
#       written into StudioRoomData.stickers.  Nothing is written here.
#   load_stickers(arr)    → replaces live stickers with arr's contents;
#       old nodes are freed first.  Safe to call repeatedly.
#
# Drag support
#   The controller connects to StudioSticker.move_started and gates
#   drag handling through begin_drag / update_drag / end_drag.
#   The parent scene (or popup) must forward InputEventMouseMotion and
#   the LMB-release event to update_drag() / end_drag() when a drag is
#   active.  is_drag_active() lets callers query the current state.
#
# Z-index assignment
#   New stickers receive z_index = highest current + 1 so each drop
#   sits on top of earlier ones.  The caller can override z_index
#   through the sticker's entry after add_sticker() returns.
# ─────────────────────────────────────────────────────────────────

# ── Signals ───────────────────────────────────────────────────────

## Emitted after _selected changes (may be null).
signal selection_changed(sticker: StudioSticker)

## Emitted after a StudioSticker node is added and ready.
signal sticker_added(sticker: StudioSticker)

## Emitted just before a sticker node is freed.
signal sticker_removed(sticker: StudioSticker)

## Emitted after load_stickers() or clear_all_stickers() wipes the board.
signal stickers_cleared

## Emitted when a sticker requests a context menu (right-click in Studio editor).
signal sticker_context_requested(sticker: StudioSticker, global_pos: Vector2)


# ── State ─────────────────────────────────────────────────────────

## The Control node whose local space sticker positions are relative to.
## Must be set via setup() before any other method is used.
var card_container: Control = null

# Runtime list — parallel to card_container's children that are stickers.
var _stickers: Array[StudioSticker] = []

# Currently selected sticker node, or null.
var _selected: StudioSticker = null

# ── Drag state ────────────────────────────────────────────────────
# The drag target and the offset from the sticker's top-left to where
# the user clicked, so the sticker doesn't snap its corner to the cursor.

var _drag_target:        StudioSticker = null
var _drag_cursor_offset: Vector2       = Vector2.ZERO
var _pending_drag_target:        StudioSticker = null
var _pending_drag_cursor_offset: Vector2       = Vector2.ZERO
var _pending_drag_start_global:  Vector2       = Vector2.ZERO

const DRAG_START_THRESHOLD_PX: float = 3.0


# ═══════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════

## Bind the controller to a card container node.
## Must be called once before add_sticker / load_stickers.
## Passing a new container to an already-set-up controller is allowed;
## existing stickers are NOT migrated — call clear_all_stickers() first.
func setup(container: Control) -> void:
	if is_instance_valid(card_container):
		var prev_gui_input_cb := Callable(self, "_on_card_container_gui_input")
		if card_container.gui_input.is_connected(prev_gui_input_cb):
			card_container.gui_input.disconnect(prev_gui_input_cb)
	card_container = container
	if is_instance_valid(card_container):
		var gui_input_cb := Callable(self, "_on_card_container_gui_input")
		if not card_container.gui_input.is_connected(gui_input_cb):
			card_container.gui_input.connect(gui_input_cb)


# ═══════════════════════════════════════════════════════════════════
# PUBLIC API — ADDING STICKERS
# ═══════════════════════════════════════════════════════════════════

## Add a brand-new sticker from catalog identity.
##
## asset_id      — catalog key (e.g. "binding_twine").
## sticker_type  — "ritual" or "consumable".
## norm_pos      — normalised (0..1) position on the card.
##                 Defaults to dead-centre (0.5, 0.5).
##
## Returns the spawned StudioSticker node, or null if the container is
## not set or the type is invalid.
func add_sticker(
	asset_id:     String,
	sticker_type: String,
	norm_pos:     Vector2 = Vector2(0.5, 0.5),
) -> StudioSticker:
	if not _container_ready():
		push_error("StudioStickerPlacementController.add_sticker: card_container not set.")
		return null
	if sticker_type not in StudioStickerEntry.VALID_TYPES:
		push_error("StudioStickerPlacementController.add_sticker: invalid type '%s'." % sticker_type)
		return null

	var entry := StudioStickerEntry.new(asset_id, sticker_type)
	entry.pos_x   = clampf(norm_pos.x, 0.0, 1.0)
	entry.pos_y   = clampf(norm_pos.y, 0.0, 1.0)
	entry.z_index = _next_z_index()

	return _spawn_sticker(entry)


## Add a sticker from a fully-populated StudioStickerEntry.
## The entry is used as-is; ownership transfers to the spawned node.
## Returns the spawned StudioSticker node, or null on failure.
func add_sticker_from_entry(entry: StudioStickerEntry) -> StudioSticker:
	if not _container_ready():
		push_error("StudioStickerPlacementController.add_sticker_from_entry: card_container not set.")
		return null
	if entry == null:
		return null
	return _spawn_sticker(entry)


# ═══════════════════════════════════════════════════════════════════
# PUBLIC API — PLACING STICKERS (palette / satchel entry point)
# ═══════════════════════════════════════════════════════════════════

## Primary entry point for placing a sticker from a palette or satchel.
##
## asset_id      — catalog key (e.g. "binding_twine").
##                 May be empty when asset_path is the sole identifier.
## sticker_type  — "ritual" or "consumable".
##                 Ignored (and may be empty) when asset_path is used.
## cursor_global — global cursor position at the time of placement.
##                 Converted to normalised card coordinates automatically.
##                 Pass Vector2.INF (the default) to place at card centre.
## asset_path    — optional res:// path for assets not in the catalog.
##                 When non-empty, takes priority over type+asset_id for
##                 texture loading and bypasses the catalog check.
##
## The method:
##   1. Validates the asset (catalog check or path existence).
##   2. Converts cursor_global into normalised card coordinates.
##   3. Spawns a StudioSticker with identity rotation/scale and the
##      next available z_index (always rendered on top of existing stickers).
##   4. Auto-selects the new sticker so the user can immediately move it.
##   5. The sticker is automatically included in serialize_stickers().
##
## Returns the spawned node, or null on failure.
func place_sticker(
	asset_id:      String,
	sticker_type:  String,
	cursor_global: Vector2 = Vector2.INF,
	asset_path:    String  = "",
) -> StudioSticker:
	if not _container_ready():
		push_error("StudioStickerPlacementController.place_sticker: card_container not set.")
		return null
	# ── 1. Asset validation ────────────────────────────────────────
	if not _validate_sticker_asset(asset_id, sticker_type, asset_path):
		return null
	# ── 2. Cursor → normalised card position ──────────────────────
	var norm_pos := _cursor_to_norm(cursor_global)
	# ── 3. Build entry with explicit identity transform ────────────
	var entry := StudioStickerEntry.new(asset_id, sticker_type)
	entry.pos_x        = norm_pos.x
	entry.pos_y        = norm_pos.y
	entry.rotation_deg = 0.0             # identity rotation
	entry.scale_x      = 1.0             # identity scale
	entry.scale_y      = 1.0
	entry.z_index      = _next_z_index() # always stacked on top
	entry.asset_path   = asset_path
	# ── 4. Spawn, register, and auto-select ───────────────────────
	var sticker := _spawn_sticker(entry)
	select_sticker(sticker)              # emits selection_changed
	return sticker


## Convenience overload: place a sticker from a raw res:// texture path
## without requiring a catalog identity.  Useful for custom image assets
## and future palette types not registered in GameData.
##
## cursor_global — global cursor position; pass Vector2.INF for card centre.
##
## Note: path-only stickers round-trip correctly through serialize_stickers()
## and load_stickers() because asset_path is preserved in the save dict.
func place_sticker_from_path(
	asset_path:    String,
	cursor_global: Vector2 = Vector2.INF,
) -> StudioSticker:
	return place_sticker("", "", cursor_global, asset_path)


# ═══════════════════════════════════════════════════════════════════
# PUBLIC API — SELECTION
# ═══════════════════════════════════════════════════════════════════

## Select a sticker node and deselect all others.
## Passing the already-selected sticker is a no-op (no signal).
## Passing null is the same as clear_selection().
func select_sticker(sticker: StudioSticker) -> void:
	if sticker == _selected:
		return
	_apply_selection(sticker)


## Deselect all stickers.  Emits selection_changed(null).
func clear_selection() -> void:
	if _selected == null:
		return
	_apply_selection(null)


## Returns the currently selected sticker, or null.
func get_selected() -> StudioSticker:
	return _selected


# ═══════════════════════════════════════════════════════════════════
# PUBLIC API — DELETION
# ═══════════════════════════════════════════════════════════════════

## Delete whichever sticker is currently selected.
## Emits sticker_removed, then frees the node.
## If nothing is selected this is a no-op.
func delete_selected_sticker() -> void:
	if _selected == null:
		return
	_remove_sticker(_selected)


## Delete a specific sticker node regardless of selection state.
func delete_sticker(sticker: StudioSticker) -> void:
	if not is_instance_valid(sticker):
		return
	_remove_sticker(sticker)


## Remove all stickers and free their nodes.
func clear_all_stickers() -> void:
	# Work on a copy — _stickers is mutated inside _remove_sticker.
	for s in _stickers.duplicate():
		_remove_sticker(s)
	stickers_cleared.emit()


# ═══════════════════════════════════════════════════════════════════
# PUBLIC API — DRAG
# ═══════════════════════════════════════════════════════════════════

## True while a sticker is being dragged.
func is_drag_active() -> bool:
	return is_instance_valid(_drag_target) or is_instance_valid(_pending_drag_target)

## True only while the cursor has moved beyond DRAG_START_THRESHOLD_PX
## and the sticker is actively being repositioned.
func is_dragging() -> bool:
	return is_instance_valid(_drag_target)

## Return the sticker node currently being dragged (after crossing the
## start threshold), or null if none.
func get_dragging_sticker() -> StudioSticker:
	return _drag_target if is_instance_valid(_drag_target) else null


## Begin dragging sticker.  cursor_global is the global cursor position
## at the start of the drag.  Called automatically from the
## move_started signal; may also be called manually.
func begin_drag(sticker: StudioSticker, cursor_global: Vector2) -> void:
	if not is_instance_valid(sticker) or not _container_ready():
		return
	_pending_drag_target = sticker
	# Compute offset from the sticker's top-left corner to the cursor so
	# the sticker moves relative to where the user grabbed it.
	var sticker_global := sticker.get_global_rect().position
	_pending_drag_cursor_offset = cursor_global - sticker_global
	_pending_drag_start_global = cursor_global
	_drag_target = null
	_drag_cursor_offset = Vector2.ZERO
	select_sticker(sticker)


## Update the drag in progress.  cursor_global is the current cursor
## position.  Call this from the parent node's _input or _gui_input
## while is_drag_active() is true.
func update_drag(cursor_global: Vector2) -> void:
	if not is_drag_active() or not _container_ready():
		return
	if not is_instance_valid(_drag_target):
		if not is_instance_valid(_pending_drag_target):
			return
		# Let plain clicks update selection without forcing motion.
		if _pending_drag_start_global.distance_to(cursor_global) < DRAG_START_THRESHOLD_PX:
			return
		_drag_target = _pending_drag_target
		_drag_cursor_offset = _pending_drag_cursor_offset
		_pending_drag_target = null
		_pending_drag_cursor_offset = Vector2.ZERO
		_pending_drag_start_global = Vector2.ZERO
	if not is_instance_valid(_drag_target):
		return
	_drag_target.position = _clamped_drag_position(_drag_target, cursor_global, _drag_cursor_offset)


## Finish the drag, writing the final position back into the entry.
## Safe to call even if no drag is active.
func end_drag() -> void:
	if not is_drag_active():
		return
	# Snap the entry's normalised position to the current pixel position.
	if is_instance_valid(_drag_target) and _container_ready():
		_drag_target.build_data(card_container.size)
	_drag_target = null
	_drag_cursor_offset = Vector2.ZERO
	_pending_drag_target = null
	_pending_drag_cursor_offset = Vector2.ZERO
	_pending_drag_start_global = Vector2.ZERO


# ═══════════════════════════════════════════════════════════════════
# PUBLIC API — RESIZE
# ═══════════════════════════════════════════════════════════════════

## Reposition all stickers after the card container has been resized.
## Call this from the container's resized signal or after layout changes.
func on_container_resized() -> void:
	if not _container_ready():
		return
	var card_size := card_container.size
	for s in _stickers:
		if is_instance_valid(s):
			s.reposition(card_size)


# ═══════════════════════════════════════════════════════════════════
# PUBLIC API — SERIALISATION / DESERIALISATION
# ═══════════════════════════════════════════════════════════════════

## Return a plain Array of Dictionaries suitable for writing into
## StudioRoomData.stickers.  Each entry is the output of
## StudioSticker.build_data(); positions are re-derived from live pixel
## coords so any drag changes are captured.
## Nothing is written to disk here.
func serialize_stickers() -> Array:
	var result: Array = []
	if not _container_ready():
		return result
	var card_size := card_container.size
	for s in _stickers:
		if not is_instance_valid(s):
			continue
		var d := s.build_data(card_size)
		if not d.is_empty():
			result.append(d)
	return result


## Replace the current sticker set with data from sticker_data_array
## (an Array of plain Dictionaries, as stored in StudioRoomData.stickers).
##
## All existing nodes are freed first.  Invalid or empty entries are
## skipped silently.  Emits stickers_cleared once, then sticker_added
## for each successfully spawned sticker.
func load_stickers(sticker_data_array: Array) -> void:
	# Free existing nodes without emitting individual sticker_removed
	# signals — the caller only needs to know the slate was wiped.
	for s in _stickers.duplicate():
		if is_instance_valid(s):
			s.queue_free()
	_stickers.clear()
	_selected = null
	stickers_cleared.emit()

	if not _container_ready():
		return

	for raw in sticker_data_array:
		if raw is not Dictionary:
			continue
		var d := raw as Dictionary
		if d.is_empty():
			continue
		var entry := StudioStickerEntry.from_dictionary(d)
		if not entry.is_valid():
			continue
		_spawn_sticker(entry)


# ═══════════════════════════════════════════════════════════════════
# PUBLIC API — QUERIES
# ═══════════════════════════════════════════════════════════════════

## Return the total number of live stickers.
func sticker_count() -> int:
	return _stickers.size()


## Return a copy of the live sticker array (safe to iterate while modifying).
func get_all_stickers() -> Array[StudioSticker]:
	return _stickers.duplicate()


# ═══════════════════════════════════════════════════════════════════
# PRIVATE HELPERS
# ═══════════════════════════════════════════════════════════════════

## Spawn a StudioSticker node from an entry, connect its signals,
## add it to card_container, and register it in _stickers.
## Emits sticker_added when done.  Returns the new node.
func _spawn_sticker(entry: StudioStickerEntry) -> StudioSticker:
	var s := StudioSticker.new()
	card_container.add_child(s)
	# apply_entry positions the node; card_container.size may still be
	# zero the very first frame, so reposition() is safe to call again
	# once the container has been laid out.
	s.apply_entry(entry, card_container.size)
	# Wire up the three interaction signals.
	s.select_requested.connect(_on_sticker_select_requested)
	s.move_started.connect(_on_sticker_move_started)
	s.delete_requested.connect(_on_sticker_delete_requested)
	s.context_requested.connect(_on_sticker_context_requested)
	s.tree_exited.connect(_on_sticker_tree_exited.bind(s), CONNECT_ONE_SHOT)
	_stickers.append(s)
	sticker_added.emit(s)
	return s


## Remove a sticker from the live list, clear selection if needed,
## emit sticker_removed, then free the node.
func _remove_sticker(sticker: StudioSticker) -> void:
	if not is_instance_valid(sticker):
		return
	if _selected == sticker:
		# Clear without re-emitting selection_changed here; we do it below.
		_selected = null
		_update_dim_state()
		selection_changed.emit(null)
	if _drag_target == sticker:
		_drag_target        = null
		_drag_cursor_offset = Vector2.ZERO
	if _pending_drag_target == sticker:
		_pending_drag_target        = null
		_pending_drag_cursor_offset = Vector2.ZERO
		_pending_drag_start_global  = Vector2.ZERO
	_stickers.erase(sticker)
	sticker_removed.emit(sticker)
	sticker.queue_free()


## Point _selected at the new sticker (or null), update visuals,
## and emit selection_changed.
func _apply_selection(sticker: StudioSticker) -> void:
	if is_instance_valid(_selected):
		_selected.set_selected(false)
	_selected = sticker
	if is_instance_valid(_selected):
		_selected.set_selected(true)
	_update_dim_state()
	selection_changed.emit(_selected)


## Apply or remove the dim effect on all non-selected stickers.
func _update_dim_state() -> void:
	var any_selected := is_instance_valid(_selected)
	for s in _stickers:
		if not is_instance_valid(s):
			continue
		if s == _selected:
			s.set_dimmed(false)
		else:
			s.set_dimmed(any_selected)


## Return z_index = one above the current highest, or 0 if empty.
func _next_z_index() -> int:
	var max_z := -1
	for s in _stickers:
		if is_instance_valid(s) and s.entry != null:
			max_z = maxi(max_z, s.entry.z_index)
	return max_z + 1


## True when card_container is set and still valid.
func _container_ready() -> bool:
	return is_instance_valid(card_container)


func _clamped_drag_position(sticker: StudioSticker, cursor_global: Vector2, cursor_offset: Vector2) -> Vector2:
	var local_cursor := card_container.get_global_transform().affine_inverse() * cursor_global
	var new_pos      := local_cursor - cursor_offset
	# Match garden decor drag behavior: clamp the moved node fully inside the layer.
	var card_size := card_container.size
	var sz        := sticker.size
	new_pos.x = clampf(new_pos.x, 0.0, maxf(0.0, card_size.x - sz.x))
	new_pos.y = clampf(new_pos.y, 0.0, maxf(0.0, card_size.y - sz.y))
	return new_pos


## Convert a global cursor position to normalised (0..1) card coordinates.
## Returns Vector2(0.5, 0.5) — card centre — when:
##   • cursor_global == Vector2.INF  (caller requests the default spawn point)
##   • card_container has not been sized yet (size.x or size.y is 0)
func _cursor_to_norm(cursor_global: Vector2) -> Vector2:
	var card_size := card_container.size
	if cursor_global == Vector2.INF or card_size.x <= 0.0 or card_size.y <= 0.0:
		return Vector2(0.5, 0.5)
	var local := card_container.get_global_transform().affine_inverse() * cursor_global
	return Vector2(
		clampf(local.x / card_size.x, 0.0, 1.0),
		clampf(local.y / card_size.y, 0.0, 1.0),
	)


## Validate a sticker asset before spawning.  Returns false only for hard
## failures (missing explicit path, or unrecognised sticker_type).
## An unknown catalog entry is a soft warning only — the default fallback
## texture renders instead, keeping placement non-blocking.
##
## Rules:
##   A. Non-empty asset_path → file must exist (hard check).
##   B. Non-empty sticker_type → must be in VALID_TYPES (hard check).
##   C. Non-empty type + asset_id not in catalog → push_warning, still allow
##      (forward-compatible with catalog extensions and placeholder assets).
func _validate_sticker_asset(
	asset_id:     String,
	sticker_type: String,
	asset_path:   String,
) -> bool:
	# Rule A — explicit path must exist when given.
	if not asset_path.is_empty():
		if not ResourceLoader.exists(asset_path):
			push_error(
				"StudioStickerPlacementController: asset_path '%s' not found." % asset_path
			)
			return false
		return true  # path-only sticker; no catalog check required.
	# Rule B — type must be valid when given.
	if not sticker_type.is_empty() and sticker_type not in StudioStickerEntry.VALID_TYPES:
		push_error(
			"StudioStickerPlacementController: invalid sticker_type '%s'." % sticker_type
		)
		return false
	# Rule C — catalog soft-check: warn but allow through so the fallback
	# texture can render.  Forward-compatible with future catalog extensions.
	if not asset_id.is_empty() and not sticker_type.is_empty():
		var catalog: Dictionary = GameData.RITUAL_STICKERS \
			if sticker_type == "ritual" else GameData.CONSUMABLE_STICKERS
		if not catalog.has(asset_id):
			push_warning(
				"StudioStickerPlacementController: asset_id '%s' not in %s catalog; " \
				+ "default texture will be used." % [asset_id, sticker_type]
			)
	return true


# ═══════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS (from StudioSticker nodes)
# ═══════════════════════════════════════════════════════════════════

func _on_sticker_select_requested(sticker: StudioSticker) -> void:
	select_sticker(sticker)


func _on_sticker_move_started(sticker: StudioSticker, global_pos: Vector2) -> void:
	begin_drag(sticker, global_pos)


func _on_sticker_delete_requested(sticker: StudioSticker) -> void:
	delete_sticker(sticker)


func _on_sticker_context_requested(sticker: StudioSticker, global_pos: Vector2) -> void:
	select_sticker(sticker)
	sticker_context_requested.emit(sticker, global_pos)


func _on_card_container_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if not is_instance_valid(_selected):
		return
	if is_drag_active():
		return
	if _is_point_over_any_sticker(mb.global_position):
		return
	clear_selection()
	if is_instance_valid(card_container):
		card_container.accept_event()


func _is_point_over_any_sticker(global_pos: Vector2) -> bool:
	for s in _stickers:
		if not is_instance_valid(s):
			continue
		if not s.visible:
			continue
		if s.get_global_rect().has_point(global_pos):
			return true
	return false


func _on_sticker_tree_exited(sticker: StudioSticker) -> void:
	# Keep controller state consistent even if a sticker is freed externally.
	_stickers.erase(sticker)
	if _selected == sticker:
		_selected = null
		_update_dim_state()
		selection_changed.emit(null)
	if _drag_target == sticker:
		_drag_target = null
		_drag_cursor_offset = Vector2.ZERO
	if _pending_drag_target == sticker:
		_pending_drag_target = null
		_pending_drag_cursor_offset = Vector2.ZERO
		_pending_drag_start_global = Vector2.ZERO
