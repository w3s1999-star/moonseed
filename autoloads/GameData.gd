extends Node
var dice_inventory: Dictionary = {}

# Chocolate coin inventory (Bar/Truffle/Artisan)
var chocolate_coin_inventory: Dictionary = {}

# ── Chocolate Coin Helpers ────────────────────────────────────────
func add_chocolate_coin(coin_type: String, qty: int = 1) -> void:
	if not chocolate_coin_inventory.has(coin_type):
		chocolate_coin_inventory[coin_type] = 0
	chocolate_coin_inventory[coin_type] += qty
	print("DEBUG add_chocolate_coin: type=", coin_type, " qty=", qty, " new_total=", chocolate_coin_inventory[coin_type])
	# Persist to database
	get_node("/root/Database").save_chocolate_coins(chocolate_coin_inventory)
	if Engine.has_singleton("SignalBus"):
		SignalBus.chocolate_coins_changed.emit(chocolate_coin_inventory)

func remove_chocolate_coin(coin_type: String, qty: int = 1) -> bool:
	if chocolate_coin_inventory.has(coin_type) and chocolate_coin_inventory[coin_type] >= qty:
		chocolate_coin_inventory[coin_type] -= qty
		# Persist to database
		get_node("/root/Database").save_chocolate_coins(chocolate_coin_inventory)
		if Engine.has_singleton("SignalBus"):
			SignalBus.chocolate_coins_changed.emit(chocolate_coin_inventory)
		return true
	return false

func get_chocolate_coin_count(coin_type: String) -> int:
	return chocolate_coin_inventory.get(coin_type, 0)

func get_all_chocolate_coins() -> Dictionary:
	return chocolate_coin_inventory.duplicate()

# Achievement system
var achievements: Dictionary = {}
var achievement_progress: Dictionary = {}

# Upgrade system
var upgrades: Dictionary = {}
var upgrade_levels: Dictionary = {}

# When true the next persist will award moonpearls; cleared after use.
var allow_next_award: bool = false
# Curio Shop Upgrades
const CURIO_SHOP_UPGRADES := {
	"resonance_charm": {
		"name": "Resonance Charm",
		"max_level": 3,
		"base_cost": 150,
		"cost_multiplier": 2.5,
		"description": "Strengthens how strongly dice respond to lunar alignment.",
		"effect_description": "Increases explosion limit by +1 per stack",
		"emoji": "🔔",
		"level_descriptions": [
			"I → slight echo",
			"II → stable chaining", 
            "III → full resonance loop"
		]
	}
}

# Dice Carver Shop Data
const DICE_CARVER_SHOP_ITEMS := {
	"d8": {
		"name": "Octahedron Die",
		"cost": 100,
		"requirement": "",
		"description": "An 8-sided die, perfectly balanced for fate.",
		"emoji": "🎲",
		"achievement_id": "unlock_d8"
	},
	"d10": {
		"name": "Pentagonal Trapezohedron",
		"cost": 300,
		"requirement": "Complete 10 tasks",
		"description": "A 10-sided die for precise divination.",
		"emoji": "🔷",
		"achievement_id": "unlock_d10"
	},
	"d12": {
		"name": "Dodecahedron Die",
		"cost": 1000,
		"requirement": "Trigger 5 explosions",
		"description": "A 12-sided die of cosmic power.",
		"emoji": "💠",
		"achievement_id": "unlock_d12"
	},
	"d20": {
		"name": "Icosahedron of Destiny",
		"cost": 3000,
		"requirement": "Special item/contract completion",
		"description": "The legendary 20-sided die of ultimate fate.",
		"emoji": "✨",
		"achievement_id": "unlock_d20"
	}
}

const ACHIEVEMENTS := {
	"unlock_d8": {
		"name": "Dice Collector I",
		"description": "Unlock your first D8 die",
		"emoji": "🎲",
		"requirement_type": "unlock",
		"requirement_target": "d8"
	},
	"unlock_d10": {
		"name": "Task Master",
		"description": "Complete 10 tasks and unlock D10",
		"emoji": "🔷",
		"requirement_type": "tasks_completed",
		"requirement_target": 10
	},
	"unlock_d12": {
		"name": "Explosion Expert",
		"description": "Trigger 5 explosions and unlock D12",
		"emoji": "💠",
		"requirement_type": "explosions_triggered",
		"requirement_target": 5
	},
	"unlock_d20": {
		"name": "Legendary Collector",
		"description": "Complete special contract and unlock D20",
		"emoji": "✨",
		"requirement_type": "special_contract",
		"requirement_target": 1
	}
}

# emit when external code requests a tab switch (key = primary or secondary tab id)
@warning_ignore("unused_signal")
signal tab_requested(tab:String)

# ─────────────────────────────────────────────────────────────────
# MOONSEED  –  GameData Singleton
# TEAL = tasks/stardrops   PINK = curio_canisters/star power
# Palette: Outer Rim #290E7A | Fuchsia Nebula #6F1CB2
#          Pink Pride #E31AE0 | Aquarium Diver #099EA9
#          Light Mint Green #A1EBAC
# ─────────────────────────────────────────────────────────────────

const APP_NAME := "MOONSEED"

const DICE_CHARS := ["⚀","⚁","⚂","⚃","⚄","⚅"]

# ── Theme / Palette constants (used across UI)
const BG_COLOR := Color("#0d0520")
const FG_COLOR := Color("#eaf7ff")

# Accent colors
const ACCENT_GOLD := Color("#ffd66b")
const ACCENT_BLUE := Color("#4a8fff")
const ACCENT_RED := Color("#E31AE0")
const ACCENT_CURIO_CANISTER := Color("#6F1CB2")

# Card / UI surfaces
const CARD_BG := Color("#1a0b3a")
const TABLE_FELT := Color("#0b2a3f")
const CHIP_COLOR := Color("#ffd66b")
const MULT_COLOR := Color("#099EA9")

# Rarity background lookup
const RARITY_BG := {
	"common": Color("#1a0a35"),
	"uncommon": Color("#0d0520"),
	"rare": Color("#332200"),
	"epic": Color("#332200"),
	"legendary": Color("#002244")
}

# Rarity text colors for UI display
const RARITY_COLORS := {
	"common": Color("#eaf7ff"),      # Light gray/white for visibility
	"uncommon": Color("#88ccff"),    # Light blue to match theme
	"rare": Color("#ffd66b"),        # Gold to match ACCENT_GOLD
	"epic": Color("#cc88ff"),        # Purple/pink for distinction
	"exotic": Color("#4a8fff")       # Bright cyan/blue for maximum visibility
}

# Per-die color mapping
const DIE_COLORS := {
	4: Color("#A1EBAC"),
	6: ACCENT_GOLD,
	8: Color("#44ccff"),
	10: Color("#c944ff"),
	12: Color("#ff9500"),
	20: Color("#e31ae0")
}

# UI highlight / card border color
const CARD_HL := Color("#A1EBAC")

# ── Panel / Surface Colors ────────────────────────────────────────
const PANEL_BG := Color("#0d0520")           # Deep void — default panel background
const PANEL_BG_ALT := Color("#060220")       # Darker variant — left panel, headers
const PANEL_BORDER := Color("#290E7A")       # Outer rim — default panel border
const PANEL_BORDER_ACCENT := Color("#099EA9") # Teal — header/nav accent borders
const PANEL_SHADOW := Color(0.0, 0.0, 0.0, 0.14)

# ── Card Colors ───────────────────────────────────────────────────
const CARD_BG_DEFAULT := Color("#1a0b3a")    # Default card surface
const CARD_BORDER_DEFAULT := Color("#290E7A") # Default card border
const CARD_HL_ACTIVE := Color("#A1EBAC")     # Active card highlight (mint)
const CARD_BG_DONE := Color("#0d1a0d")       # Completed/owned card tint

# ── Text Colors ───────────────────────────────────────────────────
const TEXT_PRIMARY := Color("#eaf7ff")       # Primary text — light blue-white
const TEXT_SECONDARY := Color("#a1ebac")     # Secondary text — mint green
const TEXT_MUTED := Color("#6644aa")         # Muted/inactive text
const TEXT_GOLD := Color("#ffd66b")          # Gold accent text
const TEXT_DANGER := Color("#E31AE0")        # Danger/pink text

