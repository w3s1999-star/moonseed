extends Control

# SettingsTab.gd – v0.8.0
# Merged: uploaded v0.65 settings + GDD §5 debug additions
# Debug gate: all dev tools hidden unless debug_mode is on.

var _profile_name_entry: LineEdit
var _tz_option:         OptionButton
var _stats_label:       Label
var _dev_section:       PanelContainer   # hidden unless debug mode
var _debug_check:       CheckBox
var _staged_settings := {}
var _any_changes: bool = false
var _apply_btn: Button
var _cancel_btn: Button
var _escape_popup: AcceptDialog = null
var _escape_timer: Timer = null
var _escape_count_lbl: Label = null
var _escape_seconds_left: int = 0

func _to_bool(v, default: bool=false) -> bool:
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_STRING:
		var s := String(v).strip_edges().to_lower()
		return s == "true" or s == "1" or s == "yes"
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v) != 0
	return default

func _ready() -> void:
	_build_ui()
	_refresh()
	_apply_saved_graphics()
	call_deferred("_setup_feedback")
	set_process_input(true)

func _apply_saved_graphics() -> void:
	# Window mode is always windowed - no mode switching
	var ws_str: String = str(Database.get_setting("window_size", ""))
	if ws_str != "" and "x" in ws_str:
		var parts := ws_str.split("x")
		if parts.size() == 2:
			var sz := Vector2i(int(parts[0]), int(parts[1]))
			if sz.x >= 640 and sz.y >= 480:
				DisplayServer.window_set_size(sz)
	var _aa_vals := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]
	var aa_idx: int = clampi(int(str(Database.get_setting("msaa", 0))), 0, 3)
	var renderer_method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	if renderer_method == "gl_compatibility":
		get_tree().root.msaa_2d = Viewport.MSAA_DISABLED
	else:
		get_tree().root.msaa_2d = _aa_vals[aa_idx]
	get_tree().root.msaa_3d = _aa_vals[aa_idx]
	var _fxaa_on: bool = _to_bool(Database.get_setting("fxaa", false), false)
	get_tree().root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if _fxaa_on else Viewport.SCREEN_SPACE_AA_DISABLED
	match int(str(Database.get_setting("vsync", 1))):
		0: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		2: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
		_: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = int(str(Database.get_setting("fps_limit", 60)))
	get_tree().root.scaling_3d_scale = float(str(Database.get_setting("render_scale_3d", 1.0)))


func _setup_feedback() -> void:
	if has_node("/root/ButtonFeedback"):
		get_node("/root/ButtonFeedback").setup_recursive(self)

