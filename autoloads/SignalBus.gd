extends Node

# ─────────────────────────────────────────────────────────────────
# SignalBus.gd  —  MOONSEED Global Signal Hub
# GDD §5 (Singleton Architecture): "SignalBus-only cross-scene
# communication. No script may connect to another scene's signals
# directly — all cross-scene events route through SignalBus."
#
# Usage:
#   Emit:   SignalBus.task_checked.emit(task_id)
#   Listen: SignalBus.task_checked.connect(_on_task_checked)
# ─────────────────────────────────────────────────────────────────

@warning_ignore_start("unused_signal")

# ── Dice Resolution Pipeline (v0.10) ─────────────────────────────
## Roll requested — dice will be queued and thrown.
signal roll_requested(task_ids: Array[int])
## Single die settled — carries structured data for the resolution queue.
signal die_settled(roll_id: String, die_id: String, task_id: int, face_value: int, sides: int, is_max: bool)
## Stardrop spawn requested at a die's position.
signal stardrop_spawn_requested(die_id: String, amount: int, global_position: Vector2, tags: Array[String])
## Merge phase started — clusters are forming.
signal merge_phase_started(clusters: Array)
## A multiplier was applied from a named source.
signal multiplier_applied(source_id: String, before_value: float, after_value: float)
## A moonpearl was created at a cluster position.
signal moonpearl_created(cluster_id: String, pearl_value: int, global_position: Vector2)
## Full reward resolution complete — summary ready.
signal reward_resolution_complete(summary: Dictionary)
## Score preview updated mid-resolution (for live UI).
signal score_preview_updated(stardrops: int, strength: float, total: int, moonpearls: int)
## Staged count intermediate tick — UI listens for chunked updates.
signal staged_count_updated(label_key: String, value: int)
## Staged count sequence finished — UI settles final value.
signal staged_count_finished(label_key: String, final_value: int)
## Relic triggered — carries effect payload.
signal relic_triggered(relic_id: String, payload: Dictionary)
## Die effect triggered — carries effect payload.
signal die_effect_triggered(effect_id: String, payload: Dictionary)

# ── Dice Table ────────────────────────────────────────────────────
## A task's checkbox was ticked — queues its die for the hand.
signal task_checked(task_id: int)
## A single die finished rolling — carries raw result.
signal task_rolled(task_id: int, result: int, sides: int)
## All dice in the current roll have settled.
signal dice_settled(results: Dictionary)
## Explosion triggered on a die (max face rolled).
signal dice_exploded(task_id: int, sides: int)
## Dice table background PNG was changed from the Satchel.
signal dice_table_bg_changed(path: String)

# ── Scoring ───────────────────────────────────────────────────────
## Live score updated mid-session (not committed yet).
signal score_updated(stardrops: int, star_power: float)
## Day's score committed and moonpearls delta awarded.
signal score_saved(final_score: int, moonpearls_delta: int)
## Task dice box interaction fired from UI activation surfaces.
signal stardrop_completed(task_id: int)

# ── Garden ────────────────────────────────────────────────────────
## Water meter filled to 1.0.
signal garden_watered()
## A plant was watered successfully.
signal garden_plant_watered(plant_id: String, new_stage: int)
## A plant advanced to the next growth stage.
signal garden_plant_bloomed(plant_id: String, new_stage: int)
## A new Moonseed was earned from a contract.
signal moonseed_found()

# ── Contracts ────────────────────────────────────────────────────
## A contract was fully completed.
signal contract_completed(contract_id: int)
## Contract data was modified (add/edit/delete/subtask toggle).
signal contract_data_changed()
## A moonkissed paper fragment was earned from completing a contract.
signal moonkissed_paper_earned(paper_data: Dictionary)
## A moonkissed paper was redeemed at the Selenic Exchange.
signal moonkissed_paper_redeemed(paper_data: Dictionary, rewards: Dictionary)

# ── Economy ──────────────────────────────────────────────────────
## Moonpearls (permanent meta score) changed.
signal moonpearls_changed(new_val: int)
## Water meter value changed (0.0–1.0).
signal water_changed(new_val: float)
## Meals logged today changed.
signal meals_changed(count: int)

# ── Shop / Bazaar Vendors ─────────────────────────────────────────
## An item was purchased from the Emporium.
signal shop_item_purchased(item_id: String)
## A bazaar vendor stall was interacted with — opens the shop panel.
signal vendor_opened(vendor_id: String)

# ── Noumenia ─────────────────────────────────────────────────────
## Request Nou to say something. Any system can call this.
signal nou_say(text: String, duration: float)

