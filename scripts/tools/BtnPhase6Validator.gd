extends Control

# ─────────────────────────────────────────────────────────────────
# BtnPhase6Validator.gd  —  Moonseed Button Art Phase 6 Validator
#
# Validates the 6 "P2 deferred selected" state PNGs:
#   btn_primary_lg_selected      (408 × 120)
#   btn_primary_md_selected      (360 × 104)
#   btn_secondary_selected       (320 ×  96)
#   btn_confirm_selected         (280 ×  96)
#   btn_cancel_selected          (280 ×  96)
#   btn_shop_merchant_selected   (320 × 104)
#
# WHAT IT CHECKS:
#   1.  All 6 P2 selected PNGs exist on disk
#   2.  All 6 readable as Image data
#   3.  Canvas sizes correct for all 6
#   4.  All 6 selected center pixels are painted (alpha > 0)
#   5.  Each selected state differs from its corresponding normal state
#   6.  All 6 selected states are mutually distinct (no duplicate placeholders)
#   7.  Cross-phase sanity: all 6 corresponding normal states exist on disk
#   8.  ArtReg keys resolve for all 6 selected states
#   9.  TextureButton texture_focused slot accepts all 6 textures
#   10. Pipeline breadth check: sampled PNGs from phases 1 / 4 / 5 still present
#
# HOW TO USE:
#   File → New Scene → Other Node → Control → attach this script
#   Scene → Run Current Scene (or F6)
# ─────────────────────────────────────────────────────────────────

# Each entry:
#   [ artreg_sel_key, sel_path, artreg_norm_key, norm_path,
#     exp_w, exp_h, disp_w, disp_h, label ]
const _P2_STATES: Array = [
	[
		"ui_button_primary_lg_selected",
		"res://assets/ui/buttons/btn_primary_lg_selected.png",
		"ui_button_primary_lg_normal",
		"res://assets/ui/buttons/btn_primary_lg_normal.png",
		408, 120, 160, 47, "btn_primary_lg",
	],
	[
		"ui_button_primary_md_selected",
		"res://assets/ui/buttons/btn_primary_md_selected.png",
		"ui_button_primary_md_normal",
		"res://assets/ui/buttons/btn_primary_md_normal.png",
		360, 104, 140, 40, "btn_primary_md",
	],
	[
		"ui_button_secondary_selected",
		"res://assets/ui/buttons/btn_secondary_selected.png",
		"ui_button_secondary_normal",
		"res://assets/ui/buttons/btn_secondary_normal.png",
		320, 96, 128, 38, "btn_secondary",
	],
	[
		"ui_button_confirm_selected",
		"res://assets/ui/buttons/btn_confirm_selected.png",
		"ui_button_confirm_normal",
		"res://assets/ui/buttons/btn_confirm_normal.png",
		280, 96, 112, 38, "btn_confirm",
	],
	[
		"ui_button_cancel_selected",
		"res://assets/ui/buttons/btn_cancel_selected.png",
		"ui_button_cancel_normal",
		"res://assets/ui/buttons/btn_cancel_normal.png",
		280, 96, 112, 38, "btn_cancel",
	],
	[
		"ui_button_shop_selected",
		"res://assets/ui/buttons/btn_shop_merchant_selected.png",
		"ui_button_shop_normal",
		"res://assets/ui/buttons/btn_shop_merchant_normal.png",
		320, 104, 128, 40, "btn_shop_merchant",
	],
]

# Spot-check PNGs from phases 1, 4, 5 to confirm earlier output is intact
const _SANITY_PATHS: Array[String] = [
	"res://assets/ui/buttons/btn_primary_lg_normal.png",
	"res://assets/ui/buttons/btn_tab_sm_selected.png",
	"res://assets/ui/buttons/merchants/btn_merchant_pearl_normal.png",
]

var _demo_button: TextureButton
var _preview_cells: Array[TextureButton] = []
var _lbl_status: Label
var _lbl_results: Label


