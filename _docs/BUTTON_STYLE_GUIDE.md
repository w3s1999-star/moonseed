# Moonseed — UI Button Art Style Specification

> **Purpose:** Define the canonical visual language for all exportable PNG button assets in Moonseed.
> Buttons must look hand-crafted, jewel-like, and at home in a cozy lunar-cavern shop — never corporate, flat, or sci-fi.

---

## 1. Core Aesthetic

Moonseed buttons draw from **early cozy social gaming** (Webkinz shop UIs, Club Penguin catalogs, early Neopets storefronts) filtered through a **magical nocturnal underground** lens.
The result sits between **polished candy plastic** and **gemstone inlay** — glossy, warm, readable, and a little bit special.

**Three words to keep in mind while painting:**
> *Friendly. Glowing. Tactile.*

---

## 2. Color Palette

All buttons stay within the Moonlight theme. Tints may shift between button types but never leave this family.

| Role              | Swatch       | Hex       | Usage                                    |
|-------------------|-------------|-----------|------------------------------------------|
| Outer Rim         | Deep Violet  | `#290E7A` | Dark border, shadow side of bevel        |
| Fuchsia Nebula    | Rich Purple  | `#6F1CB2` | Mid-tone fill, secondary button base     |
| Pink Pride        | Bright Magenta | `#E31AE0` | Primary specular pop, hover glow edge   |
| Aquarium Diver    | Teal         | `#099EA9` | Accent trim, confirm button base, icon ring |
| Light Mint Green  | Off-White    | `#A1EBAC` | Top-face highlight, moonlight sheen, text |
| Moonlight Cream   | Warm White   | `#F0F8F4` | Label text, inner bevel rim              |
| Void Black        | Near-Black   | `#0D0520` | Shadow fill, pressed-state inset         |
| Lunar Gold        | Warm Gold    | `#F5C842` | Premium/shop button face, legendary trim |
| Danger Rose       | Deep Red     | `#C0185A` | Cancel/destructive base                  |

> **Gold note:** For premium buttons use a two-stop gradient: `#F5C842` at top-center → `#B8860B` at bottom edge, with a `#FFF3A0` specular streak.

---

## 3. Shape Language

### 3.1 Proportions

| Button type       | Aspect ratio | Corner radius (relative to height) |
|-------------------|-------------|-------------------------------------|
| Primary (wide)    | ~4 : 1      | 40–45 %                             |
| Secondary (wide)  | ~3.5 : 1    | 40–45 %                             |
| Confirm / Cancel  | ~3 : 1      | 40–45 %                             |
| Shop (tall label) | ~2.5 : 1    | 40–45 %                             |
| Icon-only (round) | 1 : 1       | 50 % (perfect circle or near-circle)|

Corner radius should be large enough that buttons read as **pill-shaped** on short text buttons and **lozenge-shaped** on wider ones. Never use sharp rectangles or cut corners.

### 3.2 Thickness / Depth

Buttons must look **physically thick** — like a painted wooden tile or a hard-candy disc.
Achieve this with:
- A **bottom edge shadow band** (3–6 px for a 64 px-tall button, scaled proportionally)
- A **top-rim highlight strip** (1–2 px semi-transparent white, following the curvature)
- A subtle **inner bevel** darkening the outer ~8–12 % of the face inward

Think of a thick gummy candy viewed at slight three-quarter perspective, then flattened to a front-facing sprite.

---

## 4. Lighting Model

**Light source: upper-center, slightly warm (moonlight through cavern ceiling)**

| Region                | Treatment                                                      |
|-----------------------|----------------------------------------------------------------|
| Top-center face       | Lightest value — near-white or tinted pastel streak           |
| Upper 1/3 of face     | Gradient toward mid-tone base color                           |
| Lower 2/3 of face     | Falls off to a darker, more saturated version of base         |
| Bottom edge shadow    | 30–50 % opacity near-black, 3–6 px thick, slight blur        |
| Top-rim highlight     | 60–80 % white, 1–2 px, follows pill curvature                |
| Inner glow (optional) | Soft radial bloom at center-top for magical/premium variants  |

### 4.1 Gloss vs. Matte Rules
- **All buttons:** Start with the glossy lighting model above.
- **Cancel / Danger buttons:** Reduce gloss to about 50 % — they should feel duller and heavier.
- **Premium / Gold buttons:** Increase gloss; add a secondary specular hotspot lower on the face (simulating candy-coating).
- **Icon rings:** Full gloss, teal or violet base.

---

## 5. Border / Stroke Treatment

Every button has **two outline layers:**

1. **Outer stroke** (`#290E7A`, 2–3 px)  
   Dark violet; anchors the button against any background. Slightly darker at the bottom half to reinforce depth.

2. **Inner rim highlight** (`#A1EBAC` or `#F0F8F4`, 1 px, ~50 % opacity)  
   Sits just inside the outer stroke. Follows the top arc only (roughly 270° around the top), fading out at the lower sides.  
   Creates the illusion of a beveled candy casing.

> Do **not** use a single flat 1 px border. The double-treatment is what separates Moonseed buttons from generic UI.

---

## 6. Button Type Specifications

### 6.1 Primary Button

**Purpose:** Main CTA — Roll, Craft, Confirm Quest, etc.

| Property     | Value                                                         |
|--------------|---------------------------------------------------------------|
| Base color   | `#6F1CB2` → `#290E7A` gradient (top to bottom)               |
| Gloss streak | `#E31AE0` (magenta), soft radial, centered top               |
| Border       | Outer `#290E7A`, inner rim `#A1EBAC`                         |
| Text         | `#F0F8F4`, bold, centered, slight text shadow `#290E7A` at 70 % |
| Shadow band  | 4–5 px, `#0D0520` at 45 %                                   |

---

### 6.2 Secondary Button

**Purpose:** Alternate actions — View Details, Browse, Sort, etc.

| Property     | Value                                                         |
|--------------|---------------------------------------------------------------|
| Base color   | `#290E7A` → `#1a0a35` gradient (top to bottom)               |
| Gloss streak | `#6F1CB2` (muted purple), smaller and dimmer than primary    |
| Border       | Outer `#0D0520`, inner rim `#6F1CB2` at 60 %                 |
| Text         | `#A1EBAC` (mint), semi-bold, centered                        |
| Shadow band  | 3–4 px, more subdued                                         |

**Where used:** All buttons in the **Satchel tab** — section filter bar, quick-add bar, and all card corner action buttons.

#### Card Corner Action Buttons (Satchel)

Every non-default dice-box card and every relic card shows a vertical column of three buttons anchored to the **top-left corner** of the card face:

| Position | Label    | Action                           |
|----------|----------|----------------------------------|
| 1st (top) | Studio  | Open the card studio popup       |
| 2nd       | Archive | Move the card to the archive     |
| 3rd (bottom) | Delete | Permanently delete the card   |

Default/permanent task cards show only a `⚙` options button (Archive and Delete are not applicable to permanent tasks).

---

### 6.3 Confirm Button

**Purpose:** Accept / Yes / Save — positive commitment.

| Property     | Value                                                         |
|--------------|---------------------------------------------------------------|
| Base color   | `#099EA9` → `#065F66` gradient                               |
| Gloss streak | `#A1EBAC` (mint), wide and soft                              |
| Border       | Outer `#065F66`, inner rim `#F0F8F4` at 55 %                 |
| Text         | `#F0F8F4`, bold                                              |
| Accent       | Optional tiny star icon or check glyph left of text, `#A1EBAC` |

---

### 6.4 Cancel Button

**Purpose:** Dismiss / No / Back — low-urgency rejection.

| Property     | Value                                                         |
|--------------|---------------------------------------------------------------|
| Base color   | `#C0185A` → `#7A0A35` gradient                               |
| Gloss streak | Reduced — `#E05080` at 30 % opacity only                     |
| Border       | Outer `#5A0820`, inner rim `#F0A0B0` at 40 %                 |
| Text         | `#F0F8F4`, regular weight                                    |
| Gloss level  | Half the primary gloss intensity. Feels heavier, grounded.   |

> Cancel should never look as enticing or bright as Primary. Duller reads as "less important."

---

### 6.5 Shop Button

**Purpose:** Buy, Purchase, Trade — commerce and exchange.

