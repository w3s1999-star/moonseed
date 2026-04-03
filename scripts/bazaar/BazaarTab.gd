extends Control

# BazaarTab.gd — Lunar Bazaar environment wrapper tab.
#
# Renders the LunarBazaar 2D environment in a SubViewportContainer
# (wired in BazaarTab.tscn). Adds:
# - VendorBar: clickable vendor stall buttons along the bottom.
# - ShopOverlay: a modal overlay that hosts the vendor shop screen.

const FALLBACK_SHOP_SCENE: PackedScene = preload("res://scenes/ShopTab.tscn")

const SHOP_SCENES: Dictionary = {
	# Note: We currently map Pearl Exchange → Request Nook, since the environment
	# has 5 vendor stalls and Pearl Exchange is the closest "desk" placeholder.
	"pearl_exchange": preload("res://scenes/bazaar/RequestNookScreen.tscn"),
	"selenic_exchange": preload("res://scenes/bazaar/SelenicExchangeScreen.tscn"),
	"sweetmaker_stall": preload("res://scenes/bazaar/SweetmakerScreen.tscn"),
	"curio_dealer": preload("res://scenes/bazaar/CurioDealerScreen.tscn"),
	"dice_carver": preload("res://scenes/bazaar/DiceCarverScreen.tscn"),
}

# Display metadata for each vendor stall.
# vendor_id values must match the vendor_id exports set on BazaarVendor nodes in lunar_bazaar.tscn.
const VENDORS: Array[Dictionary] = [
	{id = "pearl_exchange",   icon = "REQ",   label = "Request Nook",     tagline = "Requests, notes, and task intake"},
	{id = "selenic_exchange", icon = "MOON",  label = "Selenic Exchange", tagline = "Offerings and moonlit trade"},
	{id = "sweetmaker_stall", icon = "SWEET", label = "Sweetmaker Stall", tagline = "Confections & sweets"},
	{id = "curio_dealer",     icon = "CUR",   label = "Curio Dealer",     tagline = "Strange relics & curiosities"},
	{id = "dice_carver",      icon = "DICE",  label = "Dice Carver",      tagline = "Fine dice, hand-carved"},
]

var _shop_overlay: Control = null
var _shop_tab_overlay: Control = null


func _ready() -> void:
	SignalBus.vendor_opened.connect(_open_vendor_shop)
	_build_vendor_bar()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		_close_shop()


# Vendor bar -------------------------------------------------------------------

func _build_vendor_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "VendorBar"
	bar.anchor_left   = 0.0
	bar.anchor_right  = 1.0
	bar.anchor_top    = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top    = -88.0
	bar.offset_bottom = 0.0
	bar.grow_vertical = GROW_DIRECTION_BEGIN
	bar.add_theme_constant_override("separation", 4)
	add_child(bar)

	for vdata: Dictionary in VENDORS:
		bar.add_child(_make_vendor_btn(vdata))


func _make_vendor_btn(vdata: Dictionary) -> Control:
	# Wrapper lets us layer styled panel + transparent click button.
	var wrapper := Control.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.custom_minimum_size   = Vector2(0, 80)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st := StyleBoxFlat.new()
	st.bg_color     = Color("#0a0820cc")
	st.border_color = Color("#8855ff")
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", st)
	wrapper.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var icon_lbl := Label.new()
	icon_lbl.text = vdata.get("icon", "") as String
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	vbox.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = vdata.get("label", "Shop") as String
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	name_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var btn := Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for skey: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(skey, empty)
	btn.mouse_entered.connect(func() -> void: st.bg_color = Color("#1a1040cc"))
	btn.mouse_exited.connect(func() -> void:  st.bg_color = Color("#0a0820cc"))
	btn.pressed.connect(func() -> void: SignalBus.vendor_opened.emit(vdata.get("id", "") as String))
	wrapper.add_child(btn)

	return wrapper


# Shop overlay -----------------------------------------------------------------

func _open_vendor_shop(vendor_id: String) -> void:
	# Handle special case for shop_tab
	if vendor_id == "shop_tab":
		_open_shop_tab()
		return
	
	if is_instance_valid(_shop_overlay):
		return

	_shop_overlay = Control.new()
	_shop_overlay.name = "ShopOverlay"
	_shop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shop_overlay)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_overlay.add_child(dimmer)

	var shop_panel := PanelContainer.new()
	shop_panel.anchor_left   = 0.0
	shop_panel.anchor_right  = 1.0
	shop_panel.anchor_top    = 0.08  # Leave space for top row buttons
	shop_panel.anchor_bottom = 0.92  # Leave space for bottom vendor bar (88px from bottom)
	shop_panel.grow_horizontal = GROW_DIRECTION_BOTH
	shop_panel.grow_vertical   = GROW_DIRECTION_BOTH
	var pst := StyleBoxFlat.new()
	pst.bg_color     = GameData.BG_COLOR
	pst.border_color = Color("#8855ff")
	pst.set_border_width_all(2)
	pst.set_corner_radius_all(8)
	shop_panel.add_theme_stylebox_override("panel", pst)
	_shop_overlay.add_child(shop_panel)

	var shop_scene: PackedScene = FALLBACK_SHOP_SCENE
	var scene_value: Variant = SHOP_SCENES.get(vendor_id, null)
	if scene_value is PackedScene:
		shop_scene = scene_value as PackedScene

	var shop_content: Control = shop_scene.instantiate() as Control
	shop_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_panel.add_child(shop_content)

	var leave_btn: BaseButton = shop_content.get_node_or_null("BackgroundRoot/RightMenuBoard/ButtonList/LeaveButton") as BaseButton
	if leave_btn != null:
		leave_btn.pressed.connect(_close_shop)

	# Play bell when opening a vendor shop
	if has_node("/root/AudioManager"):
		var am := get_node("/root/AudioManager")
		if am and am.has_method("play_bazaar_bell"):
			am.play_bazaar_bell()


