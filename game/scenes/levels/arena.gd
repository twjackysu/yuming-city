class_name Arena
extends Node
## 戰鬥場（docs/design/11-combat-first.md 3.1，D-238）：標題按下去 10 秒內開打。
## 掛在地下市場關卡底下（`Game.arena_mode` 時；這時候沒有劇情控制器）。不讀不寫劇情存檔。
##
## - 波次在 `res://data/arena/waves.json`。諾恩開場就有兩格（中毒、麻痺）與護腕；每一波開始補滿生命、清掉狀態。
## - 一波的人分批進場（D-242）：場上剩沒幾個的時候，下一批從街的北邊走進來；全部的批次都倒了才算贏。
## - 倒下：`RETRY_SEC` 秒後原地重來這一波（不重新載入關卡）。打完：一行字（用時、被打中幾下）→ 下一波；四波打完從第一波再來。
## - 每一場的數字記在 `stats`；機器人（`ArenaBot`）跑的時候每場印一行 `ARENA …`，跑滿 `runs` 場就結束程式。
##
## 這裡量得出難度、節奏、玩家的份量；量不出爽不爽。

signal fight_finished(result: Dictionary)

const WAVES_PATH: String = "res://data/arena/waves.json"
## 倒下到重來（真實時間）。design/11：2 秒內
const RETRY_SEC: float = 1.6
## 打完一波到下一波開始
const NEXT_WAVE_SEC: float = 3.5
## 機器人一場最多打幾秒（遊戲時間）：超過算「打不完」
const BOT_TIMEOUT_SEC: float = 120.0
const SLOT_STATUSES: PackedStringArray = ["poison", StatusEffects.PARALYSIS]
const BRACER_HIT_SOURCE: String = "bracer_hit"
const WAVE_START_KEY: String = "ARENA_WAVE_START"
const WAVE_DONE_KEY: String = "ARENA_WAVE_DONE"
const ALL_DONE_KEY: String = "ARENA_ALL_DONE"
const RETRY_KEY: String = "ARENA_RETRY"
## 第一次有人硬撐（整個人變紅，D-241）的那一刻講一次：紅＝打不斷，要閃。之後不再講（重來、下一波都不講）
const BRACE_TIP_KEY: String = "ARENA_TIP_BRACE"
const BRACE_TIP_SEC: float = 3.0
## 第一次身上的毒夠放的時候教一次「釋放」（D-245）：身上至少這麼多秒才講（剛沾到一下就講，人還沒看到數字在漲）
const RELEASE_TIP_KEY: String = "ARENA_TIP_RELEASE"
const RELEASE_TIP_SEC: float = 5.0
const RELEASE_TIP_AT: float = 3.0
## 後面幾批進場（D-242）：畫面上講一句「又來了幾個、這一波還剩幾個」
const REINFORCE_KEY: String = "ARENA_REINFORCE"
## 碎念與旁人的反應（D-246）：一句停多久、諾恩走進霧的碎念最少隔幾秒、各自的顏色
const BARK_SEC: float = 2.4
const ENTER_BARK_GAP: float = 6.0
const BARK_NOEN_COLOR: Color = Color(0.97, 0.94, 0.84)
const BARK_OTHER_COLOR: Color = Color(0.78, 0.86, 0.95)
## 敵人講的用偏紅的顏色（D-248）：第 99 輪的連拍上，淡藍與米白在縮小的圖上分不出來，看不出哪一句是誰講的
const BARK_ENEMY_COLOR: Color = Color(1.0, 0.6, 0.5)
## 被嗆到的人頭上那一句最少隔幾秒（一團霧可以連著嗆到兩三個人，每個人都講就是三行字疊在一起）
const CHOKE_BARK_GAP: float = 4.0
const REINFORCE_BANNER_SEC: float = 2.2
## 後面幾批最北生到哪裡（看熱鬧的人退到 z＝12.5～13.4，不要生在他們身上）
const REINFORCE_NORTH_Z: float = 14.8
## 資料裡 ahead（生在諾恩北邊幾公尺）可以寫的範圍：太近＝憑空出現在臉上；太遠＝超過敵人看得到人的距離（14 m），他不會走過來
const REINFORCE_AHEAD: Vector2 = Vector2(6.0, 13.0)

