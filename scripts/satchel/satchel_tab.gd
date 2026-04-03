extends Control

# SatchelTab.gd – Merged Satchel (Archive tab)
# Gallery-first style: flow cards, hover overlay for Edit/Delete
# Tasks: edit name, die sides, difficulty
# Curio Canisters: edit name and mult

const SATCHEL_BG_TEXTURE_PATH: String = "res://assets/ui/satchel/satchel_plain_brown_bg.png"
# SATCHEL_BUTTON_* constants removed — now uses GameData.SATCHEL_BTN_*
const STICKER_DEFAULT_TEXTURE_PATH: String = "res://assets/textures/stickers/Sticker_default.png"
const TASK_DICE_BOX_VIEW_SCRIPT := preload("res://scripts/ui/task_dice_box_view.gd")
const STUDIO_PAINT_CANVAS_SCRIPT := preload("res://scripts/ui/studio_paint_canvas.gd")
const STUDIO_STICKER_PLACEMENT_CONTROLLER_SCRIPT := preload("res://scripts/ui/studio_sticker_placement_controller.gd")
const STUDIO_STICKER_SCRIPT := preload("res://scripts/ui/studio_sticker.gd")
const CARD_BASE_TEXTURES := {
	"white": "res://assets/textures/Card Base/Card_Base_White.png",
	"blue": "res://assets/textures/Card Base/Card_Base_Blue.png",
	"green": "res://assets/textures/Card Base/Card_Base_Green.png",
	"brown": "res://assets/textures/Card Base/Card_Base_Brown.png",
}
const CARD_COLOR_ORDER := ["white", "blue", "green", "brown"]
const CARD_COLOR_LABELS := {
	"white": "White",
	"blue": "Blue",
	"green": "Green",
	"brown": "Brown",
}
const SATCHEL_CARD_SIZE := Vector2(230, 320)
const SATCHEL_CURIO_CANISTER_CARD_SCALE := Vector2(0.75, 0.75)
const HOVER_TILT_SCRIPT := preload("res://scripts/HoverCardTilt.gd")
const STUDIO_LEGACY_SLOT_POINTS := [
	Vector2(0.20, 0.18),
	Vector2(0.50, 0.14),
	Vector2(0.80, 0.18),
	Vector2(0.20, 0.56),
	Vector2(0.50, 0.56),
	Vector2(0.80, 0.56),
]
const STUDIO_TOP_AREA_RATIO: float = 0.62
const STUDIO_GRID_COLS: int = 26
const STUDIO_GRID_ROWS: int = 16

var _section:        String = "table"
var _main_tab:      String = "table"
var _filter_btns:    Dictionary = {}
var _flow:           HFlowContainer
var _section_header: VBoxContainer
var _qa_name:        LineEdit
var _qa_val:      LineEdit
var _qa_type:     OptionButton

# Contracts form state
var _c_entry_name:     LineEdit
var _c_entry_subtasks: LineEdit
var _c_entry_notes:    LineEdit
var _c_diff_option:    OptionButton
var _c_reward_option:  OptionButton
var _c_deadline_btn:   Button
var _c_selected_deadline: String = ""
var _c_cal_layer: CanvasLayer
var _c_cal_year:  int = 0
var _c_cal_month: int = 0
var _studio_popup: PopupPanel
var _studio_kind: String = ""
var _studio_entity_id: int = -1
var _studio_card_color: String = "white"
var _studio_slots: Array = []
var _studio_initial_card_color: String = "white"
var _studio_initial_slots: Array = []
var _studio_card_tex: TextureRect
var _studio_card_root: Control
var _studio_popup_root: Control
var _studio_name_label: Label
var _studio_book_hint: Label
var _studio_task_preview: TaskDiceBoxView
var _studio_task_name_edit: LineEdit
var _studio_task_diff_spin: SpinBox
var _studio_task_die_opt: OptionButton
var _studio_source_data: Dictionary = {}
var _studio_initial_task_name: String = ""
var _studio_initial_task_difficulty: int = 1
var _studio_initial_task_die_sides: int = 6
var _studio_drag_active: bool = false
var _studio_drag_type: String = ""
var _studio_drag_id: String = ""
var _studio_drag_emoji: String = ""
var _studio_drag_preview: Control
var _studio_sticker_controller: StudioStickerPlacementController = null
var _current_room_id: int = -1
var _studio_paint_canvas: Control = null
var _studio_paint_mode_btn: Button = null
# True when the user has made paint strokes (or cleared) since the studio
# was opened or last saved.  Drives the "unsaved changes" discard dialog.
var _studio_paint_dirty: bool = false

const BOSS_LEVELS := {
	"No Priority":  {"color": Color(0.8, 0.8, 0.8, 1.0),  "emoji": "📋", "label": "NO PRIORITY"},
	"Low Priority": {"color": Color(0.9, 0.82, 0.1, 1.0),  "emoji": "⚠️",  "label": "LOW PRIORITY"},
	"Med Priority": {"color": Color(1.0, 0.55, 0.1, 1.0),  "emoji": "⚠️",  "label": "MED PRIORITY"},
	"High Priority":{"color": Color(0.95, 0.12, 0.12, 1.0), "emoji": "💀",  "label": "HIGH PRIORITY"},
}

const DECOR_CATALOG := {
	"dec_gnome":      {"char": "G", "color": "#cc8844", "name": "Garden Gnome",    "desc": "A cheerful little garden gnome watching over your plants."},
	"dec_flamingo":   {"char": "F", "color": "#ff69b4", "name": "Plastic Flamingo", "desc": "A gloriously tacky hot-pink plastic flamingo."},
	"dec_birdbath":   {"char": "B", "color": "#99bbcc", "name": "Bird Bath",        "desc": "A stone bird bath. Birds love it."},
	"dec_lantern":    {"char": "S", "color": "#ffee88", "name": "Stone Lantern",    "desc": "A softly glowing stone lantern."},
	"dec_pot":        {"char": "P", "color": "#cc6633", "name": "Flower Pot",       "desc": "A terracotta planter full of possibilities."},
	"dec_bench":      {"char": "N", "color": "#886644", "name": "Garden Bench",     "desc": "A comfortable wooden bench for contemplation."},
	"dec_fence":      {"char": "W", "color": "#ccaa88", "name": "Fence Section",    "desc": "A wooden picket fence section."},
	"dec_windchimes": {"char": "C", "color": "#aaddff", "name": "Wind Chimes",      "desc": "Delicate chimes that sing in the breeze."},
}

func _ready() -> void:
	GameData.state_changed.connect(_refresh)
	if has_node("/root/SignalBus"):
		SignalBus.theme_changed.connect(_on_theme_changed_satchel)
	_build_ui()
	_ensure_studio_popup()
	_refresh()

func _on_theme_changed_satchel() -> void:
	_build_ui(); _refresh()

func _play_rollover_sfx() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_dice_clack()

# Simplified curio drag state and helpers (top-level)
var _curio_drag_active: bool = false
var _curio_drag_id: String = ""
var _curio_drag_preview: Control = null

func _begin_curio_drag(curio_id: String, emoji: String, global_pos: Vector2) -> void:
	_curio_drag_active = true
	_curio_drag_id = curio_id
	if is_instance_valid(_curio_drag_preview):
		_curio_drag_preview.queue_free()
	var preview := Label.new()
	preview.text = emoji
	preview.add_theme_font_size_override("font_size", GameData.scaled_font_size(28))
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
	add_child(preview)
	_curio_drag_preview = preview
	# Position preview near start point (local mouse position)
	var local = get_local_mouse_position()
	_curio_drag_preview.position = local + Vector2(8, 8)

func _finish_curio_drag() -> void:
	_curio_drag_active = false
	_curio_drag_id = ""
	if is_instance_valid(_curio_drag_preview):
		_curio_drag_preview.queue_free()
	_curio_drag_preview = null

# Build the main UI structure
func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)

	# Section header with filter buttons
	_section_header = VBoxContainer.new()
	_section_header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(_section_header)


	# QA controls
	_qa_name = LineEdit.new()
	_qa_name.placeholder_text = "Filter..."
	_qa_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section_header.add_child(_qa_name)

	_qa_val = LineEdit.new()
	_qa_val.placeholder_text = "Value..."
	_qa_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section_header.add_child(_qa_val)

	# Meals per day setting (always visible)
	var meals_row := HBoxContainer.new()
	var ml := Label.new(); ml.text = "Default meals per day:"
	ml.add_theme_color_override("font_color", GameData.FG_COLOR)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meals_row.add_child(ml)
	var meal_opt := OptionButton.new()
	meal_opt.add_item("1 meal  (I usually eat 1)")
	meal_opt.add_item("2 meals (I usually eat 2)")
	meal_opt.add_item("3 meals (I eat all 3!)")
	var cur_meals: int = int(Database.get_setting("default_meals", 1))
	meal_opt.selected = clampi(cur_meals - 1, 0, 2)
	meal_opt.item_selected.connect(func(idx):
		Database.save_setting("default_meals", idx + 1)
	)
	meals_row.add_child(meal_opt)
	_section_header.add_child(meals_row)

	# Flow container for cards
	_flow = HFlowContainer.new()
	_flow.add_theme_constant_override("h_separation", 12)
	_flow.add_theme_constant_override("v_separation", 12)
	main_vbox.add_child(_flow)

	# Initialize with table section
	_switch_main_tab("table")

# Style helper for satchel buttons — uses GameData constants
func _style_satchel_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = GameData.SATCHEL_BTN_BG
	style.border_color = GameData.SATCHEL_BTN_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = GameData.SATCHEL_BTN_HOVER
	hover_style.border_color = GameData.SATCHEL_BTN_BORDER
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = GameData.SATCHEL_BTN_PRESSED
	pressed_style.border_color = GameData.SATCHEL_BTN_BORDER
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed_style)

# Apply theme to all satchel buttons
func _apply_satchel_button_theme(container: Container) -> void:
	for btn in container.get_children():
		if btn is Button:
			_style_satchel_button(btn)

# Style helper for card panels (matches PlayTab _style_card)
func _style_card(panel: PanelContainer, bg: Color, border: Color, bw: int, radius: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", s)

func _attach_hover_tilt(ctrl: Control, tilt_deg: float = 3.0, scale_mul: float = 1.03) -> void:
	if ctrl == null:
		return
	ctrl.set_script(HOVER_TILT_SCRIPT)
	ctrl.set("max_tilt_degrees", tilt_deg)
	ctrl.set("hover_scale", scale_mul)
	ctrl.set("hover_wobble_degrees", 1.05)
	ctrl.set("hover_wobble_speed", 8.2)

func _switch_main_tab(tab_key: String) -> void:
	_main_tab = tab_key
	# Clear sub-tabs
	for c in _section_header.get_children(): c.queue_free()
	for c in _flow.get_children(): c.queue_free()
	
	# Build sub-tabs based on main tab
	match tab_key:
		"table":
			_build_table_subtabs()
		"garden": 
			_build_garden_subtabs()
		"confectionery":
			_build_confectionery_subtabs()

func _build_table_subtabs() -> void:
	var sub_tabs := [
		["tasks", "Dice Management", GameData.CHIP_COLOR],
		["dice", "Dice", Color("#ffaa00")],
	]
	for sd in sub_tabs:
		var btn := Button.new()
		btn.text = sd[1] as String
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		_style_satchel_button(btn)
		var k: String = sd[0]
		btn.pressed.connect(func(): _switch_section(k))
		_section_header.add_child(btn)
		_filter_btns[k] = btn
	_switch_section("tasks")

func _build_garden_subtabs() -> void:
	var sub_tabs := [
		["contracts", "Contracts", Color("#ffcc44")],
		["plants", "Plants", Color("#44cc44")],
		["decor", "Decor", Color("#cc8844")],
		["curio_management", "Curio Management", GameData.MULT_COLOR],
	]
	for sd in sub_tabs:
		var btn := Button.new()
		btn.text = sd[1] as String
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		_style_satchel_button(btn)
		var k: String = sd[0]
		btn.pressed.connect(func(): _switch_section(k))
		_section_header.add_child(btn)
		_filter_btns[k] = btn
	_switch_section("contracts")

func _build_confectionery_subtabs() -> void:
	var sub_tabs := [
		["ingredients", "Ingredients", Color("#8B4513")],
	]
	for sd in sub_tabs:
		var btn := Button.new()
		btn.text = sd[1] as String
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		_style_satchel_button(btn)
		var k: String = sd[0]
		btn.pressed.connect(func(): _switch_section(k))
		_section_header.add_child(btn)
		_filter_btns[k] = btn
	_switch_section("ingredients")

func _unhandled_input(event: InputEvent) -> void:
	if _studio_popup == null or not _studio_popup.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _studio_drag_active:
				_cancel_studio_drag()
				get_viewport().set_input_as_handled()
				return
			_save_studio_and_close()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if _studio_drag_active:
				_cancel_studio_drag()
			_save_studio_and_close()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if _studio_popup == null or not _studio_popup.visible:
		return
	if _studio_sticker_controller != null and _studio_sticker_controller.is_drag_active():
		if event is InputEventMouseMotion:
			_studio_sticker_controller.update_drag((event as InputEventMouseMotion).global_position)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var sticker_mb := event as InputEventMouseButton
			if sticker_mb.button_index == MOUSE_BUTTON_LEFT and not sticker_mb.pressed:
				_studio_sticker_controller.end_drag()
				_sync_studio_slots_from_controller()
				_refresh_studio_card_preview()
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

func _refresh() -> void:
	# Initialize main tab and sub-tabs
	_switch_main_tab(_main_tab)

func open_section(key: String) -> void:
	_switch_section(key)

func _switch_section(key: String) -> void:
	_section = key
	for k in _filter_btns:
		var btn: Button = _filter_btns[k]
		btn.modulate = Color.WHITE if k == key else Color(0.55,0.55,0.55,1.0)
	if not is_instance_valid(_flow): return
	for c in _section_header.get_children(): c.queue_free()
	for c in _flow.get_children(): c.queue_free()
	match key:
		"tasks":     _build_tasks()
		"curio_management":    _build_curio_canisters()
		"plants":    _build_plants()
		"decor":     _build_decor()
		"dice":      _build_dice()
		"contracts": _build_contracts_section()
		"ingredients": _build_ingredients()
		"achievements": _build_achievements()
	_apply_satchel_button_theme(_flow)
#  TASKS section
# ─────────────────────────────────────────────────────────────────
func _build_tasks() -> void:
	_add_hdr("🎲 DICE BOXES", GameData.CHIP_COLOR, "Completed dice boxes roll dice and earn MOONDROPS  •  Hover for options")
	for task in GameData.tasks:
		_flow.add_child(_make_task_card(task))

func _make_task_card(task: Dictionary) -> Control:
	const STARS_H: float = 28.0
	var difficulty: int = clampi(int(task.get("difficulty", 1)), 1, 5)
	var wrapper := Control.new()
	wrapper.custom_minimum_size = SATCHEL_CARD_SIZE

	# ── Styled panel (mirrors PlayTab) ──────────────────────────
	var card := PanelContainer.new()
	card.custom_minimum_size = SATCHEL_CARD_SIZE
	_style_card(card, Color(1.0, 1.0, 1.0, 1.0), GameData.CARD_HL, 1, 16)
	_set_card_base_visual(card, str(task.get("card_color", "white")))

	# Apply room composition as card background texture
	var _task_room_id := int(task.get("studio_room", -1))
	if _task_room_id > 0:
		var tex_rect: TextureRect = card.get_node_or_null("CardBaseTexture") as TextureRect
		if tex_rect != null:
			tex_rect.texture = StudioRoomManager.get_composition(_task_room_id)
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wrapper.add_child(card)

	# ── Margin + content (mirrors PlayTab container hierarchy) ──
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var content_v := VBoxContainer.new()
	content_v.add_theme_constant_override("separation", 4)
	margin.add_child(content_v)

	# Difficulty stars at the top of the card
	var stars_lbl := Label.new()
	stars_lbl.text = "⭐".repeat(difficulty)
	stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	stars_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	stars_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_v.add_child(stars_lbl)

	# Preview area
	var preview_slot := Control.new()
	preview_slot.custom_minimum_size = Vector2(0, 224)
	preview_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_v.add_child(preview_slot)

	var box_view := TASK_DICE_BOX_VIEW_SCRIPT.new()
	box_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box_view.set_task(task)
	box_view.set_preview_scale(1.02)
	box_view.set_camera_size(1.8)
	box_view.activated.connect(func(_task_id: int): _open_card_studio("task", task))
	preview_slot.add_child(box_view)
	box_view.set_name_label_visible(false)

	# Name label below preview
	var name_lbl := Label.new()
	name_lbl.text = str(task.get("task", "Task"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_v.add_child(name_lbl)

	# Spacer to push content up
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_v.add_child(spacer)

	# Always-visible corner action buttons (top-left, vertical column)
	var is_default: bool = task.get("is_default", false)
	var corner_vb := VBoxContainer.new()
	corner_vb.anchor_left = 0.0
	corner_vb.anchor_top = 0.0
	corner_vb.offset_left = 4
	corner_vb.offset_top = 4
	corner_vb.custom_minimum_size = Vector2(76, 90 if not is_default else 36)
	corner_vb.add_theme_constant_override("separation", 2)
	corner_vb.mouse_filter = Control.MOUSE_FILTER_STOP
	if not is_default:
		var studio_btn := Button.new()
		studio_btn.text = "Edit"
		studio_btn.tooltip_text = "Open Studio"
		studio_btn.custom_minimum_size = Vector2(72, 26)
		studio_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		studio_btn.pressed.connect(func(): _open_card_studio("task", task))
		_style_satchel_button(studio_btn)
		corner_vb.add_child(studio_btn)

		var arch_btn := Button.new()
		arch_btn.text = "Archive"
		arch_btn.tooltip_text = "Archive"
		arch_btn.custom_minimum_size = Vector2(72, 26)
		arch_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		arch_btn.pressed.connect(func(): _archive_task(task.id))
		_style_satchel_button(arch_btn)
		corner_vb.add_child(arch_btn)

		var del_btn := Button.new()
		del_btn.text = "Delete"
		del_btn.tooltip_text = "Delete"
		del_btn.custom_minimum_size = Vector2(72, 26)
		del_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		del_btn.pressed.connect(func(): _confirm_delete_task(task.id))
		_style_satchel_button(del_btn)
		corner_vb.add_child(del_btn)
	else:
		var opt_btn := Button.new()
		opt_btn.text = "⚙"
		opt_btn.tooltip_text = "Options"
		opt_btn.custom_minimum_size = Vector2(32, 28)
		opt_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		opt_btn.pressed.connect(func(): _open_task_options(task))
		_style_satchel_button(opt_btn)
		corner_vb.add_child(opt_btn)

	wrapper.add_child(corner_vb)

	# Apply hover tilt directly to the panel (matches PlayTab)
	_attach_hover_tilt(card, 3.0, 1.03)
	card.mouse_entered.connect(_play_rollover_sfx if has_method("_play_rollover_sfx") else func(): pass)

	return wrapper

func _make_hover_overlay_task(task: Dictionary) -> Control:
	var is_default: bool = task.get("is_default", false)
	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var ov_st := StyleBoxFlat.new()
	ov_st.bg_color = Color(GameData.CARD_BG, 0.92)
	ov_st.border_color = GameData.CHIP_COLOR
	ov_st.set_border_width_all(2); ov_st.set_corner_radius_all(5)
	overlay.add_theme_stylebox_override("panel", ov_st)

	var center_wrap := CenterContainer.new()
	center_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center_wrap)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	center_wrap.add_child(vb)

	if not is_default:
		var edit_btn := Button.new(); edit_btn.text = "🎨  Open Studio"
		edit_btn.add_theme_color_override("font_color", GameData.CHIP_COLOR)
		edit_btn.pressed.connect(func(): overlay.visible = false; _open_card_studio("task", task))
		vb.add_child(edit_btn)

		var arch_btn := Button.new(); arch_btn.text = "📦  Archive"
		arch_btn.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
		arch_btn.pressed.connect(func(): overlay.visible = false; _archive_task(task.id))
		vb.add_child(arch_btn)

		var del_btn := Button.new(); del_btn.text = "🗑  Delete"
		del_btn.add_theme_color_override("font_color", GameData.ACCENT_RED)
		del_btn.pressed.connect(func(): overlay.visible = false; _confirm_delete_task(task.id))
		vb.add_child(del_btn)
	else:
		# Default task: show permanent badge + options
		var perm_lbl := Label.new(); perm_lbl.text = "⚓ Permanent Task"
		perm_lbl.add_theme_color_override("font_color", Color(GameData.CHIP_COLOR, 0.7))
		perm_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		perm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(perm_lbl)

		var opt_btn := Button.new(); opt_btn.text = "⚙  Options"
		opt_btn.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
		opt_btn.pressed.connect(func(): overlay.visible = false; _open_task_options(task))
		vb.add_child(opt_btn)

	return overlay

func _open_task_options(task: Dictionary) -> void:
	var task_name: String = str(task.get("task",""))
	var is_water: bool = "water" in task_name.to_lower() or "drink" in task_name.to_lower() or "hydrat" in task_name.to_lower()
	var is_eat: bool   = "eat" in task_name.to_lower() or ("food" in task_name.to_lower())

	var dialog := AcceptDialog.new()
	dialog.title = "⚙  %s Options" % task_name
	dialog.get_ok_button().text = "Save"

	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 10)
	dialog.add_child(vb)

	if is_water:
		var remind_key := "remind_water"
		var cur_val: bool = bool(Database.get_setting(remind_key, true))
		var chk := CheckBox.new(); chk.text = "Remind me to drink water today"
		chk.button_pressed = cur_val
		vb.add_child(chk)
		dialog.confirmed.connect(func():
			Database.save_setting(remind_key, chk.button_pressed)
			dialog.queue_free())

	elif is_eat:
		var remind_key := "remind_food"
		var cur_val: bool = bool(Database.get_setting(remind_key, true))
		var remind_chk := CheckBox.new(); remind_chk.text = "Remind me to eat today"
		remind_chk.button_pressed = cur_val
		vb.add_child(remind_chk)

		var meals_row := HBoxContainer.new(); vb.add_child(meals_row)
		var ml := Label.new(); ml.text = "Default meals per day:"
		ml.add_theme_color_override("font_color", GameData.FG_COLOR)
		ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meals_row.add_child(ml)
		var meal_opt := OptionButton.new()
		meal_opt.add_item("1 meal  (I usually eat 1)")
		meal_opt.add_item("2 meals (I usually eat 2)")
		meal_opt.add_item("3 meals (I eat all 3!)")
		var cur_meals: int = int(Database.get_setting("default_meals", 1))
		meal_opt.selected = clampi(cur_meals - 1, 0, 2)
		meals_row.add_child(meal_opt)

		var hint := Label.new()
		hint.text = "This pre-selects your meal count in the Play tab."
		hint.add_theme_color_override("font_color", Color(GameData.ACCENT_GOLD, 0.6))
		hint.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(hint)

		dialog.confirmed.connect(func():
			Database.save_setting(remind_key, remind_chk.button_pressed)
			Database.save_setting("default_meals", meal_opt.selected + 1)
			dialog.queue_free())
	else:
		var lbl := Label.new(); lbl.text = "No configurable options for this task."
		lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
		vb.add_child(lbl)
		dialog.confirmed.connect(func(): dialog.queue_free())

	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog); dialog.popup_centered(Vector2i(360, 200))

