extends Control
class_name ModernShopLayout

# Modern, sleek shop layout component for the Dice Carver
# Features:
# - Moonseed-themed dark violet/deep blue theme with turquoise accents
# - Three-panel layout (categories + items + detail)
# - Search functionality
# - Price filtering
# - Collection statistics
# - Animated dice item cards with moonlit glow effects
# - Crystal/cavern lighting aesthetic

@export var shop_name: String = "Dice Carver"
@export var merchant_name: String = "Crystal Beetle"
@export var currency_icon: String = "✦"
@export var shop_icon: Texture2D = null

# UI References
@onready var _background: ColorRect
@onready var _content_container: MarginContainer
@onready var _main_vbox: VBoxContainer

@onready var _header: HBoxContainer
@onready var _shop_info: HBoxContainer
@onready var _shop_icon: TextureRect
@onready var _shop_title_container: VBoxContainer
@onready var _shop_name_label: Label
@onready var _merchant_label: Label
@onready var _currency_container: HBoxContainer
@onready var _currency_icon: TextureRect
@onready var _currency_label: Label

@onready var _main_content: HBoxContainer
@onready var _left_panel: VBoxContainer
@onready var _categories_section: Panel
@onready var _categories_title: Label
@onready var _categories_scroll: ScrollContainer
@onready var _categories_list: VBoxContainer

@onready var _filters_section: Panel
@onready var _filters_title: Label
@onready var _price_filter: HBoxContainer
@onready var _price_label: Label
@onready var _price_slider: HSlider
@onready var _price_value: Label

@onready var _stats_section: Panel
@onready var _stats_title: Label
@onready var _stats_content: VBoxContainer
@onready var _unlocked_label: Label
@onready var _satchel_label: Label

@onready var _right_panel: VBoxContainer
@onready var _search_bar: HBoxContainer
@onready var _search_icon: TextureRect
@onready var _search_input: LineEdit
@onready var _items_section: Panel
@onready var _items_scroll: ScrollContainer
@onready var _items_grid: GridContainer

@onready var _detail_panel: Panel
@onready var _detail_content: VBoxContainer
@onready var _detail_header: HBoxContainer
@onready var _detail_icon: TextureRect
@onready var _detail_info: VBoxContainer
@onready var _detail_name: Label
@onready var _detail_type: Label
@onready var _detail_description: Label
@onready var _detail_stats: Label
@onready var _detail_actions: HBoxContainer
@onready var _detail_cost: Label
@onready var _buy_button: Button

@onready var _footer: HBoxContainer
@onready var _back_button: Button
@onready var _refresh_button: Button

# Internal state
var _current_categories: Array[String] = []
var _current_items: Array[Dictionary] = []
var _filtered_items: Array[Dictionary] = []
var _selected_category: String = "All"
var _selected_item: Dictionary = {}
var _is_item_selected: bool = false
var _max_price: int = 5000
var _search_query: String = ""

# Signals
signal item_selected(item_data: Dictionary)
signal item_purchased(item_data: Dictionary)
signal category_changed(category: String)
signal back_to_bazaar_pressed()

func _ready() -> void:
	# Defer initialization until the entire instanced scene is ready
	call_deferred("_deferred_init")


func _deferred_init() -> void:
	_resolve_nodes()
	# Use a minimal UI setup to avoid runtime style construction issues on unstable runtimes.
	_setup_ui_minimal()
	_refresh_currency()
	_refresh_categories()
	_refresh_items()
	_update_stats()

	# Debug: log resolved node availability and current data counts
	print("ModernShopLayout: deferred_init complete. nodes:",
		"categories_list=", is_instance_valid(_categories_list),
		"items_grid=", is_instance_valid(_items_grid),
		"detail_panel=", is_instance_valid(_detail_panel))
	print("ModernShopLayout: current_categories size=", _current_categories.size(), " current_items size=", _current_items.size())

	# Connect signals (guard nulls)
	if is_instance_valid(_search_input):
		_search_input.text_changed.connect(_on_search_changed)
	if is_instance_valid(_price_slider):
		_price_slider.value_changed.connect(_on_price_filter_changed)
	if is_instance_valid(_back_button):
		_back_button.pressed.connect(_on_back_to_bazaar_pressed)
	if is_instance_valid(_refresh_button):
		_refresh_button.pressed.connect(_on_refresh_pressed)
	if is_instance_valid(_buy_button):
		_buy_button.pressed.connect(_on_buy_button_pressed)


