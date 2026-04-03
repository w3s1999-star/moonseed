extends CanvasLayer

# ─────────────────────────────────────────────────────────────────
# RecipeDiscoveryOverlay.gd  —  MOONSEED v0.9.1
# Full-screen flash when a new recipe is discovered.
# Used by: SignalBus.recipe_discovered
# ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 150
	SignalBus.recipe_discovered.connect(_on_recipe_discovered)

func _on_recipe_discovered(sweet_key: String) -> void:
	var sweet: Dictionary = IngredientData.SWEETS.get(sweet_key, {})
	_show_discovery(sweet.get("emoji","✨"), sweet.get("name","New Recipe!"))

func _show_discovery(emoji: String, name: String) -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var star_lbl := Label.new()
	star_lbl.text = emoji
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(72))
	star_lbl.modulate.a = 0.0
	vbox.add_child(star_lbl)

	var title_lbl := Label.new()
	title_lbl.text = "✦ NEW RECIPE DISCOVERED ✦"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(24))
	title_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	title_lbl.modulate.a = 0.0
	vbox.add_child(title_lbl)

	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	name_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	name_lbl.modulate.a = 0.0
	vbox.add_child(name_lbl)

	# Animate in
	var tw := vbox.create_tween()
	tw.tween_property(bg, "color", Color(0.0, 0.0, 0.0, 0.72), 0.2)
	tw.tween_property(star_lbl,  "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(title_lbl, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(name_lbl,  "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.0)
	tw.tween_property(bg,        "color",     Color(0.0, 0.0, 0.0, 0.0), 0.5)
	tw.parallel().tween_property(star_lbl,  "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(title_lbl, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(name_lbl,  "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): bg.queue_free(); vbox.queue_free())
