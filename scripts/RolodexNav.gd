extends Control
class_name RolodexNav

# ─────────────────────────────────────────────────────────────────
# RolodexNav.gd  —  Bottom primary navigation using a Rolodex metaphor.
#
# A Rolodex is a rotary card-file invented by Arnold Neustadter (1950s).
# Each tab is a physical "card" on the drum. The active card faces the
# player straight-on; adjacent cards are visible at the edges, angled
# away as though rotating around a horizontal cylinder.
#
# Visual anatomy of each card:
#   ┌─────────────┐  ← card body (rounded, border glow when active)
#   │  [NUB]      │  ← index tab nub at top-left (always visible)
#   │   ICON      │  ← 32×32 placeholder art or emoji glyph
#   │   LABEL     │  ← tab name in small caps
#   └─────────────┘
#
# The cylinder effect is approximated in 2D:
#   · Active card  : scale 1.0, full opacity, elevated shadow, ACCENT_BLUE border
#   · n±1 cards    : scale 0.82, 65% opacity, pushed inward, dimmed border
#   · n±2 cards    : scale 0.65, 35% opacity, barely visible
#
# Interaction: click any card → smooth tween to that card becoming active.
# ─────────────────────────────────────────────────────────────────

signal tab_selected(key: String)

# ── Layout constants ──────────────────────────────────────────────
const CARD_W           := 92.0    # base card width
const CARD_H           := 74.0    # base card height
const NUB_H            := 10.0    # Rolodex index-nub height above card
const CARD_SPACING     := 6.0     # horizontal gap between cards
const TWEEN_DURATION   := 0.28    # card-flip animation time

# Distance decay: scale / alpha for each positional offset from active
# Index 0 = active, 1 = adjacent, 2 = two-away, 3+ = hidden
const SCALE_AT_OFFSET:  Array = [1.00,  0.82,  0.65,  0.45]
const ALPHA_AT_OFFSET:  Array = [1.00,  0.65,  0.35,  0.10]

# ── Colour palette ────────────────────────────────────────────────
const COL_CARD_BG_ACTIVE  := Color("#1a0b3a")
const COL_CARD_BG_IDLE    := Color("#0d0520")
const COL_BORDER_ACTIVE   := Color("#4a8fff")   # GameData.ACCENT_BLUE approx
const COL_BORDER_IDLE     := Color("#290E7A")
const COL_NUB_ACTIVE      := Color("#4a8fff")
const COL_NUB_IDLE        := Color("#1e0e42")
const COL_LABEL_ACTIVE    := Color("#e8d8ff")
const COL_LABEL_IDLE      := Color("#6644aa")
const COL_SHADOW          := Color(0.0, 0.0, 0.0, 0.40)

# ── State ─────────────────────────────────────────────────────────
var _tab_defs:   Array     = []     # [{key, label, icon_path, icon_tex}]
var _active_key: String    = ""
var _cards:      Array     = []     # Card Control nodes, same order as _tab_defs
var _tween:      Tween
var _art_cache:  Dictionary = {}    # path → Texture2D

# ─────────────────────────────────────────────────────────────────
## Called by Main.gd once with the PRIMARY_TABS definition array.
## tab_defs format: [[key, label, scene_path, use_scene], …]
func setup(tab_defs: Array, initial_key: String) -> void:
	_tab_defs   = []
	_active_key = initial_key

	for td: Array in tab_defs:
		var key:   String = td[0]
		var label: String = td[1]
		# Derive placeholder art path from tab key
		var art_map: Dictionary = {
			"table":         "res://assets/ui/placeholders/tab_table.png",
			"garden":        "res://assets/ui/placeholders/tab_garden.png",
			"confectionery": "res://assets/ui/placeholders/tab_confect.png",
			"lunarbazaar":   "res://assets/ui/placeholders/tab_cave.png",
		}
		_tab_defs.append({
			key       = key,
			label     = label,
			icon_path = art_map.get(key, ""),
		})

	_preload_art()
	_build_cards()
	_layout_cards_instant()

func set_active_tab(key: String) -> void:
	if _active_key == key: return
	_active_key = key
	_animate_to_active()

