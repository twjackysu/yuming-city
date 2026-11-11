extends TestCase
## 霜橋鎮（只有鎮本身，不開新遊戲、不掛劇情）：關卡結構、合併後的 draw call 規模、街道與廣場的擺設、開發用旗標。
## 劇情（開場到貨梯）的測試在 test_reboot_*.gd。

const PATH: String = "res://scenes/levels/frostbridge.tscn"

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_fb_%d" % Time.get_ticks_usec()
	_original = tree.root.get_node("Game").get("session") as GameSession


func after_each() -> void:
	tree.root.get_node("Game").set("session", _original)
	tree.root.get_node("Game").set("dialogue", null)
	for d: String in [_dir, _dir + "_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)


func _session() -> GameSession:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	return s


## 有劇情的 session，推到 at 那一段（"market"＝守衛打完、藥拿了，席菈跟在諾恩旁邊）。
func _story_session(at: String) -> GameSession:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	s.new_reboot_game()
	RebootOpening.dev_advance(s, at)
	return s


func _load() -> StoryLevel:
	var level: StoryLevel = (load(PATH) as PackedScene).instantiate() as StoryLevel
	tree.root.add_child(level)
	await tree.physics_frame
	return level


func _free(level: Node) -> void:
	level.queue_free()
	await tree.process_frame
	await tree.process_frame


func test_layout_nodes_and_batching() -> void:
	_session()
	var level: StoryLevel = await _load()
	for n: String in ["Player", "Hud", "PauseMenu", "DialogueBox", "Town", "SouthArch", "Bell"]:
		assert_true(level.has_node(n), "有 %s" % n)
	assert_false(level.has_node("RebootOpening"), "沒有開新遊戲：只有鎮，不掛劇情")
	for old: String in ["BellTowerTrigger", "ConvoyTrigger", "ArchMemoryTrigger", "BellCamWide", "JournalView"]:
		assert_false(level.has_node(old), "舊劇情的 %s 已經拿掉（D-220）" % old)
	var town: Node = level.get_node("Town")
	var meshes: int = 0
	for c: Node in town.get_children():
		if c is MeshInstance3D:
			meshes += 1
	assert_true(meshes > 3 and meshes <= 24, "整個小鎮合併成少數幾個 mesh（實際 %d）" % meshes)
	var wet: int = 0
	var timber: int = 0
	for c: Node in town.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi == null:
			continue
		var sm: ShaderMaterial = mi.material_override as ShaderMaterial
		if sm != null and sm.shader.resource_path == FrostbridgeLook.WET_COBBLE_SHADER:
			wet += 1
		if sm != null and sm.shader.resource_path == FrostbridgeLook.HALF_TIMBER_SHADER:
			timber += 1
	# D-066：全部的窗（房子＋塔窗）合併成一個 mesh、用窗框＋窗櫺的 shader，每扇窗的資料在頂點色
	var windows: Array[MeshInstance3D] = []
	for c: Node in town.get_children():
		var wm: MeshInstance3D = c as MeshInstance3D
		if wm == null:
			continue
		var wsm: ShaderMaterial = wm.material_override as ShaderMaterial
		if wsm != null and wsm.shader.resource_path == FrostbridgeLook.WINDOW_SHADER:
			windows.append(wm)
	assert_eq(windows.size(), 1, "窗共用一個材質、合併成一個 mesh")
	var win_count: int = int(level.get("window_count"))
	var lit_count: int = int(level.get("lit_window_count"))
	assert_true(win_count > 30, "小鎮有不少窗（%d）" % win_count)
	assert_true(lit_count > win_count / 5 and lit_count < win_count * 3 / 4, "有亮有暗（%d／%d 亮）" % [lit_count, win_count])
	if windows.size() == 1:
		var arrays: Array = windows[0].mesh.surface_get_arrays(0)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		assert_eq(colors.size(), (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "每個頂點都有窗的資料")
		var curtains: int = 0
		var lit_verts: int = 0
		for col: Color in colors:
			if col.r > 0.5:
				lit_verts += 1
				if col.b > 0.1:
					curtains += 1
		assert_true(lit_verts > 0 and curtains > 0 and curtains < lit_verts, "部分亮窗拉了窗簾（%d／%d 頂點）" % [curtains, lit_verts])
	# D-068：雪（街邊雪帶、屋頂、井沿）用積雪 shader，不再是平的淺色
	var snow_meshes: int = 0
	var plain_snow: int = 0
	for c: Node in town.get_children():
		var sm2: MeshInstance3D = c as MeshInstance3D
		if sm2 == null:
			continue
		var ssm: ShaderMaterial = sm2.material_override as ShaderMaterial
		if ssm != null and ssm.shader.resource_path == FrostbridgeLook.SNOW_SHADER:
			snow_meshes += 1
		var std: StandardMaterial3D = sm2.material_override as StandardMaterial3D
		if std != null and std.albedo_color.is_equal_approx(FrostbridgeLook.SNOW):
			plain_snow += 1
	assert_eq(snow_meshes, 1, "雪共用一個積雪材質")
	# D-070：門是木板＋鐵條的 shader，全部共用一個材質
	var door_meshes: int = 0
	for c: Node in town.get_children():
		var dm: MeshInstance3D = c as MeshInstance3D
		if dm != null and dm.material_override is ShaderMaterial \
				and (dm.material_override as ShaderMaterial).shader.resource_path == FrostbridgeLook.DOOR_SHADER:
			door_meshes += 1
	assert_eq(door_meshes, 1, "門共用一個材質、合併成一個 mesh")
	assert_true(int(level.get("door_count")) > 15, "每棟房子都有門（%d）" % int(level.get("door_count")))
	# D-077：攤桌＋三個木箱用門的 shader（木箱模式），跟門合併在同一個 mesh；廣場中央石框＋鐘紋；井有燈
	assert_eq(int(level.get("stall_crates")), 4, "攤桌＋三個疊著的木箱")
	assert_eq(int(level.get("street_lanterns")), 10, "十盞路燈都是方形燈籠（D-080）")
	assert_eq(int(level.get("plaza_ring_parts")), 5, "廣場石框：石縫、石緣、內圈鋪石、石盤、鐘的剪影（D-130，不再是靶心的四圈）")
	var well_light: OmniLight3D = level.get("well_light") as OmniLight3D
	assert_not_null(well_light, "井的木架上掛一盞小燈")
	if well_light != null:
		assert_false(well_light.shadow_enabled, "井的小燈不投影")
		assert_true(well_light.omni_range < 4.0, "井的小燈範圍小（%.1f）" % well_light.omni_range)
		assert_true(well_light.global_position.distance_to(Vector3(-6.0, 1.7, -3.5)) < 1.5, "燈在井旁")
	assert_eq(plain_snow, 0, "沒有平的淺色雪")
	assert_true(wet >= 2, "街道與廣場是濕石板路（%d 個合併 mesh）" % wet)
	assert_true(timber >= 3, "房子是半木構外牆、後牆與城牆是石牆（%d 個合併 mesh）" % timber)
	assert_true((town.get_node("Collision") as StaticBody3D).get_child_count() > 60, "房子都有碰撞")
	assert_true(level._north_houses.size() >= 4, "北街至少四棟可以陷落的房子")
	assert_true(int(level.get("light_count")) <= 40, "燈的數量有上限（%d）" % int(level.get("light_count")))
	# 石階兩側的矮石燈柱（D-062）：底下一對、台地邊一對，都在街道兩側、不擋中間的路
	var lanterns: Array = level.get("step_lanterns")
	assert_eq(lanterns.size(), 4, "石階兩側四盞矮燈")
	for l: OmniLight3D in lanterns:
		assert_true(absf(l.position.x) > 3.0 and absf(l.position.x) < 4.0, "燈柱貼著街邊（x=%.2f）" % l.position.x)
		assert_true(l.position.z > -30.0 and l.position.z < -24.5, "燈柱在石階頭尾（z=%.2f）" % l.position.z)
		assert_false(l.shadow_enabled, "矮燈不投影")
	assert_true(int(level.get("lantern_count")) >= 6, "不少房子門口有掛燈（%d）" % int(level.get("lantern_count")))
	# 鐘室（D-081）：車床做的鐘身＋三道紋帶＋木頭鐘架都掛在 Bell 底下（敲鐘時一起擺）；背面與兩側百葉
	var bell: Node3D = level.get_node("Bell") as Node3D
	var bell_body: MeshInstance3D = bell.get_node("BellBody") as MeshInstance3D
	assert_true(bell_body.mesh is ArrayMesh, "鐘身是旋轉出來的鐘形，不是圓柱")
	assert_true(bell.has_node("BellBand0") and bell.has_node("BellBand2"), "鐘身有紋帶")
	assert_true(bell.has_node("BellYoke"), "鐘吊在木頭鐘架上")
	# 鐘鈕（D-121）：鐘身往下移，鐘頂與鐘架之間是鐘冠＋兩個交叉的環（環往上穿進鐘架）
	assert_true(bell.has_node("BellCrown") and bell.has_node("BellLoop0") and bell.has_node("BellLoop1"), "鐘頂有鐘鈕")
	var drop: float = level.get("BELL_DROP")
	assert_true(drop > 0.1 and is_equal_approx(bell_body.position.y, -drop), "鐘身在鐘架底下（%.2f）" % bell_body.position.y)
	var yoke_bottom: float = (bell.get_node("BellYoke") as Node3D).position.y - ((bell.get_node("BellYoke") as MeshInstance3D).mesh as BoxMesh).size.y * 0.5
	var loop: MeshInstance3D = bell.get_node("BellLoop0") as MeshInstance3D
	var loop_top: float = loop.position.y + (loop.mesh as TorusMesh).outer_radius
	assert_true(loop_top > yoke_bottom, "環穿進鐘架（環頂 %.2f、鐘架底 %.2f）" % [loop_top, yoke_bottom])
	assert_true(loop.position.y - (loop.mesh as TorusMesh).outer_radius < -drop + 0.1, "環的底部埋在鐘冠裡")
	assert_eq(int(level.get("belfry_louvres")), 24, "鐘室背面與兩側各 8 片百葉")
	assert_false(level.has_node("Sheila"), "只有鎮：沒有席菈")
	assert_false(level.has_node("Undertaker"), "只有鎮：沒有送葬者")
	await _free(level)


## 水窪倒影（D-051）：廣場、主街、南街各一個只拍一次的 ReflectionProbe，只拍小鎮的靜態幾何。
func test_puddle_reflection_probes() -> void:
	_session()
	var level: StoryLevel = await _load()
	var layer: int = int(level.get("REFLECT_LAYER"))
	var spots: Dictionary = {"ProbePlaza": Vector3(3.0, 0.0, 2.0), "ProbeMain": Vector3(0.0, 0.0, -16.0),
		"ProbeSouth": Vector3(0.0, 0.0, 22.0)}
	for n: String in spots:
		assert_true(level.has_node(n), "有 %s" % n)
		var p: ReflectionProbe = level.get_node(n) as ReflectionProbe
		assert_eq(p.update_mode, ReflectionProbe.UPDATE_ONCE, "%s 只在載入時拍一次" % n)
		assert_true(p.box_projection, "%s 用盒狀投影（街道兩側的房子對得上）" % n)
		assert_eq(p.cull_mask, layer, "%s 只拍倒影層" % n)
		var local: Vector3 = (spots[n] as Vector3) - p.position
		var half: Vector3 = p.size * 0.5
		assert_true(absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z,
			"%s 的盒子包住地面（%s）" % [n, spots[n]])
		var eye: Vector3 = p.origin_offset
		assert_true(absf(eye.y) < half.y, "%s 的拍攝點在盒子裡" % n)
	var town_ok: bool = true
	for c: Node in level.get_node("Town").get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi != null and (mi.layers & layer) == 0:
			town_ok = false
	assert_true(town_ok, "小鎮合併後的 mesh 都在倒影層（路燈、掛燈、亮窗都映得出來）")
	var actor_in_layer: bool = false
	for c: Node in level.get_node("Player").find_children("*", "VisualInstance3D", true, false):
		if ((c as VisualInstance3D).layers & layer) != 0:
			actor_in_layer = true
	assert_false(actor_in_layer, "諾恩不在倒影層（不會被凍在載入那一刻的倒影裡）")
	# D-058：路燈、門邊掛燈、梨販燈的高光比預設強（濕石板上的燈影）；窗裡透出的小補光維持預設
	var bright: int = 0
	var spec: float = float(level.get("LAMP_SPECULAR"))
	for l: Node in level.find_children("*", "OmniLight3D", true, false):
		if is_equal_approx((l as OmniLight3D).light_specular, spec):
			bright += 1
	assert_true(spec > 0.5, "燈的高光比 Godot 預設 0.5 強")
	assert_true(bright >= 8, "路燈與掛燈都加強了高光（%d 盞）" % bright)
	var cobble: Shader = load(FrostbridgeLook.WET_COBBLE_SHADER) as Shader
	assert_true(cobble.code.contains("ripple_strength"), "水窪有細波紋（倒影拉成直條）")
	# D-095：石板是平的（只在邊緣一圈倒角）、長短不一、每塊有自己的傾斜，不是整片鼓起的一樣大方塊
	var bevel: float = _uniform_default(cobble.code, "bevel_width")
	var lean: float = _uniform_default(cobble.code, "stone_lean")
	assert_true(bevel > 0.0 and bevel <= 0.15, "石板倒角只在邊緣一圈（%.2f 塊寬）" % bevel)
	assert_true(lean > 0.0, "每塊石板有自己的小傾斜（濕路上有的反光、有的暗）")
	assert_true(cobble.code.contains("split_y") and cobble.code.contains("STONE_LEN"), "排寬不一、石板長短不一")
	await _free(level)


## 從 shader 原始碼讀 uniform 的預設值（headless 的 RenderingServer 讀不到預設值）
func _uniform_default(code: String, uniform_name: String) -> float:
	var re := RegEx.new()
	re.compile("uniform\\s+float\\s+" + uniform_name + "\\s*(?::[^=]*)?=\\s*([0-9.]+)")
	var m: RegExMatch = re.search(code)
	return float(m.get_string(1)) if m != null else -1.0


func test_objective_guide_points_to_current_target() -> void:
	_story_session("market")
	var level: StoryLevel = await _load()
	var hud: Hud = level.get_node("Hud") as Hud
	# 劇情控制器停住：這裡只看指引，不要走近梨攤就開始跟艾妲說話
	var rb: Node = level.get_node("RebootOpening")
	rb.set_process(false)
	rb.set_physics_process(false)
	var player: Node3D = level.get_node("Player") as Node3D
	player.global_position = Vector3(0.0, 0.05, 7.0)
	for i: int in 3:
		await tree.process_frame
	var stall: Vector3 = (level.get_node("PearSellerTrigger") as Node3D).global_position
	var expect: float = Vector2(stall.x - player.global_position.x, stall.z - player.global_position.z).length()
	assert_true(hud.guide.shown, "守衛打完之後指向梨攤（艾妲）")
	assert_true(absf(hud.guide.distance - expect) < 0.5, "距離是到梨攤的水平距離（%.1f／%.1f）" % [hud.guide.distance, expect])
	var settings: Node = tree.root.get_node("Settings")
	settings.set("objective_marker", false)
	await tree.process_frame
	assert_false(hud.guide.shown, "設定關掉就不顯示")
	settings.set("objective_marker", true)
	await tree.process_frame
	assert_true(hud.guide.shown, "設定開回來又有了")
	# 走到目標旁邊就不顯示
	player.global_position = Vector3(stall.x, level.ground_y(stall) + 0.05, stall.z + 1.0)
	await tree.process_frame
	assert_false(hud.guide.shown, "到了目標旁邊就不顯示")
	await _free(level)


func test_player_walks_on_plaza_and_is_boxed_in() -> void:
	_session()
	var level: StoryLevel = await _load()
	var player: PlayerController = level.get_node("Player") as PlayerController
	assert_true(player.global_position.distance_to(Vector3(0, 0.05, 7)) < 0.5, "新遊戲在廣場南邊出生")
	for i: int in 10:
		await tree.physics_frame
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	for i: int in 30:
		await tree.physics_frame
	Input.action_release("move_forward")
	assert_true(player.global_position.z < start.z - 0.5, "往北走（%s → %s）" % [start, player.global_position])
	assert_true(absf(player.global_position.y) < 0.3, "站在地上（y=%.2f）" % player.global_position.y)
	# 往西一直走會被廣場西側的房子擋住
	player.global_position = Vector3(-8.0, 0.05, 0.0)
	Input.action_press("move_left")
	for i: int in 90:
		await tree.physics_frame
	Input.action_release("move_left")
	assert_true(player.global_position.x > -11.5, "出不了廣場（x=%.2f）" % player.global_position.x)
	await _free(level)


## 主街往鐘樓爬坡——北段四級石階上到台地，北街、鐘樓都在台地上。
func test_player_climbs_steps_to_north_street() -> void:
	_session()
	var level: StoryLevel = await _load()
	var player: PlayerController = level.get_node("Player") as PlayerController
	var rise: float = float(level.get("RISE"))
	assert_true(rise > 0.5, "北街台地比主街高（%.2f m）" % rise)
	assert_eq(level.ground_y(Vector3(0, 0, -20)), 0.0, "主街南段是平地")
	assert_eq(level.ground_y(Vector3(0, 0, -40)), rise, "北街在台地上")
	player.global_position = Vector3(0.0, 0.05, -21.0)
	player.yaw = 0.0
	for i: int in 5:
		await tree.physics_frame
	Input.action_press("move_forward")
	for i: int in 420:
		await tree.physics_frame
		if player.global_position.z < -33.0:
			break
	Input.action_release("move_forward")
	assert_true(player.global_position.z < -31.0, "走上石階到北街（停在 %s）" % player.global_position)
	assert_true(absf(player.global_position.y - rise) < 0.25, "站在台地上（y=%.2f）" % player.global_position.y)
	await _free(level)


## 截圖旗標 `--face=sheila`：每幀把諾恩與鏡頭轉向席菈。
func test_dev_face_turns_player_to_target() -> void:
	_story_session("market")
	var level: StoryLevel = await _load()
	var player: PlayerController = level.get_node("Player") as PlayerController
	var sheila: Node3D = level.get_node("Sheila") as Node3D
	assert_true(level.call("dev_face_target", "nobody") == null, "不認得的名字沒有目標")
	assert_true(level.call("dev_face_target", "undertaker") == null, "守衛已經倒下：沒有送葬者可以看")
	assert_eq(level.call("dev_face_target", "ada"), level.get_node("Ada"), "ada 是梨攤前的艾妲")
	assert_eq(level.call("dev_face_target", "sheila"), sheila)
	sheila.set_physics_process(false)
	sheila.global_position = player.global_position + Vector3(3.0, 0.0, 2.0)  # 在諾恩右後方
	level.set("_dev_face", "sheila")
	await tree.physics_frame
	await tree.physics_frame
	var to: Vector3 = (sheila.global_position - player.global_position) * Vector3(1, 0, 1)
	var fwd: Vector3 = -player.global_transform.basis.z * Vector3(1, 0, 1)
	assert_true(fwd.normalized().dot(to.normalized()) > 0.98, "諾恩面向席菈（dot %.3f）" % fwd.normalized().dot(to.normalized()))
	assert_true(absf(player.yaw - player.rotation.y) < 0.001, "鏡頭角度跟著轉")
	await _free(level)


## 截圖旗標 `--face-off`：轉向目標後再往左轉，目標落在畫面右側（不被諾恩的背影擋住，盤點第 5 項）。
func test_dev_face_offset_puts_target_right() -> void:
	_story_session("market")
	var level: StoryLevel = await _load()
	var player: PlayerController = level.get_node("Player") as PlayerController
	var sheila: Node3D = level.get_node("Sheila") as Node3D
	sheila.set_physics_process(false)
	sheila.global_position = player.global_position + Vector3(0.0, 0.0, -5.0)
	level.set("_dev_face", "sheila")
	level.set("_dev_face_off", 16.0)
	await tree.physics_frame
	await tree.physics_frame
	var to: Vector3 = ((sheila.global_position - player.global_position) * Vector3(1, 0, 1)).normalized()
	var fwd: Vector3 = (-player.global_transform.basis.z * Vector3(1, 0, 1)).normalized()
	var ang: float = rad_to_deg(fwd.signed_angle_to(to, Vector3.UP))
	assert_true(absf(ang + 16.0) < 1.0, "席菈在諾恩面向的右邊 16°（%.1f°，右邊是負）" % ang)
	await _free(level)


## 截圖旗標 `--pos=x,z`（高度照地面）與 `--hide=noen`（藏起諾恩的模型）。
func test_dev_place_and_hide_player() -> void:
	_session()
	var level: StoryLevel = await _load()
	var player: PlayerController = level.get_node("Player") as PlayerController
	assert_true(bool(level.call("dev_place_player", "2.6,6.5")), "x,z 格式移動")
	assert_true(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(2.6, 6.5)) < 0.01, "移到 (2.6, 6.5)：%s" % player.global_position)
	assert_true(absf(player.global_position.y - (level.ground_y(player.global_position) + 0.05)) < 0.01, "高度照地面")
	assert_true(bool(level.call("dev_place_player", "0,-35")), "北街台地")
	assert_true(player.global_position.y > 0.8, "移到台地上就站在台地高度（y=%.2f）" % player.global_position.y)
	assert_true(not bool(level.call("dev_place_player", "abc")), "格式不對不動")
	assert_true(not bool(level.call("dev_place_player", "1,x")), "不是數字不動")
	level.call("dev_hide_player")
	var shown: int = 0
	for v: Node in player.find_children("*", "GeometryInstance3D", true, false):
		if (v as GeometryInstance3D).visible:
			shown += 1
	assert_eq(shown, 0, "諾恩的模型全部藏起來")
	await _free(level)


## 南街的斷拱（D-222）：單純的場景物件——沒有腳本、兩截斷柱擋得住人、散落的石塊讓出中間的路（推車與守衛都從這裡過）。
func test_south_arch_is_a_plain_ruin_with_a_clear_middle() -> void:
	_session()
	var level: StoryLevel = await _load()
	var arch: Node3D = level.get_node("SouthArch") as Node3D
	assert_eq(level.south_arch, arch, "關卡記得它")
	assert_true(arch.get_script() == null, "沒有行為：只是一個 Node3D")
	assert_true(absf(arch.global_position.z - 20.0) < 0.01 and absf(arch.global_position.x) < 0.01, "在南街口：%s" % arch.global_position)
	var ruin: Node3D = arch.get_node("Ruin") as Node3D
	var stumps: int = 0
	var rubble: int = 0
	for c: Node in ruin.get_children():
		var b: CSGBox3D = c as CSGBox3D
		assert_not_null(b, "廢墟都是石塊：%s" % c.name)
		if b.use_collision:
			stumps += 1
			assert_true(absf(b.position.x) - b.size.x * 0.5 >= 1.5, "斷柱在兩邊，中間至少 3 m 寬：%s" % b.position)
			assert_true(b.size.y >= 0.9 - 0.001, "斷柱夠高，擋得住人：%s" % b.size.y)
		else:
			rubble += 1
			assert_true(absf(b.position.x) >= 1.3 - 0.001, "石塊不擺在路中間：%s" % b.position)
			assert_true(absf(b.position.y - b.size.y * 0.5) < 0.001, "石塊貼地")
	assert_eq(stumps, 2, "兩截斷柱")
	assert_eq(rubble, 7, "七塊散落的石頭")
	for gone: String in ["Arch", "BellRing", "Ash"]:
		assert_false(arch.has_node(gone), "「重現」的 %s 已經拿掉" % gone)
	assert_false(level.get_node("Hud").has_node("RestorePrompt"), "HUD 沒有重現提示")
	await _free(level)


## 截圖用 `--face=arch`（南街的斷拱）與 `--face=undertaker`（南街的守衛）。
func test_dev_face_arch_and_guardian() -> void:
	_story_session("guardian")
	var level: StoryLevel = await _load()
	assert_eq(level.call("dev_face_target", "arch"), level.get_node("SouthArch"), "arch 是南街的斷拱")
	assert_eq(level.call("dev_face_target", "undertaker"), level.get_node("RbGuardian"), "undertaker 是南街的守衛")
	await _free(level)


## 梨販攤正面的小補光（第二輪盤點第 6 項，D-089）：在桌前、低、不投影、範圍小、不進體積霧。
func test_stall_fill_light() -> void:
	_session()
	var level: StoryLevel = await _load()
	var fill: OmniLight3D = level.get_node_or_null("StallFill") as OmniLight3D
	assert_true(fill != null, "有攤桌補光")
	var stall: Vector3 = level.get("STALL_POS")
	assert_true(fill.position.z > stall.z + 0.8 and fill.position.y < 1.2, "在桌子正面、低低的：%s" % fill.position)
	assert_false(fill.shadow_enabled, "不投影")
	assert_true(fill.omni_range <= 2.5 and fill.light_volumetric_fog_energy == 0.0, "範圍小、不進體積霧")
	await _free(level)


## D-096（第三輪盤點第 2 項）：樓上不再大片空白——高的房子每層都有窗、寬的房子樓上中間再一扇；
## 約四分之一的房子門邊吊一塊木招牌。新加的窗與招牌用位置雜湊，房子配置不變。
func test_upper_floors_have_windows_and_signs() -> void:
	_session()
	var level: StoryLevel = await _load()
	var upper: int = int(level.get("upper_window_count"))
	var signs: int = int(level.get("shop_sign_count"))
	var total: int = int(level.get("window_count"))
	assert_true(upper >= 20, "樓上補開了不少窗（%d 扇）" % upper)
	assert_true(upper < total, "原本的窗還在（全部 %d 扇）" % total)
	assert_true(signs >= 4 and signs <= 20, "有幾家掛著店招（%d 塊）" % signs)
	# D-122（第五輪盤點第 6 項）：招牌上畫著店家的剪影（靴子、壺、鑰匙），不只一種
	var icons: Array[int] = level.get("shop_sign_icons")
	assert_eq(icons.size(), signs, "每塊招牌都有圖案")
	var kinds: Dictionary = {}
	for i: int in icons:
		assert_true(i >= 0 and i < FrostbridgeLook.SIGN_ICONS, "圖案編號在範圍內（%d）" % i)
		kinds[i] = true
	assert_true(kinds.size() >= 2, "不只一種圖案（%d 種）" % kinds.size())
	for pos: Vector3 in [Vector3(1.3, 2.6, -7.9), Vector3(-12.0, 2.6, 4.4)]:
		var t: Color = FrostbridgeLook.sign_tint(pos, true)
		assert_true(t.r > 0.3 and t.r < 0.7, "店招模式介於木箱（0）與門（1）之間（%.2f）" % t.r)
		assert_eq(int(floor((t.r - 0.35) * 10.0)), FrostbridgeLook.sign_icon(pos), "shader 解得回同一個圖案")
	await _free(level)


## D-097（第三輪盤點第 3 項）：煙囪頂有石帽，一部分冒煙（北街不冒、最多 MAX_SMOKE 根），煙是柔邊粒子。
func test_chimney_smoke() -> void:
	_session()
	var level: StoryLevel = await _load()
	var smokes: Array[Node] = level.find_children("ChimneySmoke*", "CPUParticles3D", true, false)
	var max_smoke: int = int(level.get("MAX_SMOKE"))
	assert_true(smokes.size() >= 3 and smokes.size() <= max_smoke, "有幾根煙囪在冒煙（%d 根）" % smokes.size())
	for n: Node in smokes:
		var p: CPUParticles3D = n as CPUParticles3D
		assert_true(p.global_position.y > 5.0, "煙從屋頂上冒出來（y=%.1f）" % p.global_position.y)
		assert_true(p.amount <= 16, "每根煙的粒子數很少（%d）" % p.amount)
		assert_false(String(p.get_path()).contains("NorthHouse"), "北街（會陷落）的煙囪不冒煙")
	assert_eq(ParticleLook.untextured(level).size(), 0, "煙也是柔邊圓點，不是方塊")
	await _free(level)


## D-100（第三輪盤點第 7 項的第一步）：廣場牆邊有幾堆木桶，不在主要路線上、會擋人。
func test_plaza_barrels() -> void:
	_session()
	var level: StoryLevel = await _load()
	var n: int = int(level.get("barrel_count"))
	assert_true(n >= 6 and n <= 9, "廣場邊三堆木桶（%d 個）" % n)
	var stall: Vector3 = level.get("STALL_POS")
	for spot: Vector3 in level.get("BARREL_SPOTS"):
		assert_true(absf(spot.x) > 9.0, "木桶靠牆、不在廣場中間（x=%.1f）" % spot.x)
		assert_true(spot.distance_to(stall) > 4.0 and spot.distance_to(Vector3(-6.0, 0.0, -3.5)) > 3.0, "離攤子與井夠遠")
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var spot0: Vector3 = (level.get("BARREL_SPOTS") as Array)[0]
	await tree.physics_frame
	var blocked: bool = false
	for k: int in 21:
		var p := spot0 + Vector3(0.1, 0.0, -1.0 + 0.1 * float(k))
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 3.0, 0), p + Vector3(0, -1.0, 0)))
		if not hit.is_empty() and (hit["position"] as Vector3).y > 0.5:
			blocked = true
	assert_true(blocked, "立著的木桶會擋人（往下的射線打在桶蓋高度）")
	await _free(level)


