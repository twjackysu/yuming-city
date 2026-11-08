extends StoryLevel
## 霜橋鎮白盒（M1.3）：切片《霜橋鎮的第九聲鐘》的正式關卡（docs/design/05-vertical-slice-plan.md）。
##
## 版面（-Z 是北，單位公尺）：
##   廣場  z∈[-10,10]、x∈[-11,11]：出生點、梨販攤、井、四盞路燈
##   主街  z∈[-30,-10]、寬 8；北段 z∈[-29.2,-25.2] 四級石階往上（概念圖：街道往鐘樓爬坡）
##   北街 z∈[-46,-30]（第九聲後陷落）；鐘樓 z=-50；北城牆 z=-55——都在高 RISE 的台地上
##   南街  z∈[10,34]、寬 7：石拱 z=20（九息）、送葬者戰
##   路口  z∈[34,42]、x∈[-20,20]：傷者車隊的終點
## 靜態幾何全部進 StaticBatch（每種材質一個 draw call）；會動的（北街房子、鐘）各自一個節點。
##
## 開發用旗標（`++ --level=frostbridge ...`）：`--rescue` 跳到救援段落、`--convoy` 直接開打送葬者戰、`--phase2`、
## `--arch=preview|restored|spent`（諾恩站在南街石拱前）、`--at=plaza|main|steps|north|south|cross`（出生位置）、
## `--convoy --throw=arch|kindling [--throw-t=秒]`（直接擲出鐵架，畫面停在擲出後第幾秒）。

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
## 北街＋鐘樓的台地高度；主街北段四級石階（看得到的台階＋看不到的斜坡碰撞，角色不用跨階）
const RISE: float = 0.9
const STEPS_S: float = -25.2
const STEPS_N: float = -29.2
const STEP_COUNT: int = 5

## 檢查點 -> 出生位置（沒列到的用廣場）
const CHECKPOINT_SPAWNS: Dictionary = {
	"rescue": Vector3(0.0, 0.05, -24.0),
	"undertaker": Vector3(0.0, 0.05, 6.0),
}
## `--at=` 開發用出生位置
const DEV_SPAWNS: Dictionary = {
	"plaza": Vector3(0.0, 0.05, 7.0),
	"main": Vector3(0.0, 0.05, -14.0),
	"steps": Vector3(0.6, 0.05, -21.0),
	"north": Vector3(0.0, RISE + 0.05, -32.0),
	"south": Vector3(0.0, 0.05, 12.0),
	"cross": Vector3(0.0, 0.05, 36.0),
}

var look := FrostbridgeLook.new()
var _batch := StaticBatch.new()
## 統計（測試、benchmark 用）
var light_count: int = 0
var lantern_count: int = 0


