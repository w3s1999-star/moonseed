extends Control

# ─────────────────────────────────────────────────────────────────
# BtnPhase5Validator.gd  —  Moonseed Button Art Phase 5 Validator
#
# Validates all 25 merchant variant PNGs across 5 Bazaar merchants.
# All use canvas 320 × 104 px and live in assets/ui/buttons/merchants/.
#
# WHAT IT CHECKS:
#   1.  All 25 state PNGs exist on disk
#   2.  All 25 are readable as Image data
#   3.  All 25 canvas sizes = 320 × 104 px
#   4.  All 5 normal center pixels are painted (alpha > 0)
#   5.  pearl    — 4 state variants differ from its own normal
#   6.  dice     — 4 state variants differ from its own normal
#   7.  curio    — 4 state variants differ from its own normal
#   8.  sweet    — 4 state variants differ from its own normal
#   9.  selenic  — 4 state variants differ from its own normal
#   10. All 5 merchants have normals that differ from each other
#         (ensures no merchant re-uses another merchant's fill)
#   11. All 25 ArtReg keys resolve
#   12. TextureButton slots filled for all 5 demo buttons
#
# HOW TO USE:
#   File → New Scene → Other Node → Control → attach this script
#   Scene → Run Current Scene (or F6)
# ─────────────────────────────────────────────────────────────────

const _W := 320
const _H := 104

const _GROUPS: Array = [
	# [ group_label, short_key, disp_w, disp_h, states[] ]
	# states: [ artreg_key, res_path, texturebtn_slot, state_label ]
	[
		"Pearl Exchange", "pearl", 128, 42,
		[
			["ui_button_merchant_pearl_normal",
				"res://assets/ui/buttons/merchants/btn_merchant_pearl_normal.png",   "texture_normal",   "normal"],
			["ui_button_merchant_pearl_hover",
				"res://assets/ui/buttons/merchants/btn_merchant_pearl_hover.png",    "texture_hover",    "hover"],
			["ui_button_merchant_pearl_pressed",
				"res://assets/ui/buttons/merchants/btn_merchant_pearl_pressed.png",  "texture_pressed",  "pressed"],
			["ui_button_merchant_pearl_disabled",
				"res://assets/ui/buttons/merchants/btn_merchant_pearl_disabled.png", "texture_disabled", "disabled"],
			["ui_button_merchant_pearl_selected",
				"res://assets/ui/buttons/merchants/btn_merchant_pearl_selected.png", "texture_focused",  "selected"],
		]
	],
	[
		"Dice Carver", "dice", 128, 42,
		[
			["ui_button_merchant_dice_normal",
				"res://assets/ui/buttons/merchants/btn_merchant_dice_normal.png",    "texture_normal",   "normal"],
			["ui_button_merchant_dice_hover",
				"res://assets/ui/buttons/merchants/btn_merchant_dice_hover.png",     "texture_hover",    "hover"],
			["ui_button_merchant_dice_pressed",
				"res://assets/ui/buttons/merchants/btn_merchant_dice_pressed.png",   "texture_pressed",  "pressed"],
			["ui_button_merchant_dice_disabled",
				"res://assets/ui/buttons/merchants/btn_merchant_dice_disabled.png",  "texture_disabled", "disabled"],
			["ui_button_merchant_dice_selected",
				"res://assets/ui/buttons/merchants/btn_merchant_dice_selected.png",  "texture_focused",  "selected"],
		]
	],
	[
		"Curio Dealer", "curio", 128, 42,
		[
			["ui_button_merchant_curio_normal",
				"res://assets/ui/buttons/merchants/btn_merchant_curio_normal.png",   "texture_normal",   "normal"],
			["ui_button_merchant_curio_hover",
				"res://assets/ui/buttons/merchants/btn_merchant_curio_hover.png",    "texture_hover",    "hover"],
			["ui_button_merchant_curio_pressed",
				"res://assets/ui/buttons/merchants/btn_merchant_curio_pressed.png",  "texture_pressed",  "pressed"],
			["ui_button_merchant_curio_disabled",
				"res://assets/ui/buttons/merchants/btn_merchant_curio_disabled.png", "texture_disabled", "disabled"],
			["ui_button_merchant_curio_selected",
				"res://assets/ui/buttons/merchants/btn_merchant_curio_selected.png", "texture_focused",  "selected"],
		]
	],
	[
		"Sweetmaker Stall", "sweet", 128, 42,
		[
			["ui_button_merchant_sweet_normal",
				"res://assets/ui/buttons/merchants/btn_merchant_sweet_normal.png",   "texture_normal",   "normal"],
			["ui_button_merchant_sweet_hover",
				"res://assets/ui/buttons/merchants/btn_merchant_sweet_hover.png",    "texture_hover",    "hover"],
			["ui_button_merchant_sweet_pressed",
				"res://assets/ui/buttons/merchants/btn_merchant_sweet_pressed.png",  "texture_pressed",  "pressed"],
			["ui_button_merchant_sweet_disabled",
				"res://assets/ui/buttons/merchants/btn_merchant_sweet_disabled.png", "texture_disabled", "disabled"],
			["ui_button_merchant_sweet_selected",
				"res://assets/ui/buttons/merchants/btn_merchant_sweet_selected.png", "texture_focused",  "selected"],
		]
	],
	[
		"Selenic Exchange", "selenic", 128, 42,
		[
			["ui_button_merchant_selenic_normal",
				"res://assets/ui/buttons/merchants/btn_merchant_selenic_normal.png",   "texture_normal",   "normal"],
			["ui_button_merchant_selenic_hover",
				"res://assets/ui/buttons/merchants/btn_merchant_selenic_hover.png",    "texture_hover",    "hover"],
			["ui_button_merchant_selenic_pressed",
				"res://assets/ui/buttons/merchants/btn_merchant_selenic_pressed.png",  "texture_pressed",  "pressed"],
			["ui_button_merchant_selenic_disabled",
				"res://assets/ui/buttons/merchants/btn_merchant_selenic_disabled.png", "texture_disabled", "disabled"],
			["ui_button_merchant_selenic_selected",
				"res://assets/ui/buttons/merchants/btn_merchant_selenic_selected.png", "texture_focused",  "selected"],
		]
	],
]

