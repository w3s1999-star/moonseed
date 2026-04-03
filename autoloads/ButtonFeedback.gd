extends Node

# ─────────────────────────────────────────────────────────────────
# ButtonFeedback.gd  —  MOONSEED  Standalone  (no addon required)
# Replaces res://addons/button_feedback/button_feedback.gd
#
# Adds tactile scale + parallax + shimmer feedback to every Button.
# Call  ButtonFeedback.setup_recursive(root_node)  once per scene.
# Tabs that build UI in _ready() should call it deferred:
#   call_deferred("_setup_feedback")
#   func _setup_feedback():
#       ButtonFeedback.setup_recursive(self)
#
# Behaviour:
#   • hover  → squish-down-then-bounce (1.0→0.95→1.02→1.0)
#   • press  → scale to 0.94 + theme accent flash
#   • release→ bounce back to 1.0 with spring curve
#   • hover parallax → tiny position shift following cursor
#   • hover shimmer  → light band sweeps across button
# ─────────────────────────────────────────────────────────────────

# ── Hover squish curve ───────────────────────────────────────────
const SQUISH_SCALE  := Vector2(0.95, 0.95)
const OVERSHOOT_SCALE := Vector2(1.02, 1.02)
const HOVER_REST_SCALE := Vector2(1.0, 1.0)
const SQUISH_DUR    := 0.06
const OVERSHOOT_DUR := 0.10
const SETTLE_DUR    := 0.08

# ── Press / release ──────────────────────────────────────────────
const PRESS_SCALE   := Vector2(0.94, 0.94)
const REST_SCALE    := Vector2(1.0,  1.0)
const PRESS_DUR     := 0.06
const RELEASE_DUR   := 0.22

# ── Parallax ─────────────────────────────────────────────────────
const PARALLAX_MAX_OFFSET := 3.0  # max pixels of position shift
const PARALLAX_LERP_SPEED := 10.0

# ── Shimmer ──────────────────────────────────────────────────────
const SHIMMER_DUR := 0.45

# ── State tracking ───────────────────────────────────────────────
var _wired: Dictionary = {}           # instance_id → true (avoid double-connect)
var _hovered: Dictionary = {}         # instance_id → Control (currently hovered buttons)
var _original_positions: Dictionary = {}  # instance_id → Vector2 (pre-parallax position)
var _shimmer_shader: Shader = null
var _shimmer_shader_loaded: bool = false

# ── Art (cached StyleBoxTexture instances) ───────────────────────
var _art_normal:   StyleBoxTexture = null
var _art_hover:    StyleBoxTexture = null
var _art_pressed:  StyleBoxTexture = null
var _art_disabled: StyleBoxTexture = null
var _art_ready:    bool = false

func _ready() -> void:
	set_process(true)

# ── Parallax update (runs every frame) ───────────────────────────
func _process(delta: float) -> void:
	# Guard: skip entirely when no buttons are hovered
	if _hovered.is_empty():
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	for id in _hovered:
		var btn: Control = _hovered[id]
		if not is_instance_valid(btn):
			_hovered.erase(id)
			_original_positions.erase(id)
			continue
		# Skip parallax for buttons inside containers (layout manages their position)
		if btn.get_parent() is Container:
			continue
		var btn_center: Vector2 = btn.global_position + btn.size * 0.5
		var offset: Vector2 = (mouse_pos - btn_center) / maxf(maxf(btn.size.x, btn.size.y), 1.0)
		offset = offset.limit_length(1.0) * PARALLAX_MAX_OFFSET
		var original_pos: Vector2 = _original_positions.get(id, btn.position)
		var target_pos: Vector2 = original_pos + offset
		btn.position = btn.position.lerp(target_pos, clampf(PARALLAX_LERP_SPEED * delta, 0.0, 1.0))

# ── Art helpers ──────────────────────────────────────────────────
func _ensure_art() -> bool:
	if _art_ready:
		return _art_normal != null
	_art_ready = true
	var reg = get_node_or_null("/root/ArtReg")
	if reg == null:
		return false
	for pair: Array in [
		["normal",   "ui_button_secondary_normal"],
		["hover",    "ui_button_secondary_hover"],
		["pressed",  "ui_button_secondary_pressed"],
		["disabled", "ui_button_secondary_disabled"],
	]:
		var tex: Texture2D = reg.texture_for(pair[1])
		if tex == null:
			return false
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.draw_center = true
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.axis_stretch_vertical   = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		match pair[0]:
			"normal":   _art_normal   = sb
			"hover":    _art_hover    = sb
			"pressed":  _art_pressed  = sb
			"disabled": _art_disabled = sb
	return true

func _apply_art(btn: Button) -> void:
	if btn.has_theme_stylebox_override("normal"):
		return
	if not _ensure_art():
		return
	btn.add_theme_stylebox_override("normal",   _art_normal)
	btn.add_theme_stylebox_override("hover",    _art_hover)
	btn.add_theme_stylebox_override("pressed",  _art_pressed)
	btn.add_theme_stylebox_override("disabled", _art_disabled)

# ── Shimmer helpers ──────────────────────────────────────────────
func _load_shimmer_shader() -> Shader:
	if _shimmer_shader_loaded:
		return _shimmer_shader
	_shimmer_shader_loaded = true
	_shimmer_shader = load("res://shaders/button_shimmer.gdshader")
	return _shimmer_shader

