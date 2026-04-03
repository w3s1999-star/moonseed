extends Node

# ─────────────────────────────────────────────────────────────────
# PlaceholderArtRegistry.gd  — Autoload (optional, name: ArtReg)
#
# Centralises every "temporary art" path so that when real sprites
# arrive the artist only needs to update this one file.
# Handles UI icons, ingredients, recipes, gallery items, equipment,
# and minigame assets.
#
# Usage:
#   ArtReg.texture_for("moondrop")     # From UI_ICONS
#   ArtReg.texture_for_ingredient("star_milk")  # Auto-prefixes
#   ArtReg.texture_for_recipe("comet_truffle")
#   ArtReg.has_art("ingredient:star_milk")
# ── Tab navigation icons ──────────────────────────────────────────
const TAB_ICONS: Dictionary = {
	"table":         "res://assets/textures/tab_table.png",
	"garden":        "res://assets/textures/tab_garden.png",
	"confectionery": "res://assets/textures/tab_confect.png",
	"lunarbazaar":   "res://assets/textures/tab_cave.png",
	"calendar":      "res://assets/textures/tab_calendar.png",
	"shop":          "res://assets/textures/tab_shop.png",
	"gallery":       "res://assets/textures/tab_gallery.png",
	"contracts":     "res://assets/textures/tab_contracts.png",
	"settings":      "res://assets/textures/tab_settings.png",
}

# ── General UI icons ──────────────────────────────────────────────
const UI_ICONS: Dictionary = {
	"moondrop":  "res://assets/textures/icon_starchunk.png",
	"moonpearls": "res://assets/textures/icon_stardust.png",
	"moon_full": "res://assets/textures/icon_moon_full.png",
	"moon_new":  "res://assets/textures/icon_moon_new.png",
	"curio":     "res://assets/textures/icon_curio.png",
	"die_d6":    "res://assets/textures/icon_die_d6.png",
	"die_d8":    "res://assets/textures/icon_die_d8.png",
	"die_d20":   "res://assets/textures/icon_die_d20.png",
	"water":     "res://assets/textures/icon_water.png",
	"food":      "res://assets/textures/icon_food.png",
	"seed":      "res://assets/textures/icon_seed.png",
	# coins removed — no coin icon
}

# ── Ingredient wireframes ─────────────────────────────────────────
# Keyed by ingredient ID from IngredientData.INGREDIENTS
const INGREDIENT_ICONS: Dictionary = {
	"star_milk":         "res://assets/textures/ingredient_star_milk.png",
	"void_cocoa":        "res://assets/textures/ingredient_void_cocoa.png",
	"lunar_sugar":       "res://assets/textures/ingredient_lunar_sugar.png",
	"moonbloom_honey":   "res://assets/textures/ingredient_moonbloom_honey.png",
	"rare_moon_drop":    "res://assets/textures/ingredient_rare_moon_drop.png",
	"obsidian_dust":     "res://assets/textures/ingredient_obsidian_dust.png",
	"moonpearls_flake":  "res://assets/textures/ingredient_stardust_flake.png",
}

# ── Recipe/sweet wireframes ───────────────────────────────────────
# Keyed by recipe ID from IngredientData.SWEETS
const RECIPE_ICONS: Dictionary = {
	"comet_truffle":       "res://assets/textures/recipe_comet_truffle.png",
	"eclipse_bonbon":      "res://assets/textures/recipe_eclipse_bonbon.png",
	"jackpot_caramel":     "res://assets/textures/recipe_jackpot_caramel.png",
	"moonrise_fudge":      "res://assets/textures/recipe_moonrise_fudge.png",
	"void_praline":        "res://assets/textures/recipe_void_praline.png",
	"moonpearls_bark":     "res://assets/textures/recipe_stardust_bark.png",
	"silver_fern_cream":   "res://assets/textures/recipe_silver_fern_cream.png",
	"lucky_crunch":        "res://assets/textures/recipe_lucky_crunch.png",
	"focus_bonbon":        "res://assets/textures/recipe_focus_bonbon.png",
}

