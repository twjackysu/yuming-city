class_name PlayerController
extends CharacterBody3D
## 諾恩：第三人稱移動＋越肩鏡頭（docs/design/02-gameplay.md「鏡頭」）。
## 鏡頭架（CameraRig）設 top_level，自己跟隨玩家，避免角色轉身時鏡頭跟著甩。

const WALK_SPEED: float = 3.4
const SPRINT_SPEED: float = 5.8
const ACCEL: float = 12.0
const TURN_SPEED: float = 10.0
const GRAVITY: float = 18.0
const DODGE_SPEED: float = 8.5
const DODGE_TIME: float = 0.35
const DODGE_INVULN: float = 0.25
const DODGE_COOLDOWN: float = 0.2
const MOUSE_SENS: float = 0.0025
const PAD_LOOK_SPEED: float = 2.8
const PAD_DEADZONE: float = 0.15
const PITCH_MIN: float = deg_to_rad(-55.0)
const PITCH_MAX: float = deg_to_rad(40.0)
const CAMERA_HEIGHT: float = 1.6
const FOV_WALK: float = 70.0
const FOV_SPRINT: float = 75.0
## 鎖定（02-gameplay「鏡頭」）：15 公尺外自動解除；挑鏡頭前方 70° 內最近的敵人
const LOCK_RANGE: float = 15.0
const LOCK_CONE_DEG: float = 70.0
const LOCK_PITCH: float = -0.28
## 鎖定目標被牆擋住超過這麼久就解除
const LOCK_BLOCKED_SEC: float = 1.5
## 鎖定中右搖桿／滑鼠往左右甩：換目標
const LOCK_FLICK_PAD: float = 0.75
const LOCK_FLICK_MOUSE: float = 0.12
## 鏡頭距離：探索 3.2 m，戰鬥中（20 公尺內有敵人、未鎖定）拉遠到 4.2 m
const CAMERA_DIST: float = 3.2
const CAMERA_DIST_COMBAT: float = 4.2
const COMBAT_RANGE: float = 20.0
## 過肩偏移：鏡頭在諾恩右後方，諾恩落在畫面左側、街景留在中間。
## 戰鬥中／鎖定時再往右放大一點：鏡頭的視線跟諾恩面對的方向平行，站在他正前方的敵人在畫面上
## 只比他偏右「偏移 ×（1 − 鏡頭到他的距離 ÷ 鏡頭到敵人的距離）」——0.55 m 時敵人的身體中線整個在諾恩背後
## （被打中後仰、變紅都看不到）；1.05 m 時貼身 1.2 m 的敵人中線也露在他右肩外面。
## 右邊有牆時沿著肩膀那條射線收回，不會穿牆。
const SHOULDER_OFFSET: float = 0.85
const SHOULDER_OFFSET_COMBAT: float = 1.05
## 肩膀那條射線離牆至少留這麼多（鏡頭近平面＋SpringArm 的 margin）
const SHOULDER_MARGIN: float = 0.35
## 只擋鏡頭的碰撞層：牆面上沒有碰撞的裝飾（櫥窗裡的瓶子、窗台、門邊的燈）前面放一片只在這一層的牆，
## 鏡頭的 SpringArm 與肩膀的射線會被它擋住，人、敵人、鎖定的視線都不會（他們只看第 1 層）。
const CAMERA_WALL_LAYER: int = 2
## 放回去的速度（m/s）；收回是立即的（被牆擋住時不能慢慢穿過去）
const SHOULDER_EASE: float = 1.6

var yaw: float = 0.0
var pitch: float = -0.18
var invulnerable: bool = false
## 上一次揮擊打中弱點的數量（測試與音效用）
var last_weak_hits: int = 0
## 出手打中人時給自己的狀態來源（data/reboot/statuses.json 的 sources；空的＝沒有）。戴上護腕時劇情設成 "bracer_hit"
var on_hit_source: String = ""
## 這樣給過幾次（測試用）
var on_hit_applied: int = 0
## 目前鎖定的敵人（null＝沒鎖定）；席菈的「打弱點」也打這個
var lock_target: Node3D = null
var lock_blocked: float = 0.0
var _flick_acc: float = 0.0
var _pad_flick_armed: bool = true
var _lock_marker: MeshInstance3D

## 目前的過肩偏移（SpringArm 的 x，m）
var _shoulder: float = SHOULDER_OFFSET
var _dodge_left: float = 0.0
var _dodge_cooldown: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO

@onready var _rig: Node3D = $CameraRig
@onready var _pitch_node: Node3D = $CameraRig/Pitch
@onready var _arm: SpringArm3D = $CameraRig/Pitch/SpringArm3D
@onready var _camera: Camera3D = $CameraRig/Pitch/SpringArm3D/Camera3D
@onready var _body: Node3D = $Body
## 諾恩的武器【瘴氣生鏽鐵劍】（docs/story/chapter-1.md）：Tripo 的模型，建置時由 scripts/gen_props.sh 擺成
## 跟 KayKit 雙手劍一樣的大小與原點；Tripo 的檔不在就退回 KayKit 那把（在 git 裡）。握在右手、劍尖朝下垂在身邊。
const SWORD_MODELS: Array[String] = ["tripo/weapon_rusty_miasma_sword", "tripo/weapon_longsword", "kaykit/sword_2handed"]
const SWORD_SCALE: float = 0.42
const SWORD_GRIP: Vector3 = Vector3(0.0, 0.1, 0.0)

