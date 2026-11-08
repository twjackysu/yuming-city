extends TestCase
## 霜橋鎮白盒（M1.3）：關卡結構、合併後的 draw call 規模、檢查點出生位置、
## 護送階段走進南街 → 送葬者戰 → 車隊通過 → 任務推進到收束。

const PATH: String = "res://scenes/levels/frostbridge.tscn"

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_fb_%d" % Time.get_ticks_usec()
	_original = tree.root.get_node("Game").get("session") as GameSession


func after_each() -> void:
	tree.root.get_node("Game").set("session", _original)
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _session() -> GameSession:
	var s := GameSession.new(QuestDB.load_default(), _dir)
	tree.root.get_node("Game").set("session", s)
	s.new_game()
	return s


## 任務推到護送車隊（送葬者戰之前）。
func _to_convoy(s: GameSession) -> void:
	s.set_flag("slice.met_pear_seller", true)
	for i: int in 9:
		s.add_flag("slice.bell_rings")
	s.set_flag("slice.rescue_done", true)
	s.set_flag("slice.sheila_talked", true)
	s.set_flag("slice.ashwalker_defeated", true)


func _load() -> StoryLevel:
	var level: StoryLevel = (load(PATH) as PackedScene).instantiate() as StoryLevel
	tree.root.add_child(level)
	await tree.physics_frame
	return level


func _free(level: Node) -> void:
	level.queue_free()
	await tree.process_frame
	await tree.process_frame


func test_checkpoints_map_to_frostbridge() -> void:
	var game: Node = tree.root.get_node("Game")
	for cp: String in ["start", "bell_tower", "rescue", "sheila_meet", "undertaker", "aftermath"]:
		assert_eq(game.call("level_for_checkpoint", cp), "frostbridge", "檢查點 %s 在霜橋鎮" % cp)


func test_layout_nodes_and_batching() -> void:
	_session()
	var level: StoryLevel = await _load()
	for n: String in ["Player", "Hud", "PauseMenu", "DialogueBox", "Town", "SouthArch", "Bell",
			"PearSellerTrigger", "BellTowerTrigger", "ConvoyTrigger", "BellCamWide", "BellCamRope", "NorthStreetCam"]:
		assert_true(level.has_node(n), "有 %s" % n)
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
	assert_eq(int(level.get("plaza_ring_parts")), 7, "廣場石框：石縫、石緣、內圈鋪石、鐘紋四層")
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
	assert_eq(int(level.get("belfry_louvres")), 24, "鐘室背面與兩側各 8 片百葉")
	assert_false(level.has_node("Sheila"), "新遊戲時席菈還沒登場")
	assert_false(level.has_node("Undertaker"), "送葬者還沒出現")
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
	var s: GameSession = _session()
	var level: StoryLevel = await _load()
	var hud: Hud = level.get_node("Hud") as Hud
	for i: int in 3:
		await tree.process_frame
	var player: Node3D = level.get_node("Player") as Node3D
	var stall: Vector3 = (level.get_node("PearSellerTrigger") as Node3D).global_position
	var expect: float = Vector2(stall.x - player.global_position.x, stall.z - player.global_position.z).length()
	assert_true(hud.guide.shown, "新遊戲時指向梨販")
	assert_true(absf(hud.guide.distance - expect) < 0.5, "距離是到梨販的水平距離（%.1f／%.1f）" % [hud.guide.distance, expect])
	var settings: Node = tree.root.get_node("Settings")
	settings.set("objective_marker", false)
	await tree.process_frame
	assert_false(hud.guide.shown, "設定關掉就不顯示")
	settings.set("objective_marker", true)
	# 敲鐘階段改指鐘樓
	s.set_flag("slice.met_pear_seller", true)
	await tree.process_frame
	var tower: Vector3 = (level.get_node("BellTowerTrigger") as Node3D).global_position
	assert_true(absf(hud.guide.distance - Vector2(tower.x - player.global_position.x, tower.z - player.global_position.z).length()) < 0.5, "敲鐘階段指向鐘樓")
	# 走到目標旁邊就不顯示
	player.global_position = Vector3(tower.x, level.ground_y(tower) + 0.05, tower.z + 1.0)
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


