# echo_ring.gd — Scoring echo / ripple ring effect
# Attach to:  EchoRing (Node2D)
#   └── RingRect (ColorRect)   — centred, starts at size 0×0
extends Node2D

@onready var ring : ColorRect = $RingRect

const RING_EXPAND : float = 240.0
const DURATION    : float = 0.55

func _ready() -> void:
	ring.size         = Vector2.ZERO
	ring.color        = Color(1.0, 0.94, 0.27, 0.50) # yellow echo
	ring.pivot_offset = Vector2.ZERO

func play() -> void:
	ring.size            = Vector2(8.0, 8.0)
	ring.pivot_offset    = ring.size * 0.5
	ring.position        = -ring.size * 0.5

	var tw : Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(ring, "size",     Vector2(RING_EXPAND, RING_EXPAND),       DURATION)
	tw.tween_property(ring, "position", Vector2(-RING_EXPAND * 0.5, -RING_EXPAND * 0.5), DURATION)
	tw.tween_property(ring, "modulate:a", 0.0,                                   DURATION)
