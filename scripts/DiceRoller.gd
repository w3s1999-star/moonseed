extends RefCounted
class_name DiceRoller

# ─────────────────────────────────────────────────────────────────
# DiceRoller  –  Utility class for dice roll calculations
# ─────────────────────────────────────────────────────────────────

static func roll(sides: int) -> int:
	return randi() % sides + 1

static func roll_with_advantage(sides: int) -> int:
	return max(roll(sides), roll(sides))

static func roll_with_disadvantage(sides: int) -> int:
	return min(roll(sides), roll(sides))

static func roll_n(sides: int, count: int) -> Array[int]:
	var results: Array[int] = []
	for _i in range(count):
		results.append(roll(sides))
	return results

static func sum_rolls(sides: int, count: int) -> int:
	var total := 0
	for _i in range(count):
		total += roll(sides)
	return total

static func format_roll(value: int, sides: int) -> String:
	if sides == 6 and value >= 1 and value <= 6:
		return GameData.DICE_CHARS[value - 1]
	return "(d%d: %d)" % [sides, value]

static func format_roll_sequence(rolls: Array[int], sides: int) -> String:
	var parts := []
	for r in rolls:
		parts.append(format_roll(r, sides))
	return " ".join(parts)

static func get_die_color(sides: int) -> Color:
	return GameData.DIE_COLORS.get(sides, GameData.FG_COLOR)

static func is_critical(value: int, sides: int) -> bool:
	return value == sides

static func is_fumble(value: int) -> bool:
	return value == 1

# ── Probability helpers ───────────────────────────────────────────
static func expected_value(sides: int) -> float:
	return (sides + 1.0) / 2.0

static func probability_at_least(target: int, sides: int) -> float:
	if target <= 1: return 1.0
	if target > sides: return 0.0
	return float(sides - target + 1) / float(sides)

static func chips_from_roll(value: int, sides: int, jokers: Array) -> int:
	var chips := value
	if "mega6" in jokers and sides == 6:
		chips *= 2
	return chips

# ── Display helpers (mirrors godot-dice-roller addon show_face API) ──
## Apply a face value to a sprite+label display pair.
## Uses the d6 sprite sheet for d6; falls back to unicode/text for others.
static func apply_face_to_display(
		sprite: TextureRect, label: Label,
		sides: int, face: int) -> void:

	if sides == 6 and face >= 1 and face <= 6:
		# Load the matching d6 sprite (0-indexed filenames)
		var path := "res://assets/dice/d6/spr_dice_d6_%d.png" % (face - 1)
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if tex:
			sprite.texture = tex
			sprite.modulate = GameData.DIE_COLORS.get(6, Color.WHITE)
			sprite.visible  = true
			label.visible   = false
			return

	# Fallback: text label
	sprite.visible = false
	label.visible  = true
	label.add_theme_color_override("font_color",
		GameData.DIE_COLORS.get(sides, GameData.FG_COLOR))

	if sides == 6 and face >= 1 and face <= 6:
		label.text = GameData.DICE_CHARS[face - 1]
	else:
		label.text = _die_symbol(sides, face)

## Unicode die symbol for non-d6 dice
static func _die_symbol(sides: int, face: int) -> String:
	match sides:
		4:  return "◆%d" % face
		8:  return "◈%d" % face
		10: return "◉%d" % face
		12: return "⬟%d" % face
		20: return "✦%d" % face
		_:  return "d%d:%d" % [sides, face]
