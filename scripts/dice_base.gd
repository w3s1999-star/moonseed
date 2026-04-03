# ============================================================
# dice_base.gd  ·  Moonseed — Base Die (RigidBody2D)
#
# Scene structure expected:
#   DiceBase (RigidBody2D) ← this script
#   ├── AnimatedSprite2D   ["idle", "roll_spin", "land_impact"]
#   ├── CollisionShape2D
#   ├── ShadowSprite (Sprite2D)
#   ├── AudioStreamPlayer2D
#   ├── ExplosionParticles (GPUParticles2D)
#   └── FaceHighlight (Sprite2D or ColorRect)
#         └── ShaderMaterial → dice_highlight_2d.gdshader
#
# NOTE on dice_score_highlight.gdshader
#   That shader is  shader_type spatial  (3-D rendering pipeline).
#   It CANNOT be set on a 2-D canvas node.  dice_highlight_2d.gdshader
#   is a canvas_item port of the same ring + fill algorithm, designed
#   for AnimatedSprite2D / Sprite2D / ColorRect children.
#
# Signals emitted (via SignalBus autoload):
#   task_rolled(task_id, result, sides)  — when die settles
#   dice_exploded(task_id, sides)        — on max-face explosion
# ============================================================
extends RigidBody2D

# ── child refs ───────────────────────────────────────────────
@onready var anim_sprite    : AnimatedSprite2D   = get_node_or_null("AnimatedSprite2D")
@onready var audio          : AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")
@onready var explode_fx     : GPUParticles2D     = get_node_or_null("ExplosionParticles")
## FaceHighlight: Sprite2D or ColorRect with dice_highlight_2d.gdshader
@onready var face_highlight  : CanvasItem        = get_node_or_null("FaceHighlight")
## FaceSprite: Sprite2D for texture-based face display
@onready var face_sprite     : Sprite2D          = get_node_or_null("FaceSprite")
## ImpactFX: AnimatedSprite2D for scoring impact burst (plays behind die face)
@onready var impact_fx       : AnimatedSprite2D  = get_node_or_null("ImpactFX")

# ── exports ──────────────────────────────────────────────────
## Table boundary rect in this node's parent space (DiceTable local).
@export var table_bounds    : Rect2 = Rect2(20.0, 10.0, 500.0, 300.0)
## Velocity threshold below which the die is considered at rest.
@export var settle_velocity : float = 8.0
## How long (s) to wait at low velocity before confirming a settle.
@export var settle_grace    : float = 0.30
## Minimum time (s) the die must have been rolling before settling is valid.
## Prevents a die that stops on the first frame (e.g. pinned against a wall)
## from immediately triggering a slam.
@export var min_roll_time   : float = 0.25
## Roll impulse magnitude range.
@export var impulse_min     : float = 180.0
@export var impulse_max     : float = 320.0
## Skin name for per-face textures.
## Textures are expected at res://assets/textures/dice/{die_skin}/{die_skin}_NN.png
## e.g. die_skin = "d6_basic" loads d6_basic_01.png … d6_basic_06.png
@export var die_skin        : String = ""

# ── state machine ───────────────────────────────────────────
enum State { IDLE, ROLLING, SLAMMING, RESULT }

# ── runtime state ────────────────────────────────────────────
var _sides        : int   = 6
var _task_id      : int   = 0
var _result       : int   = 0
var _state        : State = State.IDLE
var _settle_acc   : float = 0.0    # accumulator toward settle_grace
var _roll_time    : float = 0.0    # total time spent in ROLLING; guards premature settle
var _explosion_count : int = 0      # tracks number of explosions (no longer used - cascades removed)
var _base_result    : int = 0      # original roll result (no longer used - cascades removed)

# ── highlight material cache ─────────────────────────────────
var _hl_mat : ShaderMaterial

# ── per-face texture cache (indexed 0 .. _sides-1) ──────────
var _face_textures : Array = []

