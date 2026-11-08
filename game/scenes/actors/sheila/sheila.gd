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
## 燃燒劍的火色
const FIRE: Color = Color(1.0, 0.5, 0.16)
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
var _blade_mat: StandardMaterial3D
var _fire_light: OmniLight3D
var _fire_sparks: CPUParticles3D
var _fire_left: float = 0.0


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
	_fire_tick(delta)


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
		if near and not Game.is_player_locked():
			_line.text = TranslationServer.translate("SHEILA_REVIVE_HINT").format({"key": InputGlyphs.label_for_action("interact", App.last_device)})
			_line.visible = true
			_line_left = 0.1
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
	var t := create_tween()
	t.tween_property(_body, "rotation_degrees:z", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	say("SHEILA_REVIVED")
	return true


## 諾恩是否在拉得到她的距離內、而且還來得及（HUD／提示用）。
func revive_prompt_shown() -> bool:
	return brain.can_be_revived() and leader != null and _flat_dist(leader) <= CombatTuning.num("sheila.revive_range", 1.8)


func _enemies_near(radius: float) -> bool:
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e: EnemyActor = n as EnemyActor
		if e != null and e.brain.state != EnemyBrain.State.DEAD and e.global_position.distance_to(global_position) <= radius:
			return true
	return false


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
	_puppet.character_id = "sheila"
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
	# 劍身自己一份材質（燃燒劍只讓劍身燒紅，護手不亮）
	blade_mesh.material = steel.duplicate()
	blade.mesh = blade_mesh
	blade.position = Vector3(0, -0.43, 0)
	blade.rotation_degrees = Vector3(0, 0, 180)
	sword.add_child(blade)
	# 燃燒劍（平常熄著）：劍身燒紅、橘色火光、沿劍身往上飄的火星
	_blade_mat = blade_mesh.material as StandardMaterial3D
	_fire_light = OmniLight3D.new()
	_fire_light.name = "FireLight"
	_fire_light.light_color = FIRE
	_fire_light.light_energy = 0.0
	_fire_light.omni_range = 5.0
	_fire_light.position = Vector3(0, -0.45, 0)
	_fire_light.visible = false
	sword.add_child(_fire_light)
	_fire_sparks = CPUParticles3D.new()
	_fire_sparks.name = "FireSparks"
	_fire_sparks.emitting = false
	_fire_sparks.amount = 36
	_fire_sparks.lifetime = 0.7
	_fire_sparks.position = Vector3(0, -0.45, 0)
	_fire_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fire_sparks.emission_box_extents = Vector3(0.04, 0.3, 0.01)
	_fire_sparks.direction = Vector3.UP
	_fire_sparks.spread = 25.0
	_fire_sparks.gravity = Vector3(0, 2.5, 0)
	_fire_sparks.initial_velocity_min = 0.3
	_fire_sparks.initial_velocity_max = 1.2
	_fire_sparks.local_coords = false
	var spark := QuadMesh.new()
	spark.size = Vector2(0.035, 0.035)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.albedo_color = Color(1.0, 0.62, 0.25)
	spark.material = spark_mat
	_fire_sparks.mesh = spark
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 0.3, 0.1, 0))
	_fire_sparks.color_ramp = ramp
	sword.add_child(_fire_sparks)
	return sword


## 燃燒劍（D-042）：劍身燒紅、劍上有火光與火星，seconds 秒後熄掉（再點一次就延長）。
## 只是畫面與音效；手傷由 FrameThrowEvent／ConvoyEncounter 記。
func ignite_sword(seconds: float = 1.8) -> void:
	if _fire_left <= 0.0 and is_inside_tree():
		Sfx.play_at(self, "ignite", global_position + Vector3.UP * 1.2, -2.0, 0.03, 8.0)
	_fire_left = maxf(_fire_left, seconds)
	_set_fire(true)


func is_sword_lit() -> bool:
	return _fire_left > 0.0


## 短距離衝刺到某一點（送葬者擲鐵架時她離車隊太遠，先一步衝到車隊前，D-053）。
const DASH_SEC: float = 0.18
var dash_target: Vector3 = Vector3.INF


func dash_to_point(p: Vector3) -> void:
	var d: Vector3 = p - global_position
	d.y = 0.0
	if d.length() < 0.2:
		return
	dash_target = Vector3(p.x, global_position.y, p.z)
	_body.rotation.y = atan2(-d.x, -d.z)
	if is_inside_tree():
		Sfx.play_at(self, "whoosh", global_position + Vector3.UP, -3.0)
	var t := create_tween()
	t.tween_property(self, "global_position", dash_target, DASH_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 燃燒劍斬向某一點（鐵架、送葬者）：轉過去、出劍、劍燒起來。
func burn_strike(at: Vector3, seconds: float = 1.8) -> void:
	var d: Vector3 = at - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		_body.rotation.y = atan2(-d.x, -d.z)
	_puppet.play_action("attack")
	ignite_sword(seconds)
	if is_inside_tree():
		Sfx.play_at(self, "slash", global_position + Vector3.UP, 0.0)


func _fire_tick(delta: float) -> void:
	if _fire_left <= 0.0:
		return
	_fire_left = maxf(_fire_left - delta, 0.0)
	# 火光閃爍；最後 0.4 秒慢慢熄
	var fade: float = clampf(_fire_left / 0.4, 0.0, 1.0)
	_fire_light.light_energy = (2.2 + 0.5 * sin(Time.get_ticks_msec() * 0.031)) * fade
	if _fire_left <= 0.0:
		_set_fire(false)


func _set_fire(on: bool) -> void:
	if _blade_mat == null:
		return
	_blade_mat.emission_enabled = on
	_blade_mat.emission = FIRE
	_blade_mat.emission_energy_multiplier = 2.5 if on else 0.0
	_fire_light.visible = on
	_fire_light.light_energy = 2.2 if on else 0.0
	_fire_sparks.emitting = on
