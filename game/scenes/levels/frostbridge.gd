extends StoryLevel
## 霜橋鎮白盒（M1.3）：切片《霜橋鎮的第九聲鐘》的正式關卡（docs/design/05-vertical-slice-plan.md）。
##
## 版面（-Z 是北，單位公尺）：
##   廣場  z∈[-10,10]、x∈[-11,11]：出生點、梨販攤、井、四盞路燈
##   主街  z∈[-30,-10]、寬 8；北街 z∈[-46,-30]（第九聲後陷落）；鐘樓 z=-50；北城牆 z=-55
##   南街  z∈[10,34]、寬 7：石拱 z=20（九息）、送葬者戰
##   路口  z∈[34,42]、x∈[-20,20]：傷者車隊的終點
## 靜態幾何全部進 StaticBatch（每種材質一個 draw call）；會動的（北街房子、鐘）各自一個節點。
##
## 開發用旗標（`++ --level=frostbridge ...`）：`--rescue` 跳到救援段落、`--convoy` 直接開打送葬者戰、`--phase2`、
## `--arch=preview|restored|spent`（諾恩站在南街石拱前）、`--at=plaza|main|north|south|cross`（出生位置）。

const PLAZA_HALF: float = 11.0
const MAIN_HALF: float = 4.0
const SOUTH_HALF: float = 3.5
const PLAZA_N: float = -10.0
const PLAZA_S: float = 10.0
const NORTH_START: float = -30.0
const NORTH_END: float = -46.0
const TOWER_Z: float = -50.0
const ARCH_Z: float = 20.0
const CROSS_N: float = 34.0
const CROSS_S: float = 42.0
const CROSS_HALF: float = 20.0
const STALL_POS: Vector3 = Vector3(4.5, 0.0, -1.0)

## 檢查點 -> 出生位置（沒列到的用廣場）
const CHECKPOINT_SPAWNS: Dictionary = {
	"rescue": Vector3(0.0, 0.05, -24.0),
	"undertaker": Vector3(0.0, 0.05, 6.0),
}
## `--at=` 開發用出生位置
const DEV_SPAWNS: Dictionary = {
	"plaza": Vector3(0.0, 0.05, 7.0),
	"main": Vector3(0.0, 0.05, -14.0),
	"north": Vector3(0.0, 0.05, -32.0),
	"south": Vector3(0.0, 0.05, 12.0),
	"cross": Vector3(0.0, 0.05, 36.0),
}

var look := FrostbridgeLook.new()
var _batch := StaticBatch.new()
## 統計（測試、benchmark 用）
var light_count: int = 0


func _ready() -> void:
	_rng.seed = 19  # 固定種子：截圖前後可對照
	FrostbridgeLook.build_environment(self)
	_build_ground()
	_build_plaza()
	_build_streets()
	_build_bell_tower(Vector3(0.0, 0.0, TOWER_Z))
	_build_lamps()
	_build_pear_stall(STALL_POS)
	_build_cellar_hatch()
	_batch.build(self, "Town")
	arch_site = NineBreathSite.new()
	arch_site.name = "SouthArch"
	arch_site.position = Vector3(0.0, 0.0, ARCH_Z)
	arch_site.rotation.y = PI  # 正面朝北（車隊和玩家從廣場過來）
	add_child(arch_site)
	_build_story_triggers()
	_build_cutscene_cameras()
	_init_story()

	var stage: String = Game.session.quests.stage_of(GameSession.MAIN_QUEST)
	var dev_args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	var player: PlayerController = $Player as PlayerController
	var spawn: Marker3D = $Spawn
	player.global_transform = spawn.global_transform
	var cp: String = Game.session.state.checkpoint
	if CHECKPOINT_SPAWNS.has(cp):
		player.global_position = CHECKPOINT_SPAWNS[cp] as Vector3
	if dev_args.has("at") and DEV_SPAWNS.has(str(dev_args["at"])):
		player.global_position = DEV_SPAWNS[str(dev_args["at"])] as Vector3
	# 席菈：「席菈」段落在主街北段等諾恩（救出三人後出現）；之後的檢查點一進場就在身邊
	if stage == "meet_sheila":
		_begin_sheila_meet()
	elif stage in ["escort_convoy", "aftermath"] or dev_args.has("convoy"):
		_spawn_sheila(player.global_position + Vector3(-1.4, 0.0, 1.2))
	Game.session.stage_changed.connect(_on_stage_changed)
	Game.dialogue_ended.connect(_on_dialogue_ended)
	# 截圖用：`--rescue` 直接跳到敲完九下、北街陷落的救援段落，諾恩站在第一個受困者旁
	if dev_args.has("rescue"):
		Game.session.set_flag("slice.met_pear_seller", true)
		Game.session.set_flag("slice.bell_rings", 9)
		collapse_north_street(false)
		player.global_position = Vector3(-1.4, 0.05, -30.2)
	if dev_args.has("convoy"):
		player.global_position = Vector3(0.0, 0.05, 10.0)
		player.rotation.y = PI  # 面向南街
		player.yaw = player.rotation.y
		start_convoy()
		if dev_args.has("phase2") and has_node("Undertaker"):
			($Undertaker as Undertaker).enter_phase_two.call_deferred()
	if dev_args.has("arch"):
		player.global_position = Vector3(0.6, 0.05, ARCH_Z - 4.6)
		player.rotation.y = PI + deg_to_rad(8.0)
		player.yaw = player.rotation.y
		match str(dev_args["arch"]):
			"preview":
				arch_site.debug_preview = true
			"restored":
				arch_site.activate.call_deferred()
			"spent":
				arch_site.activate()
				arch_site.nb.tick(9.5, Game.session.state)
	player.snap_camera()


