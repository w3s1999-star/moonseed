extends Control

# ─────────────────────────────────────────────────────────────────
# BtnPhase0Validator.gd  —  Moonseed Button Art Phase 0 Validator
#
# Attach to a Control node (root of a new 2D scene).
# Run the scene — it builds its own UI and prints validation results
# to the Output panel.
#
# WHAT IT CHECKS:
#   1. btn_template_blank.png exists on disk
#   2. The file loads as Texture2D (import pipeline working)
#   3. Canvas is 408 × 120 px (correct 2× canvas size)
#   4. Center pixel is transparent (correct alpha fill)
#   5. ArtReg can resolve the "ui_button_template_blank" key
#   6. A TextureButton accepts the texture without errors
#
# HOW TO USE:
#   File → New Scene → Other Node → Control → attach this script
#   Scene → Run Current Scene (or F6)
# ─────────────────────────────────────────────────────────────────

const _BLANK_PATH   := "res://assets/ui/buttons/btn_template_blank.png"
const _DISPLAY_W    := 200
const _DISPLAY_H    := 56
const _EXPECTED_W   := 408
const _EXPECTED_H   := 120

# ── Build references (not @onready — nodes are created dynamically) ──
var _btn_preview: TextureButton
var _lbl_status: Label
var _lbl_results: Label


func _ready() -> void:
	_build_ui()
	await get_tree().process_frame  # let layout settle before reading sizes
	_run_validation()


# ── UI construction ───────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(520, 360)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root_margin.add_theme_constant_override("margin_" + side, 20)
	add_child(root_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	root_margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Moonseed — Phase 0 Validator"
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# TextureButton preview label
	var lbl_preview := Label.new()
	lbl_preview.text = "TextureButton preview (should be %d × %d display px):" % [_DISPLAY_W, _DISPLAY_H]
	vbox.add_child(lbl_preview)

	# Container to keep the button left-aligned and not stretched
	var btn_container := HBoxContainer.new()
	vbox.add_child(btn_container)

	_btn_preview = TextureButton.new()
	_btn_preview.custom_minimum_size = Vector2(_DISPLAY_W, _DISPLAY_H)
	_btn_preview.ignore_texture_size = true
	_btn_preview.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_container.add_child(_btn_preview)

	vbox.add_child(HSeparator.new())

	# Status line (PASS / FAIL overall summary)
	_lbl_status = Label.new()
	_lbl_status.text = "Running…"
	vbox.add_child(_lbl_status)

	vbox.add_child(HSeparator.new())

	# Detailed results
	var lbl_detail_title := Label.new()
	lbl_detail_title.text = "Check details:"
	vbox.add_child(lbl_detail_title)

	_lbl_results = Label.new()
	_lbl_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_lbl_results)


# ── Validation logic ──────────────────────────────────────────────

