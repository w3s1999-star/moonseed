# ─────────────────────────────────────────────────────────────────
# ShopTab.gd – Dice box seeded Balatro-style shop + Coin Store
# ─────────────────────────────────────────────────────────────────

extends Control

var _shop_items_container: HFlowContainer
var _timer_label: Label
var _wallet_label: Label
var _owned_container: VBoxContainer
var _timer: Timer

func _ready() -> void:
	GameData.state_changed.connect(_refresh)
	if has_node("/root/SignalBus"):
		SignalBus.theme_changed.connect(_on_theme_changed_shop)
	GameData.debug_mode_changed.connect(_on_debug_mode_changed_shop)
	_build_ui()
	_refresh()
	_start_shop_timer()
	call_deferred("_setup_feedback")

func _setup_feedback() -> void:
	if has_node("/root/ButtonFeedback"):
		get_node("/root/ButtonFeedback").setup_recursive(self)

func _build_ui() -> void:
	for _c in get_children(): _c.queue_free()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 15)
	scroll.add_child(vbox)

	# Header
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)

	var lbl_title: Label = Label.new()
	lbl_title.text = "🛒 SATCHEL SHOP"
	lbl_title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	lbl_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl_title)

	_timer_label = Label.new()
	_timer_label.text = "Refreshes in: —"
	_timer_label.add_theme_color_override("font_color", GameData.ACCENT_BLUE)
	header.add_child(_timer_label)

	_wallet_label = Label.new()
	_wallet_label.text = "🌙 0"
	_wallet_label.add_theme_color_override("font_color", Color("#FFD700"))
	_wallet_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	header.add_child(_wallet_label)

	# Shop grid
	var lbl_available := Label.new()
	lbl_available.text = "── TODAY'S OFFERINGS ──"
	lbl_available.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_available.add_theme_color_override("font_color", GameData.FG_COLOR)
	vbox.add_child(lbl_available)

	_shop_items_container = HFlowContainer.new()
	_shop_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_items_container.add_theme_constant_override("h_separation", 10)
	_shop_items_container.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_shop_items_container)

	# Coin shop section
	var coin_sep: HSeparator = HSeparator.new()
	vbox.add_child(coin_sep)

	var lbl_coin_shop: Label = Label.new()
	lbl_coin_shop.text = "── 🌙 MOONPEARL STORE ──"
	lbl_coin_shop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_coin_shop.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	vbox.add_child(lbl_coin_shop)

	var coin_items_container: HFlowContainer = HFlowContainer.new()
	coin_items_container.name = "CoinItems"
	coin_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coin_items_container.add_theme_constant_override("h_separation", 10)
	coin_items_container.add_theme_constant_override("v_separation", 10)
	vbox.add_child(coin_items_container)

	# Owned items
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	var lbl_owned: Label = Label.new()
	lbl_owned.text = "── YOUR PERMANENT SATCHEL ──"
	lbl_owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_owned.add_theme_color_override("font_color", GameData.ACCENT_CURIO_CANISTER)
	vbox.add_child(lbl_owned)

	_owned_container = VBoxContainer.new()
	vbox.add_child(_owned_container)

	# Debug panel (only visible in debug mode)
	if GameData.is_debug_mode():
		var dbg_sep: HSeparator = HSeparator.new()
		vbox.add_child(dbg_sep)
		var dbg_panel: PanelContainer = PanelContainer.new()
		var dbg_st := StyleBoxFlat.new()
		dbg_st.bg_color = Color(0.12, 0.03, 0.03, 0.95)
		dbg_st.border_color = GameData.ACCENT_RED
		dbg_st.set_border_width_all(1); dbg_st.set_corner_radius_all(4)
		dbg_panel.add_theme_stylebox_override("panel", dbg_st)
		vbox.add_child(dbg_panel)
		var dbg_vb: VBoxContainer = VBoxContainer.new(); dbg_vb.add_theme_constant_override("separation", 4)
		dbg_panel.add_child(dbg_vb)
		var dbg_title: Label = Label.new(); dbg_title.text = "🔧  DEBUG SHOP"
		dbg_title.add_theme_color_override("font_color", GameData.ACCENT_RED)
		dbg_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		dbg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dbg_vb.add_child(dbg_title)
		var hint_lbl: Label = Label.new()
		hint_lbl.text = "Use ＋/－ on owned items above to change count.\nOr reset all owned items below."
		hint_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.5))
		hint_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dbg_vb.add_child(hint_lbl)
		var reset_btn: Button = Button.new(); reset_btn.text = "🗑 RESET ALL OWNED ITEMS"
		reset_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		reset_btn.add_theme_color_override("font_color", GameData.ACCENT_RED)
		reset_btn.pressed.connect(_debug_reset_shop)
		dbg_vb.add_child(reset_btn)
		# GDD §4: Debug Seed override
		var seed_row := HBoxContainer.new(); seed_row.add_theme_constant_override("separation", 3); dbg_vb.add_child(seed_row)
		var seed_lbl := Label.new(); seed_lbl.text = "Seed:"
		seed_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
		seed_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9)); seed_row.add_child(seed_lbl)
		var seed_entry := LineEdit.new(); seed_entry.placeholder_text = "Override date seed..."
		seed_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL; seed_row.add_child(seed_entry)
		var seed_btn := Button.new(); seed_btn.text = "Apply"
		seed_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		seed_btn.pressed.connect(func():
			var v := seed_entry.text.strip_edges()
			if v.is_valid_int():
				Database.save_setting("debug_shop_seed", int(v))
				_refresh()
				_build_shop_items()
		)
		seed_row.add_child(seed_btn)
		# GDD §4: Grant Currency
		var curr_row := HBoxContainer.new(); curr_row.add_theme_constant_override("separation", 3); dbg_vb.add_child(curr_row)
		for e: Array in [["🌙 +100 Moonpearls", func(): _debug_grant_moonpearls(100)],
				  ["🌙 +500 Moonpearls", func(): _debug_grant_moonpearls(500)],
				  ["🌙 +1000 Moonpearls", func(): _debug_grant_moonpearls(1000)]]:
			var b := Button.new(); b.text = e[0]
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
			b.pressed.connect(e[1] as Callable); curr_row.add_child(b)

