extends Control

const MOON_PHASE_DISPLAY_SCRIPT := preload("res://scripts/MoonPhaseDisplay.gd")
const MOUSE_CLICK_SFX_PATH := "res://assets/audio/mouseclick1.wav"
const MOUSE_RELEASE_SFX_PATH := "res://assets/audio/mouserelease1.wav"

# Autoload singletons (alias for parser/runtime safety)
@onready var GameData := get_node("/root/GameData")
@onready var SignalBus := get_node("/root/SignalBus")
@onready var Database := get_node("/root/Database")
@onready var ArtReg := get_node("/root/ArtReg")
@onready var ButtonFeedback := get_node("/root/ButtonFeedback")
@onready var GardenSeedManager := get_node("/root/GardenSeedManager")
@onready var DiceSound := get_node("/root/DiceSound")
@onready var AudioManager := get_node("/root/AudioManager")
@onready var FXBus := get_node("/root/FXBus")
@onready var ActiveBuffs := get_node("/root/ActiveBuffs")
@onready var IngredientData := get_node("/root/IngredientData")
@onready var PlaceholderGen := get_node("/root/PlaceholderGen")
@onready var ContractRewardOverlay := get_node("/root/ContractRewardOverlay")
@onready var StudioRoomManager := get_node("/root/StudioRoomManager")
@onready var CursorManager := get_node("/root/CursorManager")

# Main.gd – Moonseed v0.8.0
# Layout:
#   [Contracts bar]
#   [Header: moonpearls LEFT | title CENTER | moon RIGHT]
#   [Content area — fills remaining space]
#   [Secondary nav: Calendar | Satchel | Settings]
#   [Primary bottom nav: Table | Garden | Confectionery | Lunar Bazaar]

var lbl_moonpearls:    HBoxContainer
var lbl_moon:        Label
var lbl_star_power:  Label
var _current_star_power: float = 1.0
var moon_phase_widget: Control
var _dev_wrench_btn: Button = null
var contracts_bar:   HBoxContainer
var _overlay_stage:  Control
var _transition:     CanvasLayer
var _ui_fx_layer:    CanvasLayer
var _escape_menu:    CanvasLayer
var _save_indicator: CanvasLayer
var _mouse_click_stream: AudioStream
var _mouse_release_stream: AudioStream
var _mouse_click_player: AudioStreamPlayer
var _mouse_release_player: AudioStreamPlayer
var _moonpearls_pulse_tween: Tween
var _prev_moonpearls: int = -1

# Content pane – all tab scripts live as children of this
var _content: Control

# Temporary test flag: set true to auto-trigger a roll once on startup (remove after debugging)
const TEST_AUTOROLL: bool = false

# Tab tracking
var _tab_nodes:     Dictionary = {}   # tab_key → Control
var _active_key:    String = ""
var _nav_btns:      Dictionary = {}   # tab_key → Button (both navs)

# Bottom primary tabs
const PRIMARY_TABS := [
	["table",          "🎲 TABLE",       "res://scenes/PlayTab.tscn",              true],
	["garden",         "🌿 GARDEN",      "res://scenes/GardenTab.tscn",             true],
	["confectionery",  "🍬 CONFECT",     "res://scenes/ConfectioneryTab.tscn",     true],
	["lunarbazaar",     "🌙 BAZAAR",      "res://scenes/BazaarTab.tscn",             true],
]
# Top secondary tabs
const SECONDARY_TABS := [
	["calendar",   "📅 Calendar",  "res://scripts/CalendarTab.gd",      false],
	["satchel",    "Satchel",      "res://scenes/SatchelTab.tscn",  true],
	["studio",     "Studio",       "res://scenes/ui/StudioRoom.tscn",    true],
	["settings",   "⚙ Settings",  "res://scripts/settings/SettingsTab.gd",       false],
]

func _ready() -> void:
	# Hide main UI while loading screen is visible
	self.visible = false

	# Build all UI and load data BEFORE showing loading screen
	print("Building main UI...")
	_build_ui()
	_setup_mouse_sfx()
	_apply_theme()
	_connect_signals()
	_load_profile()
	_refresh_header()
	call_deferred("_apply_feedback_all")

	# Now show loading screen as a brief visual splash
	var loading_screen_scene := load("res://scenes/LoadingScreen.tscn")
	var loading_screen: Node = loading_screen_scene.instantiate()
	add_child(loading_screen)
	loading_screen.connect("main_game_ready", Callable(self, "_on_loading_screen_complete"))

