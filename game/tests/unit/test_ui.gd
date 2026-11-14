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


## ：四個分組標題、「‹ 值 ›」箭頭（點箭頭／左右鍵切換）、值下面的小圓點、音量百分比、整個面板塞得進 1080。
func test_settings_menu_groups_arrows_pips() -> void:
	var settings: Node = tree.root.get_node("Settings")
	var menu: SettingsMenu = (load("res://scenes/ui/settings_menu.tscn") as PackedScene).instantiate() as SettingsMenu
	tree.root.add_child(menu)
	menu.open()
	await tree.process_frame
	await tree.process_frame
	assert_eq(menu.group_keys(), PackedStringArray(["SET_GROUP_GAME", "SET_GROUP_AUDIO", "SET_GROUP_DISPLAY", "SET_GROUP_INPUT"]), "四組：遊戲／聲音／畫面／操作")
	assert_eq(menu.group_of("Difficulty"), "Game")
	assert_eq(menu.group_of("Subtitles"), "Game")
	assert_eq(menu.group_of("VolumeMusic"), "Audio")
	assert_eq(menu.group_of("Quality"), "Display")
	assert_eq(menu.group_of("ReduceShake"), "Display")
	assert_eq(menu.group_of("Controls"), "Input")

	var quality_before: int = int(settings.get("quality"))
	var q: Button = menu.control_of("Quality") as Button
	var prev: ValueArrow = menu.arrow_of("Quality", -1)
	var next: ValueArrow = menu.arrow_of("Quality", 1)
	assert_true(prev != null and next != null, "畫質兩側有箭頭")
	if prev == null or next == null:
		menu.queue_free()
		return
	var p_pts: PackedVector2Array = prev.points()
	var n_pts: PackedVector2Array = next.points()
	assert_true(p_pts[1].x < p_pts[0].x, "左箭頭尖端朝左")
	assert_true(n_pts[1].x > n_pts[0].x, "右箭頭尖端朝右")
	assert_true(prev.position.x < q.size.x * 0.25 and next.position.x > q.size.x * 0.75, "箭頭在值的兩側")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	next._gui_input(click)
	assert_eq(int(settings.get("quality")), (quality_before + 1) % 3, "點右箭頭：下一級")
	assert_true(q.has_focus(), "點箭頭時焦點移到那一列")
	assert_eq(menu.ticks, 1, "換值時一聲小小的「叮」")
	assert_true(Sfx.NAMES.has("ui_tick"), "ui_tick 在音效清單裡（打包驗證會檢查）")
	assert_true(next.is_lit(), "有焦點時箭頭亮起來")
	prev._gui_input(click)
	prev._gui_input(click)
	assert_eq(int(settings.get("quality")), posmod(quality_before - 1, 3), "點左箭頭：上一級（會繞回）")
	assert_eq(q.text, QualityPreset.NAME_KEYS[int(settings.get("quality"))], "值跟著換")
	var left := InputEventAction.new()
	left.action = "ui_left"
	left.pressed = true
	q.gui_input.emit(left)
	assert_eq(int(settings.get("quality")), posmod(quality_before - 2, 3), "左鍵（十字鍵左）切到上一個")
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	q.gui_input.emit(right)
	assert_eq(int(settings.get("quality")), posmod(quality_before - 1, 3), "右鍵切到下一個")

	var pips: ValuePips = menu.pips_of("Quality")
	assert_true(pips != null and pips.count == 3, "畫質下面三顆圓點")
	if pips != null:
		assert_eq(pips.index, int(settings.get("quality")), "實心那顆＝目前畫質")
		assert_true(pips.center_of(0).x < pips.center_of(2).x, "圓點由左到右")
	assert_true(menu.pips_of("Vsync") == null, "開／關不畫圓點")
	assert_not_null(menu.arrow_of("Vsync", 1), "開／關也有箭頭")
	settings.call("set_quality", quality_before)

	(menu.find_child("Back", true, false) as Control).grab_focus()
	await tree.process_frame
	assert_false(next.is_lit(), "焦點離開、滑鼠不在上面：箭頭變暗")

	var vol_before: float = float(settings.call("volume", "SFX"))
	var slider: HSlider = menu.control_of("VolumeSFX") as HSlider
	var pct: Label = slider.get_parent().get_node("Percent") as Label
	slider.value = 0.35
	assert_eq(pct.text, "35%", "音量旁邊顯示百分比")
	settings.call("set_volume", "SFX", vol_before)
	menu.open()
	assert_eq(pct.text, "%d%%" % roundi(vol_before * 100.0), "重新打開時百分比跟設定一致")

	var panel: PanelContainer = menu.find_children("*", "PanelContainer", true, false)[0] as PanelContainer
	assert_true(panel.get_combined_minimum_size().y <= 1040.0, "設定面板塞得進 1080 高（%.0f）" % panel.get_combined_minimum_size().y)
	menu.close()
	menu.queue_free()
	await tree.process_frame


