class_name EnemyActor
extends CharacterBody3D
## 敵人共用：EnemyBrain、Health、追最近的心跳（"heartbeat" 群組：諾恩與同伴）、受擊與倒下的演出、難度即時套用。
## 子類別覆寫 tuning_id()（data/combat/tuning.json 裡的那一段）、_build_body()（建立 _body）、_on_strike()、_on_strike_tick()、_update_look()。

const TURN_SPEED: float = 8.0

var brain: EnemyBrain
var health: Health
## 追擊目標：最近的心跳；前兆與出招中不換目標
var target: Node3D
## 空字串＝用設定裡的難度；設定改了即時套用
var difficulty: String = ""
var move_speed: float = 2.6
## true＝只追諾恩（他倒下才找別人）。預設還是「最近的心跳」。小戰檢驗的第一個人與戰鬥場的每一個敵人會開：
## 都追最近的話，敵人圍著席菈打，諾恩站著不動也沒事。
## 硬撐中挨了幾下（只扣幾成的那種；統計與測試用）
var armored_hits: int = 0
var focus_player: bool = false

## 同時最多幾個敵人可以對同一個人擺前兆／出手（0＝不限）。別人剛出完招的 attack_gap 秒內也算佔著。
## 沒輪到的人停在 attack_range + wait_ring 外面等。數值在 tuning.json 的 crowd.*（劇情＝不限，戰鬥場＝1）；生出來的時候讀一次。
var attack_slots: int = 0
var attack_gap: float = 0.0
var wait_ring: float = 0.0
## 被諾恩打中後仰過幾次、其中幾次打斷了前兆（測試、機器人的統計用）
var flinch_count: int = 0
var interrupt_count: int = 0

var _player: PlayerController
var _body: Node3D
var _push_dir: Vector3 = Vector3.ZERO
var _push_speed: float = 0.0


func tuning_id() -> String:
	return ""


## 離鏡頭多近開始淡掉（x 以內看不到、y 以外不透明）。體型大的敵人覆寫成更遠。
func camera_fade_range() -> Vector2:
	return Vector2(CameraFade.CHARACTER_NEAR, CameraFade.CHARACTER_FAR)


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("enemies")
	if difficulty == "":
		difficulty = Settings.difficulty
		Settings.changed.connect(_on_settings_changed)
	brain = EnemyBrain.new().configure(tuning_id(), difficulty)
	brain.knelt.connect(_on_kneel)
	brain.flinched.connect(_on_flinched)
	brain.braced.connect(_on_braced)
	attack_slots = int(CombatTuning.num("crowd.attack_slots", 0.0))
	attack_gap = CombatTuning.num("crowd.attack_gap", 0.0)
	wait_ring = CombatTuning.num("crowd.wait_ring", 0.0)
	move_speed = CombatTuning.num(tuning_id() + ".move_speed", move_speed)
	health = Health.new(CombatTuning.num(tuning_id() + ".max_hp", 60.0))
	health.name = "Health"
	add_child(health)
	health.damage_scale = _damage_scale
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_build_body()
	var fade: Vector2 = camera_fade_range()
	CameraFade.apply(self, fade.x, fade.y)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _first_player()
	target = _nearest_heartbeat()
	var dist: float = 999.0
	if target != null:
		var d: Vector3 = target.global_position - global_position
		d.y = 0.0
		dist = d.length()
		if brain.state in [EnemyBrain.State.CHASE, EnemyBrain.State.TELEGRAPH] and d.length() > 0.01:
			var face: float = atan2(-d.x, -d.z)
			_body.rotation.y = lerp_angle(_body.rotation.y, face, clampf(TURN_SPEED * delta, 0.0, 1.0))
	if _held(delta):
		# 劇情動作中（送葬者把燈柱舉過頭）：不追、不出招。劇情走位由 _held_velocity 給水平速度，照樣用自己的腳走
		var held_v: Vector3 = _held_velocity(delta)
		velocity = Vector3(held_v.x, 0.0 if is_on_floor() else velocity.y - 18.0 * delta, held_v.z)
		move_and_slide()
		_update_look()
		return
	brain.may_attack = _may_attack()
	if brain.tick(delta, dist):
		_on_strike()
	var horizontal := Vector3.ZERO
	if brain.state == EnemyBrain.State.STRIKE:
		horizontal = _on_strike_tick(delta)
	elif brain.state == EnemyBrain.State.FLINCH:
		horizontal = _push_dir * _push_speed
	elif brain.is_moving() and target != null and not brain.may_attack:
		# 還沒輪到：停在出手距離外面一圈等；站得太近就慢慢退開
		var ring: float = brain.attack_range + wait_ring
		if dist > ring:
			horizontal = forward() * move_speed
		elif dist < ring - WAIT_SLACK:
			horizontal = -forward() * move_speed * WAIT_BACK_SPEED
	elif brain.is_moving() and target != null and dist > brain.attack_range * 0.8:
		horizontal = forward() * move_speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	_after_move()
	_update_look()
	_update_brace(delta)


