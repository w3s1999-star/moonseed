extends Node
class_name RewardFXController

## Centralized visual resolution for the dice reward ritual.
## Spawns moondrops, animates merges, crystallizes pearls, runs final burst.

@onready var _fx_host: Node = get_tree().get_root()

# ── Timing Constants ─────────────────────────────────────────────
const SPAWN_DELAY_PER_DIE: float = 0.05
const SPAWN_DURATION: float = 0.35
const MERGE_DURATION: float = 0.38
const CRYSTALLIZE_DELAY_PER_CLUSTER: float = 0.14
const CRYSTALLIZE_DURATION: float = 0.28
const PEARL_FLY_DURATION: float = 0.55
const FINAL_BURST_DURATION: float = 0.35

# ── Moondrop Constants ───────────────────────────────────────────
const DROPLETS_PER_MOONDROP: int = 3
const MAX_DROPLETS_PER_DIE: int = 18
const EXPLOSION_DROPLET_BONUS: int = 8

# ── Cluster Constants ────────────────────────────────────────────
const CLUSTER_CONVERGE_RADIUS: float = 36.0
const PEARLS_PER_CLUSTER: int = 3

# ── State ────────────────────────────────────────────────────────
var _active_drops: Array = []
var _active_clusters: Array = []
var _is_resolving: bool = false

# ── Public API ───────────────────────────────────────────────────

## Spawns moondrop visuals for each die in the packet.
## Returns when all drops have been spawned (not landed).
func spawn_moondrops(packet: Dictionary, table_center: Vector2) -> void:
	var dice: Array = packet.get("dice", [])
	for i in range(dice.size()):
		var die: Dictionary = dice[i]
		var amount: int = int(die.get("base_moondrops", 0))
		var is_explosion: bool = "explosion" in die.get("effect_tags", [])
		var drop_count: int = mini(amount / 5, MAX_DROPLETS_PER_DIE)
		if is_explosion:
			drop_count += EXPLOSION_DROPLET_BONUS

		# Scatter spawn position around table center
		var angle: float = (TAU / float(dice.size())) * float(i)
		var spawn_pos: Vector2 = table_center + Vector2(cos(angle), sin(angle)) * 60.0

		var drops: Array = _spawn_drop_icons(drop_count, spawn_pos)
		_active_drops.append_array(drops)

		# Stagger spawn
		await get_tree().create_timer(SPAWN_DELAY_PER_DIE).timeout