func _resolve_nodes() -> void:
	# Re-resolve onready node references in case they were not yet available
	# when the packed scene was instanced into a parent.
	# Only assign if current var is null to preserve existing references.
	if _background == null:
		_background = get_node_or_null("Background")
	if _content_container == null:
		_content_container = get_node_or_null("ContentContainer")
	if _main_vbox == null:
		_main_vbox = get_node_or_null("ContentContainer/MainVBox")
	if _header == null:
		_header = get_node_or_null("ContentContainer/MainVBox/Header")
	if _shop_info == null:
		_shop_info = get_node_or_null("ContentContainer/MainVBox/Header/ShopInfo")
	if _shop_icon == null:
		_shop_icon = get_node_or_null("ContentContainer/MainVBox/Header/ShopInfo/ShopIcon")
	if _shop_title_container == null:
		_shop_title_container = get_node_or_null("ContentContainer/MainVBox/Header/ShopInfo/ShopTitleContainer")
	if _shop_name_label == null:
		_shop_name_label = get_node_or_null("ContentContainer/MainVBox/Header/ShopInfo/ShopTitleContainer/ShopNameLabel")
	if _merchant_label == null:
		_merchant_label = get_node_or_null("ContentContainer/MainVBox/Header/ShopInfo/ShopTitleContainer/MerchantLabel")
	if _currency_container == null:
		_currency_container = get_node_or_null("ContentContainer/MainVBox/Header/CurrencyContainer")
	if _currency_icon == null:
		_currency_icon = get_node_or_null("ContentContainer/MainVBox/Header/CurrencyContainer/CurrencyIcon")
	if _currency_label == null:
		_currency_label = get_node_or_null("ContentContainer/MainVBox/Header/CurrencyContainer/CurrencyLabel")
	if _main_content == null:
		_main_content = get_node_or_null("ContentContainer/MainVBox/MainContent")
	if _left_panel == null:
		_left_panel = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel")
	if _categories_section == null:
		_categories_section = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/CategoriesSection")
	if _categories_title == null:
		_categories_title = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/CategoriesSection/CategoriesTitle")
	if _categories_scroll == null:
		_categories_scroll = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/CategoriesSection/CategoriesScroll")
	if _categories_list == null:
		_categories_list = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/CategoriesSection/CategoriesScroll/CategoriesList")
	if _filters_section == null:
		_filters_section = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/FiltersSection")
	if _filters_title == null:
		_filters_title = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/FiltersSection/FiltersTitle")
	if _price_filter == null:
		_price_filter = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/FiltersSection/PriceFilter")
	if _price_label == null:
		_price_label = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/FiltersSection/PriceFilter/PriceLabel")
	if _price_slider == null:
		_price_slider = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/FiltersSection/PriceFilter/PriceSlider")
	if _price_value == null:
		_price_value = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/FiltersSection/PriceFilter/PriceValue")
	if _stats_section == null:
		_stats_section = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/StatsSection")
	if _stats_title == null:
		_stats_title = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/StatsSection/StatsTitle")
	if _stats_content == null:
		_stats_content = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/StatsSection/StatsContent")
	if _unlocked_label == null:
		_unlocked_label = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/StatsSection/StatsContent/UnlockedLabel")
	if _satchel_label == null:
		_satchel_label = get_node_or_null("ContentContainer/MainVBox/MainContent/LeftPanel/StatsSection/StatsContent/SatchelLabel")
	if _right_panel == null:
		_right_panel = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel")
	if _search_bar == null:
		_search_bar = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/SearchBar")
	if _search_icon == null:
		_search_icon = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/SearchBar/SearchIcon")
	if _search_input == null:
		_search_input = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/SearchBar/SearchInput")
	if _items_section == null:
		_items_section = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/ItemsSection")
	if _items_scroll == null:
		_items_scroll = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/ItemsSection/ItemsScroll")
	if _items_grid == null:
		_items_grid = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/ItemsSection/ItemsScroll/ItemsGrid")
	if _detail_panel == null:
		_detail_panel = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/DetailPanel")
	if _detail_content == null:
		_detail_content = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/DetailPanel/DetailContent")
	if _detail_header == null:
		_detail_header = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/DetailPanel/DetailContent/DetailHeader")
	if _detail_icon == null:
		_detail_icon = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/DetailPanel/DetailContent/DetailHeader/DetailIcon")
	if _detail_info == null:
		_detail_info = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/DetailPanel/DetailContent/DetailHeader/DetailInfo")
	if _detail_name == null:
		_detail_name = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/DetailPanel/DetailContent/DetailHeader/DetailInfo/DetailName")
	if _detail_type == null:
		_detail_type = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/DetailPanel/DetailContent/DetailHeader/DetailInfo/DetailType")
	if _detail_description == null:
		_detail_description = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/DetailPanel/DetailContent/DetailDescription")
	if _detail_stats == null:
		_detail_stats = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/DetailPanel/DetailContent/DetailStats")
	if _detail_actions == null:
		_detail_actions = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/DetailPanel/DetailContent/DetailActions")
	if _detail_cost == null:
		_detail_cost = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/DetailPanel/DetailContent/DetailActions/DetailCost")
	if _buy_button == null:
		_buy_button = get_node_or_null("ContentContainer/MainVBox/MainContent/RightPanel/DetailPanel/DetailContent/DetailActions/BuyButton")
	if _footer == null:
		_footer = get_node_or_null("ContentContainer/MainVBox/Footer")
	if _back_button == null:
		_back_button = get_node_or_null("ContentContainer/MainVBox/Footer/BackButton")
	if _refresh_button == null:
		_refresh_button = get_node_or_null("ContentContainer/MainVBox/Footer/RefreshButton")

	# Debug: report which nodes were found
	print("ModernShopLayout: _resolve_nodes results ->",
		"_categories_list=", str(_categories_list),
		"_items_grid=", str(_items_grid),
		"_detail_panel=", str(_detail_panel))

	# Fallback: if key nodes are still null, try a recursive name-based search.
	if _categories_list == null:
		_categories_list = _find_node_by_name("CategoriesList")
	if _items_grid == null:
		_items_grid = _find_node_by_name("ItemsGrid")
	if _detail_panel == null:
		_detail_panel = _find_node_by_name("DetailPanel")

	# Final debug after fallback
	print("ModernShopLayout: _resolve_nodes fallback ->",
		"_categories_list=", str(_categories_list),
		"_items_grid=", str(_items_grid),
		"_detail_panel=", str(_detail_panel))


