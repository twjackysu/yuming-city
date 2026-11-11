extends TestCase
## 九息石拱（場景物件）：靠近提示與代價、按住預覽不付代價、放開取消、按滿發動、九息期間有碰撞與去飽和、
## 站在裡面被推出、化灰後記憶已付、讀檔後狀態正確；鐵架拋擲的兩種結局。

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_TW")


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	Input.action_release("nine_breath")


func _world(st: GameState) -> Array:
	var root := Node3D.new()
	tree.root.add_child(root)
	var env := Environment.new()
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(40, 1, 40)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	player.position = Vector3(0, 0, 3)
	root.add_child(player)
	var site := NineBreathSite.new()
	site.state = st
	root.add_child(site)
	return [root, player, site, env]


func test_prompt_preview_and_cancel() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var player: PlayerController = w[1]
	var site: NineBreathSite = w[2]
	player.global_position = Vector3(0, 0, 12)
	await tree.physics_frame
	await tree.physics_frame
	assert_false(site.prompt_shown(), "離太遠不顯示")
	player.global_position = Vector3(0, 0, 3)
	await tree.physics_frame
	await tree.physics_frame
	assert_true(site.prompt_shown(), "走近顯示可保存")
	assert_true(site.prompt_text().contains("可以重現：南街石拱"), site.prompt_text())
	assert_true(site.prompt_text().contains("代價：永遠忘掉和父親在石拱下的最後一次對話"), site.prompt_text())
	Input.action_press("nine_breath")
	for i: int in 20:
		await tree.physics_frame
	assert_true(site.is_previewing(), "按住中：預覽輪廓")
	assert_false(st.has_paid_memory("arch_father_last_talk"), "預覽不付代價")
	Input.action_release("nine_breath")
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(site.hold, 0.0, "放開就取消")
	assert_false(site.is_previewing())
	assert_eq(site.nb.phase, NineBreath.Phase.BROKEN)
	assert_false(st.has_paid_memory("arch_father_last_talk"), "取消不付代價")
	root.queue_free()
	await tree.process_frame


func test_activate_breaths_and_spend() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var site: NineBreathSite = w[2]
	var env: Environment = w[3]
	await tree.physics_frame
	assert_false(site.update_hold(0.5, true), "按住 0.5 秒還沒發動")
	assert_true(site.update_hold(0.55, true), "按滿 1 秒發動")
	assert_true(st.has_paid_memory("arch_father_last_talk"), "付出記憶")
	assert_true(site.is_solid(), "石拱是實體")
	await tree.create_timer(0.7).timeout
	assert_true(env.adjustment_saturation < 0.3, "畫面去飽和（%.2f）" % env.adjustment_saturation)
	# 石拱的柱子擋得住（射線打中）
	await tree.physics_frame
	await tree.physics_frame
	var q := PhysicsRayQueryParameters3D.create(Vector3(-2.2, 1.0, 3.0), Vector3(-2.2, 1.0, -3.0))
	var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(q)
	assert_false(hit.is_empty(), "九息期間有完整碰撞")
	var n: Array[int] = [0]
	site.breath.connect(func(_i: int) -> void: n[0] += 1)
	for i: int in 10:
		site.nb.tick(1.0, st)
	assert_eq(n[0], 9, "九聲心跳")
	assert_eq(site.nb.phase, NineBreath.Phase.SPENT, "化灰")
	assert_false(site.is_solid())
	assert_eq(st.get_flag("ninebreath.south_arch"), "spent")
	await tree.create_timer(1.4).timeout
	assert_true(absf(env.adjustment_saturation - 0.85) < 0.01, "飽和度恢復（%.2f）" % env.adjustment_saturation)
	assert_false(site.update_hold(2.0, true), "化灰後不能再發動")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


