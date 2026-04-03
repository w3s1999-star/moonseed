# ─────────────────────────────────────────────────────────────────
# PlaceholderGeneratorAutoload.gd
#
# Auto-generates placeholder PNGs on first run (dev/debug mode only).
# Add to Project Settings → Autoload as "PlaceholderGen"
# 
# In debug builds, will auto-generate on startup if dir doesn't exist.
# Disabled in release builds.
# ─────────────────────────────────────────────────────────────────

extends Node

const ASSET_DIR := "res://assets/textures/"
const SHOULD_AUTO_GENERATE := true  # Set to false to disable auto-generation

func _ready() -> void:
	if not SHOULD_AUTO_GENERATE:
		return
	
	# Only generate in debug builds
	if OS.is_debug_build():
		# Check if placeholders directory exists and has files
		var dir := DirAccess.open(ASSET_DIR)
		if not dir:
			print("[PlaceholderGen] Creating placeholders directory...")
			DirAccess.make_dir_absolute(ASSET_DIR)
			_generate_all()
		else:
			# Check if any placeholders exist
			dir.list_dir_begin()
			var file := dir.get_next()
			var has_pngs := false
			while file != "":
				if file.ends_with(".png"):
					has_pngs = true
					break
				file = dir.get_next()
			
			if not has_pngs:
				print("[PlaceholderGen] No placeholder PNGs found. Generating...")
				_generate_all()
			else:
				print("[PlaceholderGen] Placeholders already exist. Skipping generation.")
	else:
		print("[PlaceholderGen] Release build — skipping placeholder generation.")

func _generate_all() -> void:
	print("[PlaceholderGen] Generating all placeholder wireframes...")
	
	var size := Vector2i(128, 128)
	var colors = {
		"ingredient": Color(0.2, 0.8, 0.3),
		"recipe": Color(0.8, 0.4, 0.1),
		"gallery": Color(0.6, 0.2, 0.8),
		"equipment": Color(0.9, 0.8, 0.1),
		"minigame": Color(0.1, 0.6, 0.9),
		"tab": Color(0.5, 0.5, 0.5),
		"icon": Color(0.5, 0.5, 0.5),
	}
	
	var all_assets = {
		"ingredient_star_milk": "ingredient",
		"ingredient_void_cocoa": "ingredient",
		"ingredient_lunar_sugar": "ingredient",
		"ingredient_moonbloom_honey": "ingredient",
		"ingredient_rare_moon_drop": "ingredient",
		"ingredient_obsidian_dust": "ingredient",
		"ingredient_moonpearls_flake": "ingredient",
		
		"recipe_comet_truffle": "recipe",
		"recipe_eclipse_bonbon": "recipe",
		"recipe_jackpot_caramel": "recipe",
		"recipe_moonrise_fudge": "recipe",
		"recipe_void_praline": "recipe",
		"recipe_moonpearls_bark": "recipe",
		"recipe_silver_fern_cream": "recipe",
		"recipe_lucky_crunch": "recipe",
		"recipe_focus_bonbon": "recipe",
		
		"gallery_item_01": "gallery",
		"gallery_item_02": "gallery",
		"gallery_item_03": "gallery",
		
		"equipment_relic_luck": "equipment",
		"equipment_relic_multiplier": "equipment",
		"equipment_relic_garden": "equipment",
		"equipment_enhancement_speed": "equipment",
		"equipment_enhancement_focus": "equipment",
		
		"minigame_crafting_bg": "minigame",
		"minigame_crafting_pot": "minigame",
		"minigame_crafting_stir": "minigame",
		"minigame_countdown_dial": "minigame",
		
		"tab_table": "tab",
		"tab_garden": "tab",
		"tab_confect": "tab",
		"tab_cave": "tab",
		"tab_calendar": "tab",
		"tab_shop": "tab",
		"tab_gallery": "tab",
		"tab_contracts": "tab",
		"tab_settings": "tab",
		
		"icon_moondrop": "icon",
		"icon_moonpearls": "icon",
		"icon_moon_full": "icon",
		"icon_moon_new": "icon",
		"icon_curio": "icon",
		"icon_die_d6": "icon",
		"icon_die_d8": "icon",
		"icon_die_d20": "icon",
		"icon_water": "icon",
		"icon_food": "icon",
		"icon_seed": "icon",
		# coin placeholder removed
	}
	
	var count := 0
	for filename in all_assets.keys():
		var color_key = all_assets[filename]
		var color = colors.get(color_key, Color.GRAY)
		_create_placeholder_png(ASSET_DIR + filename + ".png", color, size)
		count += 1
	
	print("[PlaceholderGen] ✅ Generated %d placeholder PNGs" % count)

func _create_placeholder_png(path: String, color: Color, size: Vector2i) -> void:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	
	# Dark background
	image.fill(Color(0.15, 0.15, 0.15))
	
	# Colored border (3px)
	for x in range(size.x):
		for y in range(3):
			image.set_pixel(x, y, color)
			image.set_pixel(x, size.y - 1 - y, color)
	
	for y in range(size.y):
		for x in range(3):
			image.set_pixel(x, y, color)
			image.set_pixel(size.x - 1 - x, y, color)
	
	# Inner accent line
	var accent = color.darkened(0.3)
	for x in range(6, size.x - 6):
		image.set_pixel(x, 6, accent)
		image.set_pixel(x, size.y - 7, accent)
	
	for y in range(6, size.y - 6):
		image.set_pixel(6, y, accent)
		image.set_pixel(size.x - 7, y, accent)
	
	image.save_png(path)