func _build_ui() -> void:
	for child in get_children(): child.queue_free()

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title: Label = Label.new(); title.text = "⚙  SETTINGS"
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)


	# ── Profile Section (single-user mode) ─────────────────────────
	var pp: PanelContainer = PanelContainer.new(); _style_section(pp); vbox.add_child(pp)
	var pv: VBoxContainer = VBoxContainer.new(); pp.add_child(pv)
	var pl: Label = Label.new(); pl.text = "👤  PROFILE"
	pl.add_theme_color_override("font_color", GameData.ACCENT_BLUE); pv.add_child(pl)
	var pr: HBoxContainer = HBoxContainer.new(); pv.add_child(pr)
	_profile_name_entry = LineEdit.new()
	_profile_name_entry.placeholder_text = "Your name..."
	_profile_name_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pr.add_child(_profile_name_entry)
	var save_btn: Button = Button.new(); save_btn.text = "Save Name"; save_btn.pressed.connect(_save_profile_name); pr.add_child(save_btn)
	
	# Profile Management Actions
	var profile_actions: HBoxContainer = HBoxContainer.new(); profile_actions.add_theme_constant_override("separation", 8); pv.add_child(profile_actions)
	var reset_btn: Button = Button.new(); reset_btn.text = "🔄 Reset Profile"; reset_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	reset_btn.pressed.connect(_confirm_reset_profile); profile_actions.add_child(reset_btn)
	var export_btn: Button = Button.new(); export_btn.text = "📤 Export Profile"; export_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	export_btn.pressed.connect(_export_profile); profile_actions.add_child(export_btn)
	var import_btn: Button = Button.new(); import_btn.text = "📥 Import Profile"; import_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	import_btn.pressed.connect(_import_profile); profile_actions.add_child(import_btn)

	# ── Timezone Section ──────────────────────────────────────────
	var tp: PanelContainer = PanelContainer.new(); _style_section(tp); vbox.add_child(tp)
	var tv: VBoxContainer = VBoxContainer.new(); tp.add_child(tv)
	var tz_lbl: Label = Label.new(); tz_lbl.text = "🕐  TIMEZONE"
	tz_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE); tv.add_child(tz_lbl)
	var tz_row: HBoxContainer = HBoxContainer.new(); tv.add_child(tz_row)
	_tz_option = OptionButton.new()
	_tz_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for tz_name in GameData.TIMEZONES.keys(): _tz_option.add_item(tz_name)
	tz_row.add_child(_tz_option)
	var stz: Button = Button.new(); stz.text = "Save"; stz.pressed.connect(_save_timezone); tz_row.add_child(stz)

	# ── Stats Section ─────────────────────────────────────────────
	var sp2 := PanelContainer.new(); _style_section(sp2); vbox.add_child(sp2)
	var sv := VBoxContainer.new(); sp2.add_child(sv)
	var sh := Label.new(); sh.text = "📊  ALL-TIME STATS"
	sh.add_theme_color_override("font_color", GameData.ACCENT_BLUE); sv.add_child(sh)
	_stats_label = Label.new()
	_stats_label.add_theme_color_override("font_color", GameData.FG_COLOR); sv.add_child(_stats_label)

	# ── Save Data Location ────────────────────────────────────────
	var save_panel := PanelContainer.new(); _style_section(save_panel); vbox.add_child(save_panel)
	var save_vb := VBoxContainer.new(); save_vb.add_theme_constant_override("separation", 6); save_panel.add_child(save_vb)
	var save_lbl := Label.new(); save_lbl.text = "💾  SAVE DATA LOCATION"
	save_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE); save_vb.add_child(save_lbl)
	var save_desc := Label.new()
	save_desc.text = "Choose where your save files are stored."
	save_desc.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
	save_desc.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	save_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; save_vb.add_child(save_desc)
	var save_row := HBoxContainer.new(); save_vb.add_child(save_row)
	var save_opt := OptionButton.new()
	save_opt.add_item("📂 AppData / User Directory (default)")
	save_opt.add_item("📁 Game Folder (portable)")
	var cur_save_loc: String = str(Database.get_setting("save_location", "appdata"))
	save_opt.selected = 1 if cur_save_loc == "gamedir" else 0
	save_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; save_row.add_child(save_opt)
	var save_apply := Button.new(); save_apply.text = "Apply & Restart"
	save_apply.pressed.connect(func(): _apply_save_location(save_opt.selected)); save_row.add_child(save_apply)
	var cur_path_lbl := Label.new()
	cur_path_lbl.text = "Current: %s" % OS.get_user_data_dir()
	cur_path_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.4))
	cur_path_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); save_vb.add_child(cur_path_lbl)

	# ── Graphics & Audio Section ──────────────────────────────────
	var ga_panel := PanelContainer.new(); _style_section(ga_panel); vbox.add_child(ga_panel)
	var ga_vbox := VBoxContainer.new(); ga_panel.add_child(ga_vbox)
	ga_vbox.add_theme_constant_override("separation", 10)
	var ga_lbl := Label.new(); ga_lbl.text = "🖥  GRAPHICS & AUDIO"
	ga_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE); ga_vbox.add_child(ga_lbl)

	# ── Window Mode ──────────────────────────────────────────────
	var wm_sep := Label.new(); wm_sep.text = "🖥  WINDOW & DISPLAY"
	wm_sep.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
	wm_sep.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	ga_vbox.add_child(wm_sep)

	var wm_row := HBoxContainer.new(); ga_vbox.add_child(wm_row)
	var wm_lbl := Label.new(); wm_lbl.text = "Window Mode"
	wm_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	wm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; wm_row.add_child(wm_lbl)
	var wm_val := Label.new(); wm_val.text = "Windowed"
	wm_val.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	wm_row.add_child(wm_val)

	# Window Size (windowed mode)
	var ws_row := HBoxContainer.new(); ws_row.add_theme_constant_override("separation", 4); ga_vbox.add_child(ws_row)
	var ws_lbl := Label.new(); ws_lbl.text = "Window Size"
	ws_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	ws_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ws_row.add_child(ws_lbl)
	var ws_opt := OptionButton.new()
	var _ws_presets := [
		["1280 × 720",  Vector2i(1280, 720)],
		["1366 × 768",  Vector2i(1366, 768)],
		["1600 × 900",  Vector2i(1600, 900)],
		["1920 × 1080", Vector2i(1920,1080)],
		["2560 × 1440", Vector2i(2560,1440)],
	]
	var saved_ws: String = str(Database.get_setting("window_size", "1280x720"))
	var ws_sel := 0
	for i in range(_ws_presets.size()):
		var preset: Array = _ws_presets[i]
		ws_opt.add_item(preset[0] as String)
		var sz: Vector2i = preset[1] as Vector2i
		if "%dx%d" % [sz.x, sz.y] == saved_ws: ws_sel = i
	ws_opt.selected = ws_sel
	ws_opt.item_selected.connect(func(idx: int):
		if idx < _ws_presets.size():
			var sz: Vector2i = _ws_presets[idx][1] as Vector2i
			_stage_setting("window_size", "%dx%d" % [sz.x, sz.y])
			_show_msg("Staged: Window size %dx%d" % [sz.x, sz.y]))
	ws_row.add_child(ws_opt)

	# Anti-Aliasing (MSAA)
	var aa_row := HBoxContainer.new(); ga_vbox.add_child(aa_row)
	var aa_lbl := Label.new(); aa_lbl.text = "Anti-Aliasing (MSAA)"
	aa_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	aa_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; aa_row.add_child(aa_lbl)
	var aa_opt := OptionButton.new()
	aa_opt.add_item("Off"); aa_opt.add_item("2×"); aa_opt.add_item("4×"); aa_opt.add_item("8×")
	var _aa_vals := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]
	var cur_aa: int = int(str(Database.get_setting("msaa", 0)))
	aa_opt.selected = clampi(cur_aa, 0, 3)
	aa_opt.item_selected.connect(func(idx: int):
		_stage_setting("msaa", idx))
	aa_row.add_child(aa_opt)

	# V-Sync
	var vsync_row := HBoxContainer.new(); ga_vbox.add_child(vsync_row)
	var vsync_lbl := Label.new(); vsync_lbl.text = "V-Sync"
	vsync_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	vsync_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; vsync_row.add_child(vsync_lbl)
	var vsync_opt := OptionButton.new()
	vsync_opt.add_item("Disabled"); vsync_opt.add_item("Enabled"); vsync_opt.add_item("Adaptive")
	var cur_vsync: int = int(str(Database.get_setting("vsync", 1)))
	vsync_opt.selected = clampi(cur_vsync, 0, 2)
	vsync_opt.item_selected.connect(func(idx: int):
		_stage_setting("vsync", idx))
	vsync_row.add_child(vsync_opt)

	# FPS Limit
	var fps_row := HBoxContainer.new(); ga_vbox.add_child(fps_row)
	var fps_lbl := Label.new(); fps_lbl.text = "FPS Limit"
	fps_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	fps_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; fps_row.add_child(fps_lbl)
	var fps_val_lbl := Label.new()
	var cur_fps: int = int(str(Database.get_setting("fps_limit", 60)))
	fps_val_lbl.text = "Unlimited" if cur_fps == 0 else "%d fps" % cur_fps
	fps_val_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	fps_val_lbl.custom_minimum_size = Vector2(74, 0)
	fps_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var fps_opt := OptionButton.new()
	fps_opt.add_item("Unlimited"); fps_opt.add_item("30 fps")
	fps_opt.add_item("60 fps");   fps_opt.add_item("120 fps"); fps_opt.add_item("144 fps")
	var fps_presets := [0, 30, 60, 120, 144]
	var fps_sel := 0
	for i in range(fps_presets.size()):
		if fps_presets[i] == cur_fps: fps_sel = i; break
	fps_opt.selected = fps_sel
	fps_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps_opt.item_selected.connect(func(idx: int):
		var lim: int = fps_presets[idx] if idx < fps_presets.size() else 0
		_stage_setting("fps_limit", lim)
		fps_val_lbl.text = "Unlimited" if lim == 0 else "%d fps" % lim)
	fps_row.add_child(fps_opt); fps_row.add_child(fps_val_lbl)

	# ── Rendering ────────────────────────────────────────────────
	var rnd_sep := Label.new(); rnd_sep.text = "🔬  RENDERING"
	rnd_sep.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
	rnd_sep.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	ga_vbox.add_child(rnd_sep)

	# Render Scale (3D sub-viewport)
	var rscale_row := HBoxContainer.new(); ga_vbox.add_child(rscale_row)
	var rscale_lbl := Label.new(); rscale_lbl.text = "3D Render Scale"
	rscale_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	rscale_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rscale_row.add_child(rscale_lbl)
	var rscale_val := Label.new()
	var cur_rscale: float = float(str(Database.get_setting("render_scale_3d", 1.0)))
	rscale_val.text = "%d%%" % int(cur_rscale * 100)
	rscale_val.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	rscale_val.custom_minimum_size = Vector2(40, 0)
	rscale_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var rscale_slider := HSlider.new()
	rscale_slider.min_value = 50; rscale_slider.max_value = 200; rscale_slider.step = 25
	rscale_slider.value = int(cur_rscale * 100)
	rscale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscale_slider.value_changed.connect(func(v: float):
		rscale_val.text = "%d%%" % int(v)
		var factor := v / 100.0
		_stage_setting("render_scale_3d", factor))
	rscale_row.add_child(rscale_slider); rscale_row.add_child(rscale_val)

	# FXAA (screen-space fast AA — cheap, no sample cost)
	var fxaa_row := HBoxContainer.new(); ga_vbox.add_child(fxaa_row)
	var fxaa_lbl := Label.new(); fxaa_lbl.text = "FXAA (Fast AA)"
	fxaa_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	fxaa_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; fxaa_row.add_child(fxaa_lbl)
	var fxaa_check := CheckButton.new()
	fxaa_check.button_pressed = _to_bool(Database.get_setting("fxaa", false), false)
	fxaa_check.toggled.connect(func(on: bool): _stage_setting("fxaa", on))
	fxaa_row.add_child(fxaa_check)

	# UI Scale
	var scale_row := HBoxContainer.new(); ga_vbox.add_child(scale_row)
	var scale_lbl := Label.new(); scale_lbl.text = "UI Scale"
	scale_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	scale_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scale_row.add_child(scale_lbl)
	var scale_val_lbl := Label.new()
	var cur_scale := float(str(Database.get_setting("ui_scale", 1.0)))
	scale_val_lbl.text = "%d%%" % int(cur_scale * 100)
	scale_val_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	scale_val_lbl.custom_minimum_size = Vector2(40, 0)
	scale_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var scale_slider := HSlider.new()
	scale_slider.min_value = 50; scale_slider.max_value = 200; scale_slider.step = 25
	scale_slider.value = int(cur_scale * 100)
	scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_slider.value_changed.connect(func(v: float):
		scale_val_lbl.text = "%d%%" % int(v)
		var factor := v / 100.0
		_stage_setting("ui_scale", factor))
	scale_row.add_child(scale_slider); scale_row.add_child(scale_val_lbl)

	# Text Size
	var ts_row := HBoxContainer.new(); ga_vbox.add_child(ts_row)
	var ts_lbl := Label.new(); ts_lbl.text = "Text Size"
	ts_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	ts_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ts_row.add_child(ts_lbl)
	var ts_opt := OptionButton.new()
	ts_opt.add_item("Small"); ts_opt.add_item("Normal"); ts_opt.add_item("Large"); ts_opt.add_item("X-Large")
	var ts_map := {-3: 0, 0: 1, 3: 2, 6: 3}
	var cur_delta: int = int(str(Database.get_setting("text_size_delta", 0)))
	ts_opt.selected = ts_map.get(cur_delta, 1)
	ts_opt.item_selected.connect(func(idx: int):
		var delta_vals := [-3, 0, 3, 6]
		var delta: int = delta_vals[idx] if idx < delta_vals.size() else 0
		_stage_setting("text_size_delta", delta))
	ts_row.add_child(ts_opt)

	# Audio subsection
	var audio_sep := Label.new(); audio_sep.text = "🔊  AUDIO"
	audio_sep.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
	audio_sep.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	ga_vbox.add_child(audio_sep)

	# Master Volume
	var mv_row := HBoxContainer.new(); ga_vbox.add_child(mv_row)
	var mv_lbl := Label.new(); mv_lbl.text = "Master Volume"
	mv_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	mv_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mv_row.add_child(mv_lbl)
	var mv_pct_lbl := Label.new()
	var cur_mvol := float(str(Database.get_setting("volume_master", 1.0)))
	mv_pct_lbl.text = "%d%%" % int(cur_mvol * 100)
	mv_pct_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	mv_pct_lbl.custom_minimum_size = Vector2(40, 0)
	mv_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var mv_slider := HSlider.new()
	mv_slider.min_value = 0; mv_slider.max_value = 100; mv_slider.step = 1
	mv_slider.value = int(cur_mvol * 100)
	mv_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv_slider.value_changed.connect(func(v: float):
		mv_pct_lbl.text = "%d%%" % int(v)
		var vol := v / 100.0
		_stage_setting("volume_master", vol))
	mv_row.add_child(mv_slider); mv_row.add_child(mv_pct_lbl)

	# Music Volume
	var mus_row := HBoxContainer.new(); ga_vbox.add_child(mus_row)
	var mus_lbl := Label.new(); mus_lbl.text = "Music Volume"
	mus_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	mus_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mus_row.add_child(mus_lbl)
	var mus_pct_lbl := Label.new()
	var cur_mus := float(str(Database.get_setting("volume_music", 0.8)))
	mus_pct_lbl.text = "%d%%" % int(cur_mus * 100)
	mus_pct_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	mus_pct_lbl.custom_minimum_size = Vector2(40, 0)
	mus_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var mus_slider := HSlider.new()
	mus_slider.min_value = 0; mus_slider.max_value = 100; mus_slider.step = 1
	mus_slider.value = int(cur_mus * 100)
	mus_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mus_slider.value_changed.connect(func(v: float):
		mus_pct_lbl.text = "%d%%" % int(v)
		var vol := v / 100.0
		_stage_setting("volume_music", vol))
	mus_row.add_child(mus_slider); mus_row.add_child(mus_pct_lbl)

	# UI Sounds Volume
	var ui_row := HBoxContainer.new(); ga_vbox.add_child(ui_row)
	var ui_lbl := Label.new(); ui_lbl.text = "UI Sounds Volume"
	ui_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	ui_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ui_row.add_child(ui_lbl)
	var ui_pct_lbl := Label.new()
	var cur_ui := float(str(Database.get_setting("volume_ui", 1.0)))
	ui_pct_lbl.text = "%d%%" % int(cur_ui * 100)
	ui_pct_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	ui_pct_lbl.custom_minimum_size = Vector2(40, 0)
	ui_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var ui_slider := HSlider.new()
	ui_slider.min_value = 0; ui_slider.max_value = 100; ui_slider.step = 1
	ui_slider.value = int(cur_ui * 100)
	ui_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_slider.value_changed.connect(func(v: float):
		ui_pct_lbl.text = "%d%%" % int(v)
		var vol := v / 100.0
		_stage_setting("volume_ui", vol))
	ui_row.add_child(ui_slider); ui_row.add_child(ui_pct_lbl)

	# Mute All
	var mute_row := HBoxContainer.new(); ga_vbox.add_child(mute_row)
	var mute_lbl := Label.new(); mute_lbl.text = "Mute All"
	mute_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	mute_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mute_row.add_child(mute_lbl)
	var mute_check := CheckButton.new()
	mute_check.button_pressed = _to_bool(Database.get_setting("mute_all", false), false)
	mute_check.toggled.connect(func(on: bool): _stage_setting("mute_all", on))
	mute_row.add_child(mute_check)

	# SFX Volume
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx < 0:
		AudioServer.add_bus(); sfx_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_idx, "SFX"); AudioServer.set_bus_send(sfx_idx, "Master")
	var sfx_row := HBoxContainer.new(); ga_vbox.add_child(sfx_row)
	var sfx_lbl := Label.new(); sfx_lbl.text = "SFX Volume"
	sfx_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	sfx_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sfx_row.add_child(sfx_lbl)
	var sfx_pct_lbl := Label.new()
	var cur_sfx := float(str(Database.get_setting("volume_sfx", 1.0)))
	sfx_pct_lbl.text = "%d%%" % int(cur_sfx * 100)
	sfx_pct_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	sfx_pct_lbl.custom_minimum_size = Vector2(40, 0)
	sfx_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0; sfx_slider.max_value = 100; sfx_slider.step = 1
	sfx_slider.value = int(cur_sfx * 100)
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _sfx_bus_idx := sfx_idx
	sfx_slider.value_changed.connect(func(v: float):
		sfx_pct_lbl.text = "%d%%" % int(v)
		var vol := v / 100.0
		_stage_setting("volume_sfx", vol))
	sfx_row.add_child(sfx_slider); sfx_row.add_child(sfx_pct_lbl)

	# ── Controls & Input Section ────────────────────────────────
	var ctrl_panel := PanelContainer.new(); _style_section(ctrl_panel); vbox.add_child(ctrl_panel)
	var ctrl_vbox := VBoxContainer.new(); ctrl_panel.add_child(ctrl_vbox)
	ctrl_vbox.add_theme_constant_override("separation", 10)
	var ctrl_lbl := Label.new(); ctrl_lbl.text = "🎮  CONTROLS & INPUT"
	ctrl_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE); ctrl_vbox.add_child(ctrl_lbl)

	# Scroll Speed
	var scroll_row := HBoxContainer.new(); ctrl_vbox.add_child(scroll_row)
	var scroll_lbl := Label.new(); scroll_lbl.text = "Scroll Speed"
	scroll_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	scroll_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll_row.add_child(scroll_lbl)
	var scroll_val_lbl := Label.new()
	var cur_scroll := float(str(Database.get_setting("scroll_speed", 1.0)))
	scroll_val_lbl.text = "%.1fx" % cur_scroll
	scroll_val_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	scroll_val_lbl.custom_minimum_size = Vector2(40, 0)
	scroll_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var scroll_slider := HSlider.new()
	scroll_slider.min_value = 0.5; scroll_slider.max_value = 2.0; scroll_slider.step = 0.1
	scroll_slider.value = cur_scroll
	scroll_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_slider.value_changed.connect(func(v: float):
		scroll_val_lbl.text = "%.1fx" % v
		_stage_setting("scroll_speed", v))
	scroll_row.add_child(scroll_slider); scroll_row.add_child(scroll_val_lbl)

	# Keybindings placeholder
	var keybindings_sep := Label.new(); keybindings_sep.text = "Keybinding Remapping"
	keybindings_sep.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
	keybindings_sep.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	ctrl_vbox.add_child(keybindings_sep)
	
	var keybindings_info := Label.new()
	keybindings_info.text = "Keybinding customization coming in a future update."
	keybindings_info.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.4))
	keybindings_info.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	ctrl_vbox.add_child(keybindings_info)

	# ── Notifications Section ──────────────────────────────────
	var notif_panel := PanelContainer.new(); _style_section(notif_panel); vbox.add_child(notif_panel)
	var notif_vbox := VBoxContainer.new(); notif_panel.add_child(notif_vbox)
	notif_vbox.add_theme_constant_override("separation", 8)
	var notif_lbl := Label.new(); notif_lbl.text = "🔔  NOTIFICATIONS & FEEDBACK"
	notif_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE); notif_vbox.add_child(notif_lbl)

	# Enable Notifications
	var en_row := HBoxContainer.new(); notif_vbox.add_child(en_row)
	var en_lbl := Label.new(); en_lbl.text = "Enable Notifications"
	en_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	en_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; en_row.add_child(en_lbl)
	var en_check := CheckButton.new()
	en_check.button_pressed = _to_bool(Database.get_setting("notifications_enabled", true), true)
	en_check.toggled.connect(func(on: bool): _stage_setting("notifications_enabled", on))
	en_row.add_child(en_check)

	# Pomodoro Alerts
	var pom_row := HBoxContainer.new(); notif_vbox.add_child(pom_row)
	var pom_lbl := Label.new(); pom_lbl.text = "Pomodoro Alerts"
	pom_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	pom_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pom_row.add_child(pom_lbl)
	var pom_check := CheckButton.new()
	pom_check.button_pressed = _to_bool(Database.get_setting("pomodoro_alerts", true), true)
	pom_check.toggled.connect(func(on: bool): _stage_setting("pomodoro_alerts", on))
	pom_row.add_child(pom_check)

	# Pomodoro Auto-Minimize
	var pom_am_row := HBoxContainer.new(); notif_vbox.add_child(pom_am_row)
	var pom_am_lbl := Label.new(); pom_am_lbl.text = "Pomodoro Auto-Minimize"
	pom_am_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	pom_am_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pom_am_row.add_child(pom_am_lbl)
	var pom_am_check := CheckButton.new()
	pom_am_check.button_pressed = _to_bool(Database.get_setting("pomodoro_auto_minimize", true), true)
	pom_am_check.toggled.connect(func(on: bool): _stage_setting("pomodoro_auto_minimize", on))
	pom_am_row.add_child(pom_am_check)

	# Sound Notifications
	var snd_row := HBoxContainer.new(); notif_vbox.add_child(snd_row)
	var snd_lbl := Label.new(); snd_lbl.text = "Sound Notifications"
	snd_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	snd_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; snd_row.add_child(snd_lbl)
	var snd_check := CheckButton.new()
	snd_check.button_pressed = _to_bool(Database.get_setting("notification_sound", true), true)
	snd_check.toggled.connect(func(on: bool): _stage_setting("notification_sound", on))
	snd_row.add_child(snd_check)

	# ── Debug Mode Toggle (always visible) ────────────────────────
	var dbg_row_panel := PanelContainer.new(); _style_section(dbg_row_panel); vbox.add_child(dbg_row_panel)
	var dbg_hbox := HBoxContainer.new(); dbg_row_panel.add_child(dbg_hbox)
	_debug_check = CheckBox.new()
	_debug_check.text = "🔧  Debug Mode"
	_debug_check.button_pressed = _to_bool(Database.get_setting("debug_mode", false), false)
	_debug_check.add_theme_color_override("font_color", GameData.ACCENT_RED)
	_debug_check.toggled.connect(_on_debug_toggled)
	dbg_hbox.add_child(_debug_check)

	# ── Dev Tools Section (debug-gated) ───────────────────────────
	_dev_section = PanelContainer.new()
	var dev_st := StyleBoxFlat.new()
	dev_st.bg_color = GameData.BG_COLOR; dev_st.border_color = GameData.ACCENT_RED
	dev_st.set_border_width_all(1); dev_st.set_corner_radius_all(4)
	_dev_section.add_theme_stylebox_override("panel", dev_st)
	vbox.add_child(_dev_section)

	var dv := VBoxContainer.new(); _dev_section.add_child(dv)
	var dl := Label.new(); dl.text = "🧪  DEV TOOLS"
	dl.add_theme_color_override("font_color", GameData.ACCENT_RED); dv.add_child(dl)

	# Data tools
	_dev_btn_row(dv, [["➕ 5 Tasks", _dev_add_tasks], ["➕ 5 Relics", _dev_add_relics], ["📅 365 Days", _populate_365]])
	_dev_btn_row(dv, [["🎲 All Dice×5", _give_all_dice], ["🌿 All Plants", _unlock_all_plants], ["✨ 50k Moonpearls", _max_moonpearls]])
	_dev_btn_row(dv, [["🗑 Clear Tasks", _clear_tasks], ["🗑 Clear Relics", _clear_relics], ["💣 NUKE ALL", _confirm_nuke]])
	_dev_btn_row(dv, [[" Sample Contracts", _dev_add_contracts], ["🎲 Texture Manager", _open_scene_texture_manager]])
	_dev_btn_row(dv, [["✨ Reset Moonpearls", _reset_moonpearls]])

	# Profile management tools
	var profile_sep := Label.new(); profile_sep.text = "👤  PROFILE MANAGEMENT"
	profile_sep.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	profile_sep.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); dv.add_child(profile_sep)
	_dev_btn_row(dv, [["🔄 Reset Profile", _confirm_reset_profile], ["🗑 Delete Profile", _delete_profile]])

	# GDD §5: Settings debug extras
	var sep2 := Label.new(); sep2.text = "🎬  VFX & PERFORMANCE"
	sep2.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	sep2.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); dv.add_child(sep2)
	_dev_btn_row(dv, [["🎉 Test All Animations", _test_all_animations]])

	var show_btn := Button.new(); show_btn.text = "📁 Show Save Folder"
	show_btn.pressed.connect(_show_save_path); dv.add_child(show_btn)

	# Moon phase popup toggle
	var moon_sep := Label.new(); moon_sep.text = "🌕  MOON PHASE POPUP"
	moon_sep.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	moon_sep.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); dv.add_child(moon_sep)
	var moon_row := HBoxContainer.new(); dv.add_child(moon_row)
	var moon_lbl := Label.new(); moon_lbl.text = "Show on boot"
	moon_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	moon_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; moon_row.add_child(moon_lbl)
	var moon_check := CheckButton.new()
	moon_check.button_pressed = _to_bool(Database.get_setting("moon_phase_popup_enabled", true), true)
	moon_check.toggled.connect(func(on: bool): _stage_setting("moon_phase_popup_enabled", on))
	moon_row.add_child(moon_check)

	# Data integrity check
	var integrity_sep := Label.new(); integrity_sep.text = "🔧  DATA INTEGRITY"
	integrity_sep.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	integrity_sep.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); dv.add_child(integrity_sep)
	_dev_btn_row(dv, [["🔍 Check Integrity", _check_data_integrity], ["🔧 Fix Issues", _fix_data_integrity]])

	_update_dev_visibility()

	# Apply / Cancel controls (staged changes)
	var ctrl_row := HBoxContainer.new(); ctrl_row.add_theme_constant_override("separation", 8)
	ctrl_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL; vbox.add_child(ctrl_row)
	_apply_btn = Button.new(); _apply_btn.text = "Apply"; _apply_btn.disabled = true
	_apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_btn.pressed.connect(_apply_changes); ctrl_row.add_child(_apply_btn)
	_cancel_btn = Button.new(); _cancel_btn.text = "Cancel"; _cancel_btn.disabled = true
	_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_btn.pressed.connect(_cancel_changes); ctrl_row.add_child(_cancel_btn)

