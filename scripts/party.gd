extends RefCounted
## The wanderer's creatures and ink seals. The first member is the guide: it
## walks beside the wanderer and steps into battle first.

const DB := preload("res://scripts/creature_db.gd")
const Creature := preload("res://scripts/creature.gd")

var members: Array[Creature] = []
var seals: int = DB.STARTING_SEALS


func has_room() -> bool:
	return members.size() < DB.PARTY_LIMIT


## Adds a creature if there is room. Returns whether it joined.
func add(creature: Creature) -> bool:
	if not has_room():
		return false
	members.append(creature)
	return true


## The first member still able to fight (the guide, if it is standing), or null.
func first_able() -> Creature:
	for member in members:
		if not member.is_fainted():
			return member
	return null


func has_able() -> bool:
	return first_able() != null


## Makes the member at `index` the guide by swapping it into first place.
func set_lead(index: int) -> void:
	if index <= 0 or index >= members.size():
		return
	var previous := members[0]
	members[0] = members[index]
	members[index] = previous


## Everyone recovers a little; even an exhausted creature gets back up.
func rest(amount: int) -> void:
	for member in members:
		member.heal(amount)


func heal_all() -> void:
	for member in members:
		member.hp = member.max_hp()


## Battle-only boosts wear off.
func reset_guards() -> void:
	for member in members:
		member.guard = 1.0


## What the save file remembers about the party.
func to_data() -> Dictionary:
	var list: Array[Dictionary] = []
	for member in members:
		list.append(member.to_data())
	return {"seals": seals, "members": list}


## Rebuilds the party from saved data, ignoring anything that does not make
## sense (unknown species, impossible numbers). Returns false, leaving the
## party untouched, if no valid creature is found.
func load_data(data: Dictionary) -> bool:
	var saved_members: Variant = data.get("members")
	if not saved_members is Array:
		return false
	var loaded: Array[Creature] = []
	for entry: Variant in saved_members:
		if not entry is Dictionary:
			continue
		var species := str(entry.get("species", ""))
		if not DB.SPECIES.has(species):
			continue
		var creature := Creature.new(species, maxi(int(entry.get("level", 1)), 1))
		creature.hp = clampi(int(entry.get("hp", creature.max_hp())), 0, creature.max_hp())
		creature.xp = clampi(int(entry.get("xp", 0)), 0, creature.xp_to_next() - 1)
		loaded.append(creature)
		if loaded.size() >= DB.PARTY_LIMIT:
			break
	if loaded.is_empty():
		return false
	members = loaded
	seals = maxi(int(data.get("seals", DB.STARTING_SEALS)), 0)
	return true
