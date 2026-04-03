extends Control

# ContractsTab.gd – Active contracts panel (primary tab, left of Garden)
# New-contract creation lives in GalleryTab → Contracts section.

const BOSS_LEVELS := {
	"No Priority":  {color=Color(0.8, 0.8, 0.8, 1.0),  emoji="📋", label="NO PRIORITY"},
	"Low Priority": {color=Color(0.9, 0.82, 0.1, 1.0),  emoji="⚠️",  label="LOW PRIORITY"},
	"Med Priority": {color=Color(1.0, 0.55, 0.1, 1.0),  emoji="⚠️",  label="MED PRIORITY"},
	"High Priority":{color=Color(0.95, 0.12, 0.12, 1.0), emoji="💀",  label="HIGH PRIORITY"},
}
const ROLLOVER_SFX_PATH := "res://assets/audio/rollover2.wav"

var _contracts_container: VBoxContainer
var _archived_container:  VBoxContainer
var _show_archived: bool = false
var _snd_rollover: AudioStreamPlayer

func _ready() -> void:
	GameData.state_changed.connect(_refresh)
	GameData.contract_data_changed.connect(_refresh)
	if has_node("/root/SignalBus"):
		SignalBus.theme_changed.connect(_on_theme_changed)
	_setup_rollover_audio()
	_build_ui()
	_refresh()
	call_deferred("_setup_feedback")

func _on_theme_changed() -> void:
	_build_ui(); _refresh()

func _setup_feedback() -> void:
	if has_node("/root/ButtonFeedback"):
		get_node("/root/ButtonFeedback").setup_recursive(self)

func _setup_rollover_audio() -> void:
	_snd_rollover = AudioStreamPlayer.new()
	add_child(_snd_rollover)
	if ResourceLoader.exists(ROLLOVER_SFX_PATH):
		_snd_rollover.stream = load(ROLLOVER_SFX_PATH)

func _play_rollover_sfx() -> void:
	if _snd_rollover == null or _snd_rollover.stream == null:
		return
	_snd_rollover.pitch_scale = randf_range(0.96, 1.04)
	if _snd_rollover.playing:
		_snd_rollover.stop()
	_snd_rollover.play()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var hdr_panel: PanelContainer = PanelContainer.new()
	var hdr_st: StyleBoxFlat = StyleBoxFlat.new()
	hdr_st.bg_color = Color("060220"); hdr_st.border_color = Color("290E7A")
	hdr_st.border_width_bottom = 2
	hdr_panel.add_theme_stylebox_override("panel", hdr_st)
	hdr_panel.custom_minimum_size = Vector2(0, 44)
	root.add_child(hdr_panel)

	var hdr_hbox: HBoxContainer = HBoxContainer.new()
	hdr_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hdr_hbox.add_theme_constant_override("separation", 8)
	hdr_panel.add_child(hdr_hbox)

	var title: Label = Label.new()
	title.text = "📜  ACTIVE CONTRACTS"
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hbox.add_child(title)

	var add_btn: Button = Button.new()
	add_btn.text = "➕ NEW"
	add_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	add_btn.tooltip_text = "Add contracts in Gallery → Contracts"
	add_btn.pressed.connect(_go_to_gallery)
	hdr_hbox.add_child(add_btn)

	var template_btn: Button = Button.new()
	template_btn.text = "📋 Use Template"
	template_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	template_btn.tooltip_text = "Create contract from a template"
	template_btn.pressed.connect(_open_template_picker)
	hdr_hbox.add_child(template_btn)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var active_lbl: Label = Label.new()
	active_lbl.text = "── ACTIVE ──"
	active_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
	active_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	vbox.add_child(active_lbl)

	_contracts_container = VBoxContainer.new()
	_contracts_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contracts_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_contracts_container)

	var archived_btn := Button.new()
	archived_btn.text = "▼ Show Archived"
	archived_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	archived_btn.pressed.connect(_toggle_archived)
	vbox.add_child(archived_btn)

	_archived_container = VBoxContainer.new()
	_archived_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_archived_container.add_theme_constant_override("separation", 6)
	_archived_container.visible = false
	vbox.add_child(_archived_container)

func _refresh() -> void:
	if not is_instance_valid(_contracts_container): return
	_build_contracts()
	if _show_archived: _build_archived()

