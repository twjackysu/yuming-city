class_name RescueSite
extends Node3D
## 北街陷落後的受困者（切片段落 3「救援」，docs/design/05-vertical-slice-plan.md）。
## 救援階段走近 → 按住互動鍵搬開瓦礫（HOLD_SEC 秒，放開歸零）→ 救出：
##   slice.rescued.<site_id>＝true、slice.rescued_count +1（影響死者名單與艾妲的態度）。
## 救出三人後任務進入「席菈」段落（slice_main.json），在送葬者戰之前還可以繼續救。
## 讀檔後已救出的點只剩散開的碎石，不能再救。
## 提示「按住 A　搬開瓦礫」＋按住進度在 HUD 下方中央（InteractPrompt，D-065），不在瓦礫上浮 3D 文字。

signal rescued(site_id: String)

const HOLD_SEC: float = 1.6
const RANGE: float = 2.2
## 可以救人的任務階段
const STAGES: PackedStringArray = ["rescue", "meet_sheila"]

@export var site_id: String = "a"
var hold: float = 0.0
var _player: PlayerController
var _rubble: Node3D
var _person: Node3D
var _lamp: Node3D
var _glow: OmniLight3D
var _shroud: MeshInstance3D
var _prompt_on: bool = false
var _done: bool = false
## 搬瓦礫的刮石聲間隔與次數（測試用）
const SCRAPE_EVERY: float = 0.35
var scrape_count: int = 0


func _ready() -> void:
	add_to_group("rescue_sites")
	add_to_group("interact_prompts")
	_build()
	_done = bool(_state().get_flag(flag_key(), false))
	if _done:
		_show_cleared()


func flag_key() -> String:
	return "slice.rescued." + site_id


func _state() -> GameState:
	return Game.session.state if Game.session != null else GameState.new()


func is_rescued() -> bool:
	return _done


func is_available() -> bool:
	if _done or Game.session == null:
		return false
	return Game.session.quests.stage_of(GameSession.MAIN_QUEST) in STAGES


func prompt_shown() -> bool:
	return _prompt_on


## HUD 的互動提示（InteractPrompt）：走近時「按住 {key}　搬開瓦礫」＋按住進度。
func interact_hint() -> Dictionary:
	if not _prompt_on:
		return {}
	return {"fmt": TranslationServer.translate("RESCUE_HOLD_HINT"), "action": "interact", "progress": clampf(hold / HOLD_SEC, 0.0, 1.0)}


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		for n: Node in get_tree().get_nodes_in_group("player"):
			_player = n as PlayerController
			break
	var near: bool = is_available() and _player != null and not Game.is_player_locked() \
		and _player.global_position.distance_to(global_position) <= RANGE
	_prompt_on = near
	update_hold(delta, near and Input.is_action_pressed("interact"))


## 按住／放開。按滿 HOLD_SEC 救出；回傳是否在這一幀救出。
func update_hold(delta: float, pressed: bool) -> bool:
	if not is_available():
		hold = 0.0
		return false
	var before: float = hold
	hold = hold + delta if pressed else 0.0
	# 搬的時候每 0.35 秒刮一下石頭（第一下立刻響）
	if pressed and is_inside_tree() and (before == 0.0 or floorf(hold / SCRAPE_EVERY) > floorf(before / SCRAPE_EVERY)):
		Sfx.play_at(self, "rubble_scrape", global_position + Vector3.UP * 0.4, -6.0, 0.12, 8.0)
		scrape_count += 1
	# 搬的時候瓦礫跟著晃
	_rubble.position = Vector3(sin(hold * 40.0), 0.0, cos(hold * 33.0)) * 0.03 * minf(hold, 1.0) if hold > 0.0 else Vector3.ZERO
	if hold >= HOLD_SEC:
		rescue()
		return true
	return false


