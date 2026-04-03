extends Node

# ─────────────────────────────────────────────────────────────────
# Juice.gd  —  MOONSEED  v0.9.0  "The Sauce Layer"
# Centralises short-lived animation helpers so individual tabs
# don't each reinvent the same tweens.
#
# Usage examples:
#   Juice.punch_scale(my_label, 1.4, 0.18)
#   Juice.flash_color(my_panel, Color.WHITE, 0.12)
#   Juice.screen_shake(get_viewport(), 4.0, 0.25)
#   Juice.count_up(my_label, 0, 42, 0.6, "%d")
#   Juice.bounce_in(my_control)
#   await Juice.fade_in(my_control, 0.3)
# ─────────────────────────────────────────────────────────────────

# ── Scale Punch ──────────────────────────────────────────────────
## Quick pop-to-scale then spring back.  target_scale > 1 = enlarge.
func punch_scale(node: Control, target_scale: float = 1.35,
		duration: float = 0.22) -> void:
	if not is_instance_valid(node): return
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(target_scale, target_scale),
		duration * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE,
		duration * 0.65).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

# ── Squash & Stretch ─────────────────────────────────────────────
## Squash on hit, stretch on settle — classic game-feel staple.
func squash_and_stretch(node: Control, duration: float = 0.3) -> void:
	if not is_instance_valid(node): return
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.4, 0.7), duration * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2(0.85, 1.2), duration * 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "scale", Vector2.ONE, duration * 0.40).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

# ── Color Flash ──────────────────────────────────────────────────
## Flash a Control's modulate to flash_col then back.
func flash_color(node: CanvasItem, flash_col: Color = Color.WHITE,
		duration: float = 0.15) -> void:
	if not is_instance_valid(node): return
	var original: Color = node.modulate
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", flash_col, duration * 0.3)
	tw.tween_property(node, "modulate", original, duration * 0.7).set_trans(Tween.TRANS_SINE)

# ── Wiggle ───────────────────────────────────────────────────────
## Left-right shake (rotation wiggle) — good for errors / warnings.
func wiggle(node: Control, amplitude_deg: float = 8.0,
		cycles: int = 3, duration: float = 0.3) -> void:
	if not is_instance_valid(node): return
	node.pivot_offset = node.size * 0.5
	var step: float = duration / (cycles * 2)
	var tw := node.create_tween()
	for i in range(cycles):
		tw.tween_property(node, "rotation_degrees",  amplitude_deg, step).set_trans(Tween.TRANS_SINE)
		tw.tween_property(node, "rotation_degrees", -amplitude_deg, step).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "rotation_degrees", 0.0, step).set_trans(Tween.TRANS_SINE)

# ── Screen Shake ─────────────────────────────────────────────────
## Translates a CanvasLayer or the root Control — attach to a CanvasLayer
## for best results.  Falls back to tree root if layer is null.
func screen_shake(layer: Node, strength: float = 6.0,
		duration: float = 0.22, decay: float = 0.85) -> void:
	if not is_instance_valid(layer): return
	var original_pos: Vector2 = Vector2.ZERO
	if layer is Control:
		original_pos = (layer as Control).position
	elif layer is Node2D:
		original_pos = (layer as Node2D).position

	var current_strength: float = strength
	# Drive the shake per-frame via a SceneTreeTimer callback chain
	var tw := layer.create_tween()
	tw.set_loops(0)
	var step: float = 0.02
	var steps: int = int(duration / step)
	for _i in range(steps):
		var offset: Vector2 = Vector2(randf_range(-current_strength, current_strength),
									 randf_range(-current_strength, current_strength))
		current_strength *= decay
		tw.tween_property(layer, "position", Vector2i(original_pos + offset), step)
		tw.tween_property(layer, "position", Vector2i(original_pos), step * 2.0)

# ── Count Up ─────────────────────────────────────────────────────
## Animates a Label's text from start_val to end_val over duration.
func count_up(label: Label, start_val: int, end_val: int,
		duration: float = 0.6, fmt: String = "%d") -> void:
	if not is_instance_valid(label): return
	var tw := label.create_tween()
	tw.tween_method(func(v: float): label.text = fmt % int(v),
		float(start_val), float(end_val), duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

# ── Fade In ──────────────────────────────────────────────────────
## Fade a node's alpha from 0 to 1.  Returns tween (awaitable).
func fade_in(node: CanvasItem, duration: float = 0.25) -> Tween:
	if not is_instance_valid(node): return null
	node.modulate.a = 0.0
	node.visible = true
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	return tw

# ── Fade Out ─────────────────────────────────────────────────────
func fade_out(node: CanvasItem, duration: float = 0.25,
		free_on_finish: bool = false) -> Tween:
	if not is_instance_valid(node): return null
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	if free_on_finish:
		tw.tween_callback(node.queue_free)
	return tw

# ── Bounce In ────────────────────────────────────────────────────
## Scales a node from 0 → 1 with a spring overshoot.
func bounce_in(node: Control, duration: float = 0.35) -> void:
	if not is_instance_valid(node): return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ZERO
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE,
		duration).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