# ---------------------------------------------------------------- 救援（段落 3）

## 北街陷落後才有受困者；讀檔時已陷落也會在這裡生成。
const RESCUE_SPOTS: Dictionary = {
	"north_a": Vector3(-3.0, 0.0, -33.0),
	"north_b": Vector3(3.0, 0.0, -37.5),
	"north_c": Vector3(-2.8, 0.0, -42.0),
	"north_d": Vector3(3.1, 0.0, -45.0),
}


func collapse_north_street(animate: bool) -> void:
	super(animate)
	for id: String in RESCUE_SPOTS:
		if has_node("Rescue_" + id):
			continue
		var site := RescueSite.new()
		site.name = "Rescue_" + id
		site.site_id = id
		site.position = RESCUE_SPOTS[id] as Vector3
		site.rescued.connect(func(_id: String) -> void: _banner("RESCUE_SAVED", 2.5))
		add_child(site)


# ---------------------------------------------------------------- 席菈（段落 4）

const SHEILA_WAIT_POS: Vector3 = Vector3(1.6, 0.0, -21.0)
const ASHWALKER_POS: Vector3 = Vector3(0.0, 0.0, -34.0)
const SHEILA_TALK_RANGE: float = 2.6

var ashwalker: Ashwalker


func _on_stage_changed(quest_id: String, _from: String, to_stage: String) -> void:
	if quest_id == GameSession.MAIN_QUEST and to_stage == "meet_sheila":
		_begin_sheila_meet()


## 席菈出現；已經談過（讀檔）就直接放灰巡者。
func _begin_sheila_meet() -> void:
	_spawn_sheila(SHEILA_WAIT_POS)
	if Game.session.state.get_flag("slice.sheila_talked", false):
		_spawn_ashwalker()


func _physics_process(_delta: float) -> void:
	var stage: String = Game.session.quests.stage_of(GameSession.MAIN_QUEST)
	if stage == "aftermath":
		_update_aftermath()
		return
	# 席菈段落：走到她身邊 → 夾板、「你敲了幾下」
	if stage != "meet_sheila":
		return
	if Game.session.state.get_flag("slice.sheila_talked", false) or Game.is_player_locked():
		return
	var sheila: Node3D = get_node_or_null("Sheila") as Node3D
	var player: Node3D = get_node_or_null("Player") as Node3D
	if sheila != null and player != null and sheila.global_position.distance_to(player.global_position) <= SHEILA_TALK_RANGE:
		Game.start_dialogue("slice_sheila_meet")


func _on_dialogue_ended(dialogue_id: String) -> void:
	if dialogue_id == "slice_sheila_meet" and Game.session.state.get_flag("slice.sheila_talked", false):
		_spawn_ashwalker()


