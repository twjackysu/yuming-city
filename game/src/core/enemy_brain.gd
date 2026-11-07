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
## 前兆中受擊：不打斷出招，失衡打折（硬撐）；破綻中受擊：失衡加倍（教玩家等破綻）
var telegraph_stagger_mult: float = 0.5
var recover_stagger_mult: float = 2.0
## 目前（唯一）的招式 id，看穿顯示「▶ 爪擊」用；精英敵人之後會有多招
var move_id: String = "claw"


func configure(prefix: String, difficulty: String = "standard") -> EnemyBrain:
	telegraph_sec = CombatTuning.num(prefix + ".telegraph", 0.8) * CombatTuning.num("difficulty.%s.telegraph" % difficulty, 1.0)
	stagger_max = CombatTuning.num(prefix + ".stagger_max", 60.0)
	recover_sec = CombatTuning.num(prefix + ".recover", 0.6)
	attack_range = CombatTuning.num(prefix + ".attack_range", 1.8)
	telegraph_stagger_mult = CombatTuning.num(prefix + ".telegraph_stagger_mult", 0.5)
	recover_stagger_mult = CombatTuning.num(prefix + ".recover_stagger_mult", 2.0)
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


## 受到失衡值（依狀態套倍率）；滿了打斷前兆並跪地。回傳是否因此跪地。
func add_stagger(amount: float) -> bool:
	if state == State.DEAD or state == State.STAGGERED:
		return false
	stagger += amount * stagger_mult()
	if stagger >= stagger_max:
		_enter(State.STAGGERED)
		return true
	return false


## 目前狀態下受擊的失衡倍率。
func stagger_mult() -> float:
	match state:
		State.TELEGRAPH:
			return telegraph_stagger_mult
		State.RECOVER:
			return recover_stagger_mult
	return 1.0


## 正在出的招（前兆／出招中），沒有就回傳空字串。
func current_move() -> String:
	return move_id if state in [State.TELEGRAPH, State.STRIKE] else ""


## 破綻中（攻擊後或跪地）：席菈「打弱點」的時機。
func is_open() -> bool:
	return state == State.RECOVER or state == State.STAGGERED


func kill() -> void:
	_enter(State.DEAD)


func is_moving() -> bool:
	return state == State.CHASE


func _enter(s: State) -> void:
	state = s
	time_in_state = 0.0
