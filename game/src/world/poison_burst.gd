class_name PoisonBurst
extends Node3D
## 毒爆（docs/design/02-gameplay.md「釋放」）：諾恩把身上的毒一次放出去的那一下。
## 腳邊一圈綠環擴到傷害的範圍（環停下來的地方＝打得到的地方）、地上一片綠光、一把往外飛的綠點、一盞很短的綠燈。
## 只有畫面，傷害在 PlayerController.release()。strength 0～1（用掉的秒數占上限幾成）：越多秒越亮、點越多。

const COLOR: Color = Color(0.45, 1.0, 0.35)
const RING_FROM: float = 0.4
const RING_SEC: float = 0.34
const GLOW_SEC: float = 0.5
const MOTE_SEC: float = 0.55
const FLASH_ENERGY: float = 4.0
const TOTAL_SEC: float = 0.9

var radius: float = 3.0
var strength: float = 1.0
## 截圖用：停在剛炸開的樣子，不收掉
var debug_hold: bool = false


static func create(p_radius: float, p_strength: float) -> PoisonBurst:
	var b := PoisonBurst.new()
	b.name = "PoisonBurst"
	b.radius = p_radius
	b.strength = clampf(p_strength, 0.0, 1.0)
	return b


func _ready() -> void:
	var k: float = 0.45 + 0.55 * strength
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.albedo_color = Color(COLOR.r * 2.4 * k, COLOR.g * 2.4 * k, COLOR.b * 2.4 * k, 1.0)
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(RING_FROM, 0.3, RING_FROM)
	ring.position.y = 0.1
	add_child(ring)
	# 地上的一片綠光：平躺的面片，從中間往外淡
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * radius * 2.0
	glow.mesh = quad
	var glow_mat: StandardMaterial3D = ParticleLook.material(Color(COLOR.r, COLOR.g, COLOR.b, 0.55 * k), true, BaseMaterial3D.BILLBOARD_DISABLED)
	glow.material_override = glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position.y = 0.07
	glow.scale = Vector3.ONE * 0.3
	add_child(glow)
	# 往外飛的綠點：貼著地面往四周噴，飛到範圍邊緣差不多停
	var motes := CPUParticles3D.new()
	motes.name = "Motes"
	motes.emitting = false
	motes.one_shot = true
	motes.explosiveness = 1.0
	motes.amount = int(lerpf(28.0, 70.0, strength))
	motes.lifetime = MOTE_SEC
	motes.direction = Vector3.UP
	motes.spread = 88.0
	motes.flatness = 0.75
	motes.gravity = Vector3(0.0, -1.5, 0.0)
	motes.initial_velocity_min = radius / MOTE_SEC * 0.9
	motes.initial_velocity_max = radius / MOTE_SEC * 1.9
	motes.damping_min = 6.0
	motes.damping_max = 9.0
	motes.scale_amount_min = 0.7
	motes.scale_amount_max = 1.5
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	motes.scale_amount_curve = shrink
	var dot := QuadMesh.new()
	dot.size = Vector2.ONE * 0.16
	motes.mesh = dot
	motes.material_override = ParticleLook.material(Color(COLOR.r, COLOR.g, COLOR.b, 0.95), true)
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.position.y = 0.7
	add_child(motes)
	motes.emitting = true
	var flash := OmniLight3D.new()
	flash.name = "Flash"
	flash.light_color = COLOR
	flash.light_energy = FLASH_ENERGY * k
	flash.omni_range = radius + 2.0
	flash.omni_attenuation = 1.3
	flash.shadow_enabled = false
	# 霧裡不要有很亮的綠燈（濕石板上會有刺眼的高光點）：鏡面反光關掉，只留漫射
	flash.light_specular = 0.0
	flash.light_volumetric_fog_energy = 0.6
	flash.position.y = 1.3
	add_child(flash)
	if debug_hold:
		ring.scale = Vector3(radius, 0.3, radius)
		glow.scale = Vector3.ONE
		return
	var t: Tween = create_tween()
	t.tween_property(ring, "scale", Vector3(radius, 0.3, radius), RING_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, RING_SEC).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(glow, "scale", Vector3.ONE, RING_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(glow_mat, "albedo_color:a", 0.0, GLOW_SEC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(flash, "light_energy", 0.0, GLOW_SEC).set_ease(Tween.EASE_OUT)
	t.tween_interval(maxf(TOTAL_SEC - GLOW_SEC, 0.05))
	t.tween_callback(queue_free)
