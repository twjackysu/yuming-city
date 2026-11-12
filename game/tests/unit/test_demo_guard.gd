extends TestCase
## 示範場的守衛（D-233）：拿棍子的（橫掃、直刺）與戴護腕的（快拳：前兆短，打完右手麻掉、破綻很長）。
## 沒有狀態攻擊；倒下之後躺在原地、不再算敵人。


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


## 站著不動、會受傷的心跳（代替諾恩：不用整個玩家場景）
func _heart(root: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	var h := Health.new(100.0)
	h.name = "Health"
	n.add_child(h)
	root.add_child(n)
	n.add_to_group("heartbeat")
	return n


func test_bracer_is_fast_but_stuck_after_every_punch() -> void:
	var club := EnemyBrain.new().configure("demo_guard", "standard")
	var bracer := EnemyBrain.new().configure("demo_bracer", "standard")
	assert_eq(club.pattern, PackedStringArray(["swing", "thrust"]), "拿棍子的兩招輪流")
	assert_eq(bracer.pattern, PackedStringArray(["jab"]), "戴護腕的只有快拳")
	var jab_tel: float = bracer.move_num("jab", "telegraph")
	assert_true(jab_tel < club.move_num("swing", "telegraph") * 0.5, "快拳的前兆不到橫掃的一半（%s）" % jab_tel)
	assert_true(jab_tel < club.move_num("thrust", "telegraph"), "也比直刺短")
	assert_true(bracer.move_num("jab", "recover") >= 1.5, "打完僵住至少 1.5 秒")
	assert_true(bracer.move_num("jab", "recover") > club.move_num("swing", "recover") * 1.5, "破綻比拿棍子的長很多")
	assert_true(bracer.recover_stagger_mult > club.recover_stagger_mult, "麻掉的時候更容易被打跪")
	# 沒有狀態攻擊：招式表裡沒有會下狀態的欄位
	for b: EnemyBrain in [club, bracer]:
		for id: String in b.moves:
			var m: Dictionary = b.moves[id] as Dictionary
			assert_false(m.has("status") or m.has("life") or m.has("radius"), "%s 沒有狀態／毒霧" % id)
			assert_true(float(m.get("damage", 0.0)) > 0.0, "%s 是直接傷害" % id)
	# 看穿小卡有名字與招式（翻譯過的）
	for id: String in ["demo_guard", "demo_bracer"]:
		var rows: Array[Dictionary] = EnemyIntel.rows(id, {}, "")
		assert_true(rows.size() >= 1, "%s 有看穿資料" % id)
	for key: String in ["ENEMY_DEMO_GUARD", "ENEMY_DEMO_BRACER", "MOVE_GUARD_SWING", "MOVE_GUARD_THRUST", "MOVE_BRACER_JAB"]:
		assert_true(tr(key) != key, "%s 有翻譯" % key)


func test_jab_hits_then_the_arm_goes_numb() -> void:
	var root: Node3D = _world()
	var heart: Node3D = _heart(root, Vector3(0, 0.05, -1.3))
	var g: DemoGuard = _guard(root, DemoGuard.KIND_BRACER, Vector3(0, 0.05, 0))
	assert_true(g.is_bracer())
	assert_eq(g.intel_id(), "demo_bracer")
	assert_not_null(g.puppet().joint("elbow_L").get_node_or_null("Bracer"), "左手戴著護腕")
	assert_not_null(g.puppet().joint("elbow_R").get_node_or_null("Bracer"), "右手也戴著")
	await tree.process_frame
	assert_true(g.puppet().hand("R").get_node_or_null("BellHammer") == null, "手上沒有棍子")
	var hp: Health = heart.get_node("Health") as Health
	var kinds: Array[String] = []
	hp.damaged.connect(func(_amount: float, info: Dictionary) -> void: kinds.append(str(info.get("kind", ""))))
	var lit: float = 0.0
	for i: int in 150:
		await tree.physics_frame
		if g.brain.state == EnemyBrain.State.TELEGRAPH:
			lit = maxf(lit, g.glow_energy())
		if g.strike_count >= 1:
			break
	assert_eq(g.strike_count, 1, "打了一拳")
	assert_eq(g.last_move, "jab")
	assert_eq(hp.hp, 91.0, "快拳 9 點，直接傷害")
	assert_eq(kinds.size(), 1)
	assert_eq(kinds[0], "jab", "傷害的種類是快拳，不是任何狀態")
	assert_true(lit > DemoGuard.BRACER_ENERGY + 1.0, "出手前護腕亮起來（%s）" % lit)
	# 打完：右手麻掉——破綻裡護腕變暗紅、手垂著；這段時間他不會再出手
	for i: int in 14:
		await tree.physics_frame
	assert_true(g.is_numb(), "打完就麻（%s）" % g.brain.state_name())
	assert_true(g.glow_color().is_equal_approx(DemoGuard.NUMB_GLOW), "護腕變暗紅")
	g.apply_pose(0.0)
	assert_true(g.puppet().joint("shoulder_R").rotation.x < 0.3, "右手垂著")
	assert_true(absf(g.puppet().joint("shoulder_L").rotation.x) < 0.05, "左手從頭到尾沒動過")
	for i: int in 60:
		await tree.physics_frame
	assert_eq(g.strike_count, 1, "麻的那一秒多不會再出手")
	assert_true(g.is_numb())
	assert_eq(hp.hp, 91.0)
	# 麻的時候挨打：失衡三倍，兩下就跪
	g.health.apply_damage(6.0, {"stagger": 8.0})
	assert_eq(g.brain.state_name(), "recover")
	g.health.apply_damage(6.0, {"stagger": 8.0})
	assert_eq(g.brain.state_name(), "staggered", "8×3×2 ≥ 40：跪了")
	root.queue_free()
	await tree.process_frame


func test_club_guard_winds_up_and_only_hits_what_is_in_front() -> void:
	var root: Node3D = _world()
	var front: Node3D = _heart(root, Vector3(0, 0.05, -1.6))
	var g: DemoGuard = _guard(root, DemoGuard.KIND_CLUB, Vector3(0, 0.05, 0))
	assert_false(g.is_bracer())
	assert_eq(g.intel_id(), "demo_guard")
	assert_not_null(g.puppet().hand("R").get_node_or_null("BellHammer"), "手上有棍子")
	var idle_glow: float = g.glow_energy()
	# 前兆：棍子拉到右後方、銅箍亮起來
	g.hold_pose("swing", EnemyBrain.State.TELEGRAPH, 0.9, front.global_position)
	g.apply_pose(0.0)
	assert_true(g.glow_energy() > idle_glow + 2.0, "前兆時銅箍亮起來（%s → %s）" % [idle_glow, g.glow_energy()])
	assert_true(g.puppet().joint("shoulder_R").rotation.z > 1.0, "手往外拉開")
	for i: int in 20:
		await tree.physics_frame
	assert_eq(g.strike_count, 0, "停在姿勢上的時候不出招")
	# 放開：橫掃打得到正面的人，打不到背後的人
	var behind: Node3D = _heart(root, Vector3(0, 0.05, 2.0))
	g.debug_hold = false
	g.brain.state = EnemyBrain.State.CHASE
	g.target = front
	for i: int in 150:
		await tree.physics_frame
		if g.strike_count >= 1:
			break
	assert_eq(g.last_move, "swing")
	assert_eq((front.get_node("Health") as Health).hp, 88.0, "橫掃 12 點")
	assert_eq((behind.get_node("Health") as Health).hp, 100.0, "背後的人沒事")
	root.queue_free()
	await tree.process_frame


func test_guard_stays_down_and_stops_counting_as_an_enemy() -> void:
	var root: Node3D = _world()
	var g: DemoGuard = _guard(root, DemoGuard.KIND_CLUB, Vector3(0, 0.05, -3))
	g.set_physics_process(false)
	await tree.process_frame
	assert_true(g.is_in_group("enemies"))
	var prev: float = Engine.time_scale
	Engine.time_scale = 4.0
	g.health.apply_damage(g.health.hp, {"stagger": 0.0})
	assert_false(g.is_in_group("enemies"), "倒下就不算敵人（鎖定、席菈、戰鬥 HUD 都不再找他）")
	assert_false(g.is_in_group("damageable"))
	assert_eq(g.collision_layer, 0, "不擋路")
	for i: int in 300:
		if g.has_fallen:
			break
		await tree.process_frame
	assert_true(g.has_fallen, "撲倒了")
	for i: int in 240:
		await tree.process_frame
	Engine.time_scale = prev
	assert_true(is_instance_valid(g) and g.is_inside_tree(), "躺在原地，不會沉下去消失")
	assert_true(g._body.position.y > 0.0, "沒有沉進地裡")
	assert_eq(ParticleLook.untextured(g).size(), 0, "倒地的粉是柔邊圓點")
	root.queue_free()
	await tree.process_frame


## 丟毒瓶的（小戰檢驗，D-235）：瓶子落地才有霧、這一下沒有直接傷害、霧 3 秒自己散——丟得再久場上也不會越積越多。
func test_thrower_lobs_a_bottle_that_leaves_a_short_poison_cloud() -> void:
	var brain := EnemyBrain.new().configure("demo_thrower", "standard")
	assert_eq(brain.pattern, PackedStringArray(["toss"]), "只有丟瓶子")
	assert_true(brain.move_num("toss", "range") >= 7.0, "站在後面丟")
	assert_eq(brain.move_num("toss", "damage"), 0.0, "沒有直接傷害")
	var cycle: float = brain.move_num("toss", "telegraph") + brain.move_num("toss", "active") + brain.move_num("toss", "recover")
	assert_true(cycle > brain.move_num("toss", "life"), "一瓶散了才丟得出下一瓶（%s 秒一瓶）" % cycle)
	var rules: StatusRules = StatusRules.load_default()
	assert_true(rules.errors.is_empty(), "狀態資料沒有錯：%s" % ", ".join(rules.errors))
	var src: Dictionary = rules.source(DemoGuard.MIST_SOURCE)
	assert_eq(str(src.get("status", "")), "poison")
	assert_true(float(src.get("rate", 0.0)) < float(rules.source("guardian_spray").get("rate", 0.0)), "比守衛噴的淡")
	for key: String in ["ENEMY_DEMO_THROWER", "MOVE_THROWER_TOSS"]:
		assert_true(tr(key) != key, "%s 有翻譯" % key)
	assert_true(EnemyIntel.rows("demo_thrower", {}, "").size() >= 1, "有看穿資料")
	var root: Node3D = _world()
	var heart: Node3D = _heart(root, Vector3(0, 0.05, -6.0))
	var g: DemoGuard = _guard(root, DemoGuard.KIND_THROWER, Vector3(0, 0.05, 0))
	assert_true(g.is_thrower())
	assert_false(g.is_bracer())
	assert_eq(g.intel_id(), "demo_thrower")
	await tree.process_frame
	assert_true(g.puppet().hand("R").get_node_or_null("BellHammer") == null, "手上沒有棍子")
	assert_not_null(g.puppet().hand("R").get_node_or_null("HandBottle"), "手上拿著瓶子")
	assert_not_null(g.puppet().joint("hips").get_node_or_null("BeltBottle0"), "腰上掛著一排")
	# 還沒開打（站著等）：不追、不丟、不算敵人；放開才動
	g.set_waiting(true)
	assert_false(g.is_in_group("enemies") or g.is_in_group("damageable"))
	for i: int in 150:
		await tree.physics_frame
	assert_eq(g.toss_count, 0, "等的時候不會丟")
	g.set_waiting(false)
	assert_true(g.is_in_group("enemies") and g.is_in_group("damageable"))
	var hp: Health = heart.get_node("Health") as Health
	var waited: int = 0
	var lit: float = 0.0
	while g.toss_count < 1 and waited < 300:
		await tree.physics_frame
		waited += 1
		lit = maxf(lit, g.glow_energy())
	assert_eq(g.toss_count, 1, "丟出去了")
	assert_eq(g.last_move, "toss")
	assert_true(lit > DemoGuard.BOTTLE_ENERGY * 2.0, "舉起來的時候瓶子變亮（%s）" % lit)
	assert_true(g.last_mist == null, "瓶子還在飛：還沒有霧")
	assert_not_null(root.get_node_or_null("TossedBottle1"), "飛在空中的瓶子")
	assert_true(FrostbridgeOpening.flat_distance(g.last_toss_at, heart.global_position) < 0.2, "瞄的是人站的地方")
	for i: int in int(brain.move_num("toss", "flight") * 60.0) + 8:
		await tree.physics_frame
	var mist: PoisonMist = g.last_mist
	assert_not_null(mist, "落地：一團毒霧")
	assert_true(root.get_node_or_null("TossedBottle1") == null, "瓶子碎了")
	assert_eq(mist.source_id, DemoGuard.MIST_SOURCE)
	assert_true(absf(mist.radius - 2.0) < 0.001 and absf(mist.life - 3.0) < 0.001, "小霧：半徑 2、3 秒")
	assert_true(FrostbridgeOpening.flat_distance(mist.global_position, heart.global_position) < 0.2, "霧在落點")
	assert_eq(hp.hp, hp.max_hp, "這一下沒有直接傷害")
	# 連續丟 10 秒：場上的霧最多兩團（通常一團），不會越積越多
	var most: int = 0
	for i: int in 600:
		await tree.physics_frame
		var alive: int = 0
		for n: Node in tree.get_nodes_in_group("poison_mist"):
			if root.is_ancestor_of(n) and not n.is_queued_for_deletion():
				alive += 1
		most = maxi(most, alive)
	assert_true(g.toss_count >= 3, "一直在丟（%d 瓶）" % g.toss_count)
	assert_true(most <= 2, "霧不會越積越多（最多同時 %d 團）" % most)
	assert_false(is_instance_valid(mist) and mist.is_inside_tree(), "第一團早就散了")
	assert_eq(hp.hp, hp.max_hp, "丟了這麼多瓶，一點直接傷害都沒有")
	# 倒下：不算敵人、手上的瓶子收掉
	g.health.apply_damage(9999.0, {})
	await tree.physics_frame
	assert_false(g.is_in_group("enemies"))
	root.queue_free()
	await tree.process_frame
