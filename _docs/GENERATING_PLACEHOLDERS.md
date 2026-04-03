# Generating Placeholder Wireframes

Three methods to generate all placeholder PNG assets for the PlaceholderArtRegistry.

---

## Method 1: Editor Console (Fastest) ⚡

**Best for quick generation without leaving the editor.**

1. Open Godot's **Debug Console** (bottom panel, or View → Output)
2. Paste the entire contents of [`_docs/GENERATE_PLACEHOLDERS.gd`](GENERATE_PLACEHOLDERS.gd)
3. Press Enter

All 54 placeholder PNGs will generate instantly in `res://assets/textures/`

---

## Method 2: Editor Script

**Use if you want to integrate generation into a scene or automate during project load.**

1. Create a new Node in your scene (any node type works)
2. Attach `scripts/PlaceholderGenerator_EditorScript.gd` as an EditorScript
3. The script will run automatically and generate all placeholders

---

## Method 3: Runtime GDScript Utility

**Use if you want a reusable component in your game logic.**

1. Instantiate `scripts/GeneratePlaceholderAssets.gd` in your scene
```gdscript
var generator = GeneratePlaceholderAssets.new()
add_child(generator)
generator.generate_all()
```

Or from any script:
```gdscript
if DebugManager.has_art_generation_enabled():
    var gen = preload("res://scripts/GeneratePlaceholderAssets.gd").new()
    add_child(gen)
    gen.generate_all()
```

---

## Output Structure

Generated files will be created in: `res://assets/textures/`

**Color coding by category:**
- **Ingredients** (🟢 Green) — 7 files
- **Recipes** (🟠 Orange) — 9 files  
- **Gallery** (🟣 Purple) — 3 files
- **Equipment** (🟡 Gold/Yellow) — 5 files
- **Minigames** (🔵 Blue) — 4 files
- **Tabs** (⚪ Gray) — 9 files
- **UI Icons** (⚪ Gray) — 12 files

**Total: 49 placeholder PNGs**

---

## Generated Files

### Ingredients (7)
- `ingredient_star_milk.png`
- `ingredient_void_cocoa.png`
- `ingredient_lunar_sugar.png`
- `ingredient_moonbloom_honey.png`
- `ingredient_rare_moon_drop.png`
- `ingredient_obsidian_dust.png`
- `ingredient_moonpearls_flake.png`

### Recipes (9)
- `recipe_comet_truffle.png`
- `recipe_eclipse_bonbon.png`
- `recipe_jackpot_caramel.png`
- `recipe_moonrise_fudge.png`
- `recipe_void_praline.png`
- `recipe_moonpearls_bark.png`
- `recipe_silver_fern_cream.png`
- `recipe_lucky_crunch.png`
- `recipe_focus_bonbon.png`

### Gallery (3)
- `gallery_item_01.png`
- `gallery_item_02.png`
- `gallery_item_03.png`

### Equipment (5)
- `equipment_relic_luck.png`
- `equipment_relic_multiplier.png`
- `equipment_relic_garden.png`
- `equipment_enhancement_speed.png`
- `equipment_enhancement_focus.png`

### Minigames (4)
- `minigame_crafting_bg.png`
- `minigame_crafting_pot.png`
- `minigame_crafting_stir.png`
- `minigame_countdown_dial.png`

### Tabs (9)
- `tab_table.png`
- `tab_garden.png`
- `tab_confect.png`
- `tab_cave.png`
- `tab_calendar.png`
- `tab_shop.png`
- `tab_gallery.png`
- `tab_contracts.png`
- `tab_settings.png`

### UI Icons (12)
- `icon_moondrop.png`
- `icon_moonpearls.png`
- `icon_moon_full.png`
- `icon_moon_new.png`
- `icon_curio.png`
- `icon_die_d6.png`
- `icon_die_d8.png`
- `icon_die_d20.png`
- `icon_water.png`
- `icon_food.png`
- `icon_seed.png`
- `icon_coin.png`

---

## What You Get

Each placeholder PNG:
- **128×128 pixels** — Standard UI asset size
- **Color-coded border** — By category (ingredient=green, recipe=orange, etc.)
- **Simple wireframe design** — Clear placeholder styling
- **Ready to replace** — Just swap the PNG when real art arrives

---

## Next Steps

1. **Generate the placeholders** using any of the three methods above
2. **Update PlaceholderArtRegistry** — Already done! ✅
3. **Integrate into Tab scripts** — Use methods like:
   ```gdscript
   var texture = ArtReg.texture_for_ingredient("star_milk")
   if texture:
       icon.texture = texture
   else:
       label.text = ingredient["emoji"]  # Fallback
   ```
4. **Artist handoff** — When real art arrives, just replace PNGs in `assets/textures/`

See [`PLACEHOLDER_ART_GUIDE.md`](PLACEHOLDER_ART_GUIDE.md) for full integration documentation.
