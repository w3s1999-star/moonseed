extends Node

# ─────────────────────────────────────────────────────────────────
# btn_phase5_generator.gd  —  Moonseed Button Art Phase 5 Generator
#
# Creates placeholder PNGs for all 5 Bazaar merchant variants:
#   btn_merchant_pearl    × 5 states  (320 × 104 px 2× canvas)
#   btn_merchant_dice     × 5 states  (320 × 104 px 2× canvas)
#   btn_merchant_curio    × 5 states  (320 × 104 px 2× canvas)
#   btn_merchant_sweet    × 5 states  (320 × 104 px 2× canvas)
#   btn_merchant_selenic  × 5 states  (320 × 104 px 2× canvas)
#   Total: 25 PNGs  →  res://assets/ui/buttons/merchants/
#
# Placeholder palettes (from BUTTON_STYLE_GUIDE.md §14):
#   Pearl Exchange   → nacreous ice-teal   (#B8EEF0 base family)
#   Dice Carver      → dark faceted-purple (#3D2C58 base family)
#   Curio Dealer     → midnight indigo     (#2A1A6E base family)
#   Sweetmaker Stall → candy rose-pink     (#E87AB0 base family)
#   Selenic Exchange → silver lavender     (#9890C8 base family)
#
# Art notes for final paint pass:
#   All use the same pill shape + state deltas as btn_shop_merchant.
#   Apply §14 merchant-specific fill gradients, gloss, and ornaments
#   over the shop-button silhouette. Start from the merchant's own
#   normal palette, then apply §13 state deltas relative to that base.
#
# HOW TO RUN:
#   File → New Scene → Other Node → Node → attach this script
#   Scene → Run Current Scene (or F6)
# ─────────────────────────────────────────────────────────────────

const _W   := 320
const _H   := 104
const _DIR := "res://assets/ui/buttons/merchants/"

const _GROUPS: Array = [
	# [ group_label, states[] ]
	# states: [ filename, Color ]

	[
		"Pearl Exchange  (#B8EEF0 ice-teal)", [
			["btn_merchant_pearl_normal.png",   Color(0.600, 0.867, 0.878, 1.0)],  # #99DDE0
			["btn_merchant_pearl_hover.png",    Color(0.784, 0.957, 0.973, 1.0)],  # #C8F4F8
			["btn_merchant_pearl_pressed.png",  Color(0.239, 0.541, 0.573, 1.0)],  # #3D8A92
			["btn_merchant_pearl_disabled.png", Color(0.353, 0.471, 0.502, 1.0)],  # #5A7880
			["btn_merchant_pearl_selected.png", Color(0.910, 1.000, 1.000, 1.0)],  # #E8FEFF
		]
	],
	[
		"Dice Carver  (#3D2C58 dark-purple)", [
			["btn_merchant_dice_normal.png",    Color(0.239, 0.173, 0.345, 1.0)],  # #3D2C58
			["btn_merchant_dice_hover.png",     Color(0.416, 0.314, 0.565, 1.0)],  # #6A5090
			["btn_merchant_dice_pressed.png",   Color(0.118, 0.063, 0.188, 1.0)],  # #1E1030
			["btn_merchant_dice_disabled.png",  Color(0.290, 0.251, 0.376, 1.0)],  # #4A4060
			["btn_merchant_dice_selected.png",  Color(0.784, 0.659, 1.000, 1.0)],  # #C8A8FF
		]
	],
	[
		"Curio Dealer  (#2A1A6E midnight-indigo)", [
			["btn_merchant_curio_normal.png",   Color(0.165, 0.102, 0.431, 1.0)],  # #2A1A6E
			["btn_merchant_curio_hover.png",    Color(0.290, 0.188, 0.659, 1.0)],  # #4A30A8
			["btn_merchant_curio_pressed.png",  Color(0.039, 0.031, 0.188, 1.0)],  # #0A0830
			["btn_merchant_curio_disabled.png", Color(0.227, 0.204, 0.376, 1.0)],  # #3A3460
			["btn_merchant_curio_selected.png", Color(0.439, 0.376, 0.784, 1.0)],  # #7060C8
		]
	],
	[
		"Sweetmaker Stall  (#E87AB0 candy-rose)", [
			["btn_merchant_sweet_normal.png",   Color(0.910, 0.478, 0.690, 1.0)],  # #E87AB0
			["btn_merchant_sweet_hover.png",    Color(1.000, 0.690, 0.847, 1.0)],  # #FFB0D8
			["btn_merchant_sweet_pressed.png",  Color(0.510, 0.125, 0.353, 1.0)],  # #82205A
			["btn_merchant_sweet_disabled.png", Color(0.604, 0.408, 0.502, 1.0)],  # #9A6880
			["btn_merchant_sweet_selected.png", Color(0.753, 0.251, 0.847, 1.0)],  # #C040D8
		]
	],
	[
		"Selenic Exchange  (#9890C8 silver-lavender)", [
			["btn_merchant_selenic_normal.png",   Color(0.596, 0.565, 0.784, 1.0)],  # #9890C8
			["btn_merchant_selenic_hover.png",    Color(0.784, 0.769, 0.941, 1.0)],  # #C8C4F0
			["btn_merchant_selenic_pressed.png",  Color(0.290, 0.267, 0.439, 1.0)],  # #4A4470
			["btn_merchant_selenic_disabled.png", Color(0.416, 0.408, 0.502, 1.0)],  # #6A6880
			["btn_merchant_selenic_selected.png", Color(0.973, 0.965, 1.000, 1.0)],  # #F8F6FF
		]
	],
]


