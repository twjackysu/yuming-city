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
## 她手上的劍：現成的 CC0 模型（KayKit 的雙手劍，CREDITS）；檔案不在就用程式拼的那一把
const SWORD_MODEL: String = "kaykit/sword_2handed"
## 現成的劍原本長 2.37 m（KayKit 的尺寸比我們大），縮到配 1.65 m 的她
const SWORD_MODEL_SCALE: float = 0.42
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
## 腳步聲（D-184）：跟諾恩同一套（Footsteps），步子短一點、小聲一點——跟在旁邊聽得到她，但不搶諾恩的。
const STRIDE: float = 0.72
const RUN_STRIDE: float = 1.0
const STEP_DB: float = -18.0
const RUN_STEP_DB: float = -14.0
var footsteps: Footsteps = Footsteps.new(STRIDE, RUN_STRIDE, STEP_DB, RUN_STEP_DB)
## 站著的時候的碰撞層。倒下時關掉（D-239）：躺著的身體會把直線走過來的敵人卡住——
## 戰鬥場第 4 波，南街守衛被她擋在 0.9 m 外、100 秒一步都沒動。拉起來再開。
var _standing_layer: int = 1


func _ready() -> void:
	add_to_group("companion")
	add_to_group("interact_prompts")
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
	_standing_layer = collision_layer
	_build()
	CameraFade.apply(self, CameraFade.CHARACTER_NEAR, CameraFade.CHARACTER_FAR)  # D-115


func _physics_process(delta: float) -> void:
	if leader == null or not is_instance_valid(leader):
		leader = _first_in_group("player")
	target = _pick_target()
	if brain.mode == CompanionBrain.Mode.DOWN:
		_down_tick()
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
	# 頭上的喊話＝字幕（D-045：設定關掉字幕時不顯示；對話框與過場字永遠顯示）
	_line.visible = _line_left > 0.0 and Settings.subtitles_enabled


## 下指令（玩家輸入或測試呼叫）。回傳 CompanionBrain.command 的結果，並在頭上顯示回話。
func order(cmd: String) -> Dictionary:
	if target == null or not is_instance_valid(target):
		target = _pick_target()
	if cmd == "guard" and leader != null:
		guard_point = leader.global_position
	brain.near_wounded = _near_wounded()
	var result: Dictionary = brain.command(cmd, _brain_of(target))
	say(str(result.get("line", "")))
	command_answered.emit(cmd, result)
	return result


## 她在傷者車隊旁（3 公尺內）而且目標敵人也靠近車隊（5 公尺內）：閃開會讓攻擊砸到傷者。
func _near_wounded() -> bool:
	var c: Node3D = get_tree().get_first_node_in_group("caravan") as Node3D
	if c == null or target == null or not is_instance_valid(target):
		return false
	return global_position.distance_to(c.global_position) <= 3.0 and target.global_position.distance_to(c.global_position) <= 5.0


func _on_settings_changed() -> void:
	if Settings.difficulty != difficulty:
		difficulty = Settings.difficulty
		brain.command_window = CombatTuning.num("difficulty.%s.command_window" % difficulty, 0.6)


func say(key: String) -> void:
	if key == "":
		return
	_line.text = TranslationServer.translate(key)
	_line_left = LINE_SEC
	_line.visible = Settings.subtitles_enabled


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
		horizontal = _avoid_mist(horizontal)
		if target != null and brain.mode != CompanionBrain.Mode.FOLLOW:
			_face(target, delta)
		elif horizontal.length() > 0.3:
			_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-horizontal.x, -horizontal.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 18.0 * delta
	_puppet.set_move_speed(horizontal.length())
	move_and_slide()
	var real: Vector3 = get_real_velocity()
	var moved: float = Vector2(real.x, real.z).length() * delta
	footsteps.tick(self, moved, horizontal.length() > (WALK_SPEED + RUN_SPEED) * 0.5,
			is_on_floor() and _dodge_left <= 0.0)


## 繞開毒霧（新版，D-207）：她沒有逆轉體質，不走進毒霧；已經在裡面就先出來。場上沒有毒霧時原樣回傳。
func _avoid_mist(move: Vector3) -> Vector3:
	var centers := PackedVector3Array()
	var radii := PackedFloat32Array()
	for n: Node in get_tree().get_nodes_in_group("poison_mist"):
		var m: PoisonMist = n as PoisonMist
		if m != null and m.zone != null and not m.zone.expired():
			centers.append(m.global_position)
			radii.append(m.zone.radius)
	if centers.is_empty():
		return move
	return CompanionBrain.steer_clear(global_position, move, centers, radii)


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


## 目標：諾恩鎖定的敵人優先（02-gameplay：打弱點打「目前鎖定」的敵人），否則離她最近的。
func _pick_target() -> Node3D:
	if leader is PlayerController:
		var locked: Node3D = (leader as PlayerController).lock_target
		if locked != null and is_instance_valid(locked) and _brain_of(locked) != null and _brain_of(locked).state != EnemyBrain.State.DEAD:
			return locked
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


