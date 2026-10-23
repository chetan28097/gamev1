extends Node
## Global signal hub. Systems that should not know about each other talk here.

## Every noise in the world, after SoundBus has processed it (debug overlay, HUD).
signal noise_emitted(pos: Vector2, loudness: float, kind: StringName)
## A listener heard something and is now heading for `target`.
signal enemy_alerted(enemy: Node2D, target: Vector2)
## Short-lived visual markers ("blips") drawn by the EchoRenderer.
signal blip(pos: Vector2, color: Color, radius: float)
signal radio(text: String)
signal player_died(killer: Node2D)
signal room_cleared
signal inventory_changed
signal pulse_charge_changed(ratio: float, cooldown_ratio: float)
