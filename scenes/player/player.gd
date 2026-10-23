class_name Player
extends CharacterBody2D
## The diver. Moves, pulses (tap = short ping, hold = deep pulse), throws rocks.
## The diver never fights. Everything they do is a sound, and every sound is a risk.

const ROCK_SCENE := preload("res://scenes/objects/rock.tscn")

@export_group("Movement")
@export var walk_speed := 135.0
@export var sprint_speed := 225.0
@export var sneak_speed := 62.0
@export var accel := 1500.0
@export var friction := 1900.0

@export_group("Pulse")
@export var ping_radius := 230.0
@export var ping_loudness := 260.0
@export var deep_radius := 620.0
@export var deep_loudness := 760.0
## Seconds of holding for a full deep pulse.
@export var charge_time := 0.8
## Releases shorter than this are a plain ping.
@export var tap_time := 0.16
@export var cooldown := 0.6

@export_group("Noise")
@export var sprint_step_interval := 0.27
@export var walk_step_interval := 0.46
@export var sprint_step_loudness := 190.0
@export var walk_step_loudness := 48.0

@export_group("Throw")
@export var throw_range := 380.0

var alive := true
var _charging := false
## SPACE pressed during the cooldown: start charging as soon as it ends.
var _pulse_buffered := false
var _charge := 0.0
var _cooldown_left := 0.0
var _step_timer := 0.0
var _trail_timer := 0.0
var _glow := 0.0
var _aim_point := Vector2.ZERO
var _using_pad_aim := false


func _ready() -> void:
	add_to_group(&"player")
	z_index = 11


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_glow = maxf(_glow - delta * 2.0, 0.0)
	if not alive:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var mode := &"walk"
	var speed := walk_speed
	if Input.is_action_pressed("sneak"):
		mode = &"sneak"
		speed = sneak_speed
	elif Input.is_action_pressed("sprint"):
		mode = &"sprint"
		speed = sprint_speed
	if _charging:
		speed *= 0.55  # bracing for a deep pulse
	var rate := accel if input != Vector2.ZERO else friction
	velocity = velocity.move_toward(input * speed, rate * delta)
	move_and_slide()

	_footsteps(delta, mode)
	_pulse_input(delta)
	_update_aim()
	if Input.is_action_just_pressed("throw"):
		throw_rock(_aim_point)
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.15
		var trail: PackedVector2Array = Game.stats.trail
		if trail.size() < 6000:
			trail.append(global_position)
			Game.stats.trail = trail
	queue_redraw()


func _footsteps(delta: float, mode: StringName) -> void:
	if velocity.length() < 30.0 or mode == &"sneak":
		_step_timer = minf(_step_timer, 0.12)
		return
	_step_timer -= delta
	if _step_timer > 0.0:
		return
	var sprinting := mode == &"sprint"
	_step_timer = sprint_step_interval if sprinting else walk_step_interval
	var loudness := sprint_step_loudness if sprinting else walk_step_loudness
	SoundBus.emit_noise(global_position, loudness, &"footstep", self)
	Audio.play("step", global_position, 0.0 if sprinting else -9.0, 1.0 if sprinting else 0.9)
	# Show the player how far their own footsteps carry.
	Events.blip.emit(global_position, Color(Palette.PLAYER, 0.18 if sprinting else 0.08), loudness * 0.8)


func _pulse_input(delta: float) -> void:
	if Input.is_action_just_pressed("pulse"):
		_pulse_buffered = true
	if not Input.is_action_pressed("pulse") and not _charging:
		_pulse_buffered = false
	if _pulse_buffered and not _charging and _cooldown_left <= 0.0:
		_pulse_buffered = false
		_charging = true
		_charge = 0.0
	if not _charging:
		Events.pulse_charge_changed.emit(0.0, _cooldown_left / cooldown)
		return
	_charge += delta
	Events.pulse_charge_changed.emit(charge_ratio(), 0.0)
	if not Input.is_action_pressed("pulse"):
		fire_pulse(charge_ratio())


