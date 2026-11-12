extends Node3D
## Scene root: registers the input actions, handles hotkeys, shows the control
## hint, and offers command-line options for automated checks:
##   godot --path . -- --screenshot=C:/tmp/shot.png [--frames=90] [--walk=up]
##       [--no-post] [--start=5,21] [--encounter=1.0] [--auto=0.5] [--auto-pick=1]
##       [--partner-hp=1] [--seals=2] [--party=sassotto:3,bracino:2]
##       [--press=confirm@2.5,move_right@3] [--press-every=confirm:0.6:5]
##       [--save=check] [--time=0.9] [--day-speed=20] [--day=4] [--season=inverno]
## --time sets the time of day (0 midnight, 0.5 noon) and stops the clock there
## unless --day-speed, which multiplies how fast time passes, is given too.
## A --screenshot run never touches the real save: it neither loads nor saves,
## unless --save=name is given, which uses user://name.json instead.
## --frames counts sixtieths of a second. --start places the wanderer on a tile,
## --encounter sets the tall-grass encounter chance, --auto makes battle prompts
## answer themselves after N seconds (choosing option --auto-pick, default 0:
## 0 fight, 1 seal, 3 flee), --partner-hp sets the guide's starting health,
## --seals the number of seals, --party adds creatures. --press taps an action
## at a time in seconds; --press-every taps action:interval:start repeatedly.

const HELP_TEXT := "WASD / frecce: muovi     Shift: corri     Tab: squadra     Z / Invio: conferma     X: indietro     F1: filtro     F11: schermo intero     Esc: esci"
const Creature := preload("res://scripts/creature.gd")
const SaveGame := preload("res://scripts/save_game.gd")
## The game saves by itself after every battle, when the guide changes, when
## the window closes, and every this many steps.
const SAVE_EVERY_STEPS := 8

var _capturing := false
var _frame_drawn := false
var _save_path := "user://save.json"
var _saving_enabled := true
var _steps_unsaved := 0
var _toast: Label
var _toast_tween: Tween
var _clock_label: Label

@onready var _clock: Node = $DayCycle
@onready var _painterly: ColorRect = $PostProcess/Painterly
@onready var _help: Label = $Hud/Help
@onready var _world: Node3D = $World
@onready var _player: Node3D = $Player
@onready var _companion: Node3D = $Companion
@onready var _camera_rig: Node3D = $CameraRig
@onready var _battle: Node3D = $Battle


func _enter_tree() -> void:
	# Runs before any child's _ready, so everything can rely on these actions.
	_add_action(&"move_up", [KEY_W, KEY_UP], JOY_BUTTON_DPAD_UP)
	_add_action(&"move_down", [KEY_S, KEY_DOWN], JOY_BUTTON_DPAD_DOWN)
	_add_action(&"move_left", [KEY_A, KEY_LEFT], JOY_BUTTON_DPAD_LEFT)
	_add_action(&"move_right", [KEY_D, KEY_RIGHT], JOY_BUTTON_DPAD_RIGHT)
	_add_action(&"run", [KEY_SHIFT], JOY_BUTTON_X)
	_add_action(&"confirm", [KEY_Z, KEY_ENTER, KEY_SPACE], JOY_BUTTON_A)
	_add_action(&"cancel", [KEY_X, KEY_ESCAPE, KEY_BACKSPACE], JOY_BUTTON_B)
	_add_action(&"party", [KEY_TAB, KEY_C], JOY_BUTTON_Y)