## 柴堆（D-103）：東側牆邊、地窖北邊，一落橫放的圓木（切口朝廣場）、頂上有雪，會擋人。
func test_plaza_woodpile() -> void:
	_session()
	var level: StoryLevel = await _load()
	var n: int = int(level.get("woodpile_logs"))
	assert_true(n >= 30 and n <= 60, "柴堆有一落圓木（%d 根）" % n)
	var pos: Vector3 = level.get("WOODPILE_POS")
	assert_true(absf(pos.x) > 9.5 and absf(pos.x) < 11.0 - 0.3, "靠牆、不在廣場中間、不插進牆（x=%.1f）" % pos.x)
	assert_true(pos.distance_to(level.get("CELLAR_POS")) > 3.0, "不擋地窖")
	assert_true(pos.distance_to(level.get("STALL_POS")) > 5.0, "離攤子夠遠")
	for spot: Vector3 in level.get("BARREL_SPOTS"):
		assert_true(pos.distance_to(spot) > 2.5, "不跟木桶疊在一起")
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var p := pos + Vector3(0, 3.0, 0)
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p, pos + Vector3(0, -1.0, 0)))
	assert_true(not hit.is_empty() and (hit["position"] as Vector3).y > 0.7, "柴堆會擋人（往下的射線打在柴堆頂）")
	await _free(level)


