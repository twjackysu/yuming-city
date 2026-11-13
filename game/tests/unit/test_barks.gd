extends TestCase
## 別人躲的東西他走進去（D-246，docs/design/11-combat-first.md 第 0 節）：
## 諾恩的碎念與旁人的反應（角色頭上跳一句、輪流講）、釋放的姿勢（疊在站姿上，不佔出手）、丟毒瓶的愣住（往後退、不丟）。


func after_each() -> void:
	CombatTuning.set_profile("")
	CombatTuning.load_tuning()


func _world() -> Node3D:
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(20, 1, 20)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	return root


func _guard(root: Node3D, kind: String, at: Vector3) -> DemoGuard:
	var g := DemoGuard.new()
	g.kind = kind
	g.difficulty = "standard"
	g.position = at
	root.add_child(g)
	return g


func _heart(root: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	var h := Health.new(100.0)
	h.name = "Health"
	n.add_child(h)
	root.add_child(n)
	n.add_to_group("heartbeat")
	return n


func test_lines_take_turns_and_every_line_is_translated_in_both_languages() -> void:
	var b := BarkLines.new()
	var seen: Array[String] = []
	for i: int in 4:
		var key: String = b.next(BarkLines.NOEN_ENTER)
		assert_false(seen.has(key), "一圈裡面不重複（%s）" % key)
		seen.append(key)
	assert_eq(b.next(BarkLines.NOEN_ENTER), seen[0], "輪完一圈回到第一句")
	assert_eq(b.next(BarkLines.NOEN_RELEASE), "BARK_NOEN_RELEASE_1", "每種情境各輪各的")
	assert_eq(b.next("nothing"), "", "沒有這個情境＝不講")
	for situation: String in [BarkLines.NOEN_ENTER, BarkLines.NOEN_RELEASE]:
		var n: int = (BarkLines.LINES[situation] as Array).size()
		assert_true(n >= 3 and n <= 5, "諾恩的碎念每種情境 3～5 句（%s：%d）" % [situation, n])
	assert_eq(BarkLines.all_keys().size(), 16)
	for locale: String in ["zh_TW", "en"]:
		var t: Translation = TranslationServer.get_translation_object(locale)
		assert_not_null(t, "有 %s 的翻譯" % locale)
		for key: String in BarkLines.all_keys():
			assert_true(t != null and str(t.get_message(key)) != "", "%s 有 %s 的字" % [key, locale])


func test_release_pose_is_laid_over_the_stance_and_does_not_take_the_action() -> void:
	var p := Puppet.new()
	tree.root.add_child(p)
	p.set_process(false)
	p.advance(0.016)
	var rest_z: float = p.joint("shoulder_R").rotation.z
	var rest_hip: float = p.joint("hips").position.y
	assert_false(p.is_releasing())
	p.play_release()
	assert_true(p.is_releasing())
	assert_eq(p.action, "", "不是 action：放完同一幀照樣能出手")
	assert_eq(p.current_state(), "idle")
	var t: float = Puppet.RELEASE_POSE_TIME
	p.advance(t * 0.2)
	p.advance(t * 0.25)
	assert_true(p.joint("hips").position.y < rest_hip - 0.1, "先縮：身體往下沉（%.2f → %.2f）" % [rest_hip, p.joint("hips").position.y])
	assert_true(p.joint("elbow_R").rotation.x > 1.0 and p.joint("spine").rotation.x < -0.2, "兩手抱到胸前、上身往前捲")
	p.advance(t * 0.1)
	assert_true(p.joint("shoulder_R").rotation.z > 1.0 and p.joint("shoulder_L").rotation.z < -1.0,
		"再炸開：兩手往兩邊甩到快水平（右 %.2f、左 %.2f）" % [p.joint("shoulder_R").rotation.z, p.joint("shoulder_L").rotation.z])
	assert_true(p.joint("spine").rotation.x > 0.0, "胸口往後挺")
	p.play_action("attack")
	assert_eq(p.current_state(), "attack", "姿勢還沒收完就能出手")
	p.advance(t)
	assert_false(p.is_releasing(), "%.2f 秒就放完" % t)
	p.action = ""
	p.advance(0.016)
	assert_true(absf(p.joint("shoulder_R").rotation.z - rest_z) < 0.05, "放完回到站姿")
	# 滾到一半不擺這個姿勢（整個人在轉，看不出來）
	p.play_action("dodge")
	p.play_release()
	p.advance(t * 0.2)
	p.advance(t * 0.5)
	assert_true(p.joint("shoulder_R").rotation.z < 0.5, "閃避中不甩手")
	p.queue_free()
	await tree.process_frame


func test_thrower_gawks_drops_the_bottle_he_was_raising_and_backs_off_but_not_twice_in_a_row() -> void:
	var root: Node3D = _world()
	_heart(root, Vector3(0, 0.05, -6.0))
	var g: DemoGuard = _guard(root, DemoGuard.KIND_THROWER, Vector3(0, 0.05, 0))
	await tree.process_frame
	var waited: int = 0
	while g.brain.state != EnemyBrain.State.TELEGRAPH and waited < 300:
		await tree.physics_frame
		waited += 1
	assert_eq(g.brain.state, EnemyBrain.State.TELEGRAPH, "他正在舉瓶子")
	var z0: float = g.global_position.z
	assert_true(g.can_gawk())
	assert_true(g.gawk(), "愣住")
	assert_true(g.is_gawking())
	assert_eq(g.gawk_count, 1)
	assert_eq(g.brain.state, EnemyBrain.State.CHASE, "舉到一半的那一瓶放下來")
	assert_false(g.gawk(), "愣著的時候不會再愣一次")
	for i: int in 40:
		await tree.physics_frame
	assert_true(g.is_gawking(), "40 幀之後還愣著（gawk_sec %.1f）" % CombatTuning.num("demo_thrower.gawk_sec", 0.0))
	assert_true(g.global_position.z > z0 + 0.6, "往後退了一小段（%.2f m）" % (g.global_position.z - z0))
	assert_true(g.puppet().joint("shoulder_R").rotation.x > 0.8 and g.puppet().joint("shoulder_L").rotation.x > 0.8,
		"兩手舉起來（右 %.2f）" % g.puppet().joint("shoulder_R").rotation.x)
	waited = 0
	while g.is_gawking() and waited < 300:
		await tree.physics_frame
		waited += 1
	assert_false(g.is_gawking(), "愣完了")
	assert_eq(g.toss_count, 0, "愣住的時候沒有丟")
	assert_true(g.global_position.z < z0 + 1.6, "只退一小段，不是一直退（%.2f m）" % (g.global_position.z - z0))
	assert_false(g.gawk(), "剛愣過：gawk_cooldown 秒內不會再愣")
	waited = 0
	while g.toss_count < 1 and waited < 300:
		await tree.physics_frame
		waited += 1
	assert_eq(g.toss_count, 1, "回神之後照樣丟")
	var club: DemoGuard = _guard(root, DemoGuard.KIND_CLUB, Vector3(5, 0.05, 0))
	await tree.process_frame
	assert_false(club.gawk(), "拿棍子的不會愣")
	# 直接改記憶體裡的那一份（after_each 會重新讀檔）
	(CombatTuning.value("demo_thrower", {}) as Dictionary)["gawk_sec"] = 0.0
	var other: DemoGuard = _guard(root, DemoGuard.KIND_THROWER, Vector3(-5, 0.05, 0))
	await tree.process_frame
	assert_false(other.gawk(), "gawk_sec 是 0＝沒有這件事")
	root.queue_free()
	await tree.process_frame


## 愣住的那一刻手一滑（D-247）：瓶子掉在自己腳邊變成一團霧、他被自己的毒嗆到扣血——但不會被自己毒死。
func test_gawking_thrower_fumbles_his_bottle_and_chokes_on_his_own_poison_without_dying() -> void:
	var root: Node3D = _world()
	_heart(root, Vector3(0, 0.05, -6.0))
	var g: DemoGuard = _guard(root, DemoGuard.KIND_THROWER, Vector3(0, 0.05, 0))
	await tree.process_frame
	var hp0: float = g.health.hp
	var want: float = CombatTuning.num("demo_thrower.fumble_damage", 0.0)
	assert_true(want > 0.0 and want < hp0, "嗆到扣的血比他的生命少（%.0f／%.0f）" % [want, hp0])
	var at: Vector3 = g.global_position
	assert_true(g.gawk(), "愣住")
	assert_true(g.is_fumbling(), "手一滑")
	assert_eq(g.fumble_count, 1)
	assert_true(root.get_node_or_null("FumbledBottle1") != null, "瓶子在往下掉")
	for i: int in 24:
		await tree.physics_frame
	assert_not_null(g.last_fumble_mist, "落地變成一團霧")
	assert_true(g.last_fumble_mist.is_in_group("poison_mist"), "跟丟出去的是同一種霧（諾恩站得進去）")
	assert_true(g.last_fumble_mist.global_position.distance_to(at) < 1.0, "就在他原本站的地方")
	assert_true(g.last_fumble_mist.contains(at), "他原本站的地方在霧裡")
	assert_eq(g.toss_count, 0, "這一瓶不算丟出去的")
	assert_true(g.last_mist == null, "也不是瞄著諾恩的那一團")
	var waited: int = 0
	while g.is_gawking() and waited < 300:
		await tree.physics_frame
		waited += 1
	assert_false(g.is_fumbling(), "愣完就不嗆了")
	assert_true(absf((hp0 - g.health.hp) - want) < 0.01, "愣著的時候總共扣 fumble_damage（扣了 %.1f）" % (hp0 - g.health.hp))
	assert_true(absf(g.fumble_dealt - want) < 0.01, "fumble_dealt 記的是同一個數字")
	assert_eq(g.flinch_count, 0, "被自己嗆到不會後仰")
	# 只剩一點血的時候再來一次：扣到剩 1，不會倒
	var weak: DemoGuard = _guard(root, DemoGuard.KIND_THROWER, Vector3(6, 0.05, 0))
	await tree.process_frame
	weak.health.hp = 5.0
	assert_true(weak.gawk())
	waited = 0
	while weak.is_gawking() and waited < 300:
		await tree.physics_frame
		waited += 1
	assert_false(weak.health.is_dead(), "不會被自己毒死")
	assert_true(absf(weak.health.hp - 1.0) < 0.01, "扣到剩 1（剩 %.2f）" % weak.health.hp)
	# fumble_damage 是 0＝只愣住，瓶子不掉
	(CombatTuning.value("demo_thrower", {}) as Dictionary)["fumble_damage"] = 0.0
	var calm: DemoGuard = _guard(root, DemoGuard.KIND_THROWER, Vector3(-6, 0.05, 0))
	await tree.process_frame
	var calm_hp: float = calm.health.hp
	assert_true(calm.gawk())
	assert_false(calm.is_fumbling())
	for i: int in 40:
		await tree.physics_frame
	assert_true(calm.last_fumble_mist == null, "沒有霧")
	assert_eq(calm.health.hp, calm_hp, "沒有扣血")
	root.queue_free()
	await tree.process_frame


func test_break_off_only_cancels_a_windup_or_a_chase() -> void:
	var brain := EnemyBrain.new().configure("demo_thrower", "standard")
	brain.state = EnemyBrain.State.TELEGRAPH
	assert_true(brain.break_off(), "前兆取消了")
	assert_eq(brain.state, EnemyBrain.State.CHASE)
	assert_false(brain.break_off(), "追人中：沒有前兆可以取消")
	for s: EnemyBrain.State in [EnemyBrain.State.STRIKE, EnemyBrain.State.RECOVER, EnemyBrain.State.STAGGERED, EnemyBrain.State.DEAD]:
		brain.state = s
		assert_false(brain.break_off())
		assert_eq(brain.state, s, "出招、破綻、跪地、倒下不動")


func test_hud_bark_is_one_line_per_speaker_at_most_three_and_goes_away() -> void:
	var hud: Hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as Hud
	tree.root.add_child(hud)
	await tree.process_frame
	var who: Array[Node3D] = []
	for i: int in 4:
		var n := Node3D.new()
		tree.root.add_child(n)
		who.append(n)
	assert_eq(hud.bark_keys().size(), 0)
	hud.show_bark(who[0], "BARK_NOEN_ENTER_1", 5.0)
	hud.show_bark(who[0], "BARK_NOEN_ENTER_2", 5.0)
	assert_eq(Array(hud.bark_keys()), ["BARK_NOEN_ENTER_2"], "同一個人的上一句直接換掉")
	hud.show_bark(null, "BARK_NOEN_ENTER_3")
	hud.show_bark(who[1], "")
	assert_eq(hud.bark_keys().size(), 1, "沒有人講、沒有字＝不出現")
	hud.show_bark(who[1], "BARK_THROWER_GAWK_1", 5.0)
	hud.show_bark(who[2], "BARK_SHEILA_WATCH_1", 5.0)
	hud.show_bark(who[3], "BARK_NOEN_RELEASE_1", 0.3)
	assert_eq(hud.bark_keys().size(), Hud.BARK_MAX, "同時最多三句")
	assert_false(hud.bark_keys().has("BARK_NOEN_ENTER_2"), "最舊的先拿掉")
	who[1].free()
	var waited: int = 0
	while hud.bark_keys().size() > 1 and waited < 600:
		await tree.process_frame
		waited += 1
	assert_eq(Array(hud.bark_keys()), ["BARK_SHEILA_WATCH_1"], "講的人不在了、時間到了的都收掉")
	# 兩個人站在同一個地方講話：字不疊在一起；講話的人在鏡頭後面：不顯示
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.position = Vector3(0, 1.5, 6)
	cam.make_current()
	hud.show_bark(who[0], "BARK_NOEN_ENTER_1", 5.0)
	hud.show_bark(who[3], "BARK_THROWER_GAWK_2", 5.0)
	await tree.process_frame
	var rects: Array[Rect2] = hud.bark_rects()
	assert_eq(rects.size(), 3, "三句都看得到")
	for a: int in rects.size():
		for b: int in range(a + 1, rects.size()):
			assert_false(rects[a].intersects(rects[b]), "字不疊在一起（%s／%s）" % [rects[a], rects[b]])
	who[3].position = Vector3(0, 0, 30)
	await tree.process_frame
	assert_eq(hud.bark_rects().size(), 2, "在鏡頭後面的人講的話不顯示")
	assert_eq(hud.bark_keys().size(), 3, "但還算在講")
	cam.queue_free()
	for n: Node3D in who:
		if is_instance_valid(n):
			n.queue_free()
	hud.queue_free()
	await tree.process_frame
