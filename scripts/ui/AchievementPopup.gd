extends Control

# AchievementPopup.gd - Minecraft-style achievement popup in top-right corner
# Shows when achievements are unlocked

var _active_popups: Array[Control] = []
const MAX_POPUPS: int = 3
const POPUP_HEIGHT: float = 80.0
const POPUP_SPACING: float = 10.0
const DISPLAY_DURATION: float = 4.0
const FADE_DURATION: float = 0.5

func _ready() -> void:
	# Connect to achievement unlock signal
	if Engine.has_singleton("SignalBus"):
		SignalBus.achievement_unlocked.connect(_show_achievement_popup)
	
	# Position this container in top-right corner
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -320  # Width of popup
	offset_top = 20
	custom_minimum_size = Vector2(300, 0)

func _show_achievement_popup(_achievement_id: String, achievement_data: Dictionary) -> void:
	var popup := _create_popup(achievement_data)
	add_child(popup)
	_active_popups.append(popup)
	
	# Animate in
	_animate_popup_in(popup)
	
	# Position all active popups
	_reposition_popups()
	
	# Remove after duration
	await get_tree().create_timer(DISPLAY_DURATION).timeout
	_animate_popup_out(popup)
	await get_tree().create_timer(FADE_DURATION).timeout
	
	if popup.get_parent() == self:
		popup.queue_free()
		_active_popups.erase(popup)
		_reposition_popups()

func _create_popup(achievement_data: Dictionary) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(300, POPUP_HEIGHT)
	
	# Style the popup
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a1a2e")
	style.border_color = Color("#ffd700")  # Gold border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 2)
	container.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	container.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)
	
	# Achievement icon
	var icon_label := Label.new()
	icon_label.text = str(achievement_data.get("emoji", "🏆"))
	icon_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(32))
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)
	
	# Achievement text
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)
	
	var title_label := Label.new()
	title_label.text = "Achievement Unlocked!"
	title_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	title_label.add_theme_color_override("font_color", Color("#ffd700"))
	title_label.add_theme_font_override("font", load("res://assets/fonts/bold_font.ttf") if ResourceLoader.exists("res://assets/fonts/bold_font.ttf") else null)
	vbox.add_child(title_label)
	
	var name_label := Label.new()
	name_label.text = str(achievement_data.get("name", "Unknown"))
	name_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	name_label.add_theme_color_override("font_color", Color("#ffffff"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)
	
	return container

func _animate_popup_in(popup: Control) -> void:
	# Start from off-screen to the right
	popup.position.x = 320
	popup.modulate.a = 0.0
	
	var tween := create_tween()
	tween.set_parallel(true)
	
	# Slide in from right
	tween.tween_property(popup, "position:x", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Fade in
	tween.tween_property(popup, "modulate:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)

func _animate_popup_out(popup: Control) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	
	# Slide out to the right
	tween.tween_property(popup, "position:x", 320.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Fade out
	tween.tween_property(popup, "modulate:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)

func _reposition_popups() -> void:
	for i in range(_active_popups.size()):
		var popup: Control = _active_popups[i]
		if is_instance_valid(popup):
			var target_y := float(i) * (POPUP_HEIGHT + POPUP_SPACING)
			var tween := create_tween()
			tween.tween_property(popup, "position:y", target_y, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
