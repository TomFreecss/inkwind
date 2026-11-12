extends Node3D
## Wild encounters, turn-based battles, capturing and the party. Battles are
## staged right in the meadow: the grass parts into a clearing, the guide
## creature hops forward, the camera leans in.
##
## Flow: a step into tall grass may call _run_encounter(), which sets the stage,
## runs _fight() (one loop iteration per round) and then _finish() cleans up.

signal battle_started
signal battle_ended(result: String)  # "won", "lost", "fled" or "caught"
## The guide was changed from the party screen.
signal party_changed

const DB := preload("res://scripts/creature_db.gd")
const Creature := preload("res://scripts/creature.gd")
const Party := preload("res://scripts/party.gd")
const Actor := preload("res://scripts/creature_actor.gd")
const BattleUI := preload("res://scripts/battle_ui.gd")
const Toon := preload("res://scripts/toon.gd")

const CLEARING_RADIUS := 2.4
## Camera position relative to the middle of the fight: low and close.
const BATTLE_CAMERA_OFFSET := Vector3(0.0, 3.3, 4.6)
const PARTNER_START_LEVEL := 5
const INK_COLOR := Color(0.13, 0.1, 0.12)
const PAPER_COLOR := Color(0.97, 0.94, 0.86)
# Order of the battle menu.
const MENU_FIGHT := 0
const MENU_SEAL := 1
const MENU_PARTY := 2
const MENU_FLEE := 3

@export var player_path: NodePath
@export var companion_path: NodePath
@export var world_path: NodePath
@export var camera_path: NodePath
@export var hud_path: NodePath
## Chance of an encounter on each step into tall grass.
@export_range(0.0, 1.0) var encounter_chance := 0.14
## Steps of peace after a battle (and at the start of the game).
@export var safe_steps := 4

## The wanderer's creatures and seals. Health carries over between battles.
var party: Party
var in_battle := false
var ui: BattleUI

var _player: Node3D
var _companion: Node3D
var _world: Node3D
var _camera: Node3D
var _active: Creature  # whoever is fighting for the player right now
var _foe: Creature
var _menu_open := false
var _starter_species := "germi"
var _steps_since_battle := 0
var _clearing_center := Vector3.ZERO
var _clearing_radius := 0.0
var _clearing_tween: Tween


func _ready() -> void:
	_player = get_node(player_path)
	_companion = get_node(companion_path)
	_world = get_node(world_path)
	_camera = get_node(camera_path)

	_starter_species = _companion.species_id
	reset_party()
	ui = BattleUI.new()
	ui.name = "BattleUI"
	get_node(hud_path).add_child(ui)

	_set_clearing_radius(0.0)
	_player.step_finished.connect(_on_player_step_finished)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"party") and not in_battle and not _menu_open \
			and _player.controls_enabled:
		get_viewport().set_input_as_handled()
		_open_party_screen()


func _on_player_step_finished(cell: Vector2i) -> void:
	if in_battle or _menu_open:
		return
	_steps_since_battle += 1
	if _steps_since_battle % 3 == 0:
		party.rest(1)  # everyone catches their breath as you walk
		sync_companion()
	if not _world.is_tall_grass(cell) or _steps_since_battle <= safe_steps:
		return
	if randf() < encounter_chance:
		_run_encounter()


## A brand-new party: just the starter creature and a full bag of seals.
func reset_party() -> void:
	party = Party.new()
	party.add(Creature.new(_starter_species, PARTNER_START_LEVEL))
	_steps_since_battle = 0


## Makes the creature walking beside the wanderer match the party: the guide,
## or the next one standing if the guide is exhausted.
func sync_companion() -> void:
	var walker := party.first_able()
	if walker == null:
		walker = party.members[0]
	if _companion.species_id != walker.species_id:
		_companion.set_species(walker.species_id)


# --- Party screen (outside battle) ----------------------------------------------------

func _open_party_screen() -> void:
	_menu_open = true
	_player.controls_enabled = false
	var pick: int = await ui.choose_member(party, "Chi cammina al tuo fianco?")
	if pick > 0:
		party.set_lead(pick)
		sync_companion()
		party_changed.emit()
	_menu_open = false
	_player.controls_enabled = true


