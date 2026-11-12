class_name ArenaBot
extends Node
## 戰鬥場的機器人（docs/design/11-combat-first.md 第 4 節，D-238）：替玩家按鍵，量難度、節奏、玩家的份量。
## 只走玩家也有的輸入（`Input.action_press`：前進、後退、出手、閃避；轉鏡頭＝改 `player.yaw`），
## 只看玩家也看得到的東西（敵人在哪、誰正在擺前兆、前兆擺了多久）。**量不出爽不爽。**
##
## - idle：什麼都不按。
## - mash：追著最近的敵人一直按出手，不閃。
## - skilled：看到打得到自己的前兆快出手了就往後閃，其餘時間貼上去打；丟毒瓶的前兆不閃（霧對諾恩是回血）。
##   它的時機是照幀算的，比人準——當成「會打的人」的上限看。
##   （D-245）還會「找毒、養著、放掉」：附近地上有毒霧而且身上的毒還不夠多，就走進去站著打（敵人會自己過來）；
##   身上的毒夠多秒、而且炸得到兩個人以上（或只剩最後一個人、或已經養到上限）就按「釋放」。
##   它看的是玩家也看得到的東西：地上的霧、生命條下面那一列的秒數、敵人站在哪。`use_release = false`（`--no-release`）＝不找毒也不放。
## - circle：跟 mash 一樣一直按出手、不閃，但是靠近之後一直往右繞（D-244）。人邊走邊按的時候就是這樣；
##   mash 永遠正對著敵人走，量不到「邊走邊打會不會揮空」。

const KIND_IDLE: String = "idle"
const KIND_MASH: String = "mash"
const KIND_SKILLED: String = "skilled"
const KIND_CIRCLE: String = "circle"
const KINDS: PackedStringArray = [KIND_IDLE, KIND_MASH, KIND_SKILLED, KIND_CIRCLE]
const ACTIONS: PackedStringArray = ["move_forward", "move_back", "move_left", "move_right", "sprint", "attack", "dodge", "release"]
## 離多近就出手（諾恩的出手 1.9 m）
const ATTACK_DIST: float = 1.75
## 離多近就不再往前擠
const STOP_DIST: float = 1.1
## 離這麼遠就用跑的
const SPRINT_DIST: float = 3.0
## 繞著按的：離這麼近就開始往右繞
const CIRCLE_DIST: float = 2.6
## 前兆剩幾秒就閃（閃避的無敵 0.25 秒；每一場在這個範圍裡抽一個＝時機不是每次都一樣準）
const DODGE_LEAD: Vector2 = Vector2(0.1, 0.2)
## 敵人的招打得到的距離再加這麼多，就當成有威脅
const THREAT_MARGIN: float = 0.6

## 釋放（D-245）。身上至少幾秒的毒才放（design/11 3.5：4 秒以上）
const RELEASE_MIN_SEC: float = 4.0
## 養到這麼多秒就是上限了（毒爆上限 80＝10 秒）：旁邊有一個人就放
const RELEASE_FULL_SEC: float = 9.5
## 炸得到幾個人以上才放
const RELEASE_CROWD: int = 2
## 毒爆的範圍往裡縮這麼多才算「炸得到」（按下去的那一幀人還會動）
const RELEASE_MARGIN: float = 0.3
## 多遠以內的毒霧值得走過去
const MIST_SEEK_DIST: float = 7.0
## 身上的毒不到這麼多秒才去站霧
const MIST_WANT_BELOW: float = 6.0
## 霧剩不到這麼多秒（已經在淡了）就不去
const MIST_MIN_LIFE: float = 0.6

var kind: String = KIND_IDLE
## 會打的機器人要不要找毒、釋放（false＝第 96 輪以前的打法；量「放與不放」用）
var use_release: bool = true
var arena: Arena
var _held: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _dodge_lead: float = 0.15
var _seeded_for: int = -1