## 0 for a tap (ping) .. 1 for a fully charged deep pulse.
func charge_ratio() -> float:
	if not _charging:
		return 0.0
	return clampf((_charge - tap_time) / (charge_time - tap_time), 0.0, 1.0)


func fire_pulse(ratio: float) -> void:
	_charging = false
	var deep := ratio >= 0.999
	var radius := lerpf(ping_radius, deep_radius, ratio)
	var loudness := lerpf(ping_loudness, deep_loudness, ratio)
	SoundBus.emit_noise(global_position, loudness, &"pulse", self, radius, deep)
	if ratio < 0.5:
		Audio.play("ping", global_position, 0.0, lerpf(1.08, 0.85, ratio * 2.0))
	else:
		Audio.play("deep", global_position, 0.0, lerpf(1.25, 1.0, (ratio - 0.5) * 2.0))
		Audio.play("deep_layer", global_position, -4.0 + ratio * 4.0)
	Game.stats.pulses += 1
	_cooldown_left = cooldown + (0.35 if deep else 0.0)
	_glow = 1.0
	get_tree().call_group(&"post_fx", &"kick", 0.25 + ratio * 0.75)


func _update_aim() -> void:
	var pad := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if pad.length() > 0.3:
		_using_pad_aim = true
		_aim_point = global_position + pad.normalized() * throw_range * pad.length()
	elif not _using_pad_aim or Input.get_last_mouse_velocity().length() > 1.0:
		_using_pad_aim = false
		_aim_point = get_global_mouse_position()


func throw_rock(at: Vector2) -> void:
	if Game.rocks <= 0:
		Audio.play("empty")
		return
	var to := global_position + (at - global_position).limit_length(throw_range)
	var q := PhysicsRayQueryParameters2D.create(global_position, to, 1 | 16)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		to = hit.position + hit.normal * 10.0
	var rock := ROCK_SCENE.instantiate()
	get_parent().add_child(rock)
	rock.launch(global_position, to)
	Game.set_rocks(Game.rocks - 1)
	Audio.play("throw", global_position)


func kill(killer: Node2D) -> void:
	if not alive:
		return
	alive = false
	_charging = false
	Events.player_died.emit(killer)


## Stops all control (room clear, cutscenes).
func freeze() -> void:
	alive = false
	_charging = false


func _draw() -> void:
	var c := Palette.PLAYER
	draw_circle(Vector2.ZERO, 14.0, Color(c, 0.04 + _glow * 0.10))
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 24, Color(c, 0.22 + _glow * 0.5), 1.5)
	draw_circle(Vector2.ZERO, 3.5, Color(c, 0.95 if alive else 0.4))
	if velocity.length() > 10.0:
		var f := velocity.normalized()
		draw_line(f * 6.0, f * 12.0, Color(c, 0.5), 2.0)
	if _charging:
		var r := charge_ratio()
		var col := Color(Palette.color(Palette.Kind.WALL), 0.25 + r * 0.55)
		draw_arc(Vector2.ZERO, lerpf(14.0, 34.0, r), -PI / 2.0, -PI / 2.0 + TAU * maxf(r, 0.05), 48, col, 2.0)
		if r >= 1.0:
			draw_arc(Vector2.ZERO, 34.0 + sin(Time.get_ticks_msec() / 60.0) * 2.0, 0.0, TAU, 48, Color(col, 0.35), 1.0)
	if alive and Game.rocks > 0:
		var local := to_local(global_position + (_aim_point - global_position).limit_length(throw_range))
		var rc := Color(Palette.color(Palette.Kind.PICKUP), 0.45)
		draw_arc(local, 6.0, 0.0, TAU, 16, rc, 1.0)
		draw_line(local + Vector2(-10, 0), local + Vector2(-4, 0), rc, 1.0)
		draw_line(local + Vector2(4, 0), local + Vector2(10, 0), rc, 1.0)
		draw_line(local + Vector2(0, -10), local + Vector2(0, -4), rc, 1.0)
		draw_line(local + Vector2(0, 4), local + Vector2(0, 10), rc, 1.0)
