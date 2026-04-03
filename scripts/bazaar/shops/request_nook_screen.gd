@static_unload

extends ShopScreenBase
class_name RequestNookScreen

# @onready var _browse_popup: PanelContainer = $PopupLayer/BrowsePopup as PanelContainer  # Uncomment if needed
@onready var _detail_popup: PanelContainer = $PopupLayer/DetailPopup as PanelContainer

var _note_name_edit: LineEdit = null
var _task_diff_spin: SpinBox = null
var _relic_mult_spin: SpinBox = null

const SHOP_ICON: Texture2D = preload("res://assets/ui/placeholders/tab_calendar.png")

const ACTION_LABELS: Array[String] = [
	"View Requests",
	"Craft New Container",
	"Sticker Collecting",
	"Sweet Orders",
	"Need Ideas?",
	"Leave",
]

const HOVER_LINES: Dictionary = {
	"View Requests": "Fresh requests arrived through the tunnel post.",
	"Craft New Container": "Shape it to hold your thoughts.",
	"Sticker Collecting": "Open a pack and collect 3 random stickers.",
	"Sweet Orders": "Chocolate orders pile up faster than you'd think.",
	"Need Ideas?": "Tell me what's heavy today. We'll name it gently.",
	"Leave": "I'll keep the lantern on for you.",
}

const IDEAS_DIALOGUE: Array[String] = [
	"I was just thinking… have you had any water yet today?",
	"Maybe a stretch would wake things up a bit?",
	"Your hands may have been busy a while… a small break might help them.",
	"You do not need a full plan… just one task is enough to begin.",
]


func _ready() -> void:
	super._ready()
	set_action_labels(ACTION_LABELS)
	set_button_dialogue(HOVER_LINES)
	_apply_room_layout()
	_apply_button_textures()
	_wire_craft_new_container()
	_wire_need_ideas()


func _wire_need_ideas() -> void:
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
		if label == "Need Ideas?":
			if not btn.pressed.is_connected(_on_need_ideas_pressed):
				btn.pressed.connect(_on_need_ideas_pressed)
			return


func _on_need_ideas_pressed() -> void:
	var random_index: int = randi() % IDEAS_DIALOGUE.size()
	var selected_dialogue: String = IDEAS_DIALOGUE[random_index]
	show_dialogue(selected_dialogue, merchant_name, null, 3.0)


func _wire_craft_new_container() -> void:
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
		
		# Wire up all buttons based on their labels
		match label:
			"Craft New Container":
				if not btn.pressed.is_connected(_on_craft_new_container_pressed):
					btn.pressed.connect(_on_craft_new_container_pressed)
			"Sticker Collecting":
				if not btn.pressed.is_connected(_on_sticker_collecting_pressed):
					btn.pressed.connect(_on_sticker_collecting_pressed)
			"View Requests":
				if not btn.pressed.is_connected(_on_view_requests_pressed):
					btn.pressed.connect(_on_view_requests_pressed)
			"Sweet Orders":
				if not btn.pressed.is_connected(_on_sweet_orders_pressed):
					btn.pressed.connect(_on_sweet_orders_pressed)
			"Need Ideas?":
				if not btn.pressed.is_connected(_on_need_ideas_pressed):
					btn.pressed.connect(_on_need_ideas_pressed)
			"Leave":
				if not btn.pressed.is_connected(_on_leave_pressed):
					btn.pressed.connect(_on_leave_pressed)


func _on_craft_new_container_pressed() -> void:
	_show_note_type_popup()

func _on_sticker_collecting_pressed() -> void:
	_show_sticker_pack_shop()

func _on_view_requests_pressed() -> void:
	show_dialogue("Fresh requests arrived through the tunnel post.", merchant_name, null, 2.0)

func _on_sweet_orders_pressed() -> void:
	show_dialogue("Chocolate orders pile up faster than you'd think.", merchant_name, null, 2.0)

