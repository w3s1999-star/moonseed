extends ShopScreenBase
class_name DiceCarverScreen

# @onready var _browse_popup: PanelContainer = $PopupLayer/BrowsePopup as PanelContainer  # Uncomment if needed
@onready var _detail_popup: PanelContainer = $PopupLayer/DetailPopup as PanelContainer
@onready var _modern_layout: ModernShopLayout = $ModernShopLayout as ModernShopLayout

var _current_category: String = "All"
var _current_mode: String = "buy"  # "buy" or "sell"

const SHOP_ICON: Texture2D = preload("res://assets/ui/placeholders/icon_die_d20.png")

const ACTION_LABELS: Array[String] = [
	"Browse Dice",
	"Upgrade Dice",
	"Polish Set",
	"Preview Roll Feel",
	"Leave",
]

const HOVER_LINES: Dictionary = {
	"Browse Dice": "Cut under last night's moon. Smooth as river stone.",
	"Upgrade Dice": "A sharper edge gives a clearer fate.",
	"Polish Set": "Bring them here. I'll make them sing.",
	"Preview Roll Feel": "Listen to the tumble. That's where the truth lives.",
	"Leave": "May your next roll land kindly.",
}


func _ready() -> void:
	super._ready()
	set_action_labels(ACTION_LABELS)
	set_button_dialogue(HOVER_LINES)
	_apply_room_layout()
	_apply_button_textures()
	# Use a more robust approach - override the base class button wiring
	call_deferred("_wire_all_buttons")
	# Add debug functionality
	call_deferred("_setup_debug_mode")


func _apply_room_layout() -> void:
	var icon_rect: TextureRect = $BackgroundRoot/RightMenuBoard/ShopHeader/ShopIcon as TextureRect
	if icon_rect != null:
		icon_rect.texture = SHOP_ICON

	var room_bg: TextureRect = $BackgroundRoot/LeftMerchantScene/RoomBackground as TextureRect
	if room_bg != null:
		room_bg.modulate = Color(0.95, 0.98, 1.10, 1.0)

	var merchant_sprite: TextureRect = $BackgroundRoot/LeftMerchantScene/MerchantSprite as TextureRect
	if merchant_sprite != null:
		merchant_sprite.offset_left = 86.0
		merchant_sprite.offset_top = 84.0
		merchant_sprite.offset_right = 340.0
		merchant_sprite.offset_bottom = 360.0

	var anchor: Control = $BackgroundRoot/LeftMerchantScene/DialoguePopupAnchor as Control
	if anchor != null:
		anchor.offset_left = 210.0
		anchor.offset_top = 34.0
		anchor.offset_right = 230.0
		anchor.offset_bottom = 54.0


func _on_leave_pressed() -> void:
	# When leaving shop, ensure persistent header/buttonlist are restored before closing.
	var right_board = get_node_or_null("BackgroundRoot/RightMenuBoard")
	if right_board:
		var header_node := right_board.get_node_or_null("ShopHeader")
		var btn_list_node := right_board.get_node_or_null("ButtonList")
		if header_node: header_node.visible = true
		if btn_list_node: btn_list_node.visible = true
	# Call base implementation to actually close/hide
	super._on_leave_pressed()


func _apply_button_textures() -> void:
	var buttons := _get_action_buttons()
	for btn: ShopActionButton in buttons:
		_apply_dice_button_style(btn)


func _apply_dice_button_style(btn: ShopActionButton) -> void:
	var tex_normal: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_dice_normal.png")
	var tex_hover: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_dice_hover.png")
	var tex_pressed: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_dice_pressed.png")
	var tex_disabled: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_dice_disabled.png")
	
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


func _wire_all_buttons() -> void:
	var list_node: Node = get_node_or_null("BackgroundRoot/RightMenuBoard/ButtonList")
	if list_node == null:
		print("DEBUG: ButtonList node not found!")
		return
	
	print("DEBUG: Wiring all buttons in ButtonList...")
	
	# Get all ShopActionButton children
	var buttons := _get_action_buttons()
	if buttons.size() == 0:
		print("DEBUG: No ShopActionButton children found!")
		return
	
	print("DEBUG: Found ", buttons.size(), " ShopActionButton children")
	
	# Wire each button to our custom handler
	for btn: ShopActionButton in buttons:
		var label := btn.label_text
		print("DEBUG: Wiring button: '", label, "' (button name: ", btn.name, ")")
		
		# Disconnect any existing connections to avoid duplicates
		if btn.pressed.is_connected(_on_any_button_pressed):
			btn.pressed.disconnect(_on_any_button_pressed)
		
		# Connect our universal button handler
		btn.pressed.connect(_on_any_button_pressed.bind(label))
		
		print("DEBUG: Connected button: ", label)


