extends TestCase
## 送葬者：招式輪替與距離、各招前兆長度、橫掃／下砸／衝撞命中、撞牆跪地、鐵架關節只在背後露出、
## 追擊版少一招、守衛的噴毒在看穿裡要出現過才列出來、倒下、霧裡的輪廓、前兆的姿勢與地面範圍、鐵鏈。

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


## 追擊的那一隻（D-169、D-205）：少一招（沒有衝撞）、失衡上限比較低，打到殘血輪替也不變；換難度後照樣。
func test_pursuit_drops_charge() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[2]
	boss.global_position = Vector3(0, 0, -30)
	await tree.physics_frame
	boss.begin_pursuit()
	assert_false(boss.brain.pattern.has("charge"), "追擊的那一隻沒有衝撞：%s" % [boss.brain.pattern])
	assert_true(boss.brain.pattern.has("sweep") and boss.brain.pattern.has("slam"), "橫掃與下砸都在")
	assert_true(boss.brain.stagger_max < CombatTuning.num("undertaker.stagger_max", 200.0), "失衡上限比較低")
	var pattern: PackedStringArray = boss.brain.pattern.duplicate()
	boss.health.apply_damage(500.0, {"stagger": 0.0})
	assert_eq(boss.brain.pattern, pattern, "打到殘血輪替不變（沒有第二階段）")
	assert_true(absf(boss.brain.move_num("slam", "telegraph") - 1.0) < 0.001, "下砸前兆也不會縮短")
	var before: String = Settings.difficulty
	Settings.difficulty = "story" if before != "story" else "hard"
	boss._on_settings_changed()
	assert_false(boss.brain.pattern.has("charge"), "換難度後還是沒有衝撞")
	assert_true(boss.brain.stagger_max < CombatTuning.num("undertaker.stagger_max", 200.0), "換難度後失衡上限照舊")
	Settings.difficulty = before
	boss._on_settings_changed()
	assert_true(boss.brain.add_stagger(boss.brain.stagger_max / boss.brain.stagger_mult() + 0.01), "打滿失衡就跪下")
	assert_eq(boss.brain.state_name(), "staggered")
	root.queue_free()
	await tree.process_frame


## 看穿裡「攻略沒寫的招」（intel.json 的 hidden）：一般的送葬者不列噴毒；守衛一開始就列成未證實。
func test_hidden_move_listed_only_for_guardian() -> void:
	TranslationServer.set_locale("zh_TW")
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[2]
	boss.global_position = Vector3(0, 0, -30)
	await tree.physics_frame
	var lines: PackedStringArray = EnemyIntel.lines("undertaker", boss.intel_overrides)
	assert_true(lines.has("招式：鐵架下砸（已證實）"), ", ".join(lines))
	assert_false(", ".join(lines).contains("噴毒"), "沒出現過的招不列：" + ", ".join(lines))
	boss.begin_guardian()
	lines = EnemyIntel.lines("undertaker", boss.intel_overrides)
	assert_true(lines.has("招式：噴毒（未證實？）"), ", ".join(lines))
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
	var shadow: MeshInstance3D = boss.ground_shadow()
	assert_not_null(shadow, "倒地後還有接地陰影")
	if shadow != null:
		var at: Vector3 = shadow.global_position - origin
		assert_true(at.dot(fwd) > 0.8 and shadow.scale.z > 1.5, "接地陰影跟著身體往前、拉長（%.2f m、×%.2f）" % [at.dot(fwd), shadow.scale.z])
		assert_true(shadow.global_position.y < 0.05, "接地陰影仍貼地")
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


