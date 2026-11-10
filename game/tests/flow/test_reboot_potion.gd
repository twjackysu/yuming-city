extends TestCase
## 新版前十分鐘的藥箱與可攜毒劑（D-209）：守衛倒下 → 牠背上的箱子摔在旁邊 → 走近拿走兩瓶（只會拿到一次）→
## 喝一口（中毒 3／秒 20 秒 → 回血，不疊加）→ 席菈「你在喝什麼？」；滿血時先問、可以選「先收著」；沒喝就走遠也算先收著。
## 兩條路都進到下一階段（去地下市場的貨梯）。死亡重試回到撿藥之前：藥箱還在原地、藥不會多拿。

const PATH: String = "res://scenes/levels/frostbridge.tscn"

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_rb_potion_%d" % Time.get_ticks_usec()
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
	s.new_reboot_game()
	RebootOpening.dev_advance(s, at)
	return s


func _load() -> StoryLevel:
	var level: StoryLevel = (load(PATH) as PackedScene).instantiate() as StoryLevel
	tree.root.add_child(level)
	await tree.physics_frame
	return level


func _game() -> Node:
	return tree.root.get_node("Game")


func _run_dialogue(level: Node, choice: int = 0) -> void:
	var box: DialogueBox = level.get_node("DialogueBox") as DialogueBox
	var choices: Node = box.find_child("Choices", true, false)
	for i: int in 60:
		if not bool(_game().call("is_in_dialogue")):
			break
		if choices.get_child_count() > 0:
			(choices.get_child(choice) as Button).pressed.emit()
		else:
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


func _potions(s: GameSession) -> int:
	return int(s.state.items.get(PlayerController.PORTABLE_ITEM, 0))


## 讀到「試用毒劑」那一段，走到藥箱前拿走兩瓶、聽完諾恩那兩句
func _take_from_crate(level: StoryLevel) -> PotionCrate:
	var crate: PotionCrate = level.get_node("RbPotionCrate") as PotionCrate
	var player: PlayerController = level.get_node("Player") as PlayerController
	player.global_position = crate.global_position + Vector3(-0.6, 0.05, -1.3)
	await _frames(2)
	assert_true(crate.take(), "拿走藥瓶")
	await _run_dialogue(level)
	return crate


func test_crate_spot_stays_in_street_on_the_centre_side() -> void:
	# 牠倒在街道東側、面向北：箱子落在西邊（靠街心）
	var a: Vector3 = RebootOpening.crate_spot(Vector3(1.8, 0.0, 18.0), Vector3(0.0, 0.0, -1.0))
	assert_true(absf(a.x - 0.3) < 0.01 and absf(a.z - 18.0) < 0.01, "街心那一側 1.5 m（%s）" % a)
	# 牠倒在牆邊：不會擺到牆裡
	var b: Vector3 = RebootOpening.crate_spot(Vector3(-4.5, 0.0, 30.0), Vector3(1.0, 0.0, 0.0))
	assert_true(absf(b.x) <= RebootOpening.CRATE_X_LIMIT + 0.001, "x 夾在街道裡")
	assert_true(b.z <= RebootOpening.CRATE_Z_MAX + 0.001 and b.z >= RebootOpening.CRATE_Z_MIN - 0.001, "z 夾在南街裡")


