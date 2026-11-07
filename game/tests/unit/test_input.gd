extends TestCase
## 每個遊戲動作都要同時有鍵鼠與手把的預設綁定。


func test_every_action_has_keyboard_and_gamepad() -> void:
	InputSetup.ensure_actions()
	for action: String in InputSetup.BINDINGS:
		assert_true(InputMap.has_action(action), "缺動作：" + action)
		var has_pc: bool = false
		var has_pad: bool = false
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventKey or ev is InputEventMouseButton:
				has_pc = true
			elif ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		assert_true(has_pc, action + " 缺鍵鼠綁定")
		assert_true(has_pad, action + " 缺手把綁定")


func test_movement_axes_have_opposite_signs() -> void:
	InputSetup.ensure_actions()
	var fwd: float = _axis_value("move_forward")
	var back: float = _axis_value("move_back")
	assert_true(fwd < 0.0 and back > 0.0, "前後方向相反")


func test_ensure_is_idempotent() -> void:
	InputSetup.ensure_actions()
	var n: int = InputMap.action_get_events("dodge").size()
	InputSetup.ensure_actions()
	assert_eq(InputMap.action_get_events("dodge").size(), n, "重複呼叫不會重複加事件")


func _axis_value(action: String) -> float:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion:
			return (ev as InputEventJoypadMotion).axis_value
	return 0.0