func _on_debug_toggled(on: bool) -> void:
	_stage_setting("debug_mode", on)
	_update_dev_visibility()
	GameData.debug_mode_changed.emit(on)

func _apply_save_location(idx: int) -> void:
	var loc: String = "gamedir" if idx == 1 else "appdata"
	var dialog := ConfirmationDialog.new()
	dialog.title = "Change Save Location"
	dialog.dialog_text = "Save location will change. Game will restart. Continue?"
	dialog.confirmed.connect(func():
		Database.save_setting("save_location", loc)
		dialog.queue_free()
		get_tree().reload_current_scene())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog); dialog.popup_centered()

func _update_dev_visibility() -> void:
	if not is_instance_valid(_dev_section): return
	var is_debug: bool = _to_bool(Database.get_setting("debug_mode", false), false)
	_dev_section.visible = is_debug

func _dev_btn(parent: HBoxContainer, text: String, cb: Callable) -> void:
	var btn := Button.new(); btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	btn.pressed.connect(cb); parent.add_child(btn)

func _dev_btn_row(parent: VBoxContainer, entries: Array) -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 2); parent.add_child(row)
	for e: Array in entries: _dev_btn(row, e[0], e[1])

func _refresh() -> void:
	_refresh_profiles(); _refresh_tz(); _refresh_stats()
	if _debug_check:
		_debug_check.button_pressed = _to_bool(Database.get_setting("debug_mode", false), false)
		_update_dev_visibility()

