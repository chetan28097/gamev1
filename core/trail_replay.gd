class_name TrailReplay
extends Node2D
## Room-clear flourish: redraws the route the diver took as a glowing line.

const DURATION := 2.2

var points := PackedVector2Array()
var _t := 0.0


func _ready() -> void:
	z_index = 12
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	var n := clampi(int(points.size() * minf(_t / DURATION, 1.0)), 2, points.size())
	var shown := points.slice(0, n)
	var c := Palette.PLAYER
	draw_polyline(shown, Color(c, 0.12), 7.0)
	draw_polyline(shown, Color(c, 0.75), 1.5)
	draw_circle(shown[shown.size() - 1], 4.0, c)