func _ready() -> void:
	_rng.seed = 19  # 固定種子：截圖前後可對照
	FrostbridgeLook.build_environment(self)
	_build_ground()
	_build_plaza()
	_build_streets()
	_build_bell_tower(Vector3(0.0, RISE, TOWER_Z))
	_build_lamps()
	_build_pear_stall(STALL_POS)
	_build_cellar_hatch()
	_build_reflection_probes(_batch.build(self, "Town"))
	arch_site = NineBreathSite.new()
	arch_site.name = "SouthArch"
	arch_site.position = Vector3(0.0, 0.0, ARCH_Z)
	arch_site.rotation.y = PI  # 正面朝北（車隊和玩家從廣場過來）
	add_child(arch_site)
	_build_story_triggers()
	_build_cutscene_cameras()
	_init_story()

	var dev_args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	# 截圖用：`--convoy` 先把任務推進到送葬者戰（在連接 stage_changed 之前，不會觸發席菈登場段落）
	if dev_args.has("convoy") and StoryLevel.dev_advance_to_convoy(Game.session) and not _north_collapsed:
		collapse_north_street(false)
	var stage: String = Game.session.quests.stage_of(GameSession.MAIN_QUEST)
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
		player.global_position = Vector3(-1.4, RISE + 0.05, -30.2)
	if dev_args.has("convoy"):
		player.global_position = Vector3(0.0, 0.05, 10.0)
		player.rotation.y = PI  # 面向南街
		player.yaw = player.rotation.y
		start_convoy()
		if dev_args.has("phase2") and has_node("Undertaker"):
			($Undertaker as Undertaker).enter_phase_two.call_deferred()
		if dev_args.has("throw"):
			_debug_throw.call_deferred(str(dev_args["throw"]), float(str(dev_args.get("throw-t", "0.3"))))
		if dev_args.has("felled"):
			_debug_felled.call_deferred()
	if dev_args.has("arch"):
		Game.session.state.set_flag("slice.saw_south_arch", true)  # 截圖要看提示，不要先播石拱回憶
		player.global_position = Vector3(0.6, 0.05, ARCH_Z - 4.6)
		player.rotation.y = PI + deg_to_rad(8.0)
		# 跟 `--convoy` 一起用（重現中／化灰）：送葬者站在石拱前（_boss_spawn），諾恩退到他北邊，
		# 鏡頭裡是「送葬者擋在亮起的石拱前」，而不是站進送葬者身體裡（預覽要走近才有提示，維持原位）
		if dev_args.has("convoy") and str(dev_args["arch"]) != "preview":
			player.global_position = Vector3(1.2, 0.05, _boss_spawn().z - 6.5)
			player.rotation.y = PI + deg_to_rad(4.0)
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


## 截圖用：鐵架立刻擲出（arch：石拱先重現），飛行／碎片停在擲出後第 t 秒；燃燒劍不熄。
func _debug_throw(how: String, t: float) -> void:
	var boss: Undertaker = get_node_or_null("Undertaker") as Undertaker
	if boss == null or encounter == null:
		return
	boss.enter_phase_two()
	boss.trigger_frame_throw()
	if how == "arch":
		arch_site.activate()
	if encounter.frame_throw == null:
		return
	encounter.frame_throw.resolve(how, Game.session.state)
	var ally: Sheila = get_node_or_null("Sheila") as Sheila
	if ally != null and how == "kindling":
		ally.ignite_sword(999.0)
	var f: ThrownFrame = encounter.thrown_frame
	if f == null:
		return
	f.set_physics_process(false)
	var left: float = t
	while left > 0.0:
		f.advance(minf(left, 1.0 / 60.0))
		left -= 1.0 / 60.0


## 截圖用：送葬者被斬倒，停在倒地那一刻（`--convoy --felled`）。
func _debug_felled() -> void:
	var boss: Undertaker = get_node_or_null("Undertaker") as Undertaker
	if boss == null:
		return
	boss.debug_hold_fallen = true
	boss.health.apply_damage(boss.health.hp, {"kind": "kindling", "stagger": 0.0})
	# 截圖時藏起諾恩（鏡頭在他正後方，會擋住倒在前面的送葬者）
	for v: Node in ($Player as Node).find_children("*", "GeometryInstance3D", true, false):
		(v as GeometryInstance3D).visible = false


# ---------------------------------------------------------------- 救援（段落 3）

