extends Node3D
## Turns the windmill's sails about their hub. The speed drifts up and down so
## the mill looks as if it were answering the gusts.

@export var turns_per_minute := 8.0

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	var gust := 0.8 + 0.3 * sin(_time * 0.37) + 0.12 * sin(_time * 1.3 + 1.7)
	rotate_z(-TAU * turns_per_minute / 60.0 * gust * delta)
