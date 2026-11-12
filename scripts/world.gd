extends Node3D
## Builds the meadow from an ASCII layout: painted ground, wind-blown grass, flowers,
## trees, rocks, drifting leaves and wind streaks. Also answers "can I walk there?".
##
## One tile is one metre. Tile (x, y) covers world X in [x, x+1] and Z in [y, y+1].

const Toon := preload("res://scripts/toon.gd")
const Village := preload("res://scripts/village.gd")
const Seasons := preload("res://scripts/seasons.gd")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const GRASS_SHADER := preload("res://shaders/grass.gdshader")
const FLOWER_SHADER := preload("res://shaders/flower.gdshader")
const CANOPY_SHADER := preload("res://shaders/canopy.gdshader")
const CANOPY_OUTLINE_SHADER := preload("res://shaders/canopy_outline.gdshader")
const TRUNK_SHADER := preload("res://shaders/trunk.gdshader")
const TRUNK_OUTLINE_SHADER := preload("res://shaders/trunk_outline.gdshader")
const LEAF_SHADER := preload("res://shaders/leaves.gdshader")
const STREAK_SHADER := preload("res://shaders/wind_streak.gdshader")

## .  meadow        g  tall grass    p  path      f  flower patch    w  water
## T  maple (red)   B  ginkgo (gold) R  rock      S  start, on the path
## b  bush          c  tree stump    x  log fence (joins fence tiles beside it)
## Edit freely: every row must be the same length. Water gets a sandy beach
## BEACH_WIDTH tiles wide on the tiles around it, so keep tall grass ("g") at
## least one tile away from water or it will be hidden under the sand.
##
## The village, east of the tree line (columns 40 and up):
## 1  windmill (7x4)   2  seal workshop (6x4)   3  rest house (6x4)
## 4  cottage (5x4)    A number marks a building's north-west corner; fill the
##                     rest of its footprint with "o".
## s  signpost         q  well          d  paper-drying rack
## Buildings have no see-through window like the trees do, so keep the two rows
## behind (north of) each one blocked: nobody should walk where they can't be
## seen. Trees are big: one within four tiles south of anything hides it, which
## is why the trees along the south edge are kept low (SOUTH_EDGE_TREES).
const LAYOUT: Array[String] = [
	"TTBTTTTBTTTTTBTTTTTppTTTTBTTTTTBTTTTBTTTTTBTTTTBTTTTTBTTTTBTTTTBTTTTBTTTTT",
	"TBT..TTT...TTTB.T..pp..TT...TTBT...TTTBTT.T.B.T.T.T.B.T.T.T.T.B.T.T.T.B.TT",
	"TT.....ff.........ppp........gggg.....TTTT.T.T.B.T.T.T.T.B.T.T.T.T.B.T.TTT",
	"BT...gggg.........pp..........gggggg..TBT.B.T.T.T.B.T.T.T.T.B.T.T.T.T.B.TT",
	"TT..gggggg...R....pp...f.....ggggg....TTTT.T.T.T.T.T.B.T.T.T.T.T.B.T.T.TTT",
	"T...ggggggg......ppp.b........ggg...R..TT.T.B.T.T.T.T.T.B.T.T.T.T.B.T.T.TT",
	"TT...ggggg...bb.ppp....T.........f.....TTTTTTBTTTTTTTTBTTTTTTTBTTTTTTTBTTT",
	"T.....ggg......ppp......wwwwww.....c..TTTBTTTTTTBTTTTTTTTTBTTTTTTTTBTTTTTT",
	"TB........b...ppp.....wwwwwwwwww.......BTTbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbTT",
	"T..c..B......ppp.....wwwwwwwwwwww.ff...TTb4oooo..2ooooo..1oooooo..3ooooobT",
	"TT..........ppp......wwwwwwRwwwww......TTbooooo..oooooo..ooooooo..oooooobT",
	"T....f.....ppp.......wwwwwwwwwww..gg..TTTbooooo..oooooo..ooooooo..oooooobT",
	"T.........pppp........wwwwwwwww..gggg..TTbooooobdoooooobbooooooobboooooobT",
	"TT...bb..ppppppppppp....wwwww...ggggg..BT..ppp.....pp.......p........p...T",
	"T...R....ppp....pppppp..........gggg..TTT..ppppppppppppppppppppppppppp...T",
	"T........pp........pppppppppppp..gg....TT..............ppppppppppp.bbbbb.T",
	"TT..ggg..pp....f.........R...pppp...bb.TT.......s......ppppppppppp.bbbbb.T",
	"B..ggggg.ppp..........c........pppppppppppppppppppppppppppppqppppp.4oooobT",
	"T.gggggggppp...R........f.....b.......TTT..............ppppppppppp.ooooobT",
	"TT.ggggg.pp..xxxxxx.....B.............TBT..............ppppppppppp.ooooobT",
	"T...ggg..pp..xffffx..............R.....TT.....xxxx.xxxx............ooooobT",
	"TB....bb.ppp.xffffx.........gggg.......TT.....xffx.xffx.......c..........T",
	"T.b..f...Spp...........bb..gggggg.....TTT.....xffx.xffx..................T",
	"TT.......ppp................gggg..f...BTTB...............b.............B.T",
	"T..R..c..pp.........c........gg........TTTTTBTTTTTTTTTTBTTTTTTBTTTTTTTBTTT",
	"TB.......pp....ff................T....TTT.T.T.B.T.T.T.T.T.T.B.T.T.T.T.B.TT",
	"TTT..B...pp..TT...BTT....TT....BT...TTBTTT.B.T.T.T.B.T.T.T.T.T.B.T.T.T.TTT",
	"TTBTTTTBTppTTTTBTTTTTBTTTTBTTTTTBTTTTBTTTTBTTTTBTTTTTTBTTTTTTBTTTTTTTBTTTT",
]
const WALKABLE := ".gpfS"

