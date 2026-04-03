extends Node

# ─────────────────────────────────────────────────────────────────
# btn_phase1_generator.gd  —  Moonseed Button Art Phase 1 Generator
#
# Creates placeholder 408 × 120 PNGs for all 5 btn_primary_lg states.
# Each state gets a distinct solid fill so BtnPhase1Validator can
# confirm they are all painted and visually unique even before the
# final artwork replaces them.
#
# Placeholder colors (from the Moonlight palette, §2 of BUTTON_STYLE_GUIDE.md):
#   normal   → #290E7A  deep violet   (base button tone)
#   hover    → #6F1CB2  rich purple   (lightened)
#   pressed  → #3D0857  darkened plum (depressed)
#   disabled → #4A4255  muted grayish (desaturated)
#   selected → #099EA9  teal          (selected accent)
#
# REPLACE THESE with your painted PNGs — overwrite the files at the
# same paths and re-run BtnPhase1Validator to confirm.
#
# HOW TO RUN:
#   File → New Scene → Other Node → Node → attach this script
#   Scene → Run Current Scene (or F6)
# ─────────────────────────────────────────────────────────────────

const _W := 408
const _H := 120
const _DIR := "res://assets/ui/buttons/"

const _STATES: Array = [
	# [ filename,                         placeholder_color,         label          ]
	["btn_primary_lg_normal.png",   Color(0.157, 0.055, 0.478, 1.0), "normal"],
	["btn_primary_lg_hover.png",    Color(0.435, 0.110, 0.698, 1.0), "hover"],
	["btn_primary_lg_pressed.png",  Color(0.239, 0.031, 0.325, 1.0), "pressed"],
	["btn_primary_lg_disabled.png", Color(0.290, 0.259, 0.333, 1.0), "disabled"],
	["btn_primary_lg_selected.png", Color(0.035, 0.620, 0.663, 1.0), "selected"],
]


func _ready() -> void:
	print("\n── btn_phase1_generator ──────────────────────────")

	# Ensure directory exists
	var abs_dir := ProjectSettings.globalize_path(_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		var err := DirAccess.make_dir_recursive_absolute(abs_dir)
		if err != OK:
			push_error("Could not create directory: %s  (error %d)" % [abs_dir, err])
			return
		print("  Created directory: %s" % abs_dir)
	else:
		print("  Directory OK:      %s" % abs_dir)

	# Generate each placeholder PNG
	var ok_count := 0
	var fail_count := 0

	for state in _STATES:
		var filename: String  = state[0]
		var fill_color: Color = state[1]
		var label: String     = state[2]
		var abs_path := abs_dir + filename

		var img := Image.create(_W, _H, false, Image.FORMAT_RGBA8)
		img.fill(fill_color)

		# Stamp centered text hint so placeholder is identifiable in Krita
		# (image.draw_string is unavailable without a CanvasItem; skip it —
		# the distinct colors are sufficient for validator differentiation)

		var err := img.save_png(abs_path)
		if err == OK:
			print("  [OK]  %s  (placeholder: %s)" % [filename, label])
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
	print("  2. Run BtnPhase1Validator → expect PHASE 1 placeholder-PASS.")
	print("  3. Open each placeholder PNG in Krita at 408 × 120 px.")
	print("  4. Paint each state per §12–13 of _docs/BUTTON_STYLE_GUIDE.md.")
	print("     normal   → §12  (9-layer paint stack)")
	print("     hover    → §13  (+brightness overlay, glow pulse +15%)")
	print("     pressed  → §13  (depress shadow, shift content down 2 px)")
	print("     disabled → §13  (desaturate 60%, reduce opacity 55%)")
	print("     selected → §13  (teal accent border, inner glow)")
	print("  5. Export → overwrite same filenames → re-run BtnPhase1Validator.")
	print("  6. All 10 checks green → Phase 1 complete.")
	print("──────────────────────────────────────────────────\n")


func _print_rescan_hint() -> void:
	print("  ⚠  Rescan not available outside editor.")
	print("     In Godot editor: FileSystem panel → right-click → Rescan")
	print("     (or just save a file — Godot auto-detects new PNGs)")