func _start_shimmer(btn: Control) -> void:
	var shader: Shader = _load_shimmer_shader()
	if shader == null:
		return
	# Use a child overlay instead of replacing the button's material
	# (replacing material drops the StyleBox rendering, hiding the button)
	var overlay_name := "_ShimmerOverlay"
	var overlay: ColorRect = btn.get_node_or_null(overlay_name) as ColorRect
	if overlay == null:
		overlay = ColorRect.new()
		overlay.name = overlay_name
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color(1, 1, 1, 0)  # transparent — shader draws everything
		var mat := ShaderMaterial.new()
		mat.shader = shader
		overlay.material = mat
		btn.add_child(overlay)
	# Size overlay to match button
	overlay.position = Vector2.ZERO
	overlay.size = btn.size
	overlay.z_index = 10  # draw on top
	# Tween the shimmer sweep
	var mat: ShaderMaterial = overlay.material as ShaderMaterial
	mat.set_shader_parameter("progress", 0.0)
	var tw := create_tween()
	tw.tween_method(func(p: float): mat.set_shader_parameter("progress", p), 0.0, 1.0, SHIMMER_DUR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _clear_shimmer(btn: Control) -> void:
	var overlay_name := "_ShimmerOverlay"
	var overlay: Node = btn.get_node_or_null(overlay_name)
	if overlay != null:
		overlay.queue_free()

# ── Public API ───────────────────────────────────────────────────

func setup_recursive(root: Node) -> void:
	_wire_node(root)
	for child in root.get_children():
		setup_recursive(child)

# ── Internal ─────────────────────────────────────────────────────

func _wire_node(node: Node) -> void:
	if not (node is Button or node is LinkButton): return
	var id: int = node.get_instance_id()
	if _wired.has(id): return
	_wired[id] = true

	# Apply button art to every Button that hasn't been explicitly styled already
	if node is Button:
		_apply_art(node as Button)

	# Ensure pivot is centred so scale animates from the middle
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size * 0.5

	# Add a subtle drop shadow for buttons/menus that live inside a PanelContainer
	if node is Button or node is MenuButton or node is OptionButton or node is PopupMenu:
		var ancestor: Node = node.get_parent()
		var in_panel: bool = false
		while ancestor != null:
			if ancestor is PanelContainer:
				in_panel = true
				break
			ancestor = ancestor.get_parent()
		if in_panel:
			var parent: Node = node.get_parent()
			if parent != null:
				var shadow_name := "DropShadow_%d" % id
				if parent.get_node_or_null(shadow_name) == null:
					var shadow := ColorRect.new()
					shadow.name = shadow_name
					shadow.color = Color(0, 0, 0, 0.12)
					shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
					shadow.position = (node as Control).position + Vector2(6, 6)
					shadow.size = (node as Control).size
					parent.add_child(shadow)
					var idx: int = parent.get_children().find(node)
					if idx >= 0:
						parent.move_child(shadow, idx)
						parent.move_child(node, idx + 1)
					(node as Control).resized.connect(func():
						if is_instance_valid(shadow) and is_instance_valid(node):
							shadow.position = (node as Control).position + Vector2(6, 6)
							shadow.size = (node as Control).size
					)

	node.mouse_entered.connect(_on_hover.bind(node))
	node.mouse_exited.connect(_on_rest.bind(node))
	node.button_down.connect(_on_press.bind(node))
	node.button_up.connect(_on_release.bind(node))

	# Re-centre pivot when size changes (layout pass)
	node.resized.connect(func():
		if is_instance_valid(node):
			(node as Control).pivot_offset = (node as Control).size * 0.5
	)

func _on_hover(btn: Control) -> void:
	if not is_instance_valid(btn): return
	var id: int = btn.get_instance_id()

	# Store original position for parallax return
	_original_positions[id] = btn.position
	_hovered[id] = btn

	# Squish-then-bounce hover: 1.0 → 0.95 → 1.02 → 1.0
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", SQUISH_SCALE, SQUISH_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(btn, "scale", OVERSHOOT_SCALE, OVERSHOOT_DUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", HOVER_REST_SCALE, SETTLE_DUR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Trigger shimmer sweep
	_start_shimmer(btn)

func _on_rest(btn: Control) -> void:
	if not is_instance_valid(btn): return
	var id: int = btn.get_instance_id()

	# Remove from parallax tracking
	_hovered.erase(id)

	# Smooth position return (skip for container-managed buttons)
	var original_pos: Vector2 = _original_positions.get(id, btn.position)
	_original_positions.erase(id)
	if not (btn.get_parent() is Container):
		var tw := btn.create_tween()
		tw.tween_property(btn, "position", original_pos, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Scale return
	var tw2 := btn.create_tween()
	tw2.tween_property(btn, "scale", REST_SCALE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Clear shimmer
	_clear_shimmer(btn)

func _on_press(btn: Control) -> void:
	if not is_instance_valid(btn): return
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", PRESS_SCALE, PRESS_DUR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_release(btn: Control) -> void:
	if not is_instance_valid(btn): return
	var tw := btn.create_tween()
	# Slight overshoot spring
	tw.tween_property(btn, "scale", OVERSHOOT_SCALE * 1.04, RELEASE_DUR * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", HOVER_REST_SCALE, RELEASE_DUR * 0.6).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
