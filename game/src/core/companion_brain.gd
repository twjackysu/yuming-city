class_name CompanionBrain
extends RefCounted
## 席菈（同伴）的純邏輯：跟隨、自主斬擊、三個指令（打弱點／閃開／守住）與時機窗、冷卻、拒絕。
## 不碰場景：吃「離諾恩多遠、離目標多遠、目標的 EnemyBrain」，回傳這一幀要做的動作，由 Sheila 節點執行。
## 規則見 docs/design/02-gameplay.md「指令」「同伴：席菈」「數值初版」；數值在 tuning.json 的 sheila.*、difficulty.*。

enum Mode { FOLLOW, ENGAGE, GUARD, DOWN }
enum Move { STAY, TO_LEADER, TO_TARGET, TO_GUARD }

const COMMANDS: PackedStringArray = ["weakpoint", "evade", "guard"]
const MODE_NAMES: PackedStringArray = ["follow", "engage", "guard", "down"]

## 動作（tick 回傳）
const ACT_SLASH: String = "slash"
const ACT_WEAK_STRIKE: String = "weak_strike"
const ACT_COUNTERED: String = "countered"
const ACT_DODGE: String = "dodge"
const ACT_COUNTER: String = "counter"

var mode: Mode = Mode.FOLLOW
var stamina: float = 100.0
## 倒下後經過的秒數；revive_window 內諾恩走近按互動鍵可以拉起，超過就等戰鬥結束
var down_elapsed: float = 0.0
var revive_window: float = 8.0
var max_stamina: float = 100.0
var stamina_regen: float = 25.0
var dodge_cost: float = 20.0
var slash_cost: float = 10.0
var slash_range: float = 1.8
var slash_interval: float = 1.3
var follow_dist: float = 2.4
var engage_range: float = 10.0
var command_cooldown: float = 1.5
## 「閃開」要在前兆的後段下達：標準 0.6＝後 60%
var command_window: float = 0.6
## 閃開成功後的無敵時間
var evade_invuln: float = 0.5
var guard_active: bool = false
## 劇情要她暫時守住（送葬者戰斬完鐵架後守著車隊，D-054）：剩餘秒數；時間到 guard_active 恢復原狀
var guard_hold_left: float = 0.0
var _guard_before_hold: bool = false
## 她站在傷者旁邊、敵人也在旁邊：叫她「閃開」＝讓攻擊砸到傷者 → 拒絕並說理由（02-gameplay）。場景每次下指令前設定。
var near_wounded: bool = false

var _cooldowns: Dictionary = {}
var _slash_timer: float = 0.0
var _queued: PackedStringArray = []
var _invuln_left: float = 0.0
## 閃開成功、等敵人出完招就反擊
var _counter_ready: bool = false


func configure(difficulty: String = "standard") -> CompanionBrain:
	max_stamina = CombatTuning.num("sheila.stamina", 100.0)
	stamina = max_stamina
	stamina_regen = CombatTuning.num("sheila.stamina_regen", 25.0)
	revive_window = CombatTuning.num("sheila.revive_window", 8.0)
	dodge_cost = CombatTuning.num("sheila.dodge_cost", 20.0)
	slash_cost = CombatTuning.num("sheila.slash_cost", 10.0)
	slash_range = CombatTuning.num("sheila.slash_range", 1.8)
	slash_interval = CombatTuning.num("sheila.slash_interval", 1.3)
	engage_range = CombatTuning.num("sheila.engage_range", 10.0)
	command_cooldown = CombatTuning.num("sheila.command_cooldown", 1.5)
	command_window = CombatTuning.num("difficulty.%s.command_window" % difficulty, 0.6)
	return self


func mode_name() -> String:
	return MODE_NAMES[mode]


func is_invulnerable() -> bool:
	return _invuln_left > 0.0


func cooldown_left(cmd: String) -> float:
	return float(_cooldowns.get(cmd, 0.0))


## 倒下而且還在可拉起的時間內。
func can_be_revived() -> bool:
	return mode == Mode.DOWN and down_elapsed <= revive_window


