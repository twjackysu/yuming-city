extends TestCase
## 新版前十分鐘的最後一段（D-210）：藥的事講完 → 走近梨攤，艾妲給一半工錢、說貨梯（只給一次）→ 站上貨梯 →
## 任務完成、「待續」→ 回標題。還沒跟艾妲講話就站上貨梯不會結束；死亡重試回到檢查點，工錢不會多拿。

const PATH: String = "res://scenes/levels/frostbridge.tscn"

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_rb_market_%d" % Time.get_ticks_usec()
	_original = tree.root.get_node("Game").get("session") as GameSession


func after_each() -> void:
	tree.paused = false
	tree.root.get_node("Game").set("session", _original)
	for d: String in [_dir, _dir + "_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)


func _session_at(at: String) -> GameSession:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	s.new_game()
	FrostbridgeOpening.dev_advance(s, at)
	return s


func _load() -> StoryLevel:
	var level: StoryLevel = (load(PATH) as PackedScene).instantiate() as StoryLevel
	tree.root.add_child(level)
	await tree.physics_frame
	return level


func _game() -> Node:
	return tree.root.get_node("Game")


func _run_dialogue(level: Node) -> void:
	var box: DialogueBox = level.get_node("DialogueBox") as DialogueBox
	for i: int in 80:
		if not bool(_game().call("is_in_dialogue")):
			break
		box.press_continue()
		await tree.process_frame


func _frames(n: int) -> void:
	for i: int in n:
		await tree.physics_frame


func _park_sheila(level: Node) -> void:
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	if sheila != null:
		sheila.set_physics_process(false)
		sheila.global_position = Vector3(-3.0, 0.05, 6.0)


func _coins(s: GameSession) -> int:
	return int(s.state.items.get(FrostbridgeOpening.WAGES_ITEM, 0))


func _stand(level: StoryLevel, at: Vector3) -> void:
	var player: PlayerController = level.get_node("Player") as PlayerController
	player.global_position = Vector3(at.x, level.ground_y(at) + 0.05, at.z)
	player.velocity = Vector3.ZERO


func test_stall_and_lift_sit_where_the_town_built_them() -> void:
	var s := _session_at("market")
	var level: StoryLevel = await _load()
	var consts: Dictionary = (level.get_script() as Script).get_script_constant_map()
	assert_eq(FrostbridgeOpening.STALL_POS, consts["STALL_POS"] as Vector3, "梨攤的位置跟關卡一樣")
	assert_eq(FrostbridgeOpening.LIFT_POS, consts["CELLAR_POS"] as Vector3, "貨梯在地窖口上")
	assert_eq(s.quests.stage_of("rb_main"), "market_lead")
	assert_eq(s.objective_key(), "Q_RB_OBJ_MARKET")
	var ada: Puppet = level.get_node_or_null("Ada") as Puppet
	assert_not_null(ada, "梨攤的艾妲是人偶（不是剪影）")
	assert_true(FrostbridgeOpening.flat_distance(ada.global_position, FrostbridgeOpening.STALL_POS) < 2.0, "站在攤子旁")
	assert_not_null(ada.hand("L").get_node_or_null("Ledger"), "左手的帳本")
	assert_true(ada.hand("R").get_node_or_null("BellHammer") == null, "不拿敲鐘的槌子")
	var lift: Node3D = level.get_node_or_null("RbLift") as Node3D
	assert_not_null(lift, "貨梯的吊架")
	var glow: OmniLight3D = lift.get_node("Glow") as OmniLight3D
	assert_true(glow.light_energy > 0.5 and not glow.shadow_enabled, "柱上的燈（不投影）")
	# 任務標記：先指艾妲，講完指貨梯
	var marker: Node3D = level.get_node_or_null("PearSellerTrigger") as Node3D
	assert_not_null(marker)
	assert_true(FrostbridgeOpening.flat_distance(marker.global_position, ada.global_position) < 0.1, "標記在艾妲身上")
	var down: Node3D = level.get_node_or_null("CellarTrigger") as Node3D
	assert_not_null(down)
	assert_true(FrostbridgeOpening.flat_distance(down.global_position, FrostbridgeOpening.LIFT_POS) < 0.1, "標記在貨梯上")
	level.queue_free()
	await tree.process_frame


func test_ada_pays_half_wages_once_then_lift_ends_with_to_be_continued() -> void:
	var s := _session_at("market")
	var level: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level)
	var rb: FrostbridgeOpening = level.get_node("FrostbridgeOpening") as FrostbridgeOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var hud: Hud = level.get_node("Hud") as Hud
	var done: Array[int] = [0]
	rb.end_done = func() -> void: done[0] += 1
	assert_eq(s.state.checkpoint, "rb_market")
	assert_eq(_coins(s), 0)
	# 還沒跟艾妲講話就站上貨梯：不會結束
	_stand(level, FrostbridgeOpening.LIFT_POS)
	await _frames(6)
	assert_false(bool(s.state.get_flag("rb.market_reached", false)), "要先拿到工錢、聽她說貨梯")
	assert_false(level.has_node("ChapterCard"))
	assert_false(level.has_node("RbEndMusic"), "配樂等卡出來才進")
	# 走近梨攤：艾妲開口
	_stand(level, FrostbridgeOpening.ADA_POS + Vector3(-1.2, 0.0, 1.6))
	await _frames(6)
	assert_true(bool(_game().call("is_in_dialogue")), "走近她就開始對話")
	await _run_dialogue(level)
	await _frames(2)
	assert_true(bool(s.state.get_flag("rb.ada_talked", false)))
	assert_eq(_coins(s), FrostbridgeOpening.WAGES, "一半的工錢")
	assert_eq(hud.banner_text(), "RB_WAGES_PAID", "告訴玩家拿到了")
	assert_false(rb.pay_wages(), "只給一次")
	assert_eq(_coins(s), FrostbridgeOpening.WAGES)
	assert_eq(s.quests.stage_of("rb_main"), "market_lead", "還要走到貨梯")
	# 站在攤子前不會再講一次
	await _frames(6)
	assert_false(bool(_game().call("is_in_dialogue")))
	# 站上貨梯：任務完成、「待續」
	_stand(level, FrostbridgeOpening.LIFT_POS + Vector3(-0.3, 0.0, 0.4))
	await _frames(6)
	assert_true(bool(s.state.get_flag("rb.market_reached", false)))
	assert_true(s.quests.is_done("rb_main"), "前十分鐘走完了")
	assert_true(bool(s.state.get_flag("rb.first_ten_done", false)))
	assert_true(rb.ending)
	var card: ChapterCard = level.get_node_or_null("ChapterCard") as ChapterCard
	assert_not_null(card, "待續的卡")
	assert_eq(card.title_text(), tr("RB_END_TITLE"))
	assert_eq(player.process_mode, Node.PROCESS_MODE_DISABLED, "黑幕底下諾恩停住")
	assert_eq(done[0], 0, "卡還沒播完")
	assert_eq(rb.play_end_card(), card, "不會疊第二張")
	# 「待續」不是無聲的（D-219）：卡出來時配樂從無聲慢慢進來，走音樂匯流排、會循環，只有一個
	var music: AudioStreamPlayer = level.get_node_or_null("RbEndMusic") as AudioStreamPlayer
	assert_not_null(music, "待續的配樂")
	assert_eq(music, rb.end_music)
	assert_eq(Ambience.sfx_of(music), FrostbridgeOpening.END_MUSIC)
	if music != null:
		assert_eq(music.bus, &"Music", "跟著「音樂」音量")
		assert_true(music.playing, "在播")
		assert_true(music.volume_db < FrostbridgeOpening.END_MUSIC_DB, "從小聲慢慢進來，不是突然響起")
		var stream: AudioStreamWAV = music.stream as AudioStreamWAV
		assert_true(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "卡停多久都不會斷")
	var players: int = 0
	for c: Node in level.get_children():
		if str(c.name).begins_with("RbEndMusic"):
			players += 1
	assert_eq(players, 1, "按兩次也只有一個配樂")
	card.finish()
	assert_eq(done[0], 1, "播完（或跳過）→ 回標題")
	level.queue_free()
	await tree.process_frame


