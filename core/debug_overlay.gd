class_name DebugOverlay
extends Node2D
## F3: shows how far the LAST noise travelled (a heatmap over the sound grid).
## Walls and hunters also become visible (see Room and Stalker) so rooms can be
## balanced with the lights on.


func _ready() -> void:
	z_index = 8


func _process(_delta: float) -> void:
	if Game.debug_overlay:
		queue_redraw()
	elif visible:
		queue_redraw()
	visible = Game.debug_overlay


func _draw() -> void:
	var grid := SoundBus.grid
	var field := SoundBus.last_field
	if grid == null or field.is_empty() or SoundBus.last_loudness <= 0.0:
		return
	var cell := Vector2(PropagationGrid.CELL, PropagationGrid.CELL)
	for i in field.size():
		var d := field[i]
		if d == INF:
			continue
		var c := Vector2i(grid.rect.position.x + i % grid.rect.size.x, grid.rect.position.y + i / grid.rect.size.x)
		var k := 1.0 - d / SoundBus.last_loudness
		draw_rect(Rect2(Vector2(c) * cell, cell), Color(1.0, 0.75, 0.2, 0.05 + 0.25 * k))