func _ready() -> void:
	_help.text = HELP_TEXT
	_help.add_theme_font_size_override(&"font_size", 18)
	_help.add_theme_color_override(&"font_color", Color(0.2, 0.15, 0.13))
	_help.add_theme_color_override(&"font_outline_color", Color(0.97, 0.94, 0.88))
	_help.add_theme_constant_override(&"outline_size", 6)
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 18)

	_build_toast()
	_build_clock_label()
	_clock.phase_changed.connect(_update_clock_label.unbind(1))
	_clock.day_changed.connect(_update_clock_label.unbind(1))
	_clock.season_changed.connect(_update_clock_label.unbind(1))

	# The hint makes way for the battle interface.
	_battle.battle_started.connect(_on_battle_started)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.party_changed.connect(_save.bind(true))
	_player.step_finished.connect(_on_player_step_finished)

	var options := _user_options()
	if options.has("no-post"):
		_painterly.visible = false
	if options.has("auto"):
		_battle.ui.auto_delay = float(options["auto"])
	if options.has("auto-pick"):
		_battle.ui.auto_pick = int(options["auto-pick"])

	# Pick up the saved game, if any, before the check options below adjust things.
	_saving_enabled = not options.has("screenshot") or options.has("save")
	if options.has("save"):
		_save_path = "user://%s.json" % options["save"]
	if _saving_enabled:
		_offer_saved_game()

	if options.has("start"):
		var xy: PackedStringArray = options["start"].split(",")
		var cell := Vector2i(int(xy[0]), int(xy[1]))
		_player.teleport(cell)
		var behind := cell + Vector2i.DOWN
		_companion.teleport(behind if _world.is_walkable(behind) else cell)
		_camera_rig.snap()
	if options.has("season"):
		# primavera, estate, autunno or inverno; ".5" after it means half-way through.
		var wanted: PackedStringArray = options["season"].split(".")
		var index: int = ["primavera", "estate", "autunno", "inverno"].find(wanted[0])
		_clock.season_override = maxi(index, 0) + (0.5 if wanted.size() > 1 else 0.0)
		_clock.apply()
		_update_clock_label()
	if options.has("day"):
		_clock.set_clock(int(options["day"]), _clock.time_of_day)
	if options.has("time"):
		_clock.speed = 0.0
		_clock.set_clock(_clock.day, float(options["time"]))
	if options.has("day-speed"):
		_clock.speed = float(options["day-speed"])
	if options.has("encounter"):
		_battle.encounter_chance = float(options["encounter"])
		_battle.safe_steps = 0
	if options.has("partner-hp"):
		_battle.party.members[0].hp = int(options["partner-hp"])
	if options.has("seals"):
		_battle.party.seals = int(options["seals"])
	if options.has("party"):
		# Extra party members for checks, e.g. --party=sassotto:3,bracino:2
		for item: String in options["party"].split(","):
			var species_level := item.split(":")
			_battle.party.add(Creature.new(species_level[0], int(species_level[1])))
	if options.has("press"):
		for item: String in options["press"].split(","):
			var parts := item.split("@")
			_tap_later(parts[0], float(parts[1]))
	if options.has("press-every"):
		var spec: PackedStringArray = options["press-every"].split(":")
		_tap_repeatedly(spec[0], float(spec[1]), float(spec[2]))
	if options.has("screenshot"):
		_capture(options)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			# In a battle Esc means "back", never "quit".
			if not _battle.in_battle:
				_save()
				get_tree().quit()
		KEY_F1:
			# Compare the raw 3D scene with the painted version.
			_painterly.visible = not _painterly.visible
		KEY_F11:
			var window := get_window()
			if window.mode == Window.MODE_FULLSCREEN:
				window.mode = Window.MODE_WINDOWED
			else:
				window.mode = Window.MODE_FULLSCREEN


func _on_battle_started() -> void:
	_help.visible = false
	_clock_label.visible = false


func _on_battle_ended(result: String) -> void:
	_help.visible = not _capturing
	_clock_label.visible = true
	_save(true)
	if _capturing:
		print("battle_ended=", result, " seals=", _battle.party.seals, " party=", _party_summary())


func _on_player_step_finished(_cell: Vector2i) -> void:
	_steps_unsaved += 1
	if _steps_unsaved >= SAVE_EVERY_STEPS:
		_save()


func _notification(what: int) -> void:
	# Closing the window: save on the way out.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_save()


# --- Saving and loading ---------------------------------------------------------------

## Writes the current state to disk. Never mid-battle: a battle cannot be
## resumed, so the last save before it stands.
func _save(announce := false) -> void:
	if not _saving_enabled or _battle.in_battle:
		return
	var state := {
		"player": {
			"cell": [_player.cell.x, _player.cell.y],
			"facing": [_player.facing.x, _player.facing.y],
		},
		"companion": {"cell": [_companion.cell.x, _companion.cell.y]},
		"party": _battle.party.to_data(),
		"clock": {"day": _clock.day, "time": _clock.time_of_day},
	}
	if SaveGame.write(_save_path, state):
		_steps_unsaved = 0
		if announce:
			_show_toast("Partita salvata")


## If there is a saved game, puts it on screen straight away and asks whether
## to carry on with it or start over.
func _offer_saved_game() -> void:
	var state := SaveGame.read(_save_path)
	if state.is_empty() or not _restore(state):
		return
	_player.controls_enabled = false
	_help.visible = false
	var ui: Control = _battle.ui
	ui.open(false)
	var pick: int = await ui.choose("Bentornato! Hai una partita salvata.", ["Continua", "Nuova partita"])
	if pick == 1:
		var sure: int = await ui.choose(
				"Ricominciare da capo? La partita salvata andrà persa.",
				["No, continua", "Sì, ricomincia"])
		if sure == 1:
			SaveGame.erase(_save_path)
			_new_game()
	await ui.close()
	_help.visible = not _capturing
	_player.controls_enabled = true


