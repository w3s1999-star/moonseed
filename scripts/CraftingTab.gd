extends Control

# ─────────────────────────────────────────────────────────────────
# CraftingTab.gd  —  MOONSEED  v0.9.1
# GDD §9.4  The Crafting Mini-Game
#
# Grid-based ingredient combining — players slot ingredients into a
# 3×2 grid. When a valid recipe pattern is matched, the sweet
# is crafted. Undiscovered recipes are revealed on first craft.
# Properties: Sweet, Cosmic, Bitter, Floral, Dark
# ─────────────────────────────────────────────────────────────────

const GRID_COLS: int = 3
const GRID_ROWS: int = 2
const SLOT_SIZE: Vector2 = Vector2(72, 72)

var _grid_slots: Array = []      # 6 slots, each: {ingredient_id or null}
var _selected_ingredient: String = ""
var _slot_controls: Array = []
var _ingredient_btns: Dictionary = {}
var _result_panel: PanelContainer
var _craft_btn: Button
var _result_lbl: Label
var _result_emoji: Label
var _pantry_grid: GridContainer
var _last_match: String = ""

func _ready() -> void:
	# FIX: connect to SignalBus, not GameData directly
	SignalBus.state_changed.connect(_refresh)
	SignalBus.ingredients_changed.connect(_refresh)
	_grid_slots.resize(GRID_COLS * GRID_ROWS)
	_grid_slots.fill(null)
	_build_layout()
	_refresh()
	call_deferred("_setup_feedback")

func _setup_feedback() -> void:
	if has_node("/root/ButtonFeedback"):
		get_node("/root/ButtonFeedback").setup_recursive(self)

# ══════════════════════════════════════════════════════════════════
# LAYOUT
# ══════════════════════════════════════════════════════════════════
func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = GameData.BG_COLOR
	add_child(bg)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)

	# Title
	var title: Label = Label.new()
	title.text = "⚗️  CRAFTING LAB"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	outer.add_child(title)

	var sub: Label = Label.new()
	sub.text = "Combine ingredients to discover Sweets. Experiment — some recipes are secret."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	sub.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
	outer.add_child(sub)

	# ── Main crafting area ────────────────────────────────────────
	var main_hbox: HBoxContainer = HBoxContainer.new()
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 16)
	outer.add_child(main_hbox)

	# LEFT: Ingredient palette
	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(200, 0)
	left_vbox.add_theme_constant_override("separation", 4)
	main_hbox.add_child(left_vbox)

	var palette_lbl: Label = Label.new()
	palette_lbl.text = "🧪 SELECT INGREDIENT"
	palette_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	palette_lbl.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
	left_vbox.add_child(palette_lbl)

	var palette_scroll: ScrollContainer = ScrollContainer.new()
	palette_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(palette_scroll)

	_pantry_grid = GridContainer.new()
	_pantry_grid.columns = 2
	_pantry_grid.add_theme_constant_override("h_separation", 4)
	_pantry_grid.add_theme_constant_override("v_separation", 4)
	_pantry_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_scroll.add_child(_pantry_grid)

	# CENTER: Crafting grid + result
	var center_vbox: VBoxContainer = VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.add_theme_constant_override("separation", 10)
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(center_vbox)

	var grid_lbl: Label = Label.new()
	grid_lbl.text = "── CRAFTING GRID ──"
	grid_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	grid_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
	center_vbox.add_child(grid_lbl)

	var grid_container: GridContainer = GridContainer.new()
	grid_container.columns = GRID_COLS
	grid_container.add_theme_constant_override("h_separation", 6)
	grid_container.add_theme_constant_override("v_separation", 6)
	center_vbox.add_child(grid_container)

	_slot_controls.clear()
	for i in range(GRID_COLS * GRID_ROWS):
		var slot := _make_slot(i)
		grid_container.add_child(slot)
		_slot_controls.append(slot)

	# Arrow
	var arrow_lbl: Label = Label.new()
	arrow_lbl.text = "⬇ MATCH RECIPE"
	arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	arrow_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	center_vbox.add_child(arrow_lbl)

	# Result panel
	_result_panel = PanelContainer.new()
	_result_panel.custom_minimum_size = Vector2(240, 70)
	var rp_st: StyleBoxFlat = StyleBoxFlat.new()
	rp_st.bg_color    = Color("#0d0520")
	rp_st.border_color = GameData.ACCENT_BLUE
	rp_st.set_border_width_all(2)
	rp_st.set_corner_radius_all(8)
	_result_panel.add_theme_stylebox_override("panel", rp_st)
	center_vbox.add_child(_result_panel)

	var result_hbox: HBoxContainer = HBoxContainer.new()
	result_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	result_hbox.add_theme_constant_override("separation", 8)
	result_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_panel.add_child(result_hbox)

	_result_emoji = Label.new()
	_result_emoji.text = "❓"
	_result_emoji.add_theme_font_size_override("font_size", GameData.scaled_font_size(28))
	result_hbox.add_child(_result_emoji)

	_result_lbl = Label.new()
	_result_lbl.text = "Fill the grid to discover a recipe"
	_result_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	_result_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
	_result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_hbox.add_child(_result_lbl)

	# Craft + Clear buttons
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	center_vbox.add_child(action_row)

	_craft_btn = Button.new()
	_craft_btn.text = "✨ CRAFT"
	_craft_btn.custom_minimum_size = Vector2(140, 40)
	_craft_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	_craft_btn.disabled = true
	_craft_btn.pressed.connect(_on_craft_pressed)
	action_row.add_child(_craft_btn)

	var clear_btn: Button = Button.new()
	clear_btn.text = "↺ CLEAR"
	clear_btn.custom_minimum_size = Vector2(90, 40)
	clear_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	clear_btn.pressed.connect(_clear_grid)
	action_row.add_child(clear_btn)

