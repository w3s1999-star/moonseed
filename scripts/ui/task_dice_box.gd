extends Node3D

signal activated(task_id: int)
signal hover_changed(is_hovered: bool)

const BASE_WOOD_COLOR := Color("#cb9b67")
const LID_WOOD_COLOR := Color("#ddb27c")
const HARDWARE_COLOR := Color("#8d5a33")
const OUTLINE_COLOR := Color("#f8f3ea")
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.22)
const ACCENT_TINTS := {
	"white": Color("#d6b58a"),
	"blue": Color("#8daec8"),
	"green": Color("#8baa77"),
	"brown": Color("#9a6840"),
}
const DIE_FACE_PATHS := {
	6: "res://assets/textures/dice/d6_basic/d6_basic_%02d.png",
	8: "res://assets/textures/dice/d8_basic/d8_basic_%02d.png",
	10: "res://assets/textures/dice/d10_basic/d10_basic_%02d.png",
	12: "res://assets/textures/dice/d12_basic/d12_basic_%02d.png",
	20: "res://assets/textures/dice/d20_basic/d20_basic_%02d.png",
}
const BASE_ROTATION_Y := 30.0
const HOVER_ROTATION_DELTA := 9.0
const HOVER_SCALE := 1.05
const SELECTED_SCALE := 1.03
const FLOAT_LIFT := 0.07
const NAME_LINE_LIMIT := 14
const NAME_LINE_COUNT := 2

static var _shared_body_mesh: CylinderMesh
static var _shared_lid_mesh: CylinderMesh
static var _shared_lip_mesh: CylinderMesh
static var _shared_hardware_plate_mesh: BoxMesh
static var _shared_hardware_clasp_mesh: BoxMesh
static var _shared_knob_mesh: CylinderMesh
static var _shared_shadow_mesh: CylinderMesh
static var _die_icon_cache: Dictionary = {}

var _task_data: Dictionary = {}
var _task_id: int = -1
var _hovered: bool = false
var _selected: bool = false
var _completed: bool = false
var _scale_multiplier: float = 1.0
var _body_material: StandardMaterial3D
var _lid_material: StandardMaterial3D
var _lip_material: StandardMaterial3D
var _hardware_material: StandardMaterial3D
var _outline_material: StandardMaterial3D
var _shadow_material: StandardMaterial3D
var _body_base_color: Color = BASE_WOOD_COLOR
var _lid_base_color: Color = LID_WOOD_COLOR
var _lip_base_color: Color = BASE_WOOD_COLOR.darkened(0.14)

@onready var _visual_root: Node3D = $VisualRoot
@onready var _body_mesh: MeshInstance3D = $VisualRoot/BodyMesh
@onready var _body_outline_mesh: MeshInstance3D = $VisualRoot/BodyOutlineMesh
@onready var _lid_mesh: MeshInstance3D = $VisualRoot/LidMesh
@onready var _lid_outline_mesh: MeshInstance3D = $VisualRoot/LidOutlineMesh
@onready var _lip_mesh: MeshInstance3D = $VisualRoot/LipMesh
@onready var _hardware_plate_mesh: MeshInstance3D = $VisualRoot/HardwarePlateMesh
@onready var _hardware_clasp_mesh: MeshInstance3D = $VisualRoot/HardwareClaspMesh
@onready var _knob_mesh: MeshInstance3D = $VisualRoot/KnobMesh
@onready var _shadow_mesh: MeshInstance3D = $VisualRoot/ShadowMesh
@onready var _task_name_label: Label3D = $VisualRoot/TaskName
@onready var _difficulty_label: Label3D = $VisualRoot/Difficulty
@onready var _die_type_label: Label3D = $VisualRoot/DieTypeLabel
@onready var _die_icon: Sprite3D = $VisualRoot/DieTypeIcon
@onready var _interaction_area: Area3D = $Area3D
@onready var _collision_shape: CollisionShape3D = $Area3D/CollisionShape3D

