# Implementation Plan

## [Overview]

Consolidate 300+ hardcoded UI color values into GameData theme constants, create a centralized ThemeHelper autoload providing factory methods for styled panels/popups/cards/buttons, migrate all popup/overlay patterns to PopupPanel, and unify button styling across the Moonseed project to ensure consistent theme adherence.

The Moonseed project has accumulated significant UI technical debt: hardcoded Color() hex values scattered across 30+ scripts, duplicated color constants in multiple files (e.g., SATCHEL_BUTTON_* in both satchel_tab.gd and GalleryTab.gd), inconsistent popup patterns (some use PopupPanel, some CanvasLayer, some code-generated overlays), mixed button styling approaches (TextureButton vs StyleBoxFlat vs ButtonFeedback), and many font sizes using raw integers instead of GameData.scaled_font_size(). This cleanup creates a single source of truth for all theme colors, a reusable component library for common UI patterns, and standardized popup/button behavior — making future UI work faster and more consistent.

## [Types]

New theme color constants and UI component helper types to be added to GameData.gd and a new ThemeHelper.gd autoload.

### GameData.gd — New Theme Constants

Add the following semantic color groups to GameData.gd, using values from the existing Moonseed theme (_docs/Moonseed_theme) and BUTTON_STYLE_GUIDE.md:

```gdscript
# ── Panel / Surface Colors ────────────────────────────────────────
const PANEL_BG := Color("#0d0520")           # Deep void — default panel background
const PANEL_BG_ALT := Color("#060220")       # Darker variant — left panel, headers
const PANEL_BORDER := Color("#290E7A")       # Outer rim — default panel border
const PANEL_BORDER_ACCENT := Color("#099EA9") # Teal — header/nav accent borders
const PANEL_SHADOW := Color(0.0, 0.0, 0.0, 0.14)

# ── Card Colors ───────────────────────────────────────────────────
const CARD_BG_DEFAULT := Color("#1a0b3a")    # Default card surface
const CARD_BORDER_DEFAULT := Color("#290E7A") # Default card border
const CARD_HL_ACTIVE := Color("#A1EBAC")     # Active card highlight (mint)
const CARD_BG_DONE := Color("#0d1a0d")       # Completed/owned card tint

# ── Text Colors ───────────────────────────────────────────────────
const TEXT_PRIMARY := Color("#eaf7ff")       # Primary text — light blue-white
const TEXT_SECONDARY := Color("#a1ebac")     # Secondary text — mint green
const TEXT_MUTED := Color("#6644aa")         # Muted/inactive text
const TEXT_GOLD := Color("#ffd66b")          # Gold accent text
const TEXT_DANGER := Color("#E31AE0")        # Danger/pink text

# ── Separator / Divider ──────────────────────────────────────────
const SEPARATOR_COLOR := Color("#3a3a5a")    # Default separator line

# ── Button Text Colors (Satchel/Leather theme) ──────────────────
const SATCHEL_BTN_TEXT := Color("#f7e7c8")
const SATCHEL_BTN_BG := Color("#b07848")
const SATCHEL_BTN_HOVER := Color("#c98c58")
const SATCHEL_BTN_PRESSED := Color("#8c5e36")
const SATCHEL_BTN_BORDER := Color("#4a2c10")

# ── Calendar Heat-Map Colors ─────────────────────────────────────
const CAL_CELL_VOID := Color("#080318")
const CAL_CELL_ZERO := Color("#100830")
const CAL_CELL_DIM := Color("#1C0A55")
const CAL_CELL_MID := Color("#321096")
const CAL_CELL_BRIGHT := Color("#7B1FCC")
const CAL_BORDER_IDLE := Color("#3A1880")
const CAL_BORDER_TODAY := Color("#FFD700")
const CAL_BORDER_VIEW := Color("#5BA8FF")

# ── Dice Table Colors ─────────────────────────────────────────────
const DICE_TABLE_FELT := Color("#0d1a2e")
const DICE_TABLE_EDGE := Color("#290E7A")
const DICE_TABLE_INNER := Color("#12053a")
const DICE_TABLE_LABEL := Color("#3a2a5a")

# ── Shop / Commerce Colors ────────────────────────────────────────
const SHOP_OWNED_BG := Color("#0d1a0d")
const SHOP_OWNED_BORDER := Color("#44cc44")

# ── Rarity Text Colors (canonical, replaces SeedCaseScript duplicates) ─
const RARITY_TEXT_COLS := {
    "common":    Color("#aaaaaa"),
    "uncommon":  Color("#44aaff"),
    "rare":      Color("#cc44ff"),
    "epic":      Color("#ff8800"),
    "legendary": Color("#ffdd00"),
}
```