func forward() -> Vector3:
	return -_body.global_basis.z


## 直接轉向（水平角度，跟節點自己的 rotation.y 疊加）：關卡把劇情中的敵人交給戰鬥時用。
func set_facing(yaw: float) -> void:
	if _body != null:
		_body.rotation.y = yaw


## 現在打他算不算打在破綻上（傷害、失衡加倍，見 PlayerController.strike）：跪著的時候算。回傳 ""＝不算。
func weakpoint_exposed_to(_attacker_pos: Vector3) -> String:
	return "kneel" if brain.state == EnemyBrain.State.STAGGERED else ""


## 鎖定標記的高度（頭上）。
func lock_height() -> float:
	return _head_height() + 0.25


func hit_heartbeats(damage: float, kind: String, pred: Callable) -> int:
	var n_hit: int = 0
	for n: Node in get_tree().get_nodes_in_group("heartbeat"):
		var hb: Node3D = n as Node3D
		if hb != null and bool(pred.call(hb.global_position)) and hurt(hb, damage, kind):
			n_hit += 1
	return n_hit


## 對單一目標造成傷害（套難度倍率）。回傳是否真的扣血（閃避無敵會被擋）。
func hurt(who: Node3D, damage: float, kind: String) -> bool:
	var h: Health = who.get_node_or_null("Health") as Health
	if h == null:
		return false
	return h.apply_damage(damage * CombatTuning.num("difficulty.%s.enemy_damage" % difficulty, 1.0), {"source": self, "kind": kind})


# ---- 子類別覆寫 ----

func _build_body() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)


func _on_strike() -> void:
	pass


## 出招中每幀呼叫，回傳這一幀的水平速度（衝撞用）。
func _on_strike_tick(_delta: float) -> Vector3:
	return Vector3.ZERO


func _after_move() -> void:
	pass


## 回傳 true＝這一幀被劇情動作佔住（不跑狀態機、不出招）。
func _held(_delta: float) -> bool:
	return false


## 被劇情動作佔住時這一幀的水平速度（預設站著不動；劇情走位覆寫）。
func _held_velocity(_delta: float) -> Vector3:
	return Vector3.ZERO


func _update_look() -> void:
	pass


func _head_height() -> float:
	return 2.0


# ---- 共用 ----

func _on_settings_changed() -> void:
	if Settings.difficulty != difficulty:
		difficulty = Settings.difficulty
		brain.configure(tuning_id(), difficulty)


func _nearest_heartbeat() -> Node3D:
	if focus_player and _player != null and is_instance_valid(_player) and not _player.health.is_dead():
		return _player
	if target != null and is_instance_valid(target) and brain.state in [EnemyBrain.State.TELEGRAPH, EnemyBrain.State.STRIKE]:
		return target
	var best: Node3D = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group("heartbeat"):
		var hb: Node3D = n as Node3D
		var h: Health = hb.get_node_or_null("Health") as Health if hb != null else null
		if hb == null or (h != null and h.is_dead()):
			continue
		var d: float = hb.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = hb
	return best