func _on_loading_screen_complete():
	# Loading screen has already faded itself out — just free it
	for child in get_children():
		if child is CanvasLayer and child.has_signal("main_game_ready"):
			print("Removing LoadingScreen node")
			child.queue_free()
			break

	# Fade in main UI
	get_node("/root/Juice").fade_in(self, 0.5)
	self.visible = true

	# Show MoonPhaseOverlay as a modal popup via helper
	_show_moon_splash()

	# Start background music (main theme) if available
	if is_instance_valid(AudioManager):
		AudioManager.play_main_theme()

	# Temporary test: auto-trigger a roll once if `TEST_AUTOROLL` enabled
	if TEST_AUTOROLL:
		print("[TEST] TEST_AUTOROLL active — scheduling roll trigger")
		call_deferred("_debug_trigger_roll")

func _on_moonphase_overlay_dismissed():
	print("MoonPhaseOverlay dismissed, main UI active.")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_play_mouse_click_sfx()
		else:
			_play_mouse_release_sfx()

	if event is InputEventKey and event.pressed:
		# Check if any LineEdit is focused to prevent tab switching while typing
		var focused_control := get_viewport().gui_get_focus_owner()
		if focused_control is LineEdit:
			return

		# Use ui_cancel action for Escape key
		if event.is_action_pressed("ui_cancel"):
			if is_instance_valid(_escape_menu):
				_escape_menu.toggle()
			return

		match event.keycode:
			KEY_1: _switch_tab("table")
			KEY_2: _switch_tab("garden")
			KEY_3: _switch_tab("confectionery")
			KEY_4: _switch_tab("lunarbazaar")

func _setup_mouse_sfx() -> void:
	if ResourceLoader.exists(MOUSE_CLICK_SFX_PATH):
		_mouse_click_stream = load(MOUSE_CLICK_SFX_PATH)
	if ResourceLoader.exists(MOUSE_RELEASE_SFX_PATH):
		_mouse_release_stream = load(MOUSE_RELEASE_SFX_PATH)

	_mouse_click_player = AudioStreamPlayer.new()
	_mouse_click_player.bus = "Master"
	add_child(_mouse_click_player)

	_mouse_release_player = AudioStreamPlayer.new()
	_mouse_release_player.bus = "Master"
	add_child(_mouse_release_player)

func _play_mouse_click_sfx() -> void:
	if _mouse_click_stream == null:
		return
	_mouse_click_player.stream = _mouse_click_stream
	_mouse_click_player.play()

func _play_mouse_release_sfx() -> void:
	if _mouse_release_stream == null:
		return
	_mouse_release_player.stream = _mouse_release_stream
	_mouse_release_player.play()