func _make_shop_card(item: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 240)

	var rarity: String = item.get("rarity", "common")
	var style := StyleBoxFlat.new()
	style.bg_color = GameData.RARITY_BG.get(rarity, GameData.CARD_BG)
	style.border_color = GameData.RARITY_COLORS.get(rarity, GameData.FG_COLOR)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)

	# Title
	var title := Label.new()
	title.text = item.get("name", "Item")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	inner.add_child(title)

	# Description
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = false
	desc.scroll_active = false
	desc.custom_minimum_size = Vector2(0, 80)
	desc.text = item.get("desc", "")
	desc.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	inner.add_child(desc)

	# Cost row
	var cost_row := HBoxContainer.new()
	cost_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_row.add_theme_constant_override("separation", 8)
	inner.add_child(cost_row)

	var pearl_cost: int = item.get("pearl_cost", int(item.get("price", 1)))
	if pearl_cost <= 0: pearl_cost = 1
	var price_row: HBoxContainer = GameData.make_moondrop_row(pearl_cost, GameData.scaled_font_size(12))
	if price_row.get_child_count() > 1:
		(price_row.get_child(1) as Label).add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	price_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_row.add_child(price_row)

	# Action area
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 6)
	inner.add_child(actions)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.custom_minimum_size = Vector2(0, 40)
	buy_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	buy_btn.pressed.connect(func(): _buy_item(item))
	actions.add_child(buy_btn)

	var secondary := HBoxContainer.new()
	secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary.add_theme_constant_override("separation", 8)
	actions.add_child(secondary)

	var preview := Button.new()
	preview.text = "Preview"
	preview.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	preview.pressed.connect(func(): _show_msg("Preview not implemented."))
	secondary.add_child(preview)

	if str(item.get("type", "")) == "dice":
		var inventory := Database.get_inventory()
		var owned_count := int(inventory.get(str(item.get("sides", 6)), 0))
		var owned_lbl := Label.new()
		owned_lbl.text = "You have: %d" % owned_count
		owned_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		owned_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.7))
		secondary.add_child(owned_lbl)

	return panel

