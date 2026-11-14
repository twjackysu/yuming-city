class_name SeraVial
extends Node3D
## 席菈射出來的藥瓶：一道拋物線飛向諾恩的背（她瞄的就是他，一定會中），落在身上就套用那個來源的狀態
## （data/status/statuses.json 的 sources）——反轉的回饋由 StatusEffects.changed 自己觸發，這裡不用管。

const ARC_HEIGHT: float = 1.1
const CHEST_Y: float = 1.15
const LIQUID: Color = Color(0.75, 0.35, 1.0)

var target: PlayerController
var source: String = ""
var flight: float = 0.55
var landed: bool = false
var _from: Vector3
var _t: float = 0.0
var _bottle: MeshInstance3D
var _trail: CPUParticles3D


static func launch(parent: Node, from: Vector3, p_target: PlayerController, p_source: String) -> SeraVial:
	var v := SeraVial.new()
	v.name = "SeraVial"
	v.target = p_target
	v.source = p_source
	v.flight = maxf(CombatTuning.num("sera.vial_flight", 0.55), 0.05)
	v._from = from
	parent.add_child(v)
	v.global_position = from
	return v


func _ready() -> void:
	_bottle = MeshInstance3D.new()
	var glass := CapsuleMesh.new()
	glass.radius = 0.05
	glass.height = 0.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = LIQUID
	glass.material = mat
	_bottle.mesh = glass
	_bottle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bottle)
	var glow := OmniLight3D.new()
	glow.light_color = LIQUID
	glow.light_energy = 1.6
	glow.omni_range = 3.0
	glow.light_specular = 0.0
	_bottle.add_child(glow)
	_trail = _particles(26, 0.45, 0.4, 0.09)
	_trail.spread = 180.0
	add_child(_trail)


func _physics_process(delta: float) -> void:
	if landed:
		return
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	_t = minf(_t + delta / flight, 1.0)
	var to: Vector3 = target.global_position + Vector3.UP * CHEST_Y
	var p: Vector3 = _from.lerp(to, _t)
	p.y += sin(_t * PI) * ARC_HEIGHT
	global_position = p
	_bottle.rotation.x += delta * 14.0
	if _t >= 1.0:
		_land()


## 砸在諾恩身上：上狀態、玻璃聲、一團紫色的藥水往外濺。
func _land() -> void:
	landed = true
	var fx: StatusEffects = target.status_effects
	var status_id: String = str(fx.rules.source(source).get("status", ""))
	# 劇本：落在諾恩身上的異常狀態全部會反轉。反轉欄位（ReversalSlots）是重新開始前的設計，還沒拿掉——先把這一種裝進去
	target.reversal.unlock(status_id)
	target.reversal.equip(status_id)
	fx.apply_source(source)
	Sfx.play_at(target, "glass_clink", global_position, -2.0)
	_bottle.visible = false
	_trail.emitting = false
	var splash: CPUParticles3D = _particles(40, 0.5, 3.2, 0.14)
	splash.one_shot = true
	splash.explosiveness = 1.0
	splash.spread = 180.0
	splash.gravity = Vector3(0, -6.0, 0)
	add_child(splash)
	get_tree().create_timer(1.0).timeout.connect(queue_free)


func _particles(amount: int, life: float, speed: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3.UP
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = ParticleLook.material(LIQUID, true)
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
