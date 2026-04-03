extends Control

# ─────────────────────────────────────────────────────────────────
# BtnPhase2Validator.gd  —  Moonseed Button Art Phase 2 Validator
#
# Validates all 10 state PNGs for btn_primary_md + btn_secondary.
#
# WHAT IT CHECKS:
#   1.  All 10 state PNGs exist on disk
#   2.  All 10 are readable as Image data
#   3.  btn_primary_md: all 5 canvas sizes = 360 × 104 px
#   4.  btn_secondary:  all 5 canvas sizes = 320 × 96 px
#   5.  btn_primary_md normal center pixel is painted (alpha > 0)
#   6.  btn_secondary  normal center pixel is painted (alpha > 0)
#   7.  btn_primary_md 4 state variants each differ from normal
#   8.  btn_secondary  4 state variants each differ from normal
#   9.  All 10 ArtReg keys resolve
#   10. TextureButton slots filled for both demo buttons
#
# HOW TO USE:
#   File → New Scene → Other Node → Control → attach this script
#   Scene → Run Current Scene (or F6)
# ─────────────────────────────────────────────────────────────────

# ── Group definitions ─────────────────────────────────────────────
# Each group: [ group_label, expected_w, expected_h, display_w, display_h, states[] ]
# Each state: [ artreg_key, res_path, texturebtn_slot, state_label ]

const _MD_W := 360
const _MD_H := 104
const _SEC_W := 320
const _SEC_H := 96

const _GROUPS: Array = [
	[
		"btn_primary_md", _MD_W, _MD_H, 144, 42,
		[
			["ui_button_primary_md_normal",
				"res://assets/ui/buttons/btn_primary_md_normal.png",   "texture_normal",   "normal"],
			["ui_button_primary_md_hover",
				"res://assets/ui/buttons/btn_primary_md_hover.png",    "texture_hover",    "hover"],
			["ui_button_primary_md_pressed",
				"res://assets/ui/buttons/btn_primary_md_pressed.png",  "texture_pressed",  "pressed"],
			["ui_button_primary_md_disabled",
				"res://assets/ui/buttons/btn_primary_md_disabled.png", "texture_disabled", "disabled"],
			["ui_button_primary_md_selected",
				"res://assets/ui/buttons/btn_primary_md_selected.png", "texture_focused",  "selected"],
		]
	],
	[
		"btn_secondary", _SEC_W, _SEC_H, 128, 38,
		[
			["ui_button_secondary_normal",
				"res://assets/ui/buttons/btn_secondary_normal.png",    "texture_normal",   "normal"],
			["ui_button_secondary_hover",
				"res://assets/ui/buttons/btn_secondary_hover.png",     "texture_hover",    "hover"],
			["ui_button_secondary_pressed",
				"res://assets/ui/buttons/btn_secondary_pressed.png",   "texture_pressed",  "pressed"],
			["ui_button_secondary_disabled",
				"res://assets/ui/buttons/btn_secondary_disabled.png",  "texture_disabled", "disabled"],
			["ui_button_secondary_selected",
				"res://assets/ui/buttons/btn_secondary_selected.png",  "texture_focused",  "selected"],
		]
	],
]

# One TextureButton demo per group (filled in _build_ui / _run_validation)
var _demo_buttons: Array[TextureButton] = []

# Preview grids: _preview_grids[g][s] = TextureButton thumbnail
var _preview_grids: Array = []

var _lbl_status: Label
var _lbl_results: Label


func _ready() -> void:
	_build_ui()
	await get_tree().process_frame
	_run_validation()


