extends Control
class_name CraftingMinigame

# ─────────────────────────────────────────────────────────────────
# CraftingMinigame.gd  —  MOONSEED  v0.9.1
# GDD §9.4  Grid-based ingredient combining mini-game.
# Players drag ingredients into a 3-slot grid, then hit Craft.
# Correct combos craft the sweet; unknown combos show a hint.
# Emits: crafted(sweet_key), failed(candidate)
# ─────────────────────────────────────────────────────────────────

signal crafted(sweet_key: String)
signal failed(candidate: Array)

const SLOT_COUNT:  int   = 3
const SLOT_SIZE:   float = 60.0

# Slot state: Array of {id: String, qty: int} or null
var _slots:        Array = [null, null, null]
var _slot_panels:  Array = []
var _result_label: Label
var _craft_btn:    Button
var _hint_label:   Label

# Ingredient buttons in pantry (for clicking to assign to slot)
var _selected_ingredient: String = ""
var _selected_qty:        int    = 1
var _active_slot:         int    = -1

func _ready() -> void:
	_build_layout()
	call_deferred("_setup_feedback")

func _setup_feedback() -> void:
	if has_node("/root/ButtonFeedback"):
		get_node("/root/ButtonFeedback").setup_recursive(self)

func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "⚗️  CRAFTING BOILER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	vbox.add_child(title)

	# Ingredient source picker
	var source_lbl: Label = Label.new()
	source_lbl.text = "① Select ingredient from pantry, ② pick a slot, ③ CRAFT"
	source_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	source_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	source_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
	vbox.add_child(source_lbl)

	# Ingredient picker grid
	var ing_scroll: ScrollContainer = ScrollContainer.new()
	ing_scroll.custom_minimum_size = Vector2(0, 90)
	ing_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(ing_scroll)

	var ing_hbox: HBoxContainer = HBoxContainer.new()
	ing_hbox.add_theme_constant_override("separation", 5)
	ing_hbox.name = "IngredientPicker"
	ing_scroll.add_child(ing_hbox)

	# Slots row
	var slots_hbox: HBoxContainer = HBoxContainer.new()
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(slots_hbox)

	# Plus signs between slots
	for i in range(SLOT_COUNT):
		var slot_panel: PanelContainer = _build_slot_panel(i)
		_slot_panels.append(slot_panel)
		slots_hbox.add_child(slot_panel)
		if i < SLOT_COUNT - 1:
			var plus: Label = Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
			plus.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.4))
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slots_hbox.add_child(plus)

	# Hint label
	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	_hint_label.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.55))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_hint_label)

	# Craft row
	var craft_row: HBoxContainer = HBoxContainer.new()
	craft_row.alignment = BoxContainer.ALIGNMENT_CENTER
	craft_row.add_theme_constant_override("separation", 8)
	vbox.add_child(craft_row)

	_craft_btn = Button.new()
	_craft_btn.text = "🔥  CRAFT"
	_craft_btn.custom_minimum_size = Vector2(130, 42)
	_craft_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(15))
	_craft_btn.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	_craft_btn.pressed.connect(_attempt_craft)
	craft_row.add_child(_craft_btn)

	var clear_btn: Button = Button.new()
	clear_btn.text = "✗ Clear"
	clear_btn.custom_minimum_size = Vector2(70, 32)
	clear_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	clear_btn.pressed.connect(_clear_slots)
	craft_row.add_child(clear_btn)

	_result_label = Label.new()
	_result_label.text = ""
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	vbox.add_child(_result_label)

	refresh_ingredient_picker()