## 手推車（D-103）：西側牆邊、不擋井與木桶，會擋人（車斗高度）。
func test_plaza_handcart() -> void:
	_session()
	var level: StoryLevel = await _load()
	assert_true(bool(level.get("handcart_built")), "廣場邊停著一輛手推車")
	var pos: Vector3 = level.get("HANDCART_POS")
	assert_true(absf(pos.x) > 8.5 and absf(pos.x) < 11.0 - 0.8, "靠牆（x=%.1f）" % pos.x)
	assert_true(pos.distance_to(Vector3(-6.0, 0.0, -3.5)) > 3.5, "離井夠遠")
	assert_true(pos.distance_to(level.get("STALL_POS")) > 6.0, "離攤子夠遠")
	for spot: Vector3 in level.get("BARREL_SPOTS"):
		assert_true(pos.distance_to(spot) > 2.5, "不跟木桶疊在一起")
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 3.0, 0), pos + Vector3(0, -1.0, 0)))
	assert_true(not hit.is_empty() and (hit["position"] as Vector3).y > 0.5, "手推車會擋人")
	await _free(level)


## 木圍欄（D-104）：廣場西北角圍出一小塊院子，不擋主街口、路燈、井、木桶；有一根斷掉的橫木；會擋人。
func test_plaza_fence() -> void:
	_session()
	var level: StoryLevel = await _load()
	var posts: int = int(level.get("fence_posts"))
	var rails: int = int(level.get("fence_rails"))
	assert_true(posts >= 5 and posts <= 10, "圍欄有一排立柱（%d 根）" % posts)
	assert_eq(rails, (posts - 1) * 2, "每一格上下兩道橫木")
	assert_true(bool(level.get("fence_broken_rail")), "最西那一格的上橫木斷了一頭")
	var path: Array = level.get("FENCE_PATH")
	for p: Vector3 in path:
		assert_true(absf(p.x) > 4.0 + 0.5 and absf(p.x) < 11.0, "在廣場裡、不擋主街口（x=%.1f）" % p.x)
		assert_true(p.z >= -10.0 and p.z < -7.0, "靠北排房子（z=%.1f）" % p.z)
		assert_true(p.distance_to(Vector3(-6.0, 0.0, -3.5)) > 3.5, "離井夠遠")
		assert_true(p.distance_to(Vector3(-8.0, 0.0, -7.5)) > 0.9, "不撞路燈")
		for spot: Vector3 in level.get("BARREL_SPOTS"):
			assert_true(p.distance_to(spot) > 1.8, "不跟木桶疊在一起")
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	# 從廣場往北、橫穿前面那段圍欄
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-6.0, 0.5, -7.0), Vector3(-6.0, 0.5, -9.5)))
	assert_true(not hit.is_empty() and absf((hit["position"] as Vector3).z + 8.3) < 0.2, "前面那段圍欄會擋人（%s）" % [hit.get("position")])
	# 從主街口往西、橫穿東邊那段
	hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-3.6, 0.5, -9.2), Vector3(-5.6, 0.5, -9.2)))
	assert_true(not hit.is_empty() and absf((hit["position"] as Vector3).x + 4.7) < 0.2, "東邊那段圍欄會擋人（%s）" % [hit.get("position")])
	# 主街口本身是空的
	hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-3.5, 0.5, -7.0), Vector3(3.5, 0.5, -7.0)))
	assert_true(hit.is_empty(), "往主街的路沒有被擋住（%s）" % [hit.get("position")])
	await _free(level)


