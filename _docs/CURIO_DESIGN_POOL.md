# Moonseed Curio Design Pool
## Generated from Web Inspiration via Firecrawl MCP

**Sources crawled:**
- Balatro Wiki (150 Jokers — full mechanical effects)
- Slay the Spire Wiki (relic mechanics — 100+ relics)
- Dicey Dungeons Wiki (518 equipment pieces — dice manipulation patterns)
- Luck Be a Landlord Wiki (152 symbols — previously crawled)
- Inscryption Wiki (sigil mechanics — previously crawled)

---

## Step 1: Mechanical Pattern Extraction Table

| Source Pattern | Moonseed Translation | Family Fit | Notes |
|---|---|---|---|
| Conditional multiplier (adjacent X gives 2x) | Conditional value boost on specific die values | Roll Shaping / Trigger | Clean dice mapping |
| Self-destruction after N uses | Consumable curio with powerful one-time effect | Rule Benders | High-impact, limited use |
| Periodic payout (every N spins) | Trigger every N rolls | Trigger Effects | Clean periodicity |
| Permanent scaling (+1 per event) | Stacking bonus within session | Moondrop Scaling | Needs session-scoped tracking |
| Conditional destruction + payoff | Destroy low die for bonus | Flow Modifiers | Dice-removal mechanic |
| Random value generation | Random value shift on roll | Roll Shaping | Adds variance |
| Rarity modification | Modify roll quality distribution | Roll Shaping | Map to die value ranges |
| Duplicate detection bonus | Reward for matching values | Pattern Recognition | Natural fit for multi-die |
| Unique value bonus | Reward for all different values | Pattern Recognition | Clean inverse of duplicates |
| Threshold reward (if at least N of X) | Conditional trigger on count | Trigger Effects | Counting mechanic |
| Transformation (grow into better) | Die value upgrade | Roll Shaping | Value improvement |
| Position/slot bonuses | Order-dependent effects | Flow Modifiers | Die position in sequence |
| First trigger bonus | One-time bonus per roll | Trigger Effects | First-occurrence tracking |
| Chain/synergy (X + Y together) | Multi-die pattern combo | Pattern Recognition | Cross-die interaction |
| Reroll on condition | Conditional reroll gain | Reroll Control | Direct reroll economy |
| Low-roll compensation | Bonus when rolling low | Reroll Control / Trigger | Softens bad luck |
| High-roll jackpot | Exponential reward on high | Trigger Effects / Moondrop | Exciting moments |
| Even/odd classification | Parity-based effects | Pattern Recognition | Simple, readable |
| Sequence detection | Consecutive value reward | Pattern Recognition | Harder to implement, rare |
| Value cap/range restriction | Constrain die outcomes | Roll Shaping | Strong but simple |
| Ignore lowest/highest | Die exclusion from scoring | Flow Modifiers | Scoring manipulation |
| Extra die addition | Add die to roll pool | Flow Modifiers | Pool size change |
| Die locking | Prevent reroll of specific die | Reroll Control | Strategic lock |
| End-of-roll multiplier | Multiplier applied at resolution | Moondrop Scaling | Clean timing |
| Flat bonus per die | Per-die Moondrop gain | Moondrop Scaling | Simple scaling |
| Countdown/periodic effect | Trigger every N turns | Trigger | From Slay the Spire relics |
| Dice splitting | Break one die into multiple smaller | Flow | From Dicey Dungeons |
| Dice combining | Merge dice values | Roll Shaping | From Dicey Dungeons |
| Value inversion (flip upside down) | 7 - value transformation | Rule Benders | From Dicey Dungeons |
| Freeze/lock dice | Prevent dice manipulation | Reroll Control | From Dicey Dungeons |
| Conditional on resource state | Trigger based on rerolls remaining | Trigger | From Balatro economy jokers |
| Copy/duplicate effect | Replicate a die result | Rule Benders | From Balatro Blueprint/DNA |
| Threshold accumulation | Gain bonus at cumulative milestones | Scaling | From Balatro scaling jokers |
| Negative tradeoff (gain + lose) | Risk/reward mechanic | Rule Benders | From Balatro Ice Cream/Popcorn |
| Deck composition bonus | Bonus based on dice pool composition | Scaling | From Balatro Steel Joker |