func _build_slot_panel(idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var st := StyleBoxFlat.new()
	st.bg_color     = Color(GameData.CARD_BG, 0.8)
	st.border_color = Color(GameData.ACCENT_BLUE, 0.4)
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", st)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(content)

	var emoji_lbl := Label.new()
	emoji_lbl.name = "EmojiLbl"
	emoji_lbl.text = "[ ]"
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
	emoji_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.3))
	content.add_child(emoji_lbl)

	var name_lbl := Label.new()
	name_lbl.name = "NameLbl"
	name_lbl.text = "empty"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(8))
	name_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.25))
	content.add_child(name_lbl)

	# Click to assign selected ingredient
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func(): _assign_to_slot(idx))
	panel.add_child(btn)

	return panel

# ──────────────────────────────────────────────────────────────────
# Ingredient Picker — builds clickable ingredient buttons from pantry
func refresh_ingredient_picker() -> void:
	var picker: Node = get_node_or_null("VBoxContainer/ScrollContainer/IngredientPicker")
	if not picker: return
	for ch in picker.get_children(): ch.queue_free()

	var inv: Dictionary = Database.get_all_ingredients()
	var has_any: bool = false
	for key in IngredientData.INGREDIENTS.keys():
		var count: int = int(inv.get(key, 0))
		if count == 0: continue
		has_any = true
		var ing: Dictionary = IngredientData.INGREDIENTS[key]
		var btn := Button.new()
		btn.text = "%s\n×%d" % [ing.get("emoji","?"), count]
		btn.custom_minimum_size = Vector2(52, 52)
		btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		btn.tooltip_text = ing.get("name","?")
		var rarity_col: Color = GameData.RARITY_COLORS.get(ing.get("rarity","common"), Color.WHITE) as Color
		btn.add_theme_color_override("font_color", rarity_col)
		btn.pressed.connect(func(): _select_ingredient(key, btn))
		picker.add_child(btn)

	if not has_any:
		var lbl := Label.new()
		lbl.text = "Complete a Pomodoro session to get ingredients!"
		lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.4))
		picker.add_child(lbl)

func _select_ingredient(key: String, btn: Button) -> void:
	_selected_ingredient = key
	# Highlight selected
	var picker: Node = get_node_or_null("VBoxContainer/ScrollContainer/IngredientPicker")
	if picker:
		for ch in picker.get_children():
			if ch is Button:
				ch.add_theme_color_override("font_color",
					GameData.ACCENT_GOLD if ch == btn else
					GameData.RARITY_COLORS.get(
						IngredientData.INGREDIENTS.get(_get_ing_key_from_btn(ch),"").get("rarity","common"),
						Color.WHITE) as Color)
	_hint_label.text = "Now click a slot →"

func _get_ing_key_from_btn(_btn: Button) -> String:
	return ""  # Placeholder; real lookup via btn.tooltip_text
	
func _assign_to_slot(idx: int) -> void:
	if _selected_ingredient == "":
		_hint_label.text = "Select an ingredient first."
		return
	var count_in_slots: int = 0
	for s in _slots:
		if s != null and s["id"] == _selected_ingredient:
			count_in_slots += s["qty"]
	var available: int = Database.get_ingredient(_selected_ingredient) - count_in_slots
	if available <= 0:
		_hint_label.text = "Not enough of that ingredient."
		return

	if _slots[idx] != null and _slots[idx]["id"] == _selected_ingredient:
		_slots[idx]["qty"] += 1
	elif _slots[idx] == null:
		_slots[idx] = {"id": _selected_ingredient, "qty": 1}
	else:
		_slots[idx] = {"id": _selected_ingredient, "qty": 1}

	_update_slot_display(idx)
	_hint_label.text = ""

