extends TestCase
## 新版前十分鐘的南街守衛戰（D-207）：席菈接應之後，送葬者從南街南端走過來（走過來那一段不出招、打不動）→
## 走近就開打：單階段（沒有衝撞、不進第二階段）、多一招「噴毒」（胸口的管子發綠光＋嘶聲的前兆 → 前方地上留一團 3 秒的毒霧）。
## 諾恩站在毒霧裡回血（不疊加：強度 8、最多 3 秒）、噴毒本身沒有直接傷害；席菈繞開毒霧。
## 牠倒下 → rb.guardian_down → 席菈問名字 → 下一階段（試用毒劑）。死亡重試回到戰前：牠滿血從頭走、諾恩生命不補滿。

const PATH: String = "res://scenes/levels/frostbridge.tscn"

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_rb_guard_%d" % Time.get_ticks_usec()
	_original = tree.root.get_node("Game").get("session") as GameSession


func after_each() -> void:
	tree.root.get_node("Game").set("session", _original)
	for d: String in [_dir, _dir + "_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)


## 新版新遊戲，照正式流程的旗標推到守衛戰（席菈已經接應）
func _session_at_guardian() -> GameSession:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	s.new_reboot_game()
	RebootOpening.dev_advance(s, "guardian")
	return s


func _load() -> StoryLevel:
	var level: StoryLevel = (load(PATH) as PackedScene).instantiate() as StoryLevel
	tree.root.add_child(level)
	await tree.physics_frame
	return level


func _game() -> Node:
	return tree.root.get_node("Game")


func _run_dialogue(level: Node, choice: int = 0) -> void:
	var box: DialogueBox = level.get_node("DialogueBox") as DialogueBox
	var choices: Node = box.find_child("Choices", true, false)
	for i: int in 60:
		if not bool(_game().call("is_in_dialogue")):
			break
		if choices.get_child_count() > 0:
			(choices.get_child(choice) as Button).pressed.emit()
		else:
			box.press_continue()
		await tree.process_frame


func _frames(n: int) -> void:
	for i: int in n:
		await tree.physics_frame


func _park_sheila(level: Node) -> void:
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	if sheila != null:
		sheila.set_physics_process(false)
		sheila.global_position = Vector3(-3.0, 0.05, 6.0)


func test_guardian_walks_in_then_fights() -> void:
	var s := _session_at_guardian()
	assert_eq(s.quests.stage_of("rb_main"), "guardian_fight")
	assert_eq(s.state.checkpoint, "rb_guardian", "戰前的檢查點")
	assert_eq(s.objective_key(), "Q_RB_OBJ_GUARDIAN")
	var level: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level)
	var rb: RebootOpening = level.get_node("RebootOpening") as RebootOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var g: Undertaker = level.get_node_or_null("RbGuardian") as Undertaker
	assert_not_null(g, "南街的守衛（節點名＝任務標記 node:RbGuardian）")
	assert_false(level.has_node("RbPursuer"), "北街那隻已經離場（同一隻繞過來）")
	if g == null:
		level.queue_free()
		await tree.process_frame
		return
	assert_true(g.guardian_mode and g.struggle_mode, "單階段：不會進第二階段")
	assert_eq(g.health.max_hp, CombatTuning.num("undertaker.guardian_hp", -1.0), "守衛的生命（比切片的送葬者少）")
	assert_eq(g.health.hp, g.health.max_hp)
	assert_true(g.brain.pattern.has("spray") and g.brain.pattern.has("sweep") and g.brain.pattern.has("slam"), "橫掃、下砸、噴毒")
	assert_false(g.brain.pattern.has("charge"), "沒有衝撞（南街窄）")
	assert_not_null(g.get_node_or_null("Body/Torso/SprayPipes"), "胸口的排氣管")
	assert_true(g.global_position.z > 24.0, "從南街南端出現")
	# 走過來那一段：不出招、打不動、用自己的腳走
	assert_true(g.is_scripted() and not rb.guardian_engaged, "還沒開打")
	assert_false(g.health.apply_damage(50.0), "走過來的時候打不動")
	var z0: float = g.global_position.z
	await _frames(60)
	assert_true(g.global_position.z < z0 - 1.0 and g.global_position.z > z0 - 3.0, "往北走（每秒約 2 m）：%.2f → %.2f" % [z0, g.global_position.z])
	assert_eq(g.brain.state, EnemyBrain.State.IDLE, "狀態機還沒跑")
	# 走近 → 開打、一行提示
	player.global_position = g.global_position + Vector3(0.0, 0.05, -7.0)
	await _frames(3)
	assert_true(rb.guardian_engaged and not g.is_scripted(), "走近就開打")
	assert_eq((level.get_node("Hud") as Hud).banner_text(), "RB_GUARDIAN_START", "把規則講白的一行字")
	assert_true(g.health.apply_damage(10.0, {"kind": "blunt", "stagger": 0.0}), "開打之後打得動")
	await _frames(20)
	assert_true(g.brain.state != EnemyBrain.State.IDLE, "狀態機在跑")
	assert_eq(g.phase, 1)
	g.health.apply_damage(g.health.hp - 50.0, {"kind": "blunt", "stagger": 0.0})
	assert_eq(g.phase, 1, "打到殘血也不會進第二階段")
	level.queue_free()
	await tree.process_frame


