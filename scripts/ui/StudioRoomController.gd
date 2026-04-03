class_name StudioRoomController
extends Control

# ─────────────────────────────────────────────────────────────────
# StudioRoomController.gd
#
# Reusable controller for one studio-room editing session.
# Attach to a Control node (or use the companion StudioRoom.tscn).
#
# Usage
# ─────
#   var ctrl := preload("res://scripts/ui/StudioRoomController.gd").new()
#   ctrl.load_room(my_room_id)
#
#   # edit stickers
#   ctrl.place_sticker("ritual", "binding_twine", Vector2(0.5, 0.3))
#   ctrl.set_card_color("blue")
#
#   # commit
#   ctrl.save_room()
#
# The controller manages data state only.  Rendering is left to the
# host: call claim_view() to borrow the persistent StudioRoomManager
# node, parent it wherever you like, and call release_view() on exit.
# ─────────────────────────────────────────────────────────────────


# ═══════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════

const MAX_STICKER_SLOTS: int   = 6
const SLOT_GRID_COLS:    int   = 26
const SLOT_GRID_ROWS:    int   = 16
## Proportion of card height reserved for the sticker area (above the
## bottom info band).
const CARD_TOP_RATIO: float = 0.62

## Default slot positions used when a sticker has no explicit x/y.
## Expressed as normalised (0-1) coordinates within the card.
const LEGACY_SLOT_POSITIONS: Array[Vector2] = [
	Vector2(0.20, 0.18),
	Vector2(0.50, 0.14),
	Vector2(0.80, 0.18),
	Vector2(0.20, 0.56),
	Vector2(0.50, 0.56),
	Vector2(0.80, 0.56),
]

## Snap radius (normalised units) used when matching a drag position to
## an existing sticker slot.
const SNAP_THRESHOLD: float = 0.04

const VALID_OWNER_TYPES: Array[String] = ["task", "curio_canister"]
const VALID_CARD_COLORS:  Array[String] = ["white", "blue", "green", "brown"]

const STICKER_DEFAULT_TEXTURE_PATH: String = "res://assets/textures/stickers/Sticker_default.png"
const STUDIO_STICKER_CONTROLLER_SCRIPT := preload("res://scripts/ui/studio_sticker_placement_controller.gd")


# ═══════════════════════════════════════════════════════════════════
# SIGNALS
# ═══════════════════════════════════════════════════════════════════

## Emitted after load_room() successfully populates working state.
signal room_loaded(room_id: int)

## Emitted after save_room() writes data back to Database.
signal room_saved(room_id: int)

## Emitted when the dirty flag is toggled (true = unsaved edits exist).
signal dirty_changed(is_dirty: bool)

## Emitted when load_room() cannot find or validate the requested room.
signal load_failed(room_id: int, reason: String)


# ═══════════════════════════════════════════════════════════════════
# EXPORTED PROPERTIES
# ═══════════════════════════════════════════════════════════════════

## Non-zero: load this room automatically on _ready().
@export var initial_room_id: int = 0

## Save working state automatically when the node leaves the tree.
@export var auto_save_on_exit: bool = true


# ═══════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════

# ── Identity ──────────────────────────────────────────────────────

## Currently loaded room id; -1 when no room is loaded.
var room_id: int = -1

## "task" | "curio_canister" – resolved from the persisted StudioRoomData.
var owner_type: String = ""

## Database id of the owning entity.
var owner_id: int = -1

# ── Working state – mutated by the public API ─────────────────────

## Active sticker slots, length == MAX_STICKER_SLOTS.
## Each element is either {} (empty) or:
##   { type: "ritual"|"consumable",  id: String,  x: float,  y: float }
var _working_slots: Array = []

## Free-form paint / brush stroke data for future paint-layer tools.
## Schema is not enforced here; consumers own the structure.
var _working_paint: Dictionary = {}

## Card base-texture colour key.
var _working_card_color: String = "white"

# ── Snapshots – taken at load time for dirty detection ────────────

var _saved_slots:      Array      = []
var _saved_paint:      Dictionary = {}
var _saved_card_color: String     = "white"

# ── Flags ─────────────────────────────────────────────────────────

## True when working state differs from the last-saved snapshot.
var is_dirty: bool = false:
	set(v):
		if v != is_dirty:
			is_dirty = v
			dirty_changed.emit(v)

## True once load_room() has successfully completed.
var is_loaded: bool = false

# ── Borrowed view node (from StudioRoomManager) ───────────────────

var _claimed_view: Control = null
var _selected_list_button: Button = null
var _tasks_flow: VBoxContainer = null
var _curio_canisters_flow: VBoxContainer = null

# ── Studio tab UI (left stickers, center card, right list) ─────────

var _card_root: Control = null
var _studio_sticker_controller: RefCounted = null  # StudioStickerPlacementController
var _studio_drag_active: bool = false
var _studio_drag_type: String = ""
var _studio_drag_id: String = ""
var _studio_drag_emoji: String = ""
var _studio_drag_preview: Control = null
var _right_panel_title_tasks: Label = null
var _right_panel_title_curio_canisters: Label = null
var _tasks_scroll: ScrollContainer = null
var _curio_canisters_scroll: ScrollContainer = null
var _right_filter: String = "tasks"  # "tasks" | "curio_canisters"
var _save_btn: Button = null
var _left_panel: Control = null
var _sticker_menu: PopupMenu = null
var _sticker_menu_target: StudioSticker = null
var _sticker_menu_target_global: Vector2 = Vector2.ZERO

var _move_mode_active: bool = false
var _move_target: StudioSticker = null
var _move_cursor_offset: Vector2 = Vector2.ZERO
var _suppress_controller_dirty: bool = false

const STICKER_MENU_MOVE := 1
const STICKER_MENU_TO_INVENTORY := 2


# ═══════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	set_process_input(true)
	if initial_room_id > 0:
		load_room(initial_room_id)
	_build_studio_tab_ui()
	GameData.state_changed.connect(_refresh_active_entity_lists)
	dirty_changed.connect(_on_dirty_changed)

