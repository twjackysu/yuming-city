extends TestCase
## 暫停選單、設定選單、HUD：文字都走翻譯 key、操作會改到設定與遊戲狀態。

const KEY_PATTERN: String = "^[A-Z][A-Z0-9_]*$"

var _dir: String = ""
var _saved_session: GameSession


func before_each() -> void:
	_dir = "user://test_ui_%d" % Time.get_ticks_usec()


func after_each() -> void:
	tree.root.get_node("Game").set("dialogue", null)
	if _saved_session != null:
		(tree.root.get_node("Game") as Node).set("session", _saved_session)
		_saved_session = null
	tree.paused = false
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


## 換一個存到暫存資料夾的 session，避免動到真的 user://saves。
func _use_temp_session() -> GameSession:
	var game: Node = tree.root.get_node("Game")
	_saved_session = game.get("session") as GameSession
	var s := GameSession.new(QuestDB.load_default(), _dir)
	game.set("session", s)
	return s


func _assert_texts_are_keys(root: Node, where: String) -> int:
	var re := RegEx.create_from_string(KEY_PATTERN)
	var count: int = 0
	TranslationServer.set_locale("en")
	for n: Node in root.find_children("*", "", true, false):
		var text: String = ""
		if n is Label:
			text = (n as Label).text
		elif n is Button:
			text = (n as Button).text
		else:
			continue
		if text == "" or n.has_meta("glyph"):
			continue
		count += 1
		assert_true(re.search(text) != null, "%s 的 %s 寫死了文字：%s" % [where, n.name, text])
		assert_ne(TranslationServer.translate(text), StringName(text), "%s 用到不存在的 key：%s" % [where, text])
	TranslationServer.set_locale(str(tree.root.get_node("Settings").get("locale")))
	return count


func test_settings_menu_texts_and_controls() -> void:
	var settings: Node = tree.root.get_node("Settings")
	var menu: SettingsMenu = (load("res://scenes/ui/settings_menu.tscn") as PackedScene).instantiate() as SettingsMenu
	tree.root.add_child(menu)
	menu.open()
	await tree.process_frame
	assert_true(_assert_texts_are_keys(menu, "設定選單") >= 18, "設定選單每一列都有文字")

	var quality_before: int = int(settings.get("quality"))
	var q: Button = menu.control_of("Quality") as Button
	assert_not_null(q, "畫質列")
	q.pressed.emit()
	assert_eq(int(settings.get("quality")), (quality_before + 1) % 3, "按一下切到下一級")
	assert_eq(q.text, QualityPreset.NAME_KEYS[int(settings.get("quality"))], "按鈕顯示目前畫質")
	settings.call("set_quality", quality_before)

	var vol_before: float = float(settings.call("volume", "Music"))
	var slider: HSlider = menu.control_of("VolumeMusic") as HSlider
	assert_not_null(slider, "音樂音量滑桿")
	slider.value = 0.35
	assert_eq(float(settings.call("volume", "Music")), 0.35, "滑桿改到設定")
	var bus: int = AudioServer.get_bus_index("Music")
	assert_true(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.35)) < 0.01, "套用到 Music 匯流排")
	settings.call("set_volume", "Music", vol_before)

	var shake: Button = menu.control_of("ReduceShake") as Button
	var shake_before: bool = bool(settings.get("reduce_camera_shake"))
	shake.pressed.emit()
	assert_eq(bool(settings.get("reduce_camera_shake")), not shake_before, "減少鏡頭晃動切換")
	assert_eq(shake.text, "OPT_ON" if not shake_before else "OPT_OFF")
	settings.call("set_option", "reduce_camera_shake", shake_before)

	var closed: Array[bool] = [false]
	menu.closed.connect(func() -> void: closed[0] = true)
	menu.close()
	assert_true(closed[0] and not menu.visible, "返回會關閉並發出 closed")
	menu.queue_free()
	await tree.process_frame


func test_pause_menu_pauses_and_resumes() -> void:
	var pause: PauseMenu = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	tree.root.add_child(pause)
	await tree.process_frame
	assert_false(pause.is_open(), "一開始沒開")
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	pause._unhandled_input(ev)
	assert_true(pause.is_open(), "按暫停鍵打開")
	assert_true(tree.paused, "遊戲暫停")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "暫停時釋放滑鼠")
	assert_true(_assert_texts_are_keys(pause, "暫停選單") >= 4)
	(pause.find_child("Settings", true, false) as Button).pressed.emit()
	var sm: SettingsMenu = pause.find_child("SettingsMenu", true, false) as SettingsMenu
	assert_true(sm != null and sm.visible, "暫停中可以開設定")
	pause._unhandled_input(ev)
	assert_true(pause.is_open(), "設定開著時暫停鍵交給設定選單處理")
	sm.close()
	pause._unhandled_input(ev)
	assert_false(pause.is_open(), "再按一次繼續")
	assert_false(tree.paused, "解除暫停")
	pause.queue_free()
	await tree.process_frame


func test_hud_follows_objective_and_autosave() -> void:
	var s: GameSession = _use_temp_session()
	s.new_game()
	var hud: Hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as Hud
	tree.root.add_child(hud)
	await tree.process_frame
	assert_eq(hud.objective_text_key(), "Q_SLICE_OBJ_TOWN", "顯示目前目標")
	assert_true(hud.is_objective_shown(), "進關卡時先顯示目標")
	assert_true(Hud.OBJECTIVE_HOLD_SEC <= 10.0, "探索時 HUD 不常駐：目標幾秒後淡出")
	_assert_texts_are_keys(hud, "HUD")
	s.set_flag("slice.met_pear_seller", true)
	assert_eq(hud.objective_text_key(), "Q_SLICE_OBJ_BELL", "目標跟著任務換")
	await tree.process_frame
	await tree.process_frame
	assert_eq(hud.saved_label().text, "HUD_SAVED", "檢查點存檔成功")
	assert_true(hud.saved_label().modulate.a > 0.0, "存檔提示開始顯示")
	hud.queue_free()
	await tree.process_frame


