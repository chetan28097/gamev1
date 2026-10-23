class_name Room
extends Node2D
## Root of every room scene. The room's geometry is painted in TileMapLayers
## (Floor, Walls) like any Godot level, but hidden in-game. The world is
## black until it is heard. This script builds the sound grid, adds the
## per-room runtime layers (echo, HUD, post-FX, pause), and runs death and
## room-clear sequences.

@export var room_name := "ROOM"
@export var start_rocks := 0
## Off in tests: a death then leaves the room as it is instead of reloading.
@export var auto_respawn := true

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const POST_FX_SCENE := preload("res://scenes/fx/post_fx.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const CLEAR_SCENE := preload("res://scenes/ui/room_clear.tscn")

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls: TileMapLayer = $Walls

var echo: EchoRenderer
var hud: Hud
var _over := false
## 0 = geometry hidden, 1 = fully shown (kill-cam, room clear).
var _reveal := 0.0
var _heartbeat_timer := 0.0
var _drip_timer := 2.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	walls.set_meta(&"echo_kind", Palette.Kind.WALL)
	SoundBus.set_grid(PropagationGrid.new(floor_layer, walls))
	echo = EchoRenderer.new()
	echo.name = "Echo"
	add_child(echo)
	var debug := DebugOverlay.new()
	debug.name = "DebugOverlay"
	add_child(debug)
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	add_child(POST_FX_SCENE.instantiate())
	add_child(PAUSE_SCENE.instantiate())
	Game.set_rocks(start_rocks)
	Events.player_died.connect(_on_player_died)
	Events.room_cleared.connect(_on_room_cleared)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Audio.start_ambience()
	hud.show_title(room_name, Game.stats.deaths == 0)
	_apply_visibility()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _process(delta: float) -> void:
	if not _over:
		Game.stats.time += delta
	if Input.is_action_just_pressed("restart") and not _over:
		Game.restart_room()
	_apply_visibility()
	_heartbeat(delta)
	_drips(delta)


func _apply_visibility() -> void:
	var a := _reveal * 0.7
	if Game.debug_overlay:
		a = maxf(a, 0.3)
	walls.modulate.a = a
	floor_layer.modulate.a = a * 0.7


## Fear made audible: a heartbeat that quickens as the nearest hunter closes in.
func _heartbeat(delta: float) -> void:
	var p := player()
	if p == null or not p.alive:
		return
	var nearest := INF
	for e in get_tree().get_nodes_in_group(&"enemies"):
		nearest = minf(nearest, p.global_position.distance_to(e.global_position))
	var danger := clampf(1.0 - (nearest - 50.0) / 330.0, 0.0, 1.0)
	if danger <= 0.0:
		_heartbeat_timer = 0.0
		return
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		_heartbeat_timer = lerpf(1.1, 0.42, danger)
		Audio.play("heartbeat", null, lerpf(-22.0, -2.0, danger))
		get_tree().call_group(&"post_fx", &"beat", danger)


## Water dripping somewhere in the dark: the station feels alive and huge.
func _drips(delta: float) -> void:
	_drip_timer -= delta
	var p := player()
	if _drip_timer > 0.0 or p == null:
		return
	_drip_timer = _rng.randf_range(1.2, 4.5)
	var at := SoundBus.grid.random_open_near(p.global_position, 18, _rng)
	Audio.play("drip", at, 0.0, _rng.randf_range(0.75, 1.35))


func _on_player_died(killer: Node2D) -> void:
	if _over:
		return
	_over = true
	Game.stats.deaths += 1
	Audio.play("death")
	Audio.play("glitch")
	get_tree().call_group(&"post_fx", &"kick", 1.6)
	# Kill-cam: freeze the hunters and flash the whole room into view for a
	# moment, so every death shows where the danger came from.
	for e in get_tree().get_nodes_in_group(&"enemies"):
		e.set_physics_process(false)
		e.reveal(3.0)
	if killer:
		Events.blip.emit(killer.global_position, Palette.color(Palette.Kind.ENEMY), 80.0)
	var tw := create_tween()
	tw.tween_property(self, "_reveal", 1.0, 0.12)
	tw.tween_interval(1.1)
	tw.tween_property(self, "_reveal", 0.0, 0.5)
	hud.show_death()
	if not auto_respawn:
		return
	await get_tree().create_timer(1.9).timeout
	await hud.fade_out(0.35)
	Game.respawn()


func _on_room_cleared() -> void:
	if _over:
		return
	_over = true
	var p := player()
	if p:
		p.freeze()
	for e in get_tree().get_nodes_in_group(&"enemies"):
		e.set_physics_process(false)
		e.reveal(30.0)
	var rank := Game.finish_room()
	Audio.play("clear")
	create_tween().tween_property(self, "_reveal", 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	var trail := TrailReplay.new()
	trail.points = Game.stats.trail
	add_child(trail)
	var panel := CLEAR_SCENE.instantiate()
	add_child(panel)
	panel.setup(room_name, Game.stats, rank, Game.ROOMS[Game.room_index].par)
