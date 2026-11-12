extends Control
## The game's paper-card interface, drawn over the painted scene:
##  - in battle: a status card for each fighter, a message box and a menu;
##  - anywhere: the party panel, listing the wanderer's creatures.
## Everything is driven with the movement keys, confirm and cancel.
##
## `say()`, `choose()` and `choose_member()` are coroutines:
##     await ui.say("Un Sassotto selvatico sbuca dall'erba!")
##     var pick: int = await ui.choose("Cosa fa Germì?", ["Lotta", "Fuga"])

signal advanced
signal chosen(index: int)

const DB := preload("res://scripts/creature_db.gd")
const Creature := preload("res://scripts/creature.gd")
const Party := preload("res://scripts/party.gd")

const PAPER := Color(0.965, 0.94, 0.875)
const INK := Color(0.2, 0.14, 0.13)
const XP_COLOR := Color(0.36, 0.56, 0.86)
const TYPE_SPEED := 0.016  ## seconds per character

## Zero or more: prompts answer themselves after this many seconds, picking
## option `auto_pick`. Used by automated checks; -1 waits for the player.
var auto_delay := -1.0
var auto_pick := 0

var _ally: Creature
var _foe: Creature
var _cards: Control
var _ally_card := {}
var _foe_card := {}
var _message: Label
var _menu: GridContainer
var _next_mark: ColorRect
var _fade: ColorRect
var _option_labels: Array[Label] = []

var _party_panel: PanelContainer
var _party_title: Label
var _party_seals: Label
var _party_rows: VBoxContainer
var _row_panels: Array[PanelContainer] = []

var _mode := ""  # "", "say", "choose" or "party"
var _selected := 0
var _nav_count := 0
var _nav_columns := 1
var _allow_cancel := false
var _typing: Tween


func _ready() -> void:
	# set_anchors_AND_OFFSETS_preset: plain set_anchors_preset keeps the old
	# (zero) size, which collapses everything into the top-left corner.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_cards = Control.new()
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.visible = false
	add_child(_cards)
	_cards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_foe_card = _build_card(false)
	_ally_card = _build_card(true)
	_build_message_box()
	_build_party_panel()

	# Full-screen sheet of paper for fading out after a lost battle.
	_fade = ColorRect.new()
	_fade.color = Color(PAPER, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	if _next_mark.visible:
		_next_mark.modulate.a = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() * 0.005))


func _input(event: InputEvent) -> void:
	if _mode == "" or auto_delay >= 0.0:
		return
	# The party key also closes the party panel it opened.
	if event.is_action_pressed(&"cancel") or (_mode == "party" and event.is_action_pressed(&"party")):
		get_viewport().set_input_as_handled()
		if _mode != "say" and _allow_cancel:
			chosen.emit(-1)
		return
	if _mode == "say":
		if event.is_action_pressed(&"confirm"):
			get_viewport().set_input_as_handled()
			if _typing != null and _typing.is_running():
				# First press finishes the line, the next one moves on.
				_typing.kill()
				_message.visible_ratio = 1.0
				_next_mark.visible = true
			else:
				advanced.emit()
		return

	# "choose" and "party": move the highlight, confirm to pick.
	var step := 0
	if event.is_action_pressed(&"move_left"):
		step = -1
	elif event.is_action_pressed(&"move_right"):
		step = 1
	elif event.is_action_pressed(&"move_up"):
		step = -_nav_columns
	elif event.is_action_pressed(&"move_down"):
		step = _nav_columns
	if step != 0:
		get_viewport().set_input_as_handled()
		var target := _selected + step
		if target >= 0 and target < _nav_count:
			_selected = target
			_refresh_highlight()
	elif event.is_action_pressed(&"confirm"):
		get_viewport().set_input_as_handled()
		chosen.emit(_selected)


# --- What the game calls ------------------------------------------------------------

## Which two creatures the status cards describe.
func set_fighters(ally: Creature, foe: Creature) -> void:
	_ally = ally
	_foe = foe
	refresh(false)


## Re-reads health, level and experience. With `animated`, the bars slide.
func refresh(animated := true) -> void:
	_fill_card(_foe_card, _foe, animated)
	_fill_card(_ally_card, _ally, animated)


