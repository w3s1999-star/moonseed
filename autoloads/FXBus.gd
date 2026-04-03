extends Node

# ─────────────────────────────────────────────────────────────────
# FXBus.gd  —  MOONSEED v0.8.1  "Animated Feedback"
# GDD §17.4  Centralised visual effects dispatcher.
#
# Any system can call FXBus to trigger:
#   • Moondrops (MD) Rain  #moondrops  — FXBus.rain_moondrops(count, layer)
#   • Moondrops (MD) Fall  #moondrops  — FXBus.spawn_falling_moondrops(count, ip_pos, top_y, spread, on_landed)
#   • Moonpearls (MP) Rain #moonpearls — FXBus.rain_moonpearls(score, layer)
#   • DIE SHOCKWAVE        — FXBus.die_shockwave(die_node, value, sides)
#   • SCORE POPUP          — FXBus.score_popup(world_pos, value)
#   • SPARKLE BURST        — FXBus.burst_sparkles(world_pos, count, color)
#   • CONFETTI BURST       — FXBus.confetti_burst(layer, duration)
# ─────────────────────────────────────────────────────────────────

# Autoload singletons (typed) — use onready get_node so the live singleton
# instance is referenced and the type is explicit for GDScript 4 LSP.
@onready var SignalBus: Node = get_node("/root/SignalBus")
@onready var GameData: Node = get_node("/root/GameData")

const DICE_CHARS: Array[String] = ["⚀","⚁","⚂","⚃","⚄","⚅"]

const PEARL_GLOW_SHADER := preload("res://shaders/pearl_spawn_glow.gdshader")

# ── Moondrops (MD) Spawn Defaults  #moondrops ─────────────────────
const MD_DEFAULT_DROP_COUNT:    int   = 22  # ↑ more drops raining from top
const MD_DEFAULT_SPAWN_TOP_Y:   float = -48.0
const MD_DEFAULT_SPAWN_X_SPREAD: float = 260.0  # ↑ wider spread for denser rain
# Invisible Point (IP) convergence: how tightly MDs cluster at the landing zone.
const MD_CONVERGE_RADIUS:  float = 36.0
const MD_CONVERGE_Y_JITTER: float = 8.0  # ± y-variance so the cluster feels organic
const MD_SETTLE_DUR:       float = 0.14  # landing squash-and-recover duration
# Merge phase: after all MDs land, pull them inward before pearl conversion.
const MD_MERGE_DUR:    float = 0.38   # centroid-convergence duration (s)
const MD_MERGE_SHRINK: float = 0.78   # scale the icons settle at during merge
const MD_MERGE_JITTER: float = 5.0    # ± px offset so drops don't all stack exactly
# Crystallise phase: multiple Moonpearls (MP) scatter from the cluster centroid.
const MD_PEARL_COUNT:   int   = 3     # Moonpearls (MP) #moonpearls spawned per cluster
const MD_PEARL_SCATTER: float = 55.0  # ± radius (px) for random pearl scatter positions
# Pearl HUD flight (Step 9): pearl-to-counter arc after crystallize settle.
const MP_FLY_DUR:      float = 0.55   # total flight time (s)
const MP_FLY_FADE:     float = 0.20   # alpha-dissolve window at end of flight (s)
# Pearl arrival feedback (Step 10): sparkle count and audio on counter landing.
const MP_ARRIVE_SPARK_COUNT: int   = 6
const MP_ARRIVE_SFX_PATH: String   = "res://assets/audio/playtable/moonpearl_collect_wallet.mp3"


var _mp_arrive_stream: AudioStream = null
# Track the current AudioStreamPlayer to prevent overlap
var _mp_arrive_player: AudioStreamPlayer = null

# ── DROP LANDING TRACKER ─────────────────────────────────────────
# Counts tween-confirmed settle completions; fires the merge gate only after
# every moondrop has fully landed.  Tween callbacks (not duration estimates)
# guarantee the count is exact, preventing early pearl spawning.
class _DropLandingTracker:
	var _remaining: int
	var _on_all_landed: Callable

	func _init(count: int, on_all_landed: Callable) -> void:
		_remaining = count
		_on_all_landed = on_all_landed
		if _remaining <= 0 and _on_all_landed.is_valid():
			_on_all_landed.call()

	func notify_landed() -> void:
		_remaining = maxi(_remaining - 1, 0)
		if _remaining == 0 and _on_all_landed.is_valid():
			_on_all_landed.call()

func _fx_host() -> Node:
	var scene := get_tree().current_scene
	if is_instance_valid(scene) and scene.has_method("get_stage_root"):
		var host := scene.call("get_stage_root") as Node
		if is_instance_valid(host):
			return host
	return get_tree().get_root()