| Property     | Value                                                         |
|--------------|---------------------------------------------------------------|
| Base color   | `#F5C842` → `#B8860B` gradient                               |
| Gloss streak | `#FFF3A0` (pale gold), tight hotspot at top-center, + a second lower-center streak |
| Border       | Outer `#6B4C00`, inner rim `#FFF3A0` at 65 %                 |
| Text         | `#3A2800` (dark brown), bold — readable against gold         |
| Accent       | Moondrop coin icon or ✦ glyph left of price text, `#3A2800` |
| Extra depth  | Bottom shadow band slightly amber-tinted: `#6B4C00` at 50 % |

> Gold buttons must justify their presence — only commerce and unlock actions qualify.

---

### 6.6 Icon-Only Round Button

**Purpose:** Close, Settings, Favorite, Map toggle — compact utility actions.

| Property     | Value                                                         |
|--------------|---------------------------------------------------------------|
| Shape        | Perfect circle or slight squircle (corner radius = 50 %)     |
| Base color   | Matches its functional category (Primary → purple, Confirm → teal, Shop → gold) |
| Size         | 32×32 px, 48×48 px, or 64×64 px export sizes                |
| Icon         | Centered, 50–60 % of button diameter, color `#F0F8F4` or `#A1EBAC` |
| Gloss        | Same rules as parent category, but gloss streak is shorter and more central |
| Border       | Same double-layer treatment, thinner (1.5–2 px outer)        |

---

### 6.7 Tab Button (btn_tab_sm)

**Purpose:** Navigation tab — used by all main-navigation tabs in the game.

**Tabs using this button:**
- Primary bottom nav: Table, Garden, Confect, Bazaar
- Secondary top nav: Calendar, Satchel, Settings

| Property     | Value                                                         |
|--------------|---------------------------------------------------------------|
| Base color   | `#290E7A` → `#1a0a35` gradient (same as Secondary)           |
| Gloss streak | `#6F1CB2` (muted purple), subdued                            |
| Border       | Outer `#0D0520`, inner rim `#6F1CB2` at 60 %                 |
| Text         | `#A1EBAC` (mint), semi-bold, centered                        |
| Shadow band  | Bottom only, 3–4 px, subdued                                 |
| Shape        | Top corners rounded (pill-cap); **bottom edge flat** — the tab sits flush against the nav panel border |

**Canvas / export size:** Export at the **button's wireframe display dimensions**, not the generic primary-button canvas. The PNG is designed to fill the button rect exactly — Godot applies `AXIS_STRETCH_MODE_STRETCH` on the `StyleBoxTexture` to scale it to fit.

| Nav bar            | Display size      | Export canvas (2×) | Nine-patch? |
|--------------------|------------------|--------------------|-------------|
| Secondary top nav  | 140 × 48 px      | 280 × 96 px        | No — fixed size |
| Primary bottom nav | variable × 52 px | 280 × 108 px       | **Yes** — center column stretches horizontally |

For primary nav tabs (width varies with `SIZE_EXPAND_FILL`): export at 280 × 108 px (2×) and set nine-patch stretch margins of **56 px left / 56 px right** (2×) in Godot so the rounded end-caps remain fixed while the center column stretches to any width.

> **Selected state is P0 for tab buttons** — without it, the active tab is impossible to distinguish. Produce the `_selected` state before any other P1 assets.

---

## 7. State Variations

Export all interactive buttons in at least three states as separate PNGs.

### 7.1 Normal (Default)
The specification above. Full gloss, full saturation.

### 7.2 Hover / Focused
| Change       | Rule                                                         |
|--------------|--------------------------------------------------------------|
| Brightness   | Lighten the entire face by ~15 %                            |
| Gloss streak | Expand the gloss hotspot width by ~20 %, increase opacity   |
| Border       | Inner rim brightens (increase opacity to 80 %)              |
| Shadow band  | Slightly thicker / more visible (button "rises" optically)  |
| Optional     | Thin outer aura/glow ring: `#E31AE0` at 25 %, 2–4 px spread, for primary buttons only |

### 7.3 Pressed / Active
| Change       | Rule                                                         |
|--------------|--------------------------------------------------------------|
| Face shift   | Shift entire face down 2 px in canvas (simulate physical press) |
| Shadow band  | Reduce or eliminate bottom shadow                           |
| Top-rim      | Eliminate or heavily reduce top highlight                   |
| Face color   | Darken by ~20 % across the whole gradient                   |
| Gloss        | Remove gloss streak entirely or reduce to 10 % opacity      |
| Optional     | Inset inner shadow: dark ring at outer edge, `#0D0520` at 30 % |

> The goal of Pressed is to look distinctly **pushed in** — candy tile pressed into a surface.

### 7.4 Disabled (Optional)
| Change       | Reason                                                     |
|--------------|-------------------------------------------------------------|
| Saturation   | Desaturate base 60–70 %                                     |
| Opacity      | 50–60 % global alpha                                        |
| Gloss        | Remove gloss entirely                                        |
| Text         | `#A1EBAC` at 40 % opacity                                    |

---

## 8. Typography on Buttons

- **Font:** Moonseed's current UI typeface (or a friendly rounded sans — never serif, never condensed)
- **Weight:** Bold for Primary / Confirm / Shop; Regular or Semi-bold for Secondary / Cancel
- **Size guidance:** Button height × 0.38 as a rough target for cap-height. Scale down to fit, never overflow. Leave ≥ 10 % horizontal padding inside the button edges.
- **Text shadow:** `#290E7A` or `#0D0520`, offset 0, 1 px, blur 2 px — just enough to lift text off the gradient without an obvious drop shadow
- **Alignment:** Always centered (both horizontal and vertical). Icon + text combos: icon 8–10 px left of text center, treat the pair as a single centered unit.
- **Avoid:** All-caps except as a deliberate stylistic choice (shop prices). Avoid tight letter-spacing on small buttons.

---

## 9. Export Recommendations

### 9.1 Resolution
Export at **2× (double the intended display size)** at minimum. Standard target display sizes:

| Type          | Display size | Export size |
|---------------|-------------|-------------|
| Primary       | 180 × 52 px | 360 × 104 px |
| Secondary     | 160 × 48 px | 320 × 96 px  |
| Confirm       | 140 × 48 px | 280 × 96 px  |
| Cancel        | 140 × 48 px | 280 × 96 px  |
| Shop          | 160 × 52 px | 320 × 104 px |
| Icon round 32 | 32 × 32 px  | 64 × 64 px   |
| Icon round 48 | 48 × 48 px  | 96 × 96 px   |
| Tab sm (secondary nav) | 140 × 48 px | 280 × 96 px — matches wireframe exactly |
| Tab sm (primary nav)   | variable × 52 px | 280 × 108 px + nine-patch 56 px L/R margins |

### 9.2 File Naming Convention
```
btn_[type]_[state].png

Examples:
  btn_primary_normal.png
  btn_primary_hover.png
  btn_primary_pressed.png
  btn_shop_normal.png
  btn_icon_close_normal.png
  btn_icon_close_hover.png
```

### 9.3 Canvas / Export Settings
- **Background:** Transparent (alpha channel required)
- **Color profile:** sRGB
- **Compression:** PNG-32 (no lossy). Do not use indexed PNG.
- **Canvas bleed:** 2–4 px transparent padding on each edge to prevent the outer stroke from clipping when scaled.
- **Mipmaps:** Register each button in `PlaceholderArtRegistry` (or the final asset registry) with the appropriate category tag so `ArtReg` can swap them in automatically.

### 9.4 Nine-Patch Consideration
If variable-width buttons are needed at runtime, export the button face as a **nine-patch** slice:
- Left cap: left edge to end of left curve
- Center stretch: 1–4 px wide center column
- Right cap: mirror of left
- Top/bottom: do not stretch vertically (fixed height buttons)

---

## 10. What to Avoid

