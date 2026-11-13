class_name DemoGuard
extends EnemyActor
## 示範場的守衛（第二段 B 的後半，D-233）：人形的小敵人，身體是程序人偶（跟布景裡那兩個守衛同一套顏色）。
## 兩種（進場景樹之前設 `kind`）：
## - club＝台下拿棍子的：棍子橫掃（swing，寬）、直刺（thrust，窄但遠）。
## - bracer＝台上示範、兩手戴著高速護腕的：快拳（jab）前兆很短，但**每打完一拳右手就麻掉、垂著僵住很久**
##   （破綻長、破綻中失衡三倍）——商人沒講的副作用，打起來一看就知道。他的左手從頭到尾垂著不動（早就麻了）。
## - thrower＝丟毒瓶的（小戰檢驗，D-235）：站在後面，把發綠光的瓶子丟到諾恩腳邊，落地一團小毒霧（3 秒）。
##   這一下沒有直接傷害——對席菈是中毒，對諾恩是回血。生命最少、丟完要掏下一瓶（破綻長），近身就沒招。
## 前兩種沒有狀態攻擊：中毒回血在示範場那一場幫不上忙。倒下之後躺在原地（是人，不沉進地裡），也不再算敵人。

const KIND_CLUB: String = "club"
const KIND_BRACER: String = "bracer"
const KIND_THROWER: String = "thrower"
## 丟毒瓶的：深橄欖色的外套（跟另外兩個分得開）、瓶子的綠光（跟藥店、毒霧同一個綠）
const THROWER_COAT: Color = Color(0.13, 0.17, 0.11)
const BOTTLE_GLOW: Color = Color(0.45, 1.0, 0.4)
const BOTTLE_ENERGY: float = 1.6
const MIST_SOURCE: String = "poison_bottle"
## 瓶子飛出去的弧線最高點比兩端高多少
const TOSS_ARC: float = 1.5
const COAT: Color = Color(0.12, 0.14, 0.19)
const TRIM: Color = Color(0.5, 0.47, 0.42)
## 護腕箍上的冷光（跟台上桌子上那三個同一個顏色）；麻掉的時候變成一閃一閃的暗紅
const BRACER_GLOW: Color = Color(0.6, 0.85, 1.0)
const NUMB_GLOW: Color = Color(1.0, 0.3, 0.16)
const BRACER_ENERGY: float = 2.6
## 棍頭的銅箍：平常幾乎不亮，前兆時亮起來（看得出他要出手了）
const CLUB_GLOW: Color = Color(1.0, 0.72, 0.4)
## 斜掛在胸前的紅白布條（跟示範台的直條紋同一組顏色）：深色的人在暗的街上看得出「這兩個是商人的人」，也跟看熱鬧的人分得開
## 硬撐（後仰過幾次之後：打不斷、下一招一定打得出來，D-240）：棍箍／護腕燒成紅的，還沒擺前兆就亮著——看到紅的就該閃
const BRACE_GLOW: Color = Color(1.0, 0.2, 0.08)
const BRACE_ENERGY: float = 3.2
const SASH_RED: Color = Color(0.66, 0.11, 0.1)
const SASH_WHITE: Color = Color(0.86, 0.82, 0.74)
const STRIDE: float = 0.78
const STEP_DB: float = -15.0

var kind: String = KIND_CLUB
## 身高倍率（布景的那兩個是 1.1／1.08）
var height: float = 1.1
## 出過幾招、最後一招（測試用）
var strike_count: int = 0
var last_move: String = ""
## 截圖用：停在某個姿勢（不追、不出招）
var debug_hold: bool = false
## 還沒開打：站在原地等（不追、不出招、不算敵人——席菈不會先衝過去、鏡頭不會拉遠）。用 set_waiting() 改
var waiting: bool = false
## `focus_player`（只追諾恩）搬到 EnemyActor 了（D-239）。小戰檢驗：商人的人是來找他討護腕的——都追「最近的心跳」的話，
## 兩個拿棍子的會一起圍席菈，諾恩站著不動的時候她 16 秒就倒了（D-235）
## 丟毒瓶的：丟過幾瓶、最後一瓶落地的那團霧（還在飛的時候是 null）、最後一瓶瞄的落點
var toss_count: int = 0
var last_mist: PoisonMist
var last_toss_at: Vector3 = Vector3.ZERO
var _hand_bottle: Node3D
## 愣住（D-246）：丟毒瓶的看到諾恩站在毒霧裡不出來——手上的事停下來、往後退一小段、這段時間不丟瓶子。
## gawk_left＝還要愣幾秒；gawk_count＝愣過幾次（測試、統計用）。數值在 tuning.json 的 demo_thrower.gawk_*。
const GAWK_BACK_SEC: float = 0.5
var gawk_left: float = 0.0
var gawk_count: int = 0
var _gawk_total: float = 0.0
var _gawk_cooldown: float = 0.0
## 愣住的那一刻手一滑（D-247）：手上的瓶子掉在自己腳邊、碎成一團霧（同一種霧：諾恩走過去也能站），他自己被嗆到——
## 愣著的時候每 FUMBLE_TICK 秒扣一次血，總共 demo_thrower.fumble_damage，扣到剩 1 為止（不會被自己毒死：
## 他是毒的來源，要不要留著他是玩家決定的）。fumble_damage 是 0＝只愣住、瓶子不掉。
## 玩家的鏡頭裡他被前面拿棍子的擋住，姿勢與這團霧都看不到（只有 --tele-cam 拍得到，第 99 輪）；玩家看得到的是他少了半條血。
const FUMBLE_TICK: float = 0.4
const FUMBLE_TICKS: int = 4
const FUMBLE_DROP_SEC: float = 0.22
var fumble_count: int = 0
var fumble_dealt: float = 0.0
var last_fumble_mist: PoisonMist
var _fumbling: bool = false
var _fumble_tick: float = 0.0
var _fumble_budget: float = 0.0
## 被毒霧嗆到（D-248）：拿棍子的／戴護腕的踩進毒霧（或毒霧落在他身上）的那一刻——咳、往霧外跳開、扣一點血。
## 同一個人同一團霧只一次；走的是現成的後仰（brain.flinch()：前兆會被打斷、算一次後仰，滿了照樣硬撐）；
## 已經變紅的人不會被嗆到（照樣衝進來）；出招、破綻、跪著的時候先不嗆，回到追人的那一幀才嗆。扣血扣到剩 1 為止。
## 嗆過之後還待在那一團霧裡（走回去找諾恩）的時候，空著的那隻手摀著嘴。
## 為什麼：「別人躲、諾恩不躲」要發生在玩家的鏡頭正中間——會愣住的丟毒瓶的站在 8 m 外，玩家看不到（第 99 輪）。
## 數值在 tuning.json 的 crowd.choke_*（劇情的預設 choke_enabled 0＝沒有這件事）。
const CHOKE_POSE_SEC: float = 0.9
const CHOKE_HOLD_SEC: float = 0.25
var choke_count: int = 0
var choke_dealt: float = 0.0
var choke_left: float = 0.0
var _choked_by: Dictionary = {}
var _breath_hold: float = 0.0