## 霧裡的輪廓（D-101）：大衣比霧暗、兜帽冷光只照一小塊且幾乎不進體積霧、
## 鐵架（背上的與擲出去的）用冷色邊緣光＋霜的材質、腳下一片貼地的接地陰影（不跟著身體跪下）。
func test_silhouette_reads_in_fog() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[2]
	boss.global_position = Vector3(0, 0, -4.0)
	await tree.physics_frame
	var coat: CSGCylinder3D = null
	for c: Node in boss._body.get_node("Torso").get_children():
		if c is CSGCylinder3D and coat == null:
			coat = c as CSGCylinder3D
	assert_not_null(coat, "找得到大衣")
	if coat != null:
		var robe: StandardMaterial3D = coat.material as StandardMaterial3D
		assert_true(robe.albedo_color.get_luminance() < 0.08, "大衣夠暗，霧裡看得出深色人形（%.3f）" % robe.albedo_color.get_luminance())
		assert_true(robe.rim_enabled, "大衣保留燈下的邊緣光（D-054）")
	var hood_light: OmniLight3D = boss._body.get_node("Torso/HoodLight") as OmniLight3D
	assert_true(hood_light.omni_range <= 1.5, "兜帽冷光只照兜帽口與胸口（%.1f m）" % hood_light.omni_range)
	assert_true(hood_light.light_volumetric_fog_energy < 0.5, "兜帽冷光不在霧裡亮成一顆光球")
	# 兜帽口：一片黑，霜光點在黑的前面（看得到），冷光在胸口不在兜帽前（不把頭巾照成亮球）
	var void_mi: MeshInstance3D = boss._body.get_node_or_null("Torso/HoodVoid") as MeshInstance3D
	assert_not_null(void_mi, "兜帽口有一片黑")
	if void_mi != null:
		var front_z: float = void_mi.position.z - (void_mi.mesh as SphereMesh).radius * void_mi.scale.z
		var eye: Node3D = boss._body.get_node("Torso/HoodEyeL") as Node3D
		assert_true(eye.position.z < front_z, "霜光點在兜帽口前面（%.3f < %.3f）" % [eye.position.z, front_z])
		assert_true(front_z < -0.32 - 0.26 + 0.005, "兜帽口在頭巾球外面（%.3f）" % front_z)
		assert_true((void_mi.material_override as StandardMaterial3D).albedo_color.get_luminance() < 0.02, "兜帽口是黑的")
	assert_true(hood_light.position.y < 1.2, "冷光照胸口（上身座標 y %.2f）" % hood_light.position.y)
	var frame: Node3D = boss._frame_node()
	assert_not_null(frame, "背上有鐵架")
	var iron_parts: int = 0
	for c: Node in frame.get_children():
		var mat: ShaderMaterial = (c as CSGShape3D).material as ShaderMaterial if c is CSGShape3D else null
		if mat != null and mat.shader.resource_path == Undertaker.FRAME_IRON_SHADER:
			iron_parts += 1
			assert_eq(mat.get_shader_parameter("rim_color"), Undertaker.FROST, "鐵件的邊緣光是霜色")
	assert_eq(iron_parts, frame.get_child_count(), "鐵架每一根都用鐵架材質（%d／%d）" % [iron_parts, frame.get_child_count()])
	var src: String = (load(Undertaker.FRAME_IRON_SHADER) as Shader).code
	assert_true(src.contains("EMISSION") and src.contains("VIEW"), "邊緣光照視角算（越斜越亮）")
	var shadow: MeshInstance3D = boss.ground_shadow()
	assert_not_null(shadow, "腳下有接地陰影")
	if shadow != null:
		assert_eq(shadow.get_parent(), boss, "接地陰影掛在送葬者本身，不跟著身體跪下")
		assert_true(shadow.global_position.y < 0.05 and shadow.global_position.y > 0.0, "貼地、在地面上方一點點")
		assert_eq(shadow.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "不投影")
		var smat: ShaderMaterial = shadow.material_override as ShaderMaterial
		assert_eq(smat.shader.resource_path, Undertaker.GROUND_SHADOW_SHADER, "用接地陰影 shader")
		assert_true(smat.render_priority < 0, "畫在前兆範圍底下")
		var decal: MeshInstance3D = (boss.get("_decals") as Dictionary)["slam"] as MeshInstance3D
		assert_true(decal.position.y > shadow.position.y, "前兆範圍在接地陰影上面")
		# 硬直時身體往下沉，陰影不動
		boss._body.position.y = -0.5
		assert_true(shadow.global_position.y > 0.0, "身體下沉時陰影仍在地面上")
	root.queue_free()
	await tree.process_frame