## 協作教學戰：北街裂縫爬出一隻灰巡者；倒下 → slice.ashwalker_defeated。
func _spawn_ashwalker() -> void:
	if ashwalker != null or Game.session.state.get_flag("slice.ashwalker_defeated", false):
		return
	ashwalker = Ashwalker.new()
	ashwalker.name = "Ashwalker"
	ashwalker.position = ASHWALKER_POS
	add_child(ashwalker)
	ashwalker.health.died.connect(_on_ashwalker_died)
	_banner("SHEILA_MEET_ASHWALKER", 3.0)


func _on_ashwalker_died() -> void:
	Game.session.set_flag("slice.ashwalker_defeated", true)


# ---------------------------------------------------------------- 收束（段落 6）

const CELLAR_POS: Vector3 = Vector3(7.6, 0.0, -4.2)
const ADA_TALK_RANGE: float = 3.0


## 收束：回到梨販攤 → 艾妲（死者名單、梨與秤）→ 梨販家的地窖。
func _update_aftermath() -> void:
	if Game.session.state.get_flag("slice.ada_talked_aftermath", false) or Game.is_player_locked():
		return
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player != null and player.global_position.distance_to(STALL_POS) <= ADA_TALK_RANGE:
		Game.start_dialogue("slice_ada_aftermath")


func _on_cellar() -> void:
	if Game.session.quests.stage_of(GameSession.MAIN_QUEST) != "aftermath":
		return
	if not Game.session.state.get_flag("slice.ada_talked_aftermath", false):
		return
	Game.session.set_flag("slice.cellar_entered", true)
	_banner("SLICE_COMPLETE", 8.0)


func _build_cellar_hatch() -> void:
	var wood := look.mat(FrostbridgeLook.WOOD)
	_batch.add_box_at(Vector3(1.6, 0.08, 1.2), CELLAR_POS + Vector3(0, 0.04, 0), wood, false)
	for i: int in 3:
		_batch.add_box_at(Vector3(1.6, 0.04, 0.06), CELLAR_POS + Vector3(0, 0.1, -0.4 + i * 0.4), look.mat(FrostbridgeLook.ROOF), false)
	_batch.add_box_at(Vector3(0.2, 0.06, 0.12), CELLAR_POS + Vector3(0.5, 0.12, 0.0), look.mat(Color(0.4, 0.36, 0.3), 0.4), false)


# ---------------------------------------------------------------- 送葬者戰

func _caravan_route() -> PackedVector3Array:
	return PackedVector3Array([Vector3(-1.2, 0, 2.0), Vector3(-0.6, 0, 12.0), Vector3(0.0, 0, ARCH_Z),
		Vector3(0.4, 0, 29.0), Vector3(0.0, 0, 38.0)])


func _sheila_spawn() -> Vector3:
	return Vector3(-1.6, 0.0, 8.0)


func _boss_spawn() -> Vector3:
	return Vector3(0.5, 0.0, 15.0)


func _spawn_sheila(pos: Vector3) -> void:
	if has_node("Sheila"):
		return
	var ally := Sheila.new()
	ally.name = "Sheila"
	ally.position = pos
	add_child(ally)


## 護送階段走進南街口 → 送葬者戰開始（只觸發一次）。
func _on_south_street() -> void:
	if encounter != null:
		return
	if Game.session.quests.stage_of(GameSession.MAIN_QUEST) != "escort_convoy":
		return
	start_convoy()


func start_convoy() -> ConvoyEncounter:
	if encounter != null:
		return encounter
	spawn_convoy_fight(true)
	encounter.finished.connect(_on_convoy_finished)
	_banner("CONVOY_START", 3.5)
	return encounter


func _on_convoy_finished(_injured: int) -> void:
	# 任務層面：車隊通過路口 → 收束（ConvoyEncounter 只寫戰鬥結果旗標）
	Game.session.set_flag("slice.convoy_through", true)


# ---------------------------------------------------------------- 觸發區與鏡頭