var _demo_buttons: Array[TextureButton] = []
var _preview_grids: Array = []
var _lbl_status: Label
var _lbl_results: Label


func _ready() -> void:
	_build_ui()
	await get_tree().process_frame
	_run_validation()


# ── UI construction ───────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(980, 800)
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
	title.text = "Moonseed — Phase 5 Validator  (5 merchants × 5 states = 25 PNGs)"
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	for g in _GROUPS.size():
		var group       : Array  = _GROUPS[g]
		var group_label : String = group[0]
		var disp_w      : int    = group[2]
		var disp_h      : int    = group[3]
		var states      : Array  = group[4]

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
		demo_lbl.text = "Demo (%s):" % group_label
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


# ── Helpers ───────────────────────────────────────────────────────

func _load_image(res_path: String) -> Image:
	var tex := load(res_path) as Texture2D
	if tex != null:
		return tex.get_image()
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(res_path)) == OK:
		return img
	return null


func _images_differ(a: Image, b: Image) -> bool:
	if a == null or b == null:
		return false
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return true
	var w := a.get_width()
	var h := a.get_height()
	var pts: Array[Vector2i] = [
		Vector2i(w / 6, h / 4),      Vector2i(w / 2, h / 4),      Vector2i(w * 5 / 6, h / 4),
		Vector2i(w / 6, h / 2),      Vector2i(w / 2, h / 2),      Vector2i(w * 5 / 6, h / 2),
		Vector2i(w / 6, h * 3 / 4),  Vector2i(w / 2, h * 3 / 4),  Vector2i(w * 5 / 6, h * 3 / 4),
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
		for state in _GROUPS[g][4]:
			group_images.append(_load_image(state[1]))
		_imgs.append(group_images)

	# ── Check 1: All 25 PNGs exist ────────────────────────────────
	var missing: Array[String] = []
	for g in _GROUPS.size():
		for state in _GROUPS[g][4]:
			if not FileAccess.file_exists(state[1]):
				missing.append(_GROUPS[g][0] + "/" + state[3])
	if missing.is_empty():
		lines.append("[OK]   (1/12) All 25 state PNGs exist on disk")
		pass_count += 1
	else:
		lines.append("[FAIL] (1/12) %d / 25 PNGs missing:" % missing.size())
		for m in missing:
			lines.append("             • %s" % m)
		lines.append("             Run btn_phase5_generator.gd first.")
		fail_count += 1

	# ── Check 2: All 25 readable ──────────────────────────────────
	var unreadable: Array[String] = []
	for g in _GROUPS.size():
		for s in _imgs[g].size():
			if _imgs[g][s] == null:
				unreadable.append(_GROUPS[g][0] + "/" + _GROUPS[g][4][s][3])
	if unreadable.is_empty():
		lines.append("[OK]   (2/12) All 25 PNGs readable as Image data")
		pass_count += 1
	else:
		lines.append("[FAIL] (2/12) %d / 25 PNGs failed to load:" % unreadable.size())
		for u in unreadable:
			lines.append("             • %s" % u)
		fail_count += 1

	# ── Check 3: All 25 canvas sizes = 320 × 104 ─────────────────
	var wrong_size: Array[String] = []
	var all_loaded := true
	for g in _GROUPS.size():
		for s in _imgs[g].size():
			var img: Image = _imgs[g][s]
			if img == null:
				all_loaded = false
			elif img.get_width() != _W or img.get_height() != _H:
				wrong_size.append("%s/%s (%d×%d)" % [_GROUPS[g][0], _GROUPS[g][4][s][3], img.get_width(), img.get_height()])
	if wrong_size.is_empty() and all_loaded:
		lines.append("[OK]   (3/12) All 25 canvas sizes: %d × %d px" % [_W, _H])
		pass_count += 1
	elif not wrong_size.is_empty():
		lines.append("[FAIL] (3/12) Wrong canvas sizes:")
		for ws in wrong_size:
			lines.append("             • %s  (expected %d × %d)" % [ws, _W, _H])
		fail_count += 1
	else:
		lines.append("[SKIP] (3/12) Canvas size check skipped — some PNGs did not load.")

	# ── Check 4: All 5 normal center pixels painted ───────────────
	var unpainted: Array[String] = []
	var norm_skipped: Array[String] = []
	for g in _GROUPS.size():
		var norm_img: Image = _imgs[g][0]
		if norm_img != null:
			var probe := norm_img.duplicate()
			probe.convert(Image.FORMAT_RGBA8)
			var center: Color = probe.get_pixel(_W / 2, _H / 2)
			if center.a == 0.0:
				unpainted.append(_GROUPS[g][0])
		else:
			norm_skipped.append(_GROUPS[g][0])
	if unpainted.is_empty() and norm_skipped.is_empty():
		lines.append("[OK]   (4/12) All 5 merchant normals are painted  (alpha > 0)")
		pass_count += 1
	elif not unpainted.is_empty():
		lines.append("[FAIL] (4/12) Still blank (alpha=0) normals:")
		for u in unpainted:
			lines.append("             • %s — paint per §14 of BUTTON_STYLE_GUIDE.md." % u)
		fail_count += 1
	else:
		lines.append("[SKIP] (4/12) Normal painted check skipped — some PNGs did not load.")

	# ── Checks 5–9: Per-merchant state variants differ from normal ─
	for g in _GROUPS.size():
		var check_num := 5 + g
		var group_label: String = _GROUPS[g][0]
		var norm_img: Image = _imgs[g][0]
		var identical: Array[String] = []
		var skipped_v: Array[String] = []
		for s in range(1, _imgs[g].size()):
			var variant_img: Image  = _imgs[g][s]
			var state_label: String = _GROUPS[g][4][s][3]
			if norm_img != null and variant_img != null:
				if not _images_differ(norm_img, variant_img):
					identical.append(state_label)
			else:
				skipped_v.append(state_label)
		if identical.is_empty() and skipped_v.is_empty():
			lines.append("[OK]   (%d/12) %s — all 4 state variants differ from normal" % [check_num, group_label])
			pass_count += 1
		elif not identical.is_empty():
			lines.append("[FAIL] (%d/12) %s — identical to normal: %s" % [check_num, group_label, ", ".join(identical)])
			lines.append("             Apply §13 state deltas from %s's own base palette." % group_label)
			fail_count += 1
		else:
			lines.append("[SKIP] (%d/12) %s variant check skipped: %s" % [check_num, group_label, ", ".join(skipped_v)])

	# ── Check 10: All 5 merchant normals differ from each other ───
	var duplicate_pairs: Array[String] = []
	for g in _GROUPS.size():
		for h in range(g + 1, _GROUPS.size()):
			var img_a: Image = _imgs[g][0]
			var img_b: Image = _imgs[h][0]
			if img_a != null and img_b != null:
				if not _images_differ(img_a, img_b):
					duplicate_pairs.append("%s ≡ %s" % [_GROUPS[g][0], _GROUPS[h][0]])
	if duplicate_pairs.is_empty():
		lines.append("[OK]   (10/12) All 5 merchant normals are visually distinct from each other")
		pass_count += 1
	else:
		lines.append("[FAIL] (10/12) These merchant normals look identical:")
		for dp in duplicate_pairs:
			lines.append("              • %s" % dp)
		lines.append("              Each merchant must have its own unique fill (§14).")
		fail_count += 1

	# ── Check 11: ArtReg keys resolve ─────────────────────────────
	var art_reg = get_node_or_null("/root/ArtReg")
	if art_reg != null and art_reg.has_method("path_for"):
		var unresolved: Array[String] = []
		for g in _GROUPS.size():
			for state in _GROUPS[g][4]:
				if (art_reg.path_for(state[0]) as String).is_empty():
					unresolved.append(state[0])
		if unresolved.is_empty():
			lines.append("[OK]   (11/12) All 25 ArtReg keys resolve")
			pass_count += 1
		else:
			lines.append("[FAIL] (11/12) %d ArtReg keys unresolved:" % unresolved.size())
			for k in unresolved:
				lines.append("              • %s" % k)
			fail_count += 1
	else:
		lines.append("[INFO] (11/12) ArtReg autoload not detected — normal for a scratch scene.")

	# ── Check 12: TextureButton slots filled (all 5 demos) ────────
	var null_slots: Array[String] = []
	for g in _GROUPS.size():
		for s in _GROUPS[g][4].size():
			var img: Image          = _imgs[g][s]
			var slot_name: String   = _GROUPS[g][4][s][2]
			var state_label: String = _GROUPS[g][4][s][3]
			if img != null:
				var tex: Texture2D = ImageTexture.create_from_image(img)
				_demo_buttons[g].set(slot_name, tex)
				if s < _preview_grids[g].size():
					_preview_grids[g][s].set("texture_normal", tex)
			else:
				null_slots.append(_GROUPS[g][0] + "/" + state_label)
	if null_slots.is_empty():
		lines.append("[OK]   (12/12) All slots assigned on all 5 merchant demo buttons")
		pass_count += 1
	else:
		lines.append("[FAIL] (12/12) %d slots could not be filled:" % null_slots.size())
		for ns in null_slots:
			lines.append("              • %s" % ns)
		fail_count += 1

	# ── Summary ───────────────────────────────────────────────────
	lines.append("")
	var total := pass_count + fail_count
	if fail_count == 0:
		_lbl_status.text = "PHASE 5 PASS  (%d / %d checks)" % [pass_count, total]
		lines.append("All checks passed. All 5 merchant variants are production-ready.")
		lines.append("Next: Phase 6 — polish pass (P2 selected states + final QA).")
	else:
		_lbl_status.text = "PHASE 5 INCOMPLETE  (%d failures, %d / %d passed)" % [fail_count, pass_count, total]
		lines.append("Resolve [FAIL] items above, then re-run this scene.")

	_lbl_results.text = "\n".join(lines)

	print("\n── BtnPhase5Validator ────────────────────────────")
	for line in lines:
		print("  " + line)
	print("──────────────────────────────────────────────────\n")
