extends CanvasLayer

# ─────────────────────────────────────────────────────────────────
# TabTransition.gd – Fractal noise transition between tabs
# 
# Uses pixelated warped fractal noise shader for a dynamic wipe effect.
# Progress 0→0.5: noise covers screen (wipe in)
# Progress 0.5→1.0: noise dissipates (wipe out)
# ─────────────────────────────────────────────────────────────────

var _overlay:    ColorRect
var _tween:      Tween
var _pending_cb: Callable

const WIPE_DURATION := 0.5  # seconds for each half of the wipe

func _ready() -> void:
	layer = 10
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	
	# Apply fractal noise shader
	var shader := load("res://shaders/fractal_noise_transition.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("progress", 0.0)
		mat.set_shader_parameter("background_threshold", 0.0)
		mat.set_shader_parameter("color_threshold", 0.24)
		_overlay.material = mat
	else:
		# Fallback: plain black if shader fails to load
		_overlay.color = Color.BLACK
	
	add_child(_overlay)

## Fractal noise transition: wipe in with noise, call callback, wipe out.
## cb is called at midpoint (screen fully covered by noise).
func wipe(cb: Callable) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_pending_cb = cb
	_overlay.visible = true
	
	# Randomize seed for visual variety each transition
	if _overlay.material is ShaderMaterial:
		_overlay.material.set_shader_parameter("seed", randf())
	
	# Wipe in: progress 0.0 → 0.5 (noise covers screen)
	_tween = get_tree().create_tween()
	_tween.tween_method(_update_shader_progress, 0.0, 0.5, WIPE_DURATION)
	
	# At midpoint, switch the tab
	_tween.tween_callback(func():
		if _pending_cb.is_valid():
			_pending_cb.call()
			_pending_cb = Callable()
	)
	
	# Wipe out: progress 0.5 → 1.0 (noise dissipates)
	_tween.tween_method(_update_shader_progress, 0.5, 1.0, WIPE_DURATION)
	
	# Hide after done
	_tween.tween_callback(func():
		_overlay.visible = false
	)

## Updates shader progress and dynamically adjusts thresholds
func _update_shader_progress(value: float) -> void:
	if not _overlay.material is ShaderMaterial:
		return
	_overlay.material.set_shader_parameter("progress", value)
	_overlay.material.set_shader_parameter(
		"background_threshold",
		abs(1.0 - value * 2.0) - 0.5
	)
	_overlay.material.set_shader_parameter(
		"color_threshold",
		min(1.0, abs(-4.0 + value * 8.0)) * 0.48
	)
