extends Control

# ─────────────────────────────────────────────────────────────────
# PlayTab.gd  – logic only; layout defined in PlayTab.tscn
# ─────────────────────────────────────────────────────────────────

@onready var _nav_label:        Label          = $VBoxContainer/NavBar/NavLabel
@onready var _score_chips:      Label          = $VBoxContainer/ScoreBanner/ScoreHBox/ChipsLabel
@onready var _score_mult:        Label          = $VBoxContainer/ScoreBanner/ScoreHBox/MultLabel
@onready var _score_total_row:  HBoxContainer  = $VBoxContainer/ScoreBanner/ScoreHBox/ScoreRow
@onready var _score_total:      Label          = $VBoxContainer/ScoreBanner/ScoreHBox/ScoreRow/ScoreLabel
var _score_curio_bonus: Label = null
@onready var _tasks_container:  VBoxContainer  = $VBoxContainer/Columns/LeftPanel/LeftVBox/TasksScroll/TasksContainer
@onready var _roll_all_btn:      Button         = $VBoxContainer/Columns/LeftPanel/LeftVBox/TaskActions/RollAllBtn
@onready var _dice_table:        Control        = $VBoxContainer/Columns/CenterVBox/DiceTable
@onready var _curio_canisters_container: VBoxContainer  = $VBoxContainer/Columns/RightPanel/RightVBox/CurioCanistersScroll/CurioCanistersContainer
@onready var _score_banner:      PanelContainer = $VBoxContainer/ScoreBanner
@onready var _left_panel:        PanelContainer = $VBoxContainer/Columns/LeftPanel
@onready var _right_panel:       PanelContainer = $VBoxContainer/Columns/RightPanel
@onready var _tasks_header:      Label          = $VBoxContainer/Columns/LeftPanel/LeftVBox/TasksHeader
@onready var _curio_canisters_header:     Label          = $VBoxContainer/Columns/RightPanel/RightVBox/CurioCanistersHeader

var _task_rows:    Dictionary = {}
var _curio_canister_cards:  Dictionary = {}
var _is_rolling:   bool       = false
var _curio_canister_shader: Shader     = null
var _snd_curio_canister:    AudioStreamPlayer = null
var _snd_rollover: AudioStreamPlayer = null
var _hand:         Dictionary = {}  # task_id → true
var _eat_meal_count: int = 1
var _rituals_done: Dictionary = {}
var _last_curio_bonus: int = 0  # curio bonus from last roll

# ── Dice Resolution Pipeline (v0.10) ─────────────────────────────
var _score_engine: ScoreEngine = ScoreEngine.new()
var _resolution_queue: RollResolutionQueue = null
var _reward_fx: RewardFXController = null

# ── Dev / debug panel (only visible with debug_mode on) ──────────
var _debug_wrench_btn: Button = null
var _debug_panel: PopupPanel = null

# ── Score overlay: only shown the first time dice are rolled each day ──
var _score_overlay_shown_today: bool = false

# ── Drag-to-select (tasks / curio_canisters) ─────────────────────────────────
var _drag_selecting:     bool       = false
var _drag_select_add:    bool       = false   	# true=add to hand / activate curio_canister
var _drag_select_type:   String     = ""      # "task" or "curio_canister"
var _drag_touched_ids:   Dictionary = {}      # ids already processed this drag

# ── Card fidget drag (visual-only nudge with RMB) ────────────────────
var _card_drag_active: bool = false
var _card_drag_target: Control = null
var _card_drag_start_mouse: Vector2 = Vector2.ZERO
var _card_drag_start_position: Vector2 = Vector2.ZERO

# ── Scoring audio pool: random sounds on each scored roll ─────────────
var _score_audio_pool: Array = []
const SCORE_AUDIO_PATHS := [
	"res://assets/audio/dice/score_1.wav",
	"res://assets/audio/dice/score_2.wav",
	"res://assets/audio/dice/score_3.wav",
	"res://assets/audio/dice/score_4.wav",
]
const ROLLOVER_SFX_PATH := "res://assets/audio/rollover2.wav"

const CURIO_CANISTER_ROW_H := 320
const PLAY_CARD_SIZE := Vector2(230, 320)
const CURIO_CANISTER_CARD_SCALE := Vector2(0.75, 0.75)
const PLAY_CARD_TOP_RATIO := 0.62
const STICKER_DEFAULT_TEXTURE_PATH := "res://assets/textures/stickers/Sticker_default.png"
const PLAY_CARD_DRAG_MAX_OFFSET := Vector2(42.0, 34.0)
const HOVER_TILT_SCRIPT := preload("res://scripts/HoverCardTilt.gd")
const TASK_DICE_BOX_VIEW_SCRIPT := preload("res://scripts/ui/task_dice_box_view.gd")
const STRENGTH_FLAME_SHADER_PATH := "res://shaders/ui_strength_flame.gdshader"
const DIE_FACE_PATHS := {
	6:  "res://assets/textures/dice/d6_basic/d6_basic_%02d.png",
	8:  "res://assets/textures/dice/d8_basic/d8_basic_%02d.png",
	10: "res://assets/textures/dice/d10_basic/d10_basic_%02d.png",
	12: "res://assets/textures/dice/d12_basic/d12_basic_%02d.png",
	20: "res://assets/textures/dice/d20_basic/d20_basic_%02d.png",
}
const CARD_BASE_TEXTURES := {
	"white": "res://assets/textures/Card Base/Card_Base_White.png",
	"blue": "res://assets/textures/Card Base/Card_Base_Blue.png",
	"green": "res://assets/textures/Card Base/Card_Base_Green.png",
	"brown": "res://assets/textures/Card Base/Card_Base_Brown.png",
}
const READABLE_BG := Color("#ffffff")
const READABLE_BG_SOFT := Color("#f4f4f4")
const READABLE_BG_HIGHLIGHT := Color("#fff4cc")
const READABLE_BG_DONE := Color("#eaf7ff")
const READABLE_BORDER := Color("#1f1f1f")
const READABLE_BORDER_SOFT := Color("#9a9a9a")
const READABLE_TEXT := Color("#000000")
const READABLE_TEXT_MUTED := Color("#2d2d2d")

# Panel shadow settings — tweak these to change global panel shadow
const PANEL_SHADOW_COLOR := Color(0, 0, 0, 0.14)
const PANEL_SHADOW_OFFSET := Vector2(6, 6)

const RUNES := ["ᚠ","ᚢ","ᚦ","ᚨ","ᚱ","ᚲ","ᚷ","ᚹ","ᚺ","ᚾ","ᛁ","ᛃ","ᛇ","ᛈ","ᛉ",
				 "ᛊ","ᛏ","ᛒ","ᛖ","ᛗ","ᛚ","ᛜ","ᛞ","ᛟ","⚡","✦","★","⊕","⊗"]

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	GameData.state_changed.connect(_refresh)
	GameData.debug_mode_changed.connect(_on_debug_mode_changed_play)
	if has_node("/root/SignalBus"):
		SignalBus.theme_changed.connect(_on_theme_changed_play)
		SignalBus.studio_room_updated.connect(_on_studio_room_updated)
		SignalBus.staged_count_updated.connect(_on_staged_count_updated)
		SignalBus.staged_count_finished.connect(_on_staged_count_finished)
	_curio_canister_shader = load("res://shaders/curio_active.gdshader") as Shader
	_setup_curio_canister_audio()
	_setup_rollover_audio()
	_setup_score_audio()
	_apply_styles()
	_connect_buttons()
	_setup_score_shine()
	_setup_strength_flame()
	_setup_confetti()
	_setup_final_score_overlay()
	_inject_starchunk_icon()
	_inject_moonpearl_icon()
	_setup_curio_bonus_label()
	set_process(true)
	call_deferred("_refresh")
	call_deferred("_setup_button_feedback")

func _setup_button_feedback() -> void:
	if has_node("/root/ButtonFeedback"):
		get_node("/root/ButtonFeedback").setup_recursive(self)

func _setup_curio_bonus_label() -> void:
	# Create a label for curio bonus stardrops
	_score_curio_bonus = Label.new()
	_score_curio_bonus.name = "CurioBonusLabel"
	_score_curio_bonus.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	_score_curio_bonus.add_theme_color_override("font_color", Color("#88ff88"))
	_score_curio_bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_curio_bonus.text = ""
	_score_curio_bonus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add to the score banner
	var score_hbox = _score_chips.get_parent()
	if score_hbox:
		score_hbox.add_child(_score_curio_bonus)


# ── Staged Count Handlers ─────────────────────────────────────────
## Updates score banner labels with chunked intermediate values.
func _on_staged_count_updated(label_key: String, value: int) -> void:
	match label_key:
		"stardrops":
			_score_chips.text = "STARDROPS: %d" % value
			# tiny scale pop at each checkpoint
			_score_chips.pivot_offset = _score_chips.size * 0.5
			_score_chips.scale = Vector2(1.06, 1.06)
			var tw: Tween = _score_chips.create_tween()
			tw.tween_property(_score_chips, "scale", Vector2.ONE, 0.08)
		"moonpearls":
			_score_total.text = "FINAL MOONPEARLS: %d" % value
			_score_total.pivot_offset = _score_total.size * 0.5
			_score_total.scale = Vector2(1.08, 1.08)
			var tw2: Tween = _score_total.create_tween()
			tw2.tween_property(_score_total, "scale", Vector2.ONE, 0.08)

## Settles final value after staged count completes with an explode beat.
func _on_staged_count_finished(label_key: String, final_value: int) -> void:
	match label_key:
		"stardrops":
			var total_stardrops: int = final_value + _last_curio_bonus
			_score_chips.text = "STARDROPS: %d" % total_stardrops
			_shake_label(_score_chips, 5.0)
		"moonpearls":
			_score_total.text = "FINAL MOONPEARLS: %d" % final_value
			_shake_label(_score_total, 6.0)
			# flash the final number
			if _shine_rect and _shine_rect.material:
				var mat := _shine_rect.material as ShaderMaterial
				var ft: Tween = create_tween()
				ft.tween_method(func(v:float): mat.set_shader_parameter("alpha_mul",v), 0.0, 0.9, 0.12)
				ft.tween_interval(0.4)
				ft.tween_method(func(v:float): mat.set_shader_parameter("alpha_mul",v), 0.9, 0.0, 0.4)

func _on_studio_room_updated(room_id: int) -> void:
	# Refresh any task previews that are using this studio room composition.
	for tid in _task_rows.keys():
		var row: Dictionary = _task_rows.get(tid, {})
		if int(row.get("room_id", -1)) != room_id:
			continue
		if row.has("box_view") and is_instance_valid(row["box_view"] as TaskDiceBoxView):
			(row["box_view"] as TaskDiceBoxView).set_room_composition(StudioRoomManager.get_composition(room_id))

	for rid in _curio_canister_cards.keys():
		var row2: Dictionary = _curio_canister_cards.get(rid, {})
		if int(row2.get("room_id", -1)) != room_id:
			continue
		var card: PanelContainer = row2.get("card", null) as PanelContainer
		if not is_instance_valid(card):
			continue
		var tex_rect: TextureRect = card.get_node_or_null("CardBaseTexture") as TextureRect
		if tex_rect != null:
			tex_rect.texture = StudioRoomManager.get_composition(room_id)
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func _attach_hover_tilt(ctrl: Control, tilt_deg: float = 3.0, scale_mul: float = 1.03) -> void:
	if ctrl == null:
		return
	ctrl.set_script(HOVER_TILT_SCRIPT)
	ctrl.set("max_tilt_degrees", tilt_deg)
	ctrl.set("hover_scale", scale_mul)
	ctrl.set("hover_wobble_degrees", 1.05)
	ctrl.set("hover_wobble_speed", 8.2)

func _set_noninteractive_mouse_ignore(root: Control) -> void:
	if not is_instance_valid(root):
		return
	for child in root.get_children():
		if child is Control:
			var ctrl := child as Control
			var keep_input: bool = (ctrl is TaskDiceBoxView) or (ctrl is BaseButton)
			if not keep_input:
				ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_noninteractive_mouse_ignore(ctrl)

func _input(event: InputEvent) -> void:
	if not _card_drag_active or not is_instance_valid(_card_drag_target):
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var delta: Vector2 = mm.global_position - _card_drag_start_mouse
		delta.x = clampf(delta.x, -PLAY_CARD_DRAG_MAX_OFFSET.x, PLAY_CARD_DRAG_MAX_OFFSET.x)
		delta.y = clampf(delta.y, -PLAY_CARD_DRAG_MAX_OFFSET.y, PLAY_CARD_DRAG_MAX_OFFSET.y)
		_card_drag_target.position = _card_drag_start_position + delta
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			_end_card_drag_nudge(true)
			get_viewport().set_input_as_handled()

