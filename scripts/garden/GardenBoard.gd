extends Node3D
class_name GardenBoard

## GardenBoard - 4x8 Grid Manager for Lunar Garden
## Creates and manages all 32 slots, handles layout, state and interactions

const ROWS := 4
const COLUMNS := 8
const TOTAL_SLOTS := ROWS * COLUMNS
const START_UNLOCKED_COUNT := 12

const SLOT_SPACING := Vector3(2.2, 0.0, 2.0)
const GRID_OFFSET := Vector3(-COLUMNS * SLOT_SPACING.x / 2 + SLOT_SPACING.x / 2, 0.0, -ROWS * SLOT_SPACING.z / 2 + SLOT_SPACING.z / 2)

var slots: Array[GardenSlot] = []
var selected_slot: GardenSlot = null

# Signals
signal slot_selected(slot: GardenSlot)
signal slot_plant_requested(slot: GardenSlot)


func _ready() -> void:
	_build_grid()
	_apply_initial_unlock_pattern()


func _build_grid() -> void:
	# Clear any existing slots
	for child in get_children():
		child.queue_free()
	
	slots.clear()
	
	# Create all 32 slots
	for row in range(ROWS):
		for column in range(COLUMNS):
			var slot_id := row * COLUMNS + column
			
			# Create slot instance
			var slot_scene := preload("res://scenes/garden/GardenSlot.tscn")
			var slot := slot_scene.instantiate() as GardenSlot
			
			# Configure slot
			slot.slot_id = slot_id
			slot.row = row
			slot.column = column
			slot.is_unlocked = false
			
			# Position slot
			slot.position = GRID_OFFSET + Vector3(
				column * SLOT_SPACING.x,
				0.0,
				row * SLOT_SPACING.z
			)
			
			# Connect signals
			slot.slot_clicked.connect(_on_slot_clicked)
			slot.slot_hovered.connect(_on_slot_hovered)
			slot.slot_unhovered.connect(_on_slot_unhovered)
			
			add_child(slot)
			slots.append(slot)


func _apply_initial_unlock_pattern() -> void:
	# Unlock first 12 slots:
	# Row 0: all 8 columns (slots 0-7)
	# Row 1: first 4 columns (slots 8-11)
	for slot_id in range(START_UNLOCKED_COUNT):
		if slot_id < slots.size():
			slots[slot_id].unlock()


func _on_slot_clicked(slot: GardenSlot) -> void:
	if selected_slot == slot:
		deselect_all()
		slot_selected.emit(null)
	else:
		deselect_all()
		selected_slot = slot
		slot.set_selected(true)
		slot_selected.emit(slot)
		slot_plant_requested.emit(slot)


func _on_slot_hovered(slot: GardenSlot) -> void:
	slot.set_hovered(true)


func _on_slot_unhovered(slot: GardenSlot) -> void:
	slot.set_hovered(false)


func deselect_all() -> void:
	selected_slot = null
	for slot in slots:
		slot.set_selected(false)


func get_slot(slot_id: int) -> GardenSlot:
	if slot_id >= 0 and slot_id < slots.size():
		return slots[slot_id]
	return null


func get_slot_at_position(row: int, column: int) -> GardenSlot:
	if row >= 0 and row < ROWS and column >= 0 and column < COLUMNS:
		var slot_id := row * COLUMNS + column
		return get_slot(slot_id)
	return null


func get_unlocked_slots() -> Array[GardenSlot]:
	return slots.filter(func(s): return s.is_unlocked)


func get_empty_slots() -> Array[GardenSlot]:
	return slots.filter(func(s): return s.is_unlocked and not s.is_occupied)


func get_occupied_slots() -> Array[GardenSlot]:
	return slots.filter(func(s): return s.is_occupied)


func unlock_slot(slot_id: int) -> void:
	var slot := get_slot(slot_id)
	if slot:
		slot.unlock()


func lock_slot(slot_id: int) -> void:
	var slot := get_slot(slot_id)
	if slot:
		slot.lock()


func get_all_slot_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for slot in slots:
		data.append(slot.get_slot_data())
	return data


func find_slot_by_plant_id(plant_id: String) -> GardenSlot:
	for slot in slots:
		if slot.plant_id == plant_id:
			return slot
	return null


func get_all_slot_world_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for slot in slots:
		positions.append(Vector2(slot.global_position.x, slot.global_position.z))
	return positions
