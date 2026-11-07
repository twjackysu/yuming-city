class_name EnemyBrain
extends RefCounted
## 一般敵人（灰巡者）的純邏輯狀態機：追 → 前兆 → 出招 → 破綻 → 追；失衡滿了跪地。
## 不碰場景，只吃「離玩家多遠」與時間；出招那一刻回傳 true，由角色節點判定命中。
## 數值來自 CombatTuning（ashwalker.*、difficulty.*.telegraph）。

enum State { IDLE, CHASE, TELEGRAPH, STRIKE, RECOVER, STAGGERED, DEAD }

const STATE_NAMES: PackedStringArray = ["idle", "chase", "telegraph", "strike", "recover", "staggered", "dead"]

var state: State = State.IDLE
var time_in_state: float = 0.0
var stagger: float = 0.0

var aggro_range: float = 14.0
var attack_range: float = 1.8
var telegraph_sec: float = 0.8
var strike_sec: float = 0.15
var recover_sec: float = 0.6
var stagger_max: float = 60.0
var stagger_kneel_sec: float = 2.0


func configure(prefix: String, difficulty: String = "standard") -> EnemyBrain:
	telegraph_sec = CombatTuning.num(prefix + ".telegraph", 0.8) * CombatTuning.num("difficulty.%s.telegraph" % difficulty, 1.0)
	stagger_max = CombatTuning.num(prefix + ".stagger_max", 60.0)
	recover_sec = CombatTuning.num(prefix + ".recover", 0.6)
	attack_range = CombatTuning.num(prefix + ".attack_range", 1.8)
	return self


func state_name() -> String:
	return STATE_NAMES[state]


## 每幀呼叫。回傳 true＝這一幀出招（角色節點去判定命中）。
func tick(delta: float, dist_to_player: float) -> bool:
	time_in_state += delta
	match state:
		State.IDLE:
			if dist_to_player <= aggro_range:
				_enter(State.CHASE)
		State.CHASE:
			if dist_to_player <= attack_range:
				_enter(State.TELEGRAPH)
		State.TELEGRAPH:
			if time_in_state >= telegraph_sec:
				_enter(State.STRIKE)
				return true
		State.STRIKE:
			if time_in_state >= strike_sec:
				_enter(State.RECOVER)
		State.RECOVER:
			if time_in_state >= recover_sec:
				_enter(State.CHASE)
		State.STAGGERED:
			if time_in_state >= stagger_kneel_sec:
				stagger = 0.0
				_enter(State.CHASE)
	return false


## 前兆進度 0..1（畫面上的霜紋亮度用）。
func telegraph_progress() -> float:
	return clampf(time_in_state / telegraph_sec, 0.0, 1.0) if state == State.TELEGRAPH else 0.0


## 受到失衡值；滿了打斷前兆並跪地。回傳是否因此跪地。
func add_stagger(amount: float) -> bool:
	if state == State.DEAD or state == State.STAGGERED:
		return false
	stagger += amount
	if stagger >= stagger_max:
		_enter(State.STAGGERED)
		return true
	return false


func kill() -> void:
	_enter(State.DEAD)


func is_moving() -> bool:
	return state == State.CHASE


func _enter(s: State) -> void:
	state = s
	time_in_state = 0.0
