extends TestCase
## 送葬者第一階段：招式輪替與距離、各招前兆長度、橫掃／下砸／衝撞命中、撞牆跪地、
## 第二階段看穿「下砸」變未證實、鐵架關節只在背後露出。

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	Engine.time_scale = 1.0


func _finish_move(b: EnemyBrain, dist: float) -> void:
	b.tick(b.telegraph_sec + 0.01, dist)
	b.tick(b.strike_sec + 0.01, dist)
	b.tick(b.recover_sec + 0.01, dist)


func test_pattern_and_ranges() -> void:
	var b := EnemyBrain.new().configure("undertaker")
	b.tick(0.1, 10.0)
	assert_eq(b.state_name(), "chase")
	b.tick(0.01, 2.0)
	assert_eq(b.state_name(), "telegraph")
	assert_eq(b.move_id, "sweep", "第一招橫掃")
	assert_true(absf(b.telegraph_sec - 0.9) < 0.001, "橫掃前兆 0.9")
	_finish_move(b, 2.0)
	b.tick(0.01, 2.0)
	assert_eq(b.move_id, "slam", "第二招下砸")
	assert_true(absf(b.telegraph_sec - 1.0) < 0.001, "第一階段下砸前兆與攻略一致 1.0")
	assert_true(absf(b.recover_sec - 0.6) < 0.001, "砸地後破綻 0.6")
	_finish_move(b, 2.0)
	b.tick(0.01, 2.0)
	assert_eq(b.move_id, "sweep")
	_finish_move(b, 2.0)
	b.tick(0.01, 2.0)
	assert_eq(b.move_id, "sweep", "近身時衝撞不合距離，跳過")
	_finish_move(b, 7.0)
	b.tick(0.01, 7.0)
	assert_eq(b.move_id, "charge", "拉開距離就衝撞")
	assert_eq(b.current_move(), "charge")
	var story := EnemyBrain.new().configure("undertaker", "story")
	story.tick(0.1, 10.0)
	story.tick(0.01, 2.0)
	assert_true(absf(story.telegraph_sec - 0.9 * 1.3) < 0.001, "故事難度前兆 ×1.3")


func test_force_kneel() -> void:
	var b := EnemyBrain.new().configure("undertaker")
	b.force_kneel(2.0)
	assert_eq(b.state_name(), "staggered")
	b.tick(1.9, 5.0)
	assert_eq(b.state_name(), "staggered")
	b.tick(0.2, 5.0)
	assert_eq(b.state_name(), "chase", "撞牆跪地 2 秒")


func test_frame_joint_exposed_from_behind() -> void:
	var fwd := Vector3(0, 0, -1)
	var arc: Vector2 = EnemyIntel.arc_of(EnemyIntel.weakpoint("undertaker", "frame_joint"))
	assert_true(EnemyIntel.is_exposed(Vector3.ZERO, fwd, Vector3(0, 0, 3), arc), "正後方")
	assert_true(EnemyIntel.is_exposed(Vector3.ZERO, fwd, Vector3(-1, 0, 2), arc), "左後方")
	assert_false(EnemyIntel.is_exposed(Vector3.ZERO, fwd, Vector3(0, 0, -3), arc), "正面打不到")
	assert_false(EnemyIntel.is_exposed(Vector3.ZERO, fwd, Vector3(3, 0, 0), arc), "側面打不到")


func _arena(with_wall: bool = false) -> Array:
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(40, 1, 40)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	if with_wall:
		var wall := CSGBox3D.new()
		wall.size = Vector3(10, 4, 1)
		wall.position = Vector3(0, 2, -14)
		wall.use_collision = true
		root.add_child(wall)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	var boss := Undertaker.new()
	root.add_child(boss)
	return [root, player, boss]


