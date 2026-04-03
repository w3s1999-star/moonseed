extends Control

# SatchelTab.gd – Merged Gallery + Satchel
# Satchel-first style: flow cards, always-visible corner buttons for Studio/Archive/Delete
# Tasks: edit name, die sides, difficulty
# Relics: edit name and mult

const TASK_DICE_BOX_VIEW_SCRIPT := preload("res://scripts/ui/task_dice_box_view.gd")

var _section:     String = "tasks"
var _filter_btns: Dictionary = {}
var _flow:        HFlowContainer

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

const BOSS_LEVELS := {
	"No Priority":  {color=Color(0.8, 0.8, 0.8, 1.0),  emoji="📋", label="NO PRIORITY"},
	"Low Priority": {color=Color(0.9, 0.82, 0.1, 1.0),  emoji="⚠️",  label="LOW PRIORITY"},
	"Med Priority": {color=Color(1.0, 0.55, 0.1, 1.0),  emoji="⚠️",  label="MED PRIORITY"},
	"High Priority":{color=Color(0.95, 0.12, 0.12, 1.0), emoji="💀",  label="HIGH PRIORITY"},
}

const DECOR_CATALOG := {
	"dec_gnome":      {char="G", color="#cc8844", name="Garden Gnome",    desc="A cheerful little garden gnome watching over your plants."},
	"dec_flamingo":   {char="F", color="#ff69b4", name="Plastic Flamingo", desc="A gloriously tacky hot-pink plastic flamingo."},
	"dec_birdbath":   {char="B", color="#99bbcc", name="Bird Bath",        desc="A stone bird bath. Birds love it."},
	"dec_lantern":    {char="S", color="#ffee88", name="Stone Lantern",    desc="A softly glowing stone lantern."},
	"dec_pot":        {char="P", color="#cc6633", name="Flower Pot",       desc="A terracotta planter full of possibilities."},
	"dec_bench":      {char="N", color="#886644", name="Garden Bench",     desc="A comfortable wooden bench for contemplation."},
	"dec_fence":      {char="W", color="#ccaa88", name="Fence Section",    desc="A wooden picket fence section."},
	"dec_windchimes": {char="C", color="#aaddff", name="Wind Chimes",      desc="Delicate chimes that sing in the breeze."},
}

# SATCHEL_BUTTON_* constants removed — now uses GameData.SATCHEL_BTN_*

func _ready() -> void:
	GameData.state_changed.connect(_refresh)
	if has_node("/root/SignalBus"):
		SignalBus.theme_changed.connect(_on_theme_changed_satchel)
	_build_ui()
	_refresh()

func _on_theme_changed_satchel() -> void:
	_build_ui(); _refresh()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Title
	var title := Label.new()
	title.text = "🏛  SATCHEL"
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0, 30)
	root.add_child(title)

	# Section filter bar
	var fbar := HBoxContainer.new()
	fbar.add_theme_constant_override("separation", 4)
	fbar.custom_minimum_size = Vector2(0, 36)
	root.add_child(fbar)
	var sections := [
		["tasks",     "🎲 Dice Boxes",      GameData.CHIP_COLOR],
		["curio_canisters", "🔮 Curio Canisters", GameData.MULT_COLOR],
		["plants",    "🌿 Plants",       Color("#44cc44")],
		["decor",     "🏺 Decor",        Color("#cc8844")],
		["dice",      "🎰 Dice",         Color("#ffaa00")],
		["contracts", "📜 Contracts",    Color("#ffcc44")],
		["templates", "📋 Templates",    Color("#aaddff")],
	]
	for sd in sections:
		var btn := Button.new()
		btn.text = sd[1] as String
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
		var k: String = sd[0]
		btn.pressed.connect(func(): _switch_section(k))
		fbar.add_child(btn)
		_filter_btns[sd[0]] = btn

	# Scroll + flow
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_flow = HFlowContainer.new()
	_flow.name = "Flow"
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_theme_constant_override("h_separation", 8)
	_flow.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_flow)

	# Calendar canvas layer for contract form
	_c_cal_layer = CanvasLayer.new(); _c_cal_layer.layer = 100
	add_child(_c_cal_layer)

