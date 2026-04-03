extends ShopScreenBase
class_name SelenicExchangeScreen

# @onready var _browse_popup: PanelContainer = $PopupLayer/BrowsePopup as PanelContainer  # Uncomment if needed
@onready var _detail_popup: PanelContainer = $PopupLayer/DetailPopup as PanelContainer
@onready var _standardized_layout: StandardizedShopLayout = $StandardizedShopLayout as StandardizedShopLayout

const SHOP_ICON: Texture2D = preload("res://assets/ui/placeholders/icon_moon_full.png")

const ACTION_LABELS: Array[String] = [
	"Fulfill Contracts",
	"Redeem Moonkissed Papers",
	"Receive Blessing",
	"Ask About the Moon",
	"Leave",
]

const HOVER_LINES: Dictionary = {
	"Fulfill Contracts": "A contract kept is a thread unbroken.",
	"Redeem Moonkissed Papers": "Fragments of moonlight, traded for treasures.",
	"Receive Blessing": "Hold still. Let the cavern listen.",
	"Ask About the Moon": "The moon answers softly, but it answers.",
	"Leave": "Walk gently. The exchange remembers footsteps.",
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
		room_bg.modulate = Color(0.95, 0.98, 1.15, 1.0)

	var merchant_sprite: TextureRect = $BackgroundRoot/LeftMerchantScene/MerchantSprite as TextureRect
	if merchant_sprite != null:
		merchant_sprite.offset_left = 86.0
		merchant_sprite.offset_top = 62.0
		merchant_sprite.offset_right = 350.0
		merchant_sprite.offset_bottom = 360.0

	var anchor: Control = $BackgroundRoot/LeftMerchantScene/DialoguePopupAnchor as Control
	if anchor != null:
		anchor.offset_left = 220.0
		anchor.offset_top = 30.0
		anchor.offset_right = 240.0
		anchor.offset_bottom = 50.0


func _apply_button_textures() -> void:
	var buttons := _get_action_buttons()
	for btn: ShopActionButton in buttons:
		_apply_selenic_button_style(btn)


func _apply_selenic_button_style(btn: ShopActionButton) -> void:
	var tex_normal: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_selenic_normal.png")
	var tex_hover: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_selenic_hover.png")
	var tex_pressed: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_selenic_pressed.png")
	var tex_disabled: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_selenic_disabled.png")
	
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
			"Fulfill Contracts":
				if not btn.pressed.is_connected(_on_fulfill_contracts_pressed):
					btn.pressed.connect(_on_fulfill_contracts_pressed)
			"Redeem Moonkissed Papers":
				if not btn.pressed.is_connected(_on_redeem_moonkissed_pressed):
					btn.pressed.connect(_on_redeem_moonkissed_pressed)
			"Receive Blessing":
				if not btn.pressed.is_connected(_on_receive_blessing_pressed):
					btn.pressed.connect(_on_receive_blessing_pressed)
			"Ask About the Moon":
				if not btn.pressed.is_connected(_on_ask_moon_pressed):
					btn.pressed.connect(_on_ask_moon_pressed)
			"Leave":
				if not btn.pressed.is_connected(_on_leave_pressed):
					btn.pressed.connect(_on_leave_pressed)


func _on_fulfill_contracts_pressed() -> void:
	_show_contract_turnin_menu()


func _on_redeem_moonkissed_pressed() -> void:
	_show_moonkissed_paper_redemption()


func _show_moonkissed_paper_redemption() -> void:
	var papers := Database.get_moonkissed_papers(GameData.current_profile)
	
	if papers.is_empty():
		show_dialogue("You have no moonkissed papers to redeem. Complete contracts to earn them.", merchant_name, null, 2.5)
		return
	
	var dialog := AcceptDialog.new()
	dialog.title = "📜 Redeem Moonkissed Papers"
	dialog.size = Vector2(520, 420)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dialog.add_child(vbox)
	
	var info_label := Label.new()
	info_label.text = "You have %d moonkissed paper(s). Select one to redeem:" % papers.size()
	info_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	vbox.add_child(info_label)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	
	for i in range(papers.size()):
		var paper: Dictionary = papers[i]
		var tier: String = paper.get("reward_tier", "minor")
		var tier_label: String = "Minor" if tier == "minor" else "Major"
		var tier_color: Color = GameData.ACCENT_BLUE if tier == "minor" else GameData.ACCENT_GOLD
		
		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(GameData.CARD_BG, 0.8)
		row_style.border_color = tier_color
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(4)
		row_style.content_margin_left = 8
		row_style.content_margin_right = 8
		row_style.content_margin_top = 6
		row_style.content_margin_bottom = 6
		row.add_theme_stylebox_override("panel", row_style)
		
		var row_hbox := HBoxContainer.new()
		row_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(row_hbox)
		
		var paper_info := VBoxContainer.new()
		paper_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_child(paper_info)
		
		var name_label := Label.new()
		name_label.text = "📜 " + paper.get("contract_name", "Unknown Contract")
		name_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		paper_info.add_child(name_label)
		
		var tier_info := Label.new()
		tier_info.text = "Tier: %s Reward" % tier_label
		tier_info.add_theme_color_override("font_color", tier_color)
		tier_info.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		paper_info.add_child(tier_info)
		
		var redeem_btn := Button.new()
		redeem_btn.text = "Redeem"
		redeem_btn.custom_minimum_size = Vector2(80, 0)
		redeem_btn.pressed.connect(func(idx=i):
			var rewards := Database.redeem_moonkissed_paper(idx, GameData.current_profile)
			if not rewards.is_empty():
				var reward_text := "You received:\n"
				if rewards.get("bar", 0) > 0:
					reward_text += "• %d Chocolate Bar Coins\n" % rewards.get("bar", 0)
				if rewards.get("truffle", 0) > 0:
					reward_text += "• %d Chocolate Truffle Coins\n" % rewards.get("truffle", 0)
				if rewards.get("artisan", 0) > 0:
					reward_text += "• %d Artisan Coins\n" % rewards.get("artisan", 0)
				if rewards.get("cerulean_seeds", 0) > 0:
					reward_text += "• %d Cerulean Seeds" % rewards.get("cerulean_seeds", 0)
				show_dialogue(reward_text, merchant_name, null, 3.0)
				dialog.queue_free()
			else:
				show_dialogue("Unable to redeem this paper.", merchant_name, null, 2.0)
		)
		row_hbox.add_child(redeem_btn)
		
		list.add_child(row)
	
	var scene := get_tree().current_scene
	if scene and scene.has_method("add_overlay_to_stage"):
		scene.call("add_overlay_to_stage", dialog)
	else:
		add_child(dialog)
	dialog.popup_centered()


func _show_contract_turnin_menu() -> void:
	# Build a simple modal listing completed-but-unturned-in contracts
	var active := Database.get_contracts(GameData.current_profile, false)
	var eligible: Array = []
	for c in active:
		if Database.count_incomplete_contract_subtasks(c) == 0:
			eligible.append(c)

	if eligible.is_empty():
		show_dialogue("You have no contracts ready to turn in.", merchant_name, null, 2.0)
		return

	var dialog := AcceptDialog.new()
	dialog.title = "Turn In Contracts"
	dialog.size = Vector2(520, 380)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dialog.add_child(vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for c in eligible:
		var cid := int(c.get("id", 0))
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name := Label.new()
		name.text = c.get("name", "?")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var ti_btn := Button.new()
		ti_btn.text = "Turn In"
		ti_btn.pressed.connect(func(id=cid, btn=ti_btn):
			# attempt to complete and grant reward
			var reward := Database.complete_contract_with_reward(id)
			if reward.is_empty():
				show_dialogue("Unable to turn in contract. Ensure all subtasks are complete.", merchant_name, null, 2.0)
				return
			GameData.contract_data_changed.emit()
			_show_contract_reward(reward)
			dialog.queue_free()
		)
		row.add_child(ti_btn)
		list.add_child(row)

	# Show the dialog
	var scene := get_tree().current_scene
	if scene and scene.has_method("add_overlay_to_stage"):
		scene.call("add_overlay_to_stage", dialog)
	else:
		add_child(dialog)
	dialog.popup_centered()


func _show_contract_reward(reward: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "🏆 Contract Completed"
	var tier: String = reward.get("reward_tier", "minor")
	var tier_label: String = "Minor" if tier == "minor" else "Major"
	var tier_color: String = "blue" if tier == "minor" else "gold"
	dialog.dialog_text = "Contract completed!\n\nYou received a Moonkissed Paper Fragment (%s reward tier).\n\nVisit the Selenic Exchange to redeem your moonkissed papers for chocolate coins and cerulean seeds!" % tier_label
	var scene := get_tree().current_scene
	if scene and scene.has_method("add_overlay_to_stage"):
		scene.call("add_overlay_to_stage", dialog)
	else:
		add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())


func _on_exchange_moondrops_pressed() -> void:
	_setup_standardized_exchange_layout()

func _setup_standardized_exchange_layout() -> void:
	if _standardized_layout == null:
		print("DEBUG: Standardized layout not found!")
		return
	
	# Configure the layout for selenic exchange
	_standardized_layout.set_shop_name("Selenic Exchange")
	_standardized_layout.set_currency_icon("✦")
	_standardized_layout.set_shop_icon(SHOP_ICON)
	
	# Set up categories for exchange
	var categories: Array[String] = ["All", "Exchanges", "Blessings"]
	_standardized_layout.set_categories(categories)
	
	# Create exchange items
	var exchange_items: Array[Dictionary] = []
	
	# Add exchange rate item — canonical rate is 50:1 (matches ScoreEngine.MOONPEARL_THRESHOLD)
	var exchange_data: Dictionary = {
		"id": "moondrop_exchange",
		"name": "Moondrop Exchange",
		"desc": "Exchange 50 moondrops for 1 moonpearl. Offer what you can. Take what you need.",
		"cost": 0,  # No cost, this is an exchange
		"emoji": "🌙",
		"category": "Exchanges",
		"stats": "Rate: 50 moondrops = 1 moonpearl"
	}
	exchange_items.append(exchange_data)
	
	# Add blessings
	var blessings := [
		{id="clarity", name="Clarity", emoji="🔮", desc="+1 star power for next 3 rolls", cost=7},
		{id="courage", name="Courage", emoji="🦁", desc="Guaranteed minimum roll of 3", cost=7},
		{id="quiet", name="Quiet", emoji="🌙", desc="+5 moondrops per completed task today", cost=7},
	]
	
	for blessing in blessings:
		var blessing_data: Dictionary = {
			"id": blessing.id,
			"name": blessing.name,
			"desc": blessing.desc,
			"cost": blessing.cost,
			"emoji": blessing.emoji,
			"category": "Blessings",
			"stats": "Cost: " + str(blessing.cost) + " moonpearls"
		}
		exchange_items.append(blessing_data)
	
	_standardized_layout.set_items(exchange_items)
	
	# Connect signals
	_standardized_layout.item_selected.connect(_on_exchange_item_selected)
	_standardized_layout.item_purchased.connect(_on_exchange_purchased)
	_standardized_layout.back_to_bazaar_pressed.connect(_on_leave_pressed)
	
	# Show the layout and hide the old button list
	_standardized_layout.visible = true
	var right_board = get_node_or_null("BackgroundRoot/RightMenuBoard")
	if right_board:
		var btn_list_node := right_board.get_node_or_null("ButtonList")
		if btn_list_node:
			btn_list_node.visible = false
	
	# Show initial dialogue
	show_dialogue("Browse the offerings of the cavern.", merchant_name, null, 2.0)

func _on_exchange_item_selected(item: Dictionary) -> void:
	print("DEBUG: Exchange item selected: ", item.get("name", "Unknown"))
	
	# Show detailed description
	var detailed_desc: String = item.get("desc", "") + "\n\n" + item.get("stats", "")
	_standardized_layout._detail_description.text = detailed_desc

func _on_exchange_purchased(item: Dictionary) -> void:
	var item_id: String = item.get("id", "")
	if item_id == "":
		return
	
	print("DEBUG: Purchasing exchange item: ", item_id)
	
	# Handle different item types
	match item_id:
		"moondrop_exchange":
			# Handle moondrop exchange
			# This would need to be implemented with a custom dialog
			show_dialogue("The exchange is complete. Moonpearls have been added to your purse.", merchant_name, null, 3.0)
		"clarity", "courage", "quiet":
			# Handle blessing purchase
			var cost: int = item.get("cost", 0)
			var moonpearls: int = Database.get_moonpearls(GameData.current_profile)
			
			if moonpearls >= cost:
				Database.add_moonpearls(-cost, GameData.current_profile)
				
				# Apply the blessing effect
				match item_id:
					"clarity":
						# Clarity: +1 star power for next 3 rolls
						show_dialogue("The blessing of " + item.get("name", "") + " is upon you. Walk gently.", merchant_name, null, 3.0)
					"courage":
						# Courage: Guaranteed minimum roll of 3
						if not "courage" in GameData.active_blessings:
							GameData.active_blessings.append("courage")
							show_dialogue("The blessing of " + item.get("name", "") + " is upon you. Your courage will not falter.", merchant_name, null, 3.0)
						else:
							show_dialogue("You already have the blessing of " + item.get("name", "") + ".", merchant_name, null, 2.0)
					"quiet":
						# Quiet: +5 moondrops per completed task today
						show_dialogue("The blessing of " + item.get("name", "") + " is upon you. Walk gently.", merchant_name, null, 3.0)
				
				# Refresh the layout
				_setup_standardized_exchange_layout()
			else:
				show_dialogue("You need more moonpearls for this blessing.", merchant_name, null, 2.0)
				_standardized_layout.refresh_currency()
		_:
			print("DEBUG: Unknown exchange item: ", item_id)


func _show_exchange_popup() -> void:
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
	title.text = "Selenic Exchange"
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
	top_separator.add_theme_color_override("separator", Color("#3a3a5a"))
	root.add_child(top_separator)

	var info := Label.new()
	info.text = "50 Moondrops = 1 Moonpearl\nOffer what you can. Take what you need."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	info.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.9))
	root.add_child(info)

	var rate_container := HBoxContainer.new()
	rate_container.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(rate_container)

	var drop_icon := Label.new()
	drop_icon.text = "🌙"
	drop_icon.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	rate_container.add_child(drop_icon)

	var rate_text := Label.new()
	rate_text.text = " 50 → 1 "
	rate_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rate_text.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	rate_container.add_child(rate_text)

	var pearl_icon := Label.new()
	pearl_icon.text = "🦪"
	pearl_icon.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	rate_container.add_child(pearl_icon)

	var amount_label := Label.new()
	amount_label.text = "Exchange Amount:"
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	amount_label.add_theme_color_override("font_color", Color("#ffffff"))
	root.add_child(amount_label)

	var spin := SpinBox.new()
	spin.min_value = 50
	spin.max_value = 1000
	spin.step = 50
	spin.value = 50
	spin.suffix = " moondrops"
	spin.custom_minimum_size = Vector2(200, 30)
	root.add_child(spin)

	var exchange_btn := Button.new()
	exchange_btn.text = "Exchange"
	exchange_btn.custom_minimum_size = Vector2(200, 40)
	exchange_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	exchange_btn.pressed.connect(func() -> void:
		var amount := int(spin.value)
		var pearls_gained := int(amount / 50.0)
		Database.add_moonpearls(pearls_gained, GameData.current_profile)
		show_dialogue("The exchange is complete. " + str(pearls_gained) + " moonpearls have been added to your purse.", merchant_name, null, 3.0)
	)
	root.add_child(exchange_btn)

	# Add Exit Shop button at the bottom
	var exit_btn := Button.new()
	exit_btn.text = "🚪 Exit Shop"
	exit_btn.add_theme_color_override("font_color", Color("#ff6b6b"))
	exit_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	exit_btn.custom_minimum_size = Vector2(200, 40)
	exit_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	exit_btn.pressed.connect(_on_leave_pressed)
	root.add_child(exit_btn)