func _build_story_triggers() -> void:
	_trigger("PearSellerTrigger", STALL_POS + Vector3(-0.8, 1.0, 0.0), Vector3(3.0, 2.0, 3.0), _on_pear_seller)
	_trigger("BellTowerTrigger", Vector3(0.0, 1.0, TOWER_Z + 3.7), Vector3(4.0, 2.0, 2.0), _on_bell_tower)
	_trigger("CellarTrigger", CELLAR_POS + Vector3(0.0, 1.0, 0.0), Vector3(1.8, 2.0, 1.6), _on_cellar)
	_trigger("ConvoyTrigger", Vector3(0.0, 1.0, PLAZA_S + 2.0), Vector3(SOUTH_HALF * 2.0, 2.0, 2.0), _on_south_street)


## 過場鏡頭（CutsceneView 依名字找；slice_bell_nine.json 用到這三個）。
func _build_cutscene_cameras() -> void:
	var t := Vector3(0.0, 0.0, TOWER_Z)
	_camera_marker("BellCamWide", t + Vector3(2.6, 1.7, 19.0), t + Vector3(0.0, 14.5, 0.0))
	_camera_marker("BellCamRope", t + Vector3(2.4, 15.6, 6.2), t + Vector3(0.0, 16.3, 0.0))
	_camera_marker("NorthStreetCam", Vector3(-1.5, 10.0, NORTH_START + 8.0), Vector3(0.0, 1.0, NORTH_END + 4.0))


# ---------------------------------------------------------------- 場景

func _build_ground() -> void:
	# 街道與廣場：濕石板路（概念圖的燈光倒影）。地面方塊的側面埋在地下，看不到
	_batch.add_box_at(Vector3(90.0, 1.0, 130.0), Vector3(0.0, -0.5, -5.0), look.wet_ground(FrostbridgeLook.STONE, 0.42, 0.4))
	# 廣場鋪石（略暗）與中央的圓形石框
	_batch.add_box_at(Vector3(PLAZA_HALF * 2.0, 0.02, PLAZA_S - PLAZA_N), Vector3(0.0, 0.01, 0.0), look.wet_ground(FrostbridgeLook.COBBLE, 0.34, 0.5), false)
	_batch.add_cylinder(3.2, 3.2, 0.05, Vector3(0.0, 0.025, 0.0), look.mat(FrostbridgeLook.STONE, 0.7), false, 32)
	_batch.add_cylinder(2.9, 2.9, 0.06, Vector3(0.0, 0.03, 0.0), look.wet_ground(FrostbridgeLook.COBBLE, 0.34, 0.5), false, 32)
	# 積雪：牆腳的淺色帶
	var snow := look.mat(FrostbridgeLook.SNOW)
	for sx: float in [-1.0, 1.0]:
		_batch.add_box_at(Vector3(1.4, 0.04, PLAZA_S - PLAZA_N), Vector3(sx * (PLAZA_HALF - 0.7), 0.02, 0.0), snow, false)
		_batch.add_box_at(Vector3(1.2, 0.04, PLAZA_N - NORTH_END), Vector3(sx * (MAIN_HALF - 0.6), 0.02, (PLAZA_N + NORTH_END) * 0.5), snow, false)
		_batch.add_box_at(Vector3(1.0, 0.04, CROSS_N - PLAZA_S), Vector3(sx * (SOUTH_HALF - 0.5), 0.02, (PLAZA_S + CROSS_N) * 0.5), snow, false)
	_batch.add_box_at(Vector3(CROSS_HALF * 2.0, 0.04, 1.2), Vector3(0.0, 0.02, CROSS_S - 0.6), snow, false)


func _build_plaza() -> void:
	# 廣場四邊：西、東兩排（沿 z），北、南兩排（沿 x，中間留主街／南街的口）
	_row(Vector3(-PLAZA_HALF, 0, PLAZA_S), Vector3(-PLAZA_HALF, 0, PLAZA_N), Vector3.RIGHT)
	_row(Vector3(PLAZA_HALF, 0, PLAZA_N), Vector3(PLAZA_HALF, 0, PLAZA_S), Vector3.LEFT)
	_row(Vector3(-PLAZA_HALF - 6.0, 0, PLAZA_N), Vector3(-MAIN_HALF, 0, PLAZA_N), Vector3.BACK)
	_row(Vector3(MAIN_HALF, 0, PLAZA_N), Vector3(PLAZA_HALF + 6.0, 0, PLAZA_N), Vector3.BACK)
	_row(Vector3(-SOUTH_HALF, 0, PLAZA_S), Vector3(-PLAZA_HALF - 6.0, 0, PLAZA_S), Vector3.FORWARD)
	_row(Vector3(PLAZA_HALF + 6.0, 0, PLAZA_S), Vector3(SOUTH_HALF, 0, PLAZA_S), Vector3.FORWARD)
	_build_well(Vector3(-6.0, 0.0, -3.5))


