extends CanvasLayer
## Owns the full-screen post shader. Gameplay pokes it through the "post_fx"
## group: kick() on pulses and deaths, beat() on every heartbeat.

@onready var _mat: ShaderMaterial = $Screen.material

var _aberration := 0.0
var _beat := 0.0
var _danger := 0.0


func _ready() -> void:
	add_to_group(&"post_fx")


func kick(amount: float) -> void:
	_aberration = maxf(_aberration, amount)


func beat(danger: float) -> void:
	_beat = 1.0
	_danger = danger


func _process(delta: float) -> void:
	_aberration = move_toward(_aberration, 0.0, delta * 2.4)
	_beat = move_toward(_beat, 0.0, delta * 3.0)
	_mat.set_shader_parameter(&"aberration", _aberration)
	_mat.set_shader_parameter(&"heartbeat", _beat)
	_mat.set_shader_parameter(&"danger", _danger)