| Avoid                            | Reason                                                     |
|----------------------------------|-------------------------------------------------------------|
| Flat solid fills (no gradient)   | Looks modern-minimalist, inconsistent with Moonseed's feel |
| Hard drop shadows (offset x/y)   | Too early-2000s web, not the intended cozy-candy aesthetic |
| Thin 1 px flat borders           | Loses depth; use the double-layer bevel system             |
| Photorealistic textures or bevel  | Breaks the stylized toy-like quality                       |
| Sharp or angled corners          | Against the friendly rounded language                      |
| Neon only (no warm undertone)    | Pure neon reads sci-fi / cyberpunk, not lunar-cavern cozy  |
| Sans-serif ultra-light fonts     | Too modern; use bold/rounded weights                       |
| Buttons with no shadow band      | Looks pasted-on, not tactile                               |
| Gold on non-premium actions      | Dilutes the scarcity signal of shop/premium gold           |

---

## 11. Quick Reference Cheat-Sheet

```
Primary:   #6F1CB2 → #290E7A | gloss #E31AE0 | text #F0F8F4
Secondary: #290E7A → #1a0a35 | gloss #6F1CB2 | text #A1EBAC
Confirm:   #099EA9 → #065F66 | gloss #A1EBAC | text #F0F8F4
Cancel:    #C0185A → #7A0A35 | gloss LOW     | text #F0F8F4
Shop:      #F5C842 → #B8860B | gloss #FFF3A0 | text #3A2800
Icon:      matches parent category

All: outer border #290E7A (dark), inner rim #A1EBAC (light, 50–80 % opacity)
All: bottom shadow band #0D0520 @ 40–50 %, 3–6 px
All: top-rim highlight #F0F8F4 @ 60–80 %, 1–2 px, top arc only

States:
  Hover   → brighten +15 %, expand gloss, thicker rim
  Pressed → darken −20 %, remove gloss, remove top highlight, shift down 2 px
  Disabled → desaturate −65 %, 55 % global alpha, no gloss
```

---

## 12. Production Concept — Primary Action Button (btn_primary_lg_normal)

> Single-button deep-dive for the artist producing the first pass PNG.
> All values here are concrete paint instructions, not references to other sections.

---

### 12.1 Concept Brief

A **rounded capsule** button that evokes a polished hard-candy disc resting on a velvet surface inside a moon-lit cavern boutique.
It should read as friendly, pressable, and slightly magical — the visual language of a Webkinz shop "BUY" button crossed with a glowing amethyst slab.

No text, no icon — a clean, reusable shell.

---

### 12.2 Canvas Setup

| Parameter | Value |
|---|---|
| Canvas size (1×: display) | 204 × 60 px (includes 2 px bleed on each edge) |
| Canvas size (2×: export) | 408 × 120 px |
| Background | Transparent (alpha = 0) |
| Color profile | sRGB |
| Working color depth | 8-bit per channel minimum |

> The live button silhouette is 200 × 56 px centered within the canvas. The outer 2 px on every side is transparent bleed — keeps the border stroke from clipping at UV seams in Godot.

---

### 12.3 Silhouette / Base Shape

**Layer name:** `shape_base`

- Shape: horizontal capsule (rectangle with fully rounded ends)
- Width: 200 px · Height: 56 px (1×) — 400 × 112 px (2×)
- Corner radius: **28 px at 1×** (exactly half the height → true pill ends)
- Fill: solid `#6F1CB2` (placeholder; will be replaced by gradient in the next layer)
- Anti-alias: on, 1 px feather at edge
- This layer defines the alpha mask for all layers above — clip everything to this shape

---

### 12.4 Layer Stack (bottom to top)

Paint in this order. All layers are clipped to `shape_base` unless noted with ★.

---

#### Layer 1 — Bottom Shadow Band ★ (outside clip)

**Layer name:** `shadow_band`

- Shape: ellipse, roughly 180 × 10 px (1×)
- Position: centered horizontally, bottom edge of button + 2 px below silhouette
- Fill: radial gradient `#0D0520` → transparent
- Opacity: 45 %
- Blur: 4 px Gaussian
- Purpose: simulates the button casting a soft shadow onto the surface below; adds physical weight

---

#### Layer 2 — Base Gradient Fill

**Layer name:** `fill_gradient`

- Type: linear gradient, top → bottom
- Top color: `#7B2CC4` (slightly lighter than the mid purple)
- Mid color (50 %): `#6F1CB2`
- Bottom color: `#290E7A`
- Angle: 90° (straight vertical)
- Clipped to `shape_base`

---

#### Layer 3 — Outer Border Stroke

**Layer name:** `border_outer`

- Stroke only (no fill), following the `shape_base` silhouette exactly
- Stroke width: 2 px (1×) / 4 px (2×), inside the silhouette edge
- Color: `#290E7A`
- Bottom half (below center): darken stroke to `#1A0550` — this subtle shift reinforces the sense of depth and shadow at the base of the button
- Opacity: 100 %

---

#### Layer 4 — Inner Rim Highlight Arc

**Layer name:** `rim_highlight`

- Paint or mask a 1 px (1×) / 2 px (2×) stroke along the **top arc only**
- Arc coverage: roughly from the 9 o'clock position, over the top, to the 3 o'clock position (upper ~180°–200° of the pill perimeter)
- Color: `#F0F8F4` (moonlight cream)
- Opacity: 65 % at the top-center, fading to 0 % at the sides where it meets the 3/9 o'clock positions
- Technique: paint as a full ring stroke, mask the bottom half, apply fade with a gradient mask
- This reads as a thin glassy bevel catching the ceiling light

---

#### Layer 5 — Main Gloss Streak

**Layer name:** `gloss_main`

- Shape: wide, soft ellipse — approximately 120 × 18 px (1×)
- Position: horizontally centered; top edge at ~6 px from the top of the silhouette
- Fill: radial gradient, center → edge: `#E8C8FF` (pale pink-lilac) at 80 % opacity → transparent
- Blend mode: Screen (or Hard Light at 40 % opacity if Screen reads too bright)
- Blur: 3 px
- Purpose: the primary gloss hotspot; simulates a ceiling light source slightly behind the viewer

---

#### Layer 6 — Secondary Gloss Blush

**Layer name:** `gloss_blush`

- Shape: wider, much softer ellipse — approximately 160 × 26 px (1×)
- Position: horizontally centered; sits 2 px below Layer 5, overlapping it
- Fill: radial gradient, `#C89EF0` (soft lavender) at 30 % opacity → transparent
- Blend mode: Screen
- Blur: 6 px
- Purpose: broadens the gloss zone so the top of the button reads as gently illuminated, not just spot-lit

---

#### Layer 7 — Lower Depth Shadow

**Layer name:** `depth_shadow`

- Type: linear gradient, from ~65 % down to bottom edge
- Color: `#1A0550` → `#0D0520`
- Opacity: 50–60 %
- Blend mode: Multiply
- Purpose: deepens the lower third of the button face; completes the sense that the light source is above

---

#### Layer 8 — Bottom Inner Shadow Band

**Layer name:** `inner_shadow_bottom`

- Shape: thin half-ellipse along the inside bottom edge of the silhouette, ~180 × 8 px (1×)
- Fill: `#0D0520` → transparent (radial, fading inward toward center)
- Opacity: 35 %
- Blur: 3 px
- Purpose: reinforces the curved underside of the candy-disc shape; distinct from the outer shadow cast below

---

#### Layer 9 — Sparkle Accent (Optional)

**Layer name:** `sparkle_accent`

- Two to three 4-pointed star glints, 3–5 px point-to-point (1×)
- Positions: scatter loosely in the upper-right quadrant of the button face, within the gloss zone; avoid dead center
- Color: `#F0F8F4` (cream-white), full opacity at center of each glint, alpha 0 at tips
- Each glint: a small × or + shape with slightly soft tips — not a solid polygon, more like a light flare on glass
- Opacity: 70–85 %
- These are subtle; if they compete with text at runtime, reduce to 50 %
- Mark this layer optional — export a version with and without for artist review

---

### 12.5 Color Summary for This Button

| Layer | Color(s) | Opacity |
|---|---|---|
| Outer shadow cast | `#0D0520` → transparent | 45 % |
| Fill gradient top | `#7B2CC4` | 100 % |
| Fill gradient mid | `#6F1CB2` | 100 % |
| Fill gradient bottom | `#290E7A` | 100 % |
| Border (top half) | `#290E7A` | 100 % |
| Border (bottom half) | `#1A0550` | 100 % |
| Inner rim arc | `#F0F8F4` | 65 % center → 0 % sides |
| Gloss main | `#E8C8FF` | 80 % → 0 % |
| Gloss blush | `#C89EF0` | 30 % → 0 % |
| Depth shadow | `#1A0550` → `#0D0520` | 50–60 % multiply |
| Inner base shadow | `#0D0520` | 35 % |
| Sparkle glints | `#F0F8F4` | 70–85 % (optional) |

