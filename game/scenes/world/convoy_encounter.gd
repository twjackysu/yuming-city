class_name ConvoyEncounter
extends Node
## 送葬者戰（切片段落 5，docs/design/02-gameplay.md）：目標是讓傷者車隊通過路口，不是擊殺。
## 串起：送葬者第二階段的鐵架拋擲 → FrameThrowEvent（九息石拱擋下／席菈燒薪火劍）→ 車隊抵達＝結束。
## 結束時：送葬者被席菈的薪火劍斬倒（原作演出；之後換過場），寫入旗標：
##   slice.convoy_done＝true、slice.convoy_injured＝傷者數、slice.frame_throw_outcome（拋擲結局）。
## 場景只要把三個節點指給它；提示文字透過 banner 訊號交給 HUD。

signal banner(key: String, seconds: float)
signal finished(injured: int)

var undertaker: Undertaker
var caravan: Caravan
var arch_site: NineBreathSite
## 測試可以指定；空的就用 Game.session.state
var state: GameState
var frame_throw: FrameThrowEvent
## 飛出去的鐵架（演出；擲出後到碎片消失前）
var thrown_frame: ThrownFrame
var done: bool = false


func setup(p_undertaker: Undertaker, p_caravan: Caravan, p_arch: NineBreathSite) -> ConvoyEncounter:
	undertaker = p_undertaker
	caravan = p_caravan
	arch_site = p_arch
	return self


func _ready() -> void:
	if undertaker != null:
		undertaker.frame_throw_started.connect(start_frame_throw)
	if caravan != null:
		caravan.arrived.connect(finish)


func _state() -> GameState:
	if state != null:
		return state
	return Game.session.state if Game.session != null else null


## 鐵架拋擲開始：送葬者停下舉起鐵架，倒數 WINDUP_SEC 秒。
func start_frame_throw() -> void:
	if frame_throw != null or done:
		return
	frame_throw = FrameThrowEvent.new()
	frame_throw.resolved.connect(_on_frame_throw_resolved)
	if undertaker != null:
		undertaker.begin_throw_windup(FrameThrowEvent.WINDUP_SEC)
	banner.emit("FRAME_THROW_WARN", FrameThrowEvent.WINDUP_SEC)


func _physics_process(delta: float) -> void:
	if frame_throw != null and not frame_throw.is_resolved():
		var solid: bool = arch_site != null and arch_site.is_solid()
		frame_throw.tick(delta, solid, _state())


func _on_frame_throw_resolved(outcome: String) -> void:
	banner.emit("FRAME_THROW_ARCH" if outcome == "arch" else "FRAME_THROW_KINDLING", 3.5)
	var from: Vector3 = Vector3.ZERO
	if undertaker != null and is_instance_valid(undertaker):
		from = undertaker.frame_launch_point()
		undertaker.end_throw(outcome)
	# 鐵架真的飛出去（D-042）：石拱擋下 → 撞在石拱上碎掉；燃燒劍 → 席菈在車隊前面把它斬成兩截
	var to: Vector3 = _impact_point(outcome, from)
	var ally: Sheila = _sheila()
	if outcome == "kindling" and ally != null:
		ally.burn_strike(to, 1.6)
	if is_inside_tree():
		thrown_frame = ThrownFrame.create(from, to, outcome, _ground_y())
		thrown_frame.impacted.connect(_on_frame_impact)
		add_child(thrown_frame)


## 鐵架落點：石拱的拱心；燃燒劍路線是席菈身前（沒有席菈就是車隊上方）。
func _impact_point(outcome: String, from: Vector3) -> Vector3:
	if outcome == "arch" and arch_site != null:
		return arch_site.global_position + Vector3.UP * 3.0
	var ally: Sheila = _sheila()
	if ally != null:
		var d: Vector3 = from - ally.global_position
		d.y = 0.0
		var ahead: Vector3 = d.normalized() * 1.2 if d.length() > 0.01 else Vector3.ZERO
		return ally.global_position + ahead + Vector3.UP * 1.7
	if caravan != null:
		return caravan.global_position + Vector3.UP * 2.0
	return from + Vector3(0, -1.0, 4.0)


func _ground_y() -> float:
	if caravan != null:
		return caravan.global_position.y
	return arch_site.global_position.y if arch_site != null else 0.0


func _on_frame_impact(outcome: String) -> void:
	if undertaker != null and is_instance_valid(undertaker):
		var p: PlayerController = undertaker._player
		if p != null:
			p.shake(0.6 if outcome == "arch" else 0.35)
	if thrown_frame != null and is_instance_valid(thrown_frame):
		var at: Vector3 = thrown_frame.to
		Sfx.play_at(self, "iron_clang" if outcome == "arch" else "blunt_weak", at, 6.0, 0.02, 14.0)
	if outcome == "arch" and arch_site != null:
		arch_site.flash()


func _sheila() -> Sheila:
	if not is_inside_tree():
		return null
	for n: Node in get_tree().get_nodes_in_group("companion"):
		if n is Sheila and not (n as Sheila).health.is_dead():
			return n as Sheila
	return null


## 車隊通過路口：戰鬥結束，送葬者被斬倒。
func finish() -> void:
	if done:
		return
	done = true
	var injured: int = caravan.runner.injured if caravan != null else 0
	var st: GameState = _state()
	if st != null:
		st.set_flag("slice.convoy_done", true)
		st.set_flag("slice.convoy_injured", injured)
		# 結尾席菈用燃燒劍斬倒送葬者：手傷 +1（提前燒過的話已經是 2）
		st.set_flag("sheila.hand_injury", int(st.get_flag("sheila.hand_injury", 0)) + 1)
	if undertaker != null and is_instance_valid(undertaker) and not undertaker.health.is_dead():
		var ally: Sheila = _sheila()
		if ally != null:
			ally.burn_strike(undertaker.global_position + Vector3.UP * 1.6, 2.4)
		undertaker.health.apply_damage(undertaker.health.hp, {"kind": "kindling", "stagger": 0.0})
	banner.emit("CONVOY_THROUGH", 4.0)
	finished.emit(injured)