# ─────────────────────────────────────────────────────────────────
#  CURIO CANISTERS section — uses CurioManagementScreen
# ─────────────────────────────────────────────────────────────────
const CURIO_MANAGEMENT_SCREEN_SCENE := preload("res://scenes/curio_management_screen.tscn")

func _build_curio_canisters() -> void:
	var screen := CURIO_MANAGEMENT_SCREEN_SCENE.instantiate()
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.custom_minimum_size = Vector2(0, 520)
	_flow.add_child(screen)

func _make_owned_curio_card(curio_id: String) -> Control:
	var curio: CurioResource = CurioManager.get_curio_resource(curio_id)
	if curio == null:
		return Control.new()

	var rarity_colors := {
		"common": Color(0.7, 0.7, 0.7),
		"uncommon": Color(0.3, 0.8, 0.4),
		"rare": Color(0.3, 0.5, 1.0),
		"exotic": Color(0.8, 0.3, 1.0),
	}
	var rarity_col: Color = rarity_colors.get(curio.rarity, Color(0.7, 0.7, 0.7))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(rarity_col.r * 0.12, rarity_col.g * 0.12, rarity_col.b * 0.12, 0.85)
	st.border_color = Color(rarity_col, 0.6)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", st)

	# Enable drag
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_begin_curio_drag(curio_id, curio.emoji, ev.global_position)
	)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Emoji
	var emoji_lbl := Label.new()
	emoji_lbl.text = curio.emoji
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(24))
	emoji_lbl.custom_minimum_size = Vector2(32, 0)
	emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(emoji_lbl)

	# Info column
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	# Name + rarity
	var name_lbl := Label.new()
	name_lbl.text = curio.display_name
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	name_lbl.add_theme_color_override("font_color", rarity_col)
	name_lbl.clip_text = true
	info_vbox.add_child(name_lbl)

	# Rarity badge
	var rarity_lbl := Label.new()
	rarity_lbl.text = curio.rarity.capitalize()
	rarity_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	rarity_lbl.add_theme_color_override("font_color", Color(rarity_col, 0.7))
	info_vbox.add_child(rarity_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = curio.description
	desc_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	desc_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.clip_text = true
	info_vbox.add_child(desc_lbl)

	# Equipped status
	var equipped_canister_id := -1
	for cid in CurioManager.get_all_equipped():
		if CurioManager.get_all_equipped()[cid] == curio_id:
			equipped_canister_id = int(cid)
			break
	if equipped_canister_id >= 0:
		var equipped_lbl := Label.new()
		var canister_name := "Canister #%d" % equipped_canister_id
		for cc in GameData.curio_canisters:
			if int(cc.get("id", -1)) == equipped_canister_id:
				canister_name = str(cc.get("title", "Canister #%d" % equipped_canister_id))
				break
		equipped_lbl.text = "📦 Equipped: %s" % canister_name
		equipped_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		equipped_lbl.add_theme_color_override("font_color", Color(GameData.ACCENT_GOLD, 0.8))
		info_vbox.add_child(equipped_lbl)

	return panel

func _make_curio_canister_card(curio_canister: Dictionary) -> Control:
	# Use same sizing as Play tab for consistency
	const PLAY_CARD_SIZE := Vector2(230, 320)
	const CURIO_CANISTER_CARD_SCALE := Vector2(0.75, 0.75)
	const PLAY_CARD_TOP_RATIO := 0.62
	
	var wrapper := Control.new()
	wrapper.custom_minimum_size = PLAY_CARD_SIZE * CURIO_CANISTER_CARD_SCALE

	# Accept curio drop via click-release while dragging
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.set_meta("curio_canister_data", curio_canister)
	wrapper.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _curio_drag_active:
			var canister_id = int(curio_canister.get("id", -1))
			if canister_id >= 0 and _curio_drag_id != "":
				if CurioManager.equip_curio(_curio_drag_id, canister_id):
					_refresh()
			_finish_curio_drag()
	)

	var curio_canister_col: Color = GameData.MULT_COLOR
	var is_active: bool = curio_canister.get("active", false)
	var curio_canister_bg: Color = Color(GameData.CARD_BG, 1.0) if is_active else Color(GameData.CARD_BG, 0.8)

	var card := PanelContainer.new()
	card.custom_minimum_size = PLAY_CARD_SIZE
	card.pivot_offset = PLAY_CARD_SIZE * 0.5
	card.scale = CURIO_CANISTER_CARD_SCALE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.add_child(card)
	
	# Style the card similar to Play tab
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = curio_canister_bg
	card_style.border_color = curio_canister_col if is_active else GameData.CARD_HL
	card_style.set_border_width_all(2 if is_active else 1)
	card_style.set_corner_radius_all(16)
	card.add_theme_stylebox_override("panel", card_style)
	
	# Set card base visual (background texture/color)
	_set_card_base_visual(card, str(curio_canister.get("card_color", "white")))
	
	# Apply room composition to the card background
	var _curio_canister_room_id := int(curio_canister.get("studio_room", -1))
	if _curio_canister_room_id > 0:
		var tex_rect: TextureRect = card.get_node_or_null("CardBaseTexture") as TextureRect
		if tex_rect != null:
			tex_rect.texture = StudioRoomManager.get_composition(_curio_canister_room_id)
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	# Make card clickable to open studio
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_open_card_studio("curio_canister", curio_canister)
	)
 


	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6 if side in ["left","right"] else 4)
	card.add_child(margin)

	var content_v := VBoxContainer.new()
	content_v.add_theme_constant_override("separation", 4)
	margin.add_child(content_v)

	# Preview strip (similar to Play tab)
	var strip := PanelContainer.new()
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Color(1.0, 1.0, 1.0, 0.32)
	strip_style.border_color = Color(0.16, 0.12, 0.08, 0.24)
	strip_style.set_border_width_all(1)
	strip_style.set_corner_radius_all(4)
	strip.add_theme_stylebox_override("panel", strip_style)
	strip.custom_minimum_size = Vector2(0, PLAY_CARD_SIZE.y * PLAY_CARD_TOP_RATIO - 18.0)
	content_v.add_child(strip)

	# Sticker slots row
	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 3)
	strip.add_child(strip_row)
	
	# Add sticker slots (6 slots like in Play tab)
	for i in range(6):
		var slot := Label.new()
		slot.text = ""
		slot.custom_minimum_size = Vector2(18, 0)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
		strip_row.add_child(slot)
	
	# Add stickers from curio canister data
	var slots: Array = _task_slots_from_data(curio_canister, false)
	for slot_data in slots:
		var slot_index: int = clampi(int(slot_data.get("index", 0)), 0, 5)
		if slot_index < strip_row.get_child_count():
			var slot_label: Label = strip_row.get_child(slot_index) as Label
			if slot_label != null:
				var sticker_type: String = str(slot_data.get("type", ""))
				var sticker_id: String = str(slot_data.get("id", ""))
				var emoji: String = ""
				if sticker_type == "ritual":
					emoji = str(GameData.RITUAL_STICKERS.get(sticker_id, {}).get("emoji", ""))
				elif sticker_type == "consumable":
					emoji = str(GameData.CONSUMABLE_STICKERS.get(sticker_id, {}).get("emoji", ""))
				slot_label.text = emoji

	var strip_flex := Control.new()
	strip_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_row.add_child(strip_flex)

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_v.add_child(grow)

	# Curio Canister emoji (centered in preview area)
	var emoji_lbl := Label.new()
	emoji_lbl.text = str(curio_canister.get("emoji", "✦"))
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(34))
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_color_override("font_color", Color(0.22, 0.10, 0.18, 1.0))
	emoji_lbl.anchors_preset = Control.PRESET_FULL_RECT
	emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(emoji_lbl)

	# Curio Canister name label (below preview area)
	var curio_canister_name_lbl := Label.new()
	curio_canister_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	curio_canister_name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	curio_canister_name_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	curio_canister_name_lbl.text = str(curio_canister.get("title", "Curio Canister"))
	curio_canister_name_lbl.clip_text = true
	curio_canister_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_v.add_child(curio_canister_name_lbl)

	# Mult label
	var mult_lbl := Label.new()
	mult_lbl.text = "+%.2fx star power" % float(curio_canister.get("mult", 0.3))
	mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mult_lbl.add_theme_color_override("font_color", GameData.MULT_COLOR)
	mult_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	content_v.add_child(mult_lbl)

	# Always-visible corner action buttons (top-left, vertical column)
	var corner_vb := VBoxContainer.new()
	corner_vb.anchor_left = 0.0
	corner_vb.anchor_top = 0.0
	corner_vb.offset_left = 4
	corner_vb.offset_top = 4
	corner_vb.custom_minimum_size = Vector2(76, 84)
	corner_vb.add_theme_constant_override("separation", 2)
	corner_vb.mouse_filter = Control.MOUSE_FILTER_STOP

	var studio_btn := Button.new()
	studio_btn.text = "Edit"
	studio_btn.tooltip_text = "Open Studio"
	studio_btn.custom_minimum_size = Vector2(72, 24)
	studio_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	studio_btn.pressed.connect(func(): _open_card_studio("curio_canister", curio_canister))
	_style_satchel_button(studio_btn)
	corner_vb.add_child(studio_btn)

	var equip_btn := Button.new()
	equip_btn.text = "Equip"
	equip_btn.tooltip_text = "Equip a Curio from your stash"
	equip_btn.custom_minimum_size = Vector2(72, 24)
	equip_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	equip_btn.pressed.connect(func(): _open_equip_curio_popup(curio_canister))
	_style_satchel_button(equip_btn)
	corner_vb.add_child(equip_btn)

	var arch_btn := Button.new()
	arch_btn.text = "Archive"
	arch_btn.tooltip_text = "Archive"
	arch_btn.custom_minimum_size = Vector2(72, 24)
	arch_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	arch_btn.pressed.connect(func(): _archive_curio_canister(curio_canister.id))
	_style_satchel_button(arch_btn)
	corner_vb.add_child(arch_btn)

	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.tooltip_text = "Delete"
	del_btn.custom_minimum_size = Vector2(72, 24)
	del_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	del_btn.pressed.connect(func(): _confirm_delete_curio_canister(curio_canister.id))
	_style_satchel_button(del_btn)
	corner_vb.add_child(del_btn)

	wrapper.add_child(corner_vb)

	_attach_hover_tilt(wrapper, 3.0, 1.03)

	return wrapper