const GRASS_MARGIN := 9     ## tiles of grass painted beyond the playable map
const TREE_MARGIN := 7      ## tiles of decorative forest beyond the playable map
const SHORT_PER_TILE := 56
const TALL_PER_TILE := 80
const TRUNK_HEIGHT := 1.4
const TREE_SCALE := 2.0     ## how big trees stand next to the wanderer
const TREE_FLUFF := 0.36    ## how lumpy their crowns are, in metres
## The camera looks north, so a tall tree hides whatever stands behind it.
## Trees in the last SOUTH_EDGE_ROWS rows of the map, and in the forest beyond
## them, are shrunk by this much so they never cover the playfield.
const SOUTH_EDGE_TREES := 0.55
const SOUTH_EDGE_ROWS := 4
const LEAF_COUNT := 160
const STREAK_COUNT := 24
const SHORE_RES := 8        ## shore-field pixels per tile
const SHORE_REACH := 4.0    ## tiles: shore distances are capped here
const BEACH_WIDTH := 0.8    ## tiles of sand between the waterline and the meadow
const SHORE_WANDER := 0.35  ## how far the waterline strays from the tile edges
const HUGE_AABB := AABB(Vector3(-500.0, -20.0, -500.0), Vector3(1000.0, 60.0, 1000.0))

var width := 0
var height := 0
var start_cell := Vector2i.ZERO

var _rng := RandomNumberGenerator.new()
# Path and water masks over the map plus a border. Grass placement reads the
# path one to match the soft edges the ground shader paints; the shoreline is
# traced from the water one.
var _mask_border := GRASS_MARGIN + 2
var _mask_width := 0
var _path_mask := PackedFloat32Array()
var _water_mask := PackedFloat32Array()
# Signed distance to the shoreline in tiles, SHORE_RES pixels per tile over the
# map: positive in the water, negative on land. The ground shader paints sand,
# foam and depth from it; grass and flowers use it to stay off the beach.
var _shore_width := 0
var _shore_height := 0
var _shore := PackedFloat32Array()
# The materials a season repaints, by the names seasons.gd uses for them.
var _season_mats := {}


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
	_build_shore()
	_build_ground()
	_build_grass()
	_build_flowers()
	_build_trees()
	_build_rocks()
	_build_bushes()
	_build_stumps()
	_build_fences()
	_build_village()
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


## Repaints the land for the time of year: season `from`, drifting `amount`
## (0..1) of the way into season `to`. Indices are those of Seasons.NAMES.
func apply_season(from: int, to: int, amount: float) -> void:
	var look := Seasons.blend(from, to, amount)
	for material: String in look:
		var mat: ShaderMaterial = _season_mats.get(material)
		if mat == null:
			continue
		var outline := mat.next_pass as ShaderMaterial
		for parameter: String in look[material]:
			mat.set_shader_parameter(parameter, look[material][parameter])
			# A thing's pencil outline comes and goes with it.
			if outline != null and parameter == "shown":
				outline.set_shader_parameter(parameter, look[material][parameter])