## 北街陷落後才有受困者；讀檔時已陷落也會在這裡生成。
const RESCUE_SPOTS: Dictionary = {
	"north_a": Vector3(-3.0, RISE, -33.0),
	"north_b": Vector3(3.0, RISE, -37.5),
	"north_c": Vector3(-2.8, RISE, -42.0),
	"north_d": Vector3(3.1, RISE, -45.0),
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
const ASHWALKER_POS: Vector3 = Vector3(0.0, RISE, -34.0)
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
	# 協作教學：第一次遇到灰巡者時提示看穿與打弱點（每個存檔只一次）
	if not Game.session.state.get_flag("tutorial.insight_shown", false):
		Game.session.set_flag("tutorial.insight_shown", true)
		get_tree().create_timer(3.4).timeout.connect(_show_insight_tutorial)


func _show_insight_tutorial() -> void:
	if not is_inside_tree():
		return
	var text: String = TranslationServer.translate("TUTORIAL_INSIGHT").format({
		"insight": InputGlyphs.label_for_action("insight", App.last_device),
		"cmd": InputGlyphs.label_for_action("command_weakpoint", App.last_device)})
	_banner(text, 6.0)


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


# ---------------------------------------------------------------- 看見南街石拱（段落 1）

## 第一次走進南街看到石拱：諾恩想起父親躲在柱子後 → 日記解鎖那段記憶（之後的重現代價就是它）。
func _on_arch_memory() -> void:
	if Game.session.state.get_flag("slice.saw_south_arch", false) or encounter != null or Game.is_player_locked():
		return
	Game.start_dialogue("slice_arch_memory")


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
	# 沒先逛過南街也要有這段記憶：重現石拱的代價就是它
	if not Game.session.state.get_flag("slice.saw_south_arch", false):
		Game.session.set_flag("slice.saw_south_arch", true)
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
	_trigger("BellTowerTrigger", Vector3(0.0, RISE + 1.0, TOWER_Z + 3.7), Vector3(4.0, 2.0, 2.0), _on_bell_tower)
	_trigger("CellarTrigger", CELLAR_POS + Vector3(0.0, 1.0, 0.0), Vector3(1.8, 2.0, 1.6), _on_cellar)
	_trigger("ConvoyTrigger", Vector3(0.0, 1.0, PLAZA_S + 2.0), Vector3(SOUTH_HALF * 2.0, 2.0, 2.0), _on_south_street)
	_trigger("ArchMemoryTrigger", Vector3(0.0, 1.0, ARCH_Z - 5.5), Vector3(SOUTH_HALF * 2.0, 2.0, 2.0), _on_arch_memory)


## 過場鏡頭（CutsceneView 依名字找；slice_bell_nine.json 用到這三個）。
func _build_cutscene_cameras() -> void:
	var t := Vector3(0.0, RISE, TOWER_Z)
	_camera_marker("BellCamWide", t + Vector3(2.6, 1.7, 19.0), t + Vector3(0.0, 14.5, 0.0))
	_camera_marker("BellCamRope", t + Vector3(2.4, 15.6, 6.2), t + Vector3(0.0, 16.3, 0.0))
	_camera_marker("NorthStreetCam", Vector3(-1.5, 10.0, NORTH_START + 8.0), Vector3(0.0, RISE + 1.0, NORTH_END + 4.0))


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
		_batch.add_box_at(Vector3(1.2, 0.04, PLAZA_N - STEPS_S), Vector3(sx * (MAIN_HALF - 0.6), 0.02, (PLAZA_N + STEPS_S) * 0.5), snow, false)
		_batch.add_box_at(Vector3(1.2, 0.04, STEPS_N - NORTH_END), Vector3(sx * (MAIN_HALF - 0.6), RISE + 0.02, (STEPS_N + NORTH_END) * 0.5), snow, false)
		_batch.add_box_at(Vector3(1.0, 0.04, CROSS_N - PLAZA_S), Vector3(sx * (SOUTH_HALF - 0.5), 0.02, (PLAZA_S + CROSS_N) * 0.5), snow, false)
	_batch.add_box_at(Vector3(CROSS_HALF * 2.0, 0.04, 1.2), Vector3(0.0, 0.02, CROSS_S - 0.6), snow, false)
	_build_rise()


## 北街＋鐘樓的台地與主街北段的石階。台地本體是石牆（南面露出來的那一階看得到石塊），
## 上面再鋪一層濕石板路；石階一級一個石塊，看不到的斜坡碰撞穿過每一級的前緣。
func _build_rise() -> void:
	var z_n: float = TOWER_Z - 8.0
	var depth: float = STEPS_N - z_n
	_batch.add_box_at(Vector3(50.0, RISE + 1.0, depth), Vector3(0.0, (RISE - 1.0) * 0.5, (STEPS_N + z_n) * 0.5), look.stone_wall(1.0))
	_batch.add_box_at(Vector3(50.0, 0.02, depth), Vector3(0.0, RISE + 0.01, (STEPS_N + z_n) * 0.5), look.wet_ground(FrostbridgeLook.STONE, 0.42, 0.4), false)
	var run: float = (STEPS_S - STEPS_N) / float(STEP_COUNT - 1)  # 每級的深度
	var step_h: float = RISE / float(STEP_COUNT)
	var stone := look.stone_wall(1.0)  # 跟後牆同一個材質（不多一個 draw call）
	var tread := look.wet_ground(FrostbridgeLook.STONE, 0.42, 0.4)  # 踏面跟台地上的濕石板同一個材質
	var snow := look.mat(FrostbridgeLook.SNOW)
	for i: int in STEP_COUNT - 1:
		var top: float = step_h * float(i + 1)
		var front: float = STEPS_S - run * float(i)
		# 每一級從前緣一路延伸到台地（上一級蓋住後段），兩側離房子 5 cm 避免共面閃爍
		_batch.add_box_at(Vector3(MAIN_HALF * 2.0 - 0.1, top, front - STEPS_N), Vector3(0.0, top * 0.5, (front + STEPS_N) * 0.5), stone, false)
		# 看得到的踏面鋪濕石板（之前石牆材質在霧裡偏灰白、偏平）；前緣一條薄雪蓋在上面
		_batch.add_box_at(Vector3(MAIN_HALF * 2.0 - 0.1, 0.01, run), Vector3(0.0, top + 0.005, front - run * 0.5), tread, false)
		_batch.add_box_at(Vector3(MAIN_HALF * 2.0 - 0.6, 0.02, 0.12), Vector3(0.0, top + 0.015, front - 0.08), snow, false)
	# 斜坡碰撞：上表面通過每一級的前緣——從第一級前面一級深度處的地面（STEPS_S + run）到台地邊（STEPS_N）
	var horizontal: float = STEPS_S + run - STEPS_N
	var angle: float = atan2(RISE, horizontal)
	var slope_len: float = Vector2(horizontal, RISE).length()
	var normal := Vector3(0.0, cos(angle), sin(angle))
	var mid := Vector3(0.0, RISE * 0.5, (STEPS_S + run + STEPS_N) * 0.5)
	var body := StaticBody3D.new()
	body.name = "StepsRamp"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(MAIN_HALF * 2.0, 0.4, slope_len)
	shape.shape = box
	shape.transform = Transform3D(Basis(Vector3.RIGHT, angle), mid - normal * 0.2)
	body.add_child(shape)
	add_child(body)


## 地面高度（台地上是 RISE；石階上沿斜坡）。測試與開發用瞬移用。
func ground_y(p: Vector3) -> float:
	var run: float = (STEPS_S - STEPS_N) / float(STEP_COUNT - 1)
	if p.z <= STEPS_N and absf(p.x) < 25.0:
		return RISE
	if p.z < STEPS_S + run and absf(p.x) < MAIN_HALF:
		return RISE * (STEPS_S + run - p.z) / (STEPS_S + run - STEPS_N)
	return 0.0


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
	_row(Vector3(-MAIN_HALF, RISE, NORTH_START - 0.3), Vector3(-MAIN_HALF, RISE, NORTH_END - 3.0), Vector3.RIGHT, true)
	_row(Vector3(MAIN_HALF, RISE, NORTH_END - 3.0), Vector3(MAIN_HALF, RISE, NORTH_START - 0.3), Vector3.LEFT, true)
	# 北城牆
	_batch.add_box_at(Vector3(44.0, 9.0, 1.6), Vector3(0.0, RISE + 4.5, TOWER_Z - 5.5), look.stone_wall(1.6))
	_batch.add_box_at(Vector3(44.6, 0.5, 2.0), Vector3(0.0, RISE + 9.2, TOWER_Z - 5.5), look.mat(FrostbridgeLook.ROOF))
	_batch.add_box_at(Vector3(44.6, 0.14, 2.0), Vector3(0.0, RISE + 9.5, TOWER_Z - 5.5), look.mat(FrostbridgeLook.SNOW), false)
	# 南街
	_row(Vector3(-SOUTH_HALF, 0, CROSS_N - 0.3), Vector3(-SOUTH_HALF, 0, PLAZA_S + 0.3), Vector3.RIGHT)
	_row(Vector3(SOUTH_HALF, 0, PLAZA_S + 0.3), Vector3(SOUTH_HALF, 0, CROSS_N - 0.3), Vector3.LEFT)
	# 路口：北側兩段、南側一整排、東西兩端封牆
	_row(Vector3(-CROSS_HALF, 0, CROSS_N), Vector3(-SOUTH_HALF - 6.0, 0, CROSS_N), Vector3.BACK)
	_row(Vector3(SOUTH_HALF + 6.0, 0, CROSS_N), Vector3(CROSS_HALF, 0, CROSS_N), Vector3.BACK)
	_row(Vector3(CROSS_HALF, 0, CROSS_S), Vector3(-CROSS_HALF, 0, CROSS_S), Vector3.FORWARD)
	for sx: float in [-1.0, 1.0]:
		_batch.add_box_at(Vector3(1.6, 6.0, CROSS_S - CROSS_N + 2.0), Vector3(sx * (CROSS_HALF + 0.8), 3.0, (CROSS_N + CROSS_S) * 0.5), look.stone_wall(1.6))


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
	_batch.add_box_at(_axis_size(dir, face, length + 1.0, 0.6, 4.0), back + Vector3(0, 2.0, 0), look.stone_wall())


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
	var plaster: Color = FrostbridgeLook.PLASTER if _rng.randf() < 0.6 else FrostbridgeLook.PLASTER_WARM
	batch.add_box_at(_axis_size(dir, face, w, depth, h), origin + Vector3(0, h * 0.5, 0), look.half_timber(plaster))
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
		batch.add_box_at(Vector3(0.6, 1.6, 0.6), c + Vector3(0, h + roof_h * 0.6, 0), look.stone_wall(), false)
	# 正面：門＋窗（部分亮燈）
	var front: Vector3 = origin + face * (depth * 0.5)
	var door_off: float = _rng.randf_range(-w * 0.25, w * 0.25)
	batch.add_box_at(_axis_size(dir, face, 1.0, 0.12, 2.1), front + dir * door_off + Vector3(0, 1.05, 0), look.mat(FrostbridgeLook.WOOD), false)
	var lit_mat := look.glow(FrostbridgeLook.LAMP, 1.4)
	var dark_mat := look.mat(Color(0.06, 0.07, 0.09), 0.3)
	# 門邊的掛燈（概念圖：每幾戶門口一盞）。用位置算的雜湊決定，不動 _rng（房子配置保持不變）。
	# 有掛燈的房子，窗戶只發光不另外打燈（燈數上限見 test_frostbridge）。
	var lantern: bool = fposmod(sin(center.x * 12.9898 + center.z * 78.233) * 43758.5453, 1.0) < 0.45
	if lantern:
		var side: float = 1.0 if door_off < 0.0 else -1.0
		_door_lantern(batch, holder, front + dir * (door_off + side * 0.85), face)
	var floors: int = 2 if h > 5.6 else 1
	for f: int in floors:
		for side: float in [-1.0, 1.0]:
			var along: float = side * w * 0.3
			if f == 0 and absf(along - door_off) < 1.2:
				continue
			var pos: Vector3 = front + dir * along + Vector3(0, 1.6 + f * 2.4, 0)
			var lit: bool = _rng.randf() < 0.4
			batch.add_box_at(_axis_size(dir, face, 0.7, 0.08, 0.9), pos, lit_mat if lit else dark_mat, false)
			if lit and not lantern and light_count < 22:
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


## 門邊掛燈：木支架從牆伸出、燈罩發光、上面一片小屋頂；燈數還有額度時加一盞暖光。
func _door_lantern(batch: StaticBatch, holder: Node3D, wall_pos: Vector3, face: Vector3) -> void:
	var wood := look.mat(FrostbridgeLook.WOOD)
	var iron := look.mat(Color(0.07, 0.07, 0.08), 0.5)
	var out: Vector3 = wall_pos + face * 0.32
	lantern_count += 1
	batch.add_box_at(Vector3(0.06, 0.06, 0.06) + Vector3(absf(face.x), 0, absf(face.z)) * 0.5, wall_pos + face * 0.25 + Vector3(0, 2.62, 0), wood, false)
	batch.add_box_at(Vector3(0.02, 0.18, 0.02), out + Vector3(0, 2.5, 0), iron, false)
	batch.add_box_at(Vector3(0.3, 0.05, 0.3), out + Vector3(0, 2.4, 0), iron, false)
	batch.add_box_at(Vector3(0.2, 0.28, 0.2), out + Vector3(0, 2.23, 0), look.glow(FrostbridgeLook.LAMP, 3.2), false)
	batch.add_box_at(Vector3(0.24, 0.04, 0.24), out + Vector3(0, 2.07, 0), iron, false)
	if light_count < 22:
		var l := OmniLight3D.new()
		l.light_color = FrostbridgeLook.LAMP
		l.light_energy = 0.85
		l.omni_range = 5.0
		l.omni_attenuation = 1.4
		l.light_specular = LAMP_SPECULAR
		l.light_volumetric_fog_energy = 1.2
		l.position = out + face * 0.15 + Vector3(0, 2.2, 0)
		holder.add_child(l)
		light_count += 1


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
	var plain: Array[Vector3] = [Vector3(8.0, 0, 7.5), Vector3(-8.0, 0, -7.5), Vector3(3.2, RISE, -34.0),
		Vector3(-2.8, 0, 28.0), Vector3(-9.0, 0, 39.0)]
	for p: Vector3 in shadowed:
		_lamp_post(p, true)
	for p: Vector3 in plain:
		_lamp_post(p, false)
	_build_step_lanterns()


## 石階兩側的矮石燈柱（D-062）：石階底下與台地邊各一對，小燈籠照亮踏面的前緣，
## 往鐘樓爬的那一段不再是霧裡的一片暗。不投影、範圍小（燈的數量上限見 test_frostbridge）。
const STEP_LANTERN_X: float = MAIN_HALF - 0.38
var step_lanterns: Array[OmniLight3D] = []


func _build_step_lanterns() -> void:
	var stone := look.stone_wall(1.0)
	var roof := look.mat(FrostbridgeLook.ROOF)
	var glow := look.glow(FrostbridgeLook.LAMP, 6.0)  # 跟路燈同一個材質（不多一個 draw call）
	for z_y: Vector2 in [Vector2(STEPS_S + 0.45, 0.0), Vector2(STEPS_N - 0.45, RISE)]:
		for sx: float in [-1.0, 1.0]:
			var base := Vector3(sx * STEP_LANTERN_X, z_y.y, z_y.x)
			_batch.add_box_at(Vector3(0.34, 0.8, 0.34), base + Vector3(0, 0.4, 0), stone)
			_batch.add_box_at(Vector3(0.42, 0.07, 0.42), base + Vector3(0, 0.835, 0), roof, false)
			_batch.add_box_at(Vector3(0.17, 0.2, 0.17), base + Vector3(0, 0.97, 0), glow, false)
			_batch.add_box_at(Vector3(0.27, 0.05, 0.27), base + Vector3(0, 1.095, 0), roof, false)
			var l := OmniLight3D.new()
			l.name = "StepLantern%d" % step_lanterns.size()
			l.light_color = FrostbridgeLook.LAMP
			l.light_energy = 1.1
			l.omni_range = 3.8
			l.shadow_enabled = false
			l.light_specular = LAMP_SPECULAR
			l.light_volumetric_fog_energy = 0.8
			l.position = base + Vector3(0, 0.97, 0)
			add_child(l)
			step_lanterns.append(l)
			light_count += 1


## 水窪倒影（D-051）：廣場、主街、南街各一個 ReflectionProbe（載入時拍一次、盒狀投影）。
## 中畫質沒有 SSR，濕石板路的水窪靠它映出路燈、掛燈、亮著的窗和兩側的房子。
## 只拍「倒影層」：小鎮合併後的靜態幾何，所以角色、敵人、車隊不會被凍在倒影裡。
const REFLECT_LAYER: int = 1 << 10
const PROBE_HEIGHT: float = 9.0
const PROBE_EYE: float = 1.5  # 從離地 1.5 m 拍（大約是鏡頭高度）
## 路燈、門邊掛燈、梨販燈的高光強度（D-058；Godot 預設 0.5）：濕石板上的燈影拉得長、亮得出來
const LAMP_SPECULAR: float = 1.0


func _build_reflection_probes(town: Node3D) -> void:
	for c: Node in town.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi != null:
			mi.layers |= REFLECT_LAYER
	_probe("ProbePlaza", 0.0, PLAZA_N, PLAZA_S, PLAZA_HALF)
	_probe("ProbeMain", 0.0, STEPS_S, PLAZA_N, MAIN_HALF)
	_probe("ProbeSouth", 0.0, PLAZA_S, CROSS_N, SOUTH_HALF)


func _probe(probe_name: String, y: float, z_from: float, z_to: float, half: float) -> void:
	var p := ReflectionProbe.new()
	p.name = probe_name
	p.update_mode = ReflectionProbe.UPDATE_ONCE
	p.box_projection = true
	p.cull_mask = REFLECT_LAYER
	p.size = Vector3(half * 2.0, PROBE_HEIGHT, z_to - z_from)
	# 盒子從地面下 0.5 m 開始（地面要在盒子裡才會取樣到倒影）
	p.position = Vector3(0.0, y - 0.5 + PROBE_HEIGHT * 0.5, (z_from + z_to) * 0.5)
	p.origin_offset = Vector3(0.0, PROBE_EYE + 0.5 - PROBE_HEIGHT * 0.5, 0.0)
	p.blend_distance = 1.5
	p.intensity = 3.0
	add_child(p)


func _lamp_post(pos: Vector3, shadows: bool) -> void:
	_batch.add_box_at(Vector3(0.14, 3.2, 0.14), pos + Vector3(0, 1.6, 0), look.mat(FrostbridgeLook.ROOF))
	_batch.add_box_at(Vector3(0.5, 0.08, 0.5), pos + Vector3(0, 3.45, 0), look.mat(FrostbridgeLook.ROOF), false)
	_batch.add_sphere(0.16, pos + Vector3(0, 3.25, 0), look.glow(FrostbridgeLook.LAMP, 6.0))
	var l := OmniLight3D.new()
	l.light_color = FrostbridgeLook.LAMP
	l.light_energy = 2.2
	l.omni_range = 9.0
	l.shadow_enabled = shadows
	l.light_specular = LAMP_SPECULAR
	l.light_volumetric_fog_energy = 1.4
	l.position = pos + Vector3(0, 3.0, 0)
	add_child(l)
	light_count += 1


func _build_bell_tower(pos: Vector3) -> void:
	var wall := look.stone_wall(1.3)
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
	# 舊青銅：金屬度不能太高——夜裡沒有可反射的環境，高金屬度的鐘在敲鐘鏡頭裡只剩一個黑影
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.46, 0.34, 0.2)
	bronze.roughness = 0.42
	bronze.metallic = 0.35
	bronze.rim_enabled = true
	bronze.rim = 0.35
	bronze.rim_tint = 0.6
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
	# 鐘口外翻的唇：輪廓才像鐘，不像倒放的桶
	var lip := MeshInstance3D.new()
	var lip_mesh := CylinderMesh.new()
	lip_mesh.top_radius = 0.84
	lip_mesh.bottom_radius = 0.95
	lip_mesh.height = 0.14
	lip.mesh = lip_mesh
	lip.position = Vector3(0, -1.5 + 0.07, 0)
	lip.material_override = bronze
	_bell.add_child(lip)


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
	l.light_specular = LAMP_SPECULAR
	l.light_volumetric_fog_energy = 1.0
	l.position = pos + Vector3(0, 1.85, 0.2)
	add_child(l)
	light_count += 1
