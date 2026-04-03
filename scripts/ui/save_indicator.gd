extends CanvasLayer

## SaveIndicator — Non-blocking save indicator in bottom-right corner
## Shows bouncing save icon briefly after a save, then fades out automatically.

var _texture_rect: TextureRect
var _hide_tween: Tween
var _bounce_tween: Tween

const DISPLAY_DURATION := 2.0
const FADE_DURATION := 0.4
const BOUNCE_HEIGHT := 5.0
const BOUNCE_DURATION := 0.6

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

	# Listen for save events
	if Engine.has_singleton("SignalBus"):
		SignalBus.score_saved.connect(_on_score_saved)

func _build_ui() -> void:
	# Load save texture
	var save_texture: Texture2D = load("res://assets/ui/save.png")
	if save_texture == null:
		# Fallback: create empty texture if file not found
		print("Warning: Could not load save.png texture")
		return

	# Create texture rect anchored to bottom-right
	_texture_rect = TextureRect.new()
	_texture_rect.texture = save_texture
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_texture_rect.offset_left = -100
	_texture_rect.offset_top = -44
	_texture_rect.offset_right = -16
	_texture_rect.offset_bottom = -12
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_texture_rect)

func _on_score_saved(_final_score: int, _moonpearls_delta: int) -> void:
	_show_indicator()

func _show_indicator() -> void:
	if _texture_rect == null:
		return

	# Kill any existing hide tween
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()

	# Kill any existing bounce tween
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()

	visible = true
	_texture_rect.modulate.a = 0.0

	# Fade in
	var tw := create_tween()
	tw.tween_property(_texture_rect, "modulate:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)

	# Start bounce animation
	_start_bounce()

	# Wait, then fade out
	_hide_tween = create_tween()
	_hide_tween.tween_interval(DISPLAY_DURATION)
	_hide_tween.tween_property(_texture_rect, "modulate:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	_hide_tween.tween_callback(_on_hide_complete)

func _start_bounce() -> void:
	if _texture_rect == null:
		return

	var start_y := _texture_rect.offset_top
	var bounce_y := start_y - BOUNCE_HEIGHT

	_bounce_tween = create_tween().set_loops()
	_bounce_tween.tween_property(_texture_rect, "offset_top", bounce_y, BOUNCE_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_texture_rect, "offset_top", start_y, BOUNCE_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Also adjust bottom offset to maintain size
	_bounce_tween.parallel().tween_property(_texture_rect, "offset_bottom", _texture_rect.offset_bottom - BOUNCE_HEIGHT, BOUNCE_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_texture_rect, "offset_bottom", _texture_rect.offset_bottom, BOUNCE_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _on_hide_complete() -> void:
	# Stop bounce animation
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	visible = false