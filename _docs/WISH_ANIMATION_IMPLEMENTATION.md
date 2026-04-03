# Moonseed Wish Animation Implementation Design (Godot 4)

Status: design spec for implementation
Target: Moonseed / Ante Up reward animation system
Engine: Godot 4.2+

## 1) Goal

Implement a cinematic pull sequence inspired by modern gacha reveal pacing, while fitting Moonseed's existing architecture:

- SignalBus-only cross-scene communication
- FXBus-driven reusable visual effects
- CanvasLayer overlay flow similar to ContractRewardOverlay
- Existing rarity color map from GameData

The sequence must:

- Build anticipation before item reveal
- Telegraph rarity early via color and motion
- Support single pull and 10-pull
- Hide reward asset warm-up behind flash transitions
- Be skippable without corrupting reward order

## 2) Existing Systems To Reuse

- autoloads/SignalBus.gd: add wish-specific signals
- autoloads/FXBus.gd: reuse burst popups and optional helper methods
- autoloads/GameData.gd: rarity colors and theme-safe values
- autoloads/ContractRewardOverlay.gd: reference timing and queue-handling pattern

Do not connect tab scripts directly to each other. Trigger sequence requests through SignalBus.

## 3) Proposed New Files

Core:

- scenes/WishOverlay.tscn
- scripts/WishOverlay.gd
- scripts/WishSequenceController.gd
- autoloads/WishSystem.gd

Optional helper scenes:

- scenes/wish/WishMeteor.tscn
- scenes/wish/WishRevealCard.tscn
- scenes/wish/WishSummaryGrid.tscn

Shaders:

- shaders/wish_portal_vortex.gdshader
- shaders/wish_starfield_scroll.gdshader
- shaders/wish_atmosphere_break.gdshader

Data:

- assets/wish/reveal_frames/ (sprite sheets or textures)
- assets/audio/wish/ (portal, launch, rarity stingers, reveal pings)

## 4) Data Contract

WishSystem emits one payload per request:

{
	"request_id": String,
	"pull_count": int,
	"rarity_hint": String,
	"results": [
		{
			"item_id": String,
			"item_type": String,
			"display_name": String,
			"rarity": String,
			"icon": Texture2D,
			"is_new": bool,
			"meta": Dictionary
		}
	]
}

Rules:

- pull_count is 1 or 10
- rarity_hint is highest rarity in results
- results order is final reveal order
- payload is deterministic after RNG commit

## 5) Rarity Mapping

Moonseed already uses named rarities. For wish visuals, map to 3 bands:

- tier_low: common, uncommon
- tier_mid: rare, epic
- tier_high: legendary, exotic

Color source should come from GameData.RARITY_COLORS and then be post-processed for trail intensity.

Fallback if missing:

- tier_low: #6BA8FF
- tier_mid: #B574FF
- tier_high: #FFC54D

## 6) State Machine

WishOverlay.gd runs explicit states. Suggested enum:

- IDLE
- PORTAL_OPEN
- STAR_LAUNCH
- METEOR_FLIGHT
- ATMOSPHERE_BREAK
- FLASH_TRANSITION
- REVEAL_LOOP
- RESULT_SUMMARY
- EXIT

Timing targets (single pull baseline):

- PORTAL_OPEN: 0.9s
- STAR_LAUNCH: 0.45s
- METEOR_FLIGHT: 1.8s
- ATMOSPHERE_BREAK: 0.9s
- FLASH_TRANSITION: 0.25s
- REVEAL_LOOP: 1.0s (single) / 2.5-4.5s (10-pull)
- RESULT_SUMMARY: user-controlled

Total: about 6.3s single, 8-9s ten-pull.

## 7) SignalBus Additions

Add signals to autoloads/SignalBus.gd:

- signal wish_requested(pull_count: int)
- signal wish_sequence_started(request_id: String)
- signal wish_rarity_telegraph(tier: String)
- signal wish_item_revealed(index: int, item: Dictionary)
- signal wish_sequence_finished(request_id: String, results: Array)
- signal wish_sequence_skipped(request_id: String)

Flow:

1) UI tab emits wish_requested.
2) WishSystem resolves RNG and emits wish_sequence_started.
3) WishOverlay consumes payload and plays states.
4) Each reveal emits wish_item_revealed.
5) Finish emits wish_sequence_finished.

## 8) Scene Tree Spec

WishOverlay.tscn (CanvasLayer)

- Root (CanvasLayer)
- BlockInput (Control full rect)
- SkyRoot (Control)
- PortalLayer (Control)
- MeteorLayer (Control)
- AtmosphereLayer (Control)
- FlashLayer (ColorRect)
- RevealLayer (Control)
- SummaryLayer (Control)
- AudioRoot (Node with AudioStreamPlayers)

RevealLayer children:

- CardAnchor (CenterContainer)
- CardGlow (ColorRect or TextureRect)
- ItemIcon (TextureRect)
- ItemName (Label)
- ItemRarity (Label)
- NewTag (Label/Texture)

SummaryLayer children:

- GridContainer (10 slots max)
- ContinueButton
- CloseButton

## 9) Animation Details By Phase

### 9.1 Portal Open