func _ready() -> void:
	_ensure_shared_resources()
	_body_material = _make_body_material()
	_lid_material = _make_lid_material()
	_lip_material = _make_lip_material()
	_hardware_material = _make_hardware_material()
	_outline_material = _make_outline_material()
	_shadow_material = _make_shadow_material()
	_body_mesh.mesh = _shared_body_mesh
	_body_mesh.material_override = _body_material
	_body_outline_mesh.mesh = _shared_body_mesh
	_body_outline_mesh.material_override = _outline_material
	_lid_mesh.mesh = _shared_lid_mesh
	_lid_mesh.material_override = _lid_material
	_lid_outline_mesh.mesh = _shared_lid_mesh
	_lid_outline_mesh.material_override = _outline_material
	_lip_mesh.mesh = _shared_lip_mesh
	_lip_mesh.material_override = _lip_material
	_hardware_plate_mesh.mesh = _shared_hardware_plate_mesh
	_hardware_plate_mesh.material_override = _hardware_material
	_hardware_clasp_mesh.mesh = _shared_hardware_clasp_mesh
	_hardware_clasp_mesh.material_override = _hardware_material
	_knob_mesh.mesh = _shared_knob_mesh
	_knob_mesh.material_override = _hardware_material
	_shadow_mesh.mesh = _shared_shadow_mesh
	_shadow_mesh.material_override = _shadow_material
	_body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_body_outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lid_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_lid_outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lip_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_hardware_plate_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_hardware_clasp_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_knob_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_task_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_difficulty_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_die_type_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_die_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var hit_shape := BoxShape3D.new()
	hit_shape.size = Vector3(1.95, 1.18, 1.9)
	_collision_shape.shape = hit_shape
	_update_visual_state(true)
	# Apply theme colours for labels and update on theme changes
	if GameData != null and GameData.has_method("apply_theme"):
		if has_node("/root/SignalBus"):
			SignalBus.theme_changed.connect(_on_theme_changed_taskdice)
		_apply_label_theme()

func _process(delta: float) -> void:
	var scale_target := _scale_multiplier
	if _selected:
		scale_target *= SELECTED_SCALE
	if _hovered:
		scale_target *= HOVER_SCALE
	var target_scale := Vector3.ONE * scale_target
	_visual_root.scale = _visual_root.scale.lerp(target_scale, minf(1.0, delta * 10.0))
	var target_rot_y := deg_to_rad(BASE_ROTATION_Y + (HOVER_ROTATION_DELTA if _hovered else 0.0))
	_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, target_rot_y, minf(1.0, delta * 9.0))
	var target_y := FLOAT_LIFT if (_hovered or _selected) else 0.0
	_visual_root.position.y = lerpf(_visual_root.position.y, target_y, minf(1.0, delta * 8.0))

func set_task(task_data: Dictionary) -> void:
	_task_data = task_data.duplicate(true)
	_task_id = int(_task_data.get("id", -1))
	var task_name := str(_task_data.get("task", "Untitled Task"))
	if _is_water_task(task_name):
		task_name += "  💧"
	elif _is_eat_task(task_name):
		task_name += "  🍽"
	_task_name_label.text = _wrap_task_name(task_name)
	var difficulty := clampi(int(_task_data.get("difficulty", 1)), 1, 5)
	_difficulty_label.text = "⬟".repeat(difficulty)
	var sides := int(_task_data.get("die_sides", 6))
	_die_type_label.text = "d%d" % sides
	var die_icon_texture := _load_die_icon(sides)
	_die_icon.texture = die_icon_texture
	_die_icon.visible = die_icon_texture != null
	_update_material_tint(str(_task_data.get("card_color", "white")))
	_update_visual_state(true)

func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_update_visual_state(false)

func set_completed(value: bool) -> void:
	if _completed == value:
		return
	_completed = value
	_update_visual_state(false)

func set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	hover_changed.emit(_hovered)
	_update_visual_state(false)

func set_scale_multiplier(value: float) -> void:
	_scale_multiplier = maxf(0.4, value)

func request_activation() -> void:
	if _task_id < 0:
		return
	activated.emit(_task_id)
	if SignalBus != null and SignalBus.has_signal("moondrop_completed"):
		SignalBus.moondrop_completed.emit(_task_id)

func get_interaction_area() -> Area3D:
	return _interaction_area

