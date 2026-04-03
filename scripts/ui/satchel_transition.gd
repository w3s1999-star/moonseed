extends Control

# SatchelTransition.gd – Tactile satchel bag opening animation and overlay
# Manages visual and audio feedback for opening the Satchel tab
# Prevents duplicate playback and handles rapid tab switching

signal transition_finished()

# Audio file paths
const PRESS_SFX_PATH:  String = "res://assets/audio/ui_satchel_press_01.wav"
const CLASP_SFX_PATH:  String = "res://assets/audio/ui_satchel_clasp_01.wav"
const OPEN_SFX_PATH:   String = "res://assets/audio/ui_satchel_open_01.wav"
const REVEAL_SFX_PATH: String = "res://assets/audio/ui_gallery_reveal_01.wav"

# Animation timing (seconds)
const PRESS_DURATION:   float = 0.12
const CLASP_DELAY:      float = 0.06
const FLAP_DURATION:    float = 0.30
const CONTENT_DURATION: float = 0.25
const TOTAL_DURATION:   float = 0.55

# Animation parameters
const FLAP_ROTATION_TARGET: float = PI * 0.5  # 90 degrees open
const BUTTON_SCALE_MIN:     float = 0.92
const BUTTON_SCALE_MAX:     float = 1.05
const CONTENT_OFFSET_UP:    float = 20.0
const DIMMER_ALPHA_TARGET:  float = 0.3

# Node references
var _dimmer:           ColorRect
var _satchel:          Control
var _bag_base:         TextureRect
var _bag_flap:         TextureRect
var _bag_flap_pivot:   Node2D
var _bag_clasp:        TextureRect
var _bag_left_fold:    TextureRect
var _bag_right_fold:   TextureRect
var _inner_cloth:      TextureRect
var _dust_particles:   CPUParticles2D
var _content_root:     Control
var _satchel_content:  Control

# Audio players
var _press_player:     AudioStreamPlayer
var _clasp_player:     AudioStreamPlayer
var _open_player:      AudioStreamPlayer
var _reveal_player:    AudioStreamPlayer

# State
var _is_playing:       bool = false
var _active_tween:     Tween = null
var _left_fold_closed_position:  Vector2 = Vector2.ZERO
var _right_fold_closed_position: Vector2 = Vector2.ZERO
var _content_closed_position:    Vector2 = Vector2.ZERO

func _ready() -> void:
	_cache_nodes()
	_apply_fullscreen_layout()
	_load_audio()
	_reset_state()

func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED:
		return
	_apply_fullscreen_layout()

func _apply_fullscreen_layout() -> void:
	if _satchel == null:
		return
	_satchel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var bag_width: float = viewport_size.x * 0.86
	var bag_height: float = viewport_size.y * 0.78
	var bag_left: float = (viewport_size.x - bag_width) * 0.5
	var bag_top: float = viewport_size.y * 0.14

	if _bag_base:
		_bag_base.position = Vector2(bag_left, bag_top)
		_bag_base.size = Vector2(bag_width, bag_height)

	var fold_width: float = maxf(48.0, bag_width * 0.12)
	if _bag_left_fold:
		_bag_left_fold.position = Vector2(bag_left - fold_width * 0.45, bag_top + bag_height * 0.03)
		_bag_left_fold.size = Vector2(fold_width, bag_height * 0.96)
	if _bag_right_fold:
		_bag_right_fold.position = Vector2(bag_left + bag_width - fold_width * 0.55, bag_top + bag_height * 0.03)
		_bag_right_fold.size = Vector2(fold_width, bag_height * 0.96)

	if _bag_flap_pivot:
		_bag_flap_pivot.position = Vector2(viewport_size.x * 0.5, bag_top + 18.0)
	if _bag_flap:
		_bag_flap.position = Vector2(-bag_width * 0.5, -12.0)
		_bag_flap.size = Vector2(bag_width, bag_height * 0.46)

	if _bag_clasp:
		var clasp_w: float = maxf(40.0, bag_width * 0.06)
		var clasp_h: float = maxf(32.0, bag_height * 0.08)
		_bag_clasp.position = Vector2(viewport_size.x * 0.5 - clasp_w * 0.5, bag_top + bag_height * 0.32)
		_bag_clasp.size = Vector2(clasp_w, clasp_h)

	if _inner_cloth:
		_inner_cloth.position = Vector2(bag_left + bag_width * 0.12, bag_top + bag_height * 0.18)
		_inner_cloth.size = Vector2(bag_width * 0.76, bag_height * 0.62)

	if _dust_particles:
		_dust_particles.position = Vector2(viewport_size.x * 0.5, bag_top + bag_height * 0.32)

	if _content_root:
		_content_closed_position = _content_root.position
	if _bag_left_fold:
		_left_fold_closed_position = _bag_left_fold.position
	if _bag_right_fold:
		_right_fold_closed_position = _bag_right_fold.position

