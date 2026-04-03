extends Control

# ─────────────────────────────────────────────────────────────────
# ConfectioneryTab.gd  —  MOONSEED  v0.9.0
# GDD §9  The Confectionery — Focus & Crafting
#
# Layout (§9.6):
#   TOP:     Factory name + active timer display
#   CENTER:  The Boiler — animated machine, ingredient slots, progress bar
#   LEFT:    Ingredient Pantry
#   RIGHT:   Recipe Book
#
# v0.9.0: Now backed by ConfectioneryTab.tscn scene file.
#         @onready vars map to named nodes in the scene.
#         _build_layout() will skip structural chrome nodes that
#         are already in the scene; it only builds DATA-DRIVEN
# ─────────────────────────────────────────────────────────────────

# ── @onready — scene node wiring ─────────────────────────────────
@onready var _progress_bar: ProgressBar    = $RootVBox/MainColumns/LeftPanel/PantryVBox/BoilerPanel/BoilerVBox/ProgressBar
@onready var _start_btn: Button             = $RootVBox/MainColumns/LeftPanel/PantryVBox/ControlHBox/StartButton
@onready var _abandon_btn: Button           = $RootVBox/MainColumns/LeftPanel/PantryVBox/ControlHBox/AbandonButton
@onready var _boiler_anim: Label            = $RootVBox/MainColumns/LeftPanel/PantryVBox/BoilerPanel/BoilerVBox/BoilerAnimLabel
@onready var _status_label: Label           = $RootVBox/MainColumns/LeftPanel/PantryVBox/BoilerPanel/BoilerVBox/StatusLabel
@onready var _recipe_vbox: VBoxContainer    = $RootVBox/MainColumns/RightPanel/RecipeVBox/RecipeScroll/RecipeItemsVBox
@onready var _timer_label: Label            = $RootVBox/MainColumns/LeftPanel/PantryVBox/TimerDisplayLabel

# Session buttons
@onready var _btn_25: Button              = $RootVBox/MainColumns/LeftPanel/PantryVBox/SessionTypeHBox/Btn25
@onready var _btn_50: Button              = $RootVBox/MainColumns/LeftPanel/PantryVBox/SessionTypeHBox/Btn50
@onready var _btn_90: Button              = $RootVBox/MainColumns/LeftPanel/PantryVBox/SessionTypeHBox/Btn90

# Category influence buttons (left panel)
@onready var _category_fruit: Button      = $RootVBox/MainColumns/LeftPanel/PantryVBox/CategoryFruit
@onready var _category_crunch: Button     = $RootVBox/MainColumns/LeftPanel/PantryVBox/CategoryCrunch
@onready var _category_floral: Button     = $RootVBox/MainColumns/LeftPanel/PantryVBox/CategoryFloral
@onready var _category_spice: Button      = $RootVBox/MainColumns/LeftPanel/PantryVBox/CategorySpice
@onready var _category_wildcard: Button   = $RootVBox/MainColumns/LeftPanel/PantryVBox/CategoryWildcard

# Coin inventory labels
@onready var _bar_coin_label: Label       = $RootVBox/CoinInventoryBar/BarCoinLabel
@onready var _truffle_coin_label: Label   = $RootVBox/CoinInventoryBar/TruffleCoinLabel
@onready var _artisan_coin_label: Label   = $RootVBox/CoinInventoryBar/ArtisanCoinLabel

# Plinko drop buttons
@onready var _drop_bar_btn: Button        = $RootVBox/PlinkoDropBar/DropBarBtn
@onready var _drop_truffle_btn: Button    = $RootVBox/PlinkoDropBar/DropTruffleBtn
@onready var _drop_artisan_btn: Button    = $RootVBox/PlinkoDropBar/DropArtisanBtn

# Plinko board (center panel visual)
@onready var _plinko_board: Control       = $RootVBox/MainColumns/CenterVBox/PlinkoBoard

# ── Timer state ──────────────────────────────────────────────────
var _session_type:   String = "25min"
var _session_dur:    int    = 25 * 60
var _time_remaining: int    = 0
var _running:        bool   = false
var _timer:          Timer

var _session_type_opts: Array[Button] = []
var _boiler_tween:      Tween
var _session_btn_mats:   Dictionary = {}  # instance_id -> ShaderMaterial
var _active_session_btn: Button = null

const POMODORO_PROGRESS_SHADER := preload("res://shaders/pomodoro_outline_progress.gdshader")