---

## Step 2: Moonseed Fit Filter

**Kept patterns** (clean dice/reroll/Moondrop mapping):
- Value shifting (+1/-1, min floors)
- Reroll control (gain, refund, conditional)
- Duplicate reward / unique value reward
- Even/odd effects
- Threshold/counting triggers
- First-occurrence triggers
- Die exclusion (ignore lowest/highest)
- Extra die / die removal
- Value multiplication
- Permanent scaling within session
- Periodic triggers
- Random value generation
- Sequence/pattern detection
- End-of-roll multipliers
- Rule bending (value substitution, copy)
- Dice splitting/combining
- Freeze/lock mechanics
- Conditional on resource state
- Negative tradeoffs

**Rejected patterns** (no clean dice mapping):
- Combat/damage effects
- Health/life systems
- Deck manipulation
- Map/progression effects
- Inventory loadout swaps
- Shop/economy effects
- Plant/garden interactions
- Pomodoro timing

---

## Step 3: Taxonomy Mapping

| Family | Core Mechanic | Balatro Analogue | StS Analogue | DD Analogue |
|---|---|---|---|---|
| ROLL_SHAPING | Alter die values or constraints | Suit/rank bonuses, Fibonacci | Oddly Smooth Stone, Vajra | Bump, Nudge, Doppeldice |
| REROLL_CONTROL | Manage reroll economy | Chaos the Clown, Burglar | Lantern, Happy Flower | Combat Roll, Magic Reroll |
| TRIGGER | Conditional on roll state | Jolly Joker, Mystic Summit | Akabeko, Pen Nib | Big Stick, Dust Cloud |
| PATTERN | Reward dice combinations | Spare Trousers, The Duo | Nunchaku, Ink Bottle | Benchmark, Calculator |
| FLOW | Alter turn structure | Dusk, Acrobat | Pocketwatch, Unceasing Top | Action!, Bear Charge |
| SCALING | Grow within session | Green Joker, Ride the Bus | Girya, Face of Cleric | Transformer, Electromagnet |
| RULE_BENDER | Break normal rules | Four Fingers, Oops! All 6s | Strange Spoon, Prismatic Shard | Skeleton Key, Doppeltwice |

---

## Step 4: Final Curio Set (35 Curios)

### Family 1: ROLL_SHAPING (5 Curios)

### Family 2: REROLL_CONTROL (6 Curios)

### Family 3: TRIGGER (7 Curios)

### Family 4: PATTERN (6 Curios)

### Family 5: FLOW (4 Curios)

### Family 6: SCALING (5 Curios)

### Family 7: RULE_BENDER (4 Curios)

**Total: 35 Curios**

---

## Step 5: Full Curio Definitions

