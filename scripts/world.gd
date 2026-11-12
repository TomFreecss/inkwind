extends Node3D
## Builds the meadow from an ASCII layout: painted ground, wind-blown grass, flowers,
## trees, rocks, drifting leaves and wind streaks. Also answers "can I walk there?".
##
## One tile is one metre. Tile (x, y) covers world X in [x, x+1] and Z in [y, y+1].

const Toon := preload("res://scripts/toon.gd")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const GRASS_SHADER := preload("res://shaders/grass.gdshader")
const FLOWER_SHADER := preload("res://shaders/flower.gdshader")
const CANOPY_SHADER := preload("res://shaders/canopy.gdshader")
const TRUNK_SHADER := preload("res://shaders/trunk.gdshader")
const LEAF_SHADER := preload("res://shaders/leaves.gdshader")
const STREAK_SHADER := preload("res://shaders/wind_streak.gdshader")

## .  meadow        g  tall grass    p  path      f  flower patch    w  water
## T  maple (red)   B  ginkgo (gold) R  rock      S  start, on the path
## Edit freely: every row must be the same length.
const LAYOUT: Array[String] = [
	"TTBTTTTBTTTTTBTTTTTppTTTTBTTTTTBTTTTBTTT",
	"TBT..TTT...TTTB.T..pp..TT...TTBT...TTTBT",
	"TT.....ff.........ppp........gggg.....TT",
	"BT...gggg.........pp..........gggggg..TB",
	"TT..gggggg...R....pp...f.....ggggg....TT",
	"T...ggggggg......ppp..........ggg...R..T",
	"TT...ggggg......ppp....T...............T",
	"T.....ggg......ppp..........f.........TT",
	"TB............ppp.......wwwww..........B",
	"T.....B......ppp.......wwwwwww....ff...T",
	"TT..........ppp.......wwwwwwwww........T",
	"T....f.....ppp........wwwwwwwww...gg..TT",
	"T.........pppp.........wwwwwww...gggg..T",
	"TT.......ppppppppppp....wwwww...ggggg..B",
	"T...R....ppp....pppppp..........gggg..TT",
	"T........pp........pppppppppppp..gg....T",
	"TT..ggg..pp....f.........R...pppp......T",
	"B..ggggg.ppp...................ppppppppp",
	"T.gggggggppp...R........f.............TT",
	"TT.ggggg.pp.............B.............TB",
	"T...ggg..pp.....ff...............R.....T",
	"TB.......ppp................gggg.......T",
	"T....f...Spp...............gggggg.....TT",
	"TT.......ppp...T............gggg..f...BT",
	"T..R.....pp..................gg........T",
	"TB.......pp....ff................T....TT",
	"TTT..B...pp..TT...BTT....TT....BT...TTBT",
	"TTBTTTTBTppTTTTBTTTTTBTTTTBTTTTTBTTTTBTT",
]
const WALKABLE := ".gpfS"

const GRASS_MARGIN := 9     ## tiles of grass painted beyond the playable map
const TREE_MARGIN := 7      ## tiles of decorative forest beyond the playable map
const SHORT_PER_TILE := 56
const TALL_PER_TILE := 80
const TRUNK_HEIGHT := 1.4
const LEAF_COUNT := 160
const STREAK_COUNT := 24
const HUGE_AABB := AABB(Vector3(-500.0, -20.0, -500.0), Vector3(1000.0, 60.0, 1000.0))

var width := 0
var height := 0
var start_cell := Vector2i.ZERO

var _rng := RandomNumberGenerator.new()
# Path and water masks over the map plus a border, so grass placement can use
# the same soft edges the ground shader paints.
var _mask_border := GRASS_MARGIN + 2
var _mask_width := 0
var _path_mask := PackedFloat32Array()
var _water_mask := PackedFloat32Array()


func _init() -> void:
	height = LAYOUT.size()
	for y in height:
		width = maxi(width, LAYOUT[y].length())
		var x := LAYOUT[y].find("S")
		if x >= 0:
			start_cell = Vector2i(x, y)


func _ready() -> void:
	_rng.seed = 7341
	_build_masks()
	_build_ground()
	_build_grass()
	_build_flowers()
	_build_trees()
	_build_rocks()
	_build_air()


