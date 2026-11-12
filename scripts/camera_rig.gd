extends Node3D
## Fixed-angle diorama camera. The rig glides after the target; the camera child
## sits at `offset` and only ever tilts to keep looking at the rig.
## Near the edges of the map the rig stops, so the view never fills with the
## forest beyond the playable area. A battle can borrow the camera with
## `focus_on()` to lean in on a spot, and hand it back with `release_focus()`.

@export var target_path: NodePath
@export var world_path: NodePath
@export var offset := Vector3(0.0, 11.0, 7.6)
@export var look_height := 0.5
@export var follow_speed := 7.0
## How quickly the camera moves between the exploring and battle framings.
@export var zoom_speed := 3.5
## How close (in tiles) the view centre may get to the map's left/right and top/bottom edges.
@export var edge_margin := Vector2(6.5, 3.0)

var _target: Node3D
var _world: Node3D
var _focused := false
var _focus_point := Vector3.ZERO
var _focus_offset := Vector3.ZERO

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_target = get_node(target_path)
	_world = get_node_or_null(world_path)
	snap()


func _process(delta: float) -> void:
	global_position = global_position.lerp(_goal(), 1.0 - exp(-follow_speed * delta))
	var wanted := _focus_offset if _focused else offset
	_camera.position = _camera.position.lerp(wanted, 1.0 - exp(-zoom_speed * delta))
	_aim()


## Lean in on `point`, with the camera at `camera_offset` from it.
func focus_on(point: Vector3, camera_offset: Vector3) -> void:
	_focused = true
	_focus_point = point
	_focus_offset = camera_offset


## Go back to following the target from the usual height.
func release_focus() -> void:
	_focused = false


## Jump straight to where the camera wants to be, with no glide.
func snap() -> void:
	global_position = _goal()
	_camera.position = _focus_offset if _focused else offset
	_aim()


func _aim() -> void:
	_camera.look_at(global_position + Vector3(0.0, look_height, 0.0))


func _goal() -> Vector3:
	if _focused:
		return _focus_point
	var goal := _target.global_position
	if _world != null:
		goal.x = clampf(goal.x, edge_margin.x, maxf(edge_margin.x, _world.width - edge_margin.x))
		goal.z = clampf(goal.z, edge_margin.y, maxf(edge_margin.y, _world.height - edge_margin.y))
	return goal