```json
[
  {
    "name": "Gentle Polishing Stone",
    "family": "ROLL_SHAPING",
    "rarity": "common",
    "effect": "Each die rolls minimum 2 instead of 1.",
    "trigger_type": "passive",
    "design_role": "Floor raiser. Softens worst-case rolls without breaking ceiling.",
    "source_pattern": "value floor / minimum guarantee",
    "inspiration": "Slay the Spire (The Boot) / Dicey Dungeons (min slot)"
  },
  {
    "name": "Lunar Drift Charm",
    "family": "ROLL_SHAPING",
    "rarity": "common",
    "effect": "+1 to one random die each roll.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Small consistent boost. Encourages rolling more dice.",
    "source_pattern": "random value shift",
    "inspiration": "Balatro (Misprint) / Dicey Dungeons (Bump)"
  },
  {
    "name": "Cratered Moonstone",
    "family": "ROLL_SHAPING",
    "rarity": "uncommon",
    "effect": "Set one die to 4 after rolling. (Once per roll.)",
    "trigger_type": "on_roll_resolved",
    "design_role": "Precision tool. Enables specific pattern builds.",
    "source_pattern": "value setting / manipulation",
    "inspiration": "Dicey Dungeons (Berlin Key) / Balatro (raised Fist inverse)"
  },
  {
    "name": "Stillwater Basin",
    "family": "ROLL_SHAPING",
    "rarity": "uncommon",
    "effect": "All dice that roll 1 become 2.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Eliminates dead rolls. Pairs with even-pattern Curios.",
    "source_pattern": "value transformation (1→2)",
    "inspiration": "Dicey Dungeons (Bumpblade) / Balatro (Even Steven)"
  },
  {
    "name": "Tidecaller Glyph",
    "family": "ROLL_SHAPING",
    "rarity": "rare",
    "effect": "Once per roll, change a die's value by ±1.",
    "trigger_type": "on_roll_resolved",
    "design_role": "High-skill manipulation. Enables pattern completion.",
    "source_pattern": "value adjustment",
    "inspiration": "Dicey Dungeons (Nudge/Bump combined) / Balatro (Oportune)"
  },

  {
    "name": "Basin of Second Chances",
    "family": "REROLL_CONTROL",
    "rarity": "uncommon",
    "effect": "+1 reroll if all dice show different values.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Encourages diverse rolls and reduces dead turns.",
    "source_pattern": "conditional reroll bonus",
    "inspiration": "Balatro (delayed gratification pattern) / StS (Happy Flower)"
  },
  {
    "name": "Echo Chamber",
    "family": "REROLL_CONTROL",
    "rarity": "common",
    "effect": "Gain +1 reroll at the start of each roll phase.",
    "trigger_type": "on_roll_start",
    "design_role": "Baseline reroll economy. Foundational Curio.",
    "source_pattern": "flat reroll gain",
    "inspiration": "Balatro (Chaos the Clown) / StS (Lantern)"
  },
  {
    "name": "Hollow Die Frame",
    "family": "REROLL_CONTROL",
    "rarity": "uncommon",
    "effect": "Lock one die after rolling. Locked dice can't be rerolled but give +2 Moondrops.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Strategic lock. Trade flexibility for guaranteed value.",
    "source_pattern": "die locking with payoff",
    "inspiration": "Dicey Dungeons (Bear Trap/Glue) / Balatro (raised Fist)"
  },
  {
    "name": "Veil of Quiet Echoes",
    "family": "REROLL_CONTROL",
    "rarity": "rare",
    "effect": "Rerolls that don't improve any die are refunded.",
    "trigger_type": "on_reroll_resolved",
    "design_role": "Risk-free rerolling. Rewards careful reroll decisions.",
    "source_pattern": "conditional reroll refund",
    "inspiration": "Balatro (Delayed Gratification) / Dicey Dungeons (Lucky Roll)"
  },
  {
    "name": "Scattered Star Chart",
    "family": "REROLL_CONTROL",
    "rarity": "common",
    "effect": "+1 reroll if you rolled at least one 6.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Rewards high-rolling. Shifts from anti-duplicate to pro-high-roll.",
    "source_pattern": "conditional reroll (high value present)",
    "inspiration": "Balatro (Scholar: Ace bonus) / Dicey Dungeons (Big Stick on 6)"
  },
  {
    "name": "Fading Ember Die",
    "family": "REROLL_CONTROL",
    "rarity": "rare",
    "effect": "+1 reroll, but lose 1 reroll permanently each round.",
    "trigger_type": "on_roll_start",
    "design_role": "Front-loaded power with long-term cost. Run-defining tension.",
    "source_pattern": "diminishing resource",
    "inspiration": "Balatro (Ice Cream) / Balatro (Popcorn)"
  },

  {
    "name": "Cracked Moon Fragment",
    "family": "TRIGGER",
    "rarity": "common",
    "effect": "If any die shows 6, gain +3 bonus Moondrops.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Jackpot incentive. Makes 6s exciting beyond their base value.",
    "source_pattern": "high-value trigger",
    "inspiration": "Balatro (Scholar) / Dicey Dungeons (Big Stick on 6)"
  },
  {
    "name": "Pale Reflection Pool",
    "family": "TRIGGER",
    "rarity": "uncommon",
    "effect": "If all dice show the same value, gain 2x Moondrops this roll.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Jackpot moment. Extremely rare but thrilling.",
    "source_pattern": "all-matching trigger",
    "inspiration": "Balatro (Four of a Kind bonus) / Dicey Dungeons (Benchmark doubles)"
  },
  {
    "name": "Whispering Quartz",
    "family": "TRIGGER",
    "rarity": "common",
    "effect": "If the total roll is 7 or less, gain +1 reroll.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Consolation prize. Low rolls aren't wasted.",
    "source_pattern": "low-roll compensation",
    "inspiration": "Balatro (Mystic Summit) / Slay the Spire (Orichalcum)"
  },
  {
    "name": "Glacial Resonance",
    "family": "TRIGGER",
    "rarity": "uncommon",
    "effect": "If you roll exactly 3 dice, gain +4 Moondrops.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Dice count incentive. Shapes pool-building decisions.",
    "source_pattern": "count-specific trigger",
    "inspiration": "Balatro (Half Joker: 3 or fewer) / Dicey Dungeons (Square Joker: exactly 4)"
  },
  {
    "name": "Somber Bell",
    "family": "TRIGGER",
    "rarity": "rare",
    "effect": "Every 4th roll, gain 3x Moondrops.",
    "trigger_type": "periodic",
    "design_role": "Long-term rhythm reward. Predictable power spike.",
    "source_pattern": "periodic trigger",
    "inspiration": "Balatro (Loyalty Card) / Slay the Spire (Pen Nib / Happy Flower)"
  },
  {
    "name": "Ashen Sigil",
    "family": "TRIGGER",
    "rarity": "uncommon",
    "effect": "If no die shows a 6, gain +2 Moondrops.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Inverted jackpot. Rewards consistency over luck.",
    "source_pattern": "absence trigger",
    "inspiration": "Balatro (Even Steven: even cards) / Dicey Dungeons (conditional on non-6)"
  },
  {
    "name": "Cavern Echo",
    "family": "TRIGGER",
    "rarity": "common",
    "effect": "First roll of each round: +2 Moondrops.",
    "trigger_type": "on_first_roll",
    "design_role": "Opening advantage. Rewards getting it right early.",
    "source_pattern": "first-occurrence bonus",
    "inspiration": "Slay the Spire (Akabeko) / Balatro (first hand bonuses)"
  },

  {
    "name": "Twin Hollows",
    "family": "PATTERN",
    "rarity": "common",
    "effect": "+3 Moondrops if any two dice match.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Basic pair reward. Accessible pattern Curio.",
    "source_pattern": "pair detection",
    "inspiration": "Balatro (Jolly Joker) / Balatro (Sly Joker)"
  },
  {
    "name": "Trine Formation",
    "family": "PATTERN",
    "rarity": "uncommon",
    "effect": "+6 Moondrops if any three dice match.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Triple reward. Requires 3+ dice pool.",
    "source_pattern": "triple detection",
    "inspiration": "Balatro (Zany Joker) / Balatro (Wily Joker)"
  },
  {
    "name": "Divergence Sigil",
    "family": "PATTERN",
    "rarity": "uncommon",
    "effect": "+4 Moondrops if all dice show different values.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Anti-pair incentive. Complements pair-focused builds.",
    "source_pattern": "unique value detection",
    "inspiration": "Balatro (opposite of pair jokers) / Dicey Dungeons (diversity check)"
  },
  {
    "name": "Waxing Sequence",
    "family": "PATTERN",
    "rarity": "rare",
    "effect": "+5 Moondrops per consecutive die in ascending order (e.g. 2-3-4 = 3×5).",
    "trigger_type": "on_roll_resolved",
    "design_role": "High-skill pattern. Rewards ordering dice carefully.",
    "source_pattern": "sequence detection",
    "inspiration": "Balatro (The Order: Straight) / Dicey Dungeons (sequence equipment)"
  },
  {
    "name": "Even Moonstone",
    "family": "PATTERN",
    "rarity": "common",
    "effect": "+1 Moondrop for each even-value die.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Parity reward. Simple, stacks with multiple dice.",
    "source_pattern": "even/odd classification",
    "inspiration": "Balatro (Even Steven) / Balatro (Odd Todd)"
  },
  {
    "name": "Paired Shadows",
    "family": "PATTERN",
    "rarity": "rare",
    "effect": "+8 Moondrops if you roll exactly two pairs.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Advanced pattern. Requires 4+ dice and specific values.",
    "source_pattern": "two-pair detection",
    "inspiration": "Balatro (Mad Joker: Two Pair) / Balatro (Clever Joker)"
  },

  {
    "name": "Lunar Spindle",
    "family": "FLOW",
    "rarity": "uncommon",
    "effect": "+1 die to your pool for this roll.",
    "trigger_type": "on_roll_start",
    "design_role": "Pool expansion. More dice = more patterns + more Moondrops.",
    "source_pattern": "extra die addition",
    "inspiration": "Balatro (Juggler: +1 hand size) / Dicey Dungeons (Hall of Mirrors)"
  },
  {
    "name": "Waning Crescent",
    "family": "FLOW",
    "rarity": "rare",
    "effect": "Ignore your lowest die when scoring. It still counts for patterns.",
    "trigger_type": "on_scoring",
    "design_role": "Selective scoring. Removes bad rolls from Moondrop calc.",
    "source_pattern": "die exclusion from scoring",
    "inspiration": "Balatro (Raised Fist inverse) / Dicey Dungeons (ignore lowest)"
  },
  {
    "name": "Quiet Pulsation",
    "family": "FLOW",
    "rarity": "uncommon",
    "effect": "If you use all rerolls, gain +3 Moondrops.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Exhaustion reward. Encourages spending all resources.",
    "source_pattern": "resource exhaustion bonus",
    "inspiration": "Balatro (Mystic Summit: 0 discards) / Balatro (Banner: remaining discards)"
  },
  {
    "name": "Orbital Residue",
    "family": "FLOW",
    "rarity": "common",
    "effect": "After rerolling, each die that didn't change gives +1 Moondrop.",
    "trigger_type": "on_reroll_resolved",
    "design_role": "Reroll insurance. Kept dice still contribute.",
    "source_pattern": "unchanged die bonus",
    "inspiration": "Balatro (Banner: remaining discards) / Dicey Dungeons (kept dice)"
  },

  {
    "name": "Selenite Lattice",
    "family": "SCALING",
    "rarity": "uncommon",
    "effect": "+1 Moondrop per roll made this round. (Resets each round.)",
    "trigger_type": "on_roll_resolved",
    "design_role": "Snowball within round. Rewards multiple rolls.",
    "source_pattern": "per-roll scaling (within round)",
    "inspiration": "Balatro (Green Joker: +1 per hand) / Balatro (Supernova)"
  },
  {
    "name": "Accretion Disk",
    "family": "SCALING",
    "rarity": "rare",
    "effect": "+1 Moondrop per pair matched this run. (Permanent.)",
    "trigger_type": "on_roll_resolved",
    "design_role": "Run-long investment. Rewards pattern-focused play.",
    "source_pattern": "permanent scaling on event",
    "inspiration": "Balatro (Ride the Bus) / Balatro (Obelisk)"
  },
  {
    "name": "Stalactite Growth",
    "family": "SCALING",
    "rarity": "uncommon",
    "effect": "Each time you roll a 1, this Curio gains +1 Moondrop bonus. (Resets each round.)",
    "trigger_type": "on_roll_resolved",
    "design_role": "Turns bad rolls into investment. Emotional rescue.",
    "source_pattern": "stacking on low value",
    "inspiration": "Balatro (Green Joker: per hand) / Dicey Dungeons (Mechanical Arm)"
  },
  {
    "name": "Polished Moon Fragment",
    "family": "SCALING",
    "rarity": "rare",
    "effect": "+1 Moondrop for each die kept (not rerolled) this round.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Rewards satisfaction. 'Keep good rolls' incentive.",
    "source_pattern": "kept-die scaling",
    "inspiration": "Balatro (Banner: remaining discards) / Dicey Dungeons (Thick Skin)"
  },
  {
    "name": "Fossilized Tide",
    "family": "SCALING",
    "rarity": "uncommon",
    "effect": "Gains +1 Moondrop bonus every 3 rolls. (Permanent within run.)",
    "trigger_type": "periodic",
    "design_role": "Steady long-term growth. Reliable power curve.",
    "source_pattern": "periodic permanent scaling",
    "inspiration": "Balatro (Constellation: per planet) / Slay the Spire (Girya: 3 uses)"
  },

  {
    "name": "Mirror Shard",
    "family": "RULE_BENDER",
    "rarity": "rare",
    "effect": "Once per roll, a die can count as two different values for pattern evaluation.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Pattern enabler. One die serves double duty.",
    "source_pattern": "dual-value counting",
    "inspiration": "Balatro (Four Fingers) / Balatro (Smeared Joker) / Dicey Dungeons (Splash)"
  },
  {
    "name": "Umbral Transposition",
    "family": "RULE_BENDER",
    "rarity": "rare",
    "effect": "Once per round, swap the values of two dice.",
    "trigger_type": "on_roll_resolved",
    "design_role": "Board manipulation. Enables pattern completion.",
    "source_pattern": "value swapping",
    "inspiration": "Dicey Dungeons (Spatula/flip) / Balatro (position-dependent effects)"
  },
  {
    "name": "Gravitational Anomaly",
    "family": "RULE_BENDER",
    "rarity": "uncommon",
    "effect": "Straights can have gaps of 1 (e.g. 2-4-6 counts as straight).",
    "trigger_type": "passive",
    "design_role": "Rule relaxation. Makes sequences achievable.",
    "source_pattern": "rule bending for patterns",
    "inspiration": "Balatro (Shortcut) / Balatro (Four Fingers)"
  },
  {
    "name": "Phase-Shifted Prism",
    "family": "RULE_BENDER",
    "rarity": "rare",
    "effect": "All listed probabilities are doubled. (If Moonseed has chance-based effects.)",
    "trigger_type": "passive",
    "design_role": "Meta-amplifier. Makes lucky effects reliable.",
    "source_pattern": "probability manipulation",
    "inspiration": "Balatro (Oops! All 6s) / Balatro (Lucky Cat)"
  }
]
```

