class_name Sera
extends CharacterBody3D
## 席菈（Sera，資產 id sheila）：後排的見習鍊金術師（docs/story/chapter-1.md）。
## 跟在諾恩後面，手上【鍊金藥瓶手弩】；諾恩附近有敵人時每隔幾秒往他背上射一瓶失敗作——對別人是災難，落在諾恩身上就反轉成增益。
## 要做什麼由 SeraBrain 決定（純邏輯、有測試），這裡只管走路、轉身、舉弩、生出藥瓶。
## 不擋路、不會被打（collision_layer＝0）；樹與地形擋得住她。離太遠（被卡住）就直接出現在諾恩後面。
## 她沒有諾恩的體質：瘴氣對她是真的毒，所以靠近瘴氣就把防毒面具戴上（劇本節點 2），離開一下子才拿下來。
## 還沒結伴（joined＝false）的時候站在原地等：不跟、不射，諾恩走近會轉過來看他。

const CROSSBOW_MODEL: String = "tripo/weapon_alchemy_crossbow"
const VIAL_SOURCE: String = "sera_paralysis_vial"
const TURN_SPEED: float = 8.0
const GRAVITY: float = 18.0
const SNAP_DIST: float = 18.0
## 手弩在手上的擺法（模型的長邊是 +Y、握的地方在原點：scripts/gen_props.sh）
const CROSSBOW_ROT: Vector3 = Vector3(0, 0, 180)
const CROSSBOW_OFFSET: Vector3 = Vector3(0.0, 0.02, 0.0)
## 離瘴氣的邊緣還有這麼遠就先戴上面具；離開之後過這麼久才拿下來（在邊緣走來走去不會一直戴戴脫脫）
const MASK_MARGIN: float = 1.0
const MASK_OFF_DELAY: float = 1.5
## 面具掛在頭的骨頭上：往上、往臉的前面移這麼多（公尺）
const MASK_OFFSET: Vector3 = Vector3(0.0, -0.005, -0.115)
## 還沒結伴時，諾恩走到這麼近她才轉過來
const NOTICE_DIST: float = 9.0

## 面具戴上／拿下來的那一刻（關卡接這個讓她喊一句）
signal mask_changed(on: bool)

var brain: SeraBrain = SeraBrain.new()
## 下一瓶射什麼（statuses.json 的來源）；關卡可以換（教學戰的第一瓶是她慌了拿錯的那一瓶）
var vial_source: String = VIAL_SOURCE
## 結伴了沒（關卡照劇情旗標設）
var joined: bool = true
var masked: bool = false
var _mask: Node3D
var _mask_off_in: float = 0.0
var target: PlayerController
var vials_fired: int = 0
var last_vial: SeraVial
var _puppet: Puppet
var _crossbow: Node3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	shape.shape = capsule
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)
	_puppet = Puppet.new()
	_puppet.name = "Puppet"
	_puppet.character_id = "sheila"
	add_child(_puppet)
	ContactShadow.attach(self, 0.5, 0.5)
	_build_crossbow()
	_build_mask()


func puppet() -> Puppet:
	return _puppet


func crossbow() -> Node3D:
	return _crossbow


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	_update_mask(delta)
	if joined and dist > SNAP_DIST:
		global_position = target.global_position + Vector3.BACK.rotated(Vector3.UP, target.yaw) * CombatTuning.num("sera.follow_near", 4.5)
		return
	var locked: bool = Game.is_player_locked() or not joined
	var speed: float = 0.0 if locked else brain.follow_speed(dist)
	var dir: Vector3 = to / dist if dist > 0.01 else Vector3.ZERO
	velocity = Vector3(dir.x * speed, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, dir.z * speed)
	move_and_slide()
	_puppet.set_move_speed(speed)
	if dist > 0.3 and (joined or dist < NOTICE_DIST):
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(delta * TURN_SPEED, 1.0))
	if locked:
		return
	var was_aiming: bool = brain.is_aiming()
	if brain.tick(delta, threat_near()):
		fire()
	elif brain.is_aiming() and not was_aiming:
		_puppet.play_action("shoot")


## 諾恩附近有沒有活著的敵人
func threat_near() -> bool:
	var reach: float = CombatTuning.num("sera.threat_range", 12.0)
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e := n as EnemyActor
		if e != null and not e.health.is_dead() and e.global_position.distance_to(target.global_position) <= reach:
			return true
	return false


## 擊發：從弩口生一瓶藥飛向諾恩。
func fire() -> SeraVial:
	vials_fired += 1
	var from: Vector3 = _crossbow.global_position if _crossbow != null else global_position + Vector3.UP * 1.2
	last_vial = SeraVial.launch(get_parent(), from, target, vial_source)
	Sfx.play_at(self, "whoosh", from, -6.0)
	return last_vial