func test_spray_telegraph_leaves_mist_that_heals_noen_and_expires() -> void:
	_session_at_guardian()
	var level: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level)
	var rb: RebootOpening = level.get_node("RebootOpening") as RebootOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var g: Undertaker = level.get_node("RbGuardian") as Undertaker
	# 牠站在街心面向北，諾恩站在牠正前方 2.6 m（噴毒落點）
	g.global_position = Vector3(0.2, 0.05, 17.0)
	rb._engage_guardian()
	g.set_facing(0.0)
	player.global_position = g.global_position + Vector3(0.0, 0.0, -2.6)
	player.health.hp = 40.0
	await _frames(2)
	g.brain._set_move("spray")
	g.brain._enter(EnemyBrain.State.TELEGRAPH)
	assert_eq(g.pipe_glow() < 0.3, true, "前兆剛開始：管口還暗")
	var lowest: float = player.health.hp
	var peak_glow: float = 0.0
	for i: int in 90:
		await tree.physics_frame
		lowest = minf(lowest, player.health.hp)
		peak_glow = maxf(peak_glow, g.pipe_glow())
		if g.spray_count > 0:
			break
	assert_eq(g.spray_count, 1, "前兆（1.1 秒）之後噴出去")
	assert_true(peak_glow > 0.8, "前兆：胸口的管子越來越亮（%.2f）" % peak_glow)
	assert_true((g.get_node("Body/Torso/SprayPipes/PipeLight") as OmniLight3D).light_energy > 1.0, "綠光打在袍子與地上")
	assert_true(level.has_node("SprayJet"), "管口到地面的一道綠色噴霧")
	# 之後不讓牠接著出別的招（這個測試只看噴毒）
	g.set_physics_process(false)
	var m: PoisonMist = g.last_spray
	assert_not_null(m, "地上留一團毒霧")
	assert_eq(m.source_id, "guardian_spray")
	assert_true(m.contains(player.global_position), "落在牠正前方（諾恩站的地方）")
	assert_false(m.contains(g.global_position), "牠自己不在霧裡")
	await _frames(45)
	lowest = minf(lowest, player.health.hp)
	assert_eq(lowest, 40.0, "噴毒沒有直接傷害")
	assert_true(player.status_effects.has("poison") and player.reversal.is_reversed("poison"), "站在裡面：中毒 → 反轉")
	assert_true(player.health.hp > 42.0, "生命往上（40 → %.1f）" % player.health.hp)
	# 不疊加：再噴兩次，還是一份中毒、強度 8、最多 3 秒
	g._spray()
	g._spray()
	await _frames(20)
	assert_eq(player.status_effects.ids().size(), 1, "同一種狀態只有一份")
	assert_eq(player.status_effects.rate("poison"), 8.0, "強度不疊加")
	assert_true(player.status_effects.remaining("poison") <= 3.0, "時間不疊加（%.2f）" % player.status_effects.remaining("poison"))
	# 3 秒後散掉（每一團各自計時）
	await _frames(200)
	assert_false(is_instance_valid(m), "第一團 3 秒後散掉")
	assert_eq(tree.get_nodes_in_group("poison_mist").size(), 0, "地上沒有留下毒霧")
	level.queue_free()
	await tree.process_frame