## Shows the interface. With `show_fighters` false only the message box
## appears, for questions asked outside a battle.
func open(show_fighters := true) -> void:
	(_foe_card["panel"] as Control).visible = show_fighters
	(_ally_card["panel"] as Control).visible = show_fighters
	_message.text = ""
	_menu.visible = false
	_next_mark.visible = false
	_cards.visible = true
	_cards.modulate.a = 0.0
	create_tween().tween_property(_cards, "modulate:a", 1.0, 0.25)


func close() -> void:
	var tween := create_tween()
	tween.tween_property(_cards, "modulate:a", 0.0, 0.25)
	await tween.finished
	_cards.visible = false


## Hides the cards at once (used under a full fade).
func hide_now() -> void:
	_cards.visible = false


## Fades the whole screen to bare paper (1.0) or back (0.0).
func fade_paper(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, duration)
	await tween.finished


## Types out a line and waits for the confirm key.
func say(text: String) -> void:
	_menu.visible = false
	_next_mark.visible = false
	_message.text = text
	_message.visible_ratio = 0.0
	_mode = "say"
	var typing_time := maxf(0.12, text.length() * TYPE_SPEED)
	_typing = create_tween()
	_typing.tween_property(_message, "visible_ratio", 1.0, typing_time)
	_typing.tween_callback(_show_next_mark)
	if auto_delay >= 0.0:
		await get_tree().create_timer(typing_time + auto_delay).timeout
	else:
		await advanced
	_mode = ""
	_next_mark.visible = false


## Shows a menu and returns the chosen index, or -1 if cancelled.
func choose(prompt: String, options: Array, allow_cancel := false) -> int:
	_message.text = prompt
	_message.visible_ratio = 1.0
	_next_mark.visible = false
	_set_options(options)
	_menu.visible = true
	var result: int = await _pick("choose", options.size(), _menu.columns, allow_cancel)
	_menu.visible = false
	return result


## Shows the party panel and returns the chosen member's index, or -1 if
## cancelled. `active` marks who is currently fighting, if anyone; the
## highlight starts on member `preselect`.
func choose_member(party: Party, title: String, allow_cancel := true, active: Creature = null,
		preselect := 0) -> int:
	_party_title.text = title
	_party_seals.text = "Sigilli: %d" % party.seals
	_build_party_rows(party, active)
	_party_panel.visible = true
	var result: int = await _pick("party", party.members.size(), 1, allow_cancel, preselect)
	_party_panel.visible = false
	return result


# --- Prompt plumbing ----------------------------------------------------------------

## Waits for the player to pick one of `count` items laid out in `columns`.
func _pick(mode: String, count: int, columns: int, allow_cancel: bool, start := 0) -> int:
	_selected = clampi(start, 0, count - 1)
	_nav_count = count
	_nav_columns = columns
	_allow_cancel = allow_cancel
	_mode = mode
	_refresh_highlight()
	var result := 0
	if auto_delay >= 0.0:
		await get_tree().create_timer(auto_delay).timeout
		result = mini(auto_pick, count - 1) if mode == "choose" else 0
	else:
		result = await chosen
	_mode = ""
	return result


func _refresh_highlight() -> void:
	if _mode == "party":
		for i in _row_panels.size():
			_row_panels[i].add_theme_stylebox_override(&"panel", _row_box(i == _selected))
	else:
		# The selected option is drawn inverted: ink card, paper text.
		for i in _option_labels.size():
			var selected := i == _selected
			var box := StyleBoxFlat.new()
			box.bg_color = INK if selected else PAPER.darkened(0.07)
			box.border_color = INK
			box.set_border_width_all(2)
			box.set_corner_radius_all(10)
			box.content_margin_left = 16.0
			box.content_margin_right = 16.0
			_option_labels[i].add_theme_stylebox_override(&"normal", box)
			_option_labels[i].add_theme_color_override(&"font_color", PAPER if selected else INK)


func _show_next_mark() -> void:
	_next_mark.visible = auto_delay < 0.0


# --- Status cards ---------------------------------------------------------------------

func _fill_card(card: Dictionary, creature: Creature, animated: bool) -> void:
	if creature == null:
		return
	var element: Dictionary = DB.ELEMENTS[creature.element()]
	(card["name"] as Label).text = creature.display_name()
	(card["level"] as Label).text = "Liv. %d" % creature.level
	(card["chip"] as Label).text = element["name"]
	(card["chip_box"] as StyleBoxFlat).bg_color = element["color"]

	var ratio := _health_ratio(creature)
	_set_bar(card["hp_fill"], ratio, _health_color(ratio), animated)
	if card.has("hp_text"):
		(card["hp_text"] as Label).text = "Vita  %d / %d" % [creature.hp, creature.max_hp()]
		var xp_ratio := clampf(float(creature.xp) / float(creature.xp_to_next()), 0.0, 1.0)
		_set_bar(card["xp_fill"], xp_ratio, XP_COLOR, animated)


