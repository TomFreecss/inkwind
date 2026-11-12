extends RefCounted
## Shared look for solid props and characters: flat toon shading plus an inked outline.


## Toon-shaded material. With `outline`, a second pass draws the mesh again,
## slightly inflated and inside out, which reads as a hand-inked contour.
static func material(color: Color, outline := true, outline_width := 0.022) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if outline:
		var ink := StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = Color(0.13, 0.09, 0.12)
		ink.cull_mode = BaseMaterial3D.CULL_FRONT
		ink.grow = true
		ink.grow_amount = outline_width
		mat.next_pass = ink
	return mat


## Adds a mesh part under `parent` and returns it.
static func part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3,
		rot_degrees := Vector3.ZERO, part_scale := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation_degrees = rot_degrees
	node.scale = part_scale
	parent.add_child(node)
	return node