# ── Slide In ─────────────────────────────────────────────────────
## Slides a node in from an offset, settling at its natural position.
func slide_in(node: Control, from_offset: Vector2 = Vector2(0, 30),
		duration: float = 0.28) -> void:
	if not is_instance_valid(node): return
	var target: Vector2 = node.position
	node.position = target + from_offset
	var tw := node.create_tween()
	tw.tween_property(node, "position", target,
		duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── Pulse ────────────────────────────────────────────────────────
## Repeating scale pulse — good for "attention" indicators.
## Returns the Tween; call .kill() to stop.
func pulse(node: Control, amplitude: float = 0.08,
		period: float = 1.0) -> Tween:
	if not is_instance_valid(node): return null
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.set_loops()
	var peak: Vector2 = Vector2.ONE * (1.0 + amplitude)
	tw.tween_property(node, "scale", peak, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

# ── Glow Flash ───────────────────────────────────────────────────
## Temporarily overrides a StyleBox's border color to simulate a glow.
func glow_flash(panel: PanelContainer, col: Color,
		duration: float = 0.4) -> void:
	if not is_instance_valid(panel): return
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if not style: return
	var orig: Color = style.border_color
	var tw := panel.create_tween()
	tw.tween_method(func(c: Color): style.border_color = c, orig, col, duration * 0.3)
	tw.tween_method(func(c: Color): style.border_color = c, col, orig, duration * 0.7).set_trans(Tween.TRANS_SINE)

# ── Number Pop ───────────────────────────────────────────────────
## Creates a floating "+N" label at world_pos that rises and fades.
## Delegates to FXBus if available, otherwise handles itself.
func number_pop(world_pos: Vector2, value: int, col: Color = Color.WHITE) -> void:
	if has_node("/root/FXBus"):
		get_node("/root/FXBus").score_popup(world_pos, value, col)
		return
	# Fallback (no FXBus)
	var root: Node = get_tree().get_root()
	var lbl := Label.new()
	lbl.text = "+%d" % value if value >= 0 else str(value)
	lbl.font_size = 20
	lbl.modulate = col
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 250
	root.add_child(lbl)
	lbl.global_position = world_pos
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "global_position", world_pos + Vector2(0, -70), 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.tween_callback(lbl.queue_free)

# ── Animated Counter Update ──────────────────────────────────────
## Resource feedback: ticks a counter label from old_val to new_val with
## easing, spawns micro sparkle particles during the count, and finishes
## with a soft scale pulse + gold flash.
##
## Parameters
##   hbox    — the HBoxContainer holding [icon, label] (used for pulse)
##   label   — the Label whose .text is the counter (tweened)
##   old_val — starting value
##   new_val — target value
##   prefix  — label prefix string e.g. "MOONPEARLS: "
##   fmt     — number format template (default GardenSeedManager.format_chips)
##   root    — optional parent for sparkle particles (defaults to hbox's parent)
func animated_counter_update(
		hbox: HBoxContainer,
		label: Label,
		old_val: int,
		new_val: int,
		prefix: String = "",
		fmt: String = "%s",
		root: Node = null) -> void:
	if not is_instance_valid(hbox) or not is_instance_valid(label):
		return
	if old_val == new_val:
		return

	# ── resolve particle root ────────────────────────────────────
	if root == null:
		root = hbox.get_parent()
	if not is_instance_valid(root):
		root = hbox

	# ── duration scales with delta (clamped) ─────────────────────
	var delta: int = absi(new_val - old_val)
	var duration: float = clampf(float(delta) * 0.04, 0.25, 0.9)

	# ── resolve format callback ──────────────────────────────────
	var format_fn: Callable
	# Try GardenSeedManager.format_chips first
	var GSM: Node = get_node_or_null("/root/GardenSeedManager")
	if GSM and GSM.has_method("format_chips"):
		format_fn = func(v: int) -> String: return GSM.format_chips(v)
	else:
		format_fn = func(v: int) -> String: return fmt % str(v)

	# ── helper: spawn one micro sparkle particle ─────────────────
	var spark_glyphs: Array[String] = ["✦", "·", "★", "✦"]
	var spark_colors: Array[Color] = [
		Color(1.0, 0.95, 0.65, 0.9),   # warm gold
		Color(0.85, 0.98, 1.0, 0.9),   # cool pearl
		Color(1.0, 0.85, 0.45, 0.85),  # bright gold
	]
	var _spawn_particle := func() -> void:
		var spark := Label.new()
		spark.text = spark_glyphs.pick_random()
		spark.add_theme_font_size_override("font_size", randi_range(8, 16))
		spark.modulate = spark_colors.pick_random()
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 300
		root.add_child(spark)
		# start at counter center
		var center: Vector2 = hbox.global_position + hbox.size * 0.5
		spark.global_position = center + Vector2(randf_range(-8, 8), randf_range(-4, 4))
		var drift: Vector2 = Vector2(randf_range(-18, 18), randf_range(-28, -8))
		var dur: float = randf_range(0.3, 0.55)
		var ts := spark.create_tween()
		ts.tween_property(spark, "global_position", spark.global_position + drift, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		ts.parallel().tween_property(spark, "scale", Vector2(1.4, 1.4), dur * 0.3)
		ts.parallel().tween_property(spark, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN).set_delay(dur * 0.3)
		ts.tween_callback(spark.queue_free)

	# ── tween: count up + micro particles ────────────────────────
	# Track last-spawned value so we emit particles at ~even intervals
	var _last_tick: int = old_val
	var _tick_interval: int = maxi(1, delta / maxi(1, int(delta * 0.6)))

	var tw := label.create_tween()
	tw.tween_method(func(v: float):
		var iv := int(v)
		label.text = prefix + format_fn.call(iv)
		# spawn particle at each tick interval
		var steps := absi(iv - _last_tick)
		if steps >= _tick_interval:
			_last_tick = iv
			_spawn_particle.call()
	, float(old_val), float(new_val), duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# ── final pulse + flash after count completes ────────────────
	tw.tween_callback(func():
		# ensure exact final text
		label.text = prefix + format_fn.call(new_val)
		# soft pulse on the whole hbox
		hbox.pivot_offset = hbox.size * 0.5
		var pt := hbox.create_tween()
		pt.tween_property(hbox, "scale", Vector2(1.12, 1.12), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pt.tween_property(hbox, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# gold flash on icon (first child)
		if hbox.get_child_count() > 0 and hbox.get_child(0) is CanvasItem:
			var icon: CanvasItem = hbox.get_child(0)
			var orig_mod: Color = icon.modulate
			var ft := icon.create_tween()
			ft.tween_property(icon, "modulate", Color(1.0, 0.95, 0.6, 1.0), 0.08)
			ft.tween_property(icon, "modulate", orig_mod, 0.20).set_trans(Tween.TRANS_SINE)
		# burst 4 arrival sparkles
			for _i in range(4):
				_spawn_particle.call()
		)

# ── Staged Count ──────────────────────────────────────────────────
## Builds checkpoint values for chunked counting and emits them via
## SignalBus.staged_count_updated at timed intervals, finishing with
## staged_count_finished.
##
## Usage:
##   await Juice.staged_count("moondrops", 42, 0.10)
##
## label_key — identifies which UI label should update (e.g. "moondrops", "star_power", "moonpearls")
## final_total — the target value to count up to
## step_duration — seconds between each checkpoint tick
func staged_count(label_key: String, final_total: int,
		step_duration: float = 0.10) -> void:
	if final_total <= 0:
		SignalBus.staged_count_finished.emit(label_key, 0)
		return

	var checkpoints: Array[int] = _build_staged_checkpoints(final_total)
	for value: int in checkpoints:
		SignalBus.staged_count_updated.emit(label_key, value)
		await get_tree().create_timer(step_duration).timeout

	SignalBus.staged_count_finished.emit(label_key, final_total)

## Builds chunked checkpoint values based on total size.
## Small totals (< 10): count every step.
## Medium totals (10–50): 4 checkpoints (20%, 40%, 60%, 100%).
## Large totals (> 50): weighted checkpoints (18%, 45%, 72%, 100%).
func _build_staged_checkpoints(final_total: int) -> Array[int]:
	if final_total <= 8:
		var steps: Array[int] = []
		for i: int in range(1, final_total + 1):
			steps.append(i)
		return steps

	if final_total <= 50:
		return _unique_sorted([
			roundi(final_total * 0.20),
			roundi(final_total * 0.40),
			roundi(final_total * 0.60),
			final_total,
		])

	return _unique_sorted([
		roundi(final_total * 0.18),
		roundi(final_total * 0.45),
		roundi(final_total * 0.72),
		final_total,
	])

func _unique_sorted(values: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for value: int in values:
		var clamped: int = maxi(1, value)
		if not result.has(clamped):
			result.append(clamped)
	result.sort()
	return result
