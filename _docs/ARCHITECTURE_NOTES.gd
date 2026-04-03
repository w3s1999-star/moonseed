# ═══════════════════════════════════════════════════════════════════
# MOONSEED  —  ARCHITECTURE NOTES  (read-only, not loaded at runtime)
# Senior Developer Reference · v0.9.0
# ═══════════════════════════════════════════════════════════════════
#
# This file is a living dev-doc. Open it in the Godot script editor
# to read. It is NOT attached to any node.
#
# ───────────────────────────────────────────────────────────────────
# SINGLETON MAP
# ───────────────────────────────────────────────────────────────────
#
# SignalBus     — Cross-scene event hub (NO direct node refs across scenes)
# GameData      — UI colours, theme, font scaling, moondrop helpers
# Database      — All game state (tasks, relics, scores, economy, garden)
# GardenSeedManager — Garden plant lifecycle + watering
# ButtonFeedback — Scale/spring hover/press animation for all Buttons
# DiceSound     — Audio pool for dice clack & scoring sounds
# FXBus         — One-liner particle/popup/shake visual effects
# Juice         — Tween helpers: punch_scale, count_up, screen_shake …
# ActiveBuffs   — Tracks currently active sweet consumable buffs
# IngredientData — Ingredient → sweet recipe definitions
#
# ───────────────────────────────────────────────────────────────────
# SCENE TREE
# ───────────────────────────────────────────────────────────────────
#
# Main.tscn  (Main.gd)
#  ├─ [ColorRect]  bg fill
#  ├─ [VBoxContainer]
#  │   ├─ [PanelContainer]  Contracts bar (28px ticker)
#  │   ├─ [HBoxContainer]   Header  (moonpearls | title | moon)
#  │   ├─ [Control]         _content  — tabs swapped in here
#  │   ├─ [HBoxContainer]   SecondaryNav  (Calendar/Shop/Gallery…)
#  │   └─ [HBoxContainer]   PrimaryNav    (Table/Garden/Confect/Cave)
#  └─ [CanvasLayer]  _transition  (TabTransition shader overlay)
#
# Tab scenes (all anchor FULL_RECT inside _content):
#   PlayTab.tscn          — dice table + task list + relic panel
#   GardenTab.tscn        — 3D SubViewport isometric garden
#   ConfectioneryTab.tscn — pomodoro timer + ingredient crafting
#   LunarBazaarTab.tscn  — hold-to-mint coin economy
#   CalendarTab.tscn      — weekly/monthly score history
#   ShopTab.tscn          — dice box seeded Balatro-style item shop
#   GalleryTab.tscn       — seed/relic art gallery
#   ContractsTab.tscn     — contract management
#   SettingsTab.tscn      — theme, font, misc preferences
#
# ───────────────────────────────────────────────────────────────────
# DATA FLOW — TYPICAL ROLL LOOP
# ───────────────────────────────────────────────────────────────────
#
#  1. Player ticks task checkbox
#       PlayTab._on_task_checked(id)
#           → SignalBus.task_checked.emit(id)
#
#  2. Player presses Roll All
#       PlayTab._roll_hand()
#           → DiceTableArea.throw_task_dice(name, sides, count, results[])
#
#  3. Dice physics settle
#       DiceTableArea.roll_finished.emit(total, sides)
#           → PlayTab._on_group_finished()
#               → _update_score()
#               → SignalBus.score_updated.emit(moondrops, star_power)
#               → FXBus.score_popup(pos, value)
#               → FXBus.die_shockwave(die_node, value, sides)
#
#  4. Player presses Save
#       PlayTab._on_save_pressed()
#           → Database.set_dice_box_score(date, chips, mult, total)
#           → SignalBus.score_saved.emit(final, delta)
#           → FXBus.rain_moonpearls(score, _fx_layer)
#           → FXBus.confetti_burst(_fx_layer)
#
# ───────────────────────────────────────────────────────────────────
# THEME SYSTEM
# ───────────────────────────────────────────────────────────────────
#
# GameData.THEMES dict holds all colour palettes.
# GameData.apply_theme(name) copies palette → live vars (BG_COLOR etc.)
# SignalBus.theme_changed.emit() → every tab's _on_theme_changed()
#   rebuilds StyleBoxes and Label overrides in-place.
#
# Palette keys used throughout codebase:
#   BG_COLOR, FG_COLOR, ACCENT_BLUE, ACCENT_RED, ACCENT_RELIC,
#   ACCENT_GOLD, CARD_BG, CARD_HL, TABLE_FELT,
#   DIE_COLORS{6,8,10,12,20}, RARITY_COLORS{common…exotic}
#
# ───────────────────────────────────────────────────────────────────
# FONT SCALING
# ───────────────────────────────────────────────────────────────────
#
# GameData.FONT_SCALE (default 1.0) is adjusted by SettingsTab.
# All font sizes should use:
#   GameData.scaled_font_size(base_pts)
# Do NOT hardcode pixel sizes in code — only in .tscn files where
# the scene editor will handle scaling differently.
#
# ───────────────────────────────────────────────────────────────────
# SIGNAL CONVENTIONS
# ───────────────────────────────────────────────────────────────────
#
# RULE: No script may connect() to a signal on a node in ANOTHER scene.
#       All cross-scene signals must route through SignalBus.
#
# NAMING:
#   Signals that carry data:   noun_verbed(data)     e.g. score_updated(n, m)
#   Signals that are events:   noun_verbed()          e.g. garden_watered()
#   FX request signals:        fx_thing(params)       e.g. fx_die_shockwave(…)
#
# ───────────────────────────────────────────────────────────────────
# ECONOMY CONSTANTS (Database)
# ───────────────────────────────────────────────────────────────────
#
#  Moonpearls (MP) #moonpearls — permanent meta-score. Earned by saving dice box rolls.
#              Spent in Shop and by Lunar Bazaar (100 MP per coin).
#  Coins     — dice box-use currency. Spent in Shop, earned via Bazaar.
#  Moondrops (MD) #moondrops — the primary roll score unit (chips × multiplier).
#  Star Power — the multiplier from active relics / buffs.
#  Water     — 0.0 → 1.0, fills as dice boxes are completed; grows garden.
#
# ───────────────────────────────────────────────────────────────────
# KNOWN TECH DEBT
# ───────────────────────────────────────────────────────────────────
#
# • Main.gd _build_ui() — entire layout generated in code; should be
#   moved to Main.tscn for easier visual iteration. Currently safe
#   but fragile under font-scale changes.
#
# • GardenTab.gd builds all 3D scene in _ready(); no .tscn. Acceptable
#   because the SubViewport geometry is procedural (grass multimesh).
#
# • Several tabs store local _build_ui() state that is fully discarded
#   on theme change (queue_free all children). Prefer dirty-flag +
#   _apply_styles() pattern instead of full rebuild.
#
# • Database.gd uses a flat-file JSON store. For v1.0 ship, migrate
#   critical data to Godot ConfigFile or SQLite for atomic writes.
#
# ═══════════════════════════════════════════════════════════════════
# END OF NOTES
# ═══════════════════════════════════════════════════════════════════