### ThemeHelper.gd — Factory Method Signatures

```gdscript
# Panel styling
static func style_panel(panel: PanelContainer, bg: Color, border: Color, border_width: int = 1, corner_radius: int = 4) -> void
static func style_card(card: Panel, bg: Color, border: Color, border_width: int = 1, corner_radius: int = 8) -> void

# Popup creation (standardized PopupPanel pattern)
static func create_popup(title: String, size: Vector2, content: Control) -> PopupPanel
static func show_popup(popup: PopupPanel) -> void
static func hide_popup(popup: PopupPanel) -> void

# Button factory
static func create_button(text: String, type: String, size: Vector2) -> Button
static func style_button(btn: Button, bg: Color, border: Color, text_col: Color, corner_radius: int = 8) -> void

# Label helpers
static func create_label(text: String, font_size: int, color: Color) -> Label

# Separator
static func create_separator(color: Color) -> HSeparator
```

## [Files]

### New Files to Create

| File | Purpose |
|------|---------|
| `autoloads/ThemeHelper.gd` | Centralized UI factory: style_panel, style_card, create_popup, create_button, style_button, create_label, create_separator |

### Existing Files to Modify — Color Consolidation (Phase 1)

| File | Changes |
|------|---------|
| `autoloads/GameData.gd` | Add ~40 new theme constants (PANEL_BG, PANEL_BORDER, TEXT_PRIMARY, SATCHEL_BTN_*, CAL_CELL_*, DICE_TABLE_*, SHOP_*, RARITY_TEXT_COLS, SEPARATOR_COLOR) |
| `scripts/PlayTab.gd` | Keep READABLE_* constants (accessibility). Replace all inline Color("#...") calls with GameData constants for theme colors |
| `scripts/Main.gd` | Replace Color("#290E7A"), Color("#07030e"), Color("#0d0520"), Color("#099EA9"), Color("#6F1CB2") with GameData constants |
| `scripts/ShopTab.gd` | Replace Color("#FFD700"), Color("#0d1a0d"), Color("#44cc44") with GameData constants |
| `scripts/ContractsTab.gd` | Replace Color("060220"), Color("290E7A") with GameData constants |
| `scripts/CalendarTab.gd` | Replace COL_CELL_* and COL_BORDER_* constants with GameData references |
| `scripts/GalleryTab.gd` | Remove duplicated SATCHEL_BUTTON_* constants; use GameData.SATCHEL_BTN_* |
| `scripts/satchel/satchel_tab.gd` | Remove duplicated SATCHEL_BUTTON_* constants; use GameData.SATCHEL_BTN_* |
| `scripts/satchel/curio_management_screen.gd` | Remove duplicated SATCHEL_BUTTON_* constants; use GameData.SATCHEL_BTN_* |
| `scripts/RolodexNav.gd` | Replace COL_CARD_BG_ACTIVE, COL_BORDER_ACTIVE, etc. with GameData constants |
| `scripts/InventoryTab.gd` | Replace Color("#290E7A") with GameData.PANEL_BORDER |
| `scripts/DiceTableArea.gd` | Replace FELT_COLOR, FELT_EDGE, FELT_INNER, LABEL_IDLE with GameData constants |
| `scripts/SeedCaseScript.gd` | Replace RARITY_COLS with GameData.RARITY_TEXT_COLS; replace Color("#88ccff"), Color("#ffdd44"), Color("#060610"), Color("#44ccff") with GameData constants |
| `scripts/CraftingTab.gd` | Replace Color("#0d0520"), Color("#0d0a22") with GameData constants |
| `scripts/CraftingMinigame.gd` | Replace Color("#1a0a35") references with GameData constants |
| `scripts/DiceFaceDevUI.gd` | Replace BG_COL, PANEL_COL, BORDER_COL, HOVER_COL, SEL_COL with GameData constants |
| `scripts/ui/AchievementPopup.gd` | Replace Color("#1a1a2e"), Color("#ffd700"), Color("#ffffff") with GameData constants |
| `scripts/ui/StandardizedShopLayout.gd` | Replace Color("#ffffff"), Color("#cccccc") with GameData constants |