---

### 12.6 What the Finished Button Should Evoke

Read through this checklist before finalizing:

- [ ] Silhouette is a clean smooth pill — no bumps, no flat sides
- [ ] Top of button reads as brighter / lighter than bottom without any harsh line
- [ ] Button appears to have physical thickness — like something you could pick up
- [ ] The inner rim arc catches the eye as a thin glassy edge, not a chunky bevel
- [ ] Gloss streak feels soft and painterly, not like a vector gradient bar
- [ ] Overall gradient is rich and jewel-like — closer to a polished amethyst than a plastic toy
- [ ] The button reads cleanly at 48 × 14 px (thumbnail preview) — no layers of detail fighting each other
- [ ] At full size, sparkle glints add a magical quality without distracting from the button's neutral state

---

### 12.7 Export Sizes

| Variant | Canvas | Silhouette | Filename |
|---|---|---|---|
| 1× (display reference) | 204 × 60 px | 200 × 56 px | `btn_primary_lg_normal@1x.png` |
| 2× (Godot import target) | 408 × 120 px | 400 × 112 px | `btn_primary_lg_normal.png` |
| Thumbnail proof | 102 × 30 px | — | `btn_primary_lg_normal_thumb.png` |

> Import the 2× file into Godot. Set texture filter to **Linear** and import as `Texture2D`. Attach to a `TextureButton` node; the engine will display it at the intended 1× size on a standard-density screen and scale up on HiDPI displays automatically.

---

## 13. State Variation Specs — btn_primary_lg

> These are paint-level deltas from the `_normal` base (Section 12).
> Start from a flattened copy of the normal composite and apply only the changes listed below.
> All hex values and layer names reference Section 12's stack.

The five states form a coherent arc:

```
disabled  ←  normal  →  hover  →  pressed
                ↕
            selected
```

`disabled` is the quietest; `hover` the most luminous; `pressed` the most inward; `selected` sits between `hover` and `normal` — persistently lit but not momentarily active.

---

### 13.1 idle (normal)

This is the Section 12 base. No changes. Repeated here only for reference.

| Property | Value |
|---|---|
| Lighting | Full gradient (`#7B2CC4` → `#290E7A`), gloss main at 80 % |
| Border | Outer `#290E7A` 2 px; inner rim arc `#F0F8F4` 65 % |
| Shadow (cast) | `shadow_band` at 45 %, 4 px blur |
| Glow | None |
| Scale illusion | Neutral — shadow band is present and grounded |
| Filename | `btn_primary_lg_normal.png` |

---

### 13.2 hover

**Feel:** The button catches the light. It rises slightly toward the player — an invitation.

#### Lighting
- Brighten the entire `fill_gradient` by shifting the top stop to `#9040D8` and the mid stop to `#8030C0`. Keep the bottom stop at `#290E7A`.
- Expand `gloss_main` horizontally by ~15 % (about 18 px wider at 1×). Increase its opacity from 80 % → **95 %**.
- Increase `gloss_blush` opacity from 30 % → **48 %**.
- Add a new layer **`glow_edge`** *below* `shape_base` (not clipped): a soft bloom following the button silhouette, color `#E31AE0` (magenta), 4–6 px spread, 20–25 % opacity, 5 px blur. This is the hover's signature magical aura.

#### Border
- Inner rim arc (`rim_highlight`): increase opacity from 65 % → **82 %**.
- Outer border: shift top-half color from `#290E7A` → `#5020A0` — slightly lighter so it doesn't compete with the glow.

#### Shadow (cast)
- Increase `shadow_band` blur from 4 px → **6 px** and expand its ellipse slightly (~8 px wider). The button appears to have risen off the surface, softening the shadow footprint.
- Opacity: increase slightly from 45 % → **50 %**.

#### Glow
- `glow_edge` outer aura: `#E31AE0`, 4–6 px, 22 % opacity (applied outside the silhouette — not clipped).
- Optional: add a second wider haze ring at `#C060F0`, 10 px spread, 10 % opacity, fully blurred.

#### Scale illusion
- The button reads as ~2–3 px taller due to the expanded shadow footprint and glow ring. Do **not** actually resize the silhouette — the effect is achieved entirely through shadow/glow expansion.

| Property | Value |
|---|---|
| Filename | `btn_primary_lg_hover.png` |

---

### 13.3 pressed

**Feel:** The button dents inward — a satisfying physical click. The glow collapses. The face darkens.

#### Lighting
- Darken the `fill_gradient`: top stop → `#4E1280`, mid → `#3A0A68`, bottom → `#1A0550`.
- **Remove `gloss_main` entirely** (hide or delete the layer). A pressed button surface has no specular reflection because the angle has changed.
- Reduce `gloss_blush` to **10 % opacity** — a faint memory of the gloss.
- Remove the `sparkle_accent` layer (hide). No glints on a depressed surface.

#### Border
- Inner rim arc (`rim_highlight`): reduce to **0 % opacity** — the bevel highlight disappears when the surface is concave toward the viewer.
- Outer border: darken entire stroke to `#1A0550`, 2 px, uniform (no lighter top half). The rim is fully in shadow.
- Add a new **`inner_press_shadow`** layer (clipped): a thin dark ring 2–3 px wide just inside the silhouette edge, color `#0D0520`, 30 % opacity, 2 px blur. Simulates the inset cavity rim.

#### Shadow (cast)
- **Reduce `shadow_band` opacity to 20 %** and reduce its ellipse size by ~12 px width. The button is closer to the surface — the cast shadow shrinks.
- Shift `shadow_band` position up by 2 px to match the visual "press-in" movement.

#### Glow
- None. No `glow_edge`. The hover aura layer is hidden.

#### Scale illusion
- The entire painted content (all layers except the canvas boundaries) should be shifted **down 2 px** within the canvas. This simulates the button physically depressing without altering the export canvas size — Godot sees the same texture dimensions and doesn't shift the layout.
- The smaller shadow and absence of glow make the button read as smaller/lower even though the silhouette is identical.

| Property | Value |
|---|---|
| Filename | `btn_primary_lg_pressed.png` |

---

### 13.4 disabled

**Feel:** The magic has drained out. The button is present but inert — a faded gem, still recognizable, not alarming.

#### Lighting
- Desaturate the `fill_gradient` by 65 % — it should trend toward a dull blue-grey. Approximate result: top `#5A4870`, mid `#40325A`, bottom `#1E1530`.
- Reduce `gloss_main` to **18 % opacity**.
- Reduce `gloss_blush` to **8 % opacity**.
- Remove `sparkle_accent` (hide).

#### Border
- Inner rim arc: reduce to **30 % opacity**.
- Outer border: desaturate to near-grey-violet `#2E2240`, 1.5 px (slightly thinner).

#### Shadow (cast)
- Reduce `shadow_band` to **25 % opacity**. The button barely casts a shadow — it feels lighter, less present.

#### Glow
- None.

#### Scale illusion
- No shift. The button sits flat at normal position. The visual lightness (reduced shadow, no glow) makes it read as slightly recessed without any position change.

#### Global alpha
- Apply **55 % opacity to the entire flattened composite** as a final step. This ensures the button shows through whatever panel it sits on, reading as ghosted but not invisible.

| Property | Value |
|---|---|
| Filename | `btn_primary_lg_disabled.png` |

---

### 13.5 selected

**Feel:** This button is the active choice — a toggle that has been set. It glows with a steady, enchanted light, neither excited like hover nor neutral like normal. It has settled into its power.

#### Lighting
- Shift `fill_gradient` midtone slightly warmer and brighter: mid stop `#7D28C8`, top stop `#8C35D5`. Bottom stays `#290E7A`.
- Set `gloss_main` to **70 % opacity** — present but not as intense as hover.
- Reduce gloss ellipse width to ~90 % of normal (slightly tighter; the glow is the focus, not the specular streak).
- Add a new layer **`inner_selected_glow`** (clipped): a large soft radial bloom centered on the button face, color `#C060F0` → transparent, 20 % opacity, 12 px blur. This gives the face a gentle internal luminosity, as if lit from within.

