extends TestCase
## 看穿與弱點：資料、文字（已證實／未證實）、弱點露出的方向、前兆／破綻失衡倍率、
## 場景內按住看穿顯示資訊、從左側打中左膝傷害加倍。

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	Input.action_release("insight")


func test_intel_lines_zh_and_en() -> void:
	TranslationServer.set_locale("zh_TW")
	var zh: PackedStringArray = EnemyIntel.lines("ashwalker")
	assert_eq(zh[0], "灰巡者")
	assert_eq(zh[1], "弱點：左膝（已證實）")
	assert_eq(zh[2], "招式：爪擊（已證實）")
	TranslationServer.set_locale("en")
	var en: PackedStringArray = EnemyIntel.lines("ashwalker")
	assert_eq(en[1], "Weak point: Left knee (confirmed)")


func test_intel_override_and_current_move() -> void:
	TranslationServer.set_locale("zh_TW")
	var l: PackedStringArray = EnemyIntel.lines("ashwalker", {"claw": false}, "claw")
	assert_eq(l[2], "▶ 招式：爪擊（未證實？）", "覆寫成未證實＋正在出的招")
	assert_eq(EnemyIntel.lines("no_such_enemy")[0], "未知——攻略沒寫")


func test_exposed_arc_left_side() -> void:
	var arc := Vector2(25, 155)
	var fwd := Vector3(0, 0, -1)
	assert_true(EnemyIntel.is_exposed(Vector3.ZERO, fwd, Vector3(-2, 0, 0), arc), "敵人面向 -Z，左側是 -X")
	assert_false(EnemyIntel.is_exposed(Vector3.ZERO, fwd, Vector3(2, 0, 0), arc), "右側打不到左膝")
	assert_false(EnemyIntel.is_exposed(Vector3.ZERO, fwd, Vector3(0, 0, -2), arc), "正面打不到")
	assert_true(EnemyIntel.is_exposed(Vector3.ZERO, fwd, Vector3(-1, 0, -1), arc), "左前方 45° 打得到")
	assert_eq(EnemyIntel.arc_of({}), Vector2(-180, 180), "沒寫範圍＝任何方向")


func test_stagger_multipliers_by_state() -> void:
	var b := EnemyBrain.new().configure("ashwalker")
	assert_eq(b.stagger_mult(), 1.0)
	b.tick(0.1, 10.0)
	b.tick(0.1, 1.0)
	assert_eq(b.state_name(), "telegraph")
	assert_eq(b.current_move(), "claw")
	b.add_stagger(20.0)
	assert_eq(b.stagger, 10.0, "前兆中硬撐：失衡 ×0.5")
	b.tick(0.8, 1.0)
	b.tick(0.2, 1.0)
	assert_eq(b.state_name(), "recover")
	assert_true(b.is_open(), "出招後是破綻")
	assert_eq(b.current_move(), "")
	assert_true(b.add_stagger(25.0), "破綻中 ×2：10＋50 滿 60 跪地")
	assert_true(b.is_open(), "跪地也是破綻")


func _arena() -> Array:
	var root := Node3D.new()
	tree.root.add_child(root)
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(20, 1, 20)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	var walker := Ashwalker.new()
	root.add_child(walker)
	return [root, player, walker]


func test_insight_shows_and_hides_in_scene() -> void:
	TranslationServer.set_locale("zh_TW")
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var walker: Ashwalker = a[2]
	walker.global_position = player.global_position + Vector3(0, 0, -6)
	await tree.physics_frame
	assert_false(walker.insight_shown(), "沒按看穿不顯示")
	Input.action_press("insight")
	await tree.physics_frame
	await tree.physics_frame
	assert_true(player.insight_active)
	assert_true(walker.insight_shown(), "按住看穿顯示")
	assert_true(walker.insight_text().contains("弱點：左膝（已證實）"), "顯示已知弱點：" + walker.insight_text())
	Input.action_release("insight")
	await tree.physics_frame
	await tree.physics_frame
	assert_false(walker.insight_shown(), "放開就收起")
	root.queue_free()
	await tree.process_frame


func test_strike_from_left_hits_knee() -> void:
	var a: Array = _arena()
	var root: Node3D = a[0]
	var player: PlayerController = a[1]
	var walker: Ashwalker = a[2]
	walker.set_physics_process(false)  # 不讓牠轉身，固定面向 -Z
	walker.global_position = Vector3(0, 0, 0)
	# 諾恩站在灰巡者左側（-X），面向牠（+X）
	player.global_position = Vector3(-1.2, 0, 0)
	player.get_node("Body").rotation.y = -PI / 2.0
	await tree.physics_frame
	assert_eq(walker.weakpoint_exposed_to(player.global_position), "left_knee")
	var hp0: float = walker.health.hp
	assert_eq(player.strike(), 1)
	assert_eq(player.last_weak_hits, 1, "左側打中左膝")
	assert_eq(walker.health.hp, hp0 - 12.0, "鈍擊 6 ×2")
	assert_eq(walker.brain.stagger, 40.0, "失衡 20 ×2")
	# 換到右側（+X），面向 -X：一般命中
	player.global_position = Vector3(1.2, 0, 0)
	player.get_node("Body").rotation.y = PI / 2.0
	await tree.physics_frame
	assert_eq(player.strike(), 1)
	assert_eq(player.last_weak_hits, 0, "右側打不到左膝")
	assert_eq(walker.health.hp, hp0 - 18.0)
	assert_true(walker.brain.state == EnemyBrain.State.STAGGERED, "40＋20 滿 60 跪地")
	assert_eq(walker.weakpoint_exposed_to(player.global_position), "left_knee", "跪地時弱點全露")
	root.queue_free()
	await tree.process_frame
	Engine.time_scale = 1.0
