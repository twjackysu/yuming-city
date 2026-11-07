extends Node3D
## 開發用沙盒：冬夜小廣場，用來測移動、鏡頭、光霧（docs/design/03-art-audio-direction.md）。
## 環境在程式裡生成，之後霜橋鎮白盒會沿用同一套 FrostbridgeLook 設定。

const STONE: Color = Color(0.26, 0.28, 0.32)
const WALL: Color = Color(0.18, 0.19, 0.22)
const ROOF: Color = Color(0.11, 0.11, 0.13)
const SNOW: Color = Color(0.66, 0.71, 0.78)
const LAMP: Color = Color(0.95, 0.72, 0.42)
const MOON: Color = Color(0.55, 0.65, 0.85)

var _rng := RandomNumberGenerator.new()
## 北街（鐘樓附近）的房子；敲完九下後沉陷
var _north_houses: Array[Node3D] = []
var _north_collapsed: bool = false
var _bell: Node3D
var _bell_light: OmniLight3D


func _ready() -> void:
	_rng.seed = 9  # 固定種子：截圖前後可對照
	_build_environment()
	_build_ground()
	_build_houses()
	_build_bell_tower(Vector3(0.0, 0.0, -26.0))
	_build_arch(Vector3(0.0, 0.0, -9.0))
	for p: Vector3 in [Vector3(-3.5, 0, -4), Vector3(3.5, 0, -14), Vector3(-3.5, 0, -20)]:
		_build_lamp_post(p)
	_build_story_triggers()
	_build_cutscene_cameras()
	var dummy := TrainingDummy.new()
	dummy.name = "TrainingDummy"
	dummy.position = Vector3(-2.6, 0.0, -4.0)
	add_child(dummy)
	# 開發用：`-- --level=sandbox --enemies` 在街上放一隻灰巡者（正式遭遇戰在 M1.3 的霜橋鎮）
	var dev_args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	if dev_args.has("enemies"):
		var walker := Ashwalker.new()
		walker.name = "Ashwalker"
		walker.position = Vector3(2.0, 0.0, -12.0)
		if dev_args.has("insight"):
			walker.position = Vector3(1.6, 0.0, -3.5)
		add_child(walker)
		# 戰鬥沙盒帶席菈（正式劇情中她在霜橋鎮會合，M1.3）
		var sheila := Sheila.new()
		sheila.name = "Sheila"
		sheila.position = Vector3(-1.4, 0.0, 3.2)
		add_child(sheila)
	# 開發用：`--boss` 放送葬者（第一階段三招）＋席菈；正式戰鬥在 M1.3 霜橋鎮南街
	if dev_args.has("boss"):
		var boss := Undertaker.new()
		boss.name = "Undertaker"
		boss.position = Vector3(0.6, 0.0, -1.0) if dev_args.has("insight") else Vector3(0.0, 0.0, -6.0)
		add_child(boss)
		if not dev_args.has("enemies"):
			var ally := Sheila.new()
			ally.name = "Sheila"
			ally.position = Vector3(-1.4, 0.0, 3.2)
			add_child(ally)
	# 截圖用：`--insight` 一開始就按住看穿
	if dev_args.has("insight"):
		Input.action_press("insight")
	add_child(CutsceneView.new())
	Game.cutscene_started.connect(_on_cutscene_started)
	Game.cutscene_ended.connect(_on_cutscene_ended)
	if Game.session.state.get_flag("slice.north_street_collapsed", false):
		collapse_north_street(false)
	var spawn: Marker3D = $Spawn
	var player: Node3D = $Player
	player.global_transform = spawn.global_transform
	(player as PlayerController).snap_camera()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.38, 0.55)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.62, 0.68, 0.8)
	env.volumetric_fog_emission = Color(0.045, 0.06, 0.1)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 80.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = MOON
	moon.light_energy = 0.6
	moon.light_volumetric_fog_energy = 1.5
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.rotation_degrees = Vector3(-38.0, 35.0, 0.0)
	add_child(moon)


func _mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _box(size: Vector3, pos: Vector3, color: Color, collide: bool = true) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.material = _mat(color)
	b.use_collision = collide
	add_child(b)
	return b


