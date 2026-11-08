extends StoryLevel
## 開發用沙盒：一條直街，用來測移動、鏡頭、光霧、戰鬥（docs/design/03-art-audio-direction.md）。
## 正式關卡是霜橋鎮（scenes/levels/frostbridge.gd）；劇情邏輯兩邊共用 StoryLevel，環境共用 FrostbridgeLook。
## 沙盒保留一個方塊一個 CSG 的寫法（方便改），霜橋鎮用 StaticBatch 合併。

const STONE: Color = FrostbridgeLook.STONE
const WALL: Color = FrostbridgeLook.WALL
const ROOF: Color = FrostbridgeLook.ROOF
const SNOW: Color = FrostbridgeLook.SNOW
const LAMP: Color = FrostbridgeLook.LAMP


func _ready() -> void:
	_rng.seed = 9  # 固定種子：截圖前後可對照
	_build_environment()
	_build_ground()
	_build_houses()
	_build_bell_tower(Vector3(0.0, 0.0, -26.0))
	arch_site = NineBreathSite.new()
	arch_site.name = "SouthArch"
	arch_site.position = Vector3(0.0, 0.0, -9.0)
	add_child(arch_site)
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
		# 截圖用：`--enemies --felled` 灰巡者面向諾恩被打倒，停在撲倒那一刻（D-054）
		if dev_args.has("felled"):
			walker.position = Vector3(0.8, 0.0, -4.0)
			_debug_felled_walker.call_deferred(walker)
		# 戰鬥沙盒帶席菈（正式劇情中她在霜橋鎮會合，M1.3）
		var sheila := Sheila.new()
		sheila.name = "Sheila"
		sheila.position = Vector3(-1.4, 0.0, 3.2)
		add_child(sheila)
	# 開發用：`--boss` 放送葬者＋席菈；`--caravan` 加傷者車隊；`--convoy`＝兩個都放（M1.2 驗收：打完送葬者戰）；
	# `--phase2` 送葬者直接進第二階段。正式戰鬥在 M1.3 霜橋鎮南街
	if dev_args.has("boss") or dev_args.has("convoy"):
		spawn_convoy_fight(dev_args.has("caravan") or dev_args.has("convoy"), not dev_args.has("enemies"),
			Vector3(0.6, 0.0, -1.0) if dev_args.has("insight") else Vector3(0.0, 0.0, -6.0))
	if dev_args.has("phase2") and has_node("Undertaker"):
		($Undertaker as Undertaker).enter_phase_two.call_deferred()
	# 截圖用：`--insight` 一開始就按住看穿
	if dev_args.has("insight"):
		Input.action_press("insight")
	# 截圖用：`--lock` 一開始就鎖定最近的敵人
	if dev_args.has("lock"):
		($Player as PlayerController).toggle_lock.call_deferred()
	_init_story()
	var spawn: Marker3D = $Spawn
	var player: Node3D = $Player
	player.global_transform = spawn.global_transform
	# 截圖用：`--arch=preview|restored|spent` 諾恩站在南街石拱前
	if dev_args.has("arch"):
		player.global_position = Vector3(-0.6, 0.0, -4.6)
		(player as PlayerController).yaw = deg_to_rad(-8.0)
		match str(dev_args["arch"]):
			"preview":
				arch_site.debug_preview = true
			"restored":
				arch_site.activate.call_deferred()
			"spent":
				arch_site.activate()
				arch_site.nb.tick(9.5, Game.session.state)
	(player as PlayerController).snap_camera()


func _build_environment() -> void:
	FrostbridgeLook.build_environment(self)


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


## 暫時的劇情觸發區：讓「新遊戲 → 找到梨販 → 敲鐘」在沙盒裡能手動與自動驗證。
## 霜橋鎮白盒完成後由正式的互動（對話、敲鐘）取代。
func _build_story_triggers() -> void:
	var stall_pos := Vector3(3.0, 0.0, -2.5)
	_build_pear_stall(stall_pos)
	_trigger("PearSellerTrigger", stall_pos + Vector3(-0.8, 1.0, 0.0), Vector3(3.0, 2.0, 3.0), _on_pear_seller)
	_trigger("BellTowerTrigger", Vector3(0.0, 1.0, -22.8), Vector3(4.0, 2.0, 2.0), _on_bell_tower)


## 過場鏡頭位置（CutsceneView 依名字找）。
func _build_cutscene_cameras() -> void:
	_camera_marker("BellCamWide", Vector3(2.6, 1.7, -7.0), Vector3(0.0, 13.0, -26.0))
	_camera_marker("BellCamRope", Vector3(2.2, 13.4, -19.8), Vector3(0.0, 15.2, -23.5))
	_camera_marker("NorthStreetCam", Vector3(-1.5, 10.0, -11.0), Vector3(0.0, 1.0, -34.0))


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


## 截圖用：灰巡者轉向諾恩、被打倒並停在撲倒那一刻；藏起諾恩（鏡頭在他正後方）。
func _debug_felled_walker(walker: Ashwalker) -> void:
	walker._body.rotation.y = PI
	walker.debug_hold_fallen = true
	walker.health.apply_damage(walker.health.hp, {"stagger": 0.0})
	for v: Node in ($Player as Node).find_children("*", "GeometryInstance3D", true, false):
		(v as GeometryInstance3D).visible = false
