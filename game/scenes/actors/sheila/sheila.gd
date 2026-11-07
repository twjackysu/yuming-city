class_name Sheila
extends CharacterBody3D
## 席菈：同伴。邏輯在 CompanionBrain；這裡負責找目標、移動、執行動作（斬擊／打弱點／閃開反擊）與頭上回話。
## 指令輸入（command_weakpoint／command_evade／command_guard）由她自己讀，對話或過場中不接受。
## 外觀是程序人偶換配色（白短斗篷、寬斷劍），介面與諾恩相同，之後換正式模型（ART_REQUESTS 第 2 項）。

const WALK_SPEED: float = 3.6
const RUN_SPEED: float = 5.6
const TURN_SPEED: float = 10.0
const DODGE_SPEED: float = 6.5
const LINE_SEC: float = 1.6
const COMMAND_ACTIONS: Dictionary = {
	"command_weakpoint": "weakpoint",
	"command_evade": "evade",
	"command_guard": "guard",
}

signal command_answered(cmd: String, result: Dictionary)

var brain: CompanionBrain
var health: Health
var leader: Node3D
var target: Node3D
## 守住的位置（下「守住」時記下諾恩當時的位置）
var guard_point: Vector3 = Vector3.ZERO
## 空字串＝用設定裡的難度（指令時機窗、被反擊的傷害）；設定改了即時套用
var difficulty: String = ""

var _body: Node3D
var _puppet: Puppet
var _line: Label3D
var _line_left: float = 0.0
var _dodge_left: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("companion")
	add_to_group("heartbeat")
	if difficulty == "":
		difficulty = Settings.difficulty
		Settings.changed.connect(_on_settings_changed)
	brain = CompanionBrain.new().configure(difficulty)
	health = Health.new(CombatTuning.num("sheila.max_hp", 160.0))
	health.name = "Health"
	health.invulnerable_check = brain.is_invulnerable
	health.died.connect(_on_died)
	add_child(health)
	_build()


func _physics_process(delta: float) -> void:
	if leader == null or not is_instance_valid(leader):
		leader = _first_in_group("player")
	target = _pick_target()
	if not Game.is_player_locked():
		for action: String in COMMAND_ACTIONS:
			if Input.is_action_just_pressed(action):
				order(str(COMMAND_ACTIONS[action]))
	var leader_dist: float = _flat_dist(leader)
	var target_dist: float = _flat_dist(target)
	var target_brain: EnemyBrain = _brain_of(target)
	for act: String in brain.tick(delta, leader_dist, target_brain, target_dist):
		_perform(act)
	_move(delta, leader_dist, target_dist)
	_line_left = maxf(_line_left - delta, 0.0)
	_line.visible = _line_left > 0.0


## 下指令（玩家輸入或測試呼叫）。回傳 CompanionBrain.command 的結果，並在頭上顯示回話。
func order(cmd: String) -> Dictionary:
	if target == null or not is_instance_valid(target):
		target = _pick_target()
	if cmd == "guard" and leader != null:
		guard_point = leader.global_position
	var result: Dictionary = brain.command(cmd, _brain_of(target))
	say(str(result.get("line", "")))
	command_answered.emit(cmd, result)
	return result


func _on_settings_changed() -> void:
	if Settings.difficulty != difficulty:
		difficulty = Settings.difficulty
		brain.command_window = CombatTuning.num("difficulty.%s.command_window" % difficulty, 0.6)


func say(key: String) -> void:
	if key == "":
		return
	_line.text = TranslationServer.translate(key)
	_line_left = LINE_SEC
	_line.visible = true


func line_text() -> String:
	return _line.text if _line_left > 0.0 else ""


func puppet() -> Puppet:
	return _puppet


