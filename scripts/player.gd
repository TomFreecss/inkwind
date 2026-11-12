extends Node3D
## The wanderer. Locked to the tile grid: a tap turns in place, holding a direction
## walks tile to tile, Shift runs. The node itself slides between tile centres;
## `_visual` carries the hop, lean and facing so the camera can follow smoothly.

signal step_started(from_cell: Vector2i, to_cell: Vector2i, duration: float)
signal step_finished(cell: Vector2i)

const Toon := preload("res://scripts/toon.gd")
const RIBBON_SHADER := preload("res://shaders/ribbon.gdshader")

const WALK_TIME := 0.25   ## seconds per tile
const RUN_TIME := 0.14
const TURN_DELAY := 0.1   ## hold a new direction this long before walking
const BUMP_TIME := 0.18
const VISUAL_SCALE := 1.2 ## chunky proportions read better from the high camera
const DIRECTIONS := {
	&"move_up": Vector2i(0, -1),
	&"move_down": Vector2i(0, 1),
	&"move_left": Vector2i(-1, 0),
	&"move_right": Vector2i(1, 0),
}

@export var world_path: NodePath

var cell := Vector2i.ZERO
var facing := Vector2i(0, -1)
## False while a battle owns the screen: the wanderer stands still.
var controls_enabled := true

var _world: Node3D
var _visual: Node3D
var _held: Array[Vector2i] = []  # directions currently held, most recent last
var _moving := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _progress := 0.0
var _duration := WALK_TIME
var _turn_wait := 0.0
var _bump := 0.0


func _ready() -> void:
	_world = get_node(world_path)
	cell = _world.start_cell
	position = _world.cell_to_world(cell)
	_build_visual()
	_publish_position()


func _process(delta: float) -> void:
	_update_held()
	var chained := false
	if _moving:
		_progress += delta / _duration
		if _progress >= 1.0:
			position = _to
			_moving = false
			chained = true
			step_finished.emit(cell)
		else:
			position = _from.lerp(_to, _progress)
	if not _moving:
		_idle(delta, chained)
	_animate(delta)
	_publish_position()


# --- Input ----------------------------------------------------------------------

func _update_held() -> void:
	if not controls_enabled:
		_held.clear()
		return
	for action: StringName in DIRECTIONS:
		var dir: Vector2i = DIRECTIONS[action]
		if Input.is_action_just_pressed(action):
			_held.erase(dir)
			_held.append(dir)
		elif not Input.is_action_pressed(action):
			_held.erase(dir)
		elif not _held.has(dir):
			_held.append(dir)


func _idle(delta: float, chained: bool) -> void:
	# controls_enabled can flip off mid-frame: an encounter starts the instant
	# a step finishes, before the next step would be chained.
	if not controls_enabled or _held.is_empty():
		_turn_wait = 0.0
		return
	var dir: Vector2i = _held.back()
	if dir != facing:
		facing = dir
		if not chained:
			# A quick tap only turns; keep holding to start walking.
			_turn_wait = TURN_DELAY
			return
	if _turn_wait > 0.0:
		_turn_wait -= delta
		return
	_try_step(dir)


func _try_step(dir: Vector2i) -> void:
	var target := cell + dir
	if not _world.is_walkable(target):
		if _bump <= 0.0:
			_bump = BUMP_TIME
		return
	_from = position
	_to = _world.cell_to_world(target)
	_duration = RUN_TIME if Input.is_action_pressed(&"run") else WALK_TIME
	_progress = 0.0
	_moving = true
	step_started.emit(cell, target, _duration)
	cell = target


## Places the wanderer on `target` instantly, cancelling any step in progress.
func teleport(target: Vector2i) -> void:
	cell = target
	position = _world.cell_to_world(target)
	_moving = false
	_progress = 0.0
	_publish_position()


# --- Presentation ---------------------------------------------------------------

func _animate(delta: float) -> void:
	var target_yaw := atan2(-float(facing.x), -float(facing.y))
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-18.0 * delta))

	var offset := Vector3.ZERO
	if _moving:
		offset.y = sin(_progress * PI) * 0.07  # little hop on every step
	if _bump > 0.0:
		# Nudge into the obstacle and back.
		_bump -= delta
		var push := sin(clampf(_bump / BUMP_TIME, 0.0, 1.0) * PI) * 0.08
		offset += Vector3(facing.x, 0.0, facing.y) * push
	_visual.position = offset

	var breathe := sin(Time.get_ticks_msec() * 0.003) * 0.012
	_visual.scale = Vector3(1.0 - breathe, 1.0 + breathe, 1.0 - breathe) * VISUAL_SCALE


## Grass, leaves and the tree porthole all read this global.
func _publish_position() -> void:
	RenderingServer.global_shader_parameter_set(&"player_position", global_position)


## Built from primitives so the prototype needs no imported art. Front is -Z.
func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var robe := Toon.material(Color(0.16, 0.22, 0.44))
	var skin := Toon.material(Color(0.97, 0.81, 0.67))
	var hair := Toon.material(Color(0.2, 0.13, 0.12))
	var straw := Toon.material(Color(0.88, 0.75, 0.43))
	var sash := Toon.material(Color(0.93, 0.89, 0.78), false)
	var ink := Toon.material(Color(0.1, 0.07, 0.09), false)

	var body := CapsuleMesh.new()
	body.radius = 0.2
	body.height = 0.72
	Toon.part(_visual, body, robe, Vector3(0.0, 0.44, 0.0))

	var belt := CylinderMesh.new()
	belt.top_radius = 0.205
	belt.bottom_radius = 0.205
	belt.height = 0.07
	Toon.part(_visual, belt, sash, Vector3(0.0, 0.42, 0.0))

	var head := SphereMesh.new()
	head.radius = 0.19
	head.height = 0.38
	Toon.part(_visual, head, skin, Vector3(0.0, 0.95, 0.0))
	# Hair sits back and up so the face stays visible from the front.
	Toon.part(_visual, head, hair, Vector3(0.0, 1.0, 0.045), Vector3.ZERO, Vector3(1.06, 0.95, 1.0))

	var knot := SphereMesh.new()
	knot.radius = 0.07
	knot.height = 0.14
	Toon.part(_visual, knot, hair, Vector3(0.0, 1.2, 0.06))

	var eye := SphereMesh.new()
	eye.radius = 0.028
	eye.height = 0.056
	Toon.part(_visual, eye, ink, Vector3(-0.07, 0.95, -0.172))
	Toon.part(_visual, eye, ink, Vector3(0.07, 0.95, -0.172))

	# Straw hat slung on the back, tip pointing backwards.
	var hat := CylinderMesh.new()
	hat.top_radius = 0.02
	hat.bottom_radius = 0.3
	hat.height = 0.14
	Toon.part(_visual, hat, straw, Vector3(0.0, 0.62, 0.25), Vector3(90.0, 0.0, 0.0))

	# Scarf: the shader stretches this strip downwind from the neck.
	var strip := QuadMesh.new()
	strip.subdivide_width = 12
	var scarf := MeshInstance3D.new()
	scarf.name = "Scarf"
	scarf.mesh = strip
	var scarf_material := ShaderMaterial.new()
	scarf_material.shader = RIBBON_SHADER
	scarf.material_override = scarf_material
	scarf.position = Vector3(0.0, 0.8, 0.05)
	scarf.extra_cull_margin = 4.0
	scarf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(scarf)
