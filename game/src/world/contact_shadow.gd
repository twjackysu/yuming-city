class_name ContactShadow
extends RefCounted
## 腳下的接地陰影（D-108）：送葬者的那一片（D-101，ground_shadow.gdshader）給諾恩、席菈、灰巡者也加上。
## 夜裡月光的影子被霧吃掉、路燈大多不投影，人物像浮在濕石板上；腳下一片中間最暗、往外柔和淡出的黑，
## 用透明度畫（照樣被霧蓋住）。掛在角色本身（原點在腳底），不跟著身體動作轉。

const SHADER: String = "res://scenes/actors/undertaker/ground_shadow.gdshader"
const NODE_NAME: String = "GroundShadow"


static func attach(parent: Node3D, radius: float, strength: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER) as Shader
	mat.set_shader_parameter("strength", strength)
	mat.render_priority = -1
	var mi := MeshInstance3D.new()
	mi.name = NODE_NAME
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.015, 0)
	parent.add_child(mi)
	return mi