func _build_studio_tab_ui() -> void:
	# Three-column layout: left = stickers, center = card, right = tasks/curio_canisters
	release_view()
	for child in get_children():
		child.queue_free()
	_card_root = null
	_studio_sticker_controller = null
	_left_panel = null
	_sticker_menu = null
	_sticker_menu_target = null
	_move_mode_active = false
	_move_target = null

	var side_panel_width := 260.0

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	_sticker_menu = PopupMenu.new()
	_sticker_menu.id_pressed.connect(_on_sticker_menu_id_pressed)
	add_child(_sticker_menu)

	# ── Left panel: stickers + paint palette ───────────────────────
	var left_panel := PanelContainer.new()
	_left_panel = left_panel
	left_panel.custom_minimum_size = Vector2(side_panel_width, 0)
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.95, 0.93, 0.86, 0.98)
	left_style.border_color = Color(0.48, 0.41, 0.30, 1.0)
	left_style.set_border_width_all(2)
	left_style.set_corner_radius_all(6)
	left_style.set_content_margin_all(10)
	left_panel.add_theme_stylebox_override("panel", left_style)
	hbox.add_child(left_panel)

	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_v)

	var stickers_hdr := Label.new()
	stickers_hdr.text = "Stickers"
	stickers_hdr.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	left_v.add_child(stickers_hdr)
	left_v.add_child(_build_sticker_book_section("ritual", "Ritual Stickers", GameData.CHIP_COLOR))
	left_v.add_child(_build_sticker_book_section("consumable", "Consumable Stickers", GameData.ACCENT_GOLD))

	var palette_lbl := Label.new()
	palette_lbl.text = "Paint Palette"
	palette_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	left_v.add_child(palette_lbl)
	var palette_grid := GridContainer.new()
	palette_grid.columns = 4
	palette_grid.add_theme_constant_override("h_separation", 3)
	palette_grid.add_theme_constant_override("v_separation", 3)
	for pc in [Color("#1a1a1a"), Color("#ffffff"), Color("#e03030"), Color("#e07820"), Color("#e0d020"), Color("#38c030"), Color("#20c8d0"), Color("#2050e0"), Color("#9030d0"), Color("#e030a0"), Color("#8b4513"), Color("#f5deb3")]:
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(30, 24)
		cb.flat = true
		var st := StyleBoxFlat.new()
		st.bg_color = pc
		st.set_corner_radius_all(3)
		cb.add_theme_stylebox_override("normal", st)
		cb.pressed.connect(func(): pass)  # TODO: paint canvas brush color
		palette_grid.add_child(cb)
	left_v.add_child(palette_grid)

	# ── Center panel: background + centered card ───────────────────
	var center_panel := Control.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(center_panel)

	# Keep card + save button centered in the *visible* area (above bottom nav).
	# This margin also prevents the Save button from being hidden by the nav bar.
	var center_margin := MarginContainer.new()
	center_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_margin.add_theme_constant_override("margin_bottom", 84)
	center_panel.add_child(center_margin)

	# Non-container overlay for absolute-position UI (e.g. Save button).
	var center_overlay := Control.new()
	center_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	center_panel.add_child(center_overlay)

	var bg_full := ColorRect.new()
	bg_full.color = Color("#b3e6ff")
	bg_full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_margin.add_child(bg_full)
	var bg_grid := Control.new()
	bg_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_full.add_child(bg_grid)
	bg_grid.connect("draw", func():
		var cell_size := 32
		var cols := int(bg_grid.size.x / cell_size) + 1
		var rows := int(bg_grid.size.y / cell_size) + 1
		for x in range(cols):
			bg_grid.draw_line(Vector2(x * cell_size, 0), Vector2(x * cell_size, bg_grid.size.y), Color.WHITE, 1)
		for y in range(rows):
			bg_grid.draw_line(Vector2(0, y * cell_size), Vector2(bg_grid.size.x, y * cell_size), Color.WHITE, 1)
	)

	var center_wrap := CenterContainer.new()
	center_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_margin.add_child(center_wrap)

	var card_shell := PanelContainer.new()
	card_shell.custom_minimum_size = Vector2(230, 320)
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color(0.07, 0.05, 0.03, 0.92)
	shell_style.border_color = Color(0.96, 0.91, 0.84, 0.35)
	shell_style.set_border_width_all(2)
	shell_style.set_corner_radius_all(18)
	card_shell.add_theme_stylebox_override("panel", shell_style)
	center_wrap.add_child(card_shell)

	var card_root := Control.new()
	card_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_shell.add_child(card_root)
	_card_root = card_root

	var paint_canvas := Control.new()
	paint_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paint_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(paint_canvas)

	# Bottom-center save button (saves sticker positions for all views)
	_save_btn = Button.new()
	_save_btn.text = "Save"
	_save_btn.custom_minimum_size = Vector2(160, 40)
	_save_btn.anchor_left = 0.5
	_save_btn.anchor_right = 0.5
	_save_btn.anchor_top = 1.0
	_save_btn.anchor_bottom = 1.0
	_save_btn.offset_left = -80
	_save_btn.offset_right = 80
	_save_btn.offset_bottom = -10
	_save_btn.offset_top = -50
	_save_btn.pressed.connect(_on_save_pressed)
	_save_btn.z_index = 50
	center_overlay.add_child(_save_btn)
	_on_dirty_changed(is_dirty)

	# ── Right panel: tasks + curio canisters lists ──────────────────────────
	var side_panel_script := preload("res://scripts/ui/side_panel_bg.gd")
	var right_panel := PanelContainer.new()
	right_panel.set_script(side_panel_script)
	right_panel.default_tex_path = "res://assets/ui/table/dice_side_panel_right.png"
	right_panel.db_key = "dice_table_right_tex"
	right_panel.custom_minimum_size = Vector2(side_panel_width, 0)
	hbox.add_child(right_panel)
	right_panel.call_deferred("_load_texture")
	var right_v := VBoxContainer.new()
	right_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_v.add_theme_constant_override("separation", 6)
	right_panel.add_child(right_v)

	# Filter row: Tasks | Curio Canisters
	var filter_row := HBoxContainer.new()
	filter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	filter_row.add_theme_constant_override("separation", 6)
	right_v.add_child(filter_row)

	var tasks_btn := Button.new()
	tasks_btn.text = "Tasks"
	tasks_btn.toggle_mode = true
	filter_row.add_child(tasks_btn)

	var curio_canisters_btn := Button.new()
	curio_canisters_btn.text = "Curio Canisters"
	curio_canisters_btn.toggle_mode = true
	filter_row.add_child(curio_canisters_btn)

	# Initial button state
	tasks_btn.button_pressed = (_right_filter == "tasks")
	curio_canisters_btn.button_pressed = (_right_filter == "curio_canisters")

	# Wire handlers after all buttons exist (avoids parse/runtime errors)
	tasks_btn.pressed.connect(func():
		_right_filter = "tasks"
		tasks_btn.button_pressed = true
		curio_canisters_btn.button_pressed = false
		_refresh_active_entity_lists()
	)
	curio_canisters_btn.pressed.connect(func():
		_right_filter = "curio_canisters"
		tasks_btn.button_pressed = false
		curio_canisters_btn.button_pressed = true
		_refresh_active_entity_lists()
	)

	_right_panel_title_tasks = Label.new()
	_right_panel_title_tasks.text = "── TASKS ──"
	_right_panel_title_tasks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_v.add_child(_right_panel_title_tasks)
	_tasks_scroll = ScrollContainer.new()
	_tasks_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_v.add_child(_tasks_scroll)
	_tasks_flow = VBoxContainer.new()
	_tasks_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Pack from the top (avoid the "floating gap" effect)
	_tasks_flow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tasks_scroll.add_child(_tasks_flow)
	_refresh_active_entity_lists()

	_right_panel_title_curio_canisters = Label.new()
	_right_panel_title_curio_canisters.text = "── CURIO CANISTERS ──"
	_right_panel_title_curio_canisters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_v.add_child(_right_panel_title_curio_canisters)
	_curio_canisters_scroll = ScrollContainer.new()
	_curio_canisters_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_v.add_child(_curio_canisters_scroll)
	_curio_canisters_flow = VBoxContainer.new()
	_curio_canisters_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_curio_canisters_flow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_curio_canisters_scroll.add_child(_curio_canisters_flow)
	_refresh_active_entity_lists()

	# ── Sticker controller and room view ───────────────────────────
	_studio_sticker_controller = STUDIO_STICKER_CONTROLLER_SCRIPT.new()
	_studio_sticker_controller.setup(card_root)
	_studio_sticker_controller.sticker_added.connect(_on_studio_sticker_added)
	_studio_sticker_controller.sticker_removed.connect(_on_studio_sticker_removed)
	_studio_sticker_controller.stickers_cleared.connect(_sync_stickers_from_controller)
	if _studio_sticker_controller.has_signal("sticker_context_requested"):
		_studio_sticker_controller.sticker_context_requested.connect(_on_sticker_context_requested)
	card_root.resized.connect(_on_card_root_resized)

	if room_id > 0 and is_loaded:
		_attach_claimed_view_to_card()
		_refresh_sticker_controller_room()
		_select_list_for_current_room()