func _open_equip_curio_popup(canister: Dictionary) -> void:
	var popup := PopupPanel.new()
	popup.name = "EquipCurioPopup"
	popup.rect_min_size = Vector2(560, 360)
	add_child(popup)

	var vb := VBoxContainer.new()
	vb.margin_left = 8
	vb.margin_top = 8
	popup.add_child(vb)

	var title := Label.new()
	title.text = "Equip Curio to Canister"
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	vb.add_child(title)

	var content_h := HBoxContainer.new()
	content_h.h_size_flags = Control.SIZE_EXPAND_FILL
	vb.add_child(content_h)

	# Left: canister preview
	var left_v := VBoxContainer.new()
	left_v.custom_minimum_size = Vector2(200, 0)
	content_h.add_child(left_v)

	var canister_label := Label.new()
	canister_label.text = "Canister: %s" % canister.get("id", "?")
	left_v.add_child(canister_label)

	var equipped_id: String = CurioManager.get_equipped_curio(canister.get("id"))
	if equipped_id:
		var equipped_res: CurioResource = CurioManager.get_curio_resource(equipped_id)
		var label_eq := Label.new()
		var equipped_name := str(equipped_id)
		if equipped_res:
			if equipped_res.has_property("display_name"):
				equipped_name = equipped_res.display_name
			elif equipped_res.has_property("name"):
				equipped_name = equipped_res.name
		label_eq.text = "Equipped: %s" % equipped_name
		left_v.add_child(label_eq)

	# Right: scroll listing owned curios
	var sc := ScrollContainer.new()
	sc.v_size_flags = Control.SIZE_EXPAND_FILL
	sc.h_size_flags = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(320, 260)
	content_h.add_child(sc)

	var list_v := VBoxContainer.new()
	list_v.custom_minimum_size = Vector2(300, 0)
	sc.add_child(list_v)

	var owned: Array = CurioManager.get_owned_curios()
	if owned.size() == 0:
		var none_lbl := Label.new()
		none_lbl.text = "No curios in your stash."
		list_v.add_child(none_lbl)
	else:
		for curio_id in owned:
			var h := HBoxContainer.new()
			h.custom_minimum_size = Vector2(0, 36)
			list_v.add_child(h)
			var res: CurioResource = CurioManager.get_curio_resource(curio_id)
			var name_lbl := Label.new()
			var display_name := str(curio_id)
			if res:
				if res.has_property("display_name"):
					display_name = res.display_name
				elif res.has_property("name"):
					display_name = res.name
			name_lbl.text = display_name
			name_lbl.h_size_flags = Control.SIZE_EXPAND_FILL
			h.add_child(name_lbl)
			var equip_button := Button.new()
			equip_button.text = "Equip"
			# connect with closure to capture ids and popup
			equip_button.pressed.connect(func():
				CurioManager.equip_curio(curio_id, canister.get("id"))
				popup.queue_free()
				_refresh()
			)
			h.add_child(equip_button)

	var close_hb := HBoxContainer.new()
	close_hb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(close_hb)

	var cancel_btn := Button.new()
	cancel_btn.text = "Close"
	cancel_btn.pressed.connect(func(): popup.queue_free())
	close_hb.add_child(cancel_btn)

	# show centered
	popup.popup_centered()

func _make_hover_overlay_curio_canister(curio_canister: Dictionary) -> Control:
	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var ov_st := StyleBoxFlat.new()
	ov_st.bg_color = Color(GameData.CARD_BG, 0.92)
	ov_st.border_color = GameData.MULT_COLOR
	ov_st.set_border_width_all(2); ov_st.set_corner_radius_all(8)
	overlay.add_theme_stylebox_override("panel", ov_st)

	var center_wrap := CenterContainer.new()
	center_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center_wrap)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	center_wrap.add_child(vb)

	var edit_btn := Button.new(); edit_btn.text = "🎨  Open Studio"
	edit_btn.add_theme_color_override("font_color", GameData.MULT_COLOR)
	edit_btn.pressed.connect(func(): overlay.visible = false; _open_card_studio("curio_canister", curio_canister))
	vb.add_child(edit_btn)

	var arch_btn := Button.new(); arch_btn.text = "📦  Archive"
	arch_btn.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	arch_btn.pressed.connect(func(): overlay.visible = false; _archive_curio_canister(curio_canister.id))
	vb.add_child(arch_btn)

	var del_btn := Button.new(); del_btn.text = "🗑  Delete"
	del_btn.add_theme_color_override("font_color", GameData.ACCENT_RED)
	del_btn.pressed.connect(func(): overlay.visible = false; _confirm_delete_curio_canister(curio_canister.id))
	vb.add_child(del_btn)

	return overlay

func _make_satchel_card_panel(card_color: String, border_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.06, 0.03, 0.65)
	st.border_color = border_color
	st.set_border_width_all(2)
	st.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", st)

	var tex := TextureRect.new()
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.texture = _texture_for_card_color(card_color)
	panel.add_child(tex)

	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(1.0, 1.0, 1.0, 0.06)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tint)
	return panel

func _task_slots_from_data(data: Dictionary, preserve_empty: bool = false) -> Array:
	var slots: Array = []
	var raw_slots: Variant = data.get("sticker_slots", [])
	if raw_slots is Array and not (raw_slots as Array).is_empty():
		for slot_value in raw_slots:
			if slot_value is Dictionary:
				var slot_dict: Dictionary = slot_value
				var slot_type := str(slot_dict.get("type", "")).strip_edges()
				var slot_id := str(slot_dict.get("id", "")).strip_edges()
				if (slot_type == "ritual" or slot_type == "consumable") and slot_id != "":
					var default_pos: Vector2 = _legacy_slot_norm_pos(slots.size())
					var norm_x: float = clampf(float(slot_dict.get("x", default_pos.x)), 0.0, 1.0)
					var norm_y: float = clampf(float(slot_dict.get("y", default_pos.y)), 0.0, 1.0)
					slots.append({"type": slot_type, "id": slot_id, "x": norm_x, "y": norm_y})
				elif preserve_empty:
					continue
			elif preserve_empty:
				continue
		return slots
	for rid in data.get("rituals", []):
		var rp: Vector2 = _legacy_slot_norm_pos(slots.size())
		slots.append({"type": "ritual", "id": str(rid), "x": rp.x, "y": rp.y})
	for cid in data.get("consumables", []):
		var cp: Vector2 = _legacy_slot_norm_pos(slots.size())
		slots.append({"type": "consumable", "id": str(cid), "x": cp.x, "y": cp.y})
	return slots


func _studio_stickers_from_room_or_data(room_id: int, data: Dictionary) -> Array:
	if room_id > 0:
		var raw_room := Database.get_studio_room_data(room_id)
		if not raw_room.is_empty():
			var room_stickers: Variant = raw_room.get("stickers", [])
			if room_stickers is Array and not (room_stickers as Array).is_empty():
				var normalized: Array = []
				for sticker_value in room_stickers:
					if sticker_value is not Dictionary:
						continue
					var entry := StudioStickerEntry.from_dictionary(sticker_value as Dictionary)
					if not entry.is_valid():
						continue
					normalized.append(entry.to_dictionary())
				return normalized
	return _task_slots_from_data(data, false)

func _build_satchel_sticker_strip(slots: Array) -> Control:
	var strip := HFlowContainer.new()
	strip.add_theme_constant_override("h_separation", 6)
	strip.add_theme_constant_override("v_separation", 6)
	strip.alignment = FlowContainer.ALIGNMENT_CENTER
	if slots.is_empty():
		var blank_lbl := Label.new()
		blank_lbl.text = "Blank card"
		blank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blank_lbl.add_theme_color_override("font_color", Color(0.28, 0.20, 0.12, 0.7))
		blank_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		strip.add_child(blank_lbl)
		return strip
	for slot in slots:
		var chip := PanelContainer.new()
		var chip_style := StyleBoxFlat.new()
		chip_style.bg_color = Color(1.0, 0.97, 0.89, 0.92)
		chip_style.border_color = Color(0.45, 0.30, 0.18, 0.8)
		chip_style.set_border_width_all(1)
		chip_style.set_corner_radius_all(8)
		chip_style.content_margin_left = 6
		chip_style.content_margin_right = 6
		chip_style.content_margin_top = 4
		chip_style.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", chip_style)
		var lbl := Label.new()
		lbl.text = _emoji_for_studio_slot(slot)
		lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(lbl)
		strip.add_child(chip)
	return strip

func _die_label_for_card(sides: int) -> String:
	return GameData.DICE_CHARS[5] if sides == 6 else "d%d" % sides

