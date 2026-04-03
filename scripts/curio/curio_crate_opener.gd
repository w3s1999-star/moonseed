class_name CurioCrateOpener
extends RefCounted

## CurioCrateOpener — Handles the crate → roll → curio pipeline.
##
## Opening a crate feels like rolling dice:
##   1. Crate opens (UI flash)
##   2. Dice spawn on table
##   3. Dice roll
##   4. Dice settle
##   5. Curio result revealed
##
## This ties Curios to the core emotional loop of the Play Table.

# Preload dependencies (required because class_name isn't available during autoload)
const CurioResource := preload("res://scripts/curio/curio_resource.gd")
const CurioDatabase := preload("res://scripts/curio/curio_database.gd")

const CURIO_CRATE_COST := 10  # Moonpearls

signal crate_opening_started()
signal dice_rolling(curio: CurioResource)
signal curio_revealed(curio: CurioResource)

func can_afford_crate() -> bool:
	return Database.get_moonpearls(GameData.current_profile) >= CURIO_CRATE_COST

func purchase_crate() -> bool:
	if not can_afford_crate():
		return false
	return Database.spend_moonpearls(CURIO_CRATE_COST, GameData.current_profile)

func open_crate(rarity_bias: String = "normal") -> CurioResource:
	var curio: CurioResource = CurioManager.open_crate(rarity_bias)
	if curio:
		SignalBus.crate_opened.emit(curio.id)
	return curio

## Full animated crate open sequence.
## Call this from UI (CurioDealerScreen) to get the full experience.
func open_crate_animated(
	rarity_bias: String = "normal",
	dice_table_ref: Node = null
) -> CurioResource:
	crate_opening_started.emit()

	# 1. Purchase
	if not purchase_crate():
		return null

	# 2. Pick the curio (determines the "roll result")
	var curio: CurioResource = CurioDatabase.get_random_curio(rarity_bias)

	# 3. Animate dice on the table if reference provided
	if dice_table_ref != null and dice_table_ref.has_method("throw_task_dice"):
		dice_rolling.emit(curio)
		# Roll a ceremonial d6 — the result doesn't matter, it's the feel
		var ceremonial_result := randi() % 6 + 1
		dice_table_ref.call("throw_task_dice",
			"✦ Crate Opening ✦", 6, 1, [ceremonial_result], -1)
		# Wait for dice to settle
		if dice_table_ref.has_signal("roll_finished"):
			await dice_table_ref.roll_finished

	# 4. Grant the curio
	CurioManager.add_curio(curio.id)
	SignalBus.crate_opened.emit(curio.id)

	# 5. Reveal
	curio_revealed.emit(curio)
	return curio