func _find_node_by_name(target_name: String) -> Node:
	# Recursively search this node's subtree for a node with the given name.
	for n in get_tree().get_nodes_in_group(""):
		# avoid expensive global searches; use manual recursion from self
		pass
	# Implement local recursive search
	return _find_node_by_name_rec(self, target_name)


func _find_node_by_name_rec(start: Node, target_name: String) -> Node:
	for child in start.get_children():
		if str(child.name) == target_name:
			return child
		var res := _find_node_by_name_rec(child, target_name)
		if res != null:
			return res
	return null

func _setup_ui() -> void:
	# Moonseed-themed color palette
	var bg_color = Color(0.05, 0.02, 0.12, 1.0)  # Deep violet background
	var accent_color = Color(0.64, 0.54, 1.0, 1.0)  # Turquoise/cerulean accent
	var text_color = Color(0.9, 0.9, 0.9, 1)  # Light text
	var muted_color = Color(0.8, 0.8, 0.8, 1)  # Muted text
	var card_bg_color = Color(0.12, 0.08, 0.2, 1.0)  # Dice card background
	var border_color = Color(0.3, 0.2, 0.4, 1.0)  # UI borders
	var glow_color = Color(0.2, 0.6, 1.0, 0.3)  # Moonlit glow
	
	# Apply background styling
	if is_instance_valid(_background):
		_background.color = bg_color
	
	# Header setup with Moonseed styling
	if is_instance_valid(_shop_name_label):
		_shop_name_label.text = shop_name
		_shop_name_label.add_theme_color_override("font_color", accent_color)
		_shop_name_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(28))
		# Add subtle glow effect
		_shop_name_label.add_theme_color_override("font_outline_color", Color(0.2, 0.6, 1.0, 0.5))
		_shop_name_label.add_theme_constant_override("outline_size", 2)
	
	if is_instance_valid(_merchant_label):
		_merchant_label.text = merchant_name
		_merchant_label.add_theme_color_override("font_color", muted_color)
		_merchant_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	
	if is_instance_valid(_currency_label):
		_currency_label.add_theme_color_override("font_color", accent_color)
		_currency_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	
	if shop_icon != null and is_instance_valid(_shop_icon):
		_shop_icon.texture = shop_icon
		_shop_icon.visible = true
		# Add glow effect to shop icon
		_shop_icon.modulate = Color(1, 1, 1, 1)
	
	# Setup categories with Moonseed styling
	if is_instance_valid(_categories_list):
		_categories_list.add_theme_constant_override("separation", 12)
	if is_instance_valid(_categories_title):
		_categories_title.add_theme_color_override("font_color", accent_color)
		_categories_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	
	# Setup filters with Moonseed styling
	if is_instance_valid(_filters_title):
		_filters_title.add_theme_color_override("font_color", accent_color)
		_filters_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	if is_instance_valid(_price_label):
		_price_label.add_theme_color_override("font_color", text_color)
		_price_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	if is_instance_valid(_price_slider):
		_price_slider.min_value = 0
		_price_slider.max_value = 5000
		_price_slider.value = 5000
		# Style the slider with Moonseed theme
		var slider_style := StyleBoxFlat.new()
		slider_style.bg_color = Color(0.15, 0.1, 0.25, 1.0)
		slider_style.set_border_width_all(1)
		slider_style.border_color = border_color
		slider_style.set_corner_radius_all(4)
		_price_slider.add_theme_stylebox_override("grabber", slider_style)
	if is_instance_valid(_price_value) and is_instance_valid(_price_slider):
		_price_value.text = str(_price_slider.value)
		_price_value.add_theme_color_override("font_color", accent_color)
		_price_value.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	
	# Setup stats with Moonseed styling
	if is_instance_valid(_stats_title):
		_stats_title.add_theme_color_override("font_color", accent_color)
		_stats_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	if is_instance_valid(_unlocked_label):
		_unlocked_label.add_theme_color_override("font_color", text_color)
		_unlocked_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	if is_instance_valid(_satchel_label):
		_satchel_label.add_theme_color_override("font_color", text_color)
		_satchel_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	
	# Setup items grid with responsive columns
	if is_instance_valid(_items_grid):
		# Set responsive columns based on screen size
		_items_grid.columns = 3
		_items_grid.cell_size = Vector2(200, 240)
		_items_grid.custom_minimum_size = Vector2(600, 480)
	
	# Setup detail panel with Moonseed styling
	if is_instance_valid(_detail_panel):
		_detail_panel.visible = false
		# Style detail panel background
		var detail_style := StyleBoxFlat.new()
		detail_style.bg_color = Color(0.15, 0.1, 0.25, 1.0)
		detail_style.set_border_width_all(1)
		detail_style.border_color = border_color
		detail_style.set_corner_radius_all(12)
		_detail_panel.add_theme_stylebox_override("panel", detail_style)
	
	if is_instance_valid(_detail_name):
		_detail_name.add_theme_color_override("font_color", accent_color)
		_detail_name.add_theme_font_size_override("font_size", GameData.scaled_font_size(24))
		_detail_name.add_theme_color_override("font_outline_color", Color(0.2, 0.6, 1.0, 0.3))
		_detail_name.add_theme_constant_override("outline_size", 2)
	
	if is_instance_valid(_detail_type):
		_detail_type.add_theme_color_override("font_color", muted_color)
		_detail_type.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	
	if is_instance_valid(_detail_description):
		_detail_description.add_theme_color_override("font_color", text_color)
		_detail_description.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	
	if is_instance_valid(_detail_stats):
		_detail_stats.add_theme_color_override("font_color", text_color)
		_detail_stats.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	
	if is_instance_valid(_detail_cost):
		_detail_cost.add_theme_color_override("font_color", accent_color)
		_detail_cost.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	
	# Setup footer buttons with Moonseed styling
	if is_instance_valid(_back_button):
		_back_button.text = "Back to Bazaar"
		_setup_button_style(_back_button, Color(0.15, 0.1, 0.25, 1.0), accent_color)
	
	if is_instance_valid(_refresh_button):
		_refresh_button.text = "Refresh Selection"
		_setup_button_style(_refresh_button, Color(0.1, 0.05, 0.2, 1.0), text_color)