func _refresh_profiles() -> void:
	if not is_instance_valid(_profile_name_entry): return
	var cur_name := str(Database.get_setting("profile", GameData.current_profile))
	_profile_name_entry.text = cur_name

func _refresh_tz() -> void:
	if not is_instance_valid(_tz_option): return
	var saved_tz: String = str(Database.get_setting("timezone", GameData.DEFAULT_TZ))
	var idx: int = GameData.TIMEZONES.keys().find(saved_tz)
	if idx >= 0: _tz_option.select(idx)

func _refresh_stats() -> void:
	if not is_instance_valid(_stats_label): return
	var records := Database.get_all_dice_box_stats(GameData.current_profile)
	var total_score := 0; var best_day := 0
	for rec in records:
		var s: int = rec.get("total_score", 0)
		total_score += s; best_day = max(best_day, s)
	var streak := _calculate_streak()
	_stats_label.text = (
		"Profile: %s\nActive Days: %d\nTotal Score: %d\nBest Day: %d\nCurrent Streak: %d days\n"
		+ "Tasks: %d  |  Curio Canisters: %d"
	) % [GameData.current_profile, records.size(), total_score, best_day, streak,
		 GameData.tasks.size(), GameData.curio_canisters.size()]

func _calculate_streak() -> int:
	var dates := []
	for rec in Database.get_all_dice_box_stats(GameData.current_profile):
		dates.append(rec.get("date",""))
	dates.sort(); dates.reverse()
	var streak := 0; var check: String = GameData.get_date_string()
	for date in dates:
		if date == check:
			streak += 1
			var d := _parse_date(check)
			var prev := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict(d) - 86400)
			check = "%04d-%02d-%02d" % [prev.year, prev.month, prev.day]
		elif date < check: break
	return streak