func test_sweep_then_slam_hit_player() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var boss: Undertaker = a[2]
	player.global_position = Vector3(0, 0, 0)
	boss.global_position = Vector3(0, 0, -2.0)
	var hp0: float = player.health.hp
	for i: int in 150:
		await tree.physics_frame
		if player.health.hp < hp0:
			break
	assert_eq(player.health.hp, hp0 - 28.0, "橫掃 28")
	for i: int in 200:
		await tree.physics_frame
		if player.health.hp < hp0 - 28.0:
			break
	assert_eq(boss.brain.move_id, "slam")
	assert_eq(player.health.hp, hp0 - 28.0 - 40.0, "下砸 40")
	assert_true(boss.brain.is_open() or boss.brain.state == EnemyBrain.State.STRIKE, "砸地後是破綻")
	root.queue_free()
	await tree.process_frame


func test_charge_into_wall_kneels() -> void:
	var a: Array = _arena(true)
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var boss: Undertaker = a[2]
	# 諾恩站在牆前，送葬者在遠處；出招瞬間諾恩往旁邊閃開，送葬者直直撞上牆
	player.global_position = Vector3(0, 0, -11.5)
	boss.global_position = Vector3(0, 0, -4.0)
	var knelt: bool = false
	var charged: bool = false
	for i: int in 240:
		await tree.physics_frame
		charged = charged or boss.brain.current_move() == "charge"
		if boss.brain.state == EnemyBrain.State.STRIKE and player.global_position.x < 1.0:
			player.global_position = Vector3(4.0, 0, -11.5)
		if boss.brain.state == EnemyBrain.State.STAGGERED:
			knelt = true
			break
	assert_true(charged, "距離 7.5 公尺：衝撞")
	assert_true(knelt, "撞牆跪地")
	assert_true(boss.global_position.z < -10.0, "衝到牆邊（z=%.2f）" % boss.global_position.z)
	assert_eq(player.health.hp, player.health.max_hp, "閃開了沒被撞到")
	root.queue_free()
	await tree.process_frame


func test_phase_two_makes_slam_unverified() -> void:
	TranslationServer.set_locale("zh_TW")
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[2]
	boss.global_position = Vector3(0, 0, -30)
	await tree.physics_frame
	assert_eq(boss.health.hp, 900.0)
	var lines: PackedStringArray = EnemyIntel.lines("undertaker", boss.intel_overrides)
	assert_true(lines.has("招式：鐵架下砸（已證實）"))
	boss.health.apply_damage(460.0, {"stagger": 0.0})
	assert_eq(boss.phase, 2, "生命 450 以下進入第二階段")
	lines = EnemyIntel.lines("undertaker", boss.intel_overrides)
	assert_true(lines.has("招式：鐵架下砸（未證實？）"), "攻略開始失準：" + ", ".join(lines))
	assert_true(absf(boss.brain.move_num("slam", "telegraph") - 0.7) < 0.001, "下砸前兆縮短到 0.7")
	root.queue_free()
	await tree.process_frame


func test_double_slam_chain_and_phase_two_pattern() -> void:
	var b := EnemyBrain.new().configure("undertaker")
	b.set_pattern(PackedStringArray(["double_slam", "sweep"]))
	b.tick(0.1, 10.0)
	b.tick(0.01, 2.0)
	assert_eq(b.move_id, "double_slam")
	assert_true(absf(b.telegraph_sec - 0.7) < 0.001, "第一下前兆 0.7")
	assert_eq(b.intel_move(), "double_slam")
	b.tick(b.telegraph_sec + 0.01, 2.0)
	assert_eq(b.state_name(), "strike")
	b.tick(b.strike_sec + 0.01, 2.0)
	assert_eq(b.state_name(), "telegraph", "第一下之後沒有破綻，直接第二下的前兆")
	assert_eq(b.move_id, "double_slam_2")
	assert_true(absf(b.telegraph_sec - 0.5) < 0.001, "第二下前兆只有 0.5")
	assert_eq(b.intel_move(), "double_slam", "看穿把第二下對回「連續下砸」")
	b.tick(b.telegraph_sec + 0.01, 2.0)
	b.tick(b.strike_sec + 0.01, 2.0)
	assert_eq(b.state_name(), "recover", "第二下之後才有破綻")
	assert_true(absf(b.recover_sec - 0.7) < 0.001)
	b.tick(b.recover_sec + 0.01, 2.0)
	b.tick(0.01, 2.0)
	assert_eq(b.move_id, "sweep", "連段的後續招不在輪替裡")