func _ready() -> void:
	_build_ui()
	await get_tree().process_frame
	_run_validation()


# ── UI construction ───────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(900, 600)
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
	title.text = "Moonseed — Phase 6 Validator  (6 P2 selected-state PNGs)"
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var preview_title := Label.new()
	preview_title.text = "▸ P2 selected-state previews  (gold border = phase 6 placeholder):"
	vbox.add_child(preview_title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	for i in _P2_STATES.size():
		var entry: Array   = _P2_STATES[i]
		var disp_w: int    = entry[6]
		var disp_h: int    = entry[7]
		var lbl_text: String = entry[8]

		var col := VBoxContainer.new()
		grid.add_child(col)

		var preview := TextureButton.new()
		preview.custom_minimum_size = Vector2(disp_w, disp_h)
		preview.ignore_texture_size = true
		preview.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		col.add_child(preview)
		_preview_cells.append(preview)

		var lbl := Label.new()
		lbl.text = lbl_text + "\nselected"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lbl)

	vbox.add_child(HSeparator.new())

	var demo_row := HBoxContainer.new()
	demo_row.add_theme_constant_override("separation", 12)
	vbox.add_child(demo_row)

	var demo_lbl := Label.new()
	demo_lbl.text = "Demo (btn_primary_lg — click to toggle disabled):"
	demo_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	demo_row.add_child(demo_lbl)

	_demo_button = TextureButton.new()
	_demo_button.custom_minimum_size = Vector2(160, 47)
	_demo_button.ignore_texture_size = true
	_demo_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	demo_row.add_child(_demo_button)

	var hint_lbl := Label.new()
	hint_lbl.text = "(Tab key shows texture_focused = selected state)"
	hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	demo_row.add_child(hint_lbl)

	_demo_button.pressed.connect(func() -> void:
		_demo_button.disabled = not _demo_button.disabled
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

	# Load all 6 selected images
	var sel_imgs: Array = []
	for i in _P2_STATES.size():
		sel_imgs.append(_load_image(_P2_STATES[i][1]))

	# Load all 6 corresponding normal images (for cross-diff check)
	var norm_imgs: Array = []
	for i in _P2_STATES.size():
		norm_imgs.append(_load_image(_P2_STATES[i][3]))

	# ── Check 1: All 6 P2 selected PNGs exist ────────────────────
	var missing: Array[String] = []
	for i in _P2_STATES.size():
		if not FileAccess.file_exists(_P2_STATES[i][1]):
			missing.append(_P2_STATES[i][8])
	if missing.is_empty():
		lines.append("[OK]   (1/10) All 6 P2 selected PNGs exist on disk")
		pass_count += 1
	else:
		lines.append("[FAIL] (1/10) %d / 6 P2 selected PNGs missing:" % missing.size())
		for m in missing:
			lines.append("             • %s_selected.png" % m)
		lines.append("             Run btn_phase6_generator.gd first.")
		fail_count += 1

	# ── Check 2: All 6 readable ──────────────────────────────────
	var unreadable: Array[String] = []
	for i in _P2_STATES.size():
		if sel_imgs[i] == null:
			unreadable.append(_P2_STATES[i][8])
	if unreadable.is_empty():
		lines.append("[OK]   (2/10) All 6 P2 selected PNGs readable as Image data")
		pass_count += 1
	else:
		lines.append("[FAIL] (2/10) %d / 6 PNGs failed to load:" % unreadable.size())
		for u in unreadable:
			lines.append("             • %s_selected.png" % u)
		fail_count += 1

	# ── Check 3: Canvas dimensions ───────────────────────────────
	var wrong_size: Array[String] = []
	for i in _P2_STATES.size():
		var img: Image    = sel_imgs[i]
		var exp_w: int    = _P2_STATES[i][4]
		var exp_h: int    = _P2_STATES[i][5]
		var label: String = _P2_STATES[i][8]
		if img != null:
			if img.get_width() != exp_w or img.get_height() != exp_h:
				wrong_size.append("%s (%d×%d, expected %d×%d)" % [
						label, img.get_width(), img.get_height(), exp_w, exp_h])
	if wrong_size.is_empty():
		lines.append("[OK]   (3/10) All 6 canvas sizes correct")
		pass_count += 1
	else:
		lines.append("[FAIL] (3/10) %d canvas size mismatches:" % wrong_size.size())
		for ws in wrong_size:
			lines.append("             • %s" % ws)
		lines.append("             Re-export from Krita or re-run btn_phase6_generator.gd.")
		fail_count += 1

	# ── Check 4: Center pixels painted (alpha > 0) ───────────────
	var unpainted: Array[String] = []
	for i in _P2_STATES.size():
		var img: Image    = sel_imgs[i]
		var exp_w: int    = _P2_STATES[i][4]
		var exp_h: int    = _P2_STATES[i][5]
		var label: String = _P2_STATES[i][8]
		if img != null:
			var probe := img.duplicate()
			probe.convert(Image.FORMAT_RGBA8)
			var center: Color = probe.get_pixel(exp_w / 2, exp_h / 2)
			if center.a <= 0.0:
				unpainted.append(label)
	if unpainted.is_empty():
		lines.append("[OK]   (4/10) All 6 selected center pixels are painted (alpha > 0)")
		pass_count += 1
	else:
		lines.append("[FAIL] (4/10) %d selected PNGs have transparent center pixel:" % unpainted.size())
		for u in unpainted:
			lines.append("             • %s_selected.png" % u)
		fail_count += 1

	# ── Check 5: Each selected ≠ corresponding normal ─────────────
	var sel_matches_norm: Array[String] = []
	var sel_skip5: Array[String] = []
	for i in _P2_STATES.size():
		var sel_img: Image  = sel_imgs[i]
		var norm_img: Image = norm_imgs[i]
		var label: String   = _P2_STATES[i][8]
		if sel_img != null and norm_img != null:
			if not _images_differ(sel_img, norm_img):
				sel_matches_norm.append(label)
		else:
			sel_skip5.append(label)
	if sel_matches_norm.is_empty() and sel_skip5.is_empty():
		lines.append("[OK]   (5/10) All 6 selected states differ from their corresponding normal states")
		pass_count += 1
	elif not sel_matches_norm.is_empty():
		lines.append("[FAIL] (5/10) %d selected states identical to normal:" % sel_matches_norm.size())
		for m in sel_matches_norm:
			lines.append("             • %s — run btn_phase6_generator.gd to create distinct placeholder" % m)
		fail_count += 1
	else:
		lines.append("[SKIP] (5/10) selected-vs-normal diff check skipped for: %s" % ", ".join(sel_skip5))

	# ── Check 6: All 6 selected states mutually differ ────────────
	var dupes: Array[String] = []
	for a in range(_P2_STATES.size() - 1):
		for b in range(a + 1, _P2_STATES.size()):
			var img_a: Image = sel_imgs[a]
			var img_b: Image = sel_imgs[b]
			if img_a != null and img_b != null:
				if not _images_differ(img_a, img_b):
					dupes.append("%s vs %s" % [_P2_STATES[a][8], _P2_STATES[b][8]])
	if dupes.is_empty():
		lines.append("[OK]   (6/10) All 6 selected states are mutually distinct (no duplicate placeholders)")
		pass_count += 1
	else:
		lines.append("[FAIL] (6/10) %d selected-state pairs are identical:" % dupes.size())
		for d in dupes:
			lines.append("             • %s" % d)
		fail_count += 1

	# ── Check 7: Corresponding normal states exist (cross-phase) ──
	var norm_missing: Array[String] = []
	for i in _P2_STATES.size():
		if not FileAccess.file_exists(_P2_STATES[i][3]):
			norm_missing.append(_P2_STATES[i][8])
	if norm_missing.is_empty():
		lines.append("[OK]   (7/10) All 6 corresponding normal-state PNGs exist  (cross-phase sanity)")
		pass_count += 1
	else:
		lines.append("[FAIL] (7/10) %d normal-state PNGs missing — earlier phases may need re-run:" % norm_missing.size())
		for m in norm_missing:
			lines.append("             • %s_normal.png" % m)
		fail_count += 1

	# ── Check 8: ArtReg keys resolve ─────────────────────────────
	var art_reg = get_node_or_null("/root/ArtReg")
	if art_reg != null and art_reg.has_method("path_for"):
		var unresolved: Array[String] = []
		for i in _P2_STATES.size():
			if (art_reg.path_for(_P2_STATES[i][0]) as String).is_empty():
				unresolved.append(_P2_STATES[i][0])
		if unresolved.is_empty():
			lines.append("[OK]   (8/10) All 6 ArtReg selected-state keys resolve")
			pass_count += 1
		else:
			lines.append("[FAIL] (8/10) %d ArtReg keys unresolved:" % unresolved.size())
			for k in unresolved:
				lines.append("             • %s" % k)
			fail_count += 1
	else:
		lines.append("[INFO] (8/10) ArtReg autoload not detected — normal for a scratch scene.")

	# ── Check 9: TextureButton slot assignment ────────────────────
	var null_slots: Array[String] = []
	for i in _P2_STATES.size():
		var img: Image    = sel_imgs[i]
		var label: String = _P2_STATES[i][8]
		if img != null:
			var tex: Texture2D = ImageTexture.create_from_image(img)
			if i < _preview_cells.size():
				_preview_cells[i].set("texture_normal", tex)
			if i == 0:
				# Load primary_lg normal and selected onto the demo button
				_demo_button.set("texture_focused", tex)
				var norm0: Image = norm_imgs[0]
				if norm0 != null:
					_demo_button.set("texture_normal", ImageTexture.create_from_image(norm0))
		else:
			null_slots.append(label)
	if null_slots.is_empty():
		lines.append("[OK]   (9/10) All 6 selected textures assigned to TextureButton slots")
		pass_count += 1
	else:
		lines.append("[FAIL] (9/10) %d selected textures could not be assigned:" % null_slots.size())
		for ns in null_slots:
			lines.append("             • %s" % ns)
		fail_count += 1

	# ── Check 10: Pipeline breadth — earlier phases still intact ──
	var broad_missing: Array[String] = []
	for path in _SANITY_PATHS:
		if not FileAccess.file_exists(path):
			broad_missing.append(path.get_file())
	if broad_missing.is_empty():
		lines.append("[OK]   (10/10) Pipeline breadth check: phase 1 / 4 / 5 probe PNGs still present")
		pass_count += 1
	else:
		lines.append("[FAIL] (10/10) %d probe PNGs from earlier phases missing:" % broad_missing.size())
		for m in broad_missing:
			lines.append("             • %s" % m)
		lines.append("             Re-run the relevant phase generator(s).")
		fail_count += 1

	# ── Summary ───────────────────────────────────────────────────
	lines.append("")
	var total := pass_count + fail_count
	if fail_count == 0:
		_lbl_status.text = "PHASE 6 PASS  (%d / %d checks)" % [pass_count, total]
		lines.append("All checks passed. P2 selected-state placeholders are production-ready.")
		lines.append("Full button pipeline complete — hand off to artist for final polish pass.")
	else:
		_lbl_status.text = "PHASE 6 INCOMPLETE  (%d failures, %d / %d passed)" % [
				fail_count, pass_count, total]
		lines.append("Resolve [FAIL] items above, then re-run this scene.")

	_lbl_results.text = "\n".join(lines)

	print("\n── BtnPhase6Validator ────────────────────────────")
	for line in lines:
		print("  " + line)
	print("──────────────────────────────────────────────────\n")
