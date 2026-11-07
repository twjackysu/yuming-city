class_name TrainingDummy
extends StaticBody3D
## 練習木樁：驗證命中、hit stop 與打擊回饋。被打倒後 reset_after 秒自動立回來。
## 在 damageable 群組，Health 子節點（玩家的 strike() 依群組找目標）。

var health: Health
var hits_taken: int = 0
var _post: Node3D
var _reset_left: float = 0.0


func _ready() -> void:
	add_to_group("damageable")
	health = Health.new(CombatTuning.num("dummy.max_hp", 60.0))
	health.name = "Health"
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_build()


func _process(delta: float) -> void:
	if _reset_left <= 0.0:
		return
	_reset_left -= delta
	if _reset_left <= 0.0:
		health.reset()
		var t := create_tween()
		t.tween_property(_post, "rotation_degrees", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_damaged(_amount: float, info: Dictionary) -> void:
	hits_taken += 1
	if health.is_dead():
		return
	# 往受力方向晃一下
	var away := Vector3(0, 0, 1)
	var src: Node3D = info.get("source") as Node3D
	if src != null:
		away = (global_position - src.global_position)
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3(0, 0, 1)
	var local: Vector3 = global_basis.inverse() * away
	var tilt := Vector3(local.z, 0.0, -local.x) * 14.0
	var t := create_tween()
	t.tween_property(_post, "rotation_degrees", tilt, 0.06)
	t.tween_property(_post, "rotation_degrees", -tilt * 0.4, 0.18).set_trans(Tween.TRANS_SINE)
	t.tween_property(_post, "rotation_degrees", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_SINE)


func _on_died() -> void:
	_reset_left = CombatTuning.num("dummy.reset_after", 3.0)
	var t := create_tween()
	t.tween_property(_post, "rotation_degrees", Vector3(-80, 0, 0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _build() -> void:
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 1.8
	shape.shape = cyl
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	_post = Node3D.new()
	_post.name = "Post"
	add_child(_post)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.22, 0.15)
	wood.roughness = 0.95
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.55, 0.47, 0.3)
	straw.roughness = 1.0
	var pole := CSGCylinder3D.new()
	pole.radius = 0.09
	pole.height = 1.8
	pole.position = Vector3(0, 0.9, 0)
	pole.material = wood
	_post.add_child(pole)
	var body := CSGCylinder3D.new()
	body.radius = 0.28
	body.height = 0.8
	body.position = Vector3(0, 1.15, 0)
	body.material = straw
	_post.add_child(body)
	var arm := CSGBox3D.new()
	arm.size = Vector3(1.0, 0.1, 0.1)
	arm.position = Vector3(0, 1.4, 0)
	arm.material = wood
	_post.add_child(arm)
	var head := CSGSphere3D.new()
	head.radius = 0.18
	head.position = Vector3(0, 1.75, 0)
	head.material = straw
	_post.add_child(head)