func test_north_street_collapses() -> void:
	_session()
	var level: StoryLevel = await _load()
	var house: Node3D = level._north_houses[0]
	var y0: float = house.position.y
	level.collapse_north_street(false)
	assert_true(level.is_north_collapsed())
	assert_true(house.position.y < y0 - 2.0, "房子沉下去（%.2f → %.2f）" % [y0, house.position.y])
	await _free(level)


## D-091：北街的房子陷落前是完整屋頂、陷落後換成破屋頂（朝街那面斷成幾片、一片掉光露出斷椽）。
func test_collapsed_houses_show_broken_roofs() -> void:
	_session()
	var level: StoryLevel = await _load()
	for house: Node3D in level._north_houses:
		var roof: Node3D = house.get_node_or_null("Roof") as Node3D
		var ruin: Node3D = house.get_node_or_null("Ruin") as Node3D
		assert_true(roof != null and ruin != null, "%s 有完整與破掉兩份屋頂" % house.name)
		assert_true(roof.visible and not ruin.visible, "陷落前看到完整屋頂")
		var info: Dictionary = house.get_meta("ruin", {})
		assert_true(int(info.get("segments", 0)) >= 3, "朝街那面斷成至少三片（%d）" % int(info.get("segments", 0)))
		assert_eq(int(info.get("holes", 0)), 1, "其中一片整個掉進屋裡")
		assert_true(int(info.get("rafters", 0)) >= 2, "洞裡露出斷掉的椽子（%d）" % int(info.get("rafters", 0)))
		var snow_meshes: int = 0
		var meshes: int = 0
		for c: Node in ruin.get_children():
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi == null:
				continue
			meshes += 1
			var sm: ShaderMaterial = mi.material_override as ShaderMaterial
			if sm != null and sm.shader.resource_path == FrostbridgeLook.SNOW_SHADER:
				snow_meshes += 1
		assert_eq(snow_meshes, 1, "破屋頂上的雪用積雪 shader")
		assert_true(meshes <= 5, "破屋頂合併成少數幾個 mesh（%d）" % meshes)
	level.collapse_north_street(false)
	for house: Node3D in level._north_houses:
		assert_false((house.get_node("Roof") as Node3D).visible, "%s 陷落後完整屋頂藏起來" % house.name)
		assert_true((house.get_node("Ruin") as Node3D).visible, "%s 陷落後看到破屋頂" % house.name)
	await _free(level)


## 截圖旗標 `--convoy` 把主線推進到送葬者戰：HUD 目標是護送車隊（之前停在「到廣場找梨販」）。
func test_dev_advance_to_convoy() -> void:
	var s := _session()
	assert_true(StoryLevel.dev_advance_to_convoy(s), "新遊戲 → 推進到送葬者戰")
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "escort_convoy")
	assert_eq(s.objective_key(), "Q_SLICE_OBJ_CONVOY", "HUD 目標是護送車隊")
	assert_true(bool(s.state.get_flag("slice.north_street_collapsed", false)), "北街照正式流程陷落")
	assert_false(StoryLevel.dev_advance_to_convoy(s), "已經在送葬者戰：不動")
	s.set_flag("slice.convoy_through", true)
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "aftermath")
	assert_false(StoryLevel.dev_advance_to_convoy(s), "之後的段落：不倒退")
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "aftermath")