var _puppet: Puppet
var _glow_mat: StandardMaterial3D
var _time: float = 0.0


## 蓋掉人偶的關節：人偶自己的 `_pose` 每一幀都會重設，所以掛在人偶底下、排在它後面跑。
class PoseDriver extends Node:
	var guard: DemoGuard

	func _process(delta: float) -> void:
		if guard != null and is_instance_valid(guard):
			guard.apply_pose(delta)


func intel_id() -> String:
	match kind:
		KIND_BRACER:
			return "demo_bracer"
		KIND_THROWER:
			return "demo_thrower"
	return "demo_guard"


func is_thrower() -> bool:
	return kind == KIND_THROWER


## 開打之前站著等／開打。等的時候不在 enemies、damageable 群組裡（鎖定、席菈、戰鬥 HUD、諾恩的揮擊都看不到他）。
func set_waiting(on: bool) -> void:
	waiting = on
	for g: String in ["enemies", "damageable"]:
		if on:
			remove_from_group(g)
		elif not health.is_dead():
			add_to_group(g)


func is_bracer() -> bool:
	return kind == KIND_BRACER


## 丟毒瓶的不排隊出手（他站在後面丟；霧對諾恩是回血），也不佔別人的名額。
func uses_attack_slot() -> bool:
	return kind != KIND_THROWER


func puppet() -> Puppet:
	return _puppet


## 右手麻掉了（快拳之後的破綻）：護腕變暗紅、手垂著
func is_numb() -> bool:
	return is_bracer() and brain != null and brain.state == EnemyBrain.State.RECOVER


func glow_energy() -> float:
	return _glow_mat.emission_energy_multiplier if _glow_mat != null else 0.0


func glow_color() -> Color:
	return _glow_mat.emission if _glow_mat != null else Color.BLACK


