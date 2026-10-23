class_name Hud
extends CanvasLayer
## In-room HUD: room name and clock, rocks, the pulse meter, Dr. Varn's radio
## messages, the big centre titles, and a full-screen fade for transitions.

@onready var _room_label: Label = $Root/Top/RoomLabel
@onready var _stats_label: Label = $Root/Top/StatsLabel
@onready var _rocks_label: Label = $Root/Rocks
@onready var _pulse: PulseMeter = $Root/Pulse
@onready var _radio: PanelContainer = $Root/Radio
@onready var _radio_text: Label = $Root/Radio/Text
@onready var _title: Label = $Root/Title
@onready var _fade: ColorRect = $Root/Fade

var _radio_queue: Array[String] = []
var _radio_busy := false


func _ready() -> void:
	Events.inventory_changed.connect(_refresh_rocks)
	Events.radio.connect(say)
	Events.pulse_charge_changed.connect(_pulse.set_state)
	_room_label.text = Game.ROOMS[Game.room_index].name
	_radio.visible = false
	_title.modulate.a = 0.0
	_refresh_rocks()
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 0.5)


func _process(_delta: float) -> void:
	var t: float = Game.stats.time
	_stats_label.text = "DEATHS %d    %02d:%04.1f" % [Game.stats.deaths, int(t) / 60, fmod(t, 60.0)]


func _refresh_rocks() -> void:
	_rocks_label.text = "ROCKS  %d" % Game.rocks
	_rocks_label.modulate.a = 1.0 if Game.rocks > 0 else 0.4


func show_title(text: String, long_hold: bool) -> void:
	_title.text = text
	_title.add_theme_color_override("font_color", Color("d8f6ff"))
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.6 if long_hold else 0.6)
	tw.tween_property(_title, "modulate:a", 0.0, 0.8)


func show_death() -> void:
	_title.text = "SIGNAL LOST"
	_title.add_theme_color_override("font_color", Palette.color(Palette.Kind.ENEMY))
	var tw := create_tween()
	for i in 4:
		tw.tween_property(_title, "modulate:a", 1.0, 0.04)
		tw.tween_property(_title, "modulate:a", 0.2, 0.05)
	tw.tween_property(_title, "modulate:a", 1.0, 0.05)


func fade_out(seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, seconds)
	await tw.finished


## Dr. Varn on the radio. Messages queue up and type out one at a time.
func say(text: String) -> void:
	_radio_queue.append(text)
	if not _radio_busy:
		_next_radio()


func _next_radio() -> void:
	if _radio_queue.is_empty():
		_radio_busy = false
		create_tween().tween_property(_radio, "modulate:a", 0.0, 0.4).finished.connect(func(): _radio.visible = _radio_busy)
		return
	_radio_busy = true
	var text: String = _radio_queue.pop_front()
	_radio.visible = true
	_radio.modulate.a = 1.0
	_radio_text.text = "DR. VARN  >  " + text
	_radio_text.visible_ratio = 0.0
	Audio.play("radio")
	var tw := create_tween()
	tw.tween_property(_radio_text, "visible_ratio", 1.0, text.length() * 0.022)
	tw.tween_interval(2.4 + text.length() * 0.035)
	tw.finished.connect(_next_radio)