# ── Separator / Divider ──────────────────────────────────────────
const SEPARATOR_COLOR := Color("#3a3a5a")    # Default separator line

# ── Button Text Colors (Satchel/Leather theme) ──────────────────
const SATCHEL_BTN_TEXT := Color("#f7e7c8")
const SATCHEL_BTN_BG := Color("#b07848")
const SATCHEL_BTN_HOVER := Color("#c98c58")
const SATCHEL_BTN_PRESSED := Color("#8c5e36")
const SATCHEL_BTN_BORDER := Color("#4a2c10")

# ── Calendar Heat-Map Colors ─────────────────────────────────────
const CAL_CELL_VOID := Color("#080318")
const CAL_CELL_ZERO := Color("#100830")
const CAL_CELL_DIM := Color("#1C0A55")
const CAL_CELL_MID := Color("#321096")
const CAL_CELL_BRIGHT := Color("#7B1FCC")
const CAL_BORDER_IDLE := Color("#3A1880")
const CAL_BORDER_TODAY := Color("#FFD700")
const CAL_BORDER_VIEW := Color("#5BA8FF")

# ── Dice Table Colors ─────────────────────────────────────────────
const DICE_TABLE_FELT := Color("#0d1a2e")
const DICE_TABLE_EDGE := Color("#290E7A")
const DICE_TABLE_INNER := Color("#12053a")
const DICE_TABLE_LABEL := Color("#3a2a5a")

# ── Shop / Commerce Colors ────────────────────────────────────────
const SHOP_OWNED_BG := Color("#0d1a0d")
const SHOP_OWNED_BORDER := Color("#44cc44")

# ── Rarity Text Colors (canonical, replaces SeedCaseScript duplicates) ─
const RARITY_TEXT_COLS := {
	"common":    Color("#aaaaaa"),
	"uncommon":  Color("#44aaff"),
	"rare":      Color("#cc44ff"),
	"epic":      Color("#ff8800"),
	"legendary": Color("#ffdd00"),
}


# ── Timezones ─────────────────────────────────────────────────────
const TIMEZONES: Dictionary = {
	"Mountain Standard (MST, UTC-7)": -7,  "Pacific Standard (PST, UTC-8)": -8,
	"Central Standard (CST, UTC-6)": -6,   "Eastern Standard (EST, UTC-5)": -5,
	"UTC": 0,  "Central European (CET, UTC+1)": 1,  "UK (GMT, UTC+0)": 0,
	"Japan (JST, UTC+9)": 9,  "Australia/Sydney (AEST, UTC+10)": 10,
}
const DEFAULT_TZ := "Mountain Standard (MST, UTC-7)"

# ── Sticker definitions (task augmentations)
# these are not purchasable yet; they live on tasks themselves.
const RITUAL_STICKERS := {
	"binding_twine":   {"name":"Binding Twine",   "emoji":"🧵", "desc":"Must be clicked before the main task.", "rarity":"common"},
	"waxy_seal":       {"name":"Waxy Seal",       "emoji":"🕯️", "desc":"Adds a ritual sub‑task to be done with the main task.", "rarity":"common"},
	"lead_tape":       {"name":"Lead-Lined Tape","emoji":"⛓️", "desc":"Increases weight; +2× Moon Drops.", "rarity":"uncommon"},
	"safety_pin":      {"name":"Safety Pin",     "emoji":"🧷", "desc":"Completing it prevents misses for 24h.", "rarity":"uncommon"},
	"polka_dot_band":  {"name":"Polka-Dot Band", "emoji":"🎀", "desc":"Adds 3 tiny sub‑checkboxes with Moonpearls bursts.", "rarity":"rare"},
	"rusty_staple":    {"name":"Rusty Staple",   "emoji":"📎", "desc":"Anchors two tasks together (they share clicks).", "rarity":"rare"},
}

const CONSUMABLE_STICKERS := {
	"prismatic_star":  {"name":"Prismatic Star","emoji":"🌟", "desc":"Next completion is Spectral (high‑rarity payout).", "rarity":"epic"},
	"coffee_ring":     {"name":"Coffee Ring",    "emoji":"☕", "desc":"Jolt: resets another task's cooldown.", "rarity":"common"},
	"hand_drawn_heart":{"name":"Hand-Drawn Heart","emoji":"❤️", "desc":"Self‑Care: removes weight penalty one use.", "rarity":"common"},
	"gold_foil_leaf":  {"name":"Gold Foil Leaf","emoji":"✨", "desc":"Next Moon Drop gain ×5.", "rarity":"uncommon"},
	"sooty_thumbprint":{"name":"Sooty Thumbprint","emoji":"👤", "desc":"Underground: higher chance for Glitch outcome.", "rarity":"uncommon"},
	"doodle_arrow":    {"name":"Doodle Arrow",   "emoji":"↗️", "desc":"Guided: next roll cannot be '1'.", "rarity":"rare"},
	"lace_border":     {"name":"Lace Border",    "emoji":"🕸️", "desc":"Pure decor; +1% sparkle permanently.", "rarity":"legendary"},
}

# ── Shop Catalog ──────────────────────────────────────────────────
const SHOP_CATALOG: Array = [
	{id="d8",    name="d8 Prismatic",     type="dice",    sides=8,  desc="Rolls 1–8.",                        pearl_cost=2,  emoji="🎲", rarity="common",   color="#A1EBAC"},
	{id="d10",   name="d10 Cosmic",       type="dice",    sides=10, desc="Rolls 1–10.",                       pearl_cost=3,  emoji="🎲", rarity="common",   color="#7fff00"},
	{id="d12",   name="d12 Infernal",     type="dice",    sides=12, desc="Rolls 1–12.",                       pearl_cost=5,  emoji="🎲", rarity="uncommon", color="#ff9500"},
	{id="d20",   name="d20 Void",         type="dice",    sides=20, desc="Rolls 1–20.",                       pearl_cost=10, emoji="🎲", rarity="rare",     color="#c944ff"},
	{id="jimbo",    name="Jimbo",          type="joker",   desc="+4 Moondrops if you roll any 6.",          pearl_cost=5,  emoji="🃏", rarity="common",   color="#ffcc00"},
	{id="sloth",    name="Sloth",          type="joker",   desc="1 in 3 chance to roll twice.",              pearl_cost=8,  emoji="🦥", rarity="uncommon", color="#88aaff"},
	{id="spare",    name="Spare Change",   type="joker",   desc="Earn 1 moonpearl per 1000 moondrops.",     pearl_cost=6,  emoji="💰", rarity="uncommon", color="#4caf50"},
	{id="galaxy",   name="Galaxy Brain",   type="joker",   desc="x2 star power if all tasks done.",            pearl_cost=15, emoji="🌌", rarity="rare",     color="#c944ff"},
	{id="mega6",    name="Mega d6",        type="dice_mod",desc="Every d6 pip counts x2.",                   pearl_cost=10, emoji="💥", rarity="rare",     color="#ff3e3e"},
	{id="luckydie", name="Lucky Die",      type="dice_mod",desc="Min roll is always 3.",                     pearl_cost=8,  emoji="🍀", rarity="uncommon", color="#099EA9"},
	# legacy coin items removed — economy uses Moonpearls
	{id="tarot1", name="The Star",         type="tarot",   desc="Reveal tomorrow's best task.",              pearl_cost=5,  emoji="⭐", rarity="uncommon", color="#aaddff"},
	{id="tarot2", name="The Tower",        type="tarot",   desc="Reset star power to 1 for +50 moondrops.",  pearl_cost=4,  emoji="🏰", rarity="common",   color="#998877"},
	{id="booster",  name="Booster Pack",   type="pack",    desc="3 random items revealed.",                  pearl_cost=6,  emoji="📦", rarity="uncommon", color="#ffaa44"},
	{id="spectral", name="Spectral Pack",  type="pack",    desc="1 rare item guaranteed.",                   pearl_cost=15, emoji="👻", rarity="rare",     color="#cc88ff"},
	{id="lens",   name="Magnifier",        type="util",    desc="See moondrop value before rolling.",       pearl_cost=4,  emoji="🔍", rarity="common",   color="#88ccff"},
	{id="crown",  name="Crown of Thorns",  type="curio_canister",   desc="+0.5x star power. –5 moondrops per miss.",  pearl_cost=20, emoji="👑", rarity="rare",     color="#ffd700"},
	{id="grass_seed", name="Grass Seed",     type="util", desc="Plant more grass patches in your garden.", pearl_cost=5,  emoji="🌾", rarity="common", color="#44cc44"},
	{id="garden_gloves",name="Garden Gloves",  type="util", desc="Rip up a patch of grass quickly.",    pearl_cost=8,  emoji="🧤", rarity="uncommon", color="#cc8844"},
	# ── Dice Table Backgrounds (shader-based) ────────────────────────
	{id="bg_purple",  name="Nebula Purple",  type="bg", desc="Swirling purple cosmic background.",          pearl_cost=3,  emoji="🟣", rarity="uncommon", color="#660099", bg_shader="nebula"},
	{id="bg_ember",   name="Ember Forge",    type="bg", desc="Glowing orange embers and heat shimmer.",     pearl_cost=3,  emoji="🔥", rarity="uncommon", color="#cc3300", bg_shader="ember"},
	{id="bg_ocean",   name="Deep Ocean",     type="bg", desc="Bioluminescent ocean depths.",                pearl_cost=3,  emoji="🌊", rarity="uncommon", color="#003366", bg_shader="ocean"},
	{id="bg_void",    name="Void Rift",      type="bg", desc="Crackling electric void energy.",             pearl_cost=5,  emoji="⚡", rarity="rare",     color="#110033", bg_shader="void"},
	{id="bg_aurora",  name="Aurora Borealis",type="bg", desc="Dancing northern lights.",                   pearl_cost=5,  emoji="🌌", rarity="rare",     color="#002244", bg_shader="aurora"},
	{id="bg_gold",    name="Golden Hall",    type="bg", desc="Gilded casino gold shimmer.",                 pearl_cost=8,  emoji="🏅", rarity="epic",     color="#332200", bg_shader="gold"},
]