func _build_contracts() -> void:
	for child in _contracts_container.get_children(): child.queue_free()
	var active := Database.get_contracts(GameData.current_profile, false)
	if active.is_empty():
		var lbl := Label.new()
		lbl.text = "No active contracts.\nAdd one in Gallery → Contracts."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.35))
		lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_contracts_container.add_child(lbl); return
	active.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pri := {"High Priority": 0, "Med Priority": 1, "Low Priority": 2, "No Priority": 3}
		var pa: int = pri.get(a.get("difficulty","No Priority"), 3)
		var pb: int = pri.get(b.get("difficulty","No Priority"), 3)
		if pa != pb: return pa < pb
		var da: String = a.get("deadline",""); var db: String = b.get("deadline","")
		if da != "" and db != "": return da < db
		return da != ""
	)
	for contract in active:
		_contracts_container.add_child(_make_contract_card(contract))
	call_deferred("_setup_feedback")

func _build_archived() -> void:
	for child in _archived_container.get_children(): child.queue_free()
	for contract in Database.get_contracts(GameData.current_profile, true):
		_archived_container.add_child(_make_contract_card(contract, true))

func _contract_subtask_cards(contract: Dictionary) -> Array:
	return Database.get_contract_subtask_cards(contract)

func _make_contract_card(contract: Dictionary, is_archived: bool = false) -> PanelContainer:
	var diff: String   = contract.get("difficulty","No Priority")
	var boss_info      = BOSS_LEVELS.get(diff, BOSS_LEVELS["No Priority"])
	var cid: int       = int(contract.get("id", 0))
	var subtask_cards: Array = _contract_subtask_cards(contract)
	var incomplete_subtasks: int = Database.count_incomplete_contract_subtasks(contract)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(GameData.CARD_BG, 0.9) if not is_archived else Color(GameData.BG_COLOR, 0.7)
	style.border_color = boss_info.color if not is_archived else Color(boss_info.color, 0.3)
	style.set_border_width_all(2); style.set_corner_radius_all(6)
	style.content_margin_left=10; style.content_margin_right=10
	style.content_margin_top=8;   style.content_margin_bottom=8
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_entered.connect(_play_rollover_sfx)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)
	var badge := Label.new()
	badge.text = "%s %s" % [boss_info.emoji, boss_info.label]
	badge.add_theme_color_override("font_color", boss_info.color)
	badge.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	header.add_child(badge)
	var name_lbl := Label.new()
	name_lbl.text = contract.get("name","?")
	name_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(name_lbl)

	var subheading: String = str(contract.get("subheading", "")).strip_edges()
	if subheading != "":
		var subheading_lbl := Label.new()
		subheading_lbl.text = subheading
		subheading_lbl.add_theme_color_override("font_color", Color(GameData.ACCENT_BLUE, 0.82))
		subheading_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		subheading_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(subheading_lbl)

	var deadline: String = contract.get("deadline","")
	if deadline != "":
		var days_left := _days_between(GameData.get_date_string(), deadline)
		var urgency := "⏰" if days_left >= 3 else ("⚠️" if days_left >= 0 else "💀")
		var dl_lbl := Label.new()
		dl_lbl.text = "%s %s  (%+d days)" % [urgency, deadline, days_left]
		dl_lbl.add_theme_color_override("font_color", GameData.get_deadline_color(days_left))
		dl_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		vbox.add_child(dl_lbl)

	if not subtask_cards.is_empty():
		var st_panel := PanelContainer.new()
		var st_st := StyleBoxFlat.new()
		st_st.bg_color = Color(GameData.BG_COLOR, 0.5); st_st.set_corner_radius_all(4)
		st_panel.add_theme_stylebox_override("panel", st_st)
		vbox.add_child(st_panel)
		var st_vbox := VBoxContainer.new()
		st_vbox.add_theme_constant_override("separation", 4)
		st_panel.add_child(st_vbox)
		for card in subtask_cards:
			var card_id: int = int(card.get("id", 0))
			var st_text: String = str(card.get("title", "")).strip_edges()
			var modifiers: Array = card.get("modifiers", [])
			var checked: bool = bool(card.get("completed", false))
			var row_card := PanelContainer.new()
			row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var row_st := StyleBoxFlat.new()
			row_st.bg_color = Color(GameData.CARD_BG, 0.55)
			row_st.border_color = Color(GameData.CARD_HL, 0.35)
			row_st.set_border_width_all(1)
			row_st.set_corner_radius_all(4)
			row_st.content_margin_left = 6
			row_st.content_margin_right = 6
			row_st.content_margin_top = 4
			row_st.content_margin_bottom = 4
			row_card.add_theme_stylebox_override("panel", row_st)
			st_vbox.add_child(row_card)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row_card.add_child(row)
			var cb := CheckBox.new()
			cb.button_pressed = checked
			var st_lbl := Label.new()
			# make the whole row clickable (label included)
			row.mouse_filter = Control.MOUSE_FILTER_PASS

			# when the label is clicked, toggle the checkbox
			cb.toggled.connect(func(on: bool):
				Database.set_contract_subtask_completed(cid, card_id, on)
				st_lbl.add_theme_color_override("font_color",
					Color(GameData.ACCENT_GOLD, 0.5) if on else GameData.FG_COLOR)
				GameData.contract_data_changed.emit())
			row.add_child(cb)
			st_lbl.text = st_text
			st_lbl.add_theme_color_override("font_color",
				Color(GameData.ACCENT_GOLD, 0.5) if checked else GameData.FG_COLOR)
			st_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
			st_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			st_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			# forward clicks on the label to the checkbox
			st_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
			st_lbl.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					cb.button_pressed = not cb.button_pressed
			)
			row.add_child(st_lbl)

			var mod_lbl := Label.new()
			mod_lbl.text = "BLANK" if modifiers.is_empty() else ("+%d MOD" % modifiers.size())
			mod_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(8))
			mod_lbl.add_theme_color_override("font_color", Color(GameData.ACCENT_BLUE, 0.65))
			mod_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(mod_lbl)

	var notes: String = contract.get("notes","")
	if notes != "":
		var notes_lbl := Label.new()
		notes_lbl.text = "📝 " + notes
		notes_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.55))
		notes_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		notes_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(notes_lbl)

	if not is_archived:
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 4)
		vbox.add_child(actions)
		var complete_btn := Button.new(); complete_btn.text = "✅ Complete"
		complete_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		complete_btn.disabled = incomplete_subtasks > 0
		if incomplete_subtasks > 0:
			complete_btn.tooltip_text = "Complete all subtasks first (%d remaining)" % incomplete_subtasks
		complete_btn.pressed.connect(func(): _complete_contract(cid))
		actions.add_child(complete_btn)
		var del_btn := Button.new(); del_btn.text = "🗑 Delete"
		del_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		del_btn.pressed.connect(func(): _delete_contract(cid))
		actions.add_child(del_btn)
	else:
		var arch_lbl := Label.new()
		arch_lbl.text = "✅ Completed: %s" % contract.get("completed_date","?")
		arch_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
		arch_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		vbox.add_child(arch_lbl)

	return panel