func test_retry_at_market_never_pays_twice() -> void:
	var s := _session_at("potion")
	var level: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level)
	var rb: FrostbridgeOpening = level.get_node("FrostbridgeOpening") as FrostbridgeOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	# 拿藥、選先收著 → 檢查點 rb_market
	rb.potion_talk_sec = 0.05
	var crate: PotionCrate = level.get_node("RbPotionCrate") as PotionCrate
	player.global_position = crate.global_position + Vector3(-0.6, 0.05, -1.3)
	await _frames(2)
	assert_true(crate.take())
	await _run_dialogue(level)
	s.set_flag("rb.potion_kept", true)
	await _frames(12)
	await _run_dialogue(level)
	assert_eq(s.state.checkpoint, "rb_market", "去貨梯之前的檢查點")
	# 拿到工錢之後倒下重來
	_stand(level, FrostbridgeOpening.ADA_POS + Vector3(-1.0, 0.0, 1.4))
	await _frames(6)
	await _run_dialogue(level)
	assert_eq(_coins(s), FrostbridgeOpening.WAGES)
	level.queue_free()
	await tree.process_frame
	_game().call("retry", false)
	assert_eq(s.state.checkpoint, "rb_market")
	assert_eq(_coins(s), 0, "檢查點之後拿的工錢跟著退回")
	assert_false(bool(s.state.get_flag("rb.ada_talked", false)))
	var level2: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level2)
	var p2: PlayerController = level2.get_node("Player") as PlayerController
	assert_true(p2.global_position.z > 5.0, "回到南街口（%s）" % p2.global_position)
	assert_not_null(level2.get_node_or_null("Ada"))
	_stand(level2, FrostbridgeOpening.ADA_POS + Vector3(-1.0, 0.0, 1.4))
	await _frames(6)
	await _run_dialogue(level2)
	assert_eq(_coins(s), FrostbridgeOpening.WAGES, "再聽一次也只有一份（不是兩份）")
	level2.queue_free()
	await tree.process_frame


