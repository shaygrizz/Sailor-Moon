extends RefCounted
static func install() -> void:
	var actions = {"a_left": [KEY_A, KEY_LEFT], "a_right": [KEY_D, KEY_RIGHT], "a_up": [KEY_W, KEY_UP], "a_down": [KEY_S, KEY_DOWN],
		"a_jump": [KEY_SPACE], "a_dash": [KEY_SHIFT], "a_attack": [KEY_J], "a_primary": [KEY_K, KEY_Q], "a_special": [KEY_L, KEY_E],
		"a_focus": [KEY_F], "a_roster": [KEY_TAB]}
	for name in actions:
		if not InputMap.has_action(name): InputMap.add_action(name)
		for key in actions[name]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(name, event)
	var buttons = {"a_jump": JOY_BUTTON_A, "a_dash": JOY_BUTTON_RIGHT_SHOULDER, "a_attack": JOY_BUTTON_X,
		"a_primary": JOY_BUTTON_Y, "a_special": JOY_BUTTON_LEFT_SHOULDER, "a_roster": JOY_BUTTON_BACK,
		"a_up": JOY_BUTTON_DPAD_UP, "a_down": JOY_BUTTON_DPAD_DOWN, "a_left": JOY_BUTTON_DPAD_LEFT, "a_right": JOY_BUTTON_DPAD_RIGHT}
	for name in buttons:
		var event = InputEventJoypadButton.new()
		event.button_index = buttons[name]
		InputMap.action_add_event(name, event)
	for entry in [["a_left", JOY_AXIS_LEFT_X, -1.0], ["a_right", JOY_AXIS_LEFT_X, 1.0], ["a_up", JOY_AXIS_LEFT_Y, -1.0],
			["a_down", JOY_AXIS_LEFT_Y, 1.0], ["a_focus", JOY_AXIS_TRIGGER_RIGHT, 1.0]]:
		var event = InputEventJoypadMotion.new()
		event.axis = entry[1]
		event.axis_value = entry[2]
		InputMap.action_add_event(entry[0], event)
