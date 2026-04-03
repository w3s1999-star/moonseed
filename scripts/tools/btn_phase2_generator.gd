extends Node

# ─────────────────────────────────────────────────────────────────
# btn_phase2_generator.gd  —  Moonseed Button Art Phase 2 Generator
#
# Creates placeholder PNGs for:
#   btn_primary_md  × 5 states  (360 × 104 px 2× canvas)
#   btn_secondary   × 5 states  (320 × 96 px  2× canvas)
#   Total: 10 PNGs
#
# Each state gets a distinct solid fill so BtnPhase2Validator can
# confirm uniqueness before real artwork is dropped in.
#
# Placeholder colors:
#   btn_primary_md  (violet family — slightly distinct from lg palette)
#     normal   → #3A1290  mid-violet
#     hover    → #7B29BA  lighter violet
#     pressed  → #200645  very dark
#     disabled → #514470  muted purple-gray
#     selected → #1BA8B4  sky teal
#
#   btn_secondary  (teal family — clearly distinct from primary)
#     normal   → #0D5058  dark teal
#     hover    → #118F99  mid teal
#     pressed  → #093840  very dark teal
#     disabled → #3A5258  gray-teal
#     selected → #C01898  magenta-rose
#
# REPLACE THESE with your painted PNGs — overwrite files at same
# paths and re-run BtnPhase2Validator to confirm.
#
# HOW TO RUN:
#   File → New Scene → Other Node → Node → attach this script
#   Scene → Run Current Scene (or F6)
# ─────────────────────────────────────────────────────────────────

const _DIR := "res://assets/ui/buttons/"

const _GROUPS: Array = [
	# [ group_label, width, height, states[] ]
	[
		"btn_primary_md", 360, 104,
		[
			["btn_primary_md_normal.png",   Color(0.227, 0.071, 0.565, 1.0)],  # #3A1290
			["btn_primary_md_hover.png",    Color(0.482, 0.161, 0.729, 1.0)],  # #7B29BA
			["btn_primary_md_pressed.png",  Color(0.125, 0.024, 0.271, 1.0)],  # #200645
			["btn_primary_md_disabled.png", Color(0.318, 0.267, 0.439, 1.0)],  # #514470
			["btn_primary_md_selected.png", Color(0.106, 0.659, 0.706, 1.0)],  # #1BA8B4
		]
	],
	[
		"btn_secondary", 320, 96,
		[
			["btn_secondary_normal.png",    Color(0.051, 0.314, 0.345, 1.0)],  # #0D5058
			["btn_secondary_hover.png",     Color(0.067, 0.561, 0.600, 1.0)],  # #118F99
			["btn_secondary_pressed.png",   Color(0.035, 0.220, 0.251, 1.0)],  # #093840
			["btn_secondary_disabled.png",  Color(0.227, 0.322, 0.345, 1.0)],  # #3A5258
			["btn_secondary_selected.png",  Color(0.753, 0.094, 0.596, 1.0)],  # #C01898
		]
	],
]


func _ready() -> void:
	print("\n── btn_phase2_generator ──────────────────────────")

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
			var filename: String  = state[0]
			var fill: Color       = state[1]
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

	# Attempt rescan
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
	print("  2. Run BtnPhase2Validator → expect PHASE 2 placeholder-PASS.")
	print("  3. Paint each state in Krita, referencing BUTTON_STYLE_GUIDE.md:")
	print("")
	print("     btn_primary_md  (360 × 104 px — scale §12 layer stack to 2× medium)")
	print("       normal   → same 9-layer stack as lg; body fill at 90% lg height")
	print("       hover    → §13 hover deltas")
	print("       pressed  → §13 pressed deltas")
	print("       disabled → §13 disabled deltas")
	print("       selected → §13 selected deltas")
	print("")
	print("     btn_secondary  (320 × 96 px — §6.2 specs)")
	print("       normal   → fill #290E7A→#1A0A35, gloss #6F1CB2, text #A1EBAC")
	print("       hover    → §13 hover deltas applied to secondary palette")
	print("       pressed  → §13 pressed deltas")
	print("       disabled → §13 disabled deltas")
	print("       selected → §13 selected deltas")
	print("")
	print("  4. Export → overwrite same filenames → re-run BtnPhase2Validator.")
	print("  5. All 10 checks green → Phase 2 complete → proceed to Phase 3.")
	print("──────────────────────────────────────────────────\n")


func _print_rescan_hint() -> void:
	print("  ⚠  Rescan not available outside editor.")
	print("     In Godot editor: FileSystem panel → right-click → Rescan")
