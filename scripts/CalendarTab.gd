extends Control

const MOON_PHASE_DISPLAY_SCRIPT := preload("res://scripts/MoonPhaseDisplay.gd")

# ─────────────────────────────────────────────────────────────────
# CalendarTab.gd  –  Monthly heatmap calendar
# Visual theme: "Lunar Codex" — deep-space purples, gold accents,
# framed card layout, distinct hover states, moon-phase header.
# All game logic is unchanged from v0.7.6.
# ─────────────────────────────────────────────────────────────────

var _month_label: Label
var _month_moon: Control
var _grid: GridContainer
var _stats_label: Label
var _toolbar_hbox: HBoxContainer
var _filter_select: OptionButton
var _search_box: LineEdit

const WEEKDAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const MONTHS   := ["January","February","March","April","May","June",
				   "July","August","September","October","November","December"]

# Named colour constants — now sourced from GameData for single source of truth
const COL_CELL_VOID   := GameData.CAL_CELL_VOID    # no data at all
const COL_CELL_ZERO   := GameData.CAL_CELL_ZERO    # day logged, score = 0
const COL_CELL_DIM    := GameData.CAL_CELL_DIM     # score  1-49
const COL_CELL_MID    := GameData.CAL_CELL_MID     # score 50-199
const COL_CELL_BRIGHT := GameData.CAL_CELL_BRIGHT  # score 200+
const COL_BORDER_IDLE  := GameData.CAL_BORDER_IDLE
const COL_BORDER_TODAY := GameData.CAL_BORDER_TODAY
const COL_BORDER_VIEW  := GameData.CAL_BORDER_VIEW

func _ready() -> void:
	GameData.state_changed.connect(_refresh)
	if has_node("/root/SignalBus"):
		SignalBus.theme_changed.connect(_on_theme_changed_cal)
	_build_ui()
	_refresh()
	call_deferred("_setup_feedback")

func _setup_feedback() -> void:
	if has_node("/root/ButtonFeedback"):
		get_node("/root/ButtonFeedback").setup_recursive(self)