## Applies saved data. Anything that no longer fits the map falls back to a
## safe default. Returns false if the save holds no usable party.
func _restore(state: Dictionary) -> bool:
	var party_data: Variant = state.get("party")
	if not party_data is Dictionary or not _battle.party.load_data(party_data):
		return false

	var player_data := _as_dictionary(state.get("player"))
	var cell := _as_cell(player_data.get("cell"), _world.start_cell)
	if not _world.is_walkable(cell):
		cell = _world.start_cell
	var facing := _as_cell(player_data.get("facing"), Vector2i.UP)
	if absi(facing.x) + absi(facing.y) != 1:
		facing = Vector2i.UP
	_player.teleport(cell)
	_player.facing = facing

	# The companion must be on a free tile right next to the wanderer.
	var buddy := _as_cell(_as_dictionary(state.get("companion")).get("cell"), cell + Vector2i.DOWN)
	var gap := buddy - cell
	if not _world.is_walkable(buddy) or absi(gap.x) + absi(gap.y) > 1:
		buddy = cell + Vector2i.DOWN if _world.is_walkable(cell + Vector2i.DOWN) else cell
	_companion.teleport(buddy)
	_battle.sync_companion()
	_camera_rig.snap()

	# Saves made before the clock existed simply start on a first morning.
	var clock_data := _as_dictionary(state.get("clock"))
	_clock.set_clock(int(clock_data.get("day", 1)), float(clock_data.get("time", _clock.START_TIME)))
	return true


func _new_game() -> void:
	_battle.reset_party()
	var home: Vector2i = _world.start_cell
	_player.teleport(home)
	_player.facing = Vector2i.UP
	_companion.teleport(home + Vector2i.DOWN if _world.is_walkable(home + Vector2i.DOWN) else home)
	_battle.sync_companion()
	_camera_rig.snap()
	_clock.set_clock(1, _clock.START_TIME)


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


## Reads a saved [x, y] pair; anything else gives `fallback`.
func _as_cell(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback


func _build_toast() -> void:
	_toast = Label.new()
	_toast.add_theme_font_size_override(&"font_size", 20)
	_toast.add_theme_color_override(&"font_color", Color(0.2, 0.15, 0.13))
	_toast.add_theme_color_override(&"font_outline_color", Color(0.97, 0.94, 0.88))
	_toast.add_theme_constant_override(&"outline_size", 6)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast.modulate.a = 0.0
	$Hud.add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BEGIN


## The day and the time of day, in the top-left corner.
func _build_clock_label() -> void:
	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override(&"font_size", 20)
	_clock_label.add_theme_color_override(&"font_color", Color(0.2, 0.15, 0.13))
	_clock_label.add_theme_color_override(&"font_outline_color", Color(0.97, 0.94, 0.88))
	_clock_label.add_theme_constant_override(&"outline_size", 6)
	$Hud.add_child(_clock_label)
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	_update_clock_label()


func _update_clock_label() -> void:
	_clock_label.text = "%s · Giorno %d · %s" % [_clock.season(), _clock.day, _clock.phase()]


## A short note in the top-right corner that fades away by itself.
func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


## One line per check log, e.g. "Germì L5 21/43, Sassotto L3 9/36".
func _party_summary() -> String:
	var parts: PackedStringArray = []
	for member in _battle.party.members:
		parts.append("%s L%d %d/%d" % [member.display_name(), member.level, member.hp, member.max_hp()])
	return ", ".join(parts)


func _add_action(action: StringName, keys: Array[Key], joy_button: JoyButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)
	var pad_event := InputEventJoypadButton.new()
	pad_event.button_index = joy_button
	InputMap.action_add_event(action, pad_event)


## Arguments after "--" on the command line, as {"name": "value"}.
func _user_options() -> Dictionary:
	var options := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else ""
	return options


## Sends a key tap for `action` through the normal input pipeline, so checks
## exercise the same code path as a real key press.
func _tap(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _tap_later(action: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	_tap(action)


func _tap_repeatedly(action: String, interval: float, start: float) -> void:
	await get_tree().create_timer(start).timeout
	while true:
		_tap(action)
		await get_tree().create_timer(interval).timeout


func _on_frame_drawn() -> void:
	_frame_drawn = true


## Lets the scene run for a while (optionally holding a direction), saves a PNG
## of the final frame and quits.
func _capture(options: Dictionary) -> void:
	_capturing = true
	# "--frames" counts sixtieths of a second, so timing does not depend on
	# the monitor's refresh rate.
	var duration := float(options.get("frames", "90")) / 60.0
	var walk: String = options.get("walk", "")
	_help.visible = false
	await get_tree().create_timer(minf(duration, 10.0 / 60.0)).timeout
	if walk != "":
		Input.action_press(StringName("move_" + walk))
	await get_tree().create_timer(maxf(duration - 10.0 / 60.0, 0.01)).timeout

	# Wait for a frame to be drawn, but not forever: a minimised window or a
	# sleeping display never draws, and the check should still finish.
	_frame_drawn = false
	RenderingServer.frame_post_draw.connect(_on_frame_drawn, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + 3000
	while not _frame_drawn and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var outcome := "SKIPPED (the window is not being drawn)"
	if _frame_drawn:
		var image := get_viewport().get_texture().get_image()
		outcome = error_string(image.save_png(options["screenshot"]))
	print("screenshot=", outcome, " cell=", _player.cell,
			" in_battle=", _battle.in_battle, " fps=", Engine.get_frames_per_second(),
			" seals=", _battle.party.seals, " party=", _party_summary(),
			" day=", _clock.day, " time=", snappedf(_clock.time_of_day, 0.001),
			" season=", _clock.season())
	get_tree().quit()
