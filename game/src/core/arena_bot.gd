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
## - circle：跟 mash 一樣一直按出手、不閃，但是靠近之後一直往右繞（D-244）。人邊走邊按的時候就是這樣；
##   mash 永遠正對著敵人走，量不到「邊走邊打會不會揮空」。

const KIND_IDLE: String = "idle"
const KIND_MASH: String = "mash"
const KIND_SKILLED: String = "skilled"
const KIND_CIRCLE: String = "circle"
const KINDS: PackedStringArray = [KIND_IDLE, KIND_MASH, KIND_SKILLED, KIND_CIRCLE]
const ACTIONS: PackedStringArray = ["move_forward", "move_back", "move_left", "move_right", "sprint", "attack", "dodge"]
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

var kind: String = KIND_IDLE
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
		_hold("dodge", false)
	_hold("move_forward", dist > STOP_DIST)
	_hold("sprint", dist > SPRINT_DIST)
	_hold("move_right", kind == KIND_CIRCLE and dist <= CIRCLE_DIST)
	if dist <= ATTACK_DIST:
		_tap("attack")
	else:
		_hold("attack", false)


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