## 從台子上跳下來：只有身體從 from_height 落到地上（碰撞的膠囊一開始就在地上，不靠物理掉下來）。
func hop_down(from_height: float, sec: float) -> void:
	if _body == null:
		return
	_body.position.y = from_height
	var t := create_tween()
	t.tween_property(_body, "position:y", 0.0, sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## 截圖用：停在某一招的某個狀態（ratio＝那個狀態走到幾成），面向 look。之後不追、不出招。
func hold_pose(move: String, state: EnemyBrain.State, ratio: float, look: Vector3) -> void:
	debug_hold = true
	brain._set_move(move)
	brain.state = state
	var span: float = brain.telegraph_sec if state == EnemyBrain.State.TELEGRAPH else brain.recover_sec
	brain.time_in_state = span * ratio
	var d: Vector3 = look - global_position
	set_facing(atan2(-d.x, -d.z))
	_update_look()


func _make_footsteps() -> Footsteps:
	var f := Footsteps.new(STRIDE, STRIDE, STEP_DB, STEP_DB)
	f.pitch_base = 0.92
	f.pitch_jitter = 0.06
	f.unit_size = 3.5
	return f


func _insight_height() -> float:
	return 1.85 * height


func _hit_height() -> float:
	return 1.1 * height


func _held(delta: float) -> bool:
	choke_left = maxf(choke_left - delta, 0.0)
	_breath_hold = maxf(_breath_hold - delta, 0.0)
	if gawk_left > 0.0:
		gawk_left = maxf(gawk_left - delta, 0.0)
		if _fumbling:
			_tick_fumble(delta)
		return true
	_gawk_cooldown = maxf(_gawk_cooldown - delta, 0.0)
	return debug_hold or waiting


## 愣住的前 GAWK_BACK_SEC 秒往後退 gawk_back 公尺（用自己的腳走，撞到牆就停）。
func _held_velocity(_delta: float) -> Vector3:
	if gawk_left > 0.0 and _gawk_total - gawk_left < GAWK_BACK_SEC:
		return -forward() * (CombatTuning.num("demo_thrower.gawk_back", 1.0) / GAWK_BACK_SEC)
	return Vector3.ZERO


func is_gawking() -> bool:
	return gawk_left > 0.0


## 現在會不會愣住：只有丟毒瓶的；剛愣過（gawk_cooldown 秒內）、正在出手的那一下、跪著、倒下、開打前站著等的時候不會。
func can_gawk() -> bool:
	if not is_thrower() or waiting or debug_hold or gawk_left > 0.0 or _gawk_cooldown > 0.0:
		return false
	if brain == null or health == null or health.is_dead():
		return false
	return brain.state not in [EnemyBrain.State.DEAD, EnemyBrain.State.STAGGERED, EnemyBrain.State.STRIKE]


## 愣住 gawk_sec 秒（Arena 在諾恩站進毒霧不出來的時候叫）：正在舉的那一瓶放下來（前兆取消）、往後退、不丟。
## 回傳有沒有真的愣住。gawk_sec 是 0＝沒有這件事。
func gawk() -> bool:
	var sec: float = CombatTuning.num("demo_thrower.gawk_sec", 0.0)
	if sec <= 0.0 or not can_gawk():
		return false
	brain.break_off()
	gawk_left = sec
	_gawk_total = sec
	_gawk_cooldown = CombatTuning.num("demo_thrower.gawk_cooldown", 10.0)
	gawk_count += 1
	_fumbling = CombatTuning.num("demo_thrower.fumble_damage", 0.0) > 0.0
	if _fumbling:
		_fumble()
	return true


## 這一團霧嗆過他了沒（硬撐著衝進去的也算：那一團對他沒有用了）。
func choked_by(mist: PoisonMist) -> bool:
	return mist != null and _choked_by.has(mist.get_instance_id())


## 摀著嘴（剛嗆到，或嗆過之後還待在那團霧裡）。
func is_covering_mouth() -> bool:
	return choke_left > 0.0 or _breath_hold > 0.0


## 他站在 mist 裡（Arena 每個物理幀對霧裡的每個人叫一次）。回傳這一幀有沒有被嗆到。
func choke(mist: PoisonMist) -> bool:
	if mist == null or not is_instance_valid(mist) or is_thrower() or waiting or debug_hold:
		return false
	if brain == null or health == null or health.is_dead() or CombatTuning.num("crowd.choke_enabled", 0.0) <= 0.0:
		return false
	var id: int = mist.get_instance_id()
	if _choked_by.has(id):
		_breath_hold = CHOKE_HOLD_SEC
		return false
	if brain.is_braced():
		# 變紅的人照樣衝進來：這一團霧對他沒有用
		_choked_by[id] = true
		return false
	var away: Vector3 = global_position - mist.global_position
	away.y = 0.0
	var inside: float = away.length()
	var old_dir: Vector3 = _push_dir
	_push_dir = away.normalized() if inside > 0.05 else -forward()
	if not brain.flinch():
		_push_dir = old_dir
		return false
	_choked_by[id] = true
	# 往霧外跳：到霧的邊再多 choke_margin 公尺，最多 choke_push_max（站在正中間的人跳不出去，那一團也不會再嗆他）
	var out: float = clampf(mist.radius - inside + CombatTuning.num("crowd.choke_margin", 0.35), 0.3, CombatTuning.num("crowd.choke_push_max", 1.4))
	_push_speed = out / maxf(brain.flinch_sec, 0.01)
	choke_count += 1
	choke_left = CHOKE_POSE_SEC
	var amount: float = minf(CombatTuning.num("crowd.choke_damage", 0.0), health.hp - 1.0)
	if amount > 0.0:
		choke_dealt += health.apply_status_damage(amount, {"source": self, "kind": "poison"})
	if is_inside_tree():
		Sfx.play_at(get_parent(), "poison_hiss", global_position + Vector3.UP * 1.45 * height, -9.0, 0.1, 5.0)
		_cough_puff(9)
	return true


## 嘴邊咳出一小團綠（手一滑的那個人與被嗆到的人共用）。
func _cough_puff(amount: int) -> void:
	# 小小的幾顆（預設的粉一顆 25～56 cm，第一版連拍上是一大團白綠的球，把他的臉跟摀嘴的手整個蓋住）
	var ps: CPUParticles3D = puff_build(Vector3(0.05, 0.04, 0.05), amount, Color(0.62, 0.95, 0.55, 0.6))
	ps.spread = 30.0
	ps.direction = forward() + Vector3.UP * 0.15
	ps.initial_velocity_min = 0.9
	ps.initial_velocity_max = 1.9
	ps.lifetime = 0.55
	ps.scale_amount_min = 0.22
	ps.scale_amount_max = 0.45
	puff_start(ps, global_position + forward() * 0.25 + Vector3.UP * 1.45 * height)


func is_fumbling() -> bool:
	return _fumbling and gawk_left > 0.0


## 手一滑：瓶子從手上掉到腳前（FUMBLE_DROP_SEC 秒），落地碎成霧。
func _fumble() -> void:
	fumble_count += 1
	_fumble_budget = CombatTuning.num("demo_thrower.fumble_damage", 0.0)
	_fumble_tick = FUMBLE_DROP_SEC + 0.1
	var parent: Node = get_parent()
	if parent == null or not is_inside_tree():
		return
	var from: Vector3 = global_position + forward() * 0.3 + Vector3.UP * 1.35 * height
	var to: Vector3 = global_position + forward() * 0.35
	var bottle: Node3D = _bottle_node(1.45, BOTTLE_ENERGY * 2.2)
	bottle.name = "FumbledBottle%d" % fumble_count
	bottle.position = from
	parent.add_child(bottle)
	var fall := func(k: float) -> void:
		if is_instance_valid(bottle):
			bottle.global_position = from.lerp(to, k * k)
			bottle.rotation.x = k * 5.0
	var t: Tween = bottle.create_tween()
	t.tween_method(fall, 0.0, 1.0, FUMBLE_DROP_SEC)
	t.tween_callback(_fumble_landed.bind(bottle, to))


func _fumble_landed(bottle: Node3D, at: Vector3) -> void:
	var parent: Node = bottle.get_parent() if is_instance_valid(bottle) else null
	if is_instance_valid(bottle):
		bottle.queue_free()
	if parent == null:
		return
	last_fumble_mist = _break_bottle(parent, at, CombatTuning.num("demo_thrower.fumble_radius", 1.6),
		CombatTuning.num("demo_thrower.fumble_life", 3.0), "FumbleMist%d_%d" % [get_instance_id() % 1000, fumble_count])


## 被自己的毒嗆到：每 FUMBLE_TICK 秒扣一次，嘴邊咳出一小團綠。走的是狀態傷害（不後仰、沒有命中的火花）。
func _tick_fumble(delta: float) -> void:
	_fumble_tick -= delta
	if _fumble_tick > 0.0 or _fumble_budget <= 0.0 or health == null or health.is_dead():
		return
	_fumble_tick = FUMBLE_TICK
	var per: float = CombatTuning.num("demo_thrower.fumble_damage", 0.0) / float(FUMBLE_TICKS)
	_fumble_budget -= per
	var amount: float = minf(per, health.hp - 1.0)
	if amount > 0.0:
		fumble_dealt += health.apply_status_damage(amount, {"source": self, "kind": "poison"})
	if is_inside_tree():
		_cough_puff(7)


## 出招：前方扇形裡的心跳（諾恩、席菈）受傷。每一招的距離、角度、傷害在 tuning.json。
func _on_strike() -> void:
	var move: String = brain.move_id
	strike_count += 1
	last_move = move
	if is_thrower():
		_toss()
		return
	var fwd: Vector3 = forward()
	var origin: Vector3 = global_position
	if is_inside_tree():
		Sfx.play_at(get_parent(), "blunt" if is_bracer() else "whoosh", origin + fwd * 0.9 + Vector3.UP * 1.2, -5.0, 0.06, 5.0)
	var reach: float = brain.move_num(move, "reach", brain.attack_range + 0.3)
	var arc: float = brain.move_num(move, "arc_deg", 100.0)
	hit_heartbeats(brain.move_num(move, "damage", 10.0), move,
		func(p: Vector3) -> bool: return PlayerController.in_strike_arc(origin, fwd, p, reach, arc))


## 丟毒瓶：瞄諾恩腳邊（他不在就瞄最近的人），瓶子沿弧線飛 flight 秒，落地才有霧。沒有直接傷害。
## 霧不分敵我（PoisonMist）：站進去就中毒——對席菈是扣血，對裝了中毒的諾恩是回血。
func _toss() -> void:
	var parent: Node = get_parent()
	if parent == null or not is_inside_tree():
		return
	var aim: Node3D = _player if _player != null and is_instance_valid(_player) else target
	if aim == null:
		return
	toss_count += 1
	last_mist = null
	var from: Vector3 = global_position + forward() * 0.35 + Vector3.UP * 1.9 * height
	var to := Vector3(aim.global_position.x, global_position.y, aim.global_position.z)
	last_toss_at = to
	var flight: float = maxf(brain.move_num("toss", "flight", 0.55), 0.05)
	Sfx.play_at(parent, "whoosh", from, -8.0, 0.08, 5.0)
	var bottle: Node3D = _bottle_node(1.45, BOTTLE_ENERGY * 2.2)
	bottle.name = "TossedBottle%d" % toss_count
	bottle.position = from
	parent.add_child(bottle)
	var fly := func(k: float) -> void:
		if is_instance_valid(bottle):
			bottle.global_position = from.lerp(to, k) + Vector3.UP * TOSS_ARC * 4.0 * k * (1.0 - k)
			bottle.rotation.x = k * 9.0
	var t: Tween = bottle.create_tween()
	t.tween_method(fly, 0.0, 1.0, flight)
	t.tween_callback(_bottle_landed.bind(bottle, to, toss_count))


func _bottle_landed(bottle: Node3D, at: Vector3, n: int) -> void:
	var parent: Node = bottle.get_parent() if is_instance_valid(bottle) else null
	if is_instance_valid(bottle):
		bottle.queue_free()
	if parent == null:
		return
	last_mist = _break_bottle(parent, at, brain.move_num("toss", "radius", 2.0), brain.move_num("toss", "life", 3.0),
		"BottleMist%d_%d" % [get_instance_id() % 1000, n])


## 瓶子碎在 at：一團霧＋嘶一聲＋一小圈往外的粉。丟出去的與手滑掉的共用。
func _break_bottle(parent: Node, at: Vector3, radius: float, life: float, mist_name: String) -> PoisonMist:
	var m: PoisonMist = PoisonMist.create(radius, MIST_SOURCE, life)
	m.name = mist_name
	m.position = at
	parent.add_child(m)
	Sfx.play_at(parent, "poison_hiss", at + Vector3.UP * 0.3, -2.0, 0.06, 8.0)
	# 碎掉的那一下：一小圈往外的淡綠粉（0.5 秒就散）
	var ps: CPUParticles3D = puff_build(Vector3(0.25, 0.05, 0.25), 22, Color(0.62, 0.95, 0.55, 0.75))
	ps.spread = 80.0
	ps.initial_velocity_min = 1.4
	ps.initial_velocity_max = 3.0
	puff_start(ps, at + Vector3.UP * 0.12)
	return m


func _update_look() -> void:
	_time += get_physics_process_delta_time()
	if _puppet != null:
		var real: Vector3 = get_real_velocity()
		_puppet.set_move_speed(Vector2(real.x, real.z).length() if brain.is_moving() else 0.0)
	if _glow_mat == null:
		return
	var p: float = brain.telegraph_progress()
	if is_thrower():
		# 手上的瓶子：前兆越舉越亮；丟出去之後手上是空的，破綻過一半才掏出下一瓶
		var empty: bool = brain.state == EnemyBrain.State.STRIKE or brain.state == EnemyBrain.State.DEAD \
			or (brain.state == EnemyBrain.State.RECOVER and brain.time_in_state < brain.recover_sec * 0.55) \
			or is_fumbling()
		if _hand_bottle != null:
			_hand_bottle.visible = not empty
		_glow_mat.emission_energy_multiplier = BOTTLE_ENERGY + (p * p * 5.0 if brain.state == EnemyBrain.State.TELEGRAPH else 0.0)
		return
	if not is_bracer():
		var lit: float = 4.5 if brain.state == EnemyBrain.State.STRIKE else p * p * 5.0
		var braced: bool = brain.is_braced()
		_glow_mat.emission = BRACE_GLOW if braced else CLUB_GLOW
		_glow_mat.emission_energy_multiplier = (BRACE_ENERGY if braced else 0.12) + lit
		return
	if brain.is_braced() and brain.state in [EnemyBrain.State.CHASE, EnemyBrain.State.TELEGRAPH]:
		_glow_mat.emission = BRACE_GLOW
		_glow_mat.emission_energy_multiplier = BRACE_ENERGY + p * 7.0
		return
	match brain.state:
		EnemyBrain.State.TELEGRAPH:
			_glow_mat.emission = BRACER_GLOW
			_glow_mat.emission_energy_multiplier = BRACER_ENERGY + p * 7.0
		EnemyBrain.State.STRIKE:
			_glow_mat.emission = BRACER_GLOW
			_glow_mat.emission_energy_multiplier = BRACER_ENERGY + 8.0
		EnemyBrain.State.RECOVER:
			# 麻掉：一閃一閃的暗紅（不規則，像接觸不良）
			_glow_mat.emission = NUMB_GLOW
			_glow_mat.emission_energy_multiplier = 1.0 + 1.6 * absf(sin(_time * 19.0) * sin(_time * 7.3))
		EnemyBrain.State.DEAD:
			_glow_mat.emission = NUMB_GLOW
			_glow_mat.emission_energy_multiplier = 0.25
		_:
			_glow_mat.emission = BRACER_GLOW
			_glow_mat.emission_energy_multiplier = BRACER_ENERGY


## 照狀態擺姿勢（PoseDriver 每一幀叫；用角色模型時沒有這些關節，什麼都不做）。
## 肩膀 x 正的＝手往前往上、z 正的（右手）＝往外張；手肘 x 正的＝彎；膝蓋 x 負的＝彎。
func apply_pose(_delta: float) -> void:
	if _puppet == null or _puppet.uses_model() or brain == null:
		return
	_rot("hand_R", Vector3.ZERO)
	if gawk_left > 0.0 and brain.state != EnemyBrain.State.DEAD:
		_pose_gawk(1.0 - gawk_left / maxf(_gawk_total, 0.01))
		return
	if is_bracer():
		# 左手早就麻了：垂著，一次都不動（諾恩在台下看到的就是這個）
		_rot("shoulder_L", Vector3(0.0, 0.0, -0.04))
		_rot("elbow_L", Vector3(0.02, 0.0, 0.0))
	var p: float = ease(brain.telegraph_progress(), 0.5)
	match brain.state:
		EnemyBrain.State.TELEGRAPH:
			_pose_windup(brain.move_id, p)
		EnemyBrain.State.STRIKE:
			_pose_strike(brain.move_id, 1.0)
		EnemyBrain.State.RECOVER:
			var k: float = clampf(brain.time_in_state / maxf(brain.recover_sec, 0.01), 0.0, 1.0)
			if is_bracer():
				_pose_numb()
			else:
				_pose_strike(brain.move_id, 1.0 - ease(k, 0.6))
		EnemyBrain.State.STAGGERED:
			_pose_kneel()
		EnemyBrain.State.FLINCH:
			_pose_flinch(clampf(brain.time_in_state / maxf(brain.flinch_sec, 0.01), 0.0, 1.0))
		EnemyBrain.State.DEAD:
			_rot("shoulder_R", Vector3(2.5, 0.0, 0.5))
			_rot("elbow_R", Vector3(0.5, 0.0, 0.0))
			_rot("shoulder_L", Vector3(2.3, 0.0, -0.6))
			_rot("elbow_L", Vector3(0.7, 0.0, 0.0))
			_rot("neck", Vector3(-0.3, 0.5, 0.0))
	if is_covering_mouth() and brain.state in [EnemyBrain.State.CHASE, EnemyBrain.State.FLINCH]:
		_pose_choke()


## 被毒霧嗆到（D-248）：剛嗆到的前 0.1 秒是後仰（往後跳），接著彎腰低頭、空著的那隻手摀嘴、一下一下咳；
## 之後還待在霧裡就一直摀著。拿棍子的用左手（右手拿棍子），戴護腕的用右手（左手是麻的、垂著）。
func _pose_choke() -> void:
	var since: float = CHOKE_POSE_SEC - choke_left
	var c: float = 1.0
	if choke_left > 0.0:
		c = clampf((since - 0.1) / 0.14, 0.0, 1.0)
	if _breath_hold <= 0.0:
		c *= clampf(choke_left / 0.2, 0.0, 1.0)
	if c <= 0.0:
		return
	var hack: float = maxf(sin(_time * 15.7), 0.0) * 0.2 if choke_left > 0.0 else 0.0
	_blend("spine", Vector3(0.34 + hack, 0.0, 0.0), c)
	_blend("chest", Vector3(0.26 + hack * 0.6, 0.0, 0.0), c)
	_blend("neck", Vector3(0.36, 0.0, 0.0), c)
	if is_bracer():
		_blend("shoulder_R", Vector3(1.5, 0.0, -0.3), c)
		_blend("elbow_R", Vector3(2.2, 0.0, 0.0), c)
	else:
		_blend("shoulder_L", Vector3(1.5, 0.0, 0.3), c)
		_blend("elbow_L", Vector3(2.2, 0.0, 0.0), c)


func _pose_windup(move: String, p: float) -> void:
	match move:
		"swing":
			# 棍子往右後方拉開，身體跟著轉過去
			_rot("shoulder_R", Vector3(0.5 * p, 0.0, 0.12 + 1.35 * p))
			_rot("elbow_R", Vector3(0.25 + 0.5 * p, 0.0, 0.0))
			_rot("chest", Vector3(0.0, -0.7 * p, 0.0))
			_rot("spine", Vector3(-0.05, -0.2 * p, 0.0))
		"toss":
			# 瓶子舉過頭、往後拉（整隻手舉到頭後面），上身往後轉
			_rot("shoulder_R", Vector3(0.5 + 2.55 * p, 0.0, 0.2))
			_rot("elbow_R", Vector3(0.3 + 0.75 * p, 0.0, 0.0))
			_rot("chest", Vector3(-0.12 * p, -0.4 * p, 0.0))
			_rot("shoulder_L", Vector3(0.9 * p, 0.0, -0.15))
		"thrust":
			# 手肘往後收、棍頭對著人
			_rot("shoulder_R", Vector3(-0.75 * p, 0.0, 0.2))
			_rot("elbow_R", Vector3(0.25 + 1.5 * p, 0.0, 0.0))
			_rot("hand_R", Vector3(-0.75 * p, 0.0, 0.0))
			_rot("chest", Vector3(0.05 * p, -0.4 * p, 0.0))
		_:
			# 快拳：拳頭收到肩膀旁邊（很短的一下）
			_rot("shoulder_R", Vector3(-0.3 * p, 0.0, 0.25))
			_rot("elbow_R", Vector3(0.3 + 1.9 * p, 0.0, 0.0))
			_rot("chest", Vector3(0.0, -0.45 * p, 0.0))


## k＝1 出手到底、0 收回來
func _pose_strike(move: String, k: float) -> void:
	match move:
		"swing":
			_rot("shoulder_R", Vector3(1.25 * k, 0.0, 0.12 - 0.55 * k))
			_rot("elbow_R", Vector3(0.25 - 0.1 * k, 0.0, 0.0))
			_rot("chest", Vector3(0.12 * k, 0.75 * k, 0.0))
			_rot("spine", Vector3(-0.05, 0.25 * k, 0.0))
		"toss":
			# 手往前下方甩出去、上身跟著往前壓
			_rot("shoulder_R", Vector3(1.05 * k, 0.0, 0.12))
			_rot("elbow_R", Vector3(0.25 - 0.15 * k, 0.0, 0.0))
			_rot("chest", Vector3(0.32 * k, 0.4 * k, 0.0))
			_rot("thigh_L", Vector3(0.4 * k, 0.0, 0.0))
			_rot("knee_L", Vector3(-0.05 - 0.35 * k, 0.0, 0.0))
		"thrust":
			_rot("shoulder_R", Vector3(1.4 * k, 0.0, 0.12))
			_rot("elbow_R", Vector3(0.25 - 0.2 * k, 0.0, 0.0))
			_rot("hand_R", Vector3(-1.35 * k, 0.0, 0.0))
			_rot("chest", Vector3(0.22 * k, 0.3 * k, 0.0))
			_rot("thigh_L", Vector3(0.55 * k, 0.0, 0.0))
			_rot("knee_L", Vector3(-0.05 - 0.45 * k, 0.0, 0.0))
			_rot("thigh_R", Vector3(-0.35 * k, 0.0, 0.0))
		_:
			_rot("shoulder_R", Vector3(1.5 * k, 0.0, 0.12 - 0.2 * k))
			_rot("elbow_R", Vector3(0.25 - 0.2 * k, 0.0, 0.0))
			_rot("chest", Vector3(0.1 * k, 0.45 * k, 0.0))
			_rot("thigh_L", Vector3(0.35 * k, 0.0, 0.0))
			_rot("knee_L", Vector3(-0.05 - 0.3 * k, 0.0, 0.0))


## 麻掉：右手也垂下來、微微發抖，人往前駝、低頭看自己的手
func _pose_numb() -> void:
	var shake: float = sin(_time * 41.0) * 0.045
	_rot("shoulder_R", Vector3(0.1 + shake, 0.0, 0.03))
	_rot("elbow_R", Vector3(0.08 + shake * 0.6, 0.0, 0.0))
	_rot("chest", Vector3(0.3, 0.12, 0.0))
	_rot("spine", Vector3(0.14, 0.0, 0.0))
	_rot("neck", Vector3(0.45, 0.25, 0.0))


## 挨了一下往後仰（k＝0 剛被打中、1 快站直了）：上身往後折、頭甩上去、兩手被震開，前腳離地。
func _pose_flinch(k: float) -> void:
	var a: float = 1.0 - ease(k, 2.2)
	_rot("spine", Vector3(-0.28 * a, 0.0, 0.0))
	_rot("chest", Vector3(-0.3 * a, 0.25 * a, 0.0))
	_rot("neck", Vector3(-0.45 * a, 0.0, 0.0))
	_rot("shoulder_R", Vector3(-0.5 * a, 0.0, 0.12 + 0.85 * a))
	_rot("elbow_R", Vector3(0.25 + 0.5 * a, 0.0, 0.0))
	if not is_bracer():
		_rot("shoulder_L", Vector3(-0.4 * a, 0.0, -0.7 * a))
		_rot("elbow_L", Vector3(0.45 * a, 0.0, 0.0))
	_rot("thigh_L", Vector3(0.5 * a, 0.0, 0.0))
	_rot("knee_L", Vector3(-0.6 * a, 0.0, 0.0))


## 愣住（k＝0 剛看到、1 快回神了）：上身往後縮、頭往前探，兩手舉到臉旁邊攤開（「他在幹嘛？」），一隻腳往後踩。
## 一下子擺出來（前 12%）、撐著、最後四分之一放下來。
func _pose_gawk(k: float) -> void:
	var a: float = minf(ease(clampf(k / 0.12, 0.0, 1.0), 0.4), 1.0 - ease(clampf((k - 0.75) / 0.25, 0.0, 1.0), 1.8))
	var shake: float = sin(_time * 31.0) * 0.05 * a
	_rot("spine", Vector3(0.24 * a, 0.0, 0.0))
	_rot("chest", Vector3(0.12 * a, shake, 0.0))
	_rot("neck", Vector3(-0.42 * a, shake * 2.0, 0.0))
	_rot("shoulder_R", Vector3(1.25 * a, 0.0, 0.12 + 0.75 * a))
	_rot("shoulder_L", Vector3(1.25 * a, 0.0, -0.12 - 0.75 * a))
	_rot("elbow_R", Vector3(0.25 + 1.45 * a, 0.0, 0.0))
	_rot("elbow_L", Vector3(0.25 + 1.45 * a, 0.0, 0.0))
	_rot("thigh_R", Vector3(-0.4 * a, 0.0, 0.0))
	_rot("knee_R", Vector3(-0.25 * a, 0.0, 0.0))
	_rot("thigh_L", Vector3(0.22 * a, 0.0, 0.0))
	if not _fumbling:
		return
	# 手一滑、被自己的毒嗆到（D-247）：嚇一跳之後（前 18%）彎腰、低頭、右手摀嘴、左手在面前搧，一下一下咳
	var c: float = clampf((k - 0.18) / 0.14, 0.0, 1.0) * a
	if c <= 0.0:
		return
	var hack: float = maxf(sin(_time * 15.7), 0.0) * 0.24
	var wave: float = sin(_time * 12.0)
	_blend("spine", Vector3(0.52 + hack, 0.0, 0.0), c)
	_blend("chest", Vector3(0.36 + hack * 0.6, 0.0, 0.0), c)
	_blend("neck", Vector3(0.38, 0.0, 0.0), c)
	_blend("shoulder_R", Vector3(1.5, 0.0, -0.3), c)
	_blend("elbow_R", Vector3(2.2, 0.0, 0.0), c)
	_blend("shoulder_L", Vector3(1.3 + wave * 0.22, 0.0, -0.5 - wave * 0.3), c)
	_blend("elbow_L", Vector3(1.0 + wave * 0.35, 0.0, 0.0), c)
	_blend("thigh_L", Vector3(0.4, 0.0, 0.0), c)
	_blend("knee_L", Vector3(-0.5, 0.0, 0.0), c)
	_blend("knee_R", Vector3(-0.45, 0.0, 0.0), c)


## 失衡跪地：右膝著地、左腳踩在前面，上身往前垮
func _pose_kneel() -> void:
	var hips: Node3D = _puppet.joint("hips")
	if hips != null:
		hips.position.y = Puppet.HIP_HEIGHT - 0.42
	_rot("thigh_L", Vector3(1.45, 0.0, 0.0))
	_rot("knee_L", Vector3(-1.5, 0.0, 0.0))
	_rot("thigh_R", Vector3(0.1, 0.0, 0.0))
	_rot("knee_R", Vector3(-1.6, 0.0, 0.0))
	_rot("spine", Vector3(0.35, 0.0, 0.0))
	_rot("neck", Vector3(0.35, 0.0, 0.0))
	_rot("shoulder_R", Vector3(0.35, 0.0, 0.2))
	_rot("elbow_R", Vector3(0.5, 0.0, 0.0))


func _rot(joint_name: String, r: Vector3) -> void:
	var j: Node3D = _puppet.joint(joint_name)
	if j != null:
		j.rotation = r


## 從這一幀已經擺好的角度往 r 靠 k 成（兩個姿勢之間的過渡）。
func _blend(joint_name: String, r: Vector3, k: float) -> void:
	var j: Node3D = _puppet.joint(joint_name)
	if j != null:
		j.rotation = j.rotation.lerp(r, k)


## 倒下：跪 → 往前撲倒 → 躺在原地（不沉下去、不釋放——是人，不是怪物）。倒下的那一刻就不算敵人了
## （鎖定、席菈找目標、戰鬥 HUD 都是數「enemies」群組）。
func _on_died() -> void:
	gawk_left = 0.0
	_fumbling = false
	_begin_death()
	remove_from_group("enemies")
	if _puppet != null:
		_puppet.set_move_speed(0.0)
	_update_look()
	var t := create_tween()
	_fall_tween = t
	t.tween_property(_body, "position:y", -0.3, DIE_KNEEL_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_body, "rotation_degrees:x", FALL_FORWARD * 84.0, DIE_DROP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_body, "position:y", 0.16, DIE_DROP_SEC)
	t.tween_callback(_on_fall_impact)


func _build_body() -> void:
	super._build_body()
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7 * height
	shape.shape = cap
	shape.position = Vector3(0, 0.85 * height, 0)
	add_child(shape)
	ContactShadow.attach(self, 0.6, 0.5)
	_puppet = Puppet.new()
	_puppet.name = "Puppet"
	_puppet.coat_color = THROWER_COAT if is_thrower() else COAT
	_puppet.trim_color = TRIM
	_puppet.scale = Vector3.ONE * height
	_body.add_child(_puppet)
	if _puppet.uses_model():
		return
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(0.2, 0.2, 0.22)
	_glow_mat.emission_enabled = true
	var club: Node3D = _puppet.hand("R").get_node_or_null("BellHammer") as Node3D if _puppet.hand("R") != null else null
	if is_thrower():
		if club != null:
			club.queue_free()
		_glow_mat.albedo_color = Color(0.2, 0.42, 0.2)
		_glow_mat.emission = BOTTLE_GLOW
		_glow_mat.emission_energy_multiplier = BOTTLE_ENERGY
		_glow_mat.roughness = 0.2
		if _puppet.hand("R") != null:
			_hand_bottle = _bottle_node(1.45, -1.0)
			_hand_bottle.name = "HandBottle"
			_hand_bottle.position = Vector3(0.0, -0.05, 0.0)
			_puppet.hand("R").add_child(_hand_bottle)
		_add_bottle_belt()
	elif is_bracer():
		if club != null:
			club.queue_free()
		_glow_mat.emission = BRACER_GLOW
		_glow_mat.emission_energy_multiplier = BRACER_ENERGY
		for side: String in ["L", "R"]:
			var elbow: Node3D = _puppet.joint("elbow_" + side)
			if elbow != null:
				var worn: Node3D = _bracer(1.15)
				worn.position = Vector3(0.0, -Puppet.FOREARM_LEN * 0.62, 0.0)
				elbow.add_child(worn)
	else:
		_glow_mat.albedo_color = Color(0.62, 0.42, 0.22)
		_glow_mat.metallic = 0.6
		_glow_mat.roughness = 0.4
		_glow_mat.emission = CLUB_GLOW
		_glow_mat.emission_energy_multiplier = 0.12
		if club != null:
			# 棍頭兩端各一圈銅箍（前兆時亮起來）
			for dy: float in [0.4, 0.6]:
				var band := MeshInstance3D.new()
				band.name = "ClubBand"
				var ring := CylinderMesh.new()
				ring.top_radius = 0.086
				ring.bottom_radius = 0.086
				ring.height = 0.035
				ring.radial_segments = 10
				ring.material = _glow_mat
				band.mesh = ring
				band.position = Vector3(0.0, dy, 0.0)
				band.rotation = Vector3(0.0, 0.0, PI * 0.5)
				club.add_child(band)
	_add_sash()
	var driver := PoseDriver.new()
	driver.name = "PoseDriver"
	driver.guard = self
	_puppet.add_child(driver)


## 一個毒瓶：圓肚子＋細頸＋軟木塞。energy < 0＝用手上那一瓶共用的材質（跟著前兆變亮）；不然自己一個固定亮度的材質。
func _bottle_node(size: float, energy: float) -> Node3D:
	var root := Node3D.new()
	var mat: StandardMaterial3D = _glow_mat
	if energy >= 0.0 or mat == null:
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.42, 0.2)
		mat.roughness = 0.2
		mat.emission_enabled = true
		mat.emission = BOTTLE_GLOW
		mat.emission_energy_multiplier = maxf(energy, 0.0)
	var belly := SphereMesh.new()
	belly.radius = 0.062 * size
	belly.height = 0.13 * size
	belly.radial_segments = 10
	belly.rings = 5
	belly.material = mat
	var b := MeshInstance3D.new()
	b.name = "Belly"
	b.mesh = belly
	root.add_child(b)
	var neck := CylinderMesh.new()
	neck.top_radius = 0.02 * size
	neck.bottom_radius = 0.028 * size
	neck.height = 0.07 * size
	neck.radial_segments = 8
	neck.material = mat
	var n := MeshInstance3D.new()
	n.mesh = neck
	n.position.y = 0.09 * size
	root.add_child(n)
	var cork := CylinderMesh.new()
	cork.top_radius = 0.022 * size
	cork.bottom_radius = 0.022 * size
	cork.height = 0.03 * size
	cork.radial_segments = 8
	var cork_mat := StandardMaterial3D.new()
	cork_mat.albedo_color = Color(0.5, 0.36, 0.22)
	cork_mat.roughness = 0.9
	cork.material = cork_mat
	var c := MeshInstance3D.new()
	c.mesh = cork
	c.position.y = 0.135 * size
	root.add_child(c)
	return root


