extends Node
## Builds rooms from ASCII layouts into real Godot scenes with painted
## TileMapLayers and placed object instances:
##   tools/room_layouts/*.txt -> scenes/rooms/*.tscn
##   tests/layouts/*.txt      -> tests/rooms/*.tscn
## After that a room is a normal scene: open it in the editor, repaint walls
## with the TileMap tools, drag enemies around. Existing rooms are NOT
## overwritten unless you pass --force:
##   godot --headless --path . res://tools/build_rooms.tscn -- --force
## (It runs as a scene, not with -s, so the autoloads the room scripts use exist.)
##
## Legend:  #  wall      .  floor     (space) outside the station
##          P  player    X  exit      S  stalker     r  rock rubble
##          1-9  radio hint trigger (text from the "hintN:" header line)

const CELL := 32
const TILESET_PATH := "res://scenes/rooms/echo_tiles.tres"
const WALL := Vector2i(0, 0)
const FLOOR := Vector2i(1, 0)
const SCENES := {
	"P": "res://scenes/player/player.tscn",
	"X": "res://scenes/objects/exit.tscn",
	"S": "res://scenes/enemies/stalker/stalker.tscn",
	"r": "res://scenes/objects/rock_pickup.tscn",
}
const HINT_SCENE := "res://scenes/objects/radio_hint.tscn"
const JOBS := [
	["res://tools/room_layouts", "res://scenes/rooms"],
	["res://tests/layouts", "res://tests/rooms"],
]


func _ready() -> void:
	var force := "--force" in OS.get_cmdline_user_args()
	var tileset := _tileset(force)
	var ok := true
	for job in JOBS:
		var dir := DirAccess.open(job[0])
		if dir == null:
			continue
		DirAccess.make_dir_recursive_absolute(job[1])
		for f in dir.get_files():
			if not f.ends_with(".txt"):
				continue
			var out: String = job[1] + "/" + f.get_basename() + ".tscn"
			if FileAccess.file_exists(out) and not force:
				print("skip   %s (exists; use --force to rebuild)" % out)
				continue
			ok = _build(job[0] + "/" + f, out, tileset) and ok
	get_tree().quit(0 if ok else 1)


func _build(src: String, out: String, tileset: TileSet) -> bool:
	var text := FileAccess.get_file_as_string(src).replace("\r", "")
	var split := text.split("---\n", true, 1)
	if split.size() < 2:
		push_error("%s: missing '---' separator" % src)
		return false
	var header := {}
	for line in split[0].split("\n", false):
		var kv := line.split(":", true, 1)
		if kv.size() == 2:
			header[kv[0].strip_edges()] = kv[1].strip_edges()
	var rows := split[1].split("\n")
	while not rows.is_empty() and rows[rows.size() - 1].strip_edges() == "":
		rows.remove_at(rows.size() - 1)

	if not _validate(src, rows):
		return false

	var root := Node2D.new()
	root.name = "Room"
	root.set_script(load("res://scenes/rooms/room.gd"))
	root.set("room_name", header.get("name", out.get_file().get_basename()))
	root.set("start_rocks", int(header.get("rocks", "0")))
	var floor_layer := _layer(root, "Floor", tileset)
	var walls := _layer(root, "Walls", tileset)
	var entities := Node2D.new()
	entities.name = "Entities"
	root.add_child(entities)
	entities.owner = root

	var counts := {}
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var cell := Vector2i(x, y)
			if ch == " ":
				continue
			if ch == "#":
				walls.set_cell(cell, 0, WALL)
				continue
			floor_layer.set_cell(cell, 0, FLOOR)
			var scene_path: String = SCENES.get(ch, "")
			if ch.is_valid_int():
				scene_path = HINT_SCENE
			if scene_path == "":
				continue
			var node: Node2D = load(scene_path).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			counts[ch] = counts.get(ch, 0) + 1
			node.name = {"P": "Player", "X": "Exit", "S": "Stalker", "r": "Rubble"}.get(ch, "Hint") + ("" if ch == "P" or ch == "X" else str(counts[ch]))
			if ch.is_valid_int():
				node.name = "Hint" + ch
				node.set("text", header.get("hint" + ch, ""))
			node.position = Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5
			entities.add_child(node)
			node.owner = root

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, out)
	root.free()
	print("%s  %s  (%s)" % ["built " if err == OK else "FAILED", out, error_string(err)])
	return err == OK


func _layer(root: Node, layer_name: String, tileset: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	root.add_child(layer)
	layer.owner = root
	return layer


## The layout must have exactly one P and one X, and everything important
## must be reachable from P by walking.
func _validate(src: String, rows: PackedStringArray) -> bool:
	var start := Vector2i(-1, -1)
	var targets: Array[Vector2i] = []
	var players := 0
	var exits := 0
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			if ch == "P":
				start = Vector2i(x, y)
				players += 1
			elif ch == "X":
				exits += 1
				targets.append(Vector2i(x, y))
			elif ch == "r" or ch.is_valid_int():
				targets.append(Vector2i(x, y))
	if players != 1 or exits != 1:
		push_error("%s: needs exactly one P and one X (found %d P, %d X)" % [src, players, exits])
		return false
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if seen.has(n) or n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= rows[n.y].length():
				continue
			var ch := rows[n.y][n.x]
			if ch == "#" or ch == " ":
				continue
			seen[n] = true
			queue.append(n)
	var ok := true
	for t in targets:
		if not seen.has(t):
			push_error("%s: '%s' at %s is unreachable from the player" % [src, rows[t.y][t.x], t])
			ok = false
	return ok


## The TileSet: a wall tile (solid, physics layer "walls") and a floor tile.
## Its textures only matter in the editor, the kill-cam and the F3 overlay.
func _tileset(force: bool) -> TileSet:
	if ResourceLoader.exists(TILESET_PATH) and not force:
		return load(TILESET_PATH)
	var img := Image.create(CELL * 2, CELL, false, Image.FORMAT_RGBA8)
	for y in CELL:
		for x in CELL:
			var edge := x == 0 or y == 0 or x == CELL - 1 or y == CELL - 1
			img.set_pixel(x, y, Color("2fd8ff") if edge else Color("0d2236"))
			var dot := x % 8 == 4 and y % 8 == 4
			img.set_pixel(CELL + x, y, Color("1b2a3a") if dot else Color("070b12"))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL, CELL)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "surface")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(CELL, CELL)
	ts.add_source(src, 0)
	src.create_tile(WALL)
	src.create_tile(FLOOR)
	var h := CELL * 0.5
	var wall := src.get_tile_data(WALL, 0)
	wall.add_collision_polygon(0)
	wall.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	wall.set_custom_data("surface", "wall")
	src.get_tile_data(FLOOR, 0).set_custom_data("surface", "concrete")
	var err := ResourceSaver.save(ts, TILESET_PATH)
	ts.take_over_path(TILESET_PATH)  # rooms reference the file instead of embedding a copy
	print("tileset %s (%s)" % [TILESET_PATH, error_string(err)])
	return ts
