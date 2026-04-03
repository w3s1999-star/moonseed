extends Control
class_name ShopScreenBase

# -----------------------------------------------------------------------------
# MOONSEED — Bazaar Shop Screen Base (Webkinz-inspired composition)
#
# Core layout rule:
# - LeftMerchantScene  = left 2/3 of available width (merchant room scene)
# - RightMenuBoard     = right 1/3 of available width (decorative menu board)
#
# This keeps the merchant/room as the emotional focus, with a tall stacked menu
# on the right. The ratio is enforced on resize so it stays stable across:
# - 640×360
# - 1280×720
# - and any intermediate sizes (popup overlays, different aspect windows, etc.)
# -----------------------------------------------------------------------------

const LEFT_RATIO: float = 2.0 / 3.0

@export var shop_title: String = "Shop":
	set(value):
		shop_title = value
		_apply_header_text()

@export var shop_subtitle: String = "":
	set(value):
		shop_subtitle = value
		_apply_header_text()

# Intro line shown when entering the shop (speech bubble in merchant area).
@export var dialogue_text: String = ""

# Optional speaker name shown in the speech bubble.
@export var merchant_name: String = ""

@export var intro_auto_hide_seconds: float = 3.5

@onready var _left_scene: Control = $BackgroundRoot/LeftMerchantScene
@onready var _right_board: Control = $BackgroundRoot/RightMenuBoard

@onready var _title_label: Label = $BackgroundRoot/RightMenuBoard/ShopHeader/ShopTitleLabel
@onready var _subtitle_label: Label = $BackgroundRoot/RightMenuBoard/ShopHeader/ShopSubtitleLabel
@onready var _moonpearl_label: Label = $BackgroundRoot/RightMenuBoard/ShopHeader/CurrencyRow/MoonpearlLabel

@onready var _button_list: VBoxContainer = $BackgroundRoot/RightMenuBoard/ButtonList

@onready var _dialogue_popup: PanelContainer = $DialoguePopup
@onready var _dialogue_label: Label = $DialoguePopup/PopupVBox/DialogueLabel
@onready var _name_tag_label: Label = $DialoguePopup/PopupVBox/OptionalNameTag
@onready var _dialogue_anchor: Control = $BackgroundRoot/LeftMerchantScene/DialoguePopupAnchor

var _hide_timer: Timer = null
var _dialogue_source: Object = null


func _ready() -> void:
	resized.connect(_apply_split_layout)
	_apply_split_layout()
	_apply_header_text()

	GameData.state_changed.connect(_refresh_wallet)
	_refresh_wallet()

	_wire_action_buttons()
	call_deferred("_setup_feedback")

	if not dialogue_text.is_empty():
		show_dialogue(dialogue_text, merchant_name, null, intro_auto_hide_seconds)


func _setup_feedback() -> void:
	ButtonFeedback.setup_recursive(self)


func _apply_split_layout() -> void:
	# Enforce the 2/3–1/3 split using anchors (resolution-proof).
	#
	# LeftMerchantScene:  anchor_right = 2/3
	# RightMenuBoard:     anchor_left  = 2/3
	_left_scene.anchor_left = 0.0
	_left_scene.anchor_top = 0.0
	_left_scene.anchor_right = LEFT_RATIO
	_left_scene.anchor_bottom = 1.0
	_left_scene.offset_left = 0.0
	_left_scene.offset_top = 0.0
	_left_scene.offset_right = 0.0
	_left_scene.offset_bottom = 0.0

	_right_board.anchor_left = LEFT_RATIO
	_right_board.anchor_top = 0.0
	_right_board.anchor_right = 1.0
	_right_board.anchor_bottom = 1.0
	_right_board.offset_left = 0.0
	_right_board.offset_top = 0.0
	_right_board.offset_right = 0.0
	_right_board.offset_bottom = 0.0

	# Keep dialogue bubble clamped when resizing.
	if _dialogue_popup.visible:
		call_deferred("_position_dialogue_popup")


func _apply_header_text() -> void:
	if not is_node_ready():
		return
	_title_label.text = shop_title
	_subtitle_label.text = shop_subtitle
	_subtitle_label.visible = not shop_subtitle.is_empty()


func _refresh_wallet() -> void:
	if not is_node_ready():
		return
	var wallet: Dictionary = GameData.get_wallet_stats()
	_moonpearl_label.text = str(wallet.get("moonpearls", 0))


func _on_leave_pressed() -> void:
	# Emit a signal to close the shop or hide the parent
	var parent = get_parent()
	while parent != null:
		if parent.name == "ShopOverlay":
			parent.queue_free()
			return
		parent = parent.get_parent()
	
	# Fallback: try to hide ourselves if we're in a popup/modal
	if get_parent() is Window or get_parent() is Popup:
		get_parent().hide()
	else:
		# Last resort: hide ourselves
		hide()


