extends Node

# ─────────────────────────────────────────────────────────────────
# btn_phase4_generator.gd  —  Moonseed Button Art Phase 4 Generator
#
# Creates placeholder PNGs for:
#   btn_tab_sm      × 5 states  (192 × 72 px  2× canvas)
#   btn_icon_circle × 5 states  (96  × 96 px  2× canvas)
#   Total: 10 PNGs
#
# Palette (BUTTON_STYLE_GUIDE.md §2):
#   btn_tab_sm      → purple family (distinct from primary_lg by brightness)
#   btn_icon_circle → secondary purple base; selected uses teal/magenta shift
#
# Art notes for final paint pass:
#   btn_tab_sm      → top corners pill-rounded, bottom edge FLAT (no radius)
#                     selected state: brighter face, no bottom shadow, merges
#                     seamlessly with panel below (§16 Phase 4 note)
#   btn_icon_circle → perfect circle (border-radius 50%), no icon baked in;
#                     icon composited in-engine over the shape layer
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
		"btn_tab_sm", 192, 72,
		[
			["btn_tab_sm_normal.png",   Color(0.196, 0.082, 0.529, 1.0)],  # #321587  mid-violet
			["btn_tab_sm_hover.png",    Color(0.380, 0.157, 0.729, 1.0)],  # #6128BA  lighter violet
			["btn_tab_sm_pressed.png",  Color(0.122, 0.043, 0.329, 1.0)],  # #1F0B54  dark violet
			["btn_tab_sm_disabled.png", Color(0.302, 0.271, 0.408, 1.0)],  # #4D4568  muted purple-gray
			["btn_tab_sm_selected.png", Color(0.510, 0.208, 0.867, 1.0)],  # #8235DD  bright/active violet
		]
	],
	[
		"btn_icon_circle", 96, 96,
		[
			["btn_icon_circle_normal.png",   Color(0.157, 0.055, 0.478, 1.0)],  # #290E7A  primary purple
			["btn_icon_circle_hover.png",    Color(0.310, 0.110, 0.698, 1.0)],  # #4F1CB2  lighter
			["btn_icon_circle_pressed.png",  Color(0.094, 0.027, 0.282, 1.0)],  # #180748  dark
			["btn_icon_circle_disabled.png", Color(0.282, 0.259, 0.376, 1.0)],  # #484260  muted gray
			["btn_icon_circle_selected.png", Color(0.035, 0.620, 0.663, 1.0)],  # #099EA9  teal (toggled-on)
		]
	],
]


func _ready() -> void:
	print("\n── btn_phase4_generator ──────────────────────────")

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
	print("  2. Run BtnPhase4Validator → expect PHASE 4 placeholder-PASS.")
	print("  3. Paint each state in Krita:")
	print("")
	print("     btn_tab_sm  (192 × 72 px — top-pill, flat bottom)")
	print("       normal   → mid-violet face, top corners rounded, bottom edge flat")
	print("       hover    → §13 hover deltas")
	print("       pressed  → §13 pressed deltas (slightly inset top)")
	print("       disabled → §13 disabled deltas")
	print("       selected → bright face, NO bottom shadow; bottom edge merges")
	print("                  cleanly with panel below (P0 critical)")
	print("")
	print("     btn_icon_circle  (96 × 96 px — perfect circle, no icon baked)")
	print("       normal   → purple base circle, gloss arc, ring border")
	print("       hover    → §13 hover deltas")
	print("       pressed  → §13 pressed deltas")
	print("       disabled → §13 disabled deltas")
	print("       selected → teal/magenta fill shift (toggled-on state, P1)")
	print("                  Icon composited over shape in-engine, not baked.")
	print("")
	print("  4. Export → overwrite same filenames → re-run BtnPhase4Validator.")
	print("  5. All checks green → Phase 4 complete → proceed to Phase 5 (merchants).")
	print("──────────────────────────────────────────────────\n")


func _print_rescan_hint() -> void:
	print("  ⚠  Rescan not available outside editor.")
	print("     In Godot editor: FileSystem panel → right-click → Rescan")