func _refresh() -> void: _switch_section(_section)

func open_section(key: String) -> void:
	_switch_section(key)

func _switch_section(key: String) -> void:
	_section = key
	for k in _filter_btns:
		var btn: Button = _filter_btns[k]
		btn.modulate = Color.WHITE if k == key else Color(0.55,0.55,0.55,1.0)
	if not is_instance_valid(_flow): return
	for c in _flow.get_children(): c.queue_free()
	match key:
		"tasks":     _build_tasks()
		"curio_canisters": _build_curio_canisters()
		"plants":    _build_plants()
		"decor":     _build_decor()
		"dice":      _build_dice()
		"contracts": _build_contracts_section()
		"templates": _build_templates()


# ─────────────────────────────────────────────────────────────────
#  TASKS section
# ─────────────────────────────────────────────────────────────────
func _build_tasks() -> void:
	_add_hdr("🎲 DICE BOXES", GameData.CHIP_COLOR, "Completed dice boxes roll dice and earn MOONDROPS  •  Hover for options")
	for task in GameData.tasks:
		_flow.add_child(_make_task_card(task))

func _make_task_card(task: Dictionary) -> Control:
	var sides: int = task.get("die_sides", 6)
	var is_default: bool = task.get("is_default", false)
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(230, 320)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box_view := TASK_DICE_BOX_VIEW_SCRIPT.new()
	box_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box_view.set_task(task)
	box_view.set_preview_scale(1.0)
	box_view.set_camera_size(1.82)
	box_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(box_view)

	var info_lbl := Label.new()
	info_lbl.anchor_left = 0.0
	info_lbl.anchor_top = 1.0
	info_lbl.anchor_right = 1.0
	info_lbl.anchor_bottom = 1.0
	info_lbl.offset_left = 12
	info_lbl.offset_top = -28
	info_lbl.offset_right = -12
	info_lbl.offset_bottom = -8
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.text = "%s   •   %s" % [GameData.DICE_CHARS[5] if sides == 6 else "d%d" % sides, "⭐".repeat(task.difficulty)]
	info_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	info_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(info_lbl)

	# Always-visible corner action buttons (top-left, vertical column)
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
		studio_btn.text = "Studio"
		studio_btn.tooltip_text = "Open Studio"
		studio_btn.custom_minimum_size = Vector2(72, 26)
		studio_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		studio_btn.pressed.connect(func(): _open_edit_task(task))
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

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.add_theme_constant_override("separation", 5)
	overlay.add_child(vb)

	if not is_default:
		var edit_btn := Button.new(); edit_btn.text = "✏  Edit Task"
		edit_btn.add_theme_color_override("font_color", GameData.CHIP_COLOR)
		edit_btn.pressed.connect(func(): overlay.visible = false; _open_edit_task(task))
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
#  CURIO CANISTERS section
# ─────────────────────────────────────────────────────────────────
func _build_curio_canisters() -> void:
	_add_hdr("🔮 CURIO CANISTERS", GameData.MULT_COLOR, "Toggle active in Play tab to add MULT to score  •  Hover for options")
	for curio_canister in GameData.curio_canisters:
		_flow.add_child(_make_curio_canister_card(curio_canister))

