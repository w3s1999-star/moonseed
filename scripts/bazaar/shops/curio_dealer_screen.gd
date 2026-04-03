extends ShopScreenBase
class_name CurioDealerScreen

# Curio Dealer — Crate-based curio acquisition.
#
# Left 2/3: cozy room scene with merchant + props.
# Right 1/3: decorative menu board with actions.
#
# Core flow:
#   1. Player buys a Curio Crate (10 Moonpearls)
#   2. Crate opens with dice animation
#   3. Curio is revealed
#   4. Player can equip to a canister

# Preload dependencies (required because class_name isn't available during autoload)
const CurioResource := preload("res://scripts/curio/curio_resource.gd")
const CurioDatabase := preload("res://scripts/curio/curio_database.gd")
const CurioCrateOpener := preload("res://scripts/curio/curio_crate_opener.gd")

const REVEAL_POPUP_SCENE := preload("res://scenes/curio/curio_reveal_popup.tscn")

var _crate_opener: CurioCrateOpener = CurioCrateOpener.new()
var _reveal_popup: Control = null

const ACTION_LABELS: Array[String] = [
	"Buy Curio Crate",
	"Browse My Curios",
	"Ask About Curios",
	"Leave",
]

const HOVER_LINES: Dictionary = {
	"Buy Curio Crate": "Ten moonpearls, and you get a mystery curio. Could be common, could be rare. That's the fun.",
	"Browse My Curios": "Let's see what you've collected so far.",
	"Ask About Curios": "Curios are fragments of old moonlight. They cling to dice like memory clings to stone.",
	"Leave": "Come back when the moonlight feels right.",
}


func _ready() -> void:
	super._ready()
	set_action_labels(ACTION_LABELS)
	set_button_dialogue(HOVER_LINES)
	_apply_room_layout()
	_apply_button_textures()
	_wire_action_buttons()


func _apply_room_layout() -> void:
	var room_bg: TextureRect = $BackgroundRoot/LeftMerchantScene/RoomBackground as TextureRect
	if room_bg != null:
		room_bg.modulate = Color(1.10, 0.95, 0.85, 1.0)

	var merchant_sprite: TextureRect = $BackgroundRoot/LeftMerchantScene/MerchantSprite as TextureRect
	if merchant_sprite != null:
		merchant_sprite.offset_left = 90.0
		merchant_sprite.offset_top = 70.0
		merchant_sprite.offset_right = 360.0
		merchant_sprite.offset_bottom = 360.0

	var anchor: Control = $BackgroundRoot/LeftMerchantScene/DialoguePopupAnchor as Control
	if anchor != null:
		anchor.offset_left = 220.0
		anchor.offset_top = 34.0
		anchor.offset_right = 240.0
		anchor.offset_bottom = 54.0


func _apply_button_textures() -> void:
	var buttons := _get_action_buttons()
	for btn: ShopActionButton in buttons:
		_apply_curio_button_style(btn)


func _apply_curio_button_style(btn: ShopActionButton) -> void:
	var tex_normal: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_curio_normal.png")
	var tex_hover: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_curio_hover.png")
	var tex_pressed: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_curio_pressed.png")
	var tex_disabled: Texture2D = preload("res://assets/ui/buttons/merchants/btn_merchant_curio_disabled.png")

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
			"Buy Curio Crate":
				if not btn.pressed.is_connected(_on_buy_crate_pressed):
					btn.pressed.connect(_on_buy_crate_pressed)
			"Browse My Curios":
				if not btn.pressed.is_connected(_on_browse_curios_pressed):
					btn.pressed.connect(_on_browse_curios_pressed)
			"Ask About Curios":
				if not btn.pressed.is_connected(_on_ask_curios_pressed):
					btn.pressed.connect(_on_ask_curios_pressed)
			"Leave":
				if not btn.pressed.is_connected(_on_leave_pressed):
					btn.pressed.connect(_on_leave_pressed)


