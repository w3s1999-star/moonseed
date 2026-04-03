extends Node2D

# ─────────────────────────────────────────────────────────────────
# BazaarVendor.gd  –  Clickable vendor stall node.
#
# Attach to: PearlExchange, DiceCarver, CurioDealer,
#            SeedNursery, SweetmakerStall inside lunar_bazaar.tscn.
#
# On left-click it emits SignalBus.vendor_opened(vendor_id).
# BazaarTab listens and shows the shop overlay panel.
#
# vendor_id is set via @export in the scene, or auto-derived from
# the node name (PearlExchange → "pearl_exchange").
# ─────────────────────────────────────────────────────────────────

@export var vendor_id: String = ""

const _STALL_W: float = 130.0
const _STALL_H: float = 90.0

func _ready() -> void:
	if vendor_id.is_empty():
		vendor_id = name.to_snake_case()

	# ── Area2D for mouse click detection ─────────────────────────
	var area := Area2D.new()
	area.input_pickable = true
	add_child(area)

	var col := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(_STALL_W, _STALL_H)
	col.shape = rect_shape
	area.add_child(col)

	area.input_event.connect(_on_area_input)
	queue_redraw()


func _on_area_input(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		SignalBus.vendor_opened.emit(vendor_id)


func _draw() -> void:
	# Placeholder stall outline — replace with Sprite2D once art exists.
	var hw := _STALL_W * 0.5
	var hh := _STALL_H * 0.5
	var fill_rect := Rect2(-hw, -hh, _STALL_W, _STALL_H)

	var fill_col := Color("#0d0a22")
	fill_col.a = 0.88
	draw_rect(fill_rect, fill_col, true)
	draw_rect(fill_rect, Color("#9966ee"), false, 2.5)