func _ensure_shared_resources() -> void:
	if _shared_body_mesh == null:
		_shared_body_mesh = CylinderMesh.new()
		_shared_body_mesh.top_radius = 0.9
		_shared_body_mesh.bottom_radius = 0.9
		_shared_body_mesh.height = 0.56
		_shared_body_mesh.radial_segments = 6
		_shared_body_mesh.rings = 1
	if _shared_lid_mesh == null:
		_shared_lid_mesh = CylinderMesh.new()
		_shared_lid_mesh.top_radius = 0.96
		_shared_lid_mesh.bottom_radius = 0.88
		_shared_lid_mesh.height = 0.3
		_shared_lid_mesh.radial_segments = 6
		_shared_lid_mesh.rings = 1
	if _shared_lip_mesh == null:
		_shared_lip_mesh = CylinderMesh.new()
		_shared_lip_mesh.top_radius = 0.83
		_shared_lip_mesh.bottom_radius = 0.83
		_shared_lip_mesh.height = 0.05
		_shared_lip_mesh.radial_segments = 6
		_shared_lip_mesh.rings = 1
	if _shared_hardware_plate_mesh == null:
		_shared_hardware_plate_mesh = BoxMesh.new()
		_shared_hardware_plate_mesh.size = Vector3(0.34, 0.24, 0.06)
	if _shared_hardware_clasp_mesh == null:
		_shared_hardware_clasp_mesh = BoxMesh.new()
		_shared_hardware_clasp_mesh.size = Vector3(0.14, 0.22, 0.08)
	if _shared_knob_mesh == null:
		_shared_knob_mesh = CylinderMesh.new()
		_shared_knob_mesh.top_radius = 0.08
		_shared_knob_mesh.bottom_radius = 0.12
		_shared_knob_mesh.height = 0.12
		_shared_knob_mesh.radial_segments = 16
		_shared_knob_mesh.rings = 1
	if _shared_shadow_mesh == null:
		_shared_shadow_mesh = CylinderMesh.new()
		_shared_shadow_mesh.top_radius = 1.04
		_shared_shadow_mesh.bottom_radius = 1.04
		_shared_shadow_mesh.height = 0.02
		_shared_shadow_mesh.radial_segments = 24
		_shared_shadow_mesh.rings = 1

func _make_body_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = BASE_WOOD_COLOR
	material.roughness = 0.8
	material.metallic = 0.0
	material.metallic_specular = 0.18
	material.emission_enabled = true
	material.emission = BASE_WOOD_COLOR.darkened(0.24)
	material.emission_energy_multiplier = 0.04
	return material

func _make_lid_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = LID_WOOD_COLOR
	material.roughness = 0.7
	material.metallic = 0.0
	material.metallic_specular = 0.18
	material.emission_enabled = true
	material.emission = LID_WOOD_COLOR.darkened(0.22)
	material.emission_energy_multiplier = 0.06
	return material

func _make_lip_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = BASE_WOOD_COLOR.darkened(0.2)
	material.roughness = 0.84
	material.metallic = 0.0
	material.metallic_specular = 0.14
	return material

func _make_hardware_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = HARDWARE_COLOR
	material.roughness = 0.52
	material.metallic = 0.18
	material.metallic_specular = 0.4
	material.emission_enabled = true
	material.emission = HARDWARE_COLOR.darkened(0.35)
	material.emission_energy_multiplier = 0.04
	return material

func _make_outline_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = OUTLINE_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	return material

func _make_shadow_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = SHADOW_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_receive_shadows = true
	return material

func _update_material_tint(color_key: String) -> void:
	var accent: Color = ACCENT_TINTS.get(color_key, ACCENT_TINTS["white"])
	_body_base_color = BASE_WOOD_COLOR.lerp(accent, 0.18)
	_lid_base_color = LID_WOOD_COLOR.lerp(accent, 0.16)
	_lip_base_color = BASE_WOOD_COLOR.darkened(0.14).lerp(accent.darkened(0.18), 0.12)
	_body_material.albedo_color = _body_base_color
	_lid_material.albedo_color = _lid_base_color
	_lip_material.albedo_color = _lip_base_color