func test_guardian_down_then_sheila_asks_name() -> void:
	var s := _session_at_guardian()
	var level: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level)
	var rb: RebootOpening = level.get_node("RebootOpening") as RebootOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var g: Undertaker = level.get_node("RbGuardian") as Undertaker
	rb.guardian_down_talk_sec = 0.2
	g.global_position = Vector3(0.2, 0.05, 17.0)
	player.global_position = Vector3(0.0, 0.05, 11.0)
	rb._engage_guardian()
	g.brain._set_move("spray")
	var mist: PoisonMist = g._spray()
	await _frames(2)
	g.health.apply_damage(g.health.hp, {"kind": "blunt", "stagger": 0.0})
	assert_eq(s.state.get_flag("rb.guardian_down"), true, "牠倒下")
	assert_eq(s.quests.stage_of("rb_main"), "guardian_fight", "還要等席菈開口")
	assert_true(mist.zone.life <= 0.6, "牠噴的毒霧跟著散掉")
	await _frames(30)
	assert_true(bool(_game().call("is_in_dialogue")), "席菈：「名字。」")
	await _run_dialogue(level)
	assert_eq(s.state.get_flag("rb.guardian_talked"), true)
	assert_eq(s.quests.stage_of("rb_main"), "portable_poison", "→ 試用毒劑")
	assert_eq(s.state.checkpoint, "rb_portable")
	await _frames(40)
	assert_false(bool(_game().call("is_in_dialogue")), "對話不會再播一次")
	level.queue_free()
	await tree.process_frame


func test_retry_returns_before_fight_with_full_guardian_and_same_hp() -> void:
	var s := _session_at_guardian()
	var level: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level)
	var rb: RebootOpening = level.get_node("RebootOpening") as RebootOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var g: Undertaker = level.get_node("RbGuardian") as Undertaker
	var saved_hp: float = float(s.state.vitals.get("hp", RebootOpening.OPENING_HP))
	rb._engage_guardian()
	g.health.apply_damage(200.0, {"kind": "blunt", "stagger": 0.0})
	player.health.hp = 12.0
	level.queue_free()
	await tree.process_frame
	_game().call("retry", false)
	assert_true(s.is_reboot())
	assert_eq(s.state.checkpoint, "rb_guardian", "回到戰前")
	assert_eq(s.state.get_flag("rb.guardian_down", false), false)
	var level2: StoryLevel = await _load()
	await tree.process_frame
	var p2: PlayerController = level2.get_node("Player") as PlayerController
	var g2: Undertaker = level2.get_node_or_null("RbGuardian") as Undertaker
	assert_not_null(g2, "重來：守衛還在")
	assert_eq(g2.health.hp, g2.health.max_hp, "牠滿血")
	assert_true(g2.is_scripted() and g2.global_position.z > 24.0, "從南街南端重新走過來")
	assert_true(p2.health.hp < p2.health.max_hp, "諾恩的生命不補滿（%.0f）" % p2.health.hp)
	assert_true(p2.health.hp >= maxf(saved_hp, p2.health.max_hp * PlayerController.RESTORE_MIN_HP_RATIO) - 0.01, "照存檔，至少一半")
	assert_true(p2.global_position.z < 12.0, "諾恩在南街口（離牠夠遠）")
	assert_true(level2.has_node("Sheila"), "席菈在身邊")
	level2.queue_free()
	await tree.process_frame


