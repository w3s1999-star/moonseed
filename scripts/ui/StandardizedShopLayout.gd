extends Control
class_name StandardizedShopLayout

# Standardized shop layout component that can be used across all shop screens
# Implements the requested layout:
# ┌──────────────────────────────────────────────┐
# │ [Shop Name]        [Currency: Moonpearls ✦] │
# ├──────────────────────────────────────────────┤
# │                                              │
# │  [ Item Grid / Browsing Area ]                │
# │                                              │
# │                                              │
# ├───────────────┬──────────────────────────────┤
# │ [ Categories ]│ [ Item Detail Panel ]        │
# │               │                              │
# │ - All         │ Name                         │
# │ - Type A      │ Description                  │
# │ - Type B      │ Stats / Effects              │
# │ - Type C      │                              │
# │               │ Cost                         │
# │               │ [Buy] / [Equip]              │
# │               │                              │
# ├──────────────────────────────────────────────┤
# │ [Back to Bazaar]                             │
# └──────────────────────────────────────────────┘

@export var shop_name: String = "Shop Name"
@export var currency_icon: String = "✦"
@export var shop_icon: Texture2D = null

# Signals
signal item_selected(item_data: Dictionary)
signal item_purchased(item_data: Dictionary)
signal category_changed(category: String)
signal back_to_bazaar_pressed()

# UI References (resolved after instancing)
var _header_container: HBoxContainer = null
var _shop_name_label: Label = null
var _currency_label: Label = null
var _shop_icon_texture: TextureRect = null

var _main_content: HBoxContainer = null
var _categories_container: VBoxContainer = null
var _categories_scroll: ScrollContainer = null
var _categories_list: VBoxContainer = null

var _items_container: VBoxContainer = null
var _items_scroll: ScrollContainer = null
var _items_grid: GridContainer = null

var _detail_container: VBoxContainer = null
var _detail_scroll: ScrollContainer = null
var _detail_content: VBoxContainer = null

var _detail_name: Label = null
var _detail_description: Label = null
var _detail_stats: Label = null
var _detail_cost: Label = null
var _buy_button: Button = null

var _footer_container: HBoxContainer = null
var _back_button: Button = null

# Internal state
var _current_categories: Array[String] = []
var _current_items: Array[Dictionary] = []
var _selected_category: String = "All"
var _selected_item: Dictionary = {}
var _is_item_selected: bool = false

func _ready() -> void:
	call_deferred("_deferred_init")

func _deferred_init() -> void:
	_resolve_nodes()
	_setup_ui()
	_refresh_currency()
	_refresh_categories()
	_refresh_items()

func _resolve_nodes() -> void:
	# Header
	_header_container = get_node_or_null("HeaderContainer")
	_shop_name_label = get_node_or_null("HeaderContainer/ShopNameLabel")
	_currency_label = get_node_or_null("HeaderContainer/CurrencyLabel")
	_shop_icon_texture = get_node_or_null("HeaderContainer/ShopIcon")

	# Main content
	_main_content = get_node_or_null("MainContent")
	_categories_container = get_node_or_null("MainContent/CategoriesContainer")
	_categories_scroll = get_node_or_null("MainContent/CategoriesContainer/CategoriesScroll")
	_categories_list = get_node_or_null("MainContent/CategoriesContainer/CategoriesScroll/CategoriesList")

	_items_container = get_node_or_null("MainContent/ItemsContainer")
	_items_scroll = get_node_or_null("MainContent/ItemsContainer/ItemsScroll")
	_items_grid = get_node_or_null("MainContent/ItemsContainer/ItemsScroll/ItemsGrid")

	_detail_container = get_node_or_null("MainContent/DetailContainer")
	_detail_scroll = get_node_or_null("MainContent/DetailContainer/DetailScroll")
	_detail_content = get_node_or_null("MainContent/DetailContainer/DetailScroll/DetailContent")

	_detail_name = get_node_or_null("MainContent/DetailContainer/DetailScroll/DetailContent/DetailName")
	_detail_description = get_node_or_null("MainContent/DetailContainer/DetailScroll/DetailContent/DetailDescription")
	_detail_stats = get_node_or_null("MainContent/DetailContainer/DetailScroll/DetailContent/DetailStats")
	_detail_cost = get_node_or_null("MainContent/DetailContainer/DetailScroll/DetailContent/DetailCost")
	_buy_button = get_node_or_null("MainContent/DetailContainer/DetailScroll/DetailContent/BuyButton")

	_footer_container = get_node_or_null("FooterContainer")
	_back_button = get_node_or_null("FooterContainer/BackButton")