func _begin_card_drag_nudge(card: Control, start_mouse: Vector2) -> void:
	if not is_instance_valid(card):
		return
	_card_drag_active = true
	_card_drag_target = card
	_card_drag_start_mouse = start_mouse
	_card_drag_start_position = card.position
	card.z_index = 14

func _end_card_drag_nudge(animate_back: bool) -> void:
	if not is_instance_valid(_card_drag_target):
		_card_drag_active = false
		_card_drag_target = null
		return
	var dragged := _card_drag_target
	dragged.z_index = 0
	if animate_back:
		var tw: Tween = create_tween()
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(dragged, "position", _card_drag_start_position, 0.16)
	else:
		dragged.position = _card_drag_start_position
	_card_drag_active = false
	_card_drag_target = null

func _inject_starchunk_icon() -> void:
	# Create an HBoxContainer for moondrops if it doesn't exist
	var parent := _score_chips.get_parent()
	if not is_instance_valid(parent): 
		return
	
	print("DEBUG: _inject_starchunk_icon called, _score_chips text: '", _score_chips.text, "'")
	
	# Check if we already have an HBoxContainer for moondrops
	var moondrops_hbox: HBoxContainer
	if parent.has_node("MoondropsRow"):
		moondrops_hbox = parent.get_node("MoondropsRow") as HBoxContainer
		print("DEBUG: MoondropsRow exists with ", moondrops_hbox.get_child_count(), " children")
		# Check if we already have an icon, if so, update it instead of creating new one
		if moondrops_hbox.has_node("StarchunkIcon"):
			print("DEBUG: StarchunkIcon already exists, updating texture")
			var existing_icon = moondrops_hbox.get_node("StarchunkIcon") as TextureRect
			GameData._set_random_moondrop_frame(existing_icon)
			return
	else:
		# Create HBoxContainer for moondrops
		moondrops_hbox = HBoxContainer.new()
		moondrops_hbox.name = "MoondropsRow"
		moondrops_hbox.alignment = 0 as BoxContainer.AlignmentMode  # Left alignment
		moondrops_hbox.add_theme_constant_override("separation", 4)
		
		# Set the same layout as the original ChipsLabel
		moondrops_hbox.anchors_preset = 15
		moondrops_hbox.anchor_right = 1.0
		moondrops_hbox.anchor_bottom = 1.0
		moondrops_hbox.offset_left = 8.0
		moondrops_hbox.offset_top = 2.0
		moondrops_hbox.offset_right = -8.0
		moondrops_hbox.offset_bottom = -2.0
		moondrops_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Add the HBoxContainer to parent
		parent.add_child(moondrops_hbox)
		
		# Move the original ChipsLabel into the new HBoxContainer
		parent.remove_child(_score_chips)
		moondrops_hbox.add_child(_score_chips)
		# Ensure the label expands to the remaining horizontal space so its text is visible
		moondrops_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_score_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_score_chips.custom_minimum_size = Vector2(96, _score_chips.custom_minimum_size.y)
		_score_chips.clip_text = true
		print("DEBUG: Moondrops text after move: '", _score_chips.text, "' visible: ", _score_chips.visible, ", position: ", _score_chips.position, ", size: ", _score_chips.size, ", parent: ", _score_chips.get_parent().name)
	
	# Create and add the icon
	var icon := TextureRect.new()
	icon.name = "StarchunkIcon"
	icon.custom_minimum_size = Vector2(14, 14)  # Smaller size to fit score bar
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	GameData._set_random_moondrop_frame(icon)
	moondrops_hbox.add_child(icon)
	moondrops_hbox.move_child(icon, 0)  # Move to first position
	print("DEBUG: Added moondrop icon, MoondropsRow now has ", moondrops_hbox.get_child_count(), " children")
	print("DEBUG: Final _score_chips state: text='", _score_chips.text, "' visible=", _score_chips.visible, " position=", _score_chips.position, " size=", _score_chips.size)
	print("DEBUG: MoondropsRow children: ")
	for i in range(moondrops_hbox.get_child_count()):
		var child = moondrops_hbox.get_child(i)
		print("  Child ", i, ": ", child.name, " (", child.get_class(), ") visible=", child.visible)

func _inject_moonpearl_icon() -> void:
	var hbox := _score_total.get_parent() as HBoxContainer
	if not is_instance_valid(hbox): return
	# Update existing MoonpearlIcon if it exists, or create new one
	var icon: TextureRect
	if hbox.has_node("MoonpearlIcon"):
		icon = hbox.get_node("MoonpearlIcon") as TextureRect
		# Update existing icon to use proper settings
		icon.custom_minimum_size = Vector2(14, 14)  # Even smaller for better fit
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		icon = TextureRect.new()
		icon.name = "MoonpearlIcon"
		icon.custom_minimum_size = Vector2(14, 14)  # Even smaller for better fit
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon)
		hbox.move_child(icon, _score_total.get_index())
	
	# Set random moonpearl texture
	GameData._set_random_moonpearls_frame(icon)

func _setup_curio_canister_audio() -> void:
	_snd_curio_canister = AudioStreamPlayer.new(); add_child(_snd_curio_canister)
	var p := "res://assets/audio/curio_select.wav"
	if ResourceLoader.exists(p): _snd_curio_canister.stream = load(p)

func _setup_rollover_audio() -> void:
	_snd_rollover = AudioStreamPlayer.new()
	add_child(_snd_rollover)
	if ResourceLoader.exists(ROLLOVER_SFX_PATH):
		_snd_rollover.stream = load(ROLLOVER_SFX_PATH)

func _play_rollover_sfx() -> void:
	if _snd_rollover == null or _snd_rollover.stream == null:
		return
	_snd_rollover.pitch_scale = randf_range(0.96, 1.04)
	if _snd_rollover.playing:
		_snd_rollover.stop()
	_snd_rollover.play()

func _setup_score_audio() -> void:
	# Load dedicated score sounds if they exist; always keep a fallback
	for path in SCORE_AUDIO_PATHS:
		if ResourceLoader.exists(path):
			var player := AudioStreamPlayer.new()
			player.stream = load(path)
			add_child(player)
			_score_audio_pool.append(player)
	# Fallback: reuse curio canister sound at varied pitch if no dedicated files found
	if _score_audio_pool.is_empty():
		var fallback := "res://assets/audio/curio_select.wav"
		if ResourceLoader.exists(fallback):
			for _i in range(3):
				var player := AudioStreamPlayer.new()
				player.stream = load(fallback)
				add_child(player)
				_score_audio_pool.append(player)

func _play_score_sound() -> void:
	if _score_audio_pool.is_empty(): return
	var player: AudioStreamPlayer = _score_audio_pool[randi() % _score_audio_pool.size()]
	player.pitch_scale = randf_range(0.82, 1.28)
	if not player.playing:
		player.play()

# ── FX Setup ──────────────────────────────────────────────────────
var _shine_rect: ColorRect
var _strength_flame_material: ShaderMaterial
var _strength_flame_tween: Tween
var _label_shake_tweens: Dictionary = {}

func _setup_strength_flame() -> void:
	if not is_instance_valid(_score_mult):
		return
	if not ResourceLoader.exists(STRENGTH_FLAME_SHADER_PATH):
		return
	var shader := load(STRENGTH_FLAME_SHADER_PATH) as Shader
	if shader == null:
		return
	_strength_flame_material = ShaderMaterial.new()
	_strength_flame_material.shader = shader
	_strength_flame_material.set_shader_parameter("effect_alpha", 0.0)
	_strength_flame_material.set_shader_parameter("aspect_ratio", maxf(_score_mult.size.x / maxf(_score_mult.size.y, 1.0), 0.01))
	_score_mult.material = _strength_flame_material

func _set_strength_flame_alpha(v: float) -> void:
	if _strength_flame_material:
		_strength_flame_material.set_shader_parameter("effect_alpha", clampf(v, 0.0, 1.0))

func _trigger_strength_flame(strength: float) -> void:
	if _strength_flame_material == null:
		return
	if _strength_flame_tween:
		_strength_flame_tween.kill()
	var peak := clampf(0.58 + (strength - 1.0) * 0.28, 0.58, 1.0)
	var hold := clampf(0.2 + (strength - 1.0) * 0.55, 0.2, 1.15)
	var fall := clampf(0.52 + (strength - 1.0) * 0.42, 0.52, 1.4)
	_strength_flame_material.set_shader_parameter("strength_boost", clampf(1.0 + (strength - 1.0) * 0.5, 1.0, 3.0))
	_strength_flame_tween = create_tween()
	# Start when score labels are fading back in and stardrops are converging.
	_strength_flame_tween.tween_interval(0.84)
	_strength_flame_tween.tween_method(_set_strength_flame_alpha, 0.0, peak, 0.12)
	_strength_flame_tween.tween_interval(hold)
	_strength_flame_tween.tween_method(_set_strength_flame_alpha, peak, 0.0, fall)