func _setup_ui_minimal() -> void:
	# Minimal UI setup: only set texts and basic layout properties.
	# This avoids constructing StyleBoxFlat objects which can fail on some runtimes.
	if is_instance_valid(_shop_name_label):
		_shop_name_label.text = shop_name
		_shop_name_label.add_theme_font_size_override("font_size", 24)
	if is_instance_valid(_merchant_label):
		_merchant_label.text = merchant_name
		_merchant_label.add_theme_font_size_override("font_size", 12)
	if is_instance_valid(_currency_label):
		_currency_label.text = currency_icon
	if shop_icon != null and is_instance_valid(_shop_icon):
		_shop_icon.texture = shop_icon
		_shop_icon.visible = true
	# Minimal category/item sizing
	if is_instance_valid(_items_grid):
		_items_grid.columns = 3
		_items_grid.cell_size = Vector2(180, 220)
	# Ensure detail panel starts hidden
	if is_instance_valid(_detail_panel):
		_detail_panel.visible = false

func _setup_button_style(button: Button, bg_color: Color, text_color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_border_width_all(2)
	sb.border_color = Color(0.3, 0.2, 0.4, 1.0)
	sb.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", sb)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_font_size_override("font_size", 14)

func _refresh_currency() -> void:
	# Placeholder for currency display - will be updated by parent
	if is_instance_valid(_currency_label):
		_currency_label.text = "Currency: -- " + currency_icon

func _refresh_categories() -> void:
	# Clear existing categories
	if is_instance_valid(_categories_list):
		for child in _categories_list.get_children():
			child.queue_free()
	else:
		return
	
	# Add categories
	for category in _current_categories:
		var category_btn := Button.new()
		category_btn.text = category
		category_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_btn.pressed.connect(_on_category_pressed.bind(category))
		
		# Style based on selection
		if category == _selected_category:
			category_btn.add_theme_color_override("font_color", Color(1, 0.843137, 0, 1))
			category_btn.add_theme_color_override("font_hover_color", Color(1, 0.843137, 0, 1))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.15, 0.1, 0.25, 1.0)
			sb.set_border_width_all(2)
			sb.border_color = Color(1, 0.843137, 0, 1)
			sb.set_corner_radius_all(8)
			category_btn.add_theme_stylebox_override("normal", sb)
		else:
			category_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
			category_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.1, 0.05, 0.2, 1.0)
			sb.set_border_width_all(1)
			sb.border_color = Color(0.3, 0.2, 0.4, 1.0)
			sb.set_corner_radius_all(8)
			category_btn.add_theme_stylebox_override("normal", sb)
		
		_categories_list.add_child(category_btn)
	
	# Refresh items based on selected category
	_refresh_items()