func _cache_nodes() -> void:
	_dimmer          = get_node_or_null("Dimmer") as ColorRect
	_satchel         = get_node_or_null("Satchel") as Control
	_bag_base        = get_node_or_null("Satchel/BagBase") as TextureRect
	_bag_flap        = get_node_or_null("Satchel/BagFlapPivot/BagFlap") as TextureRect
	_bag_flap_pivot  = get_node_or_null("Satchel/BagFlapPivot") as Node2D
	_bag_clasp       = get_node_or_null("Satchel/BagClasp") as TextureRect
	_bag_left_fold   = get_node_or_null("Satchel/BagLeftFold") as TextureRect
	_bag_right_fold  = get_node_or_null("Satchel/BagRightFold") as TextureRect
	_inner_cloth     = get_node_or_null("Satchel/InnerCloth") as TextureRect
	_dust_particles  = get_node_or_null("Satchel/DustParticles") as CPUParticles2D
	_satchel_content = get_node_or_null("SatchelContent") as Control
	_content_root    = get_node_or_null("SatchelContent/ContentRoot") as Control
	if _bag_left_fold:
		_left_fold_closed_position = _bag_left_fold.position
	if _bag_right_fold:
		_right_fold_closed_position = _bag_right_fold.position
	if _content_root:
		_content_closed_position = _content_root.position
	
	_press_player    = get_node_or_null("AudioRoot/PressPlayer") as AudioStreamPlayer
	_clasp_player    = get_node_or_null("AudioRoot/ClaspPlayer") as AudioStreamPlayer
	_open_player     = get_node_or_null("AudioRoot/OpenPlayer") as AudioStreamPlayer
	_reveal_player   = get_node_or_null("AudioRoot/RevealPlayer") as AudioStreamPlayer

func _load_audio() -> void:
	if _press_player and ResourceLoader.exists(PRESS_SFX_PATH):
		_press_player.stream = load(PRESS_SFX_PATH)
	if _clasp_player and ResourceLoader.exists(CLASP_SFX_PATH):
		_clasp_player.stream = load(CLASP_SFX_PATH)
	if _open_player and ResourceLoader.exists(OPEN_SFX_PATH):
		_open_player.stream = load(OPEN_SFX_PATH)
	if _reveal_player and ResourceLoader.exists(REVEAL_SFX_PATH):
		_reveal_player.stream = load(REVEAL_SFX_PATH)

func _reset_state() -> void:
	# Ensure clean initial state before any animation
	if _dimmer:
		_dimmer.color = Color(0, 0, 0, 0)
	if _bag_flap_pivot:
		_bag_flap_pivot.rotation = 0.0
	if _bag_left_fold:
		_bag_left_fold.position = _left_fold_closed_position
	if _bag_right_fold:
		_bag_right_fold.position = _right_fold_closed_position
	if _content_root:
		_content_root.modulate.a = 0.0
		_content_root.position = Vector2(_content_closed_position.x, _content_closed_position.y + CONTENT_OFFSET_UP)
	if _dust_particles:
		_dust_particles.emitting = false
	if _satchel:
		_satchel.scale = Vector2.ONE
		_satchel.modulate = Color.WHITE