func test_phase_two_intel_and_unverified_evade() -> void:
	TranslationServer.set_locale("zh_TW")
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[2]
	boss.state = GameState.new()
	boss.global_position = Vector3(0, 0, -30)
	await tree.physics_frame
	var lines: PackedStringArray = EnemyIntel.lines("undertaker", boss.intel_overrides)
	assert_false(", ".join(lines).contains("連續下砸"), "第一階段看穿沒有攻略沒寫的招")
	boss.enter_phase_two()
	assert_eq(boss.brain.pattern, PackedStringArray(["double_slam", "sweep", "grab", "charge"]), "第二階段輪替")
	lines = EnemyIntel.lines("undertaker", boss.intel_overrides)
	assert_true(lines.has("招式：連續下砸（未證實？）"), ", ".join(lines))
	assert_false(", ".join(lines).contains("抓取"), "抓取出現過才顯示")
	# 第二下前兆中：攻略沒寫，席菈的「閃開」算失敗
	var b: EnemyBrain = boss.brain
	b.move_id = "double_slam_2"
	b.state = EnemyBrain.State.TELEGRAPH
	b.telegraph_sec = 0.5
	b.time_in_state = 0.45
	var c := CompanionBrain.new().configure("story")
	assert_false(c.evade_in_window(b), "還沒看過第二下：閃開抓不到時機")
	var verified: Array[bool] = [false]
	boss.double_slam_verified.connect(func() -> void: verified[0] = true)
	boss.note_second_slam(false, true)
	assert_false(verified[0], "被打中不算看過")
	boss.note_second_slam(true, false)
	assert_false(verified[0], "離太遠不算看過")
	boss.note_second_slam(true, true)
	assert_true(verified[0], "近處閃過一次＝看過")
	assert_true(c.evade_in_window(b), "看過之後閃開有效")
	lines = EnemyIntel.lines("undertaker", boss.intel_overrides)
	assert_true(lines.has("招式：連續下砸（已證實）"), ", ".join(lines))
	root.queue_free()
	await tree.process_frame


func test_frame_throw_triggers_once() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[2]
	var st := GameState.new()
	boss.state = st
	boss.global_position = Vector3(0, 0, -30)
	await tree.physics_frame
	var n: Array[int] = [0]
	boss.frame_throw_started.connect(func() -> void: n[0] += 1)
	boss.health.apply_damage(460.0, {"stagger": 0.0})
	assert_eq(boss.phase, 2)
	assert_eq(n[0], 0, "440 還沒到拋擲")
	boss.health.apply_damage(150.0, {"stagger": 0.0})
	await tree.physics_frame
	assert_eq(n[0], 1, "生命 ≤ 300 拋擲")
	assert_eq(st.get_flag("slice.frame_thrown", false), true)
	boss.health.apply_damage(50.0, {"stagger": 0.0})
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(n[0], 1, "只觸發一次")
	root.queue_free()
	await tree.process_frame


func test_frame_throw_on_caravan_half() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[2]
	boss.state = GameState.new()
	boss.global_position = Vector3(0, 0, -30)
	var caravan := Caravan.new()
	caravan.route = PackedVector3Array([Vector3(10, 0, 0), Vector3(10, 0, -10)])
	root.add_child(caravan)
	await tree.physics_frame
	boss.enter_phase_two()
	assert_false(boss.frame_thrown)
	caravan.runner.traveled = 5.2
	await tree.physics_frame
	await tree.physics_frame
	assert_true(boss.frame_thrown, "車隊過半拋擲")
	root.queue_free()
	await tree.process_frame