# ════════════════════════════════════════════════════════════
#  READY
# ════════════════════════════════════════════════════════════
func _ready() -> void:
	_sides   = int(get_meta("sides",   6))
	_task_id = int(get_meta("task_id", 0))
	# Physics: sleeping disabled while rolling, gravity on
	lock_rotation = false
	can_sleep     = false
	_setup_highlight_material()
	_load_face_textures()
	_play_anim("idle")

# ════════════════════════════════════════════════════════════
#  HIGHLIGHT MATERIAL
#  Loads dice_highlight_2d.gdshader (canvas_item) and attaches
#  it to the FaceHighlight child.  Falls back silently if the
#  node or shader is absent so missing assets never crash.
# ════════════════════════════════════════════════════════════
func _setup_highlight_material() -> void:
	if face_highlight == null:
		return
	var shader_path := "res://shaders/dice_highlight_2d.gdshader"
	if not ResourceLoader.exists(shader_path):
		return
	_hl_mat = ShaderMaterial.new()
	_hl_mat.shader = load(shader_path) as Shader
	_hl_mat.set_shader_parameter("progress",  0.0)
	_hl_mat.set_shader_parameter("alpha",     0.0)
	face_highlight.material = _hl_mat
	face_highlight.modulate = Color(1.0, 1.0, 1.0, 0.0)

# ════════════════════════════════════════════════════════════
#  PUBLIC API  (called by play_tab.gd)
# ════════════════════════════════════════════════════════════

## Kick off a physics roll.
func start_roll() -> void:
	_state      = State.ROLLING
	_settle_acc = 0.0
	_roll_time  = 0.0
	_result     = 0
	_explosion_count = 0
	_base_result = 0
	freeze      = false  # unfreeze if die was previously settled

	# Hide the settled face texture while the die is in motion
	if face_sprite != null:
		face_sprite.visible = false

	# Random throw direction biased toward the centre of the table
	var angle   : float   = randf_range(0.0, TAU)
	var speed   : float   = randf_range(impulse_min, impulse_max)
	linear_velocity  = Vector2(cos(angle), sin(angle)) * speed
	angular_velocity = randf_range(-12.0, 12.0)

	_play_anim("roll_spin")

## Force a specific face value (used when restoring saved layout).
func set_face_value(value : int) -> void:
	_result          = value
	_state           = State.RESULT
	linear_velocity   = Vector2.ZERO
	angular_velocity  = 0.0
	freeze            = true
	_play_anim("idle")
	_show_face(value)

## Returns the task_id this die belongs to.
func get_task_id() -> int:
	return _task_id

# ════════════════════════════════════════════════════════════
#  PHYSICS PROCESS — settle detection + boundary clamp
# ════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	if _state != State.ROLLING:
		return

	_roll_time += delta

	# Keep die inside the felt table boundaries
	_clamp_to_bounds()

	# Slow down the animation frame rate as velocity drops
	var speed : float = linear_velocity.length()
	if anim_sprite != null:
		anim_sprite.speed_scale = clampf(speed / impulse_min, 0.2, 2.0)

	# Settle detection: require low velocity for settle_grace seconds.
	# min_roll_time guard prevents a die that stops before properly rolling
	# (e.g. immediately after spawn) from triggering SLAMMING instantly.
	var can_settle: bool = _roll_time >= min_roll_time \
			and speed < settle_velocity \
			and abs(angular_velocity) < 1.0
	if can_settle:
		_settle_acc += delta
		if _settle_acc >= settle_grace:
			_begin_slam()
	else:
		_settle_acc = 0.0

func _clamp_to_bounds() -> void:
	var pos : Vector2 = position
	var changed       := false
	if pos.x < table_bounds.position.x:
		pos.x = table_bounds.position.x
		linear_velocity.x = abs(linear_velocity.x) * 0.6
		changed = true
	elif pos.x > table_bounds.end.x:
		pos.x = table_bounds.end.x
		linear_velocity.x = -abs(linear_velocity.x) * 0.6
		changed = true
	if pos.y < table_bounds.position.y:
		pos.y = table_bounds.position.y
		linear_velocity.y = abs(linear_velocity.y) * 0.6
		changed = true
	elif pos.y > table_bounds.end.y:
		pos.y = table_bounds.end.y
		linear_velocity.y = -abs(linear_velocity.y) * 0.6
		changed = true
	if changed:
		position = pos

