extends RefCounted
## What each season looks like: one set of shader parameters per material.
## world.gd owns the materials and applies these; day_cycle.gd decides which
## season it is. Autumn is the look the game was first painted in.
##
## Every season must list the same materials and parameters, because the world
## blends from one season's value to the next.

const NAMES: Array[String] = ["Primavera", "Estate", "Autunno", "Inverno"]

const SPRING := 0
const SUMMER := 1
const AUTUMN := 2
const WINTER := 3

const WATER := {
	"water_shallow": Color(0.62, 0.87, 0.84),
	"water_mid": Color(0.3, 0.68, 0.8),
	"water_deep": Color(0.17, 0.49, 0.72),
}
const EARTH := {
	"dirt_dark": Color(0.74, 0.6, 0.42),
	"dirt_light": Color(0.89, 0.77, 0.55),
	"sand_dry": Color(0.94, 0.87, 0.68),
	"sand_wet": Color(0.74, 0.64, 0.47),
}

const LOOKS: Array[Dictionary] = [
	# Spring: fresh greens, trees in blossom, flowers everywhere, petals on the wind.
	{
		"ground": {
			"grass_dark": Color(0.4, 0.66, 0.3), "grass_light": Color(0.66, 0.84, 0.42), "snow": 0.0,
			"water_shallow": WATER["water_shallow"], "water_mid": WATER["water_mid"],
			"water_deep": WATER["water_deep"], "dirt_dark": EARTH["dirt_dark"],
			"dirt_light": EARTH["dirt_light"], "sand_dry": EARTH["sand_dry"], "sand_wet": EARTH["sand_wet"],
		},
		"grass": {
			"base_color": Color(0.4, 0.66, 0.3), "tip_color": Color(0.64, 0.84, 0.4),
			"dry_tip_color": Color(0.74, 0.86, 0.42), "tall_base_color": Color(0.26, 0.54, 0.3),
			"tall_tip_color": Color(0.5, 0.76, 0.38), "seed_color": Color(0.9, 0.92, 0.7),
			"gust_color": Color(0.95, 0.98, 0.76),
		},
		"maple": {"color_light": Color(1.0, 0.86, 0.9), "color_mid": Color(0.98, 0.66, 0.76),
				"color_dark": Color(0.84, 0.46, 0.6)},
		"ginkgo": {"color_light": Color(0.8, 0.92, 0.5), "color_mid": Color(0.6, 0.8, 0.38),
				"color_dark": Color(0.4, 0.62, 0.32)},
		"bush": {"color_light": Color(0.62, 0.84, 0.46), "color_mid": Color(0.42, 0.7, 0.4),
				"color_dark": Color(0.28, 0.54, 0.36)},
		# On the bushes: blossom.
		"berries": {"color_light": Color(1.0, 0.97, 0.98), "color_mid": Color(1.0, 0.84, 0.9),
				"color_dark": Color(0.92, 0.66, 0.76), "shown": 1.0},
		"flowers": {"abundance": 1.0},
		"air": {"color_a": Color(1.0, 0.78, 0.86), "color_b": Color(1.0, 0.98, 0.98),
				"leaf_size": 0.13, "amount": 0.8, "roundness": 0.5, "drift": 0.8},
	},
	# Summer: deep greens, fewer flowers, the odd green leaf in the air.
	{
		"ground": {
			"grass_dark": Color(0.26, 0.54, 0.24), "grass_light": Color(0.5, 0.74, 0.3), "snow": 0.0,
			"water_shallow": WATER["water_shallow"], "water_mid": WATER["water_mid"],
			"water_deep": WATER["water_deep"], "dirt_dark": EARTH["dirt_dark"],
			"dirt_light": EARTH["dirt_light"], "sand_dry": EARTH["sand_dry"], "sand_wet": EARTH["sand_wet"],
		},
		"grass": {
			"base_color": Color(0.26, 0.54, 0.24), "tip_color": Color(0.48, 0.74, 0.3),
			"dry_tip_color": Color(0.66, 0.78, 0.34), "tall_base_color": Color(0.16, 0.42, 0.22),
			"tall_tip_color": Color(0.38, 0.64, 0.28), "seed_color": Color(0.9, 0.86, 0.6),
			"gust_color": Color(0.9, 0.96, 0.66),
		},
		"maple": {"color_light": Color(0.62, 0.84, 0.42), "color_mid": Color(0.38, 0.68, 0.34),
				"color_dark": Color(0.24, 0.5, 0.32)},
		"ginkgo": {"color_light": Color(0.56, 0.8, 0.36), "color_mid": Color(0.36, 0.64, 0.3),
				"color_dark": Color(0.22, 0.46, 0.28)},
		"bush": {"color_light": Color(0.5, 0.76, 0.38), "color_mid": Color(0.3, 0.6, 0.34),
				"color_dark": Color(0.18, 0.44, 0.3)},
		# Nothing on the bushes yet.
		"berries": {"color_light": Color(0.7, 0.84, 0.44), "color_mid": Color(0.52, 0.72, 0.36),
				"color_dark": Color(0.36, 0.56, 0.32), "shown": 0.0},
		"flowers": {"abundance": 0.7},
		"air": {"color_a": Color(0.5, 0.76, 0.36), "color_b": Color(0.78, 0.86, 0.42),
				"leaf_size": 0.16, "amount": 0.3, "roundness": 0.0, "drift": 1.0},
	},
	# Autumn: red maples, golden ginkgos, berries, leaves on the wind.
	{
		"ground": {
			"grass_dark": Color(0.36, 0.58, 0.22), "grass_light": Color(0.6, 0.77, 0.32), "snow": 0.0,
			"water_shallow": WATER["water_shallow"], "water_mid": WATER["water_mid"],
			"water_deep": WATER["water_deep"], "dirt_dark": EARTH["dirt_dark"],
			"dirt_light": EARTH["dirt_light"], "sand_dry": EARTH["sand_dry"], "sand_wet": EARTH["sand_wet"],
		},
		"grass": {
			"base_color": Color(0.36, 0.58, 0.22), "tip_color": Color(0.58, 0.78, 0.32),
			"dry_tip_color": Color(0.84, 0.84, 0.44), "tall_base_color": Color(0.22, 0.47, 0.24),
			"tall_tip_color": Color(0.46, 0.7, 0.32), "seed_color": Color(0.93, 0.88, 0.64),
			"gust_color": Color(0.97, 0.96, 0.72),
		},
		"maple": {"color_light": Color(0.98, 0.58, 0.3), "color_mid": Color(0.9, 0.34, 0.2),
				"color_dark": Color(0.68, 0.2, 0.2)},
		"ginkgo": {"color_light": Color(1.0, 0.87, 0.4), "color_mid": Color(0.95, 0.7, 0.22),
				"color_dark": Color(0.78, 0.52, 0.18)},
		"bush": {"color_light": Color(0.52, 0.78, 0.4), "color_mid": Color(0.32, 0.64, 0.36),
				"color_dark": Color(0.2, 0.48, 0.33)},
		"berries": {"color_light": Color(1.0, 0.5, 0.42), "color_mid": Color(0.92, 0.28, 0.3),
				"color_dark": Color(0.72, 0.16, 0.26), "shown": 1.0},
		"flowers": {"abundance": 0.35},
		"air": {"color_a": Color(0.86, 0.16, 0.1), "color_b": Color(0.98, 0.72, 0.18),
				"leaf_size": 0.2, "amount": 1.0, "roundness": 0.0, "drift": 1.0},
	},
	# Winter: snow on the ground and on the trees, icy water, snowflakes.
	{
		"ground": {
			"grass_dark": Color(0.6, 0.68, 0.66), "grass_light": Color(0.8, 0.86, 0.84), "snow": 0.85,
			"water_shallow": Color(0.78, 0.9, 0.93), "water_mid": Color(0.56, 0.76, 0.86),
			"water_deep": Color(0.4, 0.6, 0.78), "dirt_dark": Color(0.74, 0.68, 0.6),
			"dirt_light": Color(0.9, 0.86, 0.78), "sand_dry": Color(0.95, 0.95, 0.94),
			"sand_wet": Color(0.78, 0.76, 0.72),
		},
		"grass": {
			"base_color": Color(0.62, 0.7, 0.68), "tip_color": Color(0.84, 0.9, 0.9),
			"dry_tip_color": Color(0.9, 0.92, 0.9), "tall_base_color": Color(0.5, 0.6, 0.6),
			"tall_tip_color": Color(0.78, 0.85, 0.86), "seed_color": Color(0.96, 0.97, 1.0),
			"gust_color": Color(1.0, 1.0, 1.0),
		},
		"maple": {"color_light": Color(0.98, 0.99, 1.0), "color_mid": Color(0.86, 0.9, 0.96),
				"color_dark": Color(0.66, 0.74, 0.86)},
		"ginkgo": {"color_light": Color(0.97, 0.98, 1.0), "color_mid": Color(0.84, 0.88, 0.94),
				"color_dark": Color(0.64, 0.72, 0.84)},
		"bush": {"color_light": Color(0.94, 0.96, 0.98), "color_mid": Color(0.62, 0.76, 0.72),
				"color_dark": Color(0.34, 0.52, 0.48)},
		# Winter berries stay on, red against the snow.
		"berries": {"color_light": Color(1.0, 0.5, 0.42), "color_mid": Color(0.92, 0.28, 0.3),
				"color_dark": Color(0.72, 0.16, 0.26), "shown": 1.0},
		"flowers": {"abundance": 0.0},
		"air": {"color_a": Color(1.0, 1.0, 1.0), "color_b": Color(0.9, 0.94, 1.0),
				"leaf_size": 0.09, "amount": 1.0, "roundness": 1.0, "drift": 0.35},
	},
]


## The look part-way from one season to another: {material: {parameter: value}}.
static func blend(from: int, to: int, amount: float) -> Dictionary:
	var result := {}
	var a: Dictionary = LOOKS[from]
	var b: Dictionary = LOOKS[to]
	for material: String in a:
		var mixed := {}
		for parameter: String in a[material]:
			var start: Variant = a[material][parameter]
			var end: Variant = b[material][parameter]
			if start is Color:
				mixed[parameter] = (start as Color).lerp(end, amount)
			else:
				mixed[parameter] = lerpf(start, end, amount)
		result[material] = mixed
	return result
