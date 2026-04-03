extends Node2D

@export var sprite_sheet: Texture2D = preload("res://assets/textures/dice/Dice Background.png")
@export var frames_count: int = 12
@export var columns: int = 12
@export var rows: int = 1
@export var fps: int = 12
@export var tint: Color = Color8(255, 213, 90)
@export var autoplay: bool = false
@export var z_index_offset: int = -1

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if not is_instance_valid(anim):
		return
	if sprite_sheet == null:
		return
	var sheet_size := sprite_sheet.get_size()
	var frame_w := int(sheet_size.x / max(columns, 1))
	var frame_h := int(sheet_size.y / max(rows, 1))
	var frames_res := SpriteFrames.new()
	var anim_name := "default"
	for i in range(frames_count):
		var col := i % columns
		var row := int(i / columns)
		var region := Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
		var at := AtlasTexture.new()
		at.atlas = sprite_sheet
		at.region = region
		frames_res.add_frame(anim_name, at)
	anim.frames = frames_res
	anim.animation = anim_name
	anim.modulate = tint
	anim.z_index = z_index_offset
	if autoplay:
		anim.play(anim_name, float(fps))

func play_at(global_pos: Vector2) -> void:
	# Move to world position and restart the animation
	if not is_instance_valid(anim):
		return
	# Set this Node2D's global position to requested world position
	global_position = global_pos
	# Restart animation from first frame
	anim.stop()
	anim.frame = 0
	anim.play(anim.animation, float(fps))
