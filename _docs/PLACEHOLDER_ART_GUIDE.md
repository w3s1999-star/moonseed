# Placeholder Art Registry — Usage Guide

The **PlaceholderArtRegistry** (autoload: `ArtReg`) manages all temporary/wireframe assets across Moonseed.
When real art arrives, update this one file and the entire game switches over automatically.

---

## Quick Reference

### UI Icons & Tabs
```gdscript
ArtReg.texture_for("moondrop")     # General UI icon
ArtReg.path_for("table")             # Tab icon path
ArtReg.has_art("coin")               # Check if art exists
```

### Ingredients
```gdscript
ArtReg.texture_for_ingredient("star_milk")
ArtReg.path_for_ingredient("void_cocoa")
ArtReg.has_art_in_category("ingredient", "lunar_sugar")
```

### Recipes/Sweets
```gdscript
ArtReg.texture_for_recipe("comet_truffle")
ArtReg.path_for_recipe("eclipse_bonbon")
ArtReg.texture_for_category("recipe", "jackpot_caramel")
```

### Gallery Items
```gdscript
ArtReg.texture_for_gallery("gallery_placeholder_01")
ArtReg.has_art_in_category("gallery", "gallery_placeholder_02")
```

### Equipment
```gdscript
ArtReg.texture_for_equipment("relic_luck")
ArtReg.path_for_equipment("enhancement_speed")
```

### Minigames
```gdscript
ArtReg.texture_for_minigame("crafting_pot")
ArtReg.path_for_minigame("countdown_dial")
```

---

## Common Patterns

### Pattern 1: TextureRect with Fallback
```gdscript
var texture_rect: TextureRect = TextureRect.new()
var texture := ArtReg.texture_for_ingredient("star_milk")

if texture:
    texture_rect.texture = texture
else:
    # Fallback to emoji or placeholder Label
    var label := Label.new()
    label.text = IngredientData.INGREDIENTS["star_milk"]["emoji"]
```

### Pattern 2: Check Before Loading
```gdscript
if ArtReg.has_art_in_category("recipe", recipe_id):
    var tex = ArtReg.texture_for_recipe(recipe_id)
    display_node.texture = tex
```

### Pattern 3: Category-Generic Handler
```gdscript
func display_item(category: String, item_id: String) -> void:
    if ArtReg.has_art_in_category(category, item_id):
        visual_node.texture = ArtReg.texture_for_category(category, item_id)
    else:
        show_emoji_fallback(item_id)
```

---

## Asset Directory Structure

Placeholders are organized under `res://assets/textures/`:

```
assets/textures/
├── ingredient_*.png       # Ingredient wireframes (7 placeholders)
├── recipe_*.png           # Recipe/sweet wireframes (9 placeholders)
├── gallery_item_*.png     # Gallery items (3 placeholders)
├── equipment_*.png        # Relics/enhancements (5 placeholders)
└── minigame_*.png         # Crafting/gameplay (4 placeholders)
```

---

## Adding New Placeholders

### To Add Ingredients
1. Create PNG at: `res://assets/textures/ingredient_NAME.png`
2. Update `PlaceholderArtRegistry.gd`:
   ```gdscript
   const INGREDIENT_ICONS: Dictionary = {
       # ... existing entries ...
       "new_ingredient_id": "res://assets/textures/ingredient_new_ingredient_id.png",
   }
   ```

### To Add Recipes
1. Create PNG at: `res://assets/textures/recipe_NAME.png`
2. Add to `RECIPE_ICONS` dictionary:
   ```gdscript
   "new_recipe_id": "res://assets/textures/recipe_new_recipe_id.png",
   ```

### To Add Garden Decor

1. Create PNG at: `res://assets/textures/decor_NAME.png`
2. Add entry to `DECOR_ICONS` in `PlaceholderArtRegistry.gd`:
   ```gdscript
   "decor_my_decor": "res://assets/textures/decor_my_decor.png",
   ```

### To Add Gallery Items
1. Create PNG at: `res://assets/textures/gallery_item_NAME.png`
2. Add to `GALLERY_ITEMS` dictionary

### Similar Pattern for Equipment & Minigame Assets

---

## Integration Checklist

- [ ] **InventoryTab** — Use `texture_for_ingredient()` for item display
- [ ] **ConfectioneryTab** — Use `texture_for_recipe()` for recipe cards
- [ ] **GalleryTab** — Use `texture_for_gallery()` for gallery images
- [ ] **ShopTab** — Use `texture_for_equipment()` for relic/enhancement display
- [ ] **CraftingMinigame** — Use `texture_for_minigame()` for UI elements
- [ ] **ContractsTab** — Update with `has_art_in_category()` checks

---

## Best Practices

1. **Always check `has_art()` first** — Gracefully fall back to emoji/text if PNG missing
2. **Use category-specific methods** — More readable than generic `texture_for()`
3. **Keep IDs consistent** — Use snake_case for all placeholder keys
4. **Document fallback behavior** — Every display should have an emoji or text backup
5. **Never hardcode paths** — Always use `ArtReg` methods

---

## Debugging

### Check if art exists:
```gdscript
if ArtReg.has_art_in_category("ingredient", "star_milk"):
    print("Ingredient art found!")
else:
    print("Missing: ", ArtReg.path_for_ingredient("star_milk"))
```

### List all available ingredients:
```gdscript
for key in ArtReg.INGREDIENT_ICONS.keys():
    print(key)
```

### Verify paths are valid:
```gdscript
for id in IngredientData.INGREDIENTS.keys():
    var path = ArtReg.path_for_ingredient(id)
    if not ResourceLoader.exists(path):
        print("Missing art for: ", id)
```

---

## Migration from Emoji-Only

Old way (emoji only):
```gdscript
label.text = ingredient["emoji"]  # Just 🥛
```

New way (art + fallback):
```gdscript
var tex = ArtReg.texture_for_ingredient(ingredient_id)
if tex:
    texture_rect.texture = tex
else:
    label.text = ingredient["emoji"]  # Fallback if no PNG
```