func _build_streets() -> void:
	# 主街
	_row(Vector3(-MAIN_HALF, 0, PLAZA_N - 0.3), Vector3(-MAIN_HALF, 0, NORTH_START), Vector3.RIGHT)
	_row(Vector3(MAIN_HALF, 0, NORTH_START), Vector3(MAIN_HALF, 0, PLAZA_N - 0.3), Vector3.LEFT)
	# 北街：每棟獨立節點，第九聲後沉下去
	_row(Vector3(-MAIN_HALF, 0, NORTH_START - 0.3), Vector3(-MAIN_HALF, 0, NORTH_END - 3.0), Vector3.RIGHT, true)
	_row(Vector3(MAIN_HALF, 0, NORTH_END - 3.0), Vector3(MAIN_HALF, 0, NORTH_START - 0.3), Vector3.LEFT, true)
	# 北城牆
	_batch.add_box_at(Vector3(44.0, 9.0, 1.6), Vector3(0.0, 4.5, TOWER_Z - 5.5), look.mat(FrostbridgeLook.WALL_WARM))
	_batch.add_box_at(Vector3(44.6, 0.5, 2.0), Vector3(0.0, 9.2, TOWER_Z - 5.5), look.mat(FrostbridgeLook.ROOF))
	_batch.add_box_at(Vector3(44.6, 0.14, 2.0), Vector3(0.0, 9.5, TOWER_Z - 5.5), look.mat(FrostbridgeLook.SNOW), false)
	# 南街
	_row(Vector3(-SOUTH_HALF, 0, CROSS_N - 0.3), Vector3(-SOUTH_HALF, 0, PLAZA_S + 0.3), Vector3.RIGHT)
	_row(Vector3(SOUTH_HALF, 0, PLAZA_S + 0.3), Vector3(SOUTH_HALF, 0, CROSS_N - 0.3), Vector3.LEFT)
	# 路口：北側兩段、南側一整排、東西兩端封牆
	_row(Vector3(-CROSS_HALF, 0, CROSS_N), Vector3(-SOUTH_HALF - 6.0, 0, CROSS_N), Vector3.BACK)
	_row(Vector3(SOUTH_HALF + 6.0, 0, CROSS_N), Vector3(CROSS_HALF, 0, CROSS_N), Vector3.BACK)
	_row(Vector3(CROSS_HALF, 0, CROSS_S), Vector3(-CROSS_HALF, 0, CROSS_S), Vector3.FORWARD)
	for sx: float in [-1.0, 1.0]:
		_batch.add_box_at(Vector3(1.6, 6.0, CROSS_S - CROSS_N + 2.0), Vector3(sx * (CROSS_HALF + 0.8), 3.0, (CROSS_N + CROSS_S) * 0.5), look.mat(FrostbridgeLook.WALL_WARM))


## 一排房子：從 from 排到 to（都在街道邊線上），正面朝 face（指向街道）。
## 房子之間留窄巷，後面有一道連續的後牆堵住。collapsible=true 時每棟一個節點（北街）。
func _row(from: Vector3, to: Vector3, face: Vector3, collapsible: bool = false) -> void:
	var dir: Vector3 = (to - from).normalized()
	var length: float = from.distance_to(to)
	var t: float = 0.0
	while t < length - 1.0:
		var w: float = _rng.randf_range(4.5, 6.5)
		if length - t - w < 3.0:
			w = length - t
		var depth: float = _rng.randf_range(5.0, 6.5)
		var h: float = _rng.randf_range(4.2, 7.5)
		var center: Vector3 = from + dir * (t + w * 0.5) - face * (depth * 0.5)
		_house(center, w, depth, h, dir, face, collapsible)
		t += w + _rng.randf_range(0.15, 0.4)
	var back: Vector3 = (from + to) * 0.5 - face * 6.9
	_batch.add_box_at(_axis_size(dir, face, length + 1.0, 0.6, 4.0), back + Vector3(0, 2.0, 0), look.mat(FrostbridgeLook.WALL))


