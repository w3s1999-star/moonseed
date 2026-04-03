extends Control

# ─────────────────────────────────────────────────────────────────
# BtnPhase1Validator.gd  —  Moonseed Button Art Phase 1 Validator
#
# Validates all 5 state PNGs for btn_primary_lg — the Phase 1
# vertical-slice deliverable.  Extends the Phase 0 pattern with
# per-state checks and a cross-state uniqueness check.
#
# WHAT IT CHECKS:
#   1.  All 5 state PNGs exist on disk
#   2.  All 5 are readable as Image data (direct-disk fallback)
#   3.  All 5 have correct canvas size  (408 × 120 px)
#   4.  Normal center pixel is NOT fully transparent (has been painted)
#   5.  hover    is visually distinct from normal
#   6.  pressed  is visually distinct from normal
#   7.  disabled is visually distinct from normal
#   8.  selected is visually distinct from normal
#   9.  All 5 ArtReg keys resolve
#   10. TextureButton accepts all 5 textures in their correct slots
#
# HOW TO USE:
#   File → New Scene → Other Node → Control → attach this script
#   Scene → Run Current Scene (or F6)
#   Hover / click the interactive demo button to exercise slot wiring.
# ─────────────────────────────────────────────────────────────────

const _EXPECTED_W := 408
const _EXPECTED_H := 120
const _DISPLAY_W  := 160   # preview column width  (keeps 408:120 ratio)
const _DISPLAY_H  := 47    # preview column height

# Each entry: [ artreg_key, res_path, TextureButton_slot, display_label ]
const _STATES: Array = [
	["ui_button_primary_lg_normal",
		"res://assets/ui/buttons/btn_primary_lg_normal.png",   "texture_normal",   "normal"],
	["ui_button_primary_lg_hover",
		"res://assets/ui/buttons/btn_primary_lg_hover.png",    "texture_hover",    "hover"],
	["ui_button_primary_lg_pressed",
		"res://assets/ui/buttons/btn_primary_lg_pressed.png",  "texture_pressed",  "pressed"],
	["ui_button_primary_lg_disabled",
		"res://assets/ui/buttons/btn_primary_lg_disabled.png", "texture_disabled", "disabled"],
	["ui_button_primary_lg_selected",
		"res://assets/ui/buttons/btn_primary_lg_selected.png", "texture_focused",  "selected"],
]

var _preview_grid: GridContainer   # filled in _build_ui, read in _run_validation
var _btn_demo: TextureButton
var _lbl_status: Label
var _lbl_results: Label


func _ready() -> void:
	_build_ui()
	await get_tree().process_frame
	_run_validation()


# ── UI construction ───────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(900, 520)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var root_margin := MarginContainer.new()
	root_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		root_margin.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(root_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	root_margin.add_child(vbox)

	# ── Title ─────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "Moonseed — Phase 1 Validator  (btn_primary_lg × 5 states)"
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# ── State preview grid (one column per state) ─────────────────
	var grid_lbl := Label.new()
	grid_lbl.text = "State previews  (static thumbnails — each shows its painted state):"
	vbox.add_child(grid_lbl)

	_preview_grid = GridContainer.new()
	_preview_grid.columns = _STATES.size()
	_preview_grid.add_theme_constant_override("h_separation", 8)
	_preview_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_preview_grid)

	for state in _STATES:
		var col := VBoxContainer.new()
		_preview_grid.add_child(col)

		var preview := TextureButton.new()
		preview.custom_minimum_size = Vector2(_DISPLAY_W, _DISPLAY_H)
		preview.ignore_texture_size = true
		preview.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		col.add_child(preview)

		var lbl := Label.new()
		lbl.text = state[3]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lbl)

	vbox.add_child(HSeparator.new())

	# ── Interactive demo button (all 5 slots wired) ───────────────
	var demo_lbl := Label.new()
	demo_lbl.text = "Interactive demo  (hover / click / toggle disabled to test slot wiring):"
	vbox.add_child(demo_lbl)

	var demo_row := HBoxContainer.new()
	demo_row.add_theme_constant_override("separation", 16)
	vbox.add_child(demo_row)

	_btn_demo = TextureButton.new()
	_btn_demo.custom_minimum_size = Vector2(204, 60)
	_btn_demo.ignore_texture_size = true
	_btn_demo.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	demo_row.add_child(_btn_demo)

	# Toggle-disabled helper
	var toggle_lbl := Label.new()
	toggle_lbl.text = "(Click to toggle disabled state on demo →)"
	toggle_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	demo_row.add_child(toggle_lbl)

	_btn_demo.pressed.connect(func() -> void:
		_btn_demo.disabled = not _btn_demo.disabled
	)

	vbox.add_child(HSeparator.new())

	# ── Status summary line ───────────────────────────────────────
	_lbl_status = Label.new()
	_lbl_status.text = "Running…"
	vbox.add_child(_lbl_status)

	vbox.add_child(HSeparator.new())

	# ── Detailed check results ────────────────────────────────────
	var results_title := Label.new()
	results_title.text = "Check details:"
	vbox.add_child(results_title)

	_lbl_results = Label.new()
	_lbl_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_lbl_results)


