class_name Ashwalker
extends CharacterBody3D
## 灰巡者（一般敵人）：佝僂的灰色人形，胸口嵌著鐘盤。前兆時爪上的霜紋由暗轉亮。
## 邏輯在 EnemyBrain；這裡負責移動、面向、命中判定與表現。弱點（左膝）與看穿在之後的指令系統接上。

const MOVE_SPEED: float = 2.6
const TURN_SPEED: float = 8.0

var brain: EnemyBrain
var health: Health
var target: Node3D
var _body: Node3D
var _claw_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("enemies")
	brain = EnemyBrain.new().configure("ashwalker")
	health = Health.new(CombatTuning.num("ashwalker.max_hp", 60.0))
	health.name = "Health"
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_build()


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = _find_player()
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
	var dmg: float = CombatTuning.num("ashwalker.claw_damage", 14.0) * CombatTuning.num("difficulty.standard.enemy_damage", 1.0)
	return h.apply_damage(dmg, {"source": self, "kind": "claw"})


func _on_damaged(_amount: float, info: Dictionary) -> void:
	brain.add_stagger(float(info.get("stagger", 0.0)))


func _on_died() -> void:
	brain.kill()
	remove_from_group("damageable")
	var t := create_tween()
	t.tween_property(_body, "rotation_degrees:x", 80.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_body, "scale", Vector3(1.0, 0.05, 1.0), 1.2)
	t.tween_callback(queue_free)


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
