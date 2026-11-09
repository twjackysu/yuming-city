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


## 看穿小卡（第二輪盤點第 3 項，D-087）：分列資料、名字＋細線＋兩段、已證實的小勾、未證實的淡字、正在出的招變暖金色。
func test_intel_rows_and_card_layout() -> void:
	TranslationServer.set_locale("zh_TW")
	var rows: Array[Dictionary] = EnemyIntel.rows("ashwalker", {"claw": false}, "claw")
	assert_eq(rows.size(), 3, "名字、弱點、招式")
	assert_eq(str(rows[0]["kind"]), "name")
	assert_eq(str(rows[0]["text"]), "灰巡者")
	assert_eq(str(rows[1]["kind"]), "weak")
	assert_eq(str(rows[1]["text"]), "左膝", "不含「（已證實）」")
	assert_true(bool(rows[1]["verified"]))
	assert_eq(str(rows[2]["kind"]), "move")
	assert_false(bool(rows[2]["verified"]), "overrides 改成未證實")
	assert_true(bool(rows[2]["current"]), "正在出的招")
	assert_eq(str(EnemyIntel.rows("nobody")[0]["kind"]), "unknown")
	var card := InsightCard.new()
	tree.root.add_child(card)
	card.set_rows(rows)
	var box: VBoxContainer = card.get_node("Rows") as VBoxContainer
	var kinds: PackedStringArray = []
	for c: Node in box.get_children():
		kinds.append(str(c.name))
	assert_true(box.get_child(0) is Label and (box.get_child(0) as Label).text == "灰巡者", "第一行是名字")
	assert_true(box.get_child(1) is ColorRect, "名字下面一條細線")
	assert_true(box.get_node_or_null("Section_weak") != null and box.get_node_or_null("Section_move") != null, "弱點、招式兩段小標題：%s" % ", ".join(kinds))
	assert_eq((box.get_node("Section_weak") as Label).text, "弱點")
	assert_eq(card.check_count(), 1, "只有已證實的左膝有小勾")
	var unverified: Array[Node] = card.find_children("Unverified", "Label", true, false)
	assert_eq(unverified.size(), 1, "未證實的招式後面一段淡字")
	assert_eq((unverified[0] as Label).text, "（未證實？）")
	var texts: Array[Node] = card.find_children("Text", "Label", true, false)
	assert_eq(texts.size(), 2)
	var cur: Label = texts[1] as Label
	assert_true(cur.get_theme_color("font_color").is_equal_approx(InsightCard.WARM), "正在出的招是暖金色")
	var before: int = box.get_child_count()
	card.set_rows(EnemyIntel.rows("ashwalker", {"claw": false}, "claw"))
	await tree.process_frame
	assert_eq(box.get_child_count(), before, "內容一樣不重建")
	TranslationServer.set_locale("en")
	card.set_rows(EnemyIntel.rows("ashwalker"))
	await tree.process_frame
	assert_eq((box.get_node("Section_weak") as Label).text, "Weak point")
	assert_eq(card.check_count(), 2, "全部已證實：兩個小勾")
	card.queue_free()
	await tree.process_frame


## 場景裡按住看穿：小卡出現在畫面內（敵人頭頂右上方），放開收起；不再有浮在頭上的 3D 字。
func test_insight_card_on_screen_in_scene() -> void:
	TranslationServer.set_locale("zh_TW")
	var a: Array = _arena()
	var root3d: Node3D = a[0]
	var player: PlayerController = a[1]
	var walker: Ashwalker = a[2]
	walker.global_position = player.global_position + Vector3(0, 0, -6)
	assert_eq(walker.find_children("*", "Label3D", true, false).size(), 0, "敵人頭上沒有 3D 字")
	Input.action_press("insight")
	for i: int in 3:
		await tree.physics_frame
	var card: InsightCard = walker.insight_card()
	assert_true(card.visible, "按住看穿：小卡出現")
	assert_true(card.rows_shown.size() >= 3, "名字、弱點、招式")
	var rect: Rect2 = card.get_viewport_rect()
	assert_true(rect.encloses(Rect2(card.position, card.size)), "小卡整張在畫面內：%s / %s" % [Rect2(card.position, card.size), rect])
	var cam: Camera3D = card.get_viewport().get_camera_3d()
	var head: Vector2 = cam.unproject_position(walker.global_position + Vector3(0, 2.0, 0))
	assert_true(card.position.x > head.x - 1.0, "小卡在敵人頭的右邊（%.0f vs %.0f）" % [card.position.x, head.x])
	# D-146：小卡左緣不蓋進敵人身體右緣（insight_side 公尺沿鏡頭右方的投影）
	var edge: Vector2 = cam.unproject_position(walker.global_position + Vector3(0, 2.0, 0) + cam.global_transform.basis.x * walker.insight_side())
	assert_true(card.position.x >= edge.x + InsightCard.EDGE_GAP - 1.0, "小卡讓開身體右緣（%.0f vs %.0f）" % [card.position.x, edge.x])
	Input.action_release("insight")
	for i: int in 2:
		await tree.physics_frame
	assert_false(card.visible, "放開就收起")
	root3d.queue_free()
	await tree.process_frame


## 第八輪盤點第 8 項（D-146）：小卡的位置不只是頭頂＋固定位移——敵人越寬（送葬者背上的鐵架）、離鏡頭越近，
## 卡片越往右讓開；寬度 0 時跟原本一樣。送葬者比灰巡者寬。
func test_card_anchor_clears_wide_body() -> void:
	var root3d := Node3D.new()
	tree.root.add_child(root3d)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.current = true
	var head := Vector3(0.0, 0.0, -2.5)
	var plain: Vector2 = InsightCard.card_anchor(cam, head, 0.0)
	assert_eq(plain, cam.unproject_position(head) + InsightCard.OFFSET, "寬度 0：頭頂＋OFFSET")
	var wide: Vector2 = InsightCard.card_anchor(cam, head, 0.85)
	var edge: Vector2 = cam.unproject_position(head + Vector3.RIGHT * 0.85)
	assert_true(wide.x > plain.x, "寬的敵人在近處：卡片往右讓（%.0f > %.0f）" % [wide.x, plain.x])
	assert_true(absf(wide.x - (edge.x + InsightCard.EDGE_GAP)) < 0.5, "卡片左緣貼在身體右緣外 EDGE_GAP")
	assert_eq(wide.y, plain.y, "只往右讓，高度不變")
	var far: Vector2 = InsightCard.card_anchor(cam, Vector3(0.0, 0.0, -60.0), 0.85)
	assert_eq(far, cam.unproject_position(Vector3(0.0, 0.0, -60.0)) + InsightCard.OFFSET, "很遠時身體比 OFFSET 窄，照原本")
	var u := Undertaker.new()
	var w := Ashwalker.new()
	assert_true(u.insight_side() > w.insight_side(), "送葬者（鐵架）比灰巡者寬")
	u.free()
	w.free()
	root3d.queue_free()
	await tree.process_frame
