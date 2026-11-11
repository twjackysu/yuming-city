extends TestCase
## 下砸落地的那一下（D-218）：落點一圈往外推的雪塵、中間一團、彈起來的碎石、地上的砸痕。
## 掛在關卡上（牠走開、倒下都不會帶著走），砸痕留幾秒就淡掉、整組收掉——連砸不會越積越多。
## 出招的那一下上身往前壓，收招時慢慢直起來。


func _arena() -> Array:
	var root := Node3D.new()
	tree.root.add_child(root)
	var boss := Undertaker.new()
	root.add_child(boss)
	boss.global_position = Vector3(2.0, 0.0, -3.0)
	boss.set_physics_process(false)
	return [root, boss]


func _fx_nodes(root: Node) -> int:
	var n: int = 0
	for c: Node in root.get_children():
		if str(c.name).begins_with("SlamFx") and not c.is_queued_for_deletion():
			n += 1
	return n


func test_slam_strike_leaves_ring_plume_chunks_and_scar_at_the_impact() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[1]
	boss.brain._set_move("slam")
	boss.brain.state = EnemyBrain.State.STRIKE
	assert_eq(boss.slam_fx_count, 0)
	boss._on_strike()
	assert_eq(boss.slam_fx_count, 1, "砸一下就一組")
	var fx: Node3D = boss.last_slam_fx
	assert_not_null(fx, "落地的那一組")
	if fx == null:
		root.queue_free()
		await tree.process_frame
		return
	assert_eq(fx.get_parent(), root, "掛在關卡上，不是牠身上")
	var center: Vector3 = boss.slam_center()
	var off: Vector3 = fx.global_position - center
	assert_true(Vector2(off.x, off.z).length() < 0.01, "在落點（牠前面 %.1f m）" % boss.brain.move_num("slam", "reach", 1.9))
	assert_true(off.y > 0.0 and off.y < 0.1, "貼著地、比前兆的霜紋高一點（不閃爍）")
	var radius: float = boss.brain.move_num("slam", "radius", 2.0)
	var ring: CPUParticles3D = fx.get_node_or_null("Ring") as CPUParticles3D
	assert_not_null(ring, "一圈雪塵")
	if ring != null:
		assert_true(ring.one_shot and ring.emitting and ring.explosiveness > 0.95, "一次噴完")
		assert_eq(ring.emission_shape, CPUParticles3D.EMISSION_SHAPE_RING, "從一圈上出發")
		assert_true(ring.emission_ring_radius < radius * 0.5, "從落點附近出發，不是一開始就在外圈")
		assert_true(ring.radial_accel_min > 5.0 and ring.initial_velocity_max == 0.0, "往外推（不是亂飛）")
		assert_not_null(ring.radial_accel_curve, "只推一開始那一下")
		assert_true(ring.damping_min > 1.0, "推完靠阻力停住")
		assert_true(absf(ring.gravity.y) < 1.5, "貼著地，不往上衝也不往下掉")
		# D-208：粒子是在節點擺到落點之後才開始噴的
		assert_true(ring.global_position.is_equal_approx(fx.global_position))
	var plume: CPUParticles3D = fx.get_node_or_null("Plume") as CPUParticles3D
	assert_not_null(plume, "中間往上湧的一團")
	if plume != null:
		assert_true(plume.emitting and plume.direction.y > 0.9 and plume.initial_velocity_max > 2.0, "往上")
		assert_true(plume.color.a < 0.7 and plume.amount >= 24, "很多顆很淡的疊成一團（不是幾顆實心的泡泡）")
	var chunks: CPUParticles3D = fx.get_node_or_null("Chunks") as CPUParticles3D
	assert_not_null(chunks, "碎石")
	if chunks != null:
		assert_true(chunks.one_shot and chunks.emitting, "一次彈起來")
		assert_true(chunks.gravity.y < -9.0 and chunks.initial_velocity_max > 5.0, "彈得起來、掉得回去")
		assert_true(chunks.mesh is SphereMesh and (chunks.mesh as SphereMesh).radial_segments <= 6, "是有稜角的小石塊，不是面片圓點")
		assert_true((chunks.mesh as SphereMesh).radius * 2.0 * chunks.scale_amount_max < 0.2, "最大的一顆不到 20 cm（不會像一口飛起來的箱子）")
		var rock: StandardMaterial3D = chunks.mesh.surface_get_material(0) as StandardMaterial3D
		assert_true(rock != null and rock.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED, "吃場景的光（暗處不會自己亮）")
		assert_true(rock != null and rock.albedo_color.v < 0.35, "深色的石頭")
	assert_eq(ParticleLook.untextured(fx).size(), 0, "粒子都有貼圖")
	if ring != null:
		var dust: StandardMaterial3D = ring.mesh.surface_get_material(0) as StandardMaterial3D
		assert_true(dust != null and dust.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and dust.backlight_enabled, "雪塵吃場景的光、逆光時透光（不是自己發亮的白點）")
		assert_true(dust != null and dust.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED and dust.albedo_color.a < 0.6, "面向鏡頭、每一顆很淡")
	var scar: MeshInstance3D = fx.get_node_or_null("Scar") as MeshInstance3D
	assert_not_null(scar, "地上的砸痕")
	if scar != null:
		var quad: QuadMesh = scar.mesh as QuadMesh
		assert_true(quad != null and quad.orientation == PlaneMesh.FACE_Y, "平貼在地上")
		assert_true(quad != null and quad.size.x <= radius * 2.0 and quad.size.x >= radius, "比傷害範圍小一點")
		var mat: ShaderMaterial = scar.material_override as ShaderMaterial
		assert_true(mat != null and mat.shader != null, "形狀在 shader 裡畫")
		assert_true(absf(float(mat.get_shader_parameter("fade")) - 1.0) < 0.001)
		assert_eq(scar.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	root.queue_free()
	await tree.process_frame


func test_scar_fades_and_the_whole_group_frees_itself() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[1]
	boss.slam_scar_hold_sec = 0.02
	boss.slam_scar_fade_sec = 0.3
	var fx: Node3D = boss._slam_fx(boss.global_position + boss.forward() * 1.9, 2.0)
	assert_not_null(fx)
	assert_eq(_fx_nodes(root), 1)
	var mat: ShaderMaterial = (fx.get_node("Scar") as MeshInstance3D).material_override as ShaderMaterial
	await tree.create_timer(0.17).timeout
	assert_true(is_instance_valid(fx), "還在淡，還沒收")
	if is_instance_valid(fx):
		var fade: float = float(mat.get_shader_parameter("fade"))
		assert_true(fade < 0.95 and fade > 0.0, "淡到一半（%.2f）" % fade)
	await tree.create_timer(0.3).timeout
	await tree.process_frame
	assert_eq(_fx_nodes(root), 0, "淡完就收掉")
	boss.slam_scar_hold_sec = 0.05
	boss.slam_scar_fade_sec = 0.1
	# 連砸：每一下各一組，不共用、也不留下來
	for i: int in 3:
		boss._slam_fx(boss.global_position + boss.forward() * 1.9, 2.0)
	assert_eq(boss.slam_fx_count, 4)
	assert_eq(_fx_nodes(root), 3)
	await tree.create_timer(0.3).timeout
	await tree.process_frame
	assert_eq(_fx_nodes(root), 0, "三組都收掉了")
	root.queue_free()
	await tree.process_frame


func test_debug_hold_keeps_the_scar_for_screenshots() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[1]
	boss.slam_scar_hold_sec = 0.02
	boss.slam_scar_fade_sec = 0.02
	boss.debug_hold_slam = true
	var fx: Node3D = boss._slam_fx(boss.global_position, 2.0)
	await tree.create_timer(0.12).timeout
	assert_true(is_instance_valid(fx) and not fx.is_queued_for_deletion(), "截圖用：不收")
	root.queue_free()
	await tree.process_frame


func test_other_moves_do_not_leave_a_scar() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[1]
	boss.brain._set_move("sweep")
	boss.brain.state = EnemyBrain.State.STRIKE
	boss._on_strike()
	assert_eq(boss.slam_fx_count, 0, "橫掃不砸地")
	assert_eq(_fx_nodes(root), 0)
	root.queue_free()
	await tree.process_frame


func test_torso_presses_forward_on_the_strike_and_rises_during_recover() -> void:
	var strike: Vector3 = Undertaker.slam_follow_lean(false, 0.0, 0.6)
	assert_true(signf(strike.x) == signf(EnemyActor.FALL_FORWARD) and absf(strike.x) > 15.0, "打下去：上身往前壓（%s）" % str(strike))
	var back: Vector3 = Undertaker.telegraph_lean("slam", 1.0)
	assert_true(signf(back.x) == -signf(EnemyActor.FALL_FORWARD), "前兆是後仰，方向相反")
	var prev: float = absf(strike.x)
	for i: int in 7:
		var lean: Vector3 = Undertaker.slam_follow_lean(true, 0.1 * float(i), 0.6)
		assert_true(absf(lean.x) <= prev + 0.001, "收招時一路直起來，不會又往下壓")
		prev = absf(lean.x)
	assert_true(absf(Undertaker.slam_follow_lean(true, 0.6, 0.6).x - 0.0) < 0.001, "收招結束時站直")
	assert_true(absf(Undertaker.slam_follow_lean(true, 5.0, 0.6).x - 0.0) < 0.001)
	# 掛在牠身上：出招那一幀上身真的往前
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[1]
	boss.brain._set_move("slam")
	boss.brain.state = EnemyBrain.State.STRIKE
	boss._update_look()
	var torso: Node3D = boss.get_node("Body/Torso") as Node3D
	assert_true(signf(torso.rotation_degrees.x) == signf(EnemyActor.FALL_FORWARD) and absf(torso.rotation_degrees.x) > 15.0, "上身往前壓")
	boss.brain._set_move("sweep")
	boss._update_look()
	assert_true(absf(torso.rotation_degrees.x - 0.0) < 0.001, "別的招式不受影響")
	root.queue_free()
	await tree.process_frame
