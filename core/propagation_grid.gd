class_name PropagationGrid
extends RefCounted
## The room as a coarse grid of 32 px cells, used for two jobs:
##  - Sound propagation: how far a noise must TRAVEL to reach a point. It flows
##    around corners and through doorways, and is heavily muffled by walls.
##  - Enemy pathfinding, through an AStarGrid2D where walls are solid.

const CELL := 32
## Crossing one wall cell costs as much as travelling this many open cells.
const WALL_MUFFLE := 10.0
const BLOCKED := -1.0
const OPEN := 1.0

const _DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var rect: Rect2i
## Per cell: OPEN, WALL_MUFFLE (wall) or BLOCKED (outside the station).
var weights := PackedFloat32Array()
var astar := AStarGrid2D.new()


func _init(floor_layer: TileMapLayer, wall_layer: TileMapLayer) -> void:
	rect = floor_layer.get_used_rect().merge(wall_layer.get_used_rect())
	weights.resize(rect.size.x * rect.size.y)
	weights.fill(BLOCKED)
	for cell in floor_layer.get_used_cells():
		weights[_index(cell)] = OPEN
	for cell in wall_layer.get_used_cells():
		weights[_index(cell)] = WALL_MUFFLE

	astar.region = rect
	astar.cell_size = Vector2(CELL, CELL)
	astar.offset = Vector2(CELL, CELL) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if weights[_index(c)] != OPEN:
				astar.set_point_solid(c)


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c) * CELL + Vector2(CELL, CELL) * 0.5


func is_open(c: Vector2i) -> bool:
	return rect.has_point(c) and weights[_index(c)] == OPEN


## The closest open cell to `c` (itself if open). Noises made against a wall,
## like a rock landing, still need somewhere to start travelling from.
func nearest_open(c: Vector2i) -> Vector2i:
	if is_open(c):
		return c
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if is_open(n):
					return n
	return Vector2i(-99999, -99999)


## Dijkstra flood fill from `origin`, stopping once the cost exceeds `max_cost`.
## Returns the travel distance (px) to every cell; INF where the sound never got.
func flood(origin: Vector2, max_cost: float) -> PackedFloat32Array:
	var dist := PackedFloat32Array()
	dist.resize(weights.size())
	dist.fill(INF)
	var start := nearest_open(world_to_cell(origin))
	if not rect.has_point(start):
		return dist
	var heap := _MinHeap.new()
	dist[_index(start)] = 0.0
	heap.push(0.0, _index(start))
	while not heap.is_empty():
		var cost := heap.top_cost()
		var i := heap.pop()
		if cost > dist[i]:
			continue
		var c := Vector2i(rect.position.x + i % rect.size.x, rect.position.y + i / rect.size.x)
		var w_from := weights[i]
		for d in _DIRS:
			var n := c + d
			if not rect.has_point(n):
				continue
			var ni := _index(n)
			var w_to := weights[ni]
			if w_to == BLOCKED:
				continue
			var step := 1.0
			if d.x != 0 and d.y != 0:
				# No squeezing diagonally between two touching walls.
				if weights[_index(Vector2i(c.x + d.x, c.y))] != OPEN or weights[_index(Vector2i(c.x, c.y + d.y))] != OPEN:
					continue
				step = 1.41421
			var nc := cost + CELL * step * (w_from + w_to) * 0.5
			if nc < dist[ni] and nc <= max_cost:
				dist[ni] = nc
				heap.push(nc, ni)
	return dist


func cost_at(field: PackedFloat32Array, p: Vector2) -> float:
	var c := world_to_cell(p)
	if field.is_empty() or not rect.has_point(c):
		return INF
	return field[_index(c)]


## Walkable path between two world points (cell centres), for enemies.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_open(world_to_cell(from))
	var b := nearest_open(world_to_cell(to))
	if not rect.has_point(a) or not rect.has_point(b):
		return PackedVector2Array()
	var pts := astar.get_point_path(a, b, true)
	if pts.size() > 0:
		pts.remove_at(0)  # the cell we are already standing in
	return pts


## A random open cell centre within `radius_cells` of `around`.
func random_open_near(around: Vector2, radius_cells: int, rng: RandomNumberGenerator) -> Vector2:
	var base := world_to_cell(around)
	for _i in 16:
		var c := base + Vector2i(rng.randi_range(-radius_cells, radius_cells), rng.randi_range(-radius_cells, radius_cells))
		if is_open(c):
			return cell_to_world(c)
	return cell_to_world(nearest_open(base))


func _index(c: Vector2i) -> int:
	return (c.y - rect.position.y) * rect.size.x + (c.x - rect.position.x)


## Small binary min-heap of (cost, index) pairs for the flood fill.
class _MinHeap:
	var _cost: Array[float] = []
	var _idx: Array[int] = []

	func is_empty() -> bool:
		return _cost.is_empty()

	func top_cost() -> float:
		return _cost[0]

	func push(cost: float, index: int) -> void:
		_cost.append(cost)
		_idx.append(index)
		var i := _cost.size() - 1
		while i > 0:
			var parent := (i - 1) >> 1
			if _cost[parent] <= _cost[i]:
				break
			_swap(i, parent)
			i = parent

	func pop() -> int:
		var top := _idx[0]
		var last := _cost.size() - 1
		_swap(0, last)
		_cost.pop_back()
		_idx.pop_back()
		var i := 0
		var n := _cost.size()
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < n and _cost[l] < _cost[m]:
				m = l
			if r < n and _cost[r] < _cost[m]:
				m = r
			if m == i:
				break
			_swap(i, m)
			i = m
		return top

	func _swap(a: int, b: int) -> void:
		var tc := _cost[a]
		_cost[a] = _cost[b]
		_cost[b] = tc
		var ti := _idx[a]
		_idx[a] = _idx[b]
		_idx[b] = ti