---

## Step 6: Distribution Verification

```
ROLL_SHAPING        5  ✅ (target 4–6)
REROLL_CONTROL      6  ✅ (target 5–6)
TRIGGER             7  ✅ (target 6–8)
PATTERN             6  ✅ (target 5–6)
FLOW                4  ✅ (target 3–5)
SCALING             5  ✅ (target 4–5)
RULE_BENDER         4  ✅ (target 3–4)
────────────────────
TOTAL              37  ✅ (target 30–45)
```

---

## Step 7: Coverage Check

| Family | Count | Status | Gaps |
|---|---|---|---|
| ROLL_SHAPING | 5 | ✅ | Covers floor, random boost, set value, transform, adjust |
| REROLL_CONTROL | 6 | ✅ | Covers gain, conditional gain, lock, refund, diminishing |
| TRIGGER | 7 | ✅ | Covers high-value, all-match, low-roll, periodic, first-roll, absence, count-specific |
| PATTERN | 6 | ✅ | Covers pair, triple, unique, sequence, parity, two-pair |
| FLOW | 4 | ✅ | Covers pool expansion, scoring exclusion, exhaustion, unchanged bonus |
| SCALING | 5 | ✅ | Covers per-roll, permanent, low-value stacking, kept-die, periodic |
| RULE_BENDER | 4 | ✅ | Covers dual-value, swapping, rule relaxation, probability |