### Existing Files to Modify — Popup Migration (Phase 2)

| File | Changes |
|------|---------|
| `autoloads/ContractRewardOverlay.gd` | Convert from CanvasLayer (layer 140) to PopupPanel pattern using ThemeHelper.create_popup |
| `scripts/RecipeDiscoveryOverlay.gd` | Convert from CanvasLayer (layer 150) to PopupPanel pattern |
| `scripts/MoonPhaseOverlay.gd` | Convert from CanvasLayer to PopupPanel pattern |
| `scripts/ui/EscapeMenu.tscn` | Already PopupPanel — ensure it uses theme constants |
| `scenes/ui/StandardizedShopLayout.tscn` | Already PopupPanel — ensure it uses theme constants |
| `scenes/ui/ModernShopLayout.tscn` | Already PopupPanel — ensure it uses theme constants |

### Existing Files to Modify — Button Unification (Phase 3)

| File | Changes |
|------|---------|
| `autoloads/ThemeHelper.gd` | Implement create_button() and style_button() factory methods |
| `scripts/GalleryTab.gd` | Use ThemeHelper.style_button() for SATCHEL_BUTTON_* styled buttons |
| `scripts/satchel/satchel_tab.gd` | Use ThemeHelper.style_button() for SATCHEL_BUTTON_* styled buttons |
| `scripts/satchel/curio_management_screen.gd` | Use ThemeHelper.style_button() for SATCHEL_BUTTON_* styled buttons |
| `scripts/bazaar/BazaarTab.gd` | Use ThemeHelper.style_panel() for vendor cards |
| `scripts/bazaar/shops/sweetmaker_screen.gd` | Replace inline Color("#8B4513"), Color("#A0522D"), Color("#FFD700") with GameData constants |
| `scripts/bazaar/shops/curio_dealer_screen.gd` | Replace Color("#1a0b3a") with GameData.CARD_BG_DEFAULT |
| `scripts/bazaar/shops/request_nook_screen.gd` | Replace inline colors with GameData constants |
| `scripts/confectionery/ConfectioneryTab.gd` | Replace inline colors with GameData constants |
| `scripts/confectionery/confectionery_plinko_board.gd` | Replace BOARD_BG_COLOR, BOARD_BORDER_COLOR with GameData constants |
| `scripts/plinko/plinko_zone.gd` | Replace ZONE_COLORS with references to ChocolateData or GameData |

### Files NOT Modified (Intentionally Preserved)

| File | Reason |
|------|--------|
| `scripts/PlayTab.gd` READABLE_* constants | Accessibility system — intentionally different visual language for readability. Keep as-is. |
| `autoloads/ContractRewardOverlay.gd` shader colors | Shader-specific colors (starfall profiles, rarity aura shaders) are visual FX, not UI theme. Keep as-is. |
| `scripts/data/ChocolateData.gd` zone colors | Game-specific data colors for chocolate types. Keep as-is. |
| `scripts/plinko/plinko_coin.gd` coin colors | Game-specific data colors for coin types. Keep as-is. |
| `scripts/data/StudioRoomCompositor.gd` room colors | Game-specific ambient colors. Keep as-is. |
| `scripts/ui/task_dice_box.gd` / `task_dice_box_view.gd` wood colors | 3D material colors for dice box model. Keep as-is. |
| `scripts/garden/GardenTab.gd` 3D environment colors | 3D scene lighting/materials. Keep as-is. |
| `scripts/garden/GardenSkyView.gd` sky colors | Sky gradient shader colors. Keep as-is. |
| `autoloads/FXBus.gd` sparkle/particle colors | Visual FX colors, not UI theme. Keep as-is. |

## [Functions]

### New Functions — ThemeHelper.gd