# ── Art ───────────────────────────────────────────────────────────
func _preload_art() -> void:
	for td: Dictionary in _tab_defs:
		var p: String = td.icon_path
		if p.is_empty(): continue
		if not _art_cache.has(p) and ResourceLoader.exists(p):
			_art_cache[p] = load(p) as Texture2D

# ── Card construction ─────────────────────────────────────────────
func _build_cards() -> void:
	for child: Node in get_children(): child.queue_free()
	_cards.clear()

	for i in range(_tab_defs.size()):
		var td: Dictionary = _tab_defs[i]
		var card: Control = _make_card(td, i)
		add_child(card)
		_cards.append(card)

func _make_card(td: Dictionary, idx: int) -> Control:
	# Outer wrapper controls position/scale/alpha
	var wrapper := Control.new()
	wrapper.name             = "Card_%s" % td.key
	wrapper.custom_minimum_size = Vector2(CARD_W, CARD_H + NUB_H)
	wrapper.pivot_offset     = Vector2(CARD_W * 0.5, (CARD_H + NUB_H) * 0.5)

	# Nub (the Rolodex tab-index ear)
	var nub := Panel.new()
	nub.name = "Nub"
	nub.position = Vector2(8.0, 0.0)
	nub.size     = Vector2(28.0, NUB_H + 4.0)
	var nub_style := StyleBoxFlat.new()
	nub_style.bg_color = COL_NUB_IDLE
	nub_style.set_corner_radius_all(3)
	nub_style.corner_radius_bottom_left  = 0
	nub_style.corner_radius_bottom_right = 0
	nub.add_theme_stylebox_override("panel", nub_style)
	wrapper.add_child(nub)

	# Card body
	var body := PanelContainer.new()
	body.name     = "Body"
	body.position = Vector2(0.0, NUB_H)
	body.size     = Vector2(CARD_W, CARD_H)
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = COL_CARD_BG_IDLE
	body_style.border_color = COL_BORDER_IDLE
	body_style.set_border_width_all(1)
	body_style.set_corner_radius_all(6)
	body_style.corner_radius_top_left  = 0   # flush where nub meets body
	body_style.shadow_color  = COL_SHADOW
	body_style.shadow_size   = 0
	body_style.shadow_offset = Vector2(0, 3)
	body.add_theme_stylebox_override("panel", body_style)
	wrapper.add_child(body)

	# Card content vbox
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(vbox)

	# Icon — try placeholder art, fall back to emoji label
	var icon_path: String = td.icon_path
	if _art_cache.has(icon_path):
		var tex_rect := TextureRect.new()
		tex_rect.name = "Icon"
		tex_rect.texture = _art_cache[icon_path]
		tex_rect.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode    = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.custom_minimum_size = Vector2(32, 32)
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(tex_rect)
	else:
		# Emoji glyph extracted from the label (e.g. "🎲 TABLE" → "🎲")
		var emoji_lbl := Label.new()
		emoji_lbl.name = "Icon"
		emoji_lbl.text = _extract_emoji(td.label)
		emoji_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(22))
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(emoji_lbl)

	# Tab name label (small-caps feel at size 9)
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = _strip_emoji(td.label)
	name_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	name_lbl.add_theme_color_override("font_color", COL_LABEL_IDLE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(name_lbl)

	# Click the whole card to navigate
	var key: String = td.key
	wrapper.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			tab_selected.emit(key)
	)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP

	# Store metadata for the animation pass
	wrapper.set_meta("tab_key",   td.key)
	wrapper.set_meta("tab_index", idx)

	return wrapper

# ── Layout ────────────────────────────────────────────────────────

## Positions all cards immediately (no tween) — used on first build.
func _layout_cards_instant() -> void:
	_apply_card_transforms(false)

## Tweens cards to their new positions after active tab changes.
func _animate_to_active() -> void:
	_apply_card_transforms(true)

