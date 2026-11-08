class_name Ashwalker
extends EnemyActor
## 灰巡者（一般敵人）：佝僂的灰色人形，胸口嵌著鐘盤。前兆時爪上的霜紋由暗轉亮。
## 共用行為（追心跳、看穿、弱點、難度）在 EnemyActor；這裡是外型、爪擊判定與前兆表現。
## 從敵人左側或趁跪地打中，算打到左膝（傷害、失衡加倍，見 PlayerController.strike）。

var _claw_mat: StandardMaterial3D


func intel_id() -> String:
	return "ashwalker"


## 爪擊：前方扇形內的心跳（諾恩或席菈）受傷（閃避無敵時 Health 會拒絕）。
func _on_strike() -> void:
	if target == null:
		return
	var fwd: Vector3 = forward()
	Sfx.play_at(self, "claw", global_position + fwd * 0.8 + Vector3.UP, -2.0)
	var reach: float = brain.attack_range + 0.4
	var origin: Vector3 = global_position
	hit_heartbeats(CombatTuning.num("ashwalker.claw_damage", 14.0), "claw",
		func(p: Vector3) -> bool: return PlayerController.in_strike_arc(origin, fwd, p, reach, 100.0))


func _update_look() -> void:
	var p: float = brain.telegraph_progress()
	_claw_mat.emission_energy_multiplier = 0.2 + p * p * 6.0
	_body.position.y = -0.35 if brain.state == EnemyBrain.State.STAGGERED else 0.0


## 撲倒在地：胸口鐘盤與爪上的霜光慢慢熄掉（D-054）。
func _on_fall_impact() -> void:
	super._on_fall_impact()
	if _claw_mat != null and is_inside_tree():
		var t := create_tween()
		t.tween_property(_claw_mat, "emission_energy_multiplier", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _build_body() -> void:
	super._build_body()
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	shape.shape = cap
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)
	ContactShadow.attach(self, 0.65, 0.5)  # D-108
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
