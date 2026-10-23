class_name EchoRenderer
extends Node2D
## Draws everything the player can "see": wall fragments touched by sound, the
## expanding sound rings, and short blips (enemy noises, pickups, footsteps).
##
## A pulse casts a fan of rays once. Each hit is stored with the time the ring
## will REACH it (distance / ring speed), so the room lights up as the wave
## travels outward rather than all at once. Fragments stay bright, fade, and
## then linger as a faint ghost (map memory) so the player can build a mental map.

const RAY_MASK := 1 | 8 | 16  # walls, sonar targets, doors
const BRIGHT_TIME := 1.0
const FADE_TIME := 0.5  # bright -> ghost; 1.5 s of real sight in total
const GHOST_ALPHA := 0.075
const GHOST_TIME := 22.0
const FLASH_TIME := 0.07
const KEY_QUANT := 6.0
const MAX_FRAGMENTS := 12000

# One entry per remembered wall fragment (parallel arrays keep _draw cheap).
var _mid := PackedVector2Array()
var _tan := PackedVector2Array()  # half-length tangent along the wall
var _t := PackedFloat32Array()  # time the ring reaches it (can be in the future)
var _prev_t := PackedFloat32Array()  # previous reveal, so an old ghost stays until then
var _col := PackedColorArray()
var _kind := PackedInt32Array()
var _keys := {}

var _pending: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _blips: Array[Dictionary] = []
var _now := 0.0
var _session := -1


func _ready() -> void:
	add_to_group(&"echo_renderer")
	z_index = 10
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	Events.blip.connect(blip)
	_session = Game.session
	_restore()


func _exit_tree() -> void:
	# Survive a death-reload of the same room: dying should still teach the map.
	if _session == Game.session:
		Game.echo_memory = {
			"mid": _mid, "tan": _tan, "t": _t, "prev": _prev_t, "col": _col, "kind": _kind, "keys": _keys, "now": _now,
		}


func _restore() -> void:
	var m: Dictionary = Game.echo_memory
	if m.is_empty():
		return
	_mid = m.mid
	_tan = m.tan
	_t = m.t
	_prev_t = m.prev
	_col = m.col
	_kind = m.kind
	_keys = m.keys
	_now = m.now


## Queue a sonar pulse. Rays are cast on the next physics frame.
func pulse(origin: Vector2, radius: float, deep := false) -> void:
	_pending.append({"origin": origin, "radius": radius, "deep": deep})
	_rings.append({"c": origin, "start": _now, "max": radius, "deep": deep})


func blip(pos: Vector2, color: Color, radius: float) -> void:
	_blips.append({"p": pos, "c": color, "r": radius, "start": _now, "life": 0.55 + radius / 140.0})


## Count of fragments currently lit (used by tests and the debug overlay).
func lit_count() -> int:
	var n := 0
	for i in _t.size():
		var age := _now - _t[i]
		if age >= 0.0 and age < BRIGHT_TIME + FADE_TIME:
			n += 1
	return n


func fragments() -> PackedVector2Array:
	return _mid


func _process(delta: float) -> void:
	_now += delta
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if _pending.is_empty():
		return
	var space := get_world_2d().direct_space_state
	for p in _pending:
		_cast(space, p.origin, p.radius, p.deep)
	_pending.clear()
	if _mid.size() > MAX_FRAGMENTS:
		_compact()


func _cast(space: PhysicsDirectSpaceState2D, origin: Vector2, radius: float, deep: bool) -> void:
	var rays := 360 if deep else 200
	var step := TAU / rays
	var base := randf() * step  # a slightly different fan each time fills gaps
	var q := PhysicsRayQueryParameters2D.new()
	q.collision_mask = RAY_MASK
	q.collide_with_areas = true
	for i in rays:
		var dir := Vector2.from_angle(base + i * step)
		q.from = origin
		q.to = origin + dir * radius
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var d := origin.distance_to(hit.position)
		_add(hit, dir, d, d, step, 1.0)
		# A deep pulse bounces once: the reverb paints surfaces you can't face.
		if deep and radius - d > 24.0:
			var rdir := dir.bounce(hit.normal)
			q.from = hit.position + hit.normal * 0.5
			q.to = q.from + rdir * (radius - d)
			var hit2 := space.intersect_ray(q)
			if not hit2.is_empty():
				var d2: float = q.from.distance_to(hit2.position)
				_add(hit2, rdir, d2, d + d2, step, 0.55)


func _add(hit: Dictionary, dir: Vector2, leg: float, travel: float, step: float, intensity: float) -> void:
	var n: Vector2 = hit.normal
	var pos: Vector2 = hit.position
	var kind := Palette.kind_of(hit.collider)
	n = _exposed_normal(pos, n, dir, kind)
	# Spacing between neighbouring rays along this wall, so fragments just overlap.
	var facing := maxf(absf(dir.dot(n)), 0.12)
	# Never shorter than the dedup grid (KEY_QUANT), or close walls look dotted.
	var half := clampf(leg * step / facing * 0.62, KEY_QUANT * 0.62, 28.0)
	var tangent := Vector2(-n.y, n.x) * half
	var t := _now + travel / SoundBus.RING_SPEED
	var c := Palette.color(kind)
	c.a = intensity
	var key := Vector3i(roundi(pos.x / KEY_QUANT), roundi(pos.y / KEY_QUANT), kind)
	if _keys.has(key):
		var i: int = _keys[key]
		if _now - _t[i] < BRIGHT_TIME:
			return  # still lit (or about to be); nothing new to learn
		_prev_t[i] = _t[i]
		_t[i] = t
		_mid[i] = pos
		_tan[i] = tangent
		_col[i] = c
		return
	_keys[key] = _mid.size()
	_mid.append(pos)
	_tan.append(tangent)
	_t.append(t)
	_prev_t.append(-INF)
	_col.append(c)
	_kind.append(kind)