func _build_ground() -> void:
	_box(Vector3(60.0, 1.0, 80.0), Vector3(0.0, -0.5, -20.0), STONE)
	# 積雪：路邊淺色帶
	_box(Vector3(5.0, 0.04, 70.0), Vector3(-7.5, 0.02, -20.0), SNOW, false)
	_box(Vector3(5.0, 0.04, 70.0), Vector3(7.5, 0.02, -20.0), SNOW, false)


func _build_houses() -> void:
	for side: float in [-1.0, 1.0]:
		var z: float = 4.0
		while z > -40.0:
			var w: float = _rng.randf_range(4.5, 6.5)
			var h: float = _rng.randf_range(4.0, 7.0)
			var d: float = _rng.randf_range(5.0, 6.5)
			var x: float = side * (5.0 + d * 0.5)
			# 每棟房子一個 Node3D，北街的房子之後要整棟沉下去
			var house := Node3D.new()
			house.position = Vector3(x, 0.0, z - w * 0.5)
			add_child(house)
			_box(Vector3(d, h, w), Vector3(0, h * 0.5, 0), WALL).reparent(house, false)
			_box(Vector3(d + 0.6, 0.35, w + 0.4), Vector3(0, h + 0.17, 0), ROOF, false).reparent(house, false)
			_box(Vector3(d + 0.5, 0.12, w + 0.3), Vector3(0, h + 0.4, 0), SNOW, false).reparent(house, false)
			if house.position.z < -24.0:
				house.set_meta("height", h)
				_north_houses.append(house)
			if _rng.randf() < 0.55:
				_window(Vector3(side * 5.02, _rng.randf_range(1.4, h - 1.2), z - w * 0.5), side)
			z -= w + _rng.randf_range(0.3, 1.2)


func _window(pos: Vector3, side: float) -> void:
	var glass := CSGBox3D.new()
	glass.size = Vector3(0.06, 0.9, 0.7)
	glass.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = LAMP
	m.emission_enabled = true
	m.emission = LAMP
	m.emission_energy_multiplier = 1.4
	glass.material = m
	add_child(glass)
	var l := OmniLight3D.new()
	l.light_color = LAMP
	l.light_energy = 0.45
	l.omni_range = 3.5
	l.light_volumetric_fog_energy = 0.6
	l.position = pos + Vector3(-side * 0.6, 0.0, 0.0)
	add_child(l)