## 貨梯底下是打開的井口（D-214）：石框、黑的洞、底下的暖光、兩片掀開的木門；新版不蓋舊版那塊關著的木板
func test_lift_stands_over_an_open_shaft() -> void:
	_session_at("market")
	var level: StoryLevel = await _load()
	var lift: Node3D = level.get_node_or_null("RbLift") as Node3D
	assert_not_null(lift)
	var dark: MeshInstance3D = lift.get_node_or_null("ShaftDark") as MeshInstance3D
	assert_not_null(dark, "洞口那一塊黑")
	var mat: StandardMaterial3D = dark.material_override as StandardMaterial3D
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "不受光（燈照不亮洞裡）")
	assert_true(mat.albedo_color.v < 0.02, "黑的")
	var size: Vector3 = (dark.mesh as BoxMesh).size
	assert_true(size.x > 1.5 + 0.3 and size.z > 1.1 + 0.3, "洞比貨板大一圈（貨板四周看得到洞）")
	var glow: OmniLight3D = lift.get_node_or_null("ShaftGlow") as OmniLight3D
	assert_not_null(glow, "底下的暖光")
	assert_true(glow.light_energy > 1.0 and glow.light_color.r > glow.light_color.b * 2.0, "暖色、看得到")
	assert_true(glow.position.y < FrostbridgeOpening.SHAFT_CURB_H, "從洞裡往上照")
	assert_eq(glow.light_specular, 0.0, "不打高光")
	assert_false(glow.shadow_enabled)
	var north: Node3D = lift.get_node_or_null("HatchNorth") as Node3D
	var south: Node3D = lift.get_node_or_null("HatchSouth") as Node3D
	assert_true(north != null and south != null, "兩片掀開的木門")
	if north != null and south != null:
		# 北邊那片立著（門板的遠端在上面）、南邊那片翻開躺在地上
		var north_tip: Vector3 = north.to_global(Vector3(0.0, 0.0, -FrostbridgeOpening.SHAFT_HALF.y))
		var south_tip: Vector3 = south.to_global(Vector3(0.0, 0.0, -FrostbridgeOpening.SHAFT_HALF.y))
		assert_true(north_tip.y > lift.global_position.y + 0.8, "北邊那片立著（%.2f）" % (north_tip.y - lift.global_position.y))
		assert_true(south_tip.y < lift.global_position.y + 0.3, "南邊那片躺著")
		assert_true(south_tip.z > lift.global_position.z + FrostbridgeOpening.SHAFT_HALF.y + 0.5, "往南翻開")
		assert_true(north_tip.z < lift.global_position.z - FrostbridgeOpening.SHAFT_HALF.y, "不擋在洞口上")
	# 站得上去：洞口的東西都沒有碰撞（結尾照樣走得到）
	assert_eq(lift.find_children("*", "CollisionObject3D", true, false).size(), 0)
	level.queue_free()
	await tree.process_frame