# ── Plant Catalog ─────────────────────────────────────────────────
const PLANT_CATALOG: Array = [
	# ── Common (20) ──────────────────────────────────────────────
	{id="moonflower",      name="Moonflower",       type="Floral",    rarity="common",    emoji="🌸", desc="+1 star power if roll contains 6",           effect_key="mult_on_six",         effect_val=1.0},
	{id="fern",            name="Fern",              type="Forest",    rarity="common",    emoji="🌿", desc="+1 moondrop per die",                     effect_key="chips_per_die",       effect_val=1.0},
	{id="glowcap",         name="Glowcap Mushroom",  type="Fungi",     rarity="common",    emoji="✨", desc="+1 star power if rolling 3+ dice",           effect_key="mult_on_three_dice",  effect_val=1.0},
	{id="lucky_pebble",    name="Lucky Pebble",      type="Artifact",  rarity="common",    emoji="🪨", desc="+2 moondrops if 2 appears",               effect_key="chips_on_two",        effect_val=2.0},
	{id="wheat_spirit",    name="Wheat Spirit",      type="Field",     rarity="common",    emoji="🌾", desc="+5 moondrops if total is even",           effect_key="chips_on_even",       effect_val=5.0},
	{id="daisy_charm",     name="Daisy Charm",       type="Floral",    rarity="common",    emoji="🌼", desc="+1 moondrop if 1 appears",                effect_key="chips_on_one",        effect_val=1.0},
	{id="moss_patch",      name="Moss Patch",        type="Forest",    rarity="common",    emoji="🍃", desc="+3 moondrops if total ≤10",               effect_key="chips_on_low_total",  effect_val=3.0},
	{id="dust_cactus",     name="Dust Cactus",       type="Desert",    rarity="common",    emoji="🌵", desc="5% reroll chance",                         effect_key="reroll_chance",       effect_val=0.05},
	{id="spore_puff",      name="Spore Puff",        type="Fungi",     rarity="common",    emoji="🍄", desc="+2 moondrops if duplicates appear",       effect_key="chips_on_duplicate",  effect_val=2.0},
	{id="barley_sprite",   name="Barley Sprite",     type="Field",     rarity="common",    emoji="🌻", desc="+4 moondrops if total odd",               effect_key="chips_on_odd",        effect_val=4.0},
	{id="petal_clover",    name="Petal Clover",      type="Floral",    rarity="common",    emoji="🍀", desc="+1 star power if 3 appears",                 effect_key="mult_on_three",       effect_val=1.0},
	{id="twig_totem",      name="Twig Totem",        type="Forest",    rarity="common",    emoji="🪵", desc="+2 moondrops if 4 appears",               effect_key="chips_on_four",       effect_val=2.0},
	{id="dryroot",         name="Dryroot",           type="Desert",    rarity="common",    emoji="🌴", desc="+3 moondrops if 1 appears",               effect_key="chips_on_one_b",      effect_val=3.0},
	{id="button_mushroom", name="Button Mushroom",   type="Fungi",     rarity="common",    emoji="🟤", desc="+1 moondrop per duplicate die",           effect_key="chips_per_duplicate", effect_val=1.0},
	{id="corn_idol",       name="Corn Idol",         type="Field",     rarity="common",    emoji="🌽", desc="+2 moondrops per even die",               effect_key="chips_per_even_die",  effect_val=2.0},
	{id="pebble_stack",    name="Pebble Stack",      type="Artifact",  rarity="common",    emoji="🪨", desc="+1 moondrop per odd die",                 effect_key="chips_per_odd_die",   effect_val=1.0},
	{id="bluebell",        name="Bluebell",          type="Floral",    rarity="common",    emoji="🔵", desc="+2 moondrops if total 12–15",             effect_key="chips_on_mid_total",  effect_val=2.0},
	{id="forest_acorn",    name="Forest Acorn",      type="Forest",    rarity="common",    emoji="🌰", desc="+1 star power if 5 appears",                 effect_key="mult_on_five",        effect_val=1.0},
	{id="cracked_pot",     name="Cracked Pot",       type="Artifact",  rarity="common",    emoji="🪴", desc="+3 moondrops if total ≤8",               effect_key="chips_on_very_low",   effect_val=3.0},
	{id="sand_sprout",     name="Sand Sprout",       type="Desert",    rarity="common",    emoji="🏜️", desc="+2 moondrops if no duplicates",           effect_key="chips_on_no_dup",     effect_val=2.0},
	# ── Uncommon (16) ────────────────────────────────────────────
	{id="moonvine",        name="Moonvine",          type="Lunar",     rarity="uncommon",  emoji="🌙", desc="+1 star power if total ≥18",                 effect_key="mult_on_high_total",  effect_val=1.0},
	{id="crescent_lily",   name="Crescent Lily",     type="Lunar",     rarity="uncommon",  emoji="🌛", desc="Moon Drops doubled during waxing phase",   effect_key="waxing_double",       effect_val=2.0},
	{id="spore_cluster",   name="Spore Cluster",     type="Fungi",     rarity="uncommon",  emoji="🍄", desc="+2 moondrops per mushroom plant",         effect_key="chips_per_mushroom",  effect_val=2.0},
	{id="mycelium_web",    name="Mycelium Web",      type="Fungi",     rarity="uncommon",  emoji="🕸️", desc="+1 combo star power",                        effect_key="combo_mult",          effect_val=1.0},
	{id="mirage_succulent",name="Mirage Succulent",  type="Desert",    rarity="uncommon",  emoji="🌵", desc="+5 moondrops if 6 appears",               effect_key="chips_on_six",        effect_val=5.0},
	{id="sand_thorn",      name="Sand Thorn",        type="Desert",    rarity="uncommon",  emoji="🌾", desc="+3 moondrops per odd die",                effect_key="chips_per_odd_die_b", effect_val=3.0},
	{id="sunflower_idol",  name="Sunflower Idol",    type="Field",     rarity="uncommon",  emoji="🌻", desc="+6 moondrops if all dice different",      effect_key="chips_on_all_unique", effect_val=6.0},
	{id="silver_clover",   name="Silver Clover",     type="Floral",    rarity="uncommon",  emoji="🍀", desc="+2 star power if 1 and 6 appear",            effect_key="mult_on_one_and_six", effect_val=2.0},
	{id="forest_totem",    name="Forest Totem",      type="Forest",    rarity="uncommon",  emoji="🪵", desc="+1 star power if total 10–15",               effect_key="mult_on_mid_total",   effect_val=1.0},
	{id="amber_seed",      name="Amber Seed",        type="Artifact",  rarity="uncommon",  emoji="🟡", desc="+4 moondrops if 4 appears",               effect_key="chips_on_four_b",     effect_val=4.0},
	{id="crystal_shard",   name="Crystal Shard",     type="Artifact",  rarity="uncommon",  emoji="💎", desc="+1 star power if duplicates appear",         effect_key="mult_on_duplicate",   effect_val=1.0},
	{id="ancient_coin",    name="Ancient Moonpearl", type="Artifact",  rarity="uncommon",  emoji="✨", desc="+5 moondrops if total ≥20",               effect_key="chips_on_very_high",  effect_val=5.0},
	{id="wild_orchid",     name="Wild Orchid",       type="Floral",    rarity="uncommon",  emoji="🌺", desc="+2 moondrops per different die",          effect_key="chips_per_unique_die",effect_val=2.0},
	{id="root_network",    name="Root Network",      type="Forest",    rarity="uncommon",  emoji="🌿", desc="+1 moondrop per plant owned",             effect_key="chips_per_plant",     effect_val=1.0},
	{id="golden_wheat",    name="Golden Wheat",      type="Field",     rarity="uncommon",  emoji="🌾", desc="+8 moondrops if total even",              effect_key="chips_on_even_b",     effect_val=8.0},
	{id="night_petal",     name="Night Petal",       type="Lunar",     rarity="uncommon",  emoji="🌙", desc="+2 star power if 5 appears",                 effect_key="mult_on_five_b",      effect_val=2.0},
	# ── Rare (10) ────────────────────────────────────────────────
	{id="moon_orchid",     name="Moon Orchid",       type="Lunar",     rarity="rare",      emoji="🌸", desc="Every 6 rolled counts as two dice",        effect_key="six_as_two_dice",     effect_val=1.0},
	{id="king_mushroom",   name="King Mushroom",     type="Fungi",     rarity="rare",      emoji="🍄", desc="Duplicates give +3 moondrops each",       effect_key="chips_per_dup_bonus", effect_val=3.0},
	{id="solar_corn",      name="Solar Corn",        type="Field",     rarity="rare",      emoji="🌽", desc="If total ≥18 → double moondrops",         effect_key="double_chips_high",   effect_val=18.0},
	{id="clover_shrine",   name="Clover Shrine",     type="Floral",    rarity="rare",      emoji="🍀", desc="If 1,3,5 appear → +4 star power",            effect_key="mult_on_odd_faces",   effect_val=4.0},
	{id="ancient_oak",     name="Ancient Oak",       type="Forest",    rarity="rare",      emoji="🌳", desc="+1 star power per Forest plant",             effect_key="mult_per_forest",     effect_val=1.0},
	{id="mirage_bloom",    name="Mirage Bloom",      type="Desert",    rarity="rare",      emoji="🌺", desc="First roll each turn may reroll all dice", effect_key="first_reroll_all",    effect_val=1.0},
	{id="prism_curio_canister", name="Prism Curio Canister", type="Artifact",  rarity="rare",      emoji="🔮", desc="Each unique die adds +2 star power",         effect_key="mult_per_unique_die", effect_val=2.0},
	{id="fungal_crown",    name="Fungal Crown",      type="Fungi",     rarity="rare",      emoji="👑", desc="Mushrooms grant +1 star power",              effect_key="mult_per_mushroom",   effect_val=1.0},
	{id="moonwell",        name="Moonwell",          type="Lunar",     rarity="rare",      emoji="🌕", desc="Moon phase effects 50% stronger",          effect_key="moon_phase_boost",    effect_val=0.5},
	{id="totem_of_balance",name="Totem of Balance",  type="Artifact",  rarity="rare",      emoji="⚖️", desc="If total exactly 18 → triple moondrops", effect_key="triple_chips_exact",  effect_val=18.0},
	# ── Legendary (4) ────────────────────────────────────────────
	{id="world_tree",      name="World Tree",        type="Forest",    rarity="legendary", emoji="🌳", desc="+1 star power per plant owned",              effect_key="mult_per_plant",      effect_val=1.0},
	{id="lunar_nexus",     name="Lunar Nexus",       type="Lunar",     rarity="legendary", emoji="🌕", desc="All lunar plants trigger twice",           effect_key="lunar_double_trigger",effect_val=2.0},
	{id="mycelium_godcap", name="Mycelium Godcap",   type="Fungi",     rarity="legendary", emoji="🍄", desc="Duplicates also count as unique",          effect_key="dup_as_unique",       effect_val=1.0},
	{id="garden_of_fate",  name="Garden of Fate",    type="Artifact",  rarity="legendary", emoji="🌐", desc="If roll contains 1 and 6 → double star power",effect_key="double_mult_one_six",effect_val=2.0},
]