func _refresh() -> void:
	var wallet: Dictionary = GameData.get_wallet_stats()
	_wallet_label.text = "🌙 %d" % wallet.get("moonpearls", 0)
	_build_shop_items()
	_build_owned_items()
	call_deferred("_setup_feedback")

func _build_shop_items() -> void:
	for child in _shop_items_container.get_children():
		child.queue_free()

	# Standard dice box cash items
	var dice_box_items: Array = GameData.get_dice_box_shop(GameData.view_date, 6)
	for item in dice_box_items:
		var card := _make_shop_card(item)
		_shop_items_container.add_child(card)

	# Build coin store items (Fixed finding logic)
	var coin_container: Control = null
	for child in get_tree().get_nodes_in_group("coin_store_parent"): # Optimization or manual find
		pass 
	# Manual find within current UI hierarchy
	coin_container = find_child("CoinItems", true, false)
	
	if not coin_container: return
	for c in coin_container.get_children(): c.queue_free()

	var coin_catalog := [
		{id="shop_trowel",      name="Garden Trowel",        icon="🪚", cost=1,
		 desc="Move plants in the garden.",                  type="tool"},
		{id="shop_fertilizer",  name="Fertilizer",           icon="🌱", cost=1,
		 desc="Boost a plant by 1 growth stage.",            type="tool"},
		{id="shop_fertilizer_b",name="Blessed Fertilizer",  icon="✨", cost=1,
		 desc="+1 stage and tiny mult bonus.",               type="tool"},
		{id="shop_fertilizer_s",name="Selenium Fertilizer", icon="⚗",  cost=1,
		 desc="Rare mineral. Guarantees max stage.",         type="tool"},
		{id="bg_purple",        name="Purple Test BG",      icon="🟣", cost=1,
		 desc="Solid purple rolling area background.",       type="background"},
		{id="dec_gnome",        name="Garden Gnome",        icon="🪆", cost=1,
		 desc="G — A cheerful little gnome.",                type="decor"},
		{id="dec_flamingo",     name="Plastic Flamingo",    icon="🦩", cost=1,
		 desc="F — Hot pink plastic flamingo.",              type="decor"},
		{id="dec_birdbath",     name="Bird Bath",           icon="🐦", cost=1,
		 desc="B — Stone bird bath / fountain.",             type="decor"},
		{id="dec_lantern",      name="Stone Lantern",       icon="🏮", cost=1,
		 desc="S — Glowing stone lantern.",                  type="decor"},
		{id="dec_pot",          name="Flower Pot",          icon="🪴", cost=1,
		 desc="P — Terracotta planter.",                     type="decor"},
		{id="dec_bench",        name="Garden Bench",        icon="🪑", cost=1,
		 desc="N — Wooden garden bench.",                    type="decor"},
		{id="dec_fence",        name="Fence Section",       icon="🔲", cost=1,
		 desc="W — Wooden picket fence section.",            type="decor"},
		{id="dec_windchimes",   name="Wind Chimes",         icon="🎐", cost=1,
		 desc="C — Delicate wind chimes.",                   type="decor"},
	]
	
	var pearls: int = Database.get_moonpearls()
	for item in coin_catalog:
		coin_container.add_child(_make_coin_shop_card(item, pearls))