func _make_curio_canister_card(curio_canister: Dictionary) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(190, 140)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(GameData.BG_COLOR, 0.9)
	st.border_color = GameData.MULT_COLOR
	st.set_border_width_all(2); st.set_corner_radius_all(8)
	st.content_margin_left=10; st.content_margin_right=10
	st.content_margin_top=8; st.content_margin_bottom=8
	panel.add_theme_stylebox_override("panel", st)
	wrapper.add_child(panel)

	var vbox := VBoxContainer.new(); vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var emoji_lbl := Label.new(); emoji_lbl.text = curio_canister.get("emoji","✦") as String
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(24))
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(emoji_lbl)

	var name_lbl := Label.new(); name_lbl.text = curio_canister.title
	name_lbl.add_theme_color_override("font_color", GameData.MULT_COLOR)
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var mult_lbl := Label.new()
	mult_lbl.text = "+%.2fx 🔥" % curio_canister.get("mult", 0.3)
	mult_lbl.add_theme_color_override("font_color", GameData.MULT_COLOR)
	mult_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
	mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(mult_lbl)

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
	studio_btn.text = "Studio"
	studio_btn.tooltip_text = "Open Studio"
	studio_btn.custom_minimum_size = Vector2(72, 24)
	studio_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	studio_btn.pressed.connect(func(): _open_edit_relic(curio_canister))
	_style_satchel_button(studio_btn)
	corner_vb.add_child(studio_btn)

	var arch_btn := Button.new()
	arch_btn.text = "Archive"
	arch_btn.tooltip_text = "Archive"
	arch_btn.custom_minimum_size = Vector2(72, 24)
	arch_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	arch_btn.pressed.connect(func(): _archive_relic(curio_canister.id))
	_style_satchel_button(arch_btn)
	corner_vb.add_child(arch_btn)

	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.tooltip_text = "Delete"
	del_btn.custom_minimum_size = Vector2(72, 24)
	del_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	del_btn.pressed.connect(func(): _confirm_delete_relic(curio_canister.id))
	_style_satchel_button(del_btn)
	corner_vb.add_child(del_btn)

	wrapper.add_child(corner_vb)

	return wrapper

func _make_hover_overlay_relic(curio_canister: Dictionary) -> Control:
	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var ov_st := StyleBoxFlat.new()
	ov_st.bg_color = Color(GameData.CARD_BG, 0.92)
	ov_st.border_color = GameData.MULT_COLOR
	ov_st.set_border_width_all(2); ov_st.set_corner_radius_all(8)
	overlay.add_theme_stylebox_override("panel", ov_st)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.add_theme_constant_override("separation", 5)
	overlay.add_child(vb)

	var edit_btn := Button.new(); edit_btn.text = "✏  Edit Curio Canister"
	edit_btn.add_theme_color_override("font_color", GameData.MULT_COLOR)
	edit_btn.pressed.connect(func(): overlay.visible = false; _open_edit_relic(curio_canister))
	vb.add_child(edit_btn)

	var arch_btn := Button.new(); arch_btn.text = "📦  Archive"
	arch_btn.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	arch_btn.pressed.connect(func(): overlay.visible = false; _archive_relic(curio_canister.id))
	vb.add_child(arch_btn)

	var del_btn := Button.new(); del_btn.text = "🗑  Delete"
	del_btn.add_theme_color_override("font_color", GameData.ACCENT_RED)
	del_btn.pressed.connect(func(): overlay.visible = false; _confirm_delete_relic(curio_canister.id))
	vb.add_child(del_btn)

	return overlay

