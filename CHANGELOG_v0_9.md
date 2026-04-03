# MOONSEED v0.9.0 — Sauce & Style Pass

## New Files

### Autoloads
- `autoloads/ButtonFeedback.gd` — **Standalone** button juice (replaces missing addon).
  Scale/spring hover + press + release animations on every Button automatically.
  Call `ButtonFeedback.setup_recursive(node)` in any new scene.

- `autoloads/Juice.gd` — Tween helpers library ("the sauce layer").
  | Helper | What it does |
  |---|---|
  | `punch_scale(node, scale, dur)` | Pop-spring scale |
  | `squash_and_stretch(node, dur)` | Classic game-feel squash |
  | `flash_color(node, col, dur)` | Modulate flash |
  | `wiggle(node, deg, cycles, dur)` | Rotation shake |
  | `screen_shake(layer, str, dur)` | Viewport translate shake |
  | `count_up(label, from, to, dur, fmt)` | Animated number counter |
  | `fade_in / fade_out` | Alpha tween |
  | `bounce_in(node, dur)` | Scale from 0 with spring |
  | `slide_in(node, offset, dur)` | Position slide |
  | `pulse(node, amp, period)` | Looping scale pulse |
  | `glow_flash(panel, col, dur)` | StyleBox border flash |
  | `number_pop(pos, value, col)` | Floating +N label |

### Scenes
- `scenes/CoinCaveTab.tscn` — Proper 2D scene for the Coin Cave.
  Structural nodes: wallet row, press section (ProgressBar + Button), economy stats.
  Script `CoinCaveTab.gd` now has `@onready` wiring to all scene nodes.

- `scenes/ConfectioneryTab.tscn` — Proper 2D scene for the Confectionery/Pomodoro.
  Structural nodes: header with live timer, 3-column layout (Pantry | Boiler | Recipes),
  Sweets Jar at the bottom. Script has full `@onready` wiring.

### Developer Notes (`_docs/` — not loaded at runtime)
- `_docs/ARCHITECTURE_NOTES.gd` — Full system map, data flow, tech debt list.
- `_docs/BACKLOG.gd` — Prioritised backlog (P0/P1/P2/P3) from all review sessions.
- `_docs/STYLE_GUIDE.gd` — Naming conventions, UI rules, animation timing guide.

## Changed Files

### `project.godot`
- Fixed `ButtonFeedback` autoload path → `res://autoloads/ButtonFeedback.gd`
- Added `Juice` autoload → `res://autoloads/Juice.gd`
- Removed broken `editor_plugins` entry for missing `button_feedback` addon

### `scripts/Main.gd`
- Updated `PRIMARY_TABS` paths: Confectionery and CoinCave now point to `.tscn` scenes

### `scripts/ConfectioneryTab.gd`
- Added `@onready` wiring block for all scene nodes
- Legacy `var` refs kept for backward compat with `_build_layout()`

### `scripts/CoinCaveTab.gd`
- Added `@onready` wiring block for scene nodes
- Legacy HBoxContainer refs kept for `_build_ui()` compat

## Migration Notes

If you were on v0.8.x:
1. Delete your `.godot/` cache folder and re-import in editor.
2. `ButtonFeedback.setup_recursive()` API is unchanged — all callsites work.
3. Juice autoload is additive — no existing code breaks.
4. CoinCaveTab and ConfectioneryTab scenes use `_build_ui()` fallback if `@onready`
   refs are null (for compatibility with script-only load paths).
