extends Node
## The one door through which every noise enters the world.
##
## emit_noise() works out who can hear a sound by how far it must TRAVEL
## (PropagationGrid flood fill: around corners, muffled by walls), not by
## straight-line distance. Listeners react when the visible ring reaches them,
## and they head for where the sound was MADE. A noise can also carry a reveal
## radius, which asks the EchoRenderer to light up what the sound touched.

## Speed of the visible sound ring in px/s.
const RING_SPEED := 720.0

var grid: PropagationGrid
## Last noise, kept for the F3 debug heatmap.
var last_field := PackedFloat32Array()
var last_loudness := 0.0


func set_grid(g: PropagationGrid) -> void:
	grid = g
	last_field = PackedFloat32Array()


func emit_noise(pos: Vector2, loudness: float, kind: StringName, source: Node = null, reveal_radius := 0.0, deep := false) -> void:
	if reveal_radius > 0.0:
		var echo := get_tree().get_first_node_in_group(&"echo_renderer") as EchoRenderer
		if echo:
			echo.pulse(pos, reveal_radius, deep)
	Events.noise_emitted.emit(pos, loudness, kind)
	if grid == null or loudness <= 0.0:
		return
	var field := grid.flood(pos, loudness)
	last_field = field
	last_loudness = loudness
	var by_player := source != null and source.is_in_group(&"player")
	for listener in get_tree().get_nodes_in_group(&"listeners"):
		if listener == source or not listener.has_method(&"hear"):
			continue
		var travelled := grid.cost_at(field, listener.global_position)
		if travelled > loudness * float(listener.get(&"hearing")):
			continue
		_deliver(listener, pos, kind, by_player, travelled / RING_SPEED)


## How far a noise made at `pos` would have to travel to reach `to` (px).
func travel_distance(pos: Vector2, to: Vector2, max_cost: float) -> float:
	if grid == null:
		return INF
	return grid.cost_at(grid.flood(pos, max_cost), to)


func _deliver(listener: Node, pos: Vector2, kind: StringName, by_player: bool, delay: float) -> void:
	if delay <= 0.01:
		listener.hear(pos, kind, by_player)
		return
	await get_tree().create_timer(delay, false, true).timeout
	if is_instance_valid(listener):
		listener.hear(pos, kind, by_player)