var level: UndergroundMarket
var player: PlayerController
var data: Dictionary = {}
var wave: int = 0
var enemies: Array[EnemyActor] = []
var fighting: bool = false
## 這一場的數字：time（秒）、hits_taken（諾恩被打中幾下）、noen_hits（他打中幾下）、noen_damage、ally_damage、status_heal（狀態回的血）
var stats: Dictionary = {}
## 這一輪（四波）累計的用時與被打幾下
var total_time: float = 0.0
var total_hits_taken: int = 0
## 重來了幾次（這一波）
var retries: int = 0
## 機器人：種類（""＝人在玩）、要跑幾場、跑了幾場、每場的結果
var bot_kind: String = ""
var runs: int = 0
var results: Array[Dictionary] = []
var bot: ArenaBot
var worn_bracer: Node3D
## 開發用：`--side-cam`＝從街的西邊、高一點橫著看（連拍用，D-240；席菈站在東邊，從西邊看她不會擋在前面）。過肩鏡頭裡敵人被諾恩擋在正前面，
## 看不到後仰、擊退、誰打誰；橫著看兩個人一左一右。機器人照常用 player.yaw，不受影響。
const SIDE_CAM_X: float = -2.4
const SIDE_CAM_Y: float = 2.5
const SIDE_CAM_FOV: float = 52.0
var side_cam: Camera3D
## 開發用：`--tele-cam`＝架在丟毒瓶的斜前方 3 m 多、對著他（連拍「別人看到他站在毒裡」用，第 99 輪）：看得到他的正面與腳邊。
## `--side-cam` 裡他在畫面外；過肩鏡頭、或從諾恩背後用長鏡頭拍，他都被前面拿棍子的擋住（第 99 輪第一條連拍）。
## 他愣著的時候鏡頭不跟（看得出他往後退）。場上沒有丟毒瓶的就對著最近的敵人。
const TELE_CAM_OFFSET: Vector3 = Vector3(-1.9, 1.5, 2.9)
const TELE_CAM_FOV: float = 42.0
var tele_cam: bool = false
## 硬撐的提示講過了沒（只講一次）
var brace_tip_shown: bool = false
var release_tip_shown: bool = false
## 諾恩已經連續在毒霧裡站了幾秒（走出來歸零；D-246）
var mist_stay: float = 0.0
## 這一波諾恩走進毒霧幾次
var mist_entries: int = 0
var _sheila_spoke: bool = false
## 碎念與旁人的反應：輪到哪一句、最後一句是誰講的什麼、這一波講過哪些（測試用）
var barks: BarkLines = BarkLines.new()
var last_bark: Dictionary = {}
var bark_log: PackedStringArray = PackedStringArray()
var _next_enter_bark: float = 0.0
var _next_choke_bark: float = 0.0
var _burst_on: String = ""
## 開發用（連拍）：`--brace-early`＝每個敵人第一次後仰就硬撐。正常打的時候硬撐很少出現（一場 0～2 次、多半在最後），等不到
var _brace_early: bool = false
## 開發用（連拍）：`--reinforce-early`＝開場 1 秒第一批後援就進場（不等場上剩一個）。正常打要等第一個人倒下，連拍等不到
var _reinforce_early: bool = false
## 開發用（--release-early）：一開場身上就有 8 秒的毒。連拍「釋放」用——不然要等丟毒瓶的丟第一瓶、再養幾秒，
## 這台機器連拍一秒只畫一兩幀，等不到
var _release_early: bool = false
var _hp_before: Dictionary = {}
## 這一波還沒進場的批次（waves.json 的 reinforcements）與下一批是第幾批
var _batches: Array = []
var _next_batch: int = 0
var _pending: int = 0
var _rng := RandomNumberGenerator.new()


static func load_waves(path: String = WAVES_PATH) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


## 資料有沒有寫錯（測試用）：回傳問題清單，空的＝沒問題。
static func validate(d: Dictionary) -> PackedStringArray:
	var errs: PackedStringArray = []
	var waves: Array = d.get("waves", []) as Array
	if waves.is_empty():
		errs.append("沒有波次")
	for i: int in waves.size():
		var w: Dictionary = waves[i] as Dictionary
		var list: Array = w.get("enemies", []) as Array
		if str(w.get("id", "")) == "":
			errs.append("第 %d 波沒有 id" % (i + 1))
		if list.is_empty():
			errs.append("第 %d 波沒有敵人" % (i + 1))
		for e: Variant in list:
			var spec: Dictionary = e as Dictionary
			var kind: String = str(spec.get("kind", ""))
			if not kind in ["club", "bracer", "thrower", "guardian"]:
				errs.append("第 %d 波有不認得的種類 %s" % [i + 1, kind])
			var pos: Array = spec.get("pos", []) as Array
			if pos.size() != 2 or absf(float(pos[0])) > UndergroundMarket.STREET_HALF:
				errs.append("第 %d 波有敵人不在街上" % (i + 1))
		for b: Variant in w.get("reinforcements", []) as Array:
			var batch: Dictionary = b as Dictionary if b is Dictionary else {}
			var more: Array = batch.get("enemies", []) as Array
			if more.is_empty():
				errs.append("第 %d 波有一批後援是空的" % (i + 1))
			if int(batch.get("when_alive_at_most", -1)) < 0:
				errs.append("第 %d 波有一批後援沒寫 when_alive_at_most" % (i + 1))
			for m: Variant in more:
				var mspec: Dictionary = m as Dictionary
				var mkind: String = str(mspec.get("kind", ""))
				if not mkind in ["club", "bracer", "thrower"]:
					errs.append("第 %d 波的後援有不認得的種類 %s" % [i + 1, mkind])
				if absf(float(mspec.get("x", 99.0))) > UndergroundMarket.STREET_HALF:
					errs.append("第 %d 波的後援有人不在街上" % (i + 1))
				var ahead: float = float(mspec.get("ahead", 0.0))
				if ahead < REINFORCE_AHEAD.x or ahead > REINFORCE_AHEAD.y:
					errs.append("第 %d 波的後援 ahead 要在 %.0f～%.0f m" % [i + 1, REINFORCE_AHEAD.x, REINFORCE_AHEAD.y])
	return errs


