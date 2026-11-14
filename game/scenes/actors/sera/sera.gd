class_name Sera
extends CharacterBody3D
## 席菈（Sera，資產 id sheila）：後排的見習鍊金術師（docs/story/chapter-1.md）。
## 跟在諾恩後面，手上【鍊金藥瓶手弩】；諾恩附近有敵人時每隔幾秒往他背上射一瓶失敗作——對別人是災難，落在諾恩身上就反轉成增益。
## 要做什麼由 SeraBrain 決定（純邏輯、有測試），這裡只管走路、轉身、舉弩、生出藥瓶。
## 不擋路、不會被打（collision_layer＝0）；樹與地形擋得住她。離太遠（被卡住）就直接出現在諾恩後面。

const CROSSBOW_MODEL: String = "tripo/weapon_alchemy_crossbow"
const VIAL_SOURCE: String = "sera_paralysis_vial"
const TURN_SPEED: float = 8.0
const GRAVITY: float = 18.0
const SNAP_DIST: float = 18.0
## 手弩在手上的擺法（模型的長邊是 +Y、握的地方在原點：scripts/gen_props.sh）
const CROSSBOW_ROT: Vector3 = Vector3(0, 0, 180)
const CROSSBOW_OFFSET: Vector3 = Vector3(0.0, 0.02, 0.0)

var brain: SeraBrain = SeraBrain.new()
## 下一瓶射什麼（statuses.json 的來源）；關卡可以換（教學戰的第一瓶是她慌了拿錯的那一瓶）
var vial_source: String = VIAL_SOURCE
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
	if dist > SNAP_DIST:
		global_position = target.global_position + Vector3.BACK.rotated(Vector3.UP, target.yaw) * CombatTuning.num("sera.follow_near", 4.5)
		return
	var locked: bool = Game.is_player_locked()
	var speed: float = 0.0 if locked else brain.follow_speed(dist)
	var dir: Vector3 = to / dist if dist > 0.01 else Vector3.ZERO
	velocity = Vector3(dir.x * speed, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, dir.z * speed)
	move_and_slide()
	_puppet.set_move_speed(speed)
	if dist > 0.3:
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