func _health_ratio(creature: Creature) -> float:
	return clampf(float(creature.hp) / float(creature.max_hp()), 0.0, 1.0)


func _health_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.38, 0.7, 0.32)
	if ratio > 0.22:
		return Color(0.92, 0.72, 0.2)
	return Color(0.85, 0.27, 0.2)


## A bar is a ColorRect whose right anchor is the fill ratio.
func _set_bar(fill: ColorRect, ratio: float, color: Color, animated: bool) -> void:
	if animated:
		var tween := create_tween().set_parallel()
		tween.tween_property(fill, "anchor_right", ratio, 0.35) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(fill, "color", color, 0.35)
	else:
		fill.anchor_right = ratio
		fill.color = color


func _build_card(is_ally: bool) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", _paper_box())
	_cards.add_child(panel)
	if is_ally:
		# Bottom right, just above the message box.
		panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		panel.offset_left = -462.0
		panel.offset_right = -32.0
		panel.offset_top = -372.0
		panel.offset_bottom = -228.0
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.offset_left = 32.0
		panel.offset_top = 28.0
		panel.offset_right = 442.0
		panel.offset_bottom = 136.0

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	var name_label := _label("", 28)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var level_label := _label("", 22)
	top.add_child(level_label)

	var middle := HBoxContainer.new()
	middle.add_theme_constant_override(&"separation", 12)
	column.add_child(middle)
	var chip_box := _chip_box()
	var chip := _label("", 18)
	chip.add_theme_stylebox_override(&"normal", chip_box)
	middle.add_child(chip)
	var health := _build_bar(20.0, 160.0)
	(health["root"] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(health["root"])

	var card := {
		"panel": panel, "name": name_label, "level": level_label,
		"chip": chip, "chip_box": chip_box, "hp_fill": health["fill"],
	}
	if is_ally:
		var bottom := HBoxContainer.new()
		bottom.add_theme_constant_override(&"separation", 12)
		column.add_child(bottom)
		var hp_text := _label("", 20)
		hp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom.add_child(hp_text)
		bottom.add_child(_label("Esp.", 16))
		var experience := _build_bar(12.0, 130.0)
		bottom.add_child(experience["root"])
		card["hp_text"] = hp_text
		card["xp_fill"] = experience["fill"]
	return card


# --- Message box and menu ---------------------------------------------------------------

func _build_message_box() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", _paper_box())
	_cards.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 32.0
	panel.offset_right = -32.0
	panel.offset_top = -208.0
	panel.offset_bottom = -28.0

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	panel.add_child(row)

	_message = _label("", 30)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_message)

	_menu = GridContainer.new()
	_menu.columns = 2
	_menu.add_theme_constant_override(&"h_separation", 12)
	_menu.add_theme_constant_override(&"v_separation", 10)
	_menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_menu)

	# Small blinking diamond: "press confirm to continue".
	_next_mark = ColorRect.new()
	_next_mark.color = INK
	_next_mark.custom_minimum_size = Vector2(14.0, 14.0)
	_next_mark.size = Vector2(14.0, 14.0)
	_next_mark.pivot_offset = Vector2(7.0, 7.0)
	_next_mark.rotation_degrees = 45.0
	_next_mark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_next_mark.offset_left = -78.0
	_next_mark.offset_right = -64.0
	_next_mark.offset_top = -70.0
	_next_mark.offset_bottom = -56.0
	_next_mark.visible = false
	_cards.add_child(_next_mark)