func _make_coin_shop_card(item: Dictionary, pearls: int) -> PanelContainer:
	var owned: bool = Database.has_shop_item(item.id, GameData.current_profile)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 200)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0d1a0d") if owned else GameData.CARD_BG
	style.border_color = Color("#44cc44") if owned else GameData.ACCENT_GOLD
	style.set_border_width_all(2); style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)

	var title := Label.new()
	title.text = item.name as String
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	inner.add_child(title)

	var desc := Label.new()
	desc.text = item.desc as String
	desc.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	desc.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.8))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 70)
	inner.add_child(desc)

	var price_row: HBoxContainer = GameData.make_moondrop_row(int(item.cost), GameData.scaled_font_size(12))
	if price_row.get_child_count() > 1:
		(price_row.get_child(1) as Label).add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	price_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(price_row)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	inner.add_child(actions)

	var buy_btn := Button.new()
	buy_btn.text = "✓ OWNED" if owned else "Buy"
	buy_btn.disabled = owned or (Database.get_bool("debug_purchase_enabled", false) == false and Database.get_moonpearls() < int(item.cost))
	if not owned:
		buy_btn.pressed.connect(func(): _buy_pearl_item(item))
	actions.add_child(buy_btn)

	var preview := Button.new()
	preview.text = "Preview"
	preview.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	preview.pressed.connect(func(): _show_msg("Preview not implemented."))
	actions.add_child(preview)

	return panel

func _buy_item(item: Dictionary) -> void:
	var debug_buy: bool = Database.get_bool("debug_purchase_enabled", false)
	var cost: int = item.get("pearl_cost", int(item.get("price", 1.0)))
	if cost <= 0: cost = 1
	var item_type: String = item.get("type", "")

	if item_type == "dice":
		var dice_id := "d" + str(item.get("sides", 6))
		if not GameData.purchase_dice(dice_id, 1):
			_show_msg("Not enough Moonpearls!\nYou need 🌙 %d" % cost)
			return
		GameData.state_changed.emit()
		_show_msg("Purchased: %s %s" % [item.get("emoji", ""), item.get("name", item.id)])
		_refresh()
		return

	if not debug_buy and not Database.spend_moonpearls(cost, GameData.current_profile):
		_show_msg("Not enough Moonpearls!\nYou need 🌙 %d" % cost)
		return

	if item_type in ["curio_canister", "util"]:
		Database.add_shop_item(item.id, GameData.current_profile)
		if item.id not in GameData.jokers_owned:
			GameData.jokers_owned.append(item.id)
	elif item_type == "bg":
		Database.add_shop_item(item.id, GameData.current_profile)
		Database.save_setting("dice_table_bg", item.get("color", "#660099"))
		var play_tab = get_tree().get_root().find_child("PlayTab", true, false)
		if play_tab:
			var dice_table = play_tab.find_child("DiceTable", true, false)
			if dice_table and dice_table.has_method("set_bg_color"):
				dice_table.set_bg_color(Color(item.get("color", "#660099")))
	else:
		Database.add_shop_item(item.id, GameData.current_profile)

	GameData.state_changed.emit()
	_show_msg("Purchased: %s %s" % [item.get("emoji", ""), item.get("name", item.id)])
	_refresh()

func _buy_pearl_item(item: Dictionary) -> void:
	var debug_buy: bool = Database.get_bool("debug_purchase_enabled", false)
	if not debug_buy and not Database.spend_moonpearls(int(item.cost), GameData.current_profile):
		_show_msg("Not enough Moonpearls!\nYou need 🌙 %d" % item.cost)
		return
	Database.add_shop_item(item.id, GameData.current_profile)
	GameData.state_changed.emit()
	_show_msg("Purchased: %s %s" % [item.icon, item.name])
	_refresh()