func _apply_feedback_all() -> void:
	if has_node("/root/ButtonFeedback"):
		get_node("/root/ButtonFeedback").setup_recursive(self)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = GameData.PANEL_BORDER  # Fixed dark purple background
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# ── Contracts bar ──────────────────────────────────────────────
	var cb_panel := PanelContainer.new()
	cb_panel.custom_minimum_size = Vector2(0, 28)
	var cb_st := StyleBoxFlat.new()
	cb_st.bg_color = GameData.PANEL_BG_ALT
	cb_st.border_color = GameData.PANEL_BORDER
	cb_st.border_width_bottom = 1
	cb_panel.add_theme_stylebox_override("panel", cb_st)
	root_vbox.add_child(cb_panel)

	var cb_hbox := HBoxContainer.new()
	cb_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cb_hbox.add_theme_constant_override("separation", 5)
	cb_panel.add_child(cb_hbox)

	var cb_lbl := Label.new()
	cb_lbl.text = "CONTRACTS:"
	cb_lbl.add_theme_color_override("font_color", GameData.ACCENT_CURIO_CANISTER)
	cb_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	cb_hbox.add_child(cb_lbl)

	contracts_bar = HBoxContainer.new()
	contracts_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contracts_bar.add_theme_constant_override("separation", 5)
	cb_hbox.add_child(contracts_bar)

	# ── Header ────────────────────────────────────────────────────
	var header_panel := PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = GameData.PANEL_BG
	header_style.border_color = GameData.PANEL_BORDER_ACCENT  # Fixed teal color
	header_style.border_width_bottom = 2
	header_panel.add_theme_stylebox_override("panel", header_style)
	header_panel.custom_minimum_size = Vector2(0, 60)
	root_vbox.add_child(header_panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.add_child(hbox)


	# LEFT: moonpearls contained in a fixed-width panel (ensure left-side placement)
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(220, 0)
	left_panel.size_flags_horizontal = Control.SIZE_FILL
	var lp_st := StyleBoxFlat.new()
	lp_st.bg_color = Color(0,0,0,0)
	left_panel.add_theme_stylebox_override("panel", lp_st)
	hbox.add_child(left_panel)

	var left_center := CenterContainer.new()
	left_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left_panel.add_child(left_center)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 6)
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_center.add_child(left_vbox)

	lbl_moonpearls = GameData.make_moonpearls_row(0, GameData.scaled_font_size(14), "MOONPEARLS: ")
	if is_instance_valid(lbl_moonpearls):
		lbl_moonpearls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(lbl_moonpearls)

	# RIGHT: moon phase only (stim dice removed)
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	right_vbox.custom_minimum_size = Vector2(150, 0)
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(right_vbox)

	# moon phase widget + text label (keep square and don't expand horizontally)
	moon_phase_widget = MOON_PHASE_DISPLAY_SCRIPT.new() as Control
	moon_phase_widget.custom_minimum_size = Vector2(56, 56)
	moon_phase_widget.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	moon_phase_widget.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var moon_center := CenterContainer.new()
	moon_center.add_child(moon_phase_widget)
	right_vbox.add_child(moon_center)

	lbl_moon = Label.new()
	lbl_moon.text = ""
	lbl_moon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_moon.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	right_vbox.add_child(lbl_moon)

	# Dev wrench (hidden by default; shown when debug mode enabled)
	var dev_hbox := HBoxContainer.new()
	dev_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dev_hbox.alignment = BoxContainer.ALIGNMENT_END
	right_vbox.add_child(dev_hbox)

	_dev_wrench_btn = Button.new()
	_dev_wrench_btn.text = "🔧"
	_dev_wrench_btn.custom_minimum_size = Vector2(36, 28)
	_dev_wrench_btn.visible = false
	_dev_wrench_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	_dev_wrench_btn.pressed.connect(Callable(self, "_on_dev_wrench_pressed"))
	dev_hbox.add_child(_dev_wrench_btn)

	var sec_panel := PanelContainer.new()
	var sec_st := StyleBoxFlat.new()
	sec_st.bg_color = Color(GameData.PANEL_BORDER, 0.95)  # Dark purple with transparency
	sec_st.border_color = Color(GameData.PANEL_BORDER_ACCENT, 0.5)  # Teal with transparency
	sec_st.border_width_bottom = 1
	sec_panel.add_theme_stylebox_override("panel", sec_st)
	root_vbox.add_child(sec_panel)

	# Secondary panel: star power (centered) + secondary tab row
	var sec_vbox := VBoxContainer.new()
	sec_vbox.custom_minimum_size = Vector2(0, 36)
	sec_vbox.add_theme_constant_override("separation", 4)
	sec_panel.add_child(sec_vbox)

	# (Star power removed from top strip — displayed in scoring area only)

	var sec_hbox := HBoxContainer.new()
	sec_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sec_hbox.add_theme_constant_override("separation", 2)
	sec_vbox.add_child(sec_hbox)

	for tab_def in SECONDARY_TABS:
		var key: String   = tab_def[0]
		var label: String = tab_def[1]
		var btn := Button.new()
		btn.text = label
		btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
		btn.custom_minimum_size = Vector2(140, 48)
		btn.tooltip_text = key.capitalize()
		for art_state: Array in [
			["normal",   "ui_button_primary_md_normal"],
			["hover",    "ui_button_primary_md_hover"],
			["pressed",  "ui_button_primary_md_pressed"],
			["disabled", "ui_button_primary_md_disabled"],
		]:
			var sb := _make_tab_btn_stylebox(art_state[1])
			if sb:
				btn.add_theme_stylebox_override(art_state[0], sb)
		btn.pressed.connect(Callable(self, "_switch_tab").bind(key))
		sec_hbox.add_child(btn)
		_nav_btns[key] = btn

	# ── Content area ─────────────────────────────────────────────
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_content)

	# Pre-instantiate all tab nodes
	var all_tabs: Array = PRIMARY_TABS + SECONDARY_TABS
	for tab_def in all_tabs:
		var key: String      = tab_def[0]
		var path: String     = tab_def[2]
		var use_scene: bool  = tab_def[3]
		var node: Control
		if use_scene:
			var packed: PackedScene = load(path)
			node = packed.instantiate() if packed else Control.new()
		else:
			node = Control.new()
			node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			node.size_flags_vertical   = Control.SIZE_EXPAND_FILL
			var scr: Script = load(path)
			if scr: node.set_script(scr)
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.visible = false
		_content.add_child(node)
		_tab_nodes[key] = node

	# ── Primary bottom nav ────────────────────────────────────────
	var nav_panel := PanelContainer.new()
	var nav_st := StyleBoxFlat.new()
	nav_st.bg_color = GameData.PANEL_BG
	nav_st.border_color = GameData.PANEL_BORDER_ACCENT  # Fixed teal color
	nav_st.border_width_top = 2
	nav_panel.add_theme_stylebox_override("panel", nav_st)
	nav_panel.custom_minimum_size = Vector2(0, 52)
	root_vbox.add_child(nav_panel)

	var nav_hbox := HBoxContainer.new()
	nav_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nav_hbox.add_theme_constant_override("separation", 0)
	nav_panel.add_child(nav_hbox)

	for tab_def in PRIMARY_TABS:
		var key: String   = tab_def[0]
		var label: String = tab_def[1]
		var btn := Button.new()
		btn.text = label
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		for art_state: Array in [
			["normal",   "ui_button_primary_md_normal"],
			["hover",    "ui_button_primary_md_hover"],
			["pressed",  "ui_button_primary_md_pressed"],
			["disabled", "ui_button_primary_md_disabled"],
		]:
			var sb := _make_tab_btn_stylebox(art_state[1])
			if sb:
				btn.add_theme_stylebox_override(art_state[0], sb)
		btn.pressed.connect(Callable(self, "_switch_tab").bind(key))
		nav_hbox.add_child(btn)
		_nav_btns[key] = btn

	# Transition overlay
	_overlay_stage = Control.new()
	_overlay_stage.name = "OverlayStage"
	_overlay_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_stage)

	var tr_scr: Script = load("res://scripts/TabTransition.gd")
	_transition = CanvasLayer.new()
	_transition.set_script(tr_scr)
	add_child(_transition)

	_ui_fx_layer = CanvasLayer.new()
	_ui_fx_layer.layer = 2
	add_child(_ui_fx_layer)
	
	# Add achievement popup system
	var achievement_popup_script := load("res://scripts/ui/AchievementPopup.gd")
	var achievement_popup := Control.new()
	achievement_popup.set_script(achievement_popup_script)
	_ui_fx_layer.add_child(achievement_popup)

	# Escape menu overlay (CanvasLayer, layer 10)
	var escape_menu_scene := load("res://scenes/ui/EscapeMenu.tscn")
	_escape_menu = escape_menu_scene.instantiate()
	add_child(_escape_menu)

	# Save status indicator (bottom-right, non-blocking)
	var save_indicator_script := load("res://scripts/ui/save_indicator.gd")
	_save_indicator = CanvasLayer.new()
	_save_indicator.set_script(save_indicator_script)
	add_child(_save_indicator)

	# Show default tab
	_switch_tab("table", false)