# --- Queries used by the player and companion ---------------------------------

## The layout character at `cell`, or "#" outside the map.
func tile_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return "#"
	var row := LAYOUT[cell.y]
	return row[cell.x] if cell.x < row.length() else "."


func is_walkable(cell: Vector2i) -> bool:
	return tile_at(cell) in WALKABLE


func is_tall_grass(cell: Vector2i) -> bool:
	return tile_at(cell) == "g"


## World position of the centre of a tile.
func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)


# --- Masks --------------------------------------------------------------------

func _tile_clamped(cell: Vector2i) -> String:
	return tile_at(Vector2i(clampi(cell.x, 0, width - 1), clampi(cell.y, 0, height - 1)))


func _is_path(tile: String) -> bool:
	return tile == "p" or tile == "S"


func _build_masks() -> void:
	_mask_width = width + _mask_border * 2
	var mask_height := height + _mask_border * 2
	_path_mask.resize(_mask_width * mask_height)
	_water_mask.resize(_mask_width * mask_height)
	for y in mask_height:
		for x in _mask_width:
			var tile := _tile_clamped(Vector2i(x - _mask_border, y - _mask_border))
			_path_mask[y * _mask_width + x] = 1.0 if _is_path(tile) else 0.0
			_water_mask[y * _mask_width + x] = 1.0 if tile == "w" else 0.0


## Bilinear sample at a world position: the same filtering the ground shader
## gets from its one-texel-per-tile texture.
func _mask(mask: PackedFloat32Array, x: float, z: float) -> float:
	var fx := x - 0.5 + _mask_border
	var fz := z - 0.5 + _mask_border
	var x0 := floori(fx)
	var z0 := floori(fz)
	var tx := fx - x0
	var tz := fz - z0
	var i := z0 * _mask_width + x0
	var top := lerpf(mask[i], mask[i + 1], tx)
	var bottom := lerpf(mask[i + _mask_width], mask[i + _mask_width + 1], tx)
	return lerpf(top, bottom, tz)


# --- Ground -------------------------------------------------------------------

func _build_ground() -> void:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var tile := tile_at(Vector2i(x, y))
			image.set_pixel(x, y, Color(
					1.0 if _is_path(tile) else 0.0,
					1.0 if tile == "g" else 0.0,
					1.0 if tile == "w" else 0.0))

	var plane := PlaneMesh.new()
	plane.size = Vector2(320.0, 320.0)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.position = Vector3(width * 0.5, 0.0, height * 0.5)
	ground.material_override = _shader_material(GROUND_SHADER, {
		"tile_mask": ImageTexture.create_from_image(image),
		"map_size": Vector2(width, height),
	})
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


# --- Grass and flowers ----------------------------------------------------------

func _build_grass() -> void:
	var xforms: Array[Transform3D] = []
	var customs: Array[Color] = []
	for cy in range(-GRASS_MARGIN, height + GRASS_MARGIN):
		for cx in range(-GRASS_MARGIN, width + GRASS_MARGIN):
			var tile := _tile_clamped(Vector2i(cx, cy))
			if tile == "w":
				continue
			var tall := tile == "g"
			var count := TALL_PER_TILE if tall else SHORT_PER_TILE
			if tile == "T" or tile == "B":
				count = SHORT_PER_TILE / 2  # thinner under the trees
			for i in count:
				var x := cx + _rng.randf()
				var z := cy + _rng.randf()
				if _mask(_path_mask, x, z) > 0.42 or _mask(_water_mask, x, z) > 0.2:
					continue
				var blade_height := _rng.randf_range(0.6, 0.92) if tall else _rng.randf_range(0.2, 0.42)
				var blade_width := _rng.randf_range(0.12, 0.18) if tall else _rng.randf_range(0.11, 0.19)
				var basis := Basis(Vector3.UP, _rng.randf() * TAU) \
						.scaled(Vector3(blade_width, blade_height, blade_width))
				xforms.append(Transform3D(basis, Vector3(x, 0.0, z)))
				customs.append(Color(_rng.randf(), 1.0 if tall else 0.0, 0.0, 0.0))

	var grass := _add_multimesh("Grass", _blade_mesh(), xforms, customs,
			_shader_material(GRASS_SHADER), false)
	grass.custom_aabb = HUGE_AABB