## Animates drops merging into clusters.
func animate_merge(packet: Dictionary) -> void:
	if _active_drops.is_empty():
		return

	# Filter to alive icons
	var valid: Array = []
	for drop in _active_drops:
		if is_instance_valid(drop):
			valid.append(drop)

	if valid.is_empty():
		return

	# Compute centroid
	var sum := Vector2.ZERO
	for drop in valid:
		sum += drop.global_position + drop.size * 0.5
	var center: Vector2 = sum / float(valid.size())

	# Create cluster
	var cluster_id: String = "cluster_%d" % Time.get_ticks_msec()
	var cluster: Dictionary = {
		"cluster_id": cluster_id,
		"center": center,
		"drops": valid.duplicate(),
		"value": int(packet.get("flat_total", 0)),
	}
	_active_clusters.append(cluster)

	# Animate drops converging to centroid
	for drop in valid:
		var sz: float = drop.size.x
		var dest: Vector2 = center + Vector2(
			randf_range(-5.0, 5.0),
			randf_range(-5.0, 5.0))
		var tw: Tween = drop.create_tween()
		tw.tween_property(drop, "global_position",
			dest - Vector2(sz * 0.5, sz * 0.5),
			MERGE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(drop, "rotation", 0.0, MERGE_DURATION)
		tw.parallel().tween_property(drop, "scale",
			Vector2(0.78, 0.78), MERGE_DURATION)

	# Wait for merge to complete
	await get_tree().create_timer(MERGE_DURATION + 0.05).timeout

	# Update packet clusters
	packet["clusters"] = _active_clusters.duplicate()

## Crystallizes clusters into moonpearls.
func crystallize_pearls(packet: Dictionary, hud_target: Vector2) -> void:
	for cluster in _active_clusters:
		var center: Vector2 = cluster.get("center", Vector2.ZERO)
		var drops: Array = cluster.get("drops", [])

		# Dissolve merged drops
		for drop in drops:
			if not is_instance_valid(drop):
				continue
			var tw: Tween = drop.create_tween()
			tw.tween_property(drop, "scale", Vector2.ZERO, 0.18)
			tw.parallel().tween_property(drop, "modulate:a", 0.0, 0.18)
			tw.tween_callback(drop.queue_free)

		# Spawn pearls
		for pi in range(PEARLS_PER_CLUSTER):
			var angle: float = randf() * TAU
			var dist: float = randf_range(14.0, 55.0)
			var spawn_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
			var delay: float = float(pi) * CRYSTALLIZE_DELAY_PER_CLUSTER

			if delay > 0.0:
				await get_tree().create_timer(delay).timeout

			_spawn_pearl_at(spawn_pos, hud_target)

	# Wait for crystallization
	await get_tree().create_timer(CRYSTALLIZE_DURATION).timeout

	# Clear clusters
	_active_clusters.clear()
	_active_drops.clear()

## Runs final burst effects (UI tick, sparkles, etc).
func final_burst(summary: Dictionary, table_center: Vector2) -> void:
	var moonpearls: int = int(summary.get("moonpearls", 0))
	var moondrops: int = int(summary.get("multiplied_total", 0))

	# Sparkle burst at table center
	if moonpearls > 0:
		_burst_sparkles(table_center, 8 + moonpearls * 2)

	# Confetti for big rolls
	if moondrops > 100:
		_burst_confetti(2.0)

	await get_tree().create_timer(FINAL_BURST_DURATION).timeout

# ── Internal Helpers ─────────────────────────────────────────────

func _spawn_drop_icons(count: int, origin: Vector2) -> Array:
	var icons: Array = []
	var GameData_node = get_node_or_null("/root/GameData")
	if GameData_node == null:
		return icons

	for _i in range(clampi(count, 1, 32)):
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sz: float = randf_range(14.0, 22.0)
		icon.custom_minimum_size = Vector2(sz, sz)
		icon.size = Vector2(sz, sz)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
		icon.z_index = 180

		if GameData_node.has_method("_set_random_moondrop_frame"):
			GameData_node._set_random_moondrop_frame(icon)

		# Spawn near origin with scatter
		var scatter: Vector2 = Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		icon.global_position = origin + scatter - Vector2(sz * 0.5, sz * 0.5)
		icon.modulate.a = 0.0

		_fx_host.add_child(icon)

		# Fade in
		var tw: Tween = icon.create_tween()
		tw.tween_property(icon, "modulate:a", 1.0, 0.12)

		icons.append(icon)

	return icons

func _spawn_pearl_at(pos: Vector2, hud_target: Vector2) -> void:
	var GameData_node = get_node_or_null("/root/GameData")
	if GameData_node == null:
		return

	const PSZ := 36.0
	var pearl := TextureRect.new()
	pearl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pearl.custom_minimum_size = Vector2(PSZ, PSZ)
	pearl.size = Vector2(PSZ, PSZ)
	pearl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pearl.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	pearl.pivot_offset = Vector2(PSZ * 0.5, PSZ * 0.5)
	pearl.z_index = 185

	if GameData_node.has_method("_set_random_moonpearls_frame"):
		GameData_node._set_random_moonpearls_frame(pearl)

	pearl.modulate.a = 0.0
	pearl.scale = Vector2(0.2, 0.2)
	_fx_host.add_child(pearl)
	pearl.global_position = pos - Vector2(PSZ * 0.5, PSZ * 0.5)

	# Crystallize pop
	var tw: Tween = pearl.create_tween()
	tw.tween_property(pearl, "scale", Vector2(2.4, 2.4), 0.09).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(pearl, "modulate:a", 1.0, 0.09)
	tw.tween_property(pearl, "scale", Vector2(1.0, 1.0), 0.28) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Glow burst
	_spawn_glow_at(pos)

	# Fly to HUD
	tw.tween_interval(0.18)
	tw.tween_callback(_fly_pearl_to_hud.bind(pearl, hud_target))

func _fly_pearl_to_hud(pearl: TextureRect, hud_target: Vector2) -> void:
	if not is_instance_valid(pearl):
		return

	var half: Vector2 = pearl.size * 0.5
	var dest: Vector2 = hud_target - half

	var tw: Tween = pearl.create_tween()
	tw.tween_property(pearl, "global_position", dest, PEARL_FLY_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
	tw.parallel().tween_property(pearl, "scale", Vector2.ZERO, PEARL_FLY_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(pearl, "modulate:a", 0.0, 0.20) \
		.set_delay(PEARL_FLY_DURATION - 0.20)
	tw.tween_callback(pearl.queue_free)

	# Safety cleanup
	var pearl_weak: WeakRef = weakref(pearl)
	get_tree().create_timer(PEARL_FLY_DURATION + 1.0).timeout.connect(func():
		var p = pearl_weak.get_ref()
		if p:
			(p as TextureRect).queue_free()
	)

func _spawn_glow_at(pos: Vector2) -> void:
	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.custom_minimum_size = Vector2(60.0, 60.0)
	glow.size = Vector2(60.0, 60.0)
	glow.pivot_offset = Vector2(30.0, 30.0)
	glow.z_index = 183
	glow.color = Color(1.0, 0.95, 0.7, 0.6)
	glow.modulate.a = 0.0
	_fx_host.add_child(glow)
	glow.global_position = pos - Vector2(30.0, 30.0)

	var tg: Tween = glow.create_tween()
	tg.set_parallel(true)
	tg.tween_property(glow, "scale", Vector2(1.3, 1.3), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tg.tween_property(glow, "modulate:a", 0.88, 0.09)
	tg.tween_property(glow, "modulate:a", 0.0, 0.32).set_delay(0.12)
	tg.set_parallel(false)
	tg.tween_callback(glow.queue_free)

func _burst_sparkles(world_pos: Vector2, count: int) -> void:
	for _i in range(count):
		var spark := Label.new()
		spark.text = ["✦","★","⭐","✨","💫","🌟"].pick_random()
		spark.add_theme_font_size_override("font_size", randi_range(14, 28))
		spark.modulate = Color(1.0, 0.95, 0.65, 0.9)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 200
		_fx_host.add_child(spark)
		spark.global_position = world_pos + Vector2(randf_range(-60, 60), randf_range(-30, 30))
		var drift: Vector2 = Vector2(randf_range(-70, 70), randf_range(-110, -30))
		var dur: float = randf_range(0.5, 1.1)
		var tw: Tween = spark.create_tween()
		tw.tween_property(spark, "global_position", spark.global_position + drift, dur)
		tw.parallel().tween_property(spark, "scale", Vector2(1.6, 1.6), dur * 0.4)
		tw.parallel().tween_property(spark, "modulate:a", 0.0, dur)
		tw.tween_callback(spark.queue_free)

func _burst_confetti(duration: float) -> void:
	# Delegate to FXBus if available
	var fxbus = get_node_or_null("/root/FXBus")
	if fxbus and fxbus.has_method("confetti_burst"):
		# Find a canvas layer or create one
		var layer := CanvasLayer.new()
		layer.layer = 100
		_fx_host.add_child(layer)
		fxbus.confetti_burst(layer, duration)