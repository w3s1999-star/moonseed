extends Node

# ─────────────────────────────────────────────────────────────────
# btn_phase6_generator.gd  —  Moonseed Button Art Phase 6 Generator
#
# Phase 6 — Polish Pass: P2 Selected-State Placeholder Update
#
# Writes (or overwrites) the 6 "P2 deferred selected" state PNGs with
# visually distinct gold-bordered placeholder art so artists know
# exactly which files need the final polish treatment:
#
#   • btn_primary_lg_selected.png      (408 × 120)
#   • btn_primary_md_selected.png      (360 × 104)
#   • btn_secondary_selected.png       (320 ×  96)
#   • btn_confirm_selected.png         (280 ×  96)
#   • btn_cancel_selected.png          (280 ×  96)
#   • btn_shop_merchant_selected.png   (320 × 104)
#
# Visual encoding:
#   • Gold (#FFD700) border (4 px) = "selected / P2 polish needed here"
#   • Warm-yellow fill, distinct per button type (identifies each file)
#   • Diamond center mark = confirms phase 6 generator ran
#
# HOW TO USE:
#   File → New Scene → other Node (root) → attach this script → F6
#   After running, re-import in the Godot editor (Project → Reimport).
# ─────────────────────────────────────────────────────────────────

const _BORDER_COL := Color("#FFD700")   # gold — marks "selected / P2"
const _BORDER_W   := 4                  # px, drawn inside canvas

# Each entry: [ res_path, width, height, fill_hex ]
const _ASSETS: Array = [
	["res://assets/ui/buttons/btn_primary_lg_selected.png",    408, 120, "#E8D060"],
	["res://assets/ui/buttons/btn_primary_md_selected.png",    360, 104, "#D4B840"],
	["res://assets/ui/buttons/btn_secondary_selected.png",     320,  96, "#C0A030"],
	["res://assets/ui/buttons/btn_confirm_selected.png",       280,  96, "#70D060"],
	["res://assets/ui/buttons/btn_cancel_selected.png",        280,  96, "#D06060"],
	["res://assets/ui/buttons/btn_shop_merchant_selected.png", 320, 104, "#F0C840"],
]


func _ready() -> void:
	var dir := DirAccess.open("res://assets/ui/buttons")
	if dir == null:
		push_error("Phase 6 generator: assets/ui/buttons/ not found — run phase 0 first.")
		return

	var count := 0
	for entry: Array in _ASSETS:
		var path: String = entry[0]
		var w: int       = entry[1]
		var h: int       = entry[2]
		var fill: Color  = Color(entry[3] as String)
		_write_p2_selected(path, w, h, fill)
		count += 1

	print("Phase 6 generator: %d P2 selected-state PNGs written." % count)
	print("  Gold border = visual marker for 'P2 polish needed here'.")
	print("  Replace each file with real painted art when the polish pass is done.")


func _write_p2_selected(path: String, w: int, h: int, fill: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)

	# Gold border — top and bottom rows
	for x: int in range(w):
		for b: int in range(_BORDER_W):
			img.set_pixel(x, b,         _BORDER_COL)
			img.set_pixel(x, h - 1 - b, _BORDER_COL)

	# Gold border — left and right columns
	for y: int in range(h):
		for b: int in range(_BORDER_W):
			img.set_pixel(b,         y, _BORDER_COL)
			img.set_pixel(w - 1 - b, y, _BORDER_COL)

	# Diamond center mark (compass points at ±8 px)
	var cx: int = w / 2
	var cy: int = h / 2
	for offset: int in [-8, -7, -6, 6, 7, 8]:
		img.set_pixel(cx + offset, cy,         _BORDER_COL)
		img.set_pixel(cx,         cy + offset, _BORDER_COL)

	var abs_path := ProjectSettings.globalize_path(path)
	img.save_png(abs_path)
	print("  Wrote: %s  (%d × %d)" % [path.get_file(), w, h])