# ════════════════════════════════════════════════════════════
#  SLAMMING  —  physics settled; squash-and-stretch impact
# ════════════════════════════════════════════════════════════
func _begin_slam() -> void:
	_state           = State.SLAMMING
	linear_velocity   = Vector2.ZERO
	angular_velocity  = 0.0
	freeze            = true  # lock physics — die must not drift after impact
	set_meta("resting", true)

	# Determine result now; the face is *revealed* visually in _show_result,
	# not here — the impact animation plays while the result stays hidden.
	_result = randi_range(1, _sides)
	_play_anim("land_impact")

	# Audio clack on first frame of impact
	if audio != null and audio.stream != null:
		audio.pitch_scale = randf_range(0.85, 1.15)
		audio.play()

	# Squash-and-stretch disabled: replace with a short wait to preserve timing
	await get_tree().create_timer(0.03).timeout

	if not is_instance_valid(self):
		return
	_show_result()

# ════════════════════════════════════════════════════════════
#  RESULT  —  face-lock emphasis then emit task_rolled
# ════════════════════════════════════════════════════════════
func _show_result() -> void:
	_state = State.RESULT
	# Transition to idle and lock the result face — this is the reveal moment.
	# _play_anim first: ensures the impact animation stops.
	# _show_face after: if per-face animations exist it overrides idle;
	#   otherwise idle plays and the FaceLabel text is updated.
	_play_anim("idle")
	_show_face(_result)

	# Play impact burst behind the die face
	_play_impact_fx()

	# Face-lock pop disabled: short wait instead
	await get_tree().create_timer(0.02).timeout

	# Subtle highlight ring flash in parallel (fire-and-forget)
	_flash_result_highlight()

	# continuation after small wait above

	if not is_instance_valid(self):
		return
	# Explosion on max face, otherwise report result
	if _result == _sides:
		await _trigger_explosion()
	else:
		SignalBus.task_rolled.emit(_task_id, _result, _sides)

## Brief ring glow via dice_highlight_2d.gdshader to visually confirm
## the settled face.  Keeps alpha low — this is confirmation, not explosion.
func _flash_result_highlight() -> void:
	if _hl_mat == null:
		return
	face_highlight.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_hl_mat.set_shader_parameter("progress", 0.65)
	_hl_mat.set_shader_parameter("alpha",    0.0)
	var tw : Tween = create_tween()
	tw.tween_method(
		func(v: float) -> void: _hl_mat.set_shader_parameter("alpha", v),
		0.0, 0.38, 0.08
	)
	tw.tween_method(
		func(v: float) -> void: _hl_mat.set_shader_parameter("alpha", v),
		0.38, 0.0, 0.14
	)
	await tw.finished
	face_highlight.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_hl_mat.set_shader_parameter("alpha", 0.0)

# ════════════════════════════════════════════════════════════
#  EXPLOSION  — max-face roll
#  1. Glow via dice_highlight_2d.gdshader (0.25 s)
#  2. Particle burst
#  3. Re-roll and add to cumulative result
#  4. Check for additional explosions (cascading)
#  5. Emit task_rolled with combined total
# ════════════════════════════════════════════════════════════
func _trigger_explosion() -> void:
	# Explosion logic: simplified. Emit explosion event, play FX if present,
	# add a small bonus, update face, and report the final rolled value.
	SignalBus.dice_exploded.emit(_task_id, _sides)

	# Particle burst (if any)
	if explode_fx != null:
		explode_fx.emitting = true

	# Re-roll for bonus
	var bonus: int = randi_range(1, _sides)
	_result += bonus

	# Show the accumulating total
	_show_face(_result)

	# Final result - report the combined total
	SignalBus.task_rolled.emit(_task_id, _result, _sides)

