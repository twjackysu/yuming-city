class_name Arena
extends Node
## 戰鬥場（docs/design/11-combat-first.md 3.1，D-238）：標題按下去 10 秒內開打。
## 掛在地下市場關卡底下（`Game.arena_mode` 時；這時候沒有劇情控制器）。不讀不寫劇情存檔。
##
## - 波次在 `res://data/arena/waves.json`。諾恩開場就有兩格（中毒、麻痺）與護腕；每一波開始補滿生命、清掉狀態。
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
var _hp_before: Dictionary = {}
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
	return errs


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
	if bot_kind != "":
		bot = ArenaBot.new()
		bot.name = "ArenaBot"
		bot.kind = bot_kind
		bot.arena = self
		add_child(bot)
	start_wave(wave)


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
	# 敵人。機器人跑的時候每場的位置差一點（不然每一場都一模一樣）
	_rng.seed = hash("arena-%d-%d" % [wave, results.size()])
	var specs: Array = ((data.get("waves", []) as Array)[wave] as Dictionary).get("enemies", []) as Array
	for i: int in specs.size():
		var spec: Dictionary = specs[i] as Dictionary
		var at: Vector3 = _spawn_xz(spec.get("pos", []), Vector2(0.0, 24.0))
		if bot_kind != "":
			at.x = clampf(at.x + _rng.randf_range(-0.5, 0.5), -UndergroundMarket.STREET_HALF + 0.4, UndergroundMarket.STREET_HALF - 0.4)
			at.z += _rng.randf_range(-0.6, 0.6)
		var e: EnemyActor = _make_enemy(spec)
		e.name = "ArenaEnemy%d" % i
		e.position = at
		level.add_child(e)
		e.set_facing(deg_to_rad(180.0))
		if e is Undertaker:
			(e as Undertaker).begin_guardian()
		_hp_before[e.get_instance_id()] = e.health.hp
		e.health.damaged.connect(_on_enemy_damaged.bind(e))
		e.health.status_damaged.connect(_on_enemy_damaged.bind(e))
		enemies.append(e)
	stats = {"time": 0.0, "hits_taken": 0, "noen_hits": 0, "noen_damage": 0.0, "ally_damage": 0.0, "status_heal": 0.0}
	fighting = true
	if hud != null and bot_kind == "":
		hud.show_banner(tr(WAVE_START_KEY).format({"n": wave + 1, "total": wave_count()}), 2.5)


func _make_enemy(spec: Dictionary) -> EnemyActor:
	if str(spec.get("kind", "")) == "guardian":
		return Undertaker.new()
	var g := DemoGuard.new()
	g.kind = str(spec.get("kind", DemoGuard.KIND_CLUB))
	g.height = float(spec.get("height", 1.1))
	g.focus_player = bool(spec.get("focus_player", false))
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


func enemies_down() -> bool:
	if enemies.is_empty():
		return false
	for e: EnemyActor in enemies:
		if is_instance_valid(e) and not e.health.is_dead():
			return false
	return true


## 諾恩造成的傷害占全隊多少（0～1；還沒有人打中＝0）
func noen_share() -> float:
	var total: float = float(stats.get("noen_damage", 0.0)) + float(stats.get("ally_damage", 0.0))
	return float(stats.get("noen_damage", 0.0)) / total if total > 0.0 else 0.0


func _physics_process(delta: float) -> void:
	if not fighting or player == null:
		return
	stats["time"] = float(stats["time"]) + delta
	if enemies_down():
		_finish("win")
	elif bot_kind != "" and float(stats["time"]) >= BOT_TIMEOUT_SEC:
		_finish("timeout")


func _on_player_damaged(_amount: float, _info: Dictionary) -> void:
	if fighting:
		stats["hits_taken"] = int(stats["hits_taken"]) + 1


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
		stats["noen_hits"] = int(stats["noen_hits"]) + 1
	else:
		stats["ally_damage"] = float(stats["ally_damage"]) + dealt


func _finish(result: String) -> void:
	fighting = false
	var r: Dictionary = stats.duplicate()
	r["result"] = result
	r["wave"] = wave + 1
	r["hp_left"] = player.health.hp
	r["noen_share"] = noen_share()
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
	print("ARENA wave=%d bot=%s run=%d result=%s time=%.1f hits_taken=%d noen_hits=%d noen_dmg=%.0f ally_dmg=%.0f share=%.2f hp_left=%.0f heal=%.0f" % [
		wave + 1, bot_kind, results.size(), str(r["result"]), float(r["time"]), int(r["hits_taken"]), int(r["noen_hits"]),
		float(r["noen_damage"]), float(r["ally_damage"]), float(r["noen_share"]), float(r["hp_left"]), float(r["status_heal"])])
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
