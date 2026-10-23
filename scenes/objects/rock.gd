extends Node2D
## A thrown rock: arcs to its target, then makes a loud noise where it lands.
## The landing reveals the area around it and pulls every listener in earshot.

@export var landing_loudness := 520.0
@export var landing_reveal := 300.0

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _dur := 0.5
var _height := 0.0


func launch(from: Vector2, to: Vector2) -> void:
	_from = from
	_to = to
	_dur = 0.2 + from.distance_to(to) / 900.0
	global_position = from
	z_index = 11


func _process(delta: float) -> void:
	_t += delta
	var k := minf(_t / _dur, 1.0)
	global_position = _from.lerp(_to, k)
	_height = sin(k * PI) * (14.0 + _from.distance_to(_to) * 0.08)
	queue_redraw()
	if k >= 1.0:
		_land()


func _land() -> void:
	set_process(false)
	SoundBus.emit_noise(global_position, landing_loudness, &"rock", self, landing_reveal)
	Audio.play("rock", global_position)
	Events.blip.emit(global_position, Color(Palette.color(Palette.Kind.PICKUP), 0.9), 40.0)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 2.5, Color(0.6, 0.7, 0.8, 0.25))
	draw_circle(Vector2(0, -_height), 3.0, Color(0.85, 0.9, 1.0, 0.7))