static func _axis_size(dir: Vector3, face: Vector3, along: float, across: float, height: float) -> Vector3:
	return Vector3(absf(dir.x) * along + absf(face.x) * across, height, absf(dir.z) * along + absf(face.z) * across)


func _house(center: Vector3, w: float, depth: float, h: float, dir: Vector3, face: Vector3, collapsible: bool) -> void:
	var batch: StaticBatch = _batch
	var holder: Node3D = self
	var origin: Vector3 = center
	if collapsible:
		batch = StaticBatch.new()
		holder = Node3D.new()
		holder.name = "NorthHouse%d" % _north_houses.size()
		holder.position = center
		holder.set_meta("height", h)
		add_child(holder)
		_north_houses.append(holder)
		origin = Vector3.ZERO
	var wall_color: Color = FrostbridgeLook.WALL if _rng.randf() < 0.6 else FrostbridgeLook.WALL_WARM
	batch.add_box_at(_axis_size(dir, face, w, depth, h), origin + Vector3(0, h * 0.5, 0), look.mat(wall_color))
	# 屋簷＋三角屋頂（屋脊沿街道方向）＋屋頂積雪
	batch.add_box_at(_axis_size(dir, face, w + 0.5, depth + 0.7, 0.25), origin + Vector3(0, h + 0.12, 0), look.mat(FrostbridgeLook.ROOF), false)
	var roof_h: float = _rng.randf_range(1.4, 2.4)
	var basis := Basis.IDENTITY if absf(dir.z) > 0.5 else Basis(Vector3.UP, PI * 0.5)
	var roof := PrismMesh.new()
	roof.size = Vector3(depth + 0.7, roof_h, w + 0.5)
	batch.add_mesh(roof, Transform3D(basis, origin + Vector3(0, h + 0.25 + roof_h * 0.5, 0)), look.mat(FrostbridgeLook.ROOF))
	var snow_roof := PrismMesh.new()
	snow_roof.size = Vector3((depth + 0.7) * 0.82, roof_h * 0.82, w + 0.56)
	batch.add_mesh(snow_roof, Transform3D(basis, origin + Vector3(0, h + 0.25 + roof_h * 0.18 + roof_h * 0.82 * 0.5 + 0.06, 0)), look.mat(FrostbridgeLook.SNOW))
	if _rng.randf() < 0.35:
		var c: Vector3 = origin + dir * _rng.randf_range(-w * 0.3, w * 0.3) - face * depth * 0.2
		batch.add_box_at(Vector3(0.6, 1.6, 0.6), c + Vector3(0, h + roof_h * 0.6, 0), look.mat(FrostbridgeLook.WALL_WARM), false)
	# 正面：門＋窗（部分亮燈）
	var front: Vector3 = origin + face * (depth * 0.5)
	var door_off: float = _rng.randf_range(-w * 0.25, w * 0.25)
	batch.add_box_at(_axis_size(dir, face, 1.0, 0.12, 2.1), front + dir * door_off + Vector3(0, 1.05, 0), look.mat(FrostbridgeLook.WOOD), false)
	var lit_mat := look.glow(FrostbridgeLook.LAMP, 1.4)
	var dark_mat := look.mat(Color(0.06, 0.07, 0.09), 0.3)
	var floors: int = 2 if h > 5.6 else 1
	for f: int in floors:
		for side: float in [-1.0, 1.0]:
			var along: float = side * w * 0.3
			if f == 0 and absf(along - door_off) < 1.2:
				continue
			var pos: Vector3 = front + dir * along + Vector3(0, 1.6 + f * 2.4, 0)
			var lit: bool = _rng.randf() < 0.4
			batch.add_box_at(_axis_size(dir, face, 0.7, 0.08, 0.9), pos, lit_mat if lit else dark_mat, false)
			if lit and light_count < 22:
				var l := OmniLight3D.new()
				l.light_color = FrostbridgeLook.LAMP
				l.light_energy = 0.45
				l.omni_range = 3.5
				l.light_volumetric_fog_energy = 0.6
				l.position = pos + face * 0.6
				holder.add_child(l)
				light_count += 1
	if collapsible:
		batch.build(holder, "Mesh")