func _parse_date(s: String) -> Dictionary:
	var p := s.split("-")
	return {year=int(p[0]),month=int(p[1]),day=int(p[2]),hour=0,minute=0,second=0}

# ── Profile Actions ────────────────────────────────────────────────
func _switch_profile() -> void:
	_show_msg("Profile switching disabled. Rename using the Profile Name field.")

func _load_profile_name(profile_name: String) -> void:
	GameData.current_profile = profile_name
	Database.save_setting("profile", profile_name)
	GameData.dice_results.clear()
	var new_tasks := []
	for t in Database.get_tasks(profile_name):
		new_tasks.append({id=t.id, task=t.task, difficulty=t.difficulty,
			die_sides=t.get("die_sides",6), completed=false})
	GameData.tasks = new_tasks
	var new_curio_canisters := []
	for r in Database.get_curio_canisters(profile_name):
		new_curio_canisters.append({id=r.id, title=r.title, mult=r.get("mult",0.2),
			emoji=r.get("emoji","✦"), active=false})
	GameData.curio_canisters = new_curio_canisters
	_refresh_stats(); GameData.state_changed.emit()

func _create_profile() -> void:
	# Legacy hook — in single-profile mode treat creation as saving the typed name
	_save_profile_name()

func _save_profile_name() -> void:
	if not is_instance_valid(_profile_name_entry): return
	var profile_name: String = _profile_name_entry.text.strip_edges()
	if profile_name.is_empty():
		_show_msg("Please enter a non-empty name.")
		return
	Database.add_profile(profile_name)
	GameData.current_profile = profile_name
	Database.save_setting("profile", profile_name)
	_reload_gd()
	_refresh_stats()
	_show_msg("Saved profile name: %s" % profile_name)

func _confirm_reset_profile() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "🔄 Reset Profile"
	dialog.dialog_text = "Reset '%s' to a fresh state? All tasks, relics, dice, and progress will be cleared!" % GameData.current_profile
	dialog.confirmed.connect(_reset_profile_data)
	add_child(dialog); dialog.popup_centered()

func _reset_profile_data() -> void:
	# Clear all profile-specific data
	# 1. Clear tasks
	var tasks_before := Database.get_tasks(GameData.current_profile).size()
	for t in Database.get_tasks(GameData.current_profile):
		Database.delete_task(t.id)
	
	# 2. Clear curio canisters
	var curio_canisters_before := Database.get_curio_canisters(GameData.current_profile).size()
	for r in Database.get_curio_canisters(GameData.current_profile):
		Database.delete_curio_canister(r.id)
	
	# 3. Clear daily stats
	var stats_before := Database.get_all_dice_box_stats(GameData.current_profile).size()
	var all_dates := Database.get_all_dice_box_stats(GameData.current_profile)
	for stat in all_dates:
		Database.delete_dice_box_stat(stat.get("date",""), GameData.current_profile)
	
	# 4. Clear contracts
	var contracts_before := Database.get_contracts(GameData.current_profile, false).size()
	for c in Database.get_contracts(GameData.current_profile, false):
		Database.delete_contract(c.id)
	
	# 5. Reset inventory
	Database._inventory = {}
	Database._save_inventory()
	
	# 6. Reset economy
	Database._economy[GameData.current_profile] = {"moonpearls":0,"moonpearls_pressed":0,"water_meter":0.0,"meals_today":0,"last_meal_date":"","machine_running":false}
	Database._save_economy()
	
	# 7. Reset dice results and other runtime data
	GameData.dice_results.clear()
	GameData.dice_roll_sides.clear()
	GameData.dice_peak_results.clear()
	GameData.jokers_owned.clear()
	GameData.task_die_overrides.clear()

	# 8. Reset all settings to defaults
	Database.reset_settings_to_defaults()
	_apply_saved_graphics()
	GameData.apply_ui_scale()

	# 9. Reload game data
	# Ensure the minimal default tasks exist for this profile (one Drink Water, one Eat Food)
	Database.ensure_default_tasks_for_profile(GameData.current_profile)
	_reload_gd()

	# 9b. Ensure only one default Eat Food / Drink Water exists for this profile
	Database.dedupe_default_tasks_for_profile(GameData.current_profile)
	
	# 9. Validate the reset
	var tasks_after := Database.get_tasks(GameData.current_profile).size()
	var drink_water_count := 0
	var eat_food_count := 0
	for t in Database.get_tasks(GameData.current_profile):
		if str(t.get("task", "")).strip_edges() == "Drink Water":
			drink_water_count += 1
		elif str(t.get("task", "")).strip_edges() == "Eat Food":
			eat_food_count += 1
	
	# 10. Show success message with validation results
	var validation_msg := ""
	if drink_water_count == 1 and eat_food_count == 1:
		validation_msg = "✅ Profile reset successful! Found exactly 1 'Drink Water' and 1 'Eat Food' task."
	else:
		validation_msg = "⚠️ Profile reset completed, but validation found %d 'Drink Water' and %d 'Eat Food' tasks. This may indicate data corruption." % [drink_water_count, eat_food_count]
	
	_show_msg("🔄 Profile '%s' has been reset to a fresh state!\n\n" % GameData.current_profile + 
			  "Before: %d tasks, %d curio canisters, %d stats, %d contracts\n" % [tasks_before, curio_canisters_before, stats_before, contracts_before] +
			  "After: %d tasks\n" % tasks_after +
			  validation_msg)