func _moonpearls_target_position() -> Vector2:
	var scene := get_tree().current_scene
	if is_instance_valid(scene) and scene.has_method("get_moonpearls_target_global_position"):
		return scene.call("get_moonpearls_target_global_position") as Vector2
	return Vector2(72.0, 36.0)

func _pulse_moonpearls_counter() -> void:
	var scene := get_tree().current_scene
	if is_instance_valid(scene) and scene.has_method("pulse_moonpearls_counter"):
		scene.call("pulse_moonpearls_counter")
	# Step 10: arrival feedback — sparkle burst + audio cue + cross-scene notify
	_mp_arrival_sparkles(_moonpearls_target_position())
	_mp_arrival_chime()
	# Note: fx_moonpearls_arrived and moonpearls_changed signals not found in SignalBus
	# Skipping signal emission for now

# ── PEARL ARRIVAL CHIME ──────────────────────────────────────────
# Plays a soft one-shot audio cue when the MP pearl lands in the HUD counter.
# Loads lazily on first call so no _ready() is required.
# Safe to call even if the SFX file is absent — returns silently.
func _mp_arrival_chime() -> void:
		if _mp_arrive_stream == null and ResourceLoader.exists(MP_ARRIVE_SFX_PATH):
			_mp_arrive_stream = load(MP_ARRIVE_SFX_PATH)
		if _mp_arrive_stream == null:
			return
		# Stop and free any previous player
		if is_instance_valid(_mp_arrive_player):
			_mp_arrive_player.stop()
			_mp_arrive_player.queue_free()
		var p := AudioStreamPlayer.new()
		p.stream     = _mp_arrive_stream
		p.volume_db  = -6.0 # half volume
		p.bus        = "Master"
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
		_mp_arrive_player = p

# ── PEARL ARRIVAL SPARKLES ───────────────────────────────────────
# Fires a small radial burst of sparkle labels at the HUD counter position
# (Step 10).  Scatters 6 glyphs outward within a 20-55 px radius so the burst
# stays tight against the corner counter without overshooting the screen edge.
# Colors alternate warm-gold and cool-pearl to match the MP palette.
# All nodes queue_free themselves via tween callback; no manual cleanup needed.
func _mp_arrival_sparkles(pos: Vector2) -> void:
	var root: Node = _fx_host()
	var glyphs: Array[String] = ["✦", "★", "✦", "·", "✦", "★"]
	for ri in range(glyphs.size()):
		var spark := Label.new()
		spark.text = glyphs[ri]
		spark.add_theme_font_size_override("font_size", randi_range(12, 20))
		spark.modulate = Color(1.0, 0.95, 0.65, 0.9) if ri % 2 == 0 else Color(0.85, 0.98, 1.0, 0.9)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 210
		root.add_child(spark)
		var angle: float  = randf() * TAU
		var dist:  float  = randf_range(20.0, 55.0)
		spark.global_position = pos - Vector2(7.0, 7.0)
		var target: Vector2 = pos + Vector2(cos(angle), sin(angle)) * dist
		var dur: float = randf_range(0.35, 0.65)
		var ts := spark.create_tween()
		ts.tween_property(spark, "global_position", target, dur) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		ts.parallel().tween_property(spark, "scale", Vector2(1.4, 1.4), dur * 0.3)
		ts.parallel().tween_property(spark, "modulate:a", 0.0, dur) \
				.set_ease(Tween.EASE_IN).set_delay(dur * 0.3)
		ts.tween_callback(spark.queue_free)

# ── MOONDROP SPAWN HELPER ────────────────────────────────────────
# Low-level creation step: instantiates `drop_count` moondrop TextureRect
# nodes, positions each one above the screen at y=`spawn_top_y` scattered
# ±`spawn_x_spread`/2 around `ip_position.x`, and parents them under
# _fx_host().  No animation is applied; returns the typed live array.
func _spawn_moondrop_icons(
		drop_count: int,
		ip_position: Vector2,
		spawn_top_y: float,
		spawn_x_spread: float) -> Array[TextureRect]:
	var root: Node = _fx_host()
	var half: float = spawn_x_spread * 0.5
	var icons: Array[TextureRect] = []
	for _i in range(clampi(drop_count, 1, 64)):
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sz: float = randf_range(16.0, 28.0)
		icon.custom_minimum_size = Vector2(sz, sz)
		icon.size = Vector2(sz, sz)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
		icon.z_index = 180
		GameData._set_random_moondrop_frame(icon)
		var spawn_x: float = ip_position.x + randf_range(-half, half)
		icon.global_position = Vector2(spawn_x, spawn_top_y - randf() * 60.0) - Vector2(sz * 0.5, sz * 0.5)
		root.add_child(icon)
		icons.append(icon)
	return icons

