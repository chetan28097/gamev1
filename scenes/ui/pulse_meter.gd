class_name PulseMeter
extends Control
## Bottom-centre meter: fills while SPACE is held (ping -> deep pulse) and shows
## the cooldown afterwards.

var _charge := 0.0
var _cooldown := 0.0


func set_state(charge: float, cooldown: float) -> void:
	if not is_equal_approx(charge, _charge) or not is_equal_approx(cooldown, _cooldown):
		_charge = charge
		_cooldown = cooldown
		queue_redraw()


func _draw() -> void:
	var cyan := Palette.color(Palette.Kind.WALL)
	var w := size.x
	var y := size.y - 6.0
	draw_line(Vector2(0, y), Vector2(w, y), Color(cyan, 0.18), 4.0)
	if _cooldown > 0.0:
		draw_line(Vector2(0, y), Vector2(w * (1.0 - _cooldown), y), Color(cyan, 0.35), 4.0)
	elif _charge > 0.0:
		var c := Color.WHITE if _charge >= 1.0 else cyan
		draw_line(Vector2(0, y), Vector2(w * _charge, y), c, 4.0)
	else:
		draw_line(Vector2(0, y), Vector2(w, y), Color(cyan, 0.6), 4.0)
	var label := "DEEP PULSE" if _charge >= 1.0 else ("CHARGING" if _charge > 0.0 else "PULSE")
	var font := get_theme_default_font()
	var sw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2((w - sw) * 0.5, y - 10.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(cyan, 0.75))
