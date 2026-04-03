# ═══════════════════════════════════════════════════════════════════
# MOONSEED  —  CODE STYLE GUIDE  (read-only dev note)
# ═══════════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────────
# NAMING
# ───────────────────────────────────────────────────────────────────
#
# Autoloads:     PascalCase  (GameData, SignalBus, FXBus, Juice)
# Scene scripts: PascalCase  (PlayTab, GardenTab, Main)
# Signals:       snake_case  (score_updated, garden_watered)
# Variables:     _prefixed for privates, no prefix for exported/public
#   @onready:    _lbl_score, _btn_roll, _dice_table
#   Const:       ALL_CAPS    (THROW_SPEED, RARITY_SUIT)
#   Enum:        PascalCase  (enum Phase { NEW, WAXING … })
#
# Functions:
#   _ready / _process  — lifecycle (keep lean; delegate to helpers)
#   _build_ui()        — creates child nodes (call once in _ready)
#   _apply_styles()    — theme colours / StyleBoxes (call on theme_changed)
#   _refresh()         — re-reads Database and updates all labels
#   _on_signal_name()  — signal handlers
#   _setup_X()        — deferred one-time setup (audio pools, etc.)

# ───────────────────────────────────────────────────────────────────
# SCENE ORGANISATION
# ───────────────────────────────────────────────────────────────────
#
# scenes/    — .tscn files only.  One scene = one logical screen/tab.
# scripts/   — .gd files for scenes.  Named 1-to-1 with scene file.
# autoloads/ — Singletons. Stateful global services go here.
# shaders/   — .gdshader only. No inline shader strings in scripts.
# assets/    — Read-only at runtime. Never write to res://.
# _docs/     — Developer notes (.gd files, not loaded at runtime).
#
# Separate script-only utilities (DiceRoller, RolodexNav, etc.) live
# in scripts/ and are loaded via scene ext_resource or load().

# ───────────────────────────────────────────────────────────────────
# CROSS-SCENE COMMUNICATION
# ───────────────────────────────────────────────────────────────────
#
# ONLY via SignalBus.  No script may call get_node("/root/OtherScene/…")
# on a node belonging to a different scene.
#
# Within-scene: @onready and direct child references are fine.
# Autoloads: direct calls are fine (they're always in the tree).

# ───────────────────────────────────────────────────────────────────
# UI BUILDING RULES
# ───────────────────────────────────────────────────────────────────
#
# Prefer .tscn for layout.  Script-only layout (_build_ui) is allowed
# for fully procedural or data-driven content (shop cards, task rows,
# garden plants) but structural chrome should live in the scene file.
#
# Font sizes:
#   ALWAYS:   GameData.scaled_font_size(base_pts)
#   NEVER:    lbl.add_theme_font_size_override("font_size", 14)
#             … unless the value is 0 (reset).
#
# Colours:
#   ALWAYS use GameData colour vars (GameData.ACCENT_BLUE, etc.)
#   NEVER hardcode hex strings in script — put them in GameData.THEMES.
#
# StyleBoxes:
#   Create with StyleBoxFlat.new() in _apply_styles().
#   Cache them in a var _sb_panel: StyleBoxFlat so theme refresh
#   can mutate the existing object instead of creating a new one.

# ───────────────────────────────────────────────────────────────────
# ANIMATION / JUICE RULES
# ───────────────────────────────────────────────────────────────────
#
# Use Juice.gd helpers for all one-shot UI animations.
# Use FXBus.gd for particle/overlay effects (rain, shockwave, popup).
# Never block gameplay with await on a cosmetic animation.
# Tween duration guidelines:
#   Micro feedback (button press):   0.06 – 0.12 s
#   Panel transitions:               0.20 – 0.35 s
#   Score count-up:                  0.4  – 0.7  s
#   Celebration FX:                  0.8  – 2.0  s

# ───────────────────────────────────────────────────────────────────
# AUDIO RULES
# ───────────────────────────────────────────────────────────────────
#
# All game sounds route through DiceSound or direct AudioStreamPlayer.
# Never play a sound inside _draw() or heavy _process() code.
# Use volume_db, not linear scale — keep master_volume a db value.
# Dice clacks:      -4.0 db default
# Score music:      -2.0 db default
# Moondrops score: -2.0 db default (matches GDD §17.3 spec)

# ═══════════════════════════════════════════════════════════════════