## 拉起剩下的秒數（倒下中；超過時間＝0）。
func revive_time_left() -> float:
	return maxf(revive_window - down_elapsed, 0.0) if mode == Mode.DOWN else 0.0


func set_down(down: bool) -> void:
	mode = Mode.DOWN if down else Mode.FOLLOW
	down_elapsed = 0.0
	if down:
		guard_active = false
		guard_hold_left = 0.0
		_counter_ready = false


## 暫時守住 seconds 秒（不經過指令冷卻與回話）。倒下時不接；守的途中玩家下「守住」會照常切換並結束暫時狀態。
func hold_guard(seconds: float) -> void:
	if mode == Mode.DOWN or seconds <= 0.0:
		return
	if guard_hold_left <= 0.0:
		_guard_before_hold = guard_active
	guard_active = true
	guard_hold_left = seconds


## 下指令。回傳 {accepted, outcome（success／mistimed／""）, line（席菈回話的翻譯 key）}。
## 被接受的指令會進冷卻；被拒絕的不會（玩家可以馬上改下別的）。
func command(cmd: String, target: EnemyBrain) -> Dictionary:
	if not COMMANDS.has(cmd):
		return _refuse("SHEILA_REFUSE_UNKNOWN")
	if mode == Mode.DOWN:
		return _refuse("SHEILA_REFUSE_DOWN")
	if cooldown_left(cmd) > 0.0:
		return _refuse("SHEILA_BUSY")
	var alive: bool = target != null and target.state != EnemyBrain.State.DEAD
	match cmd:
		"weakpoint":
			if not alive:
				return _refuse("SHEILA_REFUSE_NO_TARGET")
			if stamina < slash_cost:
				return _refuse("SHEILA_REFUSE_STAMINA")
			_accept(cmd)
			stamina -= slash_cost
			if target.is_open():
				_queued.append(ACT_WEAK_STRIKE)
				return _result("success", "SHEILA_ACK_WEAKPOINT")
			_queued.append(ACT_COUNTERED)
			return _result("mistimed", "SHEILA_MISTIMED_WEAKPOINT")
		"evade":
			if not alive:
				return _refuse("SHEILA_REFUSE_NO_TARGET")
			if near_wounded:
				return _refuse("SHEILA_REFUSE_WOUNDED")
			if stamina < dodge_cost:
				return _refuse("SHEILA_REFUSE_STAMINA")
			_accept(cmd)
			stamina -= dodge_cost
			_queued.append(ACT_DODGE)
			if evade_in_window(target):
				_invuln_left = evade_invuln
				_counter_ready = true
				return _result("success", "SHEILA_ACK_EVADE")
			return _result("mistimed", "SHEILA_MISTIMED_EVADE")
		"guard":
			_accept(cmd)
			guard_hold_left = 0.0
			guard_active = not guard_active
			return _result("success", "SHEILA_ACK_GUARD" if guard_active else "SHEILA_ACK_UNGUARD")
	return _refuse("SHEILA_REFUSE_UNKNOWN")


## 「閃開」的時機窗：前兆進度落在後 command_window 比例內（故事難度 1.0＝整段前兆都算）。
## 讀不懂的招（攻略沒寫、諾恩還沒看過）一律算失敗。
func evade_in_window(target: EnemyBrain) -> bool:
	if target == null or target.state != EnemyBrain.State.TELEGRAPH or not target.is_readable():
		return false
	return target.telegraph_progress() >= 1.0 - command_window - 0.0001