# ── Dev Sample Data ───────────────────────────────────────────────
const DEV_SAMPLE_TASKS: Array = [
	["Drink Water",1],["Meditate",2],["Exercise",3],["Journal",2],["Read 30 Minutes",2],
	["Stretch",1],["Cold Shower",3],["Cook a Meal",2],["Study Session",4],["Clean Room",3],
	["Walk Outside",2],["Practice Skill",3],["Call Family",1],["Budget Review",3],
	["Sleep On Time",2],["No Phone Hour",2],["Meal Prep",3],["Heavy Workout",4],
	["Deep Meditation",3],["Learn Something",3],["Floss",1],
]
const DEV_SAMPLE_CURIO_CANISTERS: Array = [
	["Laundry",       0.2, "common",   "🧺"],
	["Cook Dinner",   0.3, "common",   "🍳"],
	["Make Bed",      0.1, "common",   "🛏"],
	["Wash Dishes",   0.2, "common",   "🍽"],
	["Vacuum",        0.3, "uncommon", "🌀"],
	["Grocery Run",   0.4, "uncommon", "🛒"],
	["Meal Prep",     0.5, "uncommon", "🥗"],
	["Ironing",       0.2, "common",   "👕"],
	["Take Out Trash",0.2, "common",   "🗑"],
	["Deep Clean",    0.6, "rare",     "✨"],
]
const DEV_SAMPLE_CONTRACTS := [
		{name="Doctor Appointment",      subheading="Health admin checkpoint",    difficulty="No Priority",  deadline="", subtasks="Schedule call,Prepare questions,Bring insurance card",   reward_type="minor", notes="Keep it light, but get it booked."},
		{name="Car Maintenance",         subheading="Keep the moonwagon running", difficulty="Med Priority", deadline="", subtasks="Oil change,Tire rotation,Check brakes",                  reward_type="minor", notes="Bundle errands if you need parts."},
		{name="Dentist Checkup",         subheading="Routine care before it stacks", difficulty="No Priority", deadline="", subtasks="Call to book,Floss daily beforehand",                    reward_type="minor", notes="A small prep streak makes the visit easier."},
	{name="File Taxes",              subheading="Annual paperwork gauntlet",  difficulty="High Priority", deadline="", subtasks="Gather W2s,Download software,Submit federal,Submit state", reward_type="major", notes="Do the gathering first so the filing part stays clean."},
	{name="Home Deep Clean",         subheading="Full-space reset",           difficulty="Med Priority", deadline="", subtasks="Kitchen,Bathroom,Floors,Windows",                        reward_type="minor", notes="Treat each room like its own sub-boss."},
]

# ── Runtime State ─────────────────────────────────────────────────
var current_profile: String = "Default"
var view_date:       Dictionary = {}
var dice_results:    Dictionary = {}
var dice_roll_sides: Dictionary = {}
var dice_peak_results: Dictionary = {}
var dice_satchel:  Dictionary = {8:0,10:0,12:0,20:0}
var moon_overlay_active: bool = false
var task_die_overrides: Dictionary = {}
var active_blessings: Array = []  # Track active blessings like Courage

var _tasks:  Array = []   # internal storage for tasks
var _curio_canisters: Array = []   # internal storage for curio canisters

# Public accessors with automatic state notifications.
var tasks: Array:
	get:
		return _tasks
	set(value):
		_tasks = value
		state_changed.emit()