func _apply_moonseed_button_style(btn: Button) -> void:
	# Apply Moonseed color theme: purple accent with white text and rounded corners
	var accent := Color(0.64, 0.54, 1.0, 1.0)
	var bg := Color(0.24, 0.17, 0.40, 1.0)
	var hover_bg := Color(0.36, 0.28, 0.72, 1.0)
	var pressed_bg := Color(0.18, 0.12, 0.32, 1.0)

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = bg
	sb_normal.set_border_width_all(2)
	sb_normal.border_color = accent
	sb_normal.set_corner_radius_all(8)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = hover_bg
	sb_hover.set_border_width_all(2)
	sb_hover.border_color = accent
	sb_hover.set_corner_radius_all(8)

	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = pressed_bg
	sb_pressed.set_border_width_all(2)
	sb_pressed.border_color = accent
	sb_pressed.set_corner_radius_all(8)

	var sb_disabled := StyleBoxFlat.new()
	sb_disabled.bg_color = bg.darkened(0.3)
	sb_disabled.set_border_width_all(2)
	sb_disabled.border_color = accent.darkened(0.2)
	sb_disabled.set_corner_radius_all(8)

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))


func _show_mode_tabs(header: HBoxContainer) -> void:
	# Create or update Buy/Sell mode buttons in the header
	var existing := header.get_node_or_null("ModeTabs")
	if existing:
		existing.queue_free()

	var mode_box := HBoxContainer.new()
	mode_box.name = "ModeTabs"
	mode_box.size_flags_horizontal = Control.SIZE_FILL
	mode_box.add_theme_constant_override("separation", 6)
	header.add_child(mode_box)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	_apply_moonseed_button_style(buy_btn)
	buy_btn.pressed.connect(func():
		_current_mode = "buy"
		_populate_items_for_category(_current_category, _current_mode)
	)
	mode_box.add_child(buy_btn)

	var sell_btn := Button.new()
	sell_btn.text = "Sell"
	_apply_moonseed_button_style(sell_btn)
	# Disable sell if category has no sellable items
	sell_btn.disabled = not _category_has_sellable_items(_current_category)
	sell_btn.pressed.connect(func():
		_current_mode = "sell"
		_populate_items_for_category(_current_category, _current_mode)
	)
	mode_box.add_child(sell_btn)


func _category_has_sellable_items(category: String) -> bool:
	var inv: Dictionary = get_node("/root/Database").get_inventory()
	for dice_type in GameData.DICE_CARVER_SHOP_ITEMS.keys():
		if category != "All" and dice_type != category:
			continue
		# parse sides
		var sides := 6
		if dice_type.length() > 1 and dice_type[0] == 'd':
			var nstr: String = dice_type.substr(1)
			if nstr.is_valid_int():
				sides = int(nstr)
		var key := str(sides)
		if int(inv.get(key, 0)) > 0:
			return true
	return false