# --- Staging ----------------------------------------------------------------------------

func _run_encounter() -> void:
	var stage := _find_stage(_player.cell, _player.facing)
	_active = party.first_able()
	if stage.is_empty() or _active == null:
		return  # nowhere to stand, or nobody to fight: let it go
	in_battle = true
	_player.controls_enabled = false
	battle_started.emit()
	sync_companion()

	var rolled := DB.roll_encounter(DB.MEADOW)
	_foe = Creature.new(rolled["species"], rolled["level"])
	var fighter_cell := stage[0]
	var wild_cell := stage[1]
	var fighter_pos: Vector3 = _world.cell_to_world(fighter_cell)
	var wild_pos: Vector3 = _world.cell_to_world(wild_cell)
	var center := (fighter_pos + wild_pos) * 0.5

	# The grass parts, the guide hops in, the camera leans in.
	_player.facing = fighter_cell - Vector2i(_player.cell)
	_animate_clearing(center, CLEARING_RADIUS, 0.5)
	_camera.focus_on(center, BATTLE_CAMERA_OFFSET)
	_companion.hop_to(fighter_cell, 0.4)
	await get_tree().create_timer(0.45).timeout
	_companion.face_cell(wild_cell)

	# The wild creature pops up.
	var wild: Actor = Actor.new()
	add_child(wild)
	wild.setup(_foe.species_id)
	wild.global_position = wild_pos
	wild.face_towards(fighter_pos)
	await wild.pop_in()

	ui.set_fighters(_active, _foe)
	ui.open()
	await ui.say("Un %s selvatico sbuca dall'erba!" % _foe.display_name())
	var result: String = await _fight(wild)
	await _finish(result, wild)


## Picks where the fighter and the wild creature stand: [fighter_cell, wild_cell].
## Empty if there is no room around `origin`.
func _find_stage(origin: Vector2i, facing: Vector2i) -> Array[Vector2i]:
	# Best: a side-on line across the screen, wanderer - fighter - wild creature.
	var sides: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT]
	if facing == Vector2i.LEFT:
		sides.reverse()
	for side in sides:
		if _world.is_walkable(origin + side) and _world.is_walkable(origin + side * 2):
			return [origin + side, origin + side * 2]
	# Otherwise any two free tiles next to each other, nearest the camera first.
	var around: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT]
	var steps: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for near in around:
		var fighter := origin + near
		if not _world.is_walkable(fighter):
			continue
		for step in steps:
			var wild := fighter + step
			if wild != origin and _world.is_walkable(wild):
				return [fighter, wild]
	return []


func _finish(result: String, wild: Actor) -> void:
	if result == "won":
		var reward := DB.xp_reward(_foe)
		var levels := _active.gain_xp(reward)
		ui.refresh()
		await ui.say("%s ottiene %d punti esperienza." % [_active.display_name(), reward])
		if levels > 0:
			ui.refresh()
			await _ally().pulse()
			await ui.say("%s sale al livello %d!" % [_active.display_name(), _active.level])
	elif result == "caught":
		party.add(_foe)
		await ui.say("%s entra nella squadra! (%d su %d)" % [
				_foe.display_name(), party.members.size(), DB.PARTY_LIMIT])
	elif result == "lost":
		await ui.say("La squadra non ce la fa più. Tornate indietro a riposare...")

	party.reset_guards()
	if result == "lost":
		# Fade to bare paper, carry everyone back to the start, fade back in.
		await ui.fade_paper(1.0, 0.6)
		ui.hide_now()
		wild.queue_free()
		party.heal_all()
		var home: Vector2i = _world.start_cell
		_player.teleport(home)
		_player.facing = Vector2i.UP
		_companion.teleport(home + Vector2i.DOWN if _world.is_walkable(home + Vector2i.DOWN) else home)
		sync_companion()
		_camera.release_focus()
		_camera.snap()
		_set_clearing_radius(0.0)
		await ui.fade_paper(0.0, 0.6)
	else:
		await ui.close()
		_camera.release_focus()
		_animate_clearing(_clearing_center, 0.0, 0.7)
		await wild.vanish()
		wild.queue_free()
		sync_companion()

	_steps_since_battle = 0
	in_battle = false
	_player.controls_enabled = true
	battle_ended.emit(result)


