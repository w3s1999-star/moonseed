extends Control
class_name DiceFaceDevUI

# ─────────────────────────────────────────────────────────────────
# DiceFaceDevUI.gd  –  Dev tool: view all dice faces, click to
#                       replace a face image via OS file browser.
# Opened from Settings → Dev Tools → 🎲 Dice Face Editor
# Close: ESC / ✕ button
# ─────────────────────────────────────────────────────────────────

const FACE_SPECS: Dictionary = {
	6:  {folder="d6",  count=6,  label_offset=0},
	8:  {folder="d8",  count=8,  label_offset=0},
	10: {folder="d10", count=10, label_offset=0},
	12: {folder="d12", count=12, label_offset=0},
	20: {folder="d20", count=20, label_offset=0},
}
const THUMB_SIZE := 56
const THUMB_PAD  := 6
const BG_COL     := Color("#0d0d14")
const PANEL_COL  := Color("#12121c")
const BORDER_COL := Color("#3a3a5a")
const HOVER_COL  := Color("#2a2a4a")
const SEL_COL    := Color("#099EA9")

var _selected_sides: int = 6
var _selected_face:  int = 0   # 0-indexed
var _thumb_rects:    Dictionary = {}  # "sides_face" → Rect2 (global)
var _hover_key:      String = ""
var _status_lbl:     Label
var _preview_tex:    TextureRect
var _scroll:         ScrollContainer

func _ready() -> void:
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Full-screen dark backdrop
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_ui()

func _build_ui() -> void:
	# Full-screen centering wrapper
	var center_wrap := CenterContainer.new()
	center_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_wrap)
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(680, 520)
	var st := StyleBoxFlat.new()
	st.bg_color = BG_COL; st.border_color = BORDER_COL
	st.set_border_width_all(2); st.set_corner_radius_all(8)
	outer.add_theme_stylebox_override("panel", st)
	center_wrap.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	outer.add_child(vbox)

	# ── Title bar ──
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "🎲  DICE FACE EDITOR"
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(15))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"; close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(_close)
	title_row.add_child(close_btn)

	var hint := Label.new()
	hint.text = "Click any face thumbnail to replace its sprite. Custom sprites save to user:// data."
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	hint.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	# ── Die selector tabs ──
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_row)
	for sides in [6, 8, 10, 12, 20]:
		var btn := Button.new()
		btn.text = "d%d" % sides
		btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
		btn.toggle_mode = true
		btn.button_pressed = (sides == _selected_sides)
		var col: Color = GameData.DIE_COLORS.get(sides, GameData.FG_COLOR) as Color
		btn.add_theme_color_override("font_color", col)
		btn.pressed.connect(func(): _select_die(sides))
		tab_row.add_child(btn)
	_tab_row = tab_row

	# ── Main content: face grid + preview ──
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 8)
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_row)

	# Face grid in scroll
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	content_row.add_child(_scroll)

	_grid_container = VBoxContainer.new()
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid_container)

	# Preview + info panel
	var right_vbox := VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(180, 0)
	right_vbox.add_theme_constant_override("separation", 6)
	content_row.add_child(right_vbox)

	var prev_lbl := Label.new(); prev_lbl.text = "PREVIEW"
	prev_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
	prev_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	prev_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(prev_lbl)

	var prev_panel := PanelContainer.new()
	prev_panel.custom_minimum_size = Vector2(128, 128)
	var ps := StyleBoxFlat.new(); ps.bg_color = PANEL_COL
	ps.border_color = BORDER_COL; ps.set_border_width_all(1); ps.set_corner_radius_all(4)
	prev_panel.add_theme_stylebox_override("panel", ps)
	right_vbox.add_child(prev_panel)

	_preview_tex = TextureRect.new()
	_preview_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_panel.add_child(_preview_tex)

	_face_info_lbl = Label.new()
	_face_info_lbl.text = "—"
	_face_info_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	_face_info_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	_face_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(_face_info_lbl)

	var replace_btn := Button.new(); replace_btn.text = "📂 Replace Face"
	replace_btn.pressed.connect(_browse_for_face)
	right_vbox.add_child(replace_btn)
	_replace_btn = replace_btn

	var reset_btn := Button.new(); reset_btn.text = "↩ Reset to Default"
	reset_btn.pressed.connect(_reset_face)
	right_vbox.add_child(reset_btn)

	# Separator
	var sep := HSeparator.new(); right_vbox.add_child(sep)

	# Explorer open button
	var exp_lbl := Label.new(); exp_lbl.text = "ASSET FOLDER"
	exp_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
	exp_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	exp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(exp_lbl)

	var open_folder_btn := Button.new()
	open_folder_btn.text = "📁 Open dice/ in Explorer"
	open_folder_btn.pressed.connect(_open_dice_folder)
	right_vbox.add_child(open_folder_btn)

	var open_user_btn := Button.new()
	open_user_btn.text = "📁 Open Save Folder"
	open_user_btn.pressed.connect(_open_user_folder)
	right_vbox.add_child(open_user_btn)

	var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(sp)

	_status_lbl = Label.new()
	_status_lbl.text = ""
	_status_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	_status_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(_status_lbl)

	_rebuild_grid()