# --- Masks --------------------------------------------------------------------

func _tile_clamped(cell: Vector2i) -> String:
	return tile_at(Vector2i(clampi(cell.x, 0, width - 1), clampi(cell.y, 0, height - 1)))


## Bare earth: paths, and the ground under buildings and the well.
func _is_path(tile: String) -> bool:
	return tile in "pS1234oq"


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


# --- Shore --------------------------------------------------------------------

## Works out how far every spot is from the waterline. The outline comes from
## the filtered water mask, so the lake is rounded rather than tile-square.
func _build_shore() -> void:
	_shore_width = width * SHORE_RES
	_shore_height = height * SHORE_RES
	var count := _shore_width * _shore_height
	# Slow noise pulls the waterline back by up to SHORE_WANDER of a tile, so no
	# stretch of shore is ruler-straight. It only ever retreats: the water never
	# creeps onto the walkable tiles around it.
	var wander := FastNoiseLite.new()
	wander.seed = 11
	wander.frequency = 0.3
	wander.fractal_octaves = 2
	# How far the water mask stands above the waterline level: positive = wet.
	var over := PackedFloat32Array()
	over.resize(count)
	for y in _shore_height:
		var z := (y + 0.5) / SHORE_RES
		for x in _shore_width:
			var px := (x + 0.5) / SHORE_RES
			var level := 0.5 + SHORE_WANDER * (0.5 + 0.5 * wander.get_noise_2d(px, z))
			over[y * _shore_width + x] = _mask(_water_mask, px, z) - level
	var dist := _distance_to_zero(over)
	_shore.resize(count)
	for i in count:
		var tiles := minf(dist[i] / SHORE_RES, SHORE_REACH)
		_shore[i] = tiles if over[i] > 0.0 else -tiles


## Distance in pixels from every shore-field pixel to the line where `field`
## crosses zero. Pixels beside the line get a sub-pixel estimate from the
## field's slope, so the result is smooth rather than stepped; a two-pass
## chamfer sweep (a straight step costs 1, a diagonal one sqrt(2)) then carries
## it outwards, accurate to a few percent.
func _distance_to_zero(field: PackedFloat32Array) -> PackedFloat32Array:
	const FAR := 1.0e6
	const DIAGONAL := 1.41421
	var w := _shore_width
	var h := _shore_height
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	dist.fill(FAR)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			var wet := field[i] > 0.0
			if (field[i - 1] > 0.0) == wet and (field[i + 1] > 0.0) == wet \
					and (field[i - w] > 0.0) == wet and (field[i + w] > 0.0) == wet:
				continue
			var slope := 0.5 * Vector2(
					field[i + 1] - field[i - 1], field[i + w] - field[i - w]).length()
			dist[i] = minf(absf(field[i]) / maxf(slope, 0.0001), 1.0)
	for y in h:
		for x in w:
			var i := y * w + x
			var best := dist[i]
			if x > 0:
				best = minf(best, dist[i - 1] + 1.0)
			if y > 0:
				best = minf(best, dist[i - w] + 1.0)
				if x > 0:
					best = minf(best, dist[i - w - 1] + DIAGONAL)
				if x < w - 1:
					best = minf(best, dist[i - w + 1] + DIAGONAL)
			dist[i] = best
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var best := dist[i]
			if x < w - 1:
				best = minf(best, dist[i + 1] + 1.0)
			if y < h - 1:
				best = minf(best, dist[i + w] + 1.0)
				if x < w - 1:
					best = minf(best, dist[i + w + 1] + DIAGONAL)
				if x > 0:
					best = minf(best, dist[i + w - 1] + DIAGONAL)
			dist[i] = best
	return dist