# ─────────────────────────────────────────────────────────────────
#  Edit modals
# ─────────────────────────────────────────────────────────────────
func _open_edit_task(task: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "✏  Edit Dice Box"
	dialog.get_ok_button().text = "Save"

	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 8)
	dialog.add_child(vb)

	# Name
	var name_row := HBoxContainer.new(); vb.add_child(name_row)
	var nl := Label.new(); nl.text = "Name:"; nl.custom_minimum_size = Vector2(80,0)
	nl.add_theme_color_override("font_color", GameData.FG_COLOR); name_row.add_child(nl)
	var name_edit := LineEdit.new(); name_edit.text = task.task
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; name_row.add_child(name_edit)

	# Difficulty
	var diff_row := HBoxContainer.new(); vb.add_child(diff_row)
	var dl := Label.new(); dl.text = "Difficulty:"
	dl.custom_minimum_size = Vector2(80,0)
	dl.add_theme_color_override("font_color", GameData.FG_COLOR); diff_row.add_child(dl)
	var diff_spin := SpinBox.new()
	diff_spin.min_value = 1; diff_spin.max_value = 5; diff_spin.step = 1
	diff_spin.value = task.difficulty
	diff_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL; diff_row.add_child(diff_spin)
	var diff_info := Label.new()
	diff_info.text = "  (dice rolled per dice box)"
	diff_info.add_theme_color_override("font_color", Color(GameData.ACCENT_GOLD, 0.6))
	diff_info.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); diff_row.add_child(diff_info)

	# Die sides
	var die_row := HBoxContainer.new(); vb.add_child(die_row)
	var diel := Label.new(); diel.text = "Die (d?):"
	diel.custom_minimum_size = Vector2(80,0)
	diel.add_theme_color_override("font_color", GameData.FG_COLOR); die_row.add_child(diel)
	var die_opt := OptionButton.new()
	var die_options := [6, 8, 10, 12, 20]
	for s in die_options:
		var label_txt := "d%d" % s
		if s != 6: label_txt += " (qty: %d)" % GameData.dice_satchel.get(s, 0)
		else: label_txt += " (∞ unlimited)"
		die_opt.add_item(label_txt)
	die_opt.selected = die_options.find(task.get("die_sides", 6))
	if die_opt.selected < 0: die_opt.selected = 0
	die_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; die_row.add_child(die_opt)

	add_child(dialog)
	dialog.popup_centered(Vector2i(380, 220))
	await get_tree().process_frame; name_edit.grab_focus()

	dialog.confirmed.connect(func():
		var new_name := name_edit.text.strip_edges()
		if not new_name.is_empty() and new_name != task.task:
			Database.update_task(task.id, "task", new_name)
		var new_diff := int(diff_spin.value)
		if new_diff != task.difficulty:
			Database.update_task(task.id, "difficulty", new_diff)
		var new_sides: int = die_options[die_opt.selected]
		if new_sides != task.get("die_sides", 6):
			Database.update_task(task.id, "die_sides", new_sides)
		_reload_gd(); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _open_edit_curio_canister(curio_canister: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "✏  Edit Curio Canister"
	dialog.get_ok_button().text = "Save"

	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 8)
	dialog.add_child(vb)

	# Name
	var name_row := HBoxContainer.new(); vb.add_child(name_row)
	var nl := Label.new(); nl.text = "Name:"; nl.custom_minimum_size = Vector2(80,0)
	nl.add_theme_color_override("font_color", GameData.FG_COLOR); name_row.add_child(nl)
	var name_edit := LineEdit.new(); name_edit.text = curio_canister.title
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; name_row.add_child(name_edit)

	# Difficulty (1-5) -> stored as star power = difficulty * 0.25
	var diff_row := HBoxContainer.new(); vb.add_child(diff_row)
	var dl := Label.new(); dl.text = "Difficulty:"; dl.custom_minimum_size = Vector2(80,0)
	dl.add_theme_color_override("font_color", GameData.FG_COLOR); diff_row.add_child(dl)
	var diff_spin := SpinBox.new()
	diff_spin.min_value = 1; diff_spin.max_value = 5; diff_spin.step = 1
	var cur_mult := float(curio_canister.get("mult", 0.25))
	var cur_diff := clampi(int(round(cur_mult / 0.25)), 1, 5)
	diff_spin.value = cur_diff
	diff_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL; diff_row.add_child(diff_spin)
	var diff_info := Label.new()
	diff_info.text = "  (1–5, x0.25 star power per level — e.g. 2 => 0.50)"
	diff_info.add_theme_color_override("font_color", Color(GameData.MULT_COLOR, 0.6))
	diff_info.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); diff_row.add_child(diff_info)

	# Equipped Curio dropdown
	var curio_row := HBoxContainer.new(); vb.add_child(curio_row)
	var cl := Label.new(); cl.text = "Curio:"; cl.custom_minimum_size = Vector2(80,0)
	cl.add_theme_color_override("font_color", GameData.FG_COLOR); curio_row.add_child(cl)
	var curio_opt := OptionButton.new()
	curio_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Add "None" option for unequipping
	curio_opt.add_item("— None —")
	curio_opt.set_item_metadata(0, "")
	# Get currently equipped curio
	var canister_id := int(curio_canister.get("id", -1))
	var equipped_curio_id := CurioManager.get_equipped_curio(canister_id) if canister_id >= 0 else ""
	# Populate with owned curios
	var owned_curios := CurioManager.get_owned_curios()
	var selected_idx := 0
	for curio_id in owned_curios:
		var curio_res := CurioManager.get_curio_resource(curio_id)
		if curio_res == null:
			continue
		var item_text := "%s %s" % [curio_res.emoji, curio_res.display_name]
		curio_opt.add_item(item_text)
		curio_opt.set_item_metadata(curio_opt.item_count - 1, curio_id)
		if curio_id == equipped_curio_id:
			selected_idx = curio_opt.item_count - 1
	curio_opt.selected = selected_idx
	curio_row.add_child(curio_opt)

	add_child(dialog)
	dialog.popup_centered(Vector2i(420, 240))
	await get_tree().process_frame; name_edit.grab_focus()

	dialog.confirmed.connect(func():
		var new_name := name_edit.text.strip_edges()
		if not new_name.is_empty() and new_name != curio_canister.title:
			Database.update_curio_canister(curio_canister.id, "title", new_name)
		var new_diff := int(diff_spin.value)
		var new_mult := float(new_diff) * 0.25
		if abs(new_mult - float(curio_canister.get("mult",0.3))) > 0.001:
			Database.update_curio_canister(curio_canister.id, "mult", new_mult)
		# Handle curio equip/unequip
		var selected_curio_id := str(curio_opt.get_item_metadata(curio_opt.selected))
		if canister_id >= 0:
			if selected_curio_id.is_empty():
				CurioManager.unequip_curio(canister_id)
			elif selected_curio_id != equipped_curio_id:
				CurioManager.equip_curio(selected_curio_id, canister_id)
		_reload_gd(); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _archive_curio_canister(curio_canister_id: int) -> void:
	Database.update_curio_canister(curio_canister_id, "archived", true)
	_reload_gd()

func _confirm_delete_curio_canister(curio_canister_id: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Curio Canister"
	dialog.dialog_text = "Delete this curio canister? This cannot be undone."
	dialog.confirmed.connect(func(): _delete_curio_canister(curio_canister_id); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog); dialog.popup_centered()

func _delete_curio_canister(curio_canister_id: int) -> void:
	var room_id: int = Database.get_curio_canister_studio_room(curio_canister_id)
	if _current_room_id == room_id:
		_current_room_id = -1
	Database.delete_curio_canister(curio_canister_id); _reload_gd(); GameData.state_changed.emit()
	var d := AcceptDialog.new()
	d.title = "Deleted"
	d.dialog_text = "Curio canister deleted."
	add_child(d); d.popup_centered()
	d.confirmed.connect(func(): d.queue_free())

func _ensure_studio_popup() -> void:
	if is_instance_valid(_studio_popup):
		return
	_studio_popup = PopupPanel.new()
	_studio_popup.name = "CardStudioPopup"
	_studio_popup.visible = false
	_studio_popup.exclusive = true
	_studio_popup.size = Vector2i(1180, 720)
	add_child(_studio_popup)
	_studio_popup.popup_hide.connect(_on_studio_popup_hidden)

func _on_studio_popup_hidden() -> void:
	_release_current_studio_room()

func _release_current_studio_room() -> void:
	if _current_room_id <= 0:
		return
	StudioRoomManager.release_room_view(_current_room_id)
	_current_room_id = -1

func _open_card_studio(kind: String, data: Dictionary) -> void:
	# ── Context validation ────────────────────────────────────────
	# The caller (🎨 button or hover-overlay button) passes the full
	# entity dict as |data|.  We need at minimum a valid kind and id.
	if kind != "task" and kind != "curio_canister":
		push_warning("_open_card_studio: unknown kind '%s' — ignoring" % kind)
		return
	var entity_id := int(data.get("id", -1))
	if entity_id < 0:
		push_warning("_open_card_studio: data has no valid 'id' field — ignoring")
		return

	_ensure_studio_popup()
	# Release any previously-held room before rebuilding the popup.
	_release_current_studio_room()
	_studio_kind = kind
	_studio_entity_id = entity_id
	_studio_card_color = str(data.get("card_color", "white"))
	# _studio_source_data is the single authoritative copy of the entity dict
	# used throughout the popup.  It is mutated below if a room must be created.
	_studio_source_data = data.duplicate(true)

	# ── Room resolution ───────────────────────────────────────────
	# Each task and curio_canister gets a studio_room int at creation time
	# (Database.insert_task / insert_curio_canister).  _reload_gd() copies that
	# field into GameData.tasks / GameData.curio_canisters so it arrives here
	# without requiring an extra Database look-up.
	#
	# If room_id is -1 the record pre-dates the migration (or was never
	# saved correctly).  Create a fresh room now so the popup always
	# opens a real persistent room — never an orphan temporary view.
	var room_id := int(_studio_source_data.get("studio_room", -1))
	if room_id <= 0:
		push_warning(
			"_open_card_studio: %s#%d has no studio_room; creating one now." \
			% [kind, entity_id]
		)
		room_id = StudioRoomManager.create_room(kind, entity_id)
		# Persist the new id on the entity so future openings find it directly.
		if kind == "task":
			Database.update_task(entity_id, "studio_room", room_id)
		else:
			Database.update_curio_canister(entity_id, "studio_room", room_id)
		_studio_source_data["studio_room"] = room_id

	_studio_initial_task_name = str(data.get("task", ""))
	_studio_initial_task_difficulty = int(data.get("difficulty", 1))
	_studio_initial_task_die_sides = int(data.get("die_sides", 6))
	_studio_slots = _studio_stickers_from_room_or_data(room_id, _studio_source_data)
	_studio_initial_card_color = _studio_card_color
	_studio_initial_slots = _clone_studio_slots(_studio_slots)
	_build_studio_popup(data)
	_studio_popup.popup_centered_ratio(0.92)

func _build_studio_popup(data: Dictionary) -> void:
	for c in _studio_popup.get_children():
		c.queue_free()
	_studio_task_preview = null
	_studio_card_tex = null
	_studio_task_name_edit = null
	_studio_task_diff_spin = null
	_studio_task_die_opt = null
	_studio_paint_canvas = null
	_studio_paint_mode_btn = null
	_studio_sticker_controller = null

	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color("#120d08")
	popup_style.border_color = GameData.SATCHEL_BTN_BORDER
	popup_style.set_border_width_all(2)
	popup_style.set_corner_radius_all(14)
	_studio_popup.add_theme_stylebox_override("panel", popup_style)

	var side_panel_width := 260.0
	var side_panel_gap := 18.0

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_studio_popup.add_child(root)
	_studio_popup_root = root

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(side_panel_width, 0)
	left_panel.anchor_left = 0.0
	left_panel.anchor_top = 0.0
	left_panel.anchor_right = 0.0
	left_panel.anchor_bottom = 1.0
	left_panel.offset_left = 0.0
	left_panel.offset_top = 0.0
	left_panel.offset_right = side_panel_width
	left_panel.offset_bottom = 0.0
	root.add_child(left_panel)
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color("#efe2c7")
	left_style.border_color = Color("#8b6345")
	left_style.set_border_width_all(2)
	left_style.set_corner_radius_all(14)
	left_style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	left_style.shadow_size = 6
	left_panel.add_theme_stylebox_override("panel", left_style)

	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_v)

	var left_title := Label.new()
	left_title.text = "Sticker Book"
	left_title.add_theme_color_override("font_color", Color("#533826"))
	left_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	left_v.add_child(left_title)

	_studio_book_hint = Label.new()
	_studio_book_hint.text = "Drag a sticker from the book onto the card. Drag placed stickers to reposition them, or right-click to remove them."
	_studio_book_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_studio_book_hint.add_theme_color_override("font_color", Color("#6f543f"))
	_studio_book_hint.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	left_v.add_child(_studio_book_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_v.add_child(scroll)

	var list_v := VBoxContainer.new()
	list_v.add_theme_constant_override("separation", 10)
	scroll.add_child(list_v)

	var clear_btn := Button.new()
	clear_btn.text = "Delete Selected Sticker"
	_style_satchel_button(clear_btn)
	clear_btn.pressed.connect(_clear_selected_studio_slot)
	list_v.add_child(clear_btn)

	if _studio_kind == "task":
		list_v.add_child(_build_sticker_book_section(
			"ritual",
			"Ritual Stickers",
			GameData.CHIP_COLOR,
			_owned_sticker_ids_for_current_card("ritual")
		))
		list_v.add_child(_build_sticker_book_section(
			"consumable",
			"Consumable Stickers",
			GameData.ACCENT_GOLD,
			_owned_sticker_ids_for_current_card("consumable")
		))
	else:
		list_v.add_child(_build_sticker_book_section(
			"ritual",
			"Ritual Stickers",
			GameData.CHIP_COLOR,
			_owned_sticker_ids_for_current_card("ritual")
		))
		list_v.add_child(_build_sticker_book_section(
			"consumable",
			"Consumable Stickers",
			GameData.ACCENT_GOLD,
			_owned_sticker_ids_for_current_card("consumable")
		))

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = side_panel_width + side_panel_gap
	center.offset_top = 0.0
	center.offset_right = -(side_panel_width + side_panel_gap)
	center.offset_bottom = 0.0
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 8)
	root.add_child(center)

	_studio_name_label = Label.new()
	_studio_name_label.text = str(data.get("task", data.get("title", "Card")))
	_studio_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_studio_name_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	_studio_name_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	center.add_child(_studio_name_label)

	var card_shell := PanelContainer.new()
	card_shell.custom_minimum_size = SATCHEL_CARD_SIZE
	card_shell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color(0.07, 0.05, 0.03, 0.92)
	shell_style.border_color = Color(0.96, 0.91, 0.84, 0.35)
	shell_style.set_border_width_all(2)
	shell_style.set_corner_radius_all(18)
	card_shell.add_theme_stylebox_override("panel", shell_style)
	center.add_child(card_shell)

	var card_root := Control.new()
	card_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_shell.add_child(card_root)

	# ── Claim the persistent room view ──────────────────────────
	# room_id is guaranteed to be valid here: _open_card_studio resolved
	# or created the room before calling _build_studio_popup, and stored
	# it in _studio_source_data["studio_room"].
	#
	# StudioRoomManager keeps one Control node alive per room (a
	# TaskDiceBoxView for tasks, a TextureRect for curio_canisters).  Claiming the
	# view moves it out of the hidden host and into our popup card root,
	# restoring all previously-saved sticker and paint state.
	var room_id := int(_studio_source_data.get("studio_room", -1))
	if room_id > 0:
		# Claim the persistent room view for this entity.
		# The view is reparented into card_root; releasing it on close will
		# move it back to StudioRoomManager's off-screen host automatically.
		var room_view := StudioRoomManager.claim_room_view(room_id, _studio_kind, _studio_source_data)
		room_view.reparent(card_root, false)
		room_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if _studio_kind == "task" and room_view is TaskDiceBoxView:
			_studio_task_preview = room_view as TaskDiceBoxView
			_studio_task_preview.set_preview_scale(1.14)
			_studio_task_preview.set_camera_size(1.68)
		else:
			_studio_card_tex = room_view as TextureRect
		_current_room_id = room_id
	else:
		# Should never happen: _open_card_studio always ensures a valid room_id.
		push_error("_build_studio_popup: studio_room is still -1 for %s#%d" \
			% [_studio_kind, _studio_entity_id])
	_add_studio_dev_grid(card_root)
	_studio_card_root = card_root

	# ── Paint canvas (transparent overlay on top of card) ─────────
	# Starts with MOUSE_FILTER_IGNORE so sticker slot buttons beneath it
	# remain clickable.  "Paint Mode" toggle switches to MOUSE_FILTER_STOP.
	_studio_paint_canvas = STUDIO_PAINT_CANVAS_SCRIPT.new()
	_studio_paint_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_studio_paint_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(_studio_paint_canvas)
	# Restore any previously-saved paint for this room.
	if room_id > 0:
		var _room_raw := Database.get_studio_room_data(room_id)
		if not _room_raw.is_empty():
			var _saved_pd: Variant = _room_raw.get("paint_data", {})
			if _saved_pd is Dictionary and not (_saved_pd as Dictionary).is_empty():
				_studio_paint_canvas.load_paint_data(_saved_pd as Dictionary)
	# Reset dirty flag — loading existing paint does not count as a change.
	# Connect AFTER loading so the restore itself does not set the flag.
	_studio_paint_dirty = false
	_studio_paint_canvas.canvas_modified.connect(func(): _studio_paint_dirty = true)
	_studio_sticker_controller = StudioStickerPlacementController.new()
	_studio_sticker_controller.setup(card_root)
	_studio_sticker_controller.load_stickers(_studio_slots)
	_studio_sticker_controller.selection_changed.connect(_on_studio_sticker_selection_changed)
	_studio_sticker_controller.sticker_added.connect(_on_studio_stickers_changed)
	_studio_sticker_controller.sticker_removed.connect(_on_studio_stickers_changed)
	_studio_sticker_controller.stickers_cleared.connect(_on_studio_stickers_reset)
	card_root.resized.connect(func():
		if _studio_sticker_controller != null:
			_studio_sticker_controller.on_container_resized()
	)
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(side_panel_width, 0)
	right_panel.anchor_left = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_left = -side_panel_width
	right_panel.offset_top = 0.0
	right_panel.offset_right = 0.0
	right_panel.offset_bottom = 0.0
	root.add_child(right_panel)
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color("#1f1710")
	right_style.border_color = GameData.SATCHEL_BTN_BORDER
	right_style.set_border_width_all(2)
	right_style.set_corner_radius_all(14)
	right_panel.add_theme_stylebox_override("panel", right_style)

	# right_outer: scrollable fields on top, save/cancel pinned at bottom
	var right_outer := VBoxContainer.new()
	right_outer.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_outer)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_outer.add_child(right_scroll)

	var right_v := VBoxContainer.new()
	right_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_v.add_theme_constant_override("separation", 10)
	right_scroll.add_child(right_v)

	# ── Paint tools ────────────────────────────────────────────────
	var paint_hdr := Label.new()
	paint_hdr.text = "Paint"
	paint_hdr.add_theme_color_override("font_color", GameData.SATCHEL_BTN_TEXT)
	paint_hdr.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	right_v.add_child(paint_hdr)

	_studio_paint_mode_btn = Button.new()
	_studio_paint_mode_btn.text = "Paint Mode: OFF"
	_studio_paint_mode_btn.toggle_mode = true
	_studio_paint_mode_btn.button_pressed = false
	_studio_paint_mode_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_satchel_button(_studio_paint_mode_btn)
	_studio_paint_mode_btn.toggled.connect(_on_studio_paint_mode_toggled)
	right_v.add_child(_studio_paint_mode_btn)

	var palette_lbl := Label.new()
	palette_lbl.text = "Color"
	palette_lbl.add_theme_color_override("font_color", GameData.SATCHEL_BTN_TEXT)
	palette_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	right_v.add_child(palette_lbl)

	var palette_colors: Array[Color] = [
		Color("#1a1a1a"), Color("#ffffff"), Color("#e03030"), Color("#e07820"),
		Color("#e0d020"), Color("#38c030"), Color("#20c8d0"), Color("#2050e0"),
		Color("#9030d0"), Color("#e030a0"), Color("#8b4513"), Color("#f5deb3"),
	]
	var palette_grid := GridContainer.new()
	palette_grid.columns = 4
	palette_grid.add_theme_constant_override("h_separation", 3)
	palette_grid.add_theme_constant_override("v_separation", 3)
	right_v.add_child(palette_grid)
	for pc in palette_colors:
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(30, 24)
		cb.flat = true
		var cb_normal := StyleBoxFlat.new()
		cb_normal.bg_color = pc
		cb_normal.set_corner_radius_all(3)
		cb.add_theme_stylebox_override("normal", cb_normal)
		var cb_hover_style := cb_normal.duplicate() as StyleBoxFlat
		cb_hover_style.border_color = Color.WHITE
		cb_hover_style.set_border_width_all(2)
		cb.add_theme_stylebox_override("hover", cb_hover_style)
		var cb_pressed_style := cb_normal.duplicate() as StyleBoxFlat
		cb_pressed_style.border_color = Color.YELLOW
		cb_pressed_style.set_border_width_all(3)
		cb.add_theme_stylebox_override("pressed", cb_pressed_style)
		var picked: Color = pc
		cb.pressed.connect(func():
			if is_instance_valid(_studio_paint_canvas):
				_studio_paint_canvas.brush_color = picked
		)
		palette_grid.add_child(cb)

	var tool_row_lbl := Label.new()
	tool_row_lbl.text = "Tool"
	tool_row_lbl.add_theme_color_override("font_color", GameData.SATCHEL_BTN_TEXT)
	tool_row_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	right_v.add_child(tool_row_lbl)

	var tool_hbox := HBoxContainer.new()
	tool_hbox.add_theme_constant_override("separation", 4)
	right_v.add_child(tool_hbox)

	var brush_btn_p := Button.new()
	brush_btn_p.text = "Brush"
	brush_btn_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_satchel_button(brush_btn_p)
	brush_btn_p.pressed.connect(func():
		if is_instance_valid(_studio_paint_canvas):
			_studio_paint_canvas.current_tool = STUDIO_PAINT_CANVAS_SCRIPT.Tool.BRUSH
	)
	tool_hbox.add_child(brush_btn_p)

	var eraser_btn_p := Button.new()
	eraser_btn_p.text = "Eraser"
	eraser_btn_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_satchel_button(eraser_btn_p)
	eraser_btn_p.pressed.connect(func():
		if is_instance_valid(_studio_paint_canvas):
			_studio_paint_canvas.current_tool = STUDIO_PAINT_CANVAS_SCRIPT.Tool.ERASER
	)
	tool_hbox.add_child(eraser_btn_p)

	var size_row_lbl := Label.new()
	size_row_lbl.text = "Brush Size"
	size_row_lbl.add_theme_color_override("font_color", GameData.SATCHEL_BTN_TEXT)
	size_row_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	right_v.add_child(size_row_lbl)

	var size_hbox := HBoxContainer.new()
	size_hbox.add_theme_constant_override("separation", 4)
	right_v.add_child(size_hbox)

	var brush_sizes := [["S", 3], ["M", 8], ["L", 16]]
	for sz_data in brush_sizes:
		var sz_btn := Button.new()
		sz_btn.text = str(sz_data[0])
		sz_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_satchel_button(sz_btn)
		var sz_val: int = int(sz_data[1])
		sz_btn.pressed.connect(func():
			if is_instance_valid(_studio_paint_canvas):
				_studio_paint_canvas.brush_size = sz_val
		)
		size_hbox.add_child(sz_btn)

	var clear_canvas_btn := Button.new()
	clear_canvas_btn.text = "Clear Canvas"
	clear_canvas_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_satchel_button(clear_canvas_btn)
	clear_canvas_btn.pressed.connect(_on_studio_clear_canvas_pressed)
	right_v.add_child(clear_canvas_btn)

	var paint_sep := HSeparator.new()
	paint_sep.add_theme_constant_override("separation", 6)
	right_v.add_child(paint_sep)

	if _studio_kind == "task":
		var name_lbl := Label.new()
		name_lbl.text = "Dice Box Name"
		name_lbl.add_theme_color_override("font_color", GameData.SATCHEL_BTN_TEXT)
		right_v.add_child(name_lbl)

		_studio_task_name_edit = LineEdit.new()
		_studio_task_name_edit.text = str(data.get("task", "Untitled Dice Box"))
		_studio_task_name_edit.text_changed.connect(_refresh_studio_card_preview)
		right_v.add_child(_studio_task_name_edit)

		var diff_lbl := Label.new()
		diff_lbl.text = "Difficulty"
		diff_lbl.add_theme_color_override("font_color", GameData.SATCHEL_BTN_TEXT)
		right_v.add_child(diff_lbl)

		_studio_task_diff_spin = SpinBox.new()
		_studio_task_diff_spin.min_value = 1
		_studio_task_diff_spin.max_value = 5
		_studio_task_diff_spin.step = 1
		_studio_task_diff_spin.value = int(data.get("difficulty", 1))
		_studio_task_diff_spin.value_changed.connect(func(_value: float): _refresh_studio_card_preview())
		right_v.add_child(_studio_task_diff_spin)

		var die_lbl := Label.new()
		die_lbl.text = "Die Type"
		die_lbl.add_theme_color_override("font_color", GameData.SATCHEL_BTN_TEXT)
		right_v.add_child(die_lbl)

		_studio_task_die_opt = OptionButton.new()
		for die_sides in [6, 8, 10, 12, 20]:
			_studio_task_die_opt.add_item("d%d" % die_sides)
			_studio_task_die_opt.set_item_metadata(_studio_task_die_opt.item_count - 1, die_sides)
		for item_idx in range(_studio_task_die_opt.item_count):
			if int(_studio_task_die_opt.get_item_metadata(item_idx)) == int(data.get("die_sides", 6)):
				_studio_task_die_opt.select(item_idx)
				break
		_studio_task_die_opt.item_selected.connect(func(_idx: int): _refresh_studio_card_preview())
		right_v.add_child(_studio_task_die_opt)
	elif _studio_kind == "curio_canister":
		var name_lbl := Label.new()
		name_lbl.text = "Curio Canister Name"
		name_lbl.add_theme_color_override("font_color", GameData.SATCHEL_BTN_TEXT)
		right_v.add_child(name_lbl)

		_studio_task_name_edit = LineEdit.new()
		_studio_task_name_edit.text = str(data.get("title", "Untitled Curio Canister"))
		_studio_task_name_edit.text_changed.connect(_refresh_studio_card_preview)
		right_v.add_child(_studio_task_name_edit)

		var diff_lbl := Label.new()
		diff_lbl.text = "Difficulty"
		diff_lbl.add_theme_color_override("font_color", GameData.SATCHEL_BTN_TEXT)
		right_v.add_child(diff_lbl)

		_studio_task_diff_spin = SpinBox.new()
		_studio_task_diff_spin.min_value = 1
		_studio_task_diff_spin.max_value = 5
		_studio_task_diff_spin.step = 1
		# Calculate difficulty from mult (mult = difficulty * 0.25)
		var current_mult: float = float(data.get("mult", 0.25))
		var current_diff: int = clampi(int(round(current_mult / 0.25)), 1, 5)
		_studio_task_diff_spin.value = current_diff
		_studio_task_diff_spin.value_changed.connect(func(_value: float): _refresh_studio_card_preview())
		right_v.add_child(_studio_task_diff_spin)

	var color_lbl := Label.new()
	color_lbl.text = "Card Color"
	color_lbl.add_theme_color_override("font_color", GameData.SATCHEL_BTN_TEXT)
	right_v.add_child(color_lbl)

	var color_opt := OptionButton.new()
	for ckey in CARD_COLOR_ORDER:
		color_opt.add_item(str(CARD_COLOR_LABELS.get(ckey, ckey)))
		color_opt.set_item_metadata(color_opt.item_count - 1, ckey)
	for i in range(color_opt.item_count):
		if str(color_opt.get_item_metadata(i)) == _studio_card_color:
			color_opt.select(i)
			break
	color_opt.item_selected.connect(func(idx: int):
		_studio_card_color = str(color_opt.get_item_metadata(idx))
		_refresh_studio_card_preview()
	)
	right_v.add_child(color_opt)

	var tips := Label.new()
	tips.text = "Drag stickers from the book onto the card. Press Enter to save, or Escape to cancel."
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips.add_theme_color_override("font_color", Color(0.85, 0.77, 0.63, 0.8))
	tips.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	right_v.add_child(tips)

	# Save/Cancel pinned to the bottom of the right panel
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(0, 40)
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_satchel_button(save_btn)
	save_btn.pressed.connect(_save_studio_and_close)
	right_outer.add_child(save_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_satchel_button(cancel_btn)
	cancel_btn.pressed.connect(_on_studio_cancel_pressed)
	right_outer.add_child(cancel_btn)

	_refresh_studio_card_preview()

func _build_sticker_book_button(sticker_type: String, sticker_id: String, info: Dictionary) -> Control:
	var btn := Button.new()
	btn.text = str(info.get("name", sticker_id))
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.tooltip_text = str(info.get("desc", ""))
	btn.custom_minimum_size = Vector2(132, 64)
	btn.rotation = _sticker_button_rotation(sticker_id)
	btn.icon = _default_sticker_texture()
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_constant_override("icon_max_width", 64)
	_style_satchel_button(btn)
	var emoji := str(info.get("emoji", "*"))
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_begin_studio_drag(sticker_type, sticker_id, emoji, mb.global_position)
	)
	return btn