func _update_visual_state(force: bool) -> void:
	var emission_color := Color("#ffcf70")
	var body_color := _body_base_color
	var lid_color := _lid_base_color
	var lip_color := _lip_base_color
	var hardware_color := HARDWARE_COLOR
	var body_roughness := 0.8
	var lid_roughness := 0.7
	var hardware_emission := HARDWARE_COLOR.darkened(0.35)
	var hardware_emission_energy := 0.04
	if _completed:
		body_color = _body_base_color.lightened(0.1)
		lid_color = _lid_base_color.lightened(0.08)
		lip_color = _lip_base_color.lightened(0.04)
		body_roughness = 0.86
		lid_roughness = 0.78
		hardware_color = Color("#88a9bd")
		hardware_emission = Color("#9acbf0")
		hardware_emission_energy = 0.2
	elif _selected:
		body_color = _body_base_color.lightened(0.04)
		lid_color = _lid_base_color.lightened(0.06)
		body_roughness = 0.72
		lid_roughness = 0.64
		hardware_color = HARDWARE_COLOR.lightened(0.08)
		hardware_emission = emission_color
		hardware_emission_energy = 0.34
	elif _hovered:
		body_color = _body_base_color.lightened(0.02)
		lid_color = _lid_base_color.lightened(0.03)
		body_roughness = 0.76
		lid_roughness = 0.66
		hardware_emission = emission_color.lightened(0.1)
		hardware_emission_energy = 0.22
	_body_material.albedo_color = body_color
	_body_material.roughness = body_roughness
	_body_material.emission = body_color.darkened(0.24)
	_lid_material.albedo_color = lid_color
	_lid_material.roughness = lid_roughness
	_lid_material.emission = lid_color.darkened(0.2)
	_lid_material.emission_energy_multiplier = 0.08 if (_selected or _hovered) else 0.06
	_lip_material.albedo_color = lip_color
	_hardware_material.albedo_color = hardware_color
	_hardware_material.emission = hardware_emission
	_hardware_material.emission_energy_multiplier = hardware_emission_energy
	if force:
		_visual_root.scale = Vector3.ONE * _scale_multiplier
		_visual_root.rotation.y = deg_to_rad(BASE_ROTATION_Y)

func _wrap_task_name(task_name: String) -> String:
	var words := task_name.split(" ", false)
	if words.size() <= 1 and task_name.length() <= NAME_LINE_LIMIT:
		return task_name
	var lines: Array[String] = []
	var current_line := ""
	for word in words:
		var candidate := word if current_line == "" else "%s %s" % [current_line, word]
		if candidate.length() <= NAME_LINE_LIMIT or current_line == "":
			current_line = candidate
		else:
			lines.append(current_line)
			current_line = word
		if lines.size() >= NAME_LINE_COUNT:
			break
	if current_line != "" and lines.size() < NAME_LINE_COUNT:
		lines.append(current_line)
	if lines.is_empty():
		lines.append(task_name)
	if lines.size() == NAME_LINE_COUNT and words.size() > 0:
		var joined := " ".join(lines)
		if joined.length() < task_name.length():
			lines[lines.size() - 1] = "%s…" % lines[lines.size() - 1].trim_suffix(".")
	return "\n".join(lines)

func _on_theme_changed_taskdice() -> void:
	_apply_label_theme()

func _apply_label_theme() -> void:
	if _difficulty_label != null:
		_difficulty_label.modulate = GameData.ACCENT_GOLD
		# add a darker outline for legibility over varied card backgrounds
		_difficulty_label.outline_modulate = Color(0.06, 0.05, 0.04, 0.95)
		_difficulty_label.outline_size = max(2, _difficulty_label.outline_size)
	if _task_name_label != null:
		_task_name_label.modulate = GameData.ACCENT_GOLD
		_task_name_label.outline_modulate = Color(0.06, 0.05, 0.04, 0.95)

func _load_die_icon(sides: int) -> Texture2D:
	if _die_icon_cache.has(sides):
		return _die_icon_cache[sides] as Texture2D
	if not DIE_FACE_PATHS.has(sides):
		return null
	var face_path := (DIE_FACE_PATHS[sides] as String) % clampi(sides, 1, 20)
	if not ResourceLoader.exists(face_path):
		return null
	var texture := load(face_path) as Texture2D
	_die_icon_cache[sides] = texture
	return texture

func _is_water_task(task_name: String) -> bool:
	var lower_name := task_name.to_lower()
	return "water" in lower_name or "hydrat" in lower_name or "drink" in lower_name

func _is_eat_task(task_name: String) -> bool:
	var lower_name := task_name.to_lower()
	return "eat" in lower_name or "food" in lower_name