## 某一波總共幾個人（第一批＋後面每一批）。純函式。
static func wave_size(w: Dictionary) -> int:
	var n: int = (w.get("enemies", []) as Array).size()
	for b: Variant in w.get("reinforcements", []) as Array:
		n += ((b as Dictionary).get("enemies", []) as Array).size()
	return n


func wave_count() -> int:
	return (data.get("waves", []) as Array).size()


func _ready() -> void:
	level = get_parent() as UndergroundMarket
	player = level.get_node_or_null("Player") as PlayerController
	data = load_waves()
	bot_kind = Game.arena_bot
	runs = Game.arena_runs
	wave = clampi(Game.arena_wave, 0, maxi(wave_count() - 1, 0))
	# 示範台前的街清出來：布景的守衛不在、看熱鬧的人退到北邊
	level.begin_demo_fight(true)
	if player == null:
		return
	_equip_player()
	player.health.damaged.connect(_on_player_damaged)
	player.health.healed.connect(_on_player_healed)
	player.health.died.connect(_on_player_died)
	player.released.connect(_on_player_released)
	if bot_kind != "":
		bot = ArenaBot.new()
		bot.name = "ArenaBot"
		bot.kind = bot_kind
		bot.arena = self
		# 開發用：--no-release＝會打的機器人不找毒、不釋放（量「放與不放」差多少，D-245）
		bot.use_release = not App.parse_user_args(OS.get_cmdline_user_args()).has("no-release")
		add_child(bot)
	_burst_on = str(App.parse_user_args(OS.get_cmdline_user_args()).get("burst-on", ""))
	_brace_early = App.parse_user_args(OS.get_cmdline_user_args()).has("brace-early")
	_reinforce_early = App.parse_user_args(OS.get_cmdline_user_args()).has("reinforce-early")
	_release_early = App.parse_user_args(OS.get_cmdline_user_args()).has("release-early")
	if App.parse_user_args(OS.get_cmdline_user_args()).has("side-cam"):
		make_side_cam()
	elif App.parse_user_args(OS.get_cmdline_user_args()).has("tele-cam"):
		tele_cam = true
		make_side_cam()
	start_wave(wave)


func make_side_cam() -> void:
	side_cam = Camera3D.new()
	side_cam.name = "SideCam"
	side_cam.fov = SIDE_CAM_FOV
	add_child(side_cam)
	side_cam.make_current()
	_aim_side_cam(1.0)


func _process(_delta: float) -> void:
	if side_cam != null:
		_aim_side_cam(0.15)


## 對著諾恩與最近的敵人中間（沿著街跟著走；k＝這一幀跟上幾成）。
func _aim_side_cam(k: float) -> void:
	if player == null:
		return
	if tele_cam:
		_aim_tele_cam(k)
		return
	var foe: EnemyActor = ArenaBot.nearest_enemy(player.global_position, enemies)
	var mid: Vector3 = player.global_position if foe == null else (player.global_position + foe.global_position) * 0.5
	var z: float = lerpf(side_cam.global_position.z, mid.z, k)
	side_cam.global_position = Vector3(SIDE_CAM_X, mid.y + SIDE_CAM_Y, z)
	side_cam.look_at(Vector3(maxf(mid.x, -0.8), mid.y + 0.9, z), Vector3.UP)


## 長鏡頭要對著誰：第一個還站著的丟毒瓶的，沒有就最近的敵人。
func tele_subject() -> EnemyActor:
	for e: EnemyActor in enemies:
		var g: DemoGuard = e as DemoGuard
		if g != null and is_instance_valid(g) and g.is_thrower() and not g.health.is_dead():
			return g
	return ArenaBot.nearest_enemy(player.global_position, enemies)


func _aim_tele_cam(k: float) -> void:
	var who: EnemyActor = tele_subject()
	if who == null:
		return
	var g: DemoGuard = who as DemoGuard
	if g != null and g.is_gawking() and k < 1.0:
		return
	var at: Vector3 = who.global_position
	side_cam.fov = TELE_CAM_FOV
	side_cam.global_position = side_cam.global_position.lerp(at + TELE_CAM_OFFSET, k)
	side_cam.look_at(Vector3(at.x, at.y + 0.95, at.z), Vector3.UP)