func _update_slot_display(idx: int) -> void:
	var panel: PanelContainer = _slot_panels[idx] as PanelContainer
	var vbox: Node = panel.get_child(0)
	var emoji_lbl: Label = vbox.get_node("EmojiLbl") as Label
	var name_lbl:  Label = vbox.get_node("NameLbl")  as Label
	var slot: Variant = _slots[idx]

	# Reset border color
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(6)
	st.set_border_width_all(2)

	if slot == null:
		emoji_lbl.text = "[ ]"
		emoji_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.3))
		name_lbl.text = "empty"
		name_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.25))
		st.bg_color     = Color(GameData.CARD_BG, 0.8)
		st.border_color = Color(GameData.ACCENT_BLUE, 0.3)
	else:
		var ing: Dictionary = IngredientData.INGREDIENTS.get(slot["id"], {})
		var rarity_col: Color = GameData.RARITY_COLORS.get(ing.get("rarity","common"), Color.WHITE) as Color
		emoji_lbl.text = "%s ×%d" % [ing.get("emoji","?"), slot["qty"]]
		emoji_lbl.add_theme_color_override("font_color", rarity_col)
		name_lbl.text = ing.get("name","?")
		name_lbl.add_theme_color_override("font_color", rarity_col)
		st.bg_color     = Color(GameData.RARITY_BG.get(ing.get("rarity","common"), Color("#1a0a35")) as Color, 0.9)
		st.border_color = rarity_col

	panel.add_theme_stylebox_override("panel", st)

func _clear_slots() -> void:
	for i in range(SLOT_COUNT):
		_slots[i] = null
		_update_slot_display(i)
	_result_label.text = ""
	_hint_label.text   = ""
	_selected_ingredient = ""

# ──────────────────────────────────────────────────────────────────
# CRAFT ATTEMPT (§9.4)
func _attempt_craft() -> void:
	# Build candidate from slots (ignore empty slots)
	var candidate: Array = []
	var agg: Dictionary = {}  # id → qty aggregated
	for s in _slots:
		if s == null: continue
		if agg.has(s["id"]):
			agg[s["id"]] += s["qty"]
		else:
			agg[s["id"]] = s["qty"]
	for key in agg.keys():
		candidate.append({"id": key, "qty": agg[key]})

	if candidate.is_empty():
		_hint_label.text = "Add ingredients to the slots first."
		return

	# Check we actually have the ingredients
	for item in candidate:
		if Database.get_ingredient(item["id"]) < item["qty"]:
			_hint_label.text = "❌ Not enough %s" % IngredientData.INGREDIENTS.get(item["id"], {}).get("name","?")
			return

	# Try recipe discovery
	var sweet_key: String = IngredientData.try_discover_recipe(candidate)
	if sweet_key != "":
		# Consume ingredients
		for item in candidate:
			Database.use_ingredient(item["id"], item["qty"])
		Database.add_sweet(sweet_key, 1)
		var is_new: bool = Database.discover_recipe(sweet_key)
		SignalBus.ingredients_changed.emit()
		if is_new:
			SignalBus.recipe_discovered.emit(sweet_key)
		SignalBus.sweet_crafted.emit(sweet_key)
		var sweet_data: Dictionary = IngredientData.SWEETS.get(sweet_key, {})
		_result_label.text = "✅ Crafted: %s %s!" % [sweet_data.get("emoji",""), sweet_data.get("name","")]
		_result_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
		_clear_slots()
		refresh_ingredient_picker()
		crafted.emit(sweet_key)
		_animate_craft_success()
	else:
		_result_label.text = "🔮 Unknown combination..."
		_result_label.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
		_hint_property_hint(candidate)
		failed.emit(candidate)

func _hint_property_hint(candidate: Array) -> void:
	# Give a vague property-based hint (GDD §9.4 "rewards curiosity")
	var props: Array = []
	for item in candidate:
		var ing: Dictionary = IngredientData.INGREDIENTS.get(item["id"], {})
		for p in ing.get("props", []): if p not in props: props.append(p)
	if not props.is_empty():
		_hint_label.text = "Properties mixed: %s — try different ratios." % "  ".join(props)
	else:
		_hint_label.text = "No recipe found for this combination."

func _animate_craft_success() -> void:
	_result_label.pivot_offset = _result_label.size * 0.5
	var tw := _result_label.create_tween()
	tw.tween_property(_result_label, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_result_label, "scale", Vector2(1.0, 1.0), 0.1)