func test_grab_blocked_by_guarding_sheila() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var boss: Undertaker = a[2]
	player.global_position = Vector3(0, 0, -20)
	boss.global_position = Vector3(0, 0, 0)
	var caravan := Caravan.new()
	caravan.route = PackedVector3Array([Vector3(0, 0, -1.6), Vector3(0, 0, -1.7)])
	root.add_child(caravan)
	caravan.runner.speed = 0.0
	await tree.physics_frame
	boss._body.rotation.y = 0.0
	var victim: Node3D = boss._grab()
	assert_eq(victim, caravan, "抓前方最近的心跳（傷者）")
	assert_eq(caravan.runner.injured, 1)
	assert_true(bool(boss.intel_overrides.get("grab", false)), "抓過一次看穿就有抓取")
	var sheila := Sheila.new()
	sheila.position = Vector3(1.2, 0, -1.6)
	root.add_child(sheila)
	await tree.physics_frame
	sheila.brain.guard_active = true
	sheila.global_position = Vector3(1.2, 0, -1.6)
	caravan.runner.stop_left = 0.0
	var hp0: float = sheila.health.hp
	victim = boss._grab()
	assert_eq(victim, null, "席菈守著，擋下")
	assert_eq(caravan.runner.injured, 1, "傷者沒有增加")
	assert_true(sheila.health.hp < hp0, "席菈替他挨了一下")
	root.queue_free()
	await tree.process_frame


func test_difficulty_change_keeps_phase_two() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[2]
	boss.global_position = Vector3(0, 0, -30)
	await tree.physics_frame
	var before: String = Settings.difficulty
	boss.enter_phase_two()
	Settings.difficulty = "story" if before != "story" else "hard"
	boss._on_settings_changed()
	assert_eq(boss.brain.pattern[0], "double_slam", "換難度後還是第二階段輪替")
	assert_true(absf(boss.brain.move_num("slam", "telegraph") - 0.7) < 0.001, "下砸前兆仍是 0.7")
	assert_true(bool(boss.brain.unreadable.get("double_slam_2", false)), "第二下仍讀不懂")
	Settings.difficulty = before
	boss._on_settings_changed()
	assert_eq(boss.brain.pattern[0], "double_slam")
	root.queue_free()
	await tree.process_frame


func test_grab_player_struggle_and_release() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var boss: Undertaker = a[2]
	boss.global_position = Vector3(0, 0, 0)
	player.global_position = Vector3(0, 0, -1.6)
	# 送葬者的狀態機停掉，只測抓取（不然牠會在測試中一直出招把諾恩打倒，倒下狀態會漏到後面的測試）
	boss.set_physics_process(false)
	await tree.physics_frame
	boss._body.rotation.y = 0.0
	assert_eq(boss._grab(), player, "抓到諾恩")
	assert_true(player.grabbed_by == boss, "被抓住")
	for i: int in 4:
		assert_false(player.struggle_press(), "掙扎 %d 次還沒掙脫" % (i + 1))
	assert_true(player.struggle_press(), "第 5 次掙脫")
	assert_true(player.grabbed_by == null)
	assert_true(player.global_position.distance_to(boss.global_position) > 2.2, "掙脫後被推開")
	# 沒掙脫：2 秒後被捏一下才放開
	player.global_position = Vector3(0, 0, -1.6)
	boss._body.rotation.y = 0.0
	boss._grab()
	assert_true(player.grabbed_by == boss)
	var hp_before: float = player.health.hp
	for i: int in 140:
		await tree.physics_frame
		if player.grabbed_by == null:
			break
	assert_true(player.grabbed_by == null, "時間到放開")
	assert_true(player.health.hp < hp_before, "沒掙脫：被捏一下（%.0f → %.0f）" % [hp_before, player.health.hp])
	# 抓著時被打中弱點（席菈打弱點）就鬆手
	player.global_position = Vector3(0, 0, -1.6)
	boss._body.rotation.y = 0.0
	boss.brain.state = EnemyBrain.State.RECOVER
	boss._grab()
	assert_true(player.grabbed_by == boss)
	boss.health.apply_damage(60.0, {"weak": "frame_joint", "stagger": 0.0})
	assert_true(player.grabbed_by == null, "席菈打中弱點：鬆手")
	root.queue_free()
	await tree.process_frame


