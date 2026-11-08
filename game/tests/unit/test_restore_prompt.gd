extends TestCase
## 重現提示（RestorePrompt，D-059）：走近石拱時在畫面下方中央顯示三行（可以重現／代價／按住），
## 不跟右側「重現的代價」記憶卡重疊；按住時進度條跟著長；重現中改成倒數＋九顆心跳點；化灰後消失。
## 第 14 輪截圖：原本的 Label3D 在石拱上方，右半被記憶卡蓋住、代價那一行被切掉。

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
	var floor_body := CSGBox3D.new()
	floor_body.size = Vector3(40, 1, 40)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.use_collision = true
	root.add_child(floor_body)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	player.position = Vector3(0, 0, 12)
	root.add_child(player)
	var site := NineBreathSite.new()
	site.state = st
	root.add_child(site)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var prompt := RestorePrompt.new()
	layer.add_child(prompt)
	return [root, player, site, prompt]


## 記憶卡（JournalView 的 Peek）佔的大概範圍：右側、從 18% 高度往下。
func _peek_rect(view: Vector2) -> Rect2:
	return Rect2(view.x - 660.0, view.y * 0.18, 620.0, view.y * 0.45)


func test_prompt_bottom_center_not_under_memory_card() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var player: PlayerController = w[1]
	var prompt: RestorePrompt = w[3]
	await tree.physics_frame
	prompt.refresh(0.0)
	assert_false(prompt.visible, "離太遠不顯示")
	assert_eq(prompt.mode, "")
	player.global_position = Vector3(0, 0, 3)
	await tree.physics_frame
	await tree.physics_frame
	prompt.refresh(0.0)
	assert_true(prompt.visible, "走近顯示")
	assert_eq(prompt.mode, "prompt")
	var t: String = prompt.text()
	assert_true(t.contains("可以重現：南街石拱"), t)
	assert_true(t.contains("代價：永遠忘掉和父親在石拱下的最後一次對話"), "代價那一行完整：" + t)
	assert_true(t.contains("重現 9 秒"), t)
	for loc: String in ["zh_TW", "en"]:
		TranslationServer.set_locale(loc)
		prompt.refresh(0.0)
		var view: Vector2 = prompt.size
		var r: Rect2 = prompt.panel_rect()
		assert_true(view.x > 0.0 and r.size.x > 0.0, "%s：面板有大小" % loc)
		assert_true(r.position.y > view.y * 0.6, "%s：在畫面下方（y=%.0f／%.0f）" % [loc, r.position.y, view.y])
		assert_true(r.end.y < view.y - 100.0, "%s：不貼到底（留給操作提示）" % loc)
		assert_true(absf(r.get_center().x - view.x * 0.5) < 2.0, "%s：水平置中" % loc)
		assert_true(r.size.x < view.x * 0.8, "%s：寬度不超過畫面 80%%（%.0f）" % [loc, r.size.x])
		assert_false(r.intersects(_peek_rect(view)), "%s：不跟右側記憶卡重疊" % loc)
	TranslationServer.set_locale("zh_TW")
	root.queue_free()
	await tree.process_frame


func test_hold_bar_and_countdown_pips() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var player: PlayerController = w[1]
	var site: NineBreathSite = w[2]
	var prompt: RestorePrompt = w[3]
	player.global_position = Vector3(0, 0, 3)
	await tree.physics_frame
	await tree.physics_frame
	site.update_hold(0.5, true)
	prompt.refresh(0.0)
	assert_true(absf(prompt.hold_ratio - 0.5) < 0.01, "按住一半：進度條一半（%.2f）" % prompt.hold_ratio)
	site.update_hold(0.0, false)
	prompt.refresh(0.0)
	assert_eq(prompt.hold_ratio, 0.0, "放開：進度條歸零")
	assert_true(site.update_hold(1.05, true), "按滿發動")
	prompt.refresh(0.0)
	assert_eq(prompt.mode, "count", "重現中改成倒數")
	assert_eq(prompt.breaths_left, 9, "九顆心跳點全亮")
	assert_true(prompt.text().contains("還剩 9 秒"), prompt.text())
	assert_true(prompt.panel_rect().position.y > prompt.size.y * 0.6, "倒數也在畫面下方")
	site.nb.tick(3.0, st)
	prompt.refresh(0.0)
	assert_eq(prompt.breaths_left, 6, "過三秒熄三顆")
	assert_true(prompt.text().contains("還剩 6 秒"), prompt.text())
	assert_eq(site.prompt_text(), prompt.text(), "場景與 HUD 一致")
	site.nb.tick(6.5, st)
	prompt.refresh(0.0)
	assert_false(prompt.visible, "化灰後消失")
	assert_eq(site.prompt_text(), "", "化灰後沒有提示")
	root.queue_free()
	await tree.process_frame
	await tree.process_frame


func test_site_has_no_floating_3d_text() -> void:
	var st := GameState.new()
	var w: Array = _world(st)
	var root: Node3D = w[0]
	var site: NineBreathSite = w[2]
	await tree.physics_frame
	assert_eq(site.find_children("*", "Label3D", true, false).size(), 0, "石拱上不再浮著 3D 文字（改在 HUD）")
	root.queue_free()
	await tree.process_frame