func _delete_profile() -> void:
	if GameData.current_profile == "Default":
		_show_msg("Cannot delete the Default profile."); return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Profile"
	dialog.dialog_text = "Delete '%s'? All data will be lost!" % GameData.current_profile
	dialog.confirmed.connect(func():
		Database.delete_profile(GameData.current_profile)
		GameData.current_profile = "Default"
		Database.save_setting("profile","Default")
		GameData.state_changed.emit(); _refresh())
	add_child(dialog); dialog.popup_centered()

func _save_timezone() -> void:
	var tz_keys: Array = GameData.TIMEZONES.keys()
	var idx := _tz_option.selected
	if idx >= 0 and idx < tz_keys.size():
		_stage_setting("timezone", tz_keys[idx])
		_show_msg("Staged timezone: %s" % tz_keys[idx])

# ── GDD §5 Debug: Test All Animations ────────────────────────────
func _test_all_animations() -> void:
	if not GameData.is_debug_mode(): return
	# Fire confetti via PlayTab if accessible
	var root := get_tree().get_root()
	for child in root.get_children():
		if child.has_method("_burst_confetti"):
			child.call("_burst_confetti", 2.0)
	_show_msg("🎉 Fired all VFX! Check FPS for perf impact.")

# ── Dev Actions ───────────────────────────────────────────────────
var _sim_progress_popup: AcceptDialog = null
var _sim_progress_bar:   ProgressBar  = null
var _sim_progress_lbl:   Label        = null

func _populate_365() -> void:
	_sim_progress_popup = AcceptDialog.new()
	_sim_progress_popup.title = "📅 Simulating 365 Days"
	_sim_progress_popup.get_ok_button().text = "Running..."
	_sim_progress_popup.get_ok_button().disabled = true
	var pvb := VBoxContainer.new()
	_sim_progress_popup.add_child(pvb)
	_sim_progress_lbl = Label.new()
	_sim_progress_lbl.text = "Simulating dice rolls for all tasks..."
	_sim_progress_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	pvb.add_child(_sim_progress_lbl)
	_sim_progress_bar = ProgressBar.new()
	_sim_progress_bar.min_value = 0; _sim_progress_bar.max_value = 365
	_sim_progress_bar.custom_minimum_size = Vector2(300, 20)
	pvb.add_child(_sim_progress_bar)
	add_child(_sim_progress_popup)
	_sim_progress_popup.popup_centered(Vector2i(360, 120))
	call_deferred("_run_365_simulation")

func _run_365_simulation() -> void:
	var today := Time.get_date_dict_from_system()
	var tasks_list := Database.get_tasks(GameData.current_profile)
	for i in range(1, 366):
		var unix := Time.get_unix_time_from_datetime_dict(
			{year=today.year,month=today.month,day=today.day,hour=0,minute=0,second=0}) - i*86400
		var d := Time.get_datetime_dict_from_unix_time(unix)
		var ds := "%04d-%02d-%02d" % [d.year, d.month, d.day]
		if Database.get_dice_box_stat(ds, GameData.current_profile) != null:
			if is_instance_valid(_sim_progress_bar): _sim_progress_bar.value = i
			if is_instance_valid(_sim_progress_lbl): _sim_progress_lbl.text = "Day %d/365 — skipped (exists)" % i
			if i % 15 == 0: await get_tree().process_frame
			continue
		var rolls_parts: Array = []
		var base_chips: int = 0
		for task in tasks_list:
			var sides: int = task.get("die_sides", 6)
			var count: int = max(1, int(task.get("difficulty", 1)))
			var total_roll: int = 0
			for _j in range(count): total_roll += randi_range(1, sides)
			rolls_parts.append("%d:%d" % [task.id, total_roll])
			base_chips += total_roll
		var mult := randf_range(1.0, 2.5)
		var score := int(base_chips * mult)
		Database.save_dice_box_stat(ds, GameData.current_profile, "|".join(rolls_parts), "", score)
		if is_instance_valid(_sim_progress_bar): _sim_progress_bar.value = i
		if is_instance_valid(_sim_progress_lbl): _sim_progress_lbl.text = "Day %d/365 — score: %d" % [i, score]
		if i % 5 == 0: await get_tree().process_frame
	if is_instance_valid(_sim_progress_popup):
		_sim_progress_popup.get_ok_button().text = "Done!"
		_sim_progress_popup.get_ok_button().disabled = false
		_sim_progress_lbl.text = "✅ All 365 days simulated!"
	GameData.state_changed.emit()

func _give_all_dice() -> void:
	for sides in [8,10,12,20]:
		Database.add_dice(sides, 5)
		GameData.dice_satchel[sides] = GameData.dice_satchel.get(sides,0) + 5
	_show_msg("🎲 Added 5× d8, d10, d12, d20!"); GameData.state_changed.emit()

func _unlock_all_plants() -> void:
	for plant in GameData.PLANT_CATALOG:
		Database.plant_seed(plant.id, GameData.current_profile)
		for _i in range(3): Database.water_plant(plant.id, GameData.current_profile)
	_show_msg("🌿 All plants unlocked at stage 3!"); GameData.state_changed.emit()

func _max_moonpearls() -> void:
	Database.add_moonpearls(50000, GameData.current_profile)
	_show_msg("✨ Gave 50,000 Moonpearls!"); GameData.state_changed.emit()

func _dev_give_moonpearls() -> void:
	Database.add_moonpearls(100, GameData.current_profile)
	_show_msg("🌙 Gave 100 Moonpearls!")

func _reset_moonpearls() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Reset Moonpearls"; dialog.dialog_text = "Reset ALL moonpearls to 0?"
	dialog.confirmed.connect(func():
		Database.reset_moonpearls(); GameData.state_changed.emit()
		_show_msg("✨ Moonpearls reset to 0."))
	add_child(dialog); dialog.popup_centered()

## coin reset removed — coins are deprecated

func _dev_add_tasks() -> void:
	var samples: Array = GameData.DEV_SAMPLE_TASKS.duplicate(); samples.shuffle()
	for sample in samples.slice(0, 5):
		Database.insert_task(sample[0], sample[1], GameData.current_profile)
	_reload_gd(); _show_msg("✅ Added 5 sample tasks!")

func _dev_add_relics() -> void:
	var samples: Array = GameData.DEV_SAMPLE_RELICS.duplicate(); samples.shuffle()
	for sample in samples.slice(0, 5):
		var emoji: String = "✦" if sample.size() < 4 else str(sample[3])
		Database.insert_curio_canister(sample[0], sample[1], sample[2], GameData.current_profile, emoji)
	_reload_gd(); _show_msg("✅ Added 5 sample relics!")

func _clear_tasks() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Clear Tasks"; dialog.dialog_text = "Delete ALL tasks for this profile?"
	dialog.confirmed.connect(func():
		for t in Database.get_tasks(GameData.current_profile): Database.delete_task(t.id)
		_reload_gd(); _show_msg("Tasks cleared."))
	add_child(dialog); dialog.popup_centered()

func _clear_relics() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Clear Relics"; dialog.dialog_text = "Delete ALL relics for this profile?"
	dialog.confirmed.connect(func():
		for r in Database.get_curio_canisters(GameData.current_profile): Database.delete_curio_canister(r.id)
		_reload_gd(); _show_msg("Relics cleared."))
	add_child(dialog); dialog.popup_centered()

func _dev_add_contracts() -> void:
	for sample in GameData.DEV_SAMPLE_CONTRACTS:
		Database.insert_contract(sample.name, sample.difficulty, sample.get("deadline",""),
			sample.subtasks, sample.reward_type, "", GameData.current_profile)
	_show_msg("📜 Added 5 sample contracts!")
	GameData.contract_data_changed.emit(); GameData.state_changed.emit()

func _open_scene_texture_manager() -> void:
	var ui_script := load("res://scripts/DiceFaceDevUI.gd")
	if not ui_script: _show_msg("DiceFaceDevUI.gd not found!"); return
	var ui: Control = ui_script.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.z_index = 200; get_tree().get_root().add_child(ui)

