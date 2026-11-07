class_name Ashwalker
extends CharacterBody3D
## 灰巡者（一般敵人）：佝僂的灰色人形，胸口嵌著鐘盤。前兆時爪上的霜紋由暗轉亮。
## 邏輯在 EnemyBrain；這裡負責移動、面向、命中判定與表現。
## 看穿（玩家按住 insight）時頭上顯示已知資訊（EnemyIntel），左膝亮起弱點標記；
## 從敵人左側或趁跪地打中，算打到左膝（傷害、失衡加倍，見 PlayerController.strike）。

const MOVE_SPEED: float = 2.6
const TURN_SPEED: float = 8.0
const INTEL_ID: String = "ashwalker"
## 看穿的顯示距離（公尺）
const INSIGHT_RANGE: float = 14.0

var brain: EnemyBrain
var health: Health
## 追擊目標：最近的心跳（heartbeat 群組：諾恩、席菈）；看穿則只看諾恩
var target: Node3D
var _player: PlayerController
var _body: Node3D
var _claw_mat: StandardMaterial3D
## 看穿資訊的執行期修正（id → 是否已證實），之後由觀察或劇情改
var intel_overrides: Dictionary = {}
var difficulty: String = "standard"
var _insight_label: Label3D
var _weak_marker: MeshInstance3D
var _weak_mat: StandardMaterial3D
var _insight_shown: bool = false


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("enemies")
	brain = EnemyBrain.new().configure("ashwalker", difficulty)
	health = Health.new(CombatTuning.num("ashwalker.max_hp", 60.0))
	health.name = "Health"
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_build()


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player() as PlayerController
	target = _nearest_heartbeat()
	var dist: float = 999.0
	if target != null:
		var d: Vector3 = target.global_position - global_position
		d.y = 0.0
		dist = d.length()
		if brain.state in [EnemyBrain.State.CHASE, EnemyBrain.State.TELEGRAPH] and d.length() > 0.01:
			var face: float = atan2(-d.x, -d.z)
			_body.rotation.y = lerp_angle(_body.rotation.y, face, clampf(TURN_SPEED * delta, 0.0, 1.0))
	if brain.tick(delta, dist):
		_strike()
	var horizontal := Vector3.ZERO
	if brain.is_moving() and target != null and dist > brain.attack_range * 0.8:
		horizontal = -_body.global_basis.z * MOVE_SPEED
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	_update_look()
	_update_insight()


func forward() -> Vector3:
	return -_body.global_basis.z


## 攻擊者從這個位置打，打得到哪個弱點（沒有就回傳空字串）。跪地時弱點全露。
func weakpoint_exposed_to(attacker_pos: Vector3) -> String:
	if brain.state == EnemyBrain.State.DEAD:
		return ""
	for w: Dictionary in EnemyIntel.weakpoints(INTEL_ID):
		if brain.state == EnemyBrain.State.STAGGERED or EnemyIntel.is_exposed(global_position, forward(), attacker_pos, EnemyIntel.arc_of(w)):
			return str(w.get("id", ""))
	return ""


func insight_shown() -> bool:
	return _insight_shown


func insight_text() -> String:
	return _insight_label.text


func _update_insight() -> void:
	var on: bool = false
	if _player != null and brain.state != EnemyBrain.State.DEAD:
		on = _player.insight_active and global_position.distance_to(_player.global_position) <= INSIGHT_RANGE
	if on:
		_insight_label.text = "\n".join(EnemyIntel.lines(INTEL_ID, intel_overrides, brain.current_move()))
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		_weak_mat.albedo_color.a = 0.45 + 0.4 * pulse
	if on != _insight_shown:
		_insight_shown = on
		_insight_label.visible = on
		_weak_marker.visible = on


## 前兆與出招中不換目標（不然閃開的時機會亂掉）。
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


func _find_player() -> Node3D:
	for n: Node in get_tree().get_nodes_in_group("player"):
		return n as Node3D
	return null


## 爪擊：前方扇形內的玩家受傷（閃避無敵時 Health 會拒絕）。回傳是否命中。
func _strike() -> bool:
	if target == null:
		return false
	var forward: Vector3 = -_body.global_basis.z
	if not PlayerController.in_strike_arc(global_position, forward, target.global_position, brain.attack_range + 0.4, 100.0):
		return false
	var h: Health = target.get_node_or_null("Health") as Health
	if h == null:
		return false
	var dmg: float = CombatTuning.num("ashwalker.claw_damage", 14.0) * CombatTuning.num("difficulty.%s.enemy_damage" % difficulty, 1.0)
	return h.apply_damage(dmg, {"source": self, "kind": "claw"})


