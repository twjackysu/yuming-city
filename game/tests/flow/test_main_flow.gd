extends TestCase
## 主線流程測試：
## - 開機 → 標題畫面 → 可選新遊戲
## - 新遊戲 → 每個檢查點自動存檔 → 中途存讀檔 → 死亡重試 → 切片結尾（任務／存檔層面，兩條路線）
## 切片場景完成後，同一條路線要再加上場景層面的驗證。

var _dir: String = ""


func before_each() -> void:
	_dir = "user://test_flow_%d" % Time.get_ticks_usec()


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _auto_checkpoint() -> String:
	var r: Dictionary = SaveCodec.read_file(_dir.path_join("auto.json"))
	if int(r["status"]) != SaveCodec.Status.OK:
		return "<no autosave>"
	return (r["state"] as GameState).checkpoint


## 走到送葬者戰之前。
func _play_to_undertaker(g: GameSession) -> void:
	assert_eq(g.state.checkpoint, "start")
	assert_eq(_auto_checkpoint(), "start", "新遊戲就有自動存檔")
	g.set_flag("slice.met_pear_seller", true)
	assert_eq(g.state.checkpoint, "bell_tower")
	for i: int in 9:
		g.add_flag("slice.bell_rings")
	assert_eq(g.state.get_flag("slice.north_street_collapsed"), true, "第九聲 → 北街陷落")
	assert_eq(_auto_checkpoint(), "rescue")
	g.add_flag("slice.rescued_count", 4)
	g.set_flag("slice.rescue_done", true)
	g.set_flag("slice.told_truth_about_bell", true)
	g.set_flag("slice.sheila_talked", true)
	assert_eq(g.quests.stage_of(GameSession.MAIN_QUEST), "meet_sheila", "還沒打倒灰巡者")
	g.set_flag("slice.ashwalker_defeated", true)
	assert_eq(g.state.checkpoint, "undertaker")
	assert_eq(_auto_checkpoint(), "undertaker")


func test_boot_to_title() -> void:
	var packed: PackedScene = load("res://scenes/boot/boot.tscn") as PackedScene
	assert_not_null(packed, "標題場景")
	if packed == null:
		return
	var boot: Control = packed.instantiate() as Control
	tree.root.add_child(boot)
	await tree.process_frame
	var new_game: Button = boot.get_node("%NewGame") as Button
	assert_not_null(new_game, "新遊戲按鈕")
	if new_game != null:
		assert_false(new_game.disabled, "新遊戲可按")
		assert_eq(new_game.text, "MENU_NEW_GAME", "按鈕使用翻譯 key")
	boot.queue_free()
	await tree.process_frame


func test_autoloads_present() -> void:
	for name: String in ["App", "Settings", "Game", "Perf"]:
		assert_true(tree.root.has_node(name), "autoload %s" % name)


func test_perf_snapshot_has_measurements() -> void:
	var perf: Node = tree.root.get_node_or_null("Perf")
	assert_not_null(perf, "Perf")
	if perf == null:
		return
	for i: int in 5:
		await tree.process_frame
	var d: Dictionary = perf.call("snapshot")
	for key: String in ["avg_fps", "low1_fps", "avg_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls", "vram_mb", "driver", "adapter"]:
		assert_true(d.has(key), "snapshot 有 %s" % key)
	assert_true(str(perf.call("snapshot_text")).contains("FPS"), "overlay 文字")


func test_sandbox_player_walks_forward() -> void:
	var packed: PackedScene = load("res://scenes/dev/sandbox.tscn") as PackedScene
	assert_not_null(packed, "沙盒場景")
	if packed == null:
		return
	var level: Node3D = packed.instantiate() as Node3D
	tree.root.add_child(level)
	await tree.physics_frame
	var player: PlayerController = level.get_node("Player") as PlayerController
	assert_not_null(player, "玩家")
	for i: int in 10:
		await tree.physics_frame
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	for i: int in 30:
		await tree.physics_frame
	Input.action_release("move_forward")
	var moved: Vector3 = player.global_position - start
	assert_true(moved.z < -0.5, "按前進 0.5 秒會往鏡頭前方（-Z）走，實際位移 %s" % moved)
	assert_true(absf(player.global_position.y) < 0.3, "站在地上沒有掉下去（y=%.2f）" % player.global_position.y)
	level.queue_free()
	await tree.process_frame