func _setup_score_shine() -> void:
	_shine_rect = ColorRect.new()
	_shine_rect.color = Color.TRANSPARENT
	_shine_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_banner.add_child(_shine_rect)
	_shine_rect.z_index = -1
	_shine_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := load("res://shaders/radial_shine.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var grad := Gradient.new()
		grad.set_color(0, GameData.ACCENT_GOLD)
		grad.add_point(0.5, Color(1, 1, 0.5))
		grad.add_point(1.0, Color.WHITE)
		var grad_tex := GradientTexture1D.new()
		grad_tex.gradient = grad
		mat.set_shader_parameter("gradient", grad_tex)
		mat.set_shader_parameter("alpha_mul", 0.0)
		mat.set_shader_parameter("speed", 1.2)
		_shine_rect.material = mat

var _confetti_layer: CanvasLayer
var _confetti_rect: ColorRect
var _confetti_tween: Tween
var _rain_layer: CanvasLayer

func _setup_confetti() -> void:
	_confetti_layer = CanvasLayer.new(); _confetti_layer.layer = 100; add_child(_confetti_layer)
	_confetti_rect = ColorRect.new()
	_confetti_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confetti_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confetti_rect.visible = false
	var shader := load("res://shaders/confetti.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new(); mat.shader = shader
		mat.set_shader_parameter("resolution", get_viewport_rect().size)
		mat.set_shader_parameter("alpha_scale", 0.0)
		_confetti_rect.material = mat
	_confetti_layer.add_child(_confetti_rect)
	_rain_layer = CanvasLayer.new(); _rain_layer.layer = 98; add_child(_rain_layer)

func _burst_confetti(duration: float = 4.0) -> void:
	if not _confetti_rect or not _confetti_rect.material: return
	(_confetti_rect.material as ShaderMaterial).set_shader_parameter("resolution", get_viewport_rect().size)
	_confetti_rect.visible = true
	if _confetti_tween: _confetti_tween.kill()
	_confetti_tween = create_tween()
	_confetti_tween.tween_method(func(v:float): (_confetti_rect.material as ShaderMaterial).set_shader_parameter("alpha_scale",v), 0.0, 1.0, 0.25)
	_confetti_tween.tween_interval(duration - 0.75)
	_confetti_tween.tween_method(func(v:float): (_confetti_rect.material as ShaderMaterial).set_shader_parameter("alpha_scale",v), 1.0, 0.0, 0.5)
	_confetti_tween.tween_callback(func(): _confetti_rect.visible = false)

# ── Sprite rain (moondrops) ───────────────────────────────────────
func _rain_moondrops(count: int) -> void:
	if not is_instance_valid(_rain_layer): return
	var vp := get_viewport_rect().size
	var n := clampi(count, 1, 5000)
	for i in range(n):
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sz := randf_range(18.0, 30.0)
		icon.custom_minimum_size = Vector2(sz, sz)
		icon.size = Vector2(sz, sz)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		GameData._set_random_moondrop_frame(icon)
		_rain_layer.add_child(icon)
		var start_x: float = randf() * vp.x
		icon.position = Vector2(start_x, -sz - randf() * 60.0)
		var delay: float = float(i) * randf_range(0.02, 0.09)
		var fall_dur: float = randf_range(0.7, 1.5)
		var end_y: float = vp.y * randf_range(0.35, 0.85)
		var drift_x: float = randf_range(-40.0, 40.0)
		var rot_end: float = randf_range(-PI * 1.5, PI * 1.5)
		var tw: Tween = icon.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(icon, "position", Vector2(start_x + drift_x, end_y), fall_dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(icon, "rotation", rot_end, fall_dur)
		tw.tween_property(icon, "modulate:a", 0.0, 0.3)
		tw.tween_callback(icon.queue_free)

# ── Moonpearls rain (save fx) ─────────────────────────────────────
func _rain_moonpearls(moonpearls_count: int) -> void:
	if not is_instance_valid(_rain_layer): return
	var vp := get_viewport_rect().size
	var n := clampi(int(moonpearls_count / 10.0), 1, 60)
	for i in range(n):
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sz := randf_range(24.0, 40.0)
		icon.custom_minimum_size = Vector2(sz, sz)
		icon.size = Vector2(sz, sz)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		GameData._set_random_moonpearls_frame(icon)
		_rain_layer.add_child(icon)
		var start_x: float = randf() * vp.x
		icon.position = Vector2(start_x, -sz - randf() * 120.0)
		var delay: float = float(i) * randf_range(0.03, 0.12)
		var fall_dur: float = randf_range(1.2, 2.5)
		var end_y: float = vp.y * randf_range(0.5, 1.05)
		var drift_x: float = randf_range(-55.0, 55.0)
		var tw: Tween = icon.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(icon, "position", Vector2(start_x + drift_x, end_y), fall_dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(icon, "rotation", randf_range(-0.6, 0.6), fall_dur)
		tw.parallel().tween_property(icon, "scale", Vector2(1.15, 1.15), fall_dur * 0.5)
		tw.tween_property(icon, "modulate:a", 0.0, 0.45)
		tw.tween_callback(icon.queue_free)

# ── Dice scoring effects: shockwave + score popups ────────────────
# Called after a roll settles with the list of rolled entries.
func _spawn_roll_score_effects(entries: Array) -> void:
	if entries.is_empty(): return
	if not is_instance_valid(_dice_table): return
	var table_rect: Rect2 = _dice_table.get_global_rect()
	var has_score := false
	for entry in entries:
		if entry.final_roll > 0: has_score = true; break
	if not has_score: return

	_play_score_sound()

	var die_index := 0
	for entry in entries:
		if entry.final_roll <= 0:
			continue
		# Scatter each die's effects across the dice table area
		var count: int = entry.count
		for i in range(count):
			var pos := Vector2(
				randf_range(table_rect.position.x + 24.0, table_rect.end.x - 24.0),
				randf_range(table_rect.position.y + 24.0, table_rect.end.y - 24.0)
			)
			var die_col: Color = GameData.DIE_COLORS.get(entry.sides, GameData.FG_COLOR) as Color
			# Shockwave: die-face shape expanding outward
			var face_val: int = entry.results[i] if i < entry.results.size() else entry.final_roll
			_spawn_die_shockwave(pos, face_val, entry.sides, die_col)
			# Score popup: the individual die value as floating die-colored text
			var stagger: float = float(i) * 0.07
			_spawn_score_popup_at(pos, face_val, stagger, die_col)
			# Play sound with increasing pitch (dramatic ramp for ADHD dopamine)
			_play_score_sound_with_pitch(0.85 + 0.15 * die_index)
			die_index += 1

func _play_score_sound_with_pitch(pitch: float) -> void:
	if _score_audio_pool.is_empty():
		return
	var player: AudioStreamPlayer = _score_audio_pool[randi() % _score_audio_pool.size()]
	player.pitch_scale = pitch
	if not player.playing:
		player.play()

func _spawn_die_shockwave(global_pos: Vector2, face_val: int, sides: int, col: Color) -> void:
	var lbl := Label.new()
	# Use pip characters for d6; generic die shape for others
	if sides == 6 and face_val >= 1 and face_val <= 6:
		lbl.text = GameData.DICE_CHARS[face_val - 1]
	else:
		lbl.text = "◈"
	var font_size := 32
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(col, 0.95))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 150
	var scene := get_tree().current_scene
	if scene and scene.has_method("add_overlay_to_stage"):
		scene.call("add_overlay_to_stage", lbl)
	else:
		add_child(lbl)
	# Center the label on pos
	lbl.global_position = global_pos - Vector2(font_size * 0.5, font_size * 0.5)
	lbl.pivot_offset = Vector2(font_size * 0.5, font_size * 0.5)
	lbl.scale = Vector2(0.6, 0.6)
	lbl.modulate.a = 0.95
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(3.2, 3.2), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.45)
	tw.tween_callback(lbl.queue_free)

func _spawn_score_popup_at(global_pos: Vector2, value: int, delay: float = 0.0, col: Color = Color.WHITE) -> void:
	var lbl := Label.new()
	lbl.text = "+%d" % value if value > 0 else str(value)
	lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
	lbl.add_theme_color_override("font_color", col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 160
	lbl.modulate.a = 0.0
	var scene := get_tree().current_scene
	if scene and scene.has_method("add_overlay_to_stage"):
		scene.call("add_overlay_to_stage", lbl)
	else:
		add_child(lbl)
	lbl.global_position = global_pos + Vector2(randf_range(-12.0, 12.0), 0.0)
	var tw: Tween = lbl.create_tween()
	if delay > 0.0: tw.tween_interval(delay)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.12)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector2(randf_range(-8.0, 8.0), -55.0), 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

# ── Core UI ───────────────────────────────────────────────────────
func _apply_styles() -> void:
	_style_panel(_score_banner, GameData.TABLE_FELT, Color("#0d1a35"))
	_style_panel(_left_panel,   Color("#060220"),    Color("#290E7A"))
	_style_panel(_right_panel,  Color("#070120"),    Color("#6F1CB2"))
	_nav_label.add_theme_color_override("font_color",    GameData.ACCENT_GOLD)
	_score_chips.add_theme_color_override("font_color",  GameData.ACCENT_BLUE)
	_score_mult.add_theme_color_override("font_color",    GameData.ACCENT_RED)
	_score_total.add_theme_color_override("font_color",  GameData.ACCENT_GOLD)
	_tasks_header.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
	_curio_canisters_header.add_theme_color_override("font_color",GameData.ACCENT_CURIO_CANISTER)
	
	# Add drop shadows to panel headers
	_add_label_drop_shadow(_tasks_header)
	_add_label_drop_shadow(_curio_canisters_header)

func _add_label_drop_shadow(label: Label) -> void:
	if not is_instance_valid(label):
		return
	# Add shadow effect using label theme properties
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))  # Semi-transparent black shadow
	label.add_theme_constant_override("shadow_offset_x", 2)  # Horizontal offset
	label.add_theme_constant_override("shadow_offset_y", 2)  # Vertical offset

func _connect_buttons() -> void:
	($VBoxContainer/NavBar/BtnPrev as Button).pressed.connect(func(): GameData.advance_day(-1))
	($VBoxContainer/NavBar/BtnNext as Button).pressed.connect(func(): GameData.advance_day(1))
	($VBoxContainer/NavBar/BtnToday as Button).pressed.connect(_go_to_today)
	_roll_all_btn.pressed.connect(_roll_selected_or_all)
	_roll_all_btn.text = "🎲 ROLL ALL"
	_dice_table.connect("roll_finished", _on_table_roll_finished)
	_dice_table.connect("layout_changed", _auto_save_dice_layout)
	call_deferred("_build_play_debug_panel")
	call_deferred("_setup_debug_wrench")

var _refreshing: bool = false
func _refresh() -> void:
	if not is_inside_tree() or _refreshing: return
	_refreshing = true
	Database.ensure_default_tasks_for_profile(GameData.current_profile)
	_sync_tasks_from_db()
	_nav_label.text = GameData.format_date_display()
	_build_task_rows()
	_refreshing = false

func _sync_tasks_from_db() -> void:
	var completed_by_id: Dictionary = {}
	for t in GameData.tasks:
		completed_by_id[int(t.get("id", -1))] = bool(t.get("completed", false))
	var active_curio_canister_by_id: Dictionary = {}
	for r in GameData.curio_canisters:
		active_curio_canister_by_id[int(r.get("id", -1))] = bool(r.get("active", false))

	var new_tasks := []
	for t in Database.get_tasks(GameData.current_profile):
		var tid := int(t.get("id", 0))
		new_tasks.append({
			id = tid,
			task = str(t.get("task", "")),
			difficulty = int(t.get("difficulty", 1)),
			die_sides = int(t.get("die_sides", 6)),
			rituals = t.get("rituals", []),
			consumables = t.get("consumables", []),
			sticker_slots = t.get("sticker_slots", []),
			card_color = str(t.get("card_color", "white")),
			completed = bool(completed_by_id.get(tid, false)),
		})
	GameData.tasks = new_tasks

	var new_curio_canisters := []
	for r in Database.get_curio_canisters(GameData.current_profile):
		var rid := int(r.get("id", 0))
		new_curio_canisters.append({
			id = rid,
			title = str(r.get("title", "?")),
			emoji = str(r.get("emoji", "*")),
			mult = float(r.get("mult", 0.2)),
			image_path = str(r.get("image_path", "")),
			card_color = str(r.get("card_color", "white")),
			active = bool(active_curio_canister_by_id.get(rid, false)),
		})
	GameData.curio_canisters = new_curio_canisters
	_restore_dice_layout()
	_build_curio_canister_cards()
	_update_score()
	call_deferred("_check_reminders")

func _check_reminders() -> void:
	if not is_inside_tree(): return
	var remind_water: bool = bool(Database.get_setting("remind_water", true))
	var remind_food: bool  = bool(Database.get_setting("remind_food", true))
	if not remind_water and not remind_food: return
	for task in GameData.tasks:
		var rolled: bool = GameData.dice_results.has(task.id)
		if not rolled:
			if remind_water and _is_water_task(task):
				return
			if remind_food and _is_eat_task(task):
				return

func _restore_dice_layout() -> void:
	var rec: Variant = Database.get_dice_box_stat(GameData.get_date_string(), GameData.current_profile)
	if rec == null:
		_dice_table.call("reset_table")
		GameData.dice_roll_sides.clear()
		GameData.dice_peak_results.clear()
		_score_overlay_shown_today = false
		return
	# Restore saved dice box (background/skin) selection for this day if present
	var saved_box: String = str(rec.get("dice_box_tex", ""))
	if saved_box != "":
		Database.save_setting("dice_table_bg_tex", saved_box)
		SignalBus.dice_table_bg_changed.emit(saved_box)

	# Always reset the table to prevent dice from appearing rolled on game load
	# The dice results and completed tasks are still restored below
	_dice_table.call("reset_table")
	print("[DEBUG] PlayTab._restore_dice_layout: clearing GameData.dice_results")
	GameData.dice_results.clear()
	GameData.dice_roll_sides.clear()
	GameData.dice_peak_results.clear()
	var rolls_str: String = rec.get("task_rolls", "")
	var active_ids: Array[int] = []
	for part in rolls_str.split("|", false):
		if part.begins_with("J:"):
			active_ids.append(int(part.substr(2)))
		elif ":" in part:
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
	var done_tasks: PackedStringArray = str(rec.get("completed_tasks","")).split(",", false)
	for t in GameData.tasks:
		t.completed = t.task in done_tasks
	for curio_canister in GameData.curio_canisters:
		curio_canister.active = curio_canister.id in active_ids
	# If this day already has rolls, the overlay has already been seen
	_score_overlay_shown_today = not GameData.dice_results.is_empty()

# ─────────────────────────────────────────────────────────────────
#  Tasks
# ─────────────────────────────────────────────────────────────────
func _build_task_rows() -> void:
	for child in _tasks_container.get_children(): child.queue_free()
	_task_rows.clear()
	if GameData.tasks.is_empty():
		var hint := Label.new()
		hint.text = "No tasks yet.\nAdd tasks in Satchel."
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", Color(0.5,0.5,0.5))
		hint.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tasks_container.add_child(hint); return
	for task in GameData.tasks:
		var row := _make_task_row(task)
		if row: _tasks_container.add_child(row)
	call_deferred("_setup_button_feedback")

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

func _legacy_slot_norm_pos(idx: int) -> Vector2:
	var legacy := [
		Vector2(0.20, 0.18),
		Vector2(0.50, 0.14),
		Vector2(0.80, 0.18),
		Vector2(0.20, 0.56),
		Vector2(0.50, 0.56),
		Vector2(0.80, 0.56),
	]
	if idx >= 0 and idx < legacy.size():
		var p: Vector2 = legacy[idx]
		return Vector2(clampf(p.x, 0.0, 1.0), clampf(p.y, 0.0, PLAY_CARD_TOP_RATIO))
	return Vector2(0.5, PLAY_CARD_TOP_RATIO * 0.5)