## Wall tiles are separate squares, so a grazing ray can clip the hidden seam
## between two of them and report a sideways normal (a dotted wall). If the
## cell on the normal's side is also wall, use the face that points at the ray.
func _exposed_normal(pos: Vector2, n: Vector2, dir: Vector2, kind: int) -> Vector2:
	var grid := SoundBus.grid
	if kind != Palette.Kind.WALL or grid == null:
		return n
	# Step a little further along the ray: that point is inside the solid tile
	# even when the hit lies exactly on a cell boundary.
	var c := grid.world_to_cell(pos + dir * 2.0)
	if grid.is_open(c + Vector2i(roundi(n.x), roundi(n.y))):
		return n
	return Vector2(0.0, -signf(dir.y)) if absf(n.x) > 0.5 else Vector2(-signf(dir.x), 0.0)


## Brightness for a fragment of a given age. >1 means the white-hot flash.
func _alpha(age: float) -> float:
	if age < 0.0:
		return -1.0
	if age < FLASH_TIME:
		return lerpf(1.8, 1.0, age / FLASH_TIME)
	if age < BRIGHT_TIME:
		return 1.0
	if age < BRIGHT_TIME + FADE_TIME:
		var ghost := GHOST_ALPHA if Game.map_memory else 0.0
		return lerpf(1.0, ghost, (age - BRIGHT_TIME) / FADE_TIME)
	if not Game.map_memory:
		return 0.0
	var g := age - BRIGHT_TIME - FADE_TIME
	return GHOST_ALPHA * (1.0 - g / GHOST_TIME) if g < GHOST_TIME else 0.0


func _draw() -> void:
	var pts := PackedVector2Array()
	var core := PackedColorArray()
	var glow := PackedColorArray()
	for i in _mid.size():
		var a := _alpha(_now - _t[i])
		if a < 0.0:
			a = minf(_alpha(_now - _prev_t[i]), GHOST_ALPHA)
		if a <= 0.004:
			continue
		var c := _col[i]
		var k := c.a * minf(a, 1.0)
		var cc := Color(c.r, c.g, c.b, k)
		if a > 1.0:
			cc = cc.lerp(Color(1, 1, 1, k), (a - 1.0) * 0.8)
		pts.append(_mid[i] - _tan[i])
		pts.append(_mid[i] + _tan[i])
		core.append(cc)
		glow.append(Color(cc.r, cc.g, cc.b, cc.a * 0.3))
	if not pts.is_empty():
		draw_multiline_colors(pts, glow, 8.0)
		draw_multiline_colors(pts, core, 2.0)
	_draw_rings()
	_draw_blips()


func _draw_rings() -> void:
	var keep: Array[Dictionary] = []
	for r in _rings:
		var radius: float = (_now - r.start) * SoundBus.RING_SPEED
		if radius > r.max:
			continue
		keep.append(r)
		var k: float = 1.0 - radius / r.max
		var col := Palette.color(Palette.Kind.WALL)
		var segs := clampi(int(radius / 5.0), 24, 160)
		draw_arc(r.c, radius, 0.0, TAU, segs, Color(col, 0.10 * k), 9.0 if r.deep else 6.0)
		draw_arc(r.c, radius, 0.0, TAU, segs, Color(col, (0.45 if r.deep else 0.3) * k * k), 1.5)
	_rings = keep


func _draw_blips() -> void:
	var keep: Array[Dictionary] = []
	for b in _blips:
		var age: float = _now - b.start
		if age > b.life:
			continue
		keep.append(b)
		var k: float = age / b.life
		var c: Color = b.c
		var fade := (1.0 - k) * (1.0 - k)
		draw_arc(b.p, lerpf(3.0, b.r, sqrt(k)), 0.0, TAU, 32, Color(c, c.a * 0.8 * fade), 1.5)
		draw_circle(b.p, 2.5, Color(c, c.a * fade))
	_blips = keep


## Drops fragments that have fully faded, keeping arrays small in long sessions.
func _compact() -> void:
	var mid := PackedVector2Array()
	var tan := PackedVector2Array()
	var t := PackedFloat32Array()
	var prev := PackedFloat32Array()
	var col := PackedColorArray()
	var kind := PackedInt32Array()
	var keys := {}
	var horizon := BRIGHT_TIME + FADE_TIME + GHOST_TIME
	for i in _mid.size():
		if _now - _t[i] > horizon:
			continue
		keys[Vector3i(roundi(_mid[i].x / KEY_QUANT), roundi(_mid[i].y / KEY_QUANT), _kind[i])] = mid.size()
		mid.append(_mid[i])
		tan.append(_tan[i])
		t.append(_t[i])
		prev.append(_prev_t[i])
		col.append(_col[i])
		kind.append(_kind[i])
	_mid = mid
	_tan = tan
	_t = t
	_prev_t = prev
	_col = col
	_kind = kind
	_keys = keys