func _show_sticker_pack_shop() -> void:
	if _detail_popup == null:
		return
	_clear_popup(_detail_popup)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_detail_popup.add_child(root)

	# Add header
	var title := Label.new()
	title.text = "Sticker Pack Shop"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	root.add_child(title)
	
	# Add subtitle
	var subtitle := Label.new()
	subtitle.text = "Open packs to collect rare stickers"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	subtitle.add_theme_color_override("font_color", Color("#a1ebac"))
	root.add_child(subtitle)
	
	# Add separator
	var top_separator := HSeparator.new()
	top_separator.add_theme_color_override("separator", Color("#3a3a5a"))
	root.add_child(top_separator)

	# Add sticker pack options
	var pack_container := VBoxContainer.new()
	pack_container.add_theme_constant_override("separation", 15)
	root.add_child(pack_container)

	# Basic Sticker Pack
	var basic_pack := Button.new()
	basic_pack.text = "Basic Sticker Pack - 50 🌙"
	basic_pack.custom_minimum_size = Vector2(200, 40)
	basic_pack.mouse_filter = Control.MOUSE_FILTER_STOP
	basic_pack.pressed.connect(func() -> void:
		_purchase_sticker_pack("basic", 50)
	)
	pack_container.add_child(basic_pack)

	# Premium Sticker Pack
	var premium_pack := Button.new()
	premium_pack.text = "Premium Sticker Pack - 100 🌙"
	premium_pack.custom_minimum_size = Vector2(200, 40)
	premium_pack.mouse_filter = Control.MOUSE_FILTER_STOP
	premium_pack.pressed.connect(func() -> void:
		_purchase_sticker_pack("premium", 100)
	)
	pack_container.add_child(premium_pack)

	# Cancel button
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _detail_popup.visible = false)
	root.add_child(cancel)

	_detail_popup.visible = true

func _purchase_sticker_pack(pack_type: String, cost: int) -> void:
	# Check if player has enough moonpearls
	var current_moonpearls: int = Database.get_moonpearls(GameData.current_profile)
	if current_moonpearls < cost:
		show_dialogue("Not enough Moonpearls! You need 🌙 %d but only have 🌙 %d." % [cost, current_moonpearls], merchant_name, null, 3.0)
		return
	
	# Deduct moonpearls
	if not Database.spend_moonpearls(cost, GameData.current_profile):
		show_dialogue("Transaction failed! Please try again.", merchant_name, null, 2.0)
		return
	
	# Generate 3 random stickers with proper rarity system
	var stickers_won: Array = _generate_random_stickers(pack_type)
	
	# Add stickers to inventory
	for sticker_id in stickers_won:
		Database.add_sticker_to_inventory(sticker_id, GameData.current_profile)
	
	# Show reveal screen instead of simple dialogue
	_show_sticker_reveal(stickers_won, pack_type)
	
	# Refresh wallet display
	_refresh_wallet()

func _generate_random_stickers(pack_type: String) -> Array:
	# Get all available stickers
	var all_ritual_stickers: Array = GameData.RITUAL_STICKERS.keys()
	var all_consumable_stickers: Array = GameData.CONSUMABLE_STICKERS.keys()
	
	# Combine both types
	var all_stickers: Array = all_ritual_stickers + all_consumable_stickers
	
	# Generate 3 random stickers using weighted rarity system
	var result: Array = []
	for i in range(3):
		var sticker_id: String = _roll_sticker_by_rarity(pack_type)
		if sticker_id != "":
			result.append(sticker_id)
	
	return result

func _roll_sticker_by_rarity(pack_type: String) -> String:
	# Define rarity weights based on pack type
	var rarity_weights: Dictionary
	if pack_type == "premium":
		# Premium packs have better odds for rare stickers
		rarity_weights = {
			"common": 40,
			"uncommon": 35,
			"rare": 20,
			"epic": 4,
			"legendary": 1
		}
	else:
		# Basic packs favor common stickers
		rarity_weights = {
			"common": 70,
			"uncommon": 20,
			"rare": 8,
			"epic": 1.5,
			"legendary": 0.5
		}
	
	# Roll for rarity
	var target: float = randf()
	var cumulative: float = 0.0
	var selected_rarity: String = "common"
	
	for rarity in rarity_weights:
		cumulative += rarity_weights[rarity] / 100.0
		if target <= cumulative:
			selected_rarity = rarity
			break
	
	# Get stickers of the selected rarity
	var available_stickers: Array = []
	for sticker_id in GameData.RITUAL_STICKERS.keys():
		var sticker_data = GameData.RITUAL_STICKERS[sticker_id]
		if sticker_data.get("rarity", "common") == selected_rarity:
			available_stickers.append(sticker_id)
	
	for sticker_id in GameData.CONSUMABLE_STICKERS.keys():
		var sticker_data = GameData.CONSUMABLE_STICKERS[sticker_id]
		if sticker_data.get("rarity", "common") == selected_rarity:
			available_stickers.append(sticker_id)
	
	# If no stickers of that rarity, fall back to any sticker
	if available_stickers.is_empty():
		available_stickers = GameData.RITUAL_STICKERS.keys() + GameData.CONSUMABLE_STICKERS.keys()
	
	# Select random sticker from available pool
	if available_stickers.size() > 0:
		var index: int = randi() % available_stickers.size()
		return available_stickers[index]
	
	return ""