func _task_sticker_slots(task: Dictionary) -> Array:
	var slots: Array = []
	var raw_slots: Variant = task.get("sticker_slots", [])
	if raw_slots is Array and not (raw_slots as Array).is_empty():
		for slot_value in raw_slots:
			if slots.size() >= 6:
				break
			if slot_value is not Dictionary:
				continue
			var slot: Dictionary = slot_value
			var slot_type := str(slot.get("type", "")).strip_edges()
			var slot_id := str(slot.get("id", "")).strip_edges()
			if slot_id == "" or (slot_type != "ritual" and slot_type != "consumable"):
				continue
			var emoji := ""
			if slot_type == "ritual":
				var ritual_info = GameData.RITUAL_STICKERS.get(slot_id, null)
				if ritual_info:
					emoji = str(ritual_info.emoji)
			elif slot_type == "consumable":
				var consumable_info = GameData.CONSUMABLE_STICKERS.get(slot_id, null)
				if consumable_info:
					emoji = str(consumable_info.emoji)
			var fallback: Vector2 = _legacy_slot_norm_pos(slots.size())
			var norm_x: float = clampf(float(slot.get("x", fallback.x)), 0.0, 1.0)
			var norm_y: float = clampf(float(slot.get("y", fallback.y)), 0.0, PLAY_CARD_TOP_RATIO)
			slots.append({"emoji": emoji, "type": slot_type, "id": slot_id, "x": norm_x, "y": norm_y})
		return slots
	for rid in task.get("rituals", []):
		if slots.size() >= 6:
			break
		var rinfo = GameData.RITUAL_STICKERS.get(rid, null)
		if rinfo:
			var rp: Vector2 = _legacy_slot_norm_pos(slots.size())
			slots.append({"emoji": str(rinfo.emoji), "type": "ritual", "id": str(rid), "x": rp.x, "y": rp.y})
	for cid in task.get("consumables", []):
		if slots.size() >= 6:
			break
		var cinfo = GameData.CONSUMABLE_STICKERS.get(cid, null)
		if cinfo:
			var cp: Vector2 = _legacy_slot_norm_pos(slots.size())
			slots.append({"emoji": str(cinfo.emoji), "type": "consumable", "id": str(cid), "x": cp.x, "y": cp.y})
	return slots

func _default_sticker_texture() -> Texture2D:
	if ResourceLoader.exists(STICKER_DEFAULT_TEXTURE_PATH):
		return load(STICKER_DEFAULT_TEXTURE_PATH) as Texture2D
	return null

func _build_task_sticker_grid(task: Dictionary) -> Control:
	var top := PanelContainer.new()
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(1.0, 1.0, 1.0, 0.28)
	top_style.border_color = Color(0.15, 0.11, 0.08, 0.22)
	top_style.set_border_width_all(1)
	top_style.set_corner_radius_all(6)
	top.add_theme_stylebox_override("panel", top_style)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top_w: float = PLAY_CARD_SIZE.x - 18.0
	var top_h: float = PLAY_CARD_SIZE.y * PLAY_CARD_TOP_RATIO - 18.0
	top.custom_minimum_size = Vector2(0, top_h)

	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(canvas)

	for slot in _task_sticker_slots(task):
		var emoji := str(slot.get("emoji", ""))
		if emoji == "":
			continue
		var sticker_sz: Vector2 = PLAY_CARD_SIZE / 16.0
		var slot_root := Control.new()
		slot_root.custom_minimum_size = sticker_sz
		slot_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex := TextureRect.new()
		tex.texture = _default_sticker_texture()
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_root.add_child(tex)
		var lbl := Label.new()
		lbl.text = emoji
		lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(int(sticker_sz.x)))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_root.add_child(lbl)
		var nx: float = clampf(float(slot.get("x", 0.5)), 0.0, 1.0)
		var ny: float = clampf(float(slot.get("y", PLAY_CARD_TOP_RATIO * 0.5)), 0.0, PLAY_CARD_TOP_RATIO)
		slot_root.position = Vector2(nx * top_w - sticker_sz.x * 0.5, (ny / PLAY_CARD_TOP_RATIO) * top_h - sticker_sz.y * 0.5)
		canvas.add_child(slot_root)
	return top

func _make_task_row(task: Dictionary) -> PanelContainer:
		var tid: int       = task.id
		var sides: int     = GameData.task_die_overrides.get(tid, task.die_sides)
		var done: bool     = GameData.dice_results.has(tid)
		var _die_col: Color = GameData.DIE_COLORS.get(sides, GameData.ACCENT_GOLD) as Color
		var is_eat: bool   = _is_eat_task(task)
		var _is_water: bool = _is_water_task(task)
		var in_hand: bool  = _hand.has(tid)

		var panel := PanelContainer.new()
		var border_col: Color
		if done:
			border_col = READABLE_BORDER_SOFT
		elif in_hand:
			border_col = READABLE_BORDER
		else:
			border_col = READABLE_BORDER
		var bg_col: Color
		if done:
			bg_col = Color(0.80, 0.90, 0.98, 0.12)
		elif in_hand:
			bg_col = Color(0.98, 0.88, 0.46, 0.10)
		else:
			bg_col = Color(0.08, 0.06, 0.04, 0.08)
		_style_card(panel, bg_col, border_col, 2 if in_hand else 1, 16)
		panel.custom_minimum_size = PLAY_CARD_SIZE
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.modulate = Color.WHITE
		# Grey filter: in debug mode, if dice box already rolled today, dim the card
		if GameData.is_debug_mode() and not done:
			var _rolled_today: bool = Database.has_dice_box_record(GameData.get_date_string(), GameData.current_profile)
			if _rolled_today:
				panel.modulate = Color(0.5, 0.5, 0.5, 0.85)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS if done else Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_ARROW if done else Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton:
				var mb := ev as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not done and not _is_rolling:
					# Prepare drag-select state — actual toggle is handled by the CheckBox below
					_drag_select_add = not _hand.has(tid)
					_drag_select_type = "task"
					_drag_selecting = true
					_drag_touched_ids = {tid: true}
				if mb.button_index == MOUSE_BUTTON_RIGHT:
					if mb.pressed:
						_begin_card_drag_nudge(panel, mb.global_position)
					else:
						_end_card_drag_nudge(true)
		)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		panel.add_child(margin)

		var content_v := VBoxContainer.new()
		content_v.add_theme_constant_override("separation", 4)
		margin.add_child(content_v)

		var task_box := TASK_DICE_BOX_VIEW_SCRIPT.new()
		task_box.custom_minimum_size = Vector2(0, 224)
		task_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		task_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		task_box.set_task(task)
		var _room_id := int(task.get("studio_room", -1))
		if _room_id > 0:
			task_box.set_room_composition(StudioRoomManager.get_composition(_room_id))
		task_box.set_preview_scale(0.98)
		task_box.set_camera_size(1.84)
		task_box.set_selected(in_hand and not done)
		task_box.set_completed(done)
		task_box.set_hand_indicator_visible(in_hand and not done)
		task_box.hover_changed.connect(func(is_hovered: bool):
			if is_hovered:
				_play_rollover_sfx()
		)
		# NOTE: task_box clicks previously toggled the task into the hand.
		# Remove that behavior so only the explicit checkbox controls activation.
		content_v.add_child(task_box)
		# Ensure the view-level name inside the preview is hidden and provide
		# a dedicated, high-contrast name label below the preview for Play tab.
		task_box.set_name_label_visible(false)
		var name_lbl := Label.new()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
		name_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
		name_lbl.text = str(task.get("task", "Untitled Task"))
		name_lbl.clip_text = true
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_v.add_child(name_lbl)

		var grow := Control.new()
		grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_v.add_child(grow)

		var hbox := HBoxContainer.new(); hbox.add_theme_constant_override("separation", 4)
		content_v.add_child(hbox)

		var chk := CheckBox.new()
		chk.button_pressed = done or in_hand
		# Use PASS so mouse events flow through to the panel for hover tilt detection.
		# The CheckBox still receives clicks for toggling since it covers the whole card.
		chk.mouse_filter = Control.MOUSE_FILTER_PASS
		chk.toggled.connect(func(pressed: bool):
			if _is_rolling:
				chk.button_pressed = done or in_hand
				return
			_toggle_hand(tid)
			# Sync drag state so subsequent drag uses the correct mode
			_drag_select_add = pressed
		)
		# Make the checkbox invisible but still receive input, and cover the whole card
		chk.text = ""
		chk.self_modulate = Color(1, 1, 1, 0)
		chk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(chk)

		var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info)

		var sub_lbl := Label.new()
		var sticker_text := _task_sticker_text(task)
		sub_lbl.text = "%s  •  %s" % [sticker_text, "⬟".repeat(task.difficulty)] if sticker_text != "" else "difficulty  %s" % "⬟".repeat(task.difficulty)
		sub_lbl.add_theme_color_override("font_color", READABLE_TEXT_MUTED)
		sub_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		info.add_child(sub_lbl)

		var result_lbl := Label.new()
		result_lbl.custom_minimum_size = Vector2(44, 0)
		result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
		if done:
			var rolled_sides: int = GameData.dice_roll_sides.get(tid, sides)
			var peak_val: int = int(GameData.dice_peak_results.get(tid, GameData.dice_results[tid]))
			_display_roll_result(result_lbl, peak_val, rolled_sides)
		elif in_hand:
			result_lbl.text = "d%d" % sides
			result_lbl.add_theme_color_override("font_color", READABLE_TEXT)
		else:
			result_lbl.text = "–"
			result_lbl.add_theme_color_override("font_color", READABLE_TEXT)
		hbox.add_child(result_lbl)

		# Eat/food tasks use the default meal count from Satchel settings.
		if is_eat:
			_eat_meal_count = int(Database.get_setting("default_meals", 1))

		var die_btn := MenuButton.new()
		var shown_sides: int = sides
		var shown_face: int = shown_sides
		shown_face = clampi(shown_face, 1, shown_sides)
		var shown_tex: Texture2D = _get_die_face_texture(shown_sides, shown_face)
		if shown_tex:
			die_btn.icon = shown_tex
			die_btn.text = ""
		else:
			die_btn.icon = null
			die_btn.text = _wire_symbol_for_face(shown_sides, shown_face)
		die_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		die_btn.add_theme_color_override("font_color", READABLE_TEXT)
		die_btn.custom_minimum_size = Vector2(44, 34)
		die_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		die_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		die_btn.expand_icon = true
		die_btn.clip_text = true
		die_btn.flat = false
		var die_popup := die_btn.get_popup()
		die_popup.clear()
		var available_die: Array = [6]
		for s in [8, 10, 12, 20]:
			if GameData.dice_satchel.get(s, 0) > 0: available_die.append(s)
		for i in range(available_die.size()):
			var s: int = available_die[i]
			var suffix := "∞" if s == 6 else "×%d" % GameData.dice_satchel.get(s, 0)
			var face_tex: Texture2D = _get_die_face_texture(s, s)
			if face_tex:
				die_popup.add_icon_item(face_tex, "  %s" % suffix, i)
			else:
				die_popup.add_item("%s  %s" % [_wire_symbol_for_sides(s), suffix], i)
		die_popup.id_pressed.connect(func(idx: int): _set_die_sides(tid, available_die[idx]))
		hbox.add_child(die_btn)

		_set_noninteractive_mouse_ignore(panel)

		_attach_hover_tilt(panel, 3.0, 1.03)
		panel.mouse_entered.connect(_play_rollover_sfx)

		_task_rows[tid] = {panel=panel, box_view=task_box, chk=chk, lbl_result=result_lbl, room_id=_room_id}
		return panel

func _toggle_hand(tid: int) -> void:
	# enforce basic "binding_twine" ritual: click once to satisfy
	for t in GameData.tasks:
		if t.id == tid:
			if "binding_twine" in t.get("rituals", []) and not _rituals_done.get(tid, false):
				_rituals_done[tid] = true
				return
			break
	# normal toggle behaviour
	if _hand.has(tid):
		_hand.erase(tid)
	else:
		_hand[tid] = true
		# If this task was already rolled earlier, clear its previous roll
		# so selecting it will cause a fresh roll when the user presses Roll.
		if GameData.dice_results.has(tid):
			GameData.dice_results.erase(tid)
			GameData.dice_roll_sides.erase(tid)
			GameData.dice_peak_results.erase(tid)
			var tsk = GameData.get_task_by_id(tid)
			if tsk:
				tsk.completed = false
	_update_roll_btn_text()
	_build_task_rows()

## Update _hand silently (no full row rebuild). Updates the visual of the
## affected row directly so the UI stays responsive during a drag sweep.
func _set_hand_silent(tid: int, in_hand: bool) -> void:
	if in_hand:
		_hand[tid] = true
	else:
		_hand.erase(tid)
	var row: Dictionary = _task_rows.get(tid, {})
	if row.is_empty():
		return
	var panel: PanelContainer = row.get("panel", null)
	var box_view: TaskDiceBoxView = row.get("box_view", null)
	if not is_instance_valid(panel):
		return
	var border_col: Color = READABLE_BORDER
	var bg_col: Color     = Color(0.98, 0.88, 0.46, 0.10) if in_hand else Color(0.08, 0.06, 0.04, 0.08)
	_style_card(panel, bg_col, border_col, 2 if in_hand else 1, 16)
	if is_instance_valid(box_view):
		box_view.set_selected(in_hand)
		box_view.set_hand_indicator_visible(in_hand)