func _confirm_nuke() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "💣 NUKE ALL DATA"
	dialog.dialog_text = "This deletes ALL save data for ALL profiles! Cannot be undone!"
	dialog.confirmed.connect(func():
		GameData.tasks = []; GameData.curio_canisters = []
		GameData.dice_results.clear(); GameData.jokers_owned = []
		GameData.task_die_overrides.clear()
		Database._economy = {"moonpearls":0,"moonpearls_pressed":0,"water_meter":0.0,"meals_today":0,"last_meal_date":"","machine_running":false}
		Database._save_economy()
		for path in [Database.TASKS_FILE, Database.CURIO_CANISTERS_FILE, Database.DAILY_STATS_FILE,
					  Database.CONTRACTS_FILE, Database.SATCHEL_FILE, Database.SETTINGS_FILE,
					  Database.PROFILES_FILE, Database.GARDEN_FILE, Database.SHOP_OWNED_FILE]:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		get_tree().reload_current_scene())
	get_tree().get_root().add_child(dialog); dialog.popup_centered()

func _reload_gd() -> void:
	var new_tasks := []
	for t in Database.get_tasks(GameData.current_profile):
		new_tasks.append({id=t.id, task=t.task, difficulty=t.difficulty,
			die_sides=t.get("die_sides",6), completed=false})
	GameData.tasks = new_tasks
	var new_curio_canisters := []
	for r in Database.get_curio_canisters(GameData.current_profile):
		new_curio_canisters.append({id=r.id, title=r.title, mult=r.get("mult",0.2),
			emoji=r.get("emoji","✦"), active=false})
	GameData.curio_canisters = new_curio_canisters
	_refresh_stats(); GameData.state_changed.emit()

func _show_save_path() -> void: _show_msg("Save folder:\n%s" % OS.get_user_data_dir())

func _show_msg(text: String) -> void:
	var dialog := AcceptDialog.new(); dialog.title = "Settings"; dialog.dialog_text = text
	add_child(dialog); dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())


func _style_section(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new(); style.bg_color = GameData.CARD_BG
	style.border_color = GameData.CARD_HL; style.set_border_width_all(1)
	style.set_corner_radius_all(4); panel.add_theme_stylebox_override("panel", style)


### Staging / Apply/Cancel workflow
func _stage_setting(key: String, value) -> void:
	_staged_settings[key] = value
	_any_changes = true
	if is_instance_valid(_apply_btn): _apply_btn.disabled = false
	if is_instance_valid(_cancel_btn): _cancel_btn.disabled = false

func _apply_changes() -> void:
	# Commit staged settings to Database and apply runtime effects
	for key in _staged_settings.keys():
		Database.save_setting(key, _staged_settings[key])

	# Apply graphics/audio and UI changes from saved settings
	_apply_saved_graphics()
	# UI scale
	GameData.apply_ui_scale()

	# Audio
	var mvol := float(str(Database.get_setting("volume_master", 1.0)))
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(mvol) if mvol > 0.0 else -80.0)
		AudioServer.set_bus_mute(master_idx, mvol <= 0.0)
	var sfx_vol := float(str(Database.get_setting("volume_sfx", 1.0)))
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_vol) if sfx_vol > 0.0 else -80.0)
		AudioServer.set_bus_mute(sfx_idx, sfx_vol <= 0.0)

	# Music volume
	var mus_vol := float(str(Database.get_setting("volume_music", 0.8)))
	var mus_idx := AudioServer.get_bus_index("Music")
	if mus_idx >= 0:
		AudioServer.set_bus_volume_db(mus_idx, linear_to_db(mus_vol) if mus_vol > 0.0 else -80.0)
		AudioServer.set_bus_mute(mus_idx, mus_vol <= 0.0)

	# UI volume
	var ui_vol := float(str(Database.get_setting("volume_ui", 1.0)))
	var ui_idx := AudioServer.get_bus_index("UI")
	if ui_idx >= 0:
		AudioServer.set_bus_volume_db(ui_idx, linear_to_db(ui_vol) if ui_vol > 0.0 else -80.0)
		AudioServer.set_bus_mute(ui_idx, ui_vol <= 0.0)

	# FPS
	Engine.max_fps = int(str(Database.get_setting("fps_limit", 60)))

	# Debug visibility update
	_update_dev_visibility()

	_staged_settings.clear(); _any_changes = false
	if is_instance_valid(_apply_btn): _apply_btn.disabled = true
	if is_instance_valid(_cancel_btn): _cancel_btn.disabled = true
	_show_msg("Settings applied.")

func _cancel_changes() -> void:
	# Rebuild UI from saved settings to revert staged changes
	_staged_settings.clear(); _any_changes = false
	if is_instance_valid(_apply_btn): _apply_btn.disabled = true
	if is_instance_valid(_cancel_btn): _cancel_btn.disabled = true
	_build_ui(); _refresh()

func _show_escape_popup() -> void:
	if _escape_popup != null and is_instance_valid(_escape_popup): return
	_escape_seconds_left = 10
	_escape_popup = AcceptDialog.new()
	_escape_popup.title = "Apply Changes?"
	_escape_popup.dialog_text = "Apply staged settings in %d seconds..." % _escape_seconds_left
	_escape_popup.get_ok_button().text = "Apply Now"
	_escape_popup.get_ok_button().pressed.connect(_on_escape_apply)
	# add Cancel button inside content
	var cancel_btn := Button.new(); cancel_btn.text = "Cancel Changes"
	cancel_btn.pressed.connect(_on_escape_cancel)
	_escape_count_lbl = Label.new(); _escape_count_lbl.text = ""
	var vb := VBoxContainer.new(); vb.add_child(_escape_count_lbl); vb.add_child(cancel_btn)
	_escape_popup.add_child(vb)
	add_child(_escape_popup); _escape_popup.popup_centered()

	# timer
	_escape_timer = Timer.new(); _escape_timer.wait_time = 1.0; _escape_timer.one_shot = false
	_escape_timer.autostart = true
	_escape_timer.timeout.connect(_on_escape_tick)
	add_child(_escape_timer)
	_escape_timer.start()

func _on_escape_tick() -> void:
	_escape_seconds_left -= 1
	if is_instance_valid(_escape_popup):
		_escape_popup.dialog_text = "Apply staged settings in %d seconds..." % _escape_seconds_left
	if _escape_seconds_left <= 0:
		_on_escape_apply()

func _on_escape_apply() -> void:
	if is_instance_valid(_escape_timer): _escape_timer.stop(); _escape_timer.queue_free(); _escape_timer = null
	if is_instance_valid(_escape_popup): _escape_popup.queue_free(); _escape_popup = null
	_apply_changes()

func _on_escape_cancel() -> void:
	if is_instance_valid(_escape_timer): _escape_timer.stop(); _escape_timer.queue_free(); _escape_timer = null
	if is_instance_valid(_escape_popup): _escape_popup.queue_free(); _escape_popup = null
	_cancel_changes()

func _input(event) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _any_changes:
			_show_escape_popup()

# ── Profile Export/Import ─────────────────────────────────────────
var _export_file_dialog: FileDialog = null
var _import_file_dialog: FileDialog = null

func _export_profile() -> void:
	if _export_file_dialog == null:
		_export_file_dialog = FileDialog.new()
		_export_file_dialog.title = "Export Profile"
		_export_file_dialog.add_filter("*.json;Profile Export Files")
		_export_file_dialog.current_file = "profile_export_%s.json" % _get_timestamp()
		# Skip explicit mode/access to remain compatible with multiple Godot versions
		_export_file_dialog.file_selected.connect(_on_export_file_selected)
		add_child(_export_file_dialog)

	_export_file_dialog.popup_centered()

func _on_export_file_selected(file_path: String) -> void:
	var export_data := _build_profile_export_data()
	var json_str := JSON.stringify(export_data, "\t")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		_show_msg("✅ Profile exported successfully to:\n%s" % file_path)
	else:
		_show_msg("❌ Failed to export profile. Could not write to file.")