func _build_sticker_book_section(sticker_type: String, heading: String, color: Color, owned_ids: Array) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var header := Label.new()
	header.text = heading
	header.add_theme_color_override("font_color", color)
	header.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	section.add_child(header)

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

func _owned_sticker_ids_for_current_card(sticker_type: String) -> Array:
	var owned: Array = Database.get_owned_stickers(sticker_type)
	for slot in _studio_slots:
		if slot is not Dictionary:
			continue
		var slot_data := slot as Dictionary
		if slot_data.is_empty():
			continue
		if str(slot_data.get("type", "")) != sticker_type:
			continue
		var slot_id := str(slot_data.get("id", ""))
		if slot_id != "" and not owned.has(slot_id):
			owned.append(slot_id)
	return owned

func _sticker_button_rotation(sticker_id: String) -> float:
	var sum: int = 0
	for i in range(sticker_id.length()):
		sum += sticker_id.unicode_at(i)
	return float((sum % 11) - 5) * 0.012

func _assign_sticker_to_selected_slot(sticker_type: String, sticker_id: String) -> void:
	var selected := _studio_selected_sticker()
	if selected == null:
		return
	var current := selected.build_data(_studio_card_size())
	_studio_sticker_controller.delete_sticker(selected)
	_studio_sticker_controller.add_sticker(sticker_id, sticker_type, Vector2(float(current.get("x", 0.5)), float(current.get("y", 0.5))))
	_sync_studio_slots_from_controller()
	_refresh_studio_card_preview()

func _clear_selected_studio_slot() -> void:
	if _studio_sticker_controller == null:
		return
	_studio_sticker_controller.delete_selected_sticker()
	_sync_studio_slots_from_controller()
	_refresh_studio_card_preview()

func _refresh_studio_card_preview() -> void:
	_sync_studio_slots_from_controller()
	if is_instance_valid(_studio_task_preview):
		_studio_task_preview.set_task(_studio_preview_task_data())
	elif is_instance_valid(_studio_card_tex):
		_studio_card_tex.texture = _texture_for_card_color(_studio_card_color)
	if is_instance_valid(_studio_book_hint):
		var _sticker_count := _studio_slots.size()
		var selected_name := ""
		var selected := _studio_selected_sticker()
		if selected != null:
			selected_name = selected.display_name()
		if selected_name != "":
			_studio_book_hint.text = "Selected: %s. Drag to reposition, right-click or use Delete Selected Sticker to remove it." % selected_name
		else:
			_studio_book_hint.text = "Drag a sticker from the book onto the card. Drag placed stickers to reposition them, or right-click to remove them."
	if is_instance_valid(_studio_name_label):
		if _studio_kind == "task":
			_studio_name_label.text = str(_studio_preview_task_data().get("task", "Card"))
		else:
			_studio_name_label.text = str(_studio_source_data.get("title", "Card"))
	if _studio_sticker_controller != null:
		_studio_sticker_controller.on_container_resized()

func _begin_studio_drag(sticker_type: String, sticker_id: String, emoji: String, global_pos: Vector2) -> void:
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
	_studio_drag_preview = preview
	_studio_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_studio_drag_preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
	_studio_popup.add_child(_studio_drag_preview)
	_update_studio_drag_preview(global_pos)

func _update_studio_drag_preview(global_pos: Vector2) -> void:
	if not _studio_drag_active or not is_instance_valid(_studio_drag_preview):
		return
	var popup_local: Vector2 = global_pos
	if is_instance_valid(_studio_popup_root):
		popup_local = _studio_popup_root.get_global_transform().affine_inverse() * global_pos
	_studio_drag_preview.position = popup_local + Vector2(14.0, 10.0)

func _finish_studio_drag(global_pos: Vector2) -> void:
	if not _studio_drag_active:
		return
	var snapped: bool = _place_dragged_sticker_on_card(global_pos)
	_cancel_studio_drag()
	if snapped:
		_refresh_studio_card_preview()

func _cancel_studio_drag() -> void:
	_studio_drag_active = false
	_studio_drag_type = ""
	_studio_drag_id = ""
	_studio_drag_emoji = ""
	if is_instance_valid(_studio_drag_preview):
		_studio_drag_preview.queue_free()
	_studio_drag_preview = null

func _place_dragged_sticker_on_card(global_pos: Vector2) -> bool:
	if not is_instance_valid(_studio_card_root) or _studio_sticker_controller == null:
		return false
	var card_rect := _studio_card_root.get_global_rect()
	if not card_rect.has_point(global_pos):
		return false
	_studio_sticker_controller.place_sticker(_studio_drag_id, _studio_drag_type, global_pos)
	_sync_studio_slots_from_controller()
	return true

func _add_studio_dev_grid(card_root: Control) -> void:
	if not GameData.is_debug_mode() or not is_instance_valid(card_root):
		return
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(overlay)

	var border := PanelContainer.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	border_style.border_color = Color(0.80, 0.95, 1.0, 0.65)
	border_style.set_border_width_all(1)
	border_style.set_corner_radius_all(14)
	border.add_theme_stylebox_override("panel", border_style)
	overlay.add_child(border)

	for col in range(1, STUDIO_GRID_COLS):
		var x := float(col) / float(STUDIO_GRID_COLS)
		var v_line := ColorRect.new()
		v_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v_line.color = Color(0.80, 0.95, 1.0, 0.20)
		v_line.anchor_left = x
		v_line.anchor_right = x
		v_line.anchor_top = 0.0
		v_line.anchor_bottom = 1.0
		v_line.offset_left = -0.5
		v_line.offset_right = 0.5
		overlay.add_child(v_line)

	for row in range(1, STUDIO_GRID_ROWS):
		var y := float(row) / float(STUDIO_GRID_ROWS)
		var h_line := ColorRect.new()
		h_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h_line.color = Color(0.80, 0.95, 1.0, 0.20)
		h_line.anchor_left = 0.0
		h_line.anchor_right = 1.0
		h_line.anchor_top = y
		h_line.anchor_bottom = y
		h_line.offset_top = -0.5
		h_line.offset_bottom = 0.5
		overlay.add_child(h_line)

func _studio_card_size() -> Vector2:
	if is_instance_valid(_studio_card_root) and _studio_card_root.size.x > 1.0 and _studio_card_root.size.y > 1.0:
		return _studio_card_root.size
	return Vector2(520.0, 680.0)

func _legacy_slot_norm_pos(idx: int) -> Vector2:
	if idx >= 0 and idx < STUDIO_LEGACY_SLOT_POINTS.size():
		var p: Vector2 = STUDIO_LEGACY_SLOT_POINTS[idx]
		return Vector2(clampf(p.x, 0.0, 1.0), clampf(p.y, 0.0, STUDIO_TOP_AREA_RATIO))
	return Vector2(0.5, STUDIO_TOP_AREA_RATIO * 0.5)

func _slot_norm_pos(slot: Dictionary, idx: int) -> Vector2:
	if slot.is_empty():
		return _legacy_slot_norm_pos(idx)
	var fallback: Vector2 = _legacy_slot_norm_pos(idx)
	var sx: float = clampf(float(slot.get("x", fallback.x)), 0.0, 1.0)
	var sy: float = clampf(float(slot.get("y", fallback.y)), 0.0, 1.0)
	return Vector2(sx, sy)

func _slot_norm_pos_for_index(idx: int) -> Vector2:
	if idx < 0 or idx >= _studio_slots.size():
		return _legacy_slot_norm_pos(idx)
	var slot: Dictionary = _studio_slots[idx] if _studio_slots[idx] is Dictionary else {}
	return _slot_norm_pos(slot, idx)

func _snap_to_studio_grid(local_pos: Vector2, card_size: Vector2) -> Vector2:
	var clamped_x: float = clampf(local_pos.x, 0.0, card_size.x)
	var clamped_y: float = clampf(local_pos.y, 0.0, card_size.y * STUDIO_TOP_AREA_RATIO)
	var col: int = clampi(int(round((clamped_x / max(card_size.x, 1.0)) * float(STUDIO_GRID_COLS - 1))), 0, STUDIO_GRID_COLS - 1)
	var row: int = clampi(int(round((clamped_y / max(card_size.y * STUDIO_TOP_AREA_RATIO, 1.0)) * float(STUDIO_GRID_ROWS - 1))), 0, STUDIO_GRID_ROWS - 1)
	var norm_x: float = float(col) / float(max(1, STUDIO_GRID_COLS - 1))
	var norm_y: float = (float(row) / float(max(1, STUDIO_GRID_ROWS - 1))) * STUDIO_TOP_AREA_RATIO
	return Vector2(norm_x, norm_y)

func _slot_index_near_norm_pos(norm_pos: Vector2) -> int:
	for i in range(_studio_slots.size()):
		if _studio_slots[i] is not Dictionary:
			continue
		var slot: Dictionary = _studio_slots[i]
		if slot.is_empty():
			continue
		if _slot_norm_pos(slot, i).distance_to(norm_pos) <= 0.04:
			return i
	return -1

func _first_empty_studio_slot_index() -> int:
	for i in range(_studio_slots.size()):
		if _studio_slots[i] is not Dictionary:
			return i
		if (_studio_slots[i] as Dictionary).is_empty():
			return i
	return -1

func _emoji_for_studio_slot(slot: Dictionary) -> String:
	var slot_type := str(slot.get("type", ""))
	var slot_id := str(slot.get("id", ""))
	if slot_type == "ritual":
		var info: Dictionary = GameData.RITUAL_STICKERS.get(slot_id, {})
		return str(info.get("emoji", "🧵"))
	if slot_type == "consumable":
		var info: Dictionary = GameData.CONSUMABLE_STICKERS.get(slot_id, {})
		return str(info.get("emoji", "✨"))
	return "+"

func _default_sticker_texture() -> Texture2D:
	if ResourceLoader.exists(STICKER_DEFAULT_TEXTURE_PATH):
		return load(STICKER_DEFAULT_TEXTURE_PATH) as Texture2D
	return null

func _sticker_texture_for_slot(_slot: Dictionary) -> Texture2D:
	return _default_sticker_texture()

func _sticker_tooltip_for_slot(slot: Dictionary) -> String:
	var slot_type := str(slot.get("type", ""))
	var slot_id := str(slot.get("id", ""))
	var info: Dictionary = {}
	if slot_type == "ritual":
		info = GameData.RITUAL_STICKERS.get(slot_id, {})
	elif slot_type == "consumable":
		info = GameData.CONSUMABLE_STICKERS.get(slot_id, {})
	if info.is_empty():
		return slot_id
	return "%s %s" % [str(info.get("emoji", "")), str(info.get("name", slot_id))]

func _texture_for_card_color(color_key: String) -> Texture2D:
	var path: String = CARD_BASE_TEXTURES.get(color_key, CARD_BASE_TEXTURES["white"])
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _clone_studio_slots(source: Array) -> Array:
	var cloned: Array = []
	for slot in source:
		if slot is Dictionary:
			cloned.append((slot as Dictionary).duplicate(true))
		else:
			cloned.append({})
	return cloned

func _studio_slot_signature(slots: Array) -> String:
	var normalized: Array = []
	for slot in slots:
		if slot is Dictionary and not (slot as Dictionary).is_empty():
			var slot_data: Dictionary = slot
			var s_type := str(slot_data.get("type", "")).strip_edges()
			var s_id := str(slot_data.get("id", "")).strip_edges()
			if s_id != "" and (s_type == "ritual" or s_type == "consumable"):
				var sx: float = clampf(float(slot_data.get("x", 0.0)), 0.0, 1.0)
				var sy: float = clampf(float(slot_data.get("y", 0.0)), 0.0, 1.0)
				normalized.append({"type": s_type, "id": s_id, "x": sx, "y": sy})
			else:
				normalized.append({})
		else:
			normalized.append({})
	return JSON.stringify(normalized)

func _studio_has_unsaved_changes() -> bool:
	if _studio_card_color != _studio_initial_card_color:
		return true
	if _studio_kind == "task":
		if _studio_task_name_value() != _studio_initial_task_name:
			return true
		if _studio_task_difficulty_value() != _studio_initial_task_difficulty:
			return true
		if _studio_task_die_value() != _studio_initial_task_die_sides:
			return true
	if _studio_paint_dirty:
		return true
	return _studio_slot_signature(_studio_slots) != _studio_slot_signature(_studio_initial_slots)

func _on_studio_paint_mode_toggled(toggled_on: bool) -> void:
	if is_instance_valid(_studio_paint_canvas):
		_studio_paint_canvas.mouse_filter = \
				Control.MOUSE_FILTER_STOP if toggled_on else Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_studio_paint_mode_btn):
		_studio_paint_mode_btn.text = "Paint Mode: ON" if toggled_on else "Paint Mode: OFF"


