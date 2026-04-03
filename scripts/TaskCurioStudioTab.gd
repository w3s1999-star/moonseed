extends Control

const TASK_DICE_BOX_VIEW_SCRIPT := preload("res://scripts/ui/task_dice_box_view.gd")

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
const CURIO_CARD_BASE_SIZE := Vector2(230, 320)
const CURIO_CARD_SCALE := Vector2(0.75, 0.75)
const NOTE_SETTING_KEY := "studio_design_notes"
const DEFAULT_NOTES := "Moonseed Booster Direction\n\n- Moonlit Garden Pack: steady growth and bloom thresholds\n- Nocturnal Pollinators Pack: token loops into blooms\n- Confectionery Pack: prep buffs and next-roll boosts\n- Eclipse Events Pack: phase-locked power spikes\n- Moonpearls Tools Pack: rerolls, previews, and refunds\n- Quiet Rituals Pack: comfort smoothing and bad-luck control\n\nVariant Principle\n\n- Keep weathered pulls as tradeoffs, not punishment\n- Favor conditional excitement over permanent power creep\n"

var _task_name: LineEdit
var _task_diff: SpinBox
var _curio_name: LineEdit
var _curio_mult: SpinBox
var _curio_emoji: LineEdit
var _tasks_flow: HFlowContainer
var _tasks_archive_flow: HFlowContainer
var _curios_flow: HFlowContainer
var _curios_archive_flow: HFlowContainer
var _contracts_flow: HFlowContainer
var _notes_edit: TextEdit

# List of protected/default task names (from GDD)
const PROTECTED_TASKS := ["Drink Water", "Eat Food"]

# Utility to check if a task is protected (reused from Satchel)
func is_task_protected(task: Dictionary) -> bool:
	return task.task in PROTECTED_TASKS

func _ready() -> void:
	GameData.state_changed.connect(_refresh)
	if has_node("/root/SignalBus"):
		SignalBus.theme_changed.connect(_on_theme_changed)
	_build_ui()
	_refresh()

func _on_theme_changed() -> void:
	_build_ui()
	_refresh()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var root := HSplitContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.split_offset = 320
	add_child(root)

	root.add_child(_build_notepad_panel())
	root.add_child(_build_cards_panel())

func _build_notepad_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.95, 0.93, 0.86, 0.98)
	st.border_color = Color(0.48, 0.41, 0.30, 1.0)
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", st)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Design Notepad"
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	title.add_theme_color_override("font_color", Color(0.18, 0.15, 0.10, 1.0))
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Use this panel to plan pack themes, variants, and sticker ideas."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	hint.add_theme_color_override("font_color", Color(0.24, 0.20, 0.16, 1.0))
	vbox.add_child(hint)

	_notes_edit = TextEdit.new()
	_notes_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_notes_edit.text = str(Database.get_setting(NOTE_SETTING_KEY, DEFAULT_NOTES))
	_notes_edit.text_changed.connect(func(): Database.save_setting(NOTE_SETTING_KEY, _notes_edit.text))
	vbox.add_child(_notes_edit)

	return panel

func _build_cards_panel() -> Control:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)

	var top := PanelContainer.new()
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(GameData.CARD_BG, 0.86)
	top_style.border_color = GameData.CARD_HL
	top_style.set_border_width_all(1)
	top_style.set_corner_radius_all(6)
	top_style.content_margin_left = 8
	top_style.content_margin_right = 8
	top_style.content_margin_top = 8
	top_style.content_margin_bottom = 8
	top.add_theme_stylebox_override("panel", top_style)
	outer.add_child(top)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 6)
	top.add_child(top_vbox)

	var title := Label.new()
	title.text = "Task / Curio Studio"
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	top_vbox.add_child(title)

	top_vbox.add_child(_build_add_task_row())
	top_vbox.add_child(_build_add_curio_row())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	body.add_child(_section_header("Task Cards"))
	_tasks_flow = HFlowContainer.new()
	_tasks_flow.add_theme_constant_override("h_separation", 10)
	_tasks_flow.add_theme_constant_override("v_separation", 10)
	body.add_child(_tasks_flow)

	body.add_child(_section_header("Task Archive"))
	_tasks_archive_flow = HFlowContainer.new()
	_tasks_archive_flow.add_theme_constant_override("h_separation", 10)
	_tasks_archive_flow.add_theme_constant_override("v_separation", 10)
	body.add_child(_tasks_archive_flow)

	body.add_child(_section_header("Curio Cards"))
	_curios_flow = HFlowContainer.new()
	_curios_flow.add_theme_constant_override("h_separation", 10)
	_curios_flow.add_theme_constant_override("v_separation", 10)
	body.add_child(_curios_flow)

	body.add_child(_section_header("Curio Archive"))
	_curios_archive_flow = HFlowContainer.new()
	_curios_archive_flow.add_theme_constant_override("h_separation", 10)
	_curios_archive_flow.add_theme_constant_override("v_separation", 10)
	body.add_child(_curios_archive_flow)

	body.add_child(_section_header("Contract Cards"))
	_contracts_flow = HFlowContainer.new()
	_contracts_flow.add_theme_constant_override("h_separation", 10)
	_contracts_flow.add_theme_constant_override("v_separation", 10)
	body.add_child(_contracts_flow)

	return outer

func _build_add_task_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	_task_name = LineEdit.new()
	_task_name.placeholder_text = "New task name"
	_task_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_task_name)

	_task_diff = SpinBox.new()
	_task_diff.min_value = 1
	_task_diff.max_value = 5
	_task_diff.step = 1
	_task_diff.value = 2
	_task_diff.custom_minimum_size = Vector2(70, 0)
	_task_diff.prefix = "D "
	row.add_child(_task_diff)

	var add_btn := Button.new()
	add_btn.text = "Add Task"
	add_btn.pressed.connect(_add_task)
	row.add_child(add_btn)
	return row

func _build_add_curio_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	_curio_name = LineEdit.new()
	_curio_name.placeholder_text = "New curio name"
	_curio_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_curio_name)

	_curio_mult = SpinBox.new()
	_curio_mult.min_value = 1
	_curio_mult.max_value = 5
	_curio_mult.step = 1
	_curio_mult.value = 1
	_curio_mult.custom_minimum_size = Vector2(84, 0)
	_curio_mult.prefix = "D "
	row.add_child(_curio_mult)

	_curio_emoji = LineEdit.new()
	_curio_emoji.placeholder_text = "*"
	_curio_emoji.custom_minimum_size = Vector2(44, 0)
	row.add_child(_curio_emoji)

	var add_btn := Button.new()
	add_btn.text = "Add Curio"
	add_btn.pressed.connect(_add_curio)
	row.add_child(add_btn)
	return row

func _section_header(text_value: String) -> Control:
	var lbl := Label.new()
	lbl.text = text_value
	lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	return lbl

func _refresh() -> void:
	if not is_instance_valid(_tasks_flow):
		return
	for c in _tasks_flow.get_children():
		c.queue_free()
	for c in _tasks_archive_flow.get_children():
		c.queue_free()
	for c in _curios_flow.get_children():
		c.queue_free()
	for c in _curios_archive_flow.get_children():
		c.queue_free()
	for c in _contracts_flow.get_children():
		c.queue_free()

	var tasks: Array = Database.get_tasks(GameData.current_profile, false)
	tasks.sort_custom(func(a, b): return str(a.get("task", "")) < str(b.get("task", "")))
	for t in tasks:
		_tasks_flow.add_child(_make_entity_card("task", t))
	var tasks_archived: Array = Database.get_tasks(GameData.current_profile, true)
	tasks_archived.sort_custom(func(a, b): return str(a.get("task", "")) < str(b.get("task", "")))
	for t in tasks_archived:
		_tasks_archive_flow.add_child(_make_entity_card("task", t))

	var relics: Array = Database.get_curio_canisters(GameData.current_profile, false)
	relics.sort_custom(func(a, b): return str(a.get("title", "")) < str(b.get("title", "")))
	for r in relics:
		_curios_flow.add_child(_make_entity_card("curio", r))
	var relics_archived: Array = Database.get_curio_canisters(GameData.current_profile, true)
	relics_archived.sort_custom(func(a, b): return str(a.get("title", "")) < str(b.get("title", "")))
	for r in relics_archived:
		_curios_archive_flow.add_child(_make_entity_card("curio", r))

	for c in Database.get_contracts(GameData.current_profile, false):
		_contracts_flow.add_child(_make_entity_card("contract", c))

func _add_task() -> void:
	var task_name := _task_name.text.strip_edges()
	if task_name == "":
		return
	Database.insert_task(task_name, int(_task_diff.value), GameData.current_profile)
	_task_name.clear()
	_reload_runtime_data()

func _add_curio() -> void:
	var curio_name := _curio_name.text.strip_edges()
	if curio_name == "":
		return
	var emoji := _curio_emoji.text.strip_edges()
	if emoji == "":
		emoji = "*"
	var difficulty: int = int(_curio_mult.value)
	var star_power: float = difficulty * 0.25
	Database.insert_curio_canister(curio_name, star_power, "common", GameData.current_profile, emoji)
	_curio_name.clear()
	_reload_runtime_data()

func _reload_runtime_data() -> void:
	var completed_by_id: Dictionary = {}
	for t in GameData.tasks:
		completed_by_id[int(t.get("id", -1))] = bool(t.get("completed", false))
	var active_by_id: Dictionary = {}
	for r in GameData.curio_canisters:
		active_by_id[int(r.get("id", -1))] = bool(r.get("active", false))

	var new_tasks := []
	for t in Database.get_tasks(GameData.current_profile, false):
		var tid := int(t.get("id", 0))
		new_tasks.append({
			id = tid,
			task = str(t.get("task", "")),
			difficulty = int(t.get("difficulty", 1)),
			die_sides = int(t.get("die_sides", 6)),
			rituals = t.get("rituals", []),
			consumables = t.get("consumables", []),
			card_color = str(t.get("card_color", "white")),
			archived = false,
			completed = bool(completed_by_id.get(tid, false)),
		})
	GameData.tasks = new_tasks

	var new_curio_canisters := []
	for r in Database.get_curio_canisters(GameData.current_profile, false):
		var rid := int(r.get("id", 0))
		new_curio_canisters.append({
			id = rid,
			title = str(r.get("title", "?")),
			emoji = str(r.get("emoji", "*")),
			mult = float(r.get("mult", 0.2)),
			image_path = str(r.get("image_path", "")),
			card_color = str(r.get("card_color", "white")),
			archived = false,
			active = bool(active_by_id.get(rid, false)),
		})
	GameData.curio_canisters = new_curio_canisters

	GameData.state_changed.emit()

func _texture_for_color(color_key: String) -> Texture2D:
	var path: String = CARD_BASE_TEXTURES.get(color_key, CARD_BASE_TEXTURES["white"])
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _make_task_dice_box_card(data: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = CURIO_CARD_BASE_SIZE
	# ...existing code...
	var vbox := VBoxContainer.new()
	card.add_child(vbox)
	# Add details placeholder or actual details node
	var details := Label.new()
	details.text = "Task Details: " + str(data.task)
	vbox.add_child(details)

	var task_archive_button := Button.new()
	var task_archived := bool(data.get("archived", false))
	task_archive_button.text = "Restore" if task_archived else "Archive"
	task_archive_button.pressed.connect(func():
		Database.update_task(data.id, "archived", not task_archived)
		_reload_runtime_data()
	)
	vbox.add_child(task_archive_button)

	var task_delete_button := Button.new()
	task_delete_button.text = "Delete"
	task_delete_button.pressed.connect(func():
		if is_task_protected(data):
			_show_blocked_delete_dialog(data.task)
			return
			# Block deletion for protected tasks
		else:
			_show_delete_confirmation_dialog(data)
	)
	vbox.add_child(task_delete_button)

	return card

## Helper actions used by buttons (bound via Callable.bind)
func _studio_preview(data: Dictionary) -> void:
	# Ensure a studio room exists and show a quick preview
	var room_id := int(data.get("studio_room", -1))
	if room_id <= 0:
		room_id = StudioRoomManager.create_room("curio", int(data.get("id", 0)))
		Database.update_curio(int(data.get("id", 0)), "studio_room", room_id)
		_reload_runtime_data()
	var dlg := AcceptDialog.new()
	dlg.title = "Studio Preview"
	var tex := TextureRect.new()
	tex.expand = true
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture = StudioRoomManager.get_composition(room_id)
	dlg.add_child(tex)
	add_child(dlg)
	dlg.popup_centered(Vector2i(600, 420))

func _archive_curio(data: Dictionary) -> void:
	Database.update_curio_canister(int(data.get("id", 0)), "archived", not bool(data.get("archived", false)))
	_reload_runtime_data()

func _delete_curio(data: Dictionary) -> void:
	var conf := ConfirmationDialog.new()
	conf.title = "Delete Curio"
	conf.dialog_text = "Are you sure you want to delete curio: '%s'?" % str(data.get("title", "curio"))
	add_child(conf)
	conf.popup_centered(Vector2i(360, 140))
	conf.confirmed.connect(func():
		Database.delete_curio_canister(int(data.get("id", 0)))
		_reload_runtime_data()
	)

# Show blocked delete dialog for protected tasks
func _show_blocked_delete_dialog(task_name: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Delete Blocked"
	dialog.dialog_text = "Task '" + task_name + "' is protected and cannot be deleted."
	add_child(dialog)
	dialog.popup_centered(Vector2i(320, 120))

# Show delete confirmation dialog for normal tasks
func _show_delete_confirmation_dialog(task: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Task"
	dialog.dialog_text = "Are you sure you want to delete task: '" + task.task + "'?"
	add_child(dialog)
	dialog.popup_centered(Vector2i(340, 120))
	dialog.confirmed.connect(func():
		Database.delete_task(task.id)
		_reload_runtime_data())

func _make_entity_card(kind: String, data: Dictionary) -> Control:
	if kind == "task":
		return _make_task_dice_box_card(data)

	var card := PanelContainer.new()
	card.custom_minimum_size = CURIO_CARD_BASE_SIZE
	if kind == "curio":
		card.pivot_offset = card.custom_minimum_size * 0.5
		card.scale = CURIO_CARD_SCALE
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	style.border_color = Color(0.95, 0.95, 0.95, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)

	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(layer)

	var tex_rect := TextureRect.new()
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var _r_room_id := int(data.get("studio_room", -1))
	if _r_room_id > 0:
		tex_rect.texture = StudioRoomManager.get_composition(_r_room_id)
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		tex_rect.texture = _texture_for_color(str(data.get("card_color", "white")))
	layer.add_child(tex_rect)

	var top_area := MarginContainer.new()
	top_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_area.add_theme_constant_override("margin_left", 10)
	top_area.add_theme_constant_override("margin_top", 10)
	top_area.add_theme_constant_override("margin_right", 10)
	top_area.add_theme_constant_override("margin_bottom", 96)
	layer.add_child(top_area)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 8)
	top_area.add_child(top_vbox)

	var color_row := HBoxContainer.new()
	color_row.alignment = BoxContainer.ALIGNMENT_END
	top_vbox.add_child(color_row)

	if kind == "task" or kind == "curio":
		var color_opt := OptionButton.new()
		for k in CARD_COLOR_ORDER:
			color_opt.add_item(str(CARD_COLOR_LABELS.get(k, k)))
			color_opt.set_item_metadata(color_opt.item_count - 1, k)
		var current := str(data.get("card_color", "white"))
		for i in range(color_opt.item_count):
			if str(color_opt.get_item_metadata(i)) == current:
				color_opt.select(i)
				break
		var entity_id := int(data.get("id", 0))
		color_opt.item_selected.connect(func(idx: int):
			var selected_key := str(color_opt.get_item_metadata(idx))
			if kind == "task":
				Database.update_task(entity_id, "card_color", selected_key)
			else:
				Database.update_curio(entity_id, "card_color", selected_key)
			_reload_runtime_data()
		)
		color_row.add_child(color_opt)

	top_vbox.add_child(_build_sticker_wire_row(kind))

	var bottom_strip := ColorRect.new()
	bottom_strip.anchor_top = 0.68
	bottom_strip.anchor_bottom = 1.0
	bottom_strip.anchor_right = 1.0
	bottom_strip.color = Color(0.10, 0.09, 0.11, 0.84)
	bottom_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bottom_strip)

	var text_margin := MarginContainer.new()
	text_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_margin.add_theme_constant_override("margin_left", 10)
	text_margin.add_theme_constant_override("margin_right", 10)
	text_margin.add_theme_constant_override("margin_top", 8)
	text_margin.add_theme_constant_override("margin_bottom", 10)
	bottom_strip.add_child(text_margin)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 4)
	text_margin.add_child(text_box)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	title.add_theme_color_override("font_color", Color.WHITE)
	title.clip_text = true
	title.text = _card_title(kind, data)
	text_box.add_child(title)

	var details := Label.new()
	details.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	details.add_theme_color_override("font_color", Color(0.88, 0.88, 0.91, 1.0))
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.text = _card_details(kind, data)
	text_box.add_child(details)

	# Action buttons for curios
	if kind == "curio":
		var action_row := HBoxContainer.new()
		action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.alignment = BoxContainer.ALIGNMENT_END

		var studio_btn := Button.new()
		studio_btn.text = "Studio"
		studio_btn.custom_minimum_size = Vector2(80, 24)
		studio_btn.pressed.connect(Callable(self, "_studio_preview").bind(data))
		action_row.add_child(studio_btn)

		var archived_flag := bool(data.get("archived", false))
		var archive_btn := Button.new()
		archive_btn.text = "Restore" if archived_flag else "Archive"
		archive_btn.custom_minimum_size = Vector2(84, 24)
		archive_btn.pressed.connect(Callable(self, "_archive_curio").bind(data))
		action_row.add_child(archive_btn)

		var delete_btn := Button.new()
		delete_btn.text = "Delete"
		delete_btn.custom_minimum_size = Vector2(68, 24)
		delete_btn.pressed.connect(Callable(self, "_delete_curio").bind(data))
		action_row.add_child(delete_btn)

		text_box.add_child(action_row)

	return card