# Boiler animation frames
const BOILER_FRAMES: Array[String] = ["⚙","🔩","⚙","🔧","⚙","🔩","⚙","🔨"]
const BUBBLE_FRAMES: Array[String] = ["💧","🫧","💧","🫧","💦","🫧","💧","🌊"]
var _boiler_frame: int = 0
var _bubble_frame: int = 0

# Debug
var _debug_panel:   PopupPanel
# var _debug_visible: bool = false  # Uncomment if needed
var _bpm_slider:    HSlider
var _debug_timer_speed: int = 1

func _ready() -> void:
	SignalBus.ingredients_changed.connect(_refresh_minigame_picker)
	# Connect to debug mode changes
	if not GameData.debug_mode_changed.is_connected(_on_debug_mode_changed):
		GameData.debug_mode_changed.connect(_on_debug_mode_changed)
	# If the scene already includes structural nodes, avoid rebuilding chrome layout
	if has_node("RootVBox/MainColumns/LeftPanel") and has_node("RootVBox/MainColumns/RightPanel"):
		_setup_session_buttons()
		_refresh_all()
		_build_confect_debug_panel()
		# Setup debug wrench if debug mode is enabled (deferred to ensure scene is ready)
		call_deferred("_setup_debug_wrench")
	else:
		_build_layout()
		_refresh_all()
		_build_confect_debug_panel()
	call_deferred("_setup_feedback")

func _on_debug_mode_changed(enabled: bool) -> void:
	if enabled:
		_setup_debug_wrench()
	else:
		_remove_debug_wrench()

func _setup_debug_wrench() -> void:
	# Add debug wrench button if in debug mode (for pre-built scenes)
	if not GameData.is_debug_mode(): return
	
	# Get the header HBox - try both possible paths
	var header_hbox: HBoxContainer = null
	if has_node("RootVBox/Header/HeaderHBox"):
		header_hbox = $RootVBox/Header/HeaderHBox
	elif has_node("HeaderHBox"):
		header_hbox = $HeaderHBox
	
	if header_hbox == null:
		push_warning("ConfectioneryTab: Could not find HeaderHBox for debug wrench")
		return
	
	# Check if wrench already exists
	for child in header_hbox.get_children():
		if child is Button and child.tooltip_text == "Open debug panel":
			return  # Already exists
	
	var wrench_btn := Button.new()
	wrench_btn.text = "🔧"
	wrench_btn.tooltip_text = "Open debug panel"
	wrench_btn.focus_mode = Control.FOCUS_NONE
	wrench_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrench_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	wrench_btn.pressed.connect(_toggle_confect_debug)
	
	# Add to the header HBox (at the end, before any potential spacer)
	header_hbox.add_child(wrench_btn)

func _remove_debug_wrench() -> void:
	# Remove debug wrench button when debug mode is disabled
	var header_hbox: HBoxContainer = $RootVBox/Header/HeaderHBox
	if header_hbox == null: return
	
	for child in header_hbox.get_children():
		if child is Button and child.tooltip_text == "Open debug panel":
			child.queue_free()
			return

func _setup_session_buttons() -> void:
	# Setup existing session buttons from scene
	_session_type_opts = [_btn_25, _btn_50, _btn_90]
	
	# Install shaders and connect signals
	for i in range(_session_type_opts.size()):
		var btn: Button = _session_type_opts[i]
		_install_session_button_shader(btn, GameData.ACCENT_GOLD)
		
		var stype: String
		var sdur: int
		match i:
			0: stype = "25min"; sdur = 25 * 60
			1: stype = "50min"; sdur = 50 * 60  
			2: stype = "90min"; sdur = 90 * 60
			_: continue
		
		btn.pressed.connect(func(): _select_session(stype, sdur, btn))
	
	# Connect start and abandon buttons
	if _start_btn:
		_start_btn.pressed.connect(_start_session)
	if _abandon_btn:
		_abandon_btn.pressed.connect(_abandon_session)
	
	# Setup category influence buttons
	_setup_category_buttons()
	
	# Update coin inventory display
	_update_coin_display()
	
	# Connect to coin changes signal
	SignalBus.chocolate_coins_changed.connect(_update_coin_display)
	
	# Setup plinko drop buttons
	_setup_plinko_drop_buttons()