## 倒下中：時間內諾恩走近按互動鍵拉起；超過時間，等附近沒有敵人（戰鬥結束）自己爬起來。
func _down_tick() -> void:
	var near: bool = leader != null and _flat_dist(leader) <= CombatTuning.num("sheila.revive_range", 1.8)
	if brain.can_be_revived():
		# 提示「{key} 拉起席菈」在 HUD 下方中央（interact_hint → InteractPrompt，D-065）
		if near and not Game.is_player_locked():
			if Input.is_action_just_pressed("interact"):
				revive()
	elif not _enemies_near(20.0):
		revive(CombatTuning.num("sheila.after_combat_hp", 0.25))


## 拉起來（生命回到 hp_ratio）。回傳是否真的拉起（沒倒下就不算）。
func revive(hp_ratio: float = -1.0) -> bool:
	if brain.mode != CompanionBrain.Mode.DOWN:
		return false
	if hp_ratio < 0.0:
		hp_ratio = CombatTuning.num("sheila.revive_hp", 0.4)
	health.reset()
	health.hp = health.max_hp * hp_ratio
	brain.set_down(false)
	collision_layer = _standing_layer
	var t := create_tween()
	t.tween_property(_body, "rotation_degrees:z", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	say("SHEILA_REVIVED")
	return true


## 諾恩是否在拉得到她的距離內、而且還來得及（HUD／提示用）。
func revive_prompt_shown() -> bool:
	return brain.can_be_revived() and leader != null and _flat_dist(leader) <= CombatTuning.num("sheila.revive_range", 1.8)


## HUD 的互動提示（InteractPrompt）：倒下、諾恩在旁邊、還來得及 →「{key} 拉起席菈」。
func interact_hint() -> Dictionary:
	if not revive_prompt_shown():
		return {}
	return {"fmt": TranslationServer.translate("SHEILA_REVIVE_HINT"), "action": "interact", "progress": -1.0}


func _enemies_near(radius: float) -> bool:
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e: EnemyActor = n as EnemyActor
		if e != null and e.brain.state != EnemyBrain.State.DEAD and e.global_position.distance_to(global_position) <= radius:
			return true
	return false


func _on_died() -> void:
	brain.set_down(true)
	collision_layer = 0
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
	ContactShadow.attach(self, 0.55, 0.5)  # D-108
	_puppet = Puppet.new()
	_puppet.name = "Puppet"
	_puppet.character_id = "sheila"
	# 白短斗篷、灰藍滾邊（03 美術：席菈是畫面裡最亮的人形）
	_puppet.coat_color = Color(0.74, 0.74, 0.76)
	_puppet.trim_color = Color(0.36, 0.42, 0.5)
	_puppet.skin_color = Color(0.66, 0.55, 0.47)
	_body.add_child(_puppet)
	var hammer: Node = _puppet.hand("R").get_node_or_null("BellHammer")
	if hammer != null:
		hammer.queue_free()
	var sword: Node3D = _build_sword()
	_puppet.hand("R").add_child(sword)  # 模型的手上掛點跟人偶的手同方向、已經在掌心（Puppet._model_joint，D-253），不用另外轉
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


## 寬斷劍：有現成的 CC0 模型（KayKit 的雙手劍，D-256）就用它，沒有才用程式拼的那一把。
## 現成的劍是一個網格一張貼圖（劍身與握把分不開）；斷口之後在 Blender 裡切。
func _build_sword() -> Node3D:
	var sword := Node3D.new()
	sword.name = "BrokenSword"
	var model: Node3D = PropModels.instance(SWORD_MODEL)
	if model != null:
		# 握的位置與方向是在遊戲裡試出來的（劍尖朝下垂在身邊）
		model.name = "Model"
		model.scale = Vector3(SWORD_MODEL_SCALE, SWORD_MODEL_SCALE, SWORD_MODEL_SCALE)
		model.rotation_degrees = Vector3(0, 0, 180)
		model.position = Vector3(0, 0.1, 0)
		sword.add_child(model)
		return sword
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
	# 劍身自己一份材質（燃燒劍只讓劍身燒紅，護手不亮）
	blade_mesh.material = steel.duplicate()
	blade.mesh = blade_mesh
	blade.position = Vector3(0, -0.43, 0)
	blade.rotation_degrees = Vector3(0, 0, 180)
	sword.add_child(blade)
	return sword


## 劇情要她守住某處 seconds 秒（D-054）；line 是頭上的喊話（翻譯 key，可空）。
func hold_guard(point: Vector3, seconds: float, line: String = "") -> void:
	guard_point = Vector3(point.x, global_position.y, point.z)
	brain.hold_guard(seconds)
	if line != "":
		say(line)
