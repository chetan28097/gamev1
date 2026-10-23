extends Area2D
## The exit hatch. It hums (positional audio) so it can be found by ear, and its
## echo shows up green. Touching it clears the room.

var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var hum := $Hum as AudioStreamPlayer2D
	var s := Audio.stream("exit_hum")
	if s is AudioStreamOggVorbis:
		s.loop = true
	hum.stream = s
	hum.play()


func _on_body_entered(body: Node2D) -> void:
	if _done or not body is Player:
		return
	_done = true
	$Hum.stop()
	Events.room_cleared.emit()
