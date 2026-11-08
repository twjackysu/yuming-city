extends TestCase
## 席菈：指令時機窗（依難度）、冷卻、拒絕（附理由）、打弱點／閃開反擊、自主斬擊、場景內執行。

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	Engine.time_scale = 1.0


## 讓敵人進入前兆，進度到 p（0..1）
func _telegraphing(p: float) -> EnemyBrain:
	var e := EnemyBrain.new().configure("ashwalker")
	e.tick(0.1, 10.0)
	e.tick(0.1, 1.0)
	e.tick(e.telegraph_sec * p, 1.0)
	return e


func _recovering() -> EnemyBrain:
	var e := _telegraphing(0.5)
	e.tick(e.telegraph_sec, 1.0)
	e.tick(0.2, 1.0)
	return e


func test_evade_window_by_difficulty() -> void:
	var std := CompanionBrain.new().configure("standard")
	assert_false(std.evade_in_window(_telegraphing(0.3)), "標準：前兆前 40% 太早")
	assert_true(std.evade_in_window(_telegraphing(0.5)), "標準：後 60% 內")
	assert_false(std.evade_in_window(EnemyBrain.new()), "沒在前兆")
	var story := CompanionBrain.new().configure("story")
	assert_true(story.evade_in_window(_telegraphing(0.05)), "故事難度：整段前兆都算")
	var hard := CompanionBrain.new().configure("hard")
	assert_false(hard.evade_in_window(_telegraphing(0.5)), "困難：只有後 35%")
	assert_true(hard.evade_in_window(_telegraphing(0.7)))


func test_evade_success_then_counter() -> void:
	var c := CompanionBrain.new().configure()
	var e := _telegraphing(0.6)
	var r: Dictionary = c.command("evade", e)
	assert_eq(r, {"accepted": true, "outcome": "success", "line": "SHEILA_ACK_EVADE"})
	assert_true(c.is_invulnerable(), "閃開成功有短無敵")
	assert_eq(c.stamina, 80.0, "閃避耗體力 20")
	var acts: PackedStringArray = c.tick(0.01, 1.0, e, 1.2)
	assert_true(acts.has(CompanionBrain.ACT_DODGE))
	assert_false(acts.has(CompanionBrain.ACT_SLASH), "前兆中不硬拚")
	e.tick(1.0, 1.0)
	e.tick(0.2, 1.0)
	assert_eq(e.state_name(), "recover")
	assert_true(c.tick(0.01, 1.0, e, 1.2).has(CompanionBrain.ACT_COUNTER), "敵人出完招就反擊")


func test_evade_mistimed() -> void:
	var c := CompanionBrain.new().configure()
	var r: Dictionary = c.command("evade", _telegraphing(0.1))
	assert_eq(r["outcome"], "mistimed")
	assert_eq(r["line"], "SHEILA_MISTIMED_EVADE")
	assert_false(c.is_invulnerable(), "太早閃沒有無敵")


func test_weakpoint_on_opening_and_mistimed() -> void:
	var c := CompanionBrain.new().configure()
	var r: Dictionary = c.command("weakpoint", _recovering())
	assert_eq(r["outcome"], "success", "破綻中打弱點")
	assert_true(c.tick(0.01, 1.0, _recovering(), 1.0).has(CompanionBrain.ACT_WEAK_STRIKE))
	var c2 := CompanionBrain.new().configure()
	var r2: Dictionary = c2.command("weakpoint", _telegraphing(0.2))
	assert_eq(r2["outcome"], "mistimed", "前兆中硬打弱點")
	assert_true(c2.tick(0.01, 1.0, null, 999.0).has(CompanionBrain.ACT_COUNTERED), "會被反擊")


