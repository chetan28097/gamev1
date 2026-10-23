extends Node
## Headless test suite. Runs real rooms with real physics and prints PASS/FAIL.
##   godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
## --fixed-fps makes every frame exactly 1/60 s, so the suite runs faster than
## real time and the results don't depend on how fast this machine is.

const TEST_ROOM := "res://tests/rooms/t_sound.tscn"
const CELL := 32.0

var _fails := 0
var _passes := 0
var _noises: Array[Dictionary] = []


func _ready() -> void:
	Game.persist = false
	Events.noise_emitted.connect(func(p: Vector2, l: float, k: StringName) -> void: _noises.append({"pos": p, "loudness": l, "kind": k}))
	await _run()
	print("\n%d passed, %d failed" % [_passes, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _run() -> void:
	await test_propagation()
	await test_pulse_reveal()
	await test_alert_goes_to_origin()
	await test_rock_retargets()
	await test_footstep_noise()
	await test_input_pulse()
	await test_contact_kills()
	await test_exit_clears()
	test_save_round_trip()
	await test_campaign_rooms()


# --- helpers ---------------------------------------------------------------

func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if ok:
		_passes += 1
	else:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(s: float) -> void:
	await frames(int(s * 60.0))


func cell(x: int, y: int) -> Vector2:
	return Vector2(x, y) * CELL + Vector2(CELL, CELL) * 0.5


func load_room(path: String) -> Room:
	var room: Room = load(path).instantiate()
	room.auto_respawn = false
	add_child(room)
	await frames(2)
	return room


func unload(room: Room) -> void:
	get_tree().paused = false
	room.queue_free()
	await frames(3)
	Input.action_release("pulse")
	for a in ["move_up", "move_down", "move_left", "move_right", "sprint", "sneak"]:
		Input.action_release(a)


func stalkers(room: Room) -> Array[Stalker]:
	var out: Array[Stalker] = []
	for n in room.find_children("*", "Stalker", true, false):
		out.append(n)
	return out


# --- tests -----------------------------------------------------------------

## Sound flows around corners through openings, but thick walls stop it.
func test_propagation() -> void:
	var room := await load_room(TEST_ROOM)
	var spawn := room.player().global_position
	var corner := SoundBus.travel_distance(spawn, cell(12, 7), 2000.0)
	var sealed := SoundBus.travel_distance(spawn, cell(14, 2), 2000.0)
	var straight := spawn.distance_to(cell(14, 2))
	check(corner < 500.0, "sound reaches round the corner (%.0f px travelled)" % corner)
	check(sealed > 760.0, "a thick wall muffles sound beyond a deep pulse (%.0f px vs %.0f straight)" % [sealed, straight])
	await unload(room)


## A pulse lights walls as the ring reaches them, and nothing behind a wall.
func test_pulse_reveal() -> void:
	var room := await load_room(TEST_ROOM)
	var origin := room.player().global_position
	SoundBus.emit_noise(origin, 0.0, &"pulse", null, 400.0)
	await frames(2)
	var early := room.echo.lit_count()
	await seconds(0.6)
	var lit := room.echo.lit_count()
	check(lit > 40, "pulse reveals wall fragments (%d lit)" % lit)
	check(early < lit, "the reveal travels outward (%d lit at once, %d later)" % [early, lit])
	var too_far := 0
	var leaked := 0
	for p in room.echo.fragments():
		if p.distance_to(origin) > 401.0:
			too_far += 1
		if p.x > 11.0 * CELL and p.y < 4.0 * CELL:
			leaked += 1
	check(too_far == 0, "no fragment beyond the pulse radius")
	check(leaked == 0, "no fragment inside the sealed chamber (%d)" % leaked)
	await seconds(1.6)
	check(room.echo.lit_count() == 0, "fragments fade out after ~1.5 s")
	await unload(room)


## Hunters run to where the noise was MADE, not to where the diver is now.
func test_alert_goes_to_origin() -> void:
	var room := await load_room(TEST_ROOM)
	var p := room.player()
	var all := stalkers(room)
	var sealed: Stalker = all[0] if all[0].global_position.y < 128.0 else all[1]
	var hunter: Stalker = all[1] if sealed == all[0] else all[0]
	var origin := p.global_position
	Game.stats.detections = 0
	SoundBus.emit_noise(origin, 500.0, &"pulse", p, 300.0)
	p.global_position = cell(2, 1)
	check(hunter.state == Stalker.State.IDLE, "the hunter does not react before the ring arrives")
	await seconds(0.8)
	check(hunter.state == Stalker.State.ALERTED, "the hunter is alerted by the pulse")
	check(hunter.target.distance_to(origin) < 1.0, "it heads for the pulse origin, not the diver")
	check(sealed.state == Stalker.State.IDLE, "the hunter behind the thick wall heard nothing")
	check(Game.stats.detections == 1, "a detection was counted")
	var closest := INF
	for i in 90:
		await frames(1)
		closest = minf(closest, hunter.global_position.distance_to(origin))
	check(closest < 12.0, "it reaches the spot the sound came from (%.0f px)" % closest)
	check(hunter.state == Stalker.State.SEARCH, "then searches around it")
	await unload(room)


func test_rock_retargets() -> void:
	var room := await load_room(TEST_ROOM)
	var p := room.player()
	var hunter: Stalker = stalkers(room).filter(func(s: Stalker) -> bool: return s.global_position.y > 128.0)[0]
	var before := Game.rocks
	var aim := cell(16, 6)
	p.global_position = cell(10, 6)
	await frames(2)
	p.throw_rock(aim)
	check(Game.rocks == before - 1, "throwing spends a rock")
	await seconds(1.2)
	check(hunter.state == Stalker.State.ALERTED or hunter.state == Stalker.State.SEARCH, "the rock's landing alerts the hunter")
	check(hunter.target.distance_to(aim) < 48.0, "it heads for the landing spot")
	await unload(room)


## Sprinting is loud, walking is quiet, sneaking is silent.
func test_footstep_noise() -> void:
	var room := await load_room(TEST_ROOM)
	var loud := {}
	for mode in [["walk", "move_down"], ["sprint", "move_up"], ["sneak", "move_down"]]:
		_noises.clear()
		if mode[0] != "walk":
			Input.action_press(mode[0])
		Input.action_press(mode[1])
		await seconds(0.8)
		Input.action_release(mode[1])
		if mode[0] != "walk":
			Input.action_release(mode[0])
		var steps := _noises.filter(func(n: Dictionary) -> bool: return n.kind == &"footstep")
		loud[mode[0]] = 0.0 if steps.is_empty() else steps.map(func(n: Dictionary) -> float: return n.loudness).max()
		await frames(10)
	check(loud.sprint > loud.walk and loud.walk > 0.0, "sprint steps (%.0f) carry further than walking (%.0f)" % [loud.sprint, loud.walk])
	check(loud.sneak == 0.0, "sneaking makes no footstep noise")
	await unload(room)


func test_input_pulse() -> void:
	var room := await load_room(TEST_ROOM)
	var before: int = Game.stats.pulses
	Input.action_press("pulse")
	await frames(3)
	Input.action_release("pulse")
	await seconds(0.4)
	check(Game.stats.pulses == before + 1, "tapping SPACE fires one pulse")
	check(room.echo.lit_count() > 10, "the tap ping reveals nearby walls")
	Input.action_press("pulse")
	await seconds(1.0)
	check(room.player()._charging and room.player().charge_ratio() >= 1.0, "holding SPACE charges a deep pulse")
	Input.action_release("pulse")
	await frames(2)
	check(not room.player()._charging, "releasing fires it")
	await unload(room)


func test_contact_kills() -> void:
	var room := await load_room(TEST_ROOM)
	var died := [false]
	var on_died := func(_k: Node2D) -> void: died[0] = true
	Events.player_died.connect(on_died)
	var hunter: Stalker = stalkers(room)[1]
	room.player().global_position = hunter.global_position + Vector2(8, 0)
	await frames(3)
	check(died[0] and not room.player().alive, "touching a hunter kills the diver")
	Events.player_died.disconnect(on_died)
	await unload(room)


func test_exit_clears() -> void:
	var room := await load_room(TEST_ROOM)
	var cleared := [false]
	var on_clear := func() -> void: cleared[0] = true
	Events.room_cleared.connect(on_clear)
	room.player().global_position = cell(17, 7) + Vector2(-20, 0)
	room.player().velocity = Vector2(400, 0)
	await frames(10)
	check(cleared[0], "walking into the exit clears the room")
	Events.room_cleared.disconnect(on_clear)
	await unload(room)


func test_save_round_trip() -> void:
	Game.persist = true
	Game.save_path = "user://test_save.cfg"
	var keep_best := Game.best.duplicate(true)
	var keep_unlocked := Game.unlocked
	Game.best = {"res://x.tscn": {"time": 12.5, "rank": "A"}}
	Game.unlocked = 3
	Game.save_settings()
	Game.best = {}
	Game.unlocked = 1
	Game._load()
	check(Game.unlocked == 3 and Game.best.get("res://x.tscn", {}).get("rank", "") == "A", "save file round-trips progress")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	Game.best = keep_best
	Game.unlocked = keep_unlocked
	Game.save_path = "user://save.cfg"
	Game.persist = false


## Every campaign room: the exit is reachable, and no hunter starts within
## earshot of a tap ping from the spawn point.
func test_campaign_rooms() -> void:
	var ping: float = (load("res://scenes/player/player.tscn").instantiate() as Player).ping_loudness
	for i in Game.ROOMS.size():
		var info: Dictionary = Game.ROOMS[i]
		Game.room_index = i
		var room := await load_room(info.path)
		var spawn := room.player().global_position
		var exit_pos: Vector2 = room.find_child("Exit", true, false).global_position
		var route := SoundBus.grid.path(spawn, exit_pos)
		check(not route.is_empty(), "%s: exit reachable from spawn (%d cells)" % [info.name, route.size()])
		var nearest := INF
		for s in stalkers(room):
			nearest = minf(nearest, SoundBus.travel_distance(spawn, s.global_position, 2000.0))
		check(nearest > ping, "%s: no hunter hears a ping from the spawn point" % info.name)
		await unload(room)