# ── Global State ─────────────────────────────────────────────────
## Theme was swapped — all UI should repaint.
signal theme_changed()
## Generic state refresh — tabs re-read GameData and repaint.
signal state_changed()
## Profile was switched.
signal profile_changed(profile_name: String)
## Upgrade was purchased in the Curio Shop.
signal upgrade_purchased(upgrade_id: String, new_level: int)
## Date was changed via calendar navigation.
signal date_changed(date_dict: Dictionary)

# ── Curio Crate System (v0.10) ─────────────────────────────────
## A curio was acquired from a crate.
signal curio_acquired(curio_id: String)
## A curio was equipped to a canister.
signal curio_equipped(curio_id: String, canister_id: int)
## A curio was unequipped from a canister.
signal curio_unequipped(curio_id: String, canister_id: int)
## A crate was opened — carries the curio result.
signal crate_opened(curio_id: String)

# ── Moon Phase ────────────────────────────────────────────────────
## The moon-phase splash overlay has fully faded and been freed.
## Scoring FX must wait for this before triggering, so the player
## is not distracted from the roll result by the popup.
signal moon_overlay_dismissed()

# ── Visual Effects (v0.8.1) ───────────────────────────────────────
## Request a die shockwave at a die's screen position.
signal fx_die_shockwave(die_control: Control, value: int, sides: int)
## Request stardrop rain.
signal fx_rain_stardrops(count: int)
## Request moonpearls rain on save.
signal fx_rain_moonpearls(score: int)
## Score popup at world position.
signal fx_score_popup(world_pos: Vector2, value: int)
## Pearl animation completed — HUD counter has been pulsed and sparkled. (Step 10)
signal fx_moonpearls_arrived

# ── Confectionery (v0.9.0) ────────────────────────────────────────
## Pomodoro session started.
signal confect_session_started(session_type: String, duration_sec: int)
## Pomodoro session tick (seconds remaining).
signal confect_tick(seconds_remaining: int)
## Session completed — ingredient yield issued.
signal confect_session_complete(yield_array: Array)
## Session abandoned — no yield.
signal confect_session_abandoned()
## Ingredient satchel changed.
signal ingredients_changed()
## Sweet crafted successfully.
signal sweet_crafted(sweet_key: String)
## Sweet consumed — effect applied.
signal sweet_consumed(sweet_key: String)
## New recipe discovered.
signal recipe_discovered(sweet_key: String)
## Active buff applied.
signal buff_applied(sweet_key: String)

# ── Chocolate Coin Plinko (v0.10) ─────────────────────────────────
## Chocolate coins changed (bar/truffle/artisan).
signal chocolate_coins_changed(coin_inventory: Dictionary)
## Coin dropped in Plinko board.
signal plinko_coin_dropped(coin_type: String, category: String)
## Coin entered a category zone.
signal plinko_zone_entered(zone_category: String)
## Chocolate resolved from Plinko drop.
signal chocolate_resolved(chocolate_key: String, category: String)

# ── Studio Rooms ──────────────────────────────────────────────────
## A new studio room was created and persisted (task or relic added).
signal studio_room_created(room_id: int, owner_type: String, owner_id: int)
## A studio room's data was deleted (task or relic removed).
signal studio_room_deleted(room_id: int)
## A studio room's stickers or paint were saved — linked previews should refresh.
signal studio_room_updated(room_id: int)

# ── Contracts (v0.9.0) ────────────────────────────────────────────
## Contract completed with full reward sequence.
signal contract_reward_sequence(reward_dict: Dictionary)
## Early completion bonus queued.
signal contract_early_bonus(days_early: int, multiplier_bonus: int)

# ── Wish / Reward Cinematic (v0.9.x) ─────────────────────────────
## Cerulean wish-like sequence started for a reward payload.
signal wish_sequence_started(request_id: String)
## Highest rarity telegraphed during launch/flight phase.
signal wish_rarity_telegraph(tier: String)
## One reveal entry was shown (single reward flow uses index 0).
signal wish_item_revealed(index: int, item: Dictionary)
## Wish sequence fully completed and can be considered dismissed.
signal wish_sequence_finished(request_id: String, results: Array)
## Wish sequence was player-skipped before natural completion.
signal wish_sequence_skipped(request_id: String)

# ── Achievement System ────────────────────────────────────────────
## Achievement was unlocked.
signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)
## Dice was unlocked from shop.
signal dice_unlocked(dice_type: String)

# ── Loading Screen ────────────────────────────────────────────────
## Loading phase changed (arrival, formation, compression, crystallization, transition).
signal load_phase_changed(phase: String)
## Loading progress updated (0.0–1.0).
signal load_progress_updated(percent: float)
## A stardrop droplet was spawned during loading.
signal load_stardrop_spawned(drop_index: int)
## Moonpearl crystallization animation completed.
signal load_moonpearl_crystallized()

@warning_ignore_restore("unused_signal")