func _switch_tab(key: String, animate: bool = true) -> void:
	if not _tab_nodes.has(key): return

	# If already in this tab, handle special cases
	if _active_key == key:
		if key == "lunarbazaar":
			var bazaar_tab = _tab_nodes.get("lunarbazaar")
			if bazaar_tab and bazaar_tab.has_method("cleanup_overlay"):
				bazaar_tab.cleanup_overlay()
		return

	var do_switch := func():
		# Clean up overlays when switching away from bazaar tab
		if _active_key == "lunarbazaar" and key != "lunarbazaar":
			var bazaar_tab = _tab_nodes.get("lunarbazaar")
			if bazaar_tab and bazaar_tab.has_method("cleanup_overlay"):
				bazaar_tab.cleanup_overlay()
		
		for k in _tab_nodes:
			_tab_nodes[k].visible = false
		_tab_nodes[key].visible = true
		_active_key = key
		_update_nav_highlight()
		# Switch background music for Bazaar vs rest of game
		if is_instance_valid(AudioManager):
			if key == "lunarbazaar":
				AudioManager.play_bazaar_theme()
			else:
				AudioManager.play_main_theme()
	if animate and _transition and _transition.has_method("wipe"):
		_transition.wipe(do_switch)
	else:
		do_switch.call()

