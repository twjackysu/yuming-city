class_name EnemyActor
extends CharacterBody3D
## 敵人共用：EnemyBrain、Health、追最近的心跳（諾恩、席菈）、看穿顯示、弱點判定、難度即時套用。
## 子類別覆寫 intel_id()、_build_body()（建立 _body）、_on_strike()、_on_strike_tick()、_update_look()。

const TURN_SPEED: float = 8.0
## 看穿的顯示距離（公尺）
const INSIGHT_RANGE: float = 14.0

var brain: EnemyBrain
var health: Health
## 追擊目標：最近的心跳；前兆與出招中不換目標
var target: Node3D
## 看穿資訊的執行期修正（id → 是否已證實），觀察或劇情會改
var intel_overrides: Dictionary = {}
## 空字串＝用設定裡的難度；設定改了即時套用
var difficulty: String = ""
var move_speed: float = 2.6
## 腳步聲（D-187）：子類別在 _make_footsteps() 回傳自己的一份（null＝不出聲）；移動後照實際走了多遠踏步。
var footsteps: Footsteps

var _player: PlayerController
var _body: Node3D
var _insight_layer: CanvasLayer
var _insight_card: InsightCard
var _insight_text: String = ""
var _weak_marker: MeshInstance3D
var _weak_mat: StandardMaterial3D
var _insight_shown: bool = false


func intel_id() -> String:
	return ""


## 離鏡頭多近開始淡掉（x 以內看不到、y 以外不透明，D-115）。體型大的敵人覆寫成更遠。
func camera_fade_range() -> Vector2:
	return Vector2(CameraFade.CHARACTER_NEAR, CameraFade.CHARACTER_FAR)


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("enemies")
	if difficulty == "":
		difficulty = Settings.difficulty
		Settings.changed.connect(_on_settings_changed)
	brain = EnemyBrain.new().configure(intel_id(), difficulty)
	brain.knelt.connect(_on_kneel)
	move_speed = CombatTuning.num(intel_id() + ".move_speed", move_speed)
	health = Health.new(CombatTuning.num(intel_id() + ".max_hp", 60.0))
	health.name = "Health"
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_build_body()
	_build_insight()
	footsteps = _make_footsteps()
	var fade: Vector2 = camera_fade_range()
	CameraFade.apply(self, fade.x, fade.y)  # D-115


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
		# 劇情動作中（送葬者舉起鐵架）：不追、不出招。劇情走位（D-205）由 _held_velocity 給水平速度，照樣用自己的腳走
		var held_v: Vector3 = _held_velocity(delta)
		velocity = Vector3(held_v.x, 0.0 if is_on_floor() else velocity.y - 18.0 * delta, held_v.z)
		move_and_slide()
		if Vector2(held_v.x, held_v.z).length() > 0.01:
			_tick_footsteps(delta, Vector2(held_v.x, held_v.z).length())
		_update_look()
		_update_insight()
		return
	if brain.tick(delta, dist):
		_on_strike()
	var horizontal := Vector3.ZERO
	if brain.state == EnemyBrain.State.STRIKE:
		horizontal = _on_strike_tick(delta)
	elif brain.is_moving() and target != null and dist > brain.attack_range * 0.8:
		horizontal = forward() * move_speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	_tick_footsteps(delta, Vector2(horizontal.x, horizontal.z).length())
	_after_move()
	_update_look()
	_update_insight()


func forward() -> Vector3:
	return -_body.global_basis.z


## 直接轉向（水平角度，跟節點自己的 rotation.y 疊加）：關卡把劇情中的敵人交給戰鬥時用（D-169）。
func set_facing(yaw: float) -> void:
	if _body != null:
		_body.rotation.y = yaw


## 攻擊者從這個位置打，打得到哪個弱點（沒有就回傳空字串）。跪地時弱點全露。
func weakpoint_exposed_to(attacker_pos: Vector3) -> String:
	if brain.state == EnemyBrain.State.DEAD:
		return ""
	for w: Dictionary in EnemyIntel.weakpoints(intel_id()):
		if brain.state == EnemyBrain.State.STAGGERED or EnemyIntel.is_exposed(global_position, forward(), attacker_pos, EnemyIntel.arc_of(w)):
			return str(w.get("id", ""))
	return ""


## 鎖定標記的高度（頭上）。
func lock_height() -> float:
	return _insight_height() + 0.25


func insight_shown() -> bool:
	return _insight_shown


func insight_text() -> String:
	return _insight_text


func insight_card() -> InsightCard:
	return _insight_card


## 對所有心跳（諾恩、席菈）判定：pred(位置) 為 true 就扣血。回傳命中數。
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


## 被劇情動作佔住時這一幀的水平速度（預設站著不動；劇情走位覆寫，D-205）。
func _held_velocity(_delta: float) -> Vector3:
	return Vector3.ZERO


## 這隻敵人的腳步聲（null＝不出聲）。
func _make_footsteps() -> Footsteps:
	return null