func rescue() -> void:
	if _done:
		return
	_done = true
	hold = 0.0
	_prompt_on = false
	if Game.session != null:
		Game.session.set_flag(flag_key(), true)
		Game.session.add_flag("slice.rescued_count")
	if is_inside_tree():
		Sfx.play_at(self, "blunt_weak", global_position + Vector3.UP * 0.5, -4.0, 0.05, 10.0)
		var t := create_tween().set_parallel()
		var i: int = 0
		for c: Node in _rubble.get_children():
			var n: Node3D = c as Node3D
			var away: Vector3 = Vector3(n.position.x, 0.0, n.position.z).normalized() * 1.2
			t.tween_property(n, "position", n.position + away - Vector3(0, 0.15, 0), 0.5).set_delay(i * 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			i += 1
		# 被拉起來、站好，然後被扶往南邊（先淡出，傷者車隊在送葬者戰再出現）
		t.tween_property(_person, "rotation_degrees:z", 0.0, 0.7).set_delay(0.35)
		t.tween_property(_person, "position", Vector3(0.0, 0.0, 0.0), 0.7).set_delay(0.35)
		t.chain().tween_property(_person, "scale", Vector3(1, 0.001, 1), 0.4).set_delay(1.2)
	else:
		_show_cleared()
	rescued.emit(site_id)


## 第 1 章白天的霜橋鎮（D-170）：昨晚的現場隔天早上的樣子。掉在一旁的提燈熄了、收走了；
## 沒救出來的人已經被挖出來，躺在原地、蓋著一塊布（瓦礫推到旁邊）。救出來的點照舊只剩散開的碎石。
func set_aftermath() -> void:
	_lamp.visible = false
	_glow.visible = false
	if _done or _shroud != null:
		return
	_show_cleared()
	_shroud = MeshInstance3D.new()
	_shroud.name = "Shroud"
	_shroud.mesh = shroud_mesh()
	var cloth := StandardMaterial3D.new()
	# 舊毛毯的暗紅褐（米白的布在雪地上幾乎看不見）
	cloth.albedo_color = Color(0.4, 0.29, 0.24)
	cloth.roughness = 0.97
	_shroud.material_override = cloth
	# 每個人擺的方向不太一樣（±25°）
	_shroud.rotation.y = deg_to_rad(float(absi(hash(site_id)) % 50) - 25.0)
	# 挖出來之後往街中間挪一點（離開塌下來的牆腳，從街上看得到）
	if is_inside_tree():
		_shroud.position.x = -signf(global_position.x) * 0.7
	add_child(_shroud)


func is_covered() -> bool:
	return _shroud != null and _shroud.visible


## 蓋在人身上的布（高度場，本地座標：長邊沿 Z，頭在 -Z）：身體用幾個橢球的包絡（頭、胸、腰、兩條腿、腳尖）
## 撐起來，布往外多垂一圈、慢慢落到地面，落地的地方有幾道皺褶。
static func shroud_mesh() -> ArrayMesh:
	const HALF_X: float = 0.55
	const HALF_Z: float = 1.12
	const NX: int = 22
	const NZ: int = 44
	# [中心 x, 中心 z, 半寬, 半長, 高]
	var parts: Array[PackedFloat32Array] = [
		PackedFloat32Array([0.0, -0.78, 0.12, 0.13, 0.2]),
		PackedFloat32Array([0.0, -0.36, 0.23, 0.3, 0.24]),
		PackedFloat32Array([0.0, 0.02, 0.2, 0.16, 0.2]),
		PackedFloat32Array([-0.1, 0.45, 0.09, 0.36, 0.14]),
		PackedFloat32Array([0.1, 0.45, 0.09, 0.36, 0.14]),
		PackedFloat32Array([-0.1, 0.86, 0.06, 0.06, 0.17]),
		PackedFloat32Array([0.1, 0.86, 0.06, 0.06, 0.17]),
	]
	var heights := PackedFloat32Array()
	heights.resize((NX + 1) * (NZ + 1))
	for j: int in NZ + 1:
		for i: int in NX + 1:
			var x: float = lerpf(-HALF_X, HALF_X, float(i) / NX)
			var z: float = lerpf(-HALF_Z, HALF_Z, float(j) / NZ)
			var h: float = 0.0
			var near: float = 0.0
			for p: PackedFloat32Array in parts:
				# 布比身體寬一圈（+0.09 m），用平滑的鐘形落下，兩腿之間被布撐平
				var dx: float = (x - p[0]) / (p[2] + 0.09)
				var dz: float = (z - p[1]) / (p[3] + 0.09)
				var r: float = sqrt(dx * dx + dz * dz)
				var k: float = 1.0 - smoothstep(0.0, 1.0, r)
				h = maxf(h, p[4] * sqrt(maxf(k, 0.0)))
				near = maxf(near, 1.0 - smoothstep(0.8, 1.6, r))
			# 落地的布：幾道皺褶，邊緣貼地
			var fold: float = (sin(x * 23.0 + z * 6.0) * 0.5 + 0.5) * 0.012 + (sin(z * 17.0 - x * 9.0) * 0.5 + 0.5) * 0.008
			var edge: float = minf(minf(HALF_X - absf(x), HALF_Z - absf(z)) / 0.12, 1.0)
			heights[j * (NX + 1) + i] = maxf(h, fold * (1.0 - near * 0.6) * edge) + 0.012
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in NZ:
		for i: int in NX:
			var quad: Array[Vector3] = []
			for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var ii: int = i + o.x
				var jj: int = j + o.y
				quad.append(Vector3(lerpf(-HALF_X, HALF_X, float(ii) / NX), heights[jj * (NX + 1) + ii],
					lerpf(-HALF_Z, HALF_Z, float(jj) / NZ)))
			# 從上往下看是順時針（Godot 的正面）
			for v: Vector3 in [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _show_cleared() -> void:
	_person.visible = false
	for c: Node in _rubble.get_children():
		var n: Node3D = c as Node3D
		n.position += Vector3(n.position.x, 0.0, n.position.z).normalized() * 1.2 - Vector3(0, 0.15, 0)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(site_id)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.22, 0.21, 0.22)
	stone.roughness = 0.95
	var beam := StandardMaterial3D.new()
	beam.albedo_color = Color(0.2, 0.14, 0.1)
	_rubble = Node3D.new()
	_rubble.name = "Rubble"
	add_child(_rubble)
	for i: int in 7:
		var b := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(rng.randf_range(0.35, 0.8), rng.randf_range(0.2, 0.45), rng.randf_range(0.3, 0.7))
		b.mesh = m
		b.material_override = stone
		b.position = Vector3(rng.randf_range(-0.7, 0.7), m.size.y * 0.5 + rng.randf_range(0.0, 0.25), rng.randf_range(-0.6, 0.6))
		b.rotation_degrees = Vector3(rng.randf_range(-15, 15), rng.randf_range(0, 90), rng.randf_range(-15, 15))
		_rubble.add_child(b)
	var plank := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(2.2, 0.16, 0.22)
	plank.mesh = pm
	plank.material_override = beam
	plank.position = Vector3(0.1, 0.45, 0.05)
	plank.rotation_degrees = Vector3(0, rng.randf_range(-30, 30), 12)
	_rubble.add_child(plank)
	# 受困的人：側倒在瓦礫下
	_person = Node3D.new()
	_person.name = "Person"
	_person.position = Vector3(0.0, 0.25, 0.0)
	_person.rotation_degrees = Vector3(0, 0, 90)
	add_child(_person)
	# 程序人偶整個人側倒（_person 轉 90°），救出來時跟著 _person 轉正、站起來
	var who := Puppet.new()
	who.name = "Puppet"
	who.coat_color = Color(0.3, 0.26, 0.22)
	who.trim_color = Color(0.24, 0.2, 0.16)
	_person.add_child(who)
	var hammer: Node = who.hand("R").get_node_or_null("BellHammer") if who.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()
	# 掉在一旁的提燈：在黑暗的廢墟裡指出有人
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.95, 0.72, 0.42)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(0.95, 0.72, 0.42)
	lamp_mat.emission_energy_multiplier = 3.0
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.08
	lm.height = 0.16
	lamp.mesh = lm
	lamp.material_override = lamp_mat
	lamp.position = Vector3(0.9, 0.1, 0.5)
	_rubble.add_child(lamp)
	_lamp = lamp
	var glow := OmniLight3D.new()
	_glow = glow
	glow.light_color = Color(0.95, 0.72, 0.42)
	glow.light_energy = 1.5
	glow.omni_range = 3.6
	glow.light_volumetric_fog_energy = 0.8
	glow.position = Vector3(0.8, 0.4, 0.4)
	add_child(glow)