func _on_card_root_resized() -> void:
	if _studio_sticker_controller != null and _studio_sticker_controller.has_method("on_container_resized"):
		_studio_sticker_controller.on_container_resized()


func _on_save_pressed() -> void:
	if _move_mode_active:
		_end_move_mode(true)
	if _studio_sticker_controller != null and _studio_sticker_controller.has_method("is_drag_active") and _studio_sticker_controller.is_drag_active():
		_studio_sticker_controller.end_drag()
	# Ensure controller state is synced before persisting.
	_sync_stickers_from_controller()
	save_room()
	# Update compositions consumers (Play/Satchel) will re-fetch textures after studio_room_updated.
	_on_dirty_changed(is_dirty)


func _on_dirty_changed(v: bool) -> void:
	if not is_instance_valid(_save_btn):
		return
	_save_btn.disabled = not v
	_save_btn.visible = true


func _ensure_room_selected_or_warn() -> bool:
	if is_loaded and room_id > 0 and owner_type in VALID_OWNER_TYPES and owner_id > 0:
		return true
	push_warning("StudioRoomController: stickers can only be placed on a task or curio_canister card (select one on the right).")
	var dlg := AcceptDialog.new()
	dlg.title = "Select a Card"
	dlg.dialog_text = "Select a Task or Curio Canister on the right before placing or moving stickers."
	add_child(dlg)
	dlg.popup_centered(Vector2i(520, 150))
	dlg.confirmed.connect(func(): dlg.queue_free())
	return false


func _on_studio_sticker_added(sticker: StudioSticker) -> void:
	if is_instance_valid(sticker):
		sticker.use_context_menu_on_right_click = true
	_sync_stickers_from_controller()


func _on_studio_sticker_removed(sticker: StudioSticker) -> void:
	if sticker == _move_target:
		_end_move_mode(false)
	_sync_stickers_from_controller()


func _on_sticker_context_requested(sticker: StudioSticker, global_pos: Vector2) -> void:
	if not _ensure_room_selected_or_warn():
		return
	if not is_instance_valid(_sticker_menu):
		return
	_sticker_menu_target = sticker
	_sticker_menu_target_global = global_pos
	_sticker_menu.clear()
	_sticker_menu.add_item("Move Sticker", STICKER_MENU_MOVE)
	_sticker_menu.add_item("To Inventory", STICKER_MENU_TO_INVENTORY)
	var at := Vector2i(get_viewport().get_mouse_position())
	_sticker_menu.popup(Rect2i(at, Vector2i(1, 1)))


func _on_sticker_menu_id_pressed(id: int) -> void:
	if not is_instance_valid(_sticker_menu_target):
		return
	if id == STICKER_MENU_MOVE:
		_begin_move_mode(_sticker_menu_target, _sticker_menu_target_global)
	elif id == STICKER_MENU_TO_INVENTORY:
		_send_sticker_to_inventory(_sticker_menu_target)


func _begin_move_mode(sticker: StudioSticker, cursor_global: Vector2) -> void:
	if not is_instance_valid(sticker) or _card_root == null:
		return
	if _studio_sticker_controller != null and _studio_sticker_controller.has_method("is_drag_active") and _studio_sticker_controller.is_drag_active():
		_studio_sticker_controller.end_drag()
	_move_mode_active = true
	_move_target = sticker
	var local_cursor := _card_root.get_global_transform().affine_inverse() * cursor_global
	_move_cursor_offset = local_cursor - sticker.position


func _update_move_mode(cursor_global: Vector2) -> void:
	if not _move_mode_active or not is_instance_valid(_move_target) or _card_root == null:
		_end_move_mode(false)
		return
	var local_cursor := _card_root.get_global_transform().affine_inverse() * cursor_global
	var new_pos := local_cursor - _move_cursor_offset
	var card_size := _card_root.size
	var sz := _move_target.size
	new_pos.x = clampf(new_pos.x, 0.0, maxf(0.0, card_size.x - sz.x))
	new_pos.y = clampf(new_pos.y, 0.0, maxf(0.0, card_size.y - sz.y))
	_move_target.position = new_pos


func _end_move_mode(commit: bool, cursor_global: Vector2 = Vector2.INF) -> void:
	if commit and is_instance_valid(_move_target) and _card_root != null:
		if cursor_global != Vector2.INF:
			_update_move_mode(cursor_global)
		_move_target.build_data(_card_root.size)
		_sync_stickers_from_controller()
		refresh_room_view()
	_move_mode_active = false
	_move_target = null
	_move_cursor_offset = Vector2.ZERO


func _send_sticker_to_inventory(sticker: StudioSticker) -> void:
	if sticker == _move_target:
		_end_move_mode(false)
	if _studio_sticker_controller != null and _studio_sticker_controller.has_method("delete_sticker"):
		_studio_sticker_controller.delete_sticker(sticker)
		_sync_stickers_from_controller()
		refresh_room_view()