## 丟毒瓶的腰上掛一排瓶子（四瓶，固定的暗綠光）：遠遠看就知道這個人是丟瓶子的。
func _add_bottle_belt() -> void:
	var hips: Node3D = _puppet.joint("hips")
	if hips == null:
		return
	for i: int in 4:
		var bottle: Node3D = _bottle_node(0.8, 0.9)
		bottle.name = "BeltBottle%d" % i
		var a: float = (float(i) - 1.5) * 0.42
		bottle.position = Vector3(sin(a) * 0.2, 0.02, -cos(a) * 0.19)
		hips.add_child(bottle)


## 胸前斜掛的布條（三段：紅、白、紅）＋兩隻上臂各一圈紅布。掛在胸口的關節上，跟著上身轉。
func _add_sash() -> void:
	var chest: Node3D = _puppet.joint("chest")
	if chest == null:
		return
	var sash := Node3D.new()
	sash.name = "Sash"
	sash.position = Vector3(0.0, 0.16, 0.0)
	sash.rotation = Vector3(0.0, 0.0, 0.62)
	chest.add_child(sash)
	var colors: Array[Color] = [SASH_RED, SASH_WHITE, SASH_RED]
	for i: int in colors.size():
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.62, 0.045, 0.34)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i]
		mat.roughness = 0.9
		box.material = mat
		strip.mesh = box
		strip.position = Vector3(0.0, 0.047 * float(i - 1), 0.0)
		sash.add_child(strip)
	for side: String in ["L", "R"]:
		var shoulder: Node3D = _puppet.joint("shoulder_" + side)
		if shoulder == null:
			continue
		var band := MeshInstance3D.new()
		band.name = "ArmBand"
		var ring := CylinderMesh.new()
		ring.top_radius = 0.075
		ring.bottom_radius = 0.072
		ring.height = 0.07
		ring.radial_segments = 10
		var red := StandardMaterial3D.new()
		red.albedo_color = SASH_RED
		red.roughness = 0.9
		ring.material = red
		band.mesh = ring
		band.position = Vector3(0.0, -Puppet.UPPER_ARM_LEN * 0.45, 0.0)
		shoulder.add_child(band)


## 戴在前臂上的護腕：深色的箍＋兩圈會亮的環（兩隻手共用一個材質，一起亮、一起麻）。
func _bracer(size: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Bracer"
	var cuff := CylinderMesh.new()
	cuff.top_radius = 0.062 * size
	cuff.bottom_radius = 0.056 * size
	cuff.height = 0.12 * size
	cuff.radial_segments = 10
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.16, 0.15, 0.17)
	dark.roughness = 0.32
	cuff.material = dark
	var body := MeshInstance3D.new()
	body.mesh = cuff
	root.add_child(body)
	for dy: float in [-0.036, 0.036]:
		var ring := CylinderMesh.new()
		ring.top_radius = 0.067 * size
		ring.bottom_radius = 0.067 * size
		ring.height = 0.018 * size
		ring.radial_segments = 10
		ring.material = _glow_mat
		var band := MeshInstance3D.new()
		band.name = "Ring"
		band.mesh = ring
		band.position.y = dy * size
		root.add_child(band)
	return root