func _on_receive_blessing_pressed() -> void:
	_show_blessing_popup()


func _show_blessing_popup() -> void:
	if _detail_popup == null:
		return
	_clear_popup(_detail_popup)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_detail_popup.add_child(root)

	var title := Label.new()
	title.text = "Choose a Blessing"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	root.add_child(title)

	var moonpearls := Database.get_moonpearls()
	var wallet_label := Label.new()
	wallet_label.text = "Your Moonpearls: " + str(moonpearls)
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wallet_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	wallet_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	root.add_child(wallet_label)

	var blessings := [
		{id="clarity", name="Clarity", emoji="🔮", desc="+1 star power for next 3 rolls", cost=7},
		{id="courage", name="Courage", emoji="🦁", desc="Guaranteed minimum roll of 3", cost=7},
		{id="quiet", name="Quiet", emoji="🌙", desc="+5 moondrops per completed task today", cost=7},
	]

	for blessing in blessings:
		var bless_container := VBoxContainer.new()
		bless_container.add_theme_constant_override("separation", 4)
		
		var header := HBoxContainer.new()
		bless_container.add_child(header)
		
		var emoji := Label.new()
		emoji.text = blessing.emoji
		emoji.custom_minimum_size = Vector2(40, 0)
		emoji.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
		header.add_child(emoji)
		
		var name_label := Label.new()
		name_label.text = blessing.name
		name_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(name_label)
		
		var desc := Label.new()
		desc.text = blessing.desc
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		desc.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.8))
		bless_container.add_child(desc)
		
		var bless_btn := Button.new()
		var debug_buy: bool = Database.get_bool("debug_purchase_enabled", false)
		var can_afford: bool = debug_buy or moonpearls >= blessing.cost
		if can_afford:
			bless_btn.text = "Receive (" + str(0 if debug_buy else blessing.cost) + " pearls)"
			bless_btn.pressed.connect(func() -> void:
				var debug_local: bool = Database.get_bool("debug_purchase_enabled", false)
				if not debug_local:
					Database.add_moonpearls(-blessing.cost, GameData.current_profile)
				
				# Apply the blessing effect
				match blessing.id:
					"clarity":
						# Clarity: +1 star power for next 3 rolls
						# This would need to be tracked in GameData - for now just show dialogue
						show_dialogue("The blessing of " + blessing.name + " is upon you. Walk gently.", merchant_name, null, 3.0)
					"courage":
						# Courage: Guaranteed minimum roll of 3
						if not "courage" in GameData.active_blessings:
							GameData.active_blessings.append("courage")
							show_dialogue("The blessing of " + blessing.name + " is upon you. Your courage will not falter.", merchant_name, null, 3.0)
						else:
							show_dialogue("You already have the blessing of " + blessing.name + ".", merchant_name, null, 2.0)
					"quiet":
						# Quiet: +5 moondrops per completed task today
						# This would need to be tracked in GameData - for now just show dialogue
						show_dialogue("The blessing of " + blessing.name + " is upon you. Walk gently.", merchant_name, null, 3.0)
				
				_detail_popup.visible = false
			)
		else:
			bless_btn.text = "Need " + str(blessing.cost) + " pearls"
			bless_btn.disabled = true
			
		bless_container.add_child(bless_btn)
		
		var sep := HSeparator.new()
		bless_container.add_child(sep)
		
		root.add_child(bless_container)

	var cancel := Button.new()
	cancel.text = "Close"
	cancel.pressed.connect(func() -> void: _detail_popup.visible = false)
	root.add_child(cancel)

	_detail_popup.visible = true


func _clear_popup(popup: Control) -> void:
	for c: Node in popup.get_children():
		c.queue_free()


func _on_ask_moon_pressed() -> void:
	show_dialogue("The moon remembers everything. It sees your path, knows your heartbeats, and counts your breaths. Tonight it whispers: 'You are exactly where you need to be.'", merchant_name, null, 4.0)


func show_dev_popup() -> void:
	if not GameData.is_debug_mode():
		return

	# If already open, bring to front
	var existing := get_node_or_null("SelenicDevPopup")
	if existing != null:
		if existing.has_method("popup_centered"):
			existing.call_deferred("popup_centered")
		return

	var wnd := Popup.new()
	wnd.name = "SelenicDevPopup"
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