func _show_sticker_reveal(stickers_won: Array, pack_type: String) -> void:
	# Create a modal reveal screen
	var reveal_overlay: Control = Control.new()
	reveal_overlay.name = "StickerRevealOverlay"
	reveal_overlay.anchors_preset = Control.PRESET_FULL_RECT
	reveal_overlay.anchor_right = 1.0
	reveal_overlay.anchor_bottom = 1.0
	reveal_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	reveal_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	reveal_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Dark overlay background
	var overlay_bg: ColorRect = ColorRect.new()
	overlay_bg.color = Color(0, 0, 0, 0.7)
	overlay_bg.anchors_preset = Control.PRESET_FULL_RECT
	overlay_bg.anchor_right = 1.0
	overlay_bg.anchor_bottom = 1.0
	reveal_overlay.add_child(overlay_bg)
	
	# Main reveal panel
	var reveal_panel: Panel = Panel.new()
	reveal_panel.anchors_preset = Control.PRESET_CENTER
	reveal_panel.offset_left = -250
	reveal_panel.offset_top = -200
	reveal_panel.offset_right = 250
	reveal_panel.offset_bottom = 200
	reveal_panel.add_theme_color_override("panel", Color("#1a0b3a"))
	reveal_overlay.add_child(reveal_panel)
	
	# Reveal content
	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.anchors_preset = Control.PRESET_FULL_RECT
	content_vbox.anchor_right = 1.0
	content_vbox.anchor_bottom = 1.0
	content_vbox.offset_left = 20
	content_vbox.offset_top = 20
	content_vbox.offset_right = -20
	content_vbox.offset_bottom = -20
	content_vbox.add_theme_constant_override("separation", 15)
	reveal_panel.add_child(content_vbox)
	
	# Title
	var title: Label = Label.new()
	title.text = "Pack Opened!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	content_vbox.add_child(title)
	
	# Pack type label
	var pack_label: Label = Label.new()
	pack_label.text = pack_type.capitalize() + " Pack"
	pack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	pack_label.add_theme_color_override("font_color", Color("#a1ebac"))
	content_vbox.add_child(pack_label)
	
	# Sticker display area
	var sticker_grid: HBoxContainer = HBoxContainer.new()
	sticker_grid.anchors_preset = Control.PRESET_FULL_RECT
	sticker_grid.anchor_right = 1.0
	sticker_grid.anchor_bottom = 1.0
	sticker_grid.offset_top = 120
	sticker_grid.offset_bottom = -80
	sticker_grid.add_theme_constant_override("separation", 20)
	content_vbox.add_child(sticker_grid)
	
	# Create reveal animations for each sticker
	for i in range(stickers_won.size()):
		var sticker_id: String = stickers_won[i]
		var sticker_data: Dictionary
		if GameData.RITUAL_STICKERS.has(sticker_id):
			sticker_data = GameData.RITUAL_STICKERS[sticker_id]
		elif GameData.CONSUMABLE_STICKERS.has(sticker_id):
			sticker_data = GameData.CONSUMABLE_STICKERS[sticker_id]
		
		if sticker_data:
			var sticker_card: Control = _create_sticker_card(sticker_data, i)
			sticker_grid.add_child(sticker_card)
	
	# Close button
	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	close_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(func() -> void:
		reveal_overlay.queue_free()
	)
	content_vbox.add_child(close_btn)
	
	# Add to scene
	get_tree().get_root().add_child(reveal_overlay)
	
	# Animate reveal
	call_deferred("_animate_sticker_reveal", reveal_overlay, stickers_won.size())