func _build_well(pos: Vector3) -> void:
	var stone := look.mat(FrostbridgeLook.STONE, 0.8)
	_batch.add_cylinder(1.1, 1.2, 0.8, pos + Vector3(0, 0.4, 0), stone, true, 20)
	_batch.add_cylinder(0.85, 0.85, 0.05, pos + Vector3(0, 0.81, 0), look.mat(Color(0.05, 0.06, 0.08), 0.2), false, 20)
	_batch.add_cylinder(1.15, 1.2, 0.08, pos + Vector3(0, 0.84, 0), look.mat(FrostbridgeLook.SNOW), false, 20)
	var wood := look.mat(FrostbridgeLook.WOOD)
	for sx: float in [-1.0, 1.0]:
		_batch.add_box_at(Vector3(0.14, 2.2, 0.14), pos + Vector3(sx * 1.0, 1.1, 0), wood, false)
	_batch.add_box_at(Vector3(2.3, 0.14, 0.14), pos + Vector3(0, 2.2, 0), wood, false)
	_batch.add_box_at(Vector3(0.05, 0.9, 0.05), pos + Vector3(0, 1.7, 0), look.mat(FrostbridgeLook.ROOF), false)


func _build_lamps() -> void:
	var shadowed: Array[Vector3] = [Vector3(-8.0, 0, 7.5), Vector3(8.0, 0, -7.5), Vector3(-3.2, 0, -20.0),
		Vector3(2.8, 0, 15.0), Vector3(6.0, 0, 38.0)]
	var plain: Array[Vector3] = [Vector3(8.0, 0, 7.5), Vector3(-8.0, 0, -7.5), Vector3(3.2, 0, -34.0),
		Vector3(-2.8, 0, 28.0), Vector3(-9.0, 0, 39.0)]
	for p: Vector3 in shadowed:
		_lamp_post(p, true)
	for p: Vector3 in plain:
		_lamp_post(p, false)


func _lamp_post(pos: Vector3, shadows: bool) -> void:
	_batch.add_box_at(Vector3(0.14, 3.2, 0.14), pos + Vector3(0, 1.6, 0), look.mat(FrostbridgeLook.ROOF))
	_batch.add_box_at(Vector3(0.5, 0.08, 0.5), pos + Vector3(0, 3.45, 0), look.mat(FrostbridgeLook.ROOF), false)
	_batch.add_sphere(0.16, pos + Vector3(0, 3.25, 0), look.glow(FrostbridgeLook.LAMP, 6.0))
	var l := OmniLight3D.new()
	l.light_color = FrostbridgeLook.LAMP
	l.light_energy = 2.2
	l.omni_range = 9.0
	l.shadow_enabled = shadows
	l.light_volumetric_fog_energy = 1.4
	l.position = pos + Vector3(0, 3.0, 0)
	add_child(l)
	light_count += 1