func _on_buy_crate_pressed() -> void:
	var moonpearls := Database.get_moonpearls(GameData.current_profile)
	if moonpearls < CurioCrateOpener.CURIO_CRATE_COST:
		show_dialogue(
			"You need %d moonpearls for a crate. You only have %d. Come back when you've gathered more."
			% [CurioCrateOpener.CURIO_CRATE_COST, moonpearls],
			merchant_name, null, 3.0
		)
		return

	# Deduct cost
	if not _crate_opener.purchase_crate():
		show_dialogue("Something went wrong with the transaction.", merchant_name, null, 2.0)
		return

	# Pick the curio
	var curio := CurioDatabase.get_random_curio("normal")
	if curio == null:
		show_dialogue("The crate was empty... that shouldn't happen.", merchant_name, null, 2.0)
		return

	# Grant it
	CurioManager.add_curio(curio.id)
	SignalBus.crate_opened.emit(curio.id)

	# Show reveal popup
	_show_reveal_popup(curio)

	# Refresh wallet display
	GameData.state_changed.emit()


func _show_reveal_popup(curio: CurioResource) -> void:
	if _reveal_popup != null and is_instance_valid(_reveal_popup):
		_reveal_popup.queue_free()

	_reveal_popup = REVEAL_POPUP_SCENE.instantiate()
	_reveal_popup.show_curio(curio)
	_reveal_popup.popup_closed.connect(_on_reveal_closed)
	_reveal_popup.equip_requested.connect(_on_reveal_equip_requested)

	# Add to the scene tree (above the shop overlay)
	var scene := get_tree().current_scene
	if scene and scene.has_method("add_overlay_to_stage"):
		scene.call("add_overlay_to_stage", _reveal_popup)
	else:
		add_child(_reveal_popup)


func _on_reveal_closed() -> void:
	_reveal_popup = null
	_refresh_wallet()


func _on_reveal_equip_requested(curio_id: String) -> void:
	# Equip to the first available canister, or show a message
	var equipped := false
	for canister in GameData.curio_canisters:
		var canister_id := int(canister.get("id", -1))
		if canister_id < 0:
			continue
		var current: String = CurioManager.get_equipped_curio(canister_id)
		if current.is_empty():
			if CurioManager.equip_curio(curio_id, canister_id):
				show_dialogue(
					"Equipped %s to %s. Fine choice."
					% [CurioDatabase.get_curio_by_id(curio_id).display_name, canister.get("title", "canister")],
					merchant_name, null, 3.0
				)
				equipped = true
				break

	if not equipped:
		show_dialogue(
			"All your canisters are full. Unequip one first in the Satchel tab, then try again.",
			merchant_name, null, 3.0
		)

	GameData.state_changed.emit()


func _on_browse_curios_pressed() -> void:
	var owned: Array = CurioManager.get_owned_curios()
	if owned.is_empty():
		show_dialogue("You don't have any curios yet. Buy a crate first!", merchant_name, null, 3.0)
		return

	# Build a list of owned curios
	var right_board = get_node("BackgroundRoot/RightMenuBoard")
	if right_board == null:
		return

	# Clear existing content
	for child in right_board.get_children():
		child.queue_free()

	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(400, 600)
	panel.add_theme_color_override("panel", Color("#1a0b3a"))
	right_board.add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(380, 580)
	panel.add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(360, 0)
	scroll.add_child(root)

	var title := Label.new()
	title.text = "Your Curio Collection"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	root.add_child(title)

	var count_lbl := Label.new()
	count_lbl.text = "%d curios owned" % owned.size()
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	count_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
	root.add_child(count_lbl)

	var sep := HSeparator.new()
	root.add_child(sep)

	for curio_id in owned:
		var curio := CurioDatabase.get_curio_by_id(curio_id)
		if curio == null:
			continue
		root.add_child(_make_curio_card(curio))

	# Exit button
	var exit_btn := Button.new()
	exit_btn.text = "🚪 Back"
	exit_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	exit_btn.custom_minimum_size = Vector2(200, 40)
	exit_btn.pressed.connect(_restore_menu_board)
	root.add_child(exit_btn)