var curio_canisters: Array:
	get:
		return _curio_canisters
	set(value):
		_curio_canisters = value
		state_changed.emit()

# GalleryTab uses "occasional_tasks" — it's the same array as curio_canisters
var occasional_tasks: Array:
	get: return curio_canisters
	set(v): curio_canisters = v

var jokers_owned:  Array = []
var plants_grown:  Array = []
var contracts:     Array = []
# Custom die face sprite paths: "sides_faceIndex" → "res://..." or "user://..."
# e.g. "6_0" = face 1 of d6 (0-indexed)
var die_face_sprites: Dictionary = {}

signal state_changed
@warning_ignore("UNUSED_SIGNAL")
signal task_rolled(task_id: int, result: int, sides: int)
@warning_ignore("UNUSED_SIGNAL")
signal score_updated(stardrops: int, star_power: float)
@warning_ignore("UNUSED_SIGNAL")
signal contract_data_changed
@warning_ignore("UNUSED_SIGNAL")
signal debug_mode_changed(enabled: bool)
@warning_ignore("UNUSED_SIGNAL")
## coins removed: use `SignalBus.moonpearls_changed` instead
@warning_ignore("UNUSED_SIGNAL")
signal water_changed(new_val: float)
@warning_ignore("UNUSED_SIGNAL")
signal meals_changed(count: int)

func _ready() -> void:
	var now := Time.get_datetime_dict_from_system()
	view_date = {year=now.year, month=now.month, day=now.day}
	apply_display_settings()
	get_tree().root.size_changed.connect(apply_ui_scale)
	
	# Load achievement progress and dice inventory
	achievement_progress = get_node("/root/Database").get_achievement_progress()
	dice_inventory = get_node("/root/Database").get_dice_inventory()
	
	# Load chocolate coins from database
	chocolate_coin_inventory = get_node("/root/Database").get_chocolate_coins()
	
	initialize_achievements()

	# Connect to progress tracking signals
	if Engine.has_singleton("SignalBus"):
		SignalBus.task_checked.connect(_on_task_checked)
		SignalBus.dice_exploded.connect(_on_dice_exploded)
		SignalBus.state_changed.emit()


func _on_task_checked(_task_id: int) -> void:
	# Track task completion progress
	update_achievement_progress("tasks_completed", 1)

func _on_dice_exploded(_task_id: int, _sides: int) -> void:
	# Track explosion progress (no longer used - cascades removed)
	# update_achievement_progress("explosions_triggered", 1)  # No longer tracking explosions
	pass

func on_special_contract_completed() -> void:
	# Track special contract completion for D20 achievement
	update_achievement_progress("special_contract", 1)


# ── Display & Audio Settings ──────────────────────────────────────
func apply_display_settings() -> void:
	# Window mode — single source of truth via "window_mode" string
	var window_mode: String = str(get_node("/root/Database").get_setting("window_mode", "windowed"))
	match window_mode:
		"maximized":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# UI scale (content_scale_factor)
	apply_ui_scale()

	# Text size bonus – stored as a base font size delta (0=normal, +2=large, -2=small)
	var text_delta: int = int(str(get_node("/root/Database").get_setting("text_size_delta", 0)))
	text_size_delta = text_delta

	# Master volume
	var master_vol: float = float(str(get_node("/root/Database").get_setting("volume_master", 1.0)))
	master_vol = clampf(master_vol, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),
		linear_to_db(master_vol))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), master_vol <= 0.0)
	# Apply mute_all override
	var mute_all: bool = get_node("/root/Database").get_bool("mute_all", false)
	if mute_all:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)

	# SFX volume – create bus if needed
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx < 0:
		AudioServer.add_bus()
		sfx_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")
	var sfx_vol: float = float(str(get_node("/root/Database").get_setting("volume_sfx", 1.0)))
	sfx_vol = clampf(sfx_vol, 0.0, 1.0)
	AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_vol))
	AudioServer.set_bus_mute(sfx_idx, sfx_vol <= 0.0)

# Reads the stored ui_scale preference and applies it as content_scale_factor.
# Also called automatically whenever the window is resized.
func apply_ui_scale() -> void:
	var ui_scale: float = float(str(get_node("/root/Database").get_setting("ui_scale", 1.0)))
	ui_scale = clampf(ui_scale, 0.5, 2.0)
	get_tree().root.content_scale_factor = ui_scale

# text_size_delta is read by UI builders to offset explicit font sizes
var text_size_delta: int = 0

# --- Tasks / Curio Canisters accessors and mutators -------------------------
func set_tasks(v: Array) -> void:
	_tasks = v.duplicate(true)
	if Engine.has_singleton("SignalBus"):
		SignalBus.state_changed.emit()

func get_tasks() -> Array:
	return _tasks

func set_curio_canisters(v: Array) -> void:
	_curio_canisters = v.duplicate(true)
	if Engine.has_singleton("SignalBus"):
		SignalBus.state_changed.emit()

func get_curio_canisters() -> Array:
	return _curio_canisters

func add_task(task: Dictionary) -> void:
	_tasks.append(task)
	if Engine.has_singleton("SignalBus"):
		SignalBus.state_changed.emit()

func remove_task_by_id(task_id: int) -> void:
	for i in range(_tasks.size() - 1, -1, -1):
		var t = _tasks[i]
		if typeof(t) == TYPE_DICTIONARY and int(t.get("id", -1)) == task_id:
			_tasks.remove_at(i)
	if Engine.has_singleton("SignalBus"):
		SignalBus.state_changed.emit()

func add_curio_canister(curio_canister: Dictionary) -> void:
	_curio_canisters.append(curio_canister)
	if Engine.has_singleton("SignalBus"):
		SignalBus.state_changed.emit()

func remove_curio_canister_by_id(curio_canister_id: int) -> void:
	for i in range(_curio_canisters.size() - 1, -1, -1):
		var r = _curio_canisters[i]
		if typeof(r) == TYPE_DICTIONARY and int(r.get("id", -1)) == curio_canister_id:
			_curio_canisters.remove_at(i)
	if Engine.has_singleton("SignalBus"):
		SignalBus.state_changed.emit()


func scaled_font_size(base: int) -> int:
	return max(6, base + text_size_delta)

# ── Moon Phase ────────────────────────────────────────────────────
func get_moon_phase(date_dict: Dictionary) -> Dictionary:
	var pos := fmod((Time.get_unix_time_from_datetime_dict(date_dict) - 947167200.0) / 86400.0, 29.53058867) / 29.53058867
	if pos < 0: pos += 1.0
	if   pos < 0.0625 or pos >= 0.9375: return {name="New Moon",       emoji="🌑",pos=pos}
	elif pos < 0.1875: return {name="Waxing Crescent",emoji="🌒",pos=pos}
	elif pos < 0.3125: return {name="First Quarter",  emoji="🌓",pos=pos}
	elif pos < 0.4375: return {name="Waxing Gibbous", emoji="🌔",pos=pos}
	elif pos < 0.5625: return {name="Full Moon",       emoji="🌕",pos=pos}
	elif pos < 0.6875: return {name="Waning Gibbous", emoji="🌖",pos=pos}
	elif pos < 0.8125: return {name="Last Quarter",   emoji="🌗",pos=pos}
	else:              return {name="Waning Crescent", emoji="🌘",pos=pos}

# ── Score ─────────────────────────────────────────────────────────
func calculate_score(rolls: Dictionary, active_curio_canisters: Array, active_jokers: Array, curio_stardrops_bonus: int = 0) -> Dictionary:
	var base_chips: int = 0
	var mult: float = 1.0
	for task_id in rolls:
		var task_data = get_task_by_id(task_id)
		var sides: int = int(task_data.get("die_sides", 6)) if task_data else 6
		var chip_val: int = rolls[task_id]
		if "mega6" in active_jokers and sides == 6: chip_val *= 2
		base_chips += chip_val
	if "jimbo" in active_jokers:
		for tid in rolls:
			if rolls[tid] == 6: base_chips += 4; break
	for curio_canister in active_curio_canisters:
		mult += curio_canister.mult
	if "galaxy" in active_jokers:
		var all_done := tasks.all(func(t): return t.completed)
		if all_done: mult *= 2.0
	if "crown" in active_jokers:
		mult += 0.5
		for t in tasks:
			if not t.completed: base_chips = max(0, base_chips - 5)
	# Add curio stardrops bonus
	base_chips += curio_stardrops_bonus
	return {stardrops=base_chips, star_power=mult, score=int(base_chips * mult), curio_stardrops_bonus=curio_stardrops_bonus}