func _setup_category_buttons() -> void:
	# Connect category buttons to influence system
	if _category_fruit:
		_category_fruit.pressed.connect(func(): _on_category_pressed("fruit"))
	if _category_crunch:
		_category_crunch.pressed.connect(func(): _on_category_pressed("crunch"))
	if _category_floral:
		_category_floral.pressed.connect(func(): _on_category_pressed("floral"))
	if _category_spice:
		_category_spice.pressed.connect(func(): _on_category_pressed("spice"))
	if _category_wildcard:
		_category_wildcard.pressed.connect(func(): _on_category_pressed("wild"))

func _on_category_pressed(category: String) -> void:
	# Map category string to index
	var cat_index: int = 4  # default wildcard
	match category:
		"fruit": cat_index = 0
		"crunch": cat_index = 1
		"floral": cat_index = 2
		"spice": cat_index = 3
		"wild": cat_index = 4
	
	# Update board to show subtypes for this category
	if _plinko_board and _plinko_board.has_method("set_category"):
		_plinko_board.set_category(cat_index)
	
	# Add influence to the Plinko controller
	if has_node("/root/PlinkoController"):
		get_node("/root/PlinkoController").add_influence(category, 1)
	
	# Visual feedback - pulse the button and update toggle states
	var btn: Button = null
	match category:
		"fruit": btn = _category_fruit
		"crunch": btn = _category_crunch
		"floral": btn = _category_floral
		"spice": btn = _category_spice
		"wild": btn = _category_wildcard
	
	# Deselect other buttons, select this one
	var all_btns: Array[Button] = [_category_fruit, _category_crunch, _category_floral, _category_spice, _category_wildcard]
	for b in all_btns:
		if b:
			b.button_pressed = (b == btn)
	
	if btn:
		var tween: Tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)

func _update_coin_display() -> void:
	# Update coin inventory labels
	if _bar_coin_label:
		_bar_coin_label.text = "🪙 Bar: %d" % GameData.get_chocolate_coin_count("bar")
	if _truffle_coin_label:
		_truffle_coin_label.text = "🍫 Truffle: %d" % GameData.get_chocolate_coin_count("truffle")
	if _artisan_coin_label:
		_artisan_coin_label.text = "✨ Artisan: %d" % GameData.get_chocolate_coin_count("artisan")

func _setup_plinko_drop_buttons() -> void:
	# Connect plinko drop buttons
	if _drop_bar_btn:
		_drop_bar_btn.pressed.connect(func(): _on_plinko_drop_pressed("bar"))
	if _drop_truffle_btn:
		_drop_truffle_btn.pressed.connect(func(): _on_plinko_drop_pressed("truffle"))
	if _drop_artisan_btn:
		_drop_artisan_btn.pressed.connect(func(): _on_plinko_drop_pressed("artisan"))

func _on_plinko_drop_pressed(coin_type: String) -> void:
	# Check if board is busy
	if _plinko_board and _plinko_board.has_method("is_busy") and _plinko_board.is_busy():
		_status_label.text = "⏳ Wait for current drop..."
		return
	
	# Check if player has the coin
	var coin_count: int = GameData.get_chocolate_coin_count(coin_type)
	if coin_count <= 0:
		_status_label.text = "❌ No %s coins!" % coin_type
		return
	
	# Check if plinko controller exists
	if not has_node("/root/PlinkoController"):
		_status_label.text = "❌ Plinko not available!"
		return
	
	# Remove the coin from inventory
	if not GameData.remove_chocolate_coin(coin_type, 1):
		_status_label.text = "❌ Failed to use coin!"
		return
	
	# Drop the coin in plinko
	var plinko_controller = get_node("/root/PlinkoController")
	plinko_controller.drop_coin(coin_type)
	
	# Resolve the chocolate
	var result: Dictionary = plinko_controller.resolve_chocolate(_session_type)
	if result.is_empty():
		_status_label.text = "❌ Plinko drop failed!"
		return
	
	# Trigger board visual animation
	if _plinko_board and _plinko_board.has_method("play_drop_animation"):
		var pocket_idx: int = plinko_controller.current_pocket_index
		var category: int = result.category_id if result.has("category_id") else 4
		_plinko_board.play_drop_animation(coin_type, pocket_idx, category)
	
	# Show result
	var flavor_name: String = result.flavor.name if result.has("flavor") else "Unknown"
	var category_name: String = result.category.name if result.has("category") else "Unknown"
	_status_label.text = "🍫 %s (%s)" % [flavor_name, category_name]
	
	# Add ingredients to inventory
	if result.has("flavor") and result.flavor.has("ingredients"):
		for ingredient_id in result.flavor.ingredients:
			Database.add_ingredient(ingredient_id, 1)
		SignalBus.ingredients_changed.emit()