var _tab_row:        HBoxContainer
var _grid_container: VBoxContainer
var _face_info_lbl:  Label
var _replace_btn:    Button

func _select_die(sides: int) -> void:
	_selected_sides = sides
	_selected_face  = 0
	# Update tab button states
	var idx := 0
	for sides_k in [6, 8, 10, 12, 20]:
		var btn := _tab_row.get_child(idx) as Button
		btn.button_pressed = (sides_k == sides)
		idx += 1
	_rebuild_grid()
	_update_preview()

func _rebuild_grid() -> void:
	for c in _grid_container.get_children(): c.queue_free()
	_thumb_rects.clear()

	var spec: Dictionary = FACE_SPECS.get(_selected_sides, {})
	if spec.is_empty(): return
	var count: int   = spec.count
	var folder: String = spec.folder
	var cols := 4

	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", THUMB_PAD)
	grid.add_theme_constant_override("v_separation", THUMB_PAD)
	_grid_container.add_child(grid)

	for face_idx in range(count):
		var face_val := face_idx + 1   # 1-indexed label
		var cell := _make_face_cell(folder, face_idx, face_val)
		grid.add_child(cell)

func _make_face_cell(folder: String, face_idx: int, face_val: int) -> Control:
	var sides: int = _selected_sides
	var key := "%d_%d" % [sides, face_idx]

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(THUMB_SIZE + THUMB_PAD, THUMB_SIZE + THUMB_PAD + 16)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var st_normal := StyleBoxFlat.new()
	st_normal.bg_color = PANEL_COL; st_normal.border_color = BORDER_COL
	st_normal.set_border_width_all(1); st_normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", st_normal)

	var st_hover := StyleBoxFlat.new()
	st_hover.bg_color = HOVER_COL; st_hover.border_color = GameData.ACCENT_BLUE
	st_hover.set_border_width_all(2); st_hover.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", st_hover)

	var st_pressed := StyleBoxFlat.new()
	st_pressed.bg_color = Color("#1a1a30"); st_pressed.border_color = SEL_COL
	st_pressed.set_border_width_all(2); st_pressed.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", st_pressed)

	if face_idx == _selected_face:
		btn.add_theme_stylebox_override("normal", st_pressed)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	btn.add_child(vbox)

	# Texture thumbnail
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(tex_rect)

	# Try to load custom first, then default
	var tex := _load_face_texture(folder, face_idx)
	if tex: tex_rect.texture = tex

	# Face value label
	var lbl := Label.new()
	lbl.text = str(face_val)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	var die_col: Color = GameData.DIE_COLORS.get(sides, GameData.FG_COLOR) as Color
	lbl.add_theme_color_override("font_color", die_col if face_idx != _selected_face else SEL_COL)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)

	btn.pressed.connect(func():
		_selected_face = face_idx
		_rebuild_grid()
		_update_preview()
	)

	return btn

func _load_face_texture(folder: String, face_idx: int) -> Texture2D:
	# Check for user override first
	var user_path := "user://ante_up/dice/%s/face_%d.png" % [folder, face_idx]
	if FileAccess.file_exists(user_path):
		var img := Image.load_from_file(user_path)
		if img: return ImageTexture.create_from_image(img)

	# Default res:// paths (1-indexed filename, 0-indexed lookup)
	var paths_to_try := [
		"res://assets/dice/%s/spr_dice_%s_%d.png" % [folder, folder, face_idx],
		"res://assets/dice/%s/spr_dice_%s_%d.png" % [folder, folder, face_idx + 1],
	]
	for p in paths_to_try:
		if ResourceLoader.exists(p): return load(p) as Texture2D
	return null