func _build_sticker_wire_row(kind: String) -> Control:
	var labels: Array = []
	match kind:
		"task":
			labels = ["Moon", "Bloom", "Focus"]
		"curio":
			labels = ["Aura", "Echo", "Sigil"]
		_:
			labels = ["Boss", "Time", "Reward"]

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for text_value in labels:
		var circle := PanelContainer.new()
		var _wire_sz: Vector2 = CURIO_CARD_BASE_SIZE / 16.0
		circle.custom_minimum_size = _wire_sz
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		st.border_color = Color(0.18, 0.18, 0.2, 0.9)
		st.set_border_width_all(2)
		st.set_corner_radius_all(int(_wire_sz.x * 0.5))
		circle.add_theme_stylebox_override("panel", st)

		var center := CenterContainer.new()
		circle.add_child(center)

		var lbl := Label.new()
		lbl.text = str(text_value)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		lbl.add_theme_color_override("font_color", Color(0.14, 0.14, 0.16, 1.0))
		center.add_child(lbl)

		row.add_child(circle)
	return row

func _card_title(kind: String, data: Dictionary) -> String:
	match kind:
		"task":
			return str(data.get("task", "Task"))
		"curio":
			return "%s %s" % [str(data.get("emoji", "*")), str(data.get("title", "Curio"))]
		_:
			return str(data.get("name", "Contract"))

func _card_details(kind: String, data: Dictionary) -> String:
	match kind:
		"task":
			var diff: int = int(data.get("difficulty", 1))
			var sides: int = int(data.get("die_sides", 6))
			return "d%d x %d" % [sides, diff]
		"curio":
			return "+%.1fx star power" % float(data.get("mult", 0.2))
		_:
			var diff_name := str(data.get("difficulty", "No Priority"))
			var reward := str(data.get("reward_type", "minor"))
			return "%s | %s reward" % [diff_name, reward]