func test_cooldown_and_refusals() -> void:
	var c := CompanionBrain.new().configure()
	var e := _recovering()
	assert_true(bool(c.command("weakpoint", e)["accepted"]))
	var again: Dictionary = c.command("weakpoint", e)
	assert_false(bool(again["accepted"]), "同一指令 1.5 秒冷卻")
	assert_eq(again["line"], "SHEILA_BUSY")
	assert_true(bool(c.command("guard", e)["accepted"]), "不同指令不受影響")
	c.tick(1.51, 1.0, e, 1.0)
	assert_eq(c.cooldown_left("weakpoint"), 0.0)
	var none: Dictionary = c.command("evade", null)
	assert_eq(none, {"accepted": false, "outcome": "", "line": "SHEILA_REFUSE_NO_TARGET"})
	assert_eq(c.cooldown_left("evade"), 0.0, "被拒絕的指令不進冷卻")
	c.stamina = 5.0
	assert_eq(c.command("evade", _telegraphing(0.6))["line"], "SHEILA_REFUSE_STAMINA", "體力不夠會說要喘口氣")
	c.set_down(true)
	assert_eq(c.command("guard", e)["line"], "SHEILA_REFUSE_DOWN")
	assert_eq(c.command("dance", e)["line"], "SHEILA_REFUSE_UNKNOWN")


func test_refuses_to_dodge_beside_the_wounded() -> void:
	var c := CompanionBrain.new().configure()
	c.near_wounded = true
	var r: Dictionary = c.command("evade", _telegraphing(0.6))
	assert_false(bool(r["accepted"]), "傷者在旁邊不閃")
	assert_eq(r["line"], "SHEILA_REFUSE_WOUNDED", "說理由")
	assert_eq(c.cooldown_left("evade"), 0.0, "被拒絕的不進冷卻")
	assert_true(bool(c.command("guard", _telegraphing(0.6))["accepted"]), "守住可以")
	c.near_wounded = false
	assert_true(bool(c.command("evade", _telegraphing(0.6))["accepted"]), "離開車隊就照做")


func test_guard_toggle_and_moves() -> void:
	var c := CompanionBrain.new().configure()
	assert_eq(c.command("guard", null)["line"], "SHEILA_ACK_GUARD")
	c.tick(0.01, 5.0, null, 999.0)
	assert_eq(c.mode_name(), "guard")
	assert_eq(c.desired_move(5.0, 999.0), CompanionBrain.Move.TO_GUARD)
	c.tick(1.6, 5.0, null, 999.0)
	assert_eq(c.command("guard", null)["line"], "SHEILA_ACK_UNGUARD", "再按一次解除")
	c.tick(0.01, 5.0, null, 999.0)
	assert_eq(c.mode_name(), "follow")
	assert_eq(c.desired_move(5.0, 999.0), CompanionBrain.Move.TO_LEADER, "離諾恩太遠就跟上")
	assert_eq(c.desired_move(1.0, 999.0), CompanionBrain.Move.STAY)


## 劇情暫時守住（D-054）：時間到恢復原狀；守的途中玩家下「守住」照常切換；倒下時不接。
func test_hold_guard_expires_and_player_can_override() -> void:
	var c := CompanionBrain.new().configure()
	c.hold_guard(5.0)
	c.tick(0.01, 5.0, null, 999.0)
	assert_eq(c.mode_name(), "guard", "暫時守住")
	assert_eq(c.desired_move(5.0, 999.0), CompanionBrain.Move.TO_GUARD)
	assert_eq(c.cooldown_left("guard"), 0.0, "不經過指令冷卻")
	c.tick(4.0, 5.0, null, 999.0)
	assert_eq(c.mode_name(), "guard", "4 秒時還守著")
	c.tick(1.1, 5.0, null, 999.0)
	c.tick(0.01, 5.0, null, 999.0)
	assert_eq(c.mode_name(), "follow", "5 秒後回到跟隨")
	assert_false(c.guard_active)
	# 本來就在守：暫時守住結束後仍然守著
	var g := CompanionBrain.new().configure()
	g.command("guard", null)
	g.hold_guard(2.0)
	g.tick(2.5, 5.0, null, 999.0)
	assert_true(g.guard_active, "原本就在守，時間到仍然守著")
	# 守的途中玩家按「守住」：照常切換（解除），不會時間到又被打開
	var h := CompanionBrain.new().configure()
	h.hold_guard(5.0)
	h.tick(0.5, 5.0, null, 999.0)
	assert_eq(h.command("guard", null)["line"], "SHEILA_ACK_UNGUARD", "玩家解除暫時守住")
	assert_eq(h.guard_hold_left, 0.0)
	h.tick(6.0, 5.0, null, 999.0)
	assert_false(h.guard_active, "不會被暫時狀態恢復成守住")
	# 倒下時不接
	var d := CompanionBrain.new().configure()
	d.set_down(true)
	d.hold_guard(5.0)
	assert_false(d.guard_active, "倒下時不接暫時守住")