# --- The fight ----------------------------------------------------------------------------

## Runs rounds until the wild creature is beaten or caught, the whole party is
## exhausted, or the player gets away.
func _fight(wild: Actor) -> String:
	while true:
		var action: String = await _choose_action()
		var foe_replies := true  # the wild creature gets a turn after ours
		match action:
			"flee":
				var odds := clampf(0.6 + (_active.speed() - _foe.speed()) * 0.02, 0.3, 0.95)
				if randf() < odds:
					await ui.say("Vi allontanate di corsa!")
					return "fled"
				await ui.say("Non riuscite a scappare!")
			"seal":
				var caught: bool = await _throw_seal(wild)
				if caught:
					return "caught"
			"switch":
				pass  # the swap already happened in the menu; it costs the turn
			_:
				# A move. Faster creature strikes first; ties are a coin toss.
				foe_replies = false
				var foe_move := _foe_move()
				var ally_first := _active.speed() > _foe.speed() \
						or (_active.speed() == _foe.speed() and randf() < 0.5)
				if ally_first:
					await _use_move(_active, _foe, _ally(), wild, action, false)
					if not _foe.is_fainted():
						await _use_move(_foe, _active, wild, _ally(), foe_move, true)
				else:
					await _use_move(_foe, _active, wild, _ally(), foe_move, true)
					if not _active.is_fainted():
						await _use_move(_active, _foe, _ally(), wild, action, false)
		if foe_replies:
			await _use_move(_foe, _active, wild, _ally(), _foe_move(), true)

		if _foe.is_fainted():
			return "won"
		if _active.is_fainted():
			if not party.has_able():
				return "lost"
			await _send_replacement()
	return "fled"


## Battle menu. Returns a move id, or "flee", "seal" or "switch".
func _choose_action() -> String:
	while true:
		var options: Array[String] = ["Lotta", "Sigillo (%d)" % party.seals, "Squadra", "Fuga"]
		var pick: int = await ui.choose("Cosa fa %s?" % _active.display_name(), options)
		if pick == MENU_FLEE:
			return "flee"
		if pick == MENU_SEAL:
			var problem := _seal_problem()
			if problem == "":
				return "seal"
			if not _is_auto():
				await ui.say(problem)
				continue
			pick = MENU_FIGHT  # automated runs fall back to fighting
		if pick == MENU_PARTY and not _is_auto():
			var swapped: bool = await _switch_by_choice(true)
			if swapped:
				return "switch"
			continue

		var ids := _active.moves()
		var labels: Array[String] = []
		for id: String in ids:
			var move: Dictionary = DB.MOVES[id]
			var element: Dictionary = DB.ELEMENTS[move["element"]]
			labels.append("%s  ·  %s" % [move["name"], element["name"]])
		var move_pick: int = await ui.choose("Scegli una mossa.", labels, true)
		if move_pick >= 0:
			return ids[move_pick]
	return "flee"


## Wild creatures pick at random, skipping moves that would do nothing.
func _foe_move() -> String:
	var options: Array[String] = []
	for id: String in _foe.moves():
		var move: Dictionary = DB.MOVES[id]
		if move.has("heal") and _foe.hp > _foe.max_hp() * 0.6:
			continue
		if move.has("guard") and _foe.guard >= 2.0:
			continue
		options.append(id)
	return options[randi() % options.size()]


