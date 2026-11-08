extends TestCase
## M1.4「鍵鼠與手把」：只用手把事件（Input.parse_input_event）走切片開頭——
## 左搖桿走到梨販攤 → A 讀對話、十字鍵選最後一個選項 → 按住左搖桿衝刺走上主街到鐘樓 →
## 敲鐘演出裡每次等待都按一下 A，親手敲九下 → 救援。
## 不呼叫 press_continue／runner.press，全部走 _unhandled_input 與 GUI 焦點（跟玩家一樣）。
## 只有不等輸入的過場鏡頭用 update() 快轉（等同等待，不是輸入）。

const PAD: int = 0

var _dir: String = ""
var _game: Node
var _original: GameSession
var _original_device: int = 0


func before_each() -> void:
	_dir = "user://test_gamepad_%d" % Time.get_ticks_usec()
	_game = tree.root.get_node("Game")
	_original = _game.get("session") as GameSession
	_original_device = int(App.last_device)


func after_each() -> void:
	_stick(Vector2.ZERO)
	_button(JOY_BUTTON_LEFT_STICK, false)
	_button(JOY_BUTTON_A, false)
	App.set_device(_original_device)
	_game.set("session", _original)
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _stick(v: Vector2) -> void:
	for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var ev := InputEventJoypadMotion.new()
		ev.device = PAD
		ev.axis = axis as JoyAxis
		ev.axis_value = v.x if axis == JOY_AXIS_LEFT_X else v.y
		Input.parse_input_event(ev)


func _button(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = PAD
	ev.button_index = button
	ev.pressed = pressed
	ev.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


## 按一下（按下 → 兩幀 → 放開 → 兩幀）。
func _tap(button: JoyButton) -> void:
	_button(button, true)
	for i: int in 2:
		await tree.process_frame
	_button(button, false)
	for i: int in 2:
		await tree.process_frame


func _wait_scene() -> StoryLevel:
	for i: int in 3:
		await tree.process_frame
	await tree.physics_frame
	return tree.current_scene as StoryLevel


## 用左搖桿朝 target 走（依鏡頭 yaw 換算成搖桿方向），直到 until 成立或超時；回傳是否成立。
func _walk_to(player: PlayerController, target: Vector3, until: Callable, max_frames: int = 900) -> bool:
	for i: int in max_frames:
		if until.call():
			_stick(Vector2.ZERO)
			return true
		var d := Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
		if d.length() < 0.3:
			break
		var local: Vector3 = Basis(Vector3.UP, -player.yaw) * d.normalized()
		_stick(Vector2(local.x, local.z))
		await tree.physics_frame
	_stick(Vector2.ZERO)
	return bool(until.call())


func test_gamepad_pear_seller_to_ninth_bell() -> void:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	_game.set("session", s)
	s.new_game()
	_game.call("go_to_level", "frostbridge")
	var level: StoryLevel = await _wait_scene()
	assert_not_null(level, "進霜橋鎮")
	if level == null:
		return
	var player: PlayerController = level.get_node("Player") as PlayerController
	for i: int in 5:
		await tree.physics_frame

	# --- 左搖桿走到梨販攤（走進觸發區就開始對話）
	var stall: Vector3 = (level.get_node("PearSellerTrigger") as Node3D).global_position
	var talking := func() -> bool: return bool(_game.call("is_in_dialogue"))
	assert_true(await _walk_to(player, stall, talking), "左搖桿走到梨販攤 → 對話（停在 %s）" % player.global_position)
	assert_eq(int(App.last_device), int(InputGlyphs.Device.PAD), "動了搖桿 → 畫面提示換成手把")
	if not bool(_game.call("is_in_dialogue")):
		return

	# --- A 讀對話；有選項時十字鍵往下到最後一個（「我先走了」）再按 A
	var box: DialogueBox = level.get_node("DialogueBox") as DialogueBox
	var choices: Node = box.find_child("Choices", true, false)
	var picked_by_dpad: int = 0
	for i: int in 80:
		if not bool(_game.call("is_in_dialogue")):
			break
		if choices.get_child_count() > 0:
			await tree.process_frame  # 第一個選項的焦點是 call_deferred
			for k: int in choices.get_child_count():
				await _tap(JOY_BUTTON_DPAD_DOWN)
			var last: Button = choices.get_child(choices.get_child_count() - 1) as Button
			if last.has_focus():
				picked_by_dpad += 1
		await _tap(JOY_BUTTON_A)
	assert_false(_game.call("is_in_dialogue"), "A 把梨販對話讀完")
	assert_true(picked_by_dpad > 0, "十字鍵能移動選項焦點")
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "ring_bell", "說完 → 敲鐘")

	# --- 按住左搖桿（衝刺）走上主街到鐘樓：先到主街口再往北
	var bell: Vector3 = (level.get_node("BellTowerTrigger") as Node3D).global_position
	var in_cutscene := func() -> bool: return bool(_game.call("is_in_cutscene"))
	var never := func() -> bool: return false
	_button(JOY_BUTTON_LEFT_STICK, true)
	await _walk_to(player, Vector3(0.0, 0.0, -9.0), never, 400)
	var reached: bool = await _walk_to(player, bell, in_cutscene, 900)
	_button(JOY_BUTTON_LEFT_STICK, false)
	assert_true(reached, "衝刺走到鐘樓 → 敲鐘演出（停在 %s）" % player.global_position)
	if not reached:
		return

	# --- 每次等待都按一下 A：親手敲九下
	var cs: CutsceneRunner = _game.get("cutscene") as CutsceneRunner
	var presses: int = 0
	for i: int in 200:
		if not bool(_game.call("is_in_cutscene")):
			break
		if cs.is_waiting():
			await _tap(JOY_BUTTON_A)
			presses += 1
		else:
			cs.update(10.0)
			await tree.process_frame
	assert_false(_game.call("is_in_cutscene"), "演出結束")
	assert_eq(presses, 9, "按了九下 A")
	assert_eq(int(s.state.get_flag("slice.bell_rings", 0)), 9, "親手敲了九下")
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "rescue", "九聲 → 救援")
	var scene: Node = tree.current_scene
	if scene != null:
		scene.queue_free()
	for i: int in 3:
		await tree.process_frame