func _build_bell_tower(pos: Vector3) -> void:
	var wall := look.mat(FrostbridgeLook.WALL_WARM)
	var roof := look.mat(FrostbridgeLook.ROOF)
	_batch.add_box_at(Vector3(5.0, 14.0, 5.0), pos + Vector3(0, 7.0, 0), wall)
	_batch.add_box_at(Vector3(5.8, 0.5, 5.8), pos + Vector3(0, 14.25, 0), roof)
	# 鐘室：四根柱子＋頂
	for c: Vector2 in [Vector2(-1.9, -1.9), Vector2(1.9, -1.9), Vector2(-1.9, 1.9), Vector2(1.9, 1.9)]:
		_batch.add_box_at(Vector3(0.6, 3.0, 0.6), pos + Vector3(c.x, 16.0, c.y), wall)
	_batch.add_box_at(Vector3(5.6, 0.5, 5.6), pos + Vector3(0, 17.75, 0), roof)
	var spire := PrismMesh.new()
	spire.size = Vector3(5.6, 3.2, 5.6)
	_batch.add_mesh(spire, Transform3D(Basis.IDENTITY, pos + Vector3(0, 19.6, 0)), roof)
	_batch.add_box_at(Vector3(0.08, 3.2, 5.0), pos + Vector3(0, 19.65, 0), look.mat(FrostbridgeLook.SNOW), false)
	# 塔門與塔窗的暖光
	_batch.add_box_at(Vector3(1.4, 2.4, 0.1), pos + Vector3(0, 1.2, 2.52), look.glow(FrostbridgeLook.LAMP, 2.5), false)
	_batch.add_box_at(Vector3(1.0, 1.6, 0.1), pos + Vector3(0, 9.5, 2.52), look.glow(FrostbridgeLook.LAMP, 4.0), false)
	var l := OmniLight3D.new()
	l.name = "BellLight"
	l.light_color = FrostbridgeLook.LAMP
	l.light_energy = 4.0
	l.omni_range = 16.0
	l.light_volumetric_fog_energy = 2.0
	l.position = pos + Vector3(1.2, 15.4, 2.3)  # 鐘室前緣：敲鐘時照亮鐘身，平時給街道一點暖光
	add_child(l)
	_bell_light = l
	light_count += 1
	var door := OmniLight3D.new()
	door.light_color = FrostbridgeLook.LAMP
	door.light_energy = 1.6
	door.omni_range = 6.0
	door.light_volumetric_fog_energy = 1.2
	door.position = pos + Vector3(0, 1.8, 3.4)
	add_child(door)
	light_count += 1
	# 廢鐘：掛在鐘室正中的橫梁下，鐘口朝下（會擺動，不進合併）
	_batch.add_box_at(Vector3(4.2, 0.2, 0.2), pos + Vector3(0, 17.2, 0), look.mat(FrostbridgeLook.WOOD), false)
	_bell = Node3D.new()
	_bell.name = "Bell"
	_bell.position = pos + Vector3(0, 17.1, 0)
	add_child(_bell)
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.32, 0.26, 0.18)
	bronze.roughness = 0.45
	bronze.metallic = 0.8
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.85
	cyl.height = 1.3
	body.mesh = cyl
	body.position = Vector3(0, -0.85, 0)
	body.material_override = bronze
	_bell.add_child(body)
	var crown := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.42
	sph.height = 0.6
	crown.mesh = sph
	crown.position = Vector3(0, -0.2, 0)
	crown.material_override = bronze
	_bell.add_child(crown)


## 梨販的攤子：木桌、布篷、一盞暖燈、一個披斗篷的人影（之後換成角色）。正面朝 +Z（出生點）。
func _build_pear_stall(pos: Vector3) -> void:
	var wood := look.mat(FrostbridgeLook.WOOD)
	_batch.add_box_at(Vector3(1.6, 0.9, 0.8), pos + Vector3(0, 0.45, 0), wood)
	_batch.add_box_at(Vector3(1.9, 0.06, 1.2), pos + Vector3(0, 2.1, 0.1), look.mat(Color(0.32, 0.12, 0.1)), false)
	for x: float in [-0.85, 0.85]:
		_batch.add_box_at(Vector3(0.07, 2.1, 0.07), pos + Vector3(x, 1.05, 0.55), wood, false)
	var pear := look.mat(Color(0.78, 0.66, 0.3), 0.6)
	for i: int in 6:
		_batch.add_sphere(0.09, pos + Vector3(-0.5 + i * 0.2, 0.99, -0.1 + (i % 2) * 0.15), pear)
	var cloak := look.mat(Color(0.12, 0.12, 0.14))
	_batch.add_cylinder(0.05, 0.32, 1.55, pos + Vector3(0.3, 0.78, -0.75), cloak, false, 12)
	_batch.add_sphere(0.15, pos + Vector3(0.3, 1.62, -0.75), cloak)
	var l := OmniLight3D.new()
	l.light_color = FrostbridgeLook.LAMP
	l.light_energy = 1.4
	l.omni_range = 4.5
	l.light_volumetric_fog_energy = 1.0
	l.position = pos + Vector3(0, 1.85, 0.2)
	add_child(l)
	light_count += 1