## Signed distance to the waterline in tiles at a world position: positive in
## the water, negative on land. Filtered the way the ground shader reads it.
func _shore_at(x: float, z: float) -> float:
	var fx := clampf(x * SHORE_RES - 0.5, 0.0, _shore_width - 1.001)
	var fz := clampf(z * SHORE_RES - 0.5, 0.0, _shore_height - 1.001)
	var x0 := int(fx)
	var z0 := int(fz)
	var tx := fx - x0
	var tz := fz - z0
	var i := z0 * _shore_width + x0
	var top := lerpf(_shore[i], _shore[i + 1], tx)
	var bottom := lerpf(_shore[i + _shore_width], _shore[i + _shore_width + 1], tx)
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
					0.0))
	var shore_image := Image.create_from_data(_shore_width, _shore_height, false,
			Image.FORMAT_RF, _shore.to_byte_array())

	var plane := PlaneMesh.new()
	plane.size = Vector2(320.0, 320.0)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.position = Vector3(width * 0.5, 0.0, height * 0.5)
	ground.material_override = _shader_material(GROUND_SHADER, {
		"tile_mask": ImageTexture.create_from_image(image),
		"shore_field": ImageTexture.create_from_image(shore_image),
		"map_size": Vector2(width, height),
		"beach_width": BEACH_WIDTH,
	})
	_season_mats["ground"] = ground.material_override
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
			if tile == "T" or tile == "B" or tile == "b":
				count = SHORT_PER_TILE / 2  # thinner under trees and bushes
			for i in count:
				var x := cx + _rng.randf()
				var z := cy + _rng.randf()
				if _mask(_path_mask, x, z) > 0.42:
					continue
				# Keep the beach bare, with a ragged edge where the meadow starts.
				if _shore_at(x, z) > -BEACH_WIDTH + _rng.randf_range(-0.15, 0.2):
					continue
				var blade_height := _rng.randf_range(0.6, 0.92) if tall else _rng.randf_range(0.2, 0.42)
				var blade_width := _rng.randf_range(0.12, 0.18) if tall else _rng.randf_range(0.11, 0.19)
				var basis := Basis(Vector3.UP, _rng.randf() * TAU) \
						.scaled(Vector3(blade_width, blade_height, blade_width))
				xforms.append(Transform3D(basis, Vector3(x, 0.0, z)))
				customs.append(Color(_rng.randf(), 1.0 if tall else 0.0, 0.0, 0.0))

	_season_mats["grass"] = _shader_material(GRASS_SHADER)
	var grass := _add_multimesh("Grass", _blade_mesh(), xforms, customs,
			_season_mats["grass"], false)
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
				if _shore_at(pos.x, pos.z) > -BEACH_WIDTH - 0.1:
					continue  # no flowers on the sand
				var size := _rng.randf_range(0.8, 1.3)
				xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size, size, size)), pos))
				customs.append(Color(color.r, color.g, color.b, _rng.randf()))

	var head := SphereMesh.new()
	head.radius = 0.07
	head.height = 0.14
	head.radial_segments = 8
	head.rings = 4
	_season_mats["flowers"] = _shader_material(FLOWER_SHADER)
	_add_multimesh("Flowers", head, xforms, customs, _season_mats["flowers"], false)


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
				size = _rng.randf_range(0.8, 1.0) * TREE_SCALE
			elif tile == "#":
				# Decorative forest beyond the map. Leave the path exits open.
				if _mask(_path_mask, cx + 0.5, cy + 0.5) > 0.2:
					continue
				if _rng.randf() < 0.3:
					kind = "B" if _rng.randf() < 0.25 else "T"
					size = _rng.randf_range(0.9, 1.25) * TREE_SCALE
			if kind == "":
				continue
			if cy >= height - SOUTH_EDGE_ROWS:
				size *= SOUTH_EDGE_TREES
			var pos := Vector3(
					cx + 0.5 + _rng.randf_range(-0.18, 0.18), 0.0,
					cy + 0.5 + _rng.randf_range(-0.18, 0.18))
			if kind == "T":
				_add_tree(pos, size, maple_x, maple_c, trunk_x, trunk_c)
			else:
				_add_tree(pos, size, ginkgo_x, ginkgo_c, trunk_x, trunk_c)

	var blob := _blob_mesh()
	# Each tree material draws a second, inside-out pass: its pencil outline.
	var maple := _shader_material(CANOPY_SHADER, {"fluff": TREE_FLUFF})
	maple.next_pass = _shader_material(CANOPY_OUTLINE_SHADER, {"fluff": TREE_FLUFF})
	_add_multimesh("MapleCanopies", blob, maple_x, maple_c, maple, true)
	var ginkgo := _shader_material(CANOPY_SHADER, {
		"color_light": Color(1.0, 0.87, 0.4),
		"color_mid": Color(0.95, 0.7, 0.22),
		"color_dark": Color(0.78, 0.52, 0.18),
		"fluff": TREE_FLUFF,
	})
	ginkgo.next_pass = _shader_material(CANOPY_OUTLINE_SHADER, {"fluff": TREE_FLUFF})
	_add_multimesh("GinkgoCanopies", blob, ginkgo_x, ginkgo_c, ginkgo, true)
	_season_mats["maple"] = maple
	_season_mats["ginkgo"] = ginkgo

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.13
	trunk.bottom_radius = 0.22
	trunk.height = TRUNK_HEIGHT
	trunk.radial_segments = 10
	var bark := _shader_material(TRUNK_SHADER)
	bark.next_pass = _shader_material(TRUNK_OUTLINE_SHADER)
	_add_multimesh("Trunks", trunk, trunk_x, trunk_c, bark, true)


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
	var stone := Toon.material(Color(0.74, 0.73, 0.76), true, 0.03)
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