# ── UI construction ───────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(980, 600)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Moonseed — Phase 2 Validator  (btn_primary_md × 5  +  btn_secondary × 5)"
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	# ── One preview + demo row per button group ───────────────────
	for g in _GROUPS.size():
		var group      : Array  = _GROUPS[g]
		var group_label: String = group[0]
		var disp_w     : int    = group[3]
		var disp_h     : int    = group[4]
		var states     : Array  = group[5]

		var group_title := Label.new()
		group_title.text = "▸ " + group_label + "  (state previews):"
		vbox.add_child(group_title)

		var grid := GridContainer.new()
		grid.columns = states.size()
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 4)
		vbox.add_child(grid)

		var row_previews: Array[TextureButton] = []
		for state in states:
			var col := VBoxContainer.new()
			grid.add_child(col)

			var preview := TextureButton.new()
			preview.custom_minimum_size = Vector2(disp_w, disp_h)
			preview.ignore_texture_size = true
			preview.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			col.add_child(preview)
			row_previews.append(preview)

			var lbl := Label.new()
			lbl.text = state[3]
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(lbl)

		_preview_grids.append(row_previews)

		var demo_row := HBoxContainer.new()
		demo_row.add_theme_constant_override("separation", 12)
		vbox.add_child(demo_row)

		var demo_lbl := Label.new()
		demo_lbl.text = "Interactive demo (%s — hover/click to test):" % group_label
		demo_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		demo_row.add_child(demo_lbl)

		var demo := TextureButton.new()
		demo.custom_minimum_size = Vector2(disp_w, disp_h)
		demo.ignore_texture_size = true
		demo.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		demo_row.add_child(demo)
		_demo_buttons.append(demo)

		var toggle_lbl := Label.new()
		toggle_lbl.text = "(click to toggle disabled)"
		toggle_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		demo_row.add_child(toggle_lbl)

		demo.pressed.connect(func() -> void:
			demo.disabled = not demo.disabled
		)

		vbox.add_child(HSeparator.new())

	# ── Status + results ──────────────────────────────────────────
	_lbl_status = Label.new()
	_lbl_status.text = "Running…"
	vbox.add_child(_lbl_status)
	vbox.add_child(HSeparator.new())

	var results_title := Label.new()
	results_title.text = "Check details:"
	vbox.add_child(results_title)

	_lbl_results = Label.new()
	_lbl_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_lbl_results)


# ── Image-loading helper (direct-disk fallback) ───────────────────

func _load_image(res_path: String) -> Image:
	var tex := load(res_path) as Texture2D
	if tex != null:
		return tex.get_image()
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(res_path)) == OK:
		return img
	return null


# Sample 9 points; return true if any pixel differs between two images. ──

func _images_differ(a: Image, b: Image) -> bool:
	if a == null or b == null:
		return false
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return true
	var w := a.get_width()
	var h := a.get_height()
	var pts: Array[Vector2i] = [
		Vector2i(w / 6, h / 4),  Vector2i(w / 2, h / 4),  Vector2i(w * 5 / 6, h / 4),
		Vector2i(w / 6, h / 2),  Vector2i(w / 2, h / 2),  Vector2i(w * 5 / 6, h / 2),
		Vector2i(w / 6, h * 3 / 4), Vector2i(w / 2, h * 3 / 4), Vector2i(w * 5 / 6, h * 3 / 4),
	]
	for pt in pts:
		var ca: Color = a.get_pixel(pt.x, pt.y)
		var cb: Color = b.get_pixel(pt.x, pt.y)
		if ca != cb:
			return true
	return false


# ── Validation logic ──────────────────────────────────────────────