## A tapered blade one unit tall and one unit wide; each instance scales it.
func _blade_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0),
		Vector3(-0.36, 0.5, 0.0), Vector3(0.36, 0.5, 0.0),
		Vector3(0.0, 1.0, 0.0),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP,
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(0.0, 0.5), Vector2(1.0, 0.5),
		Vector2(0.5, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 1, 2, 3, 2, 4, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_flowers() -> void:
	var palette: Array[Color] = [
		Color(1.0, 0.98, 0.9), Color(1.0, 0.84, 0.3), Color(1.0, 0.6, 0.72), Color(0.76, 0.64, 1.0),
	]
	var xforms: Array[Transform3D] = []
	var customs: Array[Color] = []
	for cy in height:
		for cx in width:
			var tile := tile_at(Vector2i(cx, cy))
			var count := 0
			if tile == "f":
				count = 16
			elif tile == "." and _rng.randf() < 0.12:
				count = _rng.randi_range(1, 3)
			if count == 0:
				continue
			var color := palette[_rng.randi() % palette.size()].srgb_to_linear()
			for i in count:
				var pos := Vector3(cx + _rng.randf(), _rng.randf_range(0.24, 0.4), cy + _rng.randf())
				var size := _rng.randf_range(0.8, 1.3)
				xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size, size, size)), pos))
				customs.append(Color(color.r, color.g, color.b, _rng.randf()))

	var head := SphereMesh.new()
	head.radius = 0.07
	head.height = 0.14
	head.radial_segments = 8
	head.rings = 4
	_add_multimesh("Flowers", head, xforms, customs, _shader_material(FLOWER_SHADER), false)


# --- Trees and rocks ------------------------------------------------------------

func _build_trees() -> void:
	var maple_x: Array[Transform3D] = []
	var maple_c: Array[Color] = []
	var ginkgo_x: Array[Transform3D] = []
	var ginkgo_c: Array[Color] = []
	var trunk_x: Array[Transform3D] = []
	var trunk_c: Array[Color] = []

	for cy in range(-TREE_MARGIN, height + TREE_MARGIN):
		for cx in range(-TREE_MARGIN, width + TREE_MARGIN):
			var tile := tile_at(Vector2i(cx, cy))
			var kind := ""
			var size := 1.0
			if tile == "T" or tile == "B":
				kind = tile
				size = _rng.randf_range(0.8, 1.0)
			elif tile == "#":
				# Decorative forest beyond the map. Leave the path exits open.
				if _mask(_path_mask, cx + 0.5, cy + 0.5) > 0.2:
					continue
				if _rng.randf() < 0.3:
					kind = "B" if _rng.randf() < 0.25 else "T"
					size = _rng.randf_range(0.9, 1.25)
			if kind == "":
				continue
			var pos := Vector3(
					cx + 0.5 + _rng.randf_range(-0.18, 0.18), 0.0,
					cy + 0.5 + _rng.randf_range(-0.18, 0.18))
			if kind == "T":
				_add_tree(pos, size, maple_x, maple_c, trunk_x, trunk_c)
			else:
				_add_tree(pos, size, ginkgo_x, ginkgo_c, trunk_x, trunk_c)

	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 20
	blob.rings = 10
	_add_multimesh("MapleCanopies", blob, maple_x, maple_c, _shader_material(CANOPY_SHADER), true)
	_add_multimesh("GinkgoCanopies", blob, ginkgo_x, ginkgo_c, _shader_material(CANOPY_SHADER, {
		"color_light": Color(0.98, 0.8, 0.28),
		"color_mid": Color(0.9, 0.62, 0.14),
		"color_dark": Color(0.6, 0.38, 0.1),
	}), true)

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.13
	trunk.bottom_radius = 0.22
	trunk.height = TRUNK_HEIGHT
	trunk.radial_segments = 10
	_add_multimesh("Trunks", trunk, trunk_x, trunk_c, _shader_material(TRUNK_SHADER), true)