var _puppet: Puppet
var _weapon: Node3D
## 生命（數值在 data/combat/tuning.json 的 noen）；閃避無敵期間不扣血
var health: Health
## 新版（劇情重寫）：身上的持續狀態與反轉欄位。舊版流程沒有任何來源會上狀態，所以不影響舊版。
var reversal: ReversalSlots = ReversalSlots.new()
var status_effects: StatusEffects
## 回血的畫面回饋：回血期間身邊往上飄的綠色光點、喝藥那一下的一小團
var heal_fx: HealMotes
## 可攜藥劑滿血時要先問（PotionBelt 回傳 confirm_full）：UI 接這個訊號跳「還是要喝嗎？」
signal potion_needs_confirm(item_id: String)
## 釋放：把身上反轉中的中毒一次用掉＝毒爆。info：{"seconds" 用掉幾秒, "damage" 每個人扣多少, "hits" 炸到幾個, "kills" 炸倒幾個}
signal released(info: Dictionary)
const RELEASE_STATUS: String = "poison"
const RELEASE_SFX: String = "poison_burst"
const RELEASE_DB: float = -1.0
## 放了幾次、最後一次的結果、最後一次的特效（測試、機器人的統計、截圖用）
var release_count: int = 0
var last_release: Dictionary = {}
var last_release_fx: PoisonBurst
## 讀檔／死亡重試：生命照檢查點存的，但至少這個比例（09 第 3 節）
const RESTORE_MIN_HP_RATIO: float = 0.5
## 新版可攜藥劑（快捷鍵 use_item）
const PORTABLE_ITEM: String = "sera_poison_vial"
var _swing_resolved: bool = true
## 出手往前滑一小步（noen.lunge_dist，0＝不滑）：還剩多遠沒滑、往哪邊、這一次有沒有對準某個敵人
var _lunge_left: float = 0.0
var _lunge_dir: Vector3 = Vector3.ZERO
var _lunge_target: Node3D
## 滑過幾公尺（測試用）
var lunge_moved: float = 0.0
var _death_tween: Tween
## 挨打的硬直：被直接打中（不是狀態扣血）的那一下，出到一半的招沒了、`noen.hurt_stun` 秒內不能出手也不能閃、
## 被往打他的人的反方向推 `noen.hurt_push` 公尺、上半身往後仰一下。0＝沒有（劇情那 20 分鐘；戰鬥場在 profiles.arena 打開）。
## 沒有這個的話，挨打除了扣血沒有任何代價：站在原地一直按出手，被打中的同一瞬間還在打人。
const HURT_LEAN_DEG: float = 13.0
var hurt_left: float = 0.0
## 這一輩子進過幾次硬直（測試與統計用）
var hurt_count: int = 0
var _hurt_dir: Vector3 = Vector3.ZERO
var _hurt_speed: float = 0.0
var _hurt_tween: Tween
## 提早按也算（`noen.input_buffer` 秒，0＝不記＝劇情那 20 分鐘）：收招、閃避、挨打硬直還沒結束的時候按出手或閃避，
## 記住這麼久，能動的第一幀就出；後按的蓋掉先按的。沒有這個的話，這些時候按的鍵全部被吃掉
## （第 96 輪量到：收招時按的出手、閃到一半按的出手、硬直快結束時按的閃避，三種都沒有反應）。
var _buffered: String = ""
var _buffer_left: float = 0.0
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rig.top_level = true
	add_to_group("player")
	add_to_group("heartbeat")
	_puppet = Puppet.new()
	_puppet.name = "Puppet"
	_puppet.character_id = "noen"
	_body.add_child(_puppet)
	ContactShadow.attach(self, 0.55, 0.5)
	_build_weapon()
	_arm.add_excluded_object(get_rid())
	_arm.collision_mask |= CAMERA_WALL_LAYER
	# 角色（席菈、敵人）不推鏡頭：SpringArm 只撞場景，跟 shoulder_room 同一個規則。
	# 之後才生成的角色（送葬者、席菈登場）靠 node_added 補上；用方法連線，玩家釋放時自動斷開
	get_tree().node_added.connect(_on_node_added_for_camera)
	for n: Node in get_tree().root.find_children("*", "CharacterBody3D", true, false):
		_exclude_from_camera(n)
	for n: Node in get_tree().root.find_children("*", "RigidBody3D", true, false):
		_exclude_from_camera(n)
	health = Health.new(CombatTuning.num("noen.max_hp", 100.0))
	health.name = "Health"
	health.invulnerable_check = is_invulnerable
	health.died.connect(_on_died)
	health.damaged.connect(_on_hurt)
	add_child(health)
	status_effects = StatusEffects.new(StatusRules.load_default(), reversal)
	heal_fx = HealMotes.attach(self, health)
	if Game.session.in_story():
		_restore_vitals(Game.session.state)
		# 用方法連線：玩家被釋放時自動斷開
		Game.session.saving.connect(_write_vitals)
	yaw = rotation.y
	snap_camera()
	_camera.current = true
	_build_lock_marker()


## 把輸入（x=左右，y=前後，前為負）依鏡頭水平角度轉成世界方向。純函式，方便測試。
static func move_direction(input: Vector2, camera_yaw: float) -> Vector3:
	var dir := Basis(Vector3.UP, camera_yaw) * Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_add_look(Vector2(-motion.relative.x, -motion.relative.y) * MOUSE_SENS, true)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func puppet() -> Puppet:
	return _puppet


func _add_look(delta_look: Vector2, from_mouse: bool = false) -> void:
	if lock_target != null:
		if from_mouse:
			_flick_acc += delta_look.x
			if absf(_flick_acc) >= LOCK_FLICK_MOUSE:
				# 滑鼠往右甩＝yaw 變小（delta 為負）
				switch_lock(1 if _flick_acc < 0.0 else -1)
				_flick_acc = 0.0
		delta_look.x = 0.0  # 鎖定中水平方向由目標決定
	yaw = wrapf(yaw + delta_look.x, -PI, PI)
	pitch = clampf(pitch + delta_look.y, PITCH_MIN, PITCH_MAX)


