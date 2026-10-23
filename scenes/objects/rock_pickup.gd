extends Area2D
## Rubble the diver can pick rocks from. It sits on the sonar layer, so pulses
## light it up amber.

@export var amount := 2


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	Game.set_rocks(Game.rocks + amount)
	Audio.play("pickup", global_position)
	Events.blip.emit(global_position, Palette.color(Palette.Kind.PICKUP), 36.0)
	queue_free()