#### Border
- Inner rim arc: **80 % opacity**, slightly more visible than normal to frame the inner glow.
- Outer border: shift full-stroke color to `#5C20A8` — a mid-violet, lighter than normal's shadowed base but not as bright as hover.
- Add a thin **outer selection ring** just outside the silhouette (outside the clip): 1 px stroke, color `#C060F0`, 50 % opacity. This is different from the hover's diffuse aura — it's a tight, clean ring, like a gem in a setting.

#### Shadow (cast)
- `shadow_band` at **40 % opacity** — slightly less than normal, making the button read as hovering a hair above the surface permanently.
- Keep blur at 4 px (same as normal).

#### Glow
- Inner glow: `#C060F0` radial, clipped, 20 % opacity, 12 px blur.
- Outer ring: `#C060F0` 1 px stroke, 50 % opacity (tight, not diffuse).
- No magenta aura (`glow_edge` from hover is not used here).

#### Scale illusion
- No position shift. The tight outer ring and reduced shadow give a subtle "hovering selected" quality without the button appearing to move.

| Property | Value |
|---|---|
| Filename | `btn_primary_lg_selected.png` |

---

### 13.6 State Comparison Table

| Property | idle | hover | pressed | disabled | selected |
|---|---|---|---|---|---|
| Fill brightness | Base | +15 % | −25 % | −65 % desat | +8 % |
| Gloss main opacity | 80 % | 95 % | 0 % | 18 % | 70 % |
| Gloss blush opacity | 30 % | 48 % | 10 % | 8 % | 30 % |
| Inner rim arc opacity | 65 % | 82 % | 0 % | 30 % | 80 % |
| Outer border color | `#290E7A` | `#5020A0` | `#1A0550` (uniform) | `#2E2240` | `#5C20A8` |
| Outer glow / aura | None | Magenta diffuse 22 % | None | None | Purple ring 50 % |
| Inner glow | None | None | Inset shadow rim | None | `#C060F0` radial 20 % |
| Cast shadow opacity | 45 % | 50 % | 20 % | 25 % | 40 % |
| Cast shadow size | Normal | +8 px wider | −12 px narrower | Slightly reduced | Normal |
| Content Y shift | 0 px | 0 px | +2 px down | 0 px | 0 px |
| Global alpha | 100 % | 100 % | 100 % | 55 % | 100 % |
| Sparkle accent | Optional | Optional | Hidden | Hidden | Optional |

---

### 13.7 Filenames and Export Summary

All exports: transparent PNG-32, 408 × 120 px (2× canvas), sRGB.

| State | Filename | Priority |
|---|---|---|
| idle | `btn_primary_lg_normal.png` | P0 |
| hover | `btn_primary_lg_hover.png` | P0 |
| pressed | `btn_primary_lg_pressed.png` | P0 |
| disabled | `btn_primary_lg_disabled.png` | P1 |
| selected | `btn_primary_lg_selected.png` | P2 |

> In Godot, assign all five to a `TextureButton` node:
> - `texture_normal` → `_normal`
> - `texture_hover` → `_hover`
> - `texture_pressed` → `_pressed`
> - `texture_disabled` → `_disabled`
> - `texture_focused` → `_selected` (or manage selected state via script by swapping `texture_normal` when the toggle is active)

---

## 14. Bazaar Merchant Button Theme Variants

> Each merchant stall in the Lunar Bazaar gets its own button skin applied atop the shared pill-shaped base from Sections 12–13.
> The silhouette, export canvas size, text safe area, and state delta rules (Section 13) are **identical** for all variants.
> Only the fill palette, border color, gloss tint, and ornament layer change.

### 14.1 Unity Rules — What Never Changes

These properties are locked across all merchant variants to keep the system readable as a family:

| Property | Locked Value |
|---|---|
| Silhouette shape | Pill / capsule, corner radius = 50 % height |
| Export canvas size | 408 × 120 px (2×) |
| Text safe area | L/R 20 px · T/B 12 px (1×) |
| Outer stroke width | 2 px (1×) |
| Inner rim arc coverage | Top ~180°, fades at sides |
| Gloss streak position | Centered top, same soft-ellipse shape |
| State delta rules | Section 13 (hover +15 %, pressed −25 %, etc.) apply to all variants |
| Export format | Transparent PNG-32, sRGB |

> **How to apply state deltas to a variant:** Take the variant's `_normal` composite and apply exactly the same relative shifts described in Section 13 — but starting from the variant's own base colors. E.g. the Sweetmaker hover brightens *its* candy-rose fill by +15 %, not the primary purple.

---

### 14.2 Pearl Exchange

**Character:** A water-world merchant dealing in rare shells, gleaming orbs, and lunar tides. Her buttons should feel like polished nacre — cool, luminous, layered with iridescent depth.

#### Fill Gradient
| Stop | Color | Hex |
|---|---|---|
| Top | Pale teal-white | `#B8EEF0` |
| Mid | Ocean teal | `#099EA9` |
| Bottom | Deep cavern teal | `#065F66` |

#### Border
- Outer stroke: `#044A50` (deep teal-black)
- Inner rim arc: `#E8FEFF` at 70 % — ice-pale blue-white; gives a nacreous edge sheen

#### Gloss
- Main streak: `#FFFFFF` radial, 85 % opacity — Pearl Exchange gloss is the brightest of all merchant variants; it reads as wet and reflective
- Blush layer: `#C0F0F4` at 38 % — cool-tinted secondary bloom
- Add a third ultra-thin streak: a narrow 2 px (1×) horizontal band of `#FFFFFF` at 90 % opacity sitting at the very top of the face, just below the rim arc — simulates the hard specular line on a pearl surface

#### Ornament
- Paint a tiny double-arc motif (like two stacked crescent moons or a partial shell) in the far-left or far-right margin of the text safe area, rendered in `#E8FEFF` at 55 % opacity
- Optional: faint concentric oval contours across the face at 6–8 % opacity in `#AADDDF` — the iridescent ring pattern inside a pearl or abalone shell; keep extremely subtle

#### Cast Shadow
`#044A50` → transparent, 40 % opacity — tinted rather than the default near-black

#### Naming
`btn_merchant_pearl_normal.png`, `…_hover.png`, `…_pressed.png`, `…_disabled.png`, `…_selected.png`

---

### 14.3 Dice Carver

**Character:** A stoic craftsman who cuts crystal and stone into playing dice. His buttons should feel like a faceted geode slab with a glowing crystal edge — heavy, precise, cool.

#### Fill Gradient
| Stop | Color | Hex |
|---|---|---|
| Top | Dusty stone-violet | `#5A4870` |
| Mid | Carved granite-purple | `#3D2C58` |
| Bottom | Deep obsidian | `#1E1030` |

#### Border
- Outer stroke: `#120A22` (near-black obsidian)
- Inner rim arc: `#C8A8FF` at 60 % — this represents crystal catching the light at the faceted edge; it has a sharper, more geometric character than other variants

#### Gloss
- Main streak: **replace the soft radial ellipse with two narrow angled strips** — simulating facet reflections rather than a smooth surface. Each strip: 3–4 px wide (1×), angled ~15° from vertical, `#D8C0FF` at 70 %, hard-edged (no blur, or max 1 px). Space them ~24 px apart, centered on the button face.
- Blush layer: `#9070C0` at 22 % — subdued; the stone absorbs rather than reflects
- No ultra-bright single hotspot; the facet strips are the signature of this variant

#### Ornament
- One small six-sided die pip cluster in the far-right margin of the text safe area: six dots arranged in ⚅ formation, 2 px circles (1×), color `#C8A8FF` at 65 %
- Optional: faint geometric hex-grid or cracked-stone texture across the face at 5 % overlay — stone surface grain

#### Cast Shadow
`#0D0820` → transparent, 50 % opacity — heavier than average; this button is weighty

#### Naming
`btn_merchant_dice_normal.png` etc.

---

### 14.4 Curio Dealer

**Character:** A wandering collector of arcane relics, strange maps, and forgotten enchantments. Her buttons feel like holding an artefact — deep, slightly unsettling, softly glowing with unknown energy.