---

## Step 8: Overlap Check

| Curio A | Curio B | Similarity | Resolution |
|---|---|---|---|
| Basin of Second Chances | Dust-Covered Lodestone | Both reward non-duplicates | Basin gives reroll; Dust gives reroll only. **Too similar.** → Merge or differentiate. |
| Even Moonstone | Stillwater Basin | Both interact with even values | Moonstone = scoring bonus; Basin = value transformation. **Distinct enough.** |
| Selenite Lattice | Fossilized Tide | Both scale over time | Lattice = per-roll within round; Tide = permanent every 3 rolls. **Distinct enough.** |
| Lunar Spindle | Glacial Resonance | Both interact with dice count | Spindle = adds die; Resonance = triggers on count. **Distinct enough.** |

**Action:** Rename Dust-Covered Lodestone to differentiate from Basin of Second Chances.

**Revised:**
- **Dust-Covered Lodestone** → renamed to **Scattered Star Chart**
  - New effect: "+1 reroll if you rolled at least one 6." (shifts from anti-duplicate to pro-high-roll)

---

## Step 9: Overlap-Resolved Set (Final 35)

The final set above with the renamed Curio. No remaining overlaps.

---

## Step 10: Starter Set (15 Curios)

Best balanced + easiest to implement:

| # | Name | Family | Rarity | Why Starter |
|---|---|---|---|---|
| 1 | Gentle Polishing Stone | ROLL_SHAPING | common | Simple floor raiser, easy to understand |
| 2 | Lunar Drift Charm | ROLL_SHAPING | common | Random +1, no player decision needed |
| 3 | Echo Chamber | REROLL_CONTROL | common | Baseline reroll economy |
| 4 | Scattered Star Chart | REROLL_CONTROL | common | Conditional reroll on 6s |
| 5 | Cracked Moon Fragment | TRIGGER | common | Simple 6-trigger bonus |
| 6 | Whispering Quartz | TRIGGER | common | Low-roll consolation |
| 7 | Cavern Echo | TRIGGER | common | First-roll bonus |
| 8 | Twin Hollows | PATTERN | common | Basic pair detection |
| 9 | Even Moonstone | PATTERN | common | Parity bonus, stacks with dice |
| 10 | Orbital Residue | FLOW | common | Reroll insurance |
| 11 | Selenite Lattice | SCALING | uncommon | Per-roll scaling (simple) |
| 12 | Stalactite Growth | SCALING | uncommon | Low-roll investment |
| 13 | Cratered Moonstone | ROLL_SHAPING | uncommon | Set-to-4 precision |
| 14 | Hollow Die Frame | REROLL_CONTROL | uncommon | Lock with payoff |
| 15 | Glacial Resonance | TRIGGER | uncommon | Dice count incentive |

