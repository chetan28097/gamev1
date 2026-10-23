class_name Stalker
extends CharacterBody2D
## A blind hunter. It cannot see the diver at all. It only hears.
## Any noise that reaches it (see SoundBus) sends it sprinting to where the
## noise was MADE, not to where the diver is now. That gap is the whole game.
##
## IDLE   -> shuffles around its post, growling now and then (heard, never seen)
## ALERTED-> sprints along the grid path to the sound
## SEARCH -> sniffs around that spot for a few seconds
## RETURN -> walks back to its post

enum State { IDLE, ALERTED, SEARCH, RETURN }

## Multiplier on how far away it can hear. Read by SoundBus.
@export var hearing := 1.0
@export var idle_speed := 38.0
@export var chase_speed := 250.0
@export var search_speed := 95.0
@export var return_speed := 85.0
@export var search_time := 3.5
@export var kill_radius := 21.0
@export var wander_cells := 2

var state := State.IDLE
var target := Vector2.ZERO
var _post := Vector2.ZERO
var _path := PackedVector2Array()
var _speed := 0.0
var _timer := 0.0
var _growl_timer := 0.0
var _step_timer := 0.0
var _stuck := 0.0
var _reveal := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"listeners")
	add_to_group(&"enemies")
	z_index = 9
	_post = global_position
	target = global_position
	_rng.seed = hash(str(get_path())) ^ int(global_position.x * 13.0 + global_position.y)
	_growl_timer = _rng.randf_range(1.5, 5.0)
	_timer = _rng.randf_range(0.5, 2.5)


func hear(origin: Vector2, kind: StringName, by_player: bool) -> void:
	var was_calm := state == State.IDLE or state == State.RETURN
	target = origin
	_go(origin, chase_speed)
	state = State.ALERTED
	if was_calm:
		if by_player:
			Game.stats.detections += 1
		Audio.play("stalker_alert", global_position, 0.0, _rng.randf_range(0.5, 0.6))
		Events.blip.emit(global_position, Palette.color(Palette.Kind.ENEMY), 48.0)
	Events.enemy_alerted.emit(self, origin)


## Make the body visible for a moment (kill-cam, room clear).
func reveal(seconds: float) -> void:
	_reveal = seconds
	queue_redraw()


func _physics_process(delta: float) -> void:
	var grid := SoundBus.grid
	if grid == null:
		return
	match state:
		State.IDLE:
			_timer -= delta
			if _path.is_empty() and _timer <= 0.0:
				_timer = _rng.randf_range(2.5, 5.5)
				_go(grid.random_open_near(_post, wander_cells, _rng), idle_speed)
		State.ALERTED:
			if _path.is_empty():
				state = State.SEARCH
				_timer = search_time
		State.SEARCH:
			_timer -= delta
			if _timer <= 0.0:
				state = State.RETURN
				_go(_post, return_speed)
			elif _path.is_empty():
				_go(grid.random_open_near(target, 3, _rng), search_speed)
		State.RETURN:
			if _path.is_empty():
				state = State.IDLE
				_timer = _rng.randf_range(1.0, 3.0)
	_follow_path(delta)
	_make_noises(delta)
	_check_contact()
	_reveal = maxf(_reveal - delta, 0.0)
	if Game.debug_overlay or _reveal > 0.0:
		queue_redraw()


func _go(where: Vector2, speed: float) -> void:
	_path = SoundBus.grid.path(global_position, where)
	if not _path.is_empty():
		_path[_path.size() - 1] = where  # finish on the exact spot, not the cell centre
	_speed = speed
	_stuck = 0.0


func _follow_path(delta: float) -> void:
	if _path.is_empty():
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		move_and_slide()
		return
	var to := _path[0] - global_position
	if to.length() < 6.0:
		_path.remove_at(0)
		if _path.is_empty():
			return
		to = _path[0] - global_position
	velocity = velocity.move_toward(to.normalized() * _speed, 2400.0 * delta)
	move_and_slide()
	# Wedged on a corner? Give up on this path; the state machine picks a new one.
	_stuck = _stuck + delta if get_real_velocity().length() < _speed * 0.2 else 0.0
	if _stuck > 0.6:
		_path.clear()


func _make_noises(delta: float) -> void:
	var moving := velocity.length() > 20.0
	if moving:
		_step_timer -= delta
		if _step_timer <= 0.0:
			var fast := state == State.ALERTED
			_step_timer = 0.24 if fast else 0.62
			Audio.play("stalker_step", global_position, 0.0 if fast else -10.0, _rng.randf_range(0.55, 0.7))
			if fast:
				Events.blip.emit(global_position, Color(Palette.color(Palette.Kind.ENEMY), 0.35), 14.0)
	if state == State.IDLE or state == State.SEARCH:
		_growl_timer -= delta
		if _growl_timer <= 0.0:
			_growl_timer = _rng.randf_range(4.0, 8.0)
			Audio.play("stalker_growl", global_position, 0.0, _rng.randf_range(0.45, 0.6))
			Events.blip.emit(global_position, Color(Palette.color(Palette.Kind.ENEMY), 0.6), 30.0)


func _check_contact() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player and player.alive and global_position.distance_to(player.global_position) < kill_radius:
		player.kill(self)


func _draw() -> void:
	var red := Palette.color(Palette.Kind.ENEMY)
	var k := clampf(_reveal, 0.0, 1.0)
	if Game.debug_overlay:
		k = maxf(k, 0.6)
		for i in _path.size():
			var a := to_local(_path[i - 1]) if i > 0 else Vector2.ZERO
			draw_line(a, to_local(_path[i]), Color(red, 0.4), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-20, -18), State.keys()[state], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(red, 0.8))
	if k <= 0.0:
		return
	draw_circle(Vector2.ZERO, 12.0, Color(red, 0.35 * k))
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, Color(red, 0.9 * k), 2.0)
	for i in 5:
		var ang := TAU * i / 5.0 + Time.get_ticks_msec() / 900.0
		draw_line(Vector2.from_angle(ang) * 12.0, Vector2.from_angle(ang) * 18.0, Color(red, 0.6 * k), 1.5)