func test_dialogue_box_reveal_and_choices() -> void:
	var s: GameSession = _use_temp_session()
	s.new_game()
	var box: DialogueBox = (load("res://scenes/ui/dialogue_box.tscn") as PackedScene).instantiate() as DialogueBox
	tree.root.add_child(box)
	await tree.process_frame
	assert_false(box.is_open(), "沒有對話時隱藏")
	var game: Node = tree.root.get_node("Game")
	assert_true(game.call("start_dialogue", "slice_pear_seller"), "開始對話")
	assert_false(game.call("start_dialogue", "slice_pear_seller"), "對話中不能再開一段")
	assert_true(box.is_open(), "對話框打開")
	assert_true(box.is_revealing(), "台詞逐字浮現")
	box.press_continue()
	assert_false(box.is_revealing(), "第一次按：先顯示完整")
	assert_eq((box.find_child("Text", true, false) as Label).text, "DLG_PEAR_001", "還在第一句")
	box.press_continue()
	assert_eq((box.find_child("Text", true, false) as Label).text, "DLG_PEAR_002", "第二次按：下一句")
	_assert_texts_are_keys(box, "對話框")
	var app: Node = tree.root.get_node("App")
	var device_before: int = int(app.get("last_device"))
	TranslationServer.set_locale("en")
	app.call("set_device", InputGlyphs.Device.KBM)
	box.refresh_hint()
	assert_true(box.hint_text().contains("[F]"), "鍵鼠提示 [F]：" + box.hint_text())
	app.call("set_device", InputGlyphs.Device.PAD)
	assert_true(box.hint_text().contains("[A]"), "切到手把自動換成 [A]：" + box.hint_text())
	assert_false(box.hint_text().contains("{key}"), "沒有未替換的佔位符")
	app.call("set_device", device_before)
	TranslationServer.set_locale(str(tree.root.get_node("Settings").get("locale")))
	(game.get("dialogue") as DialogueRunner).skip_to_choice()
	var choices: Node = box.find_child("Choices", true, false)
	assert_eq(choices.get_child_count(), 3, "選項按鈕")
	_assert_texts_are_keys(box, "對話選項")
	(choices.get_child(0) as Button).pressed.emit()
	assert_eq(s.state.get_flag("slice.bought_pears"), true, "按下選項套用效果")
	for i: int in 10:
		if not bool(game.call("is_in_dialogue")):
			break
		box.press_continue()
	assert_false(game.call("is_in_dialogue"), "對話結束")
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "ring_bell", "任務推進")
	assert_false(box.is_open())
	box.queue_free()
	await tree.process_frame


func test_controls_menu_rebind_cancel_reset() -> void:
	var settings: Node = tree.root.get_node("Settings")
	var real_path: String = str(settings.get("_config_path"))
	settings.call("load_settings", _dir + "_controls.cfg")
	var menu: SettingsMenu = (load("res://scenes/ui/settings_menu.tscn") as PackedScene).instantiate() as SettingsMenu
	tree.root.add_child(menu)
	menu.open()
	(menu.control_of("Controls") as Button).pressed.emit()
	assert_true(menu.is_controls_open(), "從設定開啟按鍵設定")
	var controls: ControlsMenu = menu.find_child("ControlsMenu", true, false) as ControlsMenu
	await tree.process_frame
	assert_true(_assert_texts_are_keys(controls, "按鍵設定") >= 18, "每個動作都有名稱")
	TranslationServer.set_locale("en")
	controls.cancel_capture()
	var cell: Button = controls.cell("dodge", InputSetup.SLOT_KBM)
	cell.pressed.emit()
	assert_true(controls.is_waiting(), "按下格子開始等待")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_C
	k.pressed = true
	assert_true(controls.feed_capture(k), "同一幀的按鍵被吃掉")
	assert_eq(settings.call("binding", "dodge", 0), Vector2i(0, KEY_SPACE), "還沒開始收：不改")
	await tree.process_frame
	assert_true(controls.feed_capture(k), "收到新鍵")
	assert_false(controls.is_waiting())
	assert_eq(settings.call("binding", "dodge", 0), Vector2i(0, KEY_C), "閃避改成 C")
	assert_eq(cell.text, "C", "格子顯示新鍵名")
	# Esc 取消
	controls.cell("interact", InputSetup.SLOT_KBM).pressed.emit()
	await tree.process_frame
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	assert_true(controls.feed_capture(esc), "Esc 被吃掉")
	assert_false(controls.is_waiting(), "Esc 取消等待")
	assert_eq(settings.call("binding", "interact", 0), Vector2i(0, KEY_F), "取消不改")
	assert_true(controls.cell("pause", InputSetup.SLOT_KBM).disabled, "暫停固定")
	assert_true(controls.cell("move_left", InputSetup.SLOT_PAD).disabled, "移動搖桿固定")
	(controls.find_child("Reset", true, false) as Button).pressed.emit()
	assert_eq(settings.call("binding", "dodge", 0), Vector2i(0, KEY_SPACE), "恢復預設")
	menu.close()
	assert_false(menu.is_controls_open(), "關設定一起關按鍵設定")
	menu.queue_free()
	await tree.process_frame
	settings.call("load_settings", real_path)
	settings.call("apply")
