extends Control

# ─────────────────────────────────────────────────────────────────
# InventoryTab.gd  –  Dev tools: Tasks, Curio Canisters, Die Faces
# ─────────────────────────────────────────────────────────────────

var _tasks_container:    VBoxContainer
var _curio_canisters_container:   VBoxContainer
var _entry_name:         LineEdit
var _entry_val:          LineEdit
var _target_option:      OptionButton
var _dice_inv_label:     Label

func _ready() -> void:
	GameData.state_changed.connect(_refresh)
	if has_node("/root/SignalBus"):
		SignalBus.theme_changed.connect(_on_theme_changed_inv)
	_build_ui()
	_refresh()
	call_deferred("_setup_feedback")

func _setup_feedback() -> void:
	if has_node("/root/ButtonFeedback"):
		get_node("/root/ButtonFeedback").setup_recursive(self)

func _build_ui() -> void:
	for _c in get_children(): _c.queue_free()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ── Title ─────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "🛠  DEV TOOLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	vbox.add_child(title)

	# ── Add item form ─────────────────────────────────────────────
	var form_panel := PanelContainer.new()
	_style_panel(form_panel, GameData.CARD_BG)
	vbox.add_child(form_panel)

	var form := VBoxContainer.new()
	form_panel.add_child(form)

	var form_lbl := Label.new()
	form_lbl.text = "➕  ADD ITEM"
	form_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	form.add_child(form_lbl)

	var form_row := HBoxContainer.new()
	form.add_child(form_row)

	_target_option = OptionButton.new()
	_target_option.add_item("Task")
	_target_option.add_item("Occasional")
	_target_option.add_separator()
	_target_option.add_item("Ritual Sticker")
	_target_option.add_item("Consumable Sticker")
	form_row.add_child(_target_option)

	_entry_name = LineEdit.new()
	_entry_name.placeholder_text = "Name..."
	_entry_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_row.add_child(_entry_name)

	_entry_val = LineEdit.new()
	_entry_val.placeholder_text = "Diff / Mult"
	_entry_val.custom_minimum_size = Vector2(80, 0)
	form_row.add_child(_entry_val)

	var add_btn := Button.new()
	add_btn.text = "ADD"
	add_btn.pressed.connect(_add_item)
	form_row.add_child(add_btn)

	# Bulk populate buttons
	var bulk_row := HBoxContainer.new()
	form.add_child(bulk_row)

	var dev_btn := Button.new()
	dev_btn.text = "🧪 Sample Tasks+Occasionals"
	dev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dev_btn.pressed.connect(_populate_dev_data)
	bulk_row.add_child(dev_btn)

	var contracts_btn := Button.new()
	contracts_btn.text = "📜 +5 Sample Contracts"
	contracts_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contracts_btn.pressed.connect(_populate_sample_contracts)
	bulk_row.add_child(contracts_btn)

	# ── Dice Satchel ────────────────────────────────────────────
	_dice_inv_label = Label.new()
	_dice_inv_label.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
	vbox.add_child(_dice_inv_label)

	# ── Tasks ─────────────────────────────────────────────────────
	vbox.add_child(HSeparator.new())

	var lbl_tasks := Label.new()
	lbl_tasks.text = "── TASKS ──"
	lbl_tasks.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
	lbl_tasks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_tasks)

	_tasks_container = VBoxContainer.new()
	vbox.add_child(_tasks_container)

	# ── Occasional Tasks (curio canisters) ─────────────────────────────────
	vbox.add_child(HSeparator.new())

	var lbl_curio_canisters := Label.new()
	lbl_curio_canisters.text = "── OCCASIONAL TASKS ──"
	lbl_curio_canisters.add_theme_color_override("font_color", GameData.ACCENT_CURIO_CANISTER)
	lbl_curio_canisters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_curio_canisters)

	var occ_note := Label.new()
	occ_note.text = "Laundry, cooking, etc. — activate in Play tab for mult bonus."
	occ_note.add_theme_color_override("font_color", Color(0.27, 0.55, 0.42, 1.0))
	occ_note.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	vbox.add_child(occ_note)

	_curio_canisters_container = VBoxContainer.new()
	vbox.add_child(_curio_canisters_container)

func _refresh() -> void:
	var satchel: Dictionary = GameData.dice_satchel
	_dice_inv_label.text = "🎲 Dice: d8×%d  d10×%d  d12×%d  d20×%d" % [
		satchel.get(8,0), satchel.get(10,0), satchel.get(12,0), satchel.get(20,0)]
	_build_tasks()
	_build_curio_canisters()