## 兩格都裝好、護腕戴在右前臂（打中人 → 麻痺重新計時）。
func _equip_player() -> void:
	for sid: String in SLOT_STATUSES:
		player.reversal.unlock(sid)
		player.reversal.equip(sid)
	player.on_hit_source = BRACER_HIT_SOURCE
	var elbow: Node3D = player.puppet().joint("elbow_R") if player.puppet() != null else null
	if elbow != null and worn_bracer == null:
		worn_bracer = level.worn_bracer()
		worn_bracer.name = "NoenBracer"
		elbow.add_child(worn_bracer)


func _spawn_xz(spec: Variant, fallback: Vector2) -> Vector3:
	var a: Array = spec as Array if spec is Array else []
	var x: float = float(a[0]) if a.size() == 2 else fallback.x
	var z: float = float(a[1]) if a.size() == 2 else fallback.y
	return Vector3(x, level.ground_y(Vector3(x, 0.0, z)) + 0.05, z)


## 開始（或重來）第 index 波：場上清乾淨、諾恩回到起點補滿、敵人照資料生出來。
func start_wave(index: int) -> void:
	_pending += 1
	wave = clampi(index, 0, maxi(wave_count() - 1, 0))
	_clear_field()
	var pspec: Dictionary = data.get("player", {}) as Dictionary
	player.revive()
	player.global_position = _spawn_xz(pspec.get("pos", []), Vector2(0.0, 31.0))
	player.velocity = Vector3.ZERO
	player.rotation.y = deg_to_rad(float(pspec.get("facing_deg", 0.0)))
	player.yaw = player.rotation.y
	player.pitch = -0.18
	player.snap_camera()
	Game.arena_revived()
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud != null:
		hud.hide_death()
	# 席菈
	var off: Array = (data.get("sheila", {}) as Dictionary).get("offset", [1.7, -0.8]) as Array
	var ally := Sheila.new()
	ally.name = "Sheila"
	var apos: Vector3 = player.global_position + Vector3(float(off[0]), 0.0, float(off[1]))
	ally.position = Vector3(apos.x, level.ground_y(apos), apos.z)
	ally.rotation_degrees.y = 0.0
	level.add_child(ally)
	# 敵人（第一批）。機器人跑的時候每場的位置差一點（不然每一場都一模一樣）
	_rng.seed = hash("arena-%d-%d" % [wave, results.size()])
	var wdata: Dictionary = (data.get("waves", []) as Array)[wave] as Dictionary
	_batches = wdata.get("reinforcements", []) as Array
	_next_batch = 0
	for s: Variant in wdata.get("enemies", []) as Array:
		var spec: Dictionary = s as Dictionary
		_spawn_enemy(spec, _spawn_xz(spec.get("pos", []), Vector2(0.0, 24.0)))
	# braces＝這一場敵人「硬撐」（整個人變紅，D-241）了幾次；first_brace＝第一次在開場後幾秒（沒有＝-1）
	# releases＝這一場放了幾次（D-245）；burst_damage＝毒爆實際扣掉的血；burst_hits＝炸到幾人次；burst_secs＝總共用掉幾秒的毒
	stats = {"time": 0.0, "hits_taken": 0, "noen_hits": 0, "noen_damage": 0.0, "ally_damage": 0.0, "status_heal": 0.0, "braces": 0, "first_brace": -1.0,
		"releases": 0, "burst_damage": 0.0, "burst_hits": 0, "burst_secs": 0.0, "gawks": 0, "self_damage": 0.0, "chokes": 0}
	mist_stay = 0.0
	mist_entries = 0
	_sheila_spoke = false
	_next_enter_bark = 0.0
	_next_choke_bark = 0.0
	bark_log.clear()
	if _release_early:
		player.status_effects.apply(PlayerController.RELEASE_STATUS, 5.0, 8.0, "dev")
	fighting = true
	if hud != null and bot_kind == "":
		hud.show_banner(tr(WAVE_START_KEY).format({"n": wave + 1, "total": wave_count()}), 2.5)


## 生一個敵人、接上統計。at＝資料寫的位置（機器人跑的時候每場差一點）。
func _spawn_enemy(spec: Dictionary, at: Vector3) -> EnemyActor:
	if bot_kind != "":
		at.x = clampf(at.x + _rng.randf_range(-0.5, 0.5), -UndergroundMarket.STREET_HALF + 0.4, UndergroundMarket.STREET_HALF - 0.4)
		at.z += _rng.randf_range(-0.6, 0.6)
	var e: EnemyActor = _make_enemy(spec)
	e.name = "ArenaEnemy%d" % enemies.size()
	e.position = at
	level.add_child(e)
	e.set_facing(deg_to_rad(180.0))
	if e is Undertaker:
		(e as Undertaker).begin_guardian()
	_hp_before[e.get_instance_id()] = e.health.hp
	e.health.damaged.connect(_on_enemy_damaged.bind(e))
	e.health.status_damaged.connect(_on_enemy_status_damaged.bind(e))
	e.health.status_damaged.connect(_on_enemy_damaged.bind(e))
	e.brain.braced.connect(_on_enemy_braced)
	if _brace_early:
		e.brain.interrupts = maxi(e.brain.brace_after - 1, 0)
	enemies.append(e)
	return e


