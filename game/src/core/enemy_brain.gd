class_name EnemyBrain
extends RefCounted
## 敵人的純邏輯狀態機：追 → 前兆 → 出招 → 破綻 → 追；失衡滿了跪地；被諾恩打中會後仰（flinch，D-240）。
## 不碰場景，只吃「離目標多遠」與時間；出招那一刻回傳 true，由角色節點判定命中。
## 數值來自 CombatTuning（<prefix>.*、difficulty.*.telegraph）。
## 一般敵人只有一招（attack_range 內就出）；精英敵人在 <prefix>.moves 定義多招，依 <prefix>.pattern 輪流，
## 每招有自己的距離（min_range～range）、前兆、出招、破綻時間（送葬者：橫掃／下砸／衝撞）。
## 連段：某招有 "chain": "<下一招 id>" 時，出招結束直接進下一招的前兆（不經破綻）。現在沒有招式用，留給之後的頭目（D-225）。
## 讀不懂的招（unreadable[id] = true）：席菈的「閃開」對它一律算失敗，直到諾恩看過一次（看穿變已證實）。

## FLINCH＝被諾恩打中往後仰的那一下（D-240）。加在最後面：前面幾個的數值不變。
enum State { IDLE, CHASE, TELEGRAPH, STRIKE, RECOVER, STAGGERED, DEAD, FLINCH }

## 跪下的那一刻（失衡滿了、撞牆）：角色節點播「膝蓋落地」的重音（D-191）。已經跪著再被逼跪不算。
signal knelt

## 被打中、往後仰的那一刻（角色節點往後退一小步）。interrupted＝這一下把正在擺的前兆打斷了。
signal flinched(interrupted: bool)

const STATE_NAMES: PackedStringArray = ["idle", "chase", "telegraph", "strike", "recover", "staggered", "dead", "flinch"]

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
## 目前（或下一個）招式 id；看穿顯示「▶ 爪擊」用
var move_id: String = "claw"
## 多招敵人：id → {telegraph, active, recover, min_range, range, ...}；空的＝一般敵人單招
var moves: Dictionary = {}
var pattern: PackedStringArray = []
## 讀不懂的招：id → true（看穿未證實、席菈抓不到時機）
var unreadable: Dictionary = {}
## 挨打後仰（D-240）。flinch_sec＝仰多久（0＝這種敵人不會後仰：劇情裡的敵人、頭目）。
## 後仰過 brace_after 次之後「硬撐」：不再後仰、前兆打不斷（還是會扣血），下一招一定打得出來——
## 不然一直按出手就能把人鎖到死。出完一招（進破綻）或跪完起來就重新算。招式資料寫 "unstoppable": true＝這一招永遠打不斷。
var flinch_sec: float = 0.0
var brace_after: int = 2
## 後仰的時候被往後推多遠（公尺；角色節點在 flinch_sec 內走完）
var flinch_push: float = 0.4
## 這一輪已經後仰了幾次（出完一招歸零）；畫面（硬撐的顏色）與測試用 is_braced()
var interrupts: int = 0
## 這一幀可不可以開始擺前兆（角色節點每幀設：同時只有幾個人可以對同一個目標出手，D-240）
var may_attack: bool = true
var _pattern_i: int = 0
var _telegraph_mult: float = 1.0
var _base_telegraph: float = 0.8
var _base_recover: float = 0.6
## 這次跪地要多久（撞牆等特殊跪地會改）
var _kneel_sec: float = 2.0


func configure(prefix: String, difficulty: String = "standard") -> EnemyBrain:
	_telegraph_mult = CombatTuning.num("difficulty.%s.telegraph" % difficulty, 1.0)
	_base_telegraph = CombatTuning.num(prefix + ".telegraph", 0.8)
	telegraph_sec = _base_telegraph * _telegraph_mult
	stagger_max = CombatTuning.num(prefix + ".stagger_max", 60.0)
	stagger_kneel_sec = CombatTuning.num(prefix + ".stagger_kneel", 2.0)
	_base_recover = CombatTuning.num(prefix + ".recover", 0.6)
	recover_sec = _base_recover
	attack_range = CombatTuning.num(prefix + ".attack_range", 1.8)
	telegraph_stagger_mult = CombatTuning.num(prefix + ".telegraph_stagger_mult", 0.5)
	recover_stagger_mult = CombatTuning.num(prefix + ".recover_stagger_mult", 2.0)
	# 後仰的三個數字只有會後仰的敵人才寫（戰鬥場的 profiles.arena）；沒寫＝不後仰，不要印「沒有這個 key」
	flinch_sec = CombatTuning.num(prefix + ".flinch", 0.0) if _has(prefix + ".flinch") else 0.0
	brace_after = int(CombatTuning.num(prefix + ".brace_after", 2.0)) if _has(prefix + ".brace_after") else 2
	flinch_push = CombatTuning.num(prefix + ".flinch_push", 0.4) if _has(prefix + ".flinch_push") else 0.4
	var mv: Variant = CombatTuning.value(prefix + ".moves", {}) if _has(prefix + ".moves") else {}
	# 複製一份：個別敵人改自己的招式數值時，不能改到共用的 CombatTuning 資料
	moves = (mv as Dictionary).duplicate(true) if mv is Dictionary else {}
	var pat: Variant = CombatTuning.value(prefix + ".pattern", []) if _has(prefix + ".pattern") else []
	pattern = PackedStringArray(pat as Array) if pat is Array else PackedStringArray()
	if not moves.is_empty() and pattern.is_empty():
		pattern = PackedStringArray(moves.keys())
	if not pattern.is_empty():
		move_id = pattern[0]
	return self


func state_name() -> String:
	return STATE_NAMES[state]