func _populate_items_for_category(category: String, mode: String, grid: GridContainer = null) -> void:
	# Resolve grid if not provided
	if grid == null:
		grid = get_node_or_null("BackgroundRoot/RightMenuBoard/DiceShopPanel/DiceShopRoot/ItemsScroll/ItemsGrid") as GridContainer
	if grid == null:
		# nothing to populate
		return

	# Clear existing
	for c in grid.get_children():
		c.queue_free()

	var inv: Dictionary = get_node("/root/Database").get_inventory()

	for dice_type in GameData.DICE_CARVER_SHOP_ITEMS.keys():
		if category != "All" and dice_type != category:
			continue

		var shop_item = GameData.DICE_CARVER_SHOP_ITEMS[dice_type]
		var name: String = shop_item.get("name", dice_type) if shop_item is Dictionary else str(shop_item)
		var cost: int = int(shop_item.get("cost", 0)) if shop_item is Dictionary else 0

		var sides := 6
		if dice_type.length() > 1 and dice_type[0] == 'd':
			var nstr: String = dice_type.substr(1)
			if nstr.is_valid_int():
				sides = int(nstr)

		if mode == "sell":
			var inv_count: int = int(inv.get(str(sides), 0))
			if inv_count <= 0:
				continue

		# Build a rich panel card matching the provided styled example
		var panel_card := Panel.new()
		panel_card.custom_minimum_size = Vector2(220, 260)
		var sb := StyleBoxFlat.new()
		sb.bg_color = GameData.CARD_BG
		sb.set_border_width_all(2)
		sb.border_color = GameData.CARD_HL
		sb.set_corner_radius_all(8)
		panel_card.add_theme_stylebox_override("panel", sb)

		var inner := VBoxContainer.new()
		inner.name = "Inner"
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inner.add_theme_constant_override("separation", 6)
		panel_card.add_child(inner)

		# Header/title area (framed)
		var header_box := VBoxContainer.new()
		header_box.custom_minimum_size = Vector2(0, 38)
		header_box.add_theme_constant_override("separation", 2)
		inner.add_child(header_box)

		var title_lbl := Label.new()
		title_lbl.text = name
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
		title_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
		header_box.add_child(title_lbl)

		# Description / effect area
		var desc_box := RichTextLabel.new()
		desc_box.bbcode_enabled = false
		desc_box.scroll_active = false
		# Ensure full text visible by default; avoid percent_visible assignment which may be typed differently across Godot versions
		desc_box.custom_minimum_size = Vector2(0, 100)
		var desc_text: String = ""
		if shop_item is Dictionary:
			desc_text = str(shop_item.get("description", ""))
			if desc_text == "":
				desc_text = str(shop_item.get("desc", ""))
		desc_box.text = desc_text
		desc_box.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
		inner.add_child(desc_box)

		# Divider
		var div := ColorRect.new()
		div.color = Color(0,0,0,0)
		div.custom_minimum_size = Vector2(0, 6)
		inner.add_child(div)

		# Cost row
		var cost_row := HBoxContainer.new()
		cost_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cost_row.add_theme_constant_override("separation", 8)
		inner.add_child(cost_row)

		var cost_lbl := Label.new()
		cost_lbl.text = "Cost: " + str(cost)
		cost_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
		cost_row.add_child(cost_lbl)

		var cost_icon := TextureRect.new()
		cost_icon.texture = SHOP_ICON
		cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cost_icon.custom_minimum_size = Vector2(24, 24)
		cost_row.add_child(cost_icon)

		# Action buttons area (large primary button, secondary preview)
		var actions := VBoxContainer.new()
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_theme_constant_override("separation", 6)
		inner.add_child(actions)

		# Primary Buy button (large green)
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy_btn.custom_minimum_size = Vector2(0, 42)
		# custom green style
		var sb_buy := StyleBoxFlat.new()
		sb_buy.bg_color = Color(0.12, 0.54, 0.12, 1.0)
		sb_buy.set_border_width_all(2)
		sb_buy.border_color = Color(0.8, 0.95, 0.6, 1.0)
		sb_buy.set_corner_radius_all(6)
		buy_btn.add_theme_stylebox_override("normal", sb_buy)
		buy_btn.add_theme_color_override("font_color", Color.WHITE)
		buy_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
		buy_btn.pressed.connect(func(dt=dice_type, s=shop_item):
			if GameData.purchase_dice(dt, 1):
				show_dialogue("Purchased " + (s.get("name", dt) if s is Dictionary else dt) + ".", merchant_name, null, 2.0)
				_populate_items_for_category(category, mode, grid)
			else:
				show_dialogue("Unable to purchase " + dt + ".", merchant_name, null, 2.0)
		)
		actions.add_child(buy_btn)

		# Secondary HBox for Preview and Sell (small)
		var secondary := HBoxContainer.new()
		secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		secondary.add_theme_constant_override("separation", 8)
		actions.add_child(secondary)

		var preview_btn := Button.new()
		preview_btn.text = "Preview Roll"
		_apply_moonseed_button_style(preview_btn)
		preview_btn.pressed.connect(func(dt=dice_type):
			_show_dice_detail_popup(dt)
		)
		secondary.add_child(preview_btn)

		var inv_count2: int = int(inv.get(str(sides), 0))
		var sell_btn := Button.new()
		sell_btn.text = "Sell"
		_apply_moonseed_button_style(sell_btn)
		sell_btn.disabled = inv_count2 <= 0
		var sell_price: int = max(1, int(cost / 2))
		sell_btn.pressed.connect(func(dt=dice_type, sd=sell_price, s=sides):
			_perform_sell(dt, s, sd)
		)
		secondary.add_child(sell_btn)

		grid.add_child(panel_card)