func _update_roll_btn_text() -> void:
	var hand_size: int = _hand.size()
	if hand_size > 0:
		_roll_all_btn.text = "🎲 ROLL HAND (%d)" % hand_size
	else:
		_roll_all_btn.text = "🎲 ROLL ALL"

# ── Drag-to-select helpers ──────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not _drag_selecting:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_drag_select()
		return
	_check_drag_select_hover(get_viewport().get_mouse_position())

func _check_drag_select_hover(global_pos: Vector2) -> void:
	if _drag_select_type == "task":
		for tid in _task_rows:
			if _drag_touched_ids.has(tid):
				continue
			var row: Dictionary = _task_rows[tid]
			var panel: PanelContainer = row.get("panel", null)
			if not is_instance_valid(panel):
				continue
			if panel.get_global_rect().has_point(global_pos):
				if not GameData.dice_results.has(tid):
					_drag_touched_ids[tid] = true
					_set_hand_silent(tid, _drag_select_add)
					_update_roll_btn_text()
	elif _drag_select_type == "curio_canister":
		for rid in _curio_canister_cards:
			if _drag_touched_ids.has(rid):
				continue
			var card_data: Dictionary = _curio_canister_cards.get(rid, {})
			var card: Control = card_data.get("card", null)
			if not is_instance_valid(card):
				continue
			if card.get_global_rect().has_point(global_pos):
				_drag_touched_ids[rid] = true
				_set_curio_canister_active_silent(rid, _drag_select_add)

func _end_drag_select() -> void:
	_drag_selecting   = false
	var was_curio_canister: bool = _drag_select_type == "curio_canister"
	_drag_select_type = ""
	_drag_touched_ids = {}
	_build_task_rows()
	if was_curio_canister:
		_build_curio_canister_cards()
		_update_score()
	_update_roll_btn_text()

## Update a curio canister's active state in-place without rebuilding all cards.
## Used during drag-select sweeps so existing card nodes stay valid.
func _set_curio_canister_active_silent(rid: int, active: bool) -> void:
	for r in GameData.curio_canisters:
		if r.id == rid:
			r.active = active
			break
	var card_data: Dictionary = _curio_canister_cards.get(rid, {})
	var card: PanelContainer = card_data.get("card", null)
	var state_lbl = card_data.get("state_lbl", null)
	var title_lbl = card_data.get("title_lbl", null)
	# equip_btn removed
	var emoji_lbl = card_data.get("emoji_lbl", null)
	if not is_instance_valid(card):
		return
	var curio_canister_col: Color = GameData.MULT_COLOR
	var curio_canister_bg: Color  = Color(GameData.CARD_BG, 1.0) if active else READABLE_BG
	var border: Color    = curio_canister_col if active else READABLE_BORDER
	_style_card(card, curio_canister_bg, border, 2 if active else 1, 16)
	card.modulate = Color.WHITE
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					_begin_card_drag_nudge(card, mb.global_position)
				else:
					_end_card_drag_nudge(true)
	)
	if _curio_canister_shader and active:
		var mat := ShaderMaterial.new()
		mat.shader = _curio_canister_shader
		mat.set_shader_parameter("glow_color", Vector4(curio_canister_col.r, curio_canister_col.g, curio_canister_col.b, 1.0))
		mat.set_shader_parameter("speed", 2.2)
		mat.set_shader_parameter("glow_width", 0.14)
		mat.set_shader_parameter("intensity", 0.75)
		card.material = mat
	else:
		card.material = null
	if is_instance_valid(state_lbl):
		state_lbl.text = "ACTIVE" if active else "dormant"
		state_lbl.add_theme_color_override("font_color", curio_canister_col if active else READABLE_TEXT)
	if is_instance_valid(title_lbl):
		title_lbl.add_theme_color_override("font_color", curio_canister_col if active else READABLE_TEXT)
	       # equip_btn removed
	if is_instance_valid(emoji_lbl):
		emoji_lbl.add_theme_color_override("font_color", curio_canister_col if active else READABLE_TEXT)
	if active:
		if _snd_curio_canister and _snd_curio_canister.stream: _snd_curio_canister.play()
		_spawn_rune_burst(rid)

func _is_eat_task(task: Dictionary) -> bool:
	var tl: String = str(task.get("task","")).to_lower()
	return "eat" in tl or ("food" in tl and "eat" in tl) or task.get("task","") == "Eat Food"

func _is_water_task(task: Dictionary) -> bool:
	var tl: String = str(task.get("task","")).to_lower()
	return "water" in tl or "hydrat" in tl or "drink" in tl

# ─────────────────────────────────────────────────────────────────
#  Curio Canisters
# ─────────────────────────────────────────────────────────────────
func _build_curio_canister_cards() -> void:
	for child in _curio_canisters_container.get_children(): child.queue_free()
	_curio_canister_cards.clear()
	if GameData.curio_canisters.is_empty():
		_curio_canisters_container.add_child(_make_empty_deck_card()); return

	var hint := Label.new()
	hint.text = "✦ Click a card to activate its power"
	hint.add_theme_color_override("font_color", Color(GameData.ACCENT_CURIO_CANISTER, 0.55))
	hint.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_curio_canisters_container.add_child(hint)
	for curio_canister in GameData.curio_canisters:
		_curio_canisters_container.add_child(_make_curio_canister_card(curio_canister))

func _make_curio_canister_card(curio_canister: Dictionary) -> Control:
	var curio_canister_col: Color  = GameData.MULT_COLOR
	var is_active: bool   = curio_canister.get("active", false)
	var curio_canister_bg: Color   = Color(GameData.CARD_BG, 1.0) if is_active else READABLE_BG

	var card := PanelContainer.new()
	card.custom_minimum_size = PLAY_CARD_SIZE
	card.pivot_offset = PLAY_CARD_SIZE * 0.5
	card.scale = CURIO_CANISTER_CARD_SCALE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var border: Color = curio_canister_col if is_active else READABLE_BORDER
	_style_card(card, curio_canister_bg, border, 2 if is_active else 1, 16)
	_set_card_base_visual(card, str(curio_canister.get("card_color", "white")))
	var _r_room_id := int(curio_canister.get("studio_room", -1))
	if _r_room_id > 0:
		var tex_rect: TextureRect = card.get_node_or_null("CardBaseTexture") as TextureRect
		if tex_rect != null:
			tex_rect.texture = StudioRoomManager.get_composition(_r_room_id)
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_attach_hover_tilt(card, 3.0, 1.03)
	card.mouse_entered.connect(_play_rollover_sfx)
	# Check if curio canister has been rolled today
	var _curio_rolled_today: bool = Database.has_curio_rolled_today(curio_canister.id, GameData.get_date_string(), GameData.current_profile)
	if _curio_rolled_today:
		# Grey out the card if it has been rolled today
		card.modulate = Color(0.5, 0.5, 0.5, 0.85)
	else:
		card.modulate = Color.WHITE

	if _curio_canister_shader and is_active:
		var mat := ShaderMaterial.new()
		mat.shader = _curio_canister_shader
		mat.set_shader_parameter("glow_color", Vector4(curio_canister_col.r, curio_canister_col.g, curio_canister_col.b, 1.0))
		mat.set_shader_parameter("speed", 2.2)
		mat.set_shader_parameter("glow_width", 0.14)
		mat.set_shader_parameter("intensity", 0.75)
		card.material = mat

	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6 if side in ["left","right"] else 4)
	card.add_child(margin)

	var content_v := VBoxContainer.new()
	content_v.add_theme_constant_override("separation", 4)
	margin.add_child(content_v)

	var strip := PanelContainer.new()
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Color(1.0, 1.0, 1.0, 0.32)
	strip_style.border_color = Color(0.16, 0.12, 0.08, 0.24)
	strip_style.set_border_width_all(1)
	strip_style.set_corner_radius_all(4)
	strip.add_theme_stylebox_override("panel", strip_style)
	strip.custom_minimum_size = Vector2(0, PLAY_CARD_SIZE.y * PLAY_CARD_TOP_RATIO - 18.0)
	content_v.add_child(strip)

	# Curio Canister name label (centered below the preview area)
	var curio_canister_name_lbl := Label.new()
	curio_canister_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	curio_canister_name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	curio_canister_name_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	curio_canister_name_lbl.text = str(curio_canister.get("title", "Curio Canister"))
	curio_canister_name_lbl.clip_text = true
	curio_canister_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_v.add_child(curio_canister_name_lbl)

	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 3)
	strip.add_child(strip_row)
	for i in range(6):
		var slot := Label.new()
		slot.text = ""
		slot.custom_minimum_size = Vector2(18, 0)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
		strip_row.add_child(slot)
	var strip_flex := Control.new()
	strip_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_row.add_child(strip_flex)

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_v.add_child(grow)

	var hbox := HBoxContainer.new(); hbox.add_theme_constant_override("separation", 8)
	content_v.add_child(hbox)

	var emoji_lbl := Label.new()
	emoji_lbl.text = str(curio_canister.get("emoji", "✦" if not curio_canister.get("active",false) else "★"))
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_color_override("font_color", curio_canister_col if is_active else READABLE_TEXT)
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(22))
	emoji_lbl.custom_minimum_size = Vector2(26, 0)
	hbox.add_child(emoji_lbl)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	hbox.add_child(info)

	var title_row := HBoxContainer.new()
	info.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = str(curio_canister.get("title", "?"))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_lbl.add_theme_color_override("font_color", curio_canister_col if is_active else READABLE_TEXT)
	title_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	title_lbl.clip_text = true
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)

	# Multiplier label (star power)
	var mult_lbl := Label.new()
	var mult_val: float = float(curio_canister.get("mult", 0.25))
	mult_lbl.text = "+%.2fx" % mult_val
	mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mult_lbl.add_theme_color_override("font_color", GameData.MULT_COLOR)
	mult_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	mult_lbl.size_flags_horizontal = Control.SIZE_FILL
	title_row.add_child(mult_lbl)

	var state_lbl := Label.new()
	state_lbl.text = "ACTIVE" if is_active else "dormant"
	state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	state_lbl.add_theme_color_override("font_color", curio_canister_col if is_active else READABLE_TEXT)
	state_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	info.add_child(state_lbl)

	# (Removed equip/unequip OptionButton)

	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			# Start a drag-select sweep (also handles single click)
			_drag_select_add   = not curio_canister.get("active", false)
			_drag_select_type  = "curio_canister"
			_drag_selecting    = true
			_drag_touched_ids  = {curio_canister.id: true}
			_set_curio_canister_active_silent(curio_canister.id, _drag_select_add)
	)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_set_noninteractive_mouse_ignore(card)

	_curio_canister_cards[curio_canister.id] = {card = card, state_lbl = state_lbl, title_lbl = title_lbl, emoji_lbl = emoji_lbl, room_id = _r_room_id}
	return card

func _make_deck_stack_hint(count: int) -> Control:
	var wrapper := Control.new(); wrapper.custom_minimum_size = Vector2(0, 14)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.tooltip_text = "Deck stack marker: shows this curio canister list is a stacked set of cards."
	var stacks: int = mini(count - 1, 3)
	for i in range(stacks, 0, -1):
		var ghost := PanelContainer.new(); ghost.custom_minimum_size = Vector2(84, 8)
		ghost.position = Vector2(i * 3, (stacks - i) * 3)
		# Use the current card background color so wireframe matches panel
		_style_card(ghost, GameData.CARD_BG, Color("#290E7A"), 1, 4)
		ghost.modulate.a = 0.5
		wrapper.add_child(ghost)
	return wrapper

func _make_empty_deck_card() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, CURIO_CANISTER_ROW_H)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_card(card, Color("#0d0520"), Color("#290E7A"), 1, 8)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)
	var q := Label.new(); q.text = "?"
	q.add_theme_font_size_override("font_size", GameData.scaled_font_size(22))
	q.add_theme_color_override("font_color", Color(0.25,0.25,0.25))
	q.custom_minimum_size = Vector2(30, 0)
	hbox.add_child(q)
	var hint := Label.new(); hint.text = "No curio canisters. Visit Shop!"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", Color(0.4,0.4,0.4))
	hint.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	hbox.add_child(hint)
	return card

# ─────────────────────────────────────────────────────────────────
#  Rolling
# ─────────────────────────────────────────────────────────────────
func _roll_selected_or_all() -> void:
	print("[PlayTab] _roll_selected_or_all called; _is_rolling=", _is_rolling)
	# Squash-and-stretch the button for satisfying tactile feedback
	if has_node("/root/Juice"):
		get_node("/root/Juice").squash_and_stretch(_roll_all_btn, 0.25)
	if _is_rolling: return

	# Prevent duplicate dice-box rolls for the same day.
	var today: String = GameData.get_date_string()
	var has_record: bool = get_node("/root/Database").has_dice_box_record(today, GameData.current_profile)
	print("[PlayTab] today=", today, " has_dice_box_record=", has_record)
	if has_record and not GameData.is_debug_mode():
		# Also check if dice_results already has data for today — this prevents
		# an inconsistent state where the DB record exists but internal state
		# was cleared (e.g. by a navigation race condition).
		if not GameData.dice_results.is_empty():
			print("PlayTab: dice results already exist for today, skipping roll")
			return
		print("PlayTab: dice box already rolled today")
		return
	# Mark this save as a user-initiated roll so rewards may be awarded
	# (previous behavior only awarded for full "Roll All" when no hand).
	GameData.allow_next_award = true
	print("[PlayTab] marking allow_next_award = true (user-initiated roll)")
	if not _hand.is_empty():
		print("[PlayTab] _hand contents:", _hand)
		var hand_tasks: Array = []
		for tid in _hand.keys():
			print("[PlayTab] checking hand tid:", tid, "type:", typeof(tid))
			var t: Variant = GameData.get_task_by_id(tid)
			if t and not GameData.dice_results.has(tid):
				hand_tasks.append(t)
		print("[PlayTab] collected hand_tasks:", hand_tasks.size())
		print("[PlayTab] dice_results keys:", GameData.dice_results.keys())
		if hand_tasks.is_empty():
			# If the selected hand contains no fresh tasks (they were already
			# rolled), clear the hand and fall through so the button will
			# continue to perform a full "Roll All" of remaining tasks.
			_hand.clear()
			_build_task_rows()
			# fall through to the roll-all path below
		await _roll_hand(hand_tasks)
		_hand.clear()
		_roll_all_btn.text = "🎲 ROLL ALL"
		_build_task_rows()
		return
	# No manual hand selection — roll all incomplete tasks
	var all_tasks: Array = []
	for t in GameData.tasks:
		if not GameData.dice_results.has(int(t.id)):
			all_tasks.append(t)
	print("[PlayTab] collected all_tasks count=", all_tasks.size())
	if all_tasks.is_empty():
		print("[PlayTab] nothing to roll: all_tasks empty")
		return
	# Mark this as a user-initiated "Roll All" so awards are allowed for this persist
	GameData.allow_next_award = true
	# Also ensure no active curio canister has already been used today (skip in debug mode).
	if not GameData.is_debug_mode():
		for r in GameData.curio_canisters:
			if bool(r.get("active", false)):
				if get_node("/root/Database").has_curio_rolled_today(int(r.get("id", -1)), today, GameData.current_profile):
					print("PlayTab: active curio already used today")
					return
	await _roll_hand(all_tasks)
	# Clear hand state after rolling to prevent stale UI selection
	_hand.clear()
	_build_task_rows()
	_roll_all_btn.text = "🎲 ROLL ALL"

func _roll_hand(hand_tasks: Array) -> void:
	if _is_rolling or hand_tasks.is_empty(): return
	_is_rolling = true; _set_roll_buttons_disabled(true)
	_score_total_row.visible = false

	# Reset curio round state
	CurioManager.reset_round_state()

	var all_entries: Array = []
	var is_first_roll: bool = true
	for task in hand_tasks:
		# consume any single-use stickers before the roll
		_consume_task_consumables(task)
		var sides: int = GameData.task_die_overrides.get(task.id, task.die_sides)
		var count: int = max(1, task.difficulty)
		var results: Array = []
		for _i in range(count):
			var r: int = GameData.roll_die(sides)
			if "sloth" in GameData.jokers_owned and randf() < 0.333:
				r = max(r, GameData.roll_die(sides))
			results.append(r)

		# ── Curio Effects: on_roll_start ──────────────────────
		var start_ctx := {
			"dice_results": results,
			"dice_sides": sides,
			"dice_count": count,
			"moondrops": 0,
			"rerolls_gained": 0,
			"roll_count": CurioManager.get_roll_count(),
			"is_first_roll": is_first_roll,
		}
		for curio in CurioManager.get_active_by_trigger("on_roll_start"):
			CurioEffects.apply(curio.effect_key, start_ctx)
		results = start_ctx["dice_results"]

		# ── Curio Effects: on_roll_resolved (ROLL_SHAPING, TRIGGER, PATTERN, SCALING) ──
		var resolved_ctx := {
			"dice_results": results,
			"dice_sides": sides,
			"dice_count": count,
			"moondrops": 0,
			"rerolls_gained": 0,
			"roll_count": CurioManager.get_roll_count(),
			"is_first_roll": is_first_roll,
			"stalactite_stacks": 0,
		}
		for curio in CurioManager.get_active_by_trigger("on_roll_resolved"):
			CurioEffects.apply(curio.effect_key, resolved_ctx)
		results = resolved_ctx["dice_results"]

		var final_roll: int = 0
		for v in results: final_roll += v
		var peak_roll: int = 0
		for v in results:
			peak_roll = maxi(peak_roll, v)

		# Store curio bonuses on the entry for score calculation
		var curio_moondrops: int = int(resolved_ctx["moondrops"]) + int(start_ctx["moondrops"])
		var curio_rerolls: int = int(resolved_ctx["rerolls_gained"]) + int(start_ctx["rerolls_gained"])

		GameData.dice_results[task.id] = final_roll
		GameData.dice_roll_sides[task.id] = sides
		GameData.dice_peak_results[task.id] = peak_roll
		task.completed = true
		all_entries.append({task=task, sides=sides, count=count,
			results=results, final_roll=final_roll, peak_roll=peak_roll,
			curio_moondrops=curio_moondrops, curio_rerolls=curio_rerolls})
		is_first_roll = false

	var total_dice: int = 0
	for e in all_entries: total_dice += e.count
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_dice_clacks(mini(total_dice, 8), 0.05)

	for entry in all_entries:
		print("[PlayTab] calling throw_task_dice for task=", entry.task.task, "sides=", entry.sides, "count=", entry.count)
		_dice_table.call("throw_task_dice", entry.task.task,
			entry.sides, entry.count, entry.results, entry.task.id)

	await _dice_table.roll_finished

	for entry in all_entries:
		var tid: int = entry.task.id
		var row_data: Dictionary = _task_rows.get(tid, {})
		if row_data.has("lbl_result"):
			_display_roll_result(row_data["lbl_result"] as Label, entry.peak_roll, entry.sides)
		if row_data.has("chk"):
			(row_data["chk"] as CheckBox).button_pressed = true
		if row_data.has("panel"):
			_style_panel(row_data["panel"] as PanelContainer, READABLE_BG_DONE, READABLE_BORDER_SOFT)
		if row_data.has("box_view") and is_instance_valid(row_data["box_view"] as TaskDiceBoxView):
			(row_data["box_view"] as TaskDiceBoxView).set_completed(true)
			(row_data["box_view"] as TaskDiceBoxView).set_selected(false)
			(row_data["box_view"] as TaskDiceBoxView).set_hand_indicator_visible(false)

		# Notify other systems that a task has been rolled (matches single-task flow)
		GameData.emit_signal("task_rolled", tid, entry.final_roll, entry.sides)
		var tl: String = str(entry.task.get("task", "")).to_lower()
		if "water" in tl or "hydrat" in tl or "drink" in tl:
			Database.set_water_meter(1.0)
			GameData.emit_signal("water_changed", 1.0)
		if "eat" in tl or "food" in tl:
			Database.set_meals_today(_eat_meal_count)
			GameData.emit_signal("meals_changed", _eat_meal_count)

	# ── Dice Resolution Pipeline (v0.10) ─────────────────────────
	# Build roll packet from entries
	var roll_entries: Array = []
	var total_curio_moondrops: int = 0
	for entry in all_entries:
		roll_entries.append({
			"task_id": entry.task.id,
			"task_name": entry.task.task,
			"sides": entry.sides,
			"results": entry.results,
			"final_roll": entry.final_roll,
			"peak_roll": entry.peak_roll,
		})
		total_curio_moondrops += entry.get("curio_moondrops", 0)
	var roll_packet: Dictionary = _score_engine.build_roll_packet(roll_entries)

	# Add curio moondrops bonuses from active curio effects
	roll_packet["curio_moondrops_bonus"] = total_curio_moondrops

	# Add curio canister strength sources
	var active_curios: Array = GameData.curio_canisters.filter(func(r): return r.active)
	roll_packet["strength_sources"] = _score_engine.curios_to_strength_sources(active_curios)

	# Get HUD target for pearl flight
	var hud_target: Vector2 = _get_moonpearls_target_global_position()
	var table_center: Vector2 = _dice_table.get_global_rect().get_center() if is_instance_valid(_dice_table) else Vector2.ZERO

	# Initialize RewardFXController if needed
	if _reward_fx == null:
		_reward_fx = RewardFXController.new()
		add_child(_reward_fx)

	# Run resolution phases via RewardFXController
	# Phase 1: Spawn moondrops per die
	await _reward_fx.spawn_moondrops(roll_packet, table_center)

	# Phase 2: Merge drops into clusters
	await _reward_fx.animate_merge(roll_packet)

	# Phase 3: Apply multipliers AFTER merge
	_score_engine.apply_multipliers(roll_packet)
	var summary: Dictionary = _score_engine.build_summary(roll_packet)
	# Store curio bonus for use in _update_score()
	_last_curio_bonus = int(summary.get("curio_moondrops_bonus", 0))

	# Phase 3b: Staged counting — chunked number updates with VFX hooks
	var _moondrops_total: int = int(summary.get("multiplied_total", 0))
	var _strength: float = float(summary.get("multiplied_total", 0)) / maxf(float(summary.get("moondrops", 1)), 1.0)
	var _moonpearls: int = int(summary.get("moonpearls", 0))

	# Start all three staged counts in parallel
	var _juice: Node = get_node_or_null("/root/Juice")
	if _juice:
		_juice.staged_count("moondrops", _moondrops_total, 0.10)
		_juice.staged_count("moonpearls", _moonpearls, 0.12)
	else:
		SignalBus.score_preview_updated.emit(
			int(summary.get("moondrops", 0)), _strength, _moondrops_total, _moonpearls)

	# Phase 4: Crystallize clusters into moonpearls
	await _reward_fx.crystallize_pearls(roll_packet, hud_target)

	# Phase 5: Final burst
	await _reward_fx.final_burst(summary, table_center)

	# Emit completion signal
	SignalBus.reward_resolution_complete.emit(summary)

	_is_rolling = false; _set_roll_buttons_disabled(false); _score_total_row.visible = true; _update_score()

	# Mark any active curio canisters as used for today so they cannot be reused.
	var today: String = GameData.get_date_string()
	for r in GameData.curio_canisters:
		if bool(r.get("active", false)):
			get_node("/root/Database").mark_curio_rolled(int(r.get("id", -1)), today, GameData.current_profile)

func _consume_task_consumables(task: Dictionary) -> void:
	var list: Array = task.get("consumables", []).duplicate()
	for cid in list:
		Database.remove_task_sticker(task.id, cid, "consumable")

