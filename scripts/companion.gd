extends Node3D
## The partner creature. Out of battle it hops along one tile behind the
## wanderer: whenever the player starts a step, it moves into the tile the
## player just left. Battles borrow `actor` for the fighting animations.

const Actor := preload("res://scripts/creature_actor.gd")

@export var player_path: NodePath
@export var world_path: NodePath
## Which species from creature_db.gd this partner is.
@export var species_id := "germi"

var cell := Vector2i.ZERO
## The creature's model and battle animations (creature_actor.gd).
var actor: Node3D

var _world: Node3D
var _visual: Node3D
var _facing := Vector2i(0, -1)
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _progress := 1.0
var _duration := 0.25
var _hop_height := 0.16


func _ready() -> void:
	_world = get_node(world_path)
	var player: Node3D = get_node(player_path)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	set_species(species_id)

	var behind: Vector2i = _world.start_cell + Vector2i(0, 1)
	if _world.is_walkable(behind):
		teleport(behind)
	else:
		teleport(_world.start_cell)
	player.step_started.connect(_on_player_step_started)


func _process(delta: float) -> void:
	var hop := 0.0
	if _progress < 1.0:
		_progress = minf(_progress + delta / _duration, 1.0)
		position = _from.lerp(_to, _progress)
		hop = sin(_progress * PI) * _hop_height
	else:
		# Idle: a tiny impatient bounce.
		hop = absf(sin(Time.get_ticks_msec() * 0.0022)) * 0.025
	_visual.position.y = hop

	var target_yaw := atan2(-float(_facing.x), -float(_facing.y))
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-14.0 * delta))
	# Squash on landing, stretch at the top of the hop.
	var stretch := 1.0 + hop * 0.9
	_visual.scale = Vector3(1.0 / sqrt(stretch), stretch, 1.0 / sqrt(stretch)) * 1.2


## Swaps the creature walking here for another species (when the guide changes
## or a different creature is sent into battle).
func set_species(id: String) -> void:
	species_id = id
	if actor != null:
		_visual.remove_child(actor)
		actor.queue_free()
	actor = Actor.new()
	actor.idle_bob = false
	_visual.add_child(actor)
	actor.setup(id)


## Jumps to `target` over `duration` seconds, however far it is.
func hop_to(target: Vector2i, duration: float) -> void:
	if target == cell:
		return
	face_cell(target)
	_hop_height = 0.06 + 0.1 * Vector2(target - cell).length()
	_from = position
	_to = _world.cell_to_world(target)
	_progress = 0.0
	_duration = duration
	cell = target


## Turns towards `target` (snapped to the nearest of the four directions).
func face_cell(target: Vector2i) -> void:
	var step := target - cell
	if step == Vector2i.ZERO:
		return
	if absi(step.x) >= absi(step.y):
		_facing = Vector2i(signi(step.x), 0)
	else:
		_facing = Vector2i(0, signi(step.y))


## Places the partner on `target` instantly.
func teleport(target: Vector2i) -> void:
	cell = target
	position = _world.cell_to_world(target)
	_from = position
	_to = position
	_progress = 1.0


func _on_player_step_started(from_cell: Vector2i, _to_cell: Vector2i, duration: float) -> void:
	hop_to(from_cell, duration)
