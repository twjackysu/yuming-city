extends TestCase
## 新版：毒霧範圍（MistZone）與狀態圖示（StatusHud）。


func _fx(reversed: bool) -> StatusEffects:
	return StatusEffects.new(StatusRules.load_default(), reversed)


func test_mist_applies_while_inside_and_lingers_after_leaving() -> void:
	var zone := MistZone.new(Vector3.ZERO, 3.0, "miasma")
	var fx := _fx(true)
	assert_true(zone.expose(1, Vector3(1, 0, 1), fx, 0.016), "一進來就上狀態")
	assert_true(fx.has("poison"))
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
	var zone := MistZone.new(Vector3(0, 1, 0), 2.0, "boss_miasma", 3.0)
	var fx := _fx(false)
	assert_false(zone.contains(Vector3(0, 5, 0)), "上面的平台不在霧裡")
	assert_true(zone.contains(Vector3(0, 1, 0)))
	zone.tick(3.0)
	assert_true(zone.expired(), "守衛噴的霧 3 秒散掉")
	assert_false(zone.expose(1, Vector3(0, 1, 0), fx, 0.1))
	assert_false(fx.has("poison"))


func test_npc_in_mist_gets_hurt_not_healed() -> void:
	var zone := MistZone.new(Vector3.ZERO, 3.0, "miasma")
	var fx := _fx(false)
	var h := Health.new(100.0)
	for i: int in 30:
		zone.expose(7, Vector3.ZERO, fx, 1.0 / 30.0)
		fx.tick(1.0 / 30.0, h)
	assert_true(h.hp < 100.0, "其他人不會反轉，照樣掉血：%s" % h.hp)


func test_status_hud_shows_original_type_and_reversal() -> void:
	var hud := StatusHud.new()
	tree.root.add_child(hud)
	var fx := _fx(true)
	hud.refresh(fx)
	assert_eq(hud.rows.size(), 0, "沒有狀態時是空的")
	fx.apply_source("miasma")
	hud.refresh(fx)
	assert_eq(hud.rows.size(), 1)
	assert_eq(hud.rows[0]["id"], "poison", "圖示保留原類型（中毒）")
	assert_true(bool(hud.rows[0]["reversed"]), "規則上已經反轉")
	assert_eq(hud.rows[0]["label"], "STATUS_POISON", "剛上身的那一下還是紅的「中毒」")
	hud.advance(ReversalCue.CURSE_SEC + ReversalCue.FLIP_SEC + 0.01)
	hud.refresh(fx)
	assert_true(float(hud.rows[0]["face"]) < 0.0, "翻成金的那一面")
	assert_true(hud.line_text(0).begins_with(tr("STATUS_POISON_REVERSED")), "寫「中毒 → 回血」：%s" % hud.line_text(0))
	assert_true(hud.line_text(0).ends_with("4"), "剩餘秒數")
	var npc := _fx(false)
	npc.apply_source("miasma")
	hud.refresh(npc)
	assert_false(bool(hud.rows[0]["reversed"]))
	assert_eq(hud.rows[0]["label"], "STATUS_POISON", "沒反轉只寫「中毒」")
	fx.tick(10.0, null)
	hud.refresh(fx)
	assert_eq(hud.line_text(0), "", "結束後收掉")
	hud.queue_free()


## 會疊的狀態（流血）：狀態列那一格記得現在幾層（畫在圖示右上角）；不會疊的是 0
func test_status_hud_counts_stacks_of_bleed() -> void:
	var fx := StatusEffects.new(StatusRules.load_default(), true)
	var hud := StatusHud.new()
	tree.root.add_child(hud)
	for i: int in 3:
		fx.apply_source("rusty_sword_cut")
	hud.refresh(fx)
	assert_eq(hud.rows.size(), 2, "流血＋中毒")
	assert_eq(hud.rows[0]["id"], "bleed")
	assert_eq(hud.rows[0]["stacks"], 3, "砍中三刀＝三層")
	assert_eq(hud.rows[1]["stacks"], 0, "中毒不會疊")
	hud.advance(1.0)
	hud.refresh(fx)
	assert_true(hud.line_text(0).begins_with(tr("STATUS_BLEED_REVERSED")), "寫「流血 → 越砍越快」：%s" % hud.line_text(0))
	hud.queue_free()
	await tree.process_frame


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
	var mist: PoisonMist = PoisonMist.create(2.0, "boss_miasma", 1.0)
	tree.root.add_child(mist)
	var discs: int = 0
	for c: Node in mist.get_children():
		discs += 1 if c is MeshInstance3D else 0
	assert_eq(discs, PoisonMist.LAYERS, "貼地的幾層霧盤")
	var vol: FogVolume = mist.get_node_or_null("MistVolume") as FogVolume
	assert_not_null(vol, "有體積的那一團（體積霧裡的綠色橢球，D-207）")
	assert_eq(vol.size.x, 4.0, "跟毒霧的範圍一樣寬")
	# 濃淡與輪廓用 fog shader（底濃上淡、邊緣不規則、會流動）；密度是 32 位元浮點數，不能直接比相等
	var vol_mat: ShaderMaterial = vol.material as ShaderMaterial
	assert_true(vol_mat != null and vol_mat.shader == PoisonMist.VOLUME_SHADER, "體積那一團用 poison_mist_volume.gdshader")
	assert_true(absf(float(vol_mat.get_shader_parameter("density")) - PoisonMist.VOLUME_DENSITY) < 0.001, "密度照常數")
	assert_true(absf(float(vol_mat.get_shader_parameter("fade")) - 1.0) < 0.001, "一開始是滿的")
	assert_true(absf(float(vol_mat.get_shader_parameter("ground_offset")) - (vol.position.y - 0.0)) < 0.001, "地面的高度跟擺放的高度一致（底濃上淡從地面算起）")
	# 霧盤的面片比毒霧的範圍大一圈（邊緣用雜訊咬的時候不會被面片切出硬邊），shader 知道大多少
	var layer0: MeshInstance3D = mist.get_node("MistLayer0") as MeshInstance3D
	assert_true(absf((layer0.mesh as PlaneMesh).size.x - 4.0 * PoisonMist.DISC_OVERSCAN) < 0.001, "貼地那層的面片＝直徑 × overscan")
	assert_true(absf(float((layer0.material_override as ShaderMaterial).get_shader_parameter("overscan")) - PoisonMist.DISC_OVERSCAN) < 0.001)
	assert_true(mist.is_in_group("poison_mist"))
	assert_true(mist.contains(mist.global_position + Vector3(1.0, 0.2, 0.0)))
	mist._physics_process(0.7)
	assert_true(is_instance_valid(mist) and not mist.is_queued_for_deletion(), "還沒散完")
	assert_true(float(vol_mat.get_shader_parameter("fade")) < 0.75, "最後 0.6 秒跟著霧盤一起淡掉")
	assert_true(absf(float(vol_mat.get_shader_parameter("fade")) - float((layer0.material_override as ShaderMaterial).get_shader_parameter("fade"))) < 0.001, "體積跟霧盤淡得一樣快")
	mist._physics_process(0.4)
	assert_true(mist.is_queued_for_deletion(), "守衛噴的霧時間到自己移除")


## 生命條（CombatHud）平常只在戰鬥中出現；身上有狀態時也要出現——不然中毒回血看不到生命往上爬