func _perform(act: String) -> void:
	var h: Health = target.get_node_or_null("Health") as Health if target != null else null
	if act in [CompanionBrain.ACT_SLASH, CompanionBrain.ACT_WEAK_STRIKE, CompanionBrain.ACT_COUNTER, CompanionBrain.ACT_COUNTERED]:
		Sfx.play_at(self, "slash", global_position + Vector3.UP, -3.0)
	elif act == CompanionBrain.ACT_DODGE:
		Sfx.play_at(self, "whoosh", global_position + Vector3.UP, -6.0)
	match act:
		CompanionBrain.ACT_SLASH:
			_face(target)
			_puppet.play_action("attack")
			if h != null and _flat_dist(target) <= brain.slash_range + 0.3:
				h.apply_damage(CombatTuning.num("sheila.slash_damage", 18.0), {"source": self, "stagger": CombatTuning.num("sheila.slash_stagger", 15.0), "kind": "slash"})
		CompanionBrain.ACT_WEAK_STRIKE:
			_dash_to(target)
			_puppet.play_action("attack")
			if h != null:
				var weak: String = _first_weakpoint(target)
				h.apply_damage(CombatTuning.num("sheila.weak_damage", 60.0), {"source": self, "stagger": 999.0, "kind": "slash", "weak": weak})
				Game.hit_stop(CombatTuning.num("feel.hit_stop_weak", 0.09))
		CompanionBrain.ACT_COUNTERED:
			_dash_to(target)
			_puppet.play_action("attack")
			var dmg: float = CombatTuning.num("sheila.countered_damage", 14.0) * CombatTuning.num("difficulty.%s.enemy_damage" % difficulty, 1.0)
			health.apply_damage(dmg, {"source": target, "kind": "counter"})
		CompanionBrain.ACT_DODGE:
			_puppet.play_action("dodge")
			# 「右轉」：往目標的右手邊閃
			var away: Vector3 = Vector3.FORWARD
			if target != null:
				var to_t: Vector3 = target.global_position - global_position
				to_t.y = 0.0
				if to_t.length() > 0.01:
					away = to_t.normalized().cross(Vector3.UP)
			_dodge_dir = away
			_dodge_left = 0.3
		CompanionBrain.ACT_COUNTER:
			_face(target)
			_puppet.play_action("attack")
			if h != null:
				h.apply_damage(CombatTuning.num("sheila.counter_damage", 27.0), {"source": self, "stagger": CombatTuning.num("sheila.counter_stagger", 30.0), "kind": "slash"})


func _move(delta: float, leader_dist: float, target_dist: float) -> void:
	var horizontal := Vector3.ZERO
	if _dodge_left > 0.0:
		_dodge_left -= delta
		horizontal = _dodge_dir * DODGE_SPEED
	else:
		var goal: Vector3 = global_position
		var speed: float = WALK_SPEED
		match brain.desired_move(leader_dist, target_dist):
			CompanionBrain.Move.TO_LEADER:
				goal = leader.global_position
				speed = RUN_SPEED if leader_dist > brain.follow_dist * 2.0 else WALK_SPEED
			CompanionBrain.Move.TO_TARGET:
				goal = target.global_position
				speed = RUN_SPEED
			CompanionBrain.Move.TO_GUARD:
				goal = guard_point
		var d: Vector3 = goal - global_position
		d.y = 0.0
		if d.length() > 0.3:
			horizontal = d.normalized() * speed
		if target != null and brain.mode != CompanionBrain.Mode.FOLLOW:
			_face(target, delta)
		elif horizontal.length() > 0.3:
			_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-horizontal.x, -horizontal.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 18.0 * delta
	_puppet.set_move_speed(horizontal.length())
	move_and_slide()


func _face(n: Node3D, delta: float = -1.0) -> void:
	if n == null:
		return
	var d: Vector3 = n.global_position - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	var face: float = atan2(-d.x, -d.z)
	_body.rotation.y = face if delta < 0.0 else lerp_angle(_body.rotation.y, face, clampf(TURN_SPEED * delta, 0.0, 1.0))


## 打弱點：一步踏到目標身邊（演出用的短位移，不穿過目標）。
func _dash_to(n: Node3D) -> void:
	if n == null:
		return
	var d: Vector3 = n.global_position - global_position
	d.y = 0.0
	if d.length() > brain.slash_range:
		global_position += d.normalized() * (d.length() - brain.slash_range * 0.8)
	_face(n)