func _ready() -> void:
	# 要排在玩家前面：同一個物理幀裡先按下去，玩家的 is_action_just_pressed 才看得到
	process_physics_priority = -100


func _exit_tree() -> void:
	release_all()


func release_all() -> void:
	for a: String in ACTIONS:
		_hold(a, false)


func _hold(action: String, down: bool) -> void:
	if bool(_held.get(action, false)) == down:
		return
	_held[action] = down
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)


## 按一下（這一幀按、下一幀放）
func _tap(action: String) -> void:
	_hold(action, not bool(_held.get(action, false)))


func _physics_process(_delta: float) -> void:
	if arena == null or arena.player == null or not arena.fighting or kind == KIND_IDLE:
		release_all()
		return
	var p: PlayerController = arena.player
	if p.health.is_dead():
		release_all()
		return
	if _seeded_for != arena.results.size():
		_seeded_for = arena.results.size()
		_rng.seed = hash("bot-%s-%d-%d" % [kind, arena.wave, _seeded_for])
		_dodge_lead = _rng.randf_range(DODGE_LEAD.x, DODGE_LEAD.y)
	var foe: EnemyActor = nearest_enemy(p.global_position, arena.enemies)
	if foe == null:
		release_all()
		return
	var to: Vector3 = foe.global_position - p.global_position
	to.y = 0.0
	var dist: float = to.length()
	# 鏡頭對著他（＝玩家轉滑鼠）
	p.yaw = atan2(-to.x, -to.z)
	if kind == KIND_SKILLED:
		var threat: EnemyActor = imminent_threat(p.global_position, arena.enemies, _dodge_lead)
		if threat != null:
			# 往後閃：先放開前進、按住後退，再按閃避（閃避的方向＝移動的方向）
			var tt: Vector3 = threat.global_position - p.global_position
			p.yaw = atan2(-tt.x, -tt.z)
			_hold("move_forward", false)
			_hold("sprint", false)
			_hold("move_back", true)
			_hold("attack", false)
			_tap("dodge")
			return
		_hold("move_back", false)
		_hold("move_left", false)
		_hold("dodge", false)
		if use_release and _release_and_mist(p, dist):
			return
	_hold("move_forward", dist > STOP_DIST)
	_hold("sprint", dist > SPRINT_DIST)
	_hold("move_right", kind == KIND_CIRCLE and dist <= CIRCLE_DIST)
	if dist <= ATTACK_DIST:
		_tap("attack")
	else:
		_hold("attack", false)


## 會打的：該放就放；附近有毒霧、身上的毒還不夠就走進去站著打。回傳 true＝這一幀的移動與出手已經決定了。
func _release_and_mist(p: PlayerController, dist: float) -> bool:
	var secs: float = p.status_effects.remaining(PlayerController.RELEASE_STATUS) if p.release_power() > 0.0 else 0.0
	var fire: bool = false
	if secs >= RELEASE_MIN_SEC:
		var near: int = enemies_within(p.global_position, arena.enemies, CombatTuning.num("noen.burst_radius", 3.0) - RELEASE_MARGIN)
		fire = near >= RELEASE_CROWD or (near >= 1 and (secs >= RELEASE_FULL_SEC or arena.enemies_left() <= 1))
	if fire:
		_tap("release")
	else:
		_hold("release", false)
	# 只剩丟毒瓶的＝沒有人會自己走過來，站在霧裡等不到人：去打他
	if secs >= MIST_WANT_BELOW or not _melee_alive():
		return false
	var mist: PoisonMist = nearest_mist(p.global_position, get_tree().get_nodes_in_group("poison_mist"), MIST_SEEK_DIST, MIST_MIN_LIFE)
	if mist == null:
		return false
	var to_m: Vector3 = mist.global_position - p.global_position
	to_m.y = 0.0
	if to_m.length() > mist.radius * 0.5:
		_walk_toward(p, to_m.normalized(), to_m.length() > SPRINT_DIST)
	else:
		_walk_toward(p, Vector3.ZERO, false)
	if dist <= ATTACK_DIST:
		_tap("attack")
	else:
		_hold("attack", false)
	return true


## 照鏡頭的方向把「往 dir 走」拆成四個方向鍵（dir＝零向量＝都放開）。
func _walk_toward(p: PlayerController, dir: Vector3, sprint: bool) -> void:
	var b := Basis(Vector3.UP, p.yaw)
	var f: float = dir.dot(b * Vector3.FORWARD)
	var r: float = dir.dot(b * Vector3.RIGHT)
	_hold("move_forward", f > 0.38)
	_hold("move_back", f < -0.38)
	_hold("move_right", r > 0.38)
	_hold("move_left", r < -0.38)
	_hold("sprint", sprint)


## 場上還有沒有會走過來打人的（丟毒瓶的不算）
func _melee_alive() -> bool:
	for e: EnemyActor in arena.enemies:
		if not is_instance_valid(e) or e.health == null or e.health.is_dead():
			continue
		if e is DemoGuard and (e as DemoGuard).kind == DemoGuard.KIND_THROWER:
			continue
		return true
	return false


## from 周圍 radius 公尺內還站著的敵人有幾個。純函式。
static func enemies_within(from: Vector3, list: Array[EnemyActor], radius: float) -> int:
	var n: int = 0
	for e: EnemyActor in list:
		if not is_instance_valid(e) or e.health == null or e.health.is_dead():
			continue
		if Vector2(e.global_position.x - from.x, e.global_position.z - from.z).length() <= radius:
			n += 1
	return n


## 最近的、還沒開始淡掉的毒霧（max_dist 公尺以內；沒有＝null）。純函式。
static func nearest_mist(from: Vector3, mists: Array, max_dist: float, min_life: float) -> PoisonMist:
	var best: PoisonMist = null
	var best_d: float = max_dist
	for v: Variant in mists:
		var m: PoisonMist = v as PoisonMist
		if m == null or not is_instance_valid(m) or m.zone == null or m.zone.expired():
			continue
		if m.zone.life >= 0.0 and m.zone.life < min_life:
			continue
		var d: float = Vector2(m.global_position.x - from.x, m.global_position.z - from.z).length()
		if d <= best_d:
			best_d = d
			best = m
	return best


## 最近的、還站著的敵人。純函式。
static func nearest_enemy(from: Vector3, list: Array[EnemyActor]) -> EnemyActor:
	var best: EnemyActor = null
	var best_d: float = INF
	for e: EnemyActor in list:
		if not is_instance_valid(e) or e.health == null or e.health.is_dead():
			continue
		var d: float = Vector2(e.global_position.x - from.x, e.global_position.z - from.z).length()
		if d < best_d:
			best_d = d
			best = e
	return best


## 正在擺前兆、打得到 from、而且剩不到 lead 秒就出手的敵人（沒有＝null）。丟毒瓶的不算。
static func imminent_threat(from: Vector3, list: Array[EnemyActor], lead: float) -> EnemyActor:
	for e: EnemyActor in list:
		if not is_instance_valid(e) or e.health == null or e.health.is_dead():
			continue
		if e.brain.state != EnemyBrain.State.TELEGRAPH:
			continue
		if e is DemoGuard and (e as DemoGuard).kind == DemoGuard.KIND_THROWER:
			continue
		var move: String = e.brain.move_id
		var reach: float = maxf(e.brain.move_num(move, "reach", 0.0) + e.brain.move_num(move, "radius", 0.0), e.brain.move_num(move, "range", e.brain.attack_range))
		var d: float = Vector2(e.global_position.x - from.x, e.global_position.z - from.z).length()
		if d > reach + THREAT_MARGIN:
			continue
		var left: float = e.brain.telegraph_sec * (1.0 - e.brain.telegraph_progress())
		if left <= lead:
			return e
	return null