# ---------------------------------------------------------------- 輪流出手、挨打後仰
## 等的人離圈子多近才開始往後退、退多快（走路速度的幾成）
const WAIT_SLACK: float = 0.5
const WAIT_BACK_SPEED: float = 0.5


## 這種敵人的出手要不要排隊（丟毒瓶的不用：他在後面丟，霧對諾恩是回血）。
func uses_attack_slot() -> bool:
	return true


## 正佔著一個出手名額：前兆、出招中，或剛出完招還不到 gap 秒。
func holds_attack_slot(gap: float) -> bool:
	match brain.state:
		EnemyBrain.State.TELEGRAPH, EnemyBrain.State.STRIKE:
			return true
		EnemyBrain.State.RECOVER:
			return brain.time_in_state < gap
	return false


## 這一幀可不可以開始擺前兆：對同一個目標，佔著名額的其他敵人不到 attack_slots 個。
func _may_attack() -> bool:
	if attack_slots <= 0 or target == null or not uses_attack_slot() or not is_inside_tree():
		return true
	var busy: int = 0
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e: EnemyActor = n as EnemyActor
		if e == null or e == self or e.brain == null or e.target != target or not e.uses_attack_slot():
			continue
		if e.holds_attack_slot(attack_gap):
			busy += 1
	return busy < attack_slots


## 後仰的那一刻：往攻擊者的反方向退 flinch_push 公尺（在後仰的時間裡走完）。
func _on_flinched(interrupted: bool) -> void:
	flinch_count += 1
	if interrupted:
		interrupt_count += 1
		last_flinch_sound = INTERRUPT_SFX
		if is_inside_tree():
			Sfx.play_at(get_parent(), INTERRUPT_SFX, global_position + Vector3.UP * _hit_height(), INTERRUPT_DB, 0.08, 5.0)
	_push_speed = brain.flinch_push / maxf(brain.flinch_sec, 0.01)
	if _push_dir == Vector3.ZERO:
		_push_dir = -forward()


func _first_player() -> PlayerController:
	for n: Node in get_tree().get_nodes_in_group("player"):
		return n as PlayerController
	return null


## 硬撐中（整個人發紅）挨打只扣幾成；順便在 info 留記號，_on_damaged 換一個「打在硬東西上」的聲音。
func _damage_scale(info: Dictionary) -> float:
	var k: float = brain.armor_mult()
	if k < 1.0:
		info["braced"] = true
	return k


func _on_damaged(_amount: float, info: Dictionary) -> void:
	_hit_fx(info)
	if bool(info.get("braced", false)):
		armored_hits += 1
		if is_inside_tree():
			Sfx.play_at(get_parent(), ARMOR_SFX, global_position + Vector3.UP * _hit_height(), ARMOR_DB, 0.1, 6.0)
	brain.add_stagger(float(info.get("stagger", 0.0)))
	# 只有諾恩打的會讓他後仰（席菈打的也算的話，她一個人就能把敵人鎖死）
	var src: Node3D = info.get("source") as Node3D
	if src is PlayerController and not health.is_dead():
		var away: Vector3 = global_position - src.global_position
		away.y = 0.0
		_push_dir = away.normalized() if away.length() > 0.01 else -forward()
		brain.flinch()