func _on_studio_clear_canvas_pressed() -> void:
	if not is_instance_valid(_studio_paint_canvas):
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Clear Canvas"
	dialog.dialog_text = "Clear all paint from this card?\nThis cannot be undone."
	dialog.ok_button_text = "Clear"
	dialog.confirmed.connect(func():
		_studio_paint_canvas.clear_canvas()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	_studio_popup.add_child(dialog)
	dialog.popup_centered(Vector2i(360, 150))


func _on_studio_cancel_pressed() -> void:
	if not _studio_has_unsaved_changes():
		_studio_popup.hide()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Unsaved Changes"
	dialog.dialog_text = "Discard unsaved card edits and return to Satchel?"
	dialog.ok_button_text = "Discard Changes"
	if dialog.get_cancel_button() != null:
		dialog.get_cancel_button().text = "Keep Editing"
	dialog.confirmed.connect(func():
		_studio_popup.hide()
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	_studio_popup.add_child(dialog)
	dialog.popup_centered(Vector2i(460, 150))

func _save_studio_and_close() -> void:
	if _studio_drag_active:
		_cancel_studio_drag()
	_sync_studio_slots_from_controller()
	var saved_stickers := _clone_studio_slots(_studio_slots)
	if _studio_kind == "task":
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
		Database.update_task(_studio_entity_id, "sticker_slots", saved_stickers)
		Database.update_task(_studio_entity_id, "rituals", rituals)
		Database.update_task(_studio_entity_id, "consumables", consumables)
		Database.update_task(_studio_entity_id, "task", _studio_task_name_value())
		Database.update_task(_studio_entity_id, "difficulty", _studio_task_difficulty_value())
		Database.update_task(_studio_entity_id, "die_sides", _studio_task_die_value())
		Database.update_task(_studio_entity_id, "card_color", _studio_card_color)
	elif _studio_kind == "curio_canister":
		Database.update_curio_canister(_studio_entity_id, "sticker_slots", saved_stickers)
		Database.update_curio_canister(_studio_entity_id, "card_color", _studio_card_color)
		Database.update_curio_canister(_studio_entity_id, "title", _studio_task_name_value())
		var diff_value: int = _studio_task_difficulty_value()
		var star_power: float = diff_value * 0.25
		Database.update_curio_canister(_studio_entity_id, "mult", star_power)
	# ── Persist paint data ────────────────────────────────────────
	var _pd_room_id := int(_studio_source_data.get("studio_room", -1))
	if _pd_room_id > 0 and is_instance_valid(_studio_paint_canvas):
		var _raw_room := Database.get_studio_room_data(_pd_room_id)
		var _room_data: StudioRoomData
		if _raw_room.is_empty():
			_room_data = StudioRoomData.new(_pd_room_id, _studio_kind, _studio_entity_id)
		else:
			_room_data = StudioRoomData.from_dict(_raw_room)
		_room_data.stickers = saved_stickers
		_room_data.paint_data = _studio_paint_canvas.get_paint_data()
		_room_data.touch()
		Database.upsert_studio_room_data(_room_data)
		SignalBus.studio_room_updated.emit(_pd_room_id)
		_studio_paint_dirty = false
	_studio_popup.hide()
	_reload_gd()
	GameData.state_changed.emit()


func _sync_studio_slots_from_controller() -> void:
	if _studio_sticker_controller == null:
		return
	_studio_slots = _clone_studio_slots(_studio_sticker_controller.serialize_stickers())


func _studio_selected_sticker() -> StudioSticker:
	if _studio_sticker_controller == null:
		return null
	return _studio_sticker_controller.get_selected()


func _on_studio_sticker_selection_changed(_sticker: StudioSticker) -> void:
	_refresh_studio_card_preview()


func _on_studio_stickers_changed(_sticker: StudioSticker) -> void:
	_sync_studio_slots_from_controller()
	_refresh_studio_card_preview()


func _on_studio_stickers_reset() -> void:
	_sync_studio_slots_from_controller()
	_refresh_studio_card_preview()

func _studio_task_name_value() -> String:
	if is_instance_valid(_studio_task_name_edit):
		var task_name := _studio_task_name_edit.text.strip_edges()
		if task_name != "":
			return task_name
	return str(_studio_source_data.get("task", "Untitled Task"))

func _studio_task_difficulty_value() -> int:
	if is_instance_valid(_studio_task_diff_spin):
		return clampi(int(_studio_task_diff_spin.value), 1, 5)
	return int(_studio_source_data.get("difficulty", 1))

func _studio_task_die_value() -> int:
	if is_instance_valid(_studio_task_die_opt) and _studio_task_die_opt.selected >= 0:
		return int(_studio_task_die_opt.get_item_metadata(_studio_task_die_opt.selected))
	return int(_studio_source_data.get("die_sides", 6))

func _studio_preview_task_data() -> Dictionary:
	var preview_data: Dictionary = _studio_source_data.duplicate(true)
	if _studio_kind == "task":
		preview_data["task"] = _studio_task_name_value()
		preview_data["difficulty"] = _studio_task_difficulty_value()
		preview_data["die_sides"] = _studio_task_die_value()
	preview_data["card_color"] = _studio_card_color
	return preview_data

func _overlay_hovered(overlay: Control) -> bool:
	for child in overlay.get_children():
		if child is Control and (child as Control).get_global_rect().has_point((child as Control).get_global_mouse_position()): return true
	return false

func _archive_task(task_id: int) -> void:
	Database.update_task(task_id, "archived", true)
	_reload_gd()

func _confirm_delete_task(task_id: int) -> void:
	# Check if default task
	for t in GameData.tasks:
		if t.id == task_id and t.get("is_default", false):
			var d := AcceptDialog.new(); d.title = "Cannot Delete"
			d.dialog_text = "This is a permanent default task.\nUse the ⚙ Options in hover to configure reminders."
			add_child(d); d.popup_centered()
			d.confirmed.connect(func(): d.queue_free())
			return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Task"
	dialog.dialog_text = "Delete this task? This cannot be undone."
	dialog.confirmed.connect(func(): _delete_task(task_id); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog); dialog.popup_centered()

# ─────────────────────────────────────────────────────────────────
#  PLANTS section
# ─────────────────────────────────────────────────────────────────
func _build_plants() -> void:
	# ── Cerulean Seeds satchel ──────────────────────────────────
	var seed_count: int = Database.get_cerulean_seeds()
	_add_hdr("🌱 PLANT SEEDS", Color("#44ccff"), "Earned by completing contracts")
	var seed_card := _make_seed_card(seed_count)
	_flow.add_child(seed_card)
	# ── Discovered plants ─────────────────────────────────────────
	_add_hdr("🌿 PLANT DISCOVERIES", Color("#44cc44"), "Discover plants in the Garden tab")
	var garden: Array = Database.get_garden(GameData.current_profile)
	var grown_ids: Array = garden.map(func(g:Dictionary)->String: return g.get("plant_id",""))
	for plant in GameData.PLANT_CATALOG:
		_flow.add_child(_make_plant_card(plant, plant.id in grown_ids, garden))

func _make_seed_card(count: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(185, 140)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.03, 0.08, 0.14, 1.0)
	st.border_color = Color("#44ccff") if count > 0 else Color("#1a3344")
	st.set_border_width_all(2); st.set_corner_radius_all(8)
	st.content_margin_left = 10; st.content_margin_right = 10
	st.content_margin_top = 8;   st.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", st)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var emoji_lbl := Label.new()
	emoji_lbl.text = "🌱"
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(30))
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(emoji_lbl)

	var name_lbl := Label.new()
	name_lbl.text = "Cerulean Seed"
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	name_lbl.add_theme_color_override("font_color", Color("#44ccff"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "× %d" % count
	count_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	count_lbl.add_theme_color_override("font_color",
		Color("#88ccff") if count > 0 else Color(0.3, 0.3, 0.4))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(count_lbl)

	if count > 0:
		var open_btn := Button.new()
		open_btn.text = "✨ Open Seed"
		open_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		open_btn.add_theme_color_override("font_color", Color("#44ccff"))
		open_btn.pressed.connect(_open_seed_case)
		vbox.add_child(open_btn)
	else:
		var hint := Label.new()
		hint.text = "Complete contracts\nto earn seeds"
		hint.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		hint.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(hint)
	return panel

func _open_seed_case() -> void:
	if not Database.use_cerulean_seed():
		return
	var script_path := "res://scripts/SeedCaseScript.gd"
	if not ResourceLoader.exists(script_path):
		push_error("SeedCaseScript.gd not found at " + script_path)
		Database.add_cerulean_seed(1)  # refund
		return
	var overlay := Control.new()
	overlay.set_script(load(script_path))
	overlay.seed_result.connect(_on_seed_result)
	var scene := get_tree().current_scene
	if scene and scene.has_method("add_overlay_to_stage"):
		scene.call("add_overlay_to_stage", overlay)
	else:
		add_child(overlay)

func _on_seed_result(plant_id: String) -> void:
	# Add the plant to the garden at stage 0 if not already grown
	var garden: Array = Database.get_garden(GameData.current_profile)
	var already_grown: bool = false
	for g in garden:
		if g.get("plant_id", "") == plant_id:
			already_grown = true; break
	if not already_grown:
		Database.plant_seed(plant_id, GameData.current_profile)
		GameData.state_changed.emit()
		_switch_section("plants")
		return
	# Already have it — show a "duplicate" note and refund a seed
	var plant_info: Dictionary = {}
	for p in GameData.PLANT_CATALOG:
		if p.get("id","") == plant_id: plant_info = p; break
	var dlg := AcceptDialog.new()
	dlg.title = "Already Discovered!"
	dlg.dialog_text = "You already have %s %s!\n\nSeed refunded to your satchel." % [
		plant_info.get("emoji","🌱"), plant_info.get("name", plant_id)]
	var scene := get_tree().current_scene
	if scene and scene.has_method("add_overlay_to_stage"):
		scene.call("add_overlay_to_stage", dlg)
	else:
		add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	Database.add_cerulean_seed(1)  # refund duplicate
	_switch_section("plants")

func _make_plant_card(plant: Dictionary, discovered: bool, garden: Array) -> PanelContainer:
	var rarity: String = plant.get("rarity","common")
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(185, 120)
	var st := StyleBoxFlat.new()
	st.bg_color = GameData.RARITY_BG.get(rarity, Color(GameData.BG_COLOR,0.9)) if discovered else Color(GameData.BG_COLOR, 0.5)
	st.border_color = GameData.RARITY_COLORS.get(rarity, Color(GameData.FG_COLOR,0.2)) if discovered else Color(GameData.FG_COLOR, 0.1)
	st.set_border_width_all(2); st.set_corner_radius_all(6)
	st.content_margin_left=8; st.content_margin_right=8
	st.content_margin_top=6; st.content_margin_bottom=6
	panel.add_theme_stylebox_override("panel", st)
	var vbox := VBoxContainer.new(); vbox.add_theme_constant_override("separation",3); panel.add_child(vbox)
	var emoji_lbl := Label.new()
	emoji_lbl.text = plant.get("emoji","🌱") if discovered else "❓"
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(28))
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(emoji_lbl)
	var name_lbl := Label.new()
	name_lbl.text = plant.get("name","???") if discovered else "Undiscovered"
	name_lbl.add_theme_color_override("font_color",
		GameData.RARITY_COLORS.get(rarity, GameData.FG_COLOR) if discovered else Color(GameData.FG_COLOR, 0.2))
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(name_lbl)
	if discovered:
		var info: Dictionary = {}
		for g in garden:
			if g.get("plant_id","") == plant.id: info = g; break
		var stage_lbl := Label.new()
		stage_lbl.text = "Stage %d | %s" % [info.get("stage",0), plant.get("zone","")]
		stage_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
		stage_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(stage_lbl)
		var desc_lbl := Label.new(); desc_lbl.text = plant.get("desc","")
		desc_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
		desc_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(desc_lbl)
	return panel

# ─────────────────────────────────────────────────────────────────
#  DICE section
# ─────────────────────────────────────────────────────────────────
func _build_dice() -> void:
	# ── Dice Satchel ──────────────────────────────────────────────
	_add_hdr("🎰 DICE SATCHEL", Color("#ffaa00"), "Equip dice to tasks via Edit")
	var dice_flow := HFlowContainer.new()
	dice_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_flow.add_theme_constant_override("h_separation", 8)
	dice_flow.add_theme_constant_override("v_separation", 8)
	for sides in [6, 8, 10, 12, 20]:
		dice_flow.add_child(_make_dice_card(sides))
	_section_header.add_child(dice_flow)

	# ── Dice Table Mat sub-section ───────────────────────────────────
	var sep := HSeparator.new()
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sep.add_theme_constant_override("separation", 8)
	_section_header.add_child(sep)

	var tbl_section := VBoxContainer.new()
	tbl_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tbl_section.add_theme_constant_override("separation", 6)
	_section_header.add_child(tbl_section)

	var tbl_title := Label.new()
	tbl_title.text = "🎲 DICE TABLE MAT"
	tbl_title.add_theme_color_override("font_color", Color("#ffaa00"))
	tbl_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	tbl_section.add_child(tbl_title)
	var tbl_sub := Label.new()
	tbl_sub.text = "Choose the background mat for the dice table"
	tbl_sub.add_theme_color_override("font_color", Color("#ffaa00", 0.5))
	tbl_sub.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	tbl_section.add_child(tbl_sub)

	var current_tex_path: String = str(Database.get_setting("dice_table_bg_tex",
		"res://assets/ui/table/dice_table_01.png"))
	# Scan res://assets/ui/table/ for available PNGs
	var table_pngs: Array[String] = []
	var dir := DirAccess.open("res://assets/ui/table")
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".png"):
				table_pngs.append("res://assets/ui/table/" + fname)
			fname = dir.get_next()
		dir.list_dir_end()
		table_pngs.sort()
	if table_pngs.is_empty():
		table_pngs.append("res://assets/ui/table/dice_table_01.png")

	var table_flow := HFlowContainer.new()
	table_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_flow.add_theme_constant_override("h_separation", 8)
	table_flow.add_theme_constant_override("v_separation", 8)
	for tpath in table_pngs:
		table_flow.add_child(_make_table_bg_card(tpath, current_tex_path))
	tbl_section.add_child(table_flow)

func _make_table_bg_card(tex_path: String, current_path: String) -> Control:
	var is_active: bool = (tex_path == current_path)
	var border_col: Color = Color("#ffaa00") if is_active else Color("#4a3a20")
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(150, 120)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#1a1008")
	st.border_color = border_col
	st.set_border_width_all(2 if is_active else 1)
	st.set_corner_radius_all(6)
	st.content_margin_left = 6; st.content_margin_right = 6
	st.content_margin_top = 6; st.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", st)
	wrapper.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	# Preview
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(0, 70)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	if ResourceLoader.exists(tex_path):
		preview.texture = load(tex_path)
	else:
		var img := Image.load_from_file(tex_path)
		if img:
			preview.texture = ImageTexture.create_from_image(img)
	vbox.add_child(preview)
	# Label
	var name_lbl := Label.new()
	name_lbl.text = tex_path.get_file().get_basename().replace("_", " ")
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	name_lbl.add_theme_color_override("font_color",
		Color("#ffaa00") if is_active else Color(GameData.FG_COLOR, 0.7))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	# Use button
	var use_btn := Button.new()
	use_btn.text = "✓ Active" if is_active else "Use"
	use_btn.disabled = is_active
	use_btn.custom_minimum_size = Vector2(0, 22)
	use_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	_style_satchel_button(use_btn)
	use_btn.pressed.connect(func():
		Database.set_setting("dice_table_bg_tex", tex_path)
		SignalBus.dice_table_bg_changed.emit(tex_path)
		_refresh())
	vbox.add_child(use_btn)
	return wrapper

func _make_dice_card(sides: int) -> Control:
	var qty: int = GameData.dice_satchel.get(sides,0) if sides != 6 else -1
	var dc: Color = GameData.DIE_COLORS.get(sides, GameData.CHIP_COLOR)
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(160, 150)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(dc.r*0.1, dc.g*0.1, dc.b*0.1, 1.0)
	st.border_color = dc; st.set_border_width_all(2); st.set_corner_radius_all(8)
	st.content_margin_left=8; st.content_margin_right=8
	st.content_margin_top=8; st.content_margin_bottom=8
	panel.add_theme_stylebox_override("panel", st)
	wrapper.add_child(panel)
	var vbox := VBoxContainer.new(); vbox.add_theme_constant_override("separation",4); panel.add_child(vbox)
	var rand_face := randi() % sides
	var face_tex: Texture2D = null
	var folder_map := {6:"d6",8:"d8",10:"d10",12:"d12",20:"d20"}
	var folder := folder_map.get(sides,"d6") as String
	var user_path := "user://ante_up/dice/%s/face_%d.png" % [folder, rand_face]
	if FileAccess.file_exists(user_path):
		var img := Image.load_from_file(user_path)
		if img: face_tex = ImageTexture.create_from_image(img)
	if not face_tex:
		var p0 := "res://assets/dice/%s/spr_dice_%s_%d.png" % [folder, folder, rand_face]
		var p1 := "res://assets/dice/%s/spr_dice_%s_%d.png" % [folder, folder, rand_face + 1]
		if ResourceLoader.exists(p0): face_tex = load(p0)
		elif ResourceLoader.exists(p1): face_tex = load(p1)
	if not face_tex and GameData.die_face_sprites.has("%d_%d" % [sides, rand_face]):
		var sp := GameData.die_face_sprites["%d_%d" % [sides, rand_face]] as String
		if ResourceLoader.exists(sp): face_tex = load(sp)
	if face_tex:
		var fi := TextureRect.new(); fi.texture = face_tex
		fi.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		fi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fi.custom_minimum_size = Vector2(56, 56)
		fi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; vbox.add_child(fi)
	else:
		var face_lbl := Label.new()
		face_lbl.text = GameData.DICE_CHARS[5] if sides==6 else str(sides)
		face_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(44))
		face_lbl.add_theme_color_override("font_color", dc)
		face_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(face_lbl)
	var name_lbl := Label.new(); name_lbl.text = "d%d" % sides
	name_lbl.add_theme_color_override("font_color", dc)
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(name_lbl)
	var qty_lbl := Label.new()
	if sides == 6:
		qty_lbl.text = "∞ Unlimited"
		qty_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	elif qty > 0:
		qty_lbl.text = "Qty: %d" % qty
		qty_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	else:
		qty_lbl.text = "???"
		qty_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.2))
	qty_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(qty_lbl)
	# If unowned (not d6), overlay with "UNKNOWN"
	if sides != 6 and qty <= 0:
		var unk_overlay := PanelContainer.new()
		unk_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var ov_st := StyleBoxFlat.new()
		ov_st.bg_color = Color(0, 0, 0, 0.7); ov_st.set_corner_radius_all(8)
		unk_overlay.add_theme_stylebox_override("panel", ov_st)
		unk_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var unk_lbl := Label.new(); unk_lbl.text = "???"
		unk_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(22))
		unk_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		unk_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		unk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unk_overlay.add_child(unk_lbl)
		panel.add_child(unk_overlay)
	# Corner action buttons (only for owned non-d6 dice)
	if sides != 6 and qty > 0:
		var corner_vb := VBoxContainer.new()
		corner_vb.anchor_left = 0.0
		corner_vb.anchor_top = 0.0
		corner_vb.offset_left = 4
		corner_vb.offset_top = 4
		corner_vb.add_theme_constant_override("separation", 2)
		corner_vb.mouse_filter = Control.MOUSE_FILTER_STOP
		var studio_btn := Button.new()
		studio_btn.text = "Edit"
		studio_btn.tooltip_text = "Die Studio"
		studio_btn.custom_minimum_size = Vector2(60, 22)
		studio_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		studio_btn.pressed.connect(func(): _open_die_studio(sides))
		_style_satchel_button(studio_btn)
		corner_vb.add_child(studio_btn)
		var arch_btn := Button.new()
		arch_btn.text = "Archive"
		arch_btn.tooltip_text = "Archive die"
		arch_btn.custom_minimum_size = Vector2(60, 22)
		arch_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		arch_btn.pressed.connect(func(): _archive_die(sides))
		_style_satchel_button(arch_btn)
		corner_vb.add_child(arch_btn)
		var del_btn := Button.new()
		del_btn.text = "Delete"
		del_btn.tooltip_text = "Discard one die"
		del_btn.custom_minimum_size = Vector2(60, 22)
		del_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		del_btn.pressed.connect(func(): _confirm_discard_die(sides))
		_style_satchel_button(del_btn)
		corner_vb.add_child(del_btn)
		wrapper.add_child(corner_vb)
	return wrapper

