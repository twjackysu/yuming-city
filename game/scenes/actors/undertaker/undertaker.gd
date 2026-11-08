class_name Undertaker
extends EnemyActor
## 送葬者（精英）：背負鐵架、追著心跳走。第一階段三招（02-gameplay「送葬者」）：
##   鐵架橫掃（扇形霜紋）／鐵架下砸（圓形霜紋，砸地後 0.6 秒破綻）／追心跳衝撞（直線霜紋，撞牆跪地 2 秒）。
## 生命降到 phase2_hp 進入第二階段：看穿裡「下砸」變成未證實，前兆縮短（攻略開始失準），轉向傷者車隊。
## 第二階段（pattern_phase2）：連續下砸（第二下前兆 0.5，攻略沒寫：諾恩沒挨打地看過一次才變已證實，
## 之前席菈的「閃開」對第二下算失敗）、抓取（抓前方最近的心跳；席菈守在旁邊就擋下）、橫掃、衝撞。
## 鐵架拋擲：第二階段生命 ≤ frame_throw_hp 或車隊過半時觸發一次（`slice.frame_thrown`），接九息或薪火劍。
## 弱點：鐵架關節，從背後打得到；跪地時全露。

signal phase_changed(phase: int)
## 鐵架拋擲（劇情觸發一次）：場景接九息石拱或席菈的薪火劍
signal frame_throw_started
## 連續下砸的第二下：諾恩看過一次（沒被打到）就變已證實
signal double_slam_verified

const FROST: Color = Color(0.55, 0.82, 1.0)

var phase: int = 1
## 測試或場景可以指定；空的就用 Game.session.state
var state: GameState
var frame_thrown: bool = false
## 舉起鐵架的剩餘秒數（>0 時站著不動）
var throw_windup: float = 0.0
var _throw_total: float = 1.0
## 最近抓住的諾恩（被打中弱點時鬆手）
var _grabbed: PlayerController
## 第二下的觀察距離：諾恩在這個範圍內沒被打到才算「看過」
const WITNESS_RANGE: float = 8.0

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
		"slam", "double_slam", "double_slam_2":
			var id: String = brain.move_id
			var center: Vector3 = slam_center()
			var r: float = brain.move_num(id, "radius", 2.0)
			Sfx.play_at(self, "blunt_weak", center + Vector3.UP * 0.3, 4.0, 0.03, 10.0)
			_shake_player(0.45)
			var player_hp: float = _player.health.hp if _player != null else 0.0
			hit_heartbeats(brain.move_num(id, "damage", 40.0), id,
				func(p: Vector3) -> bool: return Vector2(p.x - center.x, p.z - center.z).length() <= r)
			if id == "double_slam_2" and _player != null:
				var unhurt: bool = _player.health.hp >= player_hp
				note_second_slam(unhurt, _player.global_position.distance_to(global_position) <= WITNESS_RANGE)
		"grab":
			_grab()
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
	_after_move_phase2()
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
	return global_position + forward() * brain.move_num(brain.move_id if brain.move_id.contains("slam") else "slam", "reach", 1.9)


## 連續下砸第二下的結果：諾恩在近處沒被打到＝看過一次 → 看穿變已證實、席菈之後抓得到時機。
func note_second_slam(unhurt: bool, witnessed: bool) -> void:
	if not (unhurt and witnessed) or bool(intel_overrides.get("double_slam", false)):
		return
	intel_overrides["double_slam"] = true
	brain.unreadable.erase("double_slam_2")
	double_slam_verified.emit()


