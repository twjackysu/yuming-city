class_name Undertaker
extends EnemyActor
## 送葬者（精英）：背負鐵架、追著心跳走。第一階段三招（02-gameplay「送葬者」）：
##   鐵架橫掃（扇形霜紋）／鐵架下砸（圓形霜紋，砸地後 0.6 秒破綻）／追心跳衝撞（直線霜紋，撞牆跪地 2 秒）。
## 生命降到 phase2_hp 進入第二階段：看穿裡「下砸」變成未證實，前兆縮短（攻略開始失準）。第二階段的新招在下一步。
## 弱點：鐵架關節，從背後打得到；跪地時全露。

signal phase_changed(phase: int)

const FROST: Color = Color(0.55, 0.82, 1.0)

var phase: int = 1

var _decals: Dictionary = {}
var _charge_hit: Array[Node3D] = []
var _hit_wall: bool = false


func intel_id() -> String:
	return "undertaker"


func _insight_height() -> float:
	return 3.1


func _on_strike() -> void:
	var fwd: Vector3 = forward()
	var origin: Vector3 = global_position
	match brain.move_id:
		"sweep":
			var reach: float = brain.move_num("sweep", "range", 3.2)
			var arc: float = brain.move_num("sweep", "arc_deg", 150.0)
			Sfx.play_at(self, "claw", origin + fwd * 1.5 + Vector3.UP, 2.0, 0.04)
			hit_heartbeats(brain.move_num("sweep", "damage", 28.0), "sweep",
				func(p: Vector3) -> bool: return PlayerController.in_strike_arc(origin, fwd, p, reach + 0.3, arc))
		"slam":
			var center: Vector3 = slam_center()
			var r: float = brain.move_num("slam", "radius", 2.0)
			Sfx.play_at(self, "blunt_weak", center + Vector3.UP * 0.3, 4.0, 0.03, 10.0)
			_shake_player(0.45)
			hit_heartbeats(brain.move_num("slam", "damage", 40.0), "slam",
				func(p: Vector3) -> bool: return Vector2(p.x - center.x, p.z - center.z).length() <= r)
		"charge":
			_charge_hit.clear()
			_hit_wall = false
			Sfx.play_at(self, "whoosh", origin + Vector3.UP, 4.0)


## 衝撞：出招期間往前直衝，碰到心跳就撞（每次衝撞每人一次）。
func _on_strike_tick(_delta: float) -> Vector3:
	if brain.move_id != "charge" or _hit_wall:
		return Vector3.ZERO
	var r: float = brain.move_num("charge", "hit_radius", 1.1)
	var me: Vector3 = global_position
	for n: Node in get_tree().get_nodes_in_group("heartbeat"):
		var hb: Node3D = n as Node3D
		if hb == null or _charge_hit.has(hb):
			continue
		if Vector2(hb.global_position.x - me.x, hb.global_position.z - me.z).length() <= r:
			_charge_hit.append(hb)
			hurt(hb, brain.move_num("charge", "damage", 22.0), "charge")
	return forward() * brain.move_num("charge", "speed", 11.0)


## 衝撞撞到牆（水平法線的碰撞）→ 跪地。
func _after_move() -> void:
	if brain.state != EnemyBrain.State.STRIKE or brain.move_id != "charge" or _hit_wall:
		return
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		var hit: Node = c.get_collider() as Node
		if absf(c.get_normal().y) < 0.5 and not (hit != null and hit.is_in_group("heartbeat")):
			_hit_wall = true
			brain.force_kneel(brain.move_num("charge", "wall_kneel", 2.0))
			Sfx.play_at(self, "blunt_weak", global_position + forward() + Vector3.UP, 4.0, 0.03, 10.0)
			_shake_player(0.6)
			return


func slam_center() -> Vector3:
	return global_position + forward() * brain.move_num("slam", "reach", 1.9)


func _on_damaged(amount: float, info: Dictionary) -> void:
	super._on_damaged(amount, info)
	if phase == 1 and health.hp <= CombatTuning.num("undertaker.phase2_hp", 450.0) and not health.is_dead():
		enter_phase_two()


## 第二階段：扯斷一條鐵鏈；看穿裡「下砸」變成未證實，下砸前兆縮短。
func enter_phase_two() -> void:
	phase = 2
	intel_overrides["slam"] = false
	var slam: Dictionary = (brain.moves.get("slam", {}) as Dictionary).duplicate()
	slam["telegraph"] = float(slam.get("telegraph_phase2", 0.7))
	brain.moves["slam"] = slam
	phase_changed.emit(phase)


func _shake_player(amount: float) -> void:
	if _player != null and global_position.distance_to(_player.global_position) < 12.0:
		_player.shake(amount)


