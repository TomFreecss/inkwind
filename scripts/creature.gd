extends RefCounted
## One living creature: a species from creature_db.gd plus its own level,
## health and experience.

const DB := preload("res://scripts/creature_db.gd")

var species_id := "germi"
var level := 1
var hp := 1
var xp := 0
## Temporary defence multiplier from moves like Guscio; reset after each battle.
var guard := 1.0


func _init(p_species := "germi", p_level := 1) -> void:
	species_id = p_species
	level = p_level
	hp = max_hp()


func display_name() -> String:
	return DB.SPECIES[species_id]["name"]


func element() -> String:
	return DB.SPECIES[species_id]["element"]


## Move ids, in menu order.
func moves() -> Array:
	return DB.SPECIES[species_id]["moves"]


func max_hp() -> int:
	return int(_base("hp") * (level + 8) / 22.0) + 8 + level


func attack() -> int:
	return _stat("attack")


func defense() -> int:
	return int(_stat("defense") * guard)


func speed() -> int:
	return _stat("speed")


func is_fainted() -> bool:
	return hp <= 0


## Restores up to `amount` health; returns how much was actually restored.
func heal(amount: int) -> int:
	var before := hp
	hp = mini(hp + amount, max_hp())
	return hp - before


func xp_to_next() -> int:
	return 10 + level * level * 4


## Adds experience; returns how many levels were gained. Levelling up keeps
## the health already lost but adds the new maximum's extra points.
func gain_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		var before := max_hp()
		level += 1
		hp += max_hp() - before
		gained += 1
	return gained


## What the save file remembers about this creature.
func to_data() -> Dictionary:
	return {"species": species_id, "level": level, "hp": hp, "xp": xp}


func _base(stat: String) -> int:
	return int(DB.SPECIES[species_id][stat])


func _stat(stat: String) -> int:
	return int(_base(stat) * (level + 8) / 28.0) + 4
