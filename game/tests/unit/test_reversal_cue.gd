extends TestCase
## 反轉的回饋：時間軸（ReversalCue，純邏輯）、畫面那一層（ReversalOverlay）、狀態圖示翻面（StatusHud）、諾恩身上的接線。


func test_reversed_cue_goes_curse_then_shatter_once_then_gold() -> void:
	var cue := ReversalCue.new()
	var count: Array[int] = [0]
	cue.shattered.connect(func() -> void: count[0] += 1)
	assert_false(cue.is_playing(), "沒開始＝沒在播")
	assert_eq(cue.curse(), 0.0)
	cue.start(true)
	cue.step(ReversalCue.CURSE_RISE_SEC)
	assert_eq(cue.curse(), 1.0, "紫紅很快亮滿")
	assert_eq(cue.gold(), 0.0, "還沒碎之前沒有金光")
	assert_eq(count[0], 0)
	cue.step(ReversalCue.CURSE_SEC - ReversalCue.CURSE_RISE_SEC + 0.01)
	assert_eq(count[0], 1, "過了 %.1f 秒碎裂" % ReversalCue.CURSE_SEC)
	assert_true(cue.gold() > 0.9, "碎裂那一刻金光最亮：%.2f" % cue.gold())
	assert_true(cue.shatter() > 0.0 and cue.shatter() < 0.2)
	cue.step(ReversalCue.SHATTER_SEC)
	assert_eq(cue.shatter(), 1.0, "碎片掉完")
	assert_eq(cue.curse(), 0.0, "紫紅沒了")
	assert_true(cue.gold() > 0.0 and cue.gold() < 0.6, "金光慢慢退：%.2f" % cue.gold())
	cue.step(ReversalCue.GOLD_SEC)
	assert_false(cue.is_playing(), "播完")
	assert_eq(count[0], 1, "只碎一次")


func test_unreversed_cue_only_flashes_and_fades() -> void:
	var cue := ReversalCue.new()
	var count: Array[int] = [0]
	cue.shattered.connect(func() -> void: count[0] += 1)
	cue.start(false)
	cue.step(ReversalCue.CURSE_SEC + 0.2)
	assert_true(cue.curse() > 0.0 and cue.curse() < 1.0, "紫紅在退：%.2f" % cue.curse())
	assert_eq(cue.shatter(), 0.0, "不會反轉的不碎")
	assert_eq(cue.gold(), 0.0, "也沒有金光")
	cue.step(ReversalCue.HARM_FADE_SEC)
	assert_false(cue.is_playing())
	assert_eq(count[0], 0)


func test_icon_face_flips_at_the_shatter_moment() -> void:
	assert_eq(ReversalCue.icon_face(0.0), 1.0, "剛上身：紅的那一面")
	assert_eq(ReversalCue.icon_face(ReversalCue.CURSE_SEC - 0.01), 1.0)
	assert_true(absf(ReversalCue.icon_face(ReversalCue.CURSE_SEC + ReversalCue.FLIP_SEC * 0.5)) < 0.01, "翻到一半是一條線")
	assert_eq(ReversalCue.icon_face(ReversalCue.CURSE_SEC + ReversalCue.FLIP_SEC), -1.0, "翻成金的")


func test_overlay_hidden_until_a_cue_plays() -> void:
	var overlay := ReversalOverlay.new()
	tree.root.add_child(overlay)
	var cue := ReversalCue.new()
	overlay.refresh(cue)
	assert_false(overlay.visible, "沒在播就不畫")
	cue.start(true)
	cue.step(0.2)
	overlay.refresh(cue)
	assert_true(overlay.visible)
	assert_eq(overlay.levels(), Vector3(1.0, 0.0, 0.0), "紫紅滿、還沒碎")
	cue.step(0.2)
	overlay.refresh(cue)
	assert_true(overlay.levels().y > 0.0 and overlay.levels().z > 0.5, "碎裂中＋金光：%s" % overlay.levels())
	overlay.refresh(null)
	assert_false(overlay.visible)
	overlay.queue_free()
	await tree.process_frame


func test_status_icon_already_on_body_when_hud_attaches_is_settled() -> void:
	var hud := StatusHud.new()
	tree.root.add_child(hud)
	var fx := StatusEffects.new(StatusRules.load_default(), ReversalSlots.new())
	fx.apply_source("miasma")
	hud.refresh(fx)
	assert_true(float(hud.rows[0]["face"]) < 0.0, "讀檔、換關卡接上時身上已經有的：直接是金的，不再演一次翻面")
	hud.queue_free()
	await tree.process_frame


func test_player_starts_the_cue_on_a_new_status_and_bursts_gold_on_shatter() -> void:
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	tree.root.add_child(player)
	await tree.process_frame
	assert_false(player.reversal_cue.is_playing())
	player.status_effects.apply_source("miasma")
	assert_true(player.reversal_cue.is_playing(), "中毒上身就開始播")
	assert_true(player.reversal_cue.reversed, "第一次中毒自動覺醒＝會反轉")
	var bursts: int = player.heal_fx.bursts
	player.reversal_cue.step(ReversalCue.CURSE_SEC + 0.01)
	assert_eq(player.heal_fx.bursts, bursts + 1, "碎裂那一刻身上噴一團金光")
	assert_eq(player.heal_fx.light().light_color, PlayerController.REVERSAL_GOLD)
	assert_true(player.shake_amount() > 0.0, "鏡頭輕輕震一下")
	if player.weapon() != null:
		assert_eq(player.sword_glow(), 0.0, "還沒過一幀：劍還沒亮")
		for i: int in 3:
			await tree.physics_frame
		assert_true(player.sword_glow() > PlayerController.SWORD_GLOW, "碎裂之後劍透金光，剛碎的時候最亮：%.2f" % player.sword_glow())
	# 同一種狀態刷新（站在瘴氣裡每 0.25 秒一次）不重播
	player.reversal_cue.step(5.0)
	player.status_effects.apply_source("miasma")
	assert_false(player.reversal_cue.is_playing(), "刷新不重播")
	# 沒裝進反轉欄位的狀態：只有紫紅
	player.status_effects.apply_source("sera_paralysis_vial")
	assert_true(player.reversal_cue.is_playing())
	assert_false(player.reversal_cue.reversed, "麻痺還沒裝進欄位＝不會反轉")
	player.queue_free()
	await tree.process_frame
