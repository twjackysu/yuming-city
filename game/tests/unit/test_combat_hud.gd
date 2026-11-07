extends TestCase
## 席菈倒下與拉起（8 秒內走近按互動鍵；超過就等戰鬥結束）、戰鬥 HUD（只在戰鬥中顯示、數值跟著變、指令冷卻、倒下提示）。

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_TW")


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func test_revive_window_logic() -> void:
	var b := CompanionBrain.new().configure()
	b.set_down(true)
	assert_true(b.can_be_revived())
	b.tick(5.0, 1.0, null, 99.0)
	assert_true(absf(b.revive_time_left() - 3.0) < 0.001, "剩 3 秒")
	assert_true(b.can_be_revived(), "5 秒內可以拉起")
	b.tick(3.5, 1.0, null, 99.0)
	assert_false(b.can_be_revived(), "超過 8 秒")
	assert_eq(b.revive_time_left(), 0.0)
	b.set_down(false)
	assert_false(b.can_be_revived(), "沒倒下就不用拉")


func _world() -> Array:
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(60, 1, 60)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	var sheila := Sheila.new()
	sheila.position = Vector3(1.0, 0, 0)
	root.add_child(sheila)
	return [root, player, sheila]


func test_pull_sheila_up_and_after_combat() -> void:
	var w: Array = _world()
	var root: Node3D = w[0]
	var player: PlayerController = w[1]
	var sheila: Sheila = w[2]
	var walker := Ashwalker.new()
	walker.position = Vector3(0, 0, -12)
	root.add_child(walker)
	await tree.physics_frame
	sheila.health.apply_damage(999.0)
	assert_eq(sheila.brain.mode, CompanionBrain.Mode.DOWN, "倒下")
	assert_eq(sheila.order("evade").get("line"), "SHEILA_REFUSE_DOWN", "倒下時拒絕指令")
	await tree.physics_frame
	await tree.physics_frame
	assert_true(sheila.revive_prompt_shown(), "諾恩在旁邊：顯示拉起提示")
	assert_true(sheila.line_text().contains("拉起席菈"), sheila.line_text())
	assert_true(sheila.revive(), "拉起")
	assert_eq(sheila.brain.mode, CompanionBrain.Mode.FOLLOW)
	assert_true(absf(sheila.health.hp - 160.0 * 0.4) < 0.01, "生命回到 40%%（%.1f）" % sheila.health.hp)
	assert_false(sheila.revive(), "沒倒下不能再拉")
	# 再倒一次，這次超過 8 秒：戰鬥中不會自己起來，敵人倒下後才起來
	sheila.health.apply_damage(999.0)
	sheila.brain.down_elapsed = 9.0
	player.global_position = Vector3(8, 0, 8)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(sheila.brain.mode, CompanionBrain.Mode.DOWN, "戰鬥中：等")
	assert_false(sheila.revive_prompt_shown(), "超過時間沒有拉起提示")
	walker.health.apply_damage(999.0)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(sheila.brain.mode, CompanionBrain.Mode.FOLLOW, "戰鬥結束自己起來")
	assert_true(absf(sheila.health.hp - 160.0 * 0.25) < 0.01, "生命 25%%（%.1f）" % sheila.health.hp)
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


func test_combat_hud_values() -> void:
	var w: Array = _world()
	var root: Node3D = w[0]
	var player: PlayerController = w[1]
	var sheila: Sheila = w[2]
	var layer := CanvasLayer.new()
	root.add_child(layer)
	App.last_device = InputGlyphs.Device.KBM
	var hud := CombatHud.new()
	layer.add_child(hud)
	await tree.physics_frame
	hud.refresh(player, sheila)
	assert_false(hud.is_shown(), "沒有敵人：不顯示")
	var walker := Ashwalker.new()
	walker.position = Vector3(0, 0, -12)
	root.add_child(walker)
	await tree.physics_frame
	player.health.apply_damage(25.0)
	sheila.brain.stamina = 50.0
	sheila.order("guard")
	hud.refresh(player, sheila)
	assert_true(hud.is_shown(), "20 公尺內有敵人：顯示")
	assert_true(absf(hud.noen_ratio - 0.75) < 0.001, "諾恩生命 75%%")
	assert_true(absf(hud.stamina_ratio - 0.5) < 0.05, "席菈體力約 50%%（%.2f）" % hud.stamina_ratio)
	assert_true(float(hud.cooldowns["guard"]) > 0.9, "守住剛下：冷卻中")
	assert_eq(float(hud.cooldowns["evade"]), 0.0, "閃開可用")
	assert_true(hud.command_label(0).contains("打弱點"), hud.command_label(0))
	assert_true(hud.command_label(0).begins_with("[Q]"), hud.command_label(0))
	sheila.health.apply_damage(999.0)
	hud.refresh(player, sheila)
	assert_true(hud.sheila_down)
	assert_true(hud._sheila_name.text.contains("秒內拉起"), hud._sheila_name.text)
	walker.health.apply_damage(999.0)
	await tree.physics_frame
	hud.refresh(player, sheila)
	assert_false(hud.is_shown(), "敵人倒下：戰鬥結束")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame
