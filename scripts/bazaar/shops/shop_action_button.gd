extends Button
class_name ShopActionButton

@export var label_text: String = "":
	set(value):
		label_text = value
		_update_content()

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_update_content()

@export var show_icon: bool = true:
	set(value):
		show_icon = value
		_update_content()

static var _art_ready: bool = false
static var _sb_normal: StyleBoxTexture = null
static var _sb_hover: StyleBoxTexture = null
static var _sb_pressed: StyleBoxTexture = null
static var _sb_disabled: StyleBoxTexture = null


func _ready() -> void:
	flat = false
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if label_text == "" and text != "":
		label_text = text
	text = "" # always use label_text (keeps inspector clean)

	_apply_primary_md_art()
	_update_content()


func _update_content() -> void:
	if not is_node_ready():
		return

	text = label_text

	if show_icon and icon_texture != null:
		icon = icon_texture
		expand_icon = false
	else:
		icon = null


func _apply_primary_md_art() -> void:
	# Skip if caller already styled this button.
	if has_theme_stylebox_override("normal"):
		return

	if not _ensure_primary_md_art():
		return

	add_theme_stylebox_override("normal", _sb_normal)
	add_theme_stylebox_override("hover", _sb_hover)
	add_theme_stylebox_override("pressed", _sb_pressed)
	add_theme_stylebox_override("disabled", _sb_disabled)


static func _ensure_primary_md_art() -> bool:
	if _art_ready:
		return _sb_normal != null
	_art_ready = true

	var mapping: Array = [
		["normal", "ui_button_primary_md_normal"],
		["hover", "ui_button_primary_md_hover"],
		["pressed", "ui_button_primary_md_pressed"],
		["disabled", "ui_button_primary_md_disabled"],
	]

	for pair: Array in mapping:
		var tex: Texture2D = ArtReg.texture_for(pair[1])
		if tex == null:
			return false
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.draw_center = true
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		match pair[0]:
			"normal": _sb_normal = sb
			"hover": _sb_hover = sb
			"pressed": _sb_pressed = sb
			"disabled": _sb_disabled = sb

	return _sb_normal != null