## 每幀呼叫。回傳這一幀要執行的動作（可能多個）。
func tick(delta: float, leader_dist: float, target: EnemyBrain, target_dist: float) -> PackedStringArray:
	for k: Variant in _cooldowns.keys():
		_cooldowns[k] = maxf(float(_cooldowns[k]) - delta, 0.0)
	_invuln_left = maxf(_invuln_left - delta, 0.0)
	_slash_timer = maxf(_slash_timer - delta, 0.0)
	stamina = minf(stamina + stamina_regen * delta, max_stamina)
	if guard_hold_left > 0.0:
		guard_hold_left = maxf(guard_hold_left - delta, 0.0)
		if guard_hold_left <= 0.0:
			guard_active = _guard_before_hold
	var out: PackedStringArray = _queued
	_queued = []
	if mode == Mode.DOWN:
		down_elapsed += delta
		return out
	var alive: bool = target != null and target.state != EnemyBrain.State.DEAD
	if guard_active:
		mode = Mode.GUARD
	elif alive and target_dist <= engage_range:
		mode = Mode.ENGAGE
	else:
		mode = Mode.FOLLOW
	# 閃開成功：等敵人出完招（進入破綻）就反擊
	if _counter_ready:
		if not alive:
			_counter_ready = false
		elif target.state == EnemyBrain.State.RECOVER or target.state == EnemyBrain.State.STAGGERED:
			_counter_ready = false
			if target_dist <= slash_range + 0.6:
				out.append(ACT_COUNTER)
				_slash_timer = slash_interval
	# 自主斬擊：在範圍內、體力夠、不在敵人前兆中硬拚（她會等前兆過去，除非你叫她）
	if alive and mode != Mode.FOLLOW and target_dist <= slash_range and _slash_timer <= 0.0 \
			and stamina >= slash_cost and target.state != EnemyBrain.State.TELEGRAPH and not out.has(ACT_WEAK_STRIKE):
		stamina -= slash_cost
		_slash_timer = slash_interval
		out.append(ACT_SLASH)
	return out


## 這一幀該往哪走（Sheila 節點負責實際移動）。
func desired_move(leader_dist: float, target_dist: float) -> Move:
	match mode:
		Mode.DOWN:
			return Move.STAY
		Mode.GUARD:
			return Move.TO_TARGET if target_dist <= slash_range * 1.5 else Move.TO_GUARD
		Mode.ENGAGE:
			return Move.TO_TARGET if target_dist > slash_range * 0.85 else Move.STAY
	return Move.TO_LEADER if leader_dist > follow_dist else Move.STAY


func _accept(cmd: String) -> void:
	_cooldowns[cmd] = command_cooldown


func _refuse(line: String) -> Dictionary:
	return {"accepted": false, "outcome": "", "line": line}


func _result(outcome: String, line: String) -> Dictionary:
	return {"accepted": true, "outcome": outcome, "line": line}


## 繞開毒霧（新版，D-207）：席菈沒有逆轉體質，不走進毒霧。centers／radii＝場上每團毒霧的中心與半徑。
## 人在霧裡（或貼著邊）→ 往外走；下一步會踏進去 → 把往裡走的分量拿掉，沿著霧的邊緣滑過去；
## 正對著霧心走（沒有切線分量）→ 選一邊繞。move 是這一幀想走的水平速度，回傳修正後的速度。
static func steer_clear(pos: Vector3, move: Vector3, centers: PackedVector3Array, radii: PackedFloat32Array, margin: float = 0.6) -> Vector3:
	var out: Vector3 = Vector3(move.x, 0.0, move.z)
	var speed: float = out.length()
	for i: int in mini(centers.size(), radii.size()):
		var away := Vector3(pos.x - centers[i].x, 0.0, pos.z - centers[i].z)
		var keep: float = radii[i] + margin
		var dist: float = away.length()
		if dist >= keep + maxf(speed, 1.0) * 0.5:
			continue
		var n: Vector3 = away / dist if dist > 0.01 else Vector3.BACK
		if dist < radii[i]:
			# 已經在霧裡：先出去（至少用走路的速度）
			out = n * maxf(speed, 3.0)
			continue
		var inward: float = -out.dot(n)
		if inward <= 0.0:
			continue
		var tangent: Vector3 = out + n * inward
		if tangent.length() < speed * 0.3:
			tangent = Vector3(-n.z, 0.0, n.x)
		out = tangent.normalized() * speed
	return out