func _import_profile() -> void:
	if _import_file_dialog == null:
		_import_file_dialog = FileDialog.new()
		_import_file_dialog.title = "Import Profile"
		_import_file_dialog.add_filter("*.json;Profile Export Files")
		# Skip explicit mode/access to remain compatible with multiple Godot versions
		_import_file_dialog.file_selected.connect(_on_import_file_selected)
		add_child(_import_file_dialog)

	_import_file_dialog.popup_centered()

func _on_import_file_selected(file_path: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Import Profile"
	dialog.dialog_text = "This will overwrite your current profile data. Continue?"
	dialog.confirmed.connect(func(): _perform_import(file_path))
	add_child(dialog)
	dialog.popup_centered()

func _perform_import(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		_show_msg("❌ Failed to import profile. Could not read file.")
		return
	
	var json_str := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_str) != OK:
		_show_msg("❌ Failed to import profile. Invalid JSON file.")
		return
	
	var export_data: Dictionary = json.data
	if not _validate_export_data(export_data):
		_show_msg("❌ Failed to import profile. Invalid export file format.")
		return
	
	# Backup current profile before import
	_create_profile_backup()
	
	# Perform import
	_apply_profile_data(export_data)
	_show_msg("✅ Profile imported successfully!")

func _build_profile_export_data() -> Dictionary:
	var profile_name: String = GameData.current_profile
	var export_data: Dictionary = {
		"metadata": {
			"profile_name": profile_name,
			"export_date": _get_datetime_string(),
			"game_version": "0.8.0",
			"export_format_version": 1
		},
		"profile_data": {
			"tasks": Database.get_tasks(profile_name),
			"curio_canisters": Database.get_curio_canisters(profile_name),
			"daily_stats": Database.get_all_dice_box_stats(profile_name),
			"contracts": Database.get_contracts(profile_name, false),
			"inventory": Database.get_inventory(),
			"economy": Database.get_economy(profile_name),
			"garden": Database.get_garden(profile_name),
			"shop_owned": Database.get_shop_owned(profile_name),
			"decorations": Database.get_decorations(profile_name),
			"ingredients": Database.get_ingredients(),
			"sweets": Database.get_all_sweets(),
			"achievements": Database.get_achievement_progress(),
			"dice_inventory": Database.get_dice_inventory(),
			"upgrade_levels": Database.get_upgrade_levels(),
			"settings": _get_profile_settings()
		}
	}
	return export_data

func _validate_export_data(data: Dictionary) -> bool:
	if not data.has("metadata") or not data.has("profile_data"):
		return false

	var metadata: Dictionary = data.get("metadata", {}) as Dictionary
	if not metadata.has("export_format_version") or int(metadata.get("export_format_version", 0)) < 1:
		return false

	var profile_data: Dictionary = data.get("profile_data", {}) as Dictionary
	var required_keys := ["tasks", "curio_canisters", "daily_stats", "contracts", 
						 "inventory", "economy", "garden", "shop_owned"]

	for key in required_keys:
		if not profile_data.has(key):
			return false

	return true

func _apply_profile_data(export_data: Dictionary) -> void:
	var profile_name: String = GameData.current_profile
	var profile_data: Dictionary = export_data.get("profile_data", {}) as Dictionary
	
	# Clear existing data
	_clear_profile_data(profile_name)
	
	# Restore data
	Database._tasks = profile_data.get("tasks", [])
	Database._curio_canisters = profile_data.get("curio_canisters", [])
	Database._dice_box_stats = {}
	for stat in profile_data.get("daily_stats", []):
		var key := "%s:%s" % [stat.get("date",""), profile_name]
		Database._dice_box_stats[key] = stat
	Database._contracts = profile_data.get("contracts", [])
	Database._inventory = profile_data.get("inventory", {})
	Database._economy[profile_name] = profile_data.get("economy", {})
	Database._garden = profile_data.get("garden", [])
	Database._shop_owned = profile_data.get("shop_owned", [])
	Database._decorations = profile_data.get("decorations", [])
	Database._ingredients = profile_data.get("ingredients", {})
	Database._sweets = profile_data.get("sweets", {})
	Database._achievements = profile_data.get("achievements", {})
	Database._dice_inventory = profile_data.get("dice_inventory", {})
	Database._upgrades = profile_data.get("upgrade_levels", {})
	
	# Save all data
	Database._save_tasks()
	Database._save_curio_canisters()
	Database._save_dice_box_stats()
	Database._save_contracts()
	Database._save_inventory()
	Database._save_economy()
	Database._save_garden()
	Database._save_shop_owned()
	Database._save_decorations()
	Database._save_ingredients()
	Database._save_sweets()
	Database._save_achievements()
	Database._save_dice_inventory()
	Database._save_upgrades()
	
	# Update GameData state
	_reload_gd()
	
	# Apply settings
	var settings: Dictionary = profile_data.get("settings", {}) as Dictionary
	for key in settings.keys():
		Database.save_setting(str(key), settings.get(key))
	
	# Refresh UI
	_refresh()

func _clear_profile_data(profile_name: String) -> void:
	# Clear all profile-specific data
	Database._tasks = []
	Database._curio_canisters = []
	Database._dice_box_stats = {}
	Database._contracts = []
	Database._garden = []
	Database._shop_owned = []
	Database._decorations = []
	Database._achievements = {}
	Database._dice_inventory = {}
	Database._upgrades = {}
	
	# Reset economy for this profile
	Database._economy[profile_name] = {"moonpearls":0,"moonpearls_pressed":0,"water_meter":0.0,"meals_today":0,"last_meal_date":"","machine_running":false}
	
	# Clear runtime data
	GameData.dice_results.clear()
	GameData.dice_roll_sides.clear()
	GameData.dice_peak_results.clear()
	GameData.jokers_owned.clear()
	GameData.task_die_overrides.clear()

func _get_profile_settings() -> Dictionary:
	var settings: Dictionary = {}
	var setting_keys := ["timezone", "window_mode", "window_size", 
						"msaa", "vsync", "fps_limit", "render_scale_3d", "fxaa",
						"ui_scale", "text_size_delta", "volume_master", "volume_sfx", 
						"volume_music", "volume_ui", "mute_all", "debug_mode", 
						"moon_phase_popup_enabled", "notifications_enabled", 
						"pomodoro_alerts", "notification_sound", "scroll_speed"]
	
	for key in setting_keys:
		settings[key] = Database.get_setting(key, null)
	
	return settings

func _create_profile_backup() -> void:
	var backup_data := _build_profile_export_data()
	var backup_path := "user://ante_up/profile_backup_%s.json" % _get_timestamp()
	var json_str := JSON.stringify(backup_data, "\t")
	var file := FileAccess.open(backup_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		print("Profile backup created at: %s" % backup_path)

func _get_timestamp() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]

func _get_datetime_string() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]

# ── Data Integrity Functions ─────────────────────────────────────────────────
func _check_data_integrity() -> void:
	if not GameData.is_debug_mode(): return
	var report: Dictionary = Database.check_data_integrity(GameData.current_profile)
	var msg := "🔍 Data Integrity Check Results:\n\n"
	if report["total_issues"] == 0:
		msg += "✅ No data integrity issues found!"
	else:
		msg += "⚠️ Found %d data integrity issue(s):\n" % report["total_issues"]
		for task_issue in report["tasks"]:
			msg += "- Duplicate task '%s': %d instances (expected 1)\n" % [task_issue["task_name"], task_issue["count"]]
		if report["orphaned_studio_rooms"].size() > 0:
			msg += "- Orphaned studio rooms: %d\n" % report["orphaned_studio_rooms"].size()
	_show_msg(msg)

func _fix_data_integrity() -> void:
	if not GameData.is_debug_mode(): return
	var result: Dictionary = Database.fix_data_integrity_issues(GameData.current_profile)
	_show_msg(result["message"])
	_reload_gd()
	_refresh_stats()