# ── Tasks ─────────────────────────────────────────────────────────
func _task_sticker_text(task: Dictionary) -> String:
	var ordered_text := ""
	var raw_slots: Variant = task.get("sticker_slots", [])
	if raw_slots is Array and not (raw_slots as Array).is_empty():
		for slot_value in raw_slots:
			if slot_value is not Dictionary:
				continue
			var slot: Dictionary = slot_value
			var slot_type := str(slot.get("type", ""))
			var slot_id := str(slot.get("id", ""))
			if slot_type == "ritual":
				var ritual_info = GameData.RITUAL_STICKERS.get(slot_id, null)
				if ritual_info:
					ordered_text += ritual_info.emoji
			elif slot_type == "consumable":
				var consumable_info = GameData.CONSUMABLE_STICKERS.get(slot_id, null)
				if consumable_info:
					ordered_text += consumable_info.emoji
		if ordered_text != "":
			return ordered_text
	for rid in task.get("rituals", []):
		var rinfo = GameData.RITUAL_STICKERS.get(rid, null)
		if rinfo:
			ordered_text += rinfo.emoji
	for cid in task.get("consumables", []):
		var cinfo = GameData.CONSUMABLE_STICKERS.get(cid, null)
		if cinfo:
			ordered_text += cinfo.emoji
	return ordered_text

func _build_tasks() -> void:
	for child in _tasks_container.get_children():
		child.queue_free()

	for task in GameData.tasks:
		var row := HBoxContainer.new()
		_tasks_container.add_child(row)

		var sides: int = task.get("die_sides", 6)
		var die_col: Color = GameData.DIE_COLORS.get(sides, GameData.FG_COLOR) as Color

		# Difficulty stars
		var stars := "★".repeat(task.difficulty) + "☆".repeat(max(0, 5 - task.difficulty))
		var lbl := Label.new()
		var sticker_text := _task_sticker_text(task)
		lbl.text = "[%s d%d] %s %s" % [stars, sides, sticker_text, task.task]
		lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
		lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		row.add_child(lbl)

		var btn_diff_m := Button.new()
		btn_diff_m.text = "−"
		btn_diff_m.custom_minimum_size = Vector2(28, 0)
		btn_diff_m.pressed.connect(func(): _adjust_diff(task.id, -1))
		row.add_child(btn_diff_m)

		var diff_lbl := Label.new()
		diff_lbl.text = str(task.difficulty)
		diff_lbl.custom_minimum_size = Vector2(18, 0)
		diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		diff_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
		row.add_child(diff_lbl)

		var btn_diff_p := Button.new()
		btn_diff_p.text = "+"
		btn_diff_p.custom_minimum_size = Vector2(28, 0)
		btn_diff_p.pressed.connect(func(): _adjust_diff(task.id, 1))
		row.add_child(btn_diff_p)

		var die_btn := Button.new()
		die_btn.text = "d%d" % sides
		die_btn.add_theme_color_override("font_color", die_col)
		die_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		die_btn.custom_minimum_size = Vector2(32, 0)
		die_btn.pressed.connect(func(): _cycle_task_die(task.id))
		row.add_child(die_btn)

		var edit_btn := Button.new()
		edit_btn.text = "✏"
		edit_btn.custom_minimum_size = Vector2(28, 0)
		edit_btn.pressed.connect(func(): _rename_task(task.id, task.task))
		row.add_child(edit_btn)

		var del_btn := Button.new()
		del_btn.text = "🗑"
		del_btn.pressed.connect(func(): _delete_task(task.id))
		row.add_child(del_btn)

# ── Occasional Tasks ──────────────────────────────────────────────
func _build_curio_canisters() -> void:
	for child in _curio_canisters_container.get_children():
		child.queue_free()

	for curio_canister in GameData.curio_canisters:
		var row := HBoxContainer.new()
		_curio_canisters_container.add_child(row)

		var lbl := Label.new()
		lbl.text = "%s  +%.2fx mult" % [curio_canister.title, curio_canister.get("mult",0.2)]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", GameData.MULT_COLOR)
		row.add_child(lbl)

		var edit_btn := Button.new()
		edit_btn.text = "✏"
		edit_btn.custom_minimum_size = Vector2(28, 0)
		edit_btn.pressed.connect(func(): _rename_curio_canister(curio_canister.id, curio_canister.title))
		row.add_child(edit_btn)

		var del_btn := Button.new()
		del_btn.text = "🗑"
		del_btn.pressed.connect(func(): _delete_curio_canister(curio_canister.id))
		row.add_child(del_btn)

