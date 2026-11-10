extends TestCase
## 新版：毒霧範圍（MistZone）與狀態圖示（StatusHud），D-202。


func _fx(reversed: bool) -> StatusEffects:
	var rev: ReversalSlots = null
	if reversed:
		rev = ReversalSlots.new()
	return StatusEffects.new(StatusRules.load_default(), rev)


func test_mist_applies_while_inside_and_lingers_after_leaving() -> void:
	var zone := MistZone.new(Vector3.ZERO, 3.0, "barrel_mist")
	var fx := _fx(true)
	assert_true(zone.expose(1, Vector3(1, 0, 1), fx, 0.016), "一進來就上狀態")
	assert_true(fx.has("poison"))
	assert_true(fx.reversal.is_reversed("poison"), "第一次中毒自動覺醒")
	for i: int in 60:  # 在霧裡待 1 秒
		zone.expose(1, Vector3(1, 0, 1), fx, 1.0 / 60.0)
		fx.tick(1.0 / 60.0, null)
	assert_true(fx.remaining("poison") > 3.6, "在霧裡一直刷新成 4 秒：%s" % fx.remaining("poison"))
	assert_false(zone.expose(1, Vector3(5, 0, 0), fx, 0.016), "出了半徑")
	fx.tick(3.9, null)
	assert_true(fx.has("poison"), "離開後還有一下下")
	fx.tick(0.2, null)
	assert_false(fx.has("poison"), "離開約 4 秒後結束（回血跟著停）")


func test_mist_height_and_expiry() -> void:
	var zone := MistZone.new(Vector3(0, 1, 0), 2.0, "guardian_spray", 3.0)
	var fx := _fx(false)
	assert_false(zone.contains(Vector3(0, 5, 0)), "上面的平台不在霧裡")
	assert_true(zone.contains(Vector3(0, 1, 0)))
	zone.tick(3.0)
	assert_true(zone.expired(), "守衛噴的霧 3 秒散掉")
	assert_false(zone.expose(1, Vector3(0, 1, 0), fx, 0.1))
	assert_false(fx.has("poison"))


func test_npc_in_mist_gets_hurt_not_healed() -> void:
	var zone := MistZone.new(Vector3.ZERO, 3.0, "barrel_mist")
	var fx := _fx(false)
	var h := Health.new(100.0)
	for i: int in 30:
		zone.expose(7, Vector3.ZERO, fx, 1.0 / 30.0)
		fx.tick(1.0 / 30.0, h)
	assert_true(h.hp < 100.0, "NPC 沒有反轉欄位，不會跟著免疫：%s" % h.hp)


func test_status_hud_shows_original_type_and_reversal() -> void:
	var hud := StatusHud.new()
	tree.root.add_child(hud)
	var fx := _fx(true)
	hud.refresh(fx)
	assert_eq(hud.rows.size(), 0, "沒有狀態時是空的")
	fx.apply_source("barrel_mist")
	hud.refresh(fx)
	assert_eq(hud.rows.size(), 1)
	assert_eq(hud.rows[0]["id"], "poison", "圖示保留原類型（中毒）")
	assert_true(bool(hud.rows[0]["reversed"]), "帶反轉標記")
	assert_true(hud.line_text(0).begins_with(tr("RB_STATUS_POISON_REVERSED")), "寫「中毒 → 回血」：%s" % hud.line_text(0))
	assert_true(hud.line_text(0).ends_with("4"), "剩餘秒數")
	var npc := _fx(false)
	npc.apply_source("barrel_mist")
	hud.refresh(npc)
	assert_false(bool(hud.rows[0]["reversed"]))
	assert_eq(hud.rows[0]["label"], "RB_STATUS_POISON", "沒反轉只寫「中毒」")
	fx.tick(10.0, null)
	hud.refresh(fx)
	assert_eq(hud.line_text(0), "", "結束後收掉")
	hud.queue_free()


func test_restored_hp_keeps_saved_value_with_floor() -> void:
	assert_eq(PlayerController.restored_hp(null, 100.0), 100.0, "沒存過＝滿血（新遊戲）")
	assert_eq(PlayerController.restored_hp(72.5, 100.0), 72.5, "照存的，不偷偷補滿")
	assert_eq(PlayerController.restored_hp(5, 100.0), 50.0, "讀檔、重試至少一半（09 第 3 節）")
	assert_eq(PlayerController.restored_hp(400.0, 100.0), 100.0, "不超過上限")


func test_use_item_action_is_bound_and_rebindable() -> void:
	assert_true(InputSetup.BINDINGS.has("use_item"), "可攜藥劑快捷鍵")
	assert_eq(InputSetup.ACTION_KEYS.get("use_item"), "ACT_USE_ITEM", "按鍵設定頁有這一列")
	assert_true(InputSetup.is_rebindable("use_item", InputSetup.SLOT_KBM))
	assert_true(InputSetup.is_rebindable("use_item", InputSetup.SLOT_PAD))
	var used: Dictionary = {}
	for action: String in InputSetup.BINDINGS:
		for slot: int in 2:
			var spec: Vector2i = (InputSetup.BINDINGS[action] as Array)[slot]
			if spec.x == 3:
				continue  # 搖桿軸本來就成對共用
			var k: String = "%d:%s" % [slot, spec]
			assert_false(used.has(k), "%s 跟 %s 撞鍵" % [action, used.get(k, "")])
			used[k] = action


func test_poison_mist_node_builds_layers_and_fades_out() -> void:
	var mist: PoisonMist = PoisonMist.create(2.0, "guardian_spray", 1.0)
	tree.root.add_child(mist)
	assert_eq(mist.get_child_count(), PoisonMist.LAYERS, "貼地的幾層霧盤")
	assert_true(mist.is_in_group("poison_mist"))
	assert_true(mist.contains(mist.global_position + Vector3(1.0, 0.2, 0.0)))
	mist._physics_process(0.7)
	assert_true(is_instance_valid(mist) and not mist.is_queued_for_deletion(), "還沒散完")
	mist._physics_process(0.4)
	assert_true(mist.is_queued_for_deletion(), "守衛噴的霧時間到自己移除")


## 生命條（CombatHud）平常只在戰鬥中出現；身上有狀態時也要出現——不然中毒回血看不到生命往上爬（D-205）
func test_health_bar_shows_while_status_active_out_of_combat() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	var hud := CombatHud.new()
	root.add_child(hud)
	await tree.process_frame
	hud.refresh(player, null)
	assert_false(hud.in_combat, "附近沒有敵人")
	assert_false(hud.bars_shown, "沒有狀態、不在戰鬥：生命條收起來")
	player.status_effects.apply("poison", 3.0, 5.0, "test")
	hud.refresh(player, null)
	assert_false(hud.in_combat, "有狀態不算戰鬥（目標指引照常）")
	assert_true(hud.bars_shown, "身上有狀態：生命條出現")
	player.status_effects.clear("poison")
	hud.refresh(player, null)
	assert_false(hud.bars_shown, "狀態結束：收起來")
	root.queue_free()
	await tree.process_frame
