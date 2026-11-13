extends TestCase
## 戰鬥場（docs/design/11-combat-first.md 3.1，D-238）：標題的入口、不碰劇情存檔、波次照資料生出來、
## 倒下原地重來（補滿、狀態不留、敵人滿血、不會多生一批）、打完往下一波、機器人只走玩家的按鍵。

const PATH: String = "res://scenes/levels/underground_market.tscn"
const BOOT: String = "res://scenes/boot/boot.tscn"

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_arena_%d" % Time.get_ticks_usec()
	_original = _game().get("session") as GameSession


func after_each() -> void:
	tree.paused = false
	Engine.time_scale = 1.0
	for a: String in ArenaBot.ACTIONS:
		Input.action_release(a)
	_game().set("arena_mode", false)
	_game().set("arena_bot", "")
	_game().set("arena_runs", 0)
	_game().set("arena_wave", 0)
	_game().call("arena_revived")
	_game().set("session", _original)
	for d: String in [_dir, _dir + "_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)


func _game() -> Node:
	return tree.root.get_node("Game")


func _frames(n: int) -> void:
	for i: int in n:
		await tree.physics_frame


## 開戰鬥場（不換場景：自己把關卡加進樹裡）。敵人與席菈先停住，測試自己決定誰動。
func _open(wave: int = 0, bot: String = "", freeze: bool = true) -> UndergroundMarket:
	_game().set("session", GameSession.new(QuestDB.load_default(), _dir))
	_game().set("arena_bot", bot)
	_game().call("start_arena", false, wave)
	var level: UndergroundMarket = (load(PATH) as PackedScene).instantiate() as UndergroundMarket
	tree.root.add_child(level)
	await tree.physics_frame
	await tree.process_frame
	if freeze:
		_freeze(level)
	return level


func _freeze(level: UndergroundMarket) -> void:
	for e: EnemyActor in level.arena.enemies:
		e.set_physics_process(false)
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	if sheila != null:
		sheila.set_physics_process(false)


func _close(level: UndergroundMarket) -> void:
	level.queue_free()
	await tree.process_frame
	await tree.process_frame


func test_wave_data_is_valid_and_gets_harder() -> void:
	var d: Dictionary = Arena.load_waves()
	assert_eq(Arena.validate(d).size(), 0, "waves.json 沒有寫錯：%s" % ", ".join(Arena.validate(d)))
	var waves: Array = d["waves"] as Array
	assert_eq(waves.size(), 4, "四波")
	var first: Array = (waves[0] as Dictionary)["enemies"] as Array
	assert_eq(first.size(), 3, "第一波開場三個人")
	assert_eq(str((first[2] as Dictionary)["kind"]), "thrower", "第一波就有一個丟毒瓶的＝毒的來源（D-245）")
	assert_eq(((waves[2] as Dictionary)["enemies"] as Array).size(), 3, "第三波三個人")
	assert_eq(str((((waves[3] as Dictionary)["enemies"] as Array)[0] as Dictionary)["kind"]), "guardian", "最後一波是南街守衛")
	assert_true(Arena.validate({"waves": [{"id": "x", "enemies": [{"kind": "dragon", "pos": [9.0, 0.0]}]}]}).size() >= 2, "不認得的種類、不在街上的位置都會被抓到")
	# 一波的人分批進場（D-242）：前三波總共 5～8 個人、一波比一波多；頭目那一波只有牠
	var sizes: Array[int] = []
	for w: Variant in waves:
		sizes.append(Arena.wave_size(w as Dictionary))
	assert_true(sizes[0] >= 5 and sizes[2] <= 8, "一般波 5～8 個人（%s）" % str(sizes))
	assert_true(sizes[0] <= sizes[1] and sizes[1] <= sizes[2], "一波比一波多（%s）" % str(sizes))
	assert_eq(sizes[3], 1, "頭目沒有後援")
	var bad: Dictionary = {"waves": [{"id": "x", "enemies": [{"kind": "club", "pos": [0.0, 24.0]}],
			"reinforcements": [{"enemies": [{"kind": "guardian", "x": 9.0, "ahead": 2.0}]}, {"when_alive_at_most": 1, "enemies": []}]}]}
	assert_true(Arena.validate(bad).size() >= 5, "後援寫錯都抓得到：沒寫門檻、種類、不在街上、太近、空的一批（%s）" % ", ".join(Arena.validate(bad)))


func test_title_button_starts_the_arena_without_touching_story_saves() -> void:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	_game().set("session", s)
	s.new_game()
	s.set_flag("rb.test_marker", true)
	assert_eq(s.save(GameSession.AUTO_SLOT), OK)
	var save_path: String = s.slot_path(GameSession.AUTO_SLOT)
	var before: String = FileAccess.get_file_as_string(save_path)
	var boot: Control = (load(BOOT) as PackedScene).instantiate() as Control
	boot.set("load_levels", false)
	tree.root.add_child(boot)
	await tree.process_frame
	await tree.process_frame
	var button: Button = boot.get_node("%Arena") as Button
	assert_eq(button.text, "MENU_ARENA", "標題有「戰鬥場」")
	assert_false(button.disabled, "沒玩過劇情也能按")
	button.pressed.emit()
	assert_true(bool(_game().get("arena_mode")), "進戰鬥場")
	var now: GameSession = _game().get("session") as GameSession
	assert_false(now.in_story(), "戰鬥場不是劇情：不恢復也不寫生命、藥")
	assert_true(now != s, "換了一個乾淨的 session")
	assert_eq(now.save_dir, _dir, "存檔資料夾照舊")
	boot.queue_free()
	await tree.process_frame
	# 打一場、倒下、重來：劇情的存檔一個字都沒變
	var level: UndergroundMarket = (load(PATH) as PackedScene).instantiate() as UndergroundMarket
	tree.root.add_child(level)
	await tree.physics_frame
	_freeze(level)
	assert_true(level.story == null, "不掛劇情")
	assert_not_null(level.arena, "掛的是戰鬥場")
	var player: PlayerController = level.get_node("Player") as PlayerController
	player.health.apply_damage(999.0)
	await _frames(5)
	level.arena.start_wave(0)
	await _frames(5)
	assert_eq(FileAccess.get_file_as_string(save_path), before, "劇情存檔沒有被動到")
	assert_true(bool(_game().call("has_continue")), "「繼續」還在")
	# 回標題按「繼續」：讀的是原本的劇情
	assert_true(bool(_game().call("continue_game", false)), "繼續讀得到")
	assert_false(bool(_game().get("arena_mode")), "按了繼續就不是戰鬥場了")
	assert_true(bool((_game().get("session") as GameSession).state.get_flag("rb.test_marker", false)), "讀回來的是原本的進度")
	await _close(level)


func test_wave_spawns_from_data_with_both_slots_and_bracer() -> void:
	var level: UndergroundMarket = await _open(2)
	var arena: Arena = level.arena
	var player: PlayerController = level.get_node("Player") as PlayerController
	assert_eq(arena.wave, 2)
	assert_eq(arena.enemies.size(), 3, "第三波三個人")
	assert_eq((arena.enemies[2] as DemoGuard).kind, DemoGuard.KIND_THROWER, "最後一個是丟毒瓶的")
	assert_true((arena.enemies[0] as DemoGuard).focus_player, "第一個只追諾恩")
	for e: EnemyActor in arena.enemies:
		assert_true(e.is_in_group("enemies"), "一生出來就是敵人（不用等對話）")
		assert_true(absf(e.global_position.x) <= UndergroundMarket.STREET_HALF, "在街上")
		var d: float = e.global_position.distance_to(player.global_position)
		assert_true(d > 4.0 and d < 11.0, "離諾恩 4～11 m：10 秒內打得起來（%.1f）" % d)
	assert_true(player.status_effects.is_reversed("poison"), "中毒裝在欄位裡")
	assert_true(player.status_effects.is_reversed(StatusEffects.PARALYSIS), "麻痺裝在欄位裡")
	assert_eq(player.on_hit_source, Arena.BRACER_HIT_SOURCE, "戴著護腕")
	assert_not_null(arena.worn_bracer, "護腕看得到")
	assert_not_null(level.get_node_or_null("Sheila"), "席菈在")
	assert_true(arena.fighting)
	# 打中人：算在諾恩頭上
	var foe: EnemyActor = arena.enemies[0]
	player.global_position = foe.global_position + Vector3(0.2, 0.0, 0.0)
	assert_true(player.strike() >= 1)
	assert_eq(int(arena.stats["noen_hits"]), 1)
	assert_true(absf(float(arena.stats["noen_damage"]) - CombatTuning.num("noen.blunt_damage", 6.0)) < 0.01, "一下的傷害照 tuning.json")
	foe.health.apply_damage(20.0, {"source": level.get_node("Sheila")})
	assert_true(absf(float(arena.stats["ally_damage"]) - 20.0) < 0.01, "席菈打的算席菈的")
	var hit: float = CombatTuning.num("noen.blunt_damage", 6.0)
	assert_true(absf(arena.noen_share() - hit / (hit + 20.0)) < 0.01, "占比＝諾恩的／全隊的")
	await _close(level)


## 戰鬥場用自己的一套數值、每個敵人都找諾恩、席菈不先衝（D-239）。
func test_arena_uses_its_own_numbers_and_enemies_go_for_noen() -> void:
	assert_eq(CombatTuning.profile(), "", "還沒進戰鬥場：劇情的數字")
	var level: UndergroundMarket = await _open(0, "", false)
	var arena: Arena = level.arena
	var player: PlayerController = arena.player
	var sheila: Sheila = level.get_node("Sheila") as Sheila
	assert_eq(CombatTuning.profile(), CombatTuning.PROFILE_ARENA, "進戰鬥場：換成戰鬥場那一套")
	assert_true(sheila.brain.engage_range < 6.0, "席菈：敵人走近了才動手（%.1f m）" % sheila.brain.engage_range)
	var sheila_start: Vector3 = sheila.global_position
	# 開場半秒：敵人往諾恩走，席菈還站在他旁邊（以前 0.8 秒她已經衝到敵人面前）
	await _frames(30)
	for e: EnemyActor in arena.enemies:
		assert_true(e.focus_player, "每一個都找諾恩")
		assert_true(e.target == player, "目標是諾恩，不是比較近的席菈")
	assert_true(sheila.global_position.distance_to(sheila_start) < 0.6,
			"席菈沒有先衝出去（動了 %.2f m）" % sheila.global_position.distance_to(sheila_start))
	assert_eq(sheila.brain.mode, CompanionBrain.Mode.FOLLOW, "還沒動手")
	# 把席菈放到敵人面前：他們還是找諾恩
	_freeze(level)
	sheila.global_position = arena.enemies[0].global_position + Vector3(0.0, 0.0, 1.0)
	arena.enemies[0].set_physics_process(true)
	await _frames(2)
	assert_true(arena.enemies[0].target == player, "席菈比較近也一樣")
	arena.enemies[0].set_physics_process(false)
	# 第四波的南街守衛也是
	arena.start_wave(3)
	await _frames(2)
	assert_true(arena.enemies[0] is Undertaker)
	assert_true(arena.enemies[0].focus_player, "南街守衛也找諾恩")
	assert_true(arena.enemies[0].target == player)
	await _close(level)
	_game().set("arena_mode", false)
	assert_eq(CombatTuning.profile(), "", "離開戰鬥場：數字換回來")
	assert_eq(CombatTuning.num("demo_guard.moves.swing.damage"), 12.0, "劇情的橫掃還是 12")


## 這一步的驗收（design/11 第 4 節）：什麼都不按，第一波會輸，而且席菈救不了他。
func test_standing_still_loses_the_first_wave() -> void:
	var level: UndergroundMarket = await _open(0, "idle", false)
	var arena: Arena = level.arena
	var frames: int = 0
	var most_at_once: int = 0
	while arena.results.is_empty() and frames < 1500:
		await tree.physics_frame
		frames += 1
		var winding: int = 0
		for e: EnemyActor in arena.enemies:
			# 丟毒瓶的不排隊（D-240；第一波現在有一個，D-245）：他丟他的，不算在「同時出手」裡
			if e.uses_attack_slot() and e.brain.state in [EnemyBrain.State.TELEGRAPH, EnemyBrain.State.STRIKE]:
				winding += 1
		most_at_once = maxi(most_at_once, winding)
	assert_false(arena.results.is_empty(), "25 秒內打得出結果")
	assert_eq(most_at_once, 1, "同一時間只有一個人在擺前兆／出手（D-240）")
	if not arena.results.is_empty():
		var r: Dictionary = arena.results[0]
		assert_eq(str(r["result"]), "lose", "站著不動會輸")
		# 第 100 輪（D-248）：站在他面前的人踩進毒霧會被嗆到跳開，站著不動多撐 1.4 秒（12.4 → 13.8 秒，20 場平均）、
		# 多回一點血，這一場從 6 下變成 7 下（改之前 20 場裡本來就有 7 下的，平均 6.7）。上限跟著改成 7，並且多驗「15 秒內倒」
		assert_true(int(r["hits_taken"]) >= 3 and int(r["hits_taken"]) <= 7, "幾下就倒（%d 下）" % int(r["hits_taken"]))
		assert_true(float(r["time"]) <= 15.0, "站著不動 15 秒內倒（%.1f 秒）：被嗆到跳開不能讓站著變划算" % float(r["time"]))
		assert_true(float(r["noen_share"]) < 0.01, "他一下都沒打")
	arena.set_physics_process(false)
	await _close(level)


## 頭目那一波（D-243）：什麼都不按，20 秒左右會倒。第 94 輪加了「挨打被推開 0.7 m」之後這一波站著不動 120 秒不會輸——
## 被推到 3.9 m，牠走到 3.4 m 就只有噴毒打得到，噴完還是只有噴毒打得到；毒霧又幫諾恩回血。
## 現在牠照順序出招、會走進那一招的距離：不會連續噴兩次，橫掃、噴毒、下砸都用得到。
func test_standing_still_loses_to_the_guardian_who_keeps_his_move_order() -> void:
	var level: UndergroundMarket = await _open(3, "idle", false)
	var arena: Arena = level.arena
	var boss: Undertaker = arena.enemies[0] as Undertaker
	assert_true(boss.brain.pattern_strict, "戰鬥場的頭目照順序出招")
	assert_eq(boss.brain.move_num("sweep", "damage"), 30.0, "戰鬥場的橫掃 30")
	assert_eq(boss.brain.move_num("slam", "damage"), 45.0, "戰鬥場的下砸 45")
	var order: Array[String] = []
	var was: EnemyBrain.State = boss.brain.state
	var frames: int = 0
	while arena.results.is_empty() and frames < 1800:
		await tree.physics_frame
		frames += 1
		# 打出結果的那一幀，機器人模式會馬上清場開下一場：牠已經不在了
		if not arena.results.is_empty() or not is_instance_valid(boss):
			break
		if boss.brain.state == EnemyBrain.State.STRIKE and was != EnemyBrain.State.STRIKE:
			order.append(boss.brain.move_id)
		was = boss.brain.state
	assert_false(arena.results.is_empty(), "30 秒內打得出結果（出招順序 %s）" % str(order))
	for i: int in range(1, order.size()):
		assert_false(order[i] == "spray" and order[i - 1] == "spray", "不會連續噴兩次毒（%s）" % str(order))
	assert_true(order.has("sweep") and order.has("spray") and order.has("slam"), "三招都用到了（%s）" % str(order))
	if not arena.results.is_empty():
		var r: Dictionary = arena.results[0]
		assert_eq(str(r["result"]), "lose", "站著不動會輸")
		assert_true(float(r["time"]) >= 10.0 and float(r["time"]) <= 24.0, "10～20 秒左右倒（%.1f 秒）" % float(r["time"]))
		assert_true(int(r["hits_taken"]) >= 3 and int(r["hits_taken"]) <= 6, "幾下就倒（%d 下）" % int(r["hits_taken"]))
	arena.set_physics_process(false)
	await _close(level)
	_game().set("arena_mode", false)
	assert_eq(CombatTuning.num("undertaker.moves.sweep.damage"), 28.0, "劇情的橫掃還是 28")
	assert_eq(CombatTuning.num("undertaker.moves.slam.damage"), 40.0, "劇情的下砸還是 40")
	assert_eq(CombatTuning.num("undertaker.guardian_hp"), 480.0, "劇情的南街守衛還是 480")


## 諾恩打中的那一下（D-240）：敵人後仰、往後退一小步、前兆被打斷；席菈打的不算；丟毒瓶的不排隊。
func test_noen_hits_flinch_and_push_back_but_sheilas_do_not() -> void:
	var level: UndergroundMarket = await _open(2)
	var arena: Arena = level.arena
	var player: PlayerController = arena.player
	var sheila: Sheila = level.get_node("Sheila") as Sheila
	var e: EnemyActor = arena.enemies[0]
	assert_eq(e.attack_slots, 1, "戰鬥場：同時只有一個人出手")
	assert_true(e.brain.flinch_sec > 0.1, "戰鬥場的敵人會後仰")
	assert_true(e.uses_attack_slot(), "拿棍子的要排隊")
	assert_false(arena.enemies[2].uses_attack_slot(), "丟毒瓶的不排隊")
	e.brain.state = EnemyBrain.State.TELEGRAPH
	e.brain.time_in_state = 0.3
	e.health.apply_damage(6.0, {"source": sheila, "stagger": 0.0})
	assert_eq(e.brain.state, EnemyBrain.State.TELEGRAPH, "席菈打的不會打斷他")
	var start: Vector3 = e.global_position
	var away: Vector3 = (start - player.global_position).normalized()
	e.health.apply_damage(6.0, {"source": player, "stagger": 0.0})
	assert_eq(e.brain.state, EnemyBrain.State.FLINCH, "諾恩打的：前兆被打斷、往後仰")
	assert_eq(e.interrupt_count, 1)
	# 別人這時候在擺前兆：他站直之後不會馬上跟著擺
	arena.enemies[1].brain.state = EnemyBrain.State.TELEGRAPH
	e.set_physics_process(true)
	await _frames(int(e.brain.flinch_sec * 60.0) + 4)
	e.set_physics_process(false)
	var moved: Vector3 = e.global_position - start
	moved.y = 0.0
	assert_true(moved.dot(away) > 0.25 and moved.length() < 0.7, "往後退了一小步（%.2f m）" % moved.dot(away))
	assert_eq(e.brain.state, EnemyBrain.State.CHASE, "站直了；別人佔著名額，他等")
	assert_false(e.brain.may_attack)
	arena.set_physics_process(false)
	await _close(level)


## 硬撐看得懂、聽得到（D-241）：後仰滿了的那一下整個人蓋上紅光、腳邊一圈紅環、一聲警告音；打出那一招就關掉。
## 被打斷的那一下有自己的聲音。第 92 輪只有棍頭的箍變紅，縮小的連拍圖上看不出來。
func test_brace_lights_the_whole_body_and_warns_until_he_strikes() -> void:
	var level: UndergroundMarket = await _open(0)
	var arena: Arena = level.arena
	var player: PlayerController = arena.player
	var e: EnemyActor = arena.enemies[0]
	var need: int = e.brain.brace_after
	assert_true(need >= 2, "要後仰幾次才硬撐（%d）" % need)
	assert_false(e.is_brace_lit(), "平常不亮")
	assert_eq(e.brace_mesh_count(), 0)
	e.brain.state = EnemyBrain.State.TELEGRAPH
	e.health.apply_damage(1.0, {"source": player, "stagger": 0.0})
	assert_eq(e.last_flinch_sound, EnemyActor.INTERRUPT_SFX, "打斷前兆的那一下有自己的聲音")
	assert_true(Sfx.NAMES.has(EnemyActor.INTERRUPT_SFX) and Sfx.NAMES.has(EnemyActor.BRACE_SFX), "兩個音效都在清單裡")
	assert_false(e.is_brace_lit(), "才後仰一次：還沒紅")
	for i: int in need - 1:
		e.brain.state = EnemyBrain.State.CHASE
		e.health.apply_damage(1.0, {"source": player, "stagger": 0.0})
	assert_true(e.brain.is_braced(), "後仰滿了：硬撐")
	assert_eq(e.brace_count, 1, "進入硬撐只算一次")
	assert_eq(e.last_brace_sound, EnemyActor.BRACE_SFX, "警告音")
	assert_true(arena.brace_tip_shown, "第一次有人變紅：畫面上講一次「紅＝打不斷，閃開」")
	assert_eq(int(arena.stats["braces"]), 1, "這一場記一次硬撐（機器人的表會印）")
	assert_true(float(arena.stats["first_brace"]) >= 0.0, "記下第一次硬撐在開場後幾秒")
	assert_true(tr(Arena.BRACE_TIP_KEY) != Arena.BRACE_TIP_KEY, "提示有翻譯")
	assert_true(e.is_brace_lit(), "變紅的那一刻就亮（不等下一幀）")
	assert_true(e.brace_mesh_count() >= 8, "整個身體都蓋到，不是只有棍頭（%d 塊）" % e.brace_mesh_count())
	assert_true(e.brace_strength() > EnemyActor.BRACE_STRENGTH * 1.5, "剛變紅的那一下特別亮（%.2f）" % e.brace_strength())
	var fx: Node3D = e.last_brace_fx
	assert_not_null(fx, "腳邊的紅環")
	if fx != null:
		assert_eq(fx.get_parent(), e.get_parent(), "掛在關卡上，不跟著人走")
		assert_not_null(fx.get_node_or_null("Ring"))
		assert_true(fx.global_position.distance_to(e.global_position) < 0.05)
	# 再打：不再後仰、不會重複警告
	e.health.apply_damage(1.0, {"source": player, "stagger": 0.0})
	assert_eq(e.brace_count, 1)
	# 過半秒：特效自己收掉，身上還亮著、在跳（比剛變紅時暗）
	# （他離諾恩 6 m 多，這 0.6 秒還走不到出手距離：不會開始擺前兆）
	e.brain.state = EnemyBrain.State.CHASE
	e.set_physics_process(true)
	await _frames(36)
	assert_true(fx == null or not is_instance_valid(fx), "紅環 0.4 秒內收掉")
	assert_true(e.is_brace_lit(), "硬撐多久就亮多久")
	assert_true(e.brace_strength() > 0.5 and e.brace_strength() < EnemyActor.BRACE_STRENGTH * 1.5, "平常的亮度（%.2f）" % e.brace_strength())
	# 打出那一招（進破綻）：重新算，紅光關掉
	e.brain.interrupts = 0
	await _frames(2)
	assert_false(e.is_brace_lit(), "打出那一招之後不亮")
	assert_eq(e.brace_mesh_count(), 0, "那一層拿掉了")
	# 硬撐中倒下：也要關
	e.brain.interrupts = need
	await _frames(2)
	assert_true(e.is_brace_lit())
	e.health.apply_damage(9999.0, {"source": player})
	assert_false(e.is_brace_lit(), "倒下就不亮")
	arena.set_physics_process(false)
	await _close(level)


## 出手往敵人滑一小步（D-240；只有戰鬥場）：差一點夠不到的距離，按下去會自己貼上去、打得到。
func test_attack_slides_toward_the_enemy_in_the_arena_only() -> void:
	var level: UndergroundMarket = await _open(0)
	var arena: Arena = level.arena
	var player: PlayerController = arena.player
	var e: EnemyActor = arena.enemies[0]
	arena.enemies[1].global_position += Vector3(0.0, 0.0, -6.0)
	player.global_position = e.global_position + Vector3(0.5, 0.0, 2.25)
	(player.get_node("Body") as Node3D).rotation.y = 0.0
	await _frames(2)
	var gap0: float = player.global_position.distance_to(e.global_position)
	assert_true(gap0 > CombatTuning.num("noen.strike_range"), "原本夠不到（%.2f m）" % gap0)
	var hp0: float = e.health.hp
	player.start_attack()
	await _frames(30)
	var gap1: float = player.global_position.distance_to(e.global_position)
	assert_true(player.lunge_moved > 0.4 and player.lunge_moved < 0.61, "滑了一小步（%.2f m）" % player.lunge_moved)
	assert_true(gap1 < gap0 - 0.4, "是往他那邊滑（%.2f → %.2f m）" % [gap0, gap1])
	assert_true(e.health.hp < hp0, "這一下打到了")
	# 已經貼著：不再往前擠
	player.global_position = e.global_position + Vector3(0.0, 0.0, 1.1)
	var before: float = player.lunge_moved
	await _frames(20)
	player.start_attack()
	await _frames(20)
	assert_true(player.lunge_moved - before < 0.02, "貼著的時候不滑")
	arena.set_physics_process(false)
	await _close(level)
	_game().set("arena_mode", false)
	assert_eq(CombatTuning.num("noen.lunge_dist"), 0.0, "劇情裡出手不滑（數字沒動）")
	assert_eq(CombatTuning.num("crowd.attack_slots"), 0.0, "劇情裡不限幾個人同時出手")


func test_falling_restarts_the_same_wave_in_place() -> void:
	var level: UndergroundMarket = await _open(1)
	var arena: Arena = level.arena
	var player: PlayerController = level.get_node("Player") as PlayerController
	var hud: Hud = level.get_node("Hud") as Hud
	var start: Vector3 = player.global_position
	var first: EnemyActor = arena.enemies[0]
	first.health.apply_damage(50.0, {"source": player})
	player.status_effects.apply_source("poison_bottle")
	assert_true(player.status_effects.has("poison"))
	player.global_position += Vector3(1.0, 0.0, -3.0)
	player.health.apply_damage(30.0)
	assert_eq(int(arena.stats["hits_taken"]), 1, "被打中記一下")
	player.health.apply_damage(999.0)
	assert_true(player.health.is_dead())
	assert_false(arena.fighting, "倒下這一場就結束")
	assert_eq(str(arena.results[0]["result"]), "lose")
	assert_true(bool(_game().call("is_player_dead")))
	# 不重讀檢查點、不換場景：Arena 自己重來（計時器是真實時間，這裡直接叫）
	arena.start_wave(arena.wave)
	await _frames(3)
	_freeze(level)
	assert_eq(arena.wave, 1, "還是同一波")
	assert_false(player.health.is_dead())
	assert_true(player.health.is_full(), "戰鬥場重來是補滿的（跟劇情的倒下重試不一樣）")
	assert_false(player.status_effects.has("poison"), "身上的狀態不留到下一場")
	assert_true(player.status_effects.is_reversed("poison"), "欄位還在")
	assert_false(bool(_game().call("is_player_dead")), "可以動了")
	assert_false(hud.is_death_shown(), "「你倒下了」收掉")
	assert_true(player.global_position.distance_to(start) < 0.3, "回到起點")
	assert_eq(arena.enemies.size(), 2, "不會多生一批")
	assert_true(not is_instance_valid(first) or first.is_queued_for_deletion(), "上一場的敵人收掉了")
	var alive: int = 0
	for n: Node in tree.get_nodes_in_group("enemies"):
		if not n.is_queued_for_deletion():
			alive += 1
	assert_eq(alive, 2, "場上算敵人的只有這一波的兩個")
	for e: EnemyActor in arena.enemies:
		assert_true(e.health.is_full(), "敵人滿血")
	assert_eq(int(arena.stats["hits_taken"]), 0, "數字歸零")
	var sheilas: int = 0
	for n: Node in level.get_children():
		if n is Sheila and not n.is_queued_for_deletion():
			sheilas += 1
	assert_eq(sheilas, 1, "席菈只有一個")
	await _close(level)


func test_clearing_a_wave_records_the_fight_and_moves_on() -> void:
	var level: UndergroundMarket = await _open(0)
	var arena: Arena = level.arena
	var player: PlayerController = level.get_node("Player") as PlayerController
	var hud: Hud = level.get_node("Hud") as Hud
	await _frames(30)
	# 一批一批打倒（後面幾批在場上剩一個以下的時候進場，D-242）
	var rounds: int = 0
	while arena.fighting and rounds < 20:
		rounds += 1
		for e: EnemyActor in arena.enemies:
			if is_instance_valid(e) and not e.health.is_dead():
				e.health.apply_damage(e.health.max_hp, {"source": player})
		await _frames(2)
	assert_false(arena.fighting)
	assert_true(rounds >= 2, "不是第一批倒了就算贏（打了 %d 輪）" % rounds)
	assert_eq(str(arena.results[0]["result"]), "win")
	assert_eq(int(arena.results[0]["downed"]), arena.wave_total(), "每一個都倒了")
	assert_true(float(arena.results[0]["time"]) > 0.4, "有記用時")
	assert_true(absf(float(arena.results[0]["noen_share"]) - 1.0) < 0.01, "都是諾恩打的")
	assert_true(hud.banner_text().contains("1"), "打完有一行字（第幾波、幾秒、被打中幾下）：%s" % hud.banner_text())
	assert_false(hud.banner_text().contains("{"), "數字有填進去")
	# 下一波（計時器是真實時間，這裡直接叫）
	arena.start_wave(arena.wave + 1)
	await _frames(2)
	_freeze(level)
	assert_eq(arena.wave, 1)
	assert_true((arena.enemies[1] as DemoGuard).is_bracer(), "第二波有戴護腕的")
	# 最後一波：南街守衛
	arena.start_wave(3)
	await _frames(2)
	_freeze(level)
	assert_eq(arena.enemies.size(), 1)
	assert_true(arena.enemies[0] is Undertaker, "第四波是南街守衛")
	assert_true((arena.enemies[0] as Undertaker).guardian_mode)
	assert_true(absf(arena.enemies[0].health.max_hp - CombatTuning.num("undertaker.guardian_hp", 480.0)) < 0.01, "守衛的生命照 tuning.json")
	await _close(level)


## 一波的人分批進場（D-242）：場上剩一個以下，下一批從街的北邊走進來；每一批都倒了才算贏。
func test_reinforcements_walk_in_and_the_wave_ends_only_when_every_batch_is_down() -> void:
	var level: UndergroundMarket = await _open(0)
	var arena: Arena = level.arena
	var player: PlayerController = arena.player
	var hud: Hud = level.get_node("Hud") as Hud
	assert_eq(arena.enemies.size(), 3, "開場三個人（兩個拿棍子的、一個丟毒瓶的）")
	assert_eq(arena.wave_total(), 6, "第一波總共六個")
	assert_eq(arena.enemies_left(), 6)
	assert_eq(arena.melee_alive_count(), 2, "會走過來打人的兩個")
	assert_true(arena.has_reinforcements())
	await _frames(3)
	assert_eq(arena.enemies.size(), 3, "都還站著：沒有人進場")
	# 丟毒瓶的倒了不算（D-245）：後援看的是「會走過來打人的」剩幾個
	arena.enemies[2].health.apply_damage(999.0, {"source": player})
	await _frames(3)
	assert_eq(arena.enemies.size(), 3, "只倒了丟毒瓶的：沒有人進場")
	# 拿棍子的倒一個：下一個進場
	arena.enemies[0].health.apply_damage(999.0, {"source": player})
	await _frames(3)
	assert_eq(arena.enemies.size(), 4, "拿棍子的剩一個：下一批（一個人）進場，而且只進一批")
	assert_eq(arena.enemies_left(), 4)
	var fresh: EnemyActor = arena.enemies[3]
	var ahead: float = player.global_position.z - fresh.global_position.z
	assert_true(ahead >= Arena.REINFORCE_AHEAD.x - 1.5 and ahead <= Arena.REINFORCE_AHEAD.y, "從諾恩北邊走進來，不是憑空出現在臉上（%.1f m）" % ahead)
	assert_true(absf(fresh.global_position.x) <= UndergroundMarket.STREET_HALF, "在街上")
	assert_true(fresh.is_in_group("enemies") and fresh.focus_player, "一進場就是敵人、找諾恩")
	assert_true(hud.banner_text().contains("4"), "畫面上講這一波還剩幾個：%s" % hud.banner_text())
	assert_false(hud.banner_text().contains("{"), "數字有填進去")
	assert_true(tr(Arena.REINFORCE_KEY) != Arena.REINFORCE_KEY, "有翻譯")
	# 他自己會走過來（不用等諾恩靠近）
	var d0: float = fresh.global_position.distance_to(player.global_position)
	await _frames(60)
	assert_true(fresh.global_position.distance_to(player.global_position) < d0 - 1.0,
			"一秒走近了 1 m 以上（%.1f → %.1f）" % [d0, fresh.global_position.distance_to(player.global_position)])
	# 場上的人一起倒：不算贏，後面的人接著進場
	for e: EnemyActor in arena.enemies:
		if not e.health.is_dead():
			e.health.apply_damage(999.0, {"source": player})
	await _frames(3)
	assert_true(arena.fighting, "還有人沒進場：這一波還沒打完")
	assert_eq(arena.enemies.size(), 6, "剩下兩批都進場了")
	assert_false(arena.has_reinforcements())
	for e: EnemyActor in arena.enemies:
		if not e.health.is_dead():
			e.health.apply_damage(999.0, {"source": player})
	await _frames(2)
	assert_false(arena.fighting, "六個都倒了才打完")
	assert_eq(str(arena.results[0]["result"]), "win")
	assert_eq(int(arena.results[0]["downed"]), 6)
	assert_eq(int(arena.results[0]["total"]), 6)
	# 重來這一波：後援也重新算
	arena.start_wave(0)
	await _frames(2)
	assert_eq(arena.enemies.size(), 3)
	assert_eq(arena.enemies_left(), 6)
	await _close(level)


## 硬撐中打不痛（D-242）：變紅之後、那一招打出來之前只扣四分之一；進了破綻照扣。
## 沒有這一條的話，諾恩一下 24 點，他變紅之後那一招還沒打出來人就倒了——「變紅 → 閃」等於不存在。
func test_braced_enemy_shrugs_off_hits_until_he_strikes() -> void:
	var level: UndergroundMarket = await _open(0)
	var arena: Arena = level.arena
	var player: PlayerController = arena.player
	var e: EnemyActor = arena.enemies[0]
	var hit: float = CombatTuning.num("noen.blunt_damage")
	assert_true(e.health.max_hp / hit <= 5.0, "沒硬撐的時候五下以內倒（%.0f 血、一下 %.0f）" % [e.health.max_hp, hit])
	assert_true(e.brain.brace_armor < 0.5, "戰鬥場的敵人硬撐時打不痛（%.2f）" % e.brain.brace_armor)
	for i: int in e.brain.brace_after:
		e.brain.state = EnemyBrain.State.CHASE
		assert_true(absf(e.brain.armor_mult() - 1.0) < 0.001, "還沒變紅：照扣")
		e.health.apply_damage(hit, {"source": player, "stagger": 0.0})
	assert_true(e.brain.is_braced())
	assert_eq(e.armored_hits, 0, "讓他變紅的那一下還是照扣")
	var before: float = e.health.hp
	e.health.apply_damage(hit, {"source": player, "stagger": 0.0})
	assert_true(absf((before - e.health.hp) - hit * e.brain.brace_armor) < 0.01, "變紅了：只扣 %.0f%%" % (e.brain.brace_armor * 100.0))
	assert_eq(e.armored_hits, 1)
	assert_true(Sfx.NAMES.has(EnemyActor.ARMOR_SFX), "打在硬撐的人身上有自己的聲音")
	# 他把那一招打出來、進了破綻：照扣
	e.brain.state = EnemyBrain.State.STRIKE
	e.brain.time_in_state = 9.0
	e.brain.tick(0.016, 1.0)
	assert_eq(e.brain.state, EnemyBrain.State.RECOVER)
	before = e.health.hp
	e.health.apply_damage(hit, {"source": player, "stagger": 0.0})
	assert_true(absf((before - e.health.hp) - hit) < 0.01, "破綻中照扣")
	assert_eq(e.armored_hits, 1)
	await _close(level)
	_game().set("arena_mode", false)
	assert_true(absf(EnemyBrain.new().configure("demo_guard").brace_armor - 1.0) < 0.001, "劇情裡沒有這回事")
	assert_eq(CombatTuning.num("noen.blunt_damage"), 6.0, "劇情裡諾恩一下還是 6")


## 挨打有代價（D-242）：被打中的那一下，出到一半的招沒了、0.4 秒不能動手、被推開一步。只在戰鬥場。
func test_getting_hit_staggers_noen_in_the_arena_only() -> void:
	var level: UndergroundMarket = await _open(0)
	var arena: Arena = level.arena
	var player: PlayerController = arena.player
	var e: EnemyActor = arena.enemies[0]
	var stun: float = CombatTuning.num("noen.hurt_stun")
	assert_true(stun >= 0.2 and stun <= 0.6, "硬直 0.2～0.6 秒（%.2f）：比敵人兩招之間的空檔（%.1f）短，不會被連到死" % [stun, CombatTuning.num("crowd.attack_gap")])
	assert_true(stun < CombatTuning.num("crowd.attack_gap"), "硬直比敵人輪流出手的空檔短")
	player.global_position = e.global_position + Vector3(0.0, 0.0, 1.5)
	player.start_attack()
	assert_eq(player.puppet().action, "attack")
	var start: Vector3 = player.global_position
	var hp: float = e.health.hp
	player.health.apply_damage(10.0, {"source": e})
	assert_true(player.hurt_left > 0.0, "進硬直")
	assert_eq(player.hurt_count, 1)
	assert_eq(player.puppet().action, "", "出到一半的招沒了")
	Input.action_press("attack")
	await _frames(4)
	Input.action_release("attack")
	assert_eq(player.puppet().action, "", "硬直中按出手沒有用")
	await _frames(int(stun * 60.0) + 6)
	assert_true(player.hurt_left <= 0.0, "硬直結束")
	assert_true(absf(e.health.hp - hp) < 0.01, "被打斷的那一下沒有打出去")
	var moved: Vector3 = player.global_position - start
	moved.y = 0.0
	assert_true(moved.z > 0.3 and moved.length() < 1.2, "被往敵人的反方向推開一步（%.2f m）" % moved.z)
	# 狀態扣血（中毒）不算挨打
	player.health.apply_status_damage(3.0)
	assert_eq(player.hurt_count, 1, "中毒扣血不會硬直")
	# 倒下的那一下不進硬直（倒地動作接手）
	player.health.apply_damage(999.0, {"source": e})
	assert_eq(player.hurt_count, 1)
	arena.set_physics_process(false)
	await _close(level)
	_game().set("arena_mode", false)
	assert_eq(CombatTuning.num("noen.hurt_stun"), 0.0, "劇情裡挨打沒有硬直")


func test_summary_line_counts_wins_losses_and_timeouts() -> void:
	var rs: Array[Dictionary] = [
		{"result": "win", "time": 10.0, "hits_taken": 2, "noen_share": 0.5},
		{"result": "win", "time": 20.0, "hits_taken": 4, "noen_share": 0.7},
		{"result": "lose", "time": 8.0, "hits_taken": 9, "noen_share": 0.0},
		{"result": "timeout", "time": 120.0, "hits_taken": 1, "noen_share": 0.4},
	]
	var line: String = Arena.summary_line(3, "mash", rs)
	assert_true(line.begins_with("ARENA_SUMMARY wave=3 bot=mash runs=4 win_rate=50 timeout=1 "), line)
	assert_true(line.contains("avg_win_sec=15.0"), line)
	assert_true(line.contains("avg_lose_sec=8.0"), line)
	assert_true(line.contains("avg_hits_taken=4.0"), line)
	assert_true(line.contains("noen_share=40"), line)


func test_bots_only_use_player_inputs() -> void:
	# 站著不動的：什麼都不按
	var level: UndergroundMarket = await _open(0, ArenaBot.KIND_IDLE)
	var player: PlayerController = level.get_node("Player") as PlayerController
	var start: Vector3 = player.global_position
	await _frames(40)
	assert_not_null(level.arena.bot)
	assert_true(player.global_position.distance_to(start) < 0.2, "站著不動")
	for a: String in ArenaBot.ACTIONS:
		assert_false(Input.is_action_pressed(a), "%s 沒有按" % a)
	await _close(level)
	# 亂按的：自己走過去、打得到人（走的是 Input，不是直接叫 strike）
	level = await _open(0, ArenaBot.KIND_MASH)
	player = level.get_node("Player") as PlayerController
	start = player.global_position
	var foe: EnemyActor = level.arena.enemies[0]
	foe.global_position = start + Vector3(0.0, 0.0, -4.0)
	level.arena.enemies[1].global_position = start + Vector3(1.5, 0.0, -9.0)
	await _frames(150)
	assert_true(player.global_position.z < start.z - 1.5, "往敵人走過去了")
	assert_true(int(level.arena.stats["noen_hits"]) >= 1, "打中了")
	await _close(level)
	for a: String in ArenaBot.ACTIONS:
		assert_false(Input.is_action_pressed(a), "機器人離場之後按鍵都放開（%s）" % a)


func test_skilled_bot_sees_only_telegraphs_that_can_reach() -> void:
	var level: UndergroundMarket = await _open(2)
	var arena: Arena = level.arena
	var club: EnemyActor = arena.enemies[0]
	var thrower: EnemyActor = arena.enemies[2]
	var at: Vector3 = club.global_position + Vector3(0.0, 0.0, 1.5)
	assert_true(ArenaBot.imminent_threat(at, arena.enemies, 0.2) == null, "沒有人擺前兆")
	club.brain.state = EnemyBrain.State.TELEGRAPH
	club.brain.time_in_state = 0.0
	assert_true(ArenaBot.imminent_threat(at, arena.enemies, 0.2) == null, "前兆剛開始：還不用閃")
	club.brain.time_in_state = club.brain.telegraph_sec - 0.1
	assert_true(ArenaBot.imminent_threat(at, arena.enemies, 0.2) == club, "快出手了、打得到：閃")
	assert_true(ArenaBot.imminent_threat(at + Vector3(0.0, 0.0, 6.0), arena.enemies, 0.2) == null, "打不到的距離不用閃")
	club.brain.state = EnemyBrain.State.RECOVER
	thrower.brain.state = EnemyBrain.State.TELEGRAPH
	thrower.brain.time_in_state = thrower.brain.telegraph_sec - 0.05
	assert_true(ArenaBot.imminent_threat(thrower.global_position + Vector3(0.0, 0.0, 3.0), arena.enemies, 0.2) == null, "丟毒瓶的不閃（霧對諾恩是回血）")
	assert_true(ArenaBot.nearest_enemy(at, arena.enemies) == club)
	club.health.apply_damage(999.0)
	assert_true(ArenaBot.nearest_enemy(at, arena.enemies) != club, "倒下的不算")
	await _close(level)


## 會打的機器人（D-245）：身上的毒夠多秒、炸得到兩個人就按「釋放」（走的是按鍵）；`use_release = false` 就不放。
func test_skilled_bot_releases_when_the_burst_reaches_two_and_not_when_told_not_to() -> void:
	var level: UndergroundMarket = await _open(0, ArenaBot.KIND_SKILLED)
	var arena: Arena = level.arena
	var player: PlayerController = arena.player
	assert_true(arena.bot.use_release, "預設會放")
	arena.bot.use_release = false
	arena.enemies[0].global_position = player.global_position + Vector3(-1.0, 0.0, -2.0)
	arena.enemies[1].global_position = player.global_position + Vector3(1.0, 0.0, -2.0)
	player.status_effects.apply("poison", 5.0, 6.0, "test")
	await _frames(6)
	assert_eq(player.release_count, 0, "關掉的時候不放")
	arena.bot.use_release = true
	var hp0: float = arena.enemies[0].health.hp
	await _frames(6)
	assert_eq(player.release_count, 1, "炸得到兩個、身上 4 秒以上：放")
	assert_eq(int(arena.stats["releases"]), 1, "這一場記一次")
	assert_eq(int(arena.stats["burst_hits"]), 2, "炸到兩個人")
	assert_true(float(arena.stats["burst_damage"]) > 60.0, "毒爆扣的血另外記（%.0f）" % float(arena.stats["burst_damage"]))
	assert_true(arena.enemies[0].health.hp < hp0 - 30.0, "敵人真的扣血")
	assert_false(player.status_effects.has("poison"), "毒用掉了")
	# 只有一個人在旁邊、毒也還沒養滿：留著
	arena.enemies[1].global_position = player.global_position + Vector3(1.0, 0.0, -9.0)
	player.status_effects.apply("poison", 5.0, 6.0, "test")
	await _frames(6)
	assert_eq(player.release_count, 1, "只炸得到一個：先留著")
	await _close(level)
	for a: String in ArenaBot.ACTIONS:
		assert_false(Input.is_action_pressed(a), "機器人離場之後按鍵都放開（%s）" % a)


## 會打的機器人看到地上的毒霧、身上的毒還不夠多：走進去。純函式的部分一起驗。
func test_skilled_bot_walks_into_a_mist_it_can_see() -> void:
	var level: UndergroundMarket = await _open(0, ArenaBot.KIND_SKILLED)
	var arena: Arena = level.arena
	var player: PlayerController = arena.player
	var start: Vector3 = player.global_position
	player.health.apply_damage(30.0)
	for e: EnemyActor in arena.enemies:
		e.global_position = start + Vector3(0.0, 0.0, -14.0)
	var mist: PoisonMist = PoisonMist.create(2.0, "poison_bottle", 6.0)
	mist.position = start + Vector3(2.4, 0.0, 3.6)
	level.add_child(mist)
	await _frames(2)
	assert_true(ArenaBot.nearest_mist(start, tree.get_nodes_in_group("poison_mist"), ArenaBot.MIST_SEEK_DIST, ArenaBot.MIST_MIN_LIFE) == mist, "看得到這一團")
	assert_true(ArenaBot.nearest_mist(start, tree.get_nodes_in_group("poison_mist"), 2.0, ArenaBot.MIST_MIN_LIFE) == null, "太遠的不去")
	assert_true(ArenaBot.nearest_mist(start, tree.get_nodes_in_group("poison_mist"), ArenaBot.MIST_SEEK_DIST, 99.0) == null, "快散掉的不去")
	assert_eq(ArenaBot.enemies_within(start, arena.enemies, 3.0), 0)
	assert_eq(ArenaBot.enemies_within(start + Vector3(0.0, 0.0, -13.0), arena.enemies, 3.0), 3)
	await _frames(120)
	assert_true(mist.contains(player.global_position), "敵人在北邊，它還是先往南走進霧裡（離霧心 %.1f m）" % player.global_position.distance_to(mist.global_position))
	assert_true(player.status_effects.remaining("poison") > 3.5, "站在裡面，身上的毒越來越多秒（%.1f）" % player.status_effects.remaining("poison"))
	assert_true(float(arena.stats["status_heal"]) > 0.0, "留著的時候慢慢回血")
	await _close(level)


## 別人躲的東西他走進去（D-246）：站進毒霧的那一刻諾恩碎念一句；站著不出來，丟毒瓶的愣住、頭上跳一句；
## 剛愣過不會一直愣；第二次走進去換席菈講；放掉的那一下諾恩自己有姿勢、再講一句。拿棍子的不會愣。
func test_standing_in_the_mist_makes_noen_mutter_and_the_thrower_gawk() -> void:
	var level: UndergroundMarket = await _open(0)
	var arena: Arena = level.arena
	var player: PlayerController = arena.player
	var thrower: DemoGuard = arena.enemies[2] as DemoGuard
	var hud: Hud = level.get_node("Hud") as Hud
	await _frames(30)
	assert_false(arena.player_in_mist())
	assert_eq(arena.bark_log.size(), 0, "沒有霧：沒有人講話")
	var mist: PoisonMist = PoisonMist.create(2.0, "poison_bottle", 20.0)
	mist.position = player.global_position
	level.add_child(mist)
	await _frames(6)
	assert_true(arena.player_in_mist(), "站在霧裡")
	assert_eq(arena.bark_log.size(), 1, "走進去的那一刻講一句")
	assert_eq(str(arena.last_bark.get("situation", "")), BarkLines.NOEN_ENTER)
	assert_true(arena.last_bark.get("speaker") == player, "是諾恩講的")
	assert_true(hud.bark_keys().has(arena.bark_log[0]), "畫面上看得到（%s）" % ", ".join(hud.bark_keys()))
	assert_eq(thrower.gawk_count, 0, "才剛站進去：還沒有人愣住")
	await _frames(60)
	assert_eq(thrower.gawk_count, 1, "站著不出來：丟毒瓶的愣住")
	assert_eq(int(arena.stats["gawks"]), 1)
	assert_true(arena.bark_log.has("BARK_THROWER_GAWK_1"), "他頭上跳一句")
	assert_false(arena.bark_log.has("BARK_SHEILA_WATCH_1"), "席菈這時候不講：三個人不要同時講")
	for i: int in 2:
		assert_eq((arena.enemies[i] as DemoGuard).gawk_count, 0, "拿棍子的不會愣")
	# 敵人是停住的（_freeze）：手動把他的愣住放掉，看「剛愣過不會一直愣」
	thrower.gawk_left = 0.0
	await _frames(120)
	assert_eq(thrower.gawk_count, 1, "還站在裡面：剛愣過，不會一直愣")
	assert_eq(arena.bark_log.size(), 2, "站著不動的時候不會一直講（%s）" % ", ".join(arena.bark_log))
	# 這一團散了、下一團又落在腳邊，他還是站在裡面：諾恩剛講過，這次換席菈講（每一波一次）
	mist.queue_free()
	await _frames(3)
	assert_false(arena.player_in_mist(), "霧散了")
	var again: PoisonMist = PoisonMist.create(2.0, "poison_bottle", 20.0)
	again.position = player.global_position
	level.add_child(again)
	await _frames(6)
	assert_eq(arena.mist_entries, 2)
	assert_true(arena.bark_log.has("BARK_SHEILA_WATCH_1"), "第二次走進去：席菈講一句（%s）" % ", ".join(arena.bark_log))
	assert_true(arena.last_bark.get("speaker") == level.get_node("Sheila"), "是席菈講的")
	assert_eq(arena.bark_log.size(), 3)
	assert_true(player.release_power() > 0.0, "身上的毒夠放了")
	player.release()
	assert_true(player.puppet().is_releasing(), "放的那一下諾恩自己有姿勢")
	assert_eq(player.puppet().action, "", "姿勢不佔出手")
	assert_eq(str(arena.last_bark.get("situation", "")), BarkLines.NOEN_RELEASE_MISS, "旁邊沒人：講的是放空的那一句")
	assert_eq(arena.bark_log.size(), 4)
	await _close(level)


## 毒霧落在諾恩腳邊（D-248）：站在他面前的人被嗆到、跳到霧外面、頭上跳一句；諾恩自己沒事；站得遠的人沒事。
func test_enemy_in_front_of_noen_chokes_on_the_mist_at_his_feet_and_hops_out() -> void:
	var level: UndergroundMarket = await _open(0)
	var arena: Arena = level.arena
	var player: PlayerController = arena.player
	var near: DemoGuard = arena.enemies[0] as DemoGuard
	var far: DemoGuard = arena.enemies[1] as DemoGuard
	await _frames(10)
	assert_eq(int(arena.stats["chokes"]), 0)
	near.global_position = player.global_position + Vector3(0.0, 0.0, -1.3)
	near.brain.state = EnemyBrain.State.CHASE
	var hp0: float = near.health.hp
	var php: float = player.health.hp
	var mist: PoisonMist = PoisonMist.create(2.0, DemoGuard.MIST_SOURCE, 20.0)
	mist.position = player.global_position
	level.add_child(mist)
	await _frames(3)
	assert_eq(near.choke_count, 1, "站在諾恩面前的人被嗆到")
	assert_eq(far.choke_count, 0, "站在霧外面的人沒事")
	assert_eq(int(arena.stats["chokes"]), 1, "這一場記一次（機器人的表會印）")
	assert_true(near.health.hp < hp0, "扣了一點血")
	assert_true(float(arena.stats["self_damage"]) > 0.0 and float(arena.stats["noen_damage"]) == 0.0, "記在「被毒嗆掉的血」，不算諾恩打的")
	assert_true(player.health.hp >= php, "諾恩站在同一團霧裡沒有扣血")
	assert_true(arena.bark_log.has("BARK_CHOKE_1"), "他頭上跳一句（%s）" % ", ".join(arena.bark_log))
	near.set_physics_process(true)
	await _frames(int(near.brain.flinch_sec * 60.0) + 3)
	near.set_physics_process(false)
	assert_false(mist.contains(near.global_position), "跳到霧外面（離諾恩 %.2f m）" % near.global_position.distance_to(player.global_position))
	assert_true(arena.player_in_mist(), "諾恩還站在裡面")
	await _frames(30)
	assert_eq(near.choke_count, 1, "同一團霧不會一直嗆")
	await _close(level)