## 場景層面：沙盒裡走進梨販與鐘樓的觸發區 → 任務推進、自動存檔、HUD 目標跟著換。
func test_sandbox_triggers_advance_quest() -> void:
	var game: Node = tree.root.get_node("Game")
	var original: GameSession = game.get("session") as GameSession
	var s := GameSession.new(QuestDB.load_default(), _dir)
	game.set("session", s)
	s.new_game()
	var level: Node3D = (load("res://scenes/dev/sandbox.tscn") as PackedScene).instantiate() as Node3D
	tree.root.add_child(level)
	await tree.physics_frame
	var player: PlayerController = level.get_node("Player") as PlayerController
	var hud: Hud = level.get_node("Hud") as Hud
	assert_eq(hud.objective_text_key(), "Q_SLICE_OBJ_TOWN", "新遊戲：找梨販")

	# 還沒找梨販就跑去鐘樓：不會先敲鐘
	await _teleport(player, (level.get_node("BellTowerTrigger") as Node3D).global_position)
	assert_eq(int(s.state.get_flag("slice.bell_rings", 0)), 0, "順序不對時鐘樓不觸發")

	await _teleport(player, (level.get_node("PearSellerTrigger") as Node3D).global_position)
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "ring_bell", "走到梨販 → 敲鐘")
	assert_eq(hud.objective_text_key(), "Q_SLICE_OBJ_BELL", "HUD 目標更新")
	assert_eq(_auto_checkpoint(), "bell_tower", "進入檢查點自動存檔")

	await _teleport(player, (level.get_node("BellTowerTrigger") as Node3D).global_position)
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "rescue", "敲鐘九聲 → 救援")
	assert_eq(s.state.get_flag("slice.north_street_collapsed"), true, "北街陷落")
	assert_eq(hud.objective_text_key(), "Q_SLICE_OBJ_RESCUE")

	level.queue_free()
	await tree.process_frame
	game.set("session", original)


func _teleport(player: PlayerController, pos: Vector3) -> void:
	player.global_position = Vector3(pos.x, 0.05, pos.z)
	for i: int in 4:
		await tree.physics_frame
	# 離開觸發區，讓下一次進入重新觸發
	player.global_position = Vector3(0.0, 0.05, 2.0)
	for i: int in 2:
		await tree.physics_frame


func test_new_game_to_slice_end_with_nine_breaths() -> void:
	var g := GameSession.new(QuestDB.load_default(), _dir)
	g.new_game()
	_play_to_undertaker(g)

	# 手動存檔 → 讀檔 → 任務恢復到同一階段
	assert_eq(g.save("slot1"), OK)
	var g2 := GameSession.new(QuestDB.load_default(), _dir)
	assert_eq(g2.load_slot("slot1"), SaveCodec.Status.OK)
	assert_eq(g2.quests.stage_of(GameSession.MAIN_QUEST), "escort_convoy", "讀檔後任務恢復")
	assert_eq(g2.objective_key(), "Q_SLICE_OBJ_CONVOY")
	assert_eq(int(g2.state.get_flag("slice.rescued_count")), 4)

	# 九息石拱：付出記憶 → 戰死 → 重試回到檢查點，記憶沒有被扣、也不會重複扣
	var arch := NineBreath.new("south_arch", "arch_father_last_talk")
	arch.load_from(g2.state)
	assert_true(arch.activate(g2.state), "發動九息")
	assert_true(g2.state.has_paid_memory("arch_father_last_talk"))
	assert_eq(g2.retry_from_checkpoint(), SaveCodec.Status.OK, "死亡重試")
	assert_false(g2.state.has_paid_memory("arch_father_last_talk"), "回到檢查點：代價一起回到付出前")
	var arch2 := NineBreath.new("south_arch", "arch_father_last_talk")
	arch2.load_from(g2.state)
	assert_true(arch2.activate(g2.state), "重試後再發動")
	arch2.tick(9.5, g2.state)
	assert_eq(arch2.phase, NineBreath.Phase.SPENT, "九息後化灰")
	assert_eq(g2.state.memories_paid.size(), 1, "只付一次")

	g2.set_flag("slice.convoy_through", true)
	assert_eq(_auto_checkpoint(), "aftermath")
	g2.set_flag("slice.cellar_entered", true)
	assert_true(g2.is_slice_complete(), "切片完成")
	assert_eq(g2.state.get_flag("slice.complete"), true)


func test_new_game_to_slice_end_with_kindling_blade() -> void:
	# 拒絕九息：席菈提前燒薪火劍；不付記憶也能走完
	var g := GameSession.new(QuestDB.load_default(), _dir)
	g.new_game()
	_play_to_undertaker(g)
	g.set_flag("sheila.kindling_used_early", true)
	g.set_flag("slice.convoy_through", true)
	g.set_flag("slice.cellar_entered", true)
	assert_true(g.is_slice_complete())
	assert_eq(g.state.memories_paid.size(), 0, "沒有付記憶")
	assert_eq(g.state.get_flag("sheila.kindling_used_early"), true)
	# 完成後的存檔讀回來仍是完成狀態
	assert_eq(g.save("slot2"), OK)
	var g2 := GameSession.new(QuestDB.load_default(), _dir)
	g2.load_slot("slot2")
	assert_true(g2.is_slice_complete(), "讀檔後仍是完成")


func test_missing_save_reports_not_found() -> void:
	var g := GameSession.new(QuestDB.load_default(), _dir)
	assert_false(g.has_save())
	assert_eq(g.load_slot("auto"), SaveCodec.Status.NOT_FOUND)