## 被斬倒（D-052）：跪下 → 向前倒（頭朝原本面向的方向、躺平）→ 落地有雪粉 → 沉進雪裡消失。
func test_cut_down_falls_forward_then_sinks() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var boss: Undertaker = a[2]
	player.global_position = Vector3(0, 0, 6.0)
	boss.global_position = Vector3(0, 0, -4.0)
	boss._body.rotation.y = deg_to_rad(30.0)
	await tree.physics_frame
	var fwd: Vector3 = boss.forward()
	var origin: Vector3 = boss.global_position
	var fell_count: Array[int] = [0]
	boss.fell.connect(func() -> void: fell_count[0] += 1)
	# 兜帽裡的霜光（D-075）：活著時亮著、不投影
	var hood_light: OmniLight3D = boss._body.get_node("Torso/HoodLight") as OmniLight3D
	assert_not_null(hood_light, "兜帽裡有一盞冷光")
	assert_true(hood_light.light_energy > 0.5 and not hood_light.shadow_enabled, "亮著、不投影")
	assert_not_null(boss._body.get_node_or_null("Torso/HoodEyeL"), "兜帽裡的霜光點（左）")
	assert_not_null(boss._body.get_node_or_null("Torso/HoodEyeR"), "兜帽裡的霜光點（右）")
	var prev_scale: float = Engine.time_scale
	Engine.time_scale = 4.0
	boss.health.apply_damage(boss.health.hp, {"kind": "kindling", "stagger": 0.0})
	assert_false(boss.is_in_group("damageable"), "倒下後不再吃傷害")
	# 跪下的途中：還沒倒地、身體往下沉
	for i: int in 6:
		await tree.process_frame
	assert_false(boss.has_fallen, "先跪下，還沒倒地")
	for i: int in 400:
		if boss.has_fallen:
			break
		await tree.process_frame
	assert_true(boss.has_fallen, "倒地")
	assert_eq(fell_count[0], 1, "倒地訊號一次")
	assert_true(hood_light.light_energy < 0.01, "倒地時兜帽的霜光已經熄了（%.2f）" % hood_light.light_energy)
	var hood: Node3D = null
	for c: Node in boss._body.get_node("Torso").get_children():
		if c is CSGSphere3D:
			hood = c as Node3D
	assert_not_null(hood, "找得到頭巾")
	if hood != null:
		var rel: Vector3 = hood.global_position - origin
		assert_true(rel.dot(fwd) > 1.2, "向前倒：頭在原本面向的前方（%.2f m）" % rel.dot(fwd))
		assert_true(hood.global_position.y < 0.9, "躺平（頭離地 %.2f m）" % hood.global_position.y)
	var frame: Node3D = boss._frame_node()
	if frame != null:
		var up: float = (frame.global_basis * Vector3(0, 0, 1)).y
		assert_true(up > 0.8, "背上的鐵架朝天（%.2f）" % up)
	assert_true(boss.has_node("FallPuff"), "落地揚起雪粉")
	assert_true(boss.has_node("FrostExhale"), "倒地後身上的霜氣散出一盞冷光（暗色大衣在夜裡有輪廓）")
	assert_eq(boss.collision_layer, 0, "倒下後不再擋路")
	for i: int in 900:
		if not is_instance_valid(boss):
			break
		await tree.process_frame
	assert_false(is_instance_valid(boss), "躺一會兒後沉進雪裡、移除")
	Engine.time_scale = prev_scale
	root.queue_free()
	await tree.process_frame