# ─────────────────────────────────────────────────────────────────
#  Edit modals
# ─────────────────────────────────────────────────────────────────
func _open_edit_task(task: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "✏  Edit Task"
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
	diff_info.text = "  (dice rolled per task)"
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

func _open_edit_relic(curio_canister: Dictionary) -> void:
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

	add_child(dialog)
	dialog.popup_centered(Vector2i(380, 200))
	await get_tree().process_frame; name_edit.grab_focus()

	dialog.confirmed.connect(func():
		var new_name := name_edit.text.strip_edges()
		if not new_name.is_empty() and new_name != curio_canister.title:
			Database.update_curio_canister(curio_canister.id, "title", new_name)
		var new_diff := int(diff_spin.value)
		var new_mult := float(new_diff) * 0.25
		if abs(new_mult - float(curio_canister.get("mult",0.3))) > 0.001:
			Database.update_curio_canister(curio_canister.id, "mult", new_mult)
		_reload_gd(); GameData.state_changed.emit(); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _overlay_hovered(overlay: Control) -> bool:
	for child in overlay.get_children():
		if child is Control and (child as Control).get_global_rect().has_point((child as Control).get_global_mouse_position()): return true
	return false

func _archive_task(task_id: int) -> void:
	Database.update_task(task_id, "archived", true)
	_reload_gd()

func _archive_relic(curio_canister_id: int) -> void:
	Database.update_curio_canister(curio_canister_id, "archived", true)
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

func _confirm_delete_relic(curio_canister_id: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Curio Canister"
	dialog.dialog_text = "Delete this curio canister? This cannot be undone."
	dialog.confirmed.connect(func(): _delete_curio_canister(curio_canister_id); dialog.queue_free())
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
	_add_hdr("🎰 DICE SATCHEL", Color("#ffaa00"), "Equip dice to tasks via Edit")
	for sides in [6, 8, 10, 12, 20]:
		_flow.add_child(_make_dice_card(sides))

func _make_dice_card(sides: int) -> PanelContainer:
	var qty: int = GameData.dice_satchel.get(sides,0) if sides != 6 else -1
	var dc: Color = GameData.DIE_COLORS.get(sides, GameData.CHIP_COLOR)
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(160, 150)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(dc.r*0.1, dc.g*0.1, dc.b*0.1, 1.0)
	st.border_color = dc; st.set_border_width_all(2); st.set_corner_radius_all(8)
	st.content_margin_left=8; st.content_margin_right=8
	st.content_margin_top=8; st.content_margin_bottom=8
	panel.add_theme_stylebox_override("panel", st)
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
	return panel


func _delete_task(task_id: int) -> void:
	Database.delete_task(task_id); _reload_gd(); GameData.state_changed.emit()

func _delete_curio_canister(curio_canister_id: int) -> void:
	Database.delete_curio_canister(curio_canister_id); _reload_gd(); GameData.state_changed.emit()


func _reload_gd() -> void:
	var new_tasks := []
	for t in Database.get_tasks(GameData.current_profile):
		new_tasks.append({id=t.id, task=t.task, difficulty=t.difficulty,
			die_sides=t.get("die_sides",6), completed=false})
	GameData.tasks = new_tasks
	var new_curio_canisters := []
	for r in Database.get_curio_canisters(GameData.current_profile):
		new_curio_canisters.append({id=r.id, title=r.title,
			mult=r.get("mult",0.2),
			emoji=r.get("emoji","✦"), active=false})
	GameData.curio_canisters = new_curio_canisters
	_switch_section(_section)

func _add_hdr(text: String, color: Color, subtitle: String) -> void:
	var vbox := VBoxContainer.new(); vbox.custom_minimum_size = Vector2(900, 40)
	var t := Label.new(); t.text = text
	t.add_theme_color_override("font_color", color)
	t.add_theme_font_size_override("font_size", GameData.scaled_font_size(14)); vbox.add_child(t)
	var s := Label.new(); s.text = subtitle
	s.add_theme_color_override("font_color", Color(color, 0.5))
	s.add_theme_font_size_override("font_size", GameData.scaled_font_size(10)); vbox.add_child(s)
	_flow.add_child(vbox)

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
	for diff_str in ["No Priority", "Low Priority", "Med Priority", "High Priority"]:
		_c_diff_option.add_item(diff_str)
	_c_diff_option.selected = 1
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
	create_btn.text = "  📜 CREATE CONTRACT  "
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
	var difficulty: String = contract.get("difficulty", "No Priority")
	var boss_info     = BOSS_LEVELS.get(difficulty, BOSS_LEVELS["No Priority"])
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
	_show_moonkissed_paper_reward(reward)
	_switch_section("contracts")


func _show_moonkissed_paper_reward(reward: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "📜 Moonkissed Paper Earned!"
	var tier: String = reward.get("reward_tier", "minor")
	var tier_label: String = "Minor" if tier == "minor" else "Major"
	dialog.dialog_text = "Contract completed!\n\nYou received a Moonkissed Paper Fragment (%s reward tier).\n\nVisit the Selenic Exchange to redeem your moonkissed papers for chocolate coins and cerulean seeds!" % tier_label
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())


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
	var difficulty: String = diffs[_c_diff_option.selected]
	var reward: String = "minor" if _c_reward_option.selected == 0 else "major"
	Database.insert_contract(contract_name, difficulty, _c_selected_deadline,
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

	var btn_row := HBoxContainer.new(); btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)
	var clear_btn := Button.new(); clear_btn.text = "✕ Clear"
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.pressed.connect(func():
		_c_selected_deadline = ""
		_c_deadline_btn.text = "📅 Pick Deadline"
		_c_close_calendar())
	btn_row.add_child(clear_btn)
	var done_btn := Button.new(); done_btn.text = "✓ Done"
	done_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done_btn.pressed.connect(_c_close_calendar)
	btn_row.add_child(done_btn)

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

func _style_satchel_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = GameData.SATCHEL_BTN_BG
	normal.border_color = GameData.SATCHEL_BTN_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)

	var hover := StyleBoxFlat.new()
	hover.bg_color = GameData.SATCHEL_BTN_HOVER
	hover.border_color = GameData.SATCHEL_BTN_BORDER
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = GameData.SATCHEL_BTN_PRESSED
	pressed.border_color = GameData.SATCHEL_BTN_BORDER
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(6)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", GameData.SATCHEL_BTN_TEXT)
	btn.add_theme_color_override("font_hover_color", GameData.SATCHEL_BTN_TEXT)
	btn.add_theme_color_override("font_pressed_color", GameData.SATCHEL_BTN_TEXT)

# ─────────────────────────────────────────────────────────────────
#  TEMPLATES section  –  contract templates management
# ─────────────────────────────────────────────────────────────────
func _build_templates() -> void:
	# ── Active templates list ─────────────────────────────────────
	var templates: Array = Database.get_contract_templates(GameData.current_profile)
	templates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pri := {"High Priority": 0, "Med Priority": 1, "Low Priority": 2, "No Priority": 3}
		return pri.get(a.get("difficulty","No Priority"), 3) < pri.get(b.get("difficulty","No Priority"), 3)
	)
	_add_hdr("📋 CONTRACT TEMPLATES", Color("#aaddff"),
		"Templates are reusable contract blueprints. Use them to quickly create contracts.")

	if templates.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No templates yet. Create one below."
		empty_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.35))
		empty_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_flow.add_child(empty_lbl)
	else:
		for template: Dictionary in templates:
			_flow.add_child(_make_template_card(template))

	# ── New template form ─────────────────────────────────────────
	_add_hdr("📋 NEW TEMPLATE", Color("#aaddff"),
		"Create reusable contract templates")

	# Form card
	var form_wrap := Control.new()
	form_wrap.custom_minimum_size = Vector2(520, 0)
	form_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_child(form_wrap)

	var form_panel := PanelContainer.new()
	form_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fp_st := StyleBoxFlat.new()
	fp_st.bg_color = Color(GameData.CARD_BG, 0.95)
	fp_st.border_color = Color("#aaddff", 0.5)
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
	var t_entry_name := LineEdit.new()
	t_entry_name.placeholder_text = "Template name..."
	t_entry_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(t_entry_name)
	var t_diff_option := OptionButton.new()
	for diff_str in ["No Priority", "Low Priority", "Med Priority", "High Priority"]:
		t_diff_option.add_item(diff_str)
	t_diff_option.selected = 1
	row1.add_child(t_diff_option)

	# Row 2: Reward type
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	form.add_child(row2)
	var t_reward_option := OptionButton.new()
	t_reward_option.add_item("Minor Reward")
	t_reward_option.add_item("Major Reward")
	row2.add_child(t_reward_option)

	# Row 3: Subtasks + Notes
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	form.add_child(row3)
	var t_entry_subtasks := LineEdit.new()
	t_entry_subtasks.placeholder_text = "Subtasks (comma-separated)..."
	t_entry_subtasks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(t_entry_subtasks)
	var t_entry_notes := LineEdit.new()
	t_entry_notes.placeholder_text = "Notes..."
	t_entry_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(t_entry_notes)

	var create_btn := Button.new()
	create_btn.text = "  📋 CREATE TEMPLATE  "
	create_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	create_btn.pressed.connect(func():
		var template_name := t_entry_name.text.strip_edges()
		if template_name.is_empty(): return
		var diffs := ["No Priority", "Low Priority", "Med Priority", "High Priority"]
		var difficulty: String = diffs[t_diff_option.selected]
		var reward: String = "minor" if t_reward_option.selected == 0 else "major"
		Database.insert_contract_template(template_name, difficulty,
			t_entry_subtasks.text.strip_edges(), reward,
			t_entry_notes.text.strip_edges(), GameData.current_profile)
		t_entry_name.clear(); t_entry_subtasks.clear(); t_entry_notes.clear()
		_switch_section("templates")
		var d := AcceptDialog.new(); d.title = "Template Created"
		d.dialog_text = "📋 \"%s\" template saved!\n\nUse it to quickly create contracts." % template_name
		add_child(d); d.popup_centered()
		d.confirmed.connect(func(): d.queue_free()))
	form.add_child(create_btn)

	# Quick-link to contracts tab
	var link_lbl := Label.new()
	link_lbl.text = "Create contracts from templates in the 📜 CONTRACTS tab"
	link_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	link_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
	link_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	form.add_child(link_lbl)