## 席菈沒有逆轉體質：不走進毒霧（CompanionBrain.steer_clear，純邏輯）
func test_sheila_steers_clear_of_mist() -> void:
	var centers := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var radii := PackedFloat32Array([2.0])
	# 離得遠：不改
	var far: Vector3 = CompanionBrain.steer_clear(Vector3(10.0, 0.0, 0.0), Vector3(-3.0, 0.0, 0.0), centers, radii)
	assert_eq(far, Vector3(-3.0, 0.0, 0.0), "離得遠照原樣走")
	# 斜著靠近邊緣：往裡走的分量拿掉，沿著邊滑過去，速度不變
	var slide: Vector3 = CompanionBrain.steer_clear(Vector3(2.8, 0.0, 0.0), Vector3(-2.0, 0.0, 2.0), centers, radii)
	assert_true(absf(slide.x) < 0.01 and slide.z > 0.0, "沿著霧的邊緣滑過去（%s）" % slide)
	assert_true(absf(slide.length() - Vector3(-2.0, 0.0, 2.0).length()) < 0.01, "速度不變")
	# 正對著霧心走：選一邊繞，不會停在原地、也不會走進去
	var head_on: Vector3 = CompanionBrain.steer_clear(Vector3(2.8, 0.0, 0.0), Vector3(-3.0, 0.0, 0.0), centers, radii)
	assert_true(absf(head_on.x) < 0.01 and absf(head_on.z) > 2.9, "正對著走：繞一邊（%s）" % head_on)
	# 已經在霧裡（站著不動也一樣）：往外走
	var out: Vector3 = CompanionBrain.steer_clear(Vector3(1.0, 0.0, 0.0), Vector3.ZERO, centers, radii)
	assert_true(out.x >= 3.0 and absf(out.z) < 0.01, "在霧裡：往最近的邊走出去（%s）" % out)
	# 往外走：不擋
	var leaving: Vector3 = CompanionBrain.steer_clear(Vector3(2.3, 0.0, 0.0), Vector3(3.0, 0.0, 0.0), centers, radii)
	assert_eq(leaving, Vector3(3.0, 0.0, 0.0), "往外走不擋")
	# 模擬走幾步：從霧的東邊走到西邊的目標，全程不踏進霧裡
	var pos := Vector3(4.0, 0.0, 0.3)
	var goal := Vector3(-4.0, 0.0, 0.0)
	var entered: bool = false
	for i: int in 400:
		var want: Vector3 = (goal - pos).normalized() * 3.6
		pos += CompanionBrain.steer_clear(pos, want, centers, radii) / 60.0
		if Vector2(pos.x, pos.z).length() < 2.0:
			entered = true
		if pos.distance_to(goal) < 0.4:
			break
	assert_false(entered, "繞過去的路上沒有踏進毒霧")
	assert_true(pos.distance_to(goal) < 0.5, "繞得到另一邊（%s）" % pos)
	assert_eq(CompanionBrain.steer_clear(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), PackedVector3Array(), PackedFloat32Array()), Vector3(1.0, 0.0, 0.0), "沒有毒霧：原樣")


## 噴毒只在近身的招式輪替裡出現：射程不比橫掃遠多少、輪替裡不連噴。
## （射程遠的話，諾恩站在中距離牠只會一直噴——白白回血、沒有任何風險。）
func test_spray_is_a_close_range_move_in_rotation() -> void:
	var b := EnemyBrain.new().configure("undertaker", "standard")
	var pat: Variant = CombatTuning.value("undertaker.pattern_guardian", [])
	b.set_pattern(PackedStringArray(pat as Array))
	assert_true(b.move_num("spray", "range") <= b.move_num("sweep", "range") + 0.5, "噴毒的射程跟橫掃差不多")
	assert_true(b.move_num("spray", "reach") > b.move_num("spray", "radius"), "毒霧落在牠前面，牠自己不在霧裡")
	assert_false(b._choose_move(4.5), "中距離不出招（走近再打），不會站在遠處一直噴")
	var sprays: int = 0
	var last: String = ""
	for i: int in 8:
		assert_true(b._choose_move(2.5), "近身照輪替出招")
		assert_false(b.move_id == "spray" and last == "spray", "不連噴兩次")
		sprays += 1 if b.move_id == "spray" else 0
		last = b.move_id
	assert_eq(sprays, 2, "四招裡一招是噴毒")
	assert_eq(b.move_num("spray", "damage", 0.0), 0.0, "噴毒沒有直接傷害")