## 現在站的地方是不是瘴氣裡面（或就在邊上）
func near_miasma() -> bool:
	for n: Node in get_tree().get_nodes_in_group("poison_mist"):
		var mist := n as PoisonMist
		if mist != null and Vector2(mist.global_position.x - global_position.x, mist.global_position.z - global_position.z).length() <= mist.radius + MASK_MARGIN:
			return true
	return false


func _update_mask(delta: float) -> void:
	if near_miasma():
		_mask_off_in = MASK_OFF_DELAY
		_set_masked(true)
	elif masked:
		_mask_off_in -= delta
		if _mask_off_in <= 0.0:
			_set_masked(false)


func _set_masked(on: bool) -> void:
	if on == masked:
		return
	masked = on
	if _mask != null:
		_mask.visible = true
		var t: Tween = create_tween()
		t.tween_property(_mask, "scale", Vector3.ONE if on else Vector3.ONE * 0.01, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT if on else Tween.EASE_IN)
		if not on:
			t.tween_callback(_mask.hide)
	mask_changed.emit(on)


func mask() -> Node3D:
	return _mask


## 防毒面具：蓋住口鼻的皮面罩＋兩邊各一個黃銅濾毒罐（中間亮青色的濾芯）。程式拼的；平常收著看不到。
func _build_mask() -> void:
	var head: Node3D = _puppet.joint("head")
	if head == null:
		return
	_mask = Node3D.new()
	_mask.name = "GasMask"
	_mask.position = MASK_OFFSET
	_mask.scale = Vector3.ONE * 0.01
	_mask.visible = false
	head.add_child(_mask)
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.34, 0.22, 0.15)
	leather.roughness = 0.9
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.82, 0.63, 0.26)
	brass.metallic = 0.6
	brass.roughness = 0.45
	var core := StandardMaterial3D.new()
	core.albedo_color = Color(0.45, 0.95, 0.85)
	core.emission_enabled = true
	core.emission = Color(0.45, 0.95, 0.85)
	core.emission_energy_multiplier = 1.6
	var muzzle := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.07
	dome.height = 0.14
	dome.material = leather
	muzzle.mesh = dome
	muzzle.scale = Vector3(1.0, 0.82, 0.72)
	_mask.add_child(muzzle)
	for side: float in [-1.0, 1.0]:
		var can := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.034
		cyl.bottom_radius = 0.034
		cyl.height = 0.04
		cyl.material = brass
		can.mesh = cyl
		# 罐子的軸朝斜前方（臉頰的方向）
		can.position = Vector3(0.062 * side, -0.012, -0.012)
		can.rotation_degrees = Vector3(90.0, -38.0 * side, 0.0)
		_mask.add_child(can)
		var lens := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.022
		disc.bottom_radius = 0.022
		disc.height = 0.006
		disc.material = core
		lens.mesh = disc
		lens.position = Vector3(0.0, -0.022, 0.0)
		can.add_child(lens)
	for n: Node in _mask.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 右手的手弩：有 Tripo 的模型用模型，沒有就用程式拼一把（木頭弩身＋黃銅弓臂＋一管紫色的藥）。
func _build_crossbow() -> void:
	var hand: Node3D = _puppet.hand("R")
	if hand == null:
		return
	_crossbow = Node3D.new()
	_crossbow.name = "Crossbow"
	hand.add_child(_crossbow)
	var model: Node3D = PropModels.instance(CROSSBOW_MODEL)
	if model == null:
		model = _stand_in_crossbow()
	model.name = "Model"
	model.rotation_degrees = CROSSBOW_ROT
	model.position = CROSSBOW_OFFSET
	_crossbow.add_child(model)


static func _stand_in_crossbow() -> Node3D:
	var root := Node3D.new()
	for part: Array in [
		[Vector3(0.05, 0.36, 0.06), Vector3(0, 0.12, 0), Color(0.4, 0.26, 0.15)],
		[Vector3(0.34, 0.03, 0.03), Vector3(0, 0.27, 0), Color(0.75, 0.6, 0.25)],
		[Vector3(0.05, 0.12, 0.05), Vector3(0, 0.16, 0.05), Color(0.7, 0.35, 1.0)],
	]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0] as Vector3
		var mat := StandardMaterial3D.new()
		mat.albedo_color = part[2] as Color
		box.material = mat
		mesh.mesh = box
		mesh.position = part[1] as Vector3
		root.add_child(mesh)
	return root
