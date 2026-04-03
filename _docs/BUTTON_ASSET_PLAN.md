# Moonseed — Button Asset Production Plan

> Use alongside [BUTTON_STYLE_GUIDE.md](BUTTON_STYLE_GUIDE.md).
> Check off each PNG as it is painted, reviewed, and exported to `assets/ui/buttons/`.
> All exports are transparent-background PNG-32 at 2× display resolution.

---

## Button Base Specifications

One row per button shape. All states share these measurements.

| Button Base | Intended Use | Display Size | Export Size | Corner Radius Style | Text Safe Area | Label Treatment |
|---|---|---|---|---|---|---|
| `btn_primary_lg` | Main CTA — Roll, Craft, Submit Quest | 200 × 56 px | 400 × 112 px | Pill — radius ≈ 25 px at display scale | L/R 20 px · T/B 12 px | In-engine (text varies per context) |
| `btn_primary_md` | Dialog confirms, inline CTA, popups | 140 × 48 px | 280 × 96 px | Pill — radius ≈ 22 px | L/R 16 px · T/B 10 px | In-engine |
| `btn_secondary` | Alternate actions — Browse, Sort, Filter, Details | 140 × 44 px | 280 × 88 px | Pill — radius ≈ 20 px | L/R 16 px · T/B 10 px | In-engine |
| `btn_tab_sm` | Tab strip navigation — Shop, Garden, Play, etc. | 96 × 36 px | 192 × 72 px | Top-pill — top corners rounded, bottom flat | L/R 10 px · T/B 8 px | In-engine |
| `btn_icon_circle` | Close, Settings, Favorite, Map toggle, Bag | 48 × 48 px | 96 × 96 px | Circle — border radius 50 % | Icon zone: 50–60 % of diameter (24–29 px at display) | Shape only; icon composited in-engine |
| `btn_shop_merchant` | Buy item, accept trade, purchase from vendor | 160 × 52 px | 320 × 104 px | Pill — radius ≈ 24 px | L 36 px (coin icon) · R 16 px · T/B 12 px | Price text in-engine; coin/moondrop icon baked into left zone |
| `btn_confirm` | Accept confirmation, Yes, Save, Buy (final step) | 140 × 48 px | 280 × 96 px | Pill — radius ≈ 22 px | L/R 16 px · T/B 10 px | In-engine |
| `btn_cancel` | Dismiss dialog, No, Back, Close overlay | 140 × 48 px | 280 × 96 px | Pill — radius ≈ 22 px | L/R 16 px · T/B 10 px | In-engine |

---

## Export Checklist

Filename format: `btn_{base}_{state}.png`
Export destination: `assets/ui/buttons/`

**Priority key:**
- **P0** — Required for first playable UI pass
- **P1** — Required before content-complete milestone
- **P2** — Optional; situational or polish pass

---

### btn_primary_lg — Primary Large

| Done | Filename | State | Priority | Notes |
|---|---|---|---|---|
| [ ] | `btn_primary_lg_normal.png` | normal | P0 | Base purple gradient, full gloss streak |
| [ ] | `btn_primary_lg_hover.png` | hover | P0 | Face brightened +15 %, magenta glow ring |
| [ ] | `btn_primary_lg_pressed.png` | pressed | P0 | Darkened, no gloss, face shifted down 2 px |
| [ ] | `btn_primary_lg_disabled.png` | disabled | P1 | Desaturated 65 %, 55 % alpha, no gloss |
| [ ] | `btn_primary_lg_selected.png` | selected | P2 | Only if used as a persistent toggle; matches hover brightness with stable glow |

---

### btn_primary_md — Primary Medium

| Done | Filename | State | Priority | Notes |
|---|---|---|---|---|
| [ ] | `btn_primary_md_normal.png` | normal | P0 | Same treatment as lg, scaled proportionally |
| [ ] | `btn_primary_md_hover.png` | hover | P0 | |
| [ ] | `btn_primary_md_pressed.png` | pressed | P0 | |
| [ ] | `btn_primary_md_disabled.png` | disabled | P1 | |
| [ ] | `btn_primary_md_selected.png` | selected | P2 | Optional |

---

### btn_secondary — Secondary

| Done | Filename | State | Priority | Notes |
|---|---|---|---|---|
| [ ] | `btn_secondary_normal.png` | normal | P0 | Dark violet base, subdued gloss, mint text |
| [ ] | `btn_secondary_hover.png` | hover | P0 | |
| [ ] | `btn_secondary_pressed.png` | pressed | P0 | |
| [ ] | `btn_secondary_disabled.png` | disabled | P1 | |
| [ ] | `btn_secondary_selected.png` | selected | P2 | Optional |

---

### btn_tab_sm — Small Tab