**Starter Distribution:**
- 5 Common ROLL_SHAPING/REROLL_CONTROL/TRIGGER (foundational)
- 5 Common PATTERN/FLOW (mid-complexity)
- 5 Uncommon mixed (introduces scaling + decision points)

---

## Pattern Summary (Extracted Mechanics by Source)

### From Balatro (150 Jokers)
1. **Conditional suit/rank bonus** → ROLL_SHAPING (value-dependent bonus)
2. **Pattern hand bonus** (Pair, Straight, Flush) → PATTERN (dice combination reward)
3. **Scaling per action** (Green Joker, Ride the Bus) → SCALING (per-roll growth)
4. **Multiplicative scaling** (Constellation, Vampire) → SCALING (compound growth)
5. **Retrigger** (Mime, Dusk, Hack) → TRIGGER (repeat evaluation)
6. **Resource management** (Burglar, Juggler) → FLOW (pool/reroll manipulation)
7. **Probability doubling** (Oops! All 6s) → RULE_BENDER (meta-amplifier)
8. **Economy generation** (Golden Joker, Egg) → (excluded: no economy in Moonseed dice)
9. **Destroy/consume** (Ceremonial Dagger) → RULE_BENDER (sacrifice mechanic)
10. **Rule bending** (Four Fingers, Shortcut) → RULE_BENDER (pattern relaxation)
11. **Copy/synergy** (Blueprint, Brainstorm) → RULE_BENDER (duplication)
12. **Periodic trigger** (Loyalty Card) → TRIGGER (every N rolls)
13. **Threshold trigger** (Mystic Summit: 0 discards) → TRIGGER (resource state)
14. **First/last hand** (Dusk, Acrobat) → TRIGGER/FLOW (timing)
15. **Even/odd** (Even Steven, Odd Todd) → PATTERN (parity)
16. **Deck composition** (Steel Joker, Stone Joker) → SCALING (pool-based)
17. **Self-destruction** (Gros Michel) → RULE_BENDER (consumable)
18. **Negative tradeoff** (Ice Cream, Ramen) → RULE_BENDER (diminishing)
19. **Position-dependent** (Raised Fist, Baron) → FLOW (ordering)