# ── Gallery item wireframes ───────────────────────────────────────
# Keyed by gallery ID (expanded as gallery items are defined)
const GALLERY_ITEMS: Dictionary = {
	"gallery_placeholder_01": "res://assets/textures/gallery_item_01.png",
	"gallery_placeholder_02": "res://assets/textures/gallery_item_02.png",
	"gallery_placeholder_03": "res://assets/textures/gallery_item_03.png",
}

# ── Equipment/Item wireframes ─────────────────────────────────────
# Keyed by item ID (relic, enhancement, etc.)
const EQUIPMENT_ICONS: Dictionary = {
	"relic_luck":        "res://assets/textures/equipment_relic_luck.png",
	"relic_multiplier":  "res://assets/textures/equipment_relic_multiplier.png",
	"relic_garden":      "res://assets/textures/equipment_relic_garden.png",
	"enhancement_speed": "res://assets/textures/equipment_enhancement_speed.png",
	"enhancement_focus": "res://assets/textures/equipment_enhancement_focus.png",
}

# ── Minigame asset wireframes ─────────────────────────────────────
const MINIGAME_ASSETS: Dictionary = {
	"crafting_bg":       "res://assets/textures/minigame_crafting_bg.png",
	"crafting_pot":      "res://assets/textures/minigame_crafting_pot.png",
	"crafting_stir":     "res://assets/textures/minigame_crafting_stir.png",
	"countdown_dial":    "res://assets/textures/minigame_countdown_dial.png",
}

# ── UI buttons — standard set ────────────────────────────────────────────────
# Paths follow the pattern:  btn_{type}_{state}.png
# All live under  assets/ui/buttons/
# Files may not exist yet. has_art() returns false gracefully until exported.
const UI_BUTTONS: Dictionary = {
	# Phase 0 — template blank (generated by btn_phase0_generator.gd)
	"ui_button_template_blank":        "res://assets/ui/buttons/btn_template_blank.png",
	# Primary large
	"ui_button_primary_lg_normal":      "res://assets/ui/buttons/btn_primary_lg_normal.png",
	"ui_button_primary_lg_hover":       "res://assets/ui/buttons/btn_primary_lg_hover.png",
	"ui_button_primary_lg_pressed":     "res://assets/ui/buttons/btn_primary_lg_pressed.png",
	"ui_button_primary_lg_disabled":    "res://assets/ui/buttons/btn_primary_lg_disabled.png",
	"ui_button_primary_lg_selected":    "res://assets/ui/buttons/btn_primary_lg_selected.png",
	# Primary medium
	"ui_button_primary_md_normal":      "res://assets/ui/buttons/btn_primary_md_normal.png",
	"ui_button_primary_md_hover":       "res://assets/ui/buttons/btn_primary_md_hover.png",
	"ui_button_primary_md_pressed":     "res://assets/ui/buttons/btn_primary_md_pressed.png",
	"ui_button_primary_md_disabled":    "res://assets/ui/buttons/btn_primary_md_disabled.png",
	"ui_button_primary_md_selected":    "res://assets/ui/buttons/btn_primary_md_selected.png",
	# Secondary
	"ui_button_secondary_normal":       "res://assets/ui/buttons/btn_secondary_normal.png",
	"ui_button_secondary_hover":        "res://assets/ui/buttons/btn_secondary_hover.png",
	"ui_button_secondary_pressed":      "res://assets/ui/buttons/btn_secondary_pressed.png",
	"ui_button_secondary_disabled":     "res://assets/ui/buttons/btn_secondary_disabled.png",
	"ui_button_secondary_selected":     "res://assets/ui/buttons/btn_secondary_selected.png",
	# Tab small
	"ui_button_tab_sm_normal":          "res://assets/ui/buttons/btn_tab_sm_normal.png",
	"ui_button_tab_sm_hover":           "res://assets/ui/buttons/btn_tab_sm_hover.png",
	"ui_button_tab_sm_pressed":         "res://assets/ui/buttons/btn_tab_sm_pressed.png",
	"ui_button_tab_sm_disabled":        "res://assets/ui/buttons/btn_tab_sm_disabled.png",
	"ui_button_tab_sm_selected":        "res://assets/ui/buttons/btn_tab_sm_selected.png",
	# Icon circle
	"ui_button_icon_circle_normal":     "res://assets/ui/buttons/btn_icon_circle_normal.png",
	"ui_button_icon_circle_hover":      "res://assets/ui/buttons/btn_icon_circle_hover.png",
	"ui_button_icon_circle_pressed":    "res://assets/ui/buttons/btn_icon_circle_pressed.png",
	"ui_button_icon_circle_disabled":   "res://assets/ui/buttons/btn_icon_circle_disabled.png",
	"ui_button_icon_circle_selected":   "res://assets/ui/buttons/btn_icon_circle_selected.png",
	# Shop merchant (generic gold button)
	"ui_button_shop_normal":            "res://assets/ui/buttons/btn_shop_merchant_normal.png",
	"ui_button_shop_hover":             "res://assets/ui/buttons/btn_shop_merchant_hover.png",
	"ui_button_shop_pressed":           "res://assets/ui/buttons/btn_shop_merchant_pressed.png",
	"ui_button_shop_disabled":          "res://assets/ui/buttons/btn_shop_merchant_disabled.png",
	"ui_button_shop_selected":          "res://assets/ui/buttons/btn_shop_merchant_selected.png",
	# Confirm
	"ui_button_confirm_normal":         "res://assets/ui/buttons/btn_confirm_normal.png",
	"ui_button_confirm_hover":          "res://assets/ui/buttons/btn_confirm_hover.png",
	"ui_button_confirm_pressed":        "res://assets/ui/buttons/btn_confirm_pressed.png",
	"ui_button_confirm_disabled":       "res://assets/ui/buttons/btn_confirm_disabled.png",
	"ui_button_confirm_selected":       "res://assets/ui/buttons/btn_confirm_selected.png",
	# Cancel
	"ui_button_cancel_normal":          "res://assets/ui/buttons/btn_cancel_normal.png",
	"ui_button_cancel_hover":           "res://assets/ui/buttons/btn_cancel_hover.png",
	"ui_button_cancel_pressed":         "res://assets/ui/buttons/btn_cancel_pressed.png",
	"ui_button_cancel_disabled":        "res://assets/ui/buttons/btn_cancel_disabled.png",
	"ui_button_cancel_selected":        "res://assets/ui/buttons/btn_cancel_selected.png",
}

