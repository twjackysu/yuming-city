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
	assert_true(wet >= 2, "街道與廣場是濕石板路（%d 個合併 mesh）" % wet)
	assert_true(timber >= 3, "房子是半木構外牆、後牆與城牆是石牆（%d 個合併 mesh）" % timber)
	assert_true((town.get_node("Collision") as StaticBody3D).get_child_count() > 60, "房子都有碰撞")
	assert_true(level._north_houses.size() >= 4, "北街至少四棟可以陷落的房子")
	assert_true(int(level.get("light_count")) <= 40, "燈的數量有上限（%d）" % int(level.get("light_count")))
	assert_true(int(level.get("lantern_count")) >= 6, "不少房子門口有掛燈（%d）" % int(level.get("lantern_count")))
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
	await _free(level)


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