### From Slay the Spire (100+ Relics)
1. **Combat start bonus** (Anchor, Vajra) → TRIGGER (first-roll bonus)
2. **Turn-based** (Happy Flower, Lantern) → TRIGGER/SCALING (periodic)
3. **Conditional on state** (Red Skull, Orichalcum) → TRIGGER (threshold)
4. **Resource generation** (Maw Bank, Golden Idol) → (excluded)
5. **Counter/accumulation** (Pen Nib, Nunchaku) → TRIGGER/SCALING (every N)
6. **Consumable/sacrifice** (Lizard Tail, Potion Belt) → RULE_BENDER (one-time)
7. **Rule change** (Runic Pyramid, Snecko Eye) → RULE_BENDER (system alteration)
8. **Boss power/cost** (Coffee Dripper, Sozu) → RULE_BENDER (tradeoff)
9. **Scaling** (Girya, Face of Cleric) → SCALING (permanent growth)
10. **Probability** (N'loth's Gift) → RULE_BENDER (odds manipulation)

### From Dicey Dungeons (518 Equipment)
1. **Value manipulation** (Bump +1, Nudge -1) → ROLL_SHAPING
2. **Reroll** (Combat Roll, Magic Reroll) → REROLL_CONTROL
3. **Dice splitting** (Hacksaw, Lockpick) → FLOW
4. **Dice combining** (Spanner, Smush Together) → ROLL_SHAPING
5. **Freeze/lock** (Bear Trap, Glue) → REROLL_CONTROL
6. **Value constraints** (Min/Max/Require/Countdown) → ROLL_SHAPING/TRIGGER
7. **Parity effects** (Even/Odd slots) → PATTERN
8. **Duplicate** (Counterfeit, Befuddle) → RULE_BENDER
9. **Countdown/periodic** (various) → TRIGGER
10. **Self-damage tradeoff** (Nail Bat, Flaming Sword) → RULE_BENDER