## 街邊雪帶（D-105）：沿牆一串雪堆，靠牆那側高、高低不一，不會蓋到石階，也不擋路（沒有碰撞）。
func test_street_snow_banks() -> void:
	_session()
	var level: StoryLevel = await _load()
	var banks: Array = level.get("snow_banks")
	assert_true(banks.size() >= 60, "沿街一串雪堆（%d 個）" % banks.size())
	var lo: float = 1.0
	var hi: float = 0.0
	for b: Vector4 in banks:
		lo = minf(lo, b.y)
		hi = maxf(hi, b.y)
		assert_true(not (b.z < -25.2 and b.z > -29.2), "石階上沒有雪堆（z=%.1f）" % b.z)
		assert_true(b.w > 0.6 and b.w < 1.6, "靠街那側伸出 %.2f m" % b.w)
	assert_true(hi > 0.18 and lo < 0.16 and hi - lo > 0.05, "高低不一（%.2f～%.2f m）" % [lo, hi])
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	# 廣場東側牆腳：雪沒有碰撞，往下的射線打在地面
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(10.6, 2.0, 1.5), Vector3(10.6, -1.0, 1.5)))
	assert_true(not hit.is_empty() and (hit["position"] as Vector3).y < 0.05, "雪堆不擋人（%s）" % [hit.get("position")])
	await _free(level)


