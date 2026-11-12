extends RefCounted
## Builds the village's buildings and street furniture out of code-made shapes,
## so the prototype needs no imported art. Every design here is original: a
## hamlet of ink makers, with plaster houses under barrel roofs that carry a
## rolled scroll along the ridge, a windmill with paper sails, the seal
## workshop and the rest house.
##
## Each builder returns a Node3D whose origin is the centre of the footprint at
## ground level. The front (the door side) faces +Z: south, towards the camera.
## Parts are made at their real size rather than scaled, so pencil outlines
## keep an even thickness.

const Toon := preload("res://scripts/toon.gd")
const Sails := preload("res://scripts/windmill_sails.gd")

const PLASTER := Color(0.97, 0.93, 0.83)
const PAPER := Color(0.99, 0.96, 0.88)
const TIMBER := Color(0.58, 0.41, 0.29)
const STONE := Color(0.76, 0.75, 0.78)
const INDIGO := Color(0.32, 0.38, 0.62)
const MOSS := Color(0.47, 0.64, 0.38)
const OCHRE := Color(0.92, 0.66, 0.32)
const ROSE := Color(0.88, 0.48, 0.44)
const VERMILION := Color(0.88, 0.33, 0.26)
const INK_BLACK := Color(0.24, 0.23, 0.33)
const GLOW := Color(1.0, 0.86, 0.48)
const WATER := Color(0.38, 0.68, 0.8)

## Buildings are modelled small and then enlarged by this much, so one number
## sets how they stand next to the wanderer. Their footprints on the map
## (world.gd) must be big enough for the result. Street furniture is not scaled.
const BUILDING_SCALE := 2.0

static var _materials := {}
# Outline widths are multiplied by this. While a building is being made it is
# 1 / BUILDING_SCALE, so that the lines end up no thicker than anyone else's
# once the building is enlarged.
static var _line_scale := 1.0


# --- Buildings ------------------------------------------------------------------

## Round tapered tower, conical cap, four paper sails turning on the south face.
## Footprint 3x3.
static func windmill() -> Node3D:
	var root := _begin_building("Windmill")
	# Set back a little, so the turning sails stay inside the footprint.
	var back := -0.12
	Toon.part(root, _cylinder(0.72, 1.05, 2.5, 22), _mat(PLASTER, 0.035), Vector3(0.0, 1.25, back))
	Toon.part(root, _cylinder(0.78, 0.82, 0.16, 22), _mat(TIMBER, 0.025), Vector3(0.0, 2.44, back))
	Toon.part(root, _cylinder(0.06, 0.94, 0.85, 22), _mat(INDIGO, 0.035), Vector3(0.0, 2.94, back))
	_door(root, Vector3(0.0, 0.0, back + 1.02))
	_window(root, Vector3(0.0, 1.35, back + 0.86))

	var sails := Node3D.new()
	sails.name = "Sails"
	sails.set_script(Sails)
	sails.position = Vector3(0.0, 2.1, back + 1.08)
	sails.rotation_degrees.z = 20.0
	root.add_child(sails)
	Toon.part(sails, _ball(0.17, 0.3), _mat(TIMBER, 0.02), Vector3.ZERO)
	var arm := _rounded_box(Vector3(0.09, 1.5, 0.07), 4.0, 10, 6)
	var cloth := _rounded_box(Vector3(0.42, 1.08, 0.04), 4.0, 12, 6)
	for i in 4:
		var spoke := Node3D.new()
		spoke.rotation_degrees.z = 90.0 * i
		sails.add_child(spoke)
		Toon.part(spoke, arm, _mat(TIMBER, 0.02), Vector3(0.0, 0.78, 0.0))
		Toon.part(spoke, cloth, _mat(PAPER, 0.02), Vector3(0.25, 0.92, 0.0))
	return _finish_building(root)


