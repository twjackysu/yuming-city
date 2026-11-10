class_name PoisonMist
extends Node3D
## 毒霧（新版，D-202）：MistZone（規則）＋幾層貼地的綠色霧盤（poison_mist.gdshader，灰盒）。
## 每個物理幀把玩家（與 extra_targets 裡有 status_effects 的角色）餵給 MistZone；在霧裡就上狀態。
## 守衛噴的霧 life > 0：最後 0.6 秒淡掉，時間到自己移除。

const LAYERS: int = 3
const LAYER_GAP: float = 0.32
const SHADER: Shader = preload("res://src/world/poison_mist.gdshader")

var zone: MistZone
var radius: float = 3.0
var source_id: String = "barrel_mist"
var life: float = -1.0
var _mats: Array[ShaderMaterial] = []


static func create(p_radius: float, p_source: String, p_life: float = -1.0) -> PoisonMist:
	var m := PoisonMist.new()
	m.radius = p_radius
	m.source_id = p_source
	m.life = p_life
	return m


func _ready() -> void:
	add_to_group("poison_mist")
	zone = MistZone.new(global_position, radius, source_id, life)
	for i: int in LAYERS:
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(radius, radius) * 2.0 * (1.0 - 0.08 * float(i))
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("layer", float(i) / float(LAYERS - 1))
		_mats.append(mat)
		var mi := MeshInstance3D.new()
		mi.name = "MistLayer%d" % i
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = 0.06 + LAYER_GAP * float(i)
		add_child(mi)


func _physics_process(delta: float) -> void:
	zone.center = global_position
	zone.tick(delta)
	var f: float = 1.0 if zone.life < 0.0 else clampf(zone.life / 0.6, 0.0, 1.0)
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("fade", f)
	if zone.expired():
		queue_free()
		return
	if Game.is_player_locked():
		return
	for n: Node in get_tree().get_nodes_in_group("player"):
		var p: PlayerController = n as PlayerController
		if p != null and not p.health.is_dead():
			zone.expose(p.get_instance_id(), p.global_position, p.status_effects, delta)


func contains(pos: Vector3) -> bool:
	return zone != null and zone.contains(pos)