# ── UI buttons — Bazaar merchant variants ─────────────────────────────────────
# Paths follow the pattern:  btn_merchant_{vendor}_{state}.png
# All live under  assets/ui/buttons/merchants/
const MERCHANT_BUTTONS: Dictionary = {
	# Pearl Exchange
	"ui_button_merchant_pearl_normal":   "res://assets/ui/buttons/merchants/btn_merchant_pearl_normal.png",
	"ui_button_merchant_pearl_hover":    "res://assets/ui/buttons/merchants/btn_merchant_pearl_hover.png",
	"ui_button_merchant_pearl_pressed":  "res://assets/ui/buttons/merchants/btn_merchant_pearl_pressed.png",
	"ui_button_merchant_pearl_disabled": "res://assets/ui/buttons/merchants/btn_merchant_pearl_disabled.png",
	"ui_button_merchant_pearl_selected": "res://assets/ui/buttons/merchants/btn_merchant_pearl_selected.png",
	# Dice Carver
	"ui_button_merchant_dice_normal":    "res://assets/ui/buttons/merchants/btn_merchant_dice_normal.png",
	"ui_button_merchant_dice_hover":     "res://assets/ui/buttons/merchants/btn_merchant_dice_hover.png",
	"ui_button_merchant_dice_pressed":   "res://assets/ui/buttons/merchants/btn_merchant_dice_pressed.png",
	"ui_button_merchant_dice_disabled":  "res://assets/ui/buttons/merchants/btn_merchant_dice_disabled.png",
	"ui_button_merchant_dice_selected":  "res://assets/ui/buttons/merchants/btn_merchant_dice_selected.png",
	# Curio Dealer
	"ui_button_merchant_curio_normal":   "res://assets/ui/buttons/merchants/btn_merchant_curio_normal.png",
	"ui_button_merchant_curio_hover":    "res://assets/ui/buttons/merchants/btn_merchant_curio_hover.png",
	"ui_button_merchant_curio_pressed":  "res://assets/ui/buttons/merchants/btn_merchant_curio_pressed.png",
	"ui_button_merchant_curio_disabled": "res://assets/ui/buttons/merchants/btn_merchant_curio_disabled.png",
	"ui_button_merchant_curio_selected": "res://assets/ui/buttons/merchants/btn_merchant_curio_selected.png",
	# Sweetmaker Stall
	"ui_button_merchant_sweet_normal":   "res://assets/ui/buttons/merchants/btn_merchant_sweet_normal.png",
	"ui_button_merchant_sweet_hover":    "res://assets/ui/buttons/merchants/btn_merchant_sweet_hover.png",
	"ui_button_merchant_sweet_pressed":  "res://assets/ui/buttons/merchants/btn_merchant_sweet_pressed.png",
	"ui_button_merchant_sweet_disabled": "res://assets/ui/buttons/merchants/btn_merchant_sweet_disabled.png",
	"ui_button_merchant_sweet_selected": "res://assets/ui/buttons/merchants/btn_merchant_sweet_selected.png",
	# Selenic Exchange
	"ui_button_merchant_selenic_normal":   "res://assets/ui/buttons/merchants/btn_merchant_selenic_normal.png",
	"ui_button_merchant_selenic_hover":    "res://assets/ui/buttons/merchants/btn_merchant_selenic_hover.png",
	"ui_button_merchant_selenic_pressed":  "res://assets/ui/buttons/merchants/btn_merchant_selenic_pressed.png",
	"ui_button_merchant_selenic_disabled": "res://assets/ui/buttons/merchants/btn_merchant_selenic_disabled.png",
	"ui_button_merchant_selenic_selected": "res://assets/ui/buttons/merchants/btn_merchant_selenic_selected.png",
}