func test_crate_drops_beside_fallen_guardian_and_grants_two_once() -> void:
	var s := _session_at("guardian")
	var level: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level)
	var rb: RebootOpening = level.get_node("RebootOpening") as RebootOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var hud: Hud = level.get_node("Hud") as Hud
	var g: Undertaker = level.get_node("RbGuardian") as Undertaker
	assert_false(level.has_node("RbPotionCrate"), "牠倒下之前沒有藥箱")
	rb.guardian_down_talk_sec = 0.2
	g.global_position = Vector3(1.2, 0.05, 17.0)
	player.global_position = Vector3(0.0, 0.05, 11.0)
	rb._engage_guardian()
	g.health.apply_damage(g.health.hp, {"kind": "blunt", "stagger": 0.0})
	var crate: PotionCrate = level.get_node_or_null("RbPotionCrate") as PotionCrate
	assert_not_null(crate, "牠倒下：箱子從背上摔下來")
	assert_true(crate.dropping and not crate.visible, "先藏著（牠還在往前倒）")
	assert_false(crate.take(), "落地之前不能拿")
	var from_body: float = Vector2(crate.global_position.x - 1.2, crate.global_position.z - 17.0).length()
	assert_true(absf(from_body - RebootOpening.CRATE_SIDE) < 0.05, "落在牠旁邊（%.2f m）" % from_body)
	assert_true(absf(crate.global_position.x) < 1.2, "靠街心的那一側")
	assert_true(absf(float(s.state.get_flag("rb.crate_x", 99.0)) - crate.global_position.x) < 0.001, "位置記在存檔裡")
	await _frames(int((RebootOpening.CRATE_DROP_DELAY + PotionCrate.DROP_SEC) * 60.0) + 12)
	if bool(_game().call("is_in_dialogue")):
		await _run_dialogue(level)
	await _frames(12)
	assert_true(crate.visible and not crate.dropping, "落地了")
	assert_eq(crate.full_bottles_shown(), 2, "角落兩瓶還封著")
	assert_true(crate.glow().light_energy > 0.3, "瓶子的綠光")
	assert_eq(crate.glow().light_specular, 0.0, "不打高光（濕石板上不要多一顆亮點）")
	assert_eq(ParticleLook.untextured(crate).size(), 0, "落地的雪粉有圓形貼圖")
	if bool(_game().call("is_in_dialogue")):
		await _run_dialogue(level)
	assert_eq(s.quests.stage_of("rb_main"), "portable_poison")
	assert_eq(s.objective_key(), "Q_RB_OBJ_POTION")
	# 走近：提示；拿走：兩瓶、只給一次
	player.global_position = crate.global_position + Vector3(-0.5, 0.05, -1.2)
	await _frames(2)
	assert_true(crate.is_near(), "走近了")
	assert_eq(str(crate.interact_hint().get("action", "")), "interact")
	hud.interact.refresh(0.0)
	assert_true(hud.interact.is_shown(), "下方中央的互動提示")
	assert_eq(_potions(s), 0)
	assert_true(crate.take())
	assert_eq(_potions(s), 2, "兩瓶霧蛇毒劑")
	assert_eq(s.state.get_flag("rb.potion_found"), true)
	assert_true(bool(_game().call("is_in_dialogue")), "諾恩讀瓶上的字")
	await _run_dialogue(level)
	assert_eq(crate.full_bottles_shown(), 0, "那兩瓶拿走了")
	assert_true(crate.interact_hint().is_empty(), "不再提示")
	assert_false(crate.take(), "不能再拿一次")
	assert_eq(_potions(s), 2)
	# HUD：數量釘在生命條旁、生命條亮著
	await _frames(3)
	await tree.process_frame
	await tree.process_frame
	assert_true(hud.potion.pinned, "還沒決定喝不喝：釘在畫面上")
	assert_true(hud.potion.is_shown(), "藥的數量")
	assert_eq(hud.potion.count_text(), "×2")
	assert_true(hud.combat.bars_shown, "生命條也亮著")
	assert_eq(s.quests.stage_of("rb_main"), "portable_poison", "還沒試、也還沒說要收著")
	level.queue_free()
	await tree.process_frame