func _build_sticker_book_section(sticker_type: String, heading: String, color: Color) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	var header := Label.new()
	header.text = heading
	header.add_theme_color_override("font_color", color)
	header.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	section.add_child(header)
	var owned_ids: Array = _owned_sticker_ids_for_current_card(sticker_type)
	if owned_ids.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No owned stickers in this page yet."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_color_override("font_color", Color("#7c624d"))
		empty_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		section.add_child(empty_lbl)
		return section
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	for sid in owned_ids:
		var info: Dictionary = GameData.RITUAL_STICKERS.get(sid, {}) if sticker_type == "ritual" else GameData.CONSUMABLE_STICKERS.get(sid, {})
		if info.is_empty():
			continue
		flow.add_child(_build_sticker_book_button(sticker_type, str(sid), info))
	section.add_child(flow)
	return section


func _build_sticker_book_button(sticker_type: String, sticker_id: String, info: Dictionary) -> Control:
	var btn := Button.new()
	btn.text = str(info.get("name", sticker_id))
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.tooltip_text = str(info.get("desc", ""))
	btn.custom_minimum_size = Vector2(132, 64)
	btn.rotation = _sticker_button_rotation(sticker_id)
	var tex := _default_sticker_texture()
	if tex != null:
		btn.icon = tex
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_constant_override("icon_max_width", 64)
	btn.clip_text = true
	var emoji := str(info.get("emoji", "*"))
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_begin_studio_drag(sticker_type, sticker_id, emoji, mb.global_position)
	)
	return btn


func _refresh_active_entity_lists() -> void:
	# Studio should mirror the active entities shown in Satchel/PlayTab (GameData.*).
	if not is_instance_valid(_tasks_flow) or not is_instance_valid(_curio_canisters_flow):
		return

	# Show/hide sections based on filter
	var show_tasks := (_right_filter == "tasks")
	var show_curio_canisters := (_right_filter == "curio_canisters")
	if is_instance_valid(_right_panel_title_tasks):
		_right_panel_title_tasks.visible = show_tasks
	if is_instance_valid(_tasks_scroll):
		_tasks_scroll.visible = show_tasks
	if is_instance_valid(_right_panel_title_curio_canisters):
		_right_panel_title_curio_canisters.visible = show_curio_canisters
	if is_instance_valid(_curio_canisters_scroll):
		_curio_canisters_scroll.visible = show_curio_canisters

	for c in _tasks_flow.get_children():
		c.queue_free()
	for c in _curio_canisters_flow.get_children():
		c.queue_free()

	if show_tasks:
		for t in GameData.tasks:
			var b := Button.new()
			b.text = str(t.get("task", "Unnamed"))
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_color_override("font_color", Color.WHITE)
			var tid := int(t.get("id", -1))
			b.set_meta("entity_type", "task")
			b.set_meta("entity_id", tid)
			b.pressed.connect(self._on_list_item_pressed.bind("task", tid, b))
			_tasks_flow.add_child(b)

	if show_curio_canisters:
		for r in GameData.curio_canisters:
			var b2 := Button.new()
			b2.text = "%s %s" % [str(r.get("emoji", "✦")), str(r.get("title", "Unnamed"))]
			b2.flat = true
			b2.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b2.add_theme_color_override("font_color", Color.WHITE)
			var rid := int(r.get("id", -1))
			b2.set_meta("entity_type", "curio_canister")
			b2.set_meta("entity_id", rid)
			b2.pressed.connect(self._on_list_item_pressed.bind("curio_canister", rid, b2))
			_curio_canisters_flow.add_child(b2)

	_select_list_for_current_room()


func _owned_sticker_ids_for_current_card(sticker_type: String) -> Array:
	var owned: Array = Database.get_owned_stickers(sticker_type)
	for slot in _working_slots:
		if slot is not Dictionary:
			continue
		var slot_data: Dictionary = slot
		if slot_data.is_empty():
			continue
		if str(slot_data.get("type", "")) != sticker_type:
			continue
		var slot_id := str(slot_data.get("id", ""))
		if slot_id != "" and not owned.has(slot_id):
			owned.append(slot_id)
	return owned


func _sticker_button_rotation(sticker_id: String) -> float:
	var sum := 0
	for i in range(sticker_id.length()):
		sum += sticker_id.unicode_at(i)
	return float((sum % 11) - 5) * 0.012


func _default_sticker_texture() -> Texture2D:
	if ResourceLoader.exists(STICKER_DEFAULT_TEXTURE_PATH):
		return load(STICKER_DEFAULT_TEXTURE_PATH) as Texture2D
	return null


func _sync_stickers_from_controller(_sticker: Variant = null) -> void:
	if _studio_sticker_controller == null:
		return
	if not _studio_sticker_controller.has_method("serialize_stickers"):
		return
	var serialized: Array = _studio_sticker_controller.serialize_stickers()
	_working_slots = _normalize_slots(serialized, true)
	if not _suppress_controller_dirty and is_loaded:
		_mark_dirty()


func _refresh_sticker_controller_room() -> void:
	if _studio_sticker_controller == null:
		return
	if not _studio_sticker_controller.has_method("load_stickers"):
		return
	_suppress_controller_dirty = true
	_studio_sticker_controller.load_stickers(get_filled_slots())
	_suppress_controller_dirty = false


func _attach_claimed_view_to_card() -> void:
	release_view()
	if _card_root == null or not is_loaded or room_id <= 0:
		return
	var view := claim_view()
	if view != null:
		view.reparent(_card_root, false)
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Keep view behind paint canvas and stickers (add at index 0)
		_card_root.move_child(view, 0)


func _begin_studio_drag(sticker_type: String, sticker_id: String, emoji: String, global_pos: Vector2) -> void:
	if not _ensure_room_selected_or_warn():
		return
	if _move_mode_active:
		_end_move_mode(false)
	_studio_drag_active = true
	_studio_drag_type = sticker_type
	_studio_drag_id = sticker_id
	_studio_drag_emoji = emoji
	if is_instance_valid(_studio_drag_preview):
		_studio_drag_preview.queue_free()
	var preview := TextureRect.new()
	preview.texture = _default_sticker_texture()
	preview.custom_minimum_size = Vector2(42, 42)
	preview.size = Vector2(42, 42)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
	add_child(preview)
	_studio_drag_preview = preview
	_update_studio_drag_preview(global_pos)


func _update_studio_drag_preview(global_pos: Vector2) -> void:
	if not _studio_drag_active or not is_instance_valid(_studio_drag_preview):
		return
	var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * global_pos
	_studio_drag_preview.position = local_pos + Vector2(14.0, 10.0)


func _finish_studio_drag(global_pos: Vector2) -> void:
	if not _studio_drag_active:
		return
	var placed := _place_dragged_sticker_on_card(global_pos)
	_cancel_studio_drag()
	if placed:
		refresh_room_view()


func _cancel_studio_drag() -> void:
	_studio_drag_active = false
	_studio_drag_type = ""
	_studio_drag_id = ""
	_studio_drag_emoji = ""
	if is_instance_valid(_studio_drag_preview):
		_studio_drag_preview.queue_free()
	_studio_drag_preview = null


