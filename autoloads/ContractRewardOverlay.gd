extends CanvasLayer

const METABALL_SHADER_PATH := "res://shaders/procedural_metaball_splash.gdshader"
const STREAKS_BY_RARITY := {
	"common": 4,
	"uncommon": 6,
	"rare": 8,
	"legendary": 11,
}
const STARFALL_PROFILE_BY_RARITY := {
	"common": {"delay": 0.09, "travel": 0.66, "impact_pause": 0.14, "impact_flash": 0.35, "trail_scale": 1.0},
	"uncommon": {"delay": 0.07, "travel": 0.6, "impact_pause": 0.12, "impact_flash": 0.45, "trail_scale": 1.12},
	"rare": {"delay": 0.055, "travel": 0.54, "impact_pause": 0.11, "impact_flash": 0.56, "trail_scale": 1.28},
	"legendary": {"delay": 0.045, "travel": 0.5, "impact_pause": 0.1, "impact_flash": 0.7, "trail_scale": 1.46},
}

enum WishState {
	IDLE,
	PORTAL_OPEN,
	STAR_LAUNCH,
	METEOR_FLIGHT,
	ATMOSPHERE_BREAK,
	FLASH_TRANSITION,
	REVEAL_LOOP,
	RESULT_SUMMARY,
	EXIT,
}

var _queue: Array = []
var _playing: bool = false
var _can_close: bool = false
var _close_requested: bool = false
var _skip_requested: bool = false
var _skip_presses: int = 0
var _state: int = WishState.IDLE

func _ready() -> void:
	layer = 140
	process_mode = Node.PROCESS_MODE_ALWAYS
	SignalBus.contract_reward_sequence.connect(_on_contract_reward_sequence)

func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	var pressed: bool = false
	if event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed:
		pressed = true
	if not pressed:
		return
	_skip_presses += 1
	if _can_close:
		_close_requested = true
	elif _skip_presses == 1:
		_skip_requested = true
	else:
		_skip_requested = true
		_close_requested = true
	get_viewport().set_input_as_handled()

func _on_contract_reward_sequence(reward_dict: Dictionary) -> void:
	if reward_dict.is_empty():
		return
	_queue.append(reward_dict.duplicate(true))
	if not _playing:
		_play_next_reward()

func _play_next_reward() -> void:
	if _queue.is_empty():
		return
	_playing = true
	var reward: Dictionary = _queue.pop_front()
	var request_id := _request_id_for_reward(reward)
	SignalBus.wish_sequence_started.emit(request_id)
	var overlay := _build_overlay(reward)
	await _run_sequence(overlay, reward)
	SignalBus.wish_sequence_finished.emit(request_id, [reward])
	var overlay_root := overlay.get("root", null) as Control
	if is_instance_valid(overlay_root):
		overlay_root.queue_free()
	_playing = false
	_skip_requested = false
	_skip_presses = 0
	_state = WishState.IDLE
	if not _queue.is_empty():
		call_deferred("_play_next_reward")

