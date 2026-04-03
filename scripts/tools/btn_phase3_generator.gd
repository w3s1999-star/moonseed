extends Node

# ─────────────────────────────────────────────────────────────────
# btn_phase3_generator.gd  —  Moonseed Button Art Phase 3 Generator
#
# Creates placeholder PNGs for:
#   btn_confirm        × 5 states  (280 × 96 px  2× canvas)
#   btn_cancel         × 5 states  (280 × 96 px  2× canvas)
#   btn_shop_merchant  × 5 states  (320 × 104 px 2× canvas)
#   Total: 15 PNGs
#
# Palette references (BUTTON_STYLE_GUIDE.md §2 + §6.3–6.5):
#   btn_confirm  → teal family  (#099EA9 base)
#   btn_cancel   → danger rose  (#C0185A base)
#   btn_shop     → gold family  (#F5C842 base)
#
# REPLACE with final painted PNGs — same paths, re-run validator.
#
# HOW TO RUN:
#   File → New Scene → Other Node → Node → attach this script
#   Scene → Run Current Scene (or F6)
# ─────────────────────────────────────────────────────────────────

const _DIR := "res://assets/ui/buttons/"

const _GROUPS: Array = [
	# [ group_label, width, height, states[] ]
	# states: [ filename, Color ]
	[
		"btn_confirm", 280, 96,
		[
			["btn_confirm_normal.png",   Color(0.035, 0.620, 0.663, 1.0)],  # #099EA9  teal
			["btn_confirm_hover.png",    Color(0.141, 0.788, 0.839, 1.0)],  # #24C9D6  lighter teal
			["btn_confirm_pressed.png",  Color(0.024, 0.373, 0.400, 1.0)],  # #065F66  dark teal
			["btn_confirm_disabled.png", Color(0.275, 0.447, 0.455, 1.0)],  # #467274  muted teal-gray
			["btn_confirm_selected.png", Color(0.631, 0.925, 0.675, 1.0)],  # #A1EBAC  mint-green
		]
	],
	[
		"btn_cancel", 280, 96,
		[
			["btn_cancel_normal.png",    Color(0.753, 0.094, 0.353, 1.0)],  # #C0185A  danger rose
			["btn_cancel_hover.png",     Color(0.918, 0.188, 0.490, 1.0)],  # #EA307D  lighter rose
			["btn_cancel_pressed.png",   Color(0.490, 0.047, 0.220, 1.0)],  # #7D0C38  dark rose
			["btn_cancel_disabled.png",  Color(0.435, 0.306, 0.349, 1.0)],  # #6F4E59  muted rose-gray
			["btn_cancel_selected.png",  Color(0.886, 0.102, 0.882, 1.0)],  # #E21AE1  magenta accent
		]
	],
	[
		"btn_shop_merchant", 320, 104,
		[
			["btn_shop_merchant_normal.png",   Color(0.961, 0.784, 0.259, 1.0)],  # #F5C842  gold
			["btn_shop_merchant_hover.png",    Color(1.000, 0.902, 0.498, 1.0)],  # #FFE67F  pale gold
			["btn_shop_merchant_pressed.png",  Color(0.694, 0.533, 0.082, 1.0)],  # #B18815  dark amber
			["btn_shop_merchant_disabled.png", Color(0.549, 0.514, 0.384, 1.0)],  # #8C8362  muted gold-gray
			["btn_shop_merchant_selected.png", Color(0.980, 0.522, 0.118, 1.0)],  # #FA851E  warm orange
		]
	],
]


func _ready() -> void:
	print("\n── btn_phase3_generator ──────────────────────────")

	var abs_dir := ProjectSettings.globalize_path(_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		var err := DirAccess.make_dir_recursive_absolute(abs_dir)
		if err != OK:
			push_error("Could not create directory: %s  (error %d)" % [abs_dir, err])
			return
		print("  Created directory: %s" % abs_dir)
	else:
		print("  Directory OK:      %s" % abs_dir)

	var ok_count := 0
	var fail_count := 0

	for group in _GROUPS:
		var group_label: String = group[0]
		var w: int              = group[1]
		var h: int              = group[2]
		var states: Array       = group[3]

		print("")
		print("  ── %s  (%d × %d px) ─────────────────" % [group_label, w, h])

		for state in states:
			var filename: String = state[0]
			var fill: Color      = state[1]
			var abs_path := abs_dir + filename

			var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
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
	print("  2. Run BtnPhase3Validator → expect PHASE 3 placeholder-PASS.")
	print("  3. Paint each state in Krita, referencing BUTTON_STYLE_GUIDE.md:")
	print("")
	print("     btn_confirm  (280 × 96 px — §6.3)")
	print("       normal   → fill #099EA9→#065F66, gloss #A1EBAC, text #F0F8F4")
	print("       hover    → §13 hover deltas (teal palette)")
	print("       pressed  → §13 pressed deltas")
	print("       disabled → §13 disabled deltas")
	print("       selected → §13 selected deltas")
	print("")
	print("     btn_cancel  (280 × 96 px — §6.4)")
	print("       normal   → fill #C0185A→#7D0C38, reduced gloss (50%), text #F0F8F4")
	print("       hover/pressed/disabled/selected → §13 deltas on danger-rose palette")
	print("")
	print("     btn_shop_merchant  (320 × 104 px — §6.5)")
	print("       normal   → fill #F5C842→#B18815, gloss warm white, text #3A2800 bold")
	print("       hover/pressed/disabled/selected → §13 deltas on gold palette")
	print("")
	print("  4. Export → overwrite same filenames → re-run BtnPhase3Validator.")
	print("  5. All 10 checks green → Phase 3 complete → proceed to Phase 4.")
	print("──────────────────────────────────────────────────\n")


func _print_rescan_hint() -> void:
	print("  ⚠  Rescan not available outside editor.")
	print("     In Godot editor: FileSystem panel → right-click → Rescan")
