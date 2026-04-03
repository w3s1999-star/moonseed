## ThemeHelper — Centralized UI factory for Moonseed theme components.
## All methods are static. Registered as autoload in project.godot.
extends Node

# ── StyleBox Factory ──────────────────────────────────────────────

## Returns a StyleBoxFlat with the given bg, border, border_width, corner_radius.
static func make_stylebox(bg: Color, border: Color, border_width: int = 1, corner_radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_width
	sb.border_width_right = border_width
	sb.border_width_top = border_width
	sb.border_width_bottom = border_width
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	return sb

# ── Panel Styling ─────────────────────────────────────────────────

## Styles a PanelContainer with background color, border, and corner radius.
static func style_panel(panel: PanelContainer, bg: Color, border: Color, border_width: int = 1, corner_radius: int = 4) -> void:
	var sb := make_stylebox(bg, border, border_width, corner_radius)
	panel.add_theme_stylebox_override("panel", sb)

## Styles a Panel (non-container) node similarly to style_panel.
static func style_card(card: Panel, bg: Color, border: Color, border_width: int = 1, corner_radius: int = 8) -> void:
	var sb := make_stylebox(bg, border, border_width, corner_radius)
	card.add_theme_stylebox_override("panel", sb)

# ── Popup Factory ─────────────────────────────────────────────────

## Creates a standardized PopupPanel with title label, close button, and content area.
## Returns the popup (not yet shown). Call show_popup() to display.
static func create_popup(title: String, size: Vector2, content: Control) -> PopupPanel:
	var popup := PopupPanel.new()
	popup.title = title
	popup.size = size
	popup.exclusive = true
	popup.transparent_bg = true
	# Apply theme styling to the popup panel
	var sb := make_stylebox(GameData.PANEL_BG, GameData.PANEL_BORDER, 2, 8)
	popup.add_theme_stylebox_override("panel", sb)
	# Wrap content in a MarginContainer with title bar
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	# Title bar
	if title != "":
		var title_bar := HBoxContainer.new()
		title_bar.add_theme_constant_override("separation", 8)
		var title_lbl := Label.new()
		title_lbl.text = title
		title_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(16))
		title_lbl.add_theme_color_override("font_color", GameData.TEXT_PRIMARY)
		title_bar.add_child(title_lbl)
		title_bar.add_spacer(false)
		root.add_child(title_bar)
	# Content with margins
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_child(content)
	root.add_child(margin)
	popup.add_child(root)
	return popup

## Centers and shows a PopupPanel.
static func show_popup(popup: PopupPanel) -> void:
	if not is_instance_valid(popup):
		return
	popup.popup_centered()

## Hides a PopupPanel, then queue_free.
static func hide_popup(popup: PopupPanel) -> void:
	if not is_instance_valid(popup):
		return
	popup.hide()
	popup.queue_free()

# ── Button Factory ────────────────────────────────────────────────

## Creates a themed Button with the specified type and minimum size.
## Types: "primary", "secondary", "confirm", "cancel", "shop", "satchel"
static func create_button(text: String, type: String = "primary", min_size: Vector2 = Vector2(120, 36)) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	match type:
		"primary":
			style_button(btn, GameData.PANEL_BORDER, GameData.ACCENT_CURIO_CANISTER, GameData.TEXT_PRIMARY, 6)
		"secondary":
			style_button(btn, GameData.PANEL_BG_ALT, GameData.PANEL_BORDER, GameData.TEXT_SECONDARY, 6)
		"confirm":
			style_button(btn, Color("#1a3a1a"), Color("#44cc44"), Color("#aaffaa"), 6)
		"cancel":
			style_button(btn, Color("#3a1a1a"), Color("#cc4444"), Color("#ffaaaa"), 6)
		"shop":
			style_button(btn, GameData.CARD_BG_DEFAULT, GameData.ACCENT_GOLD, GameData.TEXT_GOLD, 6)
		"satchel":
			style_button(btn, GameData.SATCHEL_BTN_BG, GameData.SATCHEL_BTN_BORDER, GameData.SATCHEL_BTN_TEXT, 8)
		_:
			style_button(btn, GameData.PANEL_BG, GameData.PANEL_BORDER, GameData.TEXT_PRIMARY, 6)
	return btn

## Applies inline StyleBoxFlat overrides to a Button for normal/hover/pressed/disabled states.
static func style_button(btn: Button, bg: Color, border: Color, text_col: Color, corner_radius: int = 8) -> void:
	# Normal state
	var normal_sb := make_stylebox(bg, border, 1, corner_radius)
	normal_sb.content_margin_left = 8
	normal_sb.content_margin_right = 8
	normal_sb.content_margin_top = 4
	normal_sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", normal_sb)
	# Hover state — lighten bg and border
	var hover_bg := bg.lightened(0.12)
	var hover_border := border.lightened(0.15)
	var hover_sb := make_stylebox(hover_bg, hover_border, 1, corner_radius)
	hover_sb.content_margin_left = 8
	hover_sb.content_margin_right = 8
	hover_sb.content_margin_top = 4
	hover_sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("hover", hover_sb)
	# Pressed state — darken bg
	var pressed_bg := bg.darkened(0.15)
	var pressed_sb := make_stylebox(pressed_bg, border, 1, corner_radius)
	pressed_sb.content_margin_left = 8
	pressed_sb.content_margin_right = 8
	pressed_sb.content_margin_top = 4
	pressed_sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	# Disabled state
	var disabled_sb := make_stylebox(bg.darkened(0.3), border.darkened(0.3), 1, corner_radius)
	disabled_sb.content_margin_left = 8
	disabled_sb.content_margin_right = 8
	disabled_sb.content_margin_top = 4
	disabled_sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("disabled", disabled_sb)
	# Text color
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col.lightened(0.1))
	btn.add_theme_color_override("font_pressed_color", text_col.darkened(0.1))
	btn.add_theme_color_override("font_disabled_color", text_col.darkened(0.4))

# ── Label Factory ─────────────────────────────────────────────────

## Creates a Label with scaled font size and color.
static func create_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(font_size))
	lbl.add_theme_color_override("font_color", color)
	return lbl

# ── Separator ─────────────────────────────────────────────────────

## Creates an HSeparator with the standard theme color.
static func create_separator(color: Color = GameData.SEPARATOR_COLOR) -> HSeparator:
	var sep := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = color
	sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sb)
	return sep
