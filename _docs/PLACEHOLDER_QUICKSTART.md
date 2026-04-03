# Placeholder Asset Generation — Quick Start

Three ways to generate all 49 placeholder PNG wireframes.

---

## 🚀 Fastest: Editor Console (30 seconds)

1. Open Godot Debug Console (bottom of editor, or **View → Output**)
2. Copy-paste test code below:

```gdscript
var all_assets = {
	"ingredient_star_milk": "ingredient", "ingredient_void_cocoa": "ingredient", 
	"ingredient_lunar_sugar": "ingredient", "ingredient_moonbloom_honey": "ingredient",
	"ingredient_rare_moon_drop": "ingredient", "ingredient_obsidian_dust": "ingredient",
	"ingredient_moonpearls_flake": "ingredient",
	"recipe_comet_truffle": "recipe", "recipe_eclipse_bonbon": "recipe",
	"recipe_jackpot_caramel": "recipe", "recipe_moonrise_fudge": "recipe",
	"recipe_void_praline": "recipe", "recipe_moonpearls_bark": "recipe",
	"recipe_silver_fern_cream": "recipe", "recipe_lucky_crunch": "recipe",
	"recipe_focus_bonbon": "recipe",
	"gallery_item_01": "gallery", "gallery_item_02": "gallery", "gallery_item_03": "gallery",
	"equipment_relic_luck": "equipment", "equipment_relic_multiplier": "equipment",
	"equipment_relic_garden": "equipment", "equipment_enhancement_speed": "equipment",
	"equipment_enhancement_focus": "equipment",
	"minigame_crafting_bg": "minigame", "minigame_crafting_pot": "minigame",
	"minigame_crafting_stir": "minigame", "minigame_countdown_dial": "minigame",
	"tab_table": "tab", "tab_garden": "tab", "tab_confect": "tab", "tab_cave": "tab",
	"tab_calendar": "tab", "tab_shop": "tab", "tab_gallery": "tab", "tab_contracts": "tab", "tab_settings": "tab",
	"icon_moondrop": "icon", "icon_moonpearls": "icon", "icon_moon_full": "icon",
	"icon_moon_new": "icon", "icon_curio": "icon", "icon_die_d6": "icon",
	"icon_die_d8": "icon", "icon_die_d20": "icon", "icon_water": "icon",
	"icon_food": "icon", "icon_seed": "icon", "icon_coin": "icon",
}
var size := Vector2i(128, 128)
var colors = {"ingredient": Color(0.2, 0.8, 0.3), "recipe": Color(0.8, 0.4, 0.1), "gallery": Color(0.6, 0.2, 0.8), "equipment": Color(0.9, 0.8, 0.1), "minigame": Color(0.1, 0.6, 0.9), "tab": Color(0.5, 0.5, 0.5), "icon": Color(0.5, 0.5, 0.5)}
for filename in all_assets.keys():
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	var color = colors.get(all_assets[filename], Color.GRAY)
	image.fill(Color(0.15, 0.15, 0.15))
	for x in range(size.x):
		for y in range(3):
			image.set_pixel(x, y, color)
			image.set_pixel(x, size.y - 1 - y, color)
	for y in range(size.y):
		for x in range(3):
			image.set_pixel(x, y, color)
			image.set_pixel(size.x - 1 - x, y, color)
	var accent = color.darkened(0.3)
	for x in range(6, size.x - 6):
		image.set_pixel(x, 6, accent)
		image.set_pixel(x, size.y - 7, accent)
	for y in range(6, size.y - 6):
		image.set_pixel(6, y, accent)
		image.set_pixel(size.x - 7, y, accent)
	image.save_png("res://assets/textures/" + filename + ".png")
print("✅ Generated %d placeholders in res://assets/textures/" % all_assets.size())
```

3. Press **Enter** → Done! ✅

**Result:** All 49 PNG files created in `res://assets/textures/`

---

## 🤖 Automatic: Add Autoload (1 minute setup, auto-generates on startup)

1. Go to **Project → Project Settings → Autoload** tab
2. Select `autoloads/PlaceholderGeneratorAutoload.gd`
3. Enter node name: `PlaceholderGen`
4. Click **Add**
5. Run the game in debug mode → Placeholders auto-generate on first run

The autoload will:
- ✅ Auto-generate in **debug builds** only
- ✅ Skip if placeholders already exist
- ✅ Do nothing in **release builds**

---

## 📝 Manual: Run Script File

If you prefer a dedicated script:

1. Create a new Node in any scene
2. Attach `scripts/PlaceholderGenerator_EditorScript.gd` as a script
3. The script runs and generates all placeholders automatically

---

## ✨ What You Get

Each placeholder PNG:
- **128×128 pixels** — Standard size
- **Color-coded border** — By category (green=ingredient, orange=recipe, etc.)
- **Simple wireframe design** — Professional placeholder styling
- **Ready to replace** — When real art arrives, just swap the file

### Files Generated (49 total)

| Category | Count | Color |
|----------|-------|-------|
| Ingredients | 7 | 🟢 Green |
| Recipes | 9 | 🟠 Orange |
| Gallery Items | 3 | 🟣 Purple |
| Equipment | 5 | 🟡 Gold |
| Minigames | 4 | 🔵 Blue |
| Navigation Tabs | 9 | ⚪ Gray |
| UI Icons | 12 | ⚪ Gray |

---

## 🎯 Next: Integration

Once generated, update your Tab scripts to use the new assets:

```gdscript
# In InventoryTab, ConfectioneryTab, etc.

var texture = ArtReg.texture_for_ingredient("star_milk")
if texture:
    texture_rect.texture = texture
else:
    # Fallback to emoji if PNG missing
    label.text = ingredient_data["emoji"]
```

See [`_docs/PLACEHOLDER_ART_GUIDE.md`](PLACEHOLDER_ART_GUIDE.md) for full integration examples.

---

## 🔗 File Locations

- **Generated PNGs:** `res://assets/textures/`
- **Autoload script:** `autoloads/PlaceholderGeneratorAutoload.gd`
- **Registry:** `autoloads/PlaceholderArtRegistry.gd`
- **Documentation:** `_docs/PLACEHOLDER_ART_GUIDE.md`

---

## ❓ Troubleshooting

**Q: Placeholders not generating?**
- Check that `res://assets/textures/` directory exists
- In debug mode, look at output console for errors
- Try the Editor Console method (fastest)

**Q: Want to regenerate?**
- Delete the `res://assets/textures/` folder
- Run any generation method again

**Q: Customizing placeholder colors?**
- Edit the `colors` dictionary in the generation script
- Rerun the generator

---

**Ready to go!** Pick your preferred generation method above and follow the steps. ✨