## 抓取：前方 arc 內最近的心跳；席菈守著那個人（或她自己就是目標）時擋下。回傳被抓的對象（擋下或沒抓到＝null）。
func _grab() -> Node3D:
	var reach: float = brain.move_num("grab", "range", 2.2)
	var arc: float = brain.move_num("grab", "arc_deg", 90.0)
	var me: Vector3 = global_position
	var fwd: Vector3 = forward()
	var best: Node3D = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group("heartbeat"):
		var hb: Node3D = n as Node3D
		if hb == null or not PlayerController.in_strike_arc(me, fwd, hb.global_position, reach + 0.6, arc):
			continue
		var d: float = me.distance_squared_to(hb.global_position)
		if d < best_d:
			best_d = d
			best = hb
	intel_overrides["grab"] = true  # 抓過一次就知道了
	Sfx.play_at(self, "claw", me + fwd + Vector3.UP, 3.0, 0.04)
	if best == null:
		return null
	var guard: Node3D = _guard_for(best)
	if guard != null:
		hurt(guard, brain.move_num("grab", "damage", 20.0) * 0.5, "grab_blocked")
		return null
	hurt(best, brain.move_num("grab", "damage", 20.0), "grab")
	var p: PlayerController = best as PlayerController
	if p != null:
		_grabbed = p
		p.begin_grab(self, brain.move_num("grab", "hold", 2.0), int(brain.move_num("grab", "struggle", 5.0)), brain.move_num("grab", "squeeze_damage", 12.0))
		# 抓著人的時候站著不動
		brain.recover_sec = maxf(brain.recover_sec, brain.move_num("grab", "hold", 2.0))
	return best


## 守住：席菈開著守住、而且站在被抓的人旁邊（2.5 公尺內）就替他擋。
func _guard_for(victim: Node3D) -> Node3D:
	for n: Node in get_tree().get_nodes_in_group("heartbeat"):
		var s: Sheila = n as Sheila
		if s == null or s == victim or not s.brain.guard_active or s.brain.mode == CompanionBrain.Mode.DOWN:
			continue
		if s.global_position.distance_to(victim.global_position) <= 2.5:
			return s
	return null


func _game_state() -> GameState:
	if state != null:
		return state
	return Game.session.state if Game.session != null else null


## 第二階段：生命 ≤ frame_throw_hp 或車隊過半 → 鐵架拋擲（只一次）。
func _check_frame_throw() -> void:
	if phase != 2 or frame_thrown or health.is_dead():
		return
	var low: bool = health.hp <= CombatTuning.num("undertaker.frame_throw_hp", 300.0)
	var c: Caravan = _caravan()
	var half: bool = c != null and c.runner.progress() >= CombatTuning.num("undertaker.frame_throw_caravan_progress", 0.5)
	if low or half:
		trigger_frame_throw()


## 鐵架拋擲的前兆：站定、把鐵架舉過頭（ConvoyEncounter 呼叫）。
func begin_throw_windup(seconds: float) -> void:
	throw_windup = seconds
	_throw_total = maxf(seconds, 0.01)
	Sfx.play_at(self, "whoosh", global_position + Vector3.UP * 3.0, 2.0, 0.0, 10.0)


## 鐵架擲出去了（被石拱擋下或被燃燒劍斬斷）：背上的鐵架藏起來，之後是空手；飛出去的那一副由 ThrownFrame 演。
func end_throw(_outcome: String) -> void:
	throw_windup = 0.0
	brain.force_kneel(1.2)
	var frame: Node3D = _frame_node()
	if frame != null:
		frame.visible = false


## 背上的鐵架還在不在（擲出去之後就不在了）。
func has_frame() -> bool:
	var frame: Node3D = _frame_node()
	return frame != null and frame.visible


## 鐵架擲出的位置（背上鐵架的中心，世界座標）。
func frame_launch_point() -> Vector3:
	return global_position + Vector3.UP * 3.1


func _frame_node() -> Node3D:
	return _body.get_node_or_null("Torso/Frame") as Node3D if _body != null else null


func _held(delta: float) -> bool:
	if throw_windup <= 0.0:
		return false
	throw_windup = maxf(throw_windup - delta, 0.0)
	return true


func trigger_frame_throw() -> void:
	if frame_thrown:
		return
	frame_thrown = true
	var st: GameState = _game_state()
	if st != null:
		st.set_flag("slice.frame_thrown", true)
	frame_throw_started.emit()


func _caravan() -> Caravan:
	for n: Node in get_tree().get_nodes_in_group("caravan"):
		var c: Caravan = n as Caravan
		if c != null and not c.runner.is_arrived:
			return c
	return null


## 第二階段優先追車隊的心跳（前兆、出招中不換目標）。
func _nearest_heartbeat() -> Node3D:
	if phase == 2 and not (brain.state in [EnemyBrain.State.TELEGRAPH, EnemyBrain.State.STRIKE] and target != null and is_instance_valid(target)):
		var c: Caravan = _caravan()
		if c != null:
			return c
	return super._nearest_heartbeat()