func _setup_feedback() -> void:
	if has_node("/root/ButtonFeedback"):
		get_node("/root/ButtonFeedback").setup_recursive(self)

# ══════════════════════════════════════════════════════════════════
# LAYOUT BUILD
# ══════════════════════════════════════════════════════════════════
func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = GameData.BG_COLOR
	add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 6)
	add_child(outer)

	# ── TOP: Title + Timer Display ────────────────────────────────
	_build_top_bar(outer)

	# ── MAIN ROW: Left pantry | Center boiler | Right recipes ─────
	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 6)
	outer.add_child(main_row)


func _install_session_button_shader(btn: Button, color: Color) -> void:
	if btn == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = POMODORO_PROGRESS_SHADER
	mat.set_shader_parameter("outline_color", Vector4(color.r, color.g, color.b, 1.0))
	mat.set_shader_parameter("fade_minimum_alpha", 0.45)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("rotation", 0.0)
	mat.set_shader_parameter("draw_border", true)
	mat.set_shader_parameter("fill_style", 0)
	btn.material = mat
	_session_btn_mats[btn.get_instance_id()] = mat

func _update_session_button_progress() -> void:
	for btn in _session_type_opts:
		if btn == null:
			continue
		var mat: ShaderMaterial = _session_btn_mats.get(btn.get_instance_id(), null)
		if mat == null:
			continue
		var p: float = 0.0
		if btn == _active_session_btn:
			if _running:
				var safe_dur: float = maxf(float(_session_dur), 1.0)
				p = clampf((safe_dur - float(maxi(_time_remaining, 0))) / safe_dur, 0.0, 1.0)
			elif _time_remaining <= 0:
				p = 1.0
		mat.set_shader_parameter("progress", p)