func _build_lamp_post(pos: Vector3) -> void:
	_box(Vector3(0.14, 3.2, 0.14), pos + Vector3(0, 1.6, 0), ROOF)
	var bulb := CSGSphere3D.new()
	bulb.radius = 0.16
	bulb.position = pos + Vector3(0, 3.25, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = LAMP
	m.emission_enabled = true
	m.emission = LAMP
	m.emission_energy_multiplier = 6.0
	bulb.material = m
	add_child(bulb)
	var l := OmniLight3D.new()
	l.light_color = LAMP
	l.light_energy = 2.2
	l.omni_range = 9.0
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 1.4
	l.position = pos + Vector3(0, 3.0, 0)
	add_child(l)


func _build_bell_tower(pos: Vector3) -> void:
	_box(Vector3(4.0, 14.0, 4.0), pos + Vector3(0, 7.0, 0), WALL)
	_box(Vector3(4.8, 0.5, 4.8), pos + Vector3(0, 14.25, 0), ROOF)
	_box(Vector3(3.0, 3.0, 3.0), pos + Vector3(0, 16.0, 0), ROOF)
	var l := OmniLight3D.new()
	l.name = "BellLight"
	l.light_color = LAMP
	l.light_energy = 4.0
	l.omni_range = 16.0
	l.light_volumetric_fog_energy = 2.0
	l.position = pos + Vector3(0, 13.0, 2.6)
	add_child(l)
	_bell_light = l
	# 廢鐘：掛在鐘樓正面的橫梁下（之後換成正式模型）
	_box(Vector3(2.6, 0.18, 0.18), pos + Vector3(0, 15.9, 2.5), ROOF, false)
	_bell = Node3D.new()
	_bell.name = "Bell"
	_bell.position = pos + Vector3(0, 15.8, 2.5)
	add_child(_bell)
	var bronze := _mat(Color(0.32, 0.26, 0.18), 0.45)
	bronze.metallic = 0.8
	var body := CSGCylinder3D.new()
	body.radius = 0.75
	body.height = 1.1
	body.cone = true
	body.position = Vector3(0, -0.85, 0)
	body.material = bronze
	_bell.add_child(body)
	var crown := CSGSphere3D.new()
	crown.radius = 0.42
	crown.position = Vector3(0, -0.3, 0)
	crown.material = bronze
	_bell.add_child(crown)
	var glow := CSGBox3D.new()
	glow.size = Vector3(1.2, 1.8, 0.1)
	glow.position = pos + Vector3(0, 12.0, 2.02)
	var m := StandardMaterial3D.new()
	m.albedo_color = LAMP
	m.emission_enabled = true
	m.emission = LAMP
	m.emission_energy_multiplier = 4.0
	glow.material = m
	add_child(glow)


## 南街石拱（之後的九息物件；這裡只是外形）。
func _build_arch(pos: Vector3) -> void:
	var arch := CSGCombiner3D.new()
	arch.position = pos
	arch.use_collision = true
	add_child(arch)
	var block := CSGBox3D.new()
	block.size = Vector3(5.0, 4.6, 1.2)
	block.position = Vector3(0, 2.3, 0)
	block.material = _mat(Color(0.34, 0.33, 0.33))
	arch.add_child(block)
	var hole := CSGCylinder3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.radius = 1.6
	hole.height = 2.0
	hole.rotation_degrees = Vector3(90, 0, 0)
	hole.position = Vector3(0, 2.0, 0)
	arch.add_child(hole)
	var cut := CSGBox3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.size = Vector3(3.2, 2.0, 2.0)
	cut.position = Vector3(0, 1.0, 0)
	arch.add_child(cut)


## 暫時的劇情觸發區：讓「新遊戲 → 找到梨販 → 敲鐘」在沙盒裡能手動與自動驗證。
## 霜橋鎮白盒完成後由正式的互動（對話、敲鐘）取代。
func _build_story_triggers() -> void:
	var stall_pos := Vector3(3.0, 0.0, -2.5)
	_build_pear_stall(stall_pos)
	_trigger("PearSellerTrigger", stall_pos + Vector3(-0.8, 1.0, 0.0), Vector3(3.0, 2.0, 3.0), _on_pear_seller)
	_trigger("BellTowerTrigger", Vector3(0.0, 1.0, -22.8), Vector3(4.0, 2.0, 2.0), _on_bell_tower)


func _trigger(node_name: String, pos: Vector3, size: Vector3, action: Callable) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerController:
			action.call())
	add_child(area)
	return area


func _on_pear_seller() -> void:
	if not Game.session.state.get_flag("slice.met_pear_seller", false):
		Game.start_dialogue("slice_pear_seller")


func _on_bell_tower() -> void:
	if Game.session.quests.stage_of(GameSession.MAIN_QUEST) != "ring_bell" or Game.is_player_locked():
		return
	# 中途讀檔或重來時從第一下重新數
	Game.session.set_flag("slice.bell_rings", 0)
	Game.play_cutscene("slice_bell_nine")


## 過場鏡頭位置（CutsceneView 依名字找）。
func _build_cutscene_cameras() -> void:
	_camera_marker("BellCamWide", Vector3(2.6, 1.7, -7.0), Vector3(0.0, 13.0, -26.0))
	_camera_marker("BellCamRope", Vector3(2.2, 13.4, -19.8), Vector3(0.0, 15.2, -23.5))
	_camera_marker("NorthStreetCam", Vector3(-1.5, 10.0, -11.0), Vector3(0.0, 1.0, -34.0))


func _camera_marker(marker_name: String, pos: Vector3, target: Vector3) -> void:
	var m := Marker3D.new()
	m.name = marker_name
	add_child(m)
	m.look_at_from_position(pos, target)


func _on_cutscene_started(r: CutsceneRunner) -> void:
	r.event_fired.connect(_on_cutscene_event)


