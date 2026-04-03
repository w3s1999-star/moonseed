extends ShopScreenBase
class_name SweetmakerScreen

# @onready var _browse_popup: PanelContainer = $PopupLayer/BrowsePopup as PanelContainer  # Uncomment if needed
# @onready var _detail_popup: PanelContainer = $PopupLayer/DetailPopup as PanelContainer  # Uncomment if needed
@onready var _standardized_layout: StandardizedShopLayout = $StandardizedShopLayout as StandardizedShopLayout

const SHOP_ICON: Texture2D = preload("res://assets/ui/placeholders/icon_food.png")

const ACTION_LABELS: Array[String] = [
	"Browse Sweets",
	"Sell Chocolates",
	"Recipe Molds",
	"Special Orders",
	"Taste Test",
	"Leave",
]

const HOVER_LINES: Dictionary = {
	"Browse Sweets": "Wrapped warm. Best eaten with a secret.",
	"Sell Chocolates": "Trade sweets for moonpearls? Delicious.",
	"Recipe Molds": "Shapes make memories. Pick your favorite.",
	"Special Orders": "A request with a ribbon? I can do that.",
	"Taste Test": "One bite. Then tell me the truth.",
	"Leave": "Come back before the caramel sets.",
}


func _ready() -> void:
	super._ready()
	set_action_labels(ACTION_LABELS)
	set_button_dialogue(HOVER_LINES)
	_apply_room_layout()
	_apply_button_textures()
	_wire_action_buttons()


func _apply_room_layout() -> void:
	var icon_rect: TextureRect = $BackgroundRoot/RightMenuBoard/ShopHeader/ShopIcon as TextureRect
	if icon_rect != null:
		icon_rect.texture = SHOP_ICON

	var room_bg: TextureRect = $BackgroundRoot/LeftMerchantScene/RoomBackground as TextureRect
	if room_bg != null:
		room_bg.modulate = Color(1.08, 0.95, 1.00, 1.0)

	var merchant_sprite: TextureRect = $BackgroundRoot/LeftMerchantScene/MerchantSprite as TextureRect
	if merchant_sprite != null:
		merchant_sprite.offset_left = 86.0
		merchant_sprite.offset_top = 70.0
		merchant_sprite.offset_right = 330.0
		merchant_sprite.offset_bottom = 360.0

	var anchor: Control = $BackgroundRoot/LeftMerchantScene/DialoguePopupAnchor as Control
	if anchor != null:
		anchor.offset_left = 210.0
		anchor.offset_top = 34.0
		anchor.offset_right = 230.0
		anchor.offset_bottom = 54.0


func _apply_button_textures() -> void:
	var buttons := _get_action_buttons()
	for btn: ShopActionButton in buttons:
		_apply_sweet_button_style(btn)


func _apply_sweet_button_style(btn: ShopActionButton) -> void:
	var tex_normal: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_sweet_normal.png")
	var tex_hover: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_sweet_hover.png")
	var tex_pressed: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_sweet_pressed.png")
	var tex_disabled: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_sweet_disabled.png")
	
	var sb_normal := StyleBoxTexture.new()
	sb_normal.texture = tex_normal
	sb_normal.draw_center = true
	sb_normal.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb_normal.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	
	var sb_hover := StyleBoxTexture.new()
	sb_hover.texture = tex_hover
	sb_hover.draw_center = true
	sb_hover.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb_hover.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	
	var sb_pressed := StyleBoxTexture.new()
	sb_pressed.texture = tex_pressed
	sb_pressed.draw_center = true
	sb_pressed.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb_pressed.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	
	var sb_disabled := StyleBoxTexture.new()
	sb_disabled.texture = tex_disabled
	sb_disabled.draw_center = true
	sb_disabled.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb_disabled.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)


func _ensure_prop_rect(parent_node: Control, prop_name: String, pos: Vector2, size_px: Vector2, color: Color) -> void:
	var existing: Node = parent_node.get_node_or_null(prop_name)
	if existing != null:
		return

	var r := ColorRect.new()
	r.name = prop_name
	r.position = pos
	r.size = size_px
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_node.add_child(r)


