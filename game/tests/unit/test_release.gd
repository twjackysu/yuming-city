extends TestCase
## 釋放（毒爆，docs/design/11-combat-first.md 3.5，D-245）：把身上反轉中的毒一次用掉。
## 養＝站在霧裡越久越多秒（有上限、不會無限疊）；放＝周圍的人每個扣「秒數 × 8」（上限 80），毒就沒了；
## 劇情的數字裡這個鍵沒有作用。


func after_each() -> void:
	CombatTuning.set_profile("")
	CombatTuning.load_tuning()
	Engine.time_scale = 1.0
	Input.action_release("release")


func _effects() -> StatusEffects:
	var slots := ReversalSlots.new()
	slots.unlock("poison")
	slots.equip("poison")
	return StatusEffects.new(StatusRules.load_default(), slots)


func test_refresh_gain_grows_poison_up_to_the_cap_and_zero_keeps_the_old_rule() -> void:
	var old: StatusEffects = _effects()
	for i: int in 40:
		old.apply_source("poison_bottle")
	assert_eq(old.remaining("poison"), 3.0, "沒有開「養」：站多久都是來源的 3 秒（劇情）")
	var fx: StatusEffects = _effects()
	fx.refresh_gain = 0.75
	fx.apply_source("poison_bottle")
	assert_eq(fx.remaining("poison"), 3.0, "第一次上身就是來源的秒數，不會多")
	fx.apply_source("poison_bottle")
	assert_eq(fx.remaining("poison"), 3.75, "已經中毒：再中一次多 0.75 秒")
	for i: int in 200:
		fx.apply_source("poison_bottle")
	assert_eq(fx.remaining("poison"), fx.rules.max_duration("poison"), "疊不過上限（30 秒）")
	assert_eq(fx.ids().size(), 1, "同一種狀態還是只有一份")
	# 麻痺（不是持續傷害那一類）不會跟著越疊越久
	fx.reversal.unlock(StatusEffects.PARALYSIS)
	fx.reversal.equip(StatusEffects.PARALYSIS)
	for i: int in 30:
		fx.apply_source("bracer_hit")
	assert_eq(fx.remaining(StatusEffects.PARALYSIS), 6.0, "麻痺照舊：每次命中只是重新計時")


func test_consume_returns_the_seconds_and_removes_the_status() -> void:
	var fx: StatusEffects = _effects()
	assert_eq(fx.consume("poison"), 0.0, "身上沒有＝0")
	fx.apply("poison", 5.0, 7.0, "test")
	fx.tick(2.0, null)
	var events: Array[String] = []
	fx.changed.connect(func(id: String, event: String) -> void: events.append("%s:%s" % [id, event]))
	assert_eq(fx.consume("poison"), 5.0, "用掉剩下的 5 秒")
	assert_false(fx.has("poison"), "用掉就沒有了")
	assert_eq(events, ["poison:clear"] as Array[String], "發一次 clear")
	assert_eq(fx.consume("poison"), 0.0, "不能用第二次")


func _target(parent: Node3D, at: Vector3) -> Health:
	var body := Node3D.new()
	body.add_to_group("damageable")
	var h := Health.new(200.0)
	h.name = "Health"
	body.add_child(h)
	parent.add_child(body)
	body.global_position = at
	return h


func _player(root: Node3D, reversed: bool = true) -> PlayerController:
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	if reversed:
		player.reversal.unlock("poison")
		player.reversal.equip("poison")
	return player


func test_release_does_nothing_with_the_story_numbers() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: PlayerController = _player(root)
	var near: Health = _target(root, player.global_position + Vector3(0, 0, -1.5))
	player.status_effects.apply("poison", 5.0, 6.0, "test")
	assert_false(player.release_enabled(), "劇情：釋放沒有開")
	assert_eq(player.release_power(), 0.0)
	assert_true(player.release().is_empty(), "直接叫也沒有作用")
	Input.action_press("release")
	for i: int in 4:
		await tree.physics_frame
	Input.action_release("release")
	assert_eq(player.release_count, 0, "按了沒有反應")
	assert_true(player.status_effects.has("poison"), "毒還在身上")
	assert_eq(near.hp, 200.0, "旁邊的人沒事")
	assert_eq(player.status_effects.refresh_gain, 0.0, "劇情：站在霧裡不會越站越多秒")
	root.queue_free()
	await tree.process_frame