func _make_curio_card(curio: CurioResource) -> PanelContainer:
	var rarity_col: Color = GameData.RARITY_COLORS.get(curio.rarity, Color.WHITE)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(GameData.CARD_BG, 0.9)
	st.border_color = rarity_col
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(340, 80)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Emoji
	var emoji_lbl := Label.new()
	emoji_lbl.text = curio.emoji
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(28))
	emoji_lbl.custom_minimum_size = Vector2(40, 0)
	hbox.add_child(emoji_lbl)

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = curio.display_name
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	name_lbl.add_theme_color_override("font_color", rarity_col)
	info.add_child(name_lbl)

	var family_lbl := Label.new()
	family_lbl.text = "%s • %s" % [curio.family.replace("_", " "), curio.rarity.to_upper()]
	family_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	family_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
	info.add_child(family_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = curio.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	desc_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.7))
	info.add_child(desc_lbl)

	# Check if equipped
	var is_equipped: bool = CurioManager.is_curio_equipped(curio.id)
	if is_equipped:
		var equipped_lbl := Label.new()
		equipped_lbl.text = "⚡ EQUIPPED"
		equipped_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		equipped_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
		hbox.add_child(equipped_lbl)

	return panel


func _restore_menu_board() -> void:
	# Rebuild the original menu board
	var right_board = get_node("BackgroundRoot/RightMenuBoard")
	if right_board == null:
		return
	for child in right_board.get_children():
		child.queue_free()

	# Recreate the standard shop header and button list
	var header := VBoxContainer.new()
	header.name = "ShopHeader"
	right_board.add_child(header)

	var title_lbl := Label.new()
	title_lbl.name = "ShopTitleLabel"
	title_lbl.text = shop_title
	title_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
	title_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	header.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.name = "ShopSubtitleLabel"
	subtitle_lbl.text = shop_subtitle
	subtitle_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	subtitle_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
	header.add_child(subtitle_lbl)

	var currency_row := HBoxContainer.new()
	currency_row.name = "CurrencyRow"
	header.add_child(currency_row)

	var moonpearl_lbl := Label.new()
	moonpearl_lbl.name = "MoonpearlLabel"
	moonpearl_lbl.text = str(Database.get_moonpearls(GameData.current_profile))
	moonpearl_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	moonpearl_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	currency_row.add_child(moonpearl_lbl)

	var button_list := VBoxContainer.new()
	button_list.name = "ButtonList"
	right_board.add_child(button_list)

	# Recreate buttons
	for label_text in ACTION_LABELS:
		var btn := ShopActionButton.new()
		btn.label_text = label_text
		button_list.add_child(btn)

	# Re-wire
	_wire_action_buttons()
	_apply_button_textures()
	set_button_dialogue(HOVER_LINES)


func _on_ask_curios_pressed() -> void:
	show_dialogue(
		"Curios are fragments of old moonlight. They cling to dice like memory clings to stone. Each one changes how your dice behave — more moondrops, better rolls, strange patterns. Open a crate and see what finds you.",
		merchant_name, null, 5.0
	)


func show_dev_popup() -> void:
	if not GameData.is_debug_mode():
		return

	var existing := get_node_or_null("CurioDevPopup")
	if existing != null:
		if existing.has_method("popup_centered"):
			existing.call_deferred("popup_centered")
		return

	var wnd := Popup.new()
	wnd.name = "CurioDevPopup"
	wnd.custom_minimum_size = Vector2(360, 200)

	var vb := PanelContainer.new()
	vb.custom_minimum_size = Vector2(340, 180)
	wnd.add_child(vb)
	var content := VBoxContainer.new()
	content.margin_left = 8
	content.margin_top = 8
	content.margin_right = 8
	content.margin_bottom = 8
	vb.add_child(content)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	content.add_child(h)

	var add_money := Button.new()
	add_money.text = "Add 1000 Moonpearls"
	add_money.pressed.connect(func() -> void:
		Database.add_moonpearls(1000, GameData.current_profile)
		_refresh_wallet()
	)
	h.add_child(add_money)

	var grant_all := Button.new()
	grant_all.text = "Grant All Curios"
	grant_all.pressed.connect(func() -> void:
		for curio in CurioDatabase.get_all_curios():
			CurioManager.add_curio(curio.id)
	)
	h.add_child(grant_all)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func() -> void: wnd.hide(); wnd.queue_free())
	content.add_child(close_btn)

	add_child(wnd)
	wnd.popup_centered()