func _use_move(user: Creature, target: Creature, user_actor: Node3D, target_actor: Node3D,
		move_id: String, user_is_wild: bool) -> void:
	var move: Dictionary = DB.MOVES[move_id]
	var color: Color = DB.ELEMENTS[move["element"]]["color"]
	var user_name := _battle_name(user, user_is_wild)
	await ui.say("%s usa %s!" % [user_name, move["name"]])

	if move.has("heal"):
		var healed := user.heal(int(user.max_hp() * float(move["heal"])))
		_burst(user_actor.global_position + Vector3(0.0, 0.35, 0.0), color)
		ui.refresh()
		await user_actor.pulse()
		if healed > 0:
			await ui.say("%s recupera %d di vita." % [user_name, healed])
		else:
			await ui.say("Ma %s è già in piena forma." % user_name)
		return

	if move.has("guard"):
		if user.guard >= 2.0:
			await ui.say("Ma la difesa di %s non può salire ancora." % user_name)
			return
		user.guard *= float(move["guard"])
		await user_actor.pulse()
		await ui.say("La difesa di %s aumenta!" % user_name)
		return

	await user_actor.lunge()
	if randf() * 100.0 >= float(move["accuracy"]):
		await ui.say("Ma il colpo va a vuoto!")
		return

	var hit := DB.roll_damage(user, target, move)
	target.hp = maxi(target.hp - int(hit["damage"]), 0)
	_burst(target_actor.global_position + Vector3(0.0, 0.3, 0.0), color)
	ui.refresh()
	await target_actor.hurt()
	var eff: float = hit["effectiveness"]
	if eff > 1.0:
		await ui.say("L'elemento è in vantaggio: colpo pesante!")
	elif eff < 1.0:
		await ui.say("L'elemento è in svantaggio: colpo attutito.")
	if target.is_fainted():
		await target_actor.faint()
		await ui.say("%s è esausto!" % _battle_name(target, not user_is_wild))


func _battle_name(creature: Creature, is_wild: bool) -> String:
	if is_wild:
		return "%s selvatico" % creature.display_name()
	return creature.display_name()


## The actor of whoever is fighting for the player (it changes on a swap).
func _ally() -> Node3D:
	return _companion.actor


func _is_auto() -> bool:
	return ui.auto_delay >= 0.0


# --- Swapping creatures ---------------------------------------------------------------------

## Opens the party panel to pick who fights. Returns true if a swap happened.
## With `can_cancel` false (the fighter is exhausted) it insists on an answer.
func _switch_by_choice(can_cancel: bool) -> bool:
	while true:
		# Start the highlight on the first creature that could actually go in.
		var suggestion := 0
		for i in party.members.size():
			if party.members[i] != _active and not party.members[i].is_fainted():
				suggestion = i
				break
		var index: int = await ui.choose_member(
				party, "Chi mandi in campo?", can_cancel, _active, suggestion)
		if index < 0:
			return false
		var chosen := party.members[index]
		if chosen == _active and not _active.is_fainted():
			await ui.say("%s è già in campo." % chosen.display_name())
		elif chosen.is_fainted():
			await ui.say("%s è esausto e non può lottare." % chosen.display_name())
		else:
			await _swap_in(chosen)
			return true
	return false


## After the fighter is exhausted: the player picks the next one.
func _send_replacement() -> void:
	if _is_auto():
		await _swap_in(party.first_able())
	else:
		await _switch_by_choice(false)


func _swap_in(next: Creature) -> void:
	if not _active.is_fainted():
		await ui.say("%s, rientra!" % _active.display_name())
		await _ally().vanish()
	_active.guard = 1.0
	_active = next
	_companion.set_species(next.species_id)
	ui.set_fighters(_active, _foe)
	await _ally().pop_in()
	await ui.say("Tocca a %s!" % next.display_name())


# --- Capturing ----------------------------------------------------------------------------------

## Why a seal cannot be thrown right now, or "" if it can.
func _seal_problem() -> String:
	if party.seals <= 0:
		return "Non hai più sigilli."
	if not party.has_room():
		return "La squadra è al completo: non c'è posto per un'altra creatura."
	return ""