## D-178：停用的石拱（第 1 章白天回到南街）——站在旁邊也沒有提示、地上的圈不亮、按住或直接呼叫都不會發動、不付記憶。
func test_dormant_site_cannot_restore() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var site: NineBreathSite = w[2]
	await tree.physics_frame
	await tree.physics_frame
	assert_true(site.is_usable(), "平常走近就能重現")
	assert_true(site.ring_visible(), "地上的圈亮著")
	assert_true(site.prompt_shown(), "站在 3 m 內：有提示")
	Input.action_press("nine_breath")
	for i: int in 4:
		await tree.physics_frame
	assert_true(site.is_previewing(), "按住中：預覽")
	site.set_dormant(true)
	assert_false(site.is_usable(), "停用之後不能重現")
	assert_false(site.prompt_shown(), "提示收掉")
	assert_false(site.ring_visible(), "地上的圈不亮")
	assert_false(site.is_previewing(), "預覽取消")
	assert_eq((tree.root.get_node("Game").get("journal") as Journal).highlighted, "", "日記不再標亮")
	for i: int in 70:
		await tree.physics_frame
	assert_false(site.prompt_shown(), "一直按著也沒有提示")
	assert_false(site.update_hold(NineBreathSite.HOLD_SEC + 0.5, true), "按滿也不會發動")
	assert_false(site.activate(), "直接呼叫也不會發動")
	assert_eq(site.nb.phase, NineBreath.Phase.BROKEN)
	assert_false(st.has_paid_memory("arch_father_last_talk"), "不付記憶")
	Input.action_release("nine_breath")
	root.queue_free()
	await tree.process_frame


func test_push_out_and_reload() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var player: PlayerController = w[1]
	var site: NineBreathSite = w[2]
	await tree.physics_frame
	player.global_position = Vector3(-2.0, 0.0, 0.2)
	site.activate()
	assert_true(player.global_position.z >= 1.3, "站在柱子裡被推出去（z=%.2f）" % player.global_position.z)
	# 九息中間存的檔：讀回來視為已化灰（代價已付、不能再發動）
	var loaded := GameState.from_dict(st.to_dict())
	root.queue_free()
	await tree.process_frame
	var w2: Array = _world(loaded)
	var root2: Node3D = w2[0]
	var site2: NineBreathSite = w2[2]
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(site2.nb.phase, NineBreath.Phase.SPENT, "讀檔後是化灰")
	assert_false(site2.is_solid())
	assert_false(site2.prompt_shown(), "化灰後沒有提示")
	assert_true(loaded.has_paid_memory("arch_father_last_talk"))
	root2.queue_free()
	await tree.process_frame


## 重現的石拱（D-043）：跟石牆同一個 shader、石縫發冷光；心跳時亮一下再退回。房子外牆不發光。
func test_restored_arch_is_glowing_stone() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var site: NineBreathSite = w[2]
	await tree.physics_frame
	assert_true(site.activate(), "發動")
	var arch: CSGCombiner3D = site.get_node("Arch") as CSGCombiner3D
	var mat: ShaderMaterial = arch.material_override as ShaderMaterial
	assert_not_null(mat, "石拱用 ShaderMaterial")
	assert_eq(mat.shader.resource_path, FrostbridgeLook.HALF_TIMBER_SHADER, "跟鎮上石牆同一個 shader")
	assert_true(float(mat.get_shader_parameter("glow_energy")) > 0.0, "石縫發光")
	var wall: ShaderMaterial = FrostbridgeLook.new().stone_wall()
	assert_eq(wall.get_shader_parameter("glow_energy"), null, "石牆沒設發光（用 shader 預設 0）")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


## 石拱的形狀（D-129）：拱洞是圓的（不是 8 邊形）、一圈單數的拱石正中是拱心石、
## 拱石凸出牆面（前後對稱）、整座不超過 4.6 m（預覽 shader 的 height）。
func test_arch_has_round_vault_and_voussoirs() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var site: NineBreathSite = w[2]
	await tree.physics_frame
	var arch: CSGCombiner3D = site.get_node("Arch") as CSGCombiner3D
	var hole: CSGCylinder3D = null
	var stones: int = 0
	for c: Node in arch.get_children():
		if c is CSGCylinder3D:
			hole = c as CSGCylinder3D
		if c is CSGPolygon3D:
			stones += 1
	assert_not_null(hole, "拱洞")
	assert_true(hole.sides >= 32, "拱洞夠圓")
	assert_eq(stones, NineBreathSite.VOUSSOIRS, "一圈拱石")
	assert_eq(NineBreathSite.VOUSSOIRS % 2, 1, "單數：正中是拱心石")
	assert_not_null(arch.get_node_or_null("Keystone"), "拱心石")
	site.activate()
	await tree.process_frame
	await tree.process_frame
	var meshes: Array = arch.get_meshes()
	assert_eq(meshes.size(), 2, "CSG 算出網格")
	var box: AABB = (meshes[1] as Mesh).get_aabb()
	assert_true(box.end.y <= 4.6 + 0.01, "不超過 4.6 m：%s" % box)
	var half: float = NineBreathSite.WALL_DEPTH * 0.5
	assert_true(box.position.z < -half - 0.05 and box.end.z > half + 0.05, "拱石凸出前後兩面：%s" % box)
	assert_true(absf(box.position.z + box.end.z) < 0.02, "前後對稱：%s" % box)
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


