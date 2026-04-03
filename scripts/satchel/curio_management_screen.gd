extends Control

## CurioManagementScreen — Standalone curio management UI
## Supersedes the inline curio canisters section in SatchelTab.
## Dual-panel layout: owned curios (left) | canisters (right).

const CARD_BASE_TEXTURES := {
	"white": "res://assets/textures/Card Base/Card_Base_White.png",
	"blue": "res://assets/textures/Card Base/Card_Base_Blue.png",
	"green": "res://assets/textures/Card Base/Card_Base_Green.png",
	"brown": "res://assets/textures/Card Base/Card_Base_Brown.png",
}
const CARD_COLOR_ORDER := ["white", "blue", "green", "brown"]
const CARD_COLOR_LABELS := {
	"white": "White",
	"blue": "Blue",
	"green": "Green",
	"brown": "Brown",
}
const SATCHEL_CARD_SIZE := Vector2(230, 320)
const PLAY_CARD_SIZE := Vector2(230, 320)
const CURIO_CANISTER_CARD_SCALE := Vector2(0.75, 0.75)
const PLAY_CARD_TOP_RATIO := 0.62
# SATCHEL_BUTTON_* constants removed — now uses GameData.SATCHEL_BTN_*
const STICKER_DEFAULT_TEXTURE_PATH: String = "res://assets/textures/stickers/Sticker_default.png"
const HOVER_TILT_SCRIPT := preload("res://scripts/HoverCardTilt.gd")

# ── Drag state ─────────────────────────────────────────────────
var _curio_drag_active: bool = false
var _curio_drag_id: String = ""
var _curio_drag_preview: Control = null

# ── Studio state ───────────────────────────────────────────────
var _studio_popup: PopupPanel = null
var _studio_kind: String = ""
var _studio_entity_id: int = -1
var _studio_card_color: String = "white"
var _studio_slots: Array = []
var _studio_initial_card_color: String = ""
var _studio_initial_slots: Array = []
var _studio_task_name_edit: LineEdit = null
var _studio_task_diff_spin: SpinBox = null
var _studio_task_die_opt: OptionButton = null
var _studio_card_tex: TextureRect = null
var _studio_card_root: Control = null
var _studio_popup_root: Control = null
var _studio_name_label: Label = null
var _studio_book_hint: Label = null
var _studio_task_preview: Control = null
var _studio_source_data: Dictionary = {}
var _studio_initial_task_name: String = ""
var _studio_initial_task_difficulty: int = 1
var _studio_initial_task_die_sides: int = 6
var _studio_drag_active: bool = false
var _studio_drag_type: String = ""
var _studio_drag_id: String = ""
var _studio_drag_emoji: String = ""
var _studio_drag_preview: Control = null
var _studio_sticker_controller: Control = null
var _studio_paint_canvas: Control = null
var _studio_paint_mode_btn: Button = null
var _studio_paint_dirty: bool = false
var _current_room_id: int = -1

const STUDIO_PAINT_CANVAS_SCRIPT := preload("res://scripts/ui/studio_paint_canvas.gd")
const STUDIO_STICKER_PLACEMENT_CONTROLLER_SCRIPT := preload("res://scripts/ui/studio_sticker_placement_controller.gd")

func _ready() -> void:
	GameData.state_changed.connect(_refresh)
	_ensure_studio_popup()
	_build_layout()

func _refresh() -> void:
	if not is_inside_tree(): return
	_build_layout()

func _play_rollover_sfx() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_dice_clack()

# ── Style helpers — uses GameData constants ────────────────────
func _style_satchel_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = GameData.SATCHEL_BTN_BG
	style.border_color = GameData.SATCHEL_BTN_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = GameData.SATCHEL_BTN_HOVER
	hover_style.border_color = GameData.SATCHEL_BTN_BORDER
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = GameData.SATCHEL_BTN_PRESSED
	pressed_style.border_color = GameData.SATCHEL_BTN_BORDER
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed_style)

func _style_card(panel: PanelContainer, bg: Color, border: Color, bw: int, radius: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", s)

func _attach_hover_tilt(ctrl: Control, tilt_deg: float = 3.0, scale_mul: float = 1.03) -> void:
	if ctrl == null:
		return
	ctrl.set_script(HOVER_TILT_SCRIPT)
	ctrl.set("max_tilt_degrees", tilt_deg)
	ctrl.set("hover_scale", scale_mul)
	ctrl.set("hover_wobble_degrees", 1.05)
	ctrl.set("hover_wobble_speed", 8.2)

func _set_card_base_visual(panel: PanelContainer, color_key: String) -> void:
	if not is_instance_valid(panel):
		return
	var tex_rect: TextureRect = panel.get_node_or_null("CardBaseTexture") as TextureRect
	if tex_rect == null:
		tex_rect = TextureRect.new()
		tex_rect.name = "CardBaseTexture"
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tex_rect)
		panel.move_child(tex_rect, 0)
	tex_rect.texture = _card_base_texture(color_key)

func _card_base_texture(color_key: String) -> Texture2D:
	var path: String = CARD_BASE_TEXTURES.get(color_key, CARD_BASE_TEXTURES["white"])
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _default_sticker_texture() -> Texture2D:
	if ResourceLoader.exists(STICKER_DEFAULT_TEXTURE_PATH):
		return load(STICKER_DEFAULT_TEXTURE_PATH) as Texture2D
	return null

# ── Layout ─────────────────────────────────────────────────────
func _build_layout() -> void:
	for c in get_children(): c.queue_free()

	_add_header()

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	add_child(hbox)

	_build_left_panel(hbox)
	_build_right_panel(hbox)

func _add_header() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	var hdr := Label.new()
	hdr.text = "🔮 CURIO CANISTERS"
	hdr.add_theme_color_override("font_color", GameData.MULT_COLOR)
	hdr.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	vbox.add_child(hdr)

	var sub := Label.new()
	sub.text = "Drag a curio from your stash onto a canister to equip it."
	sub.add_theme_color_override("font_color", Color(GameData.MULT_COLOR, 0.5))
	sub.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	vbox.add_child(sub)

# ── Left Panel: Owned Curios ───────────────────────────────────
func _build_left_panel(parent: Container) -> void:
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(280, 0)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(GameData.CARD_BG, 0.92)
	left_style.border_color = Color(GameData.MULT_COLOR, 0.5)
	left_style.set_border_width_all(2)
	left_style.set_corner_radius_all(10)
	left_style.content_margin_left = 10
	left_style.content_margin_right = 10
	left_style.content_margin_top = 8
	left_style.content_margin_bottom = 8
	left_panel.add_theme_stylebox_override("panel", left_style)
	parent.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	var owned_header := Label.new()
	owned_header.text = "🔮 Owned Curios"
	owned_header.add_theme_color_override("font_color", GameData.MULT_COLOR)
	owned_header.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	left_vbox.add_child(owned_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	left_vbox.add_child(scroll)

	var curios_vbox := VBoxContainer.new()
	curios_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	curios_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(curios_vbox)

	var owned_curios: Array = CurioManager.get_owned_curios()
	if owned_curios.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No curios in stash.\nOpen crates to find curios!"
		empty_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.4))
		empty_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		curios_vbox.add_child(empty_lbl)
	else:
		for curio_id in owned_curios:
			curios_vbox.add_child(_make_owned_curio_card(curio_id))

# ── Right Panel: Canisters ─────────────────────────────────────
func _build_right_panel(parent: Container) -> void:
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(GameData.CARD_BG, 0.92)
	right_style.border_color = Color(GameData.MULT_COLOR, 0.3)
	right_style.set_border_width_all(2)
	right_style.set_corner_radius_all(10)
	right_style.content_margin_left = 10
	right_style.content_margin_right = 10
	right_style.content_margin_top = 8
	right_style.content_margin_bottom = 8
	right_panel.add_theme_stylebox_override("panel", right_style)
	parent.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	for curio_canister in GameData.curio_canisters:
		right_vbox.add_child(_make_curio_canister_card(curio_canister))

# ── Owned Curio Card ───────────────────────────────────────────
func _make_owned_curio_card(curio_id: String) -> Control:
	var curio: CurioResource = CurioManager.get_curio_resource(curio_id)
	if curio == null:
		return Control.new()

	var rarity_colors := {
		"common": Color(0.7, 0.7, 0.7),
		"uncommon": Color(0.3, 0.8, 0.4),
		"rare": Color(0.3, 0.5, 1.0),
		"exotic": Color(0.8, 0.3, 1.0),
	}
	var rarity_col: Color = rarity_colors.get(curio.rarity, Color(0.7, 0.7, 0.7))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(rarity_col.r * 0.12, rarity_col.g * 0.12, rarity_col.b * 0.12, 0.85)
	st.border_color = Color(rarity_col, 0.6)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", st)

	# Enable drag
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_begin_curio_drag(curio_id, curio.emoji, ev.global_position)
	)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Emoji
	var emoji_lbl := Label.new()
	emoji_lbl.text = curio.emoji
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(24))
	emoji_lbl.custom_minimum_size = Vector2(32, 0)
	emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(emoji_lbl)

	# Info column
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = curio.display_name
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	name_lbl.add_theme_color_override("font_color", rarity_col)
	name_lbl.clip_text = true
	info_vbox.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = curio.rarity.capitalize()
	rarity_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	rarity_lbl.add_theme_color_override("font_color", Color(rarity_col, 0.7))
	info_vbox.add_child(rarity_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = curio.description
	desc_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	desc_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.clip_text = true
	info_vbox.add_child(desc_lbl)

	# Equipped status
	var equipped_canister_id := -1
	for cid in CurioManager.get_all_equipped():
		if CurioManager.get_all_equipped()[cid] == curio_id:
			equipped_canister_id = int(cid)
			break
	if equipped_canister_id >= 0:
		var equipped_lbl := Label.new()
		var canister_name := "Canister #%d" % equipped_canister_id
		for cc in GameData.curio_canisters:
			if int(cc.get("id", -1)) == equipped_canister_id:
				canister_name = str(cc.get("title", "Canister #%d" % equipped_canister_id))
				break
		equipped_lbl.text = "📦 Equipped: %s" % canister_name
		equipped_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		equipped_lbl.add_theme_color_override("font_color", Color(GameData.ACCENT_GOLD, 0.8))
		info_vbox.add_child(equipped_lbl)

	return panel

# ── Canister Card ──────────────────────────────────────────────
func _make_curio_canister_card(curio_canister: Dictionary) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = PLAY_CARD_SIZE * CURIO_CANISTER_CARD_SCALE

	# Accept curio drop via click-release while dragging
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.set_meta("curio_canister_data", curio_canister)
	wrapper.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _curio_drag_active:
			var canister_id = int(curio_canister.get("id", -1))
			if canister_id >= 0 and _curio_drag_id != "":
				if CurioManager.equip_curio(_curio_drag_id, canister_id):
					_refresh()
			_finish_curio_drag()
	)

	var curio_canister_col: Color = GameData.MULT_COLOR
	var is_active: bool = curio_canister.get("active", false)
	var curio_canister_bg: Color = Color(GameData.CARD_BG, 1.0) if is_active else Color(GameData.CARD_BG, 0.8)

	var card := PanelContainer.new()
	card.custom_minimum_size = PLAY_CARD_SIZE
	card.pivot_offset = PLAY_CARD_SIZE * 0.5
	card.scale = CURIO_CANISTER_CARD_SCALE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.add_child(card)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = curio_canister_bg
	card_style.border_color = curio_canister_col if is_active else GameData.CARD_HL
	card_style.set_border_width_all(2 if is_active else 1)
	card_style.set_corner_radius_all(16)
	card.add_theme_stylebox_override("panel", card_style)

	_set_card_base_visual(card, str(curio_canister.get("card_color", "white")))

	# Apply room composition
	var _curio_canister_room_id := int(curio_canister.get("studio_room", -1))
	if _curio_canister_room_id > 0:
		var tex_rect: TextureRect = card.get_node_or_null("CardBaseTexture") as TextureRect
		if tex_rect != null:
			tex_rect.texture = StudioRoomManager.get_composition(_curio_canister_room_id)
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	# Make card clickable to open studio
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_open_card_studio("curio_canister", curio_canister)
	)

	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6 if side in ["left","right"] else 4)
	card.add_child(margin)

	var content_v := VBoxContainer.new()
	content_v.add_theme_constant_override("separation", 4)
	margin.add_child(content_v)

	# Preview strip
	var strip := PanelContainer.new()
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Color(1.0, 1.0, 1.0, 0.32)
	strip_style.border_color = Color(0.16, 0.12, 0.08, 0.24)
	strip_style.set_border_width_all(1)
	strip_style.set_corner_radius_all(4)
	strip.add_theme_stylebox_override("panel", strip_style)
	strip.custom_minimum_size = Vector2(0, PLAY_CARD_SIZE.y * PLAY_CARD_TOP_RATIO - 18.0)
	content_v.add_child(strip)

	# Sticker slots row
	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 3)
	strip.add_child(strip_row)
	for i in range(6):
		var slot := Label.new()
		slot.text = ""
		slot.custom_minimum_size = Vector2(18, 0)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
		strip_row.add_child(slot)

	# Add stickers from curio canister data
	var slots: Array = _task_slots_from_data(curio_canister, false)
	for i in range(slots.size()):
		var slot_data: Dictionary = slots[i]
		var slot_index: int = clampi(i, 0, 5)
		if slot_index < strip_row.get_child_count():
			var slot_label: Label = strip_row.get_child(slot_index) as Label
			if slot_label != null:
				var sticker_type: String = str(slot_data.get("type", ""))
				var sticker_id: String = str(slot_data.get("id", ""))
				var emoji: String = ""
				if sticker_type == "ritual":
					emoji = str(GameData.RITUAL_STICKERS.get(sticker_id, {}).get("emoji", ""))
				elif sticker_type == "consumable":
					emoji = str(GameData.CONSUMABLE_STICKERS.get(sticker_id, {}).get("emoji", ""))
				slot_label.text = emoji

	var strip_flex := Control.new()
	strip_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_row.add_child(strip_flex)

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_v.add_child(grow)

	# Curio Canister emoji
	var emoji_lbl := Label.new()
	emoji_lbl.text = str(curio_canister.get("emoji", "✦"))
	emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(34))
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_color_override("font_color", Color(0.22, 0.10, 0.18, 1.0))
	emoji_lbl.anchors_preset = Control.PRESET_FULL_RECT
	emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(emoji_lbl)

	# Curio Canister name label
	var curio_canister_name_lbl := Label.new()
	curio_canister_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	curio_canister_name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
	curio_canister_name_lbl.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	curio_canister_name_lbl.text = str(curio_canister.get("title", "Curio Canister"))
	curio_canister_name_lbl.clip_text = true
	curio_canister_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_v.add_child(curio_canister_name_lbl)

	# Mult label
	var mult_lbl := Label.new()
	mult_lbl.text = "+%.2fx star power" % float(curio_canister.get("mult", 0.3))
	mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mult_lbl.add_theme_color_override("font_color", GameData.MULT_COLOR)
	mult_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	content_v.add_child(mult_lbl)

	# Corner action buttons
	var corner_vb := VBoxContainer.new()
	corner_vb.anchor_left = 0.0
	corner_vb.anchor_top = 0.0
	corner_vb.offset_left = 4
	corner_vb.offset_top = 4
	corner_vb.custom_minimum_size = Vector2(76, 84)
	corner_vb.add_theme_constant_override("separation", 2)
	corner_vb.mouse_filter = Control.MOUSE_FILTER_STOP

	var studio_btn := Button.new()
	studio_btn.text = "Edit"
	studio_btn.tooltip_text = "Open Studio"
	studio_btn.custom_minimum_size = Vector2(72, 24)
	studio_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	studio_btn.pressed.connect(func(): _open_card_studio("curio_canister", curio_canister))
	_style_satchel_button(studio_btn)
	corner_vb.add_child(studio_btn)

	var equip_btn := Button.new()
	equip_btn.text = "Equip"
	equip_btn.tooltip_text = "Equip a Curio from your stash"
	equip_btn.custom_minimum_size = Vector2(72, 24)
	equip_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	equip_btn.pressed.connect(func(): _open_equip_curio_popup(curio_canister))
	_style_satchel_button(equip_btn)
	corner_vb.add_child(equip_btn)

	var arch_btn := Button.new()
	arch_btn.text = "Archive"
	arch_btn.tooltip_text = "Archive"
	arch_btn.custom_minimum_size = Vector2(72, 24)
	arch_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	arch_btn.pressed.connect(func(): _archive_curio_canister(curio_canister.id))
	_style_satchel_button(arch_btn)
	corner_vb.add_child(arch_btn)

	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.tooltip_text = "Delete"
	del_btn.custom_minimum_size = Vector2(72, 24)
	del_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	del_btn.pressed.connect(func(): _confirm_delete_curio_canister(curio_canister.id))
	_style_satchel_button(del_btn)
	corner_vb.add_child(del_btn)

	wrapper.add_child(corner_vb)

	_attach_hover_tilt(wrapper, 3.0, 1.03)

	return wrapper