# ── Image-loading helper (mirrors PlaceholderArtRegistry fallback) ─

func _load_image(res_path: String) -> Image:
	var tex := load(res_path) as Texture2D
	if tex != null:
		return tex.get_image()
	var img := Image.new()
	var abs_path := ProjectSettings.globalize_path(res_path)
	if img.load(abs_path) == OK:
		return img
	return null


# Sample 9 evenly-spread pixels; return true if any differ. ──────

func _images_differ(a: Image, b: Image) -> bool:
	if a == null or b == null:
		return false
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return true
	var pts: Array[Vector2i] = [
		Vector2i(50, 20),  Vector2i(204, 20),  Vector2i(350, 20),
		Vector2i(50, 60),  Vector2i(204, 60),  Vector2i(350, 60),
		Vector2i(50, 100), Vector2i(204, 100), Vector2i(350, 100),
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

	# Pre-load all five images (reused across multiple checks)
	var images: Array = []
	for state in _STATES:
		images.append(_load_image(state[1]))

	# ── Check 1: All 5 files exist on disk ────────────────────────
	var missing: Array[String] = []
	for state in _STATES:
		if not FileAccess.file_exists(state[1]):
			missing.append(state[3])
	if missing.is_empty():
		lines.append("[OK]   (1/10) All 5 state PNGs exist on disk")
		pass_count += 1
	else:
		lines.append("[FAIL] (1/10) %d / 5 PNGs missing: %s" % [missing.size(), ", ".join(missing)])
		lines.append("             Paint the missing states → save to assets/ui/buttons/")
		fail_count += 1

	# ── Check 2: All 5 readable as Image data ─────────────────────
	var unreadable: Array[String] = []
	for i in _STATES.size():
		if images[i] == null:
			unreadable.append(_STATES[i][3])
	if unreadable.is_empty():
		lines.append("[OK]   (2/10) All 5 PNGs readable as Image data")
		pass_count += 1
	else:
		lines.append("[FAIL] (2/10) %d / 5 PNGs failed to load: %s" % [unreadable.size(), ", ".join(unreadable)])
		lines.append("             Rescan FileSystem if newly saved; check for disk errors.")
		fail_count += 1

	# ── Check 3: All 5 correct canvas size (408 × 120) ────────────
	var wrong_size: Array[String] = []
	for i in _STATES.size():
		var img: Image = images[i]
		if img != null:
			if img.get_width() != _EXPECTED_W or img.get_height() != _EXPECTED_H:
				wrong_size.append("%s (%d×%d)" % [_STATES[i][3], img.get_width(), img.get_height()])
	if wrong_size.is_empty() and unreadable.is_empty():
		lines.append("[OK]   (3/10) All 5 canvas sizes: %d × %d px  (correct 2× canvas)" % [_EXPECTED_W, _EXPECTED_H])
		pass_count += 1
	elif not wrong_size.is_empty():
		lines.append("[FAIL] (3/10) Wrong canvas size: %s" % "  |  ".join(wrong_size))
		lines.append("             Expected %d × %d — re-export from Krita at correct size." % [_EXPECTED_W, _EXPECTED_H])
		fail_count += 1

	# ── Check 4: Normal PNG has been painted (center not blank) ───
	var normal_img: Image = images[0]
	if normal_img != null:
		var probe := normal_img.duplicate()
		probe.convert(Image.FORMAT_RGBA8)
		var center_px: Color = probe.get_pixel(_EXPECTED_W / 2, _EXPECTED_H / 2)
		if center_px.a > 0.0:
			lines.append("[OK]   (4/10) Normal center pixel: alpha=%.3f  (painted, not blank)" % center_px.a)
			pass_count += 1
		else:
			lines.append("[FAIL] (4/10) Normal center pixel: alpha=0.0 — still the blank template.")
			lines.append("             Paint btn_primary_lg_normal.png per §12 of BUTTON_STYLE_GUIDE.md.")
			fail_count += 1
	else:
		lines.append("[SKIP] (4/10) Normal PNG did not load — skipping painted-check.")

	# ── Checks 5–8: Each variant differs visually from normal ─────
	var variant_indices := [1, 2, 3, 4]  # hover, pressed, disabled, selected
	var check_num := 5
	for vi in variant_indices:
		var label: String = _STATES[vi][3]
		var variant_img: Image = images[vi]
		if normal_img != null and variant_img != null:
			if _images_differ(normal_img, variant_img):
				lines.append("[OK]   (%d/10) %s differs from normal  (state paint confirmed)" % [check_num, label])
				pass_count += 1
			else:
				lines.append("[FAIL] (%d/10) %s is identical to normal at all sampled pixels." % [check_num, label])
				lines.append("             Apply state deltas per §13 of BUTTON_STYLE_GUIDE.md.")
				fail_count += 1
		else:
			lines.append("[SKIP] (%d/10) %s vs normal skipped — one or both PNGs did not load." % [check_num, label])
		check_num += 1

	# ── Check 9: ArtReg keys resolve ──────────────────────────────
	var art_reg = get_node_or_null("/root/ArtReg")
	if art_reg != null and art_reg.has_method("path_for"):
		var unresolved: Array[String] = []
		for state in _STATES:
			var p: String = art_reg.path_for(state[0])
			if p.is_empty():
				unresolved.append(state[0])
		if unresolved.is_empty():
			lines.append("[OK]   (9/10) All 5 ArtReg keys resolve")
			pass_count += 1
		else:
			lines.append("[FAIL] (9/10) %d ArtReg keys unresolved:" % unresolved.size())
			for k in unresolved:
				lines.append("             • %s" % k)
			lines.append("             Check UI_BUTTONS block in PlaceholderArtRegistry.gd.")
			fail_count += 1
	else:
		lines.append("[INFO] (9/10) ArtReg autoload not detected — normal for a scratch scene.")

	# ── Check 10: TextureButton slots filled ──────────────────────
	var null_slots: Array[String] = []
	for i in _STATES.size():
		var img: Image = images[i]
		var slot_name: String = _STATES[i][2]
		var label: String    = _STATES[i][3]
		if img != null:
			var tex: Texture2D = ImageTexture.create_from_image(img)
			_btn_demo.set(slot_name, tex)
			# Fill static preview thumbnails in the grid
			if _preview_grid != null and i < _preview_grid.get_child_count():
				var col := _preview_grid.get_child(i)
				if col != null and col.get_child_count() > 0:
					var preview_btn := col.get_child(0) as TextureButton
					if preview_btn != null:
						preview_btn.set("texture_normal", tex)
		else:
			null_slots.append(label)

	if null_slots.is_empty():
		lines.append("[OK]   (10/10) TextureButton: all 5 slots assigned  (hover/click to test)")
		pass_count += 1
	else:
		lines.append("[FAIL] (10/10) %d slots could not be filled: %s" % [null_slots.size(), ", ".join(null_slots)])
		lines.append("              Resolve earlier load failures first.")
		fail_count += 1

	# ── Summary ───────────────────────────────────────────────────
	lines.append("")
	var total := pass_count + fail_count
	if fail_count == 0:
		_lbl_status.text = "PHASE 1 PASS  (%d / %d checks)" % [pass_count, total]
		lines.append("All checks passed. btn_primary_lg is production-ready.")
		lines.append("Next: paint btn_primary_md and run BtnPhase2Validator.")
	else:
		_lbl_status.text = "PHASE 1 INCOMPLETE  (%d failures, %d / %d passed)" % [fail_count, pass_count, total]
		lines.append("Resolve [FAIL] items above, then re-run this scene.")

	_lbl_results.text = "\n".join(lines)

	print("\n── BtnPhase1Validator ────────────────────────────")
	for line in lines:
		print("  " + line)
	print("──────────────────────────────────────────────────\n")