func test_convoy_checkpoint_spawn_and_fight() -> void:
	var s := _session()
	_to_convoy(s)
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "escort_convoy")
	var level: StoryLevel = await _load()
	var player: PlayerController = level.get_node("Player") as PlayerController
	assert_true(player.global_position.distance_to(Vector3(0, 0.05, 6)) < 0.5, "送葬者檢查點在廣場南邊出生")
	assert_true(level.has_node("Sheila"), "護送階段席菈已經在身邊")
	assert_false(level.has_node("Undertaker"), "還沒走進南街")
	# 走進南街口 → 開打
	player.global_position = (level.get_node("ConvoyTrigger") as Node3D).global_position * Vector3(1, 0, 1) + Vector3(0, 0.05, 0)
	for i: int in 4:
		await tree.physics_frame
	assert_not_null(level.encounter, "送葬者戰開始")
	var boss: Undertaker = level.get_node("Undertaker") as Undertaker
	boss.set_physics_process(false)  # 別讓諾恩真的倒下（狀態會漏到之後的測試）
	var caravan: Caravan = level.get_node("Caravan") as Caravan
	var route: PackedVector3Array = caravan.route
	assert_true(route[0].z < 10.0 and route[route.size() - 1].z > 34.0, "車隊從廣場出發、到路口")
	var through_arch: bool = false
	for p: Vector3 in route:
		if absf(p.z - level.arch_site.global_position.z) < 0.1:
			through_arch = true
	assert_true(through_arch, "車隊路線穿過南街石拱")
	var enc: ConvoyEncounter = level.encounter
	# 再走進去一次不會重複開打
	player.global_position = Vector3(0.0, 0.05, 6.0)
	for i: int in 2:
		await tree.physics_frame
	player.global_position = Vector3(0.0, 0.05, 12.0)
	for i: int in 3:
		await tree.physics_frame
	assert_true(level.encounter == enc, "只開打一次")
	assert_eq(level.get_children().filter(func(c: Node) -> bool: return c is Undertaker).size(), 1)
	# 車隊推到路口 → 戰鬥結束 → 任務推進到收束
	caravan.runner.traveled = caravan.runner.length() - 0.05
	for i: int in 20:
		await tree.physics_frame
		if enc.done:
			break
	assert_true(enc.done, "車隊通過路口")
	assert_eq(s.state.get_flag("slice.convoy_through"), true)
	assert_eq(s.quests.stage_of(GameSession.MAIN_QUEST), "aftermath", "任務推進到收束")
	await _free(level)


func test_convoy_trigger_ignored_before_escort() -> void:
	_session()
	var level: StoryLevel = await _load()
	var player: PlayerController = level.get_node("Player") as PlayerController
	player.global_position = Vector3(0.0, 0.05, 12.0)
	for i: int in 4:
		await tree.physics_frame
	assert_true(level.encounter == null, "還沒到護送階段：南街不會開打")
	await _free(level)


## 段落 1「看見南街石拱」：走進南街 → 諾恩想起父親 → 日記解鎖；護送時沒逛過也會解鎖（重現的代價要存在）。
func test_arch_memory_unlocks_journal() -> void:
	var s := _session()
	var game: Node = tree.root.get_node("Game")
	var journal: Journal = game.get("journal") as Journal
	assert_eq(journal.visible_ids(s.state).size(), 0, "新遊戲：日記是空的")
	var level: StoryLevel = await _load()
	var player: PlayerController = level.get_node("Player") as PlayerController
	var trig: Vector3 = (level.get_node("ArchMemoryTrigger") as Node3D).global_position
	player.global_position = Vector3(trig.x, 0.05, trig.z)
	for i: int in 3:
		await tree.physics_frame
	assert_true(game.call("is_in_dialogue"), "走進南街 → 諾恩的獨白")
	var box: DialogueBox = level.get_node("DialogueBox") as DialogueBox
	for i: int in 10:
		if not bool(game.call("is_in_dialogue")):
			break
		box.press_continue()
		await tree.process_frame
	assert_eq(s.state.get_flag("slice.saw_south_arch"), true)
	assert_true(journal.visible_ids(s.state).has("arch_father_last_talk"), "日記解鎖父親那段")
	# 再走進去不會重複
	player.global_position = Vector3(0.0, 0.05, 2.0)
	for i: int in 2:
		await tree.physics_frame
	player.global_position = Vector3(trig.x, 0.05, trig.z)
	for i: int in 3:
		await tree.physics_frame
	assert_false(game.call("is_in_dialogue"), "只說一次")
	await _free(level)


