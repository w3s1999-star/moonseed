# MOONSEED  v0.8  —  UI & FX Upgrade Changelog

## v0.8.0  "Persona UI"  (ZIP 1)
- **Main.gd** — Full rewrite with Persona-inspired header architecture
  - Contracts Bar (28px): scrollable pills with live deadline countdowns
  - Resource Header (64px): LEFT slab = Stardust + Coins | CENTER = Title + Date | RIGHT = Moon + StimDie + Locations
  - Resource slab uses accent-colored border + background tint
  - Contracts chip uses bold badge label style
- **ButtonFeedback addon** — Scale-bounce tween on every Button press (GDD §17.4)
- **HUD Sparkle** — Stardust and Coin labels pulse continuously in a sine wave loop
- **StimDie** — Color changes match die type, faster scale bounce, stim label turns matching color
- **Shaders added**: `grass.gdshader`, `bg_nebula.gdshader`, `bg_ember.gdshader`, `bg_ocean.gdshader`

## v0.8.1  "Animated Feedback"  (ZIP 2)
- **FXBus autoload** — Centralised visual effects dispatcher (GDD §17.4)
  - `rain_starchunks(count, layer)` — sprite-sheet icons fall from top
  - `rain_stardust(score, layer)` — star emoji drift with glow on Save
  - `die_shockwave(die_node, value, sides)` — pip-face label expands + fades from die position
  - `score_popup(world_pos, value)` — floating "+N" label rises from die
  - `burst_sparkles(world_pos, count, color)` — multi-star burst
  - `confetti_burst(layer, duration)` — full-screen confetti shader
- **DiceTableArea** — Each settled die now emits a shockwave + score popup via FXBus
- **PlayTab** — starchunk rain and stardust rain now routed through FXBus
- **Shaders added**: `bg_void.gdshader`, `bg_aurora.gdshader`, `bg_gold.gdshader`
- **SignalBus** — New FX signals added for cross-scene FX requests

## v0.8.2  "Tab Polish"  (ZIP 3)
- **PlayTab.tscn** — Dice table center column expanded (ratio 0.46), saves button taller (38px)
- **CalendarTab** — Full rewrite: moon phase emoji per day, click to jump, score heatmap tint
- **CoinCaveTab** — Redesigned with economy stats panel, Coin Press machine, recent history
- **SettingsTab** — New table background cosmetic selector (6 shader variants)
- **DiceTableArea** — New `set_bg_key(key)` method for live background swapping