## 暫停選單只用手把：Start 打開 → 十字鍵移到「設定」→ A 進設定 → B 返回暫停選單 → B 繼續遊戲。
func test_gamepad_pause_menu_settings_and_back() -> void:
	var pause: PauseMenu = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	tree.root.add_child(pause)
	await tree.process_frame
	await _tap(JOY_BUTTON_START)
	assert_true(pause.is_open(), "Start 打開暫停選單")
	await tree.process_frame  # 第一個按鈕的焦點是 call_deferred
	var settings_button: Button = pause.find_child("Settings", true, false) as Button
	for i: int in 6:
		if settings_button.has_focus():
			break
		await _tap(JOY_BUTTON_DPAD_DOWN)
	assert_true(settings_button.has_focus(), "十字鍵移到「設定」")
	await _tap(JOY_BUTTON_A)
	var sm: SettingsMenu = pause.find_child("SettingsMenu", true, false) as SettingsMenu
	assert_true(sm != null and sm.visible, "A 進設定")
	await _tap(JOY_BUTTON_B)
	assert_true(sm != null and not sm.visible, "B 關掉設定")
	assert_true(pause.is_open(), "回到暫停選單（不是直接回遊戲）")
	await tree.process_frame
	assert_true(settings_button.has_focus(), "焦點回到「設定」")
	await _tap(JOY_BUTTON_B)
	assert_false(pause.is_open(), "B 繼續遊戲")
	assert_false(tree.paused, "解除暫停")
	pause.queue_free()
	await tree.process_frame


## 救援只用手把：左搖桿走到受困者旁（出現提示）→ 按住 A 搬開瓦礫 → 救滿三人，任務推進到「席菈」。
func test_gamepad_rescue_three() -> void:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	_game.set("session", s)
	s.new_game()
	s.set_flag("slice.met_pear_seller", true)
	for i: int in 9:
		s.add_flag("slice.bell_rings")
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "rescue", "前提：救援階段")
	_game.call("go_to_level", "frostbridge")
	var level: StoryLevel = await _wait_scene()
	assert_not_null(level, "進霜橋鎮")
	if level == null:
		return
	var player: PlayerController = level.get_node("Player") as PlayerController
	var start := Vector3(0.0, 0.0, -31.0)
	start.y = level.ground_y(start) + 0.05
	player.global_position = start
	for i: int in 5:
		await tree.physics_frame
	var sites: Array[RescueSite] = []
	for c: Node in level.get_children():
		if c is RescueSite:
			sites.append(c as RescueSite)
	assert_eq(sites.size(), 4, "北街陷落、四個受困者")
	var saved: int = 0
	for site: RescueSite in sites:
		if saved >= 3:
			break
		var near: bool = await _walk_to(player, site.global_position, site.prompt_shown, 600)
		assert_true(near, "左搖桿走到受困者旁、出現按住提示（%s）" % site.name)
		if not near:
			break
		_button(JOY_BUTTON_A, true)
		for i: int in 240:
			if site.is_rescued():
				break
			await tree.physics_frame
		_button(JOY_BUTTON_A, false)
		await tree.physics_frame
		assert_true(site.is_rescued(), "按住 A 搬開瓦礫、救出 %s" % site.name)
		if site.is_rescued():
			saved += 1
	assert_eq(saved, 3, "手把救出三人")
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "meet_sheila", "救滿三人 → 席菈登場")
	var scene: Node = tree.current_scene
	if scene != null:
		scene.queue_free()
	for i: int in 3:
		await tree.process_frame