func _after_move_phase2() -> void:
	_check_frame_throw()


func _on_damaged(amount: float, info: Dictionary) -> void:
	super._on_damaged(amount, info)
	# 抓著諾恩時被打中弱點（席菈「打弱點」）就鬆手
	if str(info.get("weak", "")) != "" and _grabbed != null and is_instance_valid(_grabbed) and _grabbed.grabbed_by == self:
		_grabbed.release_grab(true)
	if phase == 1 and health.hp <= CombatTuning.num("undertaker.phase2_hp", 450.0) and not health.is_dead():
		enter_phase_two()


## 第二階段：扯斷一條鐵鏈；看穿裡「下砸」變成未證實，下砸前兆縮短；換招式輪替、出現攻略沒寫的招。
func enter_phase_two() -> void:
	phase = 2
	intel_overrides["slam"] = false
	intel_overrides["double_slam"] = false
	brain.unreadable["double_slam_2"] = true
	_apply_phase_two_brain()
	phase_changed.emit(phase)
	_check_frame_throw()


## 第二階段的招式數值與輪替（難度改了、brain 重新 configure 後也要再套一次）。
func _apply_phase_two_brain() -> void:
	var slam: Dictionary = (brain.moves.get("slam", {}) as Dictionary).duplicate()
	slam["telegraph"] = float(slam.get("telegraph_phase2", 0.7))
	brain.moves["slam"] = slam
	var pat: Variant = CombatTuning.value("undertaker.pattern_phase2", [])
	if pat is Array:
		brain.set_pattern(PackedStringArray(pat as Array))


func _on_settings_changed() -> void:
	var unread: Dictionary = brain.unreadable.duplicate()
	super._on_settings_changed()
	brain.unreadable = unread
	if phase == 2:
		_apply_phase_two_brain()


func _shake_player(amount: float) -> void:
	if _player != null and global_position.distance_to(_player.global_position) < 12.0:
		_player.shake(amount)


func _update_look() -> void:
	var p: float = brain.telegraph_progress()
	for id: String in _decals:
		var mi: MeshInstance3D = _decals[id] as MeshInstance3D
		var on: bool = brain.state == EnemyBrain.State.TELEGRAPH and _decal_for(brain.move_id) == id
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
			"slam", "double_slam", "double_slam_2":
				lean = Vector3(-18.0 * p, 0, 0)
			"grab":
				lean = Vector3(30.0 * p, 0, 0)
			"charge":
				lean = Vector3(22.0 * p, 0, 0)
	if throw_windup > 0.0:
		# 舉起鐵架：上身後仰，越接近擲出越後仰
		var k: float = 1.0 - throw_windup / _throw_total
		lean = Vector3(-10.0 - 25.0 * k, 0, 0)
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
	# 背上的鐵架：兩根立柱＋三根橫桿＋關節（弱點）；擲出去之後整組藏起來（ThrownFrame 接手）
	var frame := Node3D.new()
	frame.name = "Frame"
	torso.add_child(frame)
	for x: float in [-0.45, 0.45]:
		var post := CSGBox3D.new()
		post.size = Vector3(0.08, 2.2, 0.08)
		post.position = Vector3(x, 1.1, 0.5)
		post.material = iron
		frame.add_child(post)
	for y: float in [0.4, 1.1, 1.9]:
		var bar := CSGBox3D.new()
		bar.size = Vector3(1.1, 0.07, 0.07)
		bar.position = Vector3(0, y, 0.52)
		bar.material = iron
		frame.add_child(bar)
	for side: float in [-1.0, 1.0]:
		var arm := CSGCylinder3D.new()
		arm.radius = 0.12
		arm.height = 1.2
		arm.position = Vector3(side * 0.62, 0.6, -0.15)
		arm.rotation_degrees = Vector3(-20, 0, side * 8.0)
		arm.material = robe
		torso.add_child(arm)
	_build_decals()


## 招式 → 地面霜紋（連續下砸共用下砸的圓、抓取用小扇形）
static func _decal_for(move: String) -> String:
	if move.contains("slam"):
		return "slam"
	return move


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
	_decals["grab"] = _decal(_fan_mesh(brain.move_num("grab", "range", 2.2), brain.move_num("grab", "arc_deg", 90.0)), Vector3(0, 0.03, 0))


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