func _update_nav_highlight() -> void:
	for key in _nav_btns:
		var btn := _nav_btns[key] as Button
		if key == _active_key:
			btn.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
			var sel_sb := _make_tab_btn_stylebox("ui_button_primary_md_selected")
			var active_sb: StyleBox
			if sel_sb:
				active_sb = sel_sb
			else:
				active_sb = _make_active_btn_style()
			btn.add_theme_stylebox_override("normal", active_sb)
		else:
			btn.remove_theme_color_override("font_color")
			var norm_sb := _make_tab_btn_stylebox("ui_button_primary_md_normal")
			if norm_sb:
				btn.add_theme_stylebox_override("normal", norm_sb)
			else:
				btn.remove_theme_stylebox_override("normal")

func _is_primary_tab(key: String) -> bool:
	for td: Array in PRIMARY_TABS:
		if td[0] == key:
			return true
	return false

func _make_tab_btn_stylebox(art_key: String) -> StyleBoxTexture:
	var tex: Texture2D = ArtReg.texture_for(art_key)
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.draw_center = true
	# Stretch to fill the button exactly — no fixed margins so the art scales with button size
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical   = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb

func _make_active_btn_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(GameData.ACCENT_BLUE, 0.2)
	st.border_color = GameData.ACCENT_BLUE
	st.border_width_top = 2
	return st

func _apply_theme() -> void:
	if is_instance_valid(lbl_moonpearls) and lbl_moonpearls.get_child_count() > 1:
		(lbl_moonpearls.get_child(1) as Label).add_theme_color_override("font_color", GameData.ACCENT_GOLD)

func _connect_signals() -> void:
	GameData.state_changed.connect(_refresh_header)
	GameData.score_updated.connect(_on_score_updated)
	GameData.contract_data_changed.connect(_refresh_contracts_bar)
	if has_node("/root/SignalBus"):
		SignalBus.theme_changed.connect(_on_theme_changed)
		SignalBus.staged_count_finished.connect(_on_staged_count_finished_main)
	GameData.tab_requested.connect(func(tab): _switch_tab(tab))
	SignalBus.moonpearls_changed.connect(_on_moonpearls_changed)
	SignalBus.score_saved.connect(_on_score_saved)
	SignalBus.dice_unlocked.connect(_on_dice_unlocked)
	GameData.debug_mode_changed.connect(_on_debug_mode_changed_main)

func _on_theme_changed() -> void:
	for child in get_children():
		if child is ColorRect:
			child.color = GameData.BG_COLOR
			break
	_apply_theme()
	_refresh_header()
	_update_nav_highlight()

## Staged count finish — pulse moonpearls HUD when count resolves.
func _on_staged_count_finished_main(label_key: String, final_value: int) -> void:
	if label_key == "moonpearls":
		pulse_moonpearls_counter()
		# Update the HUD label to reflect the staged total
		if is_instance_valid(lbl_moonpearls):
			GameData.set_moonpearls_amount(lbl_moonpearls, final_value, "MOONPEARLS: ")

func _load_profile() -> void:
	var saved: Variant = Database.get_setting("profile", null)
	if saved == null or str(saved).strip_edges() == "":
		# First boot: ask user for a name
		var dialog := AcceptDialog.new()
		dialog.title = "Welcome"
		dialog.dialog_text = "Welcome to Moonseed! What should we call you?"
		var name_entry := LineEdit.new()
		name_entry.placeholder_text = "Your name"
		name_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dialog.add_child(name_entry)
		dialog.get_ok_button().text = "Save"
		dialog.confirmed.connect(func():
			var nm := name_entry.text.strip_edges()
			if nm == "": nm = "Player"
			Database.add_profile(nm)
			GameData.current_profile = nm
			_reload_game_data()
			dialog.queue_free()
		)
		add_child(dialog); dialog.popup_centered()
		return
	GameData.current_profile = str(saved)
	_reload_game_data()

