extends CanvasLayer
## ESC / P / Start: pauses the tree. This layer keeps processing while paused
## (process_mode = Always); everything else in the room freezes.

@onready var _resume: Button = %Resume
@onready var _memory: Button = %Memory


func _ready() -> void:
	visible = false
	_resume.pressed.connect(toggle)
	%Restart.pressed.connect(Game.restart_room)
	_memory.pressed.connect(_toggle_memory)
	%Menu.pressed.connect(_to_menu)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	var room := get_parent() as Room
	if room and room._over and not visible:
		return
	visible = not visible
	get_tree().paused = visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_HIDDEN
	Audio.play("ui_ok" if visible else "ui_back")
	if visible:
		_resume.grab_focus()


func _toggle_memory() -> void:
	Game.map_memory = not Game.map_memory
	Game.save_settings()
	_refresh()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _refresh() -> void:
	_memory.text = "MAP MEMORY: %s" % ("ON" if Game.map_memory else "OFF (PURIST)")
