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


## 內建 ui_accept／ui_cancel 只有鍵盤：手把要能用 A 按下對話選項與選單按鈕、B 關掉選單。
func test_ui_actions_have_pad_buttons() -> void:
	InputSetup.ensure_actions()
	InputSetup.ensure_actions()
	for action: String in InputSetup.UI_PAD:
		var pads: int = 0
		for ev: InputEvent in InputMap.action_get_events(action):
			var b: InputEventJoypadButton = ev as InputEventJoypadButton
			if b != null and b.button_index == (InputSetup.UI_PAD[action] as JoyButton):
				pads += 1
		assert_eq(pads, 1, "%s 有一個手把按鈕（重複呼叫不重複加）" % action)
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	assert_true(a.is_action_pressed("ui_accept"), "A = 確認")
	assert_true(a.is_action_pressed("interact"), "A 也還是互動")
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	assert_true(b.is_action_pressed("ui_cancel"), "B = 返回")
	# 套用按鍵設定（會清掉遊戲動作的事件）不影響 UI 的手把按鈕
	InputSetup.apply_bindings(InputSetup.defaults())
	assert_true(a.is_action_pressed("ui_accept"), "套用按鍵設定後 A 仍是確認")


## 玩家的手把不一定是 0 號（Windows 上有其他 HID 裝置或 Steam Input 虛擬手把時）：任何一支都要能玩。
func test_any_controller_device_matches() -> void:
	InputSetup.apply_bindings(InputSetup.defaults())
	var x := InputEventJoypadButton.new()
	x.device = 1
	x.button_index = JOY_BUTTON_X
	x.pressed = true
	assert_true(x.is_action_pressed("attack"), "1 號手把的 X 也是揮擊")
	var a := InputEventJoypadButton.new()
	a.device = 2
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	assert_true(a.is_action_pressed("interact") and a.is_action_pressed("ui_accept"), "2 號手把的 A 也是互動／確認")
	var stick := InputEventJoypadMotion.new()
	stick.device = 1
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -1.0
	assert_true(stick.is_action_pressed("move_forward"), "1 號手把的左搖桿也能走")
	var before: int = App.last_pad
	var before_device: int = App.last_device
	App._input(x)
	assert_eq(App.last_pad, 1, "右搖桿鏡頭跟著最後動過的手把")
	App.last_pad = before
	App.set_device(before_device)


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
	# interact = F、use_item = 1：把 interact 改成 1，use_item 應該拿到 F
	var out: Dictionary = InputSetup.rebind(b, "interact", InputSetup.SLOT_KBM, Vector2i(0, KEY_1))
	assert_eq(InputSetup.slot_of(out, "interact", 0), Vector2i(0, KEY_1), "interact 改成 1")
	assert_eq(InputSetup.slot_of(out, "use_item", 0), Vector2i(0, KEY_F), "use_item 交換成 F")
	assert_eq(InputSetup.slot_of(b, "interact", 0), Vector2i(0, KEY_F), "原表不被修改")
	# 手把欄
	out = InputSetup.rebind(out, "dodge", InputSetup.SLOT_PAD, Vector2i(2, JOY_BUTTON_A))
	assert_eq(InputSetup.slot_of(out, "interact", 1), Vector2i(2, JOY_BUTTON_B), "手把 A／B 交換")


## 舊設定檔裡還留著已經刪掉的動作（「重現」nine_breath，D-222）：略過、不出錯，其他鍵照設定檔。
func test_saved_bindings_ignore_removed_actions() -> void:
	assert_false(InputSetup.BINDINGS.has("nine_breath"), "沒有「重現」這個動作了")
	assert_false(InputSetup.ACTION_KEYS.has("nine_breath"), "按鍵設定頁也不列")
	var saved: Dictionary = {
		"nine_breath": [Vector2i(0, KEY_G), Vector2i(2, JOY_BUTTON_Y)],
		"interact": [Vector2i(0, KEY_G), Vector2i(2, JOY_BUTTON_A)],
	}
	var out: Dictionary = InputSetup.from_saved(saved)
	assert_false(out.has("nine_breath"), "刪掉的動作不會從舊設定檔回來")
	assert_eq(InputSetup.slot_of(out, "interact", InputSetup.SLOT_KBM), Vector2i(0, KEY_G), "其他鍵照設定檔")
	assert_eq(out.size(), InputSetup.BINDINGS.size(), "動作數跟預設一樣")
	InputSetup.apply_bindings(out)
	assert_false(InputMap.has_action("nine_breath"), "InputMap 裡也沒有")
	InputSetup.apply_bindings(InputSetup.defaults())


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