func _ready() -> void:
	print("\n── btn_phase5_generator ──────────────────────────")

	var abs_dir := ProjectSettings.globalize_path(_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		var err := DirAccess.make_dir_recursive_absolute(abs_dir)
		if err != OK:
			push_error("Could not create directory: %s  (error %d)" % [abs_dir, err])
			return
		print("  Created directory: %s" % abs_dir)
	else:
		print("  Directory OK:      %s" % abs_dir)

	var ok_count  := 0
	var fail_count := 0

	for group in _GROUPS:
		var group_label: String = group[0]
		var states: Array       = group[1]

		print("")
		print("  ── %s ──" % group_label)

		for state in states:
			var filename: String = state[0]
			var fill: Color      = state[1]
			var abs_path := abs_dir + filename

			var img := Image.create(_W, _H, false, Image.FORMAT_RGBA8)
			img.fill(fill)

			var err := img.save_png(abs_path)
			if err == OK:
				print("  [OK]  %s" % filename)
				ok_count += 1
			else:
				push_error("Failed to save %s  (error %d)" % [abs_path, err])
				print("  [ERR] %s — save failed (error %d)" % [filename, err])
				fail_count += 1

	print("")
	if fail_count == 0:
		print("  All %d placeholder PNGs written." % ok_count)
	else:
		print("  %d written, %d FAILED — check Output for errors." % [ok_count, fail_count])

	print("")
	if Engine.is_editor_hint():
		var ei = Engine.get_singleton("EditorInterface")
		if ei and ei.has_method("get_resource_filesystem"):
			ei.get_resource_filesystem().scan()
			print("  FileSystem rescan triggered.")
		else:
			_print_rescan_hint()
	else:
		_print_rescan_hint()

	print("")
	print("  NEXT STEPS:")
	print("  ─────────────────────────────────────────────────")
	print("  1. Rescan FileSystem panel if prompted above.")
	print("  2. Run BtnPhase5Validator → expect PHASE 5 placeholder-PASS.")
	print("  3. Paint each merchant in Krita (320 × 104 px — same silhouette")
	print("     as btn_shop_merchant; apply §14 fills + ornaments):")
	print("")
	print("     Pearl Exchange   → ice-teal gradient #B8EEF0→#099EA9→#065F66")
	print("                        +nacreous ring ornament, wet-bright gloss")
	print("     Dice Carver      → dark purple #5A4870→#3D2C58→#1E1030")
	print("                        +facet-strip gloss, ⚅ pip cluster ornament")
	print("     Curio Dealer     → midnight indigo #2A1A6E→#1C1050→#0A0830")
	print("                        +internal dim glow, runic eye ornament")
	print("     Sweetmaker Stall → candy rose #E87AB0→#C0408A→#82205A")
	print("                        +candy-bright hotspot, sprinkle-dot ornament")
	print("     Selenic Exchange → silver lavender #D8D4F0→#9890C8→#4A4470")
	print("                        +cool-ambient gloss, crescent-rule ornament")
	print("")
	print("     All: apply §13 state deltas starting from the merchant's")
	print("     own normal palette, not from the primary-button palette.")
	print("")
	print("  4. Export → overwrite same filenames → re-run BtnPhase5Validator.")
	print("  5. All 11 checks green → Phase 5 complete → Phase 6 polish pass.")
	print("──────────────────────────────────────────────────\n")


func _print_rescan_hint() -> void:
	print("  ⚠  Rescan not available outside editor.")
	print("     In Godot editor: FileSystem panel → right-click → Rescan")
