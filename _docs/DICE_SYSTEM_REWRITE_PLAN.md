# Moonseed Dice System Rewrite — Implementation Plan

## Gap Analysis: Current vs Proposed

| Component | Current State | Proposed Design | Gap |
|-----------|--------------|-----------------|-----|
| **Event Queue** | None — sequential awaits in PlayTab | `RollResolutionQueue` with phases | ❌ Missing |
| **Roll Packet** | Fragmented across GameData dicts | Single mutable dictionary | ❌ Missing |
| **Score Engine** | Inside `GameData.calculate_score()` | Separate `score_engine.gd` | ❌ Missing |
| **Reward FX** | Scattered in PlayTab + FXBus | Centralized `reward_fx_controller.gd` | ❌ Missing |
| **Relic Phase** | Curio canisters = passive multipliers | Active relic trigger phase | ❌ Missing |
| **Die Effects** | Explosive dice exist (`DiceBase_Explosive`) | Personality effects phase | ⚠️ Partial |
| **Merge Phase** | `FXBus.moondrop_merge_cluster()` exists | Structured merge with clusters | ⚠️ Partial |
| **Multiplier Phase** | Applied in `calculate_score()` | Applied after merge, visual display | ❌ Wrong order |
| **Crystallization** | `FXBus.moondrop_cluster_to_pearl()` exists | Structured crystallization | ⚠️ Partial |
| **Signals** | Basic dice/score signals | Full pipeline signals | ❌ Incomplete |

## Key Problems in Current Code

1. **PlayTab._roll_hand()** does everything — spawning, rolling, scoring, FX, UI updates
2. **Score calculation** happens instantly, then visuals decorate it afterward
3. **Multipliers** are applied before the player sees drops merge
4. **No phased resolution** — everything is flat async/await chains
5. **No structured data packet** — dice results live in separate dictionaries

## Implementation Plan

### Pass 1: Core Pipeline (Minimal Ritual)
**Goal:** Dice settle → Moondrops spawn → merge → crystallize → Moonpearls burst → UI tick

#### 1.1 Create `RollResolutionQueue`
- **File:** `scripts/dice/roll_resolution_queue.gd`
- Phase-based event queue with `begin(context)`, `_run_steps()`
- Emits `phase_started` / `phase_finished` / `queue_finished`
- Steps: spawn_moondrops → merge → crystallize → final_burst

#### 1.2 Create Roll Packet Data Model
```gdscript
var roll_packet: Dictionary = {
    "roll_id": "",
    "dice": [],
    "clusters": [],
    "relic_deltas": [],
    "die_effect_deltas": [],
    "strength_sources": [],
    "flat_total": 0,
    "multiplied_total": 0,
    "moonpearls_gained": 0
}
```

#### 1.3 Create `ScoreEngine`
- **File:** `scripts/dice/score_engine.gd`
- `build_roll_packet(entries)` — creates packet from dice results
- `compute_base_moondrops(packet)` — raw moondrop amounts per die
- `apply_multipliers(packet)` — strength/sources applied after merge
- `compute_moonpearl_yield(packet)` — final conversion

#### 1.4 Create `RewardFXController`
- **File:** `scripts/dice/reward_fx_controller.gd`
- `spawn_moondrops(packet)` — creates droplet visuals per die
- `animate_merge(clusters)` — merge animation
- `crystallize_pearls(clusters)` — pearl formation
- `final_burst(summary)` — UI tick + effects

#### 1.5 Update SignalBus
Add new signals:
```gdscript
signal roll_requested(task_ids: Array[int])
signal die_settled(roll_id: String, die_id: String, task_id: int, face_value: int, sides: int, is_max: bool)
signal moondrop_spawn_requested(die_id: String, amount: int, global_position: Vector2, tags: Array[String])
signal merge_phase_started(clusters: Array)
signal multiplier_applied(source_id: String, before_value: float, after_value: float)
signal moonpearl_created(cluster_id: String, pearl_value: int, global_position: Vector2)
signal reward_resolution_complete(summary: Dictionary)
signal score_preview_updated(moondrops: int, strength: float, total: int, moonpearls: int)
```