# ---------------------------------------------------------------- 硬撐的訊號
## 硬撐（後仰過幾次之後打不斷、下一招一定打得出來）是這個戰鬥唯一的「該閃了」訊號。
## 第 92 輪只有棍頭的兩圈箍變紅——縮小的連拍圖上是一個小橘點，看不出來。現在三樣一起：
## ①整個身體蓋一層紅光（`brace_glow.gdshader`，material_overlay：輪廓一圈最亮），硬撐多久就亮多久、一下一下跳；
## ②變紅的那一刻：腳邊一圈紅環往外擴、胸口一片紅色的亮斑、一盞很短的紅燈（掛在關卡上，自己收掉）；
## ③一聲警告音（`brace_warn`：往上滑的低吼＋一聲金屬音），只在這個時候出現。
## 被打斷的那一下另外有一聲短的「喀」（`interrupt`）：聽得出「他那一招沒了」。
## 都看 brain.is_braced()：不會後仰的敵人（劇情裡的、頭目）永遠不會亮。
const BRACE_SHADER: Shader = preload("res://src/world/brace_glow.gdshader")
const BRACE_COLOR: Color = Color(1.0, 0.16, 0.05)
const BRACE_SFX: String = "brace_warn"
const BRACE_DB: float = -2.0
const INTERRUPT_SFX: String = "interrupt"
## 打在硬撐中的人身上（只扣幾成）：一聲悶的鐵響，跟平常命中的「咚」分得開
const ARMOR_SFX: String = "iron_clang"
const ARMOR_DB: float = -11.0
const INTERRUPT_DB: float = -6.0
## 平常的亮度、一秒跳幾下、跳多深
const BRACE_STRENGTH: float = 1.0
const BRACE_PULSE_HZ: float = 3.0
const BRACE_PULSE_DEPTH: float = 0.3
## 剛變紅的那一下多亮幾倍、多久退回平常
const BRACE_FLARE: float = 1.6
const BRACE_FLARE_SEC: float = 0.35
## 擺前兆的時候再往上（越接近出手越亮）
const BRACE_WINDUP_BOOST: float = 0.9
## 變紅的那一刻：紅環從多大擴到多大（公尺，半徑）、整組多久收掉
const BRACE_RING_FROM: float = 0.45
const BRACE_RING_TO: float = 1.7
const BRACE_RING_SEC: float = 0.38
const BRACE_POP_SIZE: float = 1.9
const BRACE_FLASH_ENERGY: float = 5.0
const BRACE_FLASH_RANGE: float = 4.5

## 進入硬撐幾次、最後一次那一組特效、最後播的警告音與被打斷的聲音（測試、截圖用）
var brace_count: int = 0
var last_brace_fx: Node3D
var last_brace_sound: String = ""
var last_flinch_sound: String = ""
## 截圖用：變紅那一刻的特效不收掉
var debug_hold_brace: bool = false
var _brace_mat: ShaderMaterial
var _brace_lit: bool = false
var _brace_t: float = 0.0
var _brace_meshes: Array[GeometryInstance3D] = []


## 身上的紅光現在亮不亮、亮度多少、蓋了幾塊（測試用）。
func is_brace_lit() -> bool:
	return _brace_lit


func brace_strength() -> float:
	return float(_brace_mat.get_shader_parameter("strength")) if _brace_lit and _brace_mat != null else 0.0


func brace_mesh_count() -> int:
	var n: int = 0
	for g: GeometryInstance3D in _brace_meshes:
		if is_instance_valid(g) and g.material_overlay == _brace_mat:
			n += 1
	return n