func _on_damaged(_amount: float, info: Dictionary) -> void:
	if str(info.get("weak", "")) != "":
		_flash_weak()
	brain.add_stagger(float(info.get("stagger", 0.0)))


func _on_died() -> void:
	brain.kill()
	remove_from_group("damageable")
	var t := create_tween()
	t.tween_property(_body, "rotation_degrees:x", 80.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_body, "scale", Vector3(1.0, 0.05, 1.0), 1.2)
	t.tween_callback(queue_free)


func _flash_weak() -> void:
	var t := create_tween()
	_weak_marker.visible = true
	t.tween_property(_weak_mat, "emission_energy_multiplier", 8.0, 0.04)
	t.tween_property(_weak_mat, "emission_energy_multiplier", 2.0, 0.25)
	t.tween_callback(func() -> void: _weak_marker.visible = _insight_shown)


func _update_look() -> void:
	var p: float = brain.telegraph_progress()
	_claw_mat.emission_energy_multiplier = 0.2 + p * p * 6.0
	if brain.state == EnemyBrain.State.STAGGERED:
		_body.position.y = -0.35
	else:
		_body.position.y = 0.0


func _build() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	shape.shape = cap
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var ash := StandardMaterial3D.new()
	ash.albedo_color = Color(0.36, 0.36, 0.38)
	ash.roughness = 1.0
	_claw_mat = StandardMaterial3D.new()
	_claw_mat.albedo_color = Color(0.5, 0.6, 0.7)
	_claw_mat.emission_enabled = true
	_claw_mat.emission = Color(0.55, 0.8, 1.0)
	var torso := CSGCylinder3D.new()
	torso.radius = 0.26
	torso.height = 0.9
	torso.position = Vector3(0, 1.1, 0.1)
	torso.rotation_degrees = Vector3(-25, 0, 0)
	torso.material = ash
	_body.add_child(torso)
	var head := CSGSphere3D.new()
	head.radius = 0.17
	head.position = Vector3(0, 1.55, -0.18)
	head.material = ash
	_body.add_child(head)
	var dial := CSGCylinder3D.new()
	dial.radius = 0.12
	dial.height = 0.04
	dial.rotation_degrees = Vector3(65, 0, 0)
	dial.position = Vector3(0, 1.2, -0.12)
	dial.material = _claw_mat
	_body.add_child(dial)
	for side: float in [-1.0, 1.0]:
		var leg := CSGCylinder3D.new()
		leg.radius = 0.08
		leg.height = 0.75
		leg.position = Vector3(side * 0.14, 0.38, 0)
		leg.material = ash
		_body.add_child(leg)
		var arm := CSGCylinder3D.new()
		arm.radius = 0.06
		arm.height = 0.8
		arm.position = Vector3(side * 0.34, 1.0, -0.2)
		arm.rotation_degrees = Vector3(-35, 0, 0)
		arm.material = ash
		_body.add_child(arm)
		var claw := CSGBox3D.new()
		claw.size = Vector3(0.08, 0.05, 0.28)
		claw.position = Vector3(side * 0.34, 0.66, -0.45)
		claw.material = _claw_mat
		_body.add_child(claw)
	_build_insight()


func _build_insight() -> void:
	_insight_label = Label3D.new()
	_insight_label.name = "Insight"
	_insight_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_insight_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_insight_label.no_depth_test = true
	_insight_label.fixed_size = true
	_insight_label.pixel_size = 0.0009
	_insight_label.font_size = 30
	_insight_label.outline_size = 10
	_insight_label.modulate = Color(0.82, 0.92, 1.0)
	_insight_label.outline_modulate = Color(0.02, 0.04, 0.08, 0.85)
	_insight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_insight_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_insight_label.position = Vector3(0.35, 2.0, 0)
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
	var w: Dictionary = EnemyIntel.weakpoint(INTEL_ID, "left_knee")
	var loc: Variant = w.get("local", [-0.14, 0.38, 0.0])
	if loc is Array and (loc as Array).size() == 3:
		_weak_marker.position = Vector3(float((loc as Array)[0]), float((loc as Array)[1]), float((loc as Array)[2]))
	_weak_marker.visible = false
	_body.add_child(_weak_marker)