func _physics_process(delta: float) -> void:
	var pad := Vector2(Input.get_joy_axis(App.last_pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(App.last_pad, JOY_AXIS_RIGHT_Y))
	if lock_target != null:
		if _pad_flick_armed and absf(pad.x) >= LOCK_FLICK_PAD:
			switch_lock(1 if pad.x > 0.0 else -1)
			_pad_flick_armed = false
		elif absf(pad.x) < 0.3:
			_pad_flick_armed = true
	_flick_acc *= 0.8
	if pad.length() > PAD_DEADZONE:
		_add_look(-pad * PAD_LOOK_SPEED * delta)
	_update_camera_distance(delta)
	# 狀態只在遊戲時間推進時計時：暫停時整個 physics 停、對話與過場中不推進
	# 戰鬥場的兩個數字：站在霧裡越站越多秒、留著毒的回血打幾折。劇情是 0 與 1＝照舊
	status_effects.refresh_gain = CombatTuning.num("noen.status_refresh_gain", 0.0)
	status_effects.reversed_scale = CombatTuning.num("noen.reversed_heal_scale", 1.0)
	if not Game.is_player_locked():
		status_effects.tick(delta, health)
	# 麻痺被反轉＝出手變快（只有出手，不是整個人變快）；沒反轉的麻痺＝這段時間不能出手
	_puppet.attack_speed = status_effects.attack_speed()
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var talking: bool = Game.is_player_locked()
	if talking:
		input = Vector2.ZERO
	var dir: Vector3 = move_direction(input, yaw)
	var sprinting: bool = Input.is_action_pressed("sprint") and input.length() > 0.1

	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	if not talking and Game.session.in_story() and Input.is_action_just_pressed("use_item") and not health.is_dead():
		use_potion()
	var want: String = _wanted_action(delta, talking)
	if talking:
		pass
	elif hurt_left > 0.0:
		# 挨打的硬直：不能出手、不能閃
		pass
	elif want == "dodge" and _dodge_left <= 0.0 and _dodge_cooldown <= 0.0:
		_buffered = ""
		_dodge_dir = dir if dir.length() > 0.1 else -_body.global_basis.z
		_dodge_dir = _dodge_dir.normalized()
		_dodge_left = DODGE_TIME
		_puppet.play_action("dodge")
		Sfx.play_at(self, "whoosh", global_position + Vector3.UP, -4.0)
	elif want == "release":
		# 釋放不用等收招、閃到一半也能放（只有挨打的硬直中不行）；身上沒有能放的＝這一下沒有作用
		_buffered = ""
		release()
	elif want == "attack" and _puppet.action == "" and not health.is_dead() and not status_effects.blocks_attack():
		_buffered = ""
		start_attack()
	if not talking and Input.is_action_just_pressed("lock_on"):
		toggle_lock()
	_update_lock(delta)
	_update_swing()

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	# 挨打被推開的那一步跟出手的滑步一樣：疊在上面、不算「自己在走」。
	# 以前把它當成走路的速度：「往哪走就面向哪」連被推開也算，挨一下整個人就轉過去背對打他的人、臉朝鏡頭，
	# 硬直結束後殘留的速度還會再轉幾幀（Jacky 11/13：「向前面向後面」）。
	var push := Vector3.ZERO
	if hurt_left > 0.0:
		hurt_left -= delta
		push = _hurt_dir * _hurt_speed
		horizontal = Vector3.ZERO
	elif _dodge_left > 0.0:
		_dodge_left -= delta
		invulnerable = _dodge_left > DODGE_TIME - DODGE_INVULN
		horizontal = _dodge_dir * DODGE_SPEED
		if _dodge_left <= 0.0:
			_dodge_cooldown = DODGE_COOLDOWN
			invulnerable = false
	else:
		var target: Vector3 = dir * (SPRINT_SPEED if sprinting else WALK_SPEED)
		horizontal = horizontal.lerp(target, clampf(ACCEL * delta, 0.0, 1.0))
	# 出手的那一小步疊在走路上面，但不記進下一幀的速度（不然滑完還會往前溜）
	var lunge: Vector3 = _lunge_velocity(delta) if _dodge_left <= 0.0 else Vector3.ZERO

	velocity.x = horizontal.x + lunge.x + push.x
	velocity.z = horizontal.z + lunge.z + push.z
	_puppet.set_move_speed(horizontal.length())
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if lunge != Vector3.ZERO or push != Vector3.ZERO:
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	footstep_tick(horizontal.length() * delta, sprinting, is_on_floor() and _dodge_left <= 0.0)

	if lock_target != null and _dodge_left <= 0.0 and not sprinting:
		var to_t: Vector3 = lock_target.global_position - global_position
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-to_t.x, -to_t.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	elif swing_holds_facing():
		# 出手到判定之前對著這一下瞄的人，不跟著走路的方向轉
		var to_s: Vector3 = _lunge_target.global_position - global_position
		if Vector2(to_s.x, to_s.z).length() > 0.05:
			_body.rotation.y = atan2(-to_s.x, -to_s.z)
	elif horizontal.length() > 0.3:
		var face: float = atan2(-horizontal.x, -horizontal.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, face, clampf(TURN_SPEED * delta, 0.0, 1.0))

	var fov_target: float = FOV_SPRINT if sprinting else FOV_WALK
	_camera.fov = lerpf(_camera.fov, fov_target, clampf(4.0 * delta, 0.0, 1.0))
	_follow_rig(delta)


## 腳步聲：每走 STRIDE 公尺（跑步 SPRINT_STRIDE）踏一步，聲音照關卡的地面
## （關卡的 `footstep_surface(位置)`：雪、石、木；沒有就當石頭）。閃避、騰空時不算步。邏輯在 Footsteps（席菈共用）。
const STRIDE: float = 0.8
const SPRINT_STRIDE: float = 1.1
const STEP_DB: float = -13.0
const SPRINT_STEP_DB: float = -9.0
const STEP_SURFACES: PackedStringArray = Footsteps.SURFACES
var footsteps: Footsteps = Footsteps.new(STRIDE, SPRINT_STRIDE, STEP_DB, SPRINT_STEP_DB)
var step_count: int:
	get:
		return footsteps.count
var last_step_surface: String:
	get:
		return footsteps.last_surface


## 回傳這一幀有沒有踏一步。
func footstep_tick(moved: float, sprinting: bool, grounded: bool) -> bool:
	return footsteps.tick(self, moved, sprinting, grounded)


func footstep_surface() -> String:
	return Footsteps.surface_at(self)


## 新版：喝可攜藥劑。回傳 PotionBelt.use 的結果；滿血時發 potion_needs_confirm（confirmed=true 再喝一次）。
func use_potion(confirmed: bool = false) -> String:
	var result: String = PotionBelt.new(Game.session.state).use(PORTABLE_ITEM, status_effects, health, confirmed)
	match result:
		"used":
			Sfx.play_at(self, "glass_clink", global_position + Vector3.UP * 1.3, -7.0)
			if heal_fx != null:
				heal_fx.burst()
		"confirm_full":
			potion_needs_confirm.emit(PORTABLE_ITEM)
	return result


## 讀檔、死亡重試時從存檔拿回生命、狀態、反轉欄位（不補滿、不清掉負面狀態；生命至少一半）
func _restore_vitals(st: GameState) -> void:
	reversal = ReversalSlots.from_dict(st.reversal)
	status_effects.reversal = reversal
	status_effects.load_array(st.statuses)
	health.hp = restored_hp(st.vitals.get("hp", null), health.max_hp)


static func restored_hp(saved: Variant, max_hp: float) -> float:
	if not (saved is float or saved is int):
		return max_hp
	return clampf(float(saved), max_hp * RESTORE_MIN_HP_RATIO, max_hp)


func _write_vitals(st: GameState) -> void:
	st.vitals["hp"] = health.hp
	st.statuses = status_effects.to_array()
	st.reversal = reversal.to_dict()


## 被直接打中。狀態扣血（中毒）不走這裡。死的那一下不算（倒下的動作接手）。
func _on_hurt(_amount: float, info: Dictionary) -> void:
	var stun: float = CombatTuning.num("noen.hurt_stun", 0.0)
	if stun <= 0.0 or health.is_dead():
		return
	hurt_left = stun
	hurt_count += 1
	# 出到一半的招沒了：還沒判定的那一下不會打出去
	if _puppet.action == "attack":
		_puppet.action = ""
		_puppet.action_time = 0.0
	_swing_resolved = true
	_lunge_left = 0.0
	var src: Node3D = info.get("source") as Node3D
	var away: Vector3 = global_position - src.global_position if src != null and is_instance_valid(src) else _body.global_basis.z
	away.y = 0.0
	_hurt_dir = away.normalized() if away.length() > 0.01 else _body.global_basis.z
	_hurt_speed = CombatTuning.num("noen.hurt_push", 0.0) / stun
	if _hurt_tween != null:
		_hurt_tween.kill()
	# 往被推的方向仰（身體不轉）：正面挨打往後仰、背後挨打往前撲、側面挨打往旁邊倒
	var lean: Vector2 = hurt_lean(_body.global_rotation.y, _hurt_dir)
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(_body, "rotation_degrees:x", lean.x, stun * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hurt_tween.parallel().tween_property(_body, "rotation_degrees:z", lean.y, stun * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hurt_tween.tween_property(_body, "rotation_degrees:x", 0.0, stun * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hurt_tween.parallel().tween_property(_body, "rotation_degrees:z", 0.0, stun * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 挨打時身體往哪邊仰（度；x＝繞自己的 X 軸、y＝繞自己的 Z 軸）。body_yaw＝身體的水平角度，push＝被推的方向（世界座標）。
## 身體的正面是 −Z：被往背後（+Z）推＝繞 X 正轉＝往後仰；被往右（+X）推＝繞 Z 負轉＝往右倒。純函式，方便測試。
static func hurt_lean(body_yaw: float, push: Vector3) -> Vector2:
	var local: Vector3 = Basis(Vector3.UP, body_yaw).inverse() * push
	local.y = 0.0
	if local.length() < 0.001:
		return Vector2(HURT_LEAN_DEG, 0.0)
	local = local.normalized()
	return Vector2(local.z, -local.x) * HURT_LEAN_DEG


func _on_died() -> void:
	if _hurt_tween != null:
		_hurt_tween.kill()
		_hurt_tween = null
	hurt_left = 0.0
	_body.rotation_degrees.z = 0.0
	var t := create_tween()
	_death_tween = t
	t.tween_property(_body, "rotation_degrees:x", -85.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Game.on_player_died()


## 原地站起來（戰鬥場倒下重來、每一波開始）：生命補滿、身上的狀態清掉、動作歸零。反轉欄位與身上戴的東西不動。
## 劇情的倒下重試不走這裡（那是重讀檢查點、不補滿血）。
func revive() -> void:
	if _death_tween != null:
		_death_tween.kill()
		_death_tween = null
	if _hurt_tween != null:
		_hurt_tween.kill()
		_hurt_tween = null
	hurt_left = 0.0
	_body.rotation_degrees.x = 0.0
	_body.rotation_degrees.z = 0.0
	health.reset()
	for sid: String in status_effects.ids():
		status_effects.clear(sid)
	_puppet.action = ""
	_puppet.action_time = 0.0
	_swing_resolved = true
	_dodge_left = 0.0
	_dodge_cooldown = 0.0
	invulnerable = false
	velocity = Vector3.ZERO
	lock_target = null


## 鎖定／解除。回傳鎖定後的目標（解除或找不到時為 null）。
func toggle_lock() -> Node3D:
	if lock_target != null:
		lock_target = null
	else:
		var cam_fwd: Vector3 = Basis(Vector3.UP, yaw) * Vector3.FORWARD
		lock_target = pick_lock_target(global_position, cam_fwd, get_tree().get_nodes_in_group("enemies"))
	return lock_target


## 挑鎖定目標：鏡頭前方 LOCK_CONE_DEG 內、LOCK_RANGE 內，角度與距離加權最小者；前方沒有就挑最近的。純函式。
static func pick_lock_target(origin: Vector3, cam_forward: Vector3, candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_score: float = INF
	var nearest: Node3D = null
	var nearest_d: float = INF
	for c: Variant in candidates:
		var n: Node3D = c as Node3D
		if n == null or not lockable(n):
			continue
		var d := Vector3(n.global_position.x - origin.x, 0.0, n.global_position.z - origin.z)
		var dist: float = d.length()
		if dist > LOCK_RANGE:
			continue
		if dist < nearest_d:
			nearest_d = dist
			nearest = n
		var ang: float = rad_to_deg(Vector3(cam_forward.x, 0.0, cam_forward.z).angle_to(d)) if dist > 0.01 else 0.0
		if ang <= LOCK_CONE_DEG:
			var score: float = dist + ang * 0.08
			if score < best_score:
				best_score = score
				best = n
	return best if best != null else nearest


## 換鎖定目標：dir=+1 往畫面右邊、-1 往左邊，挑同一側角度最小的。沒有就維持原目標。
func switch_lock(dir: int) -> Node3D:
	if lock_target == null:
		return null
	var nxt: Node3D = pick_switch_target(global_position, lock_target, dir, get_tree().get_nodes_in_group("enemies"))
	if nxt != null:
		lock_target = nxt
		lock_blocked = 0.0
	return lock_target


static func pick_switch_target(origin: Vector3, current: Node3D, dir: int, candidates: Array) -> Node3D:
	var base := Vector3(current.global_position.x - origin.x, 0.0, current.global_position.z - origin.z)
	if base.length() < 0.01:
		return null
	var best: Node3D = null
	var best_ang: float = INF
	for c: Variant in candidates:
		var n: Node3D = c as Node3D
		if n == null or n == current or not lockable(n):
			continue
		var d := Vector3(n.global_position.x - origin.x, 0.0, n.global_position.z - origin.z)
		if d.length() > LOCK_RANGE or d.length() < 0.01:
			continue
		# signed_angle_to 繞 +Y：正＝往左（逆時針），右邊是負
		var ang: float = base.signed_angle_to(d, Vector3.UP)
		var side_ok: bool = ang < -0.01 if dir > 0 else ang > 0.01
		if side_ok and absf(ang) < best_ang:
			best_ang = absf(ang)
			best = n
	return best


## 目標與諾恩之間是否被擋住（胸口高度的射線打到別的東西）。
func lock_line_blocked(target: Node3D) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3.UP * 1.3
	var to: Vector3 = target.global_position + Vector3.UP * 1.2
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask &= ~CAMERA_WALL_LAYER
	var ex: Array[RID] = [get_rid()]
	if target is CollisionObject3D:
		ex.append((target as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return false
	var who: Node = hit.get("collider") as Node
	return not (who != null and (who.is_in_group("heartbeat") or who.is_in_group("enemies")))


func in_combat() -> bool:
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e: Node3D = n as Node3D
		if e != null and lockable(e) and e.global_position.distance_to(global_position) <= COMBAT_RANGE:
			return true
	return false


func _update_camera_distance(delta: float) -> void:
	var want: float = CAMERA_DIST_COMBAT if lock_target == null and in_combat() else CAMERA_DIST
	_arm.spring_length = move_toward(_arm.spring_length, want, 2.0 * delta)


func camera_distance() -> float:
	return _arm.spring_length


static func lockable(n: Node3D) -> bool:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return false
	var h: Health = n.get_node_or_null("Health") as Health
	return h == null or not h.is_dead()


func _update_lock(delta: float) -> void:
	if lock_target != null:
		if not lockable(lock_target) or lock_target.global_position.distance_to(global_position) > LOCK_RANGE:
			lock_target = null
		elif lock_line_blocked(lock_target):
			lock_blocked += delta
			if lock_blocked >= LOCK_BLOCKED_SEC:
				lock_target = null
		else:
			lock_blocked = 0.0
	if lock_target == null:
		lock_blocked = 0.0
	if lock_target == null:
		_lock_marker.visible = false
		return
	var d: Vector3 = lock_target.global_position - global_position
	if Vector2(d.x, d.z).length() > 0.3:
		yaw = lerp_angle(yaw, atan2(-d.x, -d.z), clampf(6.0 * delta, 0.0, 1.0))
	pitch = lerpf(pitch, LOCK_PITCH, clampf(3.0 * delta, 0.0, 1.0))
	var h: float = float(lock_target.call("lock_height")) if lock_target.has_method("lock_height") else 2.2
	_lock_marker.global_position = lock_target.global_position + Vector3.UP * h
	_lock_marker.visible = true


func _build_lock_marker() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.albedo_color = Color(1.0, 0.86, 0.6)
	var prism := PrismMesh.new()
	prism.size = Vector3(0.16, 0.16, 0.02)
	_lock_marker = MeshInstance3D.new()
	_lock_marker.name = "LockMarker"
	_lock_marker.mesh = prism
	_lock_marker.material_override = m
	_lock_marker.rotation_degrees = Vector3(0, 0, 180)  # 倒三角指向目標
	_lock_marker.top_level = true
	_lock_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lock_marker.visible = false
	add_child(_lock_marker)


func is_invulnerable() -> bool:
	return invulnerable


## 這一幀玩家要的動作："dodge"／"release"／"attack"／""。剛按下去的優先（同一幀都按＝閃避 → 釋放 → 出手）；沒有的話看有沒有還記著的。
## `noen.input_buffer` 是 0 的時候就是「只有按下去的那一幀算」，跟以前一樣。
func _wanted_action(delta: float, locked: bool) -> String:
	var now: String = ""
	if Input.is_action_just_pressed("dodge"):
		now = "dodge"
	elif release_enabled() and Input.is_action_just_pressed("release"):
		now = "release"
	elif Input.is_action_just_pressed("attack"):
		now = "attack"
	if locked or health.is_dead():
		_buffered = ""
		return now
	if now != "":
		_buffered = now
		_buffer_left = CombatTuning.num("noen.input_buffer", 0.0)
		return now
	if _buffered != "":
		_buffer_left -= delta
		if _buffer_left <= 0.0:
			_buffered = ""
	return _buffered


## 還記著的按鍵（""＝沒有；測試用）
func buffered_action() -> String:
	return _buffered


## 出手到判定之前，身體對著這一下瞄的那個人，不跟著走路的方向轉（`noen.attack_face_lock`，0＝照舊＝劇情）。
## 沒有這個的話：出手的那一刻身體轉向敵人（的滑步），接著 0.19 秒內又被「往哪走就面向哪」轉回去——
## 按著左右或後退出手，判定的時候身體已經偏了 108～173 度，貼著的敵人也打不到（第 96 輪量到）。
func swing_holds_facing() -> bool:
	if _swing_resolved or _puppet.action != "attack" or _lunge_target == null or not is_instance_valid(_lunge_target):
		return false
	return CombatTuning.num("noen.attack_face_lock", 0.0) > 0.0


## 「釋放」這個鍵有沒有作用（`noen.release_enabled`：戰鬥場 1、劇情 0＝按了沒有反應）
func release_enabled() -> bool:
	return CombatTuning.num("noen.release_enabled", 0.0) > 0.0


## 現在放出去每個人扣多少（0＝不能放）：身上要有**反轉中的**中毒，而且至少剩 burst_min_sec 秒。
## 沒裝進反轉欄位的毒不能放（那是在扣他的血，不是他的東西）。
func release_power() -> float:
	if not release_enabled() or health == null or health.is_dead() or status_effects == null:
		return 0.0
	if not status_effects.has(RELEASE_STATUS) or not status_effects.is_reversed(RELEASE_STATUS):
		return 0.0
	var secs: float = status_effects.remaining(RELEASE_STATUS)
	if secs < CombatTuning.num("noen.burst_min_sec", 0.5):
		return 0.0
	return minf(secs * CombatTuning.num("noen.burst_per_sec", 8.0), CombatTuning.num("noen.burst_max", 80.0))


## 毒爆：把身上的毒整個用掉（之後就沒有回血了），周圍 burst_radius 公尺內的敵人每個扣「用掉的秒數 × burst_per_sec」。
## 不能放的時候什麼都不做、回傳空的。回傳 {"seconds", "damage", "hits", "kills"}。
func release() -> Dictionary:
	var damage: float = release_power()
	if damage <= 0.0:
		return {}
	var secs: float = status_effects.consume(RELEASE_STATUS)
	var radius: float = CombatTuning.num("noen.burst_radius", 3.0)
	var stagger: float = CombatTuning.num("noen.burst_stagger", 30.0)
	var hits: int = 0
	var kills: int = 0
	for n: Node in get_tree().get_nodes_in_group("damageable"):
		var target: Node3D = n as Node3D
		if target == null or target == self:
			continue
		if Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length() > radius:
			continue
		var h: Health = target.get_node_or_null("Health") as Health
		if h == null or h.is_dead():
			continue
		if h.apply_damage(damage, {"source": self, "stagger": stagger, "kind": "burst"}):
			hits += 1
			if h.is_dead():
				kills += 1
	var cap: float = maxf(CombatTuning.num("noen.burst_max", 80.0), 1.0)
	last_release_fx = PoisonBurst.create(radius, damage / cap)
	var parent: Node = get_parent() if get_parent() != null else self
	parent.add_child(last_release_fx)
	last_release_fx.global_position = global_position
	Sfx.play_at(parent, RELEASE_SFX, global_position + Vector3.UP, RELEASE_DB, 0.04, 8.0)
	if hits > 0:
		Game.hit_stop(CombatTuning.num("feel.hit_stop_kill" if kills > 0 else "feel.hit_stop_weak", 0.08))
	shake(CombatTuning.num("feel.shake_kill", 0.3))
	# 諾恩自己的姿勢：縮一下、兩手甩開。不是 action，不擋接下來的出手
	_puppet.play_release()
	release_count += 1
	last_release = {"seconds": secs, "damage": damage, "hits": hits, "kills": kills}
	released.emit(last_release)
	return last_release


func start_attack() -> void:
	_puppet.play_action("attack")
	_swing_resolved = false
	_begin_lunge()


## 出手的那一刻決定往哪裡滑：鎖定的目標 → 身體前方 lunge_seek 公尺內最近的敵人 → 鏡頭前方的（身體馬上轉過去對準他）→ 沒有就不滑。
## 「夠不到」是第 89 輪量到的問題：諾恩出手 1.9 m，拿棍子的 2.3～2.9 m。
func _begin_lunge() -> void:
	_lunge_left = 0.0
	_lunge_target = null
	var dist: float = CombatTuning.num("noen.lunge_dist", 0.0)
	if dist <= 0.0:
		return
	var seek: float = CombatTuning.num("noen.lunge_seek", 3.4)
	var foes: Array = get_tree().get_nodes_in_group("enemies")
	var foe: Node3D = lock_target if lock_target != null and is_instance_valid(lock_target) else lunge_pick(global_position, -_body.global_basis.z, seek, foes)
	if foe == null:
		# 身體前面沒有人（例如正在往後退）：改看鏡頭前面——玩家看著誰就打誰
		foe = lunge_pick(global_position, Basis(Vector3.UP, yaw) * Vector3.FORWARD, seek, foes)
	if foe == null:
		return
	var to: Vector3 = foe.global_position - global_position
	to.y = 0.0
	if to.length() < 0.05 or to.length() > seek:
		return
	_lunge_target = foe
	_lunge_dir = to.normalized()
	_lunge_left = dist
	_body.rotation.y = atan2(-_lunge_dir.x, -_lunge_dir.z)


## 前方（左右各 75 度）seek 公尺內最近的敵人。純函式。
static func lunge_pick(origin: Vector3, forward: Vector3, seek: float, candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_d: float = seek
	var f := Vector2(forward.x, forward.z).normalized()
	for c: Variant in candidates:
		var n: Node3D = c as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var to := Vector2(n.global_position.x - origin.x, n.global_position.z - origin.z)
		var d: float = to.length()
		if d > best_d or d < 0.05 or f.dot(to / d) < 0.26:
			continue
		best_d = d
		best = n
	return best


## 這一幀滑多少（回傳水平速度）：在命中判定之前滑完；離目標 lunge_stop 公尺以內就不再往前擠。
func _lunge_velocity(delta: float) -> Vector3:
	if _lunge_left <= 0.0 or _puppet.action != "attack" or _swing_resolved:
		_lunge_left = 0.0
		return Vector3.ZERO
	if _lunge_target != null and is_instance_valid(_lunge_target):
		var to: Vector3 = _lunge_target.global_position - global_position
		to.y = 0.0
		if to.length() <= CombatTuning.num("noen.lunge_stop", 1.25):
			_lunge_left = 0.0
			return Vector3.ZERO
		_lunge_dir = to.normalized()
	var window: Vector2 = CombatTuning.pair("noen.strike_window", Vector2(0.35, 0.6))
	var wind_sec: float = maxf(float(Puppet.ACTION_TIME["attack"]) * window.x / maxf(_puppet.attack_speed, 0.01), 0.05)
	var step: float = minf(CombatTuning.num("noen.lunge_dist", 0.0) / wind_sec * delta, _lunge_left)
	_lunge_left -= step
	lunge_moved += step
	return _lunge_dir * (step / maxf(delta, 0.0001))


## 鐘錘下劈：動作進到命中區間（strike_window，動作時間比例）時判定一次。
func _update_swing() -> void:
	if _swing_resolved:
		return
	if _puppet.action != "attack":
		_swing_resolved = true
		return
	var t: float = _puppet.action_time / float(Puppet.ACTION_TIME["attack"])
	var window: Vector2 = CombatTuning.pair("noen.strike_window", Vector2(0.35, 0.6))
	if t >= window.x:
		_swing_resolved = true
		if t <= window.y:
			strike()


## 對前方扇形內所有 damageable 群組的目標造成鈍擊。回傳命中數。
func strike() -> int:
	var forward: Vector3 = -_body.global_basis.z
	var reach: float = CombatTuning.num("noen.strike_range", 1.9)
	var arc: float = CombatTuning.num("noen.strike_arc_deg", 110.0)
	var damage: float = CombatTuning.num("noen.blunt_damage", 6.0)
	var stagger: float = CombatTuning.num("noen.blunt_stagger", 20.0)
	var weak_damage: float = CombatTuning.num("noen.weak_damage_mult", 2.0)
	var weak_stagger: float = CombatTuning.num("noen.weak_stagger_mult", 2.0)
	var hits: int = 0
	var killed: bool = false
	last_weak_hits = 0
	for n: Node in get_tree().get_nodes_in_group("damageable"):
		var target: Node3D = n as Node3D
		if target == null or target == self:
			continue
		if not in_strike_arc(global_position, forward, target.global_position, reach, arc):
			continue
		var h: Health = target.get_node_or_null("Health") as Health
		if h == null:
			continue
		var weak: String = ""
		if target.has_method("weakpoint_exposed_to"):
			weak = str(target.call("weakpoint_exposed_to", global_position))
		var k_dmg: float = weak_damage if weak != "" else 1.0
		var k_stg: float = weak_stagger if weak != "" else 1.0
		if h.apply_damage(damage * k_dmg, {"source": self, "stagger": stagger * k_stg, "kind": "blunt", "weak": weak}):
			hits += 1
			if weak != "":
				last_weak_hits += 1
			killed = killed or h.is_dead()
	if hits > 0:
		_apply_on_hit_source()
		Sfx.play_at(self, "blunt_weak" if last_weak_hits > 0 else "blunt", global_position + forward * reach * 0.7 + Vector3.UP * 0.6)
		var stop_key: String = "feel.hit_stop_kill" if killed else ("feel.hit_stop_weak" if last_weak_hits > 0 else "feel.hit_stop")
		Game.hit_stop(CombatTuning.num(stop_key, 0.06))
		shake(CombatTuning.num("feel.shake_kill" if killed else "feel.shake_hit", 0.2))
	return hits


## 打中人的那一刻，身上戴的東西給的狀態（護腕 → 麻痺）。只有那個狀態已經裝在反轉欄位裡才給：
## 沒反轉的麻痺會讓他不能出手，打中一下就把自己鎖住不是這個遊戲要的。同一個來源只有一份，每次命中只是重新計時。
func _apply_on_hit_source() -> void:
	if on_hit_source == "" or status_effects == null:
		return
	var status_id: String = str(status_effects.rules.source(on_hit_source).get("status", ""))
	if status_id == "" or not status_effects.is_reversed(status_id):
		return
	status_effects.apply_source(on_hit_source)
	on_hit_applied += 1


## 水平面上的扇形判定（不看高度）。純函式。
static func in_strike_arc(origin: Vector3, forward: Vector3, target: Vector3, reach: float, arc_deg: float) -> bool:
	var d := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
	var dist: float = d.length()
	if dist > reach:
		return false
	if dist < 0.3:
		return true
	var f := Vector3(forward.x, 0.0, forward.z)
	if f.length() < 0.001:
		return false
	return f.angle_to(d) <= deg_to_rad(arc_deg * 0.5)


## 鏡頭震動（減少晃動開啟時縮到 reduced_shake_scale）。
func shake(amount: float) -> void:
	var k: float = CombatTuning.num("feel.reduced_shake_scale", 0.25) if Settings.reduce_camera_shake else 1.0
	_shake = maxf(_shake, amount * k)


func shake_amount() -> float:
	return _shake


## 右手拿劍：程序人偶右手上程式拼的那一把拿掉，換成模型。沒有任何模型檔＝維持人偶原本的。
func _build_weapon() -> void:
	var hand: Node3D = _puppet.hand("R")
	if hand == null:
		return
	var model: Node3D = PropModels.instance_first(SWORD_MODELS)
	if model == null:
		return
	var old: Node = hand.get_node_or_null("BellHammer")
	if old != null:
		hand.remove_child(old)
		old.queue_free()
	_weapon = Node3D.new()
	_weapon.name = "Weapon"
	model.name = "Model"
	model.scale = Vector3.ONE * SWORD_SCALE
	model.rotation_degrees = Vector3(0, 0, 180)
	model.position = SWORD_GRIP
	_weapon.add_child(model)
	hand.add_child(_weapon)


func weapon() -> Node3D:
	return _weapon


func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(_shake - 2.5 * delta, 0.0)
	var a: float = _shake * _shake
	_camera.h_offset = _rng.randf_range(-1.0, 1.0) * 0.12 * a
	_camera.v_offset = _rng.randf_range(-1.0, 1.0) * 0.12 * a


func _follow_rig(delta: float) -> void:
	var target: Vector3 = global_position + Vector3(0.0, CAMERA_HEIGHT, 0.0)
	_rig.global_position = _rig.global_position.lerp(target, clampf(14.0 * delta, 0.0, 1.0))
	_rig.rotation = Vector3(0.0, yaw, 0.0)
	_pitch_node.rotation = Vector3(pitch, 0.0, 0.0)
	_update_shoulder(delta)


## 這個時候想要的過肩偏移（還沒扣掉牆）：探索 0.85 m，戰鬥中或鎖定時 1.05 m。
func shoulder_target() -> float:
	return SHOULDER_OFFSET_COMBAT if lock_target != null or in_combat() else SHOULDER_OFFSET


## 目前的過肩偏移（m，SpringArm 的 x）。
func shoulder_offset() -> float:
	return _shoulder


## 跟著想要的值慢慢變；任何時候都不超過肩膀那條射線量到的空間（貼牆時立即收回）。
func _update_shoulder(delta: float) -> void:
	var want: float = shoulder_target()
	var room: float = shoulder_room(want)
	_shoulder = minf(move_toward(_shoulder, want, SHOULDER_EASE * delta), room)
	_arm.position.x = _shoulder


func _on_node_added_for_camera(n: Node) -> void:
	_exclude_from_camera(n)


## 角色（CharacterBody3D／RigidBody3D）不讓鏡頭的 SpringArm 撞到：站在諾恩身後時鏡頭不會被拉到他後腦。
func _exclude_from_camera(n: Node) -> void:
	if n == self or _arm == null:
		return
	if n is CharacterBody3D or n is RigidBody3D:
		_arm.add_excluded_object((n as CollisionObject3D).get_rid())


## 從鏡頭架（諾恩頭部高度）往右打一條射線，回傳往右最多能放多遠（m）。
## 只算場景（牆、房子、箱子）；擋到席菈、敵人、車隊等角色不算——他們走過去時鏡頭不該跟著抖。
func shoulder_room(want: float) -> float:
	if not is_inside_tree():
		return want
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = _rig.global_position
	var right: Vector3 = _rig.global_basis.x.normalized()
	var to: Vector3 = from + right * (want + SHOULDER_MARGIN)
	var ex: Array[RID] = [get_rid()]
	for _i: int in 4:
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = ex
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			return want
		var who: Object = hit.get("collider")
		if who is CharacterBody3D or who is RigidBody3D:
			ex.append(hit.get("rid") as RID)
			continue
		var d: float = from.distance_to(hit.get("position") as Vector3)
		return clampf(d - SHOULDER_MARGIN, 0.0, want)
	return want


## 傳送玩家後呼叫，鏡頭立即就位（不從舊位置滑過來）。
func snap_camera() -> void:
	_rig.global_position = global_position + Vector3(0.0, CAMERA_HEIGHT, 0.0)
	_rig.rotation = Vector3(0.0, yaw, 0.0)
	_pitch_node.rotation = Vector3(pitch, 0.0, 0.0)
	_shoulder = minf(shoulder_target(), shoulder_room(shoulder_target())) if is_inside_tree() else shoulder_target()
	_arm.position.x = _shoulder
