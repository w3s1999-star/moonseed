extends Node3D
class_name GardenSlot

## GardenSlot - Reusable container socket for Lunar Garden
## Manages slot state and visual presentation, separates container from plant content

# Slot States
enum SlotState {
	LOCKED,
	UNLOCKED_EMPTY,
	OCCUPIED,
	HOVERED,
	SELECTED
}

# Slot Data
@export var slot_id: int = -1
@export var row: int = 0
@export var column: int = 0
@export var is_unlocked: bool = false
@export var plant_id: String = ""
@export var is_occupied: bool = false

# Plant Growth System
enum GrowthStage {
	SEED,
	SPROUT,
	SMALL,
	FULL_BLOOM
}

@export var current_growth: GrowthStage = GrowthStage.SEED
@export var happiness: float = 50.0
@export var watered_at: int = 0
@export var last_need: int = 0
@export var planted_at: int = 0

const WATER_COOLDOWN_HOURS := 24
const GROWTH_TIME_HOURS := 12

# Nodes
@onready var container_mesh: MeshInstance3D = $ContainerMesh
@onready var lock_icon: Sprite3D = $LockIcon
@onready var plant_anchor: Node3D = $PlantAnchor
@onready var water_indicator: MeshInstance3D = $WaterIndicator
@onready var water_splash: GPUParticles3D = $WaterSplashParticles

var _bob_time: float = 0.0

# Materials
var material_locked: StandardMaterial3D
var material_empty: StandardMaterial3D
var material_occupied: StandardMaterial3D

# Signals
signal slot_clicked(slot: GardenSlot)
signal slot_hovered(slot: GardenSlot)
signal slot_unhovered(slot: GardenSlot)


func _ready() -> void:
	_setup_materials()
	_update_visual_state()
	lock_icon.visible = not is_unlocked
	set_process(true)

	# Planter boxes should render above grass but below plant visuals
	if is_instance_valid(container_mesh):
		container_mesh.render_priority = 1


func _process(delta: float) -> void:
	_bob_time += delta
	
	# Update need indicator
	var needs_water_now := needs_water()
	water_indicator.visible = is_occupied and is_unlocked and needs_water_now
	
	# Bob animation for indicator
	if water_indicator.visible:
		var bob_y := sin(_bob_time * 2.5) * 0.06
		water_indicator.position.y = 0.75 + bob_y
		water_indicator.rotation.z = sin(_bob_time * 1.8) * 0.12


func _input_event(camera: Camera3D, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if not is_unlocked:
		return
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			slot_clicked.emit(self)
	elif event is InputEventMouseMotion:
		slot_hovered.emit(self)


func _mouse_exited() -> void:
	slot_unhovered.emit(self)


func unlock() -> void:
	is_unlocked = true
	lock_icon.visible = false
	_update_visual_state()


func lock() -> void:
	is_unlocked = false
	is_occupied = false
	plant_id = ""
	_clear_plant()
	lock_icon.visible = true
	_update_visual_state()


func attach_plant(plant_scene: PackedScene, plant_data: Dictionary) -> void:
	if not is_unlocked:
		return
	
	_clear_plant()
	
	var plant_instance := plant_scene.instantiate()
	plant_anchor.add_child(plant_instance)
	
	is_occupied = true
	plant_id = plant_data.get("id", "")
	_update_visual_state()


func remove_plant() -> void:
	_clear_plant()
	is_occupied = false
	plant_id = ""
	_update_visual_state()


func _clear_plant() -> void:
	for child in plant_anchor.get_children():
		child.queue_free()


func _setup_materials() -> void:
	# Locked state (muted, low opacity)
	material_locked = StandardMaterial3D.new()
	material_locked.albedo_color = Color("#5a4630")
	material_locked.roughness = 0.85
	material_locked.albedo_texture = load("res://assets/textures/wood_muted.png") if ResourceLoader.exists("res://assets/textures/wood_muted.png") else null
	
	# Empty unlocked state
	material_empty = StandardMaterial3D.new()
	material_empty.albedo_color = Color("#8b6914")
	material_empty.roughness = 0.75
	material_empty.albedo_texture = load("res://assets/textures/wood.png") if ResourceLoader.exists("res://assets/textures/wood.png") else null
	
	# Occupied state
	material_occupied = StandardMaterial3D.new()
	material_occupied.albedo_color = Color("#a67c00")
	material_occupied.roughness = 0.7
	material_occupied.albedo_texture = load("res://assets/textures/wood.png") if ResourceLoader.exists("res://assets/textures/wood.png") else null


func _update_visual_state() -> void:
	if not is_unlocked:
		container_mesh.material_override = material_locked
		container_mesh.modulate.a = 0.5
	elif is_occupied:
		container_mesh.material_override = material_occupied
		container_mesh.modulate.a = 1.0
	else:
		container_mesh.material_override = material_empty
		container_mesh.modulate.a = 1.0


func set_hovered(hovered: bool) -> void:
	if not is_unlocked:
		return
	
	if hovered:
		scale = Vector3(1.05, 1.05, 1.05)
	else:
		scale = Vector3(1.0, 1.0, 1.0)


func set_selected(selected: bool) -> void:
	if not is_unlocked:
		return
	
	if selected:
		container_mesh.modulate = Color(1.2, 1.2, 1.2, 1.0)
	else:
		_update_visual_state()


func water() -> bool:
	if not is_occupied:
		return false
	
	var current_time := Time.get_unix_time_from_system()
	var hours_since_watered := (current_time - watered_at) / 3600
	
	if hours_since_watered < WATER_COOLDOWN_HOURS:
		return false
	
	watered_at = current_time
	happiness = min(happiness + 25.0, 100.0)
	_check_growth_progress()
	
	# Trigger splash effect
	water_splash.restart()
	
	# Hide need indicator
	water_indicator.visible = false
	
	return true


func needs_water() -> bool:
	if not is_occupied:
		return false
	
	var current_time := Time.get_unix_time_from_system()
	var hours_since_watered := (current_time - watered_at) / 3600
	
	return hours_since_watered >= WATER_COOLDOWN_HOURS


func _check_growth_progress() -> void:
	if current_growth == GrowthStage.FULL_BLOOM:
		return
	
	var hours_since_plant := (Time.get_unix_time_from_system() - planted_at) / 3600
	var required_time := GROWTH_TIME_HOURS * (int(current_growth) + 1)
	
	if hours_since_plant >= required_time:
		_advance_growth_stage()


func _advance_growth_stage() -> void:
	if int(current_growth) < int(GrowthStage.FULL_BLOOM):
		current_growth = int(current_growth) + 1
		# Bloom animation FX will trigger here
		# Moondrop reward will be issued here


func get_growth_progress_percent() -> float:
	if current_growth == GrowthStage.FULL_BLOOM:
		return 1.0
	
	var hours_since_plant := (Time.get_unix_time_from_system() - planted_at) / 3600
	var required_time := GROWTH_TIME_HOURS * (int(current_growth) + 1)
	
	return clamp(hours_since_plant / required_time, 0.0, 1.0)


func get_slot_data() -> Dictionary:
	return {
		"slot_id": slot_id,
		"row": row,
		"column": column,
		"is_unlocked": is_unlocked,
		"plant_id": plant_id,
		"is_occupied": is_occupied,
		"current_growth": current_growth,
		"happiness": happiness,
		"watered_at": watered_at,
		"last_need": last_need,
		"planted_at": planted_at
	}
