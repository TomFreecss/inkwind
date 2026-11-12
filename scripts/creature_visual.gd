extends RefCounted
## Builds each species' look out of primitives, so the prototype needs no
## imported art. Front is -Z, feet on y = 0. Every design here is original.

const Toon := preload("res://scripts/toon.gd")


static func build(species_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	match species_id:
		"sassotto":
			_sassotto(root)
		"soffietto":
			_soffietto(root)
		"bracino":
			_bracino(root)
		"gocciolo":
			_gocciolo(root)
		_:
			_germi(root)
	return root


## Germì: round cream body, russet ears and tail, a leaf sprouting from its head.
static func _germi(root: Node3D) -> void:
	var cream := Toon.material(Color(0.98, 0.93, 0.8))
	var russet := Toon.material(Color(0.86, 0.45, 0.24))
	var leaf := Toon.material(Color(0.36, 0.68, 0.3))
	var ball := _ball()
	Toon.part(root, ball, cream, Vector3(0.0, 0.19, 0.0), Vector3.ZERO, Vector3(0.42, 0.36, 0.46))
	Toon.part(root, ball, russet, Vector3(0.0, 0.2, 0.25), Vector3.ZERO, Vector3(0.17, 0.17, 0.2))
	Toon.part(root, ball, leaf, Vector3(0.0, 0.43, 0.03), Vector3(-25.0, 0.0, 0.0), Vector3(0.13, 0.035, 0.26))
	var ear := _cone(0.065, 0.17)
	Toon.part(root, ear, russet, Vector3(-0.11, 0.39, -0.02), Vector3(0.0, 0.0, 22.0))
	Toon.part(root, ear, russet, Vector3(0.11, 0.39, -0.02), Vector3(0.0, 0.0, -22.0))
	_eyes(root, 0.23, -0.215, 0.075)


## Sassotto: a faceted boulder on two stubby feet, wearing a cap of moss.
static func _sassotto(root: Node3D) -> void:
	var stone := Toon.material(Color(0.62, 0.62, 0.68), true, 0.026)
	var dark_stone := Toon.material(Color(0.43, 0.43, 0.52))
	var moss := Toon.material(Color(0.42, 0.62, 0.3))
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 8
	rock.rings = 4
	Toon.part(root, rock, stone, Vector3(0.0, 0.25, 0.0), Vector3(0.0, 22.0, 0.0), Vector3(0.56, 0.46, 0.5))
	Toon.part(root, _ball(), moss, Vector3(0.02, 0.44, 0.03), Vector3(0.0, 0.0, -8.0), Vector3(0.4, 0.14, 0.36))
	Toon.part(root, rock, dark_stone, Vector3(-0.17, 0.07, -0.1), Vector3.ZERO, Vector3(0.19, 0.14, 0.22))
	Toon.part(root, rock, dark_stone, Vector3(0.17, 0.07, -0.1), Vector3.ZERO, Vector3(0.19, 0.14, 0.22))
	_eyes(root, 0.27, -0.24, 0.09)


## Soffietto: a hovering puff of cloud trailing a curl of wind.
static func _soffietto(root: Node3D) -> void:
	var cloud := Toon.material(Color(0.94, 0.97, 0.99))
	var shade := Toon.material(Color(0.68, 0.84, 0.93))
	var ball := _ball()
	Toon.part(root, ball, cloud, Vector3(0.0, 0.5, 0.0), Vector3.ZERO, Vector3(0.44, 0.38, 0.42))
	Toon.part(root, ball, cloud, Vector3(-0.2, 0.44, 0.04), Vector3.ZERO, Vector3(0.28, 0.26, 0.28))
	Toon.part(root, ball, cloud, Vector3(0.2, 0.45, 0.05), Vector3.ZERO, Vector3(0.3, 0.27, 0.3))
	Toon.part(root, ball, cloud, Vector3(0.02, 0.66, 0.02), Vector3.ZERO, Vector3(0.26, 0.22, 0.26))
	Toon.part(root, ball, shade, Vector3(0.0, 0.36, 0.28), Vector3.ZERO, Vector3(0.18, 0.16, 0.18))
	Toon.part(root, ball, shade, Vector3(0.06, 0.25, 0.4), Vector3.ZERO, Vector3(0.11, 0.1, 0.11))
	_eyes(root, 0.5, -0.2, 0.08)


## Bracino: a glowing ember with a flame for a crest and coal-black feet.
static func _bracino(root: Node3D) -> void:
	var ember := Toon.material(Color(0.95, 0.42, 0.14))
	var glow := Toon.material(Color(1.0, 0.8, 0.3))
	var coal := Toon.material(Color(0.3, 0.2, 0.2))
	var ball := _ball()
	Toon.part(root, ball, ember, Vector3(0.0, 0.24, 0.0), Vector3.ZERO, Vector3(0.4, 0.4, 0.4))
	Toon.part(root, _cone(0.15, 0.3), ember, Vector3(0.0, 0.52, 0.03), Vector3(10.0, 0.0, 0.0))
	Toon.part(root, _cone(0.075, 0.17), glow, Vector3(0.0, 0.5, -0.08), Vector3(-12.0, 0.0, 0.0))
	Toon.part(root, ball, glow, Vector3(0.0, 0.2, -0.1), Vector3.ZERO, Vector3(0.26, 0.24, 0.22))
	Toon.part(root, ball, coal, Vector3(-0.11, 0.05, -0.02), Vector3.ZERO, Vector3(0.14, 0.1, 0.17))
	Toon.part(root, ball, coal, Vector3(0.11, 0.05, -0.02), Vector3.ZERO, Vector3(0.14, 0.1, 0.17))
	_eyes(root, 0.31, -0.19, 0.075)


## Gocciolo: a raindrop with a pale belly and a little tail fin.
static func _gocciolo(root: Node3D) -> void:
	var water := Toon.material(Color(0.3, 0.56, 0.9))
	var pale := Toon.material(Color(0.74, 0.89, 0.98))
	var ball := _ball()
	Toon.part(root, ball, water, Vector3(0.0, 0.21, 0.0), Vector3.ZERO, Vector3(0.42, 0.4, 0.42))
	Toon.part(root, _cone(0.14, 0.27), water, Vector3(0.0, 0.47, 0.0))
	Toon.part(root, ball, pale, Vector3(0.0, 0.15, -0.09), Vector3.ZERO, Vector3(0.3, 0.24, 0.26))
	Toon.part(root, ball, water, Vector3(0.0, 0.22, 0.27), Vector3.ZERO, Vector3(0.06, 0.22, 0.2))
	_eyes(root, 0.29, -0.2, 0.08)


# --- Shared parts ---------------------------------------------------------------

## Unit-diameter smooth sphere; parts scale it into bodies, bellies and tails.
static func _ball() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 10
	return mesh


static func _cone(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return mesh


## Two ink-dot eyes at height `y`, on the front surface at depth `z`.
static func _eyes(root: Node3D, y: float, z: float, half_gap: float) -> void:
	var ink := Toon.material(Color(0.1, 0.07, 0.09), false)
	var ball := _ball()
	Toon.part(root, ball, ink, Vector3(-half_gap, y, z), Vector3.ZERO, Vector3(0.055, 0.065, 0.04))
	Toon.part(root, ball, ink, Vector3(half_gap, y, z), Vector3.ZERO, Vector3(0.055, 0.065, 0.04))