#### Fill Gradient
| Stop | Color | Hex |
|---|---|---|
| Top | Arcane blue-violet | `#2A1A6E` |
| Mid | Relic indigo | `#1C1050` |
| Bottom | Void abyss | `#0A0830` |

#### Border
- Outer stroke: `#0A0620` (almost pure void-black)
- Inner rim arc: `#7060C8` at 55 % — a cooler, bluer rim than the standard purple; suggests an older, stranger magic

#### Gloss
- Main streak: `#A090E8` radial, 50 % opacity — significantly dimmer than primary; the button feels like it barely wants to reveal itself
- Blush layer: `#5040A0` at 30 %
- Add a **pulsing-feel effect** through paint: a second faint radial glow at the center of the face rather than the top — color `#4030C0`, 15 % opacity, 10 px blur. This shifts the light source to feel internal (emanating from inside the object) rather than external (ceiling light)

#### Ornament
- A runic eye or small crescent-with-dot symbol, 8–10 px diameter (1×), placed at center-left within text safe area, `#8070D0` at 50 % opacity
- Optional: two to four scattered small crosshatch marks along the lower face edge — aged relic surface texture, `#3020A0` at 8 % opacity

#### Cast Shadow
`#050318` → transparent, 38 % opacity — slightly less present; a relic can appear to float

#### Naming
`btn_merchant_curio_normal.png` etc.

---

### 14.5 Sweetmaker Stall

**Character:** A cheerful confectioner selling lunar bonbons, eclipse caramels, and starlight truffles. Her buttons are the warmest in the Bazaar — candy-bright, sugar-coated, irresistibly soft.

#### Fill Gradient
| Stop | Color | Hex |
|---|---|---|
| Top | Candy rose | `#E87AB0` |
| Mid | Deep strawberry | `#C0408A` |
| Bottom | Warm berry | `#82205A` |

#### Border
- Outer stroke: `#5A0A38` (deep berry-black)
- Inner rim arc: `#FFD0E8` at 72 % — warm cotton-candy pink; the warmest rim in the system

#### Gloss
- Main streak: `#FFF0F8` radial, 92 % opacity — nearly white, very broad; candy surfaces are extremely glossy
- Blush layer: `#FFB8D8` at 45 % — warm pink secondary bloom, wider than usual
- A third ultra-bright hotspot: 1 px (1×) pinpoint of `#FFFFFF` at 100 % at the very top-center of the face — a single hard candy reflection point
- The overall top-third of this button should feel nearly overexposed — that's correct for the style

#### Ornament
- One to two tiny five-pointed stars (3–4 px point-to-point, 1×) in the upper-right gloss zone, `#FFF0F8` at 80 % — these are the same sparkle glints from Section 12 Layer 9 but more prominent on this variant
- Optional: small heart or sprig of three dots (like sugar sprinkles) near the far-right margin, `#FFD0E8` at 55 %

#### Cast Shadow
`#5A0A38` → transparent, 42 % opacity — slightly warm-tinted shadow; even this button's shadow is cozy

#### Naming
`btn_merchant_sweet_normal.png` etc.

---

### 14.6 Selenic Exchange

**Character:** A dignified currency exchange operating under the Moon Shrine's authority. Sacred, unhurried, pristine. Her buttons carry a sense of ritual and permanence — silver moonstone, white jade, calm silver light.

#### Fill Gradient
| Stop | Color | Hex |
|---|---|---|
| Top | Pale silver-white | `#D8D4F0` |
| Mid | Moonstone grey-violet | `#9890C8` |
| Bottom | Dusky shrine-slate | `#4A4470` |

#### Border
- Outer stroke: `#2E2850` (dim purple-grey)
- Inner rim arc: `#F8F6FF` at 78 % — the brightest, purest inner rim in the system; a sacred silver edge

#### Gloss
- Main streak: `#FFFFFF` radial, 75 % opacity — clean white, not tinted; this is a cool, neutral light
- Blush layer: `#E0DCF8` at 32 % — very pale silver-lavender; barely tinted
- Gloss has a slightly wider-but-softer spread than the primary button — the light source feels further away, more ambient, like open moonlight rather than a shop lamp

#### Ornament
- A thin horizontal rule (single 1 px line, 1×) running left-to-right across the vertical center of the button face, color `#F8F6FF` at 18 % opacity — a barely-visible sacred register line, like an inscription groove in white jade
- Optional: a small crescent moon symbol (4–6 px, 1×) in the far-left margin, `#D8D4F0` at 60 % — the Shrine's mark

#### Cast Shadow
`#181430` → transparent, 35 % opacity — the softest shadow in the system; this button rests rather than sits

#### Naming
`btn_merchant_selenic_normal.png` etc.

---

### 14.7 Merchant Variant Quick Reference

| Merchant | Fill (top → bottom) | Rim Arc | Gloss Tint | Signature Ornament |
|---|---|---|---|---|
| Pearl Exchange | `#B8EEF0` → `#099EA9` → `#065F66` | `#E8FEFF` 70 % | `#FFFFFF` wet-bright | Nacreous rings, shell-arc motif |
| Dice Carver | `#5A4870` → `#3D2C58` → `#1E1030` | `#C8A8FF` 60 % | Facet strips, no soft bloom | ⚅ pip cluster |
| Curio Dealer | `#2A1A6E` → `#1C1050` → `#0A0830` | `#7060C8` 55 % | Internal glow, dim streak | Runic eye / crescent-dot |
| Sweetmaker | `#E87AB0` → `#C0408A` → `#82205A` | `#FFD0E8` 72 % | `#FFF0F8` candy-bright | Stars, sprinkle dots, hard hotspot |
| Selenic Exchange | `#D8D4F0` → `#9890C8` → `#4A4470` | `#F8F6FF` 78 % | `#FFFFFF` cool-ambient | Horizontal rule, crescent mark |

---

### 14.8 File Naming Summary

```
assets/ui/buttons/merchants/
├── btn_merchant_pearl_normal.png
├── btn_merchant_pearl_hover.png
├── btn_merchant_pearl_pressed.png
├── btn_merchant_pearl_disabled.png
├── btn_merchant_pearl_selected.png
├── btn_merchant_dice_normal.png
│   … (dice states)
├── btn_merchant_curio_normal.png
│   … (curio states)
├── btn_merchant_sweet_normal.png
│   … (sweet states)
├── btn_merchant_selenic_normal.png
│   … (selenic states)
```

> Register each completed merchant button set in `PlaceholderArtRegistry` under the category `"ui_button_merchant"` with the merchant key (`"pearl"`, `"dice"`, `"curio"`, `"sweet"`, `"selenic"`) so vendor UIs can look up their texture set without hardcoding asset paths.

---

## 15. Production Workflow — Button Art Pipeline

> Practical step-by-step guide for creating, revising, and exporting Moonseed button PNGs.
> Assumes any raster app that supports layers and named groups (Krita, Photoshop, Aseprite high-res, Affinity Photo, etc.).
> Source files live outside the Godot project. Only finished PNGs are committed to the repo.

---

### Step 1 — Folder Structure

#### Source files (outside Godot project)

```
moonseed_art_source/
└── ui/
    └── buttons/
        ├── _template/
        │   ├── btn_template_base.kra          ← master document; all shared layers
        │   └── btn_template_base_notes.md     ← layer naming & color token reference
        ├── primary/
        │   ├── btn_primary_lg.kra
        │   └── btn_primary_md.kra
        ├── secondary/
        │   └── btn_secondary.kra
        ├── functional/
        │   ├── btn_tab_sm.kra
        │   ├── btn_confirm.kra
        │   ├── btn_cancel.kra
        │   └── btn_shop_merchant.kra
        ├── icon/
        │   └── btn_icon_circle.kra
        └── merchants/
            ├── btn_merchant_pearl.kra
            ├── btn_merchant_dice.kra
            ├── btn_merchant_curio.kra
            ├── btn_merchant_sweet.kra
            └── btn_merchant_selenic.kra
```

#### Exported PNGs (inside Godot project)

