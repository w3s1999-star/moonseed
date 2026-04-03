extends Node

# ─────────────────────────────────────────────────────────────────
# ButtonFeedback.gd  —  MOONSEED  v0.8
# GDD §17.4  "BUTTON FEEDBACK — ButtonFeedback autoload applies a
#             subtle scale-bounce tween to every Button in the scene tree."
#
# Usage: ButtonFeedback.setup_recursive(root_node)
# Automatically connects to every Button's pressed signal.
# ─────────────────────────────────────────────────────────────────

const SCALE_UP:   Vector2 = Vector2(1.12, 1.12)
const SCALE_DOWN: Vector2 = Vector2(0.92, 0.92)
const SCALE_REST: Vector2 = Vector2(1.0,  1.0)

# Called by scenes to register all buttons below a node
func setup_recursive(root: Node) -> void:
	_walk(root)

func _walk(node: Node) -> void:
	if node is Button or node is LinkButton:
		_hook(node as Control)
	for child in node.get_children():
		_walk(child)

func _hook(btn: Control) -> void:
	# Avoid double-hooking
	if btn.has_meta("_bf_hooked"): return
	btn.set_meta("_bf_hooked", true)

	# pivot to center before tweening
	if btn is Button:
		(btn as Button).pressed.connect(func(): _bounce(btn))

func _bounce(btn: Control) -> void:
	if not is_instance_valid(btn): return
	btn.pivot_offset = btn.size * 0.5
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", SCALE_UP,   0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", SCALE_DOWN, 0.05)
	tw.tween_property(btn, "scale", SCALE_REST, 0.09).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