func _refresh_items() -> void:
	# Clear existing items
	if is_instance_valid(_items_grid):
		for child in _items_grid.get_children():
			child.queue_free()
	else:
		return
	
	# Filter items by category, price, and search query
	_filtered_items.clear()
	for item in _current_items:
		# Category filter
		if _selected_category != "All" and item.get("category", "All") != _selected_category:
			continue
		
		# Price filter
		var cost: int = item.get("cost", 0)
		if cost > _max_price:
			continue
		
		# Search filter
		if _search_query != "":
			var search_lower: String = _search_query.to_lower()
			var name_lower: String = item.get("name", "").to_lower()
			var desc_lower: String = item.get("desc", "").to_lower()
			if not (name_lower.contains(search_lower) or desc_lower.contains(search_lower)):
				continue
		
		_filtered_items.append(item)
	
	# Create item cards
	for item in _filtered_items:
		var item_card := _create_item_card(item)
		_items_grid.add_child(item_card)

func _create_item_card(item: Dictionary) -> Control:
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", _create_dice_card_stylebox())
	card.custom_minimum_size = Vector2(180, 220)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Add hover and click effects
	card.mouse_entered.connect(_on_dice_card_mouse_entered.bind(card))
	card.mouse_exited.connect(_on_dice_card_mouse_exited.bind(card))
	card.gui_input.connect(_on_dice_card_input.bind(item))
	
	var card_content := VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 12)
	card_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(card_content)
	
	# Item emoji/name header with dice icon
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	card_content.add_child(header)
	
	# Dice emoji with glow effect
	var emoji_label := Label.new()
	emoji_label.text = item.get("emoji", "❓")
	emoji_label.add_theme_font_size_override("font_size", 28)
	emoji_label.custom_minimum_size = Vector2(40, 0)
	emoji_label.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0, 1.0))  # Turquoise glow
	emoji_label.add_theme_color_override("font_outline_color", Color(0.2, 0.6, 1.0, 0.3))
	emoji_label.add_theme_constant_override("outline_size", 3)
	header.add_child(emoji_label)
	
	var name_label := Label.new()
	name_label.text = item.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(120, 0)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	header.add_child(name_label)
	
	# Item type/description
	var type_label := Label.new()
	type_label.text = "Type: " + item.get("category", "Unknown")
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	card_content.add_child(type_label)
	
	var desc_label := Label.new()
	desc_label.text = item.get("desc", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	desc_label.custom_minimum_size = Vector2(160, 40)
	card_content.add_child(desc_label)
	
	# Item stats (Max Roll, Special Effects)
	var stats_label := Label.new()
	stats_label.text = item.get("stats", "")
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_font_size_override("font_size", 10)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	stats_label.custom_minimum_size = Vector2(160, 30)
	card_content.add_child(stats_label)
	
	# Item cost and action
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	card_content.add_child(footer)
	
	var cost_label := Label.new()
	var cost = item.get("cost", 0)
	cost_label.text = str(cost) + " " + currency_icon
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(0.64, 0.54, 1.0, 1.0))  # Moonseed accent
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(cost_label)
	
	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.2, 1))
	var buy_sb := StyleBoxFlat.new()
	buy_sb.bg_color = Color(0.64, 0.54, 1.0, 1.0)  # Moonseed turquoise
	buy_sb.set_corner_radius_all(6)
	buy_btn.add_theme_stylebox_override("normal", buy_sb)
	buy_btn.add_theme_stylebox_override("hover", _create_hover_stylebox())
	buy_btn.add_theme_stylebox_override("pressed", _create_pressed_stylebox())
	footer.add_child(buy_btn)
	
	# Add click handlers
	buy_btn.pressed.connect(_on_item_buy_pressed.bind(item))
	
	return card