# ── Dice Box Shop ────────────────────────────────────────────────────
func get_dice_box_shop(date_dict: Dictionary, count: int = 5) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%04d-%02d-%02d" % [date_dict.year, date_dict.month, date_dict.day] + current_profile)
	var pool := SHOP_CATALOG.duplicate()
	var result := []; var seen := {}
	while result.size() < count and pool.size() > 0:
		var idx := rng.randi() % pool.size()
		if not seen.has(pool[idx].id): seen[pool[idx].id] = true; result.append(pool[idx])
		pool.remove_at(idx)
	return result

# ── Helpers ───────────────────────────────────────────────────────
func get_task_by_id(task_id: int) -> Variant:
	for t in tasks:
		if t.id == task_id: return t
	return null

func get_date_string(date_dict: Dictionary = {}) -> String:
	if date_dict.is_empty(): date_dict = view_date
	return "%04d-%02d-%02d" % [date_dict.year, date_dict.month, date_dict.day]

func format_date_display(date_dict: Dictionary = {}) -> String:
	if date_dict.is_empty(): date_dict = view_date
	var months   := ["January","February","March","April","May","June","July","August","September","October","November","December"]
	var weekdays := ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
	var full := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict(date_dict))
	var wd: String = weekdays[full.weekday] if "weekday" in full else ""
	return "%s, %s %02d %04d" % [wd, months[date_dict.month - 1], date_dict.day, date_dict.year]

func get_deadline_color(days_left: int) -> Color:
	if days_left > 7: return Color("#A1EBAC")  # Mint green - safe
	if days_left > 3: return Color("#099EA9")  # Teal - caution
	if days_left > 1: return Color("#6F1CB2")  # Purple - warning
	return Color("#E31AE0")                     # Pink - danger

func get_deadline_bg(difficulty: String) -> Color:
	# Always theme-independent: High Priority=red, Med Priority=orange, Low/No Priority=yellow
	match difficulty:
		"High Priority": return Color(0.55, 0.04, 0.04, 0.92)   # always red
		"Med Priority":  return Color(0.55, 0.28, 0.04, 0.92)   # always orange
		"Low Priority":  return Color(0.48, 0.42, 0.04, 0.92)   # always yellow
		_:               return Color(0.48, 0.42, 0.04, 0.92)   # always yellow (No Priority)

func roll_die(sides: int) -> int:
	# Validate input
	if sides < 1:
		print("WARNING: roll_die called with invalid sides: ", sides, " - defaulting to 6")
		sides = 6
	
	var result := randi() % sides + 1
	if "luckydie" in jokers_owned: result = max(3, result)
	if "courage" in active_blessings: result = max(3, result)
	return result

func is_debug_mode() -> bool:
	return get_node("/root/Database").get_bool("debug_mode", false)

func advance_day(delta: int = 1) -> void:
	# Save current day state before moving
	_persist_current_day()
	var unix := Time.get_unix_time_from_datetime_dict(view_date) + delta * 86400
	var nd := Time.get_datetime_dict_from_unix_time(unix)
	view_date = {year=nd.year, month=nd.month, day=nd.day}

	dice_results.clear()
	dice_roll_sides.clear()
	dice_peak_results.clear()
	for t in tasks: t.completed = false
	for r in curio_canisters: r.active = false
	# Load saved state for new day if it exists
	var _key: String = "%s:%s" % [get_date_string(), current_profile]
	var rec: Variant = get_node("/root/Database").get_dice_box_stat(get_date_string(), current_profile)
	if rec != null:
		var done = str(rec.get("completed_tasks","" )).split(",", false)
		for t in tasks: t.completed = t.task in done
		for part in str(rec.get("task_rolls","" )).split("|", false):
			if part.begins_with("J:"): continue
# ... (rest of the code remains the same)
			var kv = part.split(":", false)
			if kv.size() >= 4:
				dice_results[int(kv[0])] = int(kv[1])
				dice_roll_sides[int(kv[0])] = int(kv[2])
				dice_peak_results[int(kv[0])] = int(kv[3])
			elif kv.size() == 3:
				dice_results[int(kv[0])] = int(kv[1])
				dice_roll_sides[int(kv[0])] = int(kv[2])
				dice_peak_results[int(kv[0])] = int(kv[1])
			elif kv.size() == 2:
				dice_results[int(kv[0])] = int(kv[1])
				dice_roll_sides[int(kv[0])] = 6
				dice_peak_results[int(kv[0])] = int(kv[1])
		
		# Load dice layout for the new day
		# Restore saved dice box selection (background/skin) if present
		var saved_box := str(rec.get("dice_box_tex", ""))
		if saved_box != "":
			get_node("/root/Database").save_setting("dice_table_bg_tex", saved_box)
			if has_node("/root/SignalBus"):
				SignalBus.dice_table_bg_changed.emit(saved_box)
		SignalBus.date_changed.emit(view_date)

	state_changed.emit()

func _persist_current_day(dice_layout_json: String = "") -> int:
	if dice_results.is_empty(): return 0
	print("GameData._persist_current_day: allow_next_award=", allow_next_award, "profile=", current_profile)
	var date_str: String = get_date_string()
	var rolls_parts: Array = []
	for task_id in dice_results:
		var sides = dice_roll_sides.get(task_id, 6)
		var peak = dice_peak_results.get(task_id, dice_results[task_id])
		rolls_parts.append("%d:%d:%d:%d" % [task_id, dice_results[task_id], sides, peak])
	for r in curio_canisters:
		if r.active: rolls_parts.append("J:%d" % r.id)
	var completed_names: Array = []
	for t in tasks:
		if t.completed: completed_names.append(t.task)
	var active_curio_canisters: Array = curio_canisters.filter(func(r): return r.active)
	var result: Dictionary = calculate_score(dice_results, active_curio_canisters, jokers_owned)
	# Persist roll details first, but compute previous saved score now so
	# awarding can compute a delta against the prior saved value (pre-update).
	var existing_rec = get_node("/root/Database").get_dice_box_stat(date_str, current_profile)
	var prev_saved_score: int = 0
	if existing_rec != null:
		prev_saved_score = int(existing_rec.get("total_score", 0))
	get_node("/root/Database").save_dice_box_stat(date_str, current_profile,
		"|".join(rolls_parts), ",".join(completed_names), result.score, dice_layout_json,
		str(get_node("/root/Database").get_setting("dice_table_bg_tex", "")))
	var moonpearls_delta: int = 0
	# Only award moonpearls when explicitly allowed (e.g. user pressed Roll All)
	if allow_next_award:
		# Pass previous persisted score so delta = result.score - prev_saved_score
		moonpearls_delta = get_node("/root/Database").award_dice_box_moonpearls(date_str, current_profile, result.score, prev_saved_score)
		# reset the flag so subsequent auto-saves don't award
		allow_next_award = false
		print("GameData._persist_current_day: moonpearls_delta=", moonpearls_delta)
		if moonpearls_delta > 0:
			# Database.award_dice_box_moonpearls commits the delta to the
			# canonical wallet directly (atomic). Emit score_saved for FX.
			SignalBus.score_saved.emit(result.score, moonpearls_delta)
	return moonpearls_delta


## Commit a moonpearl reward to the player's wallet in an atomic,
## canonical way. This saves economy state, triggers UI refresh, and
## emits an FX request for display-only animation (decoupled).
func commit_moonpearl_reward(amount: int) -> void:
	if amount <= 0:
		return
	# Persist to DB (this also updates earned totals and saves economy)
	get_node("/root/Database").add_moonpearls(amount, current_profile)
	# Notify GameData listeners to refresh view state
	state_changed.emit()
	# Emit canonical economy signal and a decoupled FX request
	if Engine.has_singleton("SignalBus"):
		SignalBus.moonpearls_changed.emit(get_node("/root/Database").get_moonpearls(current_profile))
		# Request a visual-only rain effect; viewers may choose to ignore.
		SignalBus.fx_rain_moonpearls.emit(amount)