func _close_shop() -> void:
	# Play bell on close
	if has_node("/root/AudioManager"):
		var amc := get_node("/root/AudioManager")
		if amc and amc.has_method("play_bazaar_bell"):
			amc.play_bazaar_bell()
	if is_instance_valid(_shop_overlay):
		_shop_overlay.queue_free()
		_shop_overlay = null

func cleanup_overlay() -> void:
	_close_shop()
	if is_instance_valid(_shop_tab_overlay):
		_shop_tab_overlay.queue_free()
		_shop_tab_overlay = null

func _open_shop_tab() -> void:
	print("DEBUG: _open_shop_tab called from BazaarTab")
	
	# Close current overlay first
	_close_shop()
	
	# Try to find the ShopTab scene directly and open it as an overlay
	var shop_tab_scene = load("res://scenes/ShopTab.tscn")
	if shop_tab_scene:
		# Create a new overlay for the ShopTab
		var shop_overlay = Control.new()
		shop_overlay.name = "ShopOverlay"
		shop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(shop_overlay)
		_shop_tab_overlay = shop_overlay

		var dimmer := ColorRect.new()
		dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dimmer.color = Color(0.0, 0.0, 0.0, 0.72)
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		shop_overlay.add_child(dimmer)

		var shop_panel := PanelContainer.new()
		shop_panel.anchor_left   = 0.0
		shop_panel.anchor_right  = 1.0
		shop_panel.anchor_top    = 0.08
		shop_panel.anchor_bottom = 0.92
		shop_panel.grow_horizontal = GROW_DIRECTION_BOTH
		shop_panel.grow_vertical   = GROW_DIRECTION_BOTH
		var pst := StyleBoxFlat.new()
		pst.bg_color     = GameData.BG_COLOR
		pst.border_color = Color("#8855ff")
		pst.set_border_width_all(2)
		pst.set_corner_radius_all(8)
		shop_panel.add_theme_stylebox_override("panel", pst)
		shop_overlay.add_child(shop_panel)

		var shop_content: Control = shop_tab_scene.instantiate() as Control
		shop_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shop_panel.add_child(shop_content)

		# Play bell when opening the full ShopTab overlay
		if has_node("/root/AudioManager"):
			var am2 := get_node("/root/AudioManager")
			if am2 and am2.has_method("play_bazaar_bell"):
				am2.play_bazaar_bell()

		print("DEBUG: Successfully opened ShopTab as overlay")
	else:
		print("DEBUG: Could not load ShopTab scene")

func refresh_shop_display() -> void:
	# If a shop overlay is open, refresh its display
	if is_instance_valid(_shop_overlay):
		for child in _shop_overlay.get_children():
			if child is Control and child.has_method("refresh_display"):
				child.call("refresh_display")


func show_dev_popup() -> void:
	if not GameData.is_debug_mode():
		return

	# If a shop overlay is open, prefer delegating the dev popup to the
	# active shop screen so each shop can expose its own debug wrench UI.
	if is_instance_valid(_shop_overlay):
		for c in _shop_overlay.get_children():
			if c is Node and c.has_method("show_dev_popup"):
				c.call_deferred("show_dev_popup")
				return

	# If already open, bring to front
	var existing := get_node_or_null("BazaarDevPopup")
	if existing != null:
		if existing.has_method("popup_centered"):
			existing.call_deferred("popup_centered")
		return

	var wnd := Popup.new()
	wnd.name = "BazaarDevPopup"
	wnd.custom_minimum_size = Vector2(380, 220)

	var vb := PanelContainer.new()
	vb.custom_minimum_size = Vector2(360, 200)
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

	var unlock_btn := Button.new()
	unlock_btn.text = "Unlock All Dice"
	unlock_btn.pressed.connect(func() -> void:
		for dt in GameData.DICE_CARVER_SHOP_ITEMS.keys():
			GameData.unlock_dice(dt)
	)
	h.add_child(unlock_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Lock All Dice"
	clear_btn.pressed.connect(func() -> void:
		for dt in GameData.DICE_CARVER_SHOP_ITEMS.keys():
			if GameData.is_dice_unlocked(dt):
				GameData.dice_inventory.erase(dt)
		Database.save_dice_inventory(GameData.dice_inventory)
	)
	h.add_child(clear_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func() -> void: wnd.hide(); wnd.queue_free())
	content.add_child(close_btn)

	add_child(wnd)
	wnd.popup_centered()