func _update_preview() -> void:
	var spec: Dictionary = FACE_SPECS.get(_selected_sides, {})
	var folder: String = spec.get("folder", "d6")
	var tex := _load_face_texture(folder, _selected_face)
	_preview_tex.texture = tex

	var user_path := "user://ante_up/dice/%s/face_%d.png" % [folder, _selected_face]
	var source_str := "custom" if FileAccess.file_exists(user_path) else "default"
	_face_info_lbl.text = "d%d  face %d\n[%s]" % [_selected_sides, _selected_face + 1, source_str]

func _browse_for_face() -> void:
	# Open file manager dialog for image selection
	var dialog := FileDialog.new()
	# Leave dialog mode/access unset for compatibility
	dialog.title      = "Choose PNG for d%d face %d" % [_selected_sides, _selected_face + 1]
	dialog.filters    = PackedStringArray(["*.png ; PNG Images", "*.jpg ; JPEG Images",
										   "*.jpeg ; JPEG Images", "*.webp ; WebP Images"])
	# Start in project assets folder if possible
	var res_path := ProjectSettings.globalize_path("res://assets/dice/")
	if DirAccess.dir_exists_absolute(res_path):
		dialog.current_dir = res_path
	dialog.file_selected.connect(_on_file_selected)
	add_child(dialog)
	dialog.popup_centered_ratio(0.65)

func _on_file_selected(path: String) -> void:
	var img := Image.load_from_file(path)
	if not img:
		_status("❌ Could not load: %s" % path.get_file()); return

	# Save to user:// override folder
	var spec: Dictionary = FACE_SPECS.get(_selected_sides, {})
	var folder: String = spec.get("folder", "d6")
	var out_dir := "user://ante_up/dice/%s" % folder
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var out_path := "%s/face_%d.png" % [out_dir, _selected_face]
	var err := img.save_png(out_path)
	if err != OK:
		_status("❌ Save failed (err %d)" % err); return

	_status("✅ Saved face %d\n%s" % [_selected_face + 1, path.get_file()])
	_rebuild_grid()
	_update_preview()
	# Refresh DiceTableArea sprite cache if accessible
	_notify_dice_table()

func _notify_dice_table() -> void:
	# Try to find DiceTableArea in scene and refresh its cache
	var play_tab: Variant = null
	var root := get_tree().get_root()
	for child in root.get_children():
		if child.has_method("get_node"):
			play_tab = child.find_child("DiceTable", true, false)
			if play_tab: break
	if play_tab and play_tab.has_method("refresh_sprites"):
		play_tab.call("refresh_sprites")

func _reset_face() -> void:
	var spec: Dictionary = FACE_SPECS.get(_selected_sides, {})
	var folder: String = spec.get("folder", "d6")
	var out_path := "user://ante_up/dice/%s/face_%d.png" % [folder, _selected_face]
	if FileAccess.file_exists(out_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(out_path))
		_status("↩ Reset d%d face %d to default" % [_selected_sides, _selected_face + 1])
	else:
		_status("Already using default.")
	_rebuild_grid(); _update_preview()
	_notify_dice_table()

func _open_dice_folder() -> void:
	var path := ProjectSettings.globalize_path("res://assets/dice/")
	var ok := OS.shell_open(path)
	if ok != OK:
		# Fallback: try xdg-open on Linux
		var output: Array = []
		OS.execute("xdg-open", [path], output)
	_status("📁 Opened:\n%s" % path)

func _open_user_folder() -> void:
	var path := OS.get_user_data_dir() + "/ante_up/dice/"
	DirAccess.make_dir_recursive_absolute(path)
	var ok := OS.shell_open(path)
	if ok != OK:
		var output: Array = []
		OS.execute("xdg-open", [path], output)
	_status("📁 Opened:\n%s" % path)

func _status(msg: String) -> void:
	_status_lbl.text = msg

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()

func _close() -> void:
	queue_free()
