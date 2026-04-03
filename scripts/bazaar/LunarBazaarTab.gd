extends Control

# ─────────────────────────────────────────────────────────────────
# LunarBazaarTab.gd  –  Coin economy screen
# Hold the PRESS button to mint 1 coin per second.
# Requires at least 1 meal today. Costs 100 moonpearls per coin.
#
# v0.9.0: Now backed by LunarBazaarTab.tscn.
#         @onready vars wire to scene nodes. _build_ui() will skip
#         if node refs are valid (scene already provides chrome).
# ─────────────────────────────────────────────────────────────────

# ── @onready — scene node wiring ─────────────────────────────────
@onready var _moonpearls_lbl_label: Label = $ScrollContainer/RootVBox/WalletRow/MoonpearlsHBox/MoonpearlsLabel
@onready var _rate_lbl: Label               = $ScrollContainer/RootVBox/InfoSection/InfoVBox/RateLabel
@onready var _meals_lbl: Label              = $ScrollContainer/RootVBox/InfoSection/InfoVBox/MealsLabel

# ── Wallet HBox refs (kept for legacy _build_ui compat) ──────────
var _moonpearls_lbl: HBoxContainer

func _ready() -> void:
	GameData.state_changed.connect(_refresh)
	if has_node("/root/SignalBus"):
		SignalBus.theme_changed.connect(_on_theme_changed)
		SignalBus.moonpearls_changed.connect(func(_v): _refresh())
	_build_ui()
	call_deferred("_refresh")
	call_deferred("_check_intro")

func _on_theme_changed() -> void:
	_build_ui()
	_refresh()

## Coin minting removed. Bazaar no longer mints coins; Moonpearls are the canonical currency.

func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "🌙  LUNAR BAZAAR"
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Explore merchants, trade, and spend Moonpearls in the Bazaar."
	subtitle.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.55))
	subtitle.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Info / Stats panel (Moonpearls only)
	var stats: GridContainer = GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 20)
	stats.add_theme_constant_override("v_separation", 6)
	vbox.add_child(stats)

	var dust_key: Label = Label.new(); dust_key.text = "Moonpearls:"
	dust_key.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.65))
	dust_key.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	stats.add_child(dust_key)
	_moonpearls_lbl = GameData.make_moondrop_row(0, GameData.scaled_font_size(13))
	if _moonpearls_lbl.get_child_count() > 1:
		(_moonpearls_lbl.get_child(1) as Label).add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	stats.add_child(_moonpearls_lbl)

	_rate_lbl  = _stat_lbl(stats, "⚡ Bazaar Activity:", "—")
	_meals_lbl = _stat_lbl(stats, "🍽 Meals today:", "0 / 3")

	var upg_lbl: Label = Label.new()
	upg_lbl.text = "💡 Visit Gallery → Gear to upgrade Bazaar services."
	upg_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.4))
	upg_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	upg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(upg_lbl)

func _stat_lbl(parent: GridContainer, key: String, val_default: String) -> Label:
	var k := Label.new(); k.text = key
	k.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.65))
	k.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	parent.add_child(k)
	var v := Label.new(); v.text = val_default
	v.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	v.add_theme_font_size_override("font_size", GameData.scaled_font_size(13))
	parent.add_child(v)
	return v

func _refresh() -> void:
	var meals: int    = Database.get_meals_today()
	var moonpearls: int = Database.get_moonpearls()
	if is_instance_valid(_moonpearls_lbl):
		GameData.set_moondrop_amount(_moonpearls_lbl, moonpearls)

	_meals_lbl.text = "%d / 3" % meals

	# Update simple Bazaar activity label
	if is_instance_valid(_rate_lbl):
		_rate_lbl.text = "Open"

func _check_intro() -> void:
	var seen: bool = bool(Database.get_setting("lunar_bazaar_intro_seen", false))
	if not seen:
		Database.save_setting("lunar_bazaar_intro_seen", true)
		await get_tree().create_timer(0.8).timeout
		# Show welcome message via UI popup instead of mascot
		var popup := AcceptDialog.new()
		popup.title = "Welcome to the Lunar Bazaar! 🌙"
		popup.dialog_text = "Explore merchants and spend Moonpearls on curios and services."
		popup.ok_button_text = "Thanks!"
		add_child(popup)
		popup.popup_centered()
		popup.confirmed.connect(func(): popup.queue_free())