```
res://assets/ui/buttons/
├── btn_primary_lg_normal.png
├── btn_primary_lg_hover.png
├── btn_primary_lg_pressed.png
├── btn_primary_lg_disabled.png
├── btn_primary_lg_selected.png
│   … (all standard button exports)
└── merchants/
    ├── btn_merchant_pearl_normal.png
    │   … (all merchant state exports)
```

> The source folder is version-controlled separately (e.g., in a sibling art repo or a shared drive). The Godot project imports only the final PNGs — never the `.kra` / `.psd` source files.

---

### Step 2 — Build the Master Template

Open `btn_template_base.kra`. This is the foundation every source file inherits from.

#### Canvas
- Size: **408 × 120 px** (2× export canvas)
- Background: transparent
- Color profile: sRGB / 8-bit

#### Required layer groups in order (bottom to top)

```
[GROUP] shadow_cast          ← cast shadow below button; NOT clipped to silhouette
[GROUP] shape_base           ← defines the alpha mask for all clipped groups
  └── fill_gradient          ← base color gradient, clipped
[GROUP] border               ← clipped to shape_base
  ├── border_outer           ← 2 px inside stroke
  └── rim_highlight          ← 1 px top arc, fades at sides
[GROUP] gloss                ← clipped
  ├── gloss_main             ← primary specular ellipse
  ├── gloss_blush            ← secondary wider bloom
  └── gloss_hotspot          ← optional 1 px pinpoint (used by Pearl, Sweetmaker)
[GROUP] depth                ← clipped
  ├── depth_shadow           ← multiply gradient, lower third
  └── inner_shadow_bottom    ← curved inner base edge
[GROUP] decoration           ← clipped; all ornaments go here
  └── sparkle_accent         ← optional; toggle visibility per variant
[GROUP] state_overlay        ← LEAVE EMPTY in template; used only during state painting
```

> Name every layer and group exactly as above. This makes the recolor step (Step 5) mechanical rather than guesswork.

---

### Step 3 — Paint the Normal State

Work only inside `btn_template_base.kra` or its derivative source file.

1. **`shadow_cast`** — paint the bottom cast shadow. Use the Section 12 values as starting point.
2. **`fill_gradient`** — set the base fill. For the primary button this is `#7B2CC4` → `#6F1CB2` → `#290E7A`. For a merchant variant, swap these colors here only.
3. **`border_outer`** — 4 px stroke (2× canvas) on the silhouette path, inside edge. Bottom-half color is 20 % darker than top-half.
4. **`rim_highlight`** — 2 px (2× canvas) arc on top ~180°, opacity falloff to 0 at sides.
5. **`gloss_main`** — soft ellipse, Screen or Hard Light blend.
6. **`gloss_blush`** — wider softer ellipse, Screen blend.
7. **`depth_shadow`** — Multiply gradient on lower face.
8. **`inner_shadow_bottom`** — thin bottom-edge inset arc.
9. **`decoration/sparkle_accent`** — paint optional glints. Toggle off if not needed.

At this stage: **do not flatten**. Save the `.kra` with all layers intact.

---

### Step 4 — Derive State Variants in the Same File

Add one **layer group per state** above the normal stack. Each state group is structured identically to the normal stack but contains only the *delta layers* — layers that differ from normal.

```
[GROUP] state_disabled    ← visibility off by default
[GROUP] state_selected    ← visibility off by default
[GROUP] state_pressed     ← visibility off by default
[GROUP] state_hover       ← visibility off by default
[GROUP] state_normal      ← always on; this is the base stack
```

Inside each state group, include only what changes:

| State group | What to place inside |
|---|---|
| `state_hover` | Brightened `fill_gradient` copy; expanded `gloss_main`; `glow_edge` aura |
| `state_pressed` | Darkened `fill_gradient`; hidden gloss layers; `inner_press_shadow`; entire group shifted +2 px down; shrunk `shadow_cast` |
| `state_disabled` | Desaturated + reduced-opacity `fill_gradient`; dimmed `border_outer`; hidden gloss layers |
| `state_selected` | Slightly brightened fill; `inner_selected_glow`; `outer_selection_ring` |

**Workflow for a state:**
1. Duplicate the `state_normal` group.
2. Rename it (e.g. `state_hover`).
3. Set `state_normal` visibility off temporarily.
4. Edit only the sub-layers that need to change per the Section 13 delta rules.
5. Turn `state_normal` back on. Turn off the new state group.

> Keep all state groups in the same `.kra` file. This way recoloring the fill in one place ripples through all states.

---

### Step 5 — Recolor for Merchant Variants

For each merchant variant (Section 14):

1. **Duplicate** the relevant source file (e.g. `btn_primary_lg.kra` → `btn_merchant_pearl.kra`).
2. Open the duplicate. Locate `fill_gradient` inside every state group.
3. Replace fill stops with the merchant-specific palette from Section 14.
4. Update `border_outer` color.
5. Update `rim_highlight` color and opacity.
6. Update `gloss_main` and `gloss_blush` tints.
7. Replace or hide the `decoration/sparkle_accent` layer; paint the merchant's ornament instead.
8. Do **not** alter layer structure, canvas size, or silhouette shape.

> If your app supports color variables / global swatches (Krita Palette Docker, Photoshop Global Colors): define the six primary palette tokens as named swatches. Swapping a merchant variant then requires changing six swatch values, not hunting through layers.

---

### Step 6 — Export PNGs

For each state that needs a PNG:

1. Turn on exactly one state group. Turn all others off. Confirm `state_normal` is **off**.
2. Flatten to a new canvas — do **not** save over the source file.
3. Export: File → Export as PNG.
   - Canvas: 408 × 120 px (crops nothing; this is the full 2× canvas)
   - Background: transparent
   - Color depth: 8-bit RGBA
   - ICC profile: embed sRGB
   - No interlacing

#### Export naming
```
{button_base}_{state}.png

Standard buttons:
  btn_primary_lg_normal.png
  btn_primary_lg_hover.png
  btn_primary_lg_pressed.png
  btn_primary_lg_disabled.png
  btn_primary_lg_selected.png

Merchant buttons:
  btn_merchant_pearl_normal.png
  btn_merchant_pearl_hover.png
  … etc.

1× proofs (do not import into Godot; for design review only):
  btn_primary_lg_normal@1x.png
```

> Export the 1× proof by scaling the canvas to 50 % before export, or use your app's "export at scale" option. Never commit `@1x` files to the Godot project.

---

### Step 7 — Import into Godot

For each exported PNG:

1. Drop the file into `res://assets/ui/buttons/` (or `merchants/` subfolder).
2. In the Godot **FileSystem** dock, click the imported texture.
3. In the **Import** panel set:
   - **Compress** → Lossless
   - **Filter** → Linear (for standard buttons) — or Nearest if you want a crisper pixel feel at small sizes
   - **Mipmaps** → Enabled (prevents blurring at scaled-down display sizes)
   - **sRGB** → On
4. Click **Reimport**.
5. Attach to a `TextureButton` node using the slot mapping from Section 13.7.

For nine-patch buttons (variable-width, see Section 9.4): import as `Texture2D`, then wrap in a `NinePatchRect` and set the patch margins to match the button's left/right cap width (approximately 28–30 px at 1×, 56–60 px at 2×).

---

### Step 8 — Register in PlaceholderArtRegistry

After import, add an entry in `autoloads/PlaceholderArtRegistry.gd`:

```gdscript
# Standard button
"ui_button_primary_lg_normal": "res://assets/ui/buttons/btn_primary_lg_normal.png",
"ui_button_primary_lg_hover":  "res://assets/ui/buttons/btn_primary_lg_hover.png",
# … etc.

# Merchant button
"ui_button_merchant_pearl_normal": "res://assets/ui/buttons/merchants/btn_merchant_pearl_normal.png",
```

This allows any script to call `ArtReg.texture_for("ui_button_primary_lg_normal")` and receive the correct texture, or gracefully fall back to a StyleBox placeholder if the PNG has not been exported yet.

---

### Step 9 — Revision Workflow

When an iteration is needed:

1. Open the source `.kra` file.
2. Make changes in the appropriate layer group (e.g. adjust `fill_gradient` to shift the base color).
3. Because states are in the same file, the fill change is visible in every state group immediately.
4. Re-export only the affected states (not the full set unless the shape changed).
5. Overwrite the existing PNGs in `res://assets/ui/buttons/`.
6. Godot auto-detects the file change on next editor focus and reimports.