## 場上還站著幾個敵人。
func alive_count() -> int:
	var n: int = 0
	for e: EnemyActor in enemies:
		if is_instance_valid(e) and not e.health.is_dead():
			n += 1
	return n


## 場上還站著幾個「會走過來打人」的（丟毒瓶的不算，D-245）。後援看的是這個數字：
## 不然留著丟毒瓶的當毒的來源，場上就一直只有他加一個人——第 97 輪量到亂按第一波 55% → 100%。
func melee_alive_count() -> int:
	var n: int = 0
	for e: EnemyActor in enemies:
		if is_instance_valid(e) and not e.health.is_dead() and e.uses_attack_slot():
			n += 1
	return n


## 這一波總共幾個人（含還沒進場的）。
func wave_total() -> int:
	var waves: Array = data.get("waves", []) as Array
	return wave_size(waves[wave] as Dictionary) if wave < waves.size() else 0


## 這一波還要打倒幾個（場上站著的＋還沒進場的）。
func enemies_left() -> int:
	var n: int = alive_count()
	for i: int in range(_next_batch, _batches.size()):
		n += ((_batches[i] as Dictionary).get("enemies", []) as Array).size()
	return n


## 還有沒有還沒進場的批次。
func has_reinforcements() -> bool:
	return _next_batch < _batches.size()


## 後面幾批（D-242）：場上站著的人（丟毒瓶的不算，D-245）剩 when_alive_at_most 個以下，下一批就從街的北邊（諾恩北邊 ahead 公尺）走進來。
## 一幀最多進一批。回傳這一幀有沒有人進場。
func _maybe_reinforce() -> bool:
	if not has_reinforcements():
		return false
	var batch: Dictionary = _batches[_next_batch] as Dictionary
	var early: bool = _reinforce_early and _next_batch == 0 and float(stats.get("time", 0.0)) >= 1.0
	if melee_alive_count() > int(batch.get("when_alive_at_most", 0)) and not early:
		return false
	_next_batch += 1
	var list: Array = batch.get("enemies", []) as Array
	for s: Variant in list:
		var spec: Dictionary = s as Dictionary
		var x: float = float(spec.get("x", 0.0))
		var z: float = maxf(player.global_position.z - float(spec.get("ahead", 10.0)), REINFORCE_NORTH_Z)
		_spawn_enemy(spec, Vector3(x, level.ground_y(Vector3(x, 0.0, z)) + 0.05, z))
	stats["batches"] = int(stats.get("batches", 0)) + 1
	if _burst_on == "reinforce":
		# 開發用：連拍從第一批後援進場的那一刻開始（scripts/burst.sh … 99999 … --burst-on=reinforce）
		_burst_on = ""
		App.burst_start_in(1)
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud != null and bot_kind == "":
		hud.show_banner(tr(REINFORCE_KEY).format({"n": list.size(), "left": enemies_left()}), REINFORCE_BANNER_SEC)
	return true


func _on_enemy_braced() -> void:
	if fighting:
		if int(stats.get("braces", 0)) == 0:
			stats["first_brace"] = float(stats.get("time", 0.0))
		stats["braces"] = int(stats.get("braces", 0)) + 1
	if _burst_on == "brace":
		# 開發用：連拍從第一次有人變紅的那一刻開始（scripts/burst.sh … 99999 … --burst-on=brace）
		_burst_on = ""
		App.burst_start_in(1)
	if brace_tip_shown or bot_kind != "":
		return
	brace_tip_shown = true
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud != null:
		hud.show_banner(BRACE_TIP_KEY, BRACE_TIP_SEC)


func _make_enemy(spec: Dictionary) -> EnemyActor:
	# 戰鬥場的敵人預設都找諾恩（D-239）；資料寫 "focus_player": false 的才追最近的
	var focus: bool = bool(spec.get("focus_player", true))
	if str(spec.get("kind", "")) == "guardian":
		var boss := Undertaker.new()
		boss.focus_player = focus
		return boss
	var g := DemoGuard.new()
	g.kind = str(spec.get("kind", DemoGuard.KIND_CLUB))
	g.height = float(spec.get("height", 1.1))
	g.focus_player = focus
	return g