func get_wallet_stats() -> Dictionary:
	var moonpearls: int = get_node("/root/Database").get_moonpearls(current_profile)
	# stardrops are transient (earned per-roll, converted to moonpearls at save).
	# They are not persisted separately — return 0 so UI shows correct balances.
	return {stardrops=0, cash=0.0, moonpearls=moonpearls}

## Coin visuals removed — Moonpearls are the canonical currency.

# ── Moonpearls sprite helpers ──────────────────────────────────────────────────────────────────────────────
# Sheet: res://assets/textures/Moonpearl_spritesheet.png  –  1332×197, 6 frames
const MOONPEARLS_SHEET_PATH := "res://assets/textures/Moonpearl_spritesheet.png"
const MOONPEARLS_FRAME_W    := 222
const MOONPEARLS_FRAME_H    := 197
const MOONPEARLS_FRAMES     := 6

## Returns HBoxContainer: [TextureRect moonpearls-icon] [Label amount-text]
func make_moonpearls_row(amount: int, font_size: int = 14, label_prefix: String = "") -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_set_random_moonpearls_frame(icon)
	hbox.add_child(icon)
	_start_icon_sparkle(icon)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.text = (label_prefix + "%s") % GardenSeedManager.format_chips(amount)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)
	return hbox

func set_moonpearls_amount(hbox: HBoxContainer, amount: int, label_prefix: String = "") -> void:
	if not is_instance_valid(hbox): return
	var lbl: Label = hbox.get_child(1) as Label
	if is_instance_valid(lbl):
		lbl.text = (label_prefix + "%s") % GardenSeedManager.format_chips(amount)

static func _set_random_moonpearls_frame(icon: TextureRect) -> void:
	if not ResourceLoader.exists(MOONPEARLS_SHEET_PATH): return
	var atlas := AtlasTexture.new()
	atlas.atlas  = load(MOONPEARLS_SHEET_PATH)
	var frame := randi() % MOONPEARLS_FRAMES
	atlas.region = Rect2(frame * MOONPEARLS_FRAME_W, 0, MOONPEARLS_FRAME_W, MOONPEARLS_FRAME_H)
	icon.texture = atlas

# ── Moondrop sprite helpers ─────────────────────────────────────────────────────────────────────────────────
# Sheet: res://assets/textures/Moondrop_spritesheet.png  –  1332×197, 6 frames
const MOONDROP_SHEET_PATH := "res://assets/textures/Moondrop_spritesheet.png"
const MOONDROP_FRAME_W    := 222
const MOONDROP_FRAME_H    := 197
const MOONDROP_FRAMES     := 6

## Returns HBoxContainer: [TextureRect moondrop-icon] [Label amount-text]
func make_moondrop_row(amount: int, font_size: int = 11, label_prefix: String = "") -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_set_random_moondrop_frame(icon)
	hbox.add_child(icon)
	_start_icon_sparkle(icon)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.text = (label_prefix + "%s") % GardenSeedManager.format_chips(amount)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)
	return hbox

func set_moondrop_amount(hbox: HBoxContainer, amount: int, label_prefix: String = "") -> void:
	if not is_instance_valid(hbox): return
	var lbl: Label = hbox.get_child(1) as Label
	if is_instance_valid(lbl):
		lbl.text = (label_prefix + "%s") % GardenSeedManager.format_chips(amount)

static func _set_random_moondrop_frame(icon: TextureRect) -> void:
	if not ResourceLoader.exists(MOONDROP_SHEET_PATH): 
		print("DEBUG: Moondrop spritesheet not found")
		return
	var atlas := AtlasTexture.new()
	atlas.atlas  = load(MOONDROP_SHEET_PATH)
	var frame := randi() % MOONDROP_FRAMES
	atlas.region = Rect2(frame * MOONDROP_FRAME_W, 0, MOONDROP_FRAME_W, MOONDROP_FRAME_H)
	icon.texture = atlas
	print("DEBUG: Moondrop frame ", frame, ", region: ", atlas.region, ", atlas size: ", str(atlas.atlas.get_size()) if atlas.atlas else "null")