- Enable starfield shader and fade from 0 to 1 alpha.
- Vortex shader scales from 0.75 to 1.05 with slight overshoot.
- Spawn center star sprite at low alpha, then charge to full.
- Play rising chime and soft wind loop.

### 9.2 Star Launch

- Convert center star to moving meteor node.
- Tween position toward camera axis and out into flight path.
- Trail color uses highest rarity tier of the pull.
- Emit wish_rarity_telegraph once trail hue is visible.

### 9.3 Meteor Flight

- Camera proxy pans with easing, avoid sudden jerk.
- Spawn companion meteors to match pull count.
- Only primary meteor carries rarity hue; secondary meteors are neutral.

### 9.4 Atmosphere Break

- Blend sky shader from starfield to atmosphere palette.
- Spawn ring shockwave and fragment streaks.
- Add 1-2 frame white edge flash before full transition.

### 9.5 Flash Transition

- Full-screen white ColorRect alpha to 1, hold 0.04s, fade out.
- During hold, preload icon textures for reveal loop.

### 9.6 Reveal Loop

For each result item:

1) silhouette in (0.12s)
2) card turn/tilt (0.18s)
3) rarity burst (duration by tier)
4) icon + name settle
5) emit wish_item_revealed

Duration per tier:

- tier_low: 0.28s
- tier_mid: 0.55s
- tier_high: 1.05s

For 10-pull, reserve stronger pauses for high-tier entries.

### 9.7 Summary Screen

- Build 10-slot grid with rarity borders.
- Allow quick actions: Wish Again, Close.
- Keep full payload cached for tooltips or inspect panel.

## 10) Skip and Input Behavior

Input policy:

- First tap during cinematic: fast-forward current state safely.
- Second tap: jump to summary screen.
- In reveal loop, skip still marks all unrevealed items as revealed events.

Technical requirement:

- No item grant logic inside animation callbacks.
- Rewards must be committed before animation starts.

## 11) Performance and Loading

- Prewarm textures using ResourceLoader.load_threaded_request on wish start.
- Keep meteor particles pooled (5 for single, 14 for ten-pull headroom).
- Disable expensive shader passes on low-quality setting.
- Use one Tween per phase coordinator; avoid one Tween per property where possible.

Budget target:

- 60 FPS on mid-tier desktop
- No frame over 33ms during flash and reveal burst

## 12) Audio Spec

Suggested buses:

- SFX_WISH_PORTAL
- SFX_WISH_FLIGHT
- SFX_WISH_REVEAL
- SFX_WISH_STINGER

Cue points:

- Portal charge start
- Launch impulse
- Rarity telegraph hit
- Atmosphere break crack
- Per-item reveal ping
- High-tier stinger (duck background by -4 dB for 0.6s)

## 13) WishSystem Responsibilities

WishSystem.gd should own:

- RNG, pity, guarantee, banner rules
- Conversion from rarity roll to concrete item
- Result ordering policy for reveal pacing
- Persistence events (currency spend, ownership update)

WishOverlay.gd should own:

- Playback only
- Input handling for skip/fast-forward
- Visual event emissions

## 14) Pseudocode

WishSequenceController.gd:

func play_wish(payload: Dictionary) -> void:
		SignalBus.wish_sequence_started.emit(payload.request_id)
		await _state_portal_open(payload)
		await _state_star_launch(payload)
		await _state_meteor_flight(payload)
		await _state_atmosphere_break(payload)
		await _state_flash_transition(payload)
		await _state_reveal_loop(payload)
		await _state_result_summary(payload)
		SignalBus.wish_sequence_finished.emit(payload.request_id, payload.results)

## 15) Implementation Milestones

Milestone A: Wiring

- Add SignalBus wish signals
- Create WishSystem autoload with mock payload generator
- Add overlay spawn entry point in Main scene helper

Milestone B: Cinematic Core

- Implement portal, launch, flight, atmosphere, flash
- Add rarity telegraph and companion meteors

Milestone C: Reveal + Summary

- Sequential card reveal loop
- 1-pull and 10-pull summary grid
- Skip and fast-forward rules

Milestone D: Polish

- Audio mix pass
- Performance pass
- Theme/rarity color tuning

## 16) Test Matrix

Functional:

- single pull low/mid/high
- ten-pull with 0, 1, and 2+ high-tier items
- skip at each state
- alt-tab and resume mid-sequence

Integrity:

- no duplicate reward grants
- no missing wish_item_revealed emissions after skip
- summary order matches committed payload

Visual:

- rarity color is readable on all themes
- no shader compile errors in release export
- no hitch over 33ms on reveal of high-tier item

## 17) Moonseed Integration Notes

- Keep script style consistent with existing overlay coding in autoloads/ContractRewardOverlay.gd.
- Route cross-system events through SignalBus only.
- Reuse GameData scaling helpers for all label font sizes.
- If assigning shader source via code, use triple-quoted strings to avoid parser errors with concatenation.

## 18) Optional Extensions

- Pity counter UI hint before pull
- Duplicate conversion animation (into seed currency)
- Character-style reveal variant for special entities
- Weekly analytics: skip rate, average watch time, high-tier excitement moments