func _perform_sell(dice_type: String, sides: int, price: int) -> void:
	# Decrement physical dice and award moonpearls
	Database.add_moonpearls(price, GameData.current_profile)
	Database.add_dice(sides, -1)
	# adjust runtime satchel if present
	if GameData.dice_satchel.has(sides):
		GameData.dice_satchel[sides] = max(0, GameData.dice_satchel[sides] - 1)
	show_dialogue("Sold " + dice_type + " for " + str(price) + " ✦", merchant_name, null, 2.0)
	# Refresh UI
	_populate_items_for_category(_current_category, _current_mode)

func _on_any_button_pressed(button_label: String) -> void:
	print("DEBUG: Button pressed: ", button_label)
	
	match button_label:
		"Browse Dice":
			print("DEBUG: Opening browse dice popup...")
			_show_browse_dice_popup()
		"Upgrade Dice":
			print("DEBUG: Upgrade dice not implemented yet")
			show_dialogue("Dice upgrades coming soon!", merchant_name, null, 2.0)
		"Polish Set":
			print("DEBUG: Polish set not implemented yet")
			show_dialogue("Dice polishing coming soon!", merchant_name, null, 2.0)
		"Preview Roll Feel":
			print("DEBUG: Preview roll feel not implemented yet")
			show_dialogue("Roll preview coming soon!", merchant_name, null, 2.0)
		"Leave":
			print("DEBUG: Leaving shop...")
			_on_leave_pressed()
		_:
			print("DEBUG: Unknown button: ", button_label)


func _show_browse_dice_popup() -> void:
	print("DEBUG: _show_browse_dice_popup called - using modern layout")
	
	# Use the modern layout instead of the old popup
	_setup_modern_dice_layout()

func _setup_modern_dice_layout() -> void:
	# Programmatic fallback shop UI: build a simple, reliable layout directly
	var right_board = get_node_or_null("BackgroundRoot/RightMenuBoard")
	if right_board == null:
		print("DEBUG: RightMenuBoard not found; cannot show dice shop.")
		return

	# Clear existing content in right board
	for child in right_board.get_children():
		child.queue_free()

	var panel := Panel.new()
	panel.name = "DiceShopPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(420, 520)
	right_board.add_child(panel)

	var root := VBoxContainer.new()
	root.name = "DiceShopRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	# Header
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title := Label.new()
	title.text = "Dice Carver"
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	header.add_child(title)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	_apply_moonseed_button_style(refresh_btn)
	refresh_btn.pressed.connect(_setup_modern_dice_layout)
	header.add_child(refresh_btn)

	# Categories column (vertical alignment)
	var cat_row := VBoxContainer.new()
	cat_row.name = "CatRow"
	cat_row.add_theme_constant_override("separation", 6)
	cat_row.size_flags_horizontal = Control.SIZE_FILL
	cat_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cat_row.custom_minimum_size = Vector2(120, 0)
	root.add_child(cat_row)

	var categories: Array[String] = ["All", "d4", "d6", "d8", "d10", "d12", "d20"]
	for c in categories:
		var cb := Button.new()
		cb.text = c
		_apply_moonseed_button_style(cb)
		cb.pressed.connect(func(cat=c):
			_current_category = cat
			_current_mode = "buy"
			_show_mode_tabs(header)
			_populate_items_for_category(cat, _current_mode)
		)
		cat_row.add_child(cb)

	# Items scroll + grid
	var scroll := ScrollContainer.new()
	scroll.name = "ItemsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "ItemsGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size = Vector2(360, 400)
	scroll.add_child(grid)

	# Populate items
	# Initially populate current category (default All)
	_populate_items_for_category(_current_category, _current_mode, grid)
	# Footer: back button
	var footer := HBoxContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_constant_override("separation", 8)
	root.add_child(footer)

	var back := Button.new()
	back.text = "Back to Bazaar"
	_apply_moonseed_button_style(back)
	back.pressed.connect(_on_leave_pressed)
	footer.add_child(back)

	# Hide original ButtonList if present
	var btn_list_node := right_board.get_node_or_null("ButtonList")
	if btn_list_node:
		btn_list_node.visible = false

	show_dialogue("Browse my collection of hand-carved dice.", merchant_name, null, 2.0)