func _reload_game_data() -> void:
	var new_tasks := []
	for t in Database.get_tasks(GameData.current_profile):
		new_tasks.append({id=t.id, task=t.task, difficulty=t.difficulty,
			die_sides=t.get("die_sides",6),
			rituals=t.get("rituals", []),
			consumables=t.get("consumables", []),
			sticker_slots=t.get("sticker_slots", []),
			card_color=t.get("card_color", "white"),
			studio_room=t.get("studio_room", -1),
			completed=false})
	GameData.tasks = new_tasks
	var new_curio_canisters := []
	for r in Database.get_curio_canisters(GameData.current_profile):
		new_curio_canisters.append({id=r.id, title=r.get("title","?"),
			emoji=r.get("emoji","✦"),
			mult=r.get("mult",0.2),
			image_path=r.get("image_path",""),
			card_color=r.get("card_color", "white"),
			sticker_slots=r.get("sticker_slots", []),
			studio_room=r.get("studio_room", -1),
			active=false})
	GameData.curio_canisters = new_curio_canisters
	var inv: Dictionary = Database.get_inventory()
	GameData.dice_inventory = {
		8:int(inv.get("8",0)), 10:int(inv.get("10",0)),
		12:int(inv.get("12",0)), 20:int(inv.get("20",0)),
	}
	GameData.jokers_owned = []
	for owned in Database.get_shop_owned(GameData.current_profile):
		GameData.jokers_owned.append(owned.item_id)
	_load_today_state()
	# Emit state_changed to trigger all tabs to refresh, including GardenTab
	GameData.state_changed.emit()
	# Ensure garden plants are positioned correctly during initial load
	call_deferred("_ensure_garden_initialization")

func _load_today_state() -> void:
	var rec: Variant = Database.get_dice_box_stat(GameData.get_date_string(), GameData.current_profile)
	if rec == null: return
	var done: PackedStringArray = str(rec.get("completed_tasks","")).split(",", false)
	for t in GameData.tasks: t.completed = t.task in done
	print("[DEBUG] Main._load_today_state: initializing GameData.dice_results from DB (clearing first)")
	GameData.dice_results = {}
	GameData.dice_roll_sides = {}
	GameData.dice_peak_results = {}
	for part in str(rec.get("task_rolls","")).split("|", false):
		if ":" in part and not part.begins_with("R:"):
			var kv := part.split(":", false)
			if kv.size() >= 4:
				GameData.dice_results[int(kv[0])] = int(kv[1])
				GameData.dice_roll_sides[int(kv[0])] = int(kv[2])
				GameData.dice_peak_results[int(kv[0])] = int(kv[3])
			elif kv.size() == 3:
				GameData.dice_results[int(kv[0])] = int(kv[1])
				GameData.dice_roll_sides[int(kv[0])] = int(kv[2])
				GameData.dice_peak_results[int(kv[0])] = int(kv[1])
			elif kv.size() == 2:
				GameData.dice_results[int(kv[0])] = int(kv[1])
				GameData.dice_roll_sides[int(kv[0])] = 6
				GameData.dice_peak_results[int(kv[0])] = int(kv[1])

func _refresh_header() -> void:
	GameData.set_moonpearls_amount(lbl_moonpearls, Database.get_moonpearls(GameData.current_profile), "MOONPEARLS: ")
	var moon: Dictionary = GameData.get_moon_phase(GameData.view_date)
	if is_instance_valid(moon_phase_widget):
		moon_phase_widget.set_phase_data(moon)
	lbl_moon.text = moon.name
	_refresh_contracts_bar()



func _debug_trigger_roll() -> void:
	print("[TEST] _debug_trigger_roll executing")
	var table_node: Control = get_tab_node("table")
	if table_node:
		if table_node.has_method("_roll_selected_or_all"):
			print("[TEST] Calling _roll_selected_or_all()")
			table_node.call_deferred("_roll_selected_or_all")
		else:
			print("[TEST] PlayTab missing _roll_selected_or_all method")
	else:
		print("[TEST] PlayTab node not found")

## coin tick removed — periodic coin minting deprecated

