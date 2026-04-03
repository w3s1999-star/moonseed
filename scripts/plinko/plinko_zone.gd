extends Area2D

# ─────────────────────────────────────────────────────────────────
# plinko_zone.gd  —  MOONSEED  v0.10
# Category zone magnet for the Plinko system.
# Zones attract coins and influence category resolution.
# ─────────────────────────────────────────────────────────────────

signal zone_activated(category: String)
signal coin_attracted(coin_type: String)

# ── Zone Configuration ───────────────────────────────────────────
@export var zone_category: String = "fruit"
@export var attraction_strength: float = 1.0
@export var zone_radius: float = 50.0

# ── Visual State ────────────────────────────────────────────────
var is_active: bool = false
var attracted_coins: Array = []
var zone_color: Color = Color.WHITE

# ── Visual Nodes ────────────────────────────────────────────────
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_indicator: Sprite2D = $VisualIndicator
@onready var particle_effect: GPUParticles2D = $ParticleEffect
@onready var glow_light: PointLight2D = $GlowLight

# ── Zone Colors ──────────────────────────────────────────────────
const ZONE_COLORS: Dictionary = {
	"fruit": Color("#ff6b6b"),
	"crunch": Color("#ffd66b"),
	"floral": Color("#ff9fff"),
	"spice": Color("#ff8c42"),
	"wild": Color("#a855f7")
}

func _ready() -> void:
	_setup_zone()
	_connect_signals()

func _setup_zone() -> void:
	# Set zone color
	zone_color = ZONE_COLORS.get(zone_category, Color.WHITE)
	
	# Configure collision shape
	if collision_shape:
		var circle_shape: CircleShape2D = CircleShape2D.new()
		circle_shape.radius = zone_radius
		collision_shape.shape = circle_shape
	
	# Apply visual settings
	_update_visuals()

func _connect_signals() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _update_visuals() -> void:
	# Update indicator color
	if visual_indicator:
		visual_indicator.modulate = zone_color
		visual_indicator.modulate.a = 0.3 if is_active else 0.1
	
	# Update glow light
	if glow_light:
		glow_light.color = zone_color
		glow_light.energy = 1.0 if is_active else 0.3
	
	# Update particles
	if particle_effect:
		particle_effect.emitting = is_active

# ── Zone State ────────────────────────────────────────────────────
func activate() -> void:
	is_active = true
	_update_visuals()
	zone_activated.emit(zone_category)

func deactivate() -> void:
	is_active = false
	_update_visuals()

func get_zone_category() -> String:
	return zone_category

func get_attraction_strength() -> float:
	return attraction_strength

# ── Attraction Logic ──────────────────────────────────────────────
func get_attraction_force(coin_position: Vector2) -> Vector2:
	if not is_active:
		return Vector2.ZERO
	
	var to_zone: Vector2 = global_position - coin_position
	var distance: float = to_zone.length()
	
	if distance < 1.0:
		return Vector2.ZERO
	
	# Inverse square attraction (stronger when closer)
	var force_magnitude: float = attraction_strength * 1000.0 / (distance * distance)
	
	# Clamp maximum force
	force_magnitude = min(force_magnitude, 200.0)
	
	return to_zone.normalized() * force_magnitude

# ── Coin Interaction ──────────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("get_coin_type"):
		var coin_type: String = body.get_coin_type()
		attracted_coins.append(body)
		coin_attracted.emit(coin_type)
		
		# Add influence to controller
		if has_node("/root/PlinkoController"):
			get_node("/root/PlinkoController").on_zone_entered(zone_category)

func _on_body_exited(body: Node2D) -> void:
	if attracted_coins.has(body):
		attracted_coins.erase(body)

func _on_area_entered(area: Area2D) -> void:
	# Handle area-based coins
	if area.has_method("get_coin_type"):
		var coin_type: String = area.get_coin_type()
		coin_attracted.emit(coin_type)

func _on_area_exited(_area: Area2D) -> void:
	pass

# ── Visual Feedback ──────────────────────────────────────────────
func pulse_effect() -> void:
	if visual_indicator:
		var tween: Tween = create_tween()
		tween.tween_property(visual_indicator, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(visual_indicator, "scale", Vector2(1.0, 1.0), 0.1)

func show_attraction_hint() -> void:
	if glow_light:
		var tween: Tween = create_tween()
		tween.tween_property(glow_light, "energy", 2.0, 0.2)
		tween.tween_property(glow_light, "energy", 1.0 if is_active else 0.3, 0.2)

# ── Category Helpers ──────────────────────────────────────────────
func get_category_emoji() -> String:
	match zone_category:
		"fruit": return "🍓"
		"crunch": return "🍪"
		"floral": return "🌸"
		"spice": return "🌶️"
		"wild": return "🎲"
		_: return "❓"

func get_category_name() -> String:
	match zone_category:
		"fruit": return "Fruit"
		"crunch": return "Crunch"
		"floral": return "Floral"
		"spice": return "Spice"
		"wild": return "Wildcard"
		_: return "Unknown"

# ── Debug ────────────────────────────────────────────────────────
func get_debug_info() -> Dictionary:
	return {
		"category": zone_category,
		"active": is_active,
		"attraction": attraction_strength,
		"coins_attracted": attracted_coins.size()
	}