func _on_dice_item_selected(item: Dictionary) -> void:
	print("DEBUG: Dice item selected: ", item.get("name", "Unknown"))
	
	# Show detailed description
	var detailed_desc: String = item.get("desc", "") + "\n\n" + item.get("stats", "")
	_modern_layout._detail_description.text = detailed_desc

func _on_dice_purchased(item: Dictionary) -> void:
	var dice_type = item.get("id", "")
	if dice_type == "":
		return
	
	print("DEBUG: Purchasing dice: ", dice_type)
	
	# Use the existing purchase logic
	if GameData.purchase_dice(dice_type, 1):
		show_dialogue("Excellent choice! Your " + item.get("name", "") + " is ready.", merchant_name, null, 3.0)
		# Refresh the layout to show updated status
		_setup_modern_dice_layout()
	else:
		show_dialogue("You cannot unlock this die yet. Check the requirements or funds.", merchant_name, null, 2.0)
		# Refresh currency display
		_modern_layout.refresh_currency()

func _on_category_changed(category: String) -> void:
	print("DEBUG: Category changed to: ", category)
	# Update stats when category changes
	_modern_layout.refresh_stats()
	# Ensure UI refresh for current selection
	_current_category = category
	_populate_items_for_category(_current_category, _current_mode, get_node_or_null("BackgroundRoot/RightMenuBoard/DiceShopPanel/ DiceShopRoot/ItemsScroll/ItemsGrid"))

func _open_shop_tab() -> void:
	print("DEBUG: Opening Shop Tab from Dice Carver")
	
	# Close the current dice carver shop overlay
	var parent = get_parent()
	while parent != null:
		if parent.name == "ShopOverlay":
			parent.queue_free()
			break
		parent = parent.get_parent()
	
	# Emit signal to open the Shop Tab
	if has_node("/root/SignalBus"):
		SignalBus.vendor_opened.emit("shop_tab")
	else:
		print("DEBUG: SignalBus not found, trying direct navigation")
		# Fallback: try to navigate to Shop Tab directly
		_try_direct_shop_navigation()

func _try_direct_shop_navigation() -> void:
	# Try to find the main UI and switch to Shop Tab
	var main_ui = get_tree().get_root().find_child("Main", true, false)
	if main_ui:
		var tabs_container = main_ui.find_child("TabsContainer", true, false)
		if tabs_container:
			# Find the Shop Tab and switch to it
			for child in tabs_container.get_children():
				if child.name == "ShopTab":
					tabs_container.current_tab = tabs_container.get_tab_idx_from_control(child)
					break




func _handle_dice_purchase_async(dice_type: String, buy_btn: Button, parent_board: Control, qty: int, btn_content: HBoxContainer) -> void:
	# Use a timer to defer processing and prevent UI freeze
	await get_tree().process_frame
	_handle_dice_purchase(dice_type, buy_btn, parent_board, qty)
	
	# Restore button state after processing
	if is_instance_valid(buy_btn):
		buy_btn.disabled = false
		# Restore button content modulation
		if is_instance_valid(btn_content):
			btn_content.modulate = Color.WHITE