# ── Layout ────────────────────────────────────────────────────────
func _build_ui() -> void:
	for _c in get_children(): _c.queue_free()

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(outer)

	var center_hbox := HBoxContainer.new()
	center_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(center_hbox)

	# Framed card — everything lives inside this panel so the calendar
	# floats as a distinct visual object against the tab background.
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#0A0225")
	card_style.border_color = Color("#3D1580")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(12)
	card_style.content_margin_left   = 20
	card_style.content_margin_right  = 20
	card_style.content_margin_top    = 18
	card_style.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", card_style)
	center_hbox.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Month navigation header
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var _nav_prev_year := func(): _change_year(-1)
	header.add_child(_make_nav_btn("<<", _nav_prev_year))
	var _nav_prev_month := func(): _change_month(-1)
	header.add_child(_make_nav_btn("<",  _nav_prev_month))

	_month_moon = MOON_PHASE_DISPLAY_SCRIPT.new()
	_month_moon.custom_minimum_size = Vector2(24, 24)
	header.add_child(_month_moon)

	_month_label = Label.new()
	_month_label.custom_minimum_size = Vector2(280, 0)
	_month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_month_label.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
	_month_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(20))
	header.add_child(_month_label)

	var _nav_next_month := func(): _change_month(1)
	header.add_child(_make_nav_btn(">",  _nav_next_month))
	var _nav_next_year := func(): _change_year(1)
	header.add_child(_make_nav_btn(">>", _nav_next_year))

	var export_btn := _make_nav_btn("Export .ics", _export_ics)
	export_btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	header.add_child(export_btn)

	# Toolbar: quick filters and search
	_toolbar_hbox = HBoxContainer.new()
	_toolbar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_toolbar_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_toolbar_hbox)

	_filter_select = OptionButton.new()
	_filter_select.add_item("All Events", 0)
	_filter_select.add_item("Contracts", 1)
	_filter_select.add_item("Scores", 2)
	_filter_select.add_item("Reminders", 3)
	_filter_select.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	_filter_select.size_flags_horizontal = Control.SIZE_FILL
	_filter_select.size_flags_stretch_ratio = 1
	_filter_select.selected = 0
	_filter_select.item_selected.connect(_on_filter_changed)
	_toolbar_hbox.add_child(_filter_select)

	_search_box = LineEdit.new()
	_search_box.placeholder_text = "Search events..."
	_search_box.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	_search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_box.size_flags_stretch_ratio = 2
	_search_box.text_changed.connect(_on_search_text_changed)
	_toolbar_hbox.add_child(_search_box)

	# Visual divider between header and grid
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color("#3D1580")
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Calendar grid
	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_grid)

	# Stats — recessed panel so stats feel embedded, not floating free
	var stats_panel := PanelContainer.new()
	var stats_style := StyleBoxFlat.new()
	stats_style.bg_color = Color("#0D052A")
	stats_style.border_color = Color("#3D1580")
	stats_style.set_border_width_all(1)
	stats_style.set_corner_radius_all(6)
	stats_style.content_margin_left   = 14
	stats_style.content_margin_right  = 14
	stats_style.content_margin_top    = 6
	stats_style.content_margin_bottom = 6
	stats_panel.add_theme_stylebox_override("panel", stats_style)
	vbox.add_child(stats_panel)

	_stats_label = Label.new()
	_stats_label.add_theme_color_override("font_color", GameData.FG_COLOR)
	_stats_label.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_panel.add_child(_stats_label)

	# Legend
	var legend_hbox := HBoxContainer.new()
	legend_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	legend_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(legend_hbox)

	for item: Array in [
		["None",  COL_CELL_VOID],
		["Some",  COL_CELL_DIM],
		["Good",  COL_CELL_MID],
		["Great", COL_CELL_BRIGHT],
	]:
		var chip := ColorRect.new()
		chip.color = item[1]
		chip.custom_minimum_size = Vector2(14, 14)
		legend_hbox.add_child(chip)
		var lbl := Label.new()
		lbl.text = item[0]
		lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.55))
		lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		legend_hbox.add_child(lbl)

	var sep_lbl := Label.new()
	sep_lbl.text = "  |  Deadlines:"
	sep_lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.35))
	sep_lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
	legend_hbox.add_child(sep_lbl)

	# Contract Priority Legend
	for item: Array in [
		["o", Color("#FF4444"), "High Priority"],
		["o", Color("#FF8C00"), "Med Priority"],
		["o", Color("#FFD700"), "Low Priority"],
		["o", Color("#AAAAAA"), "No Priority"],
	]:
		var dot := Label.new()
		dot.text = item[0]
		dot.add_theme_color_override("font_color", item[1])
		dot.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		legend_hbox.add_child(dot)
		var dlbl := Label.new()
		dlbl.text = item[2]
		dlbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.45))
		dlbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(9))
		legend_hbox.add_child(dlbl)

