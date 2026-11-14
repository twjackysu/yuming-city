extends TestCase
## 釋放（毒爆，docs/design/02-gameplay.md「釋放」）：把身上反轉中的毒一次用掉。
## 養＝站在霧裡越久越多秒（有上限、不會無限疊）；放＝周圍的人每個扣「秒數 × 8」（上限 80），毒就沒了；
## 劇情的數字裡這個鍵沒有作用。


func after_each() -> void:
	CombatTuning.load_tuning()
	Engine.time_scale = 1.0
	Input.action_release("release")


func _effects() -> StatusEffects:
	var slots := ReversalSlots.new()
	slots.unlock("poison")
	slots.equip("poison")
	return StatusEffects.new(StatusRules.load_default(), slots)


func test_refresh_gain_grows_poison_up_to_the_cap_and_zero_keeps_the_old_rule() -> void:
	var old: StatusEffects = _effects()
	for i: int in 40:
		old.apply_source("slime_touch")
	assert_eq(old.remaining("poison"), 3.0, "沒有開「養」：站多久都是來源的 3 秒（劇情）")
	var fx: StatusEffects = _effects()
	fx.refresh_gain = 0.75
	fx.apply_source("slime_touch")
	assert_eq(fx.remaining("poison"), 3.0, "第一次上身就是來源的秒數，不會多")
	fx.apply_source("slime_touch")
	assert_eq(fx.remaining("poison"), 3.75, "已經中毒：再中一次多 0.75 秒")
	for i: int in 200:
		fx.apply_source("slime_touch")
	assert_eq(fx.remaining("poison"), fx.rules.max_duration("poison"), "疊不過上限（30 秒）")
	assert_eq(fx.ids().size(), 1, "同一種狀態還是只有一份")
	# 麻痺（不是持續傷害那一類）不會跟著越疊越久
	fx.reversal.unlock(StatusEffects.PARALYSIS)
	fx.reversal.equip(StatusEffects.PARALYSIS)
	for i: int in 30:
		fx.apply_source("paralysis_on_hit")
	assert_eq(fx.remaining(StatusEffects.PARALYSIS), 6.0, "麻痺照舊：每次命中只是重新計時")


func test_consume_returns_the_seconds_and_removes_the_status() -> void:
	var fx: StatusEffects = _effects()
	assert_eq(fx.consume("poison"), 0.0, "身上沒有＝0")
	fx.apply("poison", 5.0, 7.0, "test")
	fx.tick(2.0, null)
	var events: Array[String] = []
	fx.changed.connect(func(id: String, event: String) -> void: events.append("%s:%s" % [id, event]))
	assert_eq(fx.consume("poison"), 5.0, "用掉剩下的 5 秒")
	assert_false(fx.has("poison"), "用掉就沒有了")
	assert_eq(events, ["poison:clear"] as Array[String], "發一次 clear")
	assert_eq(fx.consume("poison"), 0.0, "不能用第二次")


func _target(parent: Node3D, at: Vector3) -> Health:
	var body := Node3D.new()
	body.add_to_group("damageable")
	var h := Health.new(200.0)
	h.name = "Health"
	body.add_child(h)
	parent.add_child(body)
	body.global_position = at
	return h


func _player(root: Node3D, reversed: bool = true) -> PlayerController:
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	if reversed:
		player.reversal.unlock("poison")
		player.reversal.equip("poison")
	return player


func test_status_row_shows_the_release_hint_only_for_that_status() -> void:
	var hud := StatusHud.new()
	tree.root.add_child(hud)
	var fx: StatusEffects = _effects()
	fx.apply("poison", 5.0, 6.0, "test")
	hud.refresh(fx, "poison", "[RMB]: 48")
	assert_true(hud.line_text(0).ends_with("[RMB]: 48"), "中毒那一列後面有提示：%s" % hud.line_text(0))
	hud.refresh(fx, "poison", "")
	assert_true(hud.line_text(0).ends_with("6"), "不能放的時候只有秒數：%s" % hud.line_text(0))
	hud.refresh(fx, "paralysis", "[RMB]: 48")
	assert_true(hud.line_text(0).ends_with("6"), "別種狀態的提示不會寫到中毒那一列")
	hud.queue_free()
	await tree.process_frame