func _setup_ui() -> void:
	# Setup header
	if _shop_name_label:
		_shop_name_label.text = shop_name
	if shop_icon != null and _shop_icon_texture:
		_shop_icon_texture.texture = shop_icon
		_shop_icon_texture.visible = true

	# Setup categories
	if _categories_list:
		_categories_list.add_theme_constant_override("separation", 8)

	# Setup items grid
	if _items_grid:
		_items_grid.columns = 3  # 3 columns for grid layout
		_items_grid.cell_size = Vector2(120, 140)  # Fixed cell size
		_items_grid.custom_minimum_size = Vector2(360, 420)

	# Setup detail panel
	if _detail_content:
		_detail_content.add_theme_constant_override("separation", 12)
	if _detail_name:
		_detail_name.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	if _detail_description:
		_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _detail_stats:
		_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _detail_cost:
		_detail_cost.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))

	# Setup footer
	if _back_button:
		_back_button.text = "Back to Bazaar"
		var back_callable := Callable(self, "_on_back_to_bazaar_pressed")
		if not _back_button.is_connected("pressed", back_callable):
			_back_button.pressed.connect(_on_back_to_bazaar_pressed)

func _refresh_currency() -> void:
	var moonpearls: int = Database.get_moonpearls(GameData.current_profile)
	if _currency_label:
		_currency_label.text = "Currency: " + str(moonpearls) + " " + currency_icon

func _refresh_categories() -> void:
	if not _categories_list:
		return

	# Clear existing categories
	for child in _categories_list.get_children():
		child.queue_free()
	
	# Add categories
	for category in _current_categories:
		var category_btn := Button.new()
		category_btn.text = category
		category_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_btn.pressed.connect(_on_category_pressed.bind(category))
		
		# Highlight selected category
		if category == _selected_category:
			category_btn.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
			category_btn.add_theme_color_override("font_hover_color", GameData.ACCENT_GOLD)
		else:
			category_btn.add_theme_color_override("font_color", Color("#ffffff"))
			category_btn.add_theme_color_override("font_hover_color", Color("#cccccc"))
		
		_categories_list.add_child(category_btn)
	
	# Refresh items based on selected category
	_refresh_items()

func _refresh_items() -> void:
	if not _items_grid:
		return

	# Clear existing items
	for child in _items_grid.get_children():
		child.queue_free()
	
	# Filter items by category
	var filtered_items: Array[Dictionary] = []
	if _selected_category == "All":
		filtered_items = _current_items
	else:
		for item in _current_items:
			if item.get("category", "All") == _selected_category:
				filtered_items.append(item)
	
	# Create item cards
	for item in filtered_items:
		var item_card := _create_item_card(item)
		_items_grid.add_child(item_card)

func _create_item_card(item: Dictionary) -> Control:
	var card := Panel.new()
	card.add_theme_color_override("panel", Color("#2a2a3a"))
	card.custom_minimum_size = Vector2(110, 130)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var card_content := VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 6)
	card_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_content.custom_minimum_size = Vector2(90, 110)
	card.add_child(card_content)
	
	# Item emoji/name
	var header := HBoxContainer.new()
	card_content.add_child(header)
	
	var emoji_label := Label.new()
	emoji_label.text = item.get("emoji", "❓")
	emoji_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
	emoji_label.custom_minimum_size = Vector2(30, 0)
	header.add_child(emoji_label)
	
	var name_label := Label.new()
	name_label.text = item.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(60, 0)
	header.add_child(name_label)
	
	# Item description preview
	var desc_label := Label.new()
	desc_label.text = item.get("desc", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	desc_label.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.8))
	desc_label.custom_minimum_size = Vector2(80, 30)
	card_content.add_child(desc_label)
	
	# Item cost
	var cost_label := Label.new()
	var cost = item.get("cost", 0)
	cost_label.text = str(cost) + " " + currency_icon
	cost_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	cost_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_content.add_child(cost_label)
	
	# Add click handler
	card.mouse_entered.connect(_on_item_card_hovered.bind(item))
	card.gui_input.connect(_on_item_card_input.bind(item))
	
	return card