# Flat nav buttons: quiet default, gold on hover — reinforces the header palette
func _make_nav_btn(label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text  = label
	btn.flat  = true
	btn.add_theme_color_override("font_color",       Color("#9B5CFF"))
	btn.add_theme_color_override("font_hover_color", GameData.ACCENT_GOLD)
	btn.add_theme_font_size_override("font_size",    GameData.scaled_font_size(13))
	btn.pressed.connect(callback)
	return btn

# ── Refresh ───────────────────────────────────────────────────────
func _refresh() -> void:
	if is_instance_valid(_month_moon):
		_month_moon.set_phase_data(GameData.get_moon_phase(GameData.view_date))
	_month_label.text = "%s  %d" % [MONTHS[GameData.view_date.month - 1], GameData.view_date.year]
	_build_grid()
	_update_stats()

# ── Grid builder ──────────────────────────────────────────────────
func _build_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()

	for wd: String in WEEKDAYS:
		var lbl := Label.new()
		lbl.text = wd
		lbl.add_theme_color_override("font_color", Color("#9B5CFF"))
		lbl.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size  = Vector2(68, 24)
		_grid.add_child(lbl)

	var year:         int = GameData.view_date.year
	var month:        int = GameData.view_date.month
	var first_day         := _get_weekday(year, month, 1)
	var days_in_month     := _days_in_month(year, month)

	for _i in range(first_day):
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(68, 68)
		_grid.add_child(spacer)

	var from_str := "%04d-%02d-01"    % [year, month]
	var to_str   := "%04d-%02d-%02d"  % [year, month, days_in_month]
	var records  := Database.get_stats_range(GameData.current_profile, from_str, to_str)
	var score_by_day: Dictionary = {}
	for rec in records:
		var day_num := int(rec.date.split("-")[2])
		score_by_day[day_num] = rec.get("total_score", 0)

	var contract_dots: Dictionary = {}
	var DIFF_ORDER := ["No Priority", "Low Priority", "Med Priority", "High Priority"]
	for c in Database.get_contracts(GameData.current_profile, false):
		var dl: String = str(c.get("deadline", ""))
		if dl.length() >= 10:
			var parts := dl.split("-")
			if parts.size() == 3 and int(parts[0]) == year and int(parts[1]) == month:
				var d: int = int(parts[2])
				var diff: String = str(c.get("difficulty", "No Priority"))
				if not contract_dots.has(d):
					contract_dots[d] = diff
				else:
					if DIFF_ORDER.find(diff) > DIFF_ORDER.find(contract_dots[d]):
						contract_dots[d] = diff

	var today := Time.get_date_dict_from_system()
	for day in range(1, days_in_month + 1):
		var cell := _make_day_cell(day, score_by_day.get(day, -1), today, year, month,
								   contract_dots.get(day, ""))
		_grid.add_child(cell)

	call_deferred("_setup_feedback")

# ── Day cell factory ──────────────────────────────────────────────
func _make_day_cell(day: int, score: int, today: Dictionary,
					 year: int, month: int, contract_diff: String = "") -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(68, 68)

	var btn := Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var is_today: bool = (day == today.day and month == today.month and year == today.year)
	var is_view:  bool = (day == GameData.view_date.day and
					 month == GameData.view_date.month and
					 year  == GameData.view_date.year)

	var bg_color: Color
	if   score < 0:   bg_color = COL_CELL_VOID
	elif score == 0:  bg_color = COL_CELL_ZERO
	elif score < 50:  bg_color = COL_CELL_DIM
	elif score < 200: bg_color = COL_CELL_MID
	else:             bg_color = COL_CELL_BRIGHT

	var style := _make_cell_style(bg_color,                  is_today, is_view, false)
	var hover  := _make_cell_style(bg_color.lightened(0.18), is_today, is_view, true)

	btn.add_theme_stylebox_override("normal",  style)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus",   style)  # suppress default focus ring

	var score_text: String = ("*%d" % score) if score > 0 else ("--" if score == 0 else "")
	btn.text = "%d\n%s" % [day, score_text]
	btn.add_theme_font_size_override("font_size", GameData.scaled_font_size(11))
	btn.add_theme_color_override("font_color",         COL_BORDER_TODAY if is_today else GameData.FG_COLOR)
	btn.add_theme_color_override("font_hover_color",   GameData.ACCENT_GOLD)
	btn.add_theme_color_override("font_pressed_color", GameData.ACCENT_GOLD)
	var _day_cb := func(d=day): _open_day_detail(d)
	btn.pressed.connect(_day_cb)
	wrapper.add_child(btn)

	# Contract deadline dot — top-right corner overlay, pointer-transparent
	if contract_diff != "":
		var dot := Label.new()
		dot.text = "o"
		match contract_diff:
			"High Priority": dot.add_theme_color_override("font_color", Color("#FF4444"))
			"Med Priority":  dot.add_theme_color_override("font_color", Color("#FF8C00"))
			"Low Priority":  dot.add_theme_color_override("font_color", Color("#FFD700"))
			"No Priority":   dot.add_theme_color_override("font_color", Color("#AAAAAA"))
			_:               dot.add_theme_color_override("font_color", Color("#AAAAAA"))
		dot.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
		dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		dot.offset_left = -14; dot.offset_top = 2
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrapper.add_child(dot)

	return wrapper

# Extracted so _make_day_cell reads as a story, not a StyleBox factory
func _make_cell_style(bg: Color, is_today: bool, is_view: bool, is_hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(8)
	if is_today:
		style.border_color = COL_BORDER_TODAY
		style.set_border_width_all(2)
	elif is_view:
		style.border_color = COL_BORDER_VIEW
		style.set_border_width_all(2)
	elif is_hover:
		style.border_color = Color("#6A30C0")
		style.set_border_width_all(1)
	else:
		style.border_color = COL_BORDER_IDLE
		style.set_border_width_all(1)
	return style

# ── Stats ─────────────────────────────────────────────────────────
func _update_stats() -> void:
	var year:    int = GameData.view_date.year
	var month:   int = GameData.view_date.month
	var days_in      := _days_in_month(year, month)
	var from_str := "%04d-%02d-01"    % [year, month]
	var to_str   := "%04d-%02d-%02d"  % [year, month, days_in]
	var records  := Database.get_stats_range(GameData.current_profile, from_str, to_str)

	var active_days: int = records.size()
	var month_score: int = 0
	for rec in records:
		month_score += rec.get("total_score", 0)
	var avg: int = int(month_score / float(active_days)) if active_days > 0 else 0

	var total_earned: int = Database.get_total_moonpearls_earned(GameData.current_profile)
	var total_spent: int  = Database.get_moonpearls_spent_total(GameData.current_profile)
	var pressed: int      = Database.get_moonpearls_pressed()
	var available: int    = Database.get_moonpearls()

	_stats_label.text = (
		"This month -- Active: %d/%d  o  Score: %d  o  Avg/day: %d\n" % [active_days, days_in, month_score, avg] +
		"All time -- Moonpearls: %d earned  o  %d spent  o  %d available  o  %d pressed" % [total_earned, total_spent, available, pressed]
	)

# ── Day navigation ────────────────────────────────────────────────
func _jump_to_day(day: int) -> void:
	_save_current_day()
	GameData.view_date.day = day
	GameData.dice_results.clear()
	var rec: Variant = Database.get_dice_box_stat(GameData.get_date_string(), GameData.current_profile)
	if rec != null:
		var done: PackedStringArray = str(rec.get("completed_tasks","")).split(",", false)
		for t in GameData.tasks: t.completed = t.task in done
		GameData.dice_results = {}
		for part in str(rec.get("task_rolls","")).split("|", false):
			if ":" in part and not part.begins_with("J:"):
				var kv := part.split(":", false)
				if kv.size() >= 2: GameData.dice_results[int(kv[0])] = int(kv[1])
	GameData.state_changed.emit()
	var main: Node = get_tree().get_root().get_child(0)
	if main and main.has_method("switch_to_tab_by_key"):
		main.switch_to_tab_by_key("table")

func _change_month(delta: int) -> void:
	var m: int = GameData.view_date.month + delta
	var y: int = GameData.view_date.year
	if m > 12: m = 1;  y += 1
	elif m < 1: m = 12; y -= 1
	GameData.view_date = {year=y, month=m, day=1}
	_refresh()

func _change_year(delta: int) -> void:
	GameData.view_date.year += delta
	GameData.view_date.day  = 1
	_refresh()

# ── Date Utilities ────────────────────────────────────────────────
func _days_in_month(year: int, month: int) -> int:
	var days := [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if month == 2 and _is_leap(year):
		return 29
	return days[month]

func _is_leap(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)

func _get_weekday(year: int, month: int, day: int) -> int:
	var d    := Time.get_unix_time_from_datetime_dict({year=year,month=month,day=day,hour=0,minute=0,second=0})
	var date := Time.get_datetime_dict_from_unix_time(d)
	return date.get("weekday", 0)

# ── ICS Export (unchanged) ────────────────────────────────────────
func _export_ics() -> void:
	var lines: PackedStringArray = []
	lines.append("BEGIN:VCALENDAR")
	lines.append("VERSION:2.0")
	lines.append("PRODID:-//MOONSEED//CalendarTab//EN")
	lines.append("CALSCALE:GREGORIAN")

	for c in Database.get_contracts(GameData.current_profile, false):
		var dl: String = str(c.get("deadline", ""))
		if dl.length() < 10: continue
		var parts := dl.split("-")
		if parts.size() < 3: continue
		var date_str: String = "%04d%02d%02d" % [int(parts[0]), int(parts[1]), int(parts[2])]
		var uid: String      = "contract-%d@moonseed" % int(c.get("id", 0))
		var summary: String  = str(c.get("name", "Contract")).replace("\n", " ")
		var diff: String     = str(c.get("difficulty", ""))
		var desc: String     = "Difficulty: %s | Subtasks: %s" % [diff, str(c.get("subtasks", ""))]
		lines.append("BEGIN:VEVENT")
		lines.append("UID:" + uid)
		lines.append("DTSTART;VALUE=DATE:" + date_str)
		lines.append("DTEND;VALUE=DATE:" + date_str)
		lines.append("SUMMARY:" + summary)
		lines.append("DESCRIPTION:" + desc)
		match diff:
			"High Priority": lines.append("PRIORITY:1")
			"Med Priority":  lines.append("PRIORITY:5")
			_:               lines.append("PRIORITY:9")
		lines.append("END:VEVENT")

	for rec in Database.get_all_dice_box_stats(GameData.current_profile):
		var dl: String = str(rec.get("date", ""))
		if dl.length() < 10: continue
		var score: int = int(rec.get("total_score", 0))
		if score <= 0: continue
		var parts := dl.split("-")
		if parts.size() < 3: continue
		var date_str: String = "%04d%02d%02d" % [int(parts[0]), int(parts[1]), int(parts[2])]
		lines.append("BEGIN:VEVENT")
		lines.append("UID:score-%s@moonseed" % dl)
		lines.append("DTSTART;VALUE=DATE:" + date_str)
		lines.append("DTEND;VALUE=DATE:" + date_str)
		lines.append("SUMMARY:Moonpearls Score: %d" % score)
		lines.append("END:VEVENT")

	lines.append("END:VCALENDAR")
	var ics_text: String  = "\r\n".join(lines) + "\r\n"
	var save_path: String = "user://moonseed_calendar.ics"
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(ics_text)
		f.close()
		_show_export_msg("Calendar exported!\n%s" % ProjectSettings.globalize_path(save_path))
	else:
		_show_export_msg("Export failed -- could not write file.")


func _get_events_for_day(year: int, month: int, day: int) -> Array:
		var events: Array = []
		var target_str := "%04d-%02d-%02d" % [year, month, day]

		# Contracts with deadlines on this date
		for c in Database.get_contracts(GameData.current_profile, false):
			var dl: String = str(c.get("deadline", ""))
			if dl.length() >= 10 and dl.begins_with("%04d-%02d-%02d" % [year, month, day]):
				events.append({
					"type": "Contract",
					"title": str(c.get("name", "Contract")),
					"desc": str(c.get("description", "")),
					"raw": c,
					"color": Color("#FF8C00")
				})

		# Score / stat events
		var rec: Variant = Database.get_dice_box_stat(target_str, GameData.current_profile)
		if rec != null:
			var score := int(rec.get("total_score", 0))
			if score > 0:
				events.append({
					"type": "Score",
					"title": "Moonpearls Score: %d" % score,
					"desc": "",
					"raw": rec,
					"color": Color("#7B1FCC")
				})

		# TODO: include Reminders and other event sources
		return events


func _open_day_detail(day: int) -> void:
		var year: int = GameData.view_date.year
		var month: int = GameData.view_date.month
		var events := _get_events_for_day(year, month, day)

		var popup := PopupPanel.new()
		add_child(popup)

		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.custom_minimum_size = Vector2(360, 260)
		popup.add_child(v)

		var title := Label.new()
		title.text = "%s %d — Day %d" % [MONTHS[month - 1], year, day]
		title.add_theme_color_override("font_color", GameData.ACCENT_GOLD)
		title.add_theme_font_size_override("font_size", GameData.scaled_font_size(14))
		v.add_child(title)

		var list := VBoxContainer.new()
		list.custom_minimum_size = Vector2(0, 160)
		list.add_theme_constant_override("separation", 6)
		v.add_child(list)

		var active_filter := 0
		if is_instance_valid(_filter_select):
			active_filter = _filter_select.get_selected_id()
		var search_text := ""
		if is_instance_valid(_search_box):
			search_text = _search_box.text.strip_edges().to_lower()

		if events.size() == 0:
			var lbl := Label.new()
			lbl.text = "No events for this day."
			lbl.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.7))
			list.add_child(lbl)
		else:
			for ev in events:
				# Apply toolbar filters/search
				var ev_type: String = ev.get("type", "")
				var ev_title := str(ev.get("title", ""))
				var ev_desc := str(ev.get("desc", ""))
				if active_filter == 1 and ev_type != "Contract":
					continue
				if active_filter == 2 and ev_type != "Score":
					continue
				if active_filter == 3 and ev_type != "Reminder":
					continue
				if search_text != "" and not (ev_title.to_lower().find(search_text) >= 0 or ev_desc.to_lower().find(search_text) >= 0):
					continue

				var h := HBoxContainer.new()
				h.add_theme_constant_override("separation", 8)
				list.add_child(h)

				var swatch := ColorRect.new()
				swatch.color = ev.color
				swatch.custom_minimum_size = Vector2(16, 16)
				h.add_child(swatch)

				var info := VBoxContainer.new()
				var t := Label.new()
				t.text = ev.title
				t.add_theme_color_override("font_color", GameData.FG_COLOR)
				t.add_theme_font_size_override("font_size", GameData.scaled_font_size(12))
				info.add_child(t)
				if ev.desc != "":
					var d := Label.new()
					d.text = ev.desc
					d.add_theme_color_override("font_color", Color(GameData.FG_COLOR, 0.6))
					d.add_theme_font_size_override("font_size", GameData.scaled_font_size(10))
					info.add_child(d)
				h.add_child(info)

				var btns := VBoxContainer.new()
				btns.size_flags_horizontal = Control.SIZE_FILL
				btns.alignment = BoxContainer.ALIGNMENT_END
				var open_btn := Button.new()
				open_btn.text = "Open"
				var _open_cb := func(_ev=ev): _on_open_event(_ev)
				open_btn.pressed.connect(_open_cb)
				btns.add_child(open_btn)
				h.add_child(btns)

		var footer := HBoxContainer.new()
		footer.alignment = BoxContainer.ALIGNMENT_END
		footer.add_theme_constant_override("separation", 8)
		v.add_child(footer)

		var goto := Button.new()
		goto.text = "Go To Day"
		var _goto_cb := func(d=day):
			popup.queue_free()
			_jump_to_day(d)
		goto.pressed.connect(_goto_cb)
		footer.add_child(goto)

		var close := Button.new()
		close.text = "Close"
		var _close_cb := func(): popup.queue_free()
		close.pressed.connect(_close_cb)
		footer.add_child(close)

		popup.popup_centered()


func _on_open_event(ev: Dictionary) -> void:
	# Introduce ev_type to this scope
	var ev_type: String = ev.get("type", "") 
	if ev_type == "Contract":
		var c: Variant = ev.get("raw", null)
		_show_export_msg("Open Contract: %s" % str(c.get("name", "")))
	else:
		_show_export_msg("Event: %s" % str(ev.get("title", "")))

func _on_filter_changed(_idx: int) -> void:
		_build_grid()


func _on_search_text_changed(_text: String) -> void:
		# debounce not necessary for small datasets; rebuild grid to reflect search
		# currently only affects day detail listing when opened
		pass

func _show_export_msg(text: String) -> void:
	var d := AcceptDialog.new(); d.title = "Export"; d.dialog_text = text
	add_child(d); d.popup_centered()
	var _dlg_close_cb := func(): d.queue_free()
	d.confirmed.connect(_dlg_close_cb)

func _on_theme_changed_cal() -> void:
	_build_ui()
	_refresh()

func _curio_canister_is_active(r) -> bool:
	return r.active

func _save_current_day() -> void:
	var date_str: String = GameData.get_date_string()
	if GameData.dice_results.is_empty(): return
	var rolls_parts: Array = []
	for task_id in GameData.dice_results:
		rolls_parts.append("%d:%d" % [task_id, GameData.dice_results[task_id]])
	for curio_canister in GameData.curio_canisters:
		if curio_canister.active: rolls_parts.append("J:%d" % curio_canister.id)
	var completed_names: Array = []
	for t in GameData.tasks:
		if t.completed: completed_names.append(t.task)
	var active_curio_canisters: Array = GameData.curio_canisters.filter(_curio_canister_is_active)
	var result: Dictionary = GameData.calculate_score(
		GameData.dice_results, active_curio_canisters, GameData.jokers_owned)
	# Compute previous saved score before we overwrite it, so award delta
	# can be computed against the prior persisted value.
	var existing_rec = Database.get_dice_box_stat(date_str, GameData.current_profile)
	var prev_saved_score: int = 0
	if existing_rec != null:
		prev_saved_score = int(existing_rec.get("total_score", 0))
	Database.save_dice_box_stat(date_str, GameData.current_profile,
		"|".join(rolls_parts), ",".join(completed_names), result.score, "")
	# Only award when an explicit Roll All triggered the save; respect GameData flag.
	if GameData.allow_next_award:
		var moonpearls_delta: int = Database.award_dice_box_moonpearls(date_str, GameData.current_profile, result.score, prev_saved_score)
		GameData.allow_next_award = false
		if moonpearls_delta > 0:
			# Database.award_dice_box_moonpearls now commits the delta directly
			# to the canonical wallet. Emit score_saved for presentation FX.
			SignalBus.score_saved.emit(result.score, moonpearls_delta)