# --- Bushes, stumps and fences --------------------------------------------------

## Bushes are foliage like the tree crowns (same shader, so they rustle in the
## same wind): a low dome with a ring of smaller clumps, some carrying berries.
func _build_bushes() -> void:
	var leaf_x: Array[Transform3D] = []
	var leaf_c: Array[Color] = []
	var berry_x: Array[Transform3D] = []
	var berry_c: Array[Color] = []
	for cy in height:
		for cx in width:
			if tile_at(Vector2i(cx, cy)) != "b":
				continue
			var base := Vector3(cx + 0.5 + _rng.randf_range(-0.08, 0.08), 0.0,
					cy + 0.5 + _rng.randf_range(-0.08, 0.08))
			var tint := _rng.randf()
			var has_berries := _rng.randf() < 0.4
			var clumps := _rng.randi_range(4, 5)
			var start := _rng.randf() * TAU
			for i in clumps + 1:
				var centre := base + Vector3(0.0, 0.28, 0.0)
				var radius := _rng.randf_range(0.38, 0.44)
				if i > 0:
					var angle := start + TAU * i / clumps + _rng.randf_range(-0.3, 0.3)
					centre = base + Vector3(
							cos(angle) * 0.24, _rng.randf_range(0.15, 0.24), sin(angle) * 0.24)
					radius = _rng.randf_range(0.22, 0.3)
				_add_blob(leaf_x, leaf_c, centre, radius, tint)
				if not has_berries:
					continue
				for j in 3:
					# Somewhere on the upper half of the clump.
					var turn := _rng.randf() * TAU
					var tilt := _rng.randf_range(0.2, 1.1)
					var out := Vector3(cos(turn) * sin(tilt), cos(tilt) * 0.82, sin(turn) * sin(tilt))
					var size := _rng.randf_range(0.05, 0.065)
					berry_x.append(Transform3D(
							Basis.IDENTITY.scaled(Vector3(size, size, size)),
							centre + out * (radius + 0.05)))
					berry_c.append(Color(_rng.randf(), _rng.randf(), 0.0, 0.0))

	# Low foliage never hides the wanderer, so it needs no see-through window.
	# In a battle the camera leans in low, so a bush in its way fades out.
	var leaves := _shader_material(CANOPY_SHADER, {
		"color_light": Color(0.52, 0.78, 0.4),
		"color_mid": Color(0.32, 0.64, 0.36),
		"color_dark": Color(0.2, 0.48, 0.33),
		"fluff": 0.1,
		"patch_scale": 2.4,
		"see_through": false,
		"fades_in_battle": true,
	})
	leaves.next_pass = _shader_material(CANOPY_OUTLINE_SHADER, {
		"fluff": 0.1,
		"see_through": false,
		"fades_in_battle": true,
		"width": 0.03,
	})
	_add_multimesh("Bushes", _blob_mesh(), leaf_x, leaf_c, leaves, true)

	var berries := _shader_material(CANOPY_SHADER, {
		"color_light": Color(1.0, 0.5, 0.42),
		"color_mid": Color(0.92, 0.28, 0.3),
		"color_dark": Color(0.72, 0.16, 0.26),
		"fluff": 0.0,
		"see_through": false,
		"fades_in_battle": true,
	})
	berries.next_pass = _shader_material(CANOPY_OUTLINE_SHADER, {
		"fluff": 0.0,
		"see_through": false,
		"fades_in_battle": true,
		"width": 0.012,
	})
	_add_multimesh("Berries", _blob_mesh(8, 4), berry_x, berry_c, berries, false)
	_season_mats["bush"] = leaves
	_season_mats["berries"] = berries