func _wire_action_buttons() -> void:
	var list_node: Node = get_node_or_null("BackgroundRoot/RightMenuBoard/ButtonList")
	if list_node == null:
		return
	for child: Node in list_node.get_children():
		var btn := child as BaseButton
		if btn == null:
			continue
		var label := ""
		if child.get("label_text") != null:
			label = str(child.get("label_text"))
		if label == "":
			label = btn.text
		
		match label:
			"Browse Sweets":
				if not btn.pressed.is_connected(_on_browse_sweets_pressed):
					btn.pressed.connect(_on_browse_sweets_pressed)
			"Sell Chocolates":
				if not btn.pressed.is_connected(_on_sell_chocolates_pressed):
					btn.pressed.connect(_on_sell_chocolates_pressed)
			"Recipe Molds":
				if not btn.pressed.is_connected(_on_recipe_molds_pressed):
					btn.pressed.connect(_on_recipe_molds_pressed)
			"Special Orders":
				if not btn.pressed.is_connected(_on_special_orders_pressed):
					btn.pressed.connect(_on_special_orders_pressed)
			"Taste Test":
				if not btn.pressed.is_connected(_on_taste_test_pressed):
					btn.pressed.connect(_on_taste_test_pressed)
			"Leave":
				if not btn.pressed.is_connected(_on_leave_pressed):
					btn.pressed.connect(_on_leave_pressed)


func _on_browse_sweets_pressed() -> void:
	_setup_standardized_sweet_layout()

func _setup_standardized_sweet_layout() -> void:
	if _standardized_layout == null:
		print("DEBUG: Standardized layout not found!")
		return
	
	# Configure the layout for sweetmaker
	_standardized_layout.set_shop_name("Sugar Bat's Sweet Shop")
	_standardized_layout.set_currency_icon("✦")
	_standardized_layout.set_shop_icon(SHOP_ICON)
	
	# Set up categories for sweets
	var categories: Array[String] = ["All", "Consumables", "Utilities", "Tarot"]
	_standardized_layout.set_categories(categories)
	
	# Convert shop catalog items to standardized format
	var sweet_items: Array[Dictionary] = []
	for item in GameData.SHOP_CATALOG:
		if item.type in ["util", "pack", "tarot"]:
			var sweet_data: Dictionary = {
				"id": item.id,
				"name": item.name,
				"desc": item.desc,
				"cost": item.pearl_cost,
				"emoji": item.emoji,
				"category": item.type.capitalize(),
				"stats": "Rarity: " + item.rarity.capitalize()
			}
			sweet_items.append(sweet_data)
	
	_standardized_layout.set_items(sweet_items)
	
	# Connect signals
	_standardized_layout.item_selected.connect(_on_sweet_item_selected)
	_standardized_layout.item_purchased.connect(_on_sweet_purchased)
	_standardized_layout.back_to_bazaar_pressed.connect(_on_leave_pressed)
	
	# Show the layout and hide the old button list
	_standardized_layout.visible = true
	var right_board = get_node_or_null("BackgroundRoot/RightMenuBoard")
	if right_board:
		var btn_list_node := right_board.get_node_or_null("ButtonList")
		if btn_list_node:
			btn_list_node.visible = false
	
	# Show initial dialogue
	show_dialogue("Browse my collection of freshly wrapped treats.", merchant_name, null, 2.0)

func _on_sweet_item_selected(item: Dictionary) -> void:
	print("DEBUG: Sweet item selected: ", item.get("name", "Unknown"))
	
	# Show detailed description
	var detailed_desc: String = item.get("desc", "") + "\n\n" + item.get("stats", "")
	_standardized_layout._detail_description.text = detailed_desc

func _on_sweet_purchased(item: Dictionary) -> void:
	var item_id: String = item.get("id", "")
	if item_id == "":
		return
	
	print("DEBUG: Purchasing sweet: ", item_id)
	
	# Use the existing purchase logic
	var debug_buy: bool = Database.get_bool("debug_purchase_enabled", false)
	if not debug_buy and not Database.spend_moonpearls(item.get("cost", 0), GameData.current_profile):
		show_dialogue("Oh dear, you need more moonpearls for that treat.", merchant_name, null, 2.0)
		_standardized_layout.refresh_currency()
		return
	
	# Add to appropriate inventory based on type
	var item_type: String = item.get("category", "").to_lower()
	match item_type:
		"tarot":
			GameData.jokers_owned.append(item_id)
		"util":
			GameData.jokers_owned.append(item_id)
		"pack":
			GameData.jokers_owned.append(item_id)
		_:
			GameData.jokers_owned.append(item_id)
	
	show_dialogue("Freshly wrapped! Your " + item.get("name", "") + " is ready for adventure.", merchant_name, null, 3.0)
	# Refresh the layout to show updated status
	_setup_standardized_sweet_layout()