func _run_validation() -> void:
	var lines: Array[String] = []
	var pass_count := 0
	var fail_count := 0

	# Pre-load all images: _imgs[g][s]
	var _imgs: Array = []
	for g in _GROUPS.size():
		var group_images: Array = []
		var states: Array = _GROUPS[g][5]
		for state in states:
			group_images.append(_load_image(state[1]))
		_imgs.append(group_images)

	# ── Check 1: All 10 PNGs exist ────────────────────────────────
	var missing: Array[String] = []
	for g in _GROUPS.size():
		var states: Array = _GROUPS[g][5]
		for state in states:
			if not FileAccess.file_exists(state[1]):
				missing.append(_GROUPS[g][0] + "/" + state[3])
	if missing.is_empty():
		lines.append("[OK]   (1/10) All 10 state PNGs exist on disk")
		pass_count += 1
	else:
		lines.append("[FAIL] (1/10) %d / 10 PNGs missing:" % missing.size())
		for m in missing:
			lines.append("             • %s" % m)
		lines.append("             Run btn_phase2_generator.gd first.")
		fail_count += 1

	# ── Check 2: All 10 readable ──────────────────────────────────
	var unreadable: Array[String] = []
	for g in _GROUPS.size():
		for s in _imgs[g].size():
			if _imgs[g][s] == null:
				unreadable.append(_GROUPS[g][0] + "/" + _GROUPS[g][5][s][3])
	if unreadable.is_empty():
		lines.append("[OK]   (2/10) All 10 PNGs readable as Image data")
		pass_count += 1
	else:
		lines.append("[FAIL] (2/10) %d / 10 PNGs failed to load:" % unreadable.size())
		for u in unreadable:
			lines.append("             • %s" % u)
		lines.append("             Rescan FileSystem; check for disk errors.")
		fail_count += 1

	# ── Check 3: btn_primary_md canvas sizes = 360 × 104 ─────────
	_check_canvas_size(0, _MD_W, _MD_H, 3, _imgs, lines, pass_count, fail_count)
	pass_count = _last_pass
	fail_count = _last_fail

	# ── Check 4: btn_secondary canvas sizes = 320 × 96 ───────────
	_check_canvas_size(1, _SEC_W, _SEC_H, 4, _imgs, lines, pass_count, fail_count)
	pass_count = _last_pass
	fail_count = _last_fail

	# ── Check 5: btn_primary_md normal is painted ─────────────────
	_check_painted(0, 5, _imgs, lines, pass_count, fail_count)
	pass_count = _last_pass
	fail_count = _last_fail

	# ── Check 6: btn_secondary normal is painted ──────────────────
	_check_painted(1, 6, _imgs, lines, pass_count, fail_count)
	pass_count = _last_pass
	fail_count = _last_fail

	# ── Check 7: btn_primary_md state variants differ ─────────────
	_check_variants_differ(0, 7, _imgs, lines, pass_count, fail_count)
	pass_count = _last_pass
	fail_count = _last_fail

	# ── Check 8: btn_secondary state variants differ ───────────────
	_check_variants_differ(1, 8, _imgs, lines, pass_count, fail_count)
	pass_count = _last_pass
	fail_count = _last_fail

	# ── Check 9: ArtReg keys resolve ──────────────────────────────
	var art_reg = get_node_or_null("/root/ArtReg")
	if art_reg != null and art_reg.has_method("path_for"):
		var unresolved: Array[String] = []
		for g in _GROUPS.size():
			for state in _GROUPS[g][5]:
				if (art_reg.path_for(state[0]) as String).is_empty():
					unresolved.append(state[0])
		if unresolved.is_empty():
			lines.append("[OK]   (9/10) All 10 ArtReg keys resolve")
			pass_count += 1
		else:
			lines.append("[FAIL] (9/10) %d ArtReg keys unresolved:" % unresolved.size())
			for k in unresolved:
				lines.append("             • %s" % k)
			fail_count += 1
	else:
		lines.append("[INFO] (9/10) ArtReg autoload not detected — normal for a scratch scene.")

	# ── Check 10: TextureButton slots filled (both demos) ─────────
	var null_slots: Array[String] = []
	for g in _GROUPS.size():
		var states: Array = _GROUPS[g][5]
		for s in states.size():
			var img: Image = _imgs[g][s]
			var slot_name: String = states[s][2]
			var state_label: String = states[s][3]
			if img != null:
				var tex: Texture2D = ImageTexture.create_from_image(img)
				_demo_buttons[g].set(slot_name, tex)
				if s < _preview_grids[g].size():
					_preview_grids[g][s].set("texture_normal", tex)
			else:
				null_slots.append(_GROUPS[g][0] + "/" + state_label)
	if null_slots.is_empty():
		lines.append("[OK]   (10/10) All slots assigned on both demo buttons")
		pass_count += 1
	else:
		lines.append("[FAIL] (10/10) %d slots could not be filled:" % null_slots.size())
		for ns in null_slots:
			lines.append("              • %s" % ns)
		fail_count += 1

	# ── Summary ───────────────────────────────────────────────────
	lines.append("")
	var total := pass_count + fail_count
	if fail_count == 0:
		_lbl_status.text = "PHASE 2 PASS  (%d / %d checks)" % [pass_count, total]
		lines.append("All checks passed. btn_primary_md + btn_secondary are production-ready.")
		lines.append("Next: paint btn_confirm, btn_cancel, btn_shop → Phase 3.")
	else:
		_lbl_status.text = "PHASE 2 INCOMPLETE  (%d failures, %d / %d passed)" % [fail_count, pass_count, total]
		lines.append("Resolve [FAIL] items above, then re-run this scene.")

	_lbl_results.text = "\n".join(lines)

	print("\n── BtnPhase2Validator ────────────────────────────")
	for line in lines:
		print("  " + line)
	print("──────────────────────────────────────────────────\n")


