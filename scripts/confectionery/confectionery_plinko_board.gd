extends Control

# ─────────────────────────────────────────────────────────────────
# confectionery_plinko_board.gd  —  MOONSEED
# Pre-generated Plinko board for the Confectionery center panel.
# Hand-authored peg layout with category buckets.
# ─────────────────────────────────────────────────────────────────

signal drop_animation_complete(pocket_index: int, category: int)

# ── Board Configuration ──────────────────────────────────────────
const BOARD_PADDING: float = 24.0
const PEG_RADIUS: float = 6.0
const PEG_COLOR: Color = Color("#c8956b")
const PEG_GLOW_COLOR: Color = Color("#e8b88a")
const BOARD_BG_COLOR: Color = Color("#1a0d0a")
const BOARD_BORDER_COLOR: Color = Color("#8B4513")

# ── Category Colors ──────────────────────────────────────────────
const CATEGORY_COLORS: Dictionary = {
	0: Color("#ff6b6b"),  # Fruit
	1: Color("#ffd66b"),  # Crunch
	2: Color("#ff9fff"),  # Floral
	3: Color("#ff8c42"),  # Spice
	4: Color("#a855f7")   # Wildcard
}

const CATEGORY_NAMES: Array[String] = ["Fruit", "Crunch", "Floral", "Spice", "Wildcard"]
const CATEGORY_EMOJIS: Array[String] = ["🍓", "🍪", "🌸", "🌶️", "🎲"]
const CATEGORY_SUBTYPES: Array[String] = [
	"Mango · Lemon · Orange\nStrawberry · Peach · Cherry",
	"Hazelnut · Almond · Wafer\nToffee · Peanut Brittle\nCookie Crumble",
	"Rose · Lavender · Violet\nJasmine · Hibiscus\nChamomile",
	"Cinnamon · Clove · Ginger\nCardamom · Chili Cocoa\nNutmeg",
	"Random from all\ncategories"
]

# ── Hand-authored Peg Layout ─────────────────────────────────────
# 8 rows, alternating 3-4-5-4-5-4-5-4 pegs (34 total)
# Positions are normalized (0.0-1.0) and scaled at runtime
const PEG_ROWS: Array = [
	# Row 0 (3 pegs)
	[0.25, 0.50, 0.75],
	# Row 1 (4 pegs)
	[0.17, 0.38, 0.62, 0.83],
	# Row 2 (5 pegs)
	[0.12, 0.30, 0.50, 0.70, 0.88],
	# Row 3 (4 pegs)
	[0.17, 0.38, 0.62, 0.83],
	# Row 4 (5 pegs)
	[0.12, 0.30, 0.50, 0.70, 0.88],
	# Row 5 (4 pegs)
	[0.17, 0.38, 0.62, 0.83],
	# Row 6 (5 pegs)
	[0.12, 0.30, 0.50, 0.70, 0.88],
	# Row 7 (4 pegs)
	[0.17, 0.38, 0.62, 0.83]
]

# ── Drop Configuration ───────────────────────────────────────────
const COIN_COLORS: Dictionary = {
	"bar": Color("#8B4513"),
	"truffle": Color("#4a2c2a"),
	"artisan": Color("#ffd700")
}

# ── Visual Nodes ────────────────────────────────────────────────
var _peg_layer: Control
var _bucket_layer: HBoxContainer
var _coin_node: Control
var _status_label: Label
var _idle_tween: Tween
var _peg_nodes: Array[Control] = []
var _hover_popup: PanelContainer
var _hover_popup_label: Label
var _hover_timer: Timer
var _current_hover_bucket: Control = null

# ── Physics Nodes ───────────────────────────────────────────────
var _physics_layer: Node2D  # Container for physics bodies
var _peg_bodies: Array[StaticBody2D] = []
var _bucket_sensors: Array[Area2D] = []
const COLLISION_LAYER_BALLS: int = 2
const COLLISION_LAYER_BUCKETS: int = 3

# ── Subtype Pools (shown when a category is selected) ────────────
const SUBTYPE_POOLS: Array[Array] = [
	# Fruit
	["Mango", "Lemon", "Orange", "Strawberry", "Peach", "Cherry"],
	# Crunch
	["Hazelnut", "Almond", "Wafer", "Toffee", "Peanut Brittle", "Cookie Crumble"],
	# Floral
	["Rose", "Lavender", "Violet", "Jasmine", "Hibiscus", "Chamomile Honey"],
	# Spice
	["Cinnamon", "Clove", "Ginger", "Cardamom", "Chili Cocoa", "Nutmeg"],
	# Wildcard
	["Mango", "Hazelnut", "Rose", "Cinnamon", "Lemon", "Almond"]
]

const SUBTYPE_EMOJIS: Array[Array] = [
	["🥭", "🍋", "🍊", "🍓", "🍑", "🍒"],
	["🌰", "🌰", "🧇", "🍬", "🥜", "🍪"],
	["🌹", "💜", "💐", "🌺", "🌺", "🌼"],
	["🫚", "🫚", "🫚", "💚", "🌶️", "🌰"],
	["🥭", "🌰", "🌹", "🫚", "🍋", "🌰"]
]

# ── State ────────────────────────────────────────────────────────
var _is_dropping: bool = false
var _board_width: float = 0.0
var _board_height: float = 0.0
var _row_height: float = 0.0
var _selected_category: int = -1  # -1 = show all categories, 0-4 = show subtypes
var _manually_selected_category: bool = false  # Track if category was manually selected

# ── Slot Machine Rotation State ──────────────────────────────────
var _rotation_timer: Timer
var _is_rotating: bool = false
var _current_rotation_index: int = 0
var _rotation_phase: int = 0  # 0=fast spin, 1=slow down, 2=settle
var _rotation_tick_count: int = 0
var _rotation_settle_target: int = -1
const ROTATION_CATEGORIES: Array[int] = [0, 1, 2, 3]  # Fruit, Crunch, Floral, Spice
const ROTATION_SPEEDS: Array[float] = [0.25, 0.4, 0.6, 0.9]  # Speed progression (slower for photo safety)
const ROTATION_TICKS_PER_PHASE: Array[int] = [8, 5, 3]  # Ticks before advancing phase