## 場上的敵人、席菈、毒霧、飛在半空的瓶子都收掉。
func _clear_field() -> void:
	for e: EnemyActor in enemies:
		if is_instance_valid(e):
			e.remove_from_group("enemies")
			e.remove_from_group("damageable")
			e.queue_free()
	enemies.clear()
	_hp_before.clear()
	for n: Node in level.get_children():
		if n is Sheila or n is PoisonMist or String(n.name).begins_with("TossedBottle"):
			n.remove_from_group("heartbeat")
			# 同一幀要再生一個同名的席菈：先改名，不然新的會被改成 @Sheila@2
			n.name = "Gone%d" % n.get_instance_id()
			n.queue_free()


## 這一波打完了沒：每一批都進場了、而且都倒了。
func enemies_down() -> bool:
	if enemies.is_empty() or has_reinforcements():
		return false
	return alive_count() == 0


## 諾恩造成的傷害占全隊多少（0～1；還沒有人打中＝0）
func noen_share() -> float:
	var total: float = float(stats.get("noen_damage", 0.0)) + float(stats.get("ally_damage", 0.0))
	return float(stats.get("noen_damage", 0.0)) / total if total > 0.0 else 0.0


func _physics_process(delta: float) -> void:
	if not fighting or player == null:
		return
	stats["time"] = float(stats["time"]) + delta
	if _burst_on == "swing" and player.puppet().action == "attack":
		# 開發用：連拍從諾恩第一次出手的那一刻開始（scripts/burst.sh … 99999 … --bot=circle --burst-on=swing）
		_burst_on = ""
		App.burst_start_in(1)
	_maybe_release_tip()
	_update_chokes()
	_update_reactions(delta)
	_maybe_reinforce()
	if enemies_down():
		_finish("win")
	elif bot_kind != "" and float(stats["time"]) >= BOT_TIMEOUT_SEC:
		_finish("timeout")


## 諾恩現在是不是站在毒霧裡，而且那個毒對他是好東西（反轉中）。
func player_in_mist() -> bool:
	if player == null or player.status_effects == null or player.health.is_dead():
		return false
	if not player.status_effects.is_reversed(PlayerController.RELEASE_STATUS):
		return false
	for n: Node in get_tree().get_nodes_in_group("poison_mist"):
		var m: PoisonMist = n as PoisonMist
		if m != null and m.contains(player.global_position):
			return true
	return false


## 別人躲的東西（D-248）：會走過來打人的敵人站進毒霧（或毒霧落在他身上）就被嗆到、往霧外跳開——
## 諾恩站在裡面沒事、站在他面前的人一進來就跳開，不用字就看得到。規則在 DemoGuard.choke()；諾恩在不在霧裡都一樣。
func _update_chokes() -> void:
	var mists: Array[Node] = get_tree().get_nodes_in_group("poison_mist")
	if mists.is_empty():
		return
	for e: EnemyActor in enemies:
		var g: DemoGuard = e as DemoGuard
		if g == null or not is_instance_valid(g) or g.health.is_dead() or not g.uses_attack_slot():
			continue
		for n: Node in mists:
			var m: PoisonMist = n as PoisonMist
			if m == null or not m.contains(g.global_position) or not g.choke(m):
				continue
			stats["chokes"] = int(stats.get("chokes", 0)) + 1
			var now: float = float(stats["time"])
			if now >= _next_choke_bark:
				_next_choke_bark = now + CHOKE_BARK_GAP
				_bark(g, BarkLines.ENEMY_CHOKE, BARK_ENEMY_COLOR, 2.1 * g.height)
			if _burst_on == "choke":
				# 開發用：連拍從第一次有人被嗆到的那一刻開始（scripts/burst.sh … 99999 … --bot=skilled --burst-on=choke）
				_burst_on = ""
				App.burst_start_in(1)
			break


## 別人躲的東西，他走進去（D-246，design/11 第 0 節）：走進霧的那一刻他碎念一句（最少隔 ENTER_BARK_GAP 秒）；
## 站滿 gawk_after 秒，丟毒瓶的愣住（DemoGuard.gawk()：往後退、這段時間不丟）、頭上跳一句；
## 第二次以後走進去而諾恩這次沒講的時候，席菈講一句（每一波一次）。
func _update_reactions(delta: float) -> void:
	if not player_in_mist():
		mist_stay = 0.0
		return
	var now: float = float(stats["time"])
	if mist_stay <= 0.0:
		mist_entries += 1
		if now >= _next_enter_bark:
			_next_enter_bark = now + ENTER_BARK_GAP
			_bark(player, BarkLines.NOEN_ENTER, BARK_NOEN_COLOR)
			if _burst_on == "enter":
				# 開發用：連拍從諾恩第一次站進毒霧的那一刻開始（scripts/burst.sh … 99999 … --bot=skilled --burst-on=enter）
				_burst_on = ""
				App.burst_start_in(1)
		elif not _sheila_spoke and mist_entries >= 2:
			# 第二次走進去、諾恩自己這次沒講：換席菈講（每一波一次；三個人不要同時講——第 98 輪的連拍三句疊在一起）
			var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
			if sheila != null:
				_sheila_spoke = true
				_bark(sheila, BarkLines.SHEILA_WATCH, BARK_OTHER_COLOR)
	mist_stay += delta
	if mist_stay < CombatTuning.num("demo_thrower.gawk_after", 0.6):
		return
	for e: EnemyActor in enemies:
		var g: DemoGuard = e as DemoGuard
		if g == null or not is_instance_valid(g) or not g.gawk():
			continue
		stats["gawks"] = int(stats.get("gawks", 0)) + 1
		_bark(g, BarkLines.THROWER_GAWK, BARK_ENEMY_COLOR, 2.1 * g.height)
		if _burst_on == "gawk":
			# 開發用：連拍從丟毒瓶的第一次愣住的那一刻開始（scripts/burst.sh … 99999 … --bot=skilled --burst-on=gawk）
			_burst_on = ""
			App.burst_start_in(1)


