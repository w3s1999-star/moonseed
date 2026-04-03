class_name CurioResource
extends Resource

## CurioResource — Data-driven definition of a single Curio.
## Each curio maps to an effect_key that CurioEffects uses to
## apply gameplay modifiers during the dice resolution pipeline.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var family: String = ""        # ROLL_SHAPING, REROLL_CONTROL, TRIGGER, PATTERN, FLOW, SCALING, RULE_BENDER
@export var rarity: String = "common"  # common, uncommon, rare, exotic
@export var trigger_type: String = ""  # passive, on_roll_start, on_roll_resolved, on_reroll_resolved, on_scoring, on_first_roll, periodic
@export var effect_key: String = ""    # maps to CurioEffects handler function
@export var emoji: String = "✦"
@export var design_role: String = ""

static func create(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_family: String,
	p_rarity: String,
	p_trigger: String,
	p_effect_key: String,
	p_emoji: String = "✦",
	p_role: String = ""
) -> CurioResource:
	var r := CurioResource.new()
	r.id = p_id
	r.display_name = p_name
	r.description = p_desc
	r.family = p_family
	r.rarity = p_rarity
	r.trigger_type = p_trigger
	r.effect_key = p_effect_key
	r.emoji = p_emoji
	r.design_role = p_role
	return r

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"family": family,
		"rarity": rarity,
		"trigger_type": trigger_type,
		"effect_key": effect_key,
		"emoji": emoji,
		"design_role": design_role,
	}

static func from_dict(d: Dictionary) -> CurioResource:
	var r := CurioResource.new()
	r.id = str(d.get("id", ""))
	r.display_name = str(d.get("display_name", ""))
	r.description = str(d.get("description", ""))
	r.family = str(d.get("family", ""))
	r.rarity = str(d.get("rarity", "common"))
	r.trigger_type = str(d.get("trigger_type", ""))
	r.effect_key = str(d.get("effect_key", ""))
	r.emoji = str(d.get("emoji", "✦"))
	r.design_role = str(d.get("design_role", ""))
	return r