func _build_overlay(reward: Dictionary) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("02030b")
	bg.modulate.a = 0.0
	root.add_child(bg)

	var horizon := ColorRect.new()
	horizon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	horizon.color = Color("0d1840")
	horizon.material = _make_sky_gradient_material()
	horizon.modulate.a = 0.0
	horizon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(horizon)

	for nebula_data in [
		{"size": Vector2(520, 520), "color": Color("183068"), "pos": Vector2(120, 120)},
		{"size": Vector2(460, 460), "color": Color("3a1d65"), "pos": Vector2(780, 180)},
		{"size": Vector2(380, 380), "color": Color("0d5a6f"), "pos": Vector2(420, 520)},
	]:
		var nebula := ColorRect.new()
		nebula.size = nebula_data["size"]
		nebula.position = nebula_data["pos"]
		nebula.color = nebula_data["color"]
		nebula.modulate.a = 0.0
		nebula.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nebula_style := StyleBoxFlat.new()
		nebula_style.bg_color = nebula_data["color"]
		nebula_style.set_corner_radius_all(999)
		nebula.add_theme_stylebox_override("panel", nebula_style)
		var panel := PanelContainer.new()
		panel.size = nebula.size
		panel.position = nebula.position
		panel.modulate.a = 0.0
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", nebula_style)
		root.add_child(panel)
		nebula.queue_free()

	var star_layer := Control.new()
	star_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	star_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(star_layer)

	var flash_layer := ColorRect.new()
	flash_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_layer.color = Color.WHITE
	flash_layer.modulate.a = 0.0
	flash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_layer)

	var title := Label.new()
	title.text = "CONTRACT COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	title.add_theme_color_override("font_color", Color("d7ddff"))
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 62
	title.offset_bottom = 92
	title.modulate.a = 0.0
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = str(reward.get("contract_name", "Cerulean Contract"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	subtitle.add_theme_color_override("font_color", Color("9fb2e8"))
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 96
	subtitle.offset_bottom = 124
	subtitle.modulate.a = 0.0
	root.add_child(subtitle)

	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	stage.offset_left = -320
	stage.offset_top = -240
	stage.offset_right = 320
	stage.offset_bottom = 240
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)

	var halo := ColorRect.new()
	halo.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	halo.offset_left = -160
	halo.offset_top = -160
	halo.offset_right = 160
	halo.offset_bottom = 160
	halo.color = _reward_color(reward).lightened(0.35)
	halo.modulate.a = 0.0
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var halo_panel := PanelContainer.new()
	halo_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	halo_panel.offset_left = -160
	halo_panel.offset_top = -160
	halo_panel.offset_right = 160
	halo_panel.offset_bottom = 160
	halo_panel.modulate.a = 0.0
	halo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var halo_style := StyleBoxFlat.new()
	halo_style.bg_color = halo.color
	halo_style.set_corner_radius_all(999)
	halo_panel.add_theme_stylebox_override("panel", halo_style)
	stage.add_child(halo_panel)

	var seed_lbl := Label.new()
	seed_lbl.text = "🌱"
	seed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(110))
	seed_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	seed_lbl.offset_left = -120
	seed_lbl.offset_top = -120
	seed_lbl.offset_right = 120
	seed_lbl.offset_bottom = 120
	seed_lbl.modulate = Color(1, 1, 1, 0.0)
	seed_lbl.scale = Vector2(0.45, 0.45)
	stage.add_child(seed_lbl)

	var plant_lbl := Label.new()
	plant_lbl.text = str((reward.get("plant", {}) as Dictionary).get("emoji", "🌿"))
	plant_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plant_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plant_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(132))
	plant_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	plant_lbl.offset_left = -140
	plant_lbl.offset_top = -140
	plant_lbl.offset_right = 140
	plant_lbl.offset_bottom = 140
	plant_lbl.modulate = Color(1, 1, 1, 0.0)
	plant_lbl.scale = Vector2(0.68, 0.68)
	stage.add_child(plant_lbl)

	var reveal_fx := _build_reveal_fx_viewport(_reward_color(reward), str(reward.get("rarity", "common")))
	reveal_fx["container"].modulate.a = 0.0
	stage.add_child(reveal_fx["container"])

	var info := VBoxContainer.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	info.offset_left = -270
	info.offset_top = -10
	info.offset_right = 270
	info.offset_bottom = 150
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	info.modulate.a = 0.0
	root.add_child(info)

	var rarity_lbl := Label.new()
	rarity_lbl.text = str(reward.get("rarity", "common")).to_upper()
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	rarity_lbl.add_theme_color_override("font_color", _reward_color(reward))
	info.add_child(rarity_lbl)

	var name_lbl := Label.new()
	name_lbl.text = str((reward.get("plant", {}) as Dictionary).get("name", "Cerulean Bloom"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(28))
	name_lbl.add_theme_color_override("font_color", Color("f6f8ff"))
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	if bool(reward.get("seed_refunded", false)):
		desc_lbl.text = "Garden catalog already has this plant. A Cerulean Seed was refunded."
	else:
		desc_lbl.text = "The seed shattered open and planted itself in your garden."
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	desc_lbl.add_theme_color_override("font_color", Color("a9b4d8"))
	info.add_child(desc_lbl)

	var continue_lbl := Label.new()
	continue_lbl.text = "Click to fast-forward, click again to skip"
	continue_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	continue_lbl.add_theme_color_override("font_color", Color("6f7caa"))
	continue_lbl.modulate.a = 0.0
	info.add_child(continue_lbl)

	var summary := PanelContainer.new()
	summary.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	summary.offset_left = -240
	summary.offset_top = -220
	summary.offset_right = 240
	summary.offset_bottom = -70
	summary.modulate.a = 0.0
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var summary_st := StyleBoxFlat.new()
	summary_st.bg_color = Color("071023")
	summary_st.border_color = Color(_reward_color(reward), 0.9)
	summary_st.set_border_width_all(2)
	summary_st.set_corner_radius_all(14)
	summary.add_theme_stylebox_override("panel", summary_st)
	root.add_child(summary)

	var summary_box := HBoxContainer.new()
	summary_box.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_box.add_theme_constant_override("separation", 12)
	summary.add_child(summary_box)

	var summary_icon := Label.new()
	summary_icon.text = str((reward.get("plant", {}) as Dictionary).get("emoji", "🌿"))
	summary_icon.add_theme_font_size_override("font_size", GameData.scaled_font_size(38))
	summary_box.add_child(summary_icon)

	var summary_text := VBoxContainer.new()
	summary_text.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_text.add_theme_constant_override("separation", 2)
	summary_box.add_child(summary_text)

	var summary_title := Label.new()
	summary_title.text = "REWARD SUMMARY"
	summary_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	summary_title.add_theme_color_override("font_color", Color("a4b2df"))
	summary_text.add_child(summary_title)

	var summary_name := Label.new()
	summary_name.text = str((reward.get("plant", {}) as Dictionary).get("name", "Cerulean Bloom"))
	summary_name.add_theme_font_size_override("font_size", GameData.scaled_font_size(17))
	summary_name.add_theme_color_override("font_color", Color("ecf3ff"))
	summary_text.add_child(summary_name)

	return {
		"root": root,
		"bg": bg,
		"horizon": horizon,
		"star_layer": star_layer,
		"flash_layer": flash_layer,
		"stage": stage,
		"title": title,
		"subtitle": subtitle,
		"halo": halo_panel,
		"seed": seed_lbl,
		"plant": plant_lbl,
		"info": info,
		"continue": continue_lbl,
		"summary": summary,
		"fx_container": reveal_fx["container"],
		"fx_material": reveal_fx["material"],
	}

func _run_sequence(overlay: Dictionary, reward: Dictionary) -> void:
	_can_close = false
	_close_requested = false
	_skip_requested = false
	_skip_presses = 0

	_state = WishState.PORTAL_OPEN
	await _state_portal_open(overlay)
	if _close_requested:
		SignalBus.wish_sequence_skipped.emit(_request_id_for_reward(reward))

	if not _close_requested:
		_state = WishState.STAR_LAUNCH
		await _state_star_launch(overlay, reward)
	if not _close_requested:
		_state = WishState.METEOR_FLIGHT
		await _state_meteor_flight(overlay, reward)
	if not _close_requested:
		_state = WishState.ATMOSPHERE_BREAK
		await _state_atmosphere_break(overlay, reward)
	if not _close_requested:
		_state = WishState.FLASH_TRANSITION
		await _state_flash_transition(overlay, reward)
	if not _close_requested:
		_state = WishState.REVEAL_LOOP
		await _state_reveal_loop(overlay, reward)
	if not _close_requested:
		_state = WishState.RESULT_SUMMARY
		await _state_result_summary(overlay)

	_state = WishState.EXIT
	var outro := create_tween()
	outro.set_parallel(true)
	outro.tween_property(overlay["root"], "modulate:a", 0.0, 0.22)
	outro.tween_property(overlay["root"], "scale", Vector2(1.03, 1.03), 0.22)
	await outro.finished
	_can_close = false

func _state_portal_open(overlay: Dictionary) -> void:
	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(overlay["bg"], "modulate:a", 0.92, 0.35)
	intro.tween_property(overlay["horizon"], "modulate:a", 0.88, 0.45)
	intro.tween_property(overlay["title"], "modulate:a", 1.0, 0.35)
	intro.tween_property(overlay["subtitle"], "modulate:a", 1.0, 0.42)
	intro.tween_property(overlay["seed"], "modulate:a", 1.0, 0.28)
	intro.tween_property(overlay["seed"], "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(overlay["halo"], "modulate:a", 0.26, 0.32)
	await intro.finished

func _state_star_launch(overlay: Dictionary, reward: Dictionary) -> void:
	var seed_ctrl := overlay["seed"] as Control
	var launch := create_tween()
	launch.set_parallel(true)
	launch.tween_property(seed_ctrl, "position", seed_ctrl.position + Vector2(0, -66), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	launch.tween_property(seed_ctrl, "scale", Vector2(0.82, 0.82), 0.22)
	launch.tween_property(overlay["halo"], "modulate:a", 0.4, 0.22)
	await launch.finished
	SignalBus.wish_rarity_telegraph.emit(_rarity_tier(reward))

func _state_meteor_flight(overlay: Dictionary, reward: Dictionary) -> void:
	var impact_strength: float = await _play_starfall(overlay["star_layer"], reward)
	var hold := clampf(impact_strength * 0.08, 0.02, 0.06)
	await _wait_or_skip(hold)

func _state_atmosphere_break(overlay: Dictionary, reward: Dictionary) -> void:
	var stage := overlay["stage"] as Control
	var break_tw := create_tween()
	break_tw.set_parallel(true)
	break_tw.tween_property(stage, "rotation_degrees", 1.8, 0.08)
	break_tw.tween_property(stage, "scale", Vector2(1.03, 1.03), 0.08)
	break_tw.chain().tween_property(stage, "rotation_degrees", 0.0, 0.14)
	break_tw.parallel().tween_property(stage, "scale", Vector2.ONE, 0.14)
	break_tw.parallel().tween_property(overlay["flash_layer"], "modulate:a", clampf(_impact_strength_for_reward(reward), 0.18, 0.5), 0.08)
	break_tw.chain().tween_property(overlay["flash_layer"], "modulate:a", 0.0, 0.1)
	await break_tw.finished

func _state_flash_transition(overlay: Dictionary, _reward: Dictionary) -> void:
	var flash := create_tween()
	flash.tween_property(overlay["flash_layer"], "modulate:a", 1.0, 0.06)
	flash.tween_property(overlay["flash_layer"], "modulate:a", 0.0, 0.12)
	await flash.finished

func _state_reveal_loop(overlay: Dictionary, reward: Dictionary) -> void:
	var rarity := str(reward.get("rarity", "common")).to_lower()
	# Frame-hold: brief dramatic pause before the burst for epic/legendary/exotic
	if rarity in ["epic", "legendary", "exotic"] and not _skip_requested:
		var hold_dur := 0.18 if rarity == "epic" else (0.28 if rarity == "legendary" else 0.38)
		await _wait_or_skip(hold_dur)
	var aura := _build_rarity_aura(overlay["root"] as Control, reward)
	await _play_reveal_break(overlay, reward, _impact_strength_for_reward(reward))
	if is_instance_valid(aura):
		var fade := create_tween()
		fade.tween_property(aura, "modulate:a", 0.0, 0.55)
		fade.tween_callback(aura.queue_free)
	SignalBus.wish_item_revealed.emit(0, reward.duplicate(true))

func _state_result_summary(overlay: Dictionary) -> void:
	var settle := create_tween()
	settle.set_parallel(true)
	settle.tween_property(overlay["info"], "modulate:a", 1.0, 0.24)
	settle.tween_property(overlay["continue"], "modulate:a", 1.0, 0.3)
	settle.tween_property(overlay["summary"], "modulate:a", 1.0, 0.28)
	await settle.finished

	_can_close = true
	var hold_s := 4.0 if not _skip_requested else 0.9
	var hold_timer := get_tree().create_timer(hold_s)
	while not _close_requested and hold_timer.time_left > 0.0:
		await get_tree().process_frame

func _impact_strength_for_reward(reward: Dictionary) -> float:
	var rarity := str(reward.get("rarity", "common"))
	var profile: Dictionary = STARFALL_PROFILE_BY_RARITY.get(rarity, STARFALL_PROFILE_BY_RARITY["common"])
	return float(profile.get("impact_flash", 0.4))

func _play_starfall(star_layer: Control, reward: Dictionary) -> float:
	var color := _reward_color(reward)
	var rarity := str(reward.get("rarity", "common"))
	var streak_count := int(STREAKS_BY_RARITY.get(rarity, 4))
	if str(reward.get("reward_type", "minor")) == "major":
		streak_count += 3
	var profile: Dictionary = STARFALL_PROFILE_BY_RARITY.get(rarity, STARFALL_PROFILE_BY_RARITY["common"])
	var companion_count := 1 if str(reward.get("reward_type", "minor")) == "major" else 0
	for i in range(streak_count):
		_spawn_star_streak(star_layer, color, i, streak_count, profile)
		for c in range(companion_count):
			_spawn_star_streak(star_layer, Color("a8c7ff"), i + c + 1, streak_count + companion_count + 1, {
				"trail_scale": 0.75,
				"travel": float(profile.get("travel", 0.62)) * 0.9,
			})
		await get_tree().create_timer(float(profile.get("delay", 0.08))).timeout
		if _skip_requested:
			break
	await get_tree().create_timer(float(profile.get("impact_pause", 0.12))).timeout
	return float(profile.get("impact_flash", 0.4))

func _wait_or_skip(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration and not _close_requested:
		if _skip_requested:
			break
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func _request_id_for_reward(reward: Dictionary) -> String:
	var contract_id := int(reward.get("contract_id", 0))
	var plant_id := str(reward.get("plant_id", "none"))
	return "contract_%d_%s" % [contract_id, plant_id]

func _rarity_tier(reward: Dictionary) -> String:
	var rarity := str(reward.get("rarity", "common")).to_lower()
	if rarity in ["legendary", "exotic"]:
		return "tier_high"
	if rarity in ["rare", "epic"]:
		return "tier_mid"
	return "tier_low"

func _spawn_star_streak(parent: Control, color: Color, index: int, total: int, profile: Dictionary) -> void:
	var trail_scale := float(profile.get("trail_scale", 1.0))
	var travel := float(profile.get("travel", 0.62)) + index * 0.02

	var streak := Control.new()
	streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak.rotation_degrees = -36.0 + randf_range(-4.5, 4.5)
	streak.position = Vector2(
		220.0 + float(index) * (760.0 / max(total, 1)) + randf_range(-45.0, 45.0),
		-250.0 - index * 36.0 + randf_range(-24.0, 10.0)
	)
	parent.add_child(streak)

	# ── Tapered comet tail (shader-driven gradient) ──────────────────
	var tail_w := (150.0 + index * 30.0) * trail_scale
	var tail_h := (8.0 + index * 1.0) * trail_scale
	var tail := ColorRect.new()
	tail.size = Vector2(tail_w, tail_h)
	tail.position = Vector2(-tail_w, -tail_h * 0.5)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.modulate.a = 0.0
	var tail_shader := Shader.new()
	tail_shader.code = """
shader_type canvas_item;
uniform vec4 star_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	float along  = UV.x;                         // 0=tail end, 1=head
	float across = abs(UV.y - 0.5) * 2.0;        // 0=centre, 1=edge
	float taper  = along;
	float edge_mask  = smoothstep(1.0, taper * 0.62, across);
	float brightness = pow(along, 1.7);
	float glow_line  = exp(-across * across * 24.0) * along;
	float alpha = (edge_mask * brightness + glow_line * 0.55) * star_color.a;
	vec3  col   = mix(star_color.rgb, vec3(1.0), glow_line * 0.45);
	COLOR = vec4(col, alpha);
}
"""
	var tail_mat := ShaderMaterial.new()
	tail_mat.shader = tail_shader
	tail_mat.set_shader_parameter("star_color", color)
	tail.material = tail_mat
	streak.add_child(tail)

	# ── Outer soft glow ring around head ────────────────────────────
	var glow_r := (12.0 + index * 2.2) * trail_scale
	var glow := PanelContainer.new()
	glow.custom_minimum_size = Vector2(glow_r * 2.0, glow_r * 2.0)
	glow.size = Vector2(glow_r * 2.0, glow_r * 2.0)
	glow.position = Vector2(-glow_r, -glow_r)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate = Color(color, 0.0)
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(color, 0.28)
	glow_style.set_corner_radius_all(int(glow_r))
	glow.add_theme_stylebox_override("panel", glow_style)
	streak.add_child(glow)

	# ── Bright circular comet head ───────────────────────────────────
	var head_r := (5.0 + index * 1.2) * trail_scale
	var head := PanelContainer.new()
	head.custom_minimum_size = Vector2(head_r * 2.0, head_r * 2.0)
	head.size = Vector2(head_r * 2.0, head_r * 2.0)
	head.position = Vector2(-head_r, -head_r)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.modulate.a = 0.0
	var head_style := StyleBoxFlat.new()
	head_style.bg_color = color.lightened(0.55)
	head_style.set_corner_radius_all(int(head_r) + 1)
	head.add_theme_stylebox_override("panel", head_style)
	streak.add_child(head)

	# ── Animate ──────────────────────────────────────────────────────
	var flash := create_tween()
	flash.set_parallel(true)
	flash.tween_property(tail, "modulate:a", 0.92, 0.07)
	flash.tween_property(glow, "modulate:a", 0.85, 0.07)
	flash.tween_property(head, "modulate:a", 1.0, 0.06)
	flash.tween_property(streak, "position", streak.position + Vector2(860, 760), travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flash.tween_property(streak, "scale", Vector2(1.8 * trail_scale, 1.3 * trail_scale), travel)
	flash.chain().tween_property(tail, "modulate:a", 0.0, 0.18)
	flash.parallel().tween_property(glow, "modulate:a", 0.0, 0.18)
	flash.parallel().tween_property(head, "modulate:a", 0.0, 0.18)
	flash.tween_callback(streak.queue_free)

# ─────────────────────────────────────────────────────────────────
# RARITY AURA  —  rarity-tiered shader overlay placed behind the
# reveal stage.  Each tier adds one extra visual layer.
# ─────────────────────────────────────────────────────────────────
func _build_rarity_aura(root: Control, reward: Dictionary) -> Control:
	var rarity := str(reward.get("rarity", "common")).to_lower()
	var color  := _reward_color(reward)
	var aura   := ColorRect.new()
	aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.modulate.a   = 0.0
	root.add_child(aura)
	root.move_child(aura, 3)  # behind stage, above sky horizon

	var shader := Shader.new()
	match rarity:
		"common":
			# Slow breathing rim glow
			shader.code = """
shader_type canvas_item;
uniform vec4 rim_color : source_color = vec4(0.7,0.8,0.7,1.0);
void fragment() {
	vec2  c    = UV - vec2(0.5);
	float dist = length(c);
	float rim  = smoothstep(0.44, 0.38, dist) * smoothstep(0.22, 0.38, dist);
	float pulse= 0.55 + 0.45 * sin(TIME * 1.8);
	COLOR = vec4(rim_color.rgb, rim * pulse * 0.32);
}
"""
		"uncommon":
			# Animated vertical gradient sweep — energy drifting upward
			shader.code = """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.2,1.0,0.5,1.0);
void fragment() {
	float shift  = fract(UV.y - TIME * 0.18);
	float band   = smoothstep(0.0, 0.35, shift) * smoothstep(0.7, 0.35, shift);
	float vign   = 1.0 - smoothstep(0.3, 0.5, length(UV - vec2(0.5)));
	COLOR = vec4(tint.rgb, band * vign * 0.38);
}
"""
		"rare":
			# Diagonal light-sweep across the screen
			shader.code = """
shader_type canvas_item;
uniform vec4 sweep_color : source_color = vec4(0.35,0.55,1.0,1.0);
void fragment() {
	float axis   = UV.x * 0.6 + UV.y * 0.4;
	float sweep  = fract(axis - TIME * 0.22);
	float band   = smoothstep(0.0, 0.12, sweep) * smoothstep(0.28, 0.12, sweep);
	float vign   = 1.0 - smoothstep(0.28, 0.52, length(UV - vec2(0.5)));
	COLOR = vec4(sweep_color.rgb, (band * 0.55 + vign * 0.08) * sweep_color.a);
}
"""
		"epic":
			# Chromatic aberration ring + wavy UV distortion aura
			shader.code = """
shader_type canvas_item;
uniform vec4 aura_color : source_color = vec4(0.7,0.2,1.0,1.0);
void fragment() {
	vec2  c      = UV - vec2(0.5);
	float dist   = length(c);
	vec2  wave   = c + vec2(
			sin(TIME * 2.8 + UV.y * 10.0) * 0.006,
			cos(TIME * 2.4 + UV.x * 10.0) * 0.006);
	float ring   = smoothstep(0.42, 0.36, dist) * smoothstep(0.25, 0.36, dist);
	float rr     = smoothstep(0.43, 0.37, length(wave + vec2(0.005,0.0)));
	float bb     = smoothstep(0.41, 0.35, length(wave - vec2(0.005,0.0)));
	vec3  col    = vec3(rr, ring, bb) * aura_color.rgb;
	COLOR = vec4(col, clamp((rr + bb) * 0.55, 0.0, 0.72));
}
"""
		"legendary":
			# Radial sunrays + metallic specular sweep
			shader.code = """
shader_type canvas_item;
uniform vec4 ray_color : source_color = vec4(1.0,0.82,0.22,1.0);
void fragment() {
	vec2  c     = UV - vec2(0.5);
	float angle = atan(c.y, c.x);
	float dist  = length(c);
	float spokes = 14.0;
	float ray    = pow(max(0.0, cos(angle * spokes + TIME * 0.9)), 6.0);
	float falloff= smoothstep(0.55, 0.05, dist);
	float spec   = pow(max(0.0, sin(UV.x * 3.0 - TIME * 0.7)), 8.0) * 0.45;
	float total  = (ray * 0.62 + spec) * falloff;
	COLOR = vec4(ray_color.rgb, total * ray_color.a);
}
"""
		_:
			# exotic — spiral void aura + temporal glitch flicker on edges
			shader.code = """
shader_type canvas_item;
uniform vec4 void_color : source_color = vec4(0.8,0.08,0.15,1.0);
void fragment() {
	vec2  c     = UV - vec2(0.5);
	float dist  = length(c);
	float angle = atan(c.y, c.x);
	float spiral = sin(angle * 4.0 - dist * 18.0 + TIME * 3.5);
	float noise  = fract(sin(dot(UV * 47.3, vec2(12.98, 78.23)) + TIME * 31.0) * 4375.9);
	float glitch = step(0.96, noise) * step(0.32, dist) * step(dist, 0.48);
	float ring   = smoothstep(0.48, 0.36, dist) * smoothstep(0.22, 0.36, dist);
	float arc    = (spiral * 0.5 + 0.5) * ring;
	COLOR = vec4(mix(void_color.rgb, vec3(1.0), glitch * 0.8), (arc * 0.75 + glitch * 0.9) * void_color.a);
}
"""

	var mat := ShaderMaterial.new()
	mat.shader = shader
	for param_name in ["rim_color","tint","sweep_color","aura_color","ray_color","void_color"]:
		mat.set_shader_parameter(param_name, color)
	aura.material = mat

	var peak_alpha: float = {"common":0.28,"uncommon":0.42,"rare":0.60,"epic":0.80,"legendary":0.92,"exotic":1.0}.get(rarity, 0.35)
	var fade_in := create_tween()
	fade_in.tween_property(aura, "modulate:a", peak_alpha, 0.18)
	return aura

func _play_reveal_break(overlay: Dictionary, reward: Dictionary, impact_strength: float = 0.4) -> void:
	var flash_rect := ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = _reward_color(reward).lightened(0.55)
	flash_rect.modulate.a = 0.0
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(overlay["root"] as Control).add_child(flash_rect)
	(overlay["root"] as Control).move_child(flash_rect, (overlay["root"] as Control).get_child_count() - 1)

	var material := overlay["fx_material"] as ShaderMaterial
	material.set_shader_parameter("progress", 0.0)
	var reveal := create_tween()
	reveal.set_parallel(true)
	reveal.tween_property(overlay["fx_container"], "modulate:a", 1.0, 0.08)
	reveal.tween_method(_set_reveal_progress.bind(material), 0.0, 1.0, 0.72)
	reveal.tween_property(overlay["seed"], "modulate:a", 0.0, 0.2)
	reveal.tween_property(overlay["seed"], "scale", Vector2(0.16, 0.16), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	reveal.tween_property(overlay["plant"], "modulate:a", 1.0, 0.24).set_delay(0.1)
	reveal.tween_property(overlay["plant"], "scale", Vector2.ONE, 0.36).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(overlay["halo"], "modulate:a", 0.72, 0.14)
	reveal.tween_property(overlay["stage"], "scale", Vector2(1.08, 1.08), 0.12)
	reveal.tween_property(flash_rect, "modulate:a", clampf(impact_strength, 0.25, 0.78), 0.07)
	reveal.chain().tween_property(overlay["stage"], "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.chain().tween_property(flash_rect, "modulate:a", 0.0, 0.28)
	await reveal.finished
	var cleanup := create_tween()
	cleanup.set_parallel(true)
	cleanup.tween_property(overlay["fx_container"], "modulate:a", 0.0, 0.22)
	cleanup.tween_property(overlay["halo"], "modulate:a", 0.34, 0.28)
	await cleanup.finished
	flash_rect.queue_free()

func _build_reveal_fx_viewport(color: Color, rarity: String) -> Dictionary:
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	container.offset_left = -230
	container.offset_top = -230
	container.offset_right = 230
	container.offset_bottom = 230
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	viewport.size = Vector2i(460, 460)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.4
	camera.position = Vector3(0.0, 0.0, 2.0)
	camera.current = true
	world.add_child(camera)

	var splash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.35, 2.35)
	splash.mesh = quad
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := _make_reveal_material(color, rarity)
	splash.material_override = material
	world.add_child(splash)

	return {"container": container, "material": material}

func _make_reveal_material(color: Color, rarity: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	if ResourceLoader.exists(METABALL_SHADER_PATH):
		material.shader = load(METABALL_SHADER_PATH)
	_configure_watering_metaball_base(material)
	material.set_shader_parameter("ease_progress", 4)
	material.set_shader_parameter("color_gradient", _make_gradient_texture([
		[0.0, Color("ffffff")],
		[0.42, color.lightened(0.5)],
		[0.82, color],
		[1.0, Color(color, 0.0)],
	]))
	material.set_shader_parameter("emission_intensity", 2.7 if rarity == "legendary" else (2.15 if rarity == "rare" else 1.9))
	material.set_shader_parameter("particles", 16 if rarity == "legendary" else (13 if rarity == "rare" else 10))
	material.set_shader_parameter("particle_size", 0.05 if rarity != "legendary" else 0.052)
	material.set_shader_parameter("size_curve", _make_gradient_texture([
		[0.0, 0.0],
		[0.14, 1.0],
		[0.86, 0.82],
		[1.0, 0.0],
	]))
	material.set_shader_parameter("randomize_size", Vector2(1.0, 4.8))
	material.set_shader_parameter("particle_feather", 0.52)
	material.set_shader_parameter("randomize_feather", Vector2(0.68, 1.1))
	material.set_shader_parameter("feather_curve", _make_gradient_texture([
		[0.0, 0.0],
		[0.88, 1.0],
		[1.0, 1.0],
	]))
	material.set_shader_parameter("initial_particle_velocity", -0.32)
	material.set_shader_parameter("acceleration", Vector4(0.7, 0.7, 0.18, 0.18))
	material.set_shader_parameter("acceleration_curve", _make_gradient_texture([
		[0.0, 0.0],
		[0.4, 0.0],
		[1.0, 0.56],
	]))
	material.set_shader_parameter("custom_feather_interp", _make_gradient_texture([
		[0.0, 0.0],
		[0.125, 0.88],
		[0.25, 0.8],
		[0.75, 0.9],
		[0.875, 0.65],
		[1.0, 1.0],
	]))
	material.set_shader_parameter("generic_curve_A", _make_gradient_texture([
		[0.0, 0.0],
		[0.94, 1.0],
		[1.0, 0.0],
	]))
	material.set_shader_parameter("apply_iridescence", 2)
	material.set_shader_parameter("iridescence", Vector4(2.0, 0.0, 0.0, 1.0))
	material.set_shader_parameter("iridescence_size", 0.62 if rarity == "legendary" else (0.54 if rarity == "rare" else 0.5))
	return material

func _configure_watering_metaball_base(material: ShaderMaterial) -> void:
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("derive_progress", 1)
	material.set_shader_parameter("ease_progress", 3)
	material.set_shader_parameter("shading", 3)
	material.set_shader_parameter("color_gradient", _make_gradient_texture([
		[0.0, Color("#ffffff")],
		[0.671, Color("#a3ffff")],
		[1.0, Color("#a3cfff00")],
	]))
	material.set_shader_parameter("emission_intensity", 1.5)
	material.set_shader_parameter("particles", 8)
	material.set_shader_parameter("particle_size", 0.04)
	material.set_shader_parameter("size_curve", _make_gradient_texture([
		[0.0, 0.0],
		[0.1, 1.0],
		[1.0, 0.0],
	]))
	material.set_shader_parameter("randomize_size", Vector2(1.0, 5.0))
	material.set_shader_parameter("particle_feather", 0.5)
	material.set_shader_parameter("randomize_feather", Vector2(0.6, 1.0))
	material.set_shader_parameter("feather_curve", _make_gradient_texture([
		[0.0, 0.0],
		[0.9, 1.0],
		[1.0, 1.0],
	]))
	material.set_shader_parameter("initial_particle_velocity", -0.3)
	material.set_shader_parameter("ease_ipv", 1)
	material.set_shader_parameter("index_shift_randomness", 1)
	material.set_shader_parameter("emission_dir", Vector2(1.0, 1.0))
	material.set_shader_parameter("acceleration", Vector4(0.5, 0.5, 0.1, 0.1))
	material.set_shader_parameter("acceleration_curve", _make_gradient_texture([
		[0.0, 0.0],
		[0.35, 0.0],
		[1.0, 0.5],
	]))
	material.set_shader_parameter("blob_step", 0.01)
	material.set_shader_parameter("feather_interpolation", 4)
	material.set_shader_parameter("custom_feather_interp", _make_gradient_texture([
		[0.0, 0.0],
		[0.125, 0.875],
		[0.25, 0.8],
		[0.75, 0.875],
		[0.875, 0.625],
		[1.0, 1.0],
	]))
	material.set_shader_parameter("uv_scale", Vector2(1.3, 1.3))
	material.set_shader_parameter("enable_texture_distortion", 5)
	material.set_shader_parameter("txdistort_str", 0.1)
	material.set_shader_parameter("txdistort_a", _make_cellular_noise_texture())
	material.set_shader_parameter("index_shift_distort_texture", 1)
	material.set_shader_parameter("alpha_dissolve", 1)
	material.set_shader_parameter("ease_alpha_dissolve", 1)
	material.set_shader_parameter("alpha_edge", Vector2(0.99, 1.0))
	material.set_shader_parameter("proximity_fade_distance", 0.5)
	material.set_shader_parameter("billboard", 1)
	material.set_shader_parameter("camera_offset", 0.1)

func _make_gradient_texture(stops: Array, width: int = 256) -> GradientTexture1D:
	var gradient := Gradient.new()
	var colors := PackedColorArray()
	var offsets := PackedFloat32Array()
	for stop in stops:
		offsets.append(float(stop[0]))
		var stop_value: Variant = stop[1]
		if stop_value is Color:
			colors.append(stop_value as Color)
		else:
			var gray := float(stop_value)
			colors.append(Color(gray, gray, gray, 1.0))
	gradient.colors = colors
	gradient.offsets = offsets
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = width
	return texture

func _make_cellular_noise_texture(size: int = 256) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 2.35
	noise.fractal_octaves = 1
	var texture := NoiseTexture2D.new()
	texture.width = size
	texture.height = size
	texture.seamless = true
	texture.noise = noise
	return texture

func _make_sky_gradient_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 top_color : source_color = vec4(0.03, 0.05, 0.12, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.12, 0.18, 0.35, 1.0);
void fragment() {
	vec4 base = mix(top_color, bottom_color, UV.y);
	float vignette = smoothstep(0.95, 0.15, distance(UV, vec2(0.5)));
	COLOR = vec4(base.rgb * mix(0.82, 1.12, vignette), 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _set_reveal_progress(value: float, material: ShaderMaterial) -> void:
	if material == null:
		return
	material.set_shader_parameter("progress", value)

func _reward_color(reward: Dictionary) -> Color:
	var rarity := str(reward.get("rarity", "common"))
	return GameData.RARITY_COLORS.get(rarity, GameData.FG_COLOR)
