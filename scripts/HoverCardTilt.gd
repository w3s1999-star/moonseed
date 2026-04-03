extends Control

@export var enabled: bool = true
@export var max_tilt_degrees: float = 3.0
@export var hover_scale: float = 1.03
@export var rotate_lerp_speed: float = 12.0
@export var scale_lerp_speed: float = 10.0
@export var idle_wobble_degrees: float = 0.0
@export var idle_wobble_speed: float = 1.5
@export var hover_wobble_degrees: float = 0.0
@export var hover_wobble_speed: float = 7.0
@export var shader_mouse_clamp: float = 2000.0

var _is_hovered: bool = false
var _time: float = 0.0

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_on_resized)
	_on_resized()
	set_process(true)

func _on_resized() -> void:
	pivot_offset = size * 0.5

func _on_mouse_entered() -> void:
	if enabled:
		_is_hovered = true

func _on_mouse_exited() -> void:
	_is_hovered = false

func _process(delta: float) -> void:
	# Guard: skip processing when disabled and not hovered
	if not enabled:
		if _is_hovered or rotation != 0.0 or scale != Vector2.ONE:
			rotation = lerp_angle(rotation, 0.0, clampf(rotate_lerp_speed * delta, 0.0, 1.0))
			scale = scale.lerp(Vector2.ONE, clampf(scale_lerp_speed * delta, 0.0, 1.0))
			_apply_shader_hover(false)
		return

	# Guard: skip when not hovered and no idle wobble needed
	if not _is_hovered and idle_wobble_degrees <= 0.0:
		# Still need to reset rotation/scale if they drifted
		if rotation != 0.0 or scale != Vector2.ONE:
			rotation = lerp_angle(rotation, 0.0, clampf(rotate_lerp_speed * delta, 0.0, 1.0))
			scale = scale.lerp(Vector2.ONE, clampf(scale_lerp_speed * delta, 0.0, 1.0))
		return

	_time += delta
	var target_rot: float = 0.0
	if _is_hovered and size.x > 0.0:
		var half: Vector2 = size * 0.5
		var local: Vector2 = get_local_mouse_position()
		var nx: float = clampf((local.x - half.x) / maxf(half.x, 1.0), -1.0, 1.0)
		var wobble_deg: float = sin(_time * hover_wobble_speed) * hover_wobble_degrees
		target_rot = deg_to_rad((-nx * max_tilt_degrees) + wobble_deg)
	elif idle_wobble_degrees > 0.0:
		target_rot = deg_to_rad(sin(_time * idle_wobble_speed) * idle_wobble_degrees)

	rotation = lerp_angle(rotation, target_rot, clampf(rotate_lerp_speed * delta, 0.0, 1.0))
	var target_scale := Vector2.ONE * (hover_scale if _is_hovered else 1.0)
	scale = scale.lerp(target_scale, clampf(scale_lerp_speed * delta, 0.0, 1.0))
	_apply_shader_hover(_is_hovered)

func _apply_shader_hover(hovering: bool) -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return

	if _shader_has_param(mat, "hovering"):
		mat.set_shader_parameter("hovering", 1.0 if hovering else 0.0)

	if _shader_has_param(mat, "mouse_screen_pos"):
		var mouse_vec := (get_global_mouse_position() - (global_position + size * 0.5)) * 2.0
		mouse_vec = mouse_vec.clamp(Vector2(-shader_mouse_clamp, -shader_mouse_clamp), Vector2(shader_mouse_clamp, shader_mouse_clamp))
		mat.set_shader_parameter("mouse_screen_pos", mouse_vec)

func _shader_has_param(mat: ShaderMaterial, param_name: String) -> bool:
	if mat.shader == null:
		return false
	for u in mat.shader.get_shader_uniform_list():
		if str(u.get("name", "")) == param_name:
			return true
	return false