## Tree stumps: a flared trunk with growth rings on the cut, roots gripping the
## ground, and sometimes mushrooms at the foot or a shoot growing from the top.
func _build_stumps() -> void:
	var bark := Toon.material(Color(0.62, 0.44, 0.31), true, 0.025)
	var wood := Toon.material(Color(0.94, 0.82, 0.6), false)
	var ring := Toon.material(Color(0.8, 0.64, 0.44), false)
	var cap := Toon.material(Color(0.94, 0.47, 0.33), true, 0.014)
	var stalk := Toon.material(Color(0.97, 0.93, 0.83), true, 0.012)
	var shoot := Toon.material(Color(0.45, 0.72, 0.34), true, 0.012)

	var trunk := _cylinder_mesh(0.27, 0.36, 0.36, 14)
	var disc := _cylinder_mesh(1.0, 1.0, 1.0, 20)  # scaled into each ring
	var root := _ball_mesh(0.15, 0.16)
	var mushroom_stalk := _cylinder_mesh(0.03, 0.04, 0.1, 8)
	var mushroom_cap := _ball_mesh(0.09, 0.11)
	var shoot_stem := _cylinder_mesh(0.012, 0.016, 0.16, 6)
	var leaf := _ball_mesh(0.07, 0.035)

	var stumps := Node3D.new()
	stumps.name = "Stumps"
	add_child(stumps)
	for cy in height:
		for cx in width:
			if tile_at(Vector2i(cx, cy)) != "c":
				continue
			var stump := Node3D.new()
			stump.position = Vector3(cx + 0.5 + _rng.randf_range(-0.1, 0.1), 0.0,
					cy + 0.5 + _rng.randf_range(-0.1, 0.1))
			stump.rotation.y = _rng.randf() * TAU
			var size := _rng.randf_range(0.88, 1.1)
			stump.scale = Vector3(size, size, size)
			stumps.add_child(stump)

			Toon.part(stump, trunk, bark, Vector3(0.0, 0.18, 0.0))
			# The cut: pale wood with two darker growth rings, a hair apart in
			# height so they never flicker against each other.
			Toon.part(stump, disc, wood, Vector3(0.0, 0.362, 0.0), Vector3.ZERO, Vector3(0.25, 0.01, 0.25))
			Toon.part(stump, disc, ring, Vector3(0.0, 0.366, 0.0), Vector3.ZERO, Vector3(0.18, 0.01, 0.18))
			Toon.part(stump, disc, wood, Vector3(0.0, 0.37, 0.0), Vector3.ZERO, Vector3(0.13, 0.01, 0.13))
			Toon.part(stump, disc, ring, Vector3(0.0, 0.374, 0.0), Vector3.ZERO, Vector3(0.045, 0.01, 0.045))
			for i in 3:
				var angle := TAU * i / 3.0 + _rng.randf_range(-0.4, 0.4)
				Toon.part(stump, root, bark, Vector3(cos(angle) * 0.33, 0.06, sin(angle) * 0.33),
						Vector3(0.0, -rad_to_deg(angle), 0.0), Vector3(1.5, 1.0, 1.0))

			var extra := _rng.randf()
			if extra < 0.45:
				for i in _rng.randi_range(1, 2):
					var angle := _rng.randf() * TAU
					var foot := Vector3(cos(angle) * 0.46, 0.0, sin(angle) * 0.46)
					Toon.part(stump, mushroom_stalk, stalk, foot + Vector3(0.0, 0.05, 0.0))
					Toon.part(stump, mushroom_cap, cap, foot + Vector3(0.0, 0.12, 0.0))
			elif extra < 0.75:
				var spot := Vector3(_rng.randf_range(-0.08, 0.08), 0.36, _rng.randf_range(-0.08, 0.08))
				Toon.part(stump, shoot_stem, shoot, spot + Vector3(0.0, 0.08, 0.0))
				Toon.part(stump, leaf, shoot, spot + Vector3(0.06, 0.17, 0.0),
						Vector3(0.0, 0.0, 28.0), Vector3(1.4, 1.0, 0.8))
				Toon.part(stump, leaf, shoot, spot + Vector3(-0.06, 0.15, 0.0),
						Vector3(0.0, 0.0, -28.0), Vector3(1.4, 1.0, 0.8))


