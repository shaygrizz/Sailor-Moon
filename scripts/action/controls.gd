extends RefCounted
static func install() -> void:
	var actions = {"a_left": [KEY_A, KEY_LEFT], "a_right": [KEY_D, KEY_RIGHT], "a_jump": [KEY_SPACE, KEY_W, KEY_UP],
		"a_dash": [KEY_SHIFT], "a_attack": [KEY_J], "a_primary": [KEY_K, KEY_Q], "a_special": [KEY_L, KEY_E], "a_roster": [KEY_TAB]}
	for name in actions:
		if not InputMap.has_action(name): InputMap.add_action(name)
		for key in actions[name]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(name, event)
	var buttons = {"a_jump": JOY_BUTTON_A, "a_dash": JOY_BUTTON_RIGHT_SHOULDER, "a_attack": JOY_BUTTON_X,
		"a_primary": JOY_BUTTON_Y, "a_special": JOY_BUTTON_LEFT_SHOULDER, "a_roster": JOY_BUTTON_BACK}
	for name in buttons:
		var event = InputEventJoypadButton.new()
		event.button_index = buttons[name]
		InputMap.action_add_event(name, event)
	for entry in [["a_left", -1.0], ["a_right", 1.0]]:
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_LEFT_X
		event.axis_value = entry[1]
		InputMap.action_add_event(entry[0], event)