func test_pause_menu_pauses_and_resumes() -> void:
	var pause: PauseMenu = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	tree.root.add_child(pause)
	# HUD 一類的圖層：暫停時藏起來、繼續時恢復；本來就藏著的維持藏著
	var hud_like := CanvasLayer.new()
	hud_like.add_to_group(PauseMenu.HIDE_GROUP)
	tree.root.add_child(hud_like)
	var already_hidden := CanvasLayer.new()
	already_hidden.add_to_group(PauseMenu.HIDE_GROUP)
	already_hidden.visible = false
	tree.root.add_child(already_hidden)
	await tree.process_frame
	assert_false(pause.is_open(), "一開始沒開")
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	pause._unhandled_input(ev)
	assert_true(pause.is_open(), "按暫停鍵打開")
	assert_false(hud_like.visible, "暫停時 HUD 藏起來")
	assert_true(tree.paused, "遊戲暫停")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "暫停時釋放滑鼠")
	assert_true(_assert_texts_are_keys(pause, "暫停選單") >= 4)
	var band: TextureRect = pause.find_child("Band", true, false) as TextureRect
	assert_true(band != null and band.offset_right >= 600.0, "選單後面有左側暗帶（D-090）")
	var g: Gradient = (band.texture as GradientTexture2D).gradient
	assert_true(g.sample(0.0).a > 0.7 and g.sample(1.0).a < 0.05, "暗帶由深到透明")
	var menu: VBoxContainer = pause.find_child("Menu", true, false) as VBoxContainer
	var title_i: int = menu.get_node("Title").get_index()
	assert_eq(menu.get_child(title_i + 1).name, &"Rule", "標題下面一條細線")
	assert_eq(menu.get_child(0).name, &"Chapter", "標題上面一行章節名（D-093）")
	assert_eq((menu.get_child(0) as Label).text, "GAME_SUBTITLE")
	assert_true(pause.hint_text().length() > 3 and not pause.hint_text().contains("{key}"), "左下角有按鍵提示（%s）" % pause.hint_text())
	if Game.session != null and Game.session.objective_key() != "":
		assert_eq(pause.objective_text(), Game.session.objective_key(), "左下角寫著目前目標")
	assert_eq(pause.get_node("Root/Hint").get_class(), "HBoxContainer", "提示用 GlyphLine")
	(pause.find_child("Settings", true, false) as Button).pressed.emit()
	var sm: SettingsMenu = pause.find_child("SettingsMenu", true, false) as SettingsMenu
	assert_true(sm != null and sm.visible, "暫停中可以開設定")
	pause._unhandled_input(ev)
	assert_true(pause.is_open(), "設定開著時暫停鍵交給設定選單處理")
	sm.close()
	pause._unhandled_input(ev)
	assert_false(pause.is_open(), "再按一次繼續")
	assert_false(tree.paused, "解除暫停")
	assert_true(hud_like.visible, "繼續時 HUD 回來")
	assert_false(already_hidden.visible, "本來就藏著的圖層維持藏著")
	hud_like.queue_free()
	already_hidden.queue_free()
	pause.queue_free()
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
	assert_true(_assert_texts_are_keys(controls, "按鍵設定") >= 17, "每個動作都有名稱")
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
