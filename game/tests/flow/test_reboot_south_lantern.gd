extends TestCase
## 南街的吊燈（D-216）：守衛戰的主光。牠從南端走過來時先從燈底下穿過，站在街上開打時燈在牠背後——
## 亮的石板與暖霧前面一個黑剪影。這裡驗的是「燈真的掛在那裡」：鏈子兩端釘在牆上、往中間垂、燈比牠高、
## 位置在牠出場的路上；舊版沒有這盞燈。畫面好不好看用 `scripts/shots.sh rb_guardian` 看。

const PATH: String = "res://scenes/levels/frostbridge.tscn"

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_rb_lantern_%d" % Time.get_ticks_usec()
	_original = tree.root.get_node("Game").get("session") as GameSession


func after_each() -> void:
	tree.root.get_node("Game").set("session", _original)
	for d: String in [_dir, _dir + "_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)


func _session(reboot: bool) -> GameSession:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	if reboot:
		s.new_reboot_game()
		RebootOpening.dev_advance(s, "guardian")
	else:
		s.new_game()
	return s


func _load() -> StoryLevel:
	var level: StoryLevel = (load(PATH) as PackedScene).instantiate() as StoryLevel
	tree.root.add_child(level)
	await tree.physics_frame
	return level


func test_lantern_hangs_on_a_chain_between_the_walls() -> void:
	_session(true)
	var level: StoryLevel = await _load()
	await tree.physics_frame
	var n: Node3D = level.get_node_or_null("RbSouthLantern") as Node3D
	assert_not_null(n, "南街的吊燈")
	if n == null:
		level.queue_free()
		await tree.process_frame
		return
	assert_true(is_equal_approx(n.position.z, RebootOpening.SOUTH_LANTERN_Z) and absf(n.position.x) < 0.001, "掛在街心上方")
	# 鏈子：兩端在牆邊同一個高度，往中間垂，一段接一段沒有斷
	var spans: int = RebootOpening.SOUTH_LANTERN_SPANS
	var first: Vector3 = RebootOpening.south_chain_point(0)
	var last: Vector3 = RebootOpening.south_chain_point(spans)
	var mid: Vector3 = RebootOpening.south_chain_point(spans / 2)
	assert_true(is_equal_approx(first.x, -RebootOpening.SOUTH_LANTERN_HALF) and is_equal_approx(last.x, RebootOpening.SOUTH_LANTERN_HALF), "從西牆拉到東牆")
	assert_true(is_equal_approx(first.y, last.y) and is_equal_approx(first.y, RebootOpening.SOUTH_LANTERN_ANCHOR_Y), "兩端一樣高")
	assert_true(is_equal_approx(mid.y, first.y - RebootOpening.SOUTH_LANTERN_SAG) and absf(mid.x) < 0.001, "最低點在街心")
	for i: int in spans:
		var span: MeshInstance3D = n.get_node_or_null("Chain%d" % i) as MeshInstance3D
		assert_not_null(span, "第 %d 段鏈子" % i)
		if span == null:
			continue
		var a: Vector3 = RebootOpening.south_chain_point(i)
		var b: Vector3 = RebootOpening.south_chain_point(i + 1)
		assert_true(span.position.is_equal_approx(a), "第 %d 段從上一段的尾端開始" % i)
		# ChainMesh 往 -Y 垂：轉過之後 -Y 指向下一個節點
		assert_true((span.basis * Vector3.DOWN).normalized().dot((b - a).normalized()) > 0.999, "第 %d 段指向下一個節點" % i)
		var aabb: AABB = span.mesh.get_aabb()
		assert_true(aabb.size.y >= a.distance_to(b) - 0.001, "第 %d 段夠長（接得上）" % i)
	# 兩端真的釘在牆上（不是懸在兩棟房子之間的空隙）：從街心往兩邊打，牆就在鐵座的位置
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	for side: float in [-1.0, 1.0]:
		var from := Vector3(0.0, RebootOpening.SOUTH_LANTERN_ANCHOR_Y, RebootOpening.SOUTH_LANTERN_Z)
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(side * 8.0, 0.0, 0.0))
		var hit: Dictionary = space.intersect_ray(q)
		assert_true(not hit.is_empty(), "鏈子的高度兩邊都有牆（%s）" % ("西" if side < 0.0 else "東"))
		if not hit.is_empty():
			var wall_x: float = absf((hit["position"] as Vector3).x)
			assert_true(absf(wall_x - RebootOpening.SOUTH_LANTERN_HALF) < 0.25, "鐵座貼在牆面上（牆 %.2f）" % wall_x)
	# 燈：暖色、投影子、在霧裡夠亮；燈的底比守衛（連背上的鐵架 3.2 m）高，牠從底下走得過去
	var light: OmniLight3D = n.get_node_or_null("Glow") as OmniLight3D
	assert_not_null(light, "燈光")
	var lamp: Node3D = n.get_node_or_null("Lamp") as Node3D
	assert_not_null(lamp, "燈")
	if light != null and lamp != null:
		assert_true(light.shadow_enabled, "守衛戰的主光：牠的影子往諾恩這邊拉長")
		assert_true(light.light_color.r > light.light_color.b + 0.3, "暖色（跟毒霧的綠、兜帽的冷光分得開）")
		assert_true(light.light_energy >= 3.0 and light.light_volumetric_fog_energy >= 2.0, "在霧裡夠亮（剪影靠這團暖霧）")
		assert_true(light.omni_range >= RebootOpening.SOUTH_LANTERN_Z - RebootOpening.GUARDIAN_MEET.z, "照得到牠站定的地方")
		var bottom: float = 999.0
		for part: Node in lamp.get_children():
			var mi: MeshInstance3D = part as MeshInstance3D
			assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "燈自己不擋自己的光")
			bottom = minf(bottom, lamp.position.y + mi.position.y - mi.mesh.get_aabb().size.y * 0.5)
		assert_true(bottom > 3.2 + 0.3, "燈底（%.2f）比守衛背上的鐵架高" % bottom)
		assert_true(absf(light.position.y - (lamp.position.y - 0.44)) < 0.01, "光源在玻璃裡")
	# 位置：在牠出場的路上（出生點 → 燈 → 站定點），所以開打時燈在牠背後
	assert_true(RebootOpening.GUARDIAN_SPAWN.z > RebootOpening.SOUTH_LANTERN_Z, "牠從燈的南邊出來")
	assert_true(RebootOpening.SOUTH_LANTERN_Z - RebootOpening.GUARDIAN_MEET.z >= 4.0, "站定時燈在牠背後 4 m 以上")
	level.queue_free()
	await tree.process_frame


func test_classic_version_has_no_south_lantern() -> void:
	_session(false)
	var level: StoryLevel = await _load()
	assert_false(level.has_node("RbSouthLantern"), "舊版的南街照舊（沒有吊燈）")
	level.queue_free()
	await tree.process_frame