func _roll_single_task(task: Dictionary) -> void:
	# Prevent duplicate dice-box daily rolls and reused curio canisters.
	# In debug mode, allow re-rolling.
	var today: String = GameData.get_date_string()
	if not GameData.is_debug_mode():
		if get_node("/root/Database").has_dice_box_record(today, GameData.current_profile):
			print("PlayTab: dice box already rolled today")
			return
		for r in GameData.curio_canisters:
			if bool(r.get("active", false)) and get_node("/root/Database").has_curio_rolled_today(int(r.get("id", -1)), today, GameData.current_profile):
				print("PlayTab: active curio already used today")
				return

	_is_rolling = true
	_score_total_row.visible = false
	# consume any consumables first
	_consume_task_consumables(task)
	var tid: int   = task.id
	var is_eat: bool = _is_eat_task(task)
	var sides: int = GameData.task_die_overrides.get(tid, task.die_sides)
	var count: int = max(1, task.difficulty)
	_set_roll_buttons_disabled(true)

	var results: Array = []
	for _i in range(count):
		var r: int = GameData.roll_die(sides)
		if "sloth" in GameData.jokers_owned and randf() < 0.333:
			r = max(r, GameData.roll_die(sides))
		results.append(r)
	var final_roll: int = 0
	for v in results: final_roll += v
	var peak_roll: int = 0
	for v in results:
		peak_roll = maxi(peak_roll, v)
	GameData.dice_results[tid] = final_roll
	GameData.dice_roll_sides[tid] = sides
	GameData.dice_peak_results[tid] = peak_roll
	task.completed = true
	# sticker effects could also alter the final_roll or other state in the future

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_dice_clacks(count, 0.09)
	_dice_table.call("throw_task_dice", task.task, sides, count, results, tid)
	await _dice_table.roll_finished

	var row_data: Dictionary = _task_rows.get(tid, {})
	if row_data.has("lbl_result"): _display_roll_result(row_data["lbl_result"] as Label, peak_roll, sides)
	if row_data.has("chk"):        (row_data["chk"] as CheckBox).button_pressed = true
	if row_data.has("panel"):      _style_panel(row_data["panel"] as PanelContainer, READABLE_BG_DONE, READABLE_BORDER_SOFT)
	if row_data.has("box_view") and is_instance_valid(row_data["box_view"] as TaskDiceBoxView):
		(row_data["box_view"] as TaskDiceBoxView).set_completed(true)
		(row_data["box_view"] as TaskDiceBoxView).set_selected(false)
		(row_data["box_view"] as TaskDiceBoxView).set_hand_indicator_visible(false)

	var tname: String = str(task.get("task","")).to_lower()
	if "water" in tname or "hydrat" in tname or "drink" in tname:
		Database.set_water_meter(1.0)
		GameData.emit_signal("water_changed", 1.0)
	if is_eat:
		Database.set_meals_today(_eat_meal_count)
		GameData.emit_signal("meals_changed", _eat_meal_count)

	# Scoring FX
	_spawn_roll_score_effects([{task=task, sides=sides, count=count, results=results, final_roll=final_roll}])
	# Moondrop reward visual: splash → cluster → crystallize into Moonpearl
	if is_instance_valid(_dice_table):
		var _fx_origin := _dice_table.get_global_rect().get_center()
		var _fx_target := _get_moonpearls_target_global_position()
		var _fx_drops: Array = FXBus.moondrop_splash_particles(_fx_origin, count * 3 + 3)
		FXBus.moondrop_cluster_to_pearl(_fx_drops, _fx_target)

	_is_rolling = false
	_set_roll_buttons_disabled(false)
	_score_total_row.visible = true
	_update_score()
	GameData.emit_signal("task_rolled", tid, final_roll, sides)

func _on_table_roll_finished(_value: int, _sides: int) -> void:
	# Save positions each time any roll group settles so multi-task rolls
	# (which emit roll_finished once per group) always persist final positions.
	_auto_save_dice_layout()


func _set_roll_buttons_disabled(state: bool) -> void:
	_roll_all_btn.disabled = state

func _set_die_sides(task_id: int, new_sides: int) -> void:
	GameData.task_die_overrides[task_id] = new_sides
	Database.update_task(task_id, "die_sides", new_sides)
	_refresh()

func _cycle_die(task_id: int, current_sides: int) -> void:
	var available: Array = [6]
	for s in [8, 10, 12, 20]:
		if GameData.dice_satchel.get(s, 0) > 0: available.append(s)
	var idx: int        = available.find(current_sides)
	var next_sides: int = available[(idx + 1) % available.size()]
	_set_die_sides(task_id, next_sides)

func _toggle_curio_canister(curio_canister_id: int, active: bool) -> void:
	for r in GameData.curio_canisters:
		if r.id == curio_canister_id: r.active = active; break
	if active:
		if _snd_curio_canister and _snd_curio_canister.stream: _snd_curio_canister.play()
		_spawn_rune_burst(curio_canister_id)
	_build_curio_canister_cards()
	_update_score()

func _spawn_rune_burst(curio_canister_id: int) -> void:
	var card_data: Dictionary = _curio_canister_cards.get(curio_canister_id, {})
	if not card_data.has("card"): return
	var card: Control = card_data["card"] as Control
	var curio_canister: Variant = null
	for r in GameData.curio_canisters:
		if r.id == curio_canister_id: curio_canister = r; break
	if not curio_canister: return
	var curio_canister_col: Color = GameData.MULT_COLOR

	var rune_count := randi_range(5, 8)
	for _i in range(rune_count):
		var rune_lbl := Label.new()
		rune_lbl.text = RUNES[randi() % RUNES.size()]
		rune_lbl.add_theme_color_override("font_color", curio_canister_col)
		rune_lbl.add_theme_font_size_override("font_size", randi_range(10, 18))
		rune_lbl.z_index = 200
		rune_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card_center: Vector2 = card.get_global_rect().get_center()
		rune_lbl.global_position = card_center + Vector2(randf_range(-30, 30), randf_range(-20, 10))
		var scene := get_tree().current_scene
		if scene and scene.has_method("add_overlay_to_stage"):
			scene.call("add_overlay_to_stage", rune_lbl)
		else:
			add_child(rune_lbl)
		var tw: Tween = rune_lbl.create_tween()
		var drift := Vector2(randf_range(-25, 25), randf_range(-60, -100))
		tw.tween_property(rune_lbl, "global_position", rune_lbl.global_position + drift, 0.9)
		tw.parallel().tween_property(rune_lbl, "modulate:a", 0.0, 0.9)
		tw.tween_callback(rune_lbl.queue_free)

# ─────────────────────────────────────────────────────────────────
#  Score
# ─────────────────────────────────────────────────────────────────
var _score_tween: Tween
var _scoring: bool = false
var _final_score_overlay: CanvasLayer
var _final_score_label: Label

func _setup_final_score_overlay() -> void:
	_final_score_overlay = CanvasLayer.new()
	_final_score_overlay.layer = 120
	add_child(_final_score_overlay)
	_final_score_label = Label.new()
	_final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_final_score_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_final_score_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(72))
	_final_score_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	_final_score_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_final_score_label.size = Vector2(600, 120)
	_final_score_label.position = Vector2(-300, -60)
	_final_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final_score_label.visible = false
	_final_score_overlay.add_child(_final_score_label)

func _shake_label(lbl: Label, intensity: float = 5.0, duration: float = 0.35) -> void:
	if not is_instance_valid(lbl):
		return
	var key: int = lbl.get_instance_id()
	if _label_shake_tweens.has(key):
		var prev_tw := _label_shake_tweens.get(key) as Tween
		if prev_tw:
			prev_tw.kill()
	lbl.pivot_offset = lbl.size * 0.5
	lbl.rotation_degrees = 0.0
	lbl.scale = Vector2.ONE
	var steps: int = max(1, int(duration / 0.04))
	var shake_tw: Tween = create_tween()
	_label_shake_tweens[key] = shake_tw
	for _i in range(steps):
		shake_tw.tween_property(lbl, "rotation_degrees", randf_range(-intensity, intensity), 0.025)
		shake_tw.parallel().tween_property(lbl, "scale", Vector2.ONE * randf_range(0.97, 1.04), 0.025)
	shake_tw.tween_property(lbl, "rotation_degrees", 0.0, 0.07)
	shake_tw.parallel().tween_property(lbl, "scale", Vector2.ONE, 0.07)
	shake_tw.finished.connect(func():
		if is_instance_valid(lbl):
			lbl.rotation_degrees = 0.0
			lbl.scale = Vector2.ONE
		_label_shake_tweens.erase(key)
	)

func _burst_sparkles_at(world_pos: Vector2, count: int = 12, col: Color = GameData.ACCENT_GOLD) -> void:
	if not is_instance_valid(_rain_layer): return
	for _i in range(count):
		var spark := Label.new()
		spark.text = ["✦","★","⭐","✨","💫","🌟"].pick_random()
		spark.add_theme_font_size_override("font_size", randi_range(16, 30))
		spark.add_theme_color_override("font_color", col)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 200
		var scene := get_tree().current_scene
		if scene and scene.has_method("add_overlay_to_stage"):
			scene.call("add_overlay_to_stage", spark)
		else:
			add_child(spark)
		spark.global_position = world_pos + Vector2(randf_range(-80, 80), randf_range(-40, 40))
		var drift := Vector2(randf_range(-70, 70), randf_range(-120, -40))
		var dur: float = randf_range(0.5, 1.1)
		var tw: Tween = spark.create_tween()
		tw.tween_property(spark, "global_position", spark.global_position + drift, dur)
		tw.parallel().tween_property(spark, "scale", Vector2(1.5, 1.5), dur * 0.4)
		tw.parallel().tween_property(spark, "modulate:a", 0.0, dur)
		tw.tween_callback(spark.queue_free)

func _get_moonpearls_target_global_position() -> Vector2:
	var scene := get_tree().current_scene
	if is_instance_valid(scene) and scene.has_method("get_moonpearls_target_global_position"):
		return scene.call("get_moonpearls_target_global_position") as Vector2
	return _score_chips.get_global_rect().get_center()

func _show_final_score_overlay(final_score: int, strength: float) -> void:
	if not is_instance_valid(_final_score_label): return
	var col: Color = GameData.ACCENT_GOLD
	if strength >= 2.0: col = Color(0.63, 0.92, 0.67)
	elif strength >= 1.5: col = Color(1.0, 0.85, 0.3)
	_final_score_label.text = "✦ %d ✦" % final_score
	_final_score_label.add_theme_color_override("font_color", col)
	_final_score_label.modulate.a = 0.0
	_final_score_label.scale     = Vector2(0.4, 0.4)
	_final_score_label.visible   = true
	var tw: Tween = _final_score_label.create_tween()
	tw.tween_property(_final_score_label, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_final_score_label, "modulate:a", 1.0, 0.15)
	tw.tween_property(_final_score_label, "scale", Vector2(1.0, 1.0), 0.1)
	tw.tween_interval(1.6)
	tw.tween_property(_final_score_label, "modulate:a", 0.0, 0.55)
	tw.tween_callback(func(): _final_score_label.visible = false)
	for delay_s in [0.0, 0.25, 0.55, 0.9]:
		var timer := get_tree().create_timer(delay_s)
		timer.timeout.connect(func():
			var vp: Vector2 = get_viewport_rect().size
			_burst_sparkles_at(Vector2(vp.x * 0.5, vp.y * 0.4),
				int(6 + strength * 4), col))

func _update_score_safe() -> void:
	_scoring = false
	_update_score()

func _update_score() -> void:
	if _is_rolling or _scoring: return
	_scoring = true
	var active_curio_canisters: Array = GameData.curio_canisters.filter(func(r): return r.active)
	var result: Dictionary   = GameData.calculate_score(GameData.dice_results, active_curio_canisters, GameData.jokers_owned)
	var final_score: int = result.score

	# Include curio bonus in stardrops display
	var total_stardrops: int = result.stardrops + _last_curio_bonus
	
	# Count-up animation for ADHD dopamine hit (reads previous value from label text)
	var prev_stardrops: int = _extract_number(_score_chips.text)
	var prev_score: int = _extract_number(_score_total.text)
	
	_score_chips.text = "STARDROPS: %d" % total_stardrops
	_score_mult.text  = "🌟 STAR POWER: x%.2f" % result.star_power
	_score_total.text = "FINAL MOONPEARLS: %d" % final_score
	
	# Animate count-up if values changed and Juice is available
	if has_node("/root/Juice") and (total_stardrops != prev_stardrops or final_score != prev_score):
		var juice = get_node("/root/Juice")
		if total_stardrops != prev_stardrops and total_stardrops > 0:
			juice.count_up(_score_chips, prev_stardrops, total_stardrops, 0.5, "STARDROPS: %d")
		if final_score != prev_score and final_score > 0:
			juice.count_up(_score_total, prev_score, final_score, 0.6, "FINAL MOONPEARLS: %d")
	
	# Update curio bonus display
	if _score_curio_bonus:
		if _last_curio_bonus > 0:
			_score_curio_bonus.text = "🔮 CURIO BONUS: +%d" % _last_curio_bonus
			_score_curio_bonus.visible = true
		else:
			_score_curio_bonus.visible = false
	
	if _strength_flame_material:
		_strength_flame_material.set_shader_parameter("aspect_ratio", maxf(_score_mult.size.x / maxf(_score_mult.size.y, 1.0), 0.01))

	if result.stardrops > 0:
		_shake_label(_score_chips, 4.0 + minf(result.stardrops * 0.5, 8.0))
	if result.star_power > 1.0:
		_shake_label(_score_mult, 3.0 + (result.star_power - 1.0) * 4.0)
		if result.stardrops > 0:
			_trigger_strength_flame(result.star_power)
		else:
			_set_strength_flame_alpha(0.0)
	else:
		_set_strength_flame_alpha(0.0)

	# ── Banner animation ──────────────────────────────────────────
	if _score_tween: _score_tween.kill()
	_score_tween = create_tween()
	if _score_tween:
		_score_total.pivot_offset = _score_total.size * 0.5
		_score_chips.modulate.a = 1.0
		_score_mult.modulate.a  = 1.0
		_score_tween.tween_property(_score_chips, "modulate:a", 0.0, 0.12)
		_score_tween.parallel().tween_property(_score_mult, "modulate:a", 0.0, 0.12)
		_score_tween.parallel().tween_property(_score_total, "scale", Vector2(1.6, 1.6), 0.12)
		_score_tween.tween_property(_score_total, "scale", Vector2(1.35, 1.35), 0.08)
		_score_tween.tween_interval(0.7)
		_score_tween.tween_property(_score_total, "scale", Vector2(1.0, 1.0), 0.18)
		_score_tween.parallel().tween_property(_score_chips, "modulate:a", 1.0, 0.18)
		_score_tween.parallel().tween_property(_score_mult,  "modulate:a", 1.0, 0.18)

	# ── Shine flash ───────────────────────────────────────────────
	if _shine_rect and _shine_rect.material:
		var mat := _shine_rect.material as ShaderMaterial
		var shine_tw: Tween = create_tween()
		shine_tw.tween_method(func(v:float): mat.set_shader_parameter("alpha_mul",v), 0.0, 0.85, 0.15)
		shine_tw.tween_interval(0.6)
		shine_tw.tween_method(func(v:float): mat.set_shader_parameter("alpha_mul",v), 0.85, 0.0, 0.5)

	# Icons are injected once at startup in _ready(), no need to re-inject here
	_scoring = false

	# ── Score label colour ────────────────────────────────────────
	var col: Color = GameData.ACCENT_GOLD
	if final_score == 0:         col = Color(0.5,0.5,0.5)
	elif result.star_power >= 2.0: col = Color(0.63, 0.92, 0.67)
	_score_total.add_theme_color_override("font_color", col)

	# ── Full-screen overlay — only the FIRST roll of this day ─────
	if final_score > 0 and not GameData.moon_overlay_active and not _score_overlay_shown_today:
		_score_overlay_shown_today = true
		_show_final_score_overlay(final_score, result.star_power)

	GameData.emit_signal("score_updated", result.stardrops, result.star_power)
	_scoring = false
	_auto_save_dice_layout()