func _apply_card_transforms(animate: bool) -> void:
	if _cards.is_empty(): return

	var active_idx: int = _get_active_index()
	var total: float    = float(_cards.size())
	var center_x: float = size.x * 0.5

	# Determine x position for each card so the active one is centered
	# and the others are evenly distributed left/right.
	var slot_w: float = CARD_W + CARD_SPACING

	if animate:
		if _tween: _tween.kill()
		_tween = create_tween()
		_tween.set_parallel(true)

	for i in range(_cards.size()):
		var card: Control = _cards[i]
		var offset: int   = i - active_idx   # relative to active (-2,-1,0,1,2…)
		var abs_off: int  = absi(offset)

		# Scale / alpha derived from distance
		var target_scale: float = SCALE_AT_OFFSET[mini(abs_off, SCALE_AT_OFFSET.size() - 1)]
		var target_alpha: float = ALPHA_AT_OFFSET[mini(abs_off, ALPHA_AT_OFFSET.size() - 1)]

		# X: cards fan out from center; Y: inactive cards sink slightly (drum curve)
		var target_x: float = center_x + float(offset) * slot_w - CARD_W * 0.5
		# Simulate drum curvature: distant cards drop a little
		var curve_drop: float = float(abs_off * abs_off) * 4.0
		var target_y: float   = curve_drop

		var target_pos := Vector2(target_x, target_y)
		var target_scl := Vector2(target_scale, target_scale)

		# Update card appearance for active vs inactive
		_style_card_state(card, offset == 0)

		if animate:
			_tween.tween_property(card, "position",       target_pos, TWEEN_DURATION) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.tween_property(card, "scale",          target_scl, TWEEN_DURATION) \
				.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
			_tween.tween_property(card, "modulate:a",     target_alpha, TWEEN_DURATION * 0.8)
		else:
			card.position   = target_pos
			card.scale      = target_scl
			card.modulate.a = target_alpha

func _style_card_state(card: Control, is_active: bool) -> void:
	var body: PanelContainer = card.get_node_or_null("Body") as PanelContainer
	var nub:  Panel          = card.get_node_or_null("Nub")  as Panel
	var lbl:  Label          = card.get_node_or_null("Body/VBoxContainer/NameLabel") as Label

	if body:
		var s := StyleBoxFlat.new()
		s.bg_color     = COL_CARD_BG_ACTIVE  if is_active else COL_CARD_BG_IDLE
		s.border_color = COL_BORDER_ACTIVE   if is_active else COL_BORDER_IDLE
		s.set_border_width_all(2           if is_active else 1)
		s.set_corner_radius_all(6)
		s.corner_radius_top_left = 0
		# Active card gets a soft drop shadow to suggest elevation
		s.shadow_color  = COL_SHADOW if is_active else Color(0,0,0,0)
		s.shadow_size   = 6          if is_active else 0
		s.shadow_offset = Vector2(0, 4)
		body.add_theme_stylebox_override("panel", s)

	if nub:
		var ns := StyleBoxFlat.new()
		ns.bg_color = COL_NUB_ACTIVE if is_active else COL_NUB_IDLE
		ns.set_corner_radius_all(3)
		ns.corner_radius_bottom_left  = 0
		ns.corner_radius_bottom_right = 0
		nub.add_theme_stylebox_override("panel", ns)

	if lbl:
		lbl.add_theme_color_override("font_color",
			COL_LABEL_ACTIVE if is_active else COL_LABEL_IDLE)
		lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(10) if is_active else GameData.scaled_font_size(9))

# ── Helpers ───────────────────────────────────────────────────────

func _get_active_index() -> int:
	for i in range(_tab_defs.size()):
		if (_tab_defs[i] as Dictionary).key == _active_key:
			return i
	return 0

## Extracts the first non-ASCII glyph (the emoji) from a tab label.
func _extract_emoji(label: String) -> String:
	for i in range(label.length()):
		var ch: String = label.substr(i, 1)
		if ch.unicode_at(0) > 127:
			return ch
	return "•"

## Returns the text portion after the emoji+space prefix.
func _strip_emoji(label: String) -> String:
	var parts := label.split(" ", false, 1)
	return parts[1].strip_edges() if parts.size() > 1 else label

# ── Resize ────────────────────────────────────────────────────────
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_cards_instant()