# ── Ingredient Ball State ────────────────────────────────────────
var _ingredient_balls: Array[RigidBody2D] = []
var _balls_landed: int = 0
var _balls_total: int = 0
var _ball_spawn_times: Dictionary = {}  # Tracks spawn time per ball for timeout detection
const BALL_RADIUS: float = 12.0  # 2:3 of bucket height (56px * 2/3 ≈ 37px diameter → 18.5px radius)
const BALL_TIMEOUT: float = 5.0  # Seconds before despawning a stuck ball
const BALL_BOUNCE: float = 0.6
const BALL_FRICTION: float = 0.3
const BALL_MASS: float = 0.5

# ── Spawn Location Indicator ─────────────────────────────────────
var _spawn_indicator: TextureRect
var _spawn_tween: Tween
const SPAWN_INDICATOR_SIZE: float = 28.0

# ── Spritesheets ─────────────────────────────────────────────────
const FRUIT_SPRITESHEET: Texture2D = preload("res://assets/textures/Confectionary/fruit_category_spritesheet.png")
const CRUNCH_SPRITESHEET: Texture2D = preload("res://assets/textures/Confectionary/crunch_category_spritesheet.png")
const FLORAL_SPRITESHEET: Texture2D = preload("res://assets/textures/Confectionary/floral_category_spritesheet.png")
const SPICE_SPRITESHEET: Texture2D = preload("res://assets/textures/Confectionary/spices_category_spritesheet.png")
const SPRITESHEET_FRAME_PADDING: float = 5.0

# ── Slot Machine Blur Shader ─────────────────────────────────────
const SLOT_MACHINE_BLUR_SHADER: Shader = preload("res://shaders/slot_machine_blur.gdshader")
var _blur_material: ShaderMaterial

# ── Centralized Subtype Data ─────────────────────────────────────
# Single source of truth for category + subtype display data.
# Column indices match spritesheet layout (0-indexed).
const CATEGORY_SUBTYPE_DATA: Dictionary = {
	0: { # Fruit — spritesheet columns: Orange(0), Cherry(1), Peach(2), Strawberry(3), Lemon(4), Mango(5)
		"spritesheet": FRUIT_SPRITESHEET,
		"subtypes": [
			{"id": "orange",     "label": "Orange Chocolate",     "column": 0},
			{"id": "cherry",     "label": "Cherry Chocolate",     "column": 1},
			{"id": "peach",      "label": "Peach Chocolate",      "column": 2},
			{"id": "strawberry", "label": "Strawberry Chocolate", "column": 3},
			{"id": "lemon",      "label": "Lemon Chocolate",      "column": 4},
			{"id": "mango",      "label": "Mango Chocolate",      "column": 5},
		]
	},
	1: { # Crunch — spritesheet columns: Hazelnut(0), Almond(1), Wafer(2), Toffee(3), Peanut Brittle(4), Cookie Crumble(5)
		"spritesheet": CRUNCH_SPRITESHEET,
		"subtypes": [
			{"id": "hazelnut",       "label": "Hazelnut Chocolate",       "column": 0},
			{"id": "almond",         "label": "Almond Chocolate",         "column": 1},
			{"id": "wafer",          "label": "Wafer Chocolate",          "column": 2},
			{"id": "toffee",         "label": "Toffee Chocolate",         "column": 3},
			{"id": "peanut_brittle", "label": "Peanut Brittle Chocolate", "column": 4},
			{"id": "cookie_crumble", "label": "Cookie Crumble Chocolate", "column": 5},
		]
	},
	2: { # Floral — spritesheet columns: Chamomile(0), Jasmine(1), Violet(2), Hibiscus(3), Lavender(4), Rose(5)
		"spritesheet": FLORAL_SPRITESHEET,
		"subtypes": [
			{"id": "chamomile", "label": "Chamomile Chocolate", "column": 0},
			{"id": "jasmine",   "label": "Jasmine Chocolate",   "column": 1},
			{"id": "violet",    "label": "Violet Chocolate",    "column": 2},
			{"id": "hibiscus",  "label": "Hibiscus Chocolate",  "column": 3},
			{"id": "lavender",  "label": "Lavender Chocolate",  "column": 4},
			{"id": "rose",      "label": "Rose Chocolate",      "column": 5},
		]
	},
	3: { # Spice — spritesheet columns: Nutmeg(0), Chili(1), Cloves(2), Cardamom(3), Ginger(4), Cinnamon(5)
		"spritesheet": SPICE_SPRITESHEET,
		"subtypes": [
			{"id": "nutmeg",    "label": "Nutmeg Chocolate",    "column": 0},
			{"id": "chili",     "label": "Chili Chocolate",     "column": 1},
			{"id": "cloves",    "label": "Cloves Chocolate",    "column": 2},
			{"id": "cardamom",  "label": "Cardamom Chocolate",  "column": 3},
			{"id": "ginger",    "label": "Ginger Chocolate",    "column": 4},
			{"id": "cinnamon",  "label": "Cinnamon Chocolate",  "column": 5},
		]
	}
}

# ── Wildcard Pool (built at runtime) ─────────────────────────────
var _wildcard_pool: Array[Dictionary] = []

func _build_wildcard_pool() -> Array[Dictionary]:
	# Builds one flat pool containing all 24 subtypes from all 4 categories
	if not _wildcard_pool.is_empty():
		return _wildcard_pool
	for cat_id in CATEGORY_SUBTYPE_DATA:
		var cat_data: Dictionary = CATEGORY_SUBTYPE_DATA[cat_id]
		var spritesheet: Texture2D = cat_data.spritesheet
		for subtype: Dictionary in cat_data.subtypes:
			_wildcard_pool.append({
				"source_category": cat_id,
				"spritesheet": spritesheet,
				"column": subtype.column,
				"label": subtype.label,
				"id": subtype.id
			})
	return _wildcard_pool