## 進入硬撐的那一刻（EnemyBrain.braced）：警告音＋腳邊的紅環＋胸口的亮斑。
func _on_braced() -> void:
	brace_count += 1
	last_brace_sound = BRACE_SFX
	_set_brace_lit(true)
	if not is_inside_tree():
		return
	var parent: Node = get_parent() if get_parent() != null else self
	Sfx.play_at(parent, BRACE_SFX, global_position + Vector3.UP * _hit_height(), BRACE_DB, 0.03, 7.0)
	var fx := Node3D.new()
	fx.name = "BraceFx"
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 6
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# 加法混色、亮度超過 1：有 glow 的時候會暈開
	ring_mat.albedo_color = Color(BRACE_COLOR.r * 2.6, BRACE_COLOR.g * 2.6, BRACE_COLOR.b * 2.6, 1.0)
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(BRACE_RING_FROM, 0.25, BRACE_RING_FROM)
	ring.position = Vector3(0.0, 0.08, 0.0)
	fx.add_child(ring)
	var pop := MeshInstance3D.new()
	pop.name = "Pop"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * BRACE_POP_SIZE
	pop.mesh = quad
	var pop_mat: StandardMaterial3D = ParticleLook.material(Color(BRACE_COLOR.r, BRACE_COLOR.g, BRACE_COLOR.b, 0.9), true)
	pop_mat.no_depth_test = true
	pop.material_override = pop_mat
	pop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pop.position = Vector3(0.0, _hit_height(), 0.0)
	pop.scale = Vector3.ONE * 0.5
	fx.add_child(pop)
	var flash := OmniLight3D.new()
	flash.name = "Flash"
	flash.light_color = BRACE_COLOR
	flash.light_energy = BRACE_FLASH_ENERGY
	flash.omni_range = BRACE_FLASH_RANGE
	flash.omni_attenuation = 1.3
	flash.shadow_enabled = false
	flash.light_volumetric_fog_energy = 0.5
	flash.position = Vector3(0.0, _hit_height(), 0.0)
	fx.add_child(flash)
	parent.add_child(fx, true)
	fx.global_position = global_position
	last_brace_fx = fx
	if debug_hold_brace:
		return
	var t: Tween = fx.create_tween()
	var big := Vector3(BRACE_RING_TO, 0.25, BRACE_RING_TO)
	t.tween_property(ring, "scale", big, BRACE_RING_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, BRACE_RING_SEC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(pop, "scale", Vector3.ONE, BRACE_RING_SEC * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(pop_mat, "albedo_color:a", 0.0, BRACE_RING_SEC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(flash, "light_energy", 0.0, BRACE_RING_SEC).set_ease(Tween.EASE_OUT)
	t.tween_callback(fx.queue_free)


## 每一幀：硬撐中就亮著（一下一下跳），打出那一招、跪完、倒下就關掉。
func _update_brace(delta: float) -> void:
	var on: bool = brain.is_braced()
	if on != _brace_lit:
		_set_brace_lit(on)
	if not on or _brace_mat == null:
		return
	_brace_t += delta
	var flare: float = BRACE_FLARE * maxf(0.0, 1.0 - _brace_t / BRACE_FLARE_SEC)
	var pulse: float = 1.0 - BRACE_PULSE_DEPTH * (0.5 - 0.5 * cos(_brace_t * TAU * BRACE_PULSE_HZ))
	var windup: float = BRACE_WINDUP_BOOST * brain.telegraph_progress()
	if brain.state == EnemyBrain.State.STRIKE:
		windup = BRACE_WINDUP_BOOST
	_brace_mat.set_shader_parameter("strength", BRACE_STRENGTH * pulse + flare + windup)


func _set_brace_lit(on: bool) -> void:
	if on == _brace_lit:
		return
	_brace_lit = on
	_brace_t = 0.0
	if on and _brace_mat == null:
		_brace_mat = ShaderMaterial.new()
		_brace_mat.shader = BRACE_SHADER
		_brace_mat.set_shader_parameter("glow_color", BRACE_COLOR)
		var fade: Vector2 = camera_fade_range()
		_brace_mat.set_shader_parameter("fade_near", fade.x)
		_brace_mat.set_shader_parameter("fade_far", fade.y)
	if on:
		_brace_mat.set_shader_parameter("strength", BRACE_STRENGTH + BRACE_FLARE)
		_brace_meshes.clear()
		if _body != null:
			_collect_brace_meshes(_body)
	for g: GeometryInstance3D in _brace_meshes:
		if is_instance_valid(g):
			g.material_overlay = _brace_mat if on else null
	if not on:
		_brace_meshes.clear()


## 身體上看得到的實心東西（網格、CSG）；粒子、文字、弱點標記不蓋。
func _collect_brace_meshes(n: Node) -> void:
	if (n is MeshInstance3D or n is CSGShape3D):
		_brace_meshes.append(n as GeometryInstance3D)
	for c: Node in n.get_children():
		_collect_brace_meshes(c)


# ---------------------------------------------------------------- 被打中的那一下
## 打中敵人原本只有聲音、頓一下、鏡頭晃——畫面上沒有東西飛出來。現在每次扣到血：
## 命中點（朝攻擊者那一側、胸口高度）噴一把冷白的霜屑（往攻擊者那邊飛、往下掉），打中弱點（鐵件）再多一把橘色火星；
## 同一點一盞很短的閃光——暗色的身體在那一下有輪廓。掛在關卡上（敵人倒下沉進雪裡也不會被帶走），自己收掉。
## 一次性粒子照 ：節點先擺到位置，粒子才開始噴。
const HIT_CHIP_COLOR: Color = Color(0.82, 0.93, 1.0)
const HIT_SPARK_COLOR: Color = Color(1.0, 0.7, 0.32)
const HIT_FLASH_SEC: float = 0.14
const HIT_FLASH_ENERGY: float = 3.2
const HIT_FLASH_RANGE: float = 3.0
## 粒子飛多久；整組在這之後收掉
const HIT_FX_SEC: float = 0.5
## 命中點那一下的亮斑（一片面向鏡頭的加法圓點，HIT_POP_SEC 秒內放大、淡掉）：小亮點太細，要有一下「啪」
const HIT_POP_SEC: float = 0.12
const HIT_POP_SIZE: float = 0.55

## 被打中過幾次、最後一次的那一組（測試、截圖用）
var hit_fx_count: int = 0
var last_hit_fx: Node3D
## 截圖用：閃光不熄、整組不收
var debug_hold_hit: bool = false


## 命中點離身體中心多遠、多高（子類別照體型改）
func _hit_radius() -> float:
	return 0.35


func _hit_height() -> float:
	return 1.05


## 攻擊者在 from：水平方向（從敵人指向攻擊者；重疊時用敵人的正面）
func hit_dir(from: Vector3) -> Vector3:
	var d := Vector3(from.x - global_position.x, 0.0, from.z - global_position.z)
	return d.normalized() if d.length() > 0.01 else forward()


func hit_point(from: Vector3) -> Vector3:
	return global_position + hit_dir(from) * _hit_radius() + Vector3.UP * _hit_height()


func _hit_fx(info: Dictionary) -> Node3D:
	if not is_inside_tree():
		return null
	var src: Node3D = info.get("source") as Node3D
	var from: Vector3 = src.global_position if src != null and is_instance_valid(src) else global_position + forward()
	var out: Vector3 = hit_dir(from)
	var weak: bool = str(info.get("weak", "")) != ""
	var fx := Node3D.new()
	fx.name = "HitFx"
	fx.set_meta("weak", weak)
	var chips: CPUParticles3D = _hit_particles("Chips", 24 if weak else 16, HIT_CHIP_COLOR, out, 0.09, Vector2(1.8, 4.6))
	fx.add_child(chips)
	var sparks: CPUParticles3D = null
	if weak:
		sparks = _hit_particles("Sparks", 30, HIT_SPARK_COLOR, out, 0.085, Vector2(3.0, 7.5))
		fx.add_child(sparks)
	var flash := OmniLight3D.new()
	flash.name = "Flash"
	flash.light_color = Color(1.0, 0.86, 0.62) if weak else HIT_CHIP_COLOR
	flash.light_energy = HIT_FLASH_ENERGY * (1.5 if weak else 1.0)
	flash.omni_range = HIT_FLASH_RANGE
	flash.omni_attenuation = 1.4
	flash.shadow_enabled = false
	flash.light_volumetric_fog_energy = 0.4
	# 往外一點：照在身體朝攻擊者的那一面，不是埋在身體裡
	flash.position = out * 0.35
	fx.add_child(flash)
	var pop := MeshInstance3D.new()
	pop.name = "Pop"
	var pop_quad := QuadMesh.new()
	pop_quad.size = Vector2.ONE * HIT_POP_SIZE * (1.5 if weak else 1.0)
	pop.mesh = pop_quad
	var pop_mat: StandardMaterial3D = ParticleLook.material(flash.light_color, true)
	# 畫在身體前面：命中點貼著大衣，不關深度測試會被大衣切掉一半
	pop_mat.no_depth_test = true
	pop.material_override = pop_mat
	pop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pop.scale = Vector3.ONE * 0.45
	fx.add_child(pop)
	# 連打時同名的兄弟節點：要引擎編成 HitFx2、HitFx3（不要 @Node3D@123 那種看不懂的名字）
	(get_parent() if get_parent() != null else self).add_child(fx, true)
	fx.global_position = hit_point(from)
	chips.emitting = true
	if sparks != null:
		sparks.emitting = true
	hit_fx_count += 1
	last_hit_fx = fx
	if not debug_hold_hit:
		var t: Tween = fx.create_tween()
		t.tween_property(flash, "light_energy", 0.0, HIT_FLASH_SEC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(pop, "scale", Vector3.ONE, HIT_POP_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.parallel().tween_property(pop_mat, "albedo_color:a", 0.0, HIT_POP_SEC).set_ease(Tween.EASE_IN)
		t.tween_interval(HIT_FX_SEC)
		t.tween_callback(fx.queue_free)
	return fx


## 命中噴出來的一把小亮點：加法混色、往 out 那一側的斜上方噴、往下掉、越飛越小。建好但還沒開始噴。
func _hit_particles(node_name: String, amount: int, color: Color, out: Vector3, size: float, speed: Vector2) -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.name = node_name
	ps.emitting = false
	ps.one_shot = true
	ps.explosiveness = 1.0
	ps.amount = amount
	ps.lifetime = HIT_FX_SEC
	ps.randomness = 0.5
	ps.direction = (out + Vector3.UP * 0.55).normalized()
	ps.spread = 48.0
	ps.initial_velocity_min = speed.x
	ps.initial_velocity_max = speed.y
	ps.gravity = Vector3(0, -11.0, 0)
	ps.damping_min = 0.5
	ps.damping_max = 2.0
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = 0.1
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.5
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.25))
	ps.scale_amount_curve = shrink
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = ParticleLook.material(color, true)
	ps.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ps.color_ramp = ramp
	return ps


# ---------------------------------------------------------------- 跪地
## 失衡滿了跪下的那一刻：膝蓋落地的重音＋一小團雪粉——「現在是破綻」聽得出來，不用盯著畫面。
## 致命的一擊不算（接著就是倒下，倒下有自己的聲音）。聲音掛在關卡上（跟腳步一樣）。

## 跪下過幾次、最後一次播了哪些音（測試用）
var kneel_count: int = 0
var last_kneel_sounds: PackedStringArray = []


func _on_kneel() -> void:
	if (health != null and health.is_dead()) or not is_inside_tree():
		return
	kneel_count += 1
	last_kneel_sounds = _play_kneel(get_parent() if get_parent() != null else self)


## 子類別決定跪地的聲音與雪粉；回傳播了哪些音名。一般敵人：腳下地面的腳步聲壓低八度左右＋很輕的悶響。
func _play_kneel(parent: Node) -> PackedStringArray:
	var at: Vector3 = global_position + forward() * 0.35
	var step: String = "step_" + Footsteps.surface_at(self)
	var p: AudioStreamPlayer3D = Sfx.play_at(parent, step, at, -6.0, 0.04, 4.0)
	if p != null:
		p.pitch_scale *= 0.62
	Sfx.play_at(parent, "blunt", at + Vector3.UP * 0.2, -15.0, 0.05, 4.0)
	_kneel_puff(at, Vector3(0.3, 0.04, 0.3), 10)
	return PackedStringArray([step, "blunt"])


## 跪地的雪粉：可能跪很多次，噴完就釋放（倒下的雪粉跟著敵人一起被釋放）。
func _kneel_puff(at: Vector3, extents: Vector3, amount: int) -> void:
	var ps: CPUParticles3D = _ground_puff(at, extents, amount, Color(0.74, 0.77, 0.84, 0.5))
	ps.name = "KneelPuff"
	ps.finished.connect(ps.queue_free)


# ---------------------------------------------------------------- 倒下
## 一般敵人：跪下 → 向前撲倒（頭朝 forward()）→ 落地揚起灰粉、胸口的光熄掉 → 躺一會兒 → 沉進雪裡。
## 不再「往後倒＋壓扁成一片」。送葬者覆寫成更長、更重的版本。
## FALL_FORWARD：繞 X 軸轉負角度是往前倒（頭在 -Z）；寫新的姿勢照這個常數，別再寫反。
const FALL_FORWARD: float = -1.0
const DIE_KNEEL_SEC: float = 0.22
const DIE_DROP_SEC: float = 0.38
const DIE_LIE_SEC: float = 1.3
const DIE_SINK_SEC: float = 1.1
## 倒地那一刻（測試用）
var has_fallen: bool = false
## 截圖用：停在倒地那一刻，不沉進雪裡
var debug_hold_fallen: bool = false
var _fall_tween: Tween


func die_total_sec() -> float:
	return DIE_KNEEL_SEC + DIE_DROP_SEC + DIE_LIE_SEC + DIE_SINK_SEC


func _on_died() -> void:
	_begin_death()
	var t := create_tween()
	_fall_tween = t
	t.tween_property(_body, "position:y", -0.3, DIE_KNEEL_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_body, "rotation_degrees:x", FALL_FORWARD * 82.0, DIE_DROP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_body, "position:y", 0.18, DIE_DROP_SEC)
	t.tween_callback(_on_fall_impact)
	t.tween_interval(DIE_LIE_SEC)
	t.tween_property(_body, "position:y", -1.0, DIE_SINK_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


## 倒下共用：不再追、不再吃傷害、不再擋路，藏起看穿與弱點標記。
## 停掉 _physics_process（_update_look 每幀會蓋掉倒地動作）。
func _begin_death() -> void:
	brain.kill()
	remove_from_group("damageable")
	set_physics_process(false)
	_set_brace_lit(false)
	collision_layer = 0


## 身體撞到地面那一刻；子類別可以加料（記得呼叫 super）。
func _on_fall_impact() -> void:
	has_fallen = true
	var at: Vector3 = global_position + forward() * 0.8
	if is_inside_tree():
		Sfx.play_at(get_parent(), "blunt", at, -4.0, 0.03)
	_ground_puff(at, Vector3(0.35, 0.05, 0.75), 24, Color(0.72, 0.74, 0.8, 0.65))
	if debug_hold_fallen and _fall_tween != null:
		_fall_tween.pause()


## 倒地揚起的粉（雪或灰）：一次性的小粒子，節點名 FallPuff。
func _ground_puff(at: Vector3, extents: Vector3, amount: int, color: Color) -> CPUParticles3D:
	var ps: CPUParticles3D = puff_build(extents, amount, color)
	puff_start(ps, at)
	return ps


## 一團粉的粒子：建好但**還沒開始噴**、也還沒進場景樹。要改速度、大小、重力的先改，再 puff_start()。
## CPUParticles3D 預設 emitting＝true，一進場景樹就會在「當下的位置」先噴出第一批；
## 一次性、explosiveness 0.9 的粒子第一批就是全部——原本先 add_child 再擺位置，整團粉其實噴在敵人腳下的原點，
## 不是指定的地方（倒地的粉偏 0.8 m 看不出來；燈柱砸藥桶那一下偏了 8 m，在鏡頭外，所以怎麼拍都拍不到）。
func puff_build(extents: Vector3, amount: int, color: Color) -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.name = "FallPuff"
	ps.emitting = false
	ps.one_shot = true
	ps.explosiveness = 0.9
	ps.amount = amount
	ps.lifetime = 1.3
	ps.direction = Vector3.UP
	ps.spread = 75.0
	ps.initial_velocity_min = 0.8
	ps.initial_velocity_max = 2.4
	ps.gravity = Vector3(0, -1.5, 0)
	ps.damping_min = 1.5
	ps.damping_max = 3.0
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = extents
	ps.scale_amount_min = 0.7
	ps.scale_amount_max = 1.6
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	# 圓形、邊緣淡出的貼圖（沒有貼圖時是硬邊方塊，一眼就看得出是方形面片）
	quad.material = ParticleLook.material(color)
	ps.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ps.color_ramp = ramp
	return ps


## 把 puff_build() 的那一團放到 at（世界座標）再開始噴：先擺好位置才能開始（見 puff_build 的說明）。
func puff_start(ps: CPUParticles3D, at: Vector3) -> void:
	add_child(ps)
	ps.global_position = at
	ps.emitting = true


## 粒子用的柔邊圓點（共用 ParticleLook）。
static func soft_dot_texture() -> GradientTexture2D:
	return ParticleLook.soft_dot()