func _create_dice_card_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.2, 1.0)  # Deep violet background
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.2, 0.4, 1.0)  # Dark border
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_offset = Vector2(0, 4)
	sb.shadow_blur_size = 8
	return sb

func _create_hover_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.15, 0.3, 1.0)  # Lighter on hover
	sb.set_border_width_all(1)
	sb.border_color = Color(0.64, 0.54, 1.0, 1.0)  # Accent color border
	sb.set_corner_radius_all(6)
	return sb

func _create_pressed_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.2, 1.0)  # Darker when pressed
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.2, 0.4, 1.0)
	sb.set_corner_radius_all(6)
	return sb

func _on_dice_card_mouse_entered(card: Panel) -> void:
	# Add hover glow effect
	var tw := card.create_tween()
	tw.tween_property(card, "modulate", Color(1, 1, 1, 1.1), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(card, "scale", Vector2(1.02, 1.02), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_dice_card_mouse_exited(card: Panel) -> void:
	# Remove hover glow effect
	var tw := card.create_tween()
	tw.tween_property(card, "modulate", Color(1, 1, 1, 1.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_dice_card_input(event: InputEvent, item: Dictionary) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_update_detail_panel(item)
			item_selected.emit(item)

func _create_card_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.2, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.2, 0.4, 1.0)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_offset = Vector2(0, 4)
	sb.shadow_blur_size = 8
	return sb

func _update_detail_panel(item: Dictionary) -> void:
	if item.is_empty():
		if is_instance_valid(_detail_panel):
			_detail_panel.visible = false
		_is_item_selected = false
		return
	
	if is_instance_valid(_detail_panel):
		_detail_panel.visible = true
	_is_item_selected = true
	_selected_item = item
	
	# Update detail content with Moonseed styling
	if is_instance_valid(_detail_name):
		_detail_name.text = item.get("name", "Unknown Item")
	if is_instance_valid(_detail_type):
		_detail_type.text = "Type: " + item.get("category", "Unknown")
	if is_instance_valid(_detail_description):
		_detail_description.text = item.get("desc", "No description available.")
	
	# Create detailed stats with max roll, cost, and special effects
	var detailed_stats: String = ""
	var max_roll: int = item.get("sides", 0)
	var cost: int = item.get("cost", 0)
	var special_effects: String = item.get("special_effects", "")
	
	if max_roll > 0:
		detailed_stats += "Max Roll: " + str(max_roll) + "\n"
	
	if cost > 0:
		detailed_stats += "Cost: " + str(cost) + " " + currency_icon + "\n"
	
	if special_effects != "":
		detailed_stats += "Special Effects: " + special_effects + "\n"
	
	# Add any additional stats from the item
	var additional_stats: String = item.get("stats", "")
	if additional_stats != "":
		if detailed_stats != "":
			detailed_stats += "\n"
		detailed_stats += additional_stats
	
	if is_instance_valid(_detail_stats):
		_detail_stats.text = detailed_stats
	
	if is_instance_valid(_detail_cost):
		_detail_cost.text = "Cost: " + str(cost) + " " + currency_icon
	
	# Setup buy button with Moonseed styling
	_buy_button.text = "Buy"
	_buy_button.disabled = false  # Will be handled by parent
	_setup_button_style(_buy_button, Color(0.64, 0.54, 1.0, 1.0), Color(0.1, 0.1, 0.2, 1.0))

func _update_stats() -> void:
	# Placeholder for stats - will be updated by parent
	if is_instance_valid(_unlocked_label):
		_unlocked_label.text = "Unlocked: --/--"
	if is_instance_valid(_satchel_label):
		_satchel_label.text = "In Satchel: --"

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

func _on_item_buy_pressed(item: Dictionary) -> void:
	_update_detail_panel(item)
	item_selected.emit(item)

func _on_search_changed(new_text: String) -> void:
	_search_query = new_text
	_refresh_items()

func _on_price_filter_changed(new_value: float) -> void:
	_max_price = int(new_value)
	if is_instance_valid(_price_value):
		_price_value.text = str(_max_price)
	_refresh_items()

func _on_buy_button_pressed() -> void:
	if not _is_item_selected:
		return
	
	var item := _selected_item
	var cost: int = item.get("cost", 0)
	
	# Emit purchase signal - parent will handle the actual purchase logic
	item_purchased.emit(item)

func _on_back_to_bazaar_pressed() -> void:
	back_to_bazaar_pressed.emit()

func _on_refresh_pressed() -> void:
	_refresh_items()
	_update_stats()

func _show_purchase_animation() -> void:
	# Create floating "BOUGHT!" text
	var lbl := Label.new()
	lbl.text = "BOUGHT!"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 0.843137, 0, 1))
	_detail_panel.add_child(lbl)
	
	# Position at center of detail panel
	var panel_size := _detail_panel.size
	lbl.position = Vector2(panel_size.x / 2 - 40, panel_size.y / 2 - 10)
	
	# Animate float up and fade out
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 40, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func(): lbl.queue_free())

# Public methods for external control
func set_shop_name(name: String) -> void:
	shop_name = name
	if is_instance_valid(_shop_name_label):
		_shop_name_label.text = name

func set_merchant_name(name: String) -> void:
	merchant_name = name
	if is_instance_valid(_merchant_label):
		_merchant_label.text = name

func set_currency_icon(icon: String) -> void:
	currency_icon = icon
	_refresh_currency()

func set_shop_icon(icon: Texture2D) -> void:
	shop_icon = icon
	if icon != null and is_instance_valid(_shop_icon):
		_shop_icon.texture = icon
		_shop_icon.visible = true

func set_categories(categories: Array[String]) -> void:
	_current_categories = categories
	# Ensure nodes are resolved before attempting to refresh UI
	_resolve_nodes()
	_refresh_categories()

func set_items(items: Array[Dictionary]) -> void:
	_current_items = items
	# Ensure nodes are resolved before attempting to refresh UI
	_resolve_nodes()
	_refresh_items()

func refresh_currency() -> void:
	_refresh_currency()

func refresh_stats() -> void:
	_update_stats()

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