## Where ink seals are made: indigo roof, a round seal sign on a post, ink jars
## by the door. Footprint 3x2.
static func workshop() -> Node3D:
	var root := _begin_building("SealWorkshop")
	_house(root, Vector3(2.6, 1.3, 1.5), INDIGO, 0.0, [-0.85, 0.85])

	# The sign: a vermilion seal with its mark left in bare paper.
	Toon.part(root, _cylinder(0.045, 0.055, 1.25, 8), _mat(TIMBER, 0.018), Vector3(1.12, 0.62, 0.86))
	Toon.part(root, _cylinder(0.26, 0.26, 0.07, 18), _mat(VERMILION, 0.025),
			Vector3(1.12, 1.3, 0.86), Vector3(90.0, 0.0, 0.0))
	Toon.part(root, _rounded_box(Vector3(0.2, 0.2, 0.05), 5.0, 10, 6), _mat(PAPER, 0.0),
			Vector3(1.12, 1.3, 0.9))

	# Ink jars: dark bellies, pale lids.
	for spot: Vector3 in [Vector3(-1.1, 0.0, 0.84), Vector3(-0.76, 0.0, 0.88)]:
		Toon.part(root, _ball(0.16, 0.3), _mat(INK_BLACK, 0.02), spot + Vector3(0.0, 0.15, 0.0))
		Toon.part(root, _cylinder(0.09, 0.1, 0.05, 12), _mat(PAPER, 0.015), spot + Vector3(0.0, 0.31, 0.0))
	return _finish_building(root)


## A place to rest: rose roof, a chimney, a paper lantern and a log bench.
## Footprint 3x2.
static func rest_house() -> Node3D:
	var root := _begin_building("RestHouse")
	_house(root, Vector3(2.6, 1.3, 1.5), ROSE, 0.35, [-0.75])
	Toon.part(root, _cylinder(0.16, 0.19, 0.6, 12), _mat(STONE, 0.025), Vector3(-0.75, 2.15, -0.25))

	# Lantern on a post.
	Toon.part(root, _cylinder(0.045, 0.055, 1.2, 8), _mat(TIMBER, 0.018), Vector3(1.15, 0.6, 0.86))
	Toon.part(root, _ball(0.15, 0.34), _mat(GLOW, 0.02), Vector3(1.15, 1.32, 0.86))
	Toon.part(root, _cylinder(0.08, 0.08, 0.04, 10), _mat(TIMBER, 0.012), Vector3(1.15, 1.5, 0.86))
	Toon.part(root, _cylinder(0.08, 0.08, 0.04, 10), _mat(TIMBER, 0.012), Vector3(1.15, 1.14, 0.86))

	# Bench: a split log on two stubs.
	Toon.part(root, _cylinder(0.09, 0.09, 0.78, 10), _mat(TIMBER, 0.02),
			Vector3(-0.72, 0.24, 0.87), Vector3(0.0, 0.0, 90.0))
	for x: float in [-0.98, -0.46]:
		Toon.part(root, _cylinder(0.06, 0.07, 0.2, 8), _mat(TIMBER, 0.015), Vector3(x, 0.1, 0.87))
	return _finish_building(root)


## A small home with a flower box under its window. `variant` picks the roof
## colour and which side the door is on. Footprint 2x2.
static func cottage(variant: int) -> Node3D:
	var root := _begin_building("Cottage")
	var roofs: Array[Color] = [MOSS, OCHRE, INDIGO]
	var flip := -1.0 if variant % 2 == 0 else 1.0
	_house(root, Vector3(1.7, 1.15, 1.4), roofs[variant % roofs.size()], 0.38 * flip, [-0.38 * flip])

	Toon.part(root, _rounded_box(Vector3(0.44, 0.1, 0.13), 4.0, 10, 6), _mat(TIMBER, 0.015),
			Vector3(-0.38 * flip, 0.3, 0.66))
	var bloom := _ball(0.05, 0.1)
	var colors: Array[Color] = [ROSE, GLOW, PAPER]
	for i in 3:
		Toon.part(root, bloom, _mat(colors[(variant + i) % colors.size()], 0.01),
				Vector3(-0.38 * flip + (i - 1) * 0.13, 0.38, 0.67))
	return _finish_building(root)


# --- Street furniture -----------------------------------------------------------