---

## Implementation Notes

### Data Structure (Suggested)
```gdscript
# curio_data.gd
class_name CurioData
extends Resource

enum Family {
    ROLL_SHAPING,
    REROLL_CONTROL,
    TRIGGER,
    PATTERN,
    FLOW,
    SCALING,
    RULE_BENDER
}

enum Rarity { COMMON, UNCOMMON, RARE }

enum TriggerType {
    PASSIVE,
    ON_ROLL_START,
    ON_ROLL_RESOLVED,
    ON_REROLL_RESOLVED,
    ON_SCORING,
    ON_FIRST_ROLL,
    PERIODIC
}

@export var id: String
@export var display_name: String
@export var family: Family
@export var rarity: Rarity
@export var effect_description: String
@export var trigger_type: TriggerType
@export var design_role: String
```

### Hook Points in Dice System
1. **Before roll:** `ON_ROLL_START` → Lunar Spindle (add die), Echo Chamber (add reroll)
2. **After roll, before reroll decision:** `ON_ROLL_RESOLVED` → most Trigger/Pattern Curios
3. **After reroll:** `ON_REROLL_RESOLVED` → Orbital Residue, Veil of Quiet Echoes
4. **During scoring:** `ON_SCORING` → Waning Crescent (ignore lowest)
5. **First roll of round:** `ON_FIRST_ROLL` → Cavern Echo
6. **Passive:** `PASSIVE` → Gentle Polishing Stone, Gravitational Anomaly

### Priority Order for Evaluation
1. ROLL_SHAPING (modify values first)
2. TRIGGER (check conditions on modified values)
3. PATTERN (evaluate patterns on modified values)
4. FLOW (apply structural effects)
5. SCALING (update scaling state)
6. RULE_BENDER (apply any rule modifications)
7. REROLL_CONTROL (manage reroll economy)