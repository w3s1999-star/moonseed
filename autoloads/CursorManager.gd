extends Node

# ─────────────────────────────────────────────────────────────────
# CursorManager.gd  —  MOONSEED
#
# Sets custom mouse cursors for the whole application:
#   spr_cursor_0  →  neutral / default cursor
#   spr_cursor_1  →  pressed cursor (any mouse button held)
# ─────────────────────────────────────────────────────────────────

const _CURSOR_NEUTRAL := preload("res://assets/ui/cursor/spr_cursor_0.png")
const _CURSOR_CLICKED := preload("res://assets/ui/cursor/spr_cursor_1.png")

# Hotspot = the pixel on the image that maps to the logical pointer tip.
# Adjust if the artwork's tip is not at the top-left corner.
const _HOTSPOT := Vector2(0, 0)


func _ready() -> void:
	_set_neutral()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			_set_clicked()
		else:
			_set_neutral()


func _set_neutral() -> void:
	Input.set_custom_mouse_cursor(_CURSOR_NEUTRAL, Input.CURSOR_ARROW, _HOTSPOT)


func _set_clicked() -> void:
	Input.set_custom_mouse_cursor(_CURSOR_CLICKED, Input.CURSOR_ARROW, _HOTSPOT)