func test_convoy_unlocks_arch_memory_without_visit() -> void:
	var s := _session()
	_to_convoy(s)
	var level: StoryLevel = await _load()
	(level as Node).call("start_convoy")
	assert_eq(s.state.get_flag("slice.saw_south_arch"), true, "護送開打時補上石拱的記憶")
	await _free(level)



## 概念圖：主街往鐘樓爬坡——北段四級石階上到台地，北街、鐘樓、受困者都在台地上。
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
	var tower: Node3D = level.get_node("BellTowerTrigger") as Node3D
	assert_true(tower.global_position.y > rise, "鐘樓觸發區跟著台地抬高")
	level.collapse_north_street(false)
	for c: Node in level.get_children():
		if c is RescueSite:
			assert_true(absf((c as RescueSite).global_position.y - rise) < 0.01, "%s 在台地上" % c.name)
	await _free(level)


## 截圖旗標 `--face=sheila`：每幀把諾恩與鏡頭轉向席菈（燃燒劍斬鐵架在諾恩背後，平常拍不到）。
func test_dev_face_turns_player_to_target() -> void:
	var s := _session()
	_to_convoy(s)
	var level: StoryLevel = await _load()
	var player: PlayerController = level.get_node("Player") as PlayerController
	var sheila: Node3D = level.get_node("Sheila") as Node3D
	assert_true(level.call("dev_face_target", "nobody") == null, "不認得的名字沒有目標")
	assert_true(level.call("dev_face_target", "frame") == null, "還沒擲鐵架")
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
	var s := _session()
	_to_convoy(s)
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
	var s := _session()
	_to_convoy(s)
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


## 截圖用 `--face=arch` 與 `--convoy --arch=preview`：送葬者停在諾恩背後、不追不出招（第二輪盤點第 8 項，
## 原本他生在石拱前，鐵架擋住預覽的石拱）。
func test_dev_face_arch_and_park_boss() -> void:
	var s := _session()
	_to_convoy(s)
	var level: StoryLevel = await _load()
	assert_eq(level.call("dev_face_target", "arch"), level.get_node("SouthArch"), "arch 是南街石拱")
	assert_true(not bool(level.call("dev_park_boss", Vector3(2.0, 0.0, 9.0))), "還沒開打，沒有送葬者")
	level.call("start_convoy")
	var boss: Undertaker = level.get_node("Undertaker") as Undertaker
	assert_true(bool(level.call("dev_park_boss", Vector3(2.0, 0.0, 9.0))), "開打後可以停住送葬者")
	for i: int in 10:
		await tree.physics_frame
	var at := Vector2(boss.global_position.x, boss.global_position.z)
	assert_true(at.distance_to(Vector2(2.0, 9.0)) < 0.01, "送葬者停在 (2, 9) 不動：%s" % boss.global_position)
	assert_true(absf(boss.global_position.y - (level.ground_y(boss.global_position) + 0.05)) < 0.01, "高度照地面")
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


## 截圖用 `--insight`（第二輪盤點第 2 項）：送葬者戰一開始就按住看穿，諾恩的看穿狀態打開。
func test_dev_hold_insight() -> void:
	var s := _session()
	_to_convoy(s)
	var level: StoryLevel = await _load()
	level.call("dev_hold_insight")
	await tree.physics_frame
	await tree.physics_frame
	var player: PlayerController = level.get_node("Player") as PlayerController
	assert_true(Input.is_action_pressed("insight"), "看穿鍵按著")
	assert_true(player.insight_active, "諾恩在看穿")
	Input.action_release("insight")
	await tree.physics_frame
	assert_false(player.insight_active, "放開後不再看穿")
	await _free(level)