func open_satchel() -> void:
	# Guard against duplicate playback
	if _is_playing:
		return
	
	_is_playing = true
	visible = true
	_reset_state()
	
	# Kill any running tween
	if _active_tween:
		_active_tween.kill()
	
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_ease(Tween.EASE_OUT)
	
	# Play press sound at start
	_play_sound(_press_player)
	
	# ─────────────────────────────────────────────────────────────
	# PHASE 1: Button press squash → bounce → settle (0–0.12s)
	# ─────────────────────────────────────────────────────────────
	
	# Squash down (0.06s)
	_active_tween.tween_property(_satchel, "scale", Vector2(BUTTON_SCALE_MIN, BUTTON_SCALE_MIN), PRESS_DURATION * 0.5)
	
	# Play clasp sound at squash point
	_active_tween.tween_callback(func(): _play_sound(_clasp_player))
	
	# Bounce up (0.04s)
	_active_tween.tween_property(_satchel, "scale", Vector2(BUTTON_SCALE_MAX, BUTTON_SCALE_MAX), PRESS_DURATION * 0.33)
	
	# Settle (0.02s)
	_active_tween.tween_property(_satchel, "scale", Vector2.ONE, PRESS_DURATION * 0.17)
	
	# ─────────────────────────────────────────────────────────────
	# PHASE 2 & 3: Flap opens (parallel) + Content reveals (delayed)
	# ─────────────────────────────────────────────────────────────
	
	# Play open sound
	_active_tween.tween_callback(func(): _play_sound(_open_player))
	
	# Run flap animations in parallel
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_dimmer, "color", Color(0, 0, 0, DIMMER_ALPHA_TARGET), FLAP_DURATION * 0.5)
	_active_tween.tween_property(_bag_flap_pivot, "rotation", FLAP_ROTATION_TARGET, FLAP_DURATION)
	_active_tween.tween_property(_bag_left_fold, "position", Vector2(_left_fold_closed_position.x - 18.0, _left_fold_closed_position.y), FLAP_DURATION * 0.6)
	_active_tween.tween_property(_bag_right_fold, "position", Vector2(_right_fold_closed_position.x + 18.0, _right_fold_closed_position.y), FLAP_DURATION * 0.6)
	_active_tween.set_parallel(false)
	
	# Dust burst and reveal sound (staggered during flap)
	_active_tween.tween_callback(func(): _burst_dust())
	_active_tween.tween_callback(func(): _play_sound(_reveal_player)).set_delay(0.15)
	
	# Content reveal animations (run after flap setup callbacks)
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_content_root, "modulate:a", 1.0, CONTENT_DURATION)
	_active_tween.tween_property(_content_root, "position:y", _content_closed_position.y, CONTENT_DURATION)
	_active_tween.tween_property(_inner_cloth, "modulate:a", 0.8, CONTENT_DURATION * 0.5)
	_active_tween.set_parallel(false)
	
	# Completion signal
	_active_tween.tween_callback(func():
		_is_playing = false
		transition_finished.emit()
	)


func _burst_dust() -> void:
	if _dust_particles:
		_dust_particles.emitting = true

func _play_sound(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	if player.playing:
		player.stop()
	player.play()

func quick_button_feedback() -> void:
	# Lightweight feedback for re-pressing the already-active Satchel tab
	# Just a quick button squash without the full animation
	if _is_playing:
		return
	
	if _active_tween:
		_active_tween.kill()
	
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_ease(Tween.EASE_OUT)
	
	_play_sound(_press_player)
	
	# Quick squash: 1.0 -> 0.95 -> 1.0 (0.15s total)
	_active_tween.tween_property(_satchel, "scale", Vector2(0.95, 0.95), 0.08)
	_active_tween.tween_property(_satchel, "scale", Vector2.ONE, 0.07)