func _add_tree(pos: Vector3, size: float, canopy_x: Array[Transform3D], canopy_c: Array[Color],
		trunk_x: Array[Transform3D], trunk_c: Array[Color]) -> void:
	var trunk_height := TRUNK_HEIGHT * size
	var trunk_basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, size, size))
	trunk_x.append(Transform3D(trunk_basis, pos + Vector3(0.0, trunk_height * 0.5, 0.0)))
	trunk_c.append(Color(_rng.randf(), 0.0, 0.0, 0.0))

	# One big crown blob plus two or three smaller ones around it.
	var tint := _rng.randf()
	var crown := pos + Vector3(0.0, trunk_height + 0.35 * size, 0.0)
	_add_blob(canopy_x, canopy_c, crown, 0.9 * size, tint)
	var extra := _rng.randi_range(2, 3)
	var start := _rng.randf() * TAU
	for i in extra:
		var angle := start + TAU * i / extra + _rng.randf_range(-0.4, 0.4)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * 0.58 * size
		offset.y = _rng.randf_range(-0.3, 0.2) * size
		_add_blob(canopy_x, canopy_c, crown + offset, _rng.randf_range(0.5, 0.68) * size, tint)


func _add_blob(xforms: Array[Transform3D], customs: Array[Color], center: Vector3,
		radius: float, tint: float) -> void:
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(radius, radius * 0.82, radius))
	xforms.append(Transform3D(basis, center))
	customs.append(Color(tint, _rng.randf(), 0.0, 0.0))


func _build_rocks() -> void:
	var boulder := SphereMesh.new()
	boulder.radius = 0.5
	boulder.height = 1.0
	boulder.radial_segments = 9
	boulder.rings = 5
	var stone := Toon.material(Color(0.55, 0.56, 0.6), true, 0.03)
	var rocks := Node3D.new()
	rocks.name = "Rocks"
	add_child(rocks)
	for cy in height:
		for cx in width:
			if tile_at(Vector2i(cx, cy)) != "R":
				continue
			var center := Vector3(cx + 0.5, 0.0, cy + 0.5)
			Toon.part(rocks, boulder, stone, center + Vector3(-0.05, 0.22, 0.0),
					Vector3(0.0, _rng.randf() * 360.0, _rng.randf_range(-12.0, 12.0)),
					Vector3(_rng.randf_range(0.85, 1.0), _rng.randf_range(0.6, 0.8), _rng.randf_range(0.75, 0.95)))
			Toon.part(rocks, boulder, stone, center + Vector3(0.3, 0.1, 0.22),
					Vector3(0.0, _rng.randf() * 360.0, 0.0),
					Vector3(0.38, 0.3, 0.42))


# --- Leaves and wind streaks ----------------------------------------------------

func _build_air() -> void:
	var leaves := _add_multimesh("Leaves", QuadMesh.new(), _identities(LEAF_COUNT),
			_random_seeds(LEAF_COUNT), _shader_material(LEAF_SHADER), false)
	leaves.custom_aabb = HUGE_AABB

	var strip := QuadMesh.new()
	strip.subdivide_width = 24
	var streaks := _add_multimesh("WindStreaks", strip, _identities(STREAK_COUNT),
			_random_seeds(STREAK_COUNT), _shader_material(STREAK_SHADER, {
				"area_center": Vector2(width * 0.5, height * 0.5),
				"area_size": Vector2(width + 12.0, height + 12.0),
			}), false)
	streaks.custom_aabb = HUGE_AABB


func _identities(count: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.resize(count)
	out.fill(Transform3D.IDENTITY)
	return out


func _random_seeds(count: int) -> Array[Color]:
	var out: Array[Color] = []
	for i in count:
		out.append(Color(_rng.randf(), _rng.randf(), _rng.randf(), _rng.randf()))
	return out


# --- Helpers --------------------------------------------------------------------

func _shader_material(shader: Shader, params := {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for key: String in params:
		mat.set_shader_parameter(key, params[key])
	return mat


## One MultiMesh draw for many copies of `mesh`; `customs` feeds INSTANCE_CUSTOM.
func _add_multimesh(node_name: String, mesh: Mesh, xforms: Array[Transform3D],
		customs: Array[Color], mat: Material, shadows: bool) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = xforms.size()
	for i in xforms.size():
		multimesh.set_instance_transform(i, xforms[i])
		multimesh.set_instance_custom_data(i, customs[i])

	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multimesh
	node.material_override = mat
	node.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	add_child(node)
	return node