# ─────────────────────────────────────────────────────────────────
#  Save / Clear / Nav
# ─────────────────────────────────────────────────────────────────
func _auto_save_dice_layout() -> void:
	if not is_inside_tree(): return
	var layout_json: String = _dice_table.call("get_layout") as String
	GameData._persist_current_day(layout_json)

func _build_play_debug_panel() -> void:
	if not GameData.is_debug_mode(): return
	if is_instance_valid(_debug_panel):
		_debug_panel.queue_free()
	_debug_panel = PopupPanel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(GameData.BG_COLOR, 0.98)
	st.border_color = GameData.ACCENT_RED
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	_debug_panel.add_theme_stylebox_override("panel", st)
	add_child(_debug_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_debug_panel.add_child(margin)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 3)
	margin.add_child(dv)
	var hdr := Label.new()
	hdr.text = "🔧  DEBUG TABLE"
	hdr.add_theme_color_override("font_color", GameData.ACCENT_RED)
	hdr.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(hdr)
	_dbg_row_play(dv, [["🔄 Reset Day", _reset_selected_day], ["🧹 Clear Table", _debug_clear_table]])
	_dbg_row_play(dv, [["✅ Complete All", _debug_complete_all], ["➕ Fill Hand", _debug_fill_hand]])
	_dbg_row_play(dv, [["🎲 Quick Roll All", _debug_quick_roll_all], ["🏅 Max All Dice", _debug_max_score]])
	_dbg_row_play(dv, [["💾 Force Save", _auto_save_dice_layout]])

func _dbg_row_play(parent: VBoxContainer, entries: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	for e: Array in entries:
		var b := Button.new()
		b.text = e[0] as String
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		b.pressed.connect(e[1] as Callable)
		row.add_child(b)

func show_dev_popup() -> void:
	if not GameData.is_debug_mode(): return
	if not is_instance_valid(_debug_panel):
		_build_play_debug_panel()
	_debug_panel.popup_centered()

func _toggle_play_debug() -> void:
	show_dev_popup()

func _refresh_play_debug_visibility() -> void:
	pass  # replaced by popup; kept for call-site compat

func _debug_clear_table() -> void:
	if not GameData.is_debug_mode(): return
	_dice_table.call("reset_table")

func _debug_complete_all() -> void:
	if not GameData.is_debug_mode(): return
	for task in GameData.tasks:
		task.completed = true
	_build_task_rows()

func _debug_fill_hand() -> void:
	if not GameData.is_debug_mode(): return
	for task in GameData.tasks:
		if not GameData.dice_results.has(task.id):
			_hand[task.id] = true
	_build_task_rows()
	_update_roll_btn_text()

func _debug_quick_roll_all() -> void:
	if not GameData.is_debug_mode() or _is_rolling: return
	for task in GameData.tasks:
		if not GameData.dice_results.has(task.id):
			var sides: int = GameData.task_die_overrides.get(task.id, task.die_sides)
			var count: int = max(1, task.difficulty)
			var final_roll: int = 0
			var peak: int = 0
			for _i in range(count):
				var r: int = GameData.roll_die(sides)
				final_roll += r
				peak = max(peak, r)
			GameData.dice_results[task.id] = final_roll
			GameData.dice_roll_sides[task.id] = sides
			GameData.dice_peak_results[task.id] = peak
			task.completed = true
	_build_task_rows()
	_update_score()
	_auto_save_dice_layout()

func _debug_max_score() -> void:
	if not GameData.is_debug_mode() or _is_rolling: return
	for task in GameData.tasks:
		if not GameData.dice_results.has(task.id):
			var sides: int = GameData.task_die_overrides.get(task.id, task.die_sides)
			var count: int = max(1, task.difficulty)
			GameData.dice_results[task.id] = sides * count
			GameData.dice_roll_sides[task.id] = sides
			GameData.dice_peak_results[task.id] = sides
			task.completed = true
	_build_task_rows()
	_update_score()
	_auto_save_dice_layout()

func _reset_selected_day() -> void:
	if not GameData.is_debug_mode(): return
	var date_str: String = GameData.get_date_string()
	print("[DEBUG] PlayTab._reset_selected_day: clearing GameData.dice_results")
	GameData.dice_results.clear()
	GameData.dice_roll_sides.clear()
	GameData.dice_peak_results.clear()
	for t in GameData.tasks: t.completed = false
	for r in GameData.curio_canisters: r.active = false
	_hand.clear()
	_score_overlay_shown_today = false
	Database.delete_dice_box_stat(date_str, GameData.current_profile)
	# Clear curio canister rolled flags for this day
	Database.clear_curio_rolled_flags(date_str, GameData.current_profile)
	_dice_table.call("reset_table")
	_build_task_rows()
	_build_curio_canister_cards()
	_update_score()
	GameData.state_changed.emit()

func _go_to_today() -> void:
	var now: Dictionary = Time.get_date_dict_from_system()
	GameData.view_date = {year=now.year, month=now.month, day=now.day}
	# Don't clear dice_results here — let _restore_dice_layout() handle it
	# by reloading from the database for the new date. This prevents a
	# race condition where cleared results cause inconsistent payout display.
	GameData.emit_signal("state_changed")

# ─────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────
func _extract_number(text: String) -> int:
	# Extract the first number from a label like "STARDROPS: 42" or "FINAL MOONPEARLS: 108"
	var regex := RegEx.new()
	regex.compile("\\d+")
	var result := regex.search(text)
	if result:
		return result.get_string().to_int()
	return 0

func _display_roll_result(lbl: Label, value: int, sides: int) -> void:
	if sides == 6 and value >= 1 and value <= 6:
		lbl.text = GameData.DICE_CHARS[value - 1]
	else:
		lbl.text = str(value)
	lbl.add_theme_color_override("font_color", GameData.DIE_COLORS.get(sides, GameData.ACCENT_GOLD) as Color)

func _wire_symbol_for_face(sides: int, face: int) -> String:
	var v := clampi(face, 1, sides)
	if sides == 6:
		return GameData.DICE_CHARS[v - 1]
	return _wire_symbol_for_sides(sides)

func _wire_symbol_for_sides(sides: int) -> String:
	match sides:
		8:  return "◈"
		10: return "◉"
		12: return "⬟"
		20: return "✦"
		_:  return "◇"

func _get_die_face_texture(sides: int, face: int) -> Texture2D:
	var idx: int = clampi(face, 1, sides) - 1
	var custom_key := "%d_%d" % [sides, idx]
	if GameData.die_face_sprites.has(custom_key):
		var custom_path: String = str(GameData.die_face_sprites[custom_key])
		if custom_path != "" and ResourceLoader.exists(custom_path):
			return load(custom_path) as Texture2D
	if DIE_FACE_PATHS.has(sides):
		var default_path: String = (DIE_FACE_PATHS[sides] as String) % (idx + 1)
		if ResourceLoader.exists(default_path):
			return load(default_path) as Texture2D
	return null

func _style_panel(panel: PanelContainer, bg: Color, border: Color = Color("#2a1a4a"), bw: int = 1) -> void:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw); s.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", s)
	_add_panel_shadow(panel)

func _style_card(panel: PanelContainer, bg: Color, border: Color, bw: int, radius: int) -> void:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw); s.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", s)
	_add_panel_shadow(panel)

func _card_base_texture(color_key: String) -> Texture2D:
	var path: String = CARD_BASE_TEXTURES.get(color_key, CARD_BASE_TEXTURES["white"])
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _set_card_base_visual(panel: PanelContainer, color_key: String) -> void:
	if not is_instance_valid(panel):
		return
	var tex_rect: TextureRect = panel.get_node_or_null("CardBaseTexture") as TextureRect
	if tex_rect == null:
		tex_rect = TextureRect.new()
		tex_rect.name = "CardBaseTexture"
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tex_rect)
		panel.move_child(tex_rect, 0)
	tex_rect.texture = _card_base_texture(color_key)

func _add_panel_shadow(panel: PanelContainer) -> void:
	if not is_instance_valid(panel):
		return
	if panel.get_node_or_null("PanelShadow") != null:
		return
	var shadow := ColorRect.new()
	shadow.name = "PanelShadow"
	shadow.color = PANEL_SHADOW_COLOR
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Add shadow as a sibling in the panel's parent so it can sit behind the panel
	var pparent: Node = panel.get_parent()
	if pparent == null:
		# fallback: add as child of panel and position inside
		panel.add_child(shadow)
		shadow.position = PANEL_SHADOW_OFFSET
		shadow.size = panel.size
		shadow.z_index = -1
		panel.resized.connect(func():
			if is_instance_valid(shadow) and is_instance_valid(panel):
				shadow.size = panel.size
		)
		return
	pparent.add_child(shadow)
	# Position/size relative to parent so shadow sits behind the panel
	shadow.position = panel.position + PANEL_SHADOW_OFFSET
	shadow.size = panel.size
	shadow.z_index = panel.z_index - 1
	var idx: int = pparent.get_children().find(panel)
	if idx >= 0:
		pparent.move_child(shadow, idx)
		pparent.move_child(panel, idx + 1)
	# Keep shadow synced when panel moves/resizes
	panel.resized.connect(func():
		if is_instance_valid(shadow) and is_instance_valid(panel):
			shadow.size = panel.size
			shadow.position = panel.position + PANEL_SHADOW_OFFSET
	)

func _on_theme_changed_play() -> void:
	_apply_styles()
	_refresh()

func _on_debug_mode_changed_play(on: bool) -> void:
	if on:
		call_deferred("_build_play_debug_panel")
		call_deferred("_setup_debug_wrench")
	else:
		if is_instance_valid(_debug_panel):
			_debug_panel.hide()
		call_deferred("_remove_debug_wrench")
	call_deferred("_refresh")

func _enter_tree() -> void:
	pass

func _setup_debug_wrench() -> void:
	# Add debug wrench button if in debug mode
	if not GameData.is_debug_mode(): return
	
	# Find the NavBar HBoxContainer
	var nav_bar: HBoxContainer = $VBoxContainer/NavBar
	if nav_bar == null:
		push_warning("PlayTab: Could not find NavBar for debug wrench")
		return
	
	# Check if wrench already exists
	if is_instance_valid(_debug_wrench_btn):
		return
	
	# Create the wrench button
	_debug_wrench_btn = Button.new()
	_debug_wrench_btn.text = "🔧"
	_debug_wrench_btn.tooltip_text = "Open debug panel"
	_debug_wrench_btn.focus_mode = Control.FOCUS_NONE
	_debug_wrench_btn.custom_minimum_size = Vector2(36, 28)
	_debug_wrench_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	_debug_wrench_btn.pressed.connect(_toggle_play_debug)
	
	# Add to the NavBar (at the end)
	nav_bar.add_child(_debug_wrench_btn)

func _remove_debug_wrench() -> void:
	# Remove debug wrench button when debug mode is disabled
	if is_instance_valid(_debug_wrench_btn):
		_debug_wrench_btn.queue_free()
		_debug_wrench_btn = null

func _exit_tree() -> void:
	pass
