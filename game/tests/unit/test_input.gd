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


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = true
	return k


func test_rebind_swaps_on_conflict() -> void:
	var b: Dictionary = InputSetup.defaults()
	# interact = F、nine_breath = V：把 interact 改成 V，nine_breath 應該拿到 F
	var out: Dictionary = InputSetup.rebind(b, "interact", InputSetup.SLOT_KBM, Vector2i(0, KEY_V))
	assert_eq(InputSetup.slot_of(out, "interact", 0), Vector2i(0, KEY_V), "interact 改成 V")
	assert_eq(InputSetup.slot_of(out, "nine_breath", 0), Vector2i(0, KEY_F), "nine_breath 交換成 F")
	assert_eq(InputSetup.slot_of(b, "interact", 0), Vector2i(0, KEY_F), "原表不被修改")
	# 手把欄
	out = InputSetup.rebind(out, "dodge", InputSetup.SLOT_PAD, Vector2i(2, JOY_BUTTON_A))
	assert_eq(InputSetup.slot_of(out, "interact", 1), Vector2i(2, JOY_BUTTON_B), "手把 A／B 交換")


func test_rebind_rejects_fixed_and_wrong_slot() -> void:
	var b: Dictionary = InputSetup.defaults()
	assert_eq(InputSetup.rebind(b, "pause", 0, Vector2i(0, KEY_P)), b, "暫停不能改")
	assert_eq(InputSetup.rebind(b, "move_forward", 1, Vector2i(2, JOY_BUTTON_A)), b, "移動搖桿不能改")
	assert_eq(InputSetup.rebind(b, "dodge", 0, Vector2i(0, KEY_ESCAPE)), b, "不能搶暫停鍵")
	assert_eq(InputSetup.rebind(b, "dodge", 0, Vector2i(2, JOY_BUTTON_A)), b, "鍵鼠欄不收手把鍵")
	assert_eq(InputSetup.rebind(b, "dodge", 1, Vector2i(0, KEY_K)), b, "手把欄不收鍵盤")
	assert_true(InputSetup.is_rebindable("move_forward", 0), "移動的鍵盤可以改")


func test_spec_from_event_filters() -> void:
	assert_eq(InputSetup.spec_from_event(_key(KEY_J), 0), Vector2i(0, KEY_J))
	var released := _key(KEY_J)
	released.pressed = false
	assert_eq(InputSetup.spec_from_event(released, 0), InputSetup.NONE, "放開不算")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	assert_eq(InputSetup.spec_from_event(wheel, 0), InputSetup.NONE, "滾輪不能綁")
	var lt := InputEventJoypadMotion.new()
	lt.axis = JOY_AXIS_TRIGGER_RIGHT
	lt.axis_value = 0.9
	assert_eq(InputSetup.spec_from_event(lt, 1), Vector2i(3, JOY_AXIS_TRIGGER_RIGHT), "扳機可以綁")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	assert_eq(InputSetup.spec_from_event(stick, 1), InputSetup.NONE, "搖桿不能綁到按鈕動作")
	assert_eq(InputSetup.spec_from_event(_key(KEY_J), 1), InputSetup.NONE, "手把欄忽略鍵盤")


func test_bindings_save_load_and_reset() -> void:
	var settings: Node = tree.root.get_node("Settings")
	var real_path: String = str(settings.get("_config_path"))
	var path: String = "user://test_input_%d.cfg" % Time.get_ticks_usec()
	settings.call("load_settings", path)
	assert_true(settings.call("set_binding", "dodge", 0, Vector2i(0, KEY_C)), "改閃避")
	assert_false(settings.call("set_binding", "pause", 0, Vector2i(0, KEY_P)), "暫停不能改")
	assert_true(InputMap.action_has_event("dodge", _key(KEY_C)), "InputMap 套用新鍵")
	assert_false(InputMap.action_has_event("dodge", _key(KEY_SPACE)), "舊鍵移除")
	settings.call("save_settings", path)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(path), OK)
	assert_eq(cfg.get_section_keys("input"), PackedStringArray(["dodge"]), "只存跟預設不同的動作")
	settings.call("reset_bindings")
	assert_true(InputMap.action_has_event("dodge", _key(KEY_SPACE)), "恢復預設")
	settings.call("load_settings", path)
	assert_eq(settings.call("binding", "dodge", 0), Vector2i(0, KEY_C), "讀回改過的鍵")
	# 壞掉的設定檔：值型別不對、跟別的動作重複 → 不會壞掉，衝突自動解開
	cfg.set_value("input", "attack", ["oops", 3])
	cfg.set_value("input", "interact", [Vector2i(0, KEY_C), Vector2i(2, JOY_BUTTON_A)])
	cfg.save(path)
	settings.call("load_settings", path)
	assert_eq(settings.call("binding", "attack", 0), Vector2i(1, MOUSE_BUTTON_LEFT), "壞值用預設")
	assert_eq(settings.call("binding", "interact", 0), Vector2i(0, KEY_C), "interact 拿到 C")
	assert_ne(settings.call("binding", "dodge", 0), Vector2i(0, KEY_C), "dodge 不再重複")
	DirAccess.remove_absolute(path)
	settings.call("load_settings", real_path)
	settings.call("apply")


func test_glyph_labels_and_device_switch() -> void:
	InputSetup.apply_bindings(InputSetup.defaults())
	TranslationServer.set_locale("en")
	assert_eq(InputGlyphs.label_for_action("interact", InputGlyphs.Device.KBM), "[F]")
	assert_eq(InputGlyphs.label_for_action("interact", InputGlyphs.Device.PAD), "[A]")
	assert_eq(InputGlyphs.label_for_action("attack", InputGlyphs.Device.KBM), "[LMB]")
	assert_eq(InputGlyphs.label_for_action("insight", InputGlyphs.Device.PAD), "[LT]")
	TranslationServer.set_locale("zh_TW")
	assert_eq(InputGlyphs.label_for_action("dodge", InputGlyphs.Device.KBM), "[空白鍵]")
	TranslationServer.set_locale(str(tree.root.get_node("Settings").get("locale")))

	var app: Node = tree.root.get_node("App")
	var before: int = int(app.get("last_device"))
	var seen: Array[int] = []
	var cb: Callable = func(d: int) -> void: seen.append(d)
	app.connect("device_changed", cb)
	app.call("set_device", InputGlyphs.Device.KBM)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	app.call("_input", pad)
	var nudge := InputEventJoypadMotion.new()
	nudge.axis = JOY_AXIS_LEFT_X
	nudge.axis_value = 0.1
	assert_eq(InputGlyphs.device_of_event(nudge), -1, "搖桿輕推不算切換")
	app.call("_input", _key(KEY_W))
	app.disconnect("device_changed", cb)
	assert_eq(seen.size(), 2, "切到手把再切回鍵鼠，各發一次")
	if seen.size() == 2:
		assert_eq(seen[0], int(InputGlyphs.Device.PAD))
		assert_eq(seen[1], int(InputGlyphs.Device.KBM))
	app.call("set_device", before)
