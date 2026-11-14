class_name Slime
extends EnemyActor
## 劇毒史萊姆（第一章教學戰，docs/story/chapter-1.md 節點 2）：慢慢靠近、蓄力壓扁、往前撲撞。
## 撞到人除了傷害還上中毒（data/status/statuses.json 的 slime_touch）——對諾恩來說那是回血。
## 外型：Tripo 的模型（建置時 scripts/gen_props.sh 擺正成 0.8 m 高）；檔案不在就用一顆半透明的球。

const MODEL: String = "tripo/enemy_poison_slime"
const BODY_RADIUS: float = 0.45
const TOUCH_SOURCE: String = "slime_touch"
const LUNGE_SPEED: float = 5.0

var _lunge_dir: Vector3 = Vector3.ZERO
var _look: Node3D


func tuning_id() -> String:
	return "poison_slime"


func _head_height() -> float:
	return 1.0


func _build_body() -> void:
	super._build_body()
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = BODY_RADIUS
	shape.shape = ball
	shape.position = Vector3(0, BODY_RADIUS, 0)
	add_child(shape)
	ContactShadow.attach(self, 0.7, 0.5)
	_look = PropModels.instance(MODEL)
	if _look == null:
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = BODY_RADIUS
		sphere.height = BODY_RADIUS * 1.6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.3, 0.85, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.9, 0.2)
		mat.emission_energy_multiplier = 0.3
		sphere.material = mat
		mesh.mesh = sphere
		mesh.position = Vector3(0, BODY_RADIUS * 0.8, 0)
		_look = mesh
	_look.name = "Look"
	_body.add_child(_look)


## 出招的那一刻：記下往哪撲、判定前方的人。
func _on_strike() -> void:
	_lunge_dir = forward()
	Sfx.play_at(self, "whoosh", global_position + Vector3.UP * 0.4, -8.0)
	var origin: Vector3 = global_position
	var fwd: Vector3 = _lunge_dir
	var reach: float = brain.attack_range + 0.5
	var hit: int = hit_heartbeats(CombatTuning.num("poison_slime.bump_damage", 10.0), "bump",
		func(p: Vector3) -> bool: return PlayerController.in_strike_arc(origin, fwd, p, reach, 120.0))
	if hit > 0 and _player != null and is_instance_valid(_player) and PlayerController.in_strike_arc(origin, fwd, _player.global_position, reach, 120.0):
		_player.status_effects.apply_source(TOUCH_SOURCE)


func _on_strike_tick(_delta: float) -> Vector3:
	return _lunge_dir * LUNGE_SPEED


## 蓄力時壓扁、出招時拉長；跪著（失衡）時攤平。
func _update_look() -> void:
	if _look == null:
		return
	var squash: float = 1.0 - 0.35 * brain.telegraph_progress()
	if brain.state == EnemyBrain.State.STRIKE:
		squash = 1.2
	elif brain.state == EnemyBrain.State.STAGGERED:
		squash = 0.5
	var wide: float = 1.0 / sqrt(maxf(squash, 0.1))
	_look.scale = _look.scale.lerp(Vector3(wide, squash, wide), 0.25)