# ── Reusable sub-checks (write results into lines; return via _last_*) ──

var _last_pass := 0
var _last_fail := 0


func _check_canvas_size(
		g: int, exp_w: int, exp_h: int, check_num: int,
		imgs: Array, lines: Array[String], pc: int, fc: int) -> void:
	var group_label: String = _GROUPS[g][0]
	var wrong: Array[String] = []
	for s in imgs[g].size():
		var img: Image = imgs[g][s]
		if img != null:
			if img.get_width() != exp_w or img.get_height() != exp_h:
				wrong.append("%s (%d×%d)" % [_GROUPS[g][5][s][3], img.get_width(), img.get_height()])
	var all_loaded := true
	for s in imgs[g].size():
		if imgs[g][s] == null:
			all_loaded = false
			break
	if wrong.is_empty() and all_loaded:
		lines.append("[OK]   (%d/10) %s canvas sizes: %d × %d px" % [check_num, group_label, exp_w, exp_h])
		_last_pass = pc + 1
		_last_fail = fc
	elif not wrong.is_empty():
		lines.append("[FAIL] (%d/10) %s wrong canvas size: %s" % [check_num, group_label, "  |  ".join(wrong)])
		lines.append("             Expected %d × %d — re-export from Krita." % [exp_w, exp_h])
		_last_pass = pc
		_last_fail = fc + 1
	else:
		lines.append("[SKIP] (%d/10) %s canvas size check skipped — PNGs did not load." % [check_num, group_label])
		_last_pass = pc
		_last_fail = fc


func _check_painted(
		g: int, check_num: int,
		imgs: Array, lines: Array[String], pc: int, fc: int) -> void:
	var group_label: String = _GROUPS[g][0]
	var norm_img: Image = imgs[g][0]
	var exp_w: int = _GROUPS[g][1]
	var exp_h: int = _GROUPS[g][2]
	if norm_img != null:
		var probe := norm_img.duplicate()
		probe.convert(Image.FORMAT_RGBA8)
		var center: Color = probe.get_pixel(exp_w / 2, exp_h / 2)
		if center.a > 0.0:
			lines.append("[OK]   (%d/10) %s normal center pixel: alpha=%.3f  (painted)" % [check_num, group_label, center.a])
			_last_pass = pc + 1
			_last_fail = fc
		else:
			lines.append("[FAIL] (%d/10) %s normal center pixel: alpha=0.0  (still blank template)" % [check_num, group_label])
			lines.append("             Paint %s_normal.png per BUTTON_STYLE_GUIDE.md." % group_label)
			_last_pass = pc
			_last_fail = fc + 1
	else:
		lines.append("[SKIP] (%d/10) %s normal PNG did not load — skipping painted-check." % [check_num, group_label])
		_last_pass = pc
		_last_fail = fc


func _check_variants_differ(
		g: int, check_num: int,
		imgs: Array, lines: Array[String], pc: int, fc: int) -> void:
	var group_label: String = _GROUPS[g][0]
	var norm_img: Image     = imgs[g][0]
	var identical: Array[String] = []
	var skipped: Array[String]   = []
	for s in range(1, imgs[g].size()):
		var variant_img: Image    = imgs[g][s]
		var state_label: String   = _GROUPS[g][5][s][3]
		if norm_img != null and variant_img != null:
			if not _images_differ(norm_img, variant_img):
				identical.append(state_label)
		else:
			skipped.append(state_label)
	if identical.is_empty() and skipped.is_empty():
		lines.append("[OK]   (%d/10) %s — all 4 state variants differ from normal" % [check_num, group_label])
		_last_pass = pc + 1
		_last_fail = fc
	elif not identical.is_empty():
		lines.append("[FAIL] (%d/10) %s — identical to normal: %s" % [check_num, group_label, ", ".join(identical)])
		lines.append("             Apply §13 state deltas in BUTTON_STYLE_GUIDE.md.")
		_last_pass = pc
		_last_fail = fc + 1
	else:
		lines.append("[SKIP] (%d/10) %s variant check skipped: %s" % [check_num, group_label, ", ".join(skipped)])
		_last_pass = pc
		_last_fail = fc