## 石階上的雪（D-137）：不再是每一級前緣一條筆直的白線——兩側靠牆各一堆、後緣角落偶爾一小團，
## 中間有人走的路（STEP_PATH_HALF）沒有雪；每一團都在石階的踏面上、不會太高（不擋腳）。
func test_step_snow_leaves_path_clear() -> void:
	_session()
	var level: StoryLevel = await _load()
	var snow: Array = level.get("step_snow")
	var path_half: float = float(level.get("STEP_PATH_HALF"))
	assert_true(snow.size() >= 8, "四級石階兩側各一堆（%d 團）" % snow.size())
	var left: int = 0
	var right: int = 0
	for b: Vector4 in snow:
		assert_true(absf(b.x) - b.w >= path_half - 0.001, "中間的路沒有雪（x=%.2f 半寬 %.2f）" % [b.x, b.w])
		assert_true(absf(b.x) + b.w <= 4.0 + 0.15, "不會伸出街外太多（x=%.2f）" % b.x)
		assert_true(b.z < -25.2 and b.z > -29.2, "在石階的踏面上（z=%.2f）" % b.z)
		var ground: float = level.ground_y(Vector3(b.x, 0.0, b.z))
		assert_true(b.y - ground < 0.3, "雪不高（%.2f m）" % (b.y - ground))
		if b.x < 0.0:
			left += 1
		else:
			right += 1
	assert_true(left >= 4 and right >= 4, "兩側都有（左 %d、右 %d）" % [left, right])
	await _free(level)


