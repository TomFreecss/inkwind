extends Node
## The world's clock, and the light that goes with it. The sun crosses the sky
## from morning to evening, dawn and dusk tint everything, and at night a moon
## takes over while windows and lanterns come on.
##
## `time_of_day` runs from 0 to 1: 0 is midnight, 0.5 is noon. `day` counts
## the days played, starting from 1.

signal phase_changed(phase: String)
signal day_changed(day: int)
signal season_changed(season: String)

const Village := preload("res://scripts/village.gd")
const Seasons := preload("res://scripts/seasons.gd")

const START_TIME := 0.36
## The calendar: this many days to a season, four seasons to a year, and a new
## game begins in autumn.
const DAYS_PER_SEASON := 3
const FIRST_SEASON := Seasons.AUTUMN
## Over this last part of a season the land drifts into the next one.
const SEASON_DRIFT := 0.25
## The sun is in the sky between these two times.
const SUNRISE := 0.23
const SUNSET := 0.79

## The look of the world at set times of day; everything in between is blended.
## "light" is the sun by day and the moon by night. Its energy drops to zero
## around sunrise and sunset, which is when it jumps from one to the other
## without anyone seeing the shadows swing round.
const KEYS: Array[Dictionary] = [
	{"t": 0.0, "light": Color(0.62, 0.72, 1.0), "energy": 0.32, "ambient": Color(0.34, 0.4, 0.68),
			"ambient_energy": 0.8, "sky": Color(0.14, 0.18, 0.34), "night": 1.0},
	{"t": 0.19, "light": Color(0.62, 0.72, 1.0), "energy": 0.32, "ambient": Color(0.34, 0.4, 0.68),
			"ambient_energy": 0.8, "sky": Color(0.14, 0.18, 0.34), "night": 1.0},
	{"t": 0.225, "light": Color(1.0, 0.72, 0.6), "energy": 0.0, "ambient": Color(0.62, 0.56, 0.76),
			"ambient_energy": 0.85, "sky": Color(0.72, 0.62, 0.74), "night": 0.5},
	{"t": 0.27, "light": Color(1.0, 0.74, 0.6), "energy": 0.75, "ambient": Color(0.76, 0.66, 0.76),
			"ambient_energy": 0.85, "sky": Color(0.97, 0.82, 0.74), "night": 0.1},
	{"t": 0.34, "light": Color(1.0, 0.95, 0.85), "energy": 1.2, "ambient": Color(0.76, 0.74, 0.9),
			"ambient_energy": 0.85, "sky": Color(0.8, 0.87, 0.88), "night": 0.0},
	{"t": 0.66, "light": Color(1.0, 0.95, 0.85), "energy": 1.2, "ambient": Color(0.76, 0.74, 0.9),
			"ambient_energy": 0.85, "sky": Color(0.8, 0.87, 0.88), "night": 0.0},
	{"t": 0.74, "light": Color(1.0, 0.64, 0.42), "energy": 0.8, "ambient": Color(0.74, 0.6, 0.7),
			"ambient_energy": 0.84, "sky": Color(0.97, 0.72, 0.58), "night": 0.15},
	{"t": 0.795, "light": Color(1.0, 0.6, 0.5), "energy": 0.0, "ambient": Color(0.56, 0.5, 0.74),
			"ambient_energy": 0.82, "sky": Color(0.5, 0.42, 0.62), "night": 0.6},
	{"t": 0.84, "light": Color(0.62, 0.72, 1.0), "energy": 0.32, "ambient": Color(0.34, 0.4, 0.68),
			"ambient_energy": 0.8, "sky": Color(0.14, 0.18, 0.34), "night": 1.0},
	{"t": 1.0, "light": Color(0.62, 0.72, 1.0), "energy": 0.32, "ambient": Color(0.34, 0.4, 0.68),
			"ambient_energy": 0.8, "sky": Color(0.14, 0.18, 0.34), "night": 1.0},
]

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var world_path: NodePath
## Real seconds for one whole day and night.
@export var day_length := 600.0
## Multiplies how fast time passes; 0 stops the clock.
@export var speed := 1.0

var time_of_day := START_TIME
var day := 1
## 0 in daylight, 1 in the middle of the night: how lit the windows are.
var night_amount := 0.0
## For checks: hold the year at this position (0 = start of spring, 1 = start of
## summer, and so on) instead of following the calendar. Negative = follow it.
var season_override := -1.0