```gdscript
# File: autoloads/ThemeHelper.gd

# Styles a PanelContainer with background color, border, and corner radius.
# Creates a StyleBoxFlat and applies it as "panel" theme override.
# Caches the StyleBoxFlat in the panel's metadata for later mutation.
static func style_panel(panel: PanelContainer, bg: Color, border: Color, border_width: int = 1, corner_radius: int = 4) -> void

# Styles a Panel (non-container) node similarly to style_panel.
static func style_card(card: Panel, bg: Color, border: Color, border_width: int = 1, corner_radius: int = 8) -> void

# Creates a standardized PopupPanel with title label, close button, and content area.
# Returns the popup (not yet shown). Call show_popup() to display.
static func create_popup(title: String, size: Vector2, content: Control) -> PopupPanel

# Centers and shows a PopupPanel with fade-in animation.
static func show_popup(popup: PopupPanel) -> void

# Hides a PopupPanel with fade-out animation, then queue_free.
static func hide_popup(popup: PopupPanel) -> void

# Creates a themed Button with the specified type ("primary", "secondary", "confirm", "cancel", "shop", "satchel").
# Applies appropriate colors from GameData constants.
static func create_button(text: String, type: String = "primary", min_size: Vector2 = Vector2(120, 36)) -> Button

# Applies inline StyleBoxFlat overrides to a Button for normal/hover/pressed states.
static func style_button(btn: Button, bg: Color, border: Color, text_col: Color, corner_radius: int = 8) -> void

# Creates a Label with scaled font size and color from GameData.
static func create_label(text: String, font_size: int, color: Color) -> Label

# Creates an HSeparator with the standard theme color.
static func create_separator(color: Color = GameData.SEPARATOR_COLOR) -> HSeparator

# Returns a StyleBoxFlat with the given properties (shared helper).
static func make_stylebox(bg: Color, border: Color, border_width: int = 1, corner_radius: int = 4) -> StyleBoxFlat
```

### Modified Functions — Color Replacement Pattern

For each file listed in Phase 1, the pattern is:
1. Remove local color constants that duplicate GameData
2. Replace inline `Color("#...")` calls with `GameData.CONSTANT_NAME`
3. Keep only truly unique/local colors that don't belong in the global theme

Specific examples:

**scripts/Main.gd** — `_build_ui()` and `_apply_styles()`:
- `Color("#290E7A")` → `GameData.PANEL_BORDER`
- `Color("#07030e")` → `GameData.PANEL_BG_ALT`
- `Color("#0d0520")` → `GameData.PANEL_BG`
- `Color("#099EA9")` → `GameData.PANEL_BORDER_ACCENT`
- `Color("#6F1CB2")` → `GameData.ACCENT_CURIO_CANISTER`

**scripts/CalendarTab.gd** — Remove local COL_CELL_* constants, replace with `GameData.CAL_CELL_*`

**scripts/GalleryTab.gd** — Remove SATCHEL_BUTTON_* constants, replace with `GameData.SATCHEL_BTN_*`

**scripts/satchel/satchel_tab.gd** — Remove SATCHEL_BUTTON_* constants, replace with `GameData.SATCHEL_BTN_*`

**scripts/SeedCaseScript.gd** — Remove RARITY_COLS, use `GameData.RARITY_TEXT_COLS`

## [Classes]

### New Classes — ThemeHelper.gd

```
Class: ThemeHelper (extends RefCounted)
  Purpose: Static utility class providing factory methods for Moonseed UI components.
  Methods: style_panel, style_card, create_popup, show_popup, hide_popup,
           create_button, style_button, create_label, create_separator, make_stylebox
  No instance state — all methods are static.
  Registered as autoload "ThemeHelper" in project.godot.
```

### Modified Classes

No class inheritance changes. All modifications are to existing GDScript files replacing hardcoded values with GameData/ThemeHelper calls. The existing class structure (autoloads, tab scripts, overlay scripts) remains unchanged.

## [Dependencies]

No new external dependencies. All changes use existing Godot 4.6 APIs:
- `StyleBoxFlat` — already used throughout
- `PopupPanel` — already used by EscapeMenu, StandardizedShopLayout
- `CanvasLayer` — currently used by some overlays, being replaced by PopupPanel
- `GameData` constants — existing pattern, expanding the set

The only "new" file is `autoloads/ThemeHelper.gd`, which must be registered in `project.godot` under the `[autoload]` section.

## [Testing]

### Validation Strategy

1. **Visual regression**: After each phase, open every tab (Play, Garden, Confectionery, Bazaar, Calendar, Satchel, Settings, Gallery, Contracts, Shop, Inventory) and verify colors match the Moonseed theme spec
2. **Popup behavior**: Open each popup (Escape Menu, Shop, Contract Reward, Recipe Discovery, Moon Phase) and verify:
   - It opens as a PopupPanel (not a CanvasLayer)
   - It has consistent styling (border, background, corner radius)
   - It closes correctly (X button, click-outside, or auto-dismiss)
