extends TestCase
## 戰鬥起步：數值檔與覆寫、生命值、命中扇形、揮擊命中、打擊停頓、鏡頭震動。


func after_each() -> void:
	CombatTuning.load_tuning()
	Engine.time_scale = 1.0


func test_tuning_defaults_match_design() -> void:
	CombatTuning.load_tuning()
	assert_eq(CombatTuning.num("noen.max_hp"), 100.0, "諾恩 100")
	assert_eq(CombatTuning.num("noen.blunt_damage"), 6.0, "鈍擊 6")
	assert_eq(CombatTuning.num("undertaker.max_hp"), 900.0, "送葬者 900")
	assert_eq(CombatTuning.pair("noen.strike_window", Vector2.ZERO), Vector2(0.35, 0.6))
	assert_eq(CombatTuning.num("no.such.key", 7.0), 7.0, "不存在用 fallback")


func test_tuning_override_merges_deep() -> void:
	var path: String = "user://test_tuning_%d.json" % Time.get_ticks_usec()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"noen": {"blunt_damage": 9}}))
	f.close()
	CombatTuning.load_tuning(CombatTuning.DEFAULT_PATH, path)
	assert_eq(CombatTuning.num("noen.blunt_damage"), 9.0, "覆寫生效")
	assert_eq(CombatTuning.num("noen.max_hp"), 100.0, "沒覆寫的 key 保留")
	DirAccess.remove_absolute(path)


func test_health_damage_invuln_death_reset() -> void:
	var h := Health.new(20.0)
	var died: Array[int] = [0]
	h.died.connect(func() -> void: died[0] += 1)
	var invuln: Array[bool] = [true]
	h.invulnerable_check = func() -> bool: return invuln[0]
	assert_false(h.apply_damage(5.0), "無敵不扣")
	invuln[0] = false
	assert_true(h.apply_damage(5.0))
	assert_eq(h.hp, 15.0)
	assert_true(h.apply_damage(50.0))
	assert_true(h.is_dead())
	assert_eq(h.hp, 0.0, "不會變負")
	assert_false(h.apply_damage(1.0), "死了不再扣")
	assert_eq(died[0], 1, "died 只發一次")
	h.reset()
	assert_eq(h.hp, 20.0)
	h.free()


func test_strike_arc() -> void:
	var fwd := Vector3(0, 0, -1)
	assert_true(PlayerController.in_strike_arc(Vector3.ZERO, fwd, Vector3(0, 0, -1.5), 1.9, 110.0), "正前方")
	assert_true(PlayerController.in_strike_arc(Vector3.ZERO, fwd, Vector3(1.0, 0.8, -1.0), 1.9, 110.0), "斜前 45° 不看高度")
	assert_false(PlayerController.in_strike_arc(Vector3.ZERO, fwd, Vector3(0, 0, 1.0), 1.9, 110.0), "背後")
	assert_false(PlayerController.in_strike_arc(Vector3.ZERO, fwd, Vector3(0, 0, -2.5), 1.9, 110.0), "太遠")
	assert_false(PlayerController.in_strike_arc(Vector3.ZERO, fwd, Vector3(1.5, 0, -0.2), 1.9, 110.0), "側邊超出扇形")


## 最小的靶：在 damageable 群組、底下有一個叫 Health 的節點（玩家的 strike() 就靠這兩件事找目標）。
func _target(parent: Node3D, at: Vector3, hits: Array[int]) -> Health:
	var body := Node3D.new()
	body.add_to_group("damageable")
	var h := Health.new(60.0)
	h.name = "Health"
	body.add_child(h)
	h.damaged.connect(func(_amount: float, _info: Dictionary) -> void: hits[0] += 1)
	parent.add_child(body)
	body.global_position = at
	return h


func test_player_swing_hits_target_with_hit_stop_and_shake() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	var forward: Vector3 = -player.get_node("Body").global_basis.z as Vector3
	var front_hits: Array[int] = [0]
	var behind_hits: Array[int] = [0]
	var front: Health = _target(root, player.global_position + forward * 1.2, front_hits)
	var behind: Health = _target(root, player.global_position - forward * 1.2, behind_hits)
	await tree.physics_frame
	player.start_attack()
	for i: int in 60:
		await tree.physics_frame
		if front_hits[0] > 0:
			break
	assert_eq(front_hits[0], 1, "前方的靶被打中一次")
	assert_eq(behind_hits[0], 0, "背後的不會中")
	assert_eq(behind.hp, 60.0, "背後的沒有扣血")
	assert_eq(front.hp, 60.0 - 6.0, "鈍擊 6")
	assert_true(player.shake_amount() > 0.0, "命中有鏡頭震動")
	for i: int in 30:
		await tree.physics_frame
	assert_eq(front_hits[0], 1, "一次揮擊只判定一次")
	assert_eq(Engine.time_scale, 1.0, "打擊停頓結束後恢復")
	# 閃避無敵
	player.invulnerable = true
	assert_false(player.health.apply_damage(10.0), "閃避無敵不扣血")
	player.invulnerable = false
	assert_true(player.health.apply_damage(10.0))
	root.queue_free()
	await tree.process_frame


func test_hit_stop_restores_time_scale() -> void:
	var game: Node = tree.root.get_node("Game")
	game.call("hit_stop", 0.05)
	assert_true(Engine.time_scale < 1.0, "停頓中時間變慢")
	await tree.create_timer(0.2, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0, "用真實時間計時並恢復")


func test_reduced_shake() -> void:
	var settings: Node = tree.root.get_node("Settings")
	var before: bool = bool(settings.get("reduce_camera_shake"))
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	tree.root.add_child(player)
	settings.set("reduce_camera_shake", true)
	player.shake(0.4)
	assert_true(absf(player.shake_amount() - 0.1) < 0.001, "減少晃動：25%")
	settings.set("reduce_camera_shake", before)
	player.queue_free()
	await tree.process_frame