# ── Actions ───────────────────────────────────────────────────────
func _rename_task(task_id: int, current_name: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Rename Task"
	var vb := VBoxContainer.new()
	var lbl := Label.new(); lbl.text = "New name:"; vb.add_child(lbl)
	var le := LineEdit.new(); le.text = current_name; le.select_all()
	vb.add_child(le)
	dialog.add_child(vb)
	dialog.get_ok_button().text = "Rename"
	add_child(dialog)
	dialog.popup_centered(Vector2i(300, 100))
	await get_tree().process_frame
	le.grab_focus()
	dialog.confirmed.connect(func():
		var new_name := le.text.strip_edges()
		if new_name.is_empty(): return
		Database.update_task(task_id, "task", new_name)
		for t in GameData.tasks:
			if t.id == task_id: t.task = new_name; break
		_refresh()
		dialog.queue_free())

func _rename_curio_canister(curio_canister_id: int, current_name: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Rename Curio Canister"
	var vb := VBoxContainer.new()
	var lbl := Label.new(); lbl.text = "New name:"; vb.add_child(lbl)
	var le := LineEdit.new(); le.text = current_name; le.select_all()
	vb.add_child(le)
	dialog.add_child(vb)
	dialog.get_ok_button().text = "Rename"
	add_child(dialog)
	dialog.popup_centered(Vector2i(300, 100))
	await get_tree().process_frame
	le.grab_focus()
	dialog.confirmed.connect(func():
		var new_name := le.text.strip_edges()
		if new_name.is_empty(): return
		Database.update_curio_canister(curio_canister_id, "title", new_name)
		for r in GameData.curio_canisters:
			if r.id == curio_canister_id: r.title = new_name; break
		_refresh()
		dialog.queue_free())

func _add_item() -> void:
	var task_name: String = _entry_name.text.strip_edges()
	var val: String       = _entry_val.text.strip_edges()
	if task_name.is_empty():
		return

	if _target_option.selected == 0:
		var diff: int = int(val) if val.is_valid_int() else 1
		diff = clampi(diff, 1, 5)
		Database.insert_task(task_name, diff, GameData.current_profile)
	elif _target_option.selected == 1:
		var diff: int = clampi(int(val) if val.is_valid_int() else 1, 1, 5)
		var star_power: float = float(diff) * 0.25
		Database.insert_curio_canister(task_name, star_power, "common", GameData.current_profile)
	elif _target_option.selected == 2:
		print("[SatchelTab] Ritual stickers must be attached to a task via scripting or future UI.")
	elif _target_option.selected == 3:
		print("[SatchelTab] Consumable stickers must be attached to a task via scripting or future UI.")

	_entry_name.clear()
	_entry_val.clear()
	_reload_tasks_and_curio_canisters()
	GameData.state_changed.emit()

func _delete_task(task_id: int) -> void:
	Database.delete_task(task_id)
	_reload_tasks_and_curio_canisters()
	GameData.state_changed.emit()

func _delete_curio_canister(curio_canister_id: int) -> void:
	Database.delete_curio_canister(curio_canister_id)
	_reload_tasks_and_curio_canisters()
	GameData.state_changed.emit()

func _adjust_diff(task_id: int, delta: int) -> void:
	for t in GameData.tasks:
		if t.id == task_id:
			t.difficulty = clampi(t.difficulty + delta, 1, 5)
			Database.update_task(task_id, "difficulty", t.difficulty)
			break
	_refresh()

func _cycle_task_die(task_id: int) -> void:
	var available: Array = [6]
	for s in [8, 10, 12, 20]:
		if GameData.dice_satchel.get(s, 0) > 0:
			available.append(s)
	for t in GameData.tasks:
		if t.id == task_id:
			var cur: int = t.get("die_sides", 6)
			var idx: int = available.find(cur)
			t.die_sides  = available[(idx + 1) % available.size()]
			Database.update_task(task_id, "die_sides", t.die_sides)
			break
	_refresh()

func _populate_dev_data() -> void:
	for sample in GameData.DEV_SAMPLE_TASKS:
		Database.insert_task(sample[0], sample[1], GameData.current_profile)
	for sample in GameData.DEV_SAMPLE_CURIO_CANISTERS:
		Database.insert_curio_canister(sample[0], sample[1], sample[2], GameData.current_profile)
	_reload_tasks_and_curio_canisters()
	GameData.state_changed.emit()

func _populate_sample_contracts() -> void:
	for sample in GameData.DEV_SAMPLE_CONTRACTS:
		Database.insert_dev_sample_contract(sample, GameData.current_profile)
	GameData.contract_data_changed.emit()
	GameData.state_changed.emit()
	# Show confirmation
	var label := Label.new()
	label.text = "✅ 5 contracts added!"
	label.add_theme_color_override("font_color", Color("#099EA9"))
	get_parent().add_child(label)
	await get_tree().create_timer(2.0).timeout
	label.queue_free()


func _reload_tasks_and_curio_canisters() -> void:
	var new_tasks := []
	for t in Database.get_tasks(GameData.current_profile):
		new_tasks.append({
			id=t.id, task=t.task, difficulty=t.difficulty,
			die_sides=t.get("die_sides",6), completed=false
		})
	GameData.tasks = new_tasks
	var new_curio_canisters := []
	for r in Database.get_curio_canisters(GameData.current_profile):
		new_curio_canisters.append({
			id=r.id, title=r.title, mult=r.get("mult",0.2),
			image_path=r.get("image_path",""),
			active=false
		})
	GameData.curio_canisters = new_curio_canisters

func _style_panel(panel: PanelContainer, bg_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color("#290E7A")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

func _on_theme_changed_inv() -> void:
	_build_ui()
	_refresh()
