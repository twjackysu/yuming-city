extends TestCase
## 被打中的那一下（D-217）：每次扣到血，命中點噴一把霜屑＋一盞很短的閃光；打中弱點再多一把火星。
## 掛在敵人的上一層（敵人沉進雪裡也不會被帶走），半秒多就自己收掉——連打不會越積越多；中毒那種持續扣血不噴。


func _arena() -> Array:
	var root := Node3D.new()
	tree.root.add_child(root)
	var boss := Undertaker.new()
	root.add_child(boss)
	var src := Node3D.new()
	root.add_child(src)
	boss.global_position = Vector3(2.0, 0.0, -3.0)
	src.global_position = Vector3(2.0, 0.0, -1.2)
	boss.set_physics_process(false)
	return [root, boss, src]


func _fx_nodes(root: Node) -> int:
	var n: int = 0
	for c: Node in root.get_children():
		if str(c.name).begins_with("HitFx") and not c.is_queued_for_deletion():
			n += 1
	return n


func test_hit_throws_chips_toward_attacker_and_flashes() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[1]
	var src: Node3D = a[2]
	assert_eq(boss.hit_fx_count, 0)
	assert_true(boss.health.apply_damage(6.0, {"source": src, "stagger": 0.0, "kind": "blunt", "weak": ""}))
	assert_eq(boss.hit_fx_count, 1, "扣到血就噴一次")
	var fx: Node3D = boss.last_hit_fx
	assert_not_null(fx, "命中的那一組")
	if fx == null:
		root.queue_free()
		await tree.process_frame
		return
	assert_eq(fx.get_parent(), root, "掛在關卡上，不是敵人身上")
	# 位置：朝攻擊者那一側（+Z）、胸口的高度、大衣外緣
	var off: Vector3 = fx.global_position - boss.global_position
	assert_true(off.z > 0.4 and absf(off.x) < 0.01, "在攻擊者那一側（%s）" % str(off))
	assert_true(off.y > 1.2 and off.y < 1.8, "胸口的高度")
	assert_true(fx.global_position.is_equal_approx(boss.hit_point(src.global_position)))
	var chips: CPUParticles3D = fx.get_node_or_null("Chips") as CPUParticles3D
	assert_not_null(chips, "霜屑")
	assert_false(fx.has_node("Sparks"), "沒打中弱點：沒有火星")
	if chips != null:
		assert_true(chips.one_shot and chips.emitting and chips.explosiveness > 0.9, "一次噴完")
		assert_true(chips.direction.z > 0.5 and chips.direction.y > 0.2, "往攻擊者那邊、斜上")
		assert_true(chips.gravity.y < -5.0, "會往下掉")
		# D-208：粒子是在節點擺到命中點之後才開始噴的（不是噴在原點）
		assert_true(chips.global_position.is_equal_approx(fx.global_position))
	assert_eq(ParticleLook.untextured(fx).size(), 0, "粒子有圓點貼圖（不是硬邊方塊）")
	var flash: OmniLight3D = fx.get_node_or_null("Flash") as OmniLight3D
	assert_not_null(flash, "閃光")
	if flash != null:
		assert_true(flash.light_energy > 1.0 and not flash.shadow_enabled, "亮、不投影")
		assert_true(flash.position.z > 0.2, "在身體外面（照在朝攻擊者的那一面）")
		assert_true(flash.light_color.b >= flash.light_color.r, "一般命中是冷白")
	# 命中點的亮斑：面向鏡頭的加法圓點，畫在身體前面，馬上放大、淡掉
	var pop: MeshInstance3D = fx.get_node_or_null("Pop") as MeshInstance3D
	assert_not_null(pop, "命中點的亮斑")
	if pop != null:
		var pm: StandardMaterial3D = pop.material_override as StandardMaterial3D
		assert_true(pm != null and pm.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and pm.albedo_texture != null, "加法混色、有圓點貼圖")
		assert_true(pm != null and pm.no_depth_test and pm.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED, "面向鏡頭、不被大衣切掉")
		assert_true(pop.scale.x < 0.8, "從小的開始")
	# 閃光很快熄掉，整組半秒多之後收掉
	await tree.create_timer(EnemyActor.HIT_FLASH_SEC + 0.08).timeout
	if flash != null and is_instance_valid(flash):
		assert_true(flash.light_energy < 0.05, "閃光熄了")
	if pop != null and is_instance_valid(pop):
		assert_true(pop.scale.x > 0.95 and (pop.material_override as StandardMaterial3D).albedo_color.a < 0.05, "亮斑放大、淡掉了")
	await tree.create_timer(EnemyActor.HIT_FX_SEC + 0.15).timeout
	assert_false(is_instance_valid(fx) and not fx.is_queued_for_deletion(), "自己收掉")
	root.queue_free()
	await tree.process_frame