func _show_browse_sweets_popup() -> void:
	# Get the right menu board and replace its content
	var right_board = get_node("BackgroundRoot/RightMenuBoard")
	if right_board == null:
		return
	
	# Clear existing content
	for child in right_board.get_children():
		child.queue_free()
	
	# Create a panel with background first
	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(400, 600)
	panel.add_theme_color_override("panel", Color("#8B4513"))  # Solid brown background
	right_board.add_child(panel)
	
	# Create scroll container for the shop content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(380, 580)
	panel.add_child(scroll)
	
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(360, 0)
	scroll.add_child(root)

	# Add header
	var title := Label.new()
	title.text = "Sugar Bat's Sweet Shop"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	title.add_theme_color_override("font_color", Color("#ffffff"))
	root.add_child(title)

	var moonpearls := Database.get_moonpearls()
	var wallet_label := Label.new()
	wallet_label.text = "Your Moonpearls: " + str(moonpearls)
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wallet_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	wallet_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	root.add_child(wallet_label)
	
	# Add separator
	var top_separator := HSeparator.new()
	top_separator.add_theme_color_override("separator", GameData.SEPARATOR_COLOR)
	root.add_child(top_separator)

	# Get consumables and utility items from shop catalog
	var sweet_items: Array = GameData.SHOP_CATALOG.filter(func(item): return item.type in ["util", "pack", "tarot"])
	
	for item in sweet_items:
		var item_container := VBoxContainer.new()
		item_container.add_theme_constant_override("separation", 4)
		
		# Add background panel for each item
		var item_panel := Panel.new()
		item_panel.add_theme_color_override("panel", Color("#A0522D"))  # Lighter brown for items
		item_panel.custom_minimum_size = Vector2(340, 120)
		item_container.add_child(item_panel)
		
		var item_content := VBoxContainer.new()
		item_content.add_theme_constant_override("separation", 4)
		item_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_content.custom_minimum_size = Vector2(320, 100)
		item_panel.add_child(item_content)
		
		# Item header with emoji and name
		var header := HBoxContainer.new()
		item_content.add_child(header)
		
		var emoji_label := Label.new()
		emoji_label.text = item.emoji
		emoji_label.custom_minimum_size = Vector2(50, 0)
		emoji_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(24))
		header.add_child(emoji_label)
		
		var name_label := Label.new()
		name_label.text = item.name
		name_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", Color("#ffffff"))
		header.add_child(name_label)
		
		# Description
		var desc_label := Label.new()
		desc_label.text = item.desc
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		desc_label.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.8))
		desc_label.custom_minimum_size = Vector2(300, 40)
		item_content.add_child(desc_label)
		
		# Cost and rarity
		var info_label := Label.new()
		info_label.text = item.rarity.capitalize()
		info_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		info_label.add_theme_color_override("font_color", GameData.RARITY_COLORS.get(item.rarity, GameData.FG_COLOR))
		info_label.custom_minimum_size = Vector2(300, 30)
		item_content.add_child(info_label)
		
		# Buy button
		var status_container := HBoxContainer.new()
		status_container.mouse_filter = Control.MOUSE_FILTER_PASS
		item_content.add_child(status_container)
		
		var buy_btn := Button.new()
		buy_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		buy_btn.custom_minimum_size = Vector2(140, 36)
		var debug_buy: bool = Database.get_bool("debug_purchase_enabled", false)
		var can_afford: bool = debug_buy or moonpearls >= item.pearl_cost
		
		# Create custom button content with moonpearl texture and cost
		var btn_content := HBoxContainer.new()
		btn_content.add_theme_constant_override("separation", 8)
		btn_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn_content.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Create left spacer for consistent alignment
		var left_spacer := Control.new()
		left_spacer.custom_minimum_size = Vector2(8, 0)
		left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_content.add_child(left_spacer)
		
		# Load moonpearl texture
		var moonpearl_texture := preload("res://assets/textures/Moonpearl_spritesheet.png")
		
		# Select random frame 1-6 and create a sub-region texture
		var frame_width = moonpearl_texture.get_width() / 6.0
		var random_frame = randi() % 6
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = moonpearl_texture
		atlas_texture.region = Rect2(random_frame * frame_width, 0, frame_width, moonpearl_texture.get_height())
		
		# Create moonpearl icon with fixed size
		var moonpearl_rect := TextureRect.new()
		moonpearl_rect.texture = atlas_texture
		moonpearl_rect.custom_minimum_size = Vector2(20, 20)
		moonpearl_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		moonpearl_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		moonpearl_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		moonpearl_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		
		btn_content.add_child(moonpearl_rect)
		
		# Cost label with fixed width
		var cost_label := Label.new()
		cost_label.text = str(0 if debug_buy else item.pearl_cost)
		cost_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
		cost_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)  # Bright gold
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cost_label.custom_minimum_size = Vector2(40, 0)
		cost_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn_content.add_child(cost_label)
		
		# Create right spacer for consistent alignment
		var right_spacer := Control.new()
		right_spacer.custom_minimum_size = Vector2(8, 0)
		right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_content.add_child(right_spacer)
		
		# Set button to use custom content
		buy_btn.add_child(btn_content)
		
		if can_afford:
			buy_btn.pressed.connect(func() -> void:
				var debug_buy_local: bool = Database.get_bool("debug_purchase_enabled", false)
				if debug_buy_local:
					# Force grant without deducting
					match item.type:
						"tarot":
							GameData.jokers_owned.append(item.id)
						"util":
							GameData.jokers_owned.append(item.id)
						_:
							GameData.jokers_owned.append(item.id)
					show_dialogue("(Debug) Granted: " + item.name, merchant_name, null, 2.0)
				else:
					_handle_sweet_purchase(item)
			)
			buy_btn.add_theme_color_override("font_color", Color("#ffffff"))
		else:
			buy_btn.disabled = true
			btn_content.modulate = Color("#666666")
		
		buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status_container.add_child(buy_btn)
		
		# Add separator
		var separator := HSeparator.new()
		separator.add_theme_color_override("separator", GameData.SEPARATOR_COLOR)
		item_container.add_child(separator)
		
		root.add_child(item_container)

	# Add Exit Shop button at the bottom
	var exit_btn := Button.new()
	exit_btn.text = "🚪 Exit Shop"
	exit_btn.add_theme_color_override("font_color", Color("#ff6b6b"))
	exit_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	exit_btn.custom_minimum_size = Vector2(200, 40)
	exit_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	exit_btn.pressed.connect(_on_leave_pressed)
	root.add_child(exit_btn)