## A paper board on a post, with two brushed lines of writing.
static func signpost() -> Node3D:
	var root := Node3D.new()
	root.name = "Signpost"
	Toon.part(root, _cylinder(0.05, 0.06, 0.95, 8), _mat(TIMBER, 0.018), Vector3(0.0, 0.47, 0.0))
	Toon.part(root, _rounded_box(Vector3(0.72, 0.36, 0.07), 5.0, 12, 6), _mat(PAPER, 0.022),
			Vector3(0.0, 0.92, 0.04))
	var stroke := _rounded_box(Vector3(0.44, 0.045, 0.03), 3.0, 8, 4)
	Toon.part(root, stroke, _mat(INK_BLACK, 0.0), Vector3(-0.04, 0.98, 0.08))
	Toon.part(root, stroke, _mat(INK_BLACK, 0.0), Vector3(0.05, 0.87, 0.08))
	return root


## A stone ring of water with a bucket hanging from a crossbar.
static func well() -> Node3D:
	var root := Node3D.new()
	root.name = "Well"
	Toon.part(root, _cylinder(0.4, 0.44, 0.4, 16), _mat(STONE, 0.028), Vector3(0.0, 0.2, 0.0))
	Toon.part(root, _cylinder(0.31, 0.31, 0.02, 16), _mat(WATER, 0.0), Vector3(0.0, 0.405, 0.0))
	for x: float in [-0.4, 0.4]:
		Toon.part(root, _cylinder(0.045, 0.055, 1.05, 8), _mat(TIMBER, 0.018), Vector3(x, 0.52, 0.0))
	Toon.part(root, _cylinder(0.04, 0.04, 0.98, 8), _mat(TIMBER, 0.018),
			Vector3(0.0, 1.03, 0.0), Vector3(0.0, 0.0, 90.0))
	Toon.part(root, _cylinder(0.012, 0.012, 0.3, 6), _mat(TIMBER, 0.0), Vector3(0.08, 0.86, 0.0))
	Toon.part(root, _cylinder(0.09, 0.07, 0.15, 10), _mat(TIMBER, 0.018), Vector3(0.08, 0.66, 0.0))
	return root


## Freshly made sheets of paper hung out to dry on a line.
static func drying_rack() -> Node3D:
	var root := Node3D.new()
	root.name = "DryingRack"
	for x: float in [-0.4, 0.4]:
		Toon.part(root, _cylinder(0.04, 0.05, 1.05, 8), _mat(TIMBER, 0.018), Vector3(x, 0.52, 0.0))
	Toon.part(root, _cylinder(0.015, 0.015, 0.84, 6), _mat(TIMBER, 0.0),
			Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 90.0))
	var sheet := _rounded_box(Vector3(0.2, 0.36, 0.025), 4.0, 10, 6)
	var lean := [-7.0, 4.0, -3.0]
	for i in 3:
		Toon.part(root, sheet, _mat(PAPER, 0.016), Vector3((i - 1) * 0.25, 0.8, 0.0),
				Vector3(0.0, 0.0, lean[i]))
	return root


# --- Shared parts ---------------------------------------------------------------

## Plaster walls under a barrel roof that runs east-west, with a rolled scroll
## along the ridge. `size` is the walls' width, height and depth; the house sits
## a little back from the centre of its footprint to leave a doorstep. `door_x`
## and `windows` are positions along the south wall.
static func _house(root: Node3D, size: Vector3, roof_color: Color, door_x: float,
		windows: Array) -> void:
	var back := -0.1
	Toon.part(root, _rounded_box(size, 6.0), _mat(PLASTER, 0.035), Vector3(0.0, size.y * 0.5, back))

	# The roof is a whole cylinder sunk into the walls: only its upper half and
	# a rolled eave show.
	var radius := size.z * 0.5 + 0.1
	var length := size.x + 0.36
	var roof_y := size.y - 0.1
	Toon.part(root, _cylinder(radius, radius, length, 26), _mat(roof_color, 0.035),
			Vector3(0.0, roof_y, back), Vector3(0.0, 0.0, 90.0))
	var ridge_y := roof_y + radius + 0.02
	Toon.part(root, _cylinder(0.12, 0.12, length + 0.14, 12), _mat(PAPER, 0.022),
			Vector3(0.0, ridge_y, back), Vector3(0.0, 0.0, 90.0))
	for side: float in [-1.0, 1.0]:
		Toon.part(root, _ball(0.09, 0.18), _mat(TIMBER, 0.015),
				Vector3(side * (length * 0.5 + 0.1), ridge_y, back))

	var front := back + size.z * 0.5
	_door(root, Vector3(door_x, 0.0, front))
	for x: float in windows:
		_window(root, Vector3(x, 0.5, front))