func _resolve_wildcard_subtype() -> Dictionary:
	# Returns one random entry from the mixed wildcard pool
	var pool: Array[Dictionary] = _build_wildcard_pool()
	return pool[randi() % pool.size()]

# ── Generic Sprite Helpers ───────────────────────────────────────
func _get_sprite_region(spritesheet: Texture2D, column: int) -> Rect2:
	var total_width: float = spritesheet.get_width()
	var total_height: float = spritesheet.get_height()
	var frame_width: float = (total_width - SPRITESHEET_FRAME_PADDING * 5.0) / 6.0
	var x: float = column * (frame_width + SPRITESHEET_FRAME_PADDING)
	return Rect2(x, 0, frame_width, total_height)

func _create_sprite_bucket(spritesheet: Texture2D, column: int, label: String, cat_color: Color) -> void:
	var bucket := PanelContainer.new()
	bucket.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bucket.custom_minimum_size = Vector2(0, 44)
	var bucket_style := StyleBoxFlat.new()
	bucket_style.bg_color = cat_color.darkened(0.65)
	bucket_style.border_color = cat_color.darkened(0.2)
	bucket_style.set_border_width_all(1)
	bucket_style.set_corner_radius_all(4)
	bucket.add_theme_stylebox_override("panel", bucket_style)
	_bucket_layer.add_child(bucket)

	# Sprite texture — use AtlasTexture to extract the correct frame
	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = spritesheet
	atlas_tex.region = _get_sprite_region(spritesheet, column)

	var sprite := TextureRect.new()
	sprite.texture = atlas_tex
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2(32, 32)
	sprite.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bucket.add_child(sprite)

	# Use shared hover popup system
	bucket.mouse_entered.connect(func():
		_current_hover_bucket = bucket
		_hover_popup_label.text = label
		_hover_popup_label.add_theme_color_override("font_color", cat_color)
		_hover_timer.start()
	)
	bucket.mouse_exited.connect(func():
		if _current_hover_bucket == bucket:
			_hide_hover_popup()
	)

func _ready() -> void:
	_build_board()
	_create_hover_popup()
	_start_idle_animation()

func _build_board() -> void:
	# Board sizing will be set when resized
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = BOARD_BG_COLOR
	add_child(bg)

	# Border frame
	var border := PanelContainer.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color.TRANSPARENT
	border_style.border_color = BOARD_BORDER_COLOR
	border_style.set_border_width_all(2)
	border_style.set_corner_radius_all(8)
	border.add_theme_stylebox_override("panel", border_style)
	add_child(border)

	# Peg layer (drawn in _draw)
	_peg_layer = Control.new()
	_peg_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_peg_layer.draw.connect(_draw_pegs)
	add_child(_peg_layer)

	# Bucket layer at bottom
	_bucket_layer = HBoxContainer.new()
	_bucket_layer.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_bucket_layer.offset_top = -72.0
	_bucket_layer.offset_bottom = -8.0
	_bucket_layer.offset_left = BOARD_PADDING
	_bucket_layer.offset_right = -BOARD_PADDING
	_bucket_layer.add_theme_constant_override("separation", 4)
	add_child(_bucket_layer)

	# Create initial category buckets
	for i in range(5):
		_create_category_bucket(i)

	# Status label (for drop feedback)
	_status_label = Label.new()
	_status_label.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_status_label.offset_top = 6.0
	_status_label.offset_bottom = 22.0
	_status_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	_status_label.add_theme_color_override("font_color", Color(GameData.ACCENT_GOLD, 0.7))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text = "Drop a coin to begin"
	add_child(_status_label)
	
	# Physics layer for physics bodies (created after resize)
	_physics_layer = Node2D.new()
	_physics_layer.name = "PhysicsLayer"
	add_child(_physics_layer)
	
	# Create spawn location indicator
	_create_spawn_indicator()

func _create_peg_physics() -> void:
	"""Create StaticBody2D collision shapes for all pegs."""
	var available_width: float = _board_width - BOARD_PADDING * 2.0
	var available_height: float = _board_height - 80.0
	var row_spacing: float = available_height / float(PEG_ROWS.size() + 1)
	
	for row_idx in range(PEG_ROWS.size()):
		var row: Array = PEG_ROWS[row_idx]
		var y: float = BOARD_PADDING + row_spacing * float(row_idx + 1)
		for peg_x_norm in row:
			var x: float = BOARD_PADDING + available_width * peg_x_norm
			var peg_pos := Vector2(x, y)
			
			# Create StaticBody2D for physics collision
			var peg_body := StaticBody2D.new()
			peg_body.position = peg_pos
			
			# Create collision shape (circle matching peg visual)
			var collision := CollisionShape2D.new()
			var shape := CircleShape2D.new()
			shape.radius = PEG_RADIUS
			collision.shape = shape
			peg_body.add_child(collision)
			
			_physics_layer.add_child(peg_body)
			_peg_bodies.append(peg_body)

func _create_bucket_sensors() -> void:
	"""Create Area2D sensors for bucket landing detection."""
	_bucket_sensors.clear()
	
	# Create sensors for 5 category buckets
	var bucket_count: int = 5
	var available_width: float = _board_width - BOARD_PADDING * 2.0
	var bucket_width: float = available_width / float(bucket_count)
	var bucket_y: float = _board_height - 56.0
	
	for i in range(bucket_count):
		var bucket_x: float = BOARD_PADDING + bucket_width * (float(i) + 0.5)
		
		# Create Area2D sensor
		var sensor := Area2D.new()
		sensor.position = Vector2(bucket_x, bucket_y)
		sensor.collision_layer = COLLISION_LAYER_BUCKETS
		sensor.collision_mask = COLLISION_LAYER_BALLS
		
		# Create collision shape for sensor (rectangle covering bucket area)
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(bucket_width - 8.0, 40.0)  # Slightly smaller than bucket
		collision.shape = shape
		sensor.add_child(collision)
		
		# Connect body_entered signal to detect when ball enters this bucket
		var bucket_idx: int = i
		sensor.body_entered.connect(_on_bucket_sensor_body_entered.bind(bucket_idx))
		
		_physics_layer.add_child(sensor)
		_bucket_sensors.append(sensor)