3. **Button states**: Click every button type (primary, secondary, confirm, cancel, shop, satchel) and verify hover/pressed states work
4. **Font scaling**: Change text_size_delta in Settings and verify all text resizes correctly (no hardcoded font sizes remaining)
5. **READABLE mode**: Verify PlayTab's READABLE_* colors are unaffected (accessibility preserved)

### Test Checklist

- [ ] All tabs render with correct theme colors
- [ ] No visual artifacts or missing borders after migration
- [ ] All popups open/close correctly as PopupPanel
- [ ] Button hover/pressed states work on all button types
- [ ] Font scaling works globally (no hardcoded font_size overrides remaining)
- [ ] PlayTab READABLE_* accessibility colors unchanged
- [ ] ContractRewardOverlay wish sequence plays correctly
- [ ] RecipeDiscoveryOverlay auto-dismisses correctly
- [ ] MoonPhaseOverlay click-to-dismiss works
- [ ] Satchel button styling consistent across GalleryTab and satchel_tab

## [Implementation Order]

### Phase 1: Foundation — GameData Constants + ThemeHelper (do first)

1. Add all new theme constants to `autoloads/GameData.gd`
2. Create `autoloads/ThemeHelper.gd` with factory methods
3. Register ThemeHelper in `project.godot` autoloads
4. Test: verify no compilation errors, ThemeHelper is accessible

### Phase 2: Color Consolidation (do second, file by file)

5. Replace hardcoded colors in `scripts/Main.gd`
6. Replace hardcoded colors in `scripts/CalendarTab.gd`
7. Replace hardcoded colors in `scripts/GalleryTab.gd` (remove SATCHEL_BUTTON_* duplication)
8. Replace hardcoded colors in `scripts/satchel/satchel_tab.gd` (remove SATCHEL_BUTTON_* duplication)
9. Replace hardcoded colors in `scripts/satchel/curio_management_screen.gd`
10. Replace hardcoded colors in `scripts/RolodexNav.gd`
11. Replace hardcoded colors in `scripts/InventoryTab.gd`
12. Replace hardcoded colors in `scripts/DiceTableArea.gd`
13. Replace hardcoded colors in `scripts/SeedCaseScript.gd` (remove RARITY_COLS duplication)
14. Replace hardcoded colors in `scripts/CraftingTab.gd`
15. Replace hardcoded colors in `scripts/CraftingMinigame.gd`
16. Replace hardcoded colors in `scripts/DiceFaceDevUI.gd`
17. Replace hardcoded colors in `scripts/ShopTab.gd`
18. Replace hardcoded colors in `scripts/ContractsTab.gd`
19. Replace hardcoded colors in `scripts/ui/AchievementPopup.gd`
20. Replace hardcoded colors in `scripts/ui/StandardizedShopLayout.gd`
21. Replace hardcoded colors in bazaar shop screens (`sweetmaker_screen.gd`, `curio_dealer_screen.gd`, `request_nook_screen.gd`)
22. Replace hardcoded colors in `scripts/bazaar/BazaarTab.gd`
23. Replace hardcoded colors in `scripts/confectionery/ConfectioneryTab.gd` and `confectionery_plinko_board.gd`
24. Test: open all tabs, verify visual consistency

### Phase 3: Popup Migration (do third)

25. Convert `ContractRewardOverlay.gd` from CanvasLayer to PopupPanel
26. Convert `RecipeDiscoveryOverlay.gd` from CanvasLayer to PopupPanel
27. Convert `MoonPhaseOverlay.gd` from CanvasLayer to PopupPanel
28. Verify existing PopupPanel popups (EscapeMenu, Shop) use theme constants
29. Test: open all popups, verify open/close behavior, verify wish sequence still plays

### Phase 4: Button Unification (do fourth)

30. Use ThemeHelper.style_button() in `scripts/GalleryTab.gd`
31. Use ThemeHelper.style_button() in `scripts/satchel/satchel_tab.gd`
32. Use ThemeHelper.style_button() in `scripts/satchel/curio_management_screen.gd`
33. Use ThemeHelper.style_panel() in bazaar vendor cards
34. Test: click all buttons, verify hover/pressed states

### Phase 5: Font Size Audit (do last)

35. Search for remaining `add_theme_font_size_override("font_size",` calls with raw integers
36. Replace raw integers with `GameData.scaled_font_size()` where appropriate
37. Keep raw integers only for intentionally fixed-size elements (sparkle FX, debug labels)
38. Test: change text_size_delta, verify global scaling