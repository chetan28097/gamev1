extends Node
## Run state that survives scene changes: which room, stats, inventory, saves.


## Campaign order. `par` is the target time (seconds) for an S rank.
const ROOMS: Array[Dictionary] = [
	{"path": "res://scenes/rooms/ch1_01.tscn", "name": "1-1  WAKE", "par": 70.0},
	{"path": "res://scenes/rooms/ch1_02.tscn", "name": "1-2  LISTEN", "par": 60.0},
	{"path": "res://scenes/rooms/ch1_03.tscn", "name": "1-3  DECOY", "par": 60.0},
]

var room_index := 0
## Bumped on every fresh room start; a death-reload keeps it (and the echo memory).
var session := 0
var rocks := 0
var debug_overlay := false
## Map memory: revealed walls linger as a faint ghost. Purist mode turns it off.
var map_memory := true

## Stats for the current attempt at the current room (kept across deaths).
var stats := {}
## Echo memory of the current room, kept across deaths so dying still teaches.
var echo_memory: Dictionary = {}
## Best result per room path: {"time": float, "rank": String}
var best: Dictionary = {}
var unlocked := 1
## Tests point this elsewhere (or turn persist off) so they never touch real saves.
var save_path := "user://save.cfg"
var persist := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	reset_stats()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_overlay"):
		debug_overlay = not debug_overlay


func start_room(index: int) -> void:
	room_index = clampi(index, 0, ROOMS.size() - 1)
	session += 1
	reset_stats()
	echo_memory = {}
	get_tree().paused = false
	get_tree().change_scene_to_file(ROOMS[room_index].path)


func restart_room() -> void:
	start_room(room_index)


## After a death: reload the room but keep stats and echo memory.
func respawn() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func next_room() -> void:
	if room_index + 1 < ROOMS.size():
		start_room(room_index + 1)
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func reset_stats() -> void:
	stats = {"time": 0.0, "pulses": 0, "detections": 0, "deaths": 0, "trail": PackedVector2Array()}


func set_rocks(value: int) -> void:
	rocks = maxi(value, 0)
	Events.inventory_changed.emit()


func rank_for(s: Dictionary, par: float) -> String:
	if s.deaths == 0 and s.detections == 0 and s.time <= par:
		return "S"
	if s.deaths == 0 and s.detections <= 1:
		return "A"
	if s.deaths <= 2:
		return "B"
	return "C"


## Records the result for the current room; returns the rank.
func finish_room() -> String:
	var room: Dictionary = ROOMS[room_index]
	var r := rank_for(stats, room.par)
	var prev: Dictionary = best.get(room.path, {"time": INF, "rank": "C"})
	best[room.path] = {"time": minf(prev.time, stats.time), "rank": _better_rank(r, prev.rank)}
	unlocked = maxi(unlocked, mini(room_index + 2, ROOMS.size()))
	_save()
	return r


func _rank_value(r: String) -> int:
	return "CBAS".find(r)


func _better_rank(a: String, b: String) -> String:
	return a if _rank_value(a) >= _rank_value(b) else b


func _save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "best", best)
	cfg.set_value("settings", "map_memory", map_memory)
	cfg.save(save_path)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	unlocked = cfg.get_value("progress", "unlocked", 1)
	best = cfg.get_value("progress", "best", {})
	map_memory = cfg.get_value("settings", "map_memory", true)


func save_settings() -> void:
	_save()