func _set_options(options: Array) -> void:
	for child in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()
	_option_labels.clear()
	for text: String in options:
		var label := _label(text, 26)
		label.custom_minimum_size = Vector2(290.0, 56.0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_menu.add_child(label)
		_option_labels.append(label)


# --- Party panel -------------------------------------------------------------------------

func _build_party_panel() -> void:
	_party_panel = PanelContainer.new()
	_party_panel.add_theme_stylebox_override(&"panel", _paper_box())
	_party_panel.visible = false
	add_child(_party_panel)
	# Centred; it grows both ways to fit however many creatures there are.
	_party_panel.set_anchors_preset(Control.PRESET_CENTER)
	_party_panel.offset_left = -470.0
	_party_panel.offset_right = 470.0
	_party_panel.offset_top = -100.0
	_party_panel.offset_bottom = -100.0
	_party_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	_party_panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_party_title = _label("", 28)
	_party_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_party_title)
	_party_seals = _label("", 22)
	header.add_child(_party_seals)

	_party_rows = VBoxContainer.new()
	_party_rows.add_theme_constant_override(&"separation", 10)
	column.add_child(_party_rows)

	var hint := _label("Su / giù: scorri     Z / Invio: scegli     X: indietro", 18)
	hint.modulate.a = 0.75
	column.add_child(hint)


func _build_party_rows(party: Party, active: Creature) -> void:
	for child in _party_rows.get_children():
		_party_rows.remove_child(child)
		child.queue_free()
	_row_panels.clear()

	for i in party.members.size():
		var creature := party.members[i]
		var row := PanelContainer.new()
		_party_rows.add_child(row)
		_row_panels.append(row)
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 14)
		row.add_child(line)

		var name_label := _label(creature.display_name(), 26)
		name_label.custom_minimum_size.x = 160.0
		line.add_child(name_label)

		var element: Dictionary = DB.ELEMENTS[creature.element()]
		var chip_box := _chip_box()
		chip_box.bg_color = element["color"]
		var chip := _label(element["name"], 18)
		chip.add_theme_stylebox_override(&"normal", chip_box)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.custom_minimum_size.x = 84.0
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(chip)

		var level := _label("Liv. %d" % creature.level, 20)
		level.custom_minimum_size.x = 64.0
		line.add_child(level)

		var ratio := _health_ratio(creature)
		var health := _build_bar(18.0, 150.0)
		(health["root"] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_set_bar(health["fill"], ratio, _health_color(ratio), false)
		line.add_child(health["root"])

		var numbers := _label("%d / %d" % [creature.hp, creature.max_hp()], 20)
		numbers.custom_minimum_size.x = 84.0
		numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(numbers)

		# What this creature is doing right now.
		var note := ""
		if creature.is_fainted():
			note = "esausto"
		elif creature == active:
			note = "in campo"
		elif i == 0:
			note = "guida"
		var note_label := _label(note, 18)
		note_label.custom_minimum_size.x = 84.0
		note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		note_label.modulate.a = 0.75
		line.add_child(note_label)


## Party rows: the selected one gets a heavy inked frame.
func _row_box(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER.lightened(0.35) if selected else PAPER.darkened(0.06)
	box.border_color = INK
	box.set_border_width_all(5 if selected else 2)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(12.0 if selected else 15.0)
	return box


# --- Small building blocks ------------------------------------------------------------------

func _build_bar(height: float, min_width: float) -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = Vector2(min_width, height)
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var frame := ColorRect.new()
	frame.color = INK
	root.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var trough := ColorRect.new()
	trough.color = PAPER.darkened(0.2)
	root.add_child(trough)
	_inset(trough, 1.0)

	var fill := ColorRect.new()
	root.add_child(fill)
	_inset(fill, 1.0)
	return {"root": root, "fill": fill}


## Anchors `rect` to its parent with a 3 px inset, filling `ratio` of the width.
func _inset(rect: Control, ratio: float) -> void:
	rect.anchor_left = 0.0
	rect.anchor_top = 0.0
	rect.anchor_right = ratio
	rect.anchor_bottom = 1.0
	rect.offset_left = 3.0
	rect.offset_top = 3.0
	rect.offset_right = -3.0
	rect.offset_bottom = -3.0


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", INK)
	return label


## Rounded tag behind an element's name; set its bg_color to the element colour.
func _chip_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(9)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 2.0
	return box


## Paper card with an inked border; uneven corners so it looks hand-cut.
func _paper_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.border_color = INK
	box.set_border_width_all(4)
	box.corner_radius_top_left = 20
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_right = 18
	box.corner_radius_bottom_left = 10
	box.set_content_margin_all(18.0)
	box.shadow_color = Color(INK, 0.28)
	box.shadow_size = 2
	box.shadow_offset = Vector2(5.0, 6.0)
	return box