func _update_look() -> void:
	pass


func _insight_height() -> float:
	return 2.0


## 身體（含背上的東西）往右多寬（公尺）：看穿小卡不蓋進這個範圍（D-146）。體型大的敵人覆寫。
func insight_side() -> float:
	return 0.45


# ---- 共用 ----

## 移動後踏步：用 move_and_slide 之後的實際速度（撞牆原地踏不算）；比平常快很多（衝撞）算跑步。
func _tick_footsteps(delta: float, speed: float) -> void:
	if footsteps == null:
		return
	var real: Vector3 = get_real_velocity()
	footsteps.tick(self, Vector2(real.x, real.z).length() * delta, speed > move_speed * 1.5, is_on_floor())


func _on_settings_changed() -> void:
	if Settings.difficulty != difficulty:
		difficulty = Settings.difficulty
		brain.configure(intel_id(), difficulty)


func _nearest_heartbeat() -> Node3D:
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


func _first_player() -> PlayerController:
	for n: Node in get_tree().get_nodes_in_group("player"):
		return n as PlayerController
	return null


func _on_damaged(_amount: float, info: Dictionary) -> void:
	var weak: bool = str(info.get("weak", "")) != ""
	if weak:
		_flash_weak()
	var knelt: bool = brain.add_stagger(float(info.get("stagger", 0.0)))
	# 成就「看穿」：打中弱點而跪下（D-147）
	if knelt and weak and intel_id() != "":
		Game.session.add_stat("stats.%s_weak_kneels" % intel_id())


# ---------------------------------------------------------------- 跪地（D-191）
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


# ---------------------------------------------------------------- 倒下（D-052、D-054）
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
	collision_layer = 0
	if _insight_card != null:
		_insight_card.visible = false
	if _weak_marker != null:
		_weak_marker.visible = false


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
## （D-208）CPUParticles3D 預設 emitting＝true，一進場景樹就會在「當下的位置」先噴出第一批；
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
	# 圓形、邊緣淡出的貼圖（沒有貼圖時是硬邊方塊，一眼就看得出是方形面片；D-056）
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


## 粒子用的柔邊圓點（共用 ParticleLook，D-056）。
static func soft_dot_texture() -> GradientTexture2D:
	return ParticleLook.soft_dot()


func _update_insight() -> void:
	var on: bool = false
	if _player != null and brain.state != EnemyBrain.State.DEAD:
		on = _player.insight_active and global_position.distance_to(_player.global_position) <= INSIGHT_RANGE
	if on:
		var move: String = brain.intel_move()
		_insight_text = "\n".join(EnemyIntel.lines(intel_id(), intel_overrides, move))
		_insight_card.set_rows(EnemyIntel.rows(intel_id(), intel_overrides, move))
		_insight_card.place(get_viewport().get_camera_3d(), global_position + Vector3(0.0, _insight_height(), 0.0), insight_side())
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		_weak_mat.albedo_color.a = 0.45 + 0.4 * pulse
	if on != _insight_shown:
		_insight_shown = on
		_weak_marker.visible = on
	if not on:
		_insight_card.visible = false


func _flash_weak() -> void:
	var t := create_tween()
	_weak_marker.visible = true
	t.tween_property(_weak_mat, "emission_energy_multiplier", 8.0, 0.04)
	t.tween_property(_weak_mat, "emission_energy_multiplier", 2.0, 0.25)
	t.tween_callback(func() -> void: _weak_marker.visible = _insight_shown)


func _build_insight() -> void:
	# 看穿小卡在畫面上（D-087）：自己一層 CanvasLayer，壓在 HUD（10）底下，不蓋住對話與暫停選單
	_insight_layer = CanvasLayer.new()
	_insight_layer.name = "InsightLayer"
	_insight_layer.layer = 9
	add_child(_insight_layer)
	_insight_card = InsightCard.new()
	_insight_layer.add_child(_insight_card)
	_weak_mat = StandardMaterial3D.new()
	_weak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_weak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_weak_mat.no_depth_test = true
	_weak_mat.albedo_color = Color(0.6, 0.9, 1.0, 0.8)
	_weak_mat.emission_enabled = true
	_weak_mat.emission = Color(0.55, 0.85, 1.0)
	_weak_mat.emission_energy_multiplier = 2.0
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	_weak_marker = MeshInstance3D.new()
	_weak_marker.name = "WeakMarker"
	_weak_marker.mesh = sphere
	_weak_marker.material_override = _weak_mat
	_weak_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ws: Array[Dictionary] = EnemyIntel.weakpoints(intel_id())
	if not ws.is_empty():
		var loc: Variant = ws[0].get("local", [0.0, 1.0, 0.0])
		if loc is Array and (loc as Array).size() == 3:
			_weak_marker.position = Vector3(float((loc as Array)[0]), float((loc as Array)[1]), float((loc as Array)[2]))
	_weak_marker.visible = false
	_body.add_child(_weak_marker)