func _make_template_card(template: Dictionary) -> PanelContainer:
	var difficulty: String = template.get("difficulty", "No Priority")
	var boss_info: Dictionary = BOSS_LEVELS.get(difficulty, BOSS_LEVELS["No Priority"])
	var tid: int      = int(template.get("id", 0))
	var subtask_cards: Array = Database.get_contract_subtask_cards(template)

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
	name_lbl.text = template.get("name", "?")
	name_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var subheading: String = str(template.get("subheading", "")).strip_edges()
	if subheading != "":
		var subheading_lbl := Label.new()
		subheading_lbl.text = subheading
		subheading_lbl.add_theme_color_override("font_color", Color(GameData.ACCENT_BLUE, 0.78))
		subheading_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		subheading_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(subheading_lbl)

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
	var notes: String = template.get("notes", "")
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
	var use_btn := Button.new()
	use_btn.text = "➕ Use Template"
	use_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	use_btn.pressed.connect(func(): _use_template(tid))
	btn_row.add_child(use_btn)
	var del_btn := Button.new()
	del_btn.text = "🗑"
	del_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	del_btn.pressed.connect(func(): _delete_template(tid))
	btn_row.add_child(del_btn)

	return panel

func _use_template(template_id: int) -> void:
	var contract_id: int = Database.copy_template_to_contract(template_id, GameData.current_profile)
	if contract_id > 0:
		GameData.contract_data_changed.emit()
		GameData.state_changed.emit()
		_switch_section("contracts")
		var d := AcceptDialog.new(); d.title = "Contract Created"
		d.dialog_text = "📜 Contract created from template!\n\nView it in the Contracts tab."
		add_child(d); d.popup_centered()
		d.confirmed.connect(func(): d.queue_free())
	else:
		var d := AcceptDialog.new(); d.title = "Error"
		d.dialog_text = "Failed to create contract from template."
		add_child(d); d.popup_centered()
		d.confirmed.connect(func(): d.queue_free())

func _delete_template(template_id: int) -> void:
	Database.delete_contract_template(template_id)
	GameData.state_changed.emit()
	_switch_section("templates")