## 前兆姿勢的方向（D-052 順手修正）：下砸上身後仰、抓取與衝撞往前探。頭巾在上身的 (0, 1.45, -0.32)，-Z 是前方。
func test_telegraph_lean_directions() -> void:
	var hood := Vector3(0.0, 1.45, -0.32)
	var rest_z: float = hood.z
	var slam_z: float = (Basis.from_euler(Undertaker.telegraph_lean("slam", 1.0) * (PI / 180.0)) * hood).z
	var grab_z: float = (Basis.from_euler(Undertaker.telegraph_lean("grab", 1.0) * (PI / 180.0)) * hood).z
	var charge_z: float = (Basis.from_euler(Undertaker.telegraph_lean("charge", 1.0) * (PI / 180.0)) * hood).z
	assert_true(slam_z > rest_z + 0.2, "下砸：頭往後（%.2f → %.2f）" % [rest_z, slam_z])
	assert_true(grab_z < rest_z - 0.3, "抓取：頭往前探（%.2f → %.2f）" % [rest_z, grab_z])
	assert_true(charge_z < rest_z - 0.2, "衝撞：低頭往前（%.2f → %.2f）" % [rest_z, charge_z])
	assert_eq(Undertaker.telegraph_lean("sweep", 0.0), Vector3.ZERO, "前兆剛開始沒有姿勢")
	assert_eq(Undertaker.telegraph_lean("unknown", 1.0), Vector3.ZERO)


## 前兆範圍（D-088）：四種招式的地面範圍都用 telegraph.gdshader（形狀與大小照招式資料），
## 前兆中只顯示當下那一招，進度從 0 往上長；不再是平塗的色塊。
func test_telegraph_decals_use_shader_and_fill() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var boss: Undertaker = a[2]
	player.global_position = Vector3(0, 0, 0)
	boss.global_position = Vector3(0, 0, -2.0)
	var decals: Dictionary = boss.get("_decals")
	assert_eq(decals.size(), 4, "橫掃、下砸、衝撞、抓取")
	var shapes: Dictionary = {"sweep": Undertaker.SHAPE_FAN, "slam": Undertaker.SHAPE_DISC, "charge": Undertaker.SHAPE_LANE, "grab": Undertaker.SHAPE_FAN}
	for id: String in shapes:
		var mi: MeshInstance3D = decals[id] as MeshInstance3D
		var mat: ShaderMaterial = mi.material_override as ShaderMaterial
		assert_true(mat != null and mat.shader.resource_path == Undertaker.TELEGRAPH_SHADER, "%s 用前兆 shader" % id)
		assert_eq(int(mat.get_shader_parameter("shape")), int(shapes[id]), "%s 的形狀" % id)
	var sweep_mat: ShaderMaterial = (decals["sweep"] as MeshInstance3D).material_override as ShaderMaterial
	assert_true(absf((sweep_mat.get_shader_parameter("extent") as Vector2).x - boss.brain.move_num("sweep", "range", 3.2)) < 0.001, "橫掃半徑照招式資料")
	assert_true(absf(float(sweep_mat.get_shader_parameter("half_arc")) - deg_to_rad(boss.brain.move_num("sweep", "arc_deg", 150.0) * 0.5)) < 0.001, "橫掃角度照招式資料")
	var lane_mat: ShaderMaterial = (decals["charge"] as MeshInstance3D).material_override as ShaderMaterial
	assert_true(absf((lane_mat.get_shader_parameter("extent") as Vector2).y - 4.0) < 0.001, "衝撞長條半長 4 m")
	var seen: float = -1.0
	var grew: bool = false
	for i: int in 120:
		await tree.physics_frame
		if boss.brain.state == EnemyBrain.State.TELEGRAPH:
			var cur: MeshInstance3D = decals[Undertaker._decal_for(boss.brain.move_id)] as MeshInstance3D
			assert_true(cur.visible, "前兆中顯示當下那一招的範圍")
			var shown: int = 0
			for id: String in decals:
				if (decals[id] as MeshInstance3D).visible:
					shown += 1
			assert_eq(shown, 1, "只顯示一個範圍")
			var p: float = float((cur.material_override as ShaderMaterial).get_shader_parameter("progress"))
			if seen >= 0.0 and p > seen + 0.01:
				grew = true
			seen = p
			if grew:
				break
	assert_true(grew, "前兆進度往上長（最後 %.2f）" % seen)
	root.queue_free()
	await tree.process_frame