func test_burst_hits_everyone_in_radius_by_seconds_and_uses_up_the_poison() -> void:
	CombatTuning.set_profile(CombatTuning.PROFILE_ARENA)
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: PlayerController = _player(root)
	var front: Health = _target(root, player.global_position + Vector3(0, 0, -2.0))
	var behind: Health = _target(root, player.global_position + Vector3(0, 0, 2.6))
	var far: Health = _target(root, player.global_position + Vector3(3.4, 0, 0))
	assert_eq(player.release_power(), 0.0, "身上沒有毒：不能放")
	assert_true(player.release().is_empty())
	player.status_effects.apply("poison", 5.0, 5.0, "test")
	assert_eq(player.release_power(), 40.0, "5 秒 × 8")
	var seen: Array[Dictionary] = []
	player.released.connect(func(info: Dictionary) -> void: seen.append(info))
	var r: Dictionary = player.release()
	assert_eq(float(r["seconds"]), 5.0)
	assert_eq(float(r["damage"]), 40.0)
	assert_eq(int(r["hits"]), 2, "3 m 以內的兩個，不分前後")
	assert_eq(front.hp, 160.0)
	assert_eq(behind.hp, 160.0)
	assert_eq(far.hp, 200.0, "3.4 m 的炸不到")
	assert_false(player.status_effects.has("poison"), "毒用掉了：之後沒有回血")
	assert_eq(player.release_count, 1)
	assert_eq(seen.size(), 1, "released 發一次")
	assert_not_null(player.last_release_fx, "有一圈特效")
	assert_eq(player.last_release_fx.radius, 3.0, "綠環擴到的地方＝打得到的地方")
	assert_true(player.release().is_empty(), "不能連放第二次")
	assert_eq(front.hp, 160.0)
	# 上限：養到 30 秒也只扣 80
	player.status_effects.apply("poison", 5.0, 30.0, "test")
	assert_eq(player.release_power(), 80.0, "上限 80")
	player.release()
	assert_eq(front.hp, 80.0)
	# 剩不到半秒的毒不能放（不然每次只炸 1、2 點還把回血丟掉）
	player.status_effects.apply("poison", 5.0, 0.3, "test")
	assert_eq(player.release_power(), 0.0)
	root.queue_free()
	await tree.process_frame


func test_release_key_fires_once_and_poison_not_in_a_slot_cannot_be_released() -> void:
	CombatTuning.set_profile(CombatTuning.PROFILE_ARENA)
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: PlayerController = _player(root, false)
	var near: Health = _target(root, player.global_position + Vector3(0, 0, -1.5))
	# 沒有裝進反轉欄位的毒：那是在扣他的血，不能放
	player.reversal.awakened_once = true
	player.status_effects.apply("poison", 5.0, 6.0, "test")
	assert_false(player.status_effects.is_reversed("poison"))
	assert_eq(player.release_power(), 0.0, "沒反轉的毒不能放")
	player.status_effects.clear("poison")
	player.reversal.unlock("poison")
	player.reversal.equip("poison")
	player.status_effects.apply("poison", 5.0, 6.0, "test")
	Input.action_press("release")
	for i: int in 6:
		await tree.physics_frame
	Input.action_release("release")
	assert_eq(player.release_count, 1, "按住也只放一次")
	assert_true(near.hp < 200.0 and near.hp >= 200.0 - 48.0, "旁邊的人被炸到（%.0f）" % near.hp)
	assert_true(player.status_effects.refresh_gain > 0.0, "戰鬥場：站在霧裡越站越多秒")
	root.queue_free()
	await tree.process_frame


func test_release_has_its_own_key_and_no_default_key_is_shared() -> void:
	assert_eq(InputSetup.slot_of(InputSetup.defaults(), "release", InputSetup.SLOT_KBM), Vector2i(1, MOUSE_BUTTON_RIGHT), "鍵鼠：滑鼠右鍵")
	assert_eq(InputSetup.slot_of(InputSetup.defaults(), "release", InputSetup.SLOT_PAD), Vector2i(2, JOY_BUTTON_Y), "手把：Y")
	assert_eq(InputSetup.slot_of(InputSetup.defaults(), "insight", InputSetup.SLOT_KBM), Vector2i(0, KEY_V), "看穿搬到 V")
	assert_true(InputSetup.ACTION_KEYS.has("release"), "按鍵設定頁列得出來")
	var seen: Dictionary = {}
	for action: String in InputSetup.BINDINGS:
		var kbm: Vector2i = (InputSetup.BINDINGS[action] as Array)[InputSetup.SLOT_KBM] as Vector2i
		assert_false(seen.has(kbm), "%s 與 %s 預設是同一個鍵" % [action, str(seen.get(kbm, ""))])
		seen[kbm] = action
	assert_true(InputMap.has_action("release"), "啟動時就有這個動作")


func test_status_row_shows_the_release_hint_only_for_that_status() -> void:
	var hud := StatusHud.new()
	tree.root.add_child(hud)
	var fx: StatusEffects = _effects()
	fx.apply("poison", 5.0, 6.0, "test")
	hud.refresh(fx, "poison", "[RMB]: 48")
	assert_true(hud.line_text(0).ends_with("[RMB]: 48"), "中毒那一列後面有提示：%s" % hud.line_text(0))
	hud.refresh(fx, "poison", "")
	assert_true(hud.line_text(0).ends_with("6"), "不能放的時候只有秒數：%s" % hud.line_text(0))
	hud.refresh(fx, "paralysis", "[RMB]: 48")
	assert_true(hud.line_text(0).ends_with("6"), "別種狀態的提示不會寫到中毒那一列")
	hud.queue_free()
	await tree.process_frame