func _wire_action_buttons() -> void:
	for btn: ShopActionButton in _get_action_buttons():
		if btn.mouse_entered.is_connected(_on_action_hover.bind(btn)):
			continue
		btn.mouse_entered.connect(_on_action_hover.bind(btn))
		btn.focus_entered.connect(_on_action_hover.bind(btn))
		btn.mouse_exited.connect(_on_action_unhover.bind(btn))
		btn.focus_exited.connect(_on_action_unhover.bind(btn))
		
		# Connect leave button to close the shop
		if btn.label_text == "Leave":
			if not btn.pressed.is_connected(_on_leave_pressed):
				btn.pressed.connect(_on_leave_pressed)


func _get_action_buttons() -> Array[ShopActionButton]:
	var result: Array[ShopActionButton] = []
	var list_node: Node = get_node_or_null("BackgroundRoot/RightMenuBoard/ButtonList")
	if list_node == null or not is_instance_valid(list_node):
		return result
	for child: Node in list_node.get_children():
		var btn: ShopActionButton = child as ShopActionButton
		if btn != null:
			result.append(btn)
	return result


func set_action_labels(labels: Array[String]) -> void:
	# Expects 4–6 labels including a Leave entry.
	var buttons := _get_action_buttons()
	for i: int in range(buttons.size()):
		var btn := buttons[i]
		if i < labels.size():
			btn.label_text = labels[i]
			btn.visible = true
		else:
			btn.visible = false


func set_button_dialogue(label_to_line: Dictionary) -> void:
	# Optional helper: provide { "Browse Relics": "Merchant line..." } mapping.
	for btn: ShopActionButton in _get_action_buttons():
		var line: String = label_to_line.get(btn.label_text, "") as String
		if not line.is_empty():
			btn.set_meta("merchant_line", line)


func _on_action_hover(btn: ShopActionButton) -> void:
	var line := ""
	if btn.has_meta("merchant_line"):
		line = btn.get_meta("merchant_line") as String
	if line.is_empty():
		return
	show_dialogue(line, merchant_name, btn, 0.0)


func _on_action_unhover(btn: ShopActionButton) -> void:
	if _dialogue_source != btn:
		return
	hide_dialogue(0.10)


func show_dialogue(text: String, name_tag: String = "", source: Object = null, auto_hide_seconds: float = 0.0) -> void:
	_dialogue_source = source
	_dialogue_label.text = text
	_name_tag_label.text = name_tag
	_name_tag_label.visible = not name_tag.is_empty()

	_dialogue_popup.visible = true
	_dialogue_popup.modulate = Color(1, 1, 1, 0)
	_dialogue_popup.scale = Vector2(0.96, 0.96)

	call_deferred("_position_dialogue_popup")

	var tw := create_tween()
	tw.tween_property(_dialogue_popup, "modulate", Color(1, 1, 1, 1), 0.12)
	tw.parallel().tween_property(_dialogue_popup, "scale", Vector2(1, 1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if auto_hide_seconds > 0.0:
		_ensure_hide_timer()
		_hide_timer.stop()
		_hide_timer.wait_time = auto_hide_seconds
		_hide_timer.start()


func hide_dialogue(fade_seconds: float = 0.12) -> void:
	_dialogue_source = null
	if _hide_timer != null:
		_hide_timer.stop()
	if not _dialogue_popup.visible:
		return
	var tw := create_tween()
	tw.tween_property(_dialogue_popup, "modulate", Color(1, 1, 1, 0), fade_seconds)
	tw.parallel().tween_property(_dialogue_popup, "scale", Vector2(0.98, 0.98), fade_seconds)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_dialogue_popup):
			_dialogue_popup.visible = false
	)


func _ensure_hide_timer() -> void:
	if _hide_timer != null:
		return
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	add_child(_hide_timer)
	_hide_timer.timeout.connect(func() -> void: hide_dialogue(0.12))


func _position_dialogue_popup() -> void:
	if not is_node_ready():
		return
	if not _dialogue_popup.visible:
		return

	# Position near the anchor, but clamp within the left merchant region.
	var left_rect := Rect2(_left_scene.global_position, _left_scene.size)

	_dialogue_popup.pivot_offset = _dialogue_popup.size * 0.5

	var target: Vector2 = _dialogue_anchor.global_position + Vector2(18, -8)
	var bubble_size: Vector2 = _dialogue_popup.size

	var min_x: float = left_rect.position.x + 8.0
	var max_x: float = left_rect.position.x + left_rect.size.x - bubble_size.x - 8.0
	var min_y: float = left_rect.position.y + 8.0
	var max_y: float = left_rect.position.y + left_rect.size.y - bubble_size.y - 8.0

	var clamped := Vector2(
		clamp(target.x, min_x, max_x),
		clamp(target.y, min_y, max_y)
	)
	_dialogue_popup.global_position = clamped.round()