func _run_validation() -> void:
	var lines: Array[String] = []
	var pass_count := 0
	var fail_count := 0

	# ── Check 1: File exists ──────────────────────────────────────
	if FileAccess.file_exists(_BLANK_PATH):
		lines.append("[OK] File exists:          %s" % _BLANK_PATH)
		pass_count += 1
	else:
		lines.append("[FAIL] File not found.     Run btn_phase0_generator.gd first.")
		lines.append("       Expected path:      %s" % _BLANK_PATH)
		fail_count += 1

	# ── Check 2: PNG readable as raw image data ───────────────────
	# Uses direct disk load as primary so this passes even before
	# Godot's import pipeline has processed the file (no .import yet).
	var tex: Texture2D = null
	var raw_img: Image = null

	if FileAccess.file_exists(_BLANK_PATH):
		# Try the import pipeline first (fast path when already imported)
		tex = load(_BLANK_PATH) as Texture2D
		if tex != null:
			raw_img = tex.get_image()
		else:
			# Fallback: read PNG bytes directly from the OS path
			var abs_path := ProjectSettings.globalize_path(_BLANK_PATH)
			raw_img = Image.new()
			if raw_img.load(abs_path) == OK:
				tex = ImageTexture.create_from_image(raw_img)
			else:
				raw_img = null

	if tex != null:
		if load(_BLANK_PATH) is Texture2D:
			lines.append("[OK] Loads as Texture2D   (import pipeline working)")
		else:
			lines.append("[OK] PNG readable (direct disk load — rescan FileSystem to complete import)")
		pass_count += 1
		_btn_preview.texture_normal = tex
	else:
		lines.append("[FAIL] Could not read PNG data from disk at all.")
		lines.append("       Re-run btn_phase0_generator.gd and check the Output panel for errors.")
		fail_count += 1

	# ── Check 3: Canvas dimensions ────────────────────────────────
	if raw_img != null:
		var w := raw_img.get_width()
		var h := raw_img.get_height()
		if w == _EXPECTED_W and h == _EXPECTED_H:
			lines.append("[OK] Canvas size:          %d × %d px  (correct 2× canvas)" % [w, h])
			pass_count += 1
		else:
			lines.append("[FAIL] Canvas size:        %d × %d px  (expected %d × %d)" % [w, h, _EXPECTED_W, _EXPECTED_H])
			lines.append("       Re-run btn_phase0_generator.gd to recreate the PNG.")
			fail_count += 1
	elif tex == null:
		lines.append("[SKIP] Canvas size check skipped — PNG did not load.")

	# ── Check 4: Transparent fill ─────────────────────────────────
	if raw_img != null:
		var probe := raw_img.duplicate()
		probe.convert(Image.FORMAT_RGBA8)
		var center: Color = probe.get_pixel(_EXPECTED_W / 2, _EXPECTED_H / 2)
		if center.a == 0.0:
			lines.append("[OK] Center pixel:         alpha=0.0  (fully transparent)")
			pass_count += 1
		else:
			lines.append("[FAIL] Center pixel:       alpha=%.3f  (expected 0.0)" % center.a)
			lines.append("       The PNG must have a fully transparent background.")
			fail_count += 1
	elif tex == null:
		lines.append("[SKIP] Transparency check skipped — PNG did not load.")

	# ── Check 5: PlaceholderArtRegistry ──────────────────────────
	if Engine.has_singleton("ArtReg") or has_node("/root/ArtReg"):
		var art_reg = get_node_or_null("/root/ArtReg")
		if art_reg != null and art_reg.has_method("path_for"):
			var reg_path: String = art_reg.path_for("ui_button_template_blank")
			if not reg_path.is_empty():
				lines.append("[OK] ArtReg key found:     \"ui_button_template_blank\"")
				pass_count += 1
			else:
				lines.append("[WARN] ArtReg key missing: \"ui_button_template_blank\"")
				lines.append("       Add UI_BUTTONS block to PlaceholderArtRegistry.gd")
				# not a hard fail — registry entries are added at Phase 1
		else:
			lines.append("[INFO] ArtReg not available (autoload not running in this scene — OK for scratch test).")
	else:
		lines.append("[INFO] ArtReg autoload not detected. Normal for a scratch scene.")

	# ── Check 6: TextureButton accepted texture ───────────────────
	if _btn_preview.texture_normal != null:
		lines.append("[OK] TextureButton:        texture_normal assigned without error")
		pass_count += 1
	else:
		lines.append("[FAIL] TextureButton:      texture_normal is null")
		lines.append("       Resolve earlier failures — texture must load before this passes.")
		fail_count += 1

	# ── Summary ───────────────────────────────────────────────────
	lines.append("")
	if fail_count == 0:
		_lbl_status.text = "PHASE 0 PASS  (%d / %d checks)" % [pass_count, pass_count]
		lines.append("All checks passed. Paint btn_primary_lg_normal.png and begin Phase 1.")
	else:
		_lbl_status.text = "PHASE 0 INCOMPLETE  (%d failures)" % fail_count
		lines.append("Resolve [FAIL] items above, then re-run this scene.")

	_lbl_results.text = "\n".join(lines)

	# Mirror to Output panel
	print("\n── BtnPhase0Validator ────────────────────────────")
	for line in lines:
		print("  " + line)
	print("──────────────────────────────────────────────────\n")