func _pick_target() -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e: Node3D = n as Node3D
		var b: EnemyBrain = _brain_of(e)
		if e == null or b == null or b.state == EnemyBrain.State.DEAD:
			continue
		var d: float = _flat_dist(e)
		if d < best_d:
			best_d = d
			best = e
	return best


func _brain_of(n: Node3D) -> EnemyBrain:
	if n == null or not is_instance_valid(n):
		return null
	var b: Variant = n.get("brain")
	return b as EnemyBrain if b is EnemyBrain else null


func _first_weakpoint(n: Node3D) -> String:
	if not n.has_method("intel_id"):
		return ""
	var ws: Array[Dictionary] = EnemyIntel.weakpoints(str(n.call("intel_id")))
	return str(ws[0].get("id", "")) if not ws.is_empty() else ""


func _flat_dist(n: Node3D) -> float:
	if n == null or not is_instance_valid(n):
		return 999.0
	var d: Vector3 = n.global_position - global_position
	return Vector2(d.x, d.z).length()


func _first_in_group(group: String) -> Node3D:
	for n: Node in get_tree().get_nodes_in_group(group):
		return n as Node3D
	return null


func _on_died() -> void:
	brain.set_down(true)
	_puppet.set_move_speed(0.0)
	var t := create_tween()
	t.tween_property(_body, "rotation_degrees:z", 80.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _build() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	shape.shape = cap
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_puppet = Puppet.new()
	_puppet.name = "Puppet"
	# 白短斗篷、灰藍滾邊（03 美術：席菈是畫面裡最亮的人形）
	_puppet.coat_color = Color(0.74, 0.74, 0.76)
	_puppet.trim_color = Color(0.36, 0.42, 0.5)
	_puppet.skin_color = Color(0.66, 0.55, 0.47)
	_body.add_child(_puppet)
	var hammer: Node = _puppet.hand("R").get_node_or_null("BellHammer")
	if hammer != null:
		hammer.queue_free()
	_puppet.hand("R").add_child(_build_sword())
	_line = Label3D.new()
	_line.name = "Line"
	_line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_line.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_line.no_depth_test = true
	_line.fixed_size = true
	_line.pixel_size = 0.0009
	_line.font_size = 32
	_line.outline_size = 10
	_line.modulate = Color(1.0, 0.93, 0.82)
	_line.outline_modulate = Color(0.05, 0.03, 0.02, 0.85)
	_line.position = Vector3(0, 2.15, 0)
	var f: Font = UiFonts.load_font(UiFonts.UI_SANS)
	if f != null:
		_line.font = f
	_line.visible = false
	add_child(_line)


## 寬斷劍：劍身在三分之二處斷掉，斷口斜切。
func _build_sword() -> Node3D:
	var sword := Node3D.new()
	sword.name = "BrokenSword"
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.57, 0.6)
	steel.metallic = 0.8
	steel.roughness = 0.35
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.2, 0.14, 0.1)
	var grip := MeshInstance3D.new()
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.022
	grip_mesh.bottom_radius = 0.022
	grip_mesh.height = 0.2
	grip_mesh.material = grip_mat
	grip.mesh = grip_mesh
	sword.add_child(grip)
	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.2, 0.03, 0.05)
	guard_mesh.material = steel
	guard.mesh = guard_mesh
	guard.position = Vector3(0, -0.11, 0)
	sword.add_child(guard)
	var blade := MeshInstance3D.new()
	var blade_mesh := PrismMesh.new()
	blade_mesh.left_to_right = 0.0
	blade_mesh.size = Vector3(0.11, 0.62, 0.02)
	blade_mesh.material = steel
	blade.mesh = blade_mesh
	blade.position = Vector3(0, -0.43, 0)
	blade.rotation_degrees = Vector3(0, 0, 180)
	sword.add_child(blade)
	return sword