func _make_slot(idx: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = SLOT_SIZE
	var st := StyleBoxFlat.new()
	st.bg_color    = Color("#0d0a22")
	st.border_color = Color(GameData.ACCENT_BLUE, 0.4)
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	slot.add_theme_stylebox_override("panel", st)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(inner)

	var emoji_lbl := Label.new()
	emoji_lbl.name = "EmojiLbl"
	emoji_lbl.text = "+"
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(24))
	emoji_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.2))
	inner.add_child(emoji_lbl)

	var name_lbl := Label.new()
	name_lbl.name = "NameLbl"
	name_lbl.text = ""
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(8))
	name_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
	inner.add_child(name_lbl)

	# Click to place / remove
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func(): _on_slot_clicked(idx))
	slot.add_child(btn)

	return slot

# ══════════════════════════════════════════════════════════════════
# PANTRY PALETTE
# ══════════════════════════════════════════════════════════════════
func _build_palette() -> void:
	for ch in _pantry_grid.get_children(): ch.queue_free()
	_ingredient_btns.clear()

	# FIX: get_all_ingredients() takes no profile param — ingredients are global
	var pantry: Dictionary = Database.get_all_ingredients()

	# FIX: catalog is on IngredientData, not GameData
	for ing_id: String in IngredientData.INGREDIENTS.keys():
		var qty: int = int(pantry.get(ing_id, 0))
		var ing: Dictionary = IngredientData.INGREDIENTS[ing_id]
		var btn := _make_palette_btn(ing_id, ing, qty)
		_pantry_grid.add_child(btn)
		_ingredient_btns[ing_id] = btn

func _make_palette_btn(ing_id: String, ing: Dictionary, qty: int) -> Button:
	var rarity: String = ing.get("rarity","common")
	var rarity_col: Color = GameData.RARITY_COLORS.get(rarity, Color.WHITE) as Color

	var btn := Button.new()
	btn.text = "%s ×%d" % [ing.get("emoji","?"), qty]
	btn.disabled = (qty <= 0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size   = Vector2(0, 36)
	btn.toggle_mode = true
	btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	btn.add_theme_color_override("font_color", rarity_col if qty > 0 else Color(rarity_col, 0.3))

	var normal_st := StyleBoxFlat.new()
	normal_st.bg_color = Color(GameData.RARITY_BG.get(rarity, Color("#1a0a35")) as Color, 0.6)
	normal_st.border_color = Color(rarity_col, 0.4)
	normal_st.set_border_width_all(1)
	normal_st.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal_st)

	btn.pressed.connect(func():
		_selected_ingredient = ing_id if _selected_ingredient != ing_id else ""
		_update_palette_selection())

	return btn

func _update_palette_selection() -> void:
	for ing_id in _ingredient_btns:
		_ingredient_btns[ing_id].button_pressed = (ing_id == _selected_ingredient)

# ══════════════════════════════════════════════════════════════════
# GRID INTERACTION
# ══════════════════════════════════════════════════════════════════
func _on_slot_clicked(idx: int) -> void:
	if _selected_ingredient != "":
		_grid_slots[idx] = _selected_ingredient
	else:
		_grid_slots[idx] = null

	_update_slot_visuals()
	_check_recipe_match()