## 屋瓦（D-107）：完整的屋頂都用屋瓦材質，雪只蓋住上面一部分（露出最下面幾排瓦）。
func test_roofs_use_tiles() -> void:
	_session()
	var level: StoryLevel = await _load()
	assert_true(int(level.get("roof_count")) >= 20, "每棟房子一個屋瓦屋頂（%d）" % int(level.get("roof_count")))
	var snow_cover: float = float(level.get("ROOF_SNOW"))
	assert_true(snow_cover > 0.55 and snow_cover < 0.8, "雪蓋住屋頂的上 %.0f%%，下緣露出幾排瓦" % (snow_cover * 100.0))
	# D-112：雪的下緣不是一條直線——每片斜面沿屋簷一串扁雪堆
	assert_true(int(level.get("roof_snow_lips")) >= int(level.get("roof_count")) * 4, "每棟屋頂兩邊各至少兩個雪堆（%d）" % int(level.get("roof_snow_lips")))
	var found: bool = false
	for mi: Node in level.get_node("Town").find_children("*", "MeshInstance3D", true, false):
		var m: ShaderMaterial = (mi as MeshInstance3D).material_override as ShaderMaterial
		if m != null and m.shader != null and m.shader.resource_path.ends_with("roof_tiles.gdshader"):
			found = true
	assert_true(found, "小鎮合併的 mesh 裡有屋瓦材質")
	await _free(level)