static func _door(root: Node3D, at: Vector3) -> void:
	Toon.part(root, _rounded_box(Vector3(0.5, 0.78, 0.1), 5.0, 12, 6), _mat(TIMBER, 0.022),
			at + Vector3(0.0, 0.39, 0.0))
	Toon.part(root, _ball(0.035, 0.07), _mat(GLOW, 0.0), at + Vector3(0.14, 0.38, 0.06))


static func _window(root: Node3D, at: Vector3) -> void:
	Toon.part(root, _rounded_box(Vector3(0.4, 0.4, 0.08), 5.0, 10, 6), _mat(TIMBER, 0.018), at)
	Toon.part(root, _rounded_box(Vector3(0.27, 0.27, 0.05), 5.0, 10, 6), _mat(GLOW, 0.0),
			at + Vector3(0.0, 0.0, 0.035))


## Every building starts and ends with these two: outlines are thinned while it
## is modelled, then the whole thing is enlarged.
static func _begin_building(node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	_line_scale = 1.0 / BUILDING_SCALE
	return root


static func _finish_building(root: Node3D) -> Node3D:
	root.scale = Vector3.ONE * BUILDING_SCALE
	_line_scale = 1.0
	return root


# --- Shapes and materials -------------------------------------------------------

## One shared material per colour and outline width (0 = no outline).
static func _mat(color: Color, outline_width: float) -> StandardMaterial3D:
	var width := outline_width * _line_scale
	var key := "%s/%.4f" % [color.to_html(false), width]
	if not _materials.has(key):
		_materials[key] = Toon.material(color, width > 0.0, width)
	return _materials[key]


static func _cylinder(top: float, bottom: float, tall: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = tall
	mesh.radial_segments = segments
	return mesh


## A ball `radius` wide and `tall` high.
static func _ball(radius: float, tall: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = tall
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh


## A box with rounded edges and corners (a superellipsoid: the higher
## `roundness`, the squarer). It is smooth all over, so toon shading stays soft
## and the grown outline has no gaps at the corners, as it would on a real box.
static func _rounded_box(size: Vector3, roundness: float, segments := 24, rings := 12) -> ArrayMesh:
	var half := size * 0.5
	var bend := 2.0 / roundness
	var slope := 2.0 * (roundness - 1.0) / roundness
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for ring in rings + 1:
		var latitude := PI * ring / rings - PI * 0.5
		for segment in segments + 1:
			var longitude := TAU * segment / segments
			# A point on the unit sphere, pushed out towards the box.
			var d := Vector3(cos(latitude) * cos(longitude), sin(latitude), cos(latitude) * sin(longitude))
			points.append(Vector3(
					half.x * signf(d.x) * pow(absf(d.x), bend),
					half.y * signf(d.y) * pow(absf(d.y), bend),
					half.z * signf(d.z) * pow(absf(d.z), bend)))
			normals.append(Vector3(
					signf(d.x) * pow(absf(d.x), slope) / half.x,
					signf(d.y) * pow(absf(d.y), slope) / half.y,
					signf(d.z) * pow(absf(d.z), slope) / half.z).normalized())
	var indices := PackedInt32Array()
	var row := segments + 1
	for ring in rings:
		for segment in segments:
			var a := ring * row + segment
			var b := a + 1
			var c := a + row
			# Clockwise as seen from outside: Godot's front face.
			indices.append_array([a, b, c, b, c + 1, c])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