func _update_look() -> void:
	var p: float = brain.telegraph_progress()
	for id: String in _decals:
		var mi: MeshInstance3D = _decals[id] as MeshInstance3D
		var on: bool = brain.state == EnemyBrain.State.TELEGRAPH and brain.move_id == id
		mi.visible = on
		if on:
			(mi.material_override as StandardMaterial3D).albedo_color = Color(FROST, 0.15 + 0.6 * p * p)
	_body.position.y = -0.5 if brain.state == EnemyBrain.State.STAGGERED else 0.0
	# 前兆姿勢：橫掃身體向左擰、下砸上身後仰、衝撞低頭
	var lean := Vector3.ZERO
	if brain.state == EnemyBrain.State.TELEGRAPH:
		match brain.move_id:
			"sweep":
				lean = Vector3(0, 35.0 * p, 0)
			"slam":
				lean = Vector3(-18.0 * p, 0, 0)
			"charge":
				lean = Vector3(22.0 * p, 0, 0)
	(_body.get_node("Torso") as Node3D).rotation_degrees = lean


func _build_body() -> void:
	super._build_body()
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 2.6
	shape.shape = cap
	shape.position = Vector3(0, 1.3, 0)
	add_child(shape)
	var robe := StandardMaterial3D.new()
	robe.albedo_color = Color(0.11, 0.11, 0.12)
	robe.roughness = 1.0
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.3, 0.24, 0.2)
	iron.metallic = 0.7
	iron.roughness = 0.6
	var torso := Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 1.0, 0)
	_body.add_child(torso)
	var coat := CSGCylinder3D.new()
	coat.radius = 0.55
	coat.height = 2.0
	coat.cone = true
	coat.position = Vector3(0, 0.1, 0)
	coat.material = robe
	torso.add_child(coat)
	var chest := CSGBox3D.new()
	chest.size = Vector3(1.0, 0.8, 0.55)
	chest.position = Vector3(0, 0.95, -0.05)
	chest.rotation_degrees = Vector3(-15, 0, 0)
	chest.material = robe
	torso.add_child(chest)
	var hood := CSGSphere3D.new()
	hood.radius = 0.26
	hood.position = Vector3(0, 1.45, -0.32)
	hood.material = robe
	torso.add_child(hood)
	# 背上的鐵架：兩根立柱＋三根橫桿＋關節（弱點）
	for x: float in [-0.45, 0.45]:
		var post := CSGBox3D.new()
		post.size = Vector3(0.08, 2.2, 0.08)
		post.position = Vector3(x, 1.1, 0.5)
		post.material = iron
		torso.add_child(post)
	for y: float in [0.4, 1.1, 1.9]:
		var bar := CSGBox3D.new()
		bar.size = Vector3(1.1, 0.07, 0.07)
		bar.position = Vector3(0, y, 0.52)
		bar.material = iron
		torso.add_child(bar)
	for side: float in [-1.0, 1.0]:
		var arm := CSGCylinder3D.new()
		arm.radius = 0.12
		arm.height = 1.2
		arm.position = Vector3(side * 0.62, 0.6, -0.15)
		arm.rotation_degrees = Vector3(-20, 0, side * 8.0)
		arm.material = robe
		torso.add_child(arm)
	_build_decals()


func _build_decals() -> void:
	var sweep_mesh: ArrayMesh = _fan_mesh(brain.move_num("sweep", "range", 3.2), brain.move_num("sweep", "arc_deg", 150.0))
	_decals["sweep"] = _decal(sweep_mesh, Vector3(0, 0.03, 0))
	var disc := CylinderMesh.new()
	var r: float = brain.move_num("slam", "radius", 2.0)
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.01
	_decals["slam"] = _decal(disc, Vector3(0, 0.03, -brain.move_num("slam", "reach", 1.9)))
	var lane := BoxMesh.new()
	var length: float = 8.0
	lane.size = Vector3(brain.move_num("charge", "hit_radius", 1.1) * 2.0, 0.01, length)
	_decals["charge"] = _decal(lane, Vector3(0, 0.03, -length * 0.5))


func _decal(mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(FROST, 0.2)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	_body.add_child(mi)
	return mi


## 地面扇形（朝 -Z，左右各 arc/2）。
static func _fan_mesh(radius: float, arc_deg: float, segments: int = 24) -> ArrayMesh:
	var verts := PackedVector3Array()
	var half: float = deg_to_rad(arc_deg * 0.5)
	for i: int in segments:
		var a0: float = -half + (2.0 * half) * float(i) / float(segments)
		var a1: float = -half + (2.0 * half) * float(i + 1) / float(segments)
		verts.append(Vector3.ZERO)
		verts.append(Vector3(-sin(a0), 0, -cos(a0)) * radius)
		verts.append(Vector3(-sin(a1), 0, -cos(a1)) * radius)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