## 地上的殘雪、髒雪與車轍（D-114）：小鎮所有濕石板材質都拿到街道範圍、踩實的髒雪、車轍；
## 車轍從西側手推車出來、繞過井與中央石框、不撞圍欄／木桶／路燈，最後進主街；街口不被當成牆。
func test_ground_snow_and_ruts() -> void:
	_session()
	var level: StoryLevel = await _load()
	var lanes: Array = level.call("ground_lanes")
	var trodden: Array = level.get("TRODDEN")
	var rut: PackedVector2Array = level.get("RUT_PATH")
	var wet: int = 0
	for mi: Node in level.get_node("Town").find_children("*", "MeshInstance3D", true, false):
		var m: ShaderMaterial = (mi as MeshInstance3D).material_override as ShaderMaterial
		if m == null or m.shader == null or not m.shader.resource_path.ends_with("wet_cobble.gdshader"):
			continue
		wet += 1
		assert_eq(int(m.get_shader_parameter("lane_count")), lanes.size(), "濕石板材質拿到街道範圍")
		assert_eq(int(m.get_shader_parameter("trodden_count")), trodden.size(), "濕石板材質拿到踩實的髒雪")
		assert_eq(int(m.get_shader_parameter("rut_count")), rut.size(), "濕石板材質拿到車轍")
	assert_true(wet >= 2, "廣場與街道兩種濕石板都有（%d）" % wet)
	# 街道範圍：每條街都在某個範圍裡；主街、南街的範圍伸進廣場（街口不是牆）
	for probe: Vector2 in [Vector2(0, 0), Vector2(0, -20), Vector2(0, -38), Vector2(0, 22), Vector2(0, 38)]:
		var inside: bool = false
		for l: Vector4 in lanes:
			inside = inside or (absf(probe.x - l.x) < l.z and absf(probe.y - l.y) < l.w)
		assert_true(inside, "(%.0f, %.0f) 在街道範圍裡" % [probe.x, probe.y])
	for mouth: Vector2 in [Vector2(0, -10), Vector2(0, 10), Vector2(0, 34), Vector2(0, 35)]:
		var deep: float = 0.0
		for l: Vector4 in lanes:
			var d := Vector2(l.z - absf(mouth.x - l.x), l.w - absf(mouth.y - l.y))
			if d.x > 0.0 and d.y > 0.0:
				deep = maxf(deep, minf(d.x, d.y))
		assert_true(deep > 2.5, "街口 (%.0f, %.0f) 離牆 %.1f m，不會積成一道雪" % [mouth.x, mouth.y, deep])
	# 踩實的髒雪：井邊一圈（內半徑貼著井身）、攤子前一片，都在廣場裡
	for t: Vector4 in trodden:
		assert_true(absf(t.x) + t.w < 11.0 + 0.5 and absf(t.y) + t.w < 10.0 + 0.5, "髒雪在廣場裡（%s）" % [t])
	assert_true((trodden[0] as Vector4).z > 1.0, "井邊那圈從井身外開始")
	assert_true(Vector2((trodden[1] as Vector4).x, (trodden[1] as Vector4).y).distance_to(Vector2(4.5, -1.0)) < 2.5, "一片在梨販攤前")
	# 車轍：從手推車出來、最後進主街
	var gauge_half: float = 1.37 * 0.5
	var cart: Vector3 = level.get("HANDCART_POS")
	assert_true(rut[0].distance_to(Vector2(cart.x, cart.z)) < 0.5, "車轍從手推車出來")
	var last: Vector2 = rut[rut.size() - 1]
	assert_true(last.y < -12.0 and absf(last.x) + gauge_half < 4.0, "最後進主街（%s）" % [last])
	var clear: Array[Vector3] = [Vector3(-6.0, -3.5, 1.2), Vector3(0.0, 0.0, 3.32), Vector3(-8.0, -7.5, 0.3),
		Vector3(-4.7, -8.3, 0.1), Vector3(-4.7, -10.0, 0.1)]
	for spot: Vector3 in level.get("BARREL_SPOTS"):
		clear.append(Vector3(spot.x, spot.z, 0.45))
	for c: Vector3 in clear:
		var d: float = _polyline_dist(rut, Vector2(c.x, c.y))
		assert_true(d - gauge_half > c.z + 0.1, "車轍不壓到 (%.1f, %.1f)（中心線距離 %.2f m）" % [c.x, c.y, d])
	await _free(level)


