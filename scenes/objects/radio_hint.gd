extends Area2D
## An invisible trigger: the first time the diver walks in, Dr. Varn speaks.

@export_multiline var text := ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and text != "":
		Events.radio.emit(text)
		queue_free()
