extends CanvasLayer
## Shown when the diver reaches the exit: stats, rank, continue / retry.

const RANK_COLORS := {"S": Color("39ff9c"), "A": Color("2fd8ff"), "B": Color("ffc85a"), "C": Color("ff3355")}

@onready var _name: Label = %RoomName
@onready var _stats: Label = %Stats
@onready var _rank: Label = %Rank
@onready var _next: Button = %Next


func _ready() -> void:
	%Panel.modulate.a = 0.0
	_next.pressed.connect(Game.next_room)
	%Retry.pressed.connect(Game.restart_room)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func setup(room_name: String, stats: Dictionary, rank: String, par: float) -> void:
	var t: float = stats.time
	_name.text = room_name + "  //  CLEAR"
	_stats.text = "TIME        %02d:%04.1f  (par %ds)\nPULSES      %d\nDETECTED    %d\nDEATHS      %d" % [
		int(t) / 60, fmod(t, 60.0), int(par), stats.pulses, stats.detections, stats.deaths]
	_rank.text = rank
	_rank.add_theme_color_override("font_color", RANK_COLORS.get(rank, Color.WHITE))
	if Game.room_index + 1 >= Game.ROOMS.size():
		_next.text = "FINISH  >  MENU"
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(%Panel, "modulate:a", 1.0, 0.5)
	tw.tween_callback(_next.grab_focus)