func _on_moonpearls_changed(new_val: int) -> void:
	if not is_instance_valid(lbl_moonpearls) or lbl_moonpearls.get_child_count() < 2:
		_refresh_header()
		return
	var lbl: Label = lbl_moonpearls.get_child(1) as Label
	if not is_instance_valid(lbl):
		_refresh_header()
		return
	# First load or unknown prev → instant update, no animation
	if _prev_moonpearls < 0 or _prev_moonpearls == new_val:
		_refresh_header()
		_prev_moonpearls = new_val
		return
	# Animate: tick up from old → new with particles + pulse
	var old_val: int = _prev_moonpearls
	_prev_moonpearls = new_val
	var Juice: Node = get_node_or_null("/root/Juice")
	if Juice:
		Juice.animated_counter_update(lbl_moonpearls, lbl, old_val, new_val, "MOONPEARLS: ", "%s", _ui_fx_layer)
	else:
		_refresh_header()

func _on_dice_unlocked(dice_type: String) -> void:
	print("DEBUG: Main._on_dice_unlocked received signal for ", dice_type)
	# Animate moonpearl counter change (purchase may decrease)
	var new_mp: int = Database.get_moonpearls(GameData.current_profile)
	if _prev_moonpearls >= 0 and _prev_moonpearls != new_mp and is_instance_valid(lbl_moonpearls) and lbl_moonpearls.get_child_count() >= 2:
		var lbl: Label = lbl_moonpearls.get_child(1) as Label
		if is_instance_valid(lbl):
			var Juice: Node = get_node_or_null("/root/Juice")
			if Juice:
				Juice.animated_counter_update(lbl_moonpearls, lbl, _prev_moonpearls, new_mp, "MOONPEARLS: ", "%s", _ui_fx_layer)
	_prev_moonpearls = new_mp
	# If we're currently in the bazaar tab, refresh the shop display
	if _active_key == "lunarbazaar":
		var bazaar_tab = _tab_nodes.get("lunarbazaar")
		if bazaar_tab and bazaar_tab.has_method("refresh_shop_display"):
			bazaar_tab.call("refresh_shop_display")

func _on_score_saved(_final_score: int, moonpearls_delta: int) -> void:
	if moonpearls_delta <= 0 or not is_instance_valid(_ui_fx_layer):
		return
	FXBus.rain_moonpearls(moonpearls_delta, _ui_fx_layer)

func _on_score_updated(_moondrops: int, _star_power: float) -> void:
	_current_star_power = _star_power
	if is_instance_valid(lbl_star_power):
		lbl_star_power.text = "⭐ STAR POWER x %.2f" % _current_star_power
	_refresh_header()

func _refresh_contracts_bar() -> void:
	if not is_instance_valid(contracts_bar): return
	for c in contracts_bar.get_children(): c.queue_free()
	var active: Array = Database.get_contracts(GameData.current_profile, false)
	if active.is_empty():
		var e := Label.new()
		e.text = "No active contracts"
		e.add_theme_color_override("font_color", GameData.PANEL_BORDER)
		e.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		contracts_bar.add_child(e); return
	active.sort_custom(func(a: Dictionary, b: Dictionary):
		var priority := {"High Priority": 0, "Med Priority": 1, "Low Priority": 2, "No Priority": 3}
		return priority.get(a.get("difficulty","No Priority"), 3) < priority.get(b.get("difficulty","No Priority"), 3)
	)
	for c in active: contracts_bar.add_child(_make_pill(c))

func _make_pill(c: Dictionary) -> PanelContainer:
	var diff: String = c.get("difficulty","No Priority")
	var bg: Color = GameData.get_deadline_bg(diff)
	var dl: String = c.get("deadline","")
	var days := -1
	if dl != "":
		days = _days_between(GameData.get_date_string(), dl)
		if days < 0: bg = Color(0.45,0.0,0.0,0.9)
	var pill := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = bg; st.set_corner_radius_all(10)
	st.content_margin_left=7; st.content_margin_right=7
	st.content_margin_top=1; st.content_margin_bottom=1
	pill.add_theme_stylebox_override("panel", st)
	var lbl := Label.new()
	if dl != "":
		var em: String = "📋"
		if diff == "High Priority":
			em = "💀"
		elif diff == "Med Priority":
			em = "⚠️"
		lbl.text = "%s %s [%dd]" % [em, c.get("name","?"), days]
	else:
		lbl.text = "📋 " + c.get("name","?")
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	pill.add_child(lbl)
	# make pill clickable – jump to garden
	pill.mouse_filter = Control.MOUSE_FILTER_PASS
	pill.gui_input.connect(Callable(self, "_on_pill_gui_input"))
	return pill