func _on_cutscene_event(event: String, _shot: Dictionary) -> void:
	match event:
		"ring", "ring_final":
			ring_bell_visual(event == "ring_final")
		"collapse":
			collapse_north_street(true)


func _on_cutscene_ended(_id: String, _skipped: bool) -> void:
	# 跳過時沒有 collapse 事件：照旗標補上結果
	if Game.session.state.get_flag("slice.north_street_collapsed", false) and not _north_collapsed:
		collapse_north_street(false)


## 鐘擺一下＋鐘樓的燈亮一下。
func ring_bell_visual(final: bool) -> void:
	if _bell == null:
		return
	Sfx.play_flat(self, "bell_ninth" if final else "bell", 0.0 if final else -3.0)
	var t := create_tween()
	t.tween_property(_bell, "rotation_degrees:x", 16.0 if final else 11.0, 0.12).set_trans(Tween.TRANS_SINE)
	t.tween_property(_bell, "rotation_degrees:x", -8.0, 0.35).set_trans(Tween.TRANS_SINE)
	t.tween_property(_bell, "rotation_degrees:x", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	var flash := create_tween()
	flash.tween_property(_bell_light, "light_energy", 14.0 if final else 9.0, 0.06)
	flash.tween_property(_bell_light, "light_energy", 4.0, 0.9)


## 北街陷落：鐘樓附近的房子沉下去、歪掉。animate=false 時直接放到最後狀態（讀檔、跳過）。
func collapse_north_street(animate: bool) -> void:
	_north_collapsed = true
	var i: int = 0
	for house: Node3D in _north_houses:
		var h: float = float(house.get_meta("height", 5.0))
		var end_pos: Vector3 = house.position + Vector3(0, -h * 0.65, 0)
		var tilt := Vector3(_rng.randf_range(-9, 9), 0, _rng.randf_range(-12, 12))
		if animate:
			var t := create_tween().set_parallel()
			t.tween_property(house, "position", end_pos, 1.6).set_delay(i * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_property(house, "rotation_degrees", tilt, 1.6).set_delay(i * 0.12)
		else:
			house.position = end_pos
			house.rotation_degrees = tilt
		i += 1


func is_north_collapsed() -> bool:
	return _north_collapsed


## 梨販的攤子：木桌、布篷、一盞暖燈、一個披斗篷的人影（之後換成角色）。
func _build_pear_stall(pos: Vector3) -> void:
	var wood := Color(0.24, 0.17, 0.12)
	_box(Vector3(1.6, 0.9, 0.8), pos + Vector3(0, 0.45, 0), wood)
	_box(Vector3(1.9, 0.06, 1.2), pos + Vector3(0, 2.1, 0.1), Color(0.32, 0.12, 0.1), false)
	for x: float in [-0.85, 0.85]:
		_box(Vector3(0.07, 2.1, 0.07), pos + Vector3(x, 1.05, 0.55), wood, false)
	# 梨：幾顆暖黃色小球
	var pear := _mat(Color(0.78, 0.66, 0.3), 0.6)
	for i: int in 6:
		var p := CSGSphere3D.new()
		p.radius = 0.09
		p.material = pear
		p.position = pos + Vector3(-0.5 + i * 0.2, 0.99, -0.1 + (i % 2) * 0.15)
		add_child(p)
	var figure := CSGCylinder3D.new()
	figure.radius = 0.32
	figure.height = 1.55
	figure.cone = true
	figure.material = _mat(Color(0.12, 0.12, 0.14))
	figure.position = pos + Vector3(0.3, 0.78, -0.75)
	add_child(figure)
	var head := CSGSphere3D.new()
	head.radius = 0.15
	head.material = _mat(Color(0.12, 0.12, 0.14))
	head.position = pos + Vector3(0.3, 1.62, -0.75)
	add_child(head)
	var l := OmniLight3D.new()
	l.light_color = LAMP
	l.light_energy = 1.4
	l.omni_range = 4.5
	l.light_volumetric_fog_energy = 1.0
	l.position = pos + Vector3(0, 1.85, 0.2)
	add_child(l)