| Done | Filename | State | Priority | Notes |
|---|---|---|---|---|
| [ ] | `btn_tab_sm_normal.png` | normal | P0 | Flat bottom edge; only top corners pill-rounded |
| [ ] | `btn_tab_sm_hover.png` | hover | P0 | |
| [ ] | `btn_tab_sm_pressed.png` | pressed | P0 | |
| [ ] | `btn_tab_sm_disabled.png` | disabled | P1 | For locked/unavailable tabs |
| [ ] | `btn_tab_sm_selected.png` | selected | P0 | Active/current tab; brighter face, no bottom shadow, seamlessly connects to panel below |

---

### btn_icon_circle — Icon Circle

| Done | Filename | State | Priority | Notes |
|---|---|---|---|---|
| [ ] | `btn_icon_circle_normal.png` | normal | P0 | Shape only — no icon baked in; purple base |
| [ ] | `btn_icon_circle_hover.png` | hover | P0 | |
| [ ] | `btn_icon_circle_pressed.png` | pressed | P0 | |
| [ ] | `btn_icon_circle_disabled.png` | disabled | P1 | |
| [ ] | `btn_icon_circle_selected.png` | selected | P1 | Toggled-on state (e.g. Favorite active); teal or magenta fill shift |

> **Icon variants:** The circle base shape is reused for all icon buttons. Individual icons (`ic_close.png`, `ic_settings.png`, `ic_favorite.png`, etc.) are layered in-engine via a child `TextureRect`. Define icon assets separately in the icon sprite sheet plan.

---

### btn_shop_merchant — Merchant Shop

| Done | Filename | State | Priority | Notes |
|---|---|---|---|---|
| [ ] | `btn_shop_merchant_normal.png` | normal | P0 | Gold gradient face; coin/moondrop icon baked into left ~28 px zone |
| [ ] | `btn_shop_merchant_hover.png` | hover | P0 | |
| [ ] | `btn_shop_merchant_pressed.png` | pressed | P0 | |
| [ ] | `btn_shop_merchant_disabled.png` | disabled | P1 | Desaturated gold; used when player cannot afford item |
| [ ] | `btn_shop_merchant_selected.png` | selected | P2 | Optional; use if an item is already owned/equipped |

---

### btn_confirm — Confirm / Buy

| Done | Filename | State | Priority | Notes |
|---|---|---|---|---|
| [ ] | `btn_confirm_normal.png` | normal | P0 | Teal base (`#099EA9 → #065F66`), mint gloss streak |
| [ ] | `btn_confirm_hover.png` | hover | P0 | |
| [ ] | `btn_confirm_pressed.png` | pressed | P0 | |
| [ ] | `btn_confirm_disabled.png` | disabled | P1 | |
| [ ] | `btn_confirm_selected.png` | selected | P2 | Optional |

---

### btn_cancel — Cancel / Back

| Done | Filename | State | Priority | Notes |
|---|---|---|---|---|
| [ ] | `btn_cancel_normal.png` | normal | P0 | Deep rose base (`#C0185A → #7A0A35`), reduced gloss |
| [ ] | `btn_cancel_hover.png` | hover | P0 | |
| [ ] | `btn_cancel_pressed.png` | pressed | P0 | |
| [ ] | `btn_cancel_disabled.png` | disabled | P1 | Rarely needed; include for completeness |
| [ ] | `btn_cancel_selected.png` | selected | P2 | Not applicable in most contexts |

---

## Summary Count

| Priority | PNG Count | Description |
|---|---|---|
| P0 | 29 | All normal + hover + pressed states; tab selected; icon circle base |
| P1 | 9 | All disabled states; icon circle selected |
| P2 | 6 | Optional selected states for non-tab button types |
| **Total** | **44** | **Full set** |

---

## File Layout in `assets/ui/buttons/`

```
assets/ui/buttons/
├── btn_primary_lg_normal.png
├── btn_primary_lg_hover.png
├── btn_primary_lg_pressed.png
├── btn_primary_lg_disabled.png
├── btn_primary_lg_selected.png
├── btn_primary_md_normal.png
│   … (md states)
├── btn_secondary_normal.png
│   … (secondary states)
├── btn_tab_sm_normal.png
├── btn_tab_sm_hover.png
├── btn_tab_sm_pressed.png
├── btn_tab_sm_disabled.png
├── btn_tab_sm_selected.png        ← P0 — critical for tab nav
├── btn_icon_circle_normal.png
│   … (icon circle states)
├── btn_shop_merchant_normal.png
│   … (shop states)
├── btn_confirm_normal.png
│   … (confirm states)
├── btn_cancel_normal.png
│   … (cancel states)
```

> Register each completed asset in `PlaceholderArtRegistry` (`autoloads/PlaceholderArtRegistry.gd`) under the `"ui_button"` category so `ArtReg` can automatically swap placeholder StyleBoxes for real PNG textures on import.