## Log fences: a post on every fence tile, each a little crooked, and two rails
## to the fence tile to its east and to its south.
func _build_fences() -> void:
	var post_wood := Toon.material(Color(0.66, 0.48, 0.32), true, 0.02)
	var rail_wood := Toon.material(Color(0.8, 0.62, 0.42), true, 0.018)
	var post := _cylinder_mesh(0.085, 0.105, 0.62, 10)
	var point := _cylinder_mesh(0.02, 0.085, 0.1, 10)
	var rail := _cylinder_mesh(0.045, 0.05, 1.1, 8)

	var fences := Node3D.new()
	fences.name = "Fences"
	add_child(fences)
	for cy in height:
		for cx in width:
			var cell := Vector2i(cx, cy)
			if tile_at(cell) != "x":
				continue
			var centre := cell_to_world(cell)
			var upright := Node3D.new()
			upright.position = centre
			upright.rotation_degrees = Vector3(
					_rng.randf_range(-4.0, 4.0), _rng.randf() * 360.0, _rng.randf_range(-4.0, 4.0))
			fences.add_child(upright)
			Toon.part(upright, post, post_wood, Vector3(0.0, 0.31, 0.0))
			Toon.part(upright, point, post_wood, Vector3(0.0, 0.67, 0.0))

			for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				if tile_at(cell + step) != "x":
					continue
				var middle := centre + Vector3(step.x, 0.0, step.y) * 0.5
				for rail_height: float in [0.2, 0.44]:
					# A cylinder stands along Y: lay it down along the fence,
					# never quite level.
					var lie := Vector3(0.0, _rng.randf_range(-2.0, 2.0), 90.0 + _rng.randf_range(-2.5, 2.5))
					if step == Vector2i.DOWN:
						lie = Vector3(90.0 + _rng.randf_range(-2.5, 2.5), 0.0, _rng.randf_range(-2.0, 2.0))
					Toon.part(fences, rail, rail_wood,
							middle + Vector3(0.0, rail_height + _rng.randf_range(-0.02, 0.02), 0.0), lie)


# --- Village --------------------------------------------------------------------

## Places the village's buildings and street furniture. A building's tile is its
## north-west corner; the model is centred on the whole footprint.
func _build_village() -> void:
	var village := Node3D.new()
	village.name = "Village"
	add_child(village)
	for cy in height:
		for cx in width:
			var model: Node3D = null
			var footprint := Vector2i.ONE
			match tile_at(Vector2i(cx, cy)):
				"1":
					model = Village.windmill()
					footprint = Vector2i(7, 4)
				"2":
					model = Village.workshop()
					footprint = Vector2i(6, 4)
				"3":
					model = Village.rest_house()
					footprint = Vector2i(6, 4)
				"4":
					model = Village.cottage(_rng.randi_range(0, 5))
					footprint = Vector2i(5, 4)
				"s":
					model = Village.signpost()
				"q":
					model = Village.well()
				"d":
					model = Village.drying_rack()
			if model == null:
				continue
			model.position = Vector3(cx + footprint.x * 0.5, 0.0, cy + footprint.y * 0.5)
			village.add_child(model)


# --- Leaves and wind streaks ----------------------------------------------------

func _build_air() -> void:
	_season_mats["air"] = _shader_material(LEAF_SHADER)
	var leaves := _add_multimesh("Leaves", QuadMesh.new(), _identities(LEAF_COUNT),
			_random_seeds(LEAF_COUNT), _season_mats["air"], false)
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

## A unit sphere for foliage clumps: each instance scales it to size.
func _blob_mesh(segments := 20, rings := 10) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


## A ball `radius` wide and `tall` high (flattened or stretched, not scaled, so
## an outline on it keeps an even thickness).
func _ball_mesh(radius: float, tall: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = tall
	mesh.radial_segments = 10
	mesh.rings = 5
	return mesh


func _cylinder_mesh(top: float, bottom: float, tall: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = tall
	mesh.radial_segments = segments
	return mesh

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