func _build_owned_items() -> void:
	for child in _owned_container.get_children():
		child.queue_free()

	var owned := Database.get_shop_owned(GameData.current_profile)
	if owned.is_empty():
		var lbl := Label.new()
		lbl.text = "Nothing purchased yet."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.3))
		_owned_container.add_child(lbl)
		return

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	_owned_container.add_child(flow)

	for owned_rec in owned:
		var item_id: String = owned_rec.get("item_id","")
		var catalog_item = _find_catalog_item(item_id)
		if not catalog_item: continue

		var mini_panel := PanelContainer.new()
		mini_panel.custom_minimum_size = Vector2(140, 70)
		var style := StyleBoxFlat.new()
		style.bg_color = GameData.CARD_BG
		style.border_color = GameData.ACCENT_CURIO_CANISTER
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		mini_panel.add_theme_stylebox_override("panel", style)

		var vb := VBoxContainer.new()
		mini_panel.add_child(vb)

		var lbl := Label.new()
		lbl.text = "%s %s" % [catalog_item.get("emoji", "✦"), catalog_item.name]
		lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(lbl)

		var sell_btn := Button.new()
		sell_btn.text = "Sell"
		sell_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		sell_btn.pressed.connect(func(): _sell_item(item_id))
		vb.add_child(sell_btn)

		# Debug: +/- quantity buttons
		if GameData.is_debug_mode():
			var qty_row := HBoxContainer.new(); qty_row.add_theme_constant_override("separation", 2)
			vb.add_child(qty_row)
			var minus_btn := Button.new(); minus_btn.text = "－"
			minus_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
			minus_btn.custom_minimum_size = Vector2(22, 0)
			minus_btn.pressed.connect(func(): _debug_dec_item(item_id))
			qty_row.add_child(minus_btn)
			var plus_btn := Button.new(); plus_btn.text = "＋"
			plus_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
			plus_btn.custom_minimum_size = Vector2(22, 0)
			plus_btn.pressed.connect(func(): _debug_inc_item(item_id))
			qty_row.add_child(plus_btn)

		flow.add_child(mini_panel)

func _debug_inc_item(item_id: String) -> void:
	if not GameData.is_debug_mode(): return
	Database.add_shop_item(item_id, GameData.current_profile)
	_refresh()

func _debug_dec_item(item_id: String) -> void:
	if not GameData.is_debug_mode(): return
	Database.remove_shop_item(item_id, GameData.current_profile)
	_refresh()

func _debug_reset_shop() -> void:
	if not GameData.is_debug_mode(): return
	var owned := Database.get_shop_owned(GameData.current_profile)
	for rec in owned:
		Database.remove_shop_item(rec.get("item_id",""), GameData.current_profile)
	GameData.state_changed.emit()
	_refresh()

func _sell_item(item_id: String) -> void:
	Database.remove_shop_item(item_id, GameData.current_profile)
	if item_id in GameData.jokers_owned:
		GameData.jokers_owned.erase(item_id)
	_refresh()

func _find_catalog_item(item_id: String) -> Dictionary:
	# Search standard catalog
	for item in GameData.SHOP_CATALOG:
		if item.id == item_id: return item
	# Search coin items (re-generating local list for lookup)
	# In a real app, move coin_catalog to GameData for easier access
	return {"name": item_id, "emoji": "📦"} 

func _start_shop_timer() -> void:
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.autostart = true
	_timer.timeout.connect(_update_timer)
	add_child(_timer)

func _update_timer() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var secs_until_midnight: int = (23 - int(now.hour)) * 3600 + (59 - int(now.minute)) * 60 + (59 - int(now.second))
	var h: int = int(secs_until_midnight / 3600.0)
	var m: int = int((secs_until_midnight % 3600) / 60.0)
	var s: int = secs_until_midnight % 60
	_timer_label.text = "Refreshes in: %02d:%02d:%02d" % [h, m, s]

func _show_msg(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Shop"
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_theme_changed_shop() -> void:
	_build_ui()
	_refresh()

func _on_debug_mode_changed_shop(_on: bool) -> void:
	_build_ui()
	_refresh()

func _open_pack(pack_item: Dictionary) -> void:
	var count: int = 3 if pack_item.id == "booster" else 1
	var pool: Array = GameData.SHOP_CATALOG
	var revealed := []
	for i in range(count):
		revealed.append(pool[randi() % pool.size()])

	var msg := "📦 Pack Contents:\n"
	for item in revealed:
		msg += "  %s %s\n" % [item.get("emoji", ""), item.name]
		Database.add_shop_item(item.id, GameData.current_profile)
	_show_msg(msg)
	_refresh()

func _debug_grant_moonpearls(amount: int) -> void:
	if not GameData.is_debug_mode(): return
	Database.add_moonpearls(amount, GameData.current_profile)
	_refresh()