## 前兆姿勢的方向（D-052 順手修正）：下砸上身後仰、衝撞往前探。頭巾在上身的 (0, 1.45, -0.32)，-Z 是前方。
func test_telegraph_lean_directions() -> void:
	var hood := Vector3(0.0, 1.45, -0.32)
	var rest_z: float = hood.z
	var slam_z: float = (Basis.from_euler(Undertaker.telegraph_lean("slam", 1.0) * (PI / 180.0)) * hood).z
	var charge_z: float = (Basis.from_euler(Undertaker.telegraph_lean("charge", 1.0) * (PI / 180.0)) * hood).z
	assert_true(slam_z > rest_z + 0.2, "下砸：頭往後（%.2f → %.2f）" % [rest_z, slam_z])
	assert_true(charge_z < rest_z - 0.2, "衝撞：低頭往前（%.2f → %.2f）" % [rest_z, charge_z])
	assert_eq(Undertaker.telegraph_lean("sweep", 0.0), Vector3.ZERO, "前兆剛開始沒有姿勢")
	assert_eq(Undertaker.telegraph_lean("unknown", 1.0), Vector3.ZERO)


## 前兆範圍（D-088）：每一招的地面範圍都用 telegraph.gdshader（形狀與大小照招式資料），
## 前兆中只顯示當下那一招，進度從 0 往上長；不再是平塗的色塊。
func test_telegraph_decals_use_shader_and_fill() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var boss: Undertaker = a[2]
	player.global_position = Vector3(0, 0, 0)
	boss.global_position = Vector3(0, 0, -2.0)
	var decals: Dictionary = boss.get("_decals")
	assert_eq(decals.size(), 3, "橫掃、下砸、衝撞（噴毒的圈是守衛才有）")
	var shapes: Dictionary = {"sweep": Undertaker.SHAPE_FAN, "slam": Undertaker.SHAPE_DISC, "charge": Undertaker.SHAPE_LANE}
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
			var cur: MeshInstance3D = decals[boss.brain.move_id] as MeshInstance3D
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


func test_chains_hang_to_ground_and_trail_behind() -> void:
	# 手裡拖著的兩條鐵鏈（D-200）：從手垂到地面附近、地上那段往身後（+Z）拖
	var a: Array = _arena()
	var root: Node3D = a[0]
	var boss: Undertaker = a[2]
	await tree.physics_frame
	for n: String in ["ChainL", "ChainR"]:
		var chain: Node3D = boss.get_node("Body/Torso/" + n) as Node3D
		assert_true(chain.visible, n + " 一開始看得到")
		var hang: MeshInstance3D = chain.get_node("Hang") as MeshInstance3D
		var trail: MeshInstance3D = boss.get_node("Body/ChainTrail" + n.substr(5)) as MeshInstance3D
		var bottom: float = (hang.global_transform * hang.mesh.get_aabb()).position.y - boss.global_position.y
		assert_true(bottom > -0.1 and bottom < 0.12, "%s 垂到地面附近（%.3f）" % [n, bottom])
		var tb: AABB = boss.global_transform.affine_inverse() * (trail.global_transform * trail.mesh.get_aabb())
		assert_true(tb.end.z > Undertaker.CHAIN_TRAIL * 0.8, "%s 地上那段往身後拖" % n)
		assert_true(tb.size.y < 0.12 and tb.position.y > -0.05, "%s 地上那段是躺平的、貼地" % n)
	boss.set_chain_trails(false)
	assert_false((boss.get_node("Body/ChainTrailL") as Node3D).visible, "吊著／倒下時地上那段可以收掉")
	root.queue_free()
	await tree.process_frame