## 某招的數值（沒有就回傳 fallback）。
func move_num(id: String, key: String, fallback: float = 0.0) -> float:
	var m: Variant = moves.get(id, {})
	if m is Dictionary and (m as Dictionary).has(key):
		return float((m as Dictionary)[key])
	return fallback


## 每幀呼叫。回傳 true＝這一幀出招（角色節點去判定命中）。
func tick(delta: float, dist_to_target: float) -> bool:
	time_in_state += delta
	match state:
		State.IDLE:
			if dist_to_target <= aggro_range:
				_enter(State.CHASE)
		State.CHASE:
			if may_attack and _choose_move(dist_to_target):
				_enter(State.TELEGRAPH)
		State.TELEGRAPH:
			if time_in_state >= telegraph_sec:
				_enter(State.STRIKE)
				return true
		State.STRIKE:
			if time_in_state >= strike_sec:
				var nxt: String = _chain_of(move_id)
				if nxt != "":
					_set_move(nxt)
					_enter(State.TELEGRAPH)
				else:
					interrupts = 0
					_enter(State.RECOVER)
		State.FLINCH:
			if time_in_state >= flinch_sec:
				_enter(State.CHASE)
		State.RECOVER:
			if time_in_state >= recover_sec:
				_enter(State.CHASE)
		State.STAGGERED:
			if time_in_state >= _kneel_sec:
				stagger = 0.0
				interrupts = 0
				_enter(State.CHASE)
	return false


## 依距離挑下一招；挑到就設定這招的時間並回傳 true。
func _choose_move(dist: float) -> bool:
	if moves.is_empty():
		if dist > attack_range:
			return false
		telegraph_sec = _base_telegraph * _telegraph_mult
		recover_sec = _base_recover
		return true
	for k: int in pattern.size():
		var i: int = (_pattern_i + k) % pattern.size()
		var id: String = pattern[i]
		if dist >= move_num(id, "min_range", 0.0) and dist <= move_num(id, "range", attack_range):
			_pattern_i = (i + 1) % pattern.size()
			_set_move(id)
			return true
	return false


func _set_move(id: String) -> void:
	move_id = id
	telegraph_sec = move_num(id, "telegraph", _base_telegraph) * _telegraph_mult
	strike_sec = move_num(id, "active", 0.15)
	recover_sec = move_num(id, "recover", _base_recover)


func _chain_of(id: String) -> String:
	var m: Variant = moves.get(id, {})
	return str((m as Dictionary).get("chain", "")) if m is Dictionary else ""


## 換招式輪替（送葬者的追擊版與守衛版）。從新 pattern 的第一招開始。
func set_pattern(p: PackedStringArray) -> void:
	if p.is_empty():
		return
	pattern = p
	_pattern_i = 0
	if state in [State.IDLE, State.CHASE]:
		move_id = pattern[0]


## 看穿用的招式 id：連段的後續招（"intel": "<第一招 id>"）對回同一條資訊。
func intel_move() -> String:
	var cur: String = current_move()
	if cur == "":
		return ""
	var m: Variant = moves.get(cur, {})
	return str((m as Dictionary).get("intel", cur)) if m is Dictionary else cur


## 目前這招讀得懂嗎（席菈「閃開」的前提）。
func is_readable() -> bool:
	return not bool(unreadable.get(move_id, false))


## 前兆進度 0..1（畫面上的霜紋亮度用）。
func telegraph_progress() -> float:
	return clampf(time_in_state / telegraph_sec, 0.0, 1.0) if state == State.TELEGRAPH else 0.0


## 受到失衡值（依狀態套倍率）；滿了打斷前兆並跪地。回傳是否因此跪地。
func add_stagger(amount: float) -> bool:
	if state == State.DEAD or state == State.STAGGERED:
		return false
	stagger += amount * stagger_mult()
	if stagger >= stagger_max:
		_kneel_sec = stagger_kneel_sec
		_enter(State.STAGGERED)
		return true
	return false


## 被諾恩打中的那一下：往後仰 flinch_sec 秒。追人中 → 停一下；前兆中 → 打斷（標了打不斷的招除外）。
## 出招、破綻、跪地中不改狀態（破綻的時間不會被重新算，不然打得越快他越晚醒）。
## 每後仰一次記一次；記滿 brace_after 次就「硬撐」：不再後仰，直到他打出一招。回傳有沒有真的後仰。
func flinch() -> bool:
	if flinch_sec <= 0.0 or is_braced():
		return false
	var interrupted: bool = state == State.TELEGRAPH
	if interrupted and _unstoppable(move_id):
		return false
	if state not in [State.CHASE, State.FLINCH, State.TELEGRAPH]:
		return false
	interrupts += 1
	_enter(State.FLINCH)
	flinched.emit(interrupted)
	return true


## 硬撐中：打不斷、不後仰（已經後仰過 brace_after 次），打出一招之後才重新算。
func is_braced() -> bool:
	return flinch_sec > 0.0 and interrupts >= brace_after and state != State.DEAD


func _unstoppable(id: String) -> bool:
	var m: Variant = moves.get(id, {})
	return m is Dictionary and bool((m as Dictionary).get("unstoppable", false))


## 衝撞撞牆之類的硬直：直接跪地 seconds 秒（不累積失衡）。
func force_kneel(seconds: float) -> void:
	if state == State.DEAD:
		return
	_kneel_sec = seconds
	_enter(State.STAGGERED)


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
	var was: State = state
	state = s
	time_in_state = 0.0
	if s == State.STAGGERED and was != State.STAGGERED:
		knelt.emit()


static func _has(path: String) -> bool:
	var node: Variant = CombatTuning.value(path.get_slice(".", 0), {})
	return node is Dictionary and (node as Dictionary).has(path.get_slice(".", 1))