## Adds a gentle looping sparkle (scale pulse + brightness flicker) to a sprite icon.
func _start_icon_sparkle(icon: TextureRect) -> void:
	# Wait until icon is in the tree before tweening
	if not icon.is_inside_tree():
		icon.tree_entered.connect(func(): _start_icon_sparkle(icon), CONNECT_ONE_SHOT)
		return
	var base_mod := icon.modulate
	var tw := icon.create_tween()
	tw.set_loops()  # loop forever
	# Gentle scale pulse
	tw.tween_property(icon, "scale", Vector2(1.08, 1.08), randf_range(1.2, 2.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(icon, "scale", Vector2(1.0,  1.0),  randf_range(1.2, 2.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Brightness flicker (separate parallel tween)
	var glow_tw := icon.create_tween()
	glow_tw.set_loops()
	var bright := Color(base_mod.r * 1.18, base_mod.g * 1.18, base_mod.b * 1.18, base_mod.a)
	glow_tw.tween_property(icon, "modulate", bright, randf_range(0.8, 1.5)).set_trans(Tween.TRANS_SINE)
	glow_tw.tween_property(icon, "modulate", base_mod, randf_range(0.8, 1.5)).set_trans(Tween.TRANS_SINE)

# ── Achievement System ─────────────────────────────────────────────────────────────────────────────────

func initialize_achievements() -> void:
	if achievements.is_empty():
		achievements = ACHIEVEMENTS.duplicate(true)
		for achievement_id in achievements:
			if not achievement_progress.has(achievement_id):
				achievement_progress[achievement_id] = {
					"completed": false,
					"progress": 0,
					"unlocked_at": null
				}

func update_achievement_progress(type: String, amount: int = 1) -> void:
	initialize_achievements()
	
	for achievement_id in achievements:
		var achievement = achievements[achievement_id]
		if achievement.requirement_type == type:
			var progress_data = achievement_progress[achievement_id]
			if not progress_data.completed:
				progress_data.progress += amount
				
				if progress_data.progress >= achievement.requirement_target:
					progress_data.completed = true
					progress_data.unlocked_at = Time.get_unix_time_from_system()
					SignalBus.achievement_unlocked.emit(achievement_id, achievement)
					get_node("/root/Database").save_achievement_progress(achievement_progress)

func check_unlock_achievement(dice_type: String) -> void:
	initialize_achievements()
	
	for achievement_id in achievements:
		var achievement = achievements[achievement_id]
		if achievement.requirement_type == "unlock" and achievement.requirement_target == dice_type:
			var progress_data = achievement_progress[achievement_id]
			if not progress_data.completed:
				progress_data.completed = true
				progress_data.unlocked_at = Time.get_unix_time_from_system()
				SignalBus.achievement_unlocked.emit(achievement_id, achievement)
				get_node("/root/Database").save_achievement_progress(achievement_progress)

func is_dice_unlocked(dice_type: String) -> bool:
	return dice_inventory.has(dice_type)

func can_unlock_dice(dice_type: String) -> bool:
	# Debug purchase override (wrench/dev mode)
	if get_node("/root/Database").get_bool("debug_purchase_enabled", false):
		return true

	if not DICE_CARVER_SHOP_ITEMS.has(dice_type):
		print("DEBUG: can_unlock_dice - dice type not found: ", dice_type)
		return false
	
	var shop_item: Dictionary = DICE_CARVER_SHOP_ITEMS[dice_type]
	var moonpearls = get_node("/root/Database").get_moonpearls(current_profile)
	
	print("DEBUG: can_unlock_dice - checking requirements for ", dice_type, " cost=", shop_item.cost, " moonpearls=", moonpearls)
	
	if moonpearls < shop_item.cost:
		print("DEBUG: can_unlock_dice - insufficient moonpearls")
		return false
	
	# Initialize achievements if not already done
	initialize_achievements()
	
	# Check requirements
	match dice_type:
		"d8":
			print("DEBUG: can_unlock_dice - d8 has no requirements")
			return true  # No requirements
		"d10":
			var d10_progress = achievement_progress.get("unlock_d10", {}).get("progress", 0)
			print("DEBUG: can_unlock_dice - d10 progress: ", d10_progress, "/10")
			return d10_progress >= 10
		"d12":
			var d12_progress = achievement_progress.get("unlock_d12", {}).get("progress", 0)
			print("DEBUG: can_unlock_dice - d12 progress: ", d12_progress, "/5")
			return d12_progress >= 5
		"d20":
			var d20_progress = achievement_progress.get("unlock_d20", {}).get("progress", 0)
			print("DEBUG: can_unlock_dice - d20 progress: ", d20_progress, "/1")
			return d20_progress >= 1
	
	print("DEBUG: can_unlock_dice - unknown dice type: ", dice_type)
	return false

func unlock_dice(dice_type: String) -> bool:
	# If debug purchase override is enabled, allow unlocking regardless of
	# requirements and do not charge moonpearls (convenience for testing).
	var debug_buy: bool = get_node("/root/Database").get_bool("debug_purchase_enabled", false)
	if not debug_buy and not can_unlock_dice(dice_type):
		return false

	var shop_item = DICE_CARVER_SHOP_ITEMS[dice_type]
	var moonpearls = get_node("/root/Database").get_moonpearls(current_profile)

	if debug_buy:
		# Force-unlock without charging
		dice_inventory[dice_type] = {
			"unlocked_at": Time.get_unix_time_from_system(),
			"uses": 0
		}
		get_node("/root/Database").save_dice_inventory(dice_inventory)
		check_unlock_achievement(dice_type)
		SignalBus.dice_unlocked.emit(dice_type)
		return true

	if moonpearls >= shop_item.cost:
		get_node("/root/Database").add_moonpearls(-shop_item.cost, current_profile)
		dice_inventory[dice_type] = {
			"unlocked_at": Time.get_unix_time_from_system(),
			"uses": 0
		}
		get_node("/root/Database").save_dice_inventory(dice_inventory)
		
		# Check for unlock achievement
		check_unlock_achievement(dice_type)
		
		SignalBus.moonpearls_changed.emit(get_node("/root/Database").get_moonpearls(current_profile))
		SignalBus.dice_unlocked.emit(dice_type)
		return true

	return false

func lock_dice(dice_type: String) -> void:
	if dice_inventory.has(dice_type):
		dice_inventory.erase(dice_type)
		get_node("/root/Database").save_dice_inventory(dice_inventory)
		SignalBus.dice_unlocked.emit(dice_type)

func unlock_all_dice() -> void:
	for dice_type in DICE_CARVER_SHOP_ITEMS.keys():
		unlock_dice(dice_type)

func lock_all_dice() -> void:
	for dice_type in DICE_CARVER_SHOP_ITEMS.keys():
		if dice_inventory.has(dice_type):
			dice_inventory.erase(dice_type)
	get_node("/root/Database").save_dice_inventory(dice_inventory)

func purchase_dice(dice_type: String, qty: int = 1) -> bool:
	# Purchase a quantity of dice and add to the player's satchel (clamped to 99).
	if qty <= 0:
		print("WARNING: purchase_dice called with invalid quantity: ", qty)
		return false
	if not DICE_CARVER_SHOP_ITEMS.has(dice_type):
		print("WARNING: purchase_dice called with invalid dice type: ", dice_type)
		return false
	
	var shop_item: Dictionary = DICE_CARVER_SHOP_ITEMS[dice_type]
	var total_cost: int = int(str(shop_item.get("cost", 0))) * qty
	var debug_buy: bool = get_node("/root/Database").get_bool("debug_purchase_enabled", false)
	if debug_buy:
		total_cost = 0
	
	print("DEBUG: purchase_dice - dice_type=", dice_type, " qty=", qty, " total_cost=", total_cost, " debug_buy=", debug_buy)
	
	# Charge player if needed
	if total_cost > 0:
		if not get_node("/root/Database").spend_moonpearls(total_cost, current_profile):
			print("WARNING: purchase_dice failed - insufficient moonpearls. Need: ", total_cost, " Have: ", get_node("/root/Database").get_moonpearls(current_profile))
			return false
	
	# Ensure permanent unlock metadata exists
	if not dice_inventory.has(dice_type):
		dice_inventory[dice_type] = {"unlocked_at": Time.get_unix_time_from_system(), "uses": 0}
		print("DEBUG: Added dice to inventory: ", dice_type)
	
	# Add physical dice to inventory/satchel
	var sides: int = 6
	# Expect dice_type like 'd8', 'd12' — parse numeric suffix
	if dice_type.length() > 1 and dice_type[0] == 'd':
		var nstr := dice_type.substr(1)
		if nstr.is_valid_int():
			sides = int(nstr)
	
	# Validate sides
	if sides < 1:
		print("WARNING: purchase_dice - invalid sides parsed: ", sides, " for type: ", dice_type)
		sides = 6
	
	print("DEBUG: Adding ", qty, " dice of sides ", sides, " to satchel")
	get_node("/root/Database").add_dice(sides, qty)
	dice_satchel[sides] = min(99, dice_satchel.get(sides, 0) + qty)
	
	# Persist dice inventory and notify
	get_node("/root/Database").save_dice_inventory(dice_inventory)
	if Engine.has_singleton("SignalBus"):
		SignalBus.moonpearls_changed.emit(get_node("/root/Database").get_moonpearls(current_profile))
		SignalBus.dice_unlocked.emit(dice_type)
		print("DEBUG: Emitted dice_unlocked signal for ", dice_type)
	else:
		print("DEBUG: SignalBus not available, cannot emit signals")
	
	state_changed.emit()
	return true

# Upgrade System Functions
func initialize_upgrades() -> void:
	if upgrades.is_empty():
		upgrades = CURIO_SHOP_UPGRADES.duplicate()
		
		# Load saved upgrade levels from database
		var saved_upgrades = get_node("/root/Database").get_upgrade_levels()
		upgrade_levels = saved_upgrades.duplicate()

func get_upgrade_level(upgrade_id: String) -> int:
	initialize_upgrades()
	return upgrade_levels.get(upgrade_id, 0)

func can_purchase_upgrade(upgrade_id: String) -> bool:
	initialize_upgrades()
	
	if not upgrades.has(upgrade_id):
		return false
	
	var upgrade = upgrades[upgrade_id]
	var current_level = get_upgrade_level(upgrade_id)
	
	if current_level >= upgrade.max_level:
		return false
	
	var moonpearls = get_node("/root/Database").get_moonpearls(current_profile)
	var cost = get_upgrade_cost(upgrade_id)
	
	return moonpearls >= cost

func get_upgrade_cost(upgrade_id: String) -> int:
	initialize_upgrades()
	
	if not upgrades.has(upgrade_id):
		return -1
	
	var upgrade = upgrades[upgrade_id]
	var current_level = get_upgrade_level(upgrade_id)
	
	if current_level >= upgrade.max_level:
		return -1
	
	return int(upgrade.base_cost * pow(upgrade.cost_multiplier, current_level))

func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_purchase_upgrade(upgrade_id):
		return false
	
	var cost = get_upgrade_cost(upgrade_id)
	var moonpearls = get_node("/root/Database").get_moonpearls(current_profile)
	
	if moonpearls >= cost:
		get_node("/root/Database").add_moonpearls(-cost, current_profile)
		
		# Increase upgrade level
		var current_level = get_upgrade_level(upgrade_id)
		upgrade_levels[upgrade_id] = current_level + 1
		
		# Save to database
		get_node("/root/Database").save_upgrade_levels(upgrade_levels)
		
		SignalBus.moonpearls_changed.emit(get_node("/root/Database").get_moonpearls(current_profile))
		SignalBus.upgrade_purchased.emit(upgrade_id, upgrade_levels[upgrade_id])
		
		return true
	
	return false

func get_upgrade_description(upgrade_id: String) -> String:
	initialize_upgrades()
	
	if not upgrades.has(upgrade_id):
		return ""
	
	var upgrade = upgrades[upgrade_id]
	var current_level = get_upgrade_level(upgrade_id)
	
	if current_level >= upgrade.max_level:
		return upgrade.effect_description + "\n\n🌟 MAX LEVEL"
	
	return upgrade.effect_description + "\n\nCurrent Level: %d/%d" % [current_level, upgrade.max_level]