func _update_slot_visuals() -> void:
	for i in range(_slot_controls.size()):
		if not is_instance_valid(_slot_controls[i]): continue
		var slot: PanelContainer = _slot_controls[i] as PanelContainer
		var ing_id: Variant = _grid_slots[i]
		var emoji_lbl: Label = slot.get_node_or_null("VBoxContainer/EmojiLbl") as Label
		var name_lbl:  Label = slot.get_node_or_null("VBoxContainer/NameLbl") as Label
		var st := StyleBoxFlat.new()

		if ing_id != null:
			# FIX: IngredientData.INGREDIENTS, not IngredientData.INGREDIENTS
			var ing: Dictionary = IngredientData.INGREDIENTS.get(ing_id as String, {})
			var rarity: String  = ing.get("rarity","common")
			var rarity_col: Color = GameData.RARITY_COLORS.get(rarity, Color.WHITE) as Color
			if is_instance_valid(emoji_lbl):
				emoji_lbl.text = ing.get("emoji","?")
				emoji_lbl.add_theme_color_override("font_color", Color.WHITE)
			if is_instance_valid(name_lbl):
				name_lbl.text = ing.get("name","?")
			st.bg_color    = Color(GameData.RARITY_BG.get(rarity, Color("#1a0a35")) as Color, 0.8)
			st.border_color = rarity_col
			st.set_border_width_all(2)
		else:
			if is_instance_valid(emoji_lbl):
				emoji_lbl.text = "+"
				emoji_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.2))
			if is_instance_valid(name_lbl):
				name_lbl.text = ""
			st.bg_color    = Color("#0d0a22")
			st.border_color = Color(GameData.ACCENT_BLUE, 0.4)
			st.set_border_width_all(2)

		st.set_corner_radius_all(6)
		slot.add_theme_stylebox_override("panel", st)

func _clear_grid() -> void:
	_grid_slots.fill(null)
	_last_match = ""
	_selected_ingredient = ""
	_update_slot_visuals()
	_update_palette_selection()
	_update_result_panel("", false)

# ══════════════════════════════════════════════════════════════════
# RECIPE MATCHING  (GDD §9.4)
# ══════════════════════════════════════════════════════════════════
func _check_recipe_match() -> void:
	var grid_counts: Dictionary = {}
	for slot in _grid_slots:
		if slot != null:
			grid_counts[slot] = int(grid_counts.get(slot, 0)) + 1

	if grid_counts.is_empty():
		_update_result_panel("", false)
		return

	# FIX: IngredientData.SWEETS, not IngredientData.SWEETS
	for sweet_id: String in IngredientData.SWEETS.keys():
		var sweet: Dictionary = IngredientData.SWEETS[sweet_id]
		if _recipe_matches(sweet.get("recipe",[]), grid_counts):
			_last_match = sweet_id
			_update_result_panel(sweet_id, true)
			return

	_last_match = ""
	_update_result_panel("", false)

func _recipe_matches(recipe: Array, grid_counts: Dictionary) -> bool:
	var recipe_counts: Dictionary = {}
	for r in recipe:
		recipe_counts[r.id] = int(recipe_counts.get(r.id, 0)) + r.qty

	var total_grid: int = 0
	for v in grid_counts.values(): total_grid += int(v)
	var total_recipe: int = 0
	for v in recipe_counts.values(): total_recipe += int(v)
	if total_grid != total_recipe: return false

	for ing_id in recipe_counts:
		if int(grid_counts.get(ing_id, 0)) != int(recipe_counts[ing_id]):
			return false
	return true

func _update_result_panel(sweet_id: String, matched: bool) -> void:
	if not is_instance_valid(_result_panel): return
	var rp_st := StyleBoxFlat.new()

	if matched and sweet_id != "":
		# FIX: IngredientData.SWEETS, not IngredientData.SWEETS
		var sweet: Dictionary = IngredientData.SWEETS.get(sweet_id, {})
		var rarity: String = sweet.get("rarity","common")
		var rarity_col: Color = GameData.RARITY_COLORS.get(rarity, Color.WHITE) as Color
		rp_st.bg_color    = Color(GameData.RARITY_BG.get(rarity, Color("#1a0a35")) as Color, 0.9)
		rp_st.border_color = rarity_col
		rp_st.set_border_width_all(3)
		rp_st.set_corner_radius_all(8)
		_result_panel.add_theme_stylebox_override("panel", rp_st)

		# FIX: has_recipe → check get_discovered_recipes()
		var discovered: bool = sweet_id in Database.get_discovered_recipes()
		if discovered:
			_result_emoji.text = sweet.get("emoji","?")
			# FIX: sweet field is "desc" not "effect_desc"
			_result_lbl.text = "%s\n%s" % [sweet.get("name","?"), sweet.get("desc","")]
			_result_lbl.add_theme_color_override("font_color", rarity_col)
		else:
			_result_emoji.text = "❓"
			_result_lbl.text = "Unknown recipe — craft to discover!"
			_result_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
		_craft_btn.disabled = false
	else:
		rp_st.bg_color    = Color("#0d0520")
		rp_st.border_color = Color(GameData.ACCENT_BLUE, 0.3)
		rp_st.set_border_width_all(2)
		rp_st.set_corner_radius_all(8)
		_result_panel.add_theme_stylebox_override("panel", rp_st)
		_result_emoji.text = "❓"
		_result_lbl.text = "Fill the grid to discover a recipe"
		_result_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.4))
		_craft_btn.disabled = true