# ── MOONDROP FALL ANIMATION ──────────────────────────────────────
# Animates a single MD icon from its current position to `landing_point`.
# Phase 1 — Fall: QUAD ease-in (accelerating drop) + free rotation.
# Phase 2 — Settle: squash on impact (wide/flat), then spring back upright
#            via BACK ease-out so the landing feels lively and weighty.
# `on_settled` is queued as a tween_callback after the recover step so it
# fires at the exact moment this drop is fully at rest.
func _animate_moondrop_fall(icon: TextureRect, landing_point: Vector2, drop_delay: float, on_settled: Callable = Callable()) -> void:
	var sz: float       = icon.size.x
	var fall_dur: float = randf_range(0.45, 0.72)  # tuned: snappier fall reads clearly at game speed
	var rot_end: float  = randf_range(-PI * 0.8, PI * 0.8)
	var tw := icon.create_tween()
	# ── pre-drop stagger ──
	tw.tween_interval(drop_delay)
	# ── fall phase ── accelerating descent + spin
	tw.tween_property(icon, "global_position",
		landing_point - Vector2(sz * 0.5, sz * 0.5),
		fall_dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(icon, "rotation", rot_end, fall_dur)
	# ── settle phase ── squash wide on impact, spring back to normal
	var squash_t: float = MD_SETTLE_DUR * 0.38
	var recover_t: float = MD_SETTLE_DUR * 0.62
	tw.tween_property(icon, "scale", Vector2(1.4, 0.65), squash_t).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(icon, "rotation", 0.0, MD_SETTLE_DUR).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "scale", Vector2(1.0, 1.0), recover_t)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if on_settled.is_valid():
		tw.tween_callback(on_settled)

# ── SPAWN FALLING MOONDROPS ───────────────────────────────────────
# Public entry point.  Calls _spawn_moondrop_icons(), then delegates
# animation to _animate_moondrop_fall() for each MD.
#
# Completion tracking: a _DropLandingTracker counts each tween-confirmed
# settle callback.  `on_landed` fires only after every drop has triggered
# its tween_callback — no timer estimates, no race conditions.
#
# Returns the live icon nodes for downstream use.
func spawn_falling_moondrops(
		drop_count: int        = MD_DEFAULT_DROP_COUNT,
		ip_position: Vector2   = Vector2.ZERO,
		spawn_top_y: float     = MD_DEFAULT_SPAWN_TOP_Y,
		spawn_x_spread: float  = MD_DEFAULT_SPAWN_X_SPREAD,
		on_landed: Callable    = Callable(),
		converge_radius: float = MD_CONVERGE_RADIUS) -> Array[TextureRect]:
	var icons: Array[TextureRect] = _spawn_moondrop_icons(
			drop_count, ip_position, spawn_top_y, spawn_x_spread)
	var tracker := _DropLandingTracker.new(icons.size(), on_landed)
	for idx in range(icons.size()):
		var icon: TextureRect = icons[idx]
		var drop_delay: float = float(idx) * randf_range(0.03, 0.06)  # tuned: tighter stagger, cohesive rain
		# Per-drop IP landing point: tight x convergence, slight y jitter.
		var landing_point := Vector2(
				ip_position.x + randf_range(-converge_radius, converge_radius),
				ip_position.y + randf_range(-MD_CONVERGE_Y_JITTER, MD_CONVERGE_Y_JITTER))
		_animate_moondrop_fall(icon, landing_point, drop_delay, Callable(tracker, "notify_landed"))
	return icons