func _handle_dice_purchase(dice_type: String, buy_btn: Button = null, parent_board: Control = null, qty: int = 1) -> void:
	print("DEBUG: _handle_dice_purchase called for ", dice_type)

	var shop_item = GameData.DICE_CARVER_SHOP_ITEMS[dice_type]
	print("DEBUG: Shop item cost: ", shop_item.cost)
	print("DEBUG: Can unlock/purchase: ", GameData.can_unlock_dice(dice_type))

	# Use the new central purchase helper which also updates satchel counts
	if GameData.purchase_dice(dice_type, qty):
		print("DEBUG: Successfully purchased ", dice_type, " qty=", qty)
		show_dialogue("Excellent choice! Your " + shop_item.name + " is ready.", merchant_name, null, 3.0)
		
		# Enhanced visual feedback with Moonseed styling
		if is_instance_valid(buy_btn) and is_instance_valid(parent_board):
			# Create floating "BOUGHT!" text with Moonseed colors
			var lbl := Label.new()
			lbl.text = "BOUGHT!"
			lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
			lbl.add_theme_color_override("font_color", Color(0.64, 0.54, 1.0, 1.0))  # Moonseed turquoise
			lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.6, 1.0, 0.5))
			lbl.add_theme_constant_override("outline_size", 2)
			parent_board.add_child(lbl)
			
			# Compute position relative to parent_board
			var global_btn_pos: Vector2 = buy_btn.get_global_position()
			var global_parent_pos: Vector2 = parent_board.get_global_position()
			var local_pos: Vector2 = global_btn_pos - global_parent_pos + Vector2(0, -20)
			lbl.position = local_pos
			
			# Enhanced animation with scale and rotation
			var tw := lbl.create_tween()
			tw.tween_property(lbl, "position:y", lbl.position.y - 40, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.finished.connect(func(): lbl.queue_free())
			
			# Add button pop effect
			if is_instance_valid(buy_btn):
				var btn_tw := buy_btn.create_tween()
				btn_tw.tween_property(buy_btn, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				btn_tw.tween_property(buy_btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# Add juice effects for extra polish
		if is_instance_valid(parent_board):
			Juice.add_pop_effect(parent_board)
			Juice.add_shake_effect(parent_board)
		
		# Refresh the shop display to show updated status/quantities
		_show_browse_dice_popup()
		# Restore header/buttonlist visibility in case browse replaced them
		var header_node := parent_board.get_node_or_null("ShopHeader") if parent_board else null
		var btn_list_node := parent_board.get_node_or_null("ButtonList") if parent_board else null
		if header_node:
			header_node.visible = true
		if btn_list_node:
			btn_list_node.visible = true
	else:
		print("DEBUG: Failed to purchase ", dice_type)
		show_dialogue("You cannot unlock this die yet. Check the requirements or funds.", merchant_name, null, 2.0)
		
		# Visual feedback for failed purchase
		if is_instance_valid(buy_btn):
			var btn_tw := buy_btn.create_tween()
			btn_tw.tween_property(buy_btn, "scale", Vector2(0.9, 0.9), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			btn_tw.tween_property(buy_btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _show_dice_detail_popup(dice_type: String) -> void:
	if _detail_popup == null:
		return
	_clear_popup(_detail_popup)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_detail_popup.add_child(root)

	var title := Label.new()
	title.text = dice_type + " Details"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	root.add_child(title)

	var desc := Label.new()
	desc.text = "A beautifully crafted " + dice_type + " die.\nPerfectly balanced for fair rolls.\nCrafted under the last full moon."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(desc)

	var price := Label.new()
	price.text = "Price: " + str(10 + randi() % 50) + " moonpearls"
	root.add_child(price)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.pressed.connect(func() -> void:
		_detail_popup.visible = false
		show_dialogue("Thank you for your purchase!", merchant_name, null, 2.0)
	)
	row.add_child(buy_btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _detail_popup.visible = false)
	row.add_child(cancel)

	_detail_popup.visible = true


func _setup_debug_mode() -> void:
	# Add debug functionality - press F1 to toggle debug panel
	set_process_input(true)
	print("DEBUG: Debug mode enabled - press F1 for debug panel")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			_toggle_debug_panel()


func _toggle_debug_panel() -> void:
	# Get or create debug panel
	var debug_panel = get_node_or_null("DebugPanel")
	if debug_panel != null:
		debug_panel.queue_free()
		print("DEBUG: Debug panel closed")
		return
	
	# Create debug panel
	debug_panel = Panel.new()
	debug_panel.name = "DebugPanel"
	debug_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_panel.add_theme_color_override("panel", Color("#1a1a1a"))
	add_child(debug_panel)
	
	var container := VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("separation", 10)
	debug_panel.add_child(container)
	
	# Title
	var title := Label.new()
	title.text = "DEBUG PANEL - DICE CARVER"
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	title.add_theme_color_override("font_color", Color("#ffff00"))
	container.add_child(title)
	
	# Moonpearls controls
	var mp_container := HBoxContainer.new()
	container.add_child(mp_container)
	
	var mp_label := Label.new()
	mp_label.text = "Moonpearls: "
	mp_label.add_theme_color_override("font_color", Color("#ffffff"))
	mp_container.add_child(mp_label)
	
	var mp_value := Label.new()
	mp_value.text = str(Database.get_moonpearls(GameData.current_profile))
	mp_value.add_theme_color_override("font_color", Color("#00ff00"))
	mp_container.add_child(mp_value)
	
	var add_mp_btn := Button.new()
	add_mp_btn.text = "+1000"
	add_mp_btn.pressed.connect(func(): 
		Database.add_moonpearls(1000, GameData.current_profile)
		mp_value.text = str(Database.get_moonpearls(GameData.current_profile))
	)
	mp_container.add_child(add_mp_btn)
	
	# Dice controls
	var dice_title := Label.new()
	dice_title.text = "Dice Controls:"
	dice_title.add_theme_color_override("font_color", Color("#ffffff"))
	container.add_child(dice_title)
	
	for dt in GameData.DICE_CARVER_SHOP_ITEMS:
		var dice_container := HBoxContainer.new()
		container.add_child(dice_container)
		
		var dice_label := Label.new()
		dice_label.text = dt + ":"
		dice_label.custom_minimum_size = Vector2(80, 0)
		dice_label.add_theme_color_override("font_color", Color("#ffffff"))
		dice_container.add_child(dice_label)
		
		var status_label := Label.new()
		status_label.custom_minimum_size = Vector2(60, 0)
		var unlocked_state: bool = GameData.is_dice_unlocked(dt)
		var can_unlock_state: bool = GameData.can_unlock_dice(dt)
		if unlocked_state:
			status_label.text = "✅"
			status_label.add_theme_color_override("font_color", Color("#00ff00"))
		elif can_unlock_state:
			status_label.text = "🔓"
			status_label.add_theme_color_override("font_color", Color("#00ff00"))
		else:
			status_label.text = "🔒"
			status_label.add_theme_color_override("font_color", Color("#ff0000"))
		dice_container.add_child(status_label)
		
		var unlock_btn := Button.new()
		unlock_btn.text = "🗝"
		unlock_btn.disabled = not can_unlock_state and not unlocked_state
		unlock_btn.pressed.connect(func():
			_debug_unlock_dice(dt)
			status_label.text = "✅"
			status_label.add_theme_color_override("font_color", Color("#00ff00"))
		)
		dice_container.add_child(unlock_btn)
		
		var lock_btn := Button.new()
		lock_btn.text = "🔒"
		lock_btn.pressed.connect(func():
			_debug_lock_dice(dt)
			status_label.text = "🔒"
			status_label.add_theme_color_override("font_color", Color("#ff0000"))
		)
		dice_container.add_child(lock_btn)
	
	# Refresh button
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Shop Display"
	refresh_btn.pressed.connect(func():
		_show_browse_dice_popup()
	)
	container.add_child(refresh_btn)
	
	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close Debug Panel (F1)"
	close_btn.pressed.connect(_toggle_debug_panel)
	container.add_child(close_btn)
	
	print("DEBUG: Debug panel opened")

func refresh_display() -> void:
	print("DEBUG: DiceCarverScreen.refresh_display called")
	# Refresh the shop display to show updated dice states
	_show_browse_dice_popup()


func _debug_unlock_dice(dice_type: String) -> void:
	print("DEBUG: Force unlocking ", dice_type)
	
	# Directly add to dice inventory
	if not GameData.dice_inventory.has(dice_type):
		GameData.dice_inventory[dice_type] = {
			"unlocked_at": Time.get_unix_time_from_system(),
			"uses": 0
		}
		Database.save_dice_inventory(GameData.dice_inventory)
		print("DEBUG: ", dice_type, " unlocked")


func _debug_lock_dice(dice_type: String) -> void:
	print("DEBUG: Force locking ", dice_type)
	
	# Directly remove from dice inventory
	if GameData.dice_inventory.has(dice_type):
		GameData.dice_inventory.erase(dice_type)
		Database.save_dice_inventory(GameData.dice_inventory)
		print("DEBUG: ", dice_type, " locked")


func _clear_popup(popup: Control) -> void:
	for c: Node in popup.get_children():
		c.queue_free()