## 第五輪盤點第 2 項（D-120）：廣場的石板繞中央石框弧形鋪、石框裡不蓋殘雪；街道是直排（微微起伏）。
## 石框裡的內圈鋪石跟廣場同一個材質（合併 mesh 數不變），兩者都還拿得到殘雪設定。
func test_plaza_arc_paving() -> void:
	_session()
	var level: StoryLevel = await _load()
	var plaza: ShaderMaterial = level.call("plaza_ground")
	assert_true(plaza.get_shader_parameter("arc_paving") == true, "廣場弧形鋪")
	assert_eq(plaza.get_shader_parameter("arc_center"), Vector2.ZERO, "繞廣場中央（石框的圓心）")
	var disc: Vector3 = plaza.get_shader_parameter("clear_disc")
	var ring_r: float = level.get("PLAZA_RING_R")
	assert_true(disc.z > 2.0 and disc.z < ring_r, "石框裡不蓋殘雪，範圍在石緣以內（%.2f）" % disc.z)
	assert_true(plaza == level.call("plaza_ground"), "同一個材質（快取）")
	# D-144：廣場一圈圈的縫在中距離就淡掉（比街道快）；每顆石板不一樣（下陷積水、深色補石、砂土填縫）
	assert_true(float(plaza.get_shader_parameter("far_fade")) > 1.5, "廣場的圈遠處淡得比街道快")
	var cobble: Shader = plaza.shader
	for u: String in ["sunken_share", "dark_share", "grit_amount", "far_fade"]:
		var found: bool = false
		for p: Dictionary in cobble.get_shader_uniform_list():
			found = found or str(p["name"]) == u
		assert_true(found, "濕石板 shader 有 %s" % u)
	var arc: int = 0
	var straight: int = 0
	for mi: Node in level.get_node("Town").find_children("*", "MeshInstance3D", true, false):
		var m: ShaderMaterial = (mi as MeshInstance3D).material_override as ShaderMaterial
		if m == null or m.shader == null or not m.shader.resource_path.ends_with("wet_cobble.gdshader"):
			continue
		if m.get_shader_parameter("arc_paving") == true:
			arc += 1
			assert_true(m == plaza, "弧形鋪的只有廣場這一個材質")
		else:
			straight += 1
			var c: Variant = m.get_shader_parameter("clear_disc")
			assert_true(c == null or (c as Vector3).z == 0.0, "街道沒有排除圓")
		assert_true(int(m.get_shader_parameter("lane_count")) > 0, "殘雪設定都有套上")
	assert_eq(arc, 1, "廣場與石框內圈合併成一個 mesh")
	assert_true(straight >= 1, "街道還是直排")
	await _free(level)


func _polyline_dist(pts: PackedVector2Array, p: Vector2) -> float:
	var best: float = INF
	for i: int in pts.size() - 1:
		var a: Vector2 = pts[i]
		var ab: Vector2 = pts[i + 1] - a
		var h: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * h))
	return best


## 廣場石盤的鐘剪影（D-130）：平躺、正面朝上（從上面看得到）、放得進半徑 1 m 的石盤。
## 鐘頂朝北（-Z）。D-141：又高又窄（不像帽子）、鐘口外翻、鐘口外（南邊）有鐘舌。
func test_plaza_bell_inlay_faces_up() -> void:
	var script: GDScript = load("res://scenes/levels/frostbridge.gd") as GDScript
	var mesh: ArrayMesh = script.call("bell_inlay_mesh", 1.4, 0.42) as ArrayMesh
	assert_not_null(mesh, "有網格")
	var arrays: Array = mesh.surface_get_arrays(0)
	var pts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	assert_true(idx.size() >= 3 and idx.size() % 3 == 0, "有索引的三角形（StaticBatch 合併時才畫得出來，%d）" % idx.size())
	var verts := PackedVector3Array()
	for k: int in idx:
		verts.append(pts[k])
	var down_facing: int = 0
	var far: float = 0.0
	var north: float = 0.0
	var south: float = 0.0
	var widest: float = 0.0
	for i: int in range(0, verts.size(), 3):
		var n: Vector3 = (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
		# Godot 正面順時針（CylinderMesh 的頂蓋也是）：從上往下看順時針 → 右手定則的法線朝下
		if n.y > 0.0:
			down_facing += 1
	for v: Vector3 in verts:
		assert_true(absf(v.y) < 0.001, "平躺")
		far = maxf(far, Vector2(v.x, v.z).length())
		north = minf(north, v.z)
		south = maxf(south, v.z)
		widest = maxf(widest, absf(v.x))
	assert_eq(down_facing, 0, "每個三角形正面朝上")
	assert_true(far < 0.95, "放得進石盤（最遠 %.2f m）" % far)
	assert_true(north < -0.6, "鐘頂朝北（%.2f）" % north)
	assert_true(south - north > widest * 2.0 * 1.4, "又高又窄：長 %.2f m、寬 %.2f m（從南邊看被壓扁也不會矮胖）" % [south - north, widest * 2.0])
	assert_true(widest > 0.42 * 1.08, "鐘口外翻，比鐘口半徑寬（%.2f）" % widest)
	# 鐘舌：鐘口（最寬那圈）再往南還有東西，而且在中線上
	var lip_z: float = -INF
	for v: Vector3 in verts:
		if absf(v.x) > widest - 0.005:
			lip_z = maxf(lip_z, v.z)
	var beyond: int = 0
	for v: Vector3 in verts:
		if v.z > lip_z + 0.05:
			beyond += 1
			assert_true(absf(v.x) < 0.2, "鐘口外的是鐘舌（在中線上，x=%.2f）" % v.x)
	assert_true(beyond > 0, "鐘口外有鐘舌")