func _complete_contract(contract_id: int) -> void:
	var reward := Database.complete_contract_with_reward(contract_id)
	if reward.is_empty():
		_show_incomplete_subtasks_notice()
		return
	GameData.contract_data_changed.emit()
	_show_contract_reward(reward)
	_refresh()


func _show_contract_reward(reward: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "🏆 Contract Complete!"
	var plant_id := str(reward.get("plant_id", "")).strip_edges()
	if plant_id != "":
		var plant_name := str(reward.get("plant", {}).get("name", "a plant"))
		dialog.dialog_text = "Contract completed!\n\nYou received: %s" % plant_name
	else:
		dialog.dialog_text = "Contract completed!\n\n🌱 You received a Cerulean Plant Seed!\nOpen it in Gallery → Plants.\n\nTake a moment to celebrate! 🎉"
	var scene := get_tree().current_scene
	if scene and scene.has_method("add_overlay_to_stage"):
		scene.call("add_overlay_to_stage", dialog)
	else:
		add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _delete_contract(contract_id: int) -> void:
	Database.delete_contract(contract_id)
	GameData.contract_data_changed.emit(); _refresh()

func _toggle_archived() -> void:
	_show_archived = not _show_archived
	_archived_container.visible = _show_archived
	if _show_archived: _build_archived()

func _go_to_gallery() -> void:
	var main: Node = get_tree().get_root().get_node_or_null("Main")
	if main and main.has_method("switch_to_tab_by_key"):
		main.switch_to_tab_by_key("gallery")
		await get_tree().process_frame
		if main.has_method("get_tab_node"):
			var gallery: Control = main.get_tab_node("gallery")
			if gallery and gallery.has_method("open_section"):
				gallery.open_section("contracts")

func _show_reward() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "🏆 Contract Complete!"
	dialog.dialog_text = "Contract completed!\n\n🌱 You received a Cerulean Plant Seed!\nOpen it in Gallery → Plants.\n\nTake a moment to celebrate! 🎉"
	var scene := get_tree().current_scene
	if scene and scene.has_method("add_overlay_to_stage"):
		scene.call("add_overlay_to_stage", dialog)
	else:
		add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	GameData.state_changed.emit()

func _show_incomplete_subtasks_notice() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Subtasks Remaining"
	dialog.dialog_text = "Complete every subtask before finishing this contract."
	var scene := get_tree().current_scene
	if scene and scene.has_method("add_overlay_to_stage"):
		scene.call("add_overlay_to_stage", dialog)
	else:
		add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _days_between(from_str: String, to_str: String) -> int:
	var fmt := func(s: String) -> Dictionary:
		var parts := s.split("-")
		return {year=int(parts[0]), month=int(parts[1]), day=int(parts[2]), hour=0, minute=0, second=0}
	return int((Time.get_unix_time_from_datetime_dict(fmt.call(to_str))
		- Time.get_unix_time_from_datetime_dict(fmt.call(from_str))) / 86400.0)

func _open_template_picker() -> void:
	var templates: Array = Database.get_contract_templates(GameData.current_profile)
	if templates.is_empty():
		var d := AcceptDialog.new()
		d.title = "No Templates"
		d.dialog_text = "No contract templates found.\nCreate templates in Gallery → Templates."
		add_child(d); d.popup_centered()
		d.confirmed.connect(func(): d.queue_free())
		return

	var dialog := AcceptDialog.new()
	dialog.title = "📋 Choose Template"
	dialog.get_ok_button().text = "Cancel"
	dialog.get_cancel_button().text = "Cancel"
	dialog.size = Vector2(480, 420)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	dialog.add_child(vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	scroll.add_child(flow)

	for template in templates:
		flow.add_child(_make_template_preview_card(template, dialog))

	var hint_lbl := Label.new()
	hint_lbl.text = "Select a template to create a new contract"
	hint_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
	hint_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint_lbl)

	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _make_template_preview_card(template: Dictionary, parent_dialog: AcceptDialog) -> PanelContainer:
	var diff: String = template.get("difficulty", "No Priority")
	var boss_info = BOSS_LEVELS.get(diff, BOSS_LEVELS["No Priority"])
	var tid: int = int(template.get("id", 0))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 120)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(GameData.CARD_BG, 0.92)
	st.border_color = boss_info.color
	st.set_border_width_all(2); st.set_corner_radius_all(6)
	st.content_margin_left=10; st.content_margin_right=10
	st.content_margin_top=8; st.content_margin_bottom=8
	panel.add_theme_stylebox_override("panel", st)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Difficulty pill
	var pill_panel := PanelContainer.new()
	var pill_st := StyleBoxFlat.new()
	pill_st.bg_color = Color(boss_info.color, 0.18)
	pill_st.border_color = Color(boss_info.color, 0.6)
	pill_st.set_border_width_all(1); pill_st.set_corner_radius_all(10)
	pill_st.content_margin_left=6; pill_st.content_margin_right=6
	pill_st.content_margin_top=1; pill_st.content_margin_bottom=1
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

	# Reward preview
	var reward: String = template.get("reward", "minor")
	var reward_lbl := Label.new()
	reward_lbl.text = "Reward: %s" % ("Major" if reward == "major" else "Minor")
	reward_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	reward_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	vbox.add_child(reward_lbl)

	# Subtasks preview
	var subtask_cards: Array = Database.get_contract_subtask_cards(template)
	if not subtask_cards.is_empty():
		var subtasks_lbl := Label.new()
		var preview_lines: Array[String] = []
		for card in subtask_cards.slice(0, 3):
			preview_lines.append(("☐ " if bool(card.get("completed", false)) else "☐ ") + str(card.get("title", "")))
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

	# Click to use
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_use_template_from_picker(tid, parent_dialog))

	return panel

func _use_template_from_picker(template_id: int, parent_dialog: AcceptDialog) -> void:
	parent_dialog.queue_free()
	var contract_id: int = Database.copy_template_to_contract(template_id, GameData.current_profile)
	if contract_id > 0:
		GameData.contract_data_changed.emit()
		GameData.state_changed.emit()
		_refresh()
		var d := AcceptDialog.new(); d.title = "Contract Created"
		d.dialog_text = "📜 Contract created from template!\n\nView it in the Contracts tab."
		add_child(d); d.popup_centered()
		d.confirmed.connect(func(): d.queue_free())
	else:
		var d := AcceptDialog.new(); d.title = "Error"
		d.dialog_text = "Failed to create contract from template."
		add_child(d); d.popup_centered()
		d.confirmed.connect(func(): d.queue_free())
