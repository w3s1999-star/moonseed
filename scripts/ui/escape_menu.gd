extends CanvasLayer

## EscapeMenu — Global pause/escape overlay for Moonseed
## Handles Escape toggle, modal backdrop, Settings/Credits/Quit routing.
## process_mode = ALWAYS so it stays interactive while tree is paused.

signal menu_opened
signal menu_closed

var _is_open: bool = false
var _backdrop: ColorRect
var _panel: PanelContainer
var _credits_popup: PanelContainer
var _quit_dialog: ConfirmationDialog
var _version_label: Label
var _resume_button: Button

const LAYER_INDEX := 10

func _ready() -> void:
	layer = LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _build_ui() -> void:
	# ── Full-screen backdrop ──────────────────────────────────────
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color("#0d0520", 0.85)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	# ── Center container ──────────────────────────────────────────
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# ── Menu panel ────────────────────────────────────────────────
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = GameData.CARD_BG
	panel_style.border_color = GameData.ACCENT_BLUE
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# ── Title ─────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "🌱  MOONSEED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
	title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(GameData.ACCENT_BLUE, 0.3))
	vbox.add_child(sep)

	# ── Buttons ───────────────────────────────────────────────────
	_resume_button = _make_menu_button("▶  Resume")
	_resume_button.pressed.connect(_on_resume_pressed)
	vbox.add_child(_resume_button)

	var settings_btn := _make_menu_button("⚙  Settings")
	settings_btn.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings_btn)

	var credits_btn := _make_menu_button("📜  Credits")
	credits_btn.pressed.connect(_on_credits_pressed)
	vbox.add_child(credits_btn)

	var return_btn := _make_menu_button("🏠  Return to Title")
	return_btn.pressed.connect(_on_return_to_title_pressed)
	vbox.add_child(return_btn)

	# Separator before quit
	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("separator", Color(GameData.ACCENT_BLUE, 0.3))
	vbox.add_child(sep2)

	var quit_btn := _make_menu_button("🚪  Quit")
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

	# ── Version label ─────────────────────────────────────────────
	_version_label = Label.new()
	_version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.7.0"))
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	_version_label.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.3))
	vbox.add_child(_version_label)

	# ── Credits popup (hidden by default) ─────────────────────────
	_credits_popup = PanelContainer.new()
	_credits_popup.visible = false
	_credits_popup.custom_minimum_size = Vector2(400, 0)
	_credits_popup.mouse_filter = Control.MOUSE_FILTER_PASS

	var credits_style := StyleBoxFlat.new()
	credits_style.bg_color = GameData.CARD_BG
	credits_style.border_color = GameData.ACCENT_GOLD
	credits_style.set_border_width_all(2)
	credits_style.set_corner_radius_all(8)
	credits_style.content_margin_left = 24
	credits_style.content_margin_right = 24
	credits_style.content_margin_top = 20
	credits_style.content_margin_bottom = 20
	_credits_popup.add_theme_stylebox_override("panel", credits_style)

	var credits_vbox := VBoxContainer.new()
	credits_vbox.add_theme_constant_override("separation", 10)
	_credits_popup.add_child(credits_vbox)

	var credits_title := Label.new()
	credits_title.text = "✨  CREDITS"
	credits_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_title.add_theme_font_size_override("font_size", GameData.scaled_font_size(18))
	credits_title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	credits_vbox.add_child(credits_title)

	var credits_sep := HSeparator.new()
	credits_sep.add_theme_color_override("separator", Color(GameData.ACCENT_GOLD, 0.3))
	credits_vbox.add_child(credits_sep)

	var credits_body := Label.new()
	credits_body.text = (
		"Moonseed\n"
		+ "A lunar habit tracker with dice mechanics\n\n"
		+ "Developer: Aubrey\n"
		+ "Engine: Godot 4.6\n"
		+ "Version: %s"
	) % str(ProjectSettings.get_setting("application/config/version", "0.7.0"))
	credits_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_body.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	credits_body.add_theme_color_override("font_color", GameData.FG_COLOR)
	credits_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits_vbox.add_child(credits_body)

	var credits_close := Button.new()
	credits_close.text = "Close"
	credits_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	credits_close.custom_minimum_size = Vector2(120, 36)
	credits_close.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	credits_close.pressed.connect(_on_credits_close_pressed)
	credits_vbox.add_child(credits_close)

	add_child(_credits_popup)

	# ── Quit confirmation dialog ──────────────────────────────────
	_quit_dialog = ConfirmationDialog.new()
	_quit_dialog.title = "Quit Moonseed?"
	_quit_dialog.dialog_text = "Are you sure you want to quit?"
	_quit_dialog.get_ok_button().text = "Quit"
	_quit_dialog.get_cancel_button().text = "Cancel"
	_quit_dialog.confirmed.connect(_on_quit_confirmed)
	_quit_dialog.canceled.connect(_on_quit_canceled)
	add_child(_quit_dialog)

func _make_menu_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))

	# Style to match Moonseed's calm aesthetic
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color("#1a0b3a", 0.8)
	normal_sb.border_color = Color("#099EA9", 0.3)
	normal_sb.set_border_width_all(1)
	normal_sb.set_corner_radius_all(6)
	normal_sb.content_margin_left = 16
	normal_sb.content_margin_right = 16
	normal_sb.content_margin_top = 8
	normal_sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal_sb)

	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = Color("#291560", 0.9)
	hover_sb.border_color = GameData.ACCENT_BLUE
	hover_sb.set_border_width_all(1)
	hover_sb.set_corner_radius_all(6)
	hover_sb.content_margin_left = 16
	hover_sb.content_margin_right = 16
	hover_sb.content_margin_top = 8
	hover_sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("hover", hover_sb)

	var pressed_sb := StyleBoxFlat.new()
	pressed_sb.bg_color = Color("#099EA9", 0.3)
	pressed_sb.border_color = GameData.ACCENT_BLUE
	pressed_sb.set_border_width_all(2)
	pressed_sb.set_corner_radius_all(6)
	pressed_sb.content_margin_left = 16
	pressed_sb.content_margin_right = 16
	pressed_sb.content_margin_top = 8
	pressed_sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	return btn

# ── Public API ────────────────────────────────────────────────────

func toggle() -> void:
	if _is_open:
		close()
	else:
		open()

func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_credits_popup.visible = false
	_panel.visible = true
	get_tree().paused = true
	menu_opened.emit()

	# Set focus on Resume button for keyboard navigation
	if is_instance_valid(_resume_button):
		_resume_button.grab_focus()

	# Subtle fade-in
	_backdrop.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.95, 0.95)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_backdrop, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	get_tree().paused = false
	menu_closed.emit()

	# Subtle fade-out
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_backdrop, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
	await tw.finished
	visible = false
	_panel.scale = Vector2.ONE

func is_open() -> bool:
	return _is_open

# ── Button Handlers ───────────────────────────────────────────────

func _on_resume_pressed() -> void:
	close()

func _on_settings_pressed() -> void:
	close()
	GameData.tab_requested.emit("settings")

func _on_credits_pressed() -> void:
	_panel.visible = false
	_credits_popup.visible = true

func _on_credits_close_pressed() -> void:
	_credits_popup.visible = false
	_panel.visible = true

func _on_return_to_title_pressed() -> void:
	# TODO: Implement when a title/main menu screen exists
	# For now, just close the menu
	close()

func _on_quit_pressed() -> void:
	_quit_dialog.popup_centered()

func _on_quit_confirmed() -> void:
	get_tree().quit()

func _on_quit_canceled() -> void:
	# Return to menu
	pass