func _handle_sweet_purchase(item: Dictionary) -> void:
	var debug_buy: bool = Database.get_bool("debug_purchase_enabled", false)
	if not debug_buy and not Database.spend_moonpearls(item.pearl_cost, GameData.current_profile):
		show_dialogue("Oh dear, you need more moonpearls for that treat.", merchant_name, null, 2.0)
		return
	
	# Add to appropriate inventory based on type
	match item.type:
		"tarot":
			GameData.jokers_owned.append(item.id)
		"util":
			GameData.jokers_owned.append(item.id)
		_:
			GameData.jokers_owned.append(item.id)
	
	show_dialogue("Freshly wrapped! Your " + item.name + " is ready for adventure.", merchant_name, null, 3.0)


func _clear_popup(popup: Control) -> void:
	for c: Node in popup.get_children():
		c.queue_free()


func _on_sell_chocolates_pressed() -> void:
	show_dialogue("Ah, homemade chocolates! I can give you 2 moonpearls per piece. The darker the chocolate, the better the price.", merchant_name, null, 3.0)


func _on_recipe_molds_pressed() -> void:
	show_dialogue("I have molds in shapes of: crescent moons, sleeping foxes, and tiny teacups. Each mold costs 15 moonpearls and makes memories.", merchant_name, null, 3.0)


func _on_special_orders_pressed() -> void:
	show_dialogue("Special orders need three days and a secret ingredient. What sweetness are you dreaming of? I'll wrap it with a ribbon of starlight.", merchant_name, null, 3.0)


func _on_taste_test_pressed() -> void:
	show_dialogue("Close your eyes... This one tastes like childhood laughter. This one like first snowfall. Which truth did you taste?", merchant_name, null, 3.0)


func show_dev_popup() -> void:
	if not GameData.is_debug_mode():
		return

	# If already open, bring to front
	var existing := get_node_or_null("SweetmakerDevPopup")
	if existing != null:
		if existing.has_method("popup_centered"):
			existing.call_deferred("popup_centered")
		return

	var wnd := Popup.new()
	wnd.name = "SweetmakerDevPopup"
	wnd.custom_minimum_size = Vector2(360, 180)

	var vb := PanelContainer.new()
	vb.custom_minimum_size = Vector2(340, 160)
	wnd.add_child(vb)
	var content := VBoxContainer.new()
	content.margin_left = 8
	content.margin_top = 8
	content.margin_right = 8
	content.margin_bottom = 8
	vb.add_child(content)

	var cb := CheckBox.new()
	cb.text = "Enable Debug Purchasing (wrench)"
	cb.button_pressed = Database.get_bool("debug_purchase_enabled", false)
	cb.toggled.connect(func(pressed: bool) -> void:
		Database.save_setting("debug_purchase_enabled", pressed)
	)
	content.add_child(cb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	content.add_child(h)

	var add_money := Button.new()
	add_money.text = "Add 1000 Moonpearls"
	add_money.pressed.connect(func() -> void:
		Database.add_moonpearls(1000, GameData.current_profile)
	)
	h.add_child(add_money)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func() -> void: wnd.hide(); wnd.queue_free())
	content.add_child(close_btn)

	add_child(wnd)
	wnd.popup_centered()