func test_drinking_heals_without_stacking_then_sheila_reacts() -> void:
	var s := _session_at("potion")
	assert_eq(s.quests.stage_of("rb_main"), "portable_poison")
	assert_eq(s.state.checkpoint, "rb_portable")
	var level: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level)
	var rb: RebootOpening = level.get_node("RebootOpening") as RebootOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var hud: Hud = level.get_node("Hud") as Hud
	assert_false(level.has_node("RbGuardian"), "牠已經倒下")
	await _take_from_crate(level)
	rb.potion_talk_sec = 0.5
	player.health.hp = 60.0
	assert_eq(player.use_potion(), "used")
	assert_eq(_potions(s), 1)
	assert_eq(s.state.get_flag("rb.potion_tried"), true)
	assert_true(player.status_effects.has("poison"), "喝下去＝中毒")
	assert_true(absf(player.status_effects.rate("poison") - 3.0) < 0.001, "自備的藥比較弱：3／秒")
	assert_true(absf(player.status_effects.remaining("poison") - 20.0) < 0.2, "持續 20 秒")
	assert_true(player.status_effects.is_reversed("poison"), "逆轉體質：中毒 → 回血")
	# 再喝一瓶：不疊加（還是 3／秒、最多 30 秒）
	assert_eq(player.use_potion(), "used")
	assert_eq(_potions(s), 0)
	assert_true(absf(player.status_effects.rate("poison") - 3.0) < 0.001, "不疊加")
	assert_true(player.status_effects.remaining("poison") <= 30.001, "最長 30 秒")
	assert_eq(player.use_potion(), "none_left", "喝完了")
	await _frames(20)
	assert_true(player.health.hp > 60.5, "生命往上爬（%.1f）" % player.health.hp)
	assert_false(bool(_game().call("is_in_dialogue")), "先讓玩家看到回血")
	await _frames(24)
	assert_true(bool(_game().call("is_in_dialogue")), "席菈：「你在喝什麼？」")
	await _run_dialogue(level)
	assert_eq(s.state.get_flag("rb.potion_talked"), true)
	assert_eq(s.quests.stage_of("rb_main"), "market_lead", "→ 去地下市場的貨梯")
	assert_eq(s.state.checkpoint, "rb_market")
	await _frames(40)
	assert_false(bool(_game().call("is_in_dialogue")), "對話不會再播一次")
	await tree.process_frame
	assert_false(hud.potion.pinned, "不再釘著")
	level.queue_free()
	await tree.process_frame


func test_full_health_asks_first_and_keeping_completes_the_stage() -> void:
	var s := _session_at("potion")
	var level: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level)
	var rb: RebootOpening = level.get_node("RebootOpening") as RebootOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var hud: Hud = level.get_node("Hud") as Hud
	await _take_from_crate(level)
	await tree.process_frame
	rb.potion_talk_sec = 0.3
	player.health.hp = player.health.max_hp
	assert_eq(player.use_potion(), "confirm_full", "滿血：先問")
	assert_true(hud.potion_confirm.is_open(), "跳出確認框")
	assert_true(tree.paused, "開著的時候遊戲暫停")
	assert_eq(_potions(s), 2, "還沒喝")
	var keep: Button = hud.potion_confirm.find_child("Keep", true, false) as Button
	var drink: Button = hud.potion_confirm.find_child("Drink", true, false) as Button
	assert_eq(keep.text, "RB_POTION_KEEP")
	assert_eq(drink.text, "RB_POTION_DRINK")
	keep.pressed.emit()
	assert_false(hud.potion_confirm.is_open())
	assert_false(tree.paused, "選完就繼續")
	assert_eq(_potions(s), 2, "先收著：一瓶都沒少")
	assert_false(player.status_effects.has("poison"), "沒有中毒")
	assert_eq(s.state.get_flag("rb.potion_kept"), true)
	await _frames(30)
	assert_true(bool(_game().call("is_in_dialogue")), "席菈：「你要留著那個？」")
	await _run_dialogue(level)
	assert_eq(s.quests.stage_of("rb_main"), "market_lead", "不喝也能往下走")
	# 之後滿血再按：照樣先問；這次選喝
	assert_eq(player.use_potion(), "confirm_full")
	assert_true(hud.potion_confirm.is_open())
	drink.pressed.emit()
	assert_false(tree.paused)
	assert_eq(_potions(s), 1, "選了喝才少一瓶")
	assert_true(player.status_effects.has("poison"))
	level.queue_free()
	await tree.process_frame


func test_walking_away_without_drinking_counts_as_keeping() -> void:
	var s := _session_at("potion")
	var level: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level)
	var rb: RebootOpening = level.get_node("RebootOpening") as RebootOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var crate: PotionCrate = await _take_from_crate(level)
	rb.potion_talk_sec = 0.2
	player.health.hp = 70.0
	await _frames(20)
	assert_eq(s.state.get_flag("rb.potion_kept", false), false, "還站在藥箱旁：不催")
	assert_false(bool(_game().call("is_in_dialogue")))
	player.global_position = crate.global_position + Vector3(0.0, 0.05, -(RebootOpening.POTION_KEEP_RANGE + 1.0))
	await _frames(30)
	assert_eq(s.state.get_flag("rb.potion_kept"), true, "沒喝就走遠＝先收著")
	assert_true(bool(_game().call("is_in_dialogue")), "席菈：「你要留著那個？」")
	await _run_dialogue(level)
	assert_eq(s.quests.stage_of("rb_main"), "market_lead")
	assert_eq(_potions(s), 2)
	level.queue_free()
	await tree.process_frame