# ── Decor icons (garden decorations)
const DECOR_ICONS: Dictionary = {
	"decor_gnome":      "res://assets/textures/decor_gnome.png",
	"decor_flamingo":   "res://assets/textures/decor_flamingo.png",
	"decor_birdbath":   "res://assets/textures/decor_birdbath.png",
	"decor_lantern":    "res://assets/textures/decor_lantern.png",
	"decor_pot":        "res://assets/textures/decor_pot.png",
	"decor_bench":      "res://assets/textures/decor_bench.png",
	# missing assets removed to avoid load errors
	#"decor_fence":      "res://assets/textures/decor_fence.png",
	#"decor_windchimes": "res://assets/textures/decor_windchimes.png",
}

# ── Merged lookup ─────────────────────────────────────────────────
var _all: Dictionary = {}
var _cache: Dictionary = {}  # key → Texture2D (loaded on demand)

func _ready() -> void:
	_all.merge(TAB_ICONS)
	_all.merge(UI_ICONS)
	_all.merge(UI_BUTTONS)
	_all.merge(MERCHANT_BUTTONS)
	_all.merge(INGREDIENT_ICONS)
	_all.merge(RECIPE_ICONS)
	_all.merge(GALLERY_ITEMS)
	_all.merge(EQUIPMENT_ICONS)
	_all.merge(MINIGAME_ASSETS)
	_all.merge(DECOR_ICONS)

func _load_texture_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	# First try regular resource loading (uses Godot import pipeline).
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	# Fallback: decode source image file directly to avoid import metadata issues.
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.new()
		if img.load(abs_path) == OK:
			return ImageTexture.create_from_image(img)
	return null

## Returns the placeholder Texture2D for key, or null if not found.
## Loads lazily and caches — safe to call every frame from a renderer.
func texture_for(key: String) -> Texture2D:
	if _cache.has(key): return _cache[key]
	var path: String = _all.get(key, "")
	if path.is_empty():
		_cache[key] = null
		return null
	var tex := _load_texture_path(path)
	_cache[key] = tex
	return tex