func _show_moon_splash() -> void:
	if not Database.get_bool("moon_phase_popup_enabled", true):
		return
	# Avoid spawning a second moon overlay if one is already active
	if GameData.get("moon_overlay_active"):
		return
	await get_tree().create_timer(0.3).timeout
	var overlay_scr: Script = load("res://scripts/MoonPhaseOverlay.gd")
	var overlay_node: Control = overlay_scr.new() as Control
	# Place the overlay Control inside a CanvasLayer so it renders above UI
	var overlay_layer := CanvasLayer.new()
	overlay_layer.add_child(overlay_node)
	add_child(overlay_layer)
	overlay_node.show_moon(GameData.get_moon_phase(GameData.view_date))
	if overlay_node.has_signal("moon_dismissed"):
		GameData.moon_overlay_active = true
		overlay_node.moon_dismissed.connect(Callable(self, "_on_moon_overlay_dismissed"))
# Public helper for other scripts that need to jump to a tab
func switch_to_tab_by_key(key: String) -> void:
	_switch_tab(key)

func get_tab_node(key: String) -> Control:
	return _tab_nodes.get(key, null) as Control

func get_stage_root() -> Node:
	if is_instance_valid(_overlay_stage):
		return _overlay_stage
	return self

func add_overlay_to_stage(node: Node) -> void:
	if not is_instance_valid(node):
		return
	get_stage_root().add_child(node)

func get_moonpearls_target_global_position() -> Vector2:
	if is_instance_valid(lbl_moonpearls) and lbl_moonpearls.get_child_count() > 0:
		var icon := lbl_moonpearls.get_child(0) as Control
		if is_instance_valid(icon):
			return icon.get_global_rect().get_center()
	if is_instance_valid(lbl_moonpearls):
		return lbl_moonpearls.get_global_rect().get_center()
	return Vector2(72.0, 36.0)

func pulse_moonpearls_counter() -> void:
	if not is_instance_valid(lbl_moonpearls):
		return
	if _moonpearls_pulse_tween:
		_moonpearls_pulse_tween.kill()
	lbl_moonpearls.pivot_offset = lbl_moonpearls.size * 0.5
	lbl_moonpearls.scale = Vector2.ONE
	_moonpearls_pulse_tween = create_tween()
	_moonpearls_pulse_tween.tween_property(lbl_moonpearls, "scale", Vector2(1.14, 1.14), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_moonpearls_pulse_tween.tween_property(lbl_moonpearls, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_debug_mode_changed_main(on: bool) -> void:
	if is_instance_valid(_dev_wrench_btn):
		_dev_wrench_btn.visible = on

func _on_dev_wrench_pressed() -> void:
	var tab: Control = _tab_nodes.get(_active_key) as Control
	if is_instance_valid(tab) and tab.has_method("show_dev_popup"):
		tab.call("show_dev_popup")

func _on_pill_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		GameData.tab_requested.emit("garden")

func _on_moon_overlay_dismissed() -> void:
	GameData.moon_overlay_active = false
	var table_node: Control = _tab_nodes.get("table")
	if table_node and table_node.has_method("_update_score_safe"):
		table_node.call("_update_score_safe")

func _days_between(from_str: String, to_str: String) -> int:
	var fmt := func(s: String) -> Dictionary:
		var p := s.split("-")
		return {year=int(p[0]),month=int(p[1]),day=int(p[2]),hour=0,minute=0,second=0}
	var f: Dictionary = fmt.call(from_str)
	var t: Dictionary = fmt.call(to_str)
	return int((Time.get_unix_time_from_datetime_dict(t) -
				Time.get_unix_time_from_datetime_dict(f)) / 86400.0)

func _ensure_garden_initialization() -> void:
	# Ensure GardenTab gets properly initialized during game load
	# This triggers the coordinate conversion for all existing plants
	var garden_tab: Control = get_tab_node("garden")
	if is_instance_valid(garden_tab) and garden_tab.has_method("_refresh"):
		print("[DEBUG] Main._ensure_garden_initialization: calling GardenTab._refresh()")
		garden_tab.call("_refresh")
	else:
		print("[DEBUG] Main._ensure_garden_initialization: GardenTab not ready, scheduling retry")
		# Add safety delay to avoid infinite recursion crash
		await get_tree().create_timer(0.1).timeout
		if is_inside_tree():
			call_deferred("_ensure_garden_initialization")