func test_retry_keeps_crate_in_place_and_never_duplicates_potions() -> void:
	var s := _session_at("guardian")
	var level: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level)
	var rb: RebootOpening = level.get_node("RebootOpening") as RebootOpening
	var player: PlayerController = level.get_node("Player") as PlayerController
	var g: Undertaker = level.get_node("RbGuardian") as Undertaker
	rb.guardian_down_talk_sec = 0.1
	g.global_position = Vector3(-0.8, 0.05, 19.0)
	player.global_position = Vector3(0.0, 0.05, 12.5)
	player.health.hp = 64.0
	rb._engage_guardian()
	g.health.apply_damage(g.health.hp, {"kind": "blunt", "stagger": 0.0})
	await _frames(20)
	await _run_dialogue(level)
	assert_eq(s.state.checkpoint, "rb_portable", "撿藥之前的檢查點")
	var crate: PotionCrate = level.get_node("RbPotionCrate") as PotionCrate
	var crate_at: Vector3 = crate.global_position
	await _frames(int((RebootOpening.CRATE_DROP_DELAY + PotionCrate.DROP_SEC) * 60.0))
	await _take_from_crate(level)
	assert_eq(_potions(s), 2)
	player.health.hp = 9.0
	level.queue_free()
	await tree.process_frame
	# 死亡重試：回到撿藥之前
	_game().call("retry", false)
	assert_eq(s.state.checkpoint, "rb_portable")
	assert_eq(_potions(s), 0, "檢查點之後拿的藥跟著退回")
	assert_eq(s.state.get_flag("rb.potion_found", false), false)
	var level2: StoryLevel = await _load()
	await tree.process_frame
	_park_sheila(level2)
	var p2: PlayerController = level2.get_node("Player") as PlayerController
	var crate2: PotionCrate = level2.get_node_or_null("RbPotionCrate") as PotionCrate
	assert_not_null(crate2, "藥箱還在")
	assert_false(level2.has_node("RbGuardian"), "牠不會再站起來")
	assert_true(crate2.global_position.distance_to(crate_at) < 0.05, "在原地（%s）" % crate2.global_position)
	assert_true(crate2.visible and not crate2.dropping, "本來就在地上")
	assert_eq(crate2.full_bottles_shown(), 2)
	assert_true(p2.health.hp < p2.health.max_hp, "生命不補滿（%.0f）" % p2.health.hp)
	await _take_from_crate(level2)
	assert_eq(_potions(s), 2, "再拿一次也只有兩瓶（不是四瓶）")
	# 喝一瓶、聽完席菈的話 → 下一個檢查點；之後重來：藥箱是空的、藥的數量照存檔
	var rb2: RebootOpening = level2.get_node("RebootOpening") as RebootOpening
	rb2.potion_talk_sec = 0.1
	assert_eq(p2.use_potion(), "used")
	await _frames(20)
	await _run_dialogue(level2)
	assert_eq(s.state.checkpoint, "rb_market")
	level2.queue_free()
	await tree.process_frame
	_game().call("retry", false)
	assert_eq(_potions(s), 1, "照存檔：剩一瓶")
	var level3: StoryLevel = await _load()
	await tree.process_frame
	var crate3: PotionCrate = level3.get_node_or_null("RbPotionCrate") as PotionCrate
	assert_not_null(crate3)
	assert_eq(crate3.full_bottles_shown(), 0, "已經拿過：空箱")
	assert_eq(crate3.glow().light_energy, 0.0, "沒有綠光了")
	assert_false(crate3.take(), "不能重複領")
	assert_eq(_potions(s), 1)
	level3.queue_free()
	await tree.process_frame
