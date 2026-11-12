extends Node3D
## A creature standing in the world: its model plus the small battle animations.
## Three layers so effects never fight each other:
##   this node (placement and facing) > _bob (idle bounce) > _model (tweens).
## The animation methods are coroutines: `await actor.lunge()`.

const Visuals := preload("res://scripts/creature_visual.gd")

## Gentle idle bounce. The partner turns this off: it has its own hop.
var idle_bob := true

var _bob: Node3D
var _model: Node3D
var _time := 0.0


func setup(species_id: String) -> void:
	_bob = Node3D.new()
	_bob.name = "Bob"
	add_child(_bob)
	_model = Visuals.build(species_id)
	_bob.add_child(_model)
	_time = randf() * 10.0


func _process(delta: float) -> void:
	if _bob == null:
		return
	_time += delta
	_bob.position.y = absf(sin(_time * 2.6)) * 0.035 if idle_bob else 0.0


## Turns to look at a world position.
func face_towards(point: Vector3) -> void:
	var dir := point - global_position
	if Vector2(dir.x, dir.z).length() > 0.01:
		rotation.y = atan2(-dir.x, -dir.z)


## Pops up out of nothing, with a little overshoot.
func pop_in() -> void:
	_model.visible = true
	_model.position = Vector3.ZERO
	_model.scale = Vector3.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


## Darts forward to strike. Returns at the moment of impact; the step back
## plays on its own.
func lunge() -> void:
	var strike := create_tween()
	strike.tween_property(_model, "position", Vector3(0.0, 0.06, -0.42), 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await strike.finished
	var recover := create_tween()
	recover.tween_property(_model, "position", Vector3.ZERO, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Shakes and squashes after taking a hit.
func hurt() -> void:
	var squash := create_tween()
	squash.tween_property(_model, "scale", Vector3(1.18, 0.78, 1.18), 0.07)
	squash.tween_property(_model, "scale", Vector3.ONE, 0.22)
	var shake := create_tween()
	for i in 3:
		shake.tween_property(_bob, "position:x", 0.07, 0.04)
		shake.tween_property(_bob, "position:x", -0.07, 0.04)
	shake.tween_property(_bob, "position:x", 0.0, 0.04)
	await shake.finished


## Swells briefly: used for healing, guarding and levelling up.
func pulse() -> void:
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE * 1.22, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "scale", Vector3.ONE, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## Flattens to the ground and disappears.
func faint() -> void:
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3(1.3, 0.04, 1.3), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	_model.visible = false


## Shrinks away: a wild creature slipping back into the grass.
func vanish() -> void:
	if not _model.visible:
		return
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	_model.visible = false


## Back on its feet after fainting.
func revive() -> void:
	_model.visible = true
	_model.scale = Vector3.ONE
	_model.position = Vector3.ZERO
