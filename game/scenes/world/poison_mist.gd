class_name PoisonMist
extends Node3D
## 毒霧／瘴氣：MistZone（規則）＋幾層貼地的霧盤（poison_mist.gdshader）＋一團有體積的霧。
## 每個物理幀把玩家（與 extra_targets 裡有 status_effects 的角色）餵給 MistZone；在霧裡就上狀態。
## 守衛噴的霧 life > 0：最後 0.6 秒淡掉，時間到自己移除。

const LAYERS: int = 3
const LAYER_GAP: float = 0.32
const SHADER: Shader = preload("res://src/world/poison_mist.gdshader")
## 真的有體積的那一團：體積霧裡的一個綠色橢球（FogVolume）。貼地的霧盤從上往下看是一個平的圓盤，
## 加上這一團之後，從旁邊看霧有厚度、後面的人和牆被染綠。畫質低（沒有體積霧）時只剩霧盤。
const VOLUME_HEIGHT: float = 1.7
const VOLUME_DENSITY: float = 1.2
const VOLUME_ALBEDO: Color = Color(0.42, 0.92, 0.36)
const VOLUME_EMISSION: Color = Color(0.07, 0.2, 0.05)
## 那一團的濃淡與輪廓：底濃上淡、邊緣用雜訊咬不規則、裡面慢慢流動（poison_mist_volume.gdshader）。
const VOLUME_SHADER: Shader = preload("res://src/world/poison_mist_volume.gdshader")
## 霧盤的面片比毒霧的範圍大一圈：邊緣用雜訊往裡外咬的時候不會被面片切出硬邊。
const DISC_OVERSCAN: float = 1.14

var zone: MistZone
var radius: float = 3.0
var source_id: String = "miasma"
var life: float = -1.0
## 有體積的那一團的顏色（預設綠；腐敗之森的瘴氣設成紫）。要在加進場景之前設。貼地霧盤的顏色在 shader 裡。
var tint: Color = VOLUME_ALBEDO
var _mats: Array[ShaderMaterial] = []
var _volume_mat: ShaderMaterial


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
		mesh.size = Vector2(radius, radius) * 2.0 * DISC_OVERSCAN * (1.0 - 0.08 * float(i))
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("layer", float(i) / float(LAYERS - 1))
		mat.set_shader_parameter("overscan", DISC_OVERSCAN)
		_mats.append(mat)
		var mi := MeshInstance3D.new()
		mi.name = "MistLayer%d" % i
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = 0.06 + LAYER_GAP * float(i)
		add_child(mi)
	_volume_mat = ShaderMaterial.new()
	_volume_mat.shader = VOLUME_SHADER
	_volume_mat.set_shader_parameter("density", VOLUME_DENSITY)
	_volume_mat.set_shader_parameter("albedo", tint)
	_volume_mat.set_shader_parameter("emission", VOLUME_EMISSION if tint == VOLUME_ALBEDO else tint * 0.2)
	_volume_mat.set_shader_parameter("fade", 1.0)
	_volume_mat.set_shader_parameter("ground_offset", VOLUME_HEIGHT * 0.4)
	var vol := FogVolume.new()
	vol.name = "MistVolume"
	vol.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	vol.size = Vector3(radius * 2.0, VOLUME_HEIGHT, radius * 2.0)
	vol.material = _volume_mat
	vol.position.y = VOLUME_HEIGHT * 0.4
	add_child(vol)


func _physics_process(delta: float) -> void:
	zone.center = global_position
	zone.tick(delta)
	var f: float = 1.0 if zone.life < 0.0 else clampf(zone.life / 0.6, 0.0, 1.0)
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("fade", f)
	_volume_mat.set_shader_parameter("fade", f)
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