#### 1.6 Refactor PlayTab
- `_roll_hand()` creates roll packet, starts queue
- Delegate FX to `RewardFXController`
- Listen to `score_preview_updated` for UI updates

#### 1.7 Refactor DiceTableArea
- On die settle, emit `die_settled` with structured data
- Keep physics unchanged (it works)

### Pass 2: Relic & Multiplier Layer
**Goal:** Add relic trigger phase, multiplier display, structured scoring

#### 2.1 Relic Trigger Phase
- New step in `RollResolutionQueue`
- Active relics inspect roll packet, emit `relic_triggered(relic_id, payload)`
- Return data deltas (bonus drops, multipliers, etc.)

#### 2.2 Multiplier Phase
- Apply **after** merge (not before)
- Show presentation: "MOONDROPS × STRENGTH = TOTAL → MOONPEARLS"
- Emit `multiplier_applied` per source

#### 2.3 Curio Canister Integration
- Map existing curio canisters to relic system
- Curio canisters provide strength multipliers

### Pass 3: Die Personality & Polish
**Goal:** Die effects, explosion branch, Nou reactions

#### 3.1 Die Effect Phase
- Die traits (explosive, lunar, cracked, polished)
- Emit `die_effect_triggered(effect_id, payload)`

#### 3.2 Explosion Branch
- Max roll → extra moondrop burst
- Visual: bigger slam, more droplets

#### 3.3 Nou Reactions
- Big rolls → Nou cheers
- Integrate with `SignalBus.nou_say`

## Files to Create

1. `scripts/dice/roll_resolution_queue.gd` — event queue
2. `scripts/dice/score_engine.gd` — scoring logic
3. `scripts/dice/reward_fx_controller.gd` — visual resolution

## Files to Modify

1. `autoloads/SignalBus.gd` — add new signals
2. `scripts/PlayTab.gd` — delegate to queue/controller
3. `scripts/DiceTableArea.gd` — emit structured settle data
4. `autoloads/FXBus.gd` — integrate with new flow

## Files Unchanged

- `scripts/DiceRoller.gd` — utility stays as-is
- `autoloads/GameData.gd` — keep data storage, delegate scoring to ScoreEngine

## Signal Flow (Proposed)

```
PlayTab._roll_hand()
  → SignalBus.roll_requested(task_ids)
  → DiceTableArea.throw_task_dice()
  → [dice settle]
  → SignalBus.die_settled(roll_id, die_id, task_id, face, sides, is_max)
  → RollResolutionQueue.begin(context)
    → Phase 1: spawn_moondrops (RewardFXController)
    → Phase 2: relics (Pass 2)
    → Phase 3: dice_effects (Pass 3)
    → Phase 4: merge (RewardFXController)
    → Phase 5: multipliers (ScoreEngine + display)
    → Phase 6: crystallize (RewardFXController)
    → Phase 7: final_burst (RewardFXController)
  → SignalBus.reward_resolution_complete(summary)
  → SignalBus.score_preview_updated(moondrops, strength, total, moonpearls)
  → PlayTab updates UI
```

## Timing Budget

```
0.00  settle
0.05  slam flash
0.10  Moondrops spawn
0.22  relic triggers (Pass 2)
0.35  dice effects (Pass 3)
0.50  merge begins
0.75  multiplier pulse
1.00  crystallization
1.20  pearls launch
1.35  final count burst
1.50  control returns
```

Normal rolls: ~1.5s. Explosions: +0.25–0.45s.

## Non-Negotiable (Minimal Ritual)

If anything is cut, **do not cut**:
1. Local Moondrop spawn (per die)
2. Visible merge (drops gathering)
3. Visible crystallization (drops → pearl)
4. Final pearl burst to UI

## Open Questions

1. **Relic scope:** Are relics implemented, or entirely new? Curio canisters act as passive multipliers — should they map to relics?
2. **Die personality:** Just basic d6/d8/d10/d12/d20, or do special die types already exist? `DiceBase_Explosive.tscn` suggests explosive dice exist.
3. **Merge behavior:** Physically merge (touch and combine) or visually converge to centroid? FXBus currently converges.
4. **Score persistence:** Replace `GameData.calculate_score()` entirely, or wrap it?
5. **Backward compatibility:** Can we break the save format?