# ── MOONDROP MERGE CLUSTER ──────────────────────────────────────
# Step 6: after all MDs have landed (gate delivered by _DropLandingTracker in
# spawn_falling_moondrops), pulls them inward to their natural centroid before
# the pearl-conversion phase fires.
#
# Cluster centre: centroid of all valid landed icon positions; falls back to
# ip_position when no valid nodes remain (safe if any were freed mid-flight).
#
# Animation: smooth SINE ease-in-out, slight shrink to MD_MERGE_SHRINK, and
# rotation zeroed — soft crystalline drift, not explosive.
#
# Completion: on_merged fires only after every icon tween calls back, tracked
# by a reused _DropLandingTracker.  Always safe to interrupt or skip.
func moondrop_merge_cluster(
		icons: Array[TextureRect],
		_ip_position: Vector2,
		on_merged: Callable = Callable()) -> void:
	# ── filter to still-alive nodes ─────────────────────────────
	var valid: Array[TextureRect] = []
	for icon in icons:
		if is_instance_valid(icon):
			valid.append(icon)
	if valid.is_empty():
		if on_merged.is_valid():
			on_merged.call()
		return
	# ── cluster centre: centroid of landed positions, or IP fallback ─
	var sum := Vector2.ZERO
	for icon in valid:
		sum += icon.global_position + icon.size * 0.5
	var center: Vector2 = sum / float(valid.size())
	# ── animate each drop inward ─────────────────────────────────
	var tracker := _DropLandingTracker.new(valid.size(), on_merged)
	for icon in valid:
		var sz: float  = icon.size.x
		var dur: float = MD_MERGE_DUR + randf_range(-0.05, 0.08)
		var dest: Vector2 = center + Vector2(
				randf_range(-MD_MERGE_JITTER, MD_MERGE_JITTER),
				randf_range(-MD_MERGE_JITTER, MD_MERGE_JITTER))
		var tw := icon.create_tween()
		tw.tween_property(icon, "global_position",
				dest - Vector2(sz * 0.5, sz * 0.5),
				dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(icon, "rotation", 0.0, dur) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(icon, "scale",
				Vector2(MD_MERGE_SHRINK, MD_MERGE_SHRINK),
				dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(Callable(tracker, "notify_landed"))

# ── Moondrops (MD) Rain  #moondrops ─────────────────────────────
func rain_moondrops(count: int, parent: CanvasLayer) -> void:
	if not is_instance_valid(parent): return
	var root: Node = _fx_host()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var n: int = clampi(count, 1, 2000)
	for i in range(n):
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sz: float = randf_range(16.0, 28.0)
		icon.custom_minimum_size = Vector2(sz, sz)
		icon.size = Vector2(sz, sz)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		GameData._set_random_moondrop_frame(icon)
		root.add_child(icon)
		var start_x: float = randf() * vp.x
		icon.global_position = Vector2(start_x, -sz - randf() * 80.0)
		var delay:    float = float(i) * randf_range(0.01, 0.06)
		var fall_dur: float = randf_range(0.65, 1.4)
		var end_y:    float = vp.y * randf_range(0.3, 0.8)
		var drift_x:  float = randf_range(-50.0, 50.0)
		var rot_end:  float = randf_range(-PI * 1.8, PI * 1.8)
		var tw := icon.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(icon, "global_position", Vector2(start_x + drift_x, end_y), fall_dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(icon, "rotation", rot_end, fall_dur)
		tw.tween_property(icon, "modulate:a", 0.0, 0.35)
		tw.tween_callback(icon.queue_free)

# ── Moonpearls (MP) Rain  #moonpearls ───────────────────────────
# Spawns pearls directly at random screen positions: 1 pearl per 5 score.
# Each pearl crystallises at its random spawn point then flies to the HUD counter.
func rain_moonpearls(score: int, parent: CanvasLayer) -> void:
	if not is_instance_valid(parent): return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var num_pearls: int = clampi(int(float(score) / 5.0), 1, 40)
	for i in range(num_pearls):
		var delay: float = float(i) * randf_range(0.08, 0.16)
		var px: float = randf_range(vp.x * 0.12, vp.x * 0.88)
		var py: float = randf_range(vp.y * 0.20, vp.y * 0.80)
		var spawn_pos := Vector2(px, py)
		if delay > 0.0:
			get_tree().create_timer(delay).timeout.connect(
					_spawn_pearl_at.bind(spawn_pos))
		else:
			_spawn_pearl_at(spawn_pos)


# ── SCORE POPUP ───────────────────────────────────────────────────
# Floating "+N" labels rise with staggered timing from die positions.
func score_popup(world_pos: Vector2, value: int, col: Color = Color.WHITE) -> void:
	var root: Node = _fx_host()
	var lbl := Label.new()
	lbl.text = "+%d" % value if value > 0 else str(value)
	lbl.add_theme_font_size_override("font_size", int(22 + mini(int(value / 10.0), 20)))
	lbl.modulate = col
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 250
	root.add_child(lbl)
	lbl.global_position = world_pos + Vector2(randf_range(-20, 20), 0)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector2(randf_range(-15, 15), -80.0), 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN).set_delay(0.35)
	tw.tween_callback(lbl.queue_free)

# ── PUDDLE ECHO (subtle) ─────────────────────────────────────────
# Creates a soft expanding circular mark under a die to indicate scoring
func puddle_echo(world_pos: Vector2, color: Color = Color(1.0, 0.9, 0.2, 0.75)) -> void:
	var root: Node = _fx_host()
	var lbl := Label.new()
	lbl.text = "●"
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.modulate = color
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 195
	root.add_child(lbl)
	lbl.global_position = world_pos - lbl.size * 0.5
	# start small and fade/expand
	lbl.scale = Vector2(0.5, 0.5)
	var dur: float = 0.5
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(2.2, 2.2), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, dur * 0.9).set_delay(dur * 0.05)
	tw.tween_callback(lbl.queue_free)

# ── SPARKLE BURST ─────────────────────────────────────────────────
func burst_sparkles(world_pos: Vector2, count: int, col: Color) -> void:
	var root: Node = _fx_host()
	for _i in range(count):
		var spark := Label.new()
		spark.text = ["✦","★","⭐","✨","💫","🌟"].pick_random()
		spark.add_theme_font_size_override("font_size", randi_range(14, 28))
		spark.modulate = col
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 200
		root.add_child(spark)
		spark.global_position = world_pos + Vector2(randf_range(-60, 60), randf_range(-30, 30))
		var drift: Vector2 = Vector2(randf_range(-70, 70), randf_range(-110, -30))
		var dur:   float   = randf_range(0.5, 1.1)
		var tw := spark.create_tween()
		tw.tween_property(spark, "global_position", spark.global_position + drift, dur)
		tw.parallel().tween_property(spark, "scale", Vector2(1.6, 1.6), dur * 0.4)
		tw.parallel().tween_property(spark, "modulate:a", 0.0, dur)
		tw.tween_callback(spark.queue_free)

# ── CONFETTI BURST ────────────────────────────────────────────────
func confetti_burst(layer: CanvasLayer, duration: float = 4.0) -> void:
	if not is_instance_valid(layer): return
	var shader: Shader = load("res://shaders/confetti.gdshader") as Shader
	if not shader: return
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("resolution", get_viewport().get_visible_rect().size)
	mat.set_shader_parameter("alpha_scale", 0.0)
	rect.material = mat
	layer.add_child(rect)
	var tw := rect.create_tween()
	tw.tween_method(func(v: float): (rect.material as ShaderMaterial).set_shader_parameter("alpha_scale", v), 0.0, 1.0, 0.25)
	tw.tween_interval(duration - 0.75)
	tw.tween_method(func(v: float): (rect.material as ShaderMaterial).set_shader_parameter("alpha_scale", v), 1.0, 0.0, 0.5)
	tw.tween_callback(rect.queue_free)

# ── MOONPEARL SPAWN HELPER ───────────────────────────────────────
# Creates one Moonpearl TextureRect at `pos` inside _fx_host().
# Runs a two-phase crystallize pop:
#   1. Scale burst: 0.2 → 2.4 (TRANS_QUAD, 0.09 s) fades in
#   2. Spring settle: 2.4 → 1.0 (TRANS_BACK ease-out, 0.28 s)
# Fires _pearl_crystallize_glow 0.06 s in, then flies the pearl to
# the moonpearls counter and queue_frees it on arrival.
# Returns the live pearl node (already parented to _fx_host()).
func _spawn_pearl_at(pos: Vector2, hud_override: Vector2 = Vector2.ZERO) -> TextureRect:
	const PSZ := 36.0
	var pearl := TextureRect.new()
	pearl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pearl.custom_minimum_size = Vector2(PSZ, PSZ)
	pearl.size = Vector2(PSZ, PSZ)
	pearl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pearl.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	pearl.pivot_offset = Vector2(PSZ * 0.5, PSZ * 0.5)
	pearl.z_index = 185
	GameData._set_random_moonpearls_frame(pearl)
	pearl.modulate.a = 0.0
	pearl.scale = Vector2(0.2, 0.2)
	_fx_host().add_child(pearl)
	pearl.global_position = pos - Vector2(PSZ * 0.5, PSZ * 0.5)
	# ── radial glow behind pearl (expand on spawn, fade as pearl settles) ──
	_spawn_pearl_bg_glow(pos)
	# ── crystallize pop ────────────────────────────────────────
	var tw := pearl.create_tween()
	tw.tween_property(pearl, "scale", Vector2(2.4, 2.4), 0.09).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(pearl, "modulate:a", 1.0, 0.09)
	tw.tween_property(pearl, "scale", Vector2(1.0, 1.0), 0.28) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# ── radial glow ring (offset so it overlaps the pop peak) ──
	get_tree().create_timer(0.06).timeout.connect(_pearl_crystallize_glow.bind(pos))
	# ── fly to HUD counter after settling (Step 9) ─────────────
	tw.tween_interval(0.18)
	tw.tween_callback(func(): _pearl_fly_to_hud(pearl, hud_override))
	return pearl

# ── PEARL HUD FLIGHT ────────────────────────────────────────────
# Step 9: Pulls the crystallised pearl from its settle position into the
# top-left moonpearls counter.
#
# Coordinate space
# ─────────────────
# The pearl is parented to _overlay_stage — a plain Control with
# PRESET_FULL_RECT that is a direct child of Main (the scene root, also a
# plain Control).  lbl_moonpearls lives in Main's header VBox, also a plain
# Control.  Both therefore share the default canvas space: global_position
# equals screen pixels (0,0 = top-left).  _moonpearls_target_position() calls
# lbl_moonpearls.get_child(0).get_global_rect().get_center(), which is already
# in the same space — no conversion is needed.
#
# If the header were ever moved into a CanvasLayer with a non-identity
# transform you would need:
#   cpos = canvas_layer.get_transform().affine_inverse() * cpos
# before tweening.  Currently this case does not exist.
#
# Flight phases (single Tween, all in default canvas global_position space)
#   A — Position  0 → MP_FLY_DUR   CIRC EASE_IN  : lazy drift → hard snap
#   A — Scale     0 → MP_FLY_DUR   QUAD EASE_IN  : parallel shrink to zero
#   B — Alpha     delay → end      linear EASE_IN : dissolve in final stretch
func _pearl_fly_to_hud(pearl: TextureRect, hud_override: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(pearl):
		return
	# ── resolve target in default canvas space ──────────────────
	var cpos: Vector2     = hud_override if hud_override != Vector2.ZERO else _moonpearls_target_position()
	var half: Vector2     = pearl.size * 0.5
	var dest: Vector2     = cpos - half
	var fade_delay: float = MP_FLY_DUR - MP_FLY_FADE
	# ── flight tween ─────────────────────────────────────────────
	var tw := pearl.create_tween()
	# Phase A: CIRC ease-in — lingers at the cluster, then snaps into counter
	tw.tween_property(pearl, "global_position", dest, MP_FLY_DUR) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
	# Phase A (parallel): shrink to nothing as the pearl arrives
	tw.parallel().tween_property(pearl, "scale", Vector2.ZERO, MP_FLY_DUR) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Phase B (parallel, delayed): dissolve into counter in the final MP_FLY_FADE s
	tw.parallel().tween_property(pearl, "modulate:a", 0.0, MP_FLY_FADE) \
			.set_delay(fade_delay).set_ease(Tween.EASE_IN)
	# Arrival: pulse HUD counter (which also fires sparkles + chime + fx signal),
	# emit the currency-changed notification, then free the node.
	tw.tween_callback(func():
		# Do not pulse/update the HUD per-pearl. The balance is updated
		# atomically by Database.add_moonpearls(); avoid per-pearl UI jumps.
		if is_instance_valid(pearl):
			pearl.queue_free()
	)
	# Safety: if the flight tween is killed externally the callback never fires.
	# A TTL timer guarantees the pearl node is freed regardless.
	# WeakRef avoids the "lambda capture freed" error when the tween already freed pearl.
	var pearl_weak: WeakRef = weakref(pearl)
	get_tree().create_timer(MP_FLY_DUR + 1.0).timeout.connect(func():
		var p: Variant = pearl_weak.get_ref()
		if p: (p as TextureRect).queue_free()
	)

# ── PEARL BACKGROUND GLOW ─────────────────────────────────────────
# Additive radial glow behind the pearl (z_index 183, below pearl's 185).
# Expands from 0.65 → 1.3 × during the crystallize pop peak, then fades
# out over 0.32 s so it has dissolved before the pearl begins flying.
func _spawn_pearl_bg_glow(pos: Vector2) -> void:
	const GSZ := 90.0
	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.custom_minimum_size = Vector2(GSZ, GSZ)
	glow.size                = Vector2(GSZ, GSZ)
	glow.pivot_offset        = Vector2(GSZ * 0.5, GSZ * 0.5)
	glow.z_index             = 183
	var mat := ShaderMaterial.new()
	mat.shader = PEARL_GLOW_SHADER
	glow.material   = mat
	glow.modulate.a = 0.0
	glow.scale      = Vector2(0.65, 0.65)
	_fx_host().add_child(glow)
	glow.global_position = pos - Vector2(GSZ * 0.5, GSZ * 0.5)
	# Phase 1 — expand and fade in alongside the crystallize pop (0.09 s)
	var tg := glow.create_tween()
	tg.set_parallel(true)
	tg.tween_property(glow, "scale",      Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tg.tween_property(glow, "modulate:a", 0.88,              0.09)
	# Phase 2 — fade out as pearl settles (starts at 0.12 s, done by ~0.44 s)
	tg.tween_property(glow, "modulate:a", 0.0, 0.32).set_delay(0.12)
	tg.set_parallel(false)
	tg.tween_callback(glow.queue_free)

# ── PEARL CRYSTALLIZE GLOW ────────────────────────────────────────
# Fires a radial ring of 8 sparks + a central flare at the pearl pop point.
func _pearl_crystallize_glow(pos: Vector2) -> void:
	var root: Node = _fx_host()
	# Central flare: large ✦ that pops and fades
	var flare := Label.new()
	flare.text = "✦"
	flare.add_theme_font_size_override("font_size", 52)
	flare.modulate = Color(1.0, 0.97, 0.75, 0.9)
	flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flare.z_index = 200
	root.add_child(flare)
	flare.pivot_offset = Vector2(26.0, 26.0)
	flare.global_position = pos - Vector2(26.0, 26.0)
	flare.scale = Vector2(0.3, 0.3)
	var tfl := flare.create_tween()
	tfl.tween_property(flare, "scale", Vector2(2.2, 2.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tfl.parallel().tween_property(flare, "modulate:a", 0.0, 0.38).set_delay(0.08)
	tfl.tween_callback(flare.queue_free)
	# Ring of 8 sparks expanding outward
	var ring_glyphs: Array[String] = ["·","✦","★","✦","·","✦","★","✦"]
	var ring_count := ring_glyphs.size()
	for ri in range(ring_count):
		var spark := Label.new()
		spark.text = ring_glyphs[ri]
		var fsz := randi_range(14, 22) if ring_glyphs[ri] == "·" else randi_range(10, 18)
		spark.add_theme_font_size_override("font_size", fsz)
		spark.modulate = Color(0.95, 0.88, 0.55, 0.85) if ri % 2 == 0 else Color(0.75, 0.95, 1.0, 0.85)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 195
		root.add_child(spark)
		var angle: float = (TAU / float(ring_count)) * ri + randf_range(-0.15, 0.15)
		spark.global_position = pos - Vector2(7.0, 7.0)
		var target_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * randf_range(55.0, 95.0)
		var dur: float = randf_range(0.38, 0.62)
		var ts := spark.create_tween()
		ts.tween_property(spark, "global_position", target_pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		ts.parallel().tween_property(spark, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN).set_delay(dur * 0.4)
		ts.tween_callback(spark.queue_free)

# ── MOONDROP SPLASH PARTICLES ─────────────────────────────────────
# Splashes N moondrop icons outward from `origin` (e.g. center of the dice
# table). Returns the live TextureRect nodes so moondrop_cluster_to_pearl()
# can collect them.
func moondrop_splash_particles(origin: Vector2, count: int) -> Array:
	var root: Node = _fx_host()
	var drops: Array = []
	var n := clampi(count, 3, 24)
	for _i in range(n):
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sz: float = randf_range(14.0, 22.0)
		icon.custom_minimum_size = Vector2(sz, sz)
		icon.size = Vector2(sz, sz)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
		icon.z_index = 180
		GameData._set_random_moondrop_frame(icon)
		icon.modulate.a = 0.0
		root.add_child(icon)
		icon.global_position = origin - Vector2(sz * 0.5, sz * 0.5)
		var angle: float = randf() * TAU
		var dist:  float = randf_range(40.0, 100.0)
		var land: Vector2 = origin + Vector2(cos(angle), sin(angle)) * dist
		var delay: float = randf_range(0.0, 0.14)
		var dur:   float = randf_range(0.22, 0.46)
		var tw := icon.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(icon, "modulate:a", 1.0, 0.07)
		tw.parallel().tween_property(icon, "global_position",
			land - Vector2(sz * 0.5, sz * 0.5), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(icon, "rotation", randf_range(-PI, PI), dur)
		drops.append(icon)
	return drops

# ── MOONDROP CLUSTER TO PEARL ─────────────────────────────────────
# Called after moondrop_merge_cluster() — drops are already converged.
# Dissolves the merged icons then crystallizes MD_PEARL_COUNT Moonpearls (MP)
# #moonpearls at random positions scattered within MD_PEARL_SCATTER px of the
# cluster centroid.  Each pearl staggered 0.14 s apart and flies independently
# to the HUD counter.  Pearl origin: centroid of surviving icon positions;
# falls back to `target` when all icons have already been freed.
func moondrop_cluster_to_pearl(drops: Array, target: Vector2, hud_override: Vector2 = Vector2.ZERO) -> void:
	# ── collect valid nodes and compute centroid ──────────────────
	var valid: Array = []
	var sum := Vector2.ZERO
	for icon in drops:
		if not is_instance_valid(icon):
			continue
		valid.append(icon)
		sum += (icon as TextureRect).global_position + (icon as TextureRect).size * 0.5
	var center: Vector2 = sum / float(valid.size()) if not valid.is_empty() else target
	# ── dissolve merged drops ─────────────────────────────────────
	for icon in valid:
		var tw: Tween = icon.create_tween()
		tw.tween_property(icon, "scale", Vector2(0.0, 0.0), 0.18) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(icon, "modulate:a", 0.0, 0.18)
		tw.tween_callback(icon.queue_free)
	# ── crystallize MD_PEARL_COUNT Moonpearls (MP) scattered around centroid ─
	for pi in range(MD_PEARL_COUNT):
		var angle:     float  = randf() * TAU
		var dist:      float  = randf_range(MD_PEARL_SCATTER * 0.25, MD_PEARL_SCATTER)
		var spawn_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
		var delay:     float  = float(pi) * 0.14
		if delay > 0.0:
			get_tree().create_timer(delay).timeout.connect(
					_spawn_pearl_at.bind(spawn_pos, hud_override))
		else:
			_spawn_pearl_at(spawn_pos, hud_override)

# ═══════════════════════════════════════════════════════════════════
# MOONDROP → MOONPEARL  ·  Full Sequence Entry Point
# ═══════════════════════════════════════════════════════════════════
# One call drives the entire MD→MP chain for a single cluster:
#
#   Step 1 — Spawn: `drop_count` moondrop icons appear off-screen
#             above `ip_position`, scattered ±`spawn_x_spread`/2.
#             (_spawn_moondrop_icons)
#
#   Step 2 — Fall: each icon drops with QUAD ease-in, free rotation,
#             and lands near ip_position within `converge_radius`.
#             Stagger delay: 0.03–0.09 s per icon.
#             (_animate_moondrop_fall × drop_count)
#
#   Step 3 — Land gate: _DropLandingTracker fires when every drop
#             has confirmed its settle tween — no timer estimates.
#
#   Step 4 — Merge: all landed icons drift to their centroid with
#             SINE ease-in-out + gentle shrink (MD_MERGE_SHRINK).
#             (moondrop_merge_cluster)
#
#   Step 5 — Merge gate: second _DropLandingTracker fires when every
#             icon has confirmed its inward tween.
#
#   Step 6 — Dissolve + Crystallise: merged icons scale/fade to zero;
#             a Moonpearl TextureRect pops at the cluster centroid
#             with a burst-and-spring animation.
#             (moondrop_cluster_to_pearl → _spawn_pearl_at)
#
#   Step 7 — Glow ring: radial spark ring + bg glow fire at pop peak.
#             (_pearl_crystallize_glow, _spawn_pearl_bg_glow)
#
#   Step 8 — Flight: pearl arcs to `hud_target_position` with CIRC
#             ease-in (lingers, then snaps) + parallel scale-shrink
#             and alpha dissolve in the final MP_FLY_FADE window.
#             (_pearl_fly_to_hud)
#
#   Step 9 — Arrival: HUD counter pulses; sparkle burst + chime fire
#             at `hud_target_position`; SignalBus.fx_moonpearls_arrived
#             and moonpearls_changed are emitted; pearl is queue_freed.
#             (_pulse_moonpearls_counter, _mp_arrival_sparkles)
#
# Parameters
# ──────────────────────────────────────────────────────────────────
#   parent            — owning node; validated before any work starts.
#   ip_position       — screen-space invisible point: landing centroid
#                       for the falling drops and origin of the merge.
#   hud_target_position — screen-space position the pearl flies to;
#                       pass Vector2.ZERO to resolve from the scene
#                       via _moonpearls_target_position() at runtime.
#   drop_count        — number of moondrop icons to rain (clamped 1–64).
#   spawn_top_y       — Y coordinate (screen-space) from which drops
#                       spawn; negative = above viewport.
#   spawn_x_spread    — total horizontal spread of spawn positions
#                       (each drop is placed within ± half this value
#                       around ip_position.x).
#   converge_radius   — ± x-spread of landing points around ip_position
#                       (tighter than spawn_x_spread for clustering).
func play_moondrop_to_moonpearl_fx(
		parent: Node,
		ip_position: Vector2,
		hud_target_position: Vector2,
		drop_count: int        = MD_DEFAULT_DROP_COUNT,
		spawn_top_y: float     = MD_DEFAULT_SPAWN_TOP_Y,
		spawn_x_spread: float  = MD_DEFAULT_SPAWN_X_SPREAD,
		converge_radius: float = MD_CONVERGE_RADIUS) -> void:
	if not is_instance_valid(parent):
		return
	# icons must be captured by the closures below; pre-declare so the
	# lambda that reads it is valid even before spawn_falling_moondrops returns.
	var icons: Array[TextureRect] = []
	icons = spawn_falling_moondrops(
			drop_count, ip_position, spawn_top_y, spawn_x_spread,
			func(): _on_md_all_landed(icons, ip_position, hud_target_position),
			converge_radius)

# ── Step 3→4 gate: all MDs landed → begin merge ─────────────────
func _on_md_all_landed(
		icons: Array[TextureRect],
		ip_position: Vector2,
		hud_target: Vector2) -> void:
	moondrop_merge_cluster(icons, ip_position,
			func(): moondrop_cluster_to_pearl(icons, ip_position, hud_target))
