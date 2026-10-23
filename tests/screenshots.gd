extends Node
## Renders a few key moments to tests/screenshots/*.png (needs a real window,
## so run WITHOUT --headless):
##   godot --path . res://tests/screenshots.tscn

const OUT := "res://tests/screenshots/"


func _ready() -> void:
	Game.persist = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await _wait(1.2)
	await _shot("01_menu")
	menu.queue_free()
	await _wait(0.1)

	Game.room_index = 1
	var room: Room = load("res://scenes/rooms/ch1_02.tscn").instantiate()
	room.auto_respawn = false
	add_child(room)
	await _wait(0.6)
	await _shot("02_dark_start")
	var p := room.player()
	p.global_position = Vector2(560, 272)
	await _wait(0.3)
	p.fire_pulse(0.0)
	await _wait(0.28)
	await _shot("03_ping")
	await _wait(1.6)
	p.fire_pulse(1.0)
	await _wait(0.55)
	await _shot("04_deep_pulse")
	p.global_position = Vector2(304, 528)  # pulse, then MOVE AWAY
	await _wait(2.5)
	await _shot("05_memory_ghost")
	Events.radio.emit("When you pulse, it runs to where you WERE. Pulse, then move away.")
	await _wait(2.0)
	await _shot("06_radio")
	p.kill(room.find_children("*", "Stalker", true, false)[0])
	await _wait(0.4)
	await _shot("07_killcam")
	room.queue_free()
	await _wait(0.2)

	Game.room_index = 2
	room = load("res://scenes/rooms/ch1_03.tscn").instantiate()
	add_child(room)
	await _wait(0.5)
	Game.stats.time = 41.3
	Game.stats.pulses = 9
	Events.room_cleared.emit()
	await _wait(2.6)
	await _shot("08_room_clear")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + shot_name + ".png"))
	print("saved ", shot_name)
