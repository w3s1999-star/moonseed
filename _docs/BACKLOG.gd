# ═══════════════════════════════════════════════════════════════════
# MOONSEED  —  BACKLOG & ROADMAP  (read-only dev note)
# Updated: v0.9.0  |  Tracks all deferred items from code-reviews
# ═══════════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────────
# P0 — MUST FIX BEFORE SHIP
# ───────────────────────────────────────────────────────────────────
#
# [ ] ROLL GUARD — historical days
#     _roll_hand() and _roll_single_task() do not prevent rolling on
#     past days, which overwrites saved layouts.
#     FIX: add at top of each:
#       if GameData.view_date != GameData.get_today_dict(): return
#
# [ ] MAIN.TSN — _build_ui() is script-only, not mirrored in scene.
#     Risky for font-scale changes and layout iteration.
#     PLAN: Add a Main_layout.tscn with all structural nodes, reduce
#     Main.gd to _apply_styles() + signal wiring only.
#
# [ ] LUNAR BAZAAR TSCN — now exists (scenes/LunarBazaarTab.tscn) but
#     PRIMARY_TABS in Main.gd still points to the .gd file.
#     UPDATE Main.gd:
#       ["lunarbazaar", "🌙 BAZAAR", "res://scenes/LunarBazaarTab.tscn", false],
#
# [ ] CONFECTIONERY TSCN — same as above.
#     UPDATE Main.gd:
#       ["confectionery", "🍬 CONFECT", "res://scenes/ConfectioneryTab.tscn", false],

# ───────────────────────────────────────────────────────────────────
# P1 — HIGH PRIORITY  (target v0.9.x)
# ───────────────────────────────────────────────────────────────────
#
# [ ] ROLODEX NAV — secondary-nav (top icon row) mini Rolodex
#     Currently plain HBox emoji buttons.
#     Design: same card-drop barrel curve, narrower card width.
#
# [ ] SCREEN SHAKE on max-face roll
#     Hook in DiceTableArea: when result == sides, emit
#       SignalBus.fx_die_shockwave with shake flag.
#     PlayTab handles: Juice.screen_shake(get_viewport(), 5.0, 0.2)
#
# [ ] COUNT-UP ANIMATION on score banner
#     Replace instant label update with:
#       Juice.count_up(_score_total, old_val, new_val, 0.4)
#
# [ ] GARDEN — Plant info tooltip on hover
#     Coins     — dice box-use currency. Spent in Shop, earned via Bazaar.
#     Move to a tooltip Control anchored near the 3D click point.
#
# [ ] SHOP — Animate item cards on dice box refresh
#     Use Juice.bounce_in() staggered per card (0.08s delay each).
#
# [ ] CONFECTIONERY — Boiler animation linked to actual timer
#     Currently loops at a fixed rate. Change frame rate to
#     map to session urgency (faster as time_remaining → 0).

# ───────────────────────────────────────────────────────────────────
# P2 — MEDIUM PRIORITY  (target v1.0)
# ───────────────────────────────────────────────────────────────────
#
# [ ] ROLODEX — 3D SubViewport for true barrel perspective distortion.
#     Current: 2D approximation (card drops + offset² curve).
#
# [ ] ROLODEX CARD FLIP SOUND on tab switch.
#     DiceSound has a good pool; add a softer "whoosh" WAV.
#
# [ ] PLACEHOLDER ART PIPELINE
#     Hook ArtReg.has_art() check into GalleryTab so art team can
#     hot-reload PNG sprites without a full restart.
#
# [ ] DATABASE MIGRATION to Godot ConfigFile or GDExtension SQLite
#     for atomic writes and crash recovery.
#
# [ ] ENERGY SAVER — Screen dimmer after N minutes of inactivity.
#     autoloads/energy_saver.gd skeleton exists; finish it.
#
# [ ] LUNAR BAZAAR — Animated coin-press machine using Juice.squash_and_stretch()
#     on each mint event.
#
# [ ] CALENDAR — Heatmap view (weekly colour-coded by score tier).
#           → Database.set_dice_box_score(date, chips, mult, total).
#
# [ ] CONTRACTS — Early-completion streak bonus visual (stars burst)
#     Triggered by SignalBus.contract_early_bonus.

# ───────────────────────────────────────────────────────────────────
# P3 — NICE TO HAVE  (post v1.0 backlog)
# ───────────────────────────────────────────────────────────────────
#
# [ ] MULTIPLAYER / SHARED GARDEN — co-op watering via LAN/relay.
# [ ] SEASONAL EVENTS — Moon phase calendar + seasonal relics.
# [ ] MOONSEED NFT STUBS — wallet connect, keep behind feature flag.
# [ ] ACCESSIBILITY — screen-reader labels on all icon buttons.
# [ ] ANDROID EXPORT — touch targets need ≥ 48dp; audit all buttons.
# [ ] ACHIEVEMENT SYSTEM — Godot Achievements plugin or custom.

# ═══════════════════════════════════════════════════════════════════
# COMPLETED (from v0.8.1 Polish Pass)
# ═══════════════════════════════════════════════════════════════════
#
# [x] Score popup above each die (FXBus.score_popup)
# [x] Moondrops audio sequential + pitch ramp (DiceSound)
# [x] Moon-phase gate before scoring (await moon_overlay_dismissed)
# [x] Per-day dice layout save/restore (Database.set/get_dice_layout)
# [x] Placeholder art PNGs (21 icons under assets/ui/placeholders/)
# [x] RolodexNav 2D barrel nav (scripts/RolodexNav.gd)
# [x] FXBus centralised visual effects dispatcher
# [x] Juice.gd tween helper library (v0.9.0)
# [x] ButtonFeedback.gd standalone (no addon required) (v0.9.0)
# [x] LunarBazaarTab.tscn 2D scene scaffold (v0.9.0)
# [x] ConfectioneryTab.tscn 2D scene scaffold (v0.9.0)

# ═══════════════════════════════════════════════════════════════════