# ─────────────────────────────────────────────────────────────────
#  Quick-add
# ─────────────────────────────────────────────────────────────────
func _add_item() -> void:
	# Satchel no longer supports creating Dice Boxes or Curios.
	return
	var task_name: String = _qa_name.text.strip_edges()
	if task_name.is_empty(): return
	var val: String = _qa_val.text.strip_edges()
	if _qa_type.selected == 0:
		var diff: int = clampi(int(val) if val.is_valid_int() else 1, 1, 5)
		Database.insert_task(task_name, diff, GameData.current_profile)
		_section = "tasks"
	else:
		var diff: int = clampi(int(val) if val.is_valid_int() else 1, 1, 5)
		var star_power: float = float(diff) * 0.25
		Database.insert_curio_canister(task_name, star_power, "common", GameData.current_profile)
		_section = "curio_canisters"
	_qa_name.clear(); _qa_val.clear()
	_reload_gd(); GameData.state_changed.emit()

func _delete_task(task_id: int) -> void:
	var room_id: int = Database.get_task_studio_room(task_id)
	if _current_room_id == room_id:
		_current_room_id = -1
	# Database.delete_task purges the room's persistent data and emits
	# studio_room_deleted, which StudioRoomManager uses to cull the view node.
	Database.delete_task(task_id); _reload_gd(); GameData.state_changed.emit()

func _open_die_studio(_sides: int) -> void:
	var d := AcceptDialog.new()
	d.title = "Die Studio"
	d.dialog_text = "Die face customization is not yet available."
	add_child(d); d.popup_centered()
	d.confirmed.connect(func(): d.queue_free())

func _archive_die(_sides: int) -> void:
	var d := AcceptDialog.new()
	d.title = "Archive Die"
	d.dialog_text = "Die archiving is not yet available."
	add_child(d); d.popup_centered()
	d.confirmed.connect(func(): d.queue_free())

func _confirm_discard_die(sides: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Discard d%d" % sides
	dialog.dialog_text = "Remove one d%d from your satchel?" % sides
	dialog.confirmed.connect(func():
		Database.use_dice(sides)
		GameData.dice_satchel[sides] = maxi(0, GameData.dice_satchel.get(sides, 0) - 1)
		_reload_gd(); GameData.state_changed.emit(); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog); dialog.popup_centered()

func _reload_gd() -> void:
	var new_tasks := []
	for t in Database.get_tasks(GameData.current_profile):
		new_tasks.append({
			id=t.id,
			task=t.task,
			difficulty=t.difficulty,
			die_sides=t.get("die_sides",6),
			rituals=t.get("rituals", []),
			consumables=t.get("consumables", []),
			sticker_slots=t.get("sticker_slots", []),
			card_color=t.get("card_color", "white"),
			# studio_room is the persistent room ID assigned at task-creation time.    
			# It is forwarded here so _open_card_studio can look it up without a
			# separate Database call, then passed into StudioRoomManager.claim_room_view.
			studio_room=t.get("studio_room", -1),
			completed=false,
		})
	GameData.tasks = new_tasks
	var new_curio_canisters := []
	for r in Database.get_curio_canisters(GameData.current_profile):
		new_curio_canisters.append({
			id=r.id,
			title=r.title,
			mult=r.get("mult",0.2),
			emoji=r.get("emoji","✦"),
			image_path=r.get("image_path", ""),
			card_color=r.get("card_color", "white"),
			sticker_slots=r.get("sticker_slots", []),
			# studio_room is the persistent room ID assigned at curio_canister-creation time.
			# Same role as the task field above.
			studio_room=r.get("studio_room", -1),
			active=false,
		})
	GameData.curio_canisters = new_curio_canisters
	_switch_section(_section)

func _add_hdr(text: String, color: Color, subtitle: String) -> void:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := Label.new(); t.text = text
	t.add_theme_color_override("font_color", color)
	t.add_theme_font_size_override("font_size", GameData.scaled_font_size(14)); vbox.add_child(t)
	var s := Label.new(); s.text = subtitle
	s.add_theme_color_override("font_color", Color(color, 0.5))
	s.add_theme_font_size_override("font_size", GameData.scaled_font_size(10)); vbox.add_child(s)
	_section_header.add_child(vbox)

# ─────────────────────────────────────────────────────────────────
#  GEAR section  –  Coin Press upgrades, tools, fertilizers
# ─────────────────────────────────────────────────────────────────
func _build_gear() -> void:
	var pearls: int = Database.get_moonpearls()
	_add_hdr("⚙ GEAR & UPGRADES", Color("#aaaaff"),
		"🌙 %d moonpearls available  •  Spend Moonpearls on tools and upgrades" % pearls)

	var gear_items := [
		{id="trowel",        name="Garden Trowel",        icon="🪚", cost=1,
		 desc="Unlock the ability to move plants in the garden.",    owned_key="trowel"},
		{id="fertilizer",    name="Fertilizer",           icon="🌱", cost=1,
		 desc="Basic fertilizer. Speeds plant growth by 1 stage.",   owned_key="fertilizer"},
		{id="fertilizer_b",  name="Blessed Fertilizer",   icon="✨", cost=1,
		 desc="Blessed earth. +1 stage and +0.1 mult bonus.",        owned_key="fertilizer_b"},
		{id="fertilizer_s",  name="Selenium Fertilizer",  icon="⚗",  cost=1,
		 desc="Rare mineral mix. Guarantees max stage growth.",       owned_key="fertilizer_s"},
		{id="fertilizer_a",  name="Angelic Fertilizer",   icon="👼", cost=2,
		 desc="Divine growth catalyst. Unlocks legendary plants.",   owned_key="fertilizer_a"},
		{id="press_upgrade", name="Bazaar Service Upgrade",   icon="⚙",  cost=5,
		 desc="Improves Bazaar services and merchant offerings.", owned_key="press_upgrade"},
	]
	for item in gear_items:
		_flow.add_child(_make_gear_card(item, pearls))

func _make_gear_card(item: Dictionary, pearls: int) -> PanelContainer:
	var owned: bool = Database.has_shop_item(item.id, GameData.current_profile)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 130)
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#1a2030") if not owned else Color("#0d2a1e")
	st.border_color = Color("#aaaaff") if not owned else Color("#44cc44")
	st.set_border_width_all(2); st.set_corner_radius_all(6)
	st.content_margin_left=8; st.content_margin_right=8
	st.content_margin_top=6; st.content_margin_bottom=6
	panel.add_theme_stylebox_override("panel", st)

	var vbox := VBoxContainer.new(); vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var top := HBoxContainer.new(); vbox.add_child(top)
	var icon_lbl := Label.new(); icon_lbl.text = item.icon as String
	icon_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(22)); top.add_child(icon_lbl)
	var name_lbl := Label.new(); name_lbl.text = item.name as String
	name_lbl.add_theme_color_override("font_color", Color("#aaaaff"))
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; top.add_child(name_lbl)

	var desc_lbl := Label.new(); desc_lbl.text = item.desc as String
	desc_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.65))
	desc_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL; vbox.add_child(desc_lbl)

	var bottom := HBoxContainer.new(); vbox.add_child(bottom)
	var cost_row: HBoxContainer = GameData.make_moondrop_row(int(item.cost), GameData.scaled_font_size(10))
	if cost_row.get_child_count() > 1:
		(cost_row.get_child(1) as Label).add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	cost_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bottom.add_child(cost_row)

	var btn := Button.new()
	if owned:
		btn.text = "✓ OWNED"; btn.disabled = true
	else:
		btn.text = "BUY"
		var can_afford: bool = pearls >= int(item.cost)
		btn.disabled = not can_afford
		if not can_afford:
			btn.tooltip_text = "Need %d Moonpearls" % item.cost
		btn.pressed.connect(func(): _buy_gear(item))
	bottom.add_child(btn)
	return panel

func _buy_gear(item: Dictionary) -> void:
	if Database.has_shop_item(item.id, GameData.current_profile): return
	if not Database.spend_moonpearls(int(item.cost), GameData.current_profile):
		_show_gear_msg("Not enough Moonpearls! Need %d 🌙" % item.cost); return
	Database.add_shop_item(item.id, GameData.current_profile)
	if item.id == "press_upgrade":
		var level: int = Database.get_bazaar_service_level()
		Database.set_bazaar_service_level(level + 1)
	GameData.state_changed.emit()
	_switch_section("tasks")

func _show_gear_msg(text: String) -> void:
	var d := AcceptDialog.new(); d.title = "Gear Shop"; d.dialog_text = text
	add_child(d); d.popup_centered()
	d.confirmed.connect(func(): d.queue_free())

# ─────────────────────────────────────────────────────────────────
#  DECOR section  –  mirrors Plants; shows owned/unowned decor
# ─────────────────────────────────────────────────────────────────
func _build_decor() -> void:
	var owned_items: Array = Database.get_shop_owned(GameData.current_profile)
	var owned_ids: Array = owned_items.map(func(i): return i.get("item_id",""))

	_add_hdr("🏺 GARDEN DECORATIONS", Color("#cc8844"),
		"Buy decorations in the Shop, then place them in the Garden")

	for dec_id in DECOR_CATALOG:
		var info: Dictionary = DECOR_CATALOG[dec_id]
		var owned: bool = dec_id in owned_ids
		_flow.add_child(_make_decor_card(dec_id, info, owned))

func _make_decor_card(dec_id: String, info: Dictionary, owned: bool) -> PanelContainer:
	var col := Color(info.color as String)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 130)
	var st := StyleBoxFlat.new()
	st.bg_color     = Color(GameData.CARD_BG, 0.95) if owned else Color(GameData.BG_COLOR, 0.6)
	st.border_color = col if owned else Color(col, 0.25)
	st.set_border_width_all(2); st.set_corner_radius_all(6)
	st.content_margin_left=8; st.content_margin_right=8
	st.content_margin_top=6;  st.content_margin_bottom=6
	panel.add_theme_stylebox_override("panel", st)
	panel.modulate = Color.WHITE if owned else Color(0.55, 0.55, 0.55, 1.0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vbox.add_child(top)

	var ch_lbl := Label.new()
	ch_lbl.text = info.char as String
	ch_lbl.add_theme_color_override("font_color", col)
	ch_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(28))
	ch_lbl.custom_minimum_size = Vector2(32, 0)
	ch_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(ch_lbl)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info_vb)

	var name_lbl := Label.new()
	name_lbl.text = info.name as String
	name_lbl.add_theme_color_override("font_color", col)
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vb.add_child(name_lbl)

	if owned:
		var owned_lbl := Label.new(); owned_lbl.text = "✓ OWNED"
		owned_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
		owned_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		info_vb.add_child(owned_lbl)
	else:
		var lock_lbl := Label.new(); lock_lbl.text = "🔒 Buy in Shop"
		lock_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.4))
		lock_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		info_vb.add_child(lock_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = info.desc as String
	desc_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.55))
	desc_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	if owned:
		var place_btn := Button.new()
		place_btn.text = "📍 Place in Garden"
		place_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		var did := dec_id
		place_btn.pressed.connect(func(): _place_decor_in_garden(did))
		vbox.add_child(place_btn)

	return panel

func _place_decor_in_garden(dec_id: String) -> void:
	var main: Node = get_tree().get_root().get_node_or_null("Main")
	if not main: return
	if main.has_method("switch_to_tab_by_key"):
		main.switch_to_tab_by_key("garden")
	await get_tree().process_frame
	if main.has_method("get_tab_node"):
		var garden: Control = main.get_tab_node("garden")
		if garden and garden.has_method("select_decor_for_placement"):
			garden.select_decor_for_placement(dec_id)

# ─────────────────────────────────────────────────────────────────
#  CONTRACTS section  –  active list + creation form
# ─────────────────────────────────────────────────────────────────
func _build_contracts_section() -> void:
	# ── Active contracts list ─────────────────────────────────────
	var active: Array = Database.get_contracts(GameData.current_profile, false)
	active.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pri := {"High Priority": 0, "Med Priority": 1, "Low Priority": 2, "No Priority": 3}
		return pri.get(a.get("difficulty","No Priority"), 3) < pri.get(b.get("difficulty","No Priority"), 3)
	)
	_add_hdr("📜 ACTIVE CONTRACTS", GameData.ACCENT_GOLD,
		"Sorted by priority · Complete them in the Contracts tab")
	if active.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No active contracts. Create one below."
		empty_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.35))
		empty_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_flow.add_child(empty_lbl)
	else:
		for contract: Dictionary in active:
			_flow.add_child(_make_gallery_contract_card(contract))

	# ── New contract form ─────────────────────────────────────────
	_add_hdr("📜 NEW CONTRACT", Color("#ffcc44"),
		"Active contracts are tracked in the Contracts tab")

	# Form card
	var form_wrap := Control.new()
	form_wrap.custom_minimum_size = Vector2(520, 0)
	form_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_child(form_wrap)

	var form_panel := PanelContainer.new()
	form_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fp_st := StyleBoxFlat.new()
	fp_st.bg_color = Color(GameData.CARD_BG, 0.95)
	fp_st.border_color = Color("#ffcc44", 0.5)
	fp_st.set_border_width_all(1); fp_st.set_corner_radius_all(6)
	fp_st.content_margin_left=14; fp_st.content_margin_right=14
	fp_st.content_margin_top=10;  fp_st.content_margin_bottom=10
	form_panel.add_theme_stylebox_override("panel", fp_st)
	form_wrap.add_child(form_panel)

	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 7)
	form_panel.add_child(form)

	# Row 1: Name + Difficulty
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	form.add_child(row1)
	_c_entry_name = LineEdit.new()
	_c_entry_name.placeholder_text = "Contract name..."
	_c_entry_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(_c_entry_name)
	_c_diff_option = OptionButton.new()
	for diff in ["No Priority", "Low Priority", "Med Priority", "High Priority"]:
		_c_diff_option.add_item(diff)
	_c_diff_option.selected = 2
	row1.add_child(_c_diff_option)

	# Row 2: Deadline + Reward
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	form.add_child(row2)
	_c_deadline_btn = Button.new()
	_c_deadline_btn.text = "📅 Pick Deadline"
	_c_deadline_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c_deadline_btn.pressed.connect(_c_open_calendar)
	var dl_st := StyleBoxFlat.new()
	dl_st.bg_color = GameData.CARD_BG; dl_st.border_color = GameData.CARD_HL
	dl_st.set_border_width_all(1); dl_st.set_corner_radius_all(4)
	_c_deadline_btn.add_theme_stylebox_override("normal", dl_st)
	_c_deadline_btn.add_theme_color_override("font_color", GameData.FG_COLOR)
	row2.add_child(_c_deadline_btn)
	_c_reward_option = OptionButton.new()
	_c_reward_option.add_item("Minor Reward")
	_c_reward_option.add_item("Major Reward")
	row2.add_child(_c_reward_option)

	# Row 3: Subtasks + Notes
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	form.add_child(row3)
	_c_entry_subtasks = LineEdit.new()
	_c_entry_subtasks.placeholder_text = "Subtasks (comma-separated)..."
	_c_entry_subtasks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(_c_entry_subtasks)
	_c_entry_notes = LineEdit.new()
	_c_entry_notes.placeholder_text = "Notes..."
	_c_entry_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(_c_entry_notes)

	var create_btn := Button.new()
	create_btn.text = "  CREATE CONTRACT  "
	_style_satchel_button(create_btn)
	create_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	create_btn.pressed.connect(_c_create_contract)
	form.add_child(create_btn)

	# Quick-link to contracts tab
	var link_lbl := Label.new()
	link_lbl.text = "Manage active contracts in the 📜 CONTRACTS tab"
	link_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	link_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
	link_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	form.add_child(link_lbl)


func _gallery_contract_subtask_cards(contract: Dictionary) -> Array:
	return Database.get_contract_subtask_cards(contract)