## Returns the path string for key, or "" if not found.
## Useful for pre-checking before calling load() elsewhere.
func path_for(key: String) -> String:
	return _all.get(key, "")

## True if a real placeholder PNG exists for this key.
func has_art(key: String) -> bool:
	var path: String = _all.get(key, "")
	if path.is_empty():
		return false
	if ResourceLoader.exists(path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))

# ──────────────────────────────────────────────────────────────────
# Category-specific convenience methods
# ──────────────────────────────────────────────────────────────────

## Get texture for an ingredient by ID. Returns null if not found.
func texture_for_ingredient(ingredient_id: String) -> Texture2D:
	var path: String = INGREDIENT_ICONS.get(ingredient_id, "")
	return _load_texture_path(path)

## Get path for an ingredient by ID. Returns "" if not found.
func path_for_ingredient(ingredient_id: String) -> String:
	return INGREDIENT_ICONS.get(ingredient_id, "")

## Get texture for a recipe/sweet by ID. Returns null if not found.
func texture_for_recipe(recipe_id: String) -> Texture2D:
	var path: String = RECIPE_ICONS.get(recipe_id, "")
	return _load_texture_path(path)

## Get path for a recipe by ID. Returns "" if not found.
func path_for_recipe(recipe_id: String) -> String:
	return RECIPE_ICONS.get(recipe_id, "")

## Get texture for a gallery item by ID. Returns null if not found.
func texture_for_gallery(gallery_id: String) -> Texture2D:
	var path: String = GALLERY_ITEMS.get(gallery_id, "")
	return _load_texture_path(path)

## Get path for a gallery item by ID. Returns "" if not found.
func path_for_gallery(gallery_id: String) -> String:
	return GALLERY_ITEMS.get(gallery_id, "")

## Get texture for equipment by ID. Returns null if not found.
func texture_for_equipment(equipment_id: String) -> Texture2D:
	var path: String = EQUIPMENT_ICONS.get(equipment_id, "")
	return _load_texture_path(path)

## Get path for equipment by ID. Returns "" if not found.
func path_for_equipment(equipment_id: String) -> String:
	return EQUIPMENT_ICONS.get(equipment_id, "")

## Get texture for minigame asset by ID. Returns null if not found.
func texture_for_minigame(asset_id: String) -> Texture2D:
	var path: String = MINIGAME_ASSETS.get(asset_id, "")
	return _load_texture_path(path)

## Get path for minigame asset by ID. Returns "" if not found.
func path_for_minigame(asset_id: String) -> String:
	return MINIGAME_ASSETS.get(asset_id, "")

## Check if a specific category has art for the given ID.
## category can be: "ingredient", "recipe", "gallery", "equipment", "minigame", "ui", "tab", "decor"
func has_art_in_category(category: String, asset_id: String) -> bool:
	var dict := _get_category_dict(category)
	if dict.is_empty(): return false
	var path: String = dict.get(asset_id, "")
	if path.is_empty():
		return false
	if ResourceLoader.exists(path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))

## Get texture from any category. Pass category name (ingredient, recipe, etc.)
func texture_for_category(category: String, asset_id: String) -> Texture2D:
	var dict := _get_category_dict(category)
	if dict.is_empty(): return null
	var path: String = dict.get(asset_id, "")
	return _load_texture_path(path)

## Get path from any category.
func path_for_category(category: String, asset_id: String) -> String:
	var dict := _get_category_dict(category)
	if dict.is_empty(): return ""
	return dict.get(asset_id, "")

## Helper to fetch the appropriate dictionary by category name.
func _get_category_dict(category: String) -> Dictionary:
	match category.to_lower():
		"decor":
			return DECOR_ICONS
		"ingredient": return INGREDIENT_ICONS
		"recipe": return RECIPE_ICONS
		"gallery": return GALLERY_ITEMS
		"equipment": return EQUIPMENT_ICONS
		"minigame": return MINIGAME_ASSETS
		"ui": return UI_ICONS
		"tab": return TAB_ICONS
		_: return {}
