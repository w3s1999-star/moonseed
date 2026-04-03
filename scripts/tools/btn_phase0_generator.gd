@tool
extends Node

# ─────────────────────────────────────────────────────────────────
# btn_phase0_generator.gd  —  Moonseed Button Art Phase 0 Setup
#
# Creates the button asset directory tree and a blank 408 × 120 px
# transparent PNG used to validate Godot import settings before
# any real button art exists.
#
# HOW TO RUN:
#   1. File → New Scene → Other Node → Node → (name it Phase0Generator)
#   2. Select the node → Inspector → Script → Attach → choose this file
#   3. Save the scene, then press F6 (Run Current Scene)
#   4. Check the Output panel for results and next-step instructions.
#   5. You can delete the scratch scene afterwards — it is not needed
#      for gameplay.
# ─────────────────────────────────────────────────────────────────

const _BUTTON_DIR    := "res://assets/ui/buttons/"
const _MERCHANT_DIR  := "res://assets/ui/buttons/merchants/"
const _BLANK_PATH    := "res://assets/ui/buttons/btn_template_blank.png"
const _CANVAS_W      := 408
const _CANVAS_H      := 120


func _ready() -> void:
	print("\n╔══════════════════════════════════════════════════╗")
	print("║  Moonseed — Phase 0: Button Asset Setup          ║")
	print("╚══════════════════════════════════════════════════╝\n")

	_create_dirs()
	_create_blank_png()
	_trigger_rescan()
	_print_import_instructions()
	_print_checklist()


# ── Directory creation ────────────────────────────────────────────

func _create_dirs() -> void:
	print("── Directories ─────────────────────────────────────")
	for path in [_BUTTON_DIR, _MERCHANT_DIR]:
		var abs := ProjectSettings.globalize_path(path)
		if DirAccess.dir_exists_absolute(abs):
			print("  [--] Already exists:  %s" % path)
		else:
			var err := DirAccess.make_dir_recursive_absolute(abs)
			if err == OK:
				print("  [OK] Created:         %s" % path)
			else:
				push_error("  [FAIL] Could not create %s  (error %d)" % [path, err])
	print("")


# ── Blank PNG ─────────────────────────────────────────────────────

func _create_blank_png() -> void:
	print("── Blank Template PNG ──────────────────────────────")

	if FileAccess.file_exists(_BLANK_PATH):
		print("  [--] Already exists:  %s" % _BLANK_PATH)
		print("       Delete it and re-run to regenerate.\n")
		return

	var img := Image.create(_CANVAS_W, _CANVAS_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))  # fully transparent

	var err := img.save_png(_BLANK_PATH)
	if err == OK:
		print("  [OK] Created:  %s" % _BLANK_PATH)
		print("       Size:     %d × %d px  (2× canvas)" % [_CANVAS_W, _CANVAS_H])
		print("       Fill:     transparent (alpha = 0)\n")
	else:
		push_error("  [FAIL] Could not save PNG — error code %d" % err)
	print("")


# ── Trigger reimport ──────────────────────────────────────────────

func _trigger_rescan() -> void:
	print("── FileSystem Rescan ────────────────────────────────")
	# Attempt to trigger a scan via EditorInterface (available in-editor only).
	if Engine.is_editor_hint():
		var ei := Engine.get_singleton(&"EditorInterface") if Engine.has_singleton(&"EditorInterface") else null
		if ei and ei.has_method("get_resource_filesystem"):
			ei.get_resource_filesystem().scan()
			print("  [OK] Scan triggered automatically.")
			print("       Wait for the FileSystem dock progress bar to finish.\n")
			return
	print("  [--] Auto-scan not available in this context.")
	print("       ACTION REQUIRED: In the Godot editor, click the FileSystem")
	print("       dock and press the Rescan button (circular arrow icon),")
	print("       OR close and reopen the project to trigger a full reimport.\n")


# ── Manual import settings reminder ──────────────────────────────

func _print_import_instructions() -> void:
	print("""── Import Settings (set manually after scan) ────────────
  1. FileSystem dock → assets/ui/buttons/ → btn_template_blank.png
  2. Open the Import panel (Import dock or Scene → Import)
  3. Set these values:

       Compress / Mode             → Lossless
       Texture / Filter            → Linear
       Mipmaps / Generate Mipmaps  → ON
       Process / Fix Alpha Border  → ON

  4. Click  Reimport

  These settings apply to every PNG in assets/ui/buttons/.
  You may also pre-write a .import override file — see the note
  at the bottom of this script for the format.
──────────────────────────────────────────────────────────────────
""")


# ── Milestone checklist ───────────────────────────────────────────

func _print_checklist() -> void:
	print("""── Phase 0 Milestone Checklist ──────────────────────────
  [ ] assets/ui/buttons/           directory exists
  [ ] assets/ui/buttons/merchants/ directory exists
  [ ] btn_template_blank.png       exists (408 × 120 px, transparent)
  [ ] Import settings applied      (Lossless, Linear, Mipmaps, Fix Alpha Border)
  [ ] Blank PNG wired to a TextureButton in BtnPhase0Validator scene
  [ ] Validator prints PASS in Output panel
  [ ] Gate approved — proceed to Phase 1 (btn_primary_lg_normal.png)
──────────────────────────────────────────────────────────────────
Next step: open scenes/tools/BtnPhase0Validator.tscn and run the scene.
""")


# ─────────────────────────────────────────────────────────────────
# APPENDIX — .import file format for button PNGs
#
# If you want to pre-configure import settings without clicking
# through the Import dock, create a file named:
#   <asset_name>.png.import
# alongside each PNG AFTER Godot has scanned it once,
# then edit the [params] section to match the values below.
#
# Example: btn_primary_lg_normal.png.import  [params] section:
#
#   compress/mode=0              ; 0 = Lossless
#   compress/high_quality=false
#   compress/lossy_quality=0.7
#   compress/normal_map=0
#   compress/channel_pack=0
#   mipmaps/generate=true
#   mipmaps/limit=-1
#   roughness/mode=0
#   roughness/src_normal=""
#   process/fix_alpha_border=true
#   process/premult_alpha=false
#   process/normal_map_invert_y=false
#   process/hdr_as_srgb=false
#   process/hdr_clamp_exposure=false
#   process/size_limit=0
#   detect_3d/compress_to=1
#
# Do NOT modify the [remap] or [deps] sections — those are
# auto-managed by the Godot import pipeline.
# ─────────────────────────────────────────────────────────────────
