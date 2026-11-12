extends RefCounted
## Every creature, move and battle rule in the game, in one place.
## All of it is original content: edit the tables to add species or rebalance.

## Elements. "comune" is neutral: it has no strengths or weaknesses.
const ELEMENTS := {
	"comune": {"name": "Comune", "color": Color(0.74, 0.69, 0.6)},
	"radice": {"name": "Radice", "color": Color(0.4, 0.68, 0.3)},
	"pietra": {"name": "Pietra", "color": Color(0.6, 0.6, 0.66)},
	"vento": {"name": "Vento", "color": Color(0.62, 0.85, 0.9)},
	"pioggia": {"name": "Pioggia", "color": Color(0.3, 0.54, 0.88)},
	"brace": {"name": "Brace", "color": Color(0.96, 0.47, 0.16)},
}

## Each element overpowers exactly one other, in a five-step ring:
## embers burn roots, roots split stone, stone stops wind,
## wind scatters rain, rain douses embers.
const BEATS := {
	"brace": "radice",
	"radice": "pietra",
	"pietra": "vento",
	"vento": "pioggia",
	"pioggia": "brace",
}
const STRONG := 1.5
const WEAK := 0.67
## Bonus when a creature uses a move of its own element.
const AFFINITY := 1.2

## How many creatures can travel with the wanderer.
const PARTY_LIMIT := 4
## Ink seals in the bag at the start: paper slips that capture a creature's portrait.
const STARTING_SEALS := 6

## A move has either "power" + "accuracy" (an attack), "heal" (fraction of max
## health restored) or "guard" (defence multiplier for the rest of the battle).
const MOVES := {
	"colpetto": {"name": "Colpetto", "element": "comune", "power": 35, "accuracy": 100},
	"radicata": {"name": "Radicata", "element": "radice", "power": 45, "accuracy": 95},
	"linfa": {"name": "Linfa", "element": "radice", "heal": 0.35},
	"sassata": {"name": "Sassata", "element": "pietra", "power": 45, "accuracy": 90},
	"guscio": {"name": "Guscio", "element": "pietra", "guard": 1.5},
	"raffica": {"name": "Raffica", "element": "vento", "power": 40, "accuracy": 100},
	"mulinello": {"name": "Mulinello", "element": "vento", "power": 60, "accuracy": 80},
	"scintilla": {"name": "Scintilla", "element": "brace", "power": 45, "accuracy": 95},
	"vampa": {"name": "Vampa", "element": "brace", "power": 60, "accuracy": 80},
	"schizzo": {"name": "Schizzo", "element": "pioggia", "power": 45, "accuracy": 95},
	"acquazzone": {"name": "Acquazzone", "element": "pioggia", "power": 60, "accuracy": 80},
}

## Base stats are on a rough 30-70 scale; creature.gd turns them into real
## numbers for a given level. Looks are built in creature_visual.gd.
const SPECIES := {
	"germi": {
		"name": "Germì", "element": "radice",
		"hp": 52, "attack": 48, "defense": 46, "speed": 50,
		"moves": ["colpetto", "radicata", "linfa"], "xp_yield": 14,
	},
	"sassotto": {
		"name": "Sassotto", "element": "pietra",
		"hp": 50, "attack": 44, "defense": 60, "speed": 28,
		"moves": ["colpetto", "sassata", "guscio"], "xp_yield": 14,
	},
	"soffietto": {
		"name": "Soffietto", "element": "vento",
		"hp": 38, "attack": 46, "defense": 36, "speed": 66,
		"moves": ["colpetto", "raffica", "mulinello"], "xp_yield": 13,
	},
	"bracino": {
		"name": "Bracino", "element": "brace",
		"hp": 40, "attack": 48, "defense": 38, "speed": 54,
		"moves": ["colpetto", "scintilla", "vampa"], "xp_yield": 16,
	},
	"gocciolo": {
		"name": "Gocciolo", "element": "pioggia",
		"hp": 48, "attack": 44, "defense": 48, "speed": 44,
		"moves": ["colpetto", "schizzo", "acquazzone"], "xp_yield": 14,
	},
}

## Who lives in the meadow's tall grass. "weight" is relative likelihood.
const MEADOW := [
	{"species": "sassotto", "weight": 30, "levels": [2, 4]},
	{"species": "soffietto", "weight": 30, "levels": [2, 4]},
	{"species": "gocciolo", "weight": 25, "levels": [2, 4]},
	{"species": "bracino", "weight": 15, "levels": [2, 3]},
]


## Damage multiplier for a move of `move_element` hitting a `target_element` creature.
static func effectiveness(move_element: String, target_element: String) -> float:
	if BEATS.get(move_element, "") == target_element:
		return STRONG
	if BEATS.get(target_element, "") == move_element:
		return WEAK
	return 1.0


## Rolls one hit. `attacker` and `defender` are creature.gd instances.
## Returns {"damage": int, "effectiveness": float}.
static func roll_damage(attacker, defender, move: Dictionary) -> Dictionary:
	var move_element: String = move["element"]
	var eff := effectiveness(move_element, defender.element())
	var affinity: float = AFFINITY if move_element == attacker.element() else 1.0
	var base: float = float(move["power"]) * float(attacker.attack()) / float(defender.defense())
	var level_scale: float = 0.18 + float(attacker.level) * 0.025
	var damage := int(base * level_scale * eff * affinity * randf_range(0.85, 1.0))
	return {"damage": maxi(damage, 1), "effectiveness": eff}


## Picks a wild creature from an encounter table. Returns {"species", "level"}.
static func roll_encounter(table: Array) -> Dictionary:
	var total := 0
	for entry: Dictionary in table:
		total += int(entry["weight"])
	var pick := randi_range(1, total)
	for entry: Dictionary in table:
		pick -= int(entry["weight"])
		if pick <= 0:
			var levels: Array = entry["levels"]
			return {"species": entry["species"], "level": randi_range(levels[0], levels[1])}
	return {"species": table[0]["species"], "level": 2}


## Chance (0..1) that an ink seal holds `target` (a creature.gd instance).
## A fresh creature tears free most of the time; a worn-out one rarely does.
static func capture_chance(target) -> float:
	var health: float = float(target.hp) / float(target.max_hp())
	return clampf(0.3 + 0.6 * (1.0 - health), 0.1, 0.92)


## Experience earned for defeating `defeated` (a creature.gd instance).
static func xp_reward(defeated) -> int:
	var yield_value: int = SPECIES[defeated.species_id]["xp_yield"]
	return int(yield_value * float(defeated.level) * 0.5) + 4
