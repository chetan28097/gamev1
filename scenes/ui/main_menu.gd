extends Control
## Title screen: start / continue, room select with best ranks, map memory
## toggle, quit. Fully keyboard and gamepad navigable.

@onready var _start: Button = %Start
@onready var _rooms_btn: Button = %Rooms
@onready var _memory: Button = %Memory
@onready var _room_list: VBoxContainer = %RoomList

var _resume := 0


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.start_ambience()
	_resume = mini(Game.unlocked, Game.ROOMS.size()) - 1
	_start.text = "CONTINUE  //  " + Game.ROOMS[_resume].name if _resume > 0 else "BEGIN DESCENT"
	_start.pressed.connect(func() -> void: _go(_resume))
	_rooms_btn.pressed.connect(_toggle_rooms)
	_memory.pressed.connect(_toggle_memory)
	%Quit.pressed.connect(get_tree().quit)
	for i in Game.ROOMS.size():
		var room: Dictionary = Game.ROOMS[i]
		var best: Dictionary = Game.best.get(room.path, {})
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = room.name
		if not best.is_empty():
			b.text += "    %s   %02d:%04.1f" % [best.rank, int(best.time) / 60, fmod(best.time, 60.0)]
		b.disabled = i >= Game.unlocked
		b.pressed.connect(_go.bind(i))
		_room_list.add_child(b)
	_room_list.visible = false
	for b in find_children("*", "Button", true, false):
		b.focus_entered.connect(Audio.play.bind("ui_move"))
	_refresh()
	_start.grab_focus()


func _toggle_rooms() -> void:
	_room_list.visible = not _room_list.visible
	if _room_list.visible:
		_room_list.get_child(0).grab_focus()


func _toggle_memory() -> void:
	Game.map_memory = not Game.map_memory
	Game.save_settings()
	_refresh()


func _refresh() -> void:
	_memory.text = "MAP MEMORY: %s" % ("ON" if Game.map_memory else "OFF (PURIST)")


func _go(index: int) -> void:
	Audio.play("ui_ok")
	Game.start_room(index)