# ══════════════════════════════════════════════════════════════════
# CRAFTING
# ══════════════════════════════════════════════════════════════════
func _on_craft_pressed() -> void:
	if _last_match == "": return
	# FIX: IngredientData.SWEETS, not IngredientData.SWEETS
	var sweet: Dictionary = IngredientData.SWEETS.get(_last_match, {})

	# Check pantry has enough of each ingredient
	var recipe: Array = sweet.get("recipe",[])
	for r in recipe:
		# FIX: get_ingredient() takes only the key — no profile param
		var available: int = Database.get_ingredient(r.id)
		if available < r.qty:
			# FIX: IngredientData.INGREDIENTS, not IngredientData.INGREDIENTS
			_flash_craft_error("Not enough %s!" % IngredientData.INGREDIENTS.get(r.id, {}).get("name","?"))
			return

	# Spend ingredients
	for r in recipe:
		# FIX: use_ingredient() not spend_ingredient(), no profile param
		Database.use_ingredient(r.id, r.qty)

	# Craft the sweet
	# FIX: add_sweet() takes only (key, qty) — no profile param
	Database.add_sweet(_last_match, 1)

	# Discover recipe if new
	# FIX: discover_recipe() returns bool (true = first discovery)
	var was_new: bool = Database.discover_recipe(_last_match)
	if was_new:
		SignalBus.recipe_discovered.emit(_last_match)

	# Burst FX
	if has_node("/root/FXBus"):
		var rarity: String = sweet.get("rarity","common")
		var col: Color = GameData.RARITY_COLORS.get(rarity, Color.WHITE) as Color
		var pos: Vector2 = _craft_btn.get_global_rect().get_center()
		get_node("/root/FXBus").burst_sparkles(pos, 12, col)

	_clear_grid()
	SignalBus.ingredients_changed.emit()
	SignalBus.sweet_crafted.emit(_last_match)

	if was_new:
		_show_discovery_popup(_last_match, sweet)

func _flash_craft_error(msg: String) -> void:
	var orig: String = _craft_btn.text
	_craft_btn.text = msg
	await get_tree().create_timer(1.5).timeout
	if is_inside_tree(): _craft_btn.text = orig

func _show_discovery_popup(sweet_id: String, sweet: Dictionary) -> void:
	var cl := CanvasLayer.new(); cl.layer = 130; add_child(cl)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	cl.add_child(bg)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 160)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -170; panel.offset_right = 170
	panel.offset_top  = -80;  panel.offset_bottom = 80
	var rarity: String = sweet.get("rarity","common")
	var rarity_col: Color = GameData.RARITY_COLORS.get(rarity, Color.WHITE) as Color
	var st := StyleBoxFlat.new()
	st.bg_color    = Color(GameData.RARITY_BG.get(rarity, Color("#1a0a35")) as Color, 0.97)
	st.border_color = rarity_col
	st.set_border_width_all(3)
	st.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", st)
	cl.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	var new_lbl := Label.new()
	new_lbl.text = "✨ RECIPE DISCOVERED! ✨"
	new_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	new_lbl.add_theme_color_override("font_color", rarity_col)
	vbox.add_child(new_lbl)

	var em_lbl := Label.new()
	em_lbl.text = sweet.get("emoji","?")
	em_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	em_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(36))
	vbox.add_child(em_lbl)

	var name_lbl := Label.new()
	name_lbl.text = sweet.get("name","?")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	name_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	vbox.add_child(name_lbl)

	var dismiss_btn := Button.new()
	dismiss_btn.text = "▸ SWEET!"
	dismiss_btn.custom_minimum_size = Vector2(100, 32)
	dismiss_btn.pressed.connect(func(): cl.queue_free())
	vbox.add_child(dismiss_btn)

	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(cl): cl.queue_free()

# ══════════════════════════════════════════════════════════════════
# REFRESH
# ══════════════════════════════════════════════════════════════════
func _refresh() -> void:
	if not is_instance_valid(_pantry_grid): return
	_build_palette()