func _make_gallery_contract_card(contract: Dictionary) -> PanelContainer:
	var diff: String = contract.get("difficulty", "No Priority")
	var boss_info     = BOSS_LEVELS.get(diff, BOSS_LEVELS["No Priority"])
	var cid: int      = int(contract.get("id", 0))
	var subtask_cards: Array = _gallery_contract_subtask_cards(contract)
	var incomplete_subtasks: int = Database.count_incomplete_contract_subtasks(contract)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	var st := StyleBoxFlat.new()
	st.bg_color     = Color(GameData.CARD_BG, 0.92)
	st.border_color = boss_info.color
	st.set_border_width_all(2); st.set_corner_radius_all(6)
	st.content_margin_left=12; st.content_margin_right=12
	st.content_margin_top=9;   st.content_margin_bottom=9
	panel.add_theme_stylebox_override("panel", st)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	# Difficulty pill
	var pill_panel := PanelContainer.new()
	var pill_st := StyleBoxFlat.new()
	pill_st.bg_color = Color(boss_info.color, 0.18)
	pill_st.border_color = Color(boss_info.color, 0.6)
	pill_st.set_border_width_all(1); pill_st.set_corner_radius_all(10)
	pill_st.content_margin_left=6; pill_st.content_margin_right=6
	pill_st.content_margin_top=1;  pill_st.content_margin_bottom=1
	pill_panel.add_theme_stylebox_override("panel", pill_st)
	var pill_lbl := Label.new()
	pill_lbl.text = "%s %s" % [boss_info.emoji, boss_info.label]
	pill_lbl.add_theme_color_override("font_color", boss_info.color)
	pill_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(8))
	pill_panel.add_child(pill_lbl)
	vbox.add_child(pill_panel)

	var name_lbl := Label.new()
	name_lbl.text = contract.get("name", "?")
	name_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var subheading: String = str(contract.get("subheading", "")).strip_edges()
	if subheading != "":
		var subheading_lbl := Label.new()
		subheading_lbl.text = subheading
		subheading_lbl.add_theme_color_override("font_color", Color(GameData.ACCENT_BLUE, 0.78))
		subheading_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		subheading_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(subheading_lbl)

	# Deadline indicator
	var deadline: String = contract.get("deadline", "")
	if deadline != "":
		var days_left := _gc_days_between(GameData.get_date_string(), deadline)
		var urgency := "⏰" if days_left >= 3 else ("⚠️" if days_left >= 0 else "💀")
		var dl_lbl := Label.new()
		dl_lbl.text = "%s %s  (%+d d)" % [urgency, deadline, days_left]
		dl_lbl.add_theme_color_override("font_color", GameData.get_deadline_color(days_left))
		dl_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		vbox.add_child(dl_lbl)

	if not subtask_cards.is_empty():
		var subtasks_lbl := Label.new()
		var preview_lines: Array[String] = []
		for card in subtask_cards.slice(0, 3):
			preview_lines.append(("☑ " if bool(card.get("completed", false)) else "☐ ") + str(card.get("title", "")))
		subtasks_lbl.text = "\n".join(preview_lines)
		if subtask_cards.size() > 3:
			subtasks_lbl.text += "\n+%d more" % (subtask_cards.size() - 3)
		subtasks_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.72))
		subtasks_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		subtasks_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(subtasks_lbl)

	# Notes preview
	var notes: String = contract.get("notes", "")
	if notes != "":
		var notes_lbl := Label.new()
		notes_lbl.text = "📝 " + notes
		notes_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
		notes_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		notes_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(notes_lbl)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_row)
	var complete_btn := Button.new()
	complete_btn.text = "✅ Complete"
	complete_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	complete_btn.disabled = incomplete_subtasks > 0
	if incomplete_subtasks > 0:
		complete_btn.tooltip_text = "Complete all subtasks first (%d remaining)" % incomplete_subtasks
	complete_btn.pressed.connect(func(): _gc_complete_contract(cid))
	btn_row.add_child(complete_btn)
	var del_btn := Button.new()
	del_btn.text = "🗑"
	del_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	del_btn.pressed.connect(func(): _gc_delete_contract(cid))
	btn_row.add_child(del_btn)

	return panel


func _gc_complete_contract(contract_id: int) -> void:
	var reward := Database.complete_contract_with_reward(contract_id)
	if reward.is_empty():
		_show_contract_subtask_gate_notice()
		return
	GameData.contract_data_changed.emit()
	GameData.state_changed.emit()
	_switch_section("contracts")


func _gc_delete_contract(contract_id: int) -> void:
	Database.delete_contract(contract_id)
	GameData.contract_data_changed.emit()
	_switch_section("contracts")


func _gc_days_between(from_str: String, to_str: String) -> int:
	var fmt := func(s: String) -> Dictionary:
		var parts := s.split("-")
		return {year=int(parts[0]), month=int(parts[1]), day=int(parts[2]), hour=0, minute=0, second=0}
	return int((Time.get_unix_time_from_datetime_dict(fmt.call(to_str))
		- Time.get_unix_time_from_datetime_dict(fmt.call(from_str))) / 86400.0)

func _show_contract_subtask_gate_notice() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Subtasks Remaining"
	dialog.dialog_text = "Complete every subtask before finishing this contract."
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _c_create_contract() -> void:
	if not is_instance_valid(_c_entry_name): return
	var contract_name: String = _c_entry_name.text.strip_edges()
	if contract_name.is_empty(): return
	var diffs := ["No Priority", "Low Priority", "Med Priority", "High Priority"]
	var diff: String = diffs[_c_diff_option.selected]
	var reward: String = "minor" if _c_reward_option.selected == 0 else "major"
	Database.insert_contract(contract_name, diff, _c_selected_deadline,
		_c_entry_subtasks.text.strip_edges(), reward,
		_c_entry_notes.text.strip_edges(), GameData.current_profile)
	_c_entry_name.clear(); _c_entry_subtasks.clear(); _c_entry_notes.clear()
	_c_selected_deadline = ""
	_c_deadline_btn.text = "📅 Pick Deadline"
	_c_deadline_btn.add_theme_color_override("font_color", GameData.FG_COLOR)
	GameData.contract_data_changed.emit()
	# Refresh gallery contracts view and show confirmation
	_switch_section("contracts")
	var d := AcceptDialog.new(); d.title = "Contract Created"
	d.dialog_text = "📜 \"%s\" added!\n\nView it in the Contracts tab." % contract_name
	add_child(d); d.popup_centered()
	d.confirmed.connect(func(): d.queue_free())

# ─────────────────────────────────────────────────────────────────
#  Contracts calendar popup
# ─────────────────────────────────────────────────────────────────
func _c_open_calendar() -> void:
	for c in _c_cal_layer.get_children(): c.queue_free()
	var now := Time.get_date_dict_from_system()
	_c_cal_year = now.year; _c_cal_month = now.month
	if _c_selected_deadline != "":
		var parts := _c_selected_deadline.split("-")
		if parts.size() == 3:
			_c_cal_year = int(parts[0]); _c_cal_month = int(parts[1])
	_c_build_calendar()

func _c_build_calendar() -> void:
	for c in _c_cal_layer.get_children(): c.queue_free()

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _c_close_calendar())
	_c_cal_layer.add_child(dim)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(340, 380)
	card.set_anchors_preset(Control.PRESET_CENTER)
	var cst := StyleBoxFlat.new()
	cst.bg_color = GameData.CARD_BG; cst.border_color = GameData.ACCENT_BLUE
	cst.set_border_width_all(2); cst.set_corner_radius_all(10)
	cst.content_margin_left=16; cst.content_margin_right=16
	cst.content_margin_top=12;  cst.content_margin_bottom=12
	card.add_theme_stylebox_override("panel", cst)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_c_cal_layer.add_child(card)

	var vbox := VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var cal_title := Label.new(); cal_title.text = "📅  SELECT DEADLINE"
	cal_title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	cal_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	cal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cal_title)

	var nav := HBoxContainer.new(); nav.add_theme_constant_override("separation", 4)
	vbox.add_child(nav)
	var prev_btn := Button.new(); prev_btn.text = "◀"
	prev_btn.pressed.connect(func():
		_c_cal_month -= 1
		if _c_cal_month < 1: _c_cal_month = 12; _c_cal_year -= 1
		_c_build_calendar())
	nav.add_child(prev_btn)
	var month_names := ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
	var month_lbl := Label.new()
	month_lbl.text = "%s  %d" % [month_names[_c_cal_month - 1], _c_cal_year]
	month_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	month_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	month_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	month_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(month_lbl)
	var next_btn := Button.new(); next_btn.text = "▶"
	next_btn.pressed.connect(func():
		_c_cal_month += 1
		if _c_cal_month > 12: _c_cal_month = 1; _c_cal_year += 1
		_c_build_calendar())
	nav.add_child(next_btn)

	var dow_grid := GridContainer.new(); dow_grid.columns = 7
	dow_grid.add_theme_constant_override("h_separation", 4)
	vbox.add_child(dow_grid)
	for dow in ["Su","Mo","Tu","We","Th","Fr","Sa"]:
		var dl := Label.new(); dl.text = dow
		dl.add_theme_color_override("font_color", Color(GameData.ACCENT_BLUE, 0.7))
		dl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.custom_minimum_size = Vector2(40, 18)
		dow_grid.add_child(dl)

	var grid := GridContainer.new(); grid.columns = 7
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)

	var first_day_dict := {year=_c_cal_year, month=_c_cal_month, day=1, hour=0, minute=0, second=0}
	var first_unix := Time.get_unix_time_from_datetime_dict(first_day_dict)
	var first_weekday: int = Time.get_datetime_dict_from_unix_time(first_unix).get("weekday", 0)
	var days_in_month := _c_days_in_month(_c_cal_year, _c_cal_month)
	var today_str: String = GameData.get_date_string()

	for _i in range(first_weekday):
		var blank := Control.new(); blank.custom_minimum_size = Vector2(40, 36)
		grid.add_child(blank)

	for day in range(1, days_in_month + 1):
		var ds: String = "%04d-%02d-%02d" % [_c_cal_year, _c_cal_month, day]
		var is_today:    bool = ds == today_str
		var is_selected: bool = ds == _c_selected_deadline
		var is_past:     bool = ds < today_str
		var btn := Button.new(); btn.text = str(day)
		btn.custom_minimum_size = Vector2(40, 36)
		btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
		var bst := StyleBoxFlat.new()
		if is_selected:
			bst.bg_color = GameData.ACCENT_BLUE; bst.border_color = GameData.ACCENT_GOLD
			bst.set_border_width_all(2); btn.add_theme_color_override("font_color", GameData.BG_COLOR)
		elif is_today:
			bst.bg_color = Color(GameData.ACCENT_GOLD, 0.2); bst.border_color = GameData.ACCENT_GOLD
			bst.set_border_width_all(1); btn.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
		elif is_past:
			bst.bg_color = Color(GameData.BG_COLOR, 0.3)
			btn.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.3))
		else:
			bst.bg_color = Color(GameData.CARD_BG, 0.8); bst.border_color = Color(GameData.CARD_HL, 0.5)
			bst.set_border_width_all(1); btn.add_theme_color_override("font_color", GameData.FG_COLOR)
		bst.set_corner_radius_all(4); btn.add_theme_stylebox_override("normal", bst)
		var capture_ds := ds
		btn.pressed.connect(func(): _c_select_date(capture_ds))
		grid.add_child(btn)

# ── Card Base Visual Functions ───────────────────────────────────────
func _set_card_base_visual(panel: PanelContainer, color_key: String) -> void:
	if not is_instance_valid(panel):
		return
	var tex_rect: TextureRect = panel.get_node_or_null("CardBaseTexture") as TextureRect
	if tex_rect == null:
		tex_rect = TextureRect.new()
		tex_rect.name = "CardBaseTexture"
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tex_rect)
		panel.move_child(tex_rect, 0)
	tex_rect.texture = _card_base_texture(color_key)

func _c_select_date(ds: String) -> void:
	_c_selected_deadline = ds
	_c_deadline_btn.text = "📅 " + ds
	_c_deadline_btn.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	_c_build_calendar()

func _c_close_calendar() -> void:
	for c in _c_cal_layer.get_children(): c.queue_free()

func _c_days_in_month(year: int, month: int) -> int:
	var days := [0,31,28,31,30,31,30,31,31,30,31,30,31]
	if month == 2 and ((year % 4 == 0 and year % 100 != 0) or year % 400 == 0):
		return 29
	return days[month]

# ─────────────────────────────────────────────────────────────────
#  ACHIEVEMENTS section
# ─────────────────────────────────────────────────────────────────
func _build_achievements() -> void:
	_add_hdr("🏆 ACHIEVEMENTS", Color("#ffd700"), "Track your progress and unlock special rewards")
	
	# Ensure achievements are initialized
	GameData.initialize_achievements()
	
	for achievement_id in GameData.ACHIEVEMENTS:
		var achievement_data = GameData.ACHIEVEMENTS[achievement_id]
		var progress_data = GameData.achievement_progress.get(achievement_id, {})
		_flow.add_child(_make_achievement_card(achievement_id, achievement_data, progress_data))

func _make_achievement_card(_achievement_id: String, achievement_data: Dictionary, progress_data: Dictionary) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = SATCHEL_CARD_SIZE
	
	# Card background
	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Style based on completion status
	var is_completed = progress_data.get("completed", false)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.12, 0.08, 1.0) if is_completed else Color(0.08, 0.08, 0.08, 1.0)
	card_style.border_color = Color("#ffd700") if is_completed else Color("#666666")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	wrapper.add_child(card)
	
	# Card content
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_all", 12)
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Header with emoji and title
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	var emoji_label := Label.new()
	emoji_label.text = str(achievement_data.get("emoji", "🏆"))
	emoji_label.add_theme_font_size_override("font_size", 24)
	header.add_child(emoji_label)
	
	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 2)
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_vbox)
	
	var title_label := Label.new()
	title_label.text = str(achievement_data.get("name", "Unknown Achievement"))
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color("#ffd700") if is_completed else GameData.FG_COLOR)
	title_vbox.add_child(title_label)
	
	var completed_label := Label.new()
	completed_label.text = "✓ COMPLETED" if is_completed else "IN PROGRESS"
	completed_label.add_theme_font_size_override("font_size", 10)
	completed_label.add_theme_color_override("font_color", Color("#44ff88") if is_completed else Color("#888888"))
	title_vbox.add_child(completed_label)
	
	# Description
	var desc_label := Label.new()
	desc_label.text = str(achievement_data.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.8))
	vbox.add_child(desc_label)
	
	# Progress bar
	var progress_container := VBoxContainer.new()
	progress_container.add_theme_constant_override("separation", 4)
	vbox.add_child(progress_container)
	
	var _requirement_type = str(achievement_data.get("requirement_type", ""))
	var requirement_target = int(achievement_data.get("requirement_target", 1))
	var current_progress = int(progress_data.get("progress", 0))
	
	var progress_label := Label.new()
	progress_label.text = "Progress: %s / %s" % [current_progress, requirement_target]
	progress_label.add_theme_font_size_override("font_size", 10)
	progress_container.add_child(progress_label)
	
	# Progress bar background
	var progress_bg := ColorRect.new()
	progress_bg.custom_minimum_size = Vector2(0, 8)
	progress_bg.color = Color("#333333")
	progress_container.add_child(progress_bg)
	
	# Progress bar fill
	var progress_fill := ColorRect.new()
	progress_fill.custom_minimum_size = Vector2(0, 8)
	progress_fill.color = Color("#ffd700")
	var progress_ratio = clampf(float(current_progress) / float(requirement_target), 0.0, 1.0)
	progress_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_fill.custom_minimum_size = Vector2(0, 8)
	progress_container.add_child(progress_fill)
	
	# Animate progress fill
	progress_fill.size.x = progress_bg.size.x * progress_ratio
	
	return wrapper

# ── Card Base Visual Functions ───────────────────────────────────────
func _card_base_texture(color_key: String) -> Texture2D:
	var path: String = CARD_BASE_TEXTURES.get(color_key, CARD_BASE_TEXTURES["white"])
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

# ─────────────────────────────────────────────────────────────────
#  INGREDIENTS section
# ─────────────────────────────────────────────────────────────────
func _build_ingredients() -> void:
	_add_hdr("🍫 INGREDIENTS", Color("#8B4513"), "Your Moonmelt Cocoa and crafting materials")
	var inv: Dictionary = Database.get_all_ingredients()
	var has_any: bool = false
	for key in IngredientData.INGREDIENTS.keys():
		var count: int = int(inv.get(key, 0))
		if count == 0: continue
		has_any = true
		var row := _make_ingredient_row(key, count)
		_flow.add_child(row)
	if not has_any:
		var empty := Label.new()
		empty.text = "No ingredients yet\nComplete focus sessions\nto earn Moonmelt Cocoa"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		empty.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.4))
		_flow.add_child(empty)

func _make_ingredient_row(key: String, count: int) -> HBoxContainer:
	var ing: Dictionary = IngredientData.INGREDIENTS.get(key, {})
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size = Vector2(200, 0)

	var rarity_col: Color = GameData.RARITY_COLORS.get(ing.get("rarity","common"), Color.WHITE) as Color

	var emoji_lbl := Label.new()
	emoji_lbl.text = ing.get("emoji","?")
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	emoji_lbl.custom_minimum_size = Vector2(30, 0)
	row.add_child(emoji_lbl)

	var name_lbl := Label.new()
	name_lbl.text = ing.get("name","?")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	name_lbl.add_theme_color_override("font_color", rarity_col)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "×%d" % count
	count_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	count_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	count_lbl.custom_minimum_size = Vector2(40, 0)
	row.add_child(count_lbl)
	
	return row