func test_autonomous_slash_respects_telegraph() -> void:
	var c := CompanionBrain.new().configure()
	var idle_enemy := EnemyBrain.new().configure("ashwalker")
	idle_enemy.tick(0.1, 10.0)
	assert_true(c.tick(0.01, 1.0, idle_enemy, 1.0).has(CompanionBrain.ACT_SLASH), "近身自主斬擊")
	assert_eq(c.stamina, 90.0, "斬擊耗體力 10")
	assert_false(c.tick(0.5, 1.0, idle_enemy, 1.0).has(CompanionBrain.ACT_SLASH), "斬擊間隔")
	var c2 := CompanionBrain.new().configure()
	assert_false(c2.tick(0.01, 1.0, _telegraphing(0.5), 1.0).has(CompanionBrain.ACT_SLASH), "敵人前兆中不出手")
	assert_eq(c2.mode_name(), "engage")


func _arena() -> Array:
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(30, 1, 30)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	var sheila := Sheila.new()
	root.add_child(sheila)
	return [root, player, sheila]


func test_sheila_follows_player() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var sheila: Sheila = a[2]
	sheila.global_position = player.global_position + Vector3(8, 0, 0)
	for i: int in 90:
		await tree.physics_frame
	var d: float = Vector2(sheila.global_position.x - player.global_position.x, sheila.global_position.z - player.global_position.z).length()
	assert_true(d < 4.0, "席菈跟上諾恩（距離 %.2f）" % d)
	assert_eq(sheila.brain.mode_name(), "follow")
	assert_eq(sheila.health.hp, 160.0, "生命 160")
	root.queue_free()
	await tree.process_frame


func test_sheila_weakpoint_kills_staggered_ashwalker_and_says_line() -> void:
	TranslationServer.set_locale("zh_TW")
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var sheila: Sheila = a[2]
	var walker := Ashwalker.new()
	root.add_child(walker)
	walker.global_position = player.global_position + Vector3(0, 0, -1.5)
	sheila.global_position = player.global_position + Vector3(2.0, 0, -1.0)
	await tree.physics_frame
	# 前兆中硬打弱點：席菈被反擊
	walker.brain.tick(0.1, 10.0)
	walker.brain.tick(0.1, 1.0)
	assert_eq(walker.brain.state_name(), "telegraph")
	var r: Dictionary = sheila.order("weakpoint")
	assert_eq(r["outcome"], "mistimed")
	assert_eq(sheila.line_text(), "太早了——！", "頭上顯示回話")
	await tree.physics_frame
	assert_eq(sheila.health.hp, 160.0 - 14.0, "被反擊 14")
	# 諾恩把牠打到跪地，再叫席菈打弱點：60 傷害，灰巡者倒下
	walker.brain.add_stagger(999.0)
	assert_eq(walker.brain.state_name(), "staggered")
	sheila.brain.tick(1.6, 1.0, walker.brain, 1.0)
	var r2: Dictionary = sheila.order("weakpoint")
	assert_eq(r2["outcome"], "success")
	assert_eq(sheila.line_text(), "膝蓋——交給我。")
	await tree.physics_frame
	assert_true(walker.health.is_dead(), "打弱點 60 直接倒下")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


## 字幕設定（D-045）：關掉時席菈頭上的喊話不顯示（台詞照樣記著，打開就看得到）。
func test_sheila_barks_follow_subtitle_setting() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var sheila: Sheila = a[2]
	var was: bool = Settings.subtitles_enabled
	Settings.subtitles_enabled = false
	sheila.say("SHEILA_ACK_GUARD")
	var line: Label3D = sheila.get_node("Line") as Label3D
	assert_false(line.visible, "字幕關：頭上不顯示")
	assert_ne(sheila.line_text(), "", "台詞還是有")
	await tree.physics_frame
	assert_false(line.visible, "下一幀也不顯示")
	Settings.subtitles_enabled = true
	await tree.physics_frame
	assert_true(line.visible, "字幕開：顯示")
	Settings.subtitles_enabled = was
	root.queue_free()
	await tree.process_frame
	await tree.process_frame