# ── Drag Helpers ───────────────────────────────────────────────
func _begin_curio_drag(curio_id: String, emoji: String, global_pos: Vector2) -> void:
	_curio_drag_active = true
	_curio_drag_id = curio_id
	if is_instance_valid(_curio_drag_preview):
		_curio_drag_preview.queue_free()
	var preview := Label.new()
	preview.text = emoji
	preview.add_theme_font_size_override("font_size", GameData.scaled_font_size(28))
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
	add_child(preview)
	_curio_drag_preview = preview
	var local = get_local_mouse_position()
	_curio_drag_preview.position = local + Vector2(8, 8)

func _finish_curio_drag() -> void:
	_curio_drag_active = false
	_curio_drag_id = ""
	if is_instance_valid(_curio_drag_preview):
		_curio_drag_preview.queue_free()
	_curio_drag_preview = null

# ── Equip Popup ────────────────────────────────────────────────
func _open_equip_curio_popup(canister: Dictionary) -> void:
	var popup := PopupPanel.new()
	popup.name = "EquipCurioPopup"
	popup.rect_min_size = Vector2(560, 360)
	add_child(popup)

	var vb := VBoxContainer.new()
	vb.margin_left = 8
	vb.margin_top = 8
	popup.add_child(vb)

	var title := Label.new()
	title.text = "Equip Curio to Canister"
	title.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
	vb.add_child(title)

	var content_h := HBoxContainer.new()
	content_h.h_size_flags = Control.SIZE_EXPAND_FILL
	vb.add_child(content_h)

	# Left: canister preview
	var left_v := VBoxContainer.new()
	left_v.custom_minimum_size = Vector2(200, 0)
	content_h.add_child(left_v)

	var canister_label := Label.new()
	canister_label.text = "Canister: %s" % canister.get("id", "?")
	left_v.add_child(canister_label)

	var equipped_id = CurioManager.get_equipped_curio(canister.get("id"))
	if equipped_id:
		var equipped_res = CurioManager.get_curio_resource(equipped_id)
		var label_eq := Label.new()
		var equipped_name := str(equipped_id)
		if equipped_res:
			if equipped_res.has_property("display_name"):
				equipped_name = equipped_res.display_name
			elif equipped_res.has_property("name"):
				equipped_name = equipped_res.name
		label_eq.text = "Equipped: %s" % equipped_name
		left_v.add_child(label_eq)

	# Right: scroll listing owned curios
	var sc := ScrollContainer.new()
	sc.v_size_flags = Control.SIZE_EXPAND_FILL
	sc.h_size_flags = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(320, 260)
	content_h.add_child(sc)

	var list_v := VBoxContainer.new()
	list_v.custom_minimum_size = Vector2(300, 0)
	sc.add_child(list_v)

	var owned = CurioManager.get_owned_curios()
	if owned.size() == 0:
		var none_lbl := Label.new()
		none_lbl.text = "No curios in your stash."
		list_v.add_child(none_lbl)
	else:
		for curio_id in owned:
			var h := HBoxContainer.new()
			h.custom_minimum_size = Vector2(0, 36)
			list_v.add_child(h)
			var res = CurioManager.get_curio_resource(curio_id)
			var name_lbl := Label.new()
			var display_name := str(curio_id)
			if res:
				if res.has_property("display_name"):
					display_name = res.display_name
				elif res.has_property("name"):
					display_name = res.name
			name_lbl.text = display_name
			name_lbl.h_size_flags = Control.SIZE_EXPAND_FILL
			h.add_child(name_lbl)
			var equip_button := Button.new()
			equip_button.text = "Equip"
			equip_button.pressed.connect(func():
				CurioManager.equip_curio(curio_id, canister.get("id"))
				popup.queue_free()
				_refresh()
			)
			h.add_child(equip_button)

	var close_hb := HBoxContainer.new()
	close_hb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(close_hb)

	var cancel_btn := Button.new()
	cancel_btn.text = "Close"
	cancel_btn.pressed.connect(func(): popup.queue_free())
	close_hb.add_child(cancel_btn)

	popup.popup_centered()

# ── Canister Management ────────────────────────────────────────
func _archive_curio_canister(curio_canister_id: int) -> void:
	Database.update_curio_canister(curio_canister_id, "archived", true)
	_refresh()

func _confirm_delete_curio_canister(curio_canister_id: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Curio Canister"
	dialog.dialog_text = "Delete this curio canister? This cannot be undone."
	dialog.confirmed.connect(func(): _delete_curio_canister(curio_canister_id); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog); dialog.popup_centered()

func _delete_curio_canister(curio_canister_id: int) -> void:
	var room_id: int = Database.get_curio_canister_studio_room(curio_canister_id)
	if _current_room_id == room_id:
		_current_room_id = -1
	Database.delete_curio_canister(curio_canister_id)
	_refresh()
	GameData.state_changed.emit()
	var d := AcceptDialog.new()
	d.title = "Deleted"
	d.dialog_text = "Curio canister deleted."
	add_child(d); d.popup_centered()
	d.confirmed.connect(func(): d.queue_free())

# ── Sticker slot helpers ───────────────────────────────────────
func _task_slots_from_data(data: Dictionary, preserve_empty: bool = false) -> Array:
	var slots: Array = []
	var raw_slots: Variant = data.get("sticker_slots", [])
	if raw_slots is Array and not (raw_slots as Array).is_empty():
		for slot_value in raw_slots:
			if slot_value is Dictionary:
				var slot_dict: Dictionary = slot_value
				var slot_type := str(slot_dict.get("type", "")).strip_edges()
				var slot_id := str(slot_dict.get("id", "")).strip_edges()
				if (slot_type == "ritual" or slot_type == "consumable") and slot_id != "":
					var norm_x: float = clampf(float(slot_dict.get("x", 0.5)), 0.0, 1.0)
					var norm_y: float = clampf(float(slot_dict.get("y", 0.5)), 0.0, PLAY_CARD_TOP_RATIO)
					slots.append({"type": slot_type, "id": slot_id, "x": norm_x, "y": norm_y})
				elif preserve_empty:
					continue
			elif preserve_empty:
				continue
	return slots

# ── Studio (card editor) ───────────────────────────────────────
func _ensure_studio_popup() -> void:
	if is_instance_valid(_studio_popup):
		return
	_studio_popup = PopupPanel.new()
	_studio_popup.name = "CardStudioPopup"
	_studio_popup.visible = false
	_studio_popup.exclusive = true
	_studio_popup.size = Vector2i(1180, 720)
	add_child(_studio_popup)

func _open_card_studio(kind: String, data: Dictionary) -> void:
	if kind != "task" and kind != "curio_canister":
		return
	var entity_id := int(data.get("id", -1))
	if entity_id < 0:
		return

	_ensure_studio_popup()
	_release_current_studio_room()
	_studio_kind = kind
	_studio_entity_id = entity_id
	_studio_card_color = str(data.get("card_color", "white"))
	_studio_source_data = data.duplicate(true)

	var room_id := int(_studio_source_data.get("studio_room", -1))
	if room_id <= 0:
		room_id = StudioRoomManager.create_room(kind, entity_id)
		if kind == "task":
			Database.update_task(entity_id, "studio_room", room_id)
		else:
			Database.update_curio_canister(entity_id, "studio_room", room_id)
		_studio_source_data["studio_room"] = room_id

	_studio_initial_task_name = str(data.get("task", data.get("title", "")))
	_studio_initial_task_difficulty = int(data.get("difficulty", 1))
	_studio_initial_task_die_sides = int(data.get("die_sides", 6))
	_studio_slots = _studio_stickers_from_room_or_data(room_id, _studio_source_data)
	_studio_initial_card_color = _studio_card_color
	_studio_initial_slots = _clone_studio_slots(_studio_slots)

	var d := AcceptDialog.new()
	d.title = "Studio — %s" % str(data.get("title", data.get("task", "Card")))
	d.dialog_text = "Full studio editing is shared with SatchelTab. Open the Satchel tab for the full card studio experience."
	d.ok_button_text = "OK"
	add_child(d)
	d.popup_centered(Vector2i(400, 200))
	d.confirmed.connect(func(): d.queue_free())

func _release_current_studio_room() -> void:
	if _current_room_id <= 0:
		return
	StudioRoomManager.release_room_view(_current_room_id)
	_current_room_id = -1

func _studio_stickers_from_room_or_data(room_id: int, data: Dictionary) -> Array:
	if room_id > 0:
		var raw_room := Database.get_studio_room_data(room_id)
		if not raw_room.is_empty():
			var room_stickers: Variant = raw_room.get("stickers", [])
			if room_stickers is Array and not (room_stickers as Array).is_empty():
				var normalized: Array = []
				for sticker_value in room_stickers:
					if sticker_value is not Dictionary:
						continue
					var entry := sticker_value as Dictionary
					normalized.append(entry)
				return normalized
	return _task_slots_from_data(data, false)

func _clone_studio_slots(source: Array) -> Array:
	var cloned: Array = []
	for slot in source:
		if slot is Dictionary:
			cloned.append((slot as Dictionary).duplicate(true))
		else:
			cloned.append({})
	return cloned