extends Control

## CurioRevealPopup — Modal popup showing a curio after crate opening.
##
## Display:
##   • Curio name (colored by rarity)
##   • Description text
##   • Family icon/label
##   • Rarity badge
##   • "Add to Stash" / "Equip to Canister" buttons

# Preload dependencies (required because class_name isn't available during autoload)
const CurioResource := preload("res://scripts/curio/curio_resource.gd")

signal popup_closed()
signal equip_requested(curio_id: String)

var _curio: CurioResource = null

const RARITY_COLORS := {
	"common": Color("#eaf7ff"),
	"uncommon": Color("#88ccff"),
	"rare": Color("#ffd66b"),
	"exotic": Color("#4a8fff"),
}

const FAMILY_LABELS := {
	"ROLL_SHAPING": "⛏ Roll Shaping",
	"REROLL_CONTROL": "🔄 Reroll Control",
	"TRIGGER": "⚡ Trigger",
	"PATTERN": "🧩 Pattern",
	"FLOW": "🌊 Flow",
	"SCALING": "📈 Scaling",
	"RULE_BENDER": "🔀 Rule Bender",
}

func show_curio(curio: CurioResource) -> void:
	_curio = curio
	if _curio == null:
		queue_free()
		return
	_build_ui()
	_animate_in()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	# Full-screen dimmer
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.75)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	# Center card
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 420)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -190
	card.offset_top = -210
	card.offset_right = 190
	card.offset_bottom = 210
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#1a0b3a")
	var rarity_col: Color = RARITY_COLORS.get(_curio.rarity, Color.WHITE)
	card_style.border_color = rarity_col
	card_style.set_border_width_all(3)
	card_style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# "CURIO ACQUIRED" header
	var header := Label.new()
	header.text = "✦ CURIO ACQUIRED ✦"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	vbox.add_child(header)

	# Rarity badge
	var rarity_badge := Label.new()
	rarity_badge.text = _curio.rarity.to_upper()
	rarity_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_badge.add_theme_font_size_override("font_size", 12)
	rarity_badge.add_theme_color_override("font_color", rarity_col)
	vbox.add_child(rarity_badge)

	# Emoji
	var emoji_lbl := Label.new()
	emoji_lbl.text = _curio.emoji
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_font_size_override("font_size", 48)
	vbox.add_child(emoji_lbl)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = _curio.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", rarity_col)
	vbox.add_child(name_lbl)

	# Family
	var family_lbl := Label.new()
	family_lbl.text = FAMILY_LABELS.get(_curio.family, _curio.family)
	family_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	family_lbl.add_theme_font_size_override("font_size", 12)
	family_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.7))
	vbox.add_child(family_lbl)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = _curio.description
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", GameData.FG_COLOR)
	vbox.add_child(desc_lbl)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var stash_btn := Button.new()
	stash_btn.text = "📦 Add to Stash"
	stash_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stash_btn.add_theme_font_size_override("font_size", 14)
	stash_btn.pressed.connect(_on_stash_pressed)
	btn_row.add_child(stash_btn)

	var equip_btn := Button.new()
	equip_btn.text = "⚡ Equip"
	equip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_btn.add_theme_font_size_override("font_size", 14)
	equip_btn.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	equip_btn.pressed.connect(_on_equip_pressed)
	btn_row.add_child(equip_btn)

func _animate_in() -> void:
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.15)

func _on_stash_pressed() -> void:
	popup_closed.emit()
	queue_free()

func _on_equip_pressed() -> void:
	if _curio:
		equip_requested.emit(_curio.id)
	popup_closed.emit()
	queue_free()