var _sun: DirectionalLight3D
var _environment: Environment
var _world: Node3D
var _phase := ""
var _season := -1
var _painted_year := -1.0


func _ready() -> void:
	_sun = get_node(sun_path)
	_environment = (get_node(environment_path) as WorldEnvironment).environment
	_world = get_node(world_path)
	apply()


func _process(delta: float) -> void:
	if speed <= 0.0 or day_length <= 0.0:
		return
	time_of_day += delta * speed / day_length
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
		day_changed.emit(day)
	apply()


## Jump to a time (and day), e.g. when loading a saved game.
func set_clock(new_day: int, new_time: float) -> void:
	day = maxi(new_day, 1)
	time_of_day = fposmod(new_time, 1.0)
	day_changed.emit(day)
	apply()


## Where the year stands, 0..4: the whole part is the season (as in
## Seasons.NAMES), the rest is how far through it we are.
func year_position() -> float:
	if season_override >= 0.0:
		return fposmod(season_override, 4.0)
	return fposmod(FIRST_SEASON + (day - 1 + time_of_day) / DAYS_PER_SEASON, 4.0)


## "Primavera", "Estate", "Autunno" or "Inverno".
func season() -> String:
	return Seasons.NAMES[int(year_position())]


## "Alba", "Mattina", "Pomeriggio", "Tramonto" or "Notte".
func phase() -> String:
	if time_of_day < SUNRISE or time_of_day >= SUNSET:
		return "Notte"
	if time_of_day < 0.34:
		return "Alba"
	if time_of_day < 0.5:
		return "Mattina"
	if time_of_day < 0.68:
		return "Pomeriggio"
	return "Tramonto"


## Puts the light, the sky and the village's lamps where the clock says.
func apply() -> void:
	var next := 1
	while next < KEYS.size() - 1 and KEYS[next]["t"] < time_of_day:
		next += 1
	var from: Dictionary = KEYS[next - 1]
	var to: Dictionary = KEYS[next]
	var blend := inverse_lerp(from["t"], to["t"], time_of_day)
	blend = clampf(blend, 0.0, 1.0)

	_sun.light_color = (from["light"] as Color).lerp(to["light"], blend)
	_sun.light_energy = lerpf(from["energy"], to["energy"], blend)
	_sun.global_transform.basis = Basis.looking_at(_light_direction(), Vector3.UP)
	_environment.ambient_light_color = (from["ambient"] as Color).lerp(to["ambient"], blend)
	_environment.ambient_light_energy = lerpf(from["ambient_energy"], to["ambient_energy"], blend)
	var sky := (from["sky"] as Color).lerp(to["sky"], blend)
	_environment.background_color = sky
	_environment.fog_light_color = sky

	night_amount = lerpf(from["night"], to["night"], blend)
	Village.set_night(night_amount)
	# Unlit things (leaves, cloth, wind streaks) dim through this shader global.
	RenderingServer.global_shader_parameter_set(&"day_brightness", lerpf(1.0, 0.5, night_amount))

	var now := phase()
	if now != _phase:
		_phase = now
		phase_changed.emit(now)

	# The season: repaint only when the year has moved enough to show.
	var year := year_position()
	if absf(year - _painted_year) > 0.002:
		_painted_year = year
		var current := int(year)
		var drift := smoothstep(1.0 - SEASON_DRIFT, 1.0, year - current)
		_world.apply_season(current, (current + 1) % 4, drift)
		if current != _season:
			_season = current
			season_changed.emit(Seasons.NAMES[current])


## Which way the light in the sky shines. The sun rises to the camera's right,
## climbs, and sets to its left, always standing behind the scene so that
## shadows fall towards the viewer; the moon keeps one place all night.
func _light_direction() -> Vector3:
	var azimuth := deg_to_rad(-25.0)
	var elevation := deg_to_rad(56.0)
	if time_of_day >= SUNRISE and time_of_day < SUNSET:
		var progress := inverse_lerp(SUNRISE, SUNSET, time_of_day)
		azimuth = deg_to_rad(lerpf(40.0, -50.0, progress))
		elevation = deg_to_rad(18.0 + 44.0 * pow(sin(progress * PI), 0.6))
	# Where the light stands in the sky (north is -Z); it shines the other way.
	var stands := Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))
	return -stands