func _create_sticker_card(sticker_data: Dictionary, index: int) -> Control:
	var card: Panel = Panel.new()
	card.custom_minimum_size = Vector2(120, 160)
	card.add_theme_color_override("panel", Color("#0d0520"))
	
	# Add rarity border color
	var rarity: String = sticker_data.get("rarity", "common")
	var border_color: Color = GameData.RARITY_COLORS.get(rarity, Color("#eaf7ff"))
	card.add_theme_color_override("border_color", border_color)
	card.add_theme_constant_override("border_width", 3)
	
	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.anchors_preset = Control.PRESET_FULL_RECT
	card_vbox.anchor_right = 1.0
	card_vbox.anchor_bottom = 1.0
	card_vbox.offset_left = 10
	card_vbox.offset_top = 10
	card_vbox.offset_right = -10
	card_vbox.offset_bottom = -10
	card_vbox.add_theme_constant_override("separation", 8)
	card.add_child(card_vbox)
	
	# Sticker emoji/icon
	var emoji_label: Label = Label.new()
	emoji_label.text = sticker_data.get("emoji", "❓")
	emoji_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(32))
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(emoji_label)
	
	# Rarity indicator
	var rarity_label: Label = Label.new()
	rarity_label.text = rarity.capitalize()
	rarity_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	rarity_label.add_theme_color_override("font_color", border_color)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(rarity_label)
	
	# Sticker name
	var name_label: Label = Label.new()
	name_label.text = sticker_data.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	name_label.add_theme_color_override("font_color", Color("#eaf7ff"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(100, 0)
	card_vbox.add_child(name_label)
	
	# Hide initially for animation
	card.modulate = Color(1, 1, 1, 0)
	card.scale = Vector2(0.8, 0.8)
	
	return card

func _animate_sticker_reveal(reveal_overlay: Control, sticker_count: int) -> void:
	var sticker_cards: Array[Panel] = []
	for child in reveal_overlay.get_children():
		if child is Panel:
			for grandchild in child.get_children():
				if grandchild is VBoxContainer:
					for greatgrandchild in grandchild.get_children():
						if greatgrandchild is Panel:
							sticker_cards.append(greatgrandchild as Panel)
	
	# Animate each sticker card
	for i in range(sticker_cards.size()):
		var card: Panel = sticker_cards[i]
		var delay: float = i * 0.3
		
		var tw: Tween = card.create_tween()
		tw.set_parallel(false)
		tw.tween_callback(func() -> void: pass).set_delay(delay)
		tw.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_wallet() -> void:
	if not is_node_ready():
		return
	var wallet: Dictionary = GameData.get_wallet_stats()
	var moonpearl_label: Label = get_node_or_null("BackgroundRoot/RightMenuBoard/ShopHeader/CurrencyRow/MoonpearlLabel") as Label
	if moonpearl_label:
		moonpearl_label.text = str(wallet.get("moonpearls", 0))


func _show_note_type_popup() -> void:
	if _detail_popup == null:
		return
	_clear_popup(_detail_popup)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_detail_popup.add_child(root)

	# Add header
	var title := Label.new()
	title.text = "Craft a new container"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	title.add_theme_color_override("font_color", Color("#ffffff"))
	root.add_child(title)
	
	# Add separator
	var top_separator := HSeparator.new()
	top_separator.add_theme_color_override("separator", Color("#3a3a5a"))
	root.add_child(top_separator)

	var btn_task := Button.new()
	btn_task.text = "Dice Box"
	btn_task.custom_minimum_size = Vector2(200, 40)
	btn_task.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_task.pressed.connect(func() -> void:
		_show_dice_box_popup()
	)
	root.add_child(btn_task)

	var btn_relic := Button.new()
	btn_relic.text = "Curio Canisters"
	btn_relic.custom_minimum_size = Vector2(200, 40)
	btn_relic.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_relic.pressed.connect(func() -> void:
		_show_curio_canisters_popup()
	)
	root.add_child(btn_relic)

	# Cancel button
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _detail_popup.visible = false)
	root.add_child(cancel)

	_detail_popup.visible = true


func _show_dice_box_popup() -> void:
	if _detail_popup == null:
		return
	_clear_popup(_detail_popup)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_detail_popup.add_child(root)

	var title := Label.new()
	title.text = "New dice box"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	root.add_child(title)

	_note_name_edit = LineEdit.new()
	_note_name_edit.placeholder_text = "Task name"
	_note_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_note_name_edit)

	_task_diff_spin = SpinBox.new()
	_task_diff_spin.min_value = 1
	_task_diff_spin.max_value = 5
	_task_diff_spin.step = 1
	_task_diff_spin.value = 1
	_task_diff_spin.prefix = "Difficulty "
	root.add_child(_task_diff_spin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)

	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_btn.pressed.connect(_add_dice_box_from_popup)
	row.add_child(add_btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _detail_popup.visible = false)
	row.add_child(cancel)

	_detail_popup.visible = true
	call_deferred("_focus_note_edit")