## 拱石的放射縫（D-132）：重現後的石頭與預覽輪廓都拿到拱圈的形狀（跟幾何同一組常數），
## 鎮上的石牆沒有拱圈（shader 預設 0）。
func test_arch_shaders_get_voussoir_ring() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var site: NineBreathSite = w[2]
	await tree.physics_frame
	var arch: CSGCombiner3D = site.get_node("Arch") as CSGCombiner3D
	site.update_hold(0.1, true)
	var ghost: ShaderMaterial = arch.material_override as ShaderMaterial
	site.update_hold(0.1, false)
	assert_true(site.activate(), "發動")
	var stone: ShaderMaterial = arch.material_override as ShaderMaterial
	assert_true(ghost != stone, "預覽與重現是兩個材質")
	for m: ShaderMaterial in [ghost, stone]:
		assert_eq(int(m.get_shader_parameter("arch_voussoirs")), NineBreathSite.VOUSSOIRS, "拱石塊數")
		assert_eq(m.get_shader_parameter("arch_center"), Vector2(0.0, NineBreathSite.ARCH_SPRING), "拱心在拱腳高度")
		assert_true(is_equal_approx(float(m.get_shader_parameter("arch_inner")), NineBreathSite.ARCH_INNER), "內緣＝拱洞")
		assert_true(is_equal_approx(float(m.get_shader_parameter("arch_outer")), NineBreathSite.ARCH_OUTER), "外緣")
		assert_true(is_equal_approx(float(m.get_shader_parameter("arch_key_extra")), NineBreathSite.KEYSTONE_RISE), "拱心石高一點")
	var keystone: CSGPolygon3D = arch.get_node("Keystone") as CSGPolygon3D
	var reach: float = 0.0
	for p: Vector2 in keystone.polygon:
		reach = maxf(reach, p.distance_to(Vector2(0.0, NineBreathSite.ARCH_SPRING)))
	assert_true(is_equal_approx(reach, NineBreathSite.ARCH_OUTER + NineBreathSite.KEYSTONE_RISE), "幾何與 shader 同一組數字：%f" % reach)
	var wall: ShaderMaterial = FrostbridgeLook.new().stone_wall()
	assert_eq(wall.get_shader_parameter("arch_voussoirs"), null, "石牆沒有拱圈（用 shader 預設 0）")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


## 預覽輪廓（D-046）：按住時用 restore_ghost shader，fill 跟著按住的進度從 0 往上長；放開就藏起來。
func test_preview_ghost_grows_with_hold() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var site: NineBreathSite = w[2]
	await tree.physics_frame
	site.update_hold(0.25, true)
	var arch: CSGCombiner3D = site.get_node("Arch") as CSGCombiner3D
	var ghost: ShaderMaterial = arch.material_override as ShaderMaterial
	assert_not_null(ghost, "預覽用 ShaderMaterial")
	assert_eq(ghost.shader.resource_path, NineBreathSite.GHOST_SHADER)
	assert_true(is_equal_approx(float(ghost.get_shader_parameter("fill")), 0.25 / NineBreathSite.HOLD_SEC), "長到 1/4")
	site.update_hold(0.25, true)
	assert_true(is_equal_approx(float(ghost.get_shader_parameter("fill")), 0.5 / NineBreathSite.HOLD_SEC), "長到一半")
	site.update_hold(0.1, false)
	assert_false(arch.visible, "放開：預覽消失")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


## 暫停（M1.4）：暫停中重現的倒數與傷者車隊都不推進，解除後繼續。
func test_pause_freezes_restoration_and_caravan() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var site: NineBreathSite = w[2]
	var caravan := Caravan.new()
	caravan.route = PackedVector3Array([Vector3(6, 0, 0), Vector3(6, 0, -20)])
	root.add_child(caravan)
	await tree.physics_frame
	assert_true(site.activate())
	await tree.physics_frame
	tree.paused = true
	var t0: float = site.nb.elapsed
	var d0: float = caravan.runner.traveled
	for i: int in 10:
		await tree.physics_frame
	assert_eq(site.nb.elapsed, t0, "暫停中倒數不動")
	assert_eq(caravan.runner.traveled, d0, "暫停中車隊不動")
	tree.paused = false
	for i: int in 3:
		await tree.physics_frame
	assert_true(site.nb.elapsed > t0, "解除後倒數繼續")
	assert_true(caravan.runner.traveled > d0 or caravan.runner.is_stopped(), "解除後車隊繼續")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame
