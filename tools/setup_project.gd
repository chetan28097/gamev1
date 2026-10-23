extends SceneTree
## One-time project setup: writes the Input Map into project.godot.
## Run: godot --headless --path . -s tools/setup_project.gd
## Afterwards the actions show up (and can be edited) in Project Settings > Input Map.

func _init() -> void:
	_action("move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("aim_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_action("aim_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_action("aim_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_action("aim_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_action("sprint", [_key(KEY_SHIFT), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_action("sneak", [_key(KEY_CTRL), _button(JOY_BUTTON_LEFT_STICK)])
	_action("pulse", [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_action("throw", [_mouse(MOUSE_BUTTON_RIGHT), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_action("pause", [_key(KEY_ESCAPE), _key(KEY_P), _button(JOY_BUTTON_START)])
	_action("restart", [_key(KEY_R), _button(JOY_BUTTON_BACK)])
	_action("confirm", [_key(KEY_ENTER), _key(KEY_KP_ENTER), _button(JOY_BUTTON_A)])
	_action("debug_overlay", [_key(KEY_F3)])
	var err := ProjectSettings.save()
	print("Input map saved: ", error_string(err))
	quit(err)


func _action(action_name: String, events: Array) -> void:
	ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.25, "events": events})


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


func _button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