func _build_top_bar(parent: VBoxContainer) -> void:
	var top_panel := PanelContainer.new()
	top_panel.custom_minimum_size = Vector2(0, 52)
	var tp_st := StyleBoxFlat.new()
	tp_st.bg_color    = Color("#0d0520")
	tp_st.border_color = GameData.ACCENT_GOLD
	tp_st.border_width_bottom = 2
	top_panel.add_theme_stylebox_override("panel", tp_st)
	parent.add_child(top_panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	top_panel.add_child(hbox)

	var title := Label.new()
	title.text = "🍫  THE CONFECTIONERY"
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	# Debug wrench button (only in debug mode)
	if GameData.is_debug_mode():
		var wrench_btn := Button.new()
		wrench_btn.text = "🔧"
		wrench_btn.tooltip_text = "Open debug panel"
		wrench_btn.focus_mode = Control.FOCUS_NONE
		wrench_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		wrench_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
		wrench_btn.pressed.connect(_toggle_confect_debug)
		hbox.add_child(wrench_btn)

	_timer_label = Label.new()
	_timer_label.text = "⏱ --:--"
	_timer_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
	_timer_label.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
	_timer_label.custom_minimum_size = Vector2(130, 0)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(_timer_label)

func _build_boiler(parent: HBoxContainer) -> void:
	var boiler_panel := PanelContainer.new()
	boiler_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boiler_panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	var bp_st := StyleBoxFlat.new()
	bp_st.bg_color     = Color("#080315")
	bp_st.border_color = GameData.ACCENT_GOLD
	bp_st.set_border_width_all(2)
	bp_st.set_corner_radius_all(6)
	boiler_panel.add_theme_stylebox_override("panel", bp_st)
	parent.add_child(boiler_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boiler_panel.add_child(vbox)

	# Machine animation display
	_boiler_anim = Label.new()
	_boiler_anim.text = "🏭"
	_boiler_anim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boiler_anim.add_theme_font_size_override("font_size", GameData.scaled_font_size(52))
	vbox.add_child(_boiler_anim)

	_status_label = Label.new()
	_status_label.text = "Choose a session to begin"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	_status_label.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
	vbox.add_child(_status_label)
# ══════════════════════════════════════════════════════════════════
# SESSION LOGIC (§9.2)
# ══════════════════════════════════════════════════════════════════
func _to_bool(v, default: bool=false) -> bool:
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_STRING:
		var s := String(v).strip_edges().to_lower()
		return s == "true" or s == "1" or s == "yes"
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v) != 0
	return default

func _select_session(stype: String, sdur: int, pressed_btn: Button) -> void:
	if _running: return
	_session_type = stype
	_session_dur  = sdur
	_time_remaining = sdur
	_active_session_btn = pressed_btn
	_update_timer_label()
	_update_session_button_progress()
	for btn in _session_type_opts:
		btn.button_pressed = (btn == pressed_btn)
		btn.add_theme_color_override("font_color",
			GameData.ACCENT_GOLD if btn == pressed_btn else Color(GameData.FG_COLOR, 0.6))

func _start_session() -> void:
	if _running: return
	_running = true
	_update_session_button_progress()
	_start_btn.visible   = false
	_abandon_btn.visible = true
	_status_label.text   = "🔥 Session in progress..."

	# Minimize window when session starts (if setting enabled)
	if _to_bool(Database.get_setting("pomodoro_auto_minimize", true), true):
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MINIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

	_start_boiler_animation()
	SignalBus.confect_session_started.emit(_session_type, _session_dur)

func _on_tick() -> void:
	_time_remaining = maxi(_time_remaining - _debug_timer_speed, 0)
	_update_timer_label()
	_progress_bar.value = 1.0 - float(_time_remaining) / float(_session_dur)
	_update_session_button_progress()
	SignalBus.confect_tick.emit(_time_remaining)
	if _time_remaining <= 0:
		_complete_session()

func _complete_session() -> void:
	_stop_timer()
	_stop_boiler_animation()
	_running = false

	# Play notification sound and unminimize window
	var notif_path := "res://assets/audio/confectionary/notification.wav"
	var sfx_cache := get_node_or_null("/root/SfxCache")
	var notif_stream: AudioStream = null
	if sfx_cache:
		notif_stream = sfx_cache.get_stream(notif_path)
	else:
		if ResourceLoader.exists(notif_path):
			notif_stream = load(notif_path)
	if notif_stream:
		get_node("/root/AudioManager").play_sfx(notif_stream)

	# Unminimize or request attention (if setting enabled)
	if _to_bool(Database.get_setting("pomodoro_auto_minimize", true), true):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_request_attention()

	# Calculate yield (check Focus Bonbon buff)
	var has_bonus: bool = ActiveBuffs.has_buff("double_ingredients")
	if has_bonus: ActiveBuffs.consume_charge("double_ingredients")
	var yield_arr: Array = IngredientData.get_session_yield(_session_type, has_bonus)

	# Check if active relic provides extra ingredient
	var curio_canister_bonus: bool = _check_curio_canister_bonus()
	if curio_canister_bonus:
		var extra := IngredientData.get_session_yield("25min", false)
		yield_arr.append_array(extra)

	# Award ingredients
	for item in yield_arr:
		Database.add_ingredient(item["id"], item["qty"])

	# Award chocolate coins based on session duration
	var duration_minutes: int = _session_dur / 60
	var coin_rewards: Array = IngredientData.get_coin_reward(duration_minutes)
	print("DEBUG _complete_session: duration_minutes=", duration_minutes, " coin_rewards=", coin_rewards)
	for coin_reward in coin_rewards:
		print("DEBUG: Adding coin type=", coin_reward.type, " qty=", coin_reward.qty)
		GameData.add_chocolate_coin(coin_reward.type, coin_reward.qty)
	
	# Update coin display immediately after awarding coins
	_update_coin_display()

	SignalBus.ingredients_changed.emit()
	SignalBus.confect_session_complete.emit(yield_arr)

	_status_label.text = "✅ Session complete!"
	_show_yield_popup(yield_arr)
	_start_btn.visible   = true
	_abandon_btn.visible = false
	_progress_bar.value  = 1.0
	_update_session_button_progress()

func _abandon_session() -> void:
	_stop_timer()
	_stop_boiler_animation()
	_running = false
	_start_btn.visible   = true
	_abandon_btn.visible = false
	_status_label.text   = "❌ Session abandoned — no yield"
	_progress_bar.value  = 0.0
	_time_remaining = _session_dur
	_debug_timer_speed = 1
	_update_timer_label()
	_update_session_button_progress()
	SignalBus.confect_session_abandoned.emit()

func _stop_timer() -> void:
	if is_instance_valid(_timer):
		_timer.stop()
		_timer.queue_free()
		_timer = null

func _check_curio_canister_bonus() -> bool:
	for r in GameData.curio_canisters:
		if r.get("active", false):
			return true
	return false

# ══════════════════════════════════════════════════════════════════
# BOILER ANIMATION (§9.2 "gears turn, liquid bubbles, smoke puffs")
# ══════════════════════════════════════════════════════════════════
var _anim_timer: Timer

func _start_boiler_animation() -> void:
	_anim_timer = Timer.new()
	_anim_timer.wait_time = 0.45   # ~133BPM factory rhythm
	_anim_timer.autostart = true
	_anim_timer.timeout.connect(_tick_boiler_anim)
	add_child(_anim_timer)

func _stop_boiler_animation() -> void:
	if is_instance_valid(_anim_timer):
		_anim_timer.stop()
		_anim_timer.queue_free()
		_anim_timer = null
	_boiler_anim.text = "🏭"

func _tick_boiler_anim() -> void:
	_boiler_frame = (_boiler_frame + 1) % BOILER_FRAMES.size()
	_bubble_frame = (_bubble_frame + 1) % BUBBLE_FRAMES.size()
	var gear:   String = BOILER_FRAMES[_boiler_frame]
	var bubble: String = BUBBLE_FRAMES[_bubble_frame]
	_boiler_anim.text = "%s 🏭 %s" % [bubble, gear]
	# Slight scale pulse for life
	_boiler_anim.pivot_offset = _boiler_anim.size * 0.5
	if _boiler_tween: _boiler_tween.kill()
	_boiler_tween = _boiler_anim.create_tween()
	_boiler_tween.tween_property(_boiler_anim, "scale", Vector2(1.06, 1.06), 0.1)
	_boiler_tween.tween_property(_boiler_anim, "scale", Vector2(1.0,  1.0),  0.1)

# ══════════════════════════════════════════════════════════════════
# UI HELPERS
# ══════════════════════════════════════════════════════════════════
func _update_timer_label() -> void:
	var mins: int = int(_time_remaining / 60.0)
	var secs: int = _time_remaining % 60
	_timer_label.text = "⏱ %02d:%02d" % [mins, secs]
	if _time_remaining <= 60:
		_timer_label.add_theme_color_override("font_color", GameData.ACCENT_RED)
	elif _time_remaining <= 300:
		_timer_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	else:
		_timer_label.add_theme_color_override("font_color", GameData.ACCENT_BLUE)


func _show_yield_popup(yield_arr: Array) -> void:
	pass

func _refresh_all() -> void:
	 # Pantry items removed - only show timer, boiler, and recipes
		# Select default session if buttons are available
		if _session_type_opts.size() > 0:
			_select_session("25min", 25 * 60, _btn_25)

func _refresh_minigame_picker() -> void:
	var minigame: Variant = get_node_or_null("%CraftingMinigame")
	if not minigame: return
	if minigame.has_method("refresh_ingredient_picker"):
		minigame.call("refresh_ingredient_picker")

# ── GDD §3 Confectionery Debug Panel ─────────────────────────────
func _build_confect_debug_panel() -> void:
	if not GameData.is_debug_mode(): return
	if is_instance_valid(_debug_panel):
		_debug_panel.queue_free()
	_debug_panel = PopupPanel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(GameData.BG_COLOR, 0.98); st.border_color = GameData.ACCENT_RED
	st.set_border_width_all(1); st.set_corner_radius_all(6)
	_debug_panel.add_theme_stylebox_override("panel", st)
	add_child(_debug_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_debug_panel.add_child(margin)
	var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", 3)
	margin.add_child(dv)
	var hdr := Label.new(); hdr.text = "🔧  DEBUG CONFECTIONERY"
	hdr.add_theme_color_override("font_color", GameData.ACCENT_RED)
	hdr.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; dv.add_child(hdr)
	# GDD §3: Instant Pomodoro
	var r1 := HBoxContainer.new(); r1.add_theme_constant_override("separation", 2); dv.add_child(r1)
	for e: Array in [["⏱ Instant Pomodoro", _debug_instant_pomodoro],
					  ["🛑 Abandon", _debug_abandon_session]]:
		var b := Button.new(); b.text = e[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		b.pressed.connect(e[1] as Callable); r1.add_child(b)
	# GDD §3: Give Chocolate Coins
	var coin_lbl := Label.new(); coin_lbl.text = "🍫 Give Chocolate Coins"
	coin_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	coin_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); dv.add_child(coin_lbl)
	var r3 := HBoxContainer.new(); r3.add_theme_constant_override("separation", 2); dv.add_child(r3)
	for e: Array in [["🪙 +5 Bar", func(): _debug_give_coins("bar", 5)],
					  ["🍫 +5 Truffle", func(): _debug_give_coins("truffle", 5)],
					  ["✨ +5 Artisan", func(): _debug_give_coins("artisan", 5)]]:
		var b := Button.new(); b.text = e[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		b.pressed.connect(e[1] as Callable); r3.add_child(b)
	# Pomodoro speed multipliers (debug only)
	var spd_lbl := Label.new(); spd_lbl.text = "⏩ Pomodoro Speed"
	spd_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	spd_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); dv.add_child(spd_lbl)
	var r1b := HBoxContainer.new(); r1b.add_theme_constant_override("separation", 2); dv.add_child(r1b)
	for e: Array in [["1x", 1], ["5x", 5], ["10x", 10], ["20x", 20], ["50x", 50]]:
		var b := Button.new(); b.text = e[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		var speed: int = e[1]
		b.pressed.connect(func(): _debug_set_timer_speed(speed))
		r1b.add_child(b)
	# GDD §3: Ingredient Infusion
	var r2 := HBoxContainer.new(); r2.add_theme_constant_override("separation", 2); dv.add_child(r2)
	for e: Array in [["� +Moonmelt Cocoa ×5", func(): _debug_add_ingredient("moonmelt_cocoa", 5)],
					  ["🍬 +All ×2", _debug_add_all_ingredients]]:
		var b := Button.new(); b.text = e[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		b.pressed.connect(e[1] as Callable); r2.add_child(b)
	# GDD §3: Test Machine BPM
	var bpm_lbl := Label.new(); bpm_lbl.text = "⚙ Boiler BPM"
	bpm_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	bpm_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); dv.add_child(bpm_lbl)
	var bpm_row := HBoxContainer.new(); dv.add_child(bpm_row)
	_bpm_slider = HSlider.new()
	_bpm_slider.min_value = 0.1; _bpm_slider.max_value = 5.0; _bpm_slider.step = 0.1
	_bpm_slider.value = 1.0
	_bpm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bpm_val := Label.new(); bpm_val.text = "1.0×"
	bpm_val.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	_bpm_slider.value_changed.connect(func(v: float):
		bpm_val.text = "%.1f×" % v
		Database.save_setting("debug_boiler_bpm", v))
	bpm_row.add_child(_bpm_slider); bpm_row.add_child(bpm_val)
	# Show/hide button in header area
	_refresh_debug_visibility()

func show_dev_popup() -> void:
	if not GameData.is_debug_mode(): return
	if not is_instance_valid(_debug_panel):
		_build_confect_debug_panel()
	_debug_panel.popup_centered()

func _toggle_confect_debug() -> void:
	show_dev_popup()

func _refresh_debug_visibility() -> void:
	pass  # replaced by popup; kept for call-site compat

func _debug_instant_pomodoro() -> void:
	if not GameData.is_debug_mode(): return
	if not _running: _start_session()
	_time_remaining = 0  # Complete immediately
	_complete_session()

func _debug_give_coins(coin_type: String, qty: int) -> void:
	if not GameData.is_debug_mode(): return
	GameData.add_chocolate_coin(coin_type, qty)
	_update_coin_display()

func _debug_set_timer_speed(speed: int) -> void:
	if not GameData.is_debug_mode(): return
	_debug_timer_speed = maxi(speed, 1)
	if _running:
		_status_label.text = "🔥 Session in progress... (%dx)" % _debug_timer_speed

func _debug_abandon_session() -> void:
	if not GameData.is_debug_mode(): return
	_abandon_session()

func _debug_add_ingredient(key: String, qty: int) -> void:
	if not GameData.is_debug_mode(): return
	Database.add_ingredient(key, qty)
	SignalBus.ingredients_changed.emit()

func _debug_add_all_ingredients() -> void:
	if not GameData.is_debug_mode(): return
	for key in IngredientData.INGREDIENTS.keys():
		Database.add_ingredient(key, 2)
	SignalBus.ingredients_changed.emit()