func test_weak_hit_adds_sparks_and_warm_flash() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[1]
	var src: Node3D = a[2]
	boss.health.apply_damage(6.0, {"source": src, "stagger": 0.0, "kind": "blunt", "weak": ""})
	var plain: Node3D = boss.last_hit_fx
	boss.health.apply_damage(12.0, {"source": src, "stagger": 0.0, "kind": "blunt", "weak": "frame_joint"})
	var weak: Node3D = boss.last_hit_fx
	assert_eq(boss.hit_fx_count, 2)
	assert_true(weak != null and weak != plain, "每一下各自一組")
	if weak == null or plain == null:
		root.queue_free()
		await tree.process_frame
		return
	var sparks: CPUParticles3D = weak.get_node_or_null("Sparks") as CPUParticles3D
	assert_not_null(sparks, "打中弱點（鐵件）：多一把火星")
	if sparks != null:
		assert_true(sparks.emitting and sparks.one_shot)
		assert_true(sparks.initial_velocity_max > (weak.get_node("Chips") as CPUParticles3D).initial_velocity_max, "火星飛得比霜屑快")
	assert_true((weak.get_node("Chips") as CPUParticles3D).amount > (plain.get_node("Chips") as CPUParticles3D).amount, "弱點那一下比較大")
	var wf: OmniLight3D = weak.get_node("Flash") as OmniLight3D
	var pf: OmniLight3D = plain.get_node("Flash") as OmniLight3D
	assert_true(wf.light_color.r > wf.light_color.b + 0.2, "弱點的閃光偏暖")
	assert_true(wf.light_energy > pf.light_energy or pf.light_energy < 0.01, "也比較亮")
	assert_eq(ParticleLook.untextured(weak).size(), 0)
	root.queue_free()
	await tree.process_frame


func test_rapid_hits_do_not_pile_up_and_status_damage_has_no_fx() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[1]
	var src: Node3D = a[2]
	for i: int in 6:
		boss.health.apply_damage(3.0, {"source": src, "stagger": 0.0, "kind": "blunt", "weak": ""})
	assert_eq(boss.hit_fx_count, 6)
	assert_eq(_fx_nodes(root), 6, "每一下一組")
	# 持續扣血（中毒那一類）不走 damaged：不噴
	boss.health.apply_status_damage(2.0, {"status": "poison"})
	assert_eq(boss.hit_fx_count, 6, "狀態傷害不噴")
	# 沒有來源（陷阱、掉落物）也噴得出來：用牠的正面
	boss.health.apply_damage(3.0, {"kind": "fall"})
	assert_eq(boss.hit_fx_count, 7)
	assert_true(boss.last_hit_fx.global_position.is_equal_approx(boss.hit_point(boss.global_position + boss.forward())), "沒有來源：噴在正面")
	await tree.create_timer(EnemyActor.HIT_FLASH_SEC + EnemyActor.HIT_FX_SEC + 0.25).timeout
	assert_eq(_fx_nodes(root), 0, "連打之後全部收掉，不會越積越多")
	# 死了之後再打（apply_damage 回 false）不噴
	boss.health.apply_damage(99999.0, {"source": src, "kind": "blunt"})
	var after_kill: int = boss.hit_fx_count
	assert_false(boss.health.apply_damage(5.0, {"source": src, "kind": "blunt"}), "倒下之後打不到")
	assert_eq(boss.hit_fx_count, after_kill, "倒下之後不再噴")
	root.queue_free()
	await tree.process_frame