func _create_boundary_walls() -> void:
	"""Create left and right wall colliders to keep balls within the board."""
	var wall_thickness: float = 10.0
	var wall_height: float = _board_height - 80.0  # From top to bucket area
	
	# Left wall
	var left_wall := StaticBody2D.new()
	left_wall.position = Vector2(BOARD_PADDING - wall_thickness / 2.0, wall_height / 2.0)
	var left_shape := CollisionShape2D.new()
	var left_rect := RectangleShape2D.new()
	left_rect.size = Vector2(wall_thickness, wall_height)
	left_shape.shape = left_rect
	left_wall.add_child(left_shape)
	_physics_layer.add_child(left_wall)
	
	# Right wall
	var right_wall := StaticBody2D.new()
	right_wall.position = Vector2(_board_width - BOARD_PADDING + wall_thickness / 2.0, wall_height / 2.0)
	var right_shape := CollisionShape2D.new()
	var right_rect := RectangleShape2D.new()
	right_rect.size = Vector2(wall_thickness, wall_height)
	right_shape.shape = right_rect
	right_wall.add_child(right_shape)
	_physics_layer.add_child(right_wall)

func _draw_pegs() -> void:
	if _board_width <= 0.0 or _board_height <= 0.0:
		return

	var available_width: float = _board_width - BOARD_PADDING * 2.0
	var available_height: float = _board_height - 80.0  # Reserve space for buckets
	var row_spacing: float = available_height / float(PEG_ROWS.size() + 1)

	for row_idx in range(PEG_ROWS.size()):
		var row: Array = PEG_ROWS[row_idx]
		var y: float = BOARD_PADDING + row_spacing * float(row_idx + 1)
		for peg_x_norm in row:
			var x: float = BOARD_PADDING + available_width * peg_x_norm
			var pos := Vector2(x, y)

			# Outer glow
			_peg_layer.draw_circle(pos, PEG_RADIUS + 2.0, Color(PEG_GLOW_COLOR, 0.15))
			# Main peg
			_peg_layer.draw_circle(pos, PEG_RADIUS, PEG_COLOR)
			# Highlight
			_peg_layer.draw_circle(pos + Vector2(-1.5, -1.5), PEG_RADIUS * 0.45, Color(PEG_GLOW_COLOR, 0.4))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_board_width = size.x
		_board_height = size.y
		if _peg_layer:
			_peg_layer.queue_redraw()
		# Create physics bodies after resize (when board dimensions are known)
		if _peg_bodies.is_empty() and _board_width > 0 and _board_height > 0:
			_create_peg_physics()
			_create_bucket_sensors()
			_create_boundary_walls()

func _start_idle_animation() -> void:
	# Initialize blur material
	_blur_material = ShaderMaterial.new()
	_blur_material.shader = SLOT_MACHINE_BLUR_SHADER
	_blur_material.set_shader_parameter("blur_amount", 0.0)
	
	# Start slot machine rotation when idle
	start_idle_rotation()

# ══════════════════════════════════════════════════════════════════
# SLOT MACHINE ROTATION
# ══════════════════════════════════════════════════════════════════

func start_idle_rotation() -> void:
	"""Start the slot machine category rotation when plinko is inactive."""
	if _is_rotating or _is_dropping:
		return
	
	# Don't start rotation if a category was manually selected
	if _manually_selected_category:
		return
	
	_is_rotating = true
	_rotation_phase = 0
	_rotation_tick_count = 0
	_current_rotation_index = 0
	_rotation_settle_target = ROTATION_CATEGORIES[randi() % ROTATION_CATEGORIES.size()]
	
	# Hide spawn indicator during rotation
	_update_spawn_indicator_visibility()
	
	# Apply blur effect to bucket layer during spin
	if _blur_material and _bucket_layer:
		_bucket_layer.material = _blur_material
		_blur_material.set_shader_parameter("blur_amount", 5.0)
	
	# Create rotation timer
	if not is_instance_valid(_rotation_timer):
		_rotation_timer = Timer.new()
		_rotation_timer.one_shot = false
		_rotation_timer.timeout.connect(_on_rotation_tick)
		add_child(_rotation_timer)
	
	# Start with fast speed
	_rotation_timer.wait_time = ROTATION_SPEEDS[0]
	_rotation_timer.start()
	
	# Show initial spinning state
	_status_label.text = "🎰 Spinning..."
	
	# Set initial category view
	_selected_category = ROTATION_CATEGORIES[0]
	_rebuild_buckets()

func stop_idle_rotation() -> void:
	"""Stop the slot machine rotation when plinko becomes active."""
	if not _is_rotating:
		return
	
	_is_rotating = false
	
	if is_instance_valid(_rotation_timer):
		_rotation_timer.stop()
	
	# Reset to default view
	_selected_category = -1
	_rebuild_buckets()

func _on_rotation_tick() -> void:
	"""Timer callback for slot machine rotation effect."""
	if not _is_rotating or _is_dropping:
		return
	
	_rotation_tick_count += 1
	
	# Check if we should advance to next phase
	var ticks_needed: int = ROTATION_TICKS_PER_PHASE[_rotation_phase] if _rotation_phase < ROTATION_TICKS_PER_PHASE.size() else 4
	
	if _rotation_tick_count >= ticks_needed:
		_rotation_tick_count = 0
		_rotation_phase += 1
		
		if _rotation_phase >= ROTATION_SPEEDS.size():
			# Settle on target
			_slot_machine_settle()
			return
		
		# Update timer speed for new phase
		_rotation_timer.wait_time = ROTATION_SPEEDS[_rotation_phase]
	
	# Advance to next category
	_current_rotation_index = (_current_rotation_index + 1) % ROTATION_CATEGORIES.size()
	var cat_index: int = ROTATION_CATEGORIES[_current_rotation_index]
	
	# Update display
	_selected_category = cat_index
	_rebuild_buckets()
	
	# Show spinning indicator with category preview
	var cat_name: String = CATEGORY_NAMES[cat_index]
	var cat_emoji: String = CATEGORY_EMOJIS[cat_index]
	
	if _rotation_phase == 0:
		_status_label.text = "🎰 Spinning... %s" % cat_emoji
	elif _rotation_phase == 1:
		_status_label.text = "🎰 Slowing... %s %s" % [cat_emoji, cat_name]
	else:
		_status_label.text = "🎰 Almost... %s %s" % [cat_emoji, cat_name]