> If the silhouette shape changes (corner radius, size), all states and all merchant variants must be re-exported. This is rare — treat the shape as locked once it enters a build.

---

### Quick Reference Checklist

```
[ ] Source file created from template in moonseed_art_source/ui/buttons/
[ ] All 9 layer groups present and named correctly
[ ] Normal state painted
[ ] Hover state group complete
[ ] Pressed state group complete (content shifted +2 px)
[ ] Disabled state group complete
[ ] Selected state group complete
[ ] Source file saved (.kra) with all groups intact
[ ] 5 PNGs exported at 2× (408 × 120 px), transparent, sRGB
[ ] PNGs placed in res://assets/ui/buttons/
[ ] Textures imported in Godot (Linear filter, Lossless, Mipmaps on, sRGB on)
[ ] PlaceholderArtRegistry entries added
[ ] TextureButton slots assigned in .tscn
```

---

## 16. Recommended Production Order

> Start narrow, go deep, then go wide.
> The first deliverable is a single complete **vertical slice** — one button, all five states, wired into Godot and confirmed working. Every subsequent button is produced from the same validated template.

---

### Phase 0 — Template Foundation (do this once)

Before painting any button:

1. Build `btn_template_base.kra` per Section 15 Step 2.
2. Verify the canvas is 408 × 120 px, transparent, sRGB.
3. Confirm all 8 layer groups are named and ordered correctly.
4. Export a blank 408 × 120 transparent PNG as `btn_template_blank.png` — use it to verify Godot's import settings (Linear, Lossless, Mipmaps, sRGB) before real art exists.
5. Drop `btn_template_blank.png` into a test `TextureButton` in a scratch scene to confirm the node accepts the texture and the size matches the layout.

**Gate:** Template file exists, Godot import settings proven, TextureButton wired correctly.

---

### Phase 1 — Primary Button Vertical Slice (P0 blocker)

**Goal:** One button, fully complete, in-engine, all interactions working. This is the proof of concept for the entire system.

| Order | Asset | Notes |
|---|---|---|
| 1 | `btn_primary_lg_normal.png` | Full layer stack per Section 12. This is the hardest paint pass — all other normals derive from it. |
| 2 | `btn_primary_lg_hover.png` | Apply Section 13.2 deltas to the normal. Verify the magenta glow reads correctly at game resolution. |
| 3 | `btn_primary_lg_pressed.png` | Apply Section 13.3 deltas. Critical: confirm the +2 px content shift looks like a physical press, not a layout jump. |
| 4 | `btn_primary_lg_disabled.png` | Apply Section 13.4 deltas. Verify 55 % global alpha reads as ghosted-but-legible against the Bazaar panel BG. |
| 5 | `btn_primary_lg_selected.png` | Apply Section 13.5 deltas. Confirm the tight purple ring reads as "toggled on" versus hover's diffuse aura. |

**Milestone check after Phase 1:**

- [ ] All 5 PNGs imported in Godot (408 × 120 px, transparent, sRGB)
- [ ] Wired to a `TextureButton` in a scratch scene
- [ ] All 5 states visible by toggling `disabled` / holding click / calling `grab_focus()`
- [ ] Button reads clearly at intended display size (200 × 56 px)
- [ ] No fringing, no clipped border stroke, no blurry edges
- [ ] PlaceholderArtRegistry entries added for all 5 states
- [ ] Art direction approved — do **not** proceed to Phase 2 until this milestone is signed off

> **Why start here:** Every other button is a recolor of this one. If the painting approach needs to change (gloss feels wrong, border too heavy, shadow too dark), you want to discover that on one button, not after painting twenty.

---

### Phase 2 — Primary Medium + Secondary (P0)

With the template validated, produce the two remaining general-purpose button shapes.

| Order | Asset | Notes |
|---|---|---|
| 6–10 | `btn_primary_md_{state}.png` × 5 | Scale the lg source to the md canvas (280 × 96 px 2×). Adjust gloss ellipse size proportionally — do not simply scale the whole image or gloss will look wrong. Produce all 5 states. |
| 11–15 | `btn_secondary_{state}.png` × 5 | Recolor using Section 6.2 values. This is the first real recolor test of the layer system. |

---

### Phase 3 — Functional Buttons: Confirm, Cancel, Shop (P0)

These appear in the most player-critical moments (buy, dismiss, confirm). Ship normal + hover + pressed first, disabled after.

| Order | Asset | Notes |
|---|---|---|
| 16–20 | `btn_confirm_{state}.png` × 5 | Teal palette per Section 6.3. Good test of a warm-vs-cool palette shift keeping the same layer system. |
| 21–25 | `btn_cancel_{state}.png` × 5 | Section 6.4. Deliberately lower gloss — resist the urge to make it too bright. |
| 26–30 | `btn_shop_merchant_{state}.png` × 5 | Gold palette per Section 6.5. The coin/moondrop icon zone is baked in; confirm text safe area is respected. |

---

### Phase 4 — Navigation: Tab + Icon Circle (P0 / P1)

| Order | Asset | Notes |
|---|---|---|
| 31–35 | `btn_tab_sm_{state}.png` × 5 | Used by all 7 main nav tabs (Table, Garden, Confect, Bazaar, Calendar, Satchel, Settings). Flat bottom edge only. Export at wireframe size: **280 × 96 px** (2×) for secondary nav (fixed 140 × 48 display); **280 × 108 px** (2×) with nine-patch margins 56 px L/R for primary nav (variable width, 52 px tall). Godot scales the PNG to fill each button rect via `AXIS_STRETCH_MODE_STRETCH`. The selected state is P0 — tabs are unreadable without it. |
| 36–40 | `btn_icon_circle_{state}.png` × 5 | Shape only, no baked icon. Purple base matches primary. The selected state (P1) uses a teal/magenta fill shift. |

---

### Phase 5 — Bazaar Merchant Variants (P1)

Produce merchant buttons only after all standard buttons are signed off. Merchant variants reuse the Phase 1 layer structure — this phase is mostly recoloring + ornament painting.

Recommended merchant order (easiest to most complex paint work):

| Order | Merchant | Why this order |
|---|---|---|
| 1st | **Selenic Exchange** | Silver-white fill is the lightest recolor; good warm-up for the variant system |
| 2nd | **Pearl Exchange** | Teal palette is already familiar from Confirm buttons; adds the nacre gloss streak |
| 3rd | **Sweetmaker Stall** | Warm pink is a bigger palette shift; candy gloss requires the extra hotspot layer |
| 4th | **Curio Dealer** | Very dark fill needs care not to lose the border; internal center glow is a new technique |
| 5th | **Dice Carver** | Facet-strip gloss replaces the standard radial — hardest variant; do last when the system is fully understood |

Each merchant: 5 states → 5 PNGs → 25 PNGs total for all merchants.

---

### Phase 6 — Polish Pass (P2)

After all P0/P1 buttons are in-engine and integrated:

- Add `_selected` state to any button that is used as a persistent toggle but was deferred
- Audit thumbnail readability: check every button at 50 % scale in a layout mockup
- Check for consistency: gloss streaks should feel like the same light source across all buttons
- Export `@1x` proof sheet for art direction review (not committed to Godot project)

---

### Production Order Summary

```
Phase 0   Template & Godot validation              1 blank PNG
Phase 1   btn_primary_lg — all 5 states            5 PNGs   ← VERTICAL SLICE MILESTONE
Phase 2   btn_primary_md + btn_secondary            10 PNGs
Phase 3   btn_confirm + btn_cancel + btn_shop       15 PNGs
Phase 4   btn_tab_sm + btn_icon_circle              10 PNGs
          ─────────────────────────────────────────────────
          Standard button set complete              40 PNGs
Phase 5   5 merchant variants × 5 states           25 PNGs
Phase 6   P2 selected states + polish pass          ~6 PNGs
          ─────────────────────────────────────────────────
          Full package                             ~71 PNGs
```

> **Export destination:** `res://assets/ui/buttons/` for standard buttons and `res://assets/ui/buttons/merchants/` for merchant variants. All paths registered in `PlaceholderArtRegistry` under `"ui_button"` and `"ui_button_merchant"` categories respectively.