func _update_detail_panel(item: Dictionary) -> void:
	if item.is_empty():
		if _detail_container:
			_detail_container.visible = false
		_is_item_selected = false
		return

	if not _detail_container:
		return

	_detail_container.visible = true
	_is_item_selected = true
	_selected_item = item

	# Update detail content
	if _detail_name:
		_detail_name.text = item.get("name", "Unknown Item")
	if _detail_description:
		_detail_description.text = item.get("desc", "No description available.")
	if _detail_stats:
		_detail_stats.text = item.get("stats", "")
	if _detail_cost:
		_detail_cost.text = "Cost: " + str(item.get("cost", 0)) + " " + currency_icon

	# Setup buy button
	var cost: int = item.get("cost", 0)
	var moonpearls: int = Database.get_moonpearls(GameData.current_profile)
	var can_afford: bool = moonpearls >= cost

	if _buy_button:
		_buy_button.text = "Buy"
		_buy_button.disabled = not can_afford
		var buy_callable := Callable(self, "_on_buy_button_pressed")
		if _buy_button.is_connected("pressed", buy_callable):
			_buy_button.pressed.disconnect(_on_buy_button_pressed)
		if can_afford:
			_buy_button.pressed.connect(_on_buy_button_pressed)

func _on_category_pressed(category: String) -> void:
	_selected_category = category
	_refresh_categories()
	_refresh_items()
	category_changed.emit(category)

func _on_item_card_hovered(item: Dictionary) -> void:
	_update_detail_panel(item)

func _on_item_card_input(event: InputEvent, item: Dictionary) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_update_detail_panel(item)
			item_selected.emit(item)

func _on_buy_button_pressed() -> void:
	if not _is_item_selected:
		return
	
	var item := _selected_item
	var cost: int = item.get("cost", 0)
	var moonpearls: int = Database.get_moonpearls(GameData.current_profile)
	
	if moonpearls >= cost:
		# Deduct currency
		Database.add_moonpearls(-cost, GameData.current_profile)
		_refresh_currency()
		
		# Emit purchase signal
		item_purchased.emit(item)
		
		# Show success message
		print("Successfully purchased: " + item.get("name", "Unknown"))
	else:
		# Show insufficient funds message
		print("Insufficient funds to purchase: " + item.get("name", "Unknown"))

func _on_back_to_bazaar_pressed() -> void:
	back_to_bazaar_pressed.emit()

# Public methods for external control
func set_shop_name(name: String) -> void:
	shop_name = name
	if _shop_name_label:
		_shop_name_label.text = name

func set_currency_icon(icon: String) -> void:
	currency_icon = icon
	_refresh_currency()

func set_shop_icon(icon: Texture2D) -> void:
	shop_icon = icon
	if icon != null and _shop_icon_texture:
		_shop_icon_texture.texture = icon
		_shop_icon_texture.visible = true

func set_categories(categories: Array[String]) -> void:
	_current_categories = categories
	_refresh_categories()

func set_items(items: Array[Dictionary]) -> void:
	_current_items = items
	_refresh_items()

func refresh_currency() -> void:
	_refresh_currency()

func select_category(category: String) -> void:
	if _current_categories.has(category):
		_selected_category = category
		_refresh_categories()
		_refresh_items()

func select_item(item: Dictionary) -> void:
	_update_detail_panel(item)
	item_selected.emit(item)

func clear_selection() -> void:
	_update_detail_panel({})