func _bark(speaker: Node3D, situation: String, color: Color, head: float = 2.1) -> void:
	var key: String = barks.next(situation)
	if key == "":
		return
	last_bark = {"speaker": speaker, "situation": situation, "key": key}
	bark_log.append(key)
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud != null:
		hud.show_bark(speaker, key, BARK_SEC, color, head)


func _on_player_damaged(_amount: float, _info: Dictionary) -> void:
	if fighting:
		stats["hits_taken"] = int(stats["hits_taken"]) + 1
	if _burst_on == "hurt":
		# 開發用：連拍從諾恩第一次被打中的那一刻開始（scripts/burst.sh … 99999 … --bot=idle --burst-on=hurt）
		_burst_on = ""
		App.burst_start_in(1)


## 第一次身上的毒夠放：畫面上方講一次按哪個鍵（之後看生命條下面那一列的提示）。機器人跑的時候不講。
func _maybe_release_tip() -> void:
	if release_tip_shown or bot_kind != "" or player.status_effects == null:
		return
	if player.release_power() <= 0.0 or player.status_effects.remaining(PlayerController.RELEASE_STATUS) < RELEASE_TIP_AT:
		return
	release_tip_shown = true
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud != null:
		hud.show_banner(tr(RELEASE_TIP_KEY).format({"key": InputGlyphs.label_for_action("release", App.last_device)}), RELEASE_TIP_SEC)


func _on_player_released(info: Dictionary) -> void:
	if fighting:
		stats["releases"] = int(stats.get("releases", 0)) + 1
		stats["burst_hits"] = int(stats.get("burst_hits", 0)) + int(info.get("hits", 0))
		stats["burst_secs"] = float(stats.get("burst_secs", 0.0)) + float(info.get("seconds", 0.0))
	_bark(player, BarkLines.NOEN_RELEASE if int(info.get("hits", 0)) > 0 else BarkLines.NOEN_RELEASE_MISS, BARK_NOEN_COLOR)
	if _burst_on == "release":
		# 開發用：連拍從諾恩第一次釋放的那一刻開始（scripts/burst.sh … 99999 … --bot=skilled --burst-on=release）
		_burst_on = ""
		App.burst_start_in(1)


func _on_player_healed(amount: float, _info: Dictionary) -> void:
	if fighting:
		stats["status_heal"] = float(stats["status_heal"]) + amount


func _on_player_died() -> void:
	if fighting:
		_finish("lose")


func _on_enemy_damaged(_amount: float, info: Dictionary, e: EnemyActor) -> void:
	if not fighting or not is_instance_valid(e):
		return
	var id: int = e.get_instance_id()
	var dealt: float = float(_hp_before.get(id, e.health.hp)) - e.health.hp
	_hp_before[id] = e.health.hp
	if info.get("source", null) == player:
		stats["noen_damage"] = float(stats["noen_damage"]) + dealt
		if str(info.get("kind", "")) == "burst":
			stats["burst_damage"] = float(stats.get("burst_damage", 0.0)) + dealt
		else:
			stats["noen_hits"] = int(stats["noen_hits"]) + 1
	else:
		stats["ally_damage"] = float(stats["ally_damage"]) + dealt


## 敵人被自己的毒嗆到扣的血（D-247）：不算諾恩的、也不算席菈的，另外記。
func _on_enemy_status_damaged(dealt: float, _info: Dictionary, e: EnemyActor) -> void:
	if not fighting or not is_instance_valid(e):
		return
	_hp_before[e.get_instance_id()] = e.health.hp
	stats["self_damage"] = float(stats.get("self_damage", 0.0)) + dealt


