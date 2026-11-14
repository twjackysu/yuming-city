class_name Fireball
extends Node3D
## 諾恩的普通攻擊：從杖頭射出去的火球（Jacky 2026-11-14：「拿法杖還用敲的有點太遜，普攻可能是遠距離射火球」）。
## 直直往前飛，碰到第一個 damageable 的目標就炸開、造成傷害；飛滿 MAX_RANGE 沒碰到人就熄掉。
## 近身那一下（PlayerController.strike() 的扇形）已經打到的人放進 skip，不會同一下吃兩次。

const SPEED: float = 18.0
const MAX_RANGE: float = 14.0
## 水平距離在這以內算碰到（不看高度：敵人有高有矮）
const HIT_RADIUS: float = 0.75
const CORE_COLOR: Color = Color(1.0, 0.72, 0.28)
const GLOW_COLOR: Color = Color(1.0, 0.42, 0.12)

var direction: Vector3 = Vector3.FORWARD
var damage: float = 6.0
var stagger: float = 20.0
var source: Node3D
var skip: Array[Node] = []
var traveled: float = 0.0
var hit_target: Node3D
var _done: bool = false


static func create(p_source: Node3D, p_direction: Vector3, p_damage: float, p_stagger: float, p_skip: Array[Node]) -> Fireball:
	var f := Fireball.new()
	f.source = p_source
	f.direction = Vector3(p_direction.x, 0.0, p_direction.z).normalized()
	f.damage = p_damage
	f.stagger = p_stagger
	f.skip = p_skip
	return f


func _ready() -> void:
	var core := MeshInstance3D.new()
	core.name = "Core"
	var ball := SphereMesh.new()
	ball.radius = 0.16
	ball.height = 0.32
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = CORE_COLOR
	mat.emission_enabled = true
	mat.emission = GLOW_COLOR
	mat.emission_energy_multiplier = 4.0
	ball.material = mat
	core.mesh = ball
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = GLOW_COLOR
	light.light_energy = 2.2
	light.omni_range = 4.5
	add_child(light)
	var trail := GPUParticles3D.new()
	trail.name = "Trail"
	trail.amount = 28
	trail.lifetime = 0.35
	trail.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, 0.6, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.spread = 180.0
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = GLOW_COLOR
	trail.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	quad.material = ParticleLook.material(GLOW_COLOR, true)
	trail.draw_pass_1 = quad
	add_child(trail)


func _physics_process(delta: float) -> void:
	if _done:
		return
	advance(delta)


## 往前飛一步並判定（測試直接呼叫）。回傳這一步有沒有打到人。
func advance(delta: float) -> bool:
	if _done:
		return false
	var step: float = SPEED * delta
	global_position += direction * step
	traveled += step
	for n: Node in get_tree().get_nodes_in_group("damageable"):
		var target: Node3D = n as Node3D
		if target == null or target == source or skip.has(target):
			continue
		var d := Vector3(target.global_position.x - global_position.x, 0.0, target.global_position.z - global_position.z)
		if d.length() > HIT_RADIUS:
			continue
		var h: Health = target.get_node_or_null("Health") as Health
		if h == null or h.is_dead():
			continue
		var weak: String = ""
		if source != null and is_instance_valid(source) and target.has_method("weakpoint_exposed_to"):
			weak = str(target.call("weakpoint_exposed_to", source.global_position))
		var k: float = CombatTuning.num("noen.weak_damage_mult", 2.0) if weak != "" else 1.0
		if h.apply_damage(damage * k, {"source": source, "stagger": stagger * k, "kind": "fire", "weak": weak}):
			hit_target = target
			_burst()
			return true
	if traveled >= MAX_RANGE:
		_finish(0.0)
	return false


func _burst() -> void:
	Sfx.play_at(self, "blunt", global_position)
	if source != null and is_instance_valid(source) and source.has_method("shake"):
		source.call("shake", CombatTuning.num("feel.shake_hit", 0.2))
	var core: MeshInstance3D = get_node_or_null("Core") as MeshInstance3D
	if core != null and is_inside_tree():
		var t := create_tween().set_parallel(true)
		t.tween_property(core, "scale", Vector3.ONE * 4.0, 0.14)
		t.tween_property(get_node("Glow"), "light_energy", 0.0, 0.18)
	_finish(0.18)


func _finish(after: float) -> void:
	_done = true
	var trail: GPUParticles3D = get_node_or_null("Trail") as GPUParticles3D
	if trail != null:
		trail.emitting = false
	if after <= 0.0 or not is_inside_tree():
		queue_free()
	else:
		get_tree().create_timer(after).timeout.connect(queue_free)