## Throws an ink seal at the wild creature. Returns true if it is caught.
func _throw_seal(wild: Actor) -> bool:
	party.seals -= 1
	await ui.say("Lanci un sigillo d'inchiostro!")

	var chance := DB.capture_chance(_foe)
	var roll := randf()
	var caught := roll < chance
	# The closer the call, the longer the seal trembles before tearing.
	var shakes := 3
	if not caught:
		var miss := roll - chance
		shakes = 2 if miss < 0.2 else (1 if miss < 0.45 else 0)

	var hand: Vector3 = _player.global_position + Vector3(0.0, 1.0, 0.0)
	var target := wild.global_position + Vector3(0.0, 0.35, 0.0)
	var seal := _make_seal()
	add_child(seal)
	seal.global_position = hand
	await _fly(seal, hand, target, 0.45, 1.1)

	# The creature is drawn into the paper in a splash of ink.
	_burst(target, INK_COLOR)
	await wild.vanish()
	var resting := wild.global_position + Vector3(0.0, 0.17, 0.0)
	var settle := create_tween()
	settle.tween_property(seal, "global_position", resting, 0.2) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await settle.finished
	for i in shakes:
		var wobble := create_tween()
		wobble.tween_property(seal, "rotation:z", 0.5, 0.09)
		wobble.tween_property(seal, "rotation:z", -0.5, 0.18)
		wobble.tween_property(seal, "rotation:z", 0.0, 0.09)
		wobble.tween_interval(0.32)
		await wobble.finished

	if caught:
		_burst(resting, PAPER_COLOR)
		await ui.say("Preso! %s si lascia ritrarre nel sigillo." % _foe.display_name())
		await _fly(seal, resting, hand, 0.4, 0.8)
		seal.queue_free()
		return true

	_burst(resting, INK_COLOR)
	seal.queue_free()
	await wild.pop_in()
	await ui.say("%s selvatico strappa il sigillo e si libera!" % _foe.display_name())
	return false


## A slip of paper with a brush stroke and a red stamp.
func _make_seal() -> Node3D:
	var seal := Node3D.new()
	seal.name = "Seal"
	var sheet := BoxMesh.new()
	sheet.size = Vector3(0.17, 0.27, 0.016)
	Toon.part(seal, sheet, Toon.material(PAPER_COLOR, true, 0.012), Vector3.ZERO)
	var stroke := BoxMesh.new()
	stroke.size = Vector3(0.045, 0.16, 0.022)
	Toon.part(seal, stroke, Toon.material(INK_COLOR, false), Vector3(-0.015, 0.02, 0.0))
	var stamp := BoxMesh.new()
	stamp.size = Vector3(0.045, 0.045, 0.022)
	Toon.part(seal, stamp, Toon.material(Color(0.82, 0.16, 0.14), false), Vector3(0.04, -0.08, 0.0))
	return seal


## Sends `node` from `from` to `to` along an arc, spinning as it goes.
func _fly(node: Node3D, from: Vector3, to: Vector3, duration: float, arc: float) -> void:
	var tween := create_tween()
	tween.tween_method(_place_on_arc.bind(node, from, to, arc), 0.0, 1.0, duration)
	await tween.finished
	node.rotation.z = 0.0


func _place_on_arc(t: float, node: Node3D, from: Vector3, to: Vector3, arc: float) -> void:
	node.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * arc
	node.rotation.z = t * TAU * 2.0


# --- Effects ----------------------------------------------------------------------------------

## A spatter of paint dabs in the given colour.
func _burst(at: Vector3, color: Color) -> void:
	var dab_mesh := SphereMesh.new()
	dab_mesh.radius = 0.07
	dab_mesh.height = 0.14
	dab_mesh.radial_segments = 8
	dab_mesh.rings = 4
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = color
	for i in 10:
		var dab := MeshInstance3D.new()
		dab.mesh = dab_mesh
		dab.material_override = paint
		dab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dab)
		dab.global_position = at
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.1, 1.0), randf_range(-1.0, 1.0)).normalized()
		var tween := dab.create_tween().set_parallel()
		tween.tween_property(dab, "global_position", at + dir * randf_range(0.35, 0.75), 0.4) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(dab, "scale", Vector3.ONE * 0.05, 0.4) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(dab.queue_free)


func _animate_clearing(center: Vector3, radius: float, duration: float) -> void:
	_clearing_center = center
	if _clearing_tween != null:
		_clearing_tween.kill()
	_clearing_tween = create_tween()
	_clearing_tween.tween_method(_set_clearing_radius, _clearing_radius, radius, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The grass, flower and tree shaders read these two globals.
func _set_clearing_radius(radius: float) -> void:
	_clearing_radius = radius
	RenderingServer.global_shader_parameter_set(&"clearing_center", _clearing_center)
	RenderingServer.global_shader_parameter_set(&"clearing_radius", radius)