func _finish(result: String) -> void:
	fighting = false
	var r: Dictionary = stats.duplicate()
	r["result"] = result
	r["wave"] = wave + 1
	r["hp_left"] = player.health.hp
	r["noen_share"] = noen_share()
	# 這一場敵人後仰了幾次、其中幾次是前兆被打斷（D-240）、失衡跪下幾次
	var flinches: int = 0
	var interrupts: int = 0
	var kneels: int = 0
	for e: EnemyActor in enemies:
		if is_instance_valid(e):
			flinches += e.flinch_count
			interrupts += e.interrupt_count
			kneels += e.kneel_count
	r["flinches"] = flinches
	r["interrupts"] = interrupts
	r["kneels"] = kneels
	# 這一波總共幾個人、打倒了幾個（輸的時候看得出撐到第幾個，D-242）
	r["total"] = wave_total()
	r["downed"] = enemies.size() - alive_count()
	results.append(r)
	fight_finished.emit(r)
	if bot_kind != "":
		_bot_next(r)
		return
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	_pending += 1
	var token: int = _pending
	if result == "lose":
		retries += 1
		if hud != null:
			hud.show_banner(RETRY_KEY, RETRY_SEC)
		await get_tree().create_timer(RETRY_SEC, true, false, true).timeout
		if token == _pending and is_inside_tree():
			start_wave(wave)
		return
	retries = 0
	total_time += float(r["time"])
	total_hits_taken += int(r["hits_taken"])
	var last: bool = wave + 1 >= wave_count()
	if hud != null:
		if last:
			hud.show_banner(tr(ALL_DONE_KEY).format({"sec": "%.0f" % total_time, "hits": total_hits_taken}), NEXT_WAVE_SEC + 1.0)
		else:
			hud.show_banner(tr(WAVE_DONE_KEY).format({"n": wave + 1, "sec": "%.0f" % float(r["time"]), "hits": int(r["hits_taken"])}), NEXT_WAVE_SEC)
	await get_tree().create_timer(NEXT_WAVE_SEC, true, false, true).timeout
	if token != _pending or not is_inside_tree():
		return
	if last:
		total_time = 0.0
		total_hits_taken = 0
	start_wave(0 if last else wave + 1)


## 機器人：印一行、下一場；跑滿就印總結、結束程式。
func _bot_next(r: Dictionary) -> void:
	print("ARENA wave=%d bot=%s run=%d result=%s time=%.1f hits_taken=%d noen_hits=%d noen_dmg=%.0f ally_dmg=%.0f share=%.2f hp_left=%.0f heal=%.0f braces=%d first_brace=%.1f flinches=%d interrupts=%d kneels=%d downed=%d total=%d releases=%d burst_dmg=%.0f burst_hits=%d burst_secs=%.1f gawks=%d self_dmg=%.0f chokes=%d" % [
		wave + 1, bot_kind, results.size(), str(r["result"]), float(r["time"]), int(r["hits_taken"]), int(r["noen_hits"]),
		float(r["noen_damage"]), float(r["ally_damage"]), float(r["noen_share"]), float(r["hp_left"]), float(r["status_heal"]),
		int(r.get("braces", 0)), float(r.get("first_brace", -1.0)), int(r.get("flinches", 0)), int(r.get("interrupts", 0)), int(r.get("kneels", 0)),
		int(r.get("downed", 0)), int(r.get("total", 0)),
		int(r.get("releases", 0)), float(r.get("burst_damage", 0.0)), int(r.get("burst_hits", 0)), float(r.get("burst_secs", 0.0)), int(r.get("gawks", 0)),
		float(r.get("self_damage", 0.0)), int(r.get("chokes", 0))])
	if runs > 0 and results.size() >= runs:
		print(summary_line(wave + 1, bot_kind, results))
		if bot != null:
			bot.release_all()
		get_tree().quit(0)
		return
	start_wave.call_deferred(wave)


## 一格（某一波×某一種機器人）的總結。純函式，測試用同一支。
static func summary_line(wave_no: int, kind: String, rs: Array[Dictionary]) -> String:
	var n: int = rs.size()
	var wins: int = 0
	var timeouts: int = 0
	var win_time: float = 0.0
	var lose_time: float = 0.0
	var hits: float = 0.0
	var share: float = 0.0
	for r: Dictionary in rs:
		hits += float(r.get("hits_taken", 0))
		share += float(r.get("noen_share", 0.0))
		match str(r.get("result", "")):
			"win":
				wins += 1
				win_time += float(r.get("time", 0.0))
			"timeout":
				timeouts += 1
			_:
				lose_time += float(r.get("time", 0.0))
	var losses: int = n - wins - timeouts
	return "ARENA_SUMMARY wave=%d bot=%s runs=%d win_rate=%.0f timeout=%d avg_win_sec=%.1f avg_lose_sec=%.1f avg_hits_taken=%.1f noen_share=%.0f" % [
		wave_no, kind, n, 100.0 * float(wins) / float(maxi(n, 1)), timeouts,
		win_time / float(maxi(wins, 1)), lose_time / float(maxi(losses, 1)), hits / float(maxi(n, 1)), 100.0 * share / float(maxi(n, 1))]
