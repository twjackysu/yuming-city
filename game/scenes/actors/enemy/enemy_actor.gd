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

var _player: PlayerController
var _body: Node3D
var _insight_label: Label3D
var _weak_marker: MeshInstance3D
var _weak_mat: StandardMaterial3D
var _insight_shown: bool = false


func intel_id() -> String:
	return ""


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("enemies")
	if difficulty == "":
		difficulty = Settings.difficulty
		Settings.changed.connect(_on_settings_changed)
	brain = EnemyBrain.new().configure(intel_id(), difficulty)
	move_speed = CombatTuning.num(intel_id() + ".move_speed", move_speed)
	health = Health.new(CombatTuning.num(intel_id() + ".max_hp", 60.0))
	health.name = "Health"
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_build_body()
	_build_insight()


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
		# 劇情動作中（送葬者舉起鐵架）：不追、不出招
		velocity = Vector3(0.0, 0.0 if is_on_floor() else velocity.y - 18.0 * delta, 0.0)
		move_and_slide()
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
	_after_move()
	_update_look()
	_update_insight()


func forward() -> Vector3:
	return -_body.global_basis.z


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
	return _insight_label.text


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


## 回傳 true＝這一幀被劇情動作佔住（不跑狀態機、不移動）。
func _held(_delta: float) -> bool:
	return false


func _update_look() -> void:
	pass


func _insight_height() -> float:
	return 2.0


# ---- 共用 ----

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
	if str(info.get("weak", "")) != "":
		_flash_weak()
	brain.add_stagger(float(info.get("stagger", 0.0)))


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
	if _insight_label != null:
		_insight_label.visible = false
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
func _ground_puff(at: Vector3, extents: Vector3, amount: int, color: Color) -> void:
	var ps := CPUParticles3D.new()
	ps.name = "FallPuff"
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
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	# 圓形、邊緣淡出的貼圖（沒有貼圖時是硬邊方塊，一眼就看得出是方形面片）
	mat.albedo_texture = soft_dot_texture()
	quad.material = mat
	ps.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ps.color_ramp = ramp
	add_child(ps)
	ps.global_position = at
	ps.emitting = true


## 粒子用的柔邊圓點（中心白、往外透明；32×32，倒下時才建一張）。
static func soft_dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


func _update_insight() -> void:
	var on: bool = false
	if _player != null and brain.state != EnemyBrain.State.DEAD:
		on = _player.insight_active and global_position.distance_to(_player.global_position) <= INSIGHT_RANGE
	if on:
		_insight_label.text = "\n".join(EnemyIntel.lines(intel_id(), intel_overrides, brain.intel_move()))
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		_weak_mat.albedo_color.a = 0.45 + 0.4 * pulse
	if on != _insight_shown:
		_insight_shown = on
		_insight_label.visible = on
		_weak_marker.visible = on


func _flash_weak() -> void:
	var t := create_tween()
	_weak_marker.visible = true
	t.tween_property(_weak_mat, "emission_energy_multiplier", 8.0, 0.04)
	t.tween_property(_weak_mat, "emission_energy_multiplier", 2.0, 0.25)
	t.tween_callback(func() -> void: _weak_marker.visible = _insight_shown)


func _build_insight() -> void:
	_insight_label = Label3D.new()
	_insight_label.name = "Insight"
	_insight_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_insight_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_insight_label.no_depth_test = true
	_insight_label.fixed_size = true
	_insight_label.pixel_size = 0.0009
	_insight_label.font_size = 30
	_insight_label.outline_size = 18
	_insight_label.modulate = Color(0.82, 0.92, 1.0)
	_insight_label.outline_modulate = Color(0.02, 0.04, 0.08, 0.85)
	_insight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_insight_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_insight_label.position = Vector3(0.35, _insight_height(), 0)
	var f: Font = UiFonts.load_font(UiFonts.UI_SANS)
	if f != null:
		_insight_label.font = f
	_insight_label.visible = false
	add_child(_insight_label)
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
