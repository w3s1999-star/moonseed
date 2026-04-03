extends Node2D

# ─────────────────────────────────────────────────────────────────
# plinko_coin.gd  —  MOONSEED  v0.10
# Individual coin behavior for the Plinko system.
# ─────────────────────────────────────────────────────────────────

signal coin_settled(pocket_index: int)
signal zone_entered(zone_category: String)

# ── Coin Configuration ───────────────────────────────────────────
@export var coin_type: String = "bar"
@export var coin_value: int = 1

# ── Physics State ────────────────────────────────────────────────
var velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var is_settled: bool = false
var current_pocket: int = -1

# ── Coin Properties (set by controller) ─────────────────────────
var mass: float = 1.0
var bounce_factor: float = 0.7
var spread_modifier: float = 1.0
var steering_strength: float = 0.0
var has_glow: bool = false
var coin_color: Color = Color("#8B4513")

# ── Visual Nodes ────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_effect: PointLight2D = $GlowEffect
@onready var trail_particles: GPUParticles2D = $TrailParticles

# ── Constants ────────────────────────────────────────────────────
const GRAVITY: float = 980.0
const BOUNCE_DAMPING: float = 0.6
const ROTATION_SPEED: float = 5.0
const SETTLE_THRESHOLD: float = 10.0

func _ready() -> void:
	_setup_coin()

func _setup_coin() -> void:
	# Set properties based on coin type
	match coin_type:
		"bar":
			mass = 1.0
			bounce_factor = 0.7
			spread_modifier = 1.2
			steering_strength = 0.0
			has_glow = false
			coin_color = Color("#8B4513")
			coin_value = 1
		"truffle":
			mass = 1.3
			bounce_factor = 0.5
			spread_modifier = 0.9
			steering_strength = 0.15
			has_glow = false
			coin_color = Color("#4a2c2a")
			coin_value = 2
		"artisan":
			mass = 1.5
			bounce_factor = 0.4
			spread_modifier = 0.7
			steering_strength = 0.3
			has_glow = true
			coin_color = Color("#ffd700")
			coin_value = 3
	
	# Apply visual settings
	if sprite:
		sprite.modulate = coin_color
	
	if glow_effect:
		glow_effect.enabled = has_glow
		if has_glow:
			glow_effect.energy = 1.5
			glow_effect.color = coin_color
	
	if trail_particles:
		trail_particles.emitting = has_glow

func _physics_process(delta: float) -> void:
	if is_settled:
		return
	
	# Apply gravity
	velocity.y += GRAVITY * mass * delta
	
	# Apply steering (for truffle and artisan coins)
	if steering_strength > 0:
		var steer_input: float = _get_steering_input()
		velocity.x += steer_input * steering_strength * 500.0 * delta
	
	# Update position
	position += velocity * delta
	
	# Update rotation
	angular_velocity = velocity.x * ROTATION_SPEED * 0.01
	rotation += angular_velocity * delta
	
	# Check if settled
	if velocity.length() < SETTLE_THRESHOLD:
		_settle()

func _get_steering_input() -> float:
	# For now, return 0 (no steering)
	# In a full implementation, this would read player input
	return 0.0

func _settle() -> void:
	is_settled = true
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	
	# Emit settled signal
	coin_settled.emit(current_pocket)

func apply_bounce(normal: Vector2) -> void:
	if is_settled:
		return
	
	# Reflect velocity with damping
	velocity = velocity.bounce(normal) * bounce_factor * BOUNCE_DAMPING
	
	# Reduce angular velocity on bounce
	angular_velocity *= 0.5

func apply_peg_collision(peg_position: Vector2) -> void:
	if is_settled:
		return
	
	# Calculate bounce direction
	var to_coin: Vector2 = position - peg_position
	var bounce_dir: Vector2 = to_coin.normalized()
	
	# Apply bounce
	var speed: float = velocity.length()
	velocity = bounce_dir * speed * bounce_factor
	
	# Add some randomness for spread
	var spread_angle: float = randf_range(-0.3, 0.3) * spread_modifier
	velocity = velocity.rotated(spread_angle)

func set_pocket(pocket_index: int) -> void:
	current_pocket = pocket_index

func get_coin_type() -> String:
	return coin_type

func get_coin_value() -> int:
	return coin_value

func get_coin_color() -> Color:
	return coin_color

func is_glowing() -> bool:
	return has_glow

# ── Zone Detection ───────────────────────────────────────────────
func _on_zone_detector_area_entered(area: Area2D) -> void:
	if area.has_method("get_zone_category"):
		var zone_category: String = area.get_zone_category()
		zone_entered.emit(zone_category)

# ── Trail Effect ────────────────────────────────────────────────
func _update_trail() -> void:
	if trail_particles and has_glow:
		trail_particles.emitting = velocity.length() > 50.0

func _on_visibility_changed() -> void:
	if trail_particles:
		trail_particles.emitting = visible and has_glow