## Animates the dice_highlight_2d.gdshader ring over 0.25 s.
## progress: 0 → 1  (ring travels from centre outward)
## alpha:    0 → 1 → 0
func _play_explosion_glow() -> void:
	if _hl_mat == null:
		await get_tree().create_timer(0.25).timeout
		return

	face_highlight.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_hl_mat.set_shader_parameter("progress", 0.0)
	_hl_mat.set_shader_parameter("alpha",    0.0)

	const DUR : float = 0.25

	# Fade alpha in, ring progress 0→1, fade alpha out — all parallel
	var tw : Tween = create_tween()
	tw.set_parallel(true)

	# Alpha envelope: 0 → 1 at 20 % duration, hold, 1 → 0 at 80 %
	tw.tween_method(
		func(v : float) -> void: _hl_mat.set_shader_parameter("alpha", v),
		0.0, 1.0, DUR * 0.25
	)
	tw.tween_method(
		func(v : float) -> void: _hl_mat.set_shader_parameter("progress", v),
		0.0, 1.0, DUR
	)

	await get_tree().create_timer(DUR * 0.75).timeout

	# Fade out
	var tw2 : Tween = create_tween()
	tw2.tween_method(
		func(v : float) -> void: _hl_mat.set_shader_parameter("alpha", v),
		1.0, 0.0, DUR * 0.25
	)
	await tw2.finished

	face_highlight.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_hl_mat.set_shader_parameter("progress", 0.0)
	_hl_mat.set_shader_parameter("alpha",    0.0)

# ════════════════════════════════════════════════════════════
#  HELPERS
# ════════════════════════════════════════════════════════════
func _play_anim(anim_name : String) -> void:
	if anim_sprite == null:
		return
	if anim_sprite.sprite_frames != null \
			and anim_sprite.sprite_frames.has_animation(anim_name):
		anim_sprite.play(anim_name)

## Loads per-face textures for the current die_skin.
## Called once in _ready().  Silently skips missing files.
func _load_face_textures() -> void:
	if die_skin.is_empty():
		return
	_face_textures.resize(_sides)
	for i in range(_sides):
		var path := "res://assets/textures/dice/%s/%s_%02d.png" % [die_skin, die_skin, i + 1]
		if ResourceLoader.exists(path):
			_face_textures[i] = load(path) as Texture2D

## Plays the yellow impact burst animation behind the die face.
## Fires once and hides when complete.  Safe to call if node is absent.
func _play_impact_fx() -> void:
	if impact_fx == null:
		return
	impact_fx.visible = true
	impact_fx.play("impact")
	# Hide when animation finishes (one-shot)
	if not impact_fx.animation_finished.is_connected(_on_impact_fx_finished):
		impact_fx.animation_finished.connect(_on_impact_fx_finished)

func _on_impact_fx_finished() -> void:
	if impact_fx != null:
		impact_fx.stop()
		impact_fx.visible = false

## Sets the visible die face.
## Priority: skin texture → AnimatedSprite2D per-face anim → FaceLabel text.
func _show_face(value : int) -> void:
	var idx : int = clampi(value, 1, _sides) - 1
	# 1. Per-face skin texture
	if face_sprite != null and idx < _face_textures.size() \
			and _face_textures[idx] != null:
		face_sprite.texture = _face_textures[idx]
		face_sprite.visible = true
		return
	# 2. AnimatedSprite2D per-face animation
	var face_anim : String = "face_%d" % clampi(value, 1, _sides)
	if anim_sprite != null and anim_sprite.sprite_frames != null \
			and anim_sprite.sprite_frames.has_animation(face_anim):
		anim_sprite.play(face_anim)
		return
	# 3. Fallback: update a child Label named "FaceLabel"
	var lbl : Label = get_node_or_null("FaceLabel") as Label
	if lbl != null:
		lbl.text = str(value)