func _show_curio_canisters_popup() -> void:
	if _detail_popup == null:
		return
	_clear_popup(_detail_popup)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_detail_popup.add_child(root)

	var title := Label.new()
	title.text = "New curio canister"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	root.add_child(title)

	_note_name_edit = LineEdit.new()
	_note_name_edit.placeholder_text = "Curio canister name"
	_note_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_note_name_edit)

	_relic_mult_spin = SpinBox.new()
	_relic_mult_spin.min_value = 1
	_relic_mult_spin.max_value = 5
	_relic_mult_spin.step = 1
	_relic_mult_spin.value = 1
	_relic_mult_spin.prefix = "Difficulty "
	root.add_child(_relic_mult_spin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)

	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_btn.pressed.connect(_add_curio_canisters_from_popup)
	row.add_child(add_btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _detail_popup.visible = false)
	row.add_child(cancel)

	_detail_popup.visible = true
	call_deferred("_focus_note_edit")


func _focus_note_edit() -> void:
	if is_instance_valid(_note_name_edit):
		_note_name_edit.grab_focus()


func _add_dice_box_from_popup() -> void:
	if not is_instance_valid(_note_name_edit) or not is_instance_valid(_task_diff_spin):
		return
	var task_name := _note_name_edit.text.strip_edges()
	if task_name == "":
		return
	Database.insert_task(task_name, int(_task_diff_spin.value), GameData.current_profile)
	GameData.state_changed.emit()
	_detail_popup.visible = false
	show_dialogue("Pinned: " + task_name, merchant_name, null, 2.0)


func _add_curio_canisters_from_popup() -> void:
	if not is_instance_valid(_note_name_edit) or not is_instance_valid(_relic_mult_spin):
		return
	var canister_name := _note_name_edit.text.strip_edges()
	if canister_name == "":
		return
	var difficulty: int = int(_relic_mult_spin.value)
	var star_power: float = difficulty * 0.25
	Database.insert_curio_canister(canister_name, star_power, "common", GameData.current_profile)
	# Refresh runtime GameData curio list so Satchel / Play update immediately
	var new_curios := []
	for r in Database.get_curio_canisters(GameData.current_profile):
		new_curios.append({id=r.id, title=r.title, mult=r.get("mult", 0.25), emoji=r.get("emoji", "✦"), active=false})
	GameData.curio_canisters = new_curios
	GameData.state_changed.emit()
	_detail_popup.visible = false
	show_dialogue("Crafted: " + canister_name, merchant_name, null, 2.0)


func _clear_popup(popup: Control) -> void:
	for c: Node in popup.get_children():
		c.queue_free()


func _apply_room_layout() -> void:
	var icon_rect: TextureRect = $BackgroundRoot/RightMenuBoard/ShopHeader/ShopIcon as TextureRect
	if icon_rect != null:
		icon_rect.texture = SHOP_ICON

	var room_bg: TextureRect = $BackgroundRoot/LeftMerchantScene/RoomBackground as TextureRect
	if room_bg != null:
		room_bg.modulate = Color(0.92, 1.00, 1.10, 1.0)

	var merchant_sprite: TextureRect = $BackgroundRoot/LeftMerchantScene/MerchantSprite as TextureRect
	if merchant_sprite != null:
		merchant_sprite.offset_left = 70.0
		merchant_sprite.offset_top = 88.0
		merchant_sprite.offset_right = 320.0
		merchant_sprite.offset_bottom = 360.0

	var anchor: Control = $BackgroundRoot/LeftMerchantScene/DialoguePopupAnchor as Control
	if anchor != null:
		anchor.offset_left = 200.0
		anchor.offset_top = 38.0
		anchor.offset_right = 220.0
		anchor.offset_bottom = 58.0


func _apply_button_textures() -> void:
	var buttons := _get_action_buttons()
	for btn: ShopActionButton in buttons:
		_apply_pearl_button_style(btn)


func _apply_pearl_button_style(btn: ShopActionButton) -> void:
	var tex_normal: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_pearl_normal.png")
	var tex_hover: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_pearl_hover.png")
	var tex_pressed: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_pearl_pressed.png")
	var tex_disabled: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_pearl_disabled.png")
	
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
	
	# Darken text colors for better readability
	btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.2, 1.0))  # Dark blue-gray
	btn.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.15, 1.0))  # Even darker on hover
	btn.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.1, 1.0))  # Darkest when pressed
	btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.4, 0.7))  # Medium gray when disabled
	
	# Add subtle shadow for better contrast
	btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.3))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 1)


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


func show_dev_popup() -> void:
	if not GameData.is_debug_mode():
		return

	# If already open, bring to front
	var existing := get_node_or_null("RequestNookDevPopup")
	if existing != null:
		if existing.has_method("popup_centered"):
			existing.call_deferred("popup_centered")
		return

	var wnd := Popup.new()
	wnd.name = "RequestNookDevPopup"
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