func _slot_machine_settle() -> void:
	"""Final settle animation for slot machine."""
	if is_instance_valid(_rotation_timer):
		_rotation_timer.stop()
	
	_is_rotating = false
	
	# Remove blur effect when settling
	if _blur_material and _bucket_layer:
		_blur_material.set_shader_parameter("blur_amount", 0.0)
	
	# Settle on the pre-determined target
	_selected_category = _rotation_settle_target
	_rebuild_buckets()
	
	var cat_name: String = CATEGORY_NAMES[_rotation_settle_target]
	var cat_emoji: String = CATEGORY_EMOJIS[_rotation_settle_target]
	var cat_color: Color = CATEGORY_COLORS[_rotation_settle_target]
	
	# Show settle message with color
	_status_label.text = "✨ %s %s! ✨" % [cat_emoji, cat_name]
	_status_label.add_theme_color_override("font_color", cat_color)
	
	# Highlight the settled bucket with a bounce effect
	var bucket_index: int = _rotation_settle_target
	if _bucket_layer and bucket_index >= 0 and bucket_index < _bucket_layer.get_child_count():
		var bucket: Control = _bucket_layer.get_child(bucket_index)
		var tween: Tween = create_tween()
		tween.tween_property(bucket, "scale", Vector2(1.15, 1.15), 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(bucket, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_IN_OUT)
	
	# Show spawn indicator when settled
	_update_spawn_indicator_visibility()
	
	# Spawn ingredient balls after a brief pause
	var spawn_timer := get_tree().create_timer(0.5)
	spawn_timer.timeout.connect(func():
		if is_instance_valid(self):
			_spawn_ingredient_balls(_rotation_settle_target)
	)

# ══════════════════════════════════════════════════════════════════
# INGREDIENT BALL SPAWNING
# ══════════════════════════════════════════════════════════════════

func _spawn_ingredient_balls(category: int) -> void:
	"""Spawn 3-6 ingredient balls that plinko down into buckets."""
	if category < 0 or category >= CATEGORY_SUBTYPE_DATA.size():
		return
	
	var cat_data: Dictionary = CATEGORY_SUBTYPE_DATA[category]
	var spritesheet: Texture2D = cat_data.spritesheet
	var subtypes: Array = cat_data.subtypes
	var cat_color: Color = CATEGORY_COLORS[category]
	
	# Random number of balls (3-6)
	_balls_total = randi_range(3, 6)
	_balls_landed = 0
	_ingredient_balls.clear()
	
	# Hide spawn indicator while balls are dropping
	_update_spawn_indicator_visibility()
	
	_status_label.text = "🍫 Dropping %d ingredients..." % _balls_total
	
	# Spawn balls with staggered timing
	for i in range(_balls_total):
		var subtype_index: int = randi() % subtypes.size()
		var subtype: Dictionary = subtypes[subtype_index]
		
		var spawn_delay: float = float(i) * 0.15
		var delay_timer := get_tree().create_timer(spawn_delay)
		delay_timer.timeout.connect(func():
			if is_instance_valid(self):
				_spawn_single_ball(spritesheet, subtype.column, cat_color, i)
		)

func _spawn_single_ball(spritesheet: Texture2D, column: int, cat_color: Color, ball_index: int) -> void:
	"""Spawn a single ingredient ball with physics simulation."""
	# Create RigidBody2D for physics
	var ball := RigidBody2D.new()
	ball.gravity_scale = 1.0
	ball.mass = BALL_MASS
	ball.collision_layer = COLLISION_LAYER_BALLS
	ball.collision_mask = 1 | COLLISION_LAYER_BALLS | COLLISION_LAYER_BUCKETS  # Include layer 1 for pegs/walls
	ball.contact_monitor = true
	ball.max_contacts_reported = 1
	ball.physics_material_override = PhysicsMaterial.new()
	ball.physics_material_override.bounce = BALL_BOUNCE
	ball.physics_material_override.friction = BALL_FRICTION
	
	# Create collision shape (circle)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = BALL_RADIUS
	collision.shape = shape
	ball.add_child(collision)
	
	# Create sprite texture from spritesheet
	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = spritesheet
	atlas_tex.region = _get_sprite_region(spritesheet, column)
	
	var sprite := TextureRect.new()
	sprite.texture = atlas_tex
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2(BALL_RADIUS * 2.0, BALL_RADIUS * 2.0)
	sprite.position = Vector2(-BALL_RADIUS, -BALL_RADIUS)  # Center on physics body
	ball.add_child(sprite)
	
	# Add to physics layer
	_physics_layer.add_child(ball)
	_ingredient_balls.append(ball)
	
	# Track spawn time for timeout detection
	_ball_spawn_times[ball] = Time.get_ticks_msec() / 1000.0
	
	# Starting position: spread across top with some randomness
	var available_width: float = _board_width - BOARD_PADDING * 2.0
	var start_x: float = BOARD_PADDING + (available_width * float(ball_index + 1)) / float(_balls_total + 1)
	start_x += randf_range(-15.0, 15.0)
	var start_y: float = BOARD_PADDING + BALL_RADIUS + 5.0
	ball.position = Vector2(start_x, start_y)
	
	# Give initial velocity with slight horizontal variation
	ball.linear_velocity = Vector2(randf_range(-20.0, 20.0), 0.0)
	
	# Connect signal for when ball enters bucket sensor
	ball.body_entered.connect(_on_ball_body_entered.bind(ball))

func _on_ball_body_entered(body: PhysicsBody2D, ball: RigidBody2D) -> void:
	"""Called when ball collides with something - check if it's a bucket sensor."""
	# Check if this is a bucket sensor
	for i in range(_bucket_sensors.size()):
		if body == _bucket_sensors[i] or body.get_parent() == _bucket_sensors[i]:
			_on_ball_landed(ball, i)
			return

func _on_bucket_sensor_body_entered(body: PhysicsBody2D, bucket_index: int) -> void:
	"""Called when a body enters a bucket sensor area."""
	# Check if the body is an ingredient ball
	for ball in _ingredient_balls:
		if ball == body:
			_on_ball_landed(ball, bucket_index)
			return

func _on_ball_landed(ball: RigidBody2D, bucket_index: int = -1) -> void:
	"""Called when an ingredient ball lands in a bucket."""
	# Freeze the ball so it stops moving
	ball.freeze = true
	
	_balls_landed += 1
	
	# Check if all balls have landed
	if _balls_landed >= _balls_total:
		_all_balls_landed()

func _all_balls_landed() -> void:
	"""Called when all ingredient balls have landed."""
	_status_label.text = "✨ All ingredients settled!"
	
	# Wait 1 second then clear balls and restart rotation
	var wait_timer := get_tree().create_timer(1.0)
	wait_timer.timeout.connect(func():
		if is_instance_valid(self):
			_clear_ingredient_balls()
			_status_label.add_theme_color_override("font_color", Color(GameData.ACCENT_GOLD, 0.7))
			start_idle_rotation()
	)

func _clear_ingredient_balls() -> void:
	"""Remove all ingredient balls from the board."""
	for ball in _ingredient_balls:
		if is_instance_valid(ball):
			ball.queue_free()
	_ingredient_balls.clear()
	_ball_spawn_times.clear()
	_balls_landed = 0
	_balls_total = 0

func _process(_delta: float) -> void:
	"""Check for stuck ingredient balls that have exceeded the timeout."""
	if _ingredient_balls.is_empty():
		return
	
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var timed_out_balls: Array[RigidBody2D] = []
	
	for ball in _ingredient_balls:
		if not is_instance_valid(ball):
			continue
		if ball.freeze:
			continue  # Already landed, skip
		if _ball_spawn_times.has(ball):
			var spawn_time: float = _ball_spawn_times[ball]
			if current_time - spawn_time > BALL_TIMEOUT:
				timed_out_balls.append(ball)
	
	# Force-land timed-out balls
	for ball in timed_out_balls:
		ball.freeze = true
		_balls_landed += 1
		_ball_spawn_times.erase(ball)
	
	# Check if all balls have now landed (including timed-out ones)
	if not timed_out_balls.is_empty() and _balls_landed >= _balls_total:
		_all_balls_landed()

func _create_hover_popup() -> void:
	# Create shared hover popup that appears next to mouse
	_hover_popup = PanelContainer.new()
	_hover_popup.visible = false
	_hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_popup.z_index = 100  # Ensure popup appears above everything
	
	# Style the popup
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color("#1a0d0a")
	popup_style.border_color = GameData.ACCENT_GOLD
	popup_style.set_border_width_all(1)
	popup_style.set_corner_radius_all(4)
	popup_style.content_margin_left = 8
	popup_style.content_margin_right = 8
	popup_style.content_margin_top = 4
	popup_style.content_margin_bottom = 4
	_hover_popup.add_theme_stylebox_override("panel", popup_style)
	
	# Add label inside popup
	_hover_popup_label = Label.new()
	_hover_popup_label.add_theme_font_size_override("font_size", 11)
	_hover_popup_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	_hover_popup.add_child(_hover_popup_label)
	
	add_child(_hover_popup)
	
	# Create hover timer
	_hover_timer = Timer.new()
	_hover_timer.wait_time = 0.5
	_hover_timer.one_shot = true
	_hover_timer.timeout.connect(_show_hover_popup)
	add_child(_hover_timer)

func _show_hover_popup() -> void:
	if _current_hover_bucket == null:
		return
	
	# Position popup next to mouse with 5px padding
	var mouse_pos := get_global_mouse_position()
	_hover_popup.position = mouse_pos + Vector2(5, 5)
	_hover_popup.visible = true

func _hide_hover_popup() -> void:
	_hover_popup.visible = false
	_current_hover_bucket = null
	_hover_timer.stop()

# ══════════════════════════════════════════════════════════════════
# SPAWN LOCATION INDICATOR
# ══════════════════════════════════════════════════════════════════

func _create_spawn_indicator() -> void:
	"""Create the spawn location indicator ball."""
	_spawn_indicator = TextureRect.new()
	_spawn_indicator.custom_minimum_size = Vector2(SPAWN_INDICATOR_SIZE, SPAWN_INDICATOR_SIZE)
	_spawn_indicator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spawn_indicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spawn_indicator.visible = false
	_spawn_indicator.z_index = 50  # Above pegs but below buckets
	
	# Create a simple circle texture for the indicator
	var image := Image.create(int(SPAWN_INDICATOR_SIZE), int(SPAWN_INDICATOR_SIZE), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(SPAWN_INDICATOR_SIZE / 2.0, SPAWN_INDICATOR_SIZE / 2.0)
	var radius := SPAWN_INDICATOR_SIZE / 2.0 - 2.0
	
	for x in range(int(SPAWN_INDICATOR_SIZE)):
		for y in range(int(SPAWN_INDICATOR_SIZE)):
			var dist := Vector2(x, y).distance_to(center)
			if dist <= radius:
				var alpha := 1.0 - (dist / radius) * 0.3
				image.set_pixel(x, y, Color(GameData.ACCENT_GOLD.r, GameData.ACCENT_GOLD.g, GameData.ACCENT_GOLD.b, alpha))
	
	var texture := ImageTexture.create_from_image(image)
	_spawn_indicator.texture = texture
	
	add_child(_spawn_indicator)
	_update_spawn_indicator_position()

func _update_spawn_indicator_position() -> void:
	"""Update spawn indicator position based on board width."""
	if not is_instance_valid(_spawn_indicator):
		return
	var center_x: float = _board_width / 2.0
	var spawn_y: float = BOARD_PADDING + SPAWN_INDICATOR_SIZE / 2.0 + 5.0
	_spawn_indicator.position = Vector2(center_x - SPAWN_INDICATOR_SIZE / 2.0, spawn_y)

func _update_spawn_indicator_visibility() -> void:
	"""Show/hide spawn indicator based on current state."""
	if not is_instance_valid(_spawn_indicator):
		return
	
	var should_show: bool = (_selected_category >= 0 and not _is_rotating and not _is_dropping)
	_spawn_indicator.visible = should_show
	
	if should_show:
		_start_spawn_animation()
	else:
		_stop_spawn_animation()

func _start_spawn_animation() -> void:
	"""Start oscillating animation for spawn indicator."""
	if not is_instance_valid(_spawn_indicator):
		return
	
	if _spawn_tween:
		_spawn_tween.kill()
	
	_spawn_tween = create_tween()
	_spawn_tween.set_loops()
	
	var available_width: float = _board_width - BOARD_PADDING * 2.0
	var left_x: float = BOARD_PADDING + available_width * 0.2
	var right_x: float = BOARD_PADDING + available_width * 0.8
	var spawn_y: float = BOARD_PADDING + SPAWN_INDICATOR_SIZE / 2.0 + 5.0
	
	_spawn_tween.tween_property(_spawn_indicator, "position", Vector2(left_x - SPAWN_INDICATOR_SIZE / 2.0, spawn_y), 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_spawn_tween.tween_property(_spawn_indicator, "position", Vector2(right_x - SPAWN_INDICATOR_SIZE / 2.0, spawn_y), 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _stop_spawn_animation() -> void:
	"""Stop spawn indicator animation."""
	if _spawn_tween:
		_spawn_tween.kill()
		_spawn_tween = null

# ══════════════════════════════════════════════════════════════════
# COIN DROP ANIMATION
# ══════════════════════════════════════════════════════════════════

func play_drop_animation(coin_type: String, pocket_index: int, category: int) -> void:
	if _is_dropping:
		return
	
	# Stop rotation when dropping
	stop_idle_rotation()
	
	_is_dropping = true

	var coin_color: Color = COIN_COLORS.get(coin_type, COIN_COLORS["bar"])
	_status_label.text = "Dropping %s coin..." % coin_type.capitalize()

	# Create coin visual
	_coin_node = Control.new()
	_coin_node.custom_minimum_size = Vector2(20, 20)
	var coin_circle := ColorRect.new()
	coin_circle.custom_minimum_size = Vector2(16, 16)
	coin_circle.color = coin_color
	_coin_node.add_child(coin_circle)
	add_child(_coin_node)

	# Starting position: top center with slight random offset
	var start_x: float = _board_width * 0.5 + randf_range(-30.0, 30.0)
	var start_y: float = BOARD_PADDING + 10.0
	_coin_node.position = Vector2(start_x, start_y)

	# Build drop path through peg rows
	var available_width: float = _board_width - BOARD_PADDING * 2.0
	var available_height: float = _board_height - 80.0
	var row_spacing: float = available_height / float(PEG_ROWS.size() + 1)

	# Determine final bucket X position (mapped from pocket_index to bucket)
	var bucket_count: int = get_bucket_count()
	var bucket_index: int = clampi(int(float(pocket_index) / 10.0 * float(bucket_count)), 0, bucket_count - 1)
	var bucket_center_x: float = BOARD_PADDING + available_width * (float(bucket_index) + 0.5) / float(bucket_count)
	var bucket_y: float = _board_height - 56.0

	# Build waypoints through each peg row
	var waypoints: Array[Vector2] = []
	waypoints.append(Vector2(start_x, start_y))

	var current_x: float = start_x
	for row_idx in range(PEG_ROWS.size()):
		var y: float = BOARD_PADDING + row_spacing * float(row_idx + 1)
		# Random deflection at each row (biased toward final bucket)
		var bias: float = (bucket_center_x - current_x) * 0.15
		current_x += randf_range(-20.0, 20.0) + bias
		current_x = clampf(current_x, BOARD_PADDING + 10.0, _board_width - BOARD_PADDING - 10.0)
		waypoints.append(Vector2(current_x, y))

	# Final bucket landing
	waypoints.append(Vector2(bucket_center_x, bucket_y))

	# Animate through waypoints
	var tween: Tween = create_tween()
	for i in range(1, waypoints.size()):
		var duration: float = 0.12 if i < waypoints.size() - 1 else 0.18
		var ease_type: Tween.EaseType = Tween.EASE_IN_OUT if i < waypoints.size() - 1 else Tween.EASE_OUT
		tween.tween_property(_coin_node, "position", waypoints[i], duration).set_ease(ease_type).set_trans(Tween.TRANS_QUAD)

	# Scale down on landing
	tween.tween_property(_coin_node, "scale", Vector2(0.5, 0.5), 0.1).set_ease(Tween.EASE_IN)
	tween.tween_property(_coin_node, "modulate:a", 0.0, 0.15)

	# Finish
	tween.tween_callback(_on_drop_complete.bind(pocket_index, category))

func _on_drop_complete(pocket_index: int, category: int) -> void:
	if is_instance_valid(_coin_node):
		_coin_node.queue_free()
	_coin_node = null
	_is_dropping = false

	var cat_name: String = CATEGORY_NAMES[category] if category < CATEGORY_NAMES.size() else "Unknown"
	var cat_emoji: String = CATEGORY_EMOJIS[category] if category < CATEGORY_EMOJIS.size() else "❓"
	_status_label.text = "%s Landed in %s!" % [cat_emoji, cat_name]

	drop_animation_complete.emit(pocket_index, category)

	# Reset status after a moment and either restart rotation or keep category selected
	var reset_timer := get_tree().create_timer(2.0)
	reset_timer.timeout.connect(func():
		if not _is_dropping and is_instance_valid(_status_label):
			if _manually_selected_category:
				# Keep the manually selected category visible
				_status_label.text = "%s %s selected — drop a coin!" % [CATEGORY_EMOJIS[_selected_category], CATEGORY_NAMES[_selected_category]]
				_update_spawn_indicator_visibility()
			else:
				# Restart slot machine rotation after drop completes
				_status_label.text = "Drop a coin to begin"
				start_idle_rotation()
	)

# ══════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════

func is_busy() -> bool:
	return _is_dropping

func set_category(category_index: int) -> void:
	_selected_category = clampi(category_index, 0, 4)
	_manually_selected_category = true  # Track that this was manually selected
	_rebuild_buckets()
	_status_label.text = "%s %s selected — drop a coin!" % [CATEGORY_EMOJIS[_selected_category], CATEGORY_NAMES[_selected_category]]
	# Show spawn indicator when category is selected
	_update_spawn_indicator_visibility()

func clear_category() -> void:
	_selected_category = -1
	_manually_selected_category = false  # Reset manual selection flag
	_rebuild_buckets()
	_status_label.text = "Select a category to begin"
	# Hide spawn indicator when category is cleared
	_update_spawn_indicator_visibility()

func _rebuild_buckets() -> void:
	if not _bucket_layer:
		return
	
	# Clear existing buckets
	for child in _bucket_layer.get_children():
		child.queue_free()
	
	# Wait a frame for queue_free to complete
	await get_tree().process_frame
	
	if _selected_category < 0:
		# Show 5 category buckets
		for i in range(5):
			_create_category_bucket(i)
	else:
		# Show 6 subtype buckets for selected category
		var subtypes: Array = SUBTYPE_POOLS[_selected_category]
		var emojis: Array = SUBTYPE_EMOJIS[_selected_category]
		var cat_color: Color = CATEGORY_COLORS[_selected_category]
		for i in range(6):
			_create_subtype_bucket(subtypes[i], emojis[i], cat_color, _selected_category, i)

func _create_category_bucket(cat_index: int) -> void:
	var cat_color: Color = CATEGORY_COLORS[cat_index]
	
	if cat_index == 4:
		# Wildcard: resolve one random subtype and show as sprite icon
		var resolved: Dictionary = _resolve_wildcard_subtype()
		var bucket := PanelContainer.new()
		bucket.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bucket.custom_minimum_size = Vector2(0, 56)
		var bucket_style := StyleBoxFlat.new()
		bucket_style.bg_color = cat_color.darkened(0.6)
		bucket_style.border_color = cat_color
		bucket_style.set_border_width_all(1)
		bucket_style.set_corner_radius_all(4)
		bucket.add_theme_stylebox_override("panel", bucket_style)
		_bucket_layer.add_child(bucket)

		# Sprite texture
		var atlas_tex := AtlasTexture.new()
		atlas_tex.atlas = resolved.spritesheet
		atlas_tex.region = _get_sprite_region(resolved.spritesheet, resolved.column)

		var sprite := TextureRect.new()
		sprite.texture = atlas_tex
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.custom_minimum_size = Vector2(40, 40)
		sprite.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		bucket.add_child(sprite)

		# Tooltip
		bucket.mouse_entered.connect(func():
			_current_hover_bucket = bucket
			_hover_popup_label.text = resolved.label
			_hover_popup_label.add_theme_color_override("font_color", cat_color)
			_hover_timer.start()
		)
		bucket.mouse_exited.connect(func():
			if _current_hover_bucket == bucket:
				_hide_hover_popup()
		)
		return
	
	# Standard category: text + emoji label
	var bucket := PanelContainer.new()
	bucket.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bucket.custom_minimum_size = Vector2(0, 56)
	var bucket_style := StyleBoxFlat.new()
	bucket_style.bg_color = cat_color.darkened(0.6)
	bucket_style.border_color = cat_color
	bucket_style.set_border_width_all(1)
	bucket_style.set_corner_radius_all(4)
	bucket.add_theme_stylebox_override("panel", bucket_style)
	_bucket_layer.add_child(bucket)

	var bucket_vbox := VBoxContainer.new()
	bucket_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bucket_vbox.add_theme_constant_override("separation", 1)
	bucket.add_child(bucket_vbox)

	var bucket_title := Label.new()
	bucket_title.text = "%s %s" % [CATEGORY_EMOJIS[cat_index], CATEGORY_NAMES[cat_index]]
	bucket_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	bucket_title.add_theme_color_override("font_color", cat_color)
	bucket_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bucket_vbox.add_child(bucket_title)

	var bucket_sub := Label.new()
	bucket_sub.text = CATEGORY_SUBTYPES[cat_index]
	bucket_sub.add_theme_font_size_override("font_size", GameData.scaled_font_size(7))
	bucket_sub.add_theme_color_override("font_color", Color(cat_color, 0.65))
	bucket_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bucket_sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	bucket_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bucket_vbox.add_child(bucket_sub)

func _create_subtype_bucket(_subtype_name: String, _emoji: String, cat_color: Color, cat_index: int, sub_index: int = 0) -> void:
	if CATEGORY_SUBTYPE_DATA.has(cat_index):
		# Standard category: use sprite bucket from centralized data
		var cat_data: Dictionary = CATEGORY_SUBTYPE_DATA[cat_index]
		var subtype: Dictionary = cat_data.subtypes[sub_index]
		_create_sprite_bucket(cat_data.spritesheet, subtype.column, subtype.label, cat_color)
	else:
		# Wildcard (cat_index 4): resolve from mixed pool
		var resolved: Dictionary = _resolve_wildcard_subtype()
		_create_sprite_bucket(resolved.spritesheet, resolved.column, resolved.label, cat_color)

func get_selected_category() -> int:
	return _selected_category

func get_bucket_count() -> int:
	if _selected_category < 0:
		return 5
	return 6

func highlight_bucket(bucket_index: int) -> void:
	if _bucket_layer and bucket_index >= 0 and bucket_index < _bucket_layer.get_child_count():
		var bucket: Control = _bucket_layer.get_child(bucket_index)
		var tween: Tween = create_tween()
		tween.tween_property(bucket, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(bucket, "scale", Vector2(1.0, 1.0), 0.1)