func _place_dragged_sticker_on_card(global_pos: Vector2) -> bool:
	if not _ensure_room_selected_or_warn():
		return false
	if _card_root == null or _studio_sticker_controller == null:
		return false
	var card_rect := _card_root.get_global_rect()
	if not card_rect.has_point(global_pos):
		return false
	if not _studio_sticker_controller.has_method("place_sticker"):
		return false
	_studio_sticker_controller.place_sticker(_studio_drag_id, _studio_drag_type, global_pos)
	_sync_stickers_from_controller()
	return true


func _input(event: InputEvent) -> void:
	if _move_mode_active:
		if event is InputEventMouseMotion:
			_update_move_mode((event as InputEventMouseMotion).global_position)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mb2 := event as InputEventMouseButton
			if mb2.button_index == MOUSE_BUTTON_LEFT and mb2.pressed:
				if _card_root != null and _card_root.get_global_rect().has_point(mb2.global_position):
					_end_move_mode(true, mb2.global_position)
				else:
					_end_move_mode(false)
				get_viewport().set_input_as_handled()
			elif mb2.button_index == MOUSE_BUTTON_RIGHT and mb2.pressed:
				_end_move_mode(false)
				get_viewport().set_input_as_handled()
		return
	if _studio_sticker_controller != null and _studio_sticker_controller.has_method("is_drag_active") and _studio_sticker_controller.is_drag_active():
		if event is InputEventMouseMotion:
			_studio_sticker_controller.update_drag((event as InputEventMouseMotion).global_position)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				if _studio_sticker_controller.has_method("is_dragging") and _studio_sticker_controller.is_dragging():
					if _is_over_left_panel(mb.global_position) and _studio_sticker_controller.has_method("get_dragging_sticker") and _studio_sticker_controller.has_method("delete_sticker"):
						var dragged: Variant = _studio_sticker_controller.get_dragging_sticker()
						if dragged != null:
							_studio_sticker_controller.delete_sticker(dragged)
				_studio_sticker_controller.end_drag()
				_sync_stickers_from_controller()
				refresh_room_view()
				get_viewport().set_input_as_handled()
		return
	if not _studio_drag_active:
		return
	if event is InputEventMouseMotion:
		_update_studio_drag_preview((event as InputEventMouseMotion).global_position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finish_studio_drag(mb.global_position)
			get_viewport().set_input_as_handled()


func _on_list_item_pressed(item_type: String, entity_id: int, btn: Button) -> void:
	if _move_mode_active:
		_end_move_mode(false)
	release_view()  # release current room's view before switching
	var target_room_id: int = -1
	if item_type == "task":
		target_room_id = Database.get_task_studio_room(entity_id)
	elif item_type == "curio_canister":
		target_room_id = Database.get_curio_canister_studio_room(entity_id)
	if target_room_id <= 0:
		target_room_id = StudioRoomManager.create_room(item_type, entity_id)
		if item_type == "task":
			Database.update_task(entity_id, "studio_room", target_room_id)
		else:
			Database.update_curio_canister(entity_id, "studio_room", target_room_id)
	if target_room_id > 0:
		load_room(target_room_id)
		_attach_claimed_view_to_card()
		_refresh_sticker_controller_room()
		_select_list_button(btn)


func _select_list_button(btn: Button) -> void:
	if _selected_list_button == btn:
		return
	# Reset previous selection
	if is_instance_valid(_selected_list_button):
		_selected_list_button.add_theme_color_override("font_color", GameData.FG_COLOR)
	# Apply new selection
	_selected_list_button = btn
	if is_instance_valid(_selected_list_button):
		_selected_list_button.add_theme_color_override("font_color", Color("#ffd700"))


func _select_list_for_current_room() -> void:
	if owner_type == "task" and _tasks_flow != null:
		for c in _tasks_flow.get_children():
			if c is Button and int(c.get_meta("entity_id", -1)) == owner_id:
				_select_list_button(c as Button)
				return
	if owner_type == "curio_canister" and _curio_canisters_flow != null:
		for c in _curio_canisters_flow.get_children():
			if c is Button and int(c.get_meta("entity_id", -1)) == owner_id:
				_select_list_button(c as Button)
				return


func _exit_tree() -> void:
	if _move_mode_active:
		_end_move_mode(false)
	if auto_save_on_exit and is_dirty:
		save_room()
	release_view()


func _is_over_left_panel(global_pos: Vector2) -> bool:
	if not is_instance_valid(_left_panel):
		return false
	return _left_panel.get_global_rect().has_point(global_pos)


# ═══════════════════════════════════════════════════════════════════
# PUBLIC: LOAD / SAVE
# ═══════════════════════════════════════════════════════════════════

## Load room p_room_id from Database.
## Populates working state from persisted data, or builds a blank
## default when the room record has never been written.
## Returns true on success.
func load_room(p_room_id: int) -> bool:
	if p_room_id <= 0:
		_emit_load_failed(p_room_id, "room_id must be > 0")
		return false

	var raw: Dictionary = Database.get_studio_room_data(p_room_id)
	if raw.is_empty():
		_emit_load_failed(p_room_id, "room not found in Database")
		return false

	room_id    = p_room_id
	owner_type = str(raw.get("owner_type", ""))
	owner_id   = int(raw.get("owner_id",   -1))

	if owner_type not in VALID_OWNER_TYPES:
		_emit_load_failed(p_room_id, "unknown owner_type '%s'" % owner_type)
		room_id = -1
		return false

	_apply_working_state_from_room_data(raw)
	_snapshot_state()
	is_dirty  = false
	is_loaded = true
	room_loaded.emit(room_id)
	# Auto-select corresponding list item in the right panel
	_select_list_for_current_room()
	return true


## Persist working state to Database.
## Writes a full StudioRoomData record (stickers + paint).
## Returns true on success; false if no room is loaded.
func save_room() -> bool:
	if not is_loaded or room_id <= 0:
		push_warning("StudioRoomController.save_room: no room loaded")
		return false

	_sync_stickers_from_controller()  # ensure _working_slots is up to date from sticker controller
	var data := _build_room_data_for_save()
	Database.upsert_studio_room_data(data)

	# Mirror the equipped sticker slots back onto the owning entity so
	# gameplay/state consumers (e.g. PlayTab) can read rituals/consumables.
	var saved_stickers := _clone_slots(_working_slots)
	if owner_type == "task":
		var rituals: Array = []
		var consumables: Array = []
		for slot in saved_stickers:
			if slot is not Dictionary or (slot as Dictionary).is_empty():
				continue
			var st := slot as Dictionary
			var s_type := str(st.get("type", "")).strip_edges()
			var s_id := str(st.get("id", "")).strip_edges()
			if s_id == "":
				continue
			if s_type == "ritual":
				rituals.append(s_id)
			elif s_type == "consumable":
				consumables.append(s_id)
		Database.update_task(owner_id, "sticker_slots", saved_stickers)
		Database.update_task(owner_id, "rituals", rituals)
		Database.update_task(owner_id, "consumables", consumables)
		Database.update_task(owner_id, "card_color", _working_card_color)
		_update_gamedata_task(owner_id, saved_stickers, rituals, consumables)
	elif owner_type == "curio_canister":
		Database.update_curio_canister(owner_id, "sticker_slots", saved_stickers)
		Database.update_curio_canister(owner_id, "card_color", _working_card_color)
		_update_gamedata_curio_canister(owner_id, saved_stickers)

	_snapshot_state()
	is_dirty = false
	# Notify composition consumers (StudioRoomManager cache + linked previews).
	SignalBus.studio_room_updated.emit(room_id)
	room_saved.emit(room_id)
	GameData.state_changed.emit()
	return true


## Reset working state to the last-saved snapshot.
## Does NOT reload from disk; use load_room() for that.
func discard_changes() -> void:
	if not is_loaded:
		return
	_working_slots      = _clone_slots(_saved_slots)
	_working_paint      = _saved_paint.duplicate(true)
	_working_card_color = _saved_card_color
	is_dirty = false


## Refresh the borrowed view node to reflect current working state.
## A no-op when no view has been claimed.
func refresh_room_view() -> void:
	if not is_instance_valid(_claimed_view):
		return
	if owner_type == "task":
		var view := _claimed_view as TaskDiceBoxView
		if view != null:
			view.set_task(_build_entity_preview_data())
	# Relic views (TextureRect) are refreshed automatically when
	# the texture is swapped; call _refresh_relic_view() explicitly.
	else:
		_refresh_relic_view()


# ═══════════════════════════════════════════════════════════════════
# PUBLIC: STICKER LOGIC
# ═══════════════════════════════════════════════════════════════════

## Return the slot dict at idx, or {} when out of bounds or empty.
func get_sticker_at_slot(idx: int) -> Dictionary:
	if idx < 0 or idx >= _working_slots.size():
		return {}
	var slot: Variant = _working_slots[idx]
	if slot is Dictionary:
		return (slot as Dictionary).duplicate()
	return {}


## Overwrite slot idx with slot_data.
## Provide a dict with type, id, x, y – or {} to clear.
func set_sticker_at_slot(idx: int, slot_data: Dictionary) -> void:
	if idx < 0 or idx >= MAX_STICKER_SLOTS:
		push_warning("StudioRoomController.set_sticker_at_slot: index %d out of range" % idx)
		return
	_ensure_slots_size()
	if slot_data.is_empty():
		_working_slots[idx] = {}
	else:
		var s_type := str(slot_data.get("type", "")).strip_edges()
		var s_id   := str(slot_data.get("id",   "")).strip_edges()
		if s_type not in ["ritual", "consumable"] or s_id.is_empty():
			push_warning("StudioRoomController.set_sticker_at_slot: invalid slot_data")
			return
		var fallback: Vector2 = _legacy_slot_norm_pos(idx)
		_working_slots[idx] = {
			"type": s_type,
			"id":   s_id,
			"x":    clampf(float(slot_data.get("x", fallback.x)), 0.0, 1.0),
			"y":    clampf(float(slot_data.get("y", fallback.y)), 0.0, 1.0),
		}
	_mark_dirty()


## Place a sticker at the slot nearest to norm_pos (0-1 card coords).
## Tries the closest empty slot within SNAP_THRESHOLD first; falls back
## to the first empty slot; falls back to the selected slot (slot 0).
## Returns the slot index assigned, or -1 if all slots are occupied.
func place_sticker(sticker_type: String, sticker_id: String, norm_pos: Vector2) -> int:
	if sticker_type not in ["ritual", "consumable"] or sticker_id.is_empty():
		push_warning("StudioRoomController.place_sticker: invalid type or id")
		return -1
	_ensure_slots_size()

	# Snap to an existing slot near norm_pos.
	var target := _slot_index_near_norm_pos(norm_pos)
	if target < 0:
		target = _first_empty_slot_index()
	if target < 0:
		return -1  # all slots full

	_working_slots[target] = {
		"type": sticker_type,
		"id":   sticker_id,
		"x":    clampf(norm_pos.x, 0.0, 1.0),
		"y":    clampf(norm_pos.y, 0.0, 1.0),
	}
	_mark_dirty()
	return target


## Move the sticker at slot_idx to a new normalised position.
## The type and id are preserved; only x/y change.
func move_sticker_to(slot_idx: int, norm_pos: Vector2) -> void:
	var slot := get_sticker_at_slot(slot_idx)
	if slot.is_empty():
		return
	slot["x"] = clampf(norm_pos.x, 0.0, 1.0)
	slot["y"] = clampf(norm_pos.y, 0.0, 1.0)
	_working_slots[slot_idx] = slot
	_mark_dirty()


## Swap the contents of two sticker slots.
func swap_sticker_slots(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return
	_ensure_slots_size()
	var a := get_sticker_at_slot(from_idx)
	var b := get_sticker_at_slot(to_idx)
	_working_slots[from_idx] = b
	_working_slots[to_idx]   = a
	_mark_dirty()


## Remove the sticker from slot idx.
func clear_sticker_at_slot(idx: int) -> void:
	if idx < 0 or idx >= _working_slots.size():
		return
	_working_slots[idx] = {}
	_mark_dirty()


## Remove all stickers from every slot.
func clear_all_stickers() -> void:
	_build_blank_slots()
	_mark_dirty()


## Number of slots that contain a sticker.
func occupied_slot_count() -> int:
	var n := 0
	for slot in _working_slots:
		if slot is Dictionary and not (slot as Dictionary).is_empty():
			n += 1
	return n


## Array of all non-empty slot dicts (no index gaps; order preserved).
func get_filled_slots() -> Array:
	var result: Array = []
	for slot in _working_slots:
		if slot is Dictionary and not (slot as Dictionary).is_empty():
			result.append((slot as Dictionary).duplicate())
	return result


## Sticker ids currently placed on the card for the given type.
## Includes stickers that are in the working slots even if they are not
## in the player's owned satchel (e.g. legacy data).
func sticker_ids_on_card(sticker_type: String) -> Array:
	var ids: Array = []
	for slot in _working_slots:
		if slot is not Dictionary:
			continue
		var s: Dictionary = slot
		if s.is_empty():
			continue
		if str(s.get("type", "")) == sticker_type:
			ids.append(str(s.get("id", "")))
	return ids


# ═══════════════════════════════════════════════════════════════════
# PUBLIC: PAINT LOGIC
# ═══════════════════════════════════════════════════════════════════

## Return a deep duplicate of the working paint data.
## The schema is consumer-defined; this controller does not validate it.
func get_paint_data() -> Dictionary:
	return _working_paint.duplicate(true)


## Replace the working paint data entirely.
func set_paint_data(data: Dictionary) -> void:
	_working_paint = data.duplicate(true)
	_mark_dirty()


## Merge data into the existing paint data.
## Keys in data overwrite matching keys in the working paint.
func merge_paint_data(data: Dictionary) -> void:
	_working_paint.merge(data, true)
	_mark_dirty()


## Remove all paint strokes from working state.
func clear_paint_data() -> void:
	_working_paint = {}
	_mark_dirty()


# ═══════════════════════════════════════════════════════════════════
# PUBLIC: CARD COLOR
# ═══════════════════════════════════════════════════════════════════

func get_card_color() -> String:
	return _working_card_color


## Set the card base-texture colour.
## color_key must be one of VALID_CARD_COLORS; invalid keys are ignored.
func set_card_color(color_key: String) -> void:
	if color_key not in VALID_CARD_COLORS:
		push_warning("StudioRoomController.set_card_color: unknown key '%s'" % color_key)
		return
	if color_key == _working_card_color:
		return
	_working_card_color = color_key
	_mark_dirty()
	_refresh_relic_view()


# ═══════════════════════════════════════════════════════════════════
# PUBLIC: VIEW MANAGEMENT
# ═══════════════════════════════════════════════════════════════════

## Borrow the persistent view node from StudioRoomManager.
## The caller is responsible for reparenting the node into its own layout.
## Returns null when no room is loaded or the room has no live node yet.
func claim_view() -> Control:
	if not is_loaded or room_id <= 0:
		return null
	var entity_data := _resolve_entity_data()
	_claimed_view = StudioRoomManager.claim_room_view(room_id, owner_type, entity_data)
	refresh_room_view()
	return _claimed_view


## Return the view node to StudioRoomManager's off-screen host.
func release_view() -> void:
	if room_id > 0:
		StudioRoomManager.release_room_view(room_id)
	_claimed_view = null


# ═══════════════════════════════════════════════════════════════════
# PRIVATE: PERSISTENCE HELPERS
# ═══════════════════════════════════════════════════════════════════

## Construct a save-ready StudioRoomData from current working state.
func _build_room_data_for_save() -> StudioRoomData:
	var data := StudioRoomData.from_dict({
		"room_id":    room_id,
		"owner_type": owner_type,
		"owner_id":   owner_id,
	})
	# Normalise slots: only persist filled, valid entries.
	var out_stickers: Array = []
	for i in range(_working_slots.size()):
		var slot: Variant = _working_slots[i]
		if slot is not Dictionary:
			continue
		var s: Dictionary = slot
		if s.is_empty():
			continue
		var s_type := str(s.get("type", "")).strip_edges()
		var s_id   := str(s.get("id",   "")).strip_edges()
		if s_type not in ["ritual", "consumable"] or s_id.is_empty():
			continue
		var fallback: Vector2 = _legacy_slot_norm_pos(i)
		out_stickers.append({
			"type": s_type,
			"id":   s_id,
			"x":    clampf(float(s.get("x", fallback.x)), 0.0, 1.0),
			"y":    clampf(float(s.get("y", fallback.y)), 0.0, 1.0),
		})
	data.stickers   = out_stickers
	data.paint_data = _working_paint.duplicate(true)
	return data


## Populate working state from a raw room-data dict returned by Database.
## Falls back to a blank state when the dict contains no sticker data.
func _apply_working_state_from_room_data(raw: Dictionary) -> void:
	var raw_stickers: Variant = raw.get("stickers", [])
	if raw_stickers is Array and not (raw_stickers as Array).is_empty():
		_working_slots = _normalize_slots(raw_stickers as Array, true)
	else:
		# Room exists but no sticker art yet – use blank default.
		_build_blank_state()

	var raw_paint: Variant = raw.get("paint_data", {})
	_working_paint = (raw_paint as Dictionary).duplicate(true) if raw_paint is Dictionary else {}

	# Card colour lives on the entity, not the room record; resolve below.
	_working_card_color = _resolve_entity_card_color()


## Take snapshots of every working-state value for dirty detection.
func _snapshot_state() -> void:
	_saved_slots      = _clone_slots(_working_slots)
	_saved_paint      = _working_paint.duplicate(true)
	_saved_card_color = _working_card_color


## Apply blank default content to working state.
func _build_blank_state() -> void:
	_build_blank_slots()
	_working_paint      = {}
	_working_card_color = "white"


func _mark_dirty() -> void:
	is_dirty = true


func _emit_load_failed(p_room_id: int, reason: String) -> void:
	push_warning("StudioRoomController: load_failed(room_id=%d) – %s" % [p_room_id, reason])
	load_failed.emit(p_room_id, reason)


# ═══════════════════════════════════════════════════════════════════
# PRIVATE: SLOT HELPERS
# ═══════════════════════════════════════════════════════════════════

## Normalise raw slot data from Database or entity dicts into the internal
## { type, id, x, y } format.  When preserve_empty is true the returned
## Array is padded with {} up to MAX_STICKER_SLOTS.
func _update_gamedata_task(task_id: int, sticker_slots: Array, rituals: Array, consumables: Array) -> void:
	for t in GameData.tasks:
		if int(t.get("id", -1)) == task_id:
			t["sticker_slots"] = _clone_slots(sticker_slots)
			t["rituals"] = rituals.duplicate()
			t["consumables"] = consumables.duplicate()
			t["card_color"] = _working_card_color
			t["studio_room"] = room_id
			return


func _update_gamedata_curio_canister(curio_canister_id: int, sticker_slots: Array) -> void:
	for r in GameData.curio_canisters:
		if int(r.get("id", -1)) == curio_canister_id:
			r["sticker_slots"] = _clone_slots(sticker_slots)
			r["card_color"] = _working_card_color
			r["studio_room"] = room_id
			return


func _normalize_slots(raw: Array, preserve_empty: bool = false) -> Array:
	var out: Array = []
	for slot_val in raw:
		if out.size() >= MAX_STICKER_SLOTS:
			break
		if slot_val is Dictionary:
			var s: Dictionary = slot_val
			var s_type := str(s.get("type", "")).strip_edges()
			var s_id   := str(s.get("id",   "")).strip_edges()
			if (s_type == "ritual" or s_type == "consumable") and s_id != "":
				var fallback: Vector2 = _legacy_slot_norm_pos(out.size())
				out.append({
					"type": s_type,
					"id":   s_id,
					"x":    clampf(float(s.get("x", fallback.x)), 0.0, 1.0),
					"y":    clampf(float(s.get("y", fallback.y)), 0.0, 1.0),
				})
			elif preserve_empty:
				out.append({})
		elif preserve_empty:
			out.append({})
	if preserve_empty:
		while out.size() < MAX_STICKER_SLOTS:
			out.append({})
	return out


## Build the fallback legacy grid position for slot index idx.
func _legacy_slot_norm_pos(idx: int) -> Vector2:
	if idx >= 0 and idx < LEGACY_SLOT_POSITIONS.size():
		var p: Vector2 = LEGACY_SLOT_POSITIONS[idx]
		return Vector2(clampf(p.x, 0.0, 1.0), clampf(p.y, 0.0, CARD_TOP_RATIO))
	return Vector2(0.5, CARD_TOP_RATIO * 0.5)


## Resolve (or default) the norm position stored in a slot dict.
func _slot_norm_pos(slot: Dictionary, fallback_idx: int) -> Vector2:
	if slot.is_empty():
		return _legacy_slot_norm_pos(fallback_idx)
	var fallback: Vector2 = _legacy_slot_norm_pos(fallback_idx)
	return Vector2(
		clampf(float(slot.get("x", fallback.x)), 0.0, 1.0),
		clampf(float(slot.get("y", fallback.y)), 0.0, 1.0),
	)


## Return the first non-empty slot whose saved position is within
## SNAP_THRESHOLD of norm_pos.  Returns -1 if none qualifies.
func _slot_index_near_norm_pos(norm_pos: Vector2) -> int:
	for i in range(_working_slots.size()):
		if _working_slots[i] is not Dictionary:
			continue
		var s: Dictionary = _working_slots[i]
		if s.is_empty():
			continue
		if _slot_norm_pos(s, i).distance_to(norm_pos) <= SNAP_THRESHOLD:
			return i
	return -1


## Index of the first empty slot, or -1 if all are occupied.
func _first_empty_slot_index() -> int:
	for i in range(_working_slots.size()):
		var s: Variant = _working_slots[i]
		if s is not Dictionary or (s as Dictionary).is_empty():
			return i
	return -1


## Deep-copy a slots array.
func _clone_slots(source: Array) -> Array:
	var out: Array = []
	for slot in source:
		out.append((slot as Dictionary).duplicate(true) if slot is Dictionary else {})
	return out


## Canonical string fingerprint of slot contents for change detection.
func _slot_signature(slots: Array) -> String:
	var parts: Array = []
	for i in range(slots.size()):
		var s: Variant = slots[i]
		if s is not Dictionary or (s as Dictionary).is_empty():
			parts.append("_")
			continue
		var sd: Dictionary = s
		var s_type := str(sd.get("type", ""))
		var s_id   := str(sd.get("id",   ""))
		if s_type.is_empty() or s_id.is_empty():
			parts.append("_")
		else:
			parts.append("%s:%s@%.3f,%.3f" % [
				s_type, s_id,
				clampf(float(sd.get("x", 0.0)), 0.0, 1.0),
				clampf(float(sd.get("y", 0.0)), 0.0, 1.0),
			])
	return ",".join(parts)


## Initialise _working_slots to MAX_STICKER_SLOTS empty dicts.
func _build_blank_slots() -> void:
	_working_slots = []
	for _i in range(MAX_STICKER_SLOTS):
		_working_slots.append({})


## Ensure _working_slots has exactly MAX_STICKER_SLOTS entries.
func _ensure_slots_size() -> void:
	if _working_slots.size() < MAX_STICKER_SLOTS:
		while _working_slots.size() < MAX_STICKER_SLOTS:
			_working_slots.append({})
	elif _working_slots.size() > MAX_STICKER_SLOTS:
		_working_slots = _working_slots.slice(0, MAX_STICKER_SLOTS)


# ═══════════════════════════════════════════════════════════════════
# PRIVATE: ENTITY DATA HELPERS
# ═══════════════════════════════════════════════════════════════════

## Pull the card_color field from the owning entity (task or relic).
## Falls back to "white" when the entity cannot be found.
func _resolve_entity_card_color() -> String:
	var raw := _find_raw_entity()
	if raw.is_empty():
		return "white"
	var color := str(raw.get("card_color", "white")).strip_edges()
	return color if color in VALID_CARD_COLORS else "white"


## Return the raw entity dict from Database, or {} if not found.
func _find_raw_entity() -> Dictionary:
	if owner_type == "task":
		for t in Database.get_tasks(GameData.current_profile):
			if int(t.get("id", -1)) == owner_id:
				return t
		# Also check archived tasks.
		for t in Database.get_tasks(GameData.current_profile, true):
			if int(t.get("id", -1)) == owner_id:
				return t
	elif owner_type == "curio_canister":
		for r in Database.get_curio_canisters(GameData.current_profile):
			if int(r.get("id", -1)) == owner_id:
				return r
		for r in Database.get_curio_canisters(GameData.current_profile, true):
			if int(r.get("id", -1)) == owner_id:
				return r
	return {}


## Build the minimal entity dict needed to refresh the live view node.
func _resolve_entity_data() -> Dictionary:
	var raw := _find_raw_entity()
	if raw.is_empty():
		return {}
	var out: Dictionary = raw.duplicate(true)
	out["card_color"]    = _working_card_color
	out["sticker_slots"] = _clone_slots(_working_slots)
	return out


## Build a preview-only entity dict (used to refresh TaskDiceBoxView).
## For tasks the controller holds no task-name/difficulty overrides
## beyond what is in the entity itself; callers that allow editing
## those fields should override this data before calling refresh_room_view().
func _build_entity_preview_data() -> Dictionary:
	return _resolve_entity_data()


## Refresh a relic TextureRect from the current card colour.
func _refresh_relic_view() -> void:
	if not is_instance_valid(_claimed_view):
		return
	if owner_type != "relic":
		return
	var tex_rect := _claimed_view as TextureRect
	if tex_rect == null:
		return
	const CARD_BASE_TEXTURES := {
		"white": "res://assets/textures/Card Base/Card_Base_White.png",
		"blue":  "res://assets/textures/Card Base/Card_Base_Blue.png",
		"green": "res://assets/textures/Card Base/Card_Base_Green.png",
		"brown": "res://assets/textures/Card Base/Card_Base_Brown.png",
	}
	var tex_path: String = CARD_BASE_TEXTURES.get(_working_card_color, CARD_BASE_TEXTURES["white"])
	if ResourceLoader.exists(tex_path):
		tex_rect.texture = load(tex_path)


## Check whether working state has actually changed relative to the snapshot.
## More accurate than the lazy is_dirty flag for edge cases (e.g. round-trip edits).
func has_real_changes() -> bool:
	if _working_card_color != _saved_card_color:
		return true
	if _slot_signature(_working_slots) != _slot_signature(_saved_slots):
		return true
	if _working_paint != _saved_paint:
		return true
	return false
