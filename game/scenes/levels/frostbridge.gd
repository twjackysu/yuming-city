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
## `--convoy --throw=arch|kindling [--throw-t=秒]`（直接擲出鐵架，畫面停在擲出後第幾秒）、`--hide=noen`（藏起諾恩）、`--pos=x,z`（最後把諾恩移到這裡）、`--face=...` `--face-off=度`。

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
var window_count: int = 0
var door_count: int = 0
var lit_window_count: int = 0
## D-096：樓上補開的窗、門邊的店招（測試用）
var upper_window_count: int = 0
var shop_sign_count: int = 0
var shop_sign_icons: Array[int] = []
## 用屋瓦材質的完整屋頂數（D-107）
var roof_count: int = 0
## 屋頂雪下緣的扁雪堆數（D-112）
var roof_snow_lips: int = 0
## 屋頂的雪蓋住上面多少（以屋頂高度的比例；原本 0.82，D-107 改成露出最下面三四排瓦）
const ROOF_SNOW: float = 0.7
## 房子亮窗的發光強度（window_glass.gdshader 每扇再乘 0.75～1.2，D-066）
const WINDOW_ENERGY: float = 1.5


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
		player.global_position = Vector3(-2.0, RISE + 0.05, -31.3)  # 離第一個受困者（north_a）約 1.8 m，提示會出現
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
	# 截圖用：`--insight` 一開始就按住看穿（README 的戰鬥圖改拍霜橋鎮送葬者戰，第二輪盤點第 2 項）
	if dev_args.has("insight"):
		dev_hold_insight()
	if dev_args.has("arch"):
		Game.session.state.set_flag("slice.saw_south_arch", true)  # 截圖要看提示，不要先播石拱回憶
		player.global_position = Vector3(0.6, 0.05, ARCH_Z - 4.6)
		player.rotation.y = PI + deg_to_rad(8.0)
		# 跟 `--convoy` 一起用（重現中／化灰）：送葬者站在石拱前（_boss_spawn），諾恩退到他北邊，
		# 鏡頭裡是「送葬者擋在亮起的石拱前」，而不是站進送葬者身體裡（預覽要走近才有提示，維持原位）
		if dev_args.has("convoy") and str(dev_args["arch"]) != "preview":
			player.global_position = Vector3(1.2, 0.05, _boss_spawn().z - 6.5)
			player.rotation.y = PI + deg_to_rad(4.0)
		elif dev_args.has("convoy"):
			# 預覽要站在石拱 5 m 內，送葬者卻就生在石拱前，鐵架會擋住預覽的石拱（第二輪盤點第 8 項）：
			# 截圖時把他停在諾恩背後、鏡頭後面，畫面裡是石拱預覽＋代價卡，車隊戰的 HUD 照舊
			dev_park_boss(player.global_position + Vector3(1.8, 0.0, -5.5))
		player.yaw = player.rotation.y
		match str(dev_args["arch"]):
			"preview":
				arch_site.debug_preview = true
			"restored":
				arch_site.activate.call_deferred()
			"spent":
				arch_site.activate()
				arch_site.nb.tick(9.5, Game.session.state)
	# 截圖用：`--face=sheila|undertaker|frame|arch`：每幀把諾恩（和鏡頭）轉向那個角色（arch＝南街石拱）。
	# 燃燒劍斬鐵架的火星在諾恩背後，平常的鏡頭拍不到（NEXT 第 2 項、Steam 截圖 6）
	if dev_args.has("face"):
		_dev_face = str(dev_args["face"])
	# 截圖用：`--pos=x,z` 最後再把諾恩移到這裡（其他旗標排好場面之後換個拍攝位置；高度照地面）。
	# 例：燃燒劍斬鐵架時送葬者站在諾恩正後方，鏡頭會卡進他身體裡 → `--pos=2.6,6.5 --face=sheila --face-off=16` 從側面拍
	if dev_args.has("pos"):
		dev_place_player(str(dev_args["pos"]))
	# `--face-off=度`：轉向目標之後再往左轉幾度，目標落在畫面右側、不被諾恩的背影擋住
	if dev_args.has("face-off"):
		_dev_face_off = float(str(dev_args["face-off"]))
	# 截圖用：`--hide=noen` 藏起諾恩（商店截圖：石拱預覽、燃燒劍，盤點第 5 項）
	if str(dev_args.get("hide", "")) == "noen":
		dev_hide_player.call_deferred()
	player.snap_camera()


## 截圖用：按住看穿（跟沙盒的 `--insight` 一樣，直接按下輸入動作；放開要呼叫 Input.action_release）。
func dev_hold_insight() -> void:
	Input.action_press("insight")


## 截圖用：送葬者移到 at（高度照地面）並停住不動（不追、不出招）。沒有送葬者回傳 false。
func dev_park_boss(at: Vector3) -> bool:
	var boss: Undertaker = get_node_or_null("Undertaker") as Undertaker
	if boss == null:
		return false
	boss.global_position = Vector3(at.x, ground_y(at) + 0.05, at.z)
	boss.velocity = Vector3.ZERO
	boss.set_physics_process(false)
	return true


## 截圖用：把諾恩移到 "x,z"（高度照地面）。格式不對就不動，回傳有沒有移動。
func dev_place_player(spec: String) -> bool:
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	var xz: PackedStringArray = spec.split(",")
	if player == null or xz.size() != 2 or not xz[0].is_valid_float() or not xz[1].is_valid_float():
		return false
	var at := Vector3(float(xz[0]), 0.0, float(xz[1]))
	player.global_position = Vector3(at.x, ground_y(at) + 0.05, at.z)
	player.snap_camera()
	return true


## `--face` 的目標（找不到回傳 null）。
func dev_face_target(who: String) -> Node3D:
	match who:
		"sheila":
			return get_node_or_null("Sheila") as Node3D
		"undertaker":
			return get_node_or_null("Undertaker") as Node3D
		"frame":
			return encounter.thrown_frame if encounter != null and is_instance_valid(encounter.thrown_frame) else null
		"arch":
			return arch_site
	return null


## 諾恩面向目標（只轉水平角度），鏡頭跟著轉到他正後方。
func _update_dev_face() -> void:
	var target: Node3D = dev_face_target(_dev_face)
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if target == null or player == null:
		return
	var d: Vector3 = target.global_position - player.global_position
	d.y = 0.0
	if d.length() < 0.3:
		return
	player.rotation.y = atan2(-d.x, -d.z) + deg_to_rad(_dev_face_off)
	player.yaw = player.rotation.y
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
	dev_hide_player()


## 截圖用：藏起諾恩的模型（提燈的光留著）。`--felled` 與 `--hide=noen` 用。
func dev_hide_player() -> void:
	var p: Node = get_node_or_null("Player")
	if p == null:
		return
	for v: Node in p.find_children("*", "GeometryInstance3D", true, false):
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
## 截圖旗標 `--face` 的目標（""＝不轉）
var _dev_face: String = ""
## `--face-off`：轉向目標後再往左轉的角度（度；正＝往左轉，目標落到畫面右側）
var _dev_face_off: float = 0.0


func _on_stage_changed(quest_id: String, _from: String, to_stage: String) -> void:
	if quest_id == GameSession.MAIN_QUEST and to_stage == "meet_sheila":
		_begin_sheila_meet()


## 席菈出現；已經談過（讀檔）就直接放灰巡者。
func _begin_sheila_meet() -> void:
	_spawn_sheila(SHEILA_WAIT_POS)
	if Game.session.state.get_flag("slice.sheila_talked", false):
		_spawn_ashwalker()


func _physics_process(_delta: float) -> void:
	if _dev_face != "":
		_update_dev_face()
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
	# 地上的殘雪、髒雪與車轍（D-114）：先設好，之後建立的濕石板材質都會套上
	look.set_ground_marks(ground_lanes(), TRODDEN, RUT_PATH)
	# 街道與廣場：濕石板路（概念圖的燈光倒影）。地面方塊的側面埋在地下，看不到
	_batch.add_box_at(Vector3(90.0, 1.0, 130.0), Vector3(0.0, -0.5, -5.0), look.wet_ground(FrostbridgeLook.STONE, 0.42, 0.4))
	# 廣場鋪石（略暗，繞中央石框一圈圈弧形鋪，D-120）與中央的圓形石框
	_batch.add_box_at(Vector3(PLAZA_HALF * 2.0, 0.02, PLAZA_S - PLAZA_N), Vector3(0.0, 0.01, 0.0), plaza_ground(), false)
	_build_plaza_ring()
	# 積雪：牆腳的雪帶（D-105：靠牆堆高、靠街邊緣不規則的一串雪堆，取代平的淺色帶）
	for sx: float in [-1.0, 1.0]:
		var wall := Vector3(sx, 0, 0)
		_snow_bank(Vector3(sx * PLAZA_HALF, 0.02, PLAZA_S), Vector3(sx * PLAZA_HALF, 0.02, PLAZA_N), wall, 1.4)
		_snow_bank(Vector3(sx * MAIN_HALF, 0.0, PLAZA_N), Vector3(sx * MAIN_HALF, 0.0, STEPS_S), wall, 1.2)
		_snow_bank(Vector3(sx * MAIN_HALF, RISE, STEPS_N), Vector3(sx * MAIN_HALF, RISE, NORTH_END), wall, 1.2)
		_snow_bank(Vector3(sx * SOUTH_HALF, 0.0, PLAZA_S), Vector3(sx * SOUTH_HALF, 0.0, CROSS_N), wall, 1.0)
	_snow_bank(Vector3(-CROSS_HALF, 0.0, CROSS_S), Vector3(CROSS_HALF, 0.0, CROSS_S), Vector3.BACK, 1.2)
	_build_rise()


## 地上的殘雪與髒雪（D-114，第四輪盤點第 4 項）：廣場下半畫面原本是一大片空的暗石板。
## 濕石板 shader 依「離牆多近」在石縫裡卡雪（靠牆、角落多）、井邊與梨販攤前一圈踩實的灰褐髒雪、
## 一道從西側手推車往北繞過井與石框、進主街的車轍。全部在 shader 裡（不擋人、不進碰撞、不多 draw call）。
## 街道範圍：中心 x、z，半寬 x、z。街道往廣場裡多伸一段，街口才不會被當成牆。
func ground_lanes() -> Array[Vector4]:
	return [
		Vector4(0.0, 0.0, PLAZA_HALF, PLAZA_S),
		Vector4(0.0, (NORTH_END - 1.0) * 0.5, MAIN_HALF, (1.0 - NORTH_END) * 0.5),
		Vector4(0.0, CROSS_S * 0.5, SOUTH_HALF, CROSS_S * 0.5),  # 一路伸到路口南邊的牆：南街口不會積成一道雪
		Vector4(0.0, (CROSS_N + CROSS_S) * 0.5, CROSS_HALF, (CROSS_S - CROSS_N) * 0.5),
	]


## 踩實的髒雪：井邊一圈（井身外半徑 1.2）、梨販攤前一片（攤子在 STALL_POS，正面朝南）
const TRODDEN: Array[Vector4] = [
	Vector4(-6.0, -3.5, 1.15, 2.7),
	Vector4(4.3, 0.5, 0.0, 2.1),
]
## 車轍中心線：西側手推車（HANDCART_POS，兩輪相距約 1.37 m、沿 X 滾）往東出來，往北繞過井與中央石框，進主街
const RUT_PATH: PackedVector2Array = [
	Vector2(-9.3, 0.9), Vector2(-6.9, 0.6), Vector2(-4.3, -1.9), Vector2(-3.0, -5.8), Vector2(-2.3, -10.0), Vector2(-2.0, -14.5),
]


## 街邊雪帶（D-105，第三輪盤點第 8 項）：原本是一條 4 cm 高的平板，低角度看是一條平的淺色帶。
## 改成沿著牆腳一串互相重疊的 SnowMound：最高點偏向牆（靠牆那側高而陡、碰到牆時還很厚），
## 往街那側慢慢變薄、邊緣不規則；每個雪堆的長短、寬窄、高低用位置雜湊（不動 _rng）。
## 雪堆有一段埋進牆裡（看不到），靠街那側伸出來的寬度跟原本的雪帶一樣（reach）。沒有碰撞。
## from／to：牆腳線（房子正面那條線）的兩端，y 是那段地面的高度；wall：從街道指向牆的方向。
const SNOW_BANK_STEP: float = 1.8
const SNOW_BANK_INTO_WALL: float = 0.3
## 每一個街邊雪堆：x、z 是中心，y 是最高點離地多高，w 是靠街那側伸出牆外多遠（給測試看）
var snow_banks: Array[Vector4] = []


func _snow_bank(from: Vector3, to: Vector3, wall: Vector3, reach: float) -> void:
	var length: float = from.distance_to(to)
	var dir: Vector3 = (to - from) / length
	# 雪堆模型的 X＝沿著牆、Z＝X × Y；最高點往牆那邊偏
	var side: Vector3 = dir.cross(Vector3.UP)
	var toward_wall: float = signf(side.dot(wall))
	var basis := Basis(dir, Vector3.UP, side)
	var n: int = maxi(1, roundi(length / SNOW_BANK_STEP))
	var step: float = length / float(n)
	for k: int in n:
		var c0: Vector3 = from + dir * (step * (float(k) + 0.5))
		var h0: float = _house_hash(c0, 400.0)
		var h1: float = _house_hash(c0, 401.0)
		var h2: float = _house_hash(c0, 402.0)
		var seg_len: float = step * lerpf(1.3, 1.6, h0)
		var t: float = clampf(step * (float(k) + 0.5) + (h1 - 0.5) * step * 0.3, seg_len * 0.5, length - seg_len * 0.5)
		var out: float = reach * lerpf(0.75, 1.1, h2)  # 靠街那側伸出牆外多遠
		var w: float = out + SNOW_BANK_INTO_WALL
		var hgt: float = lerpf(0.13, 0.24, _house_hash(c0, 403.0))
		var center: Vector3 = from + dir * t - wall * (w * 0.5 - SNOW_BANK_INTO_WALL)
		var mesh: ArrayMesh = SnowMound.build(seg_len, w, hgt, c0.x * 1.7 + c0.z * 3.3, Vector2(0.0, 0.5 * toward_wall))
		_batch.add_mesh(mesh, Transform3D(basis, center), look.snow())
		snow_banks.append(Vector4(center.x, hgt, center.z, out))


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
	var snow := look.snow()
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


## 廣場中央的圓形石框（D-077）：一圈比鋪石淺、斜邊的整塊石緣（燈光照得到斜面），裡面是低一點的鋪石，
## 正中央一個鐘紋石盤（淺色外圈、深色溝、內圈），霜橋鎮是敲鐘的鎮。石緣只高 7 cm、不加碰撞
## （車隊與角色會走過去）。之前是兩片幾乎一樣高、顏色接近的薄圓盤，遠看只是一圈淡淡的線。
const PLAZA_RING_R: float = 3.2
var plaza_ring_parts: int = 0


## 廣場的濕石板（D-120）：繞中央石框弧形鋪；石框裡（內圈鋪石的範圍）不蓋殘雪與薄雪
func plaza_ground() -> ShaderMaterial:
	return look.wet_ground_arc(FrostbridgeLook.COBBLE, 0.34, 0.5, Vector2.ZERO, PLAZA_RING_R - 0.4)


func _build_plaza_ring() -> void:
	var curb := look.mat(FrostbridgeLook.STONE.lightened(0.28), 0.55)
	var groove := look.mat(Color(0.05, 0.055, 0.065), 0.35)
	var inner := plaza_ground()  # 石框裡跟廣場同一個材質，但不蓋殘雪（D-120）
	# 石緣外側的一圈深色石縫，讓石緣跟鋪石分開
	_batch.add_cylinder(PLAZA_RING_R + 0.12, PLAZA_RING_R + 0.12, 0.03, Vector3(0.0, 0.02, 0.0), groove, false, 48)
	_batch.add_cylinder(PLAZA_RING_R - 0.05, PLAZA_RING_R + 0.08, 0.07, Vector3(0.0, 0.035, 0.0), curb, false, 48)
	_batch.add_cylinder(PLAZA_RING_R - 0.4, PLAZA_RING_R - 0.4, 0.05, Vector3(0.0, 0.05, 0.0), inner, false, 48)
	# 鐘紋石盤
	_batch.add_cylinder(0.95, 1.0, 0.06, Vector3(0.0, 0.055, 0.0), curb, false, 40)
	_batch.add_cylinder(0.78, 0.78, 0.06, Vector3(0.0, 0.06, 0.0), groove, false, 40)
	_batch.add_cylinder(0.66, 0.7, 0.06, Vector3(0.0, 0.065, 0.0), curb, false, 40)
	_batch.add_cylinder(0.16, 0.16, 0.06, Vector3(0.0, 0.07, 0.0), groove, false, 20)
	plaza_ring_parts = 7


func _build_plaza() -> void:
	# 廣場四邊：西、東兩排（沿 z），北、南兩排（沿 x，中間留主街／南街的口）
	_row(Vector3(-PLAZA_HALF, 0, PLAZA_S), Vector3(-PLAZA_HALF, 0, PLAZA_N), Vector3.RIGHT)
	_row(Vector3(PLAZA_HALF, 0, PLAZA_N), Vector3(PLAZA_HALF, 0, PLAZA_S), Vector3.LEFT)
	_row(Vector3(-PLAZA_HALF - 6.0, 0, PLAZA_N), Vector3(-MAIN_HALF, 0, PLAZA_N), Vector3.BACK)
	_row(Vector3(MAIN_HALF, 0, PLAZA_N), Vector3(PLAZA_HALF + 6.0, 0, PLAZA_N), Vector3.BACK)
	_row(Vector3(-SOUTH_HALF, 0, PLAZA_S), Vector3(-PLAZA_HALF - 6.0, 0, PLAZA_S), Vector3.FORWARD)
	_row(Vector3(PLAZA_HALF + 6.0, 0, PLAZA_S), Vector3(SOUTH_HALF, 0, PLAZA_S), Vector3.FORWARD)
	_build_well(Vector3(-6.0, 0.0, -3.5))
	_build_plaza_barrels()
	_build_woodpile(WOODPILE_POS)
	_build_handcart(HANDCART_POS)
	_build_fence(FENCE_PATH)


## 廣場東側牆邊的柴堆（D-103，第三輪盤點第 7 項）：地窖北邊、靠牆，一落橫放的圓木，
## 切口朝廣場（淺色的木頭斷面，一眼看得出是柴）、底下兩根墊木、頂上一層雪堆（SnowMound）。
## 每根粗細與前後位置用位置雜湊（不動 _rng）；整落一個方塊碰撞，會擋人。
const WOODPILE_POS: Vector3 = Vector3(10.2, 0.0, -7.7)
const WOODPILE_LEN: float = 2.0
const WOODPILE_ROWS: int = 5
const LOG_R: float = 0.095
const LOG_LEN: float = 0.6
## 圓木斷面的顏色（比樹皮淺、偏暖）
const LOG_END: Color = Color(0.46, 0.36, 0.25)
var woodpile_logs: int = 0


func _build_woodpile(base: Vector3) -> void:
	var wood := look.mat(FrostbridgeLook.WOOD)
	var end_grain := look.mat(LOG_END, 0.95)
	var inward: float = -1.0 if base.x > 0.0 else 1.0
	var to_plaza := Basis(Vector3.BACK, PI * 0.5)  # 圓柱的軸（Y）轉成 X
	# 墊木
	for dz: float in [-WOODPILE_LEN * 0.35, WOODPILE_LEN * 0.35]:
		_batch.add_box_at(Vector3(LOG_LEN * 0.9, 0.08, 0.12), base + Vector3(0, 0.04, dz), wood, false)
	var per_row: int = int(WOODPILE_LEN / (LOG_R * 2.05))
	var top_y: float = 0.0
	for row: int in WOODPILE_ROWS:
		# 上面幾排少一根、往中間縮（堆起來不是一堵方牆）
		var n: int = per_row - floori(row / 2.0)
		var y: float = 0.08 + LOG_R + float(row) * LOG_R * 1.78
		top_y = y + LOG_R
		for i: int in n:
			var h: float = _house_hash(base, 100.0 + float(row * 31 + i))
			var r: float = LOG_R * lerpf(0.82, 1.08, h)
			var z: float = (float(i) - float(n - 1) * 0.5) * LOG_R * 2.05 + (0.5 if row % 2 == 1 else 0.0) * LOG_R * 0.6
			var stick: float = (_house_hash(base, 200.0 + float(row * 31 + i)) - 0.5) * 0.08
			var c: Vector3 = base + Vector3(inward * stick, y, z)
			var log_mesh := CylinderMesh.new()
			log_mesh.top_radius = r
			log_mesh.bottom_radius = r
			log_mesh.height = LOG_LEN
			log_mesh.radial_segments = 7
			log_mesh.rings = 1
			_batch.add_mesh(log_mesh, Transform3D(to_plaza, c), wood)
			# 朝廣場那端的斷面：薄的淺色圓片，稍微突出一點
			var cap := CylinderMesh.new()
			cap.top_radius = r * 0.9
			cap.bottom_radius = r * 0.9
			cap.height = 0.012
			cap.radial_segments = 7
			cap.rings = 1
			_batch.add_mesh(cap, Transform3D(to_plaza, c + Vector3(inward * (LOG_LEN * 0.5 + 0.004), 0, 0)), end_grain)
			woodpile_logs += 1
	# 頂上的雪
	_batch.add_mesh(SnowMound.build(WOODPILE_LEN * 0.92, LOG_LEN * 0.95, 0.09, base.z * 3.1),
		Transform3D(Basis(Vector3.UP, PI * 0.5), base + Vector3(0, top_y - 0.03, 0)), look.snow())
	var col := BoxShape3D.new()
	col.size = Vector3(LOG_LEN, top_y, WOODPILE_LEN)
	_batch.add_shape(Transform3D(Basis.IDENTITY, base + Vector3(0, top_y * 0.5, 0)), col)


## 廣場西側牆邊停著一輛兩輪手推車（D-103，第三輪盤點第 7 項）：木頭車斗＋低車欄、兩個木輪（六根輻條、
## 鐵輪框）、兩根把手朝廣場、把手那端一根撐腳；車斗裡一層雪堆、一個木箱。整台一個方塊碰撞。
const HANDCART_POS: Vector3 = Vector3(-9.3, 0.0, 0.9)
const CART_WHEEL_R: float = 0.36
var handcart_built: bool = false


func _build_handcart(base: Vector3) -> void:
	var wood := look.mat(FrostbridgeLook.WOOD)
	var iron := look.mat(Color(0.07, 0.07, 0.08), 0.5)  # 跟木桶的鐵箍同一個材質
	var yaw: float = deg_to_rad(lerpf(-14.0, 6.0, _house_hash(base, 300.0)))
	var xf := Transform3D(Basis(Vector3.UP, yaw), base)
	var bed_y: float = CART_WHEEL_R + 0.16
	var bed := Vector3(0.82, 0.06, 1.25)
	_cart_box(xf, bed, Vector3(0, bed_y, 0), wood)
	# 低車欄：兩側＋前後
	for sx: float in [-1.0, 1.0]:
		_cart_box(xf, Vector3(0.04, 0.2, bed.z), Vector3(sx * (bed.x * 0.5 - 0.02), bed_y + 0.13, 0), wood)
	for sz: float in [-1.0, 1.0]:
		_cart_box(xf, Vector3(bed.x, 0.2, 0.04), Vector3(0, bed_y + 0.13, sz * (bed.z * 0.5 - 0.02)), wood)
	# 把手（往 +X，朝廣場）與撐腳
	for sz: float in [-1.0, 1.0]:
		_cart_box(xf, Vector3(0.95, 0.05, 0.05), Vector3(bed.x * 0.5 + 0.42, bed_y - 0.02, sz * 0.32), wood)
	_cart_box(xf, Vector3(0.05, bed_y - 0.02, 0.05), Vector3(bed.x * 0.5 + 0.55, (bed_y - 0.02) * 0.5, 0.32), wood)
	_cart_box(xf, Vector3(0.05, bed_y - 0.02, 0.05), Vector3(bed.x * 0.5 + 0.55, (bed_y - 0.02) * 0.5, -0.32), wood)
	# 輪子：輪軸沿 Z（車的兩側），木輪框＋鐵輪框＋輪轂＋六根輻條
	var axle := Basis(Vector3.RIGHT, PI * 0.5)  # 圓柱／圓環的軸（Y）轉成 Z
	for sz: float in [-1.0, 1.0]:
		var hub := Vector3(-0.08, CART_WHEEL_R, sz * (bed.z * 0.5 + 0.06))
		var tire := TorusMesh.new()
		tire.inner_radius = CART_WHEEL_R - 0.05
		tire.outer_radius = CART_WHEEL_R
		tire.rings = 20
		tire.ring_segments = 6
		_batch.add_mesh(tire, xf * Transform3D(axle, hub), iron)
		var felloe := TorusMesh.new()
		felloe.inner_radius = CART_WHEEL_R - 0.1
		felloe.outer_radius = CART_WHEEL_R - 0.04
		felloe.rings = 20
		felloe.ring_segments = 5
		_batch.add_mesh(felloe, xf * Transform3D(axle, hub), wood)
		var nave := CylinderMesh.new()
		nave.top_radius = 0.07
		nave.bottom_radius = 0.07
		nave.height = 0.14
		nave.radial_segments = 8
		nave.rings = 1
		_batch.add_mesh(nave, xf * Transform3D(axle, hub), wood)
		for k: int in 3:
			var spoke := Basis(Vector3.BACK, PI / 3.0 * float(k) + _house_hash(base, 310.0 + sz))
			_batch.add_mesh(_box_mesh(Vector3(0.035, (CART_WHEEL_R - 0.06) * 2.0, 0.03)), xf * Transform3D(spoke, hub), wood)
	# 車軸
	var axle_mesh := CylinderMesh.new()
	axle_mesh.top_radius = 0.03
	axle_mesh.bottom_radius = 0.03
	axle_mesh.height = bed.z + 0.2
	axle_mesh.radial_segments = 6
	axle_mesh.rings = 1
	_batch.add_mesh(axle_mesh, xf * Transform3D(axle, Vector3(-0.08, CART_WHEEL_R, 0)), iron)
	# 車斗裡：一個木箱（木箱模式）＋一層雪
	var crate_c: Vector3 = xf * Vector3(-0.12, bed_y + 0.03 + 0.2, -0.28)
	_batch.add_box_tinted(Vector3(0.42, 0.4, 0.42), crate_c, look.door(), FrostbridgeLook.crate_tint(crate_c), false)
	_batch.add_mesh(SnowMound.build(0.36, 0.36, 0.06, base.z * 5.3), Transform3D(Basis.IDENTITY, crate_c + Vector3(0, 0.2, 0)), look.snow())
	_batch.add_mesh(SnowMound.build(bed.x * 0.85, 0.6, 0.07, base.z * 7.1),
		xf * Transform3D(Basis.IDENTITY, Vector3(0.02, bed_y + 0.03, 0.3)), look.snow())
	var col := BoxShape3D.new()
	col.size = Vector3(bed.x + 0.9, bed_y + 0.25, bed.z + 0.2)
	_batch.add_shape(xf * Transform3D(Basis.IDENTITY, Vector3(0.4, (bed_y + 0.25) * 0.5, 0)), col)
	handcart_built = true


## 廣場西北角的木圍欄（D-104，第三輪盤點第 7 項的最後一步）：北排最東那棟（主街口）門前圍出一小塊院子——
## 從房子正面往廣場伸出一段、轉角再往西一段；最西那一格的上橫木斷了一頭、斜斜垂到雪裡。
## 立柱（頂上一小團雪）＋上下兩道橫木（上面那道頂上一條雪）；立柱的高低與歪斜、橫木的高低用位置雜湊（不動 _rng）。
## 院子裡一整片沒人踩過的雪（靠房子那側厚）。每一段一個細長方塊碰撞，會擋人。
const FENCE_PATH: Array[Vector3] = [Vector3(-4.7, 0.0, -10.0), Vector3(-4.7, 0.0, -8.3), Vector3(-7.25, 0.0, -8.3)]
const FENCE_BAY: float = 0.9
const FENCE_HEIGHT: float = 0.95
const FENCE_RAILS: Array[float] = [0.36, 0.76]
var fence_posts: int = 0
var fence_rails: int = 0
var fence_broken_rail: bool = false


func _build_fence(path: Array[Vector3]) -> void:
	var wood := look.mat(FrostbridgeLook.WOOD)
	var snow := look.snow()
	var y0: float = 0.02  # 廣場鋪石的高度
	for seg: int in path.size() - 1:
		var a: Vector3 = path[seg] + Vector3(0, y0, 0)
		var b: Vector3 = path[seg + 1] + Vector3(0, y0, 0)
		var length: float = a.distance_to(b)
		var dir: Vector3 = (b - a) / length
		var side: Vector3 = dir.cross(Vector3.UP)
		var along := Basis(dir, Vector3.UP, side)
		var bays: int = maxi(1, ceili(length / FENCE_BAY))
		var bay: float = length / float(bays)
		var last_seg: bool = seg == path.size() - 2
		for i: int in bays + 1:
			if i == 0 and seg > 0:
				continue  # 轉角的立柱跟上一段共用
			var p: Vector3 = a + dir * (bay * float(i))
			var hp: float = _house_hash(p, 500.0)
			var post_h: float = FENCE_HEIGHT + lerpf(-0.06, 0.08, hp)
			# 立柱微微歪向一邊（沿著圍欄或往外）
			var tilt := Basis(dir if hp > 0.5 else side, deg_to_rad(lerpf(-3.0, 3.0, _house_hash(p, 501.0))))
			var top: Vector3 = p + tilt * Vector3(0, post_h, 0)
			_batch.add_box(Vector3(0.11, post_h, 0.11), Transform3D(tilt * along, p + tilt * Vector3(0, post_h * 0.5, 0)), wood, false)
			_batch.add_mesh(SnowMound.build(0.15, 0.15, 0.05, p.x * 2.3 + p.z), Transform3D(tilt * along, top - Vector3(0, 0.005, 0)), snow)
			fence_posts += 1
		for i: int in bays:
			var m: Vector3 = a + dir * (bay * (float(i) + 0.5))
			for r: int in FENCE_RAILS.size():
				var ry: float = FENCE_RAILS[r] + (_house_hash(m, 510.0 + float(r)) - 0.5) * 0.06
				var roll := Basis(side, deg_to_rad((_house_hash(m, 520.0 + float(r)) - 0.5) * 4.0))
				var rail_len: float = bay + 0.06
				var rail_xf := Transform3D(roll * along, m + Vector3(0, ry, 0) - side * 0.06)
				if last_seg and i == bays - 1 and r == FENCE_RAILS.size() - 1:
					# 斷掉的上橫木：靠轉角那頭還釘著，另一頭垂到雪裡
					var pivot: Vector3 = m - dir * (bay * 0.5) + Vector3(0, ry, 0) - side * 0.06
					var drop: float = asin(clampf((ry - 0.06) / rail_len, 0.0, 1.0))
					var hang := Basis(side, -drop)
					rail_xf = Transform3D(hang * along, pivot + hang * (dir * (rail_len * 0.5)))
					fence_broken_rail = true
				_batch.add_box(Vector3(rail_len, 0.08, 0.045), rail_xf, wood, false)
				if r == FENCE_RAILS.size() - 1 and not (last_seg and i == bays - 1):
					# 上橫木頂上一條雪
					_batch.add_mesh(SnowMound.build(bay * 0.9, 0.07, 0.03, m.x * 4.1 + m.z * 1.3),
						rail_xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.035, 0)), snow)
				fence_rails += 1
		var col := BoxShape3D.new()
		col.size = Vector3(length, FENCE_HEIGHT, 0.16)
		_batch.add_shape(Transform3D(along, (a + b) * 0.5 + Vector3(0, FENCE_HEIGHT * 0.5, 0) - side * 0.03), col)
	# 院子裡沒人踩過的雪：一整片薄雪堆，靠房子那側厚（深色的圍欄襯在白雪前面，一眼看得出是一塊院子）
	var lo: Vector3 = path[0]
	var hi: Vector3 = path[0]
	for p: Vector3 in path:
		lo = lo.min(p)
		hi = hi.max(p)
	var yard: Vector3 = (lo + hi) * 0.5
	_batch.add_mesh(SnowMound.build(hi.x - lo.x + 0.3, hi.z - lo.z + 0.3, 0.12, yard.x * 3.7, Vector2(0.0, -0.4)),
		Transform3D(Basis.IDENTITY, Vector3(yard.x, y0, yard.z - 0.05)), snow)


func _cart_box(xf: Transform3D, size: Vector3, local: Vector3, mat: Material) -> void:
	_batch.add_box(size, xf * Transform3D(Basis.IDENTITY, local), mat, false)


func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## 廣場邊的木桶（D-100，第三輪盤點第 7 項的第一步）：廣場中間大片空地、沒有生活痕跡。
## 東西兩側牆邊、主要路線（中間、攤子、地窖、井）以外放三堆木桶：兩三個立著的（中間鼓起：上下兩段錐台＋
## 中段、兩道鐵箍、桶蓋上一圈雪）。用木頭／鐵件／雪既有的材質（小鎮 mesh 數不變），立著的會擋人。
const BARREL_SPOTS: Array[Vector3] = [Vector3(-10.0, 0.0, 5.2), Vector3(10.0, 0.0, 4.4), Vector3(-10.1, 0.0, -8.4)]
var barrel_count: int = 0


func _build_plaza_barrels() -> void:
	for spot: Vector3 in BARREL_SPOTS:
		var inward: float = 1.0 if spot.x < 0.0 else -1.0
		var n: int = 2 + int(_house_hash(spot, 11.0) * 2.0)
		for i: int in n:
			var off := Vector3(inward * (0.1 + 0.55 * float(i % 2)), 0.0, (float(i) - float(n - 1) * 0.5) * 0.66)
			off.z += (_house_hash(spot, 12.0 + i) - 0.5) * 0.15
			_barrel(spot + off, _house_hash(spot, 13.0 + i))


func _barrel(base: Vector3, hsh: float) -> void:
	var wood := look.mat(FrostbridgeLook.WOOD)
	var iron := look.mat(Color(0.07, 0.07, 0.08), 0.5)  # 跟門邊掛燈的鐵件同一個材質
	var hgt: float = lerpf(0.82, 0.95, hsh)
	var r_end: float = 0.25
	var r_mid: float = 0.3
	var seg: float = hgt * 0.3
	_batch.add_cylinder(r_mid, r_end, seg, base + Vector3(0, seg * 0.5, 0), wood, false, 14)
	_batch.add_cylinder(r_mid, r_mid, hgt - seg * 2.0, base + Vector3(0, hgt * 0.5, 0), wood, false, 14)
	_batch.add_cylinder(r_end, r_mid, seg, base + Vector3(0, hgt - seg * 0.5, 0), wood, false, 14)
	for y: float in [hgt * 0.2, hgt * 0.8]:
		var r: float = lerpf(r_end, r_mid, 0.75) + 0.012
		_batch.add_cylinder(r, r, 0.045, base + Vector3(0, y, 0), iron, false, 14)
	# 桶蓋上的雪（薄、比桶口小一點）＋看不見的碰撞（只有一個圓柱）
	_batch.add_cylinder(r_end - 0.03, r_end - 0.01, 0.05, base + Vector3(0, hgt + 0.025, 0), look.snow(), false, 14)
	var col := CylinderShape3D.new()
	col.radius = r_mid
	col.height = hgt
	_batch.add_shape(Transform3D(Basis.IDENTITY, base + Vector3(0, hgt * 0.5, 0)), col)
	barrel_count += 1


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
	_batch.add_box_at(Vector3(44.6, 0.14, 2.0), Vector3(0.0, RISE + 9.5, TOWER_Z - 5.5), look.snow(), false)
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
	# 北街的房子：完整屋頂放在自己的 batch（陷落時藏起來），另外先蓋好一份破屋頂（D-091）
	var roof_batch: StaticBatch = StaticBatch.new() if collapsible else batch
	# 屋瓦（D-107）：斜面 UV 是公尺，roof_tiles.gdshader 排一排排的瓦；雪的下緣露出最下面幾排
	var roof: ArrayMesh = RoofMesh.build(depth + 0.7, roof_h, w + 0.5)
	roof_batch.add_mesh(roof, Transform3D(basis, origin + Vector3(0, h + 0.25 + roof_h * 0.5, 0)), look.roof_tiles())
	roof_count += 1
	var snow_roof := PrismMesh.new()
	snow_roof.size = Vector3((depth + 0.7) * ROOF_SNOW, roof_h * ROOF_SNOW, w + 0.56)
	roof_batch.add_mesh(snow_roof, Transform3D(basis, origin + Vector3(0, h + 0.25 + roof_h * (1.0 - ROOF_SNOW) + roof_h * ROOF_SNOW * 0.5 + 0.06, 0)), look.snow())
	_roof_snow_lip(roof_batch, basis, origin, center, depth + 0.7, roof_h, w + 0.56, h + 0.25)
	if collapsible:
		roof_batch.build(holder, "Roof")
		var ruin := StaticBatch.new()
		var info: Dictionary = _roof_ruin(ruin, center, w, depth, h, roof_h, dir, face, basis)
		var ruin_node: Node3D = ruin.build(holder, "Ruin")
		ruin_node.visible = false
		holder.set_meta("ruin", info)
	if _rng.randf() < 0.35:
		var c: Vector3 = origin + dir * _rng.randf_range(-w * 0.3, w * 0.3) - face * depth * 0.2
		batch.add_box_at(Vector3(0.6, 1.6, 0.6), c + Vector3(0, h + roof_h * 0.6, 0), look.stone_wall(), false)
		_chimney_top(batch, holder, c + Vector3(0, h + roof_h * 0.6 + 0.8, 0), center, collapsible)
	# 正面：門＋窗（部分亮燈）
	var front: Vector3 = origin + face * (depth * 0.5)
	var door_off: float = _rng.randf_range(-w * 0.25, w * 0.25)
	var door_pos: Vector3 = front + dir * door_off + Vector3(0, 1.05, 0)
	batch.add_box_tinted(_axis_size(dir, face, 1.0, 0.12, 2.1), door_pos, look.door(), FrostbridgeLook.door_tint(door_pos))
	door_count += 1
	var window_mat: ShaderMaterial = look.window()
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
			batch.add_box_tinted(_axis_size(dir, face, 0.7, 0.08, 0.9), pos, window_mat,
				FrostbridgeLook.window_tint(lit, pos, WINDOW_ENERGY))
			window_count += 1
			if lit:
				lit_window_count += 1
			if lit and not lantern and light_count < 22:
				var l := OmniLight3D.new()
				l.light_color = FrostbridgeLook.LAMP
				l.light_energy = 0.45
				l.omni_range = 3.5
				l.light_volumetric_fog_energy = 0.6
				l.position = pos + face * 0.6
				holder.add_child(l)
				light_count += 1
	_upper_windows(batch, front, w, h, dir, face, floors, window_mat)
	if not collapsible and _house_hash(center, 3.3) < 0.28:
		var sign_side: float = 1.0 if door_off < 0.0 else -1.0
		_shop_sign(batch, front + dir * (door_off - sign_side * 0.95), face)
	if collapsible:
		batch.build(holder, "Mesh")


## 樓上的窗（D-096，第三輪盤點第 2 項）：原本兩層樓的房子只在 1.6、4.0 m 各開兩扇窗，
## 高的房子 4.5 m 以上、矮的房子 2 m 以上是一整片灰泥（主街、石階兩側的上層牆面大片空白）。
## 每一層放得下窗（窗頂離屋簷 ≥ 0.4 m）就開兩扇，寬的房子樓上中間再一扇；最高一層的窗小一點。
## 亮不亮用位置雜湊（不動 _rng，整個鎮的配置不變），不另外打燈（燈數上限）。
func _upper_windows(batch: StaticBatch, front: Vector3, w: float, h: float, dir: Vector3, face: Vector3,
		existing_floors: int, window_mat: Material) -> void:
	var top_floor: int = int(floor((h - 0.85 - 1.6) / 2.4))
	for f: int in range(1, top_floor + 1):
		var spots: Array[float] = []
		if f >= existing_floors:
			spots.append(-w * 0.3)
			spots.append(w * 0.3)
		if w > 5.2:
			spots.append(0.0)
		var small: bool = f == top_floor and f >= 2
		var size: Vector2 = Vector2(0.6, 0.75) if small else Vector2(0.7, 0.9)
		for along: float in spots:
			var pos: Vector3 = front + dir * along + Vector3(0, 1.6 + f * 2.4 - (0.08 if small else 0.0), 0)
			var lit: bool = _house_hash(pos, 7.7) < 0.32
			batch.add_box_tinted(_axis_size(dir, face, size.x, 0.08, size.y), pos, window_mat,
				FrostbridgeLook.window_tint(lit, pos, WINDOW_ENERGY))
			window_count += 1
			upper_window_count += 1
			if lit:
				lit_window_count += 1


## 店招（D-096）：約四分之一的房子門邊伸出一支鐵架，吊一塊木招牌（跟木箱同一個木頭材質）。
## 招牌垂直於牆面，從街上斜看時是一塊突出的剪影，打破一整排平的牆面。
func _shop_sign(batch: StaticBatch, wall_pos: Vector3, face: Vector3) -> void:
	var iron := look.mat(Color(0.07, 0.07, 0.08), 0.5)  # 跟門邊掛燈的鐵件同一個材質
	var reach: float = 0.95
	var arm_y: float = 3.05
	var across: Vector3 = Vector3(absf(face.z), 0, absf(face.x))  # 沿牆方向
	var out: Vector3 = Vector3(absf(face.x), 0, absf(face.z))     # 垂直牆面的軸
	# 鐵架：一支水平臂＋一支斜撐＋貼牆的底板
	batch.add_box_at(out * reach + Vector3(0.04, 0.04, 0.04), wall_pos + face * (reach * 0.5) + Vector3(0, arm_y, 0), iron, false)
	batch.add_box_at(Vector3(0.05, 0.36, 0.05) + across * 0.1, wall_pos + face * 0.03 + Vector3(0, arm_y - 0.12, 0), iron, false)
	var brace := BoxMesh.new()
	brace.size = Vector3(0.03, 0.03, 0.62)
	var brace_mid: Vector3 = wall_pos + face * 0.26 + Vector3(0, arm_y - 0.2, 0)
	var brace_basis := Basis.looking_at((face * 0.5 + Vector3(0, 0.4, 0)).normalized(), Vector3.UP if absf(face.y) < 0.9 else Vector3.FORWARD)
	batch.add_mesh(brace, Transform3D(brace_basis, brace_mid), iron)
	# 兩條短鏈＋木招牌（垂直於牆、比臂短一點）
	var board_c: Vector3 = wall_pos + face * (reach * 0.55) + Vector3(0, arm_y - 0.48, 0)
	for k: float in [-0.28, 0.28]:
		batch.add_box_at(Vector3(0.015, 0.24, 0.015), board_c + face * k + Vector3(0, 0.37, 0), iron, false)
	var board_size: Vector3 = out * 0.72 + across * 0.06 + Vector3(0, 0.5, 0)
	# 招牌兩面畫著店家的剪影（靴子、壺、鑰匙；不用文字，D-122）
	batch.add_box_tinted(board_size, board_c, look.door(), FrostbridgeLook.sign_tint(board_c, across.x > 0.5), false)
	shop_sign_icons.append(FrostbridgeLook.sign_icon(board_c))
	# 招牌頂上一小條雪
	batch.add_box_at(out * 0.72 + across * 0.08 + Vector3(0, 0.035, 0), board_c + Vector3(0, 0.27, 0), look.snow(), false)
	shop_sign_count += 1


## 煙囪頂（D-097，第三輪盤點第 3 項）：原本煙囪是一根素面方柱，夜空下的屋頂剪影每棟都一樣。
## 頂上加一圈較寬的石帽；約一半（北街以外、最多 MAX_SMOKE 根）冒著慢慢往上飄、被風吹斜的煙
## （概念圖的屋頂炊煙），其他的石帽上積一小塊雪（有煙的不積雪）。位置雜湊決定，不動 _rng。
const MAX_SMOKE: int = 8
var smoke_count: int = 0


func _chimney_top(batch: StaticBatch, holder: Node3D, top: Vector3, house_center: Vector3, collapsible: bool) -> void:
	batch.add_box_at(Vector3(0.76, 0.12, 0.76), top + Vector3(0, 0.04, 0), look.stone_wall(), false)
	var smoky: bool = not collapsible and smoke_count < MAX_SMOKE and _house_hash(house_center, 5.1) < 0.6
	if not smoky:
		batch.add_box_at(Vector3(0.66, 0.07, 0.66), top + Vector3(0, 0.13, 0), look.snow(), false)
		return
	var smoke := CPUParticles3D.new()
	smoke.name = "ChimneySmoke%d" % smoke_count
	smoke.position = top + Vector3(0, 0.2, 0) - holder.position
	smoke.amount = 14
	smoke.lifetime = 7.0
	smoke.preprocess = 7.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.15
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 8.0
	smoke.initial_velocity_min = 0.3
	smoke.initial_velocity_max = 0.45
	smoke.gravity = Vector3(0.12, 0.02, 0.05)  # 微風往東吹
	smoke.damping_min = 0.02
	smoke.damping_max = 0.05
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = grow
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	# 月光下的煙：偏藍的灰、很淡；不受光（粒子材質一律 unshaded，D-056）
	quad.material = ParticleLook.material(Color(0.42, 0.46, 0.55, 1.0), false, BaseMaterial3D.BILLBOARD_PARTICLES)
	smoke.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	ramp.add_point(0.12, Color(0.9, 0.92, 0.95, 0.26))
	ramp.add_point(0.55, Color(0.8, 0.83, 0.9, 0.13))
	smoke.color_ramp = ramp
	holder.add_child(smoke)
	smoke_count += 1


## 屋頂雪的下緣（第四輪盤點第 3 項，D-112）：雪稜柱的下緣是一條直線，遠看每棟屋頂都是「雪＋一道直邊的深色帶」。
## 沿兩邊屋簷方向，在雪的下緣放一串貼著斜面的扁雪堆（SnowMound，最高點偏向屋脊、埋進雪稜柱底下），
## 往下伸出的長短不一：有的地方雪往下多蓋兩排瓦、有的地方照樣露出瓦。長短、寬窄、往下伸多少用位置雜湊（不動 _rng）。
## base_w／roof_h／length 是屋頂（RoofMesh）的底寬、高、沿屋脊長；eave_y 是屋簷高度（房子座標）。
func _roof_snow_lip(batch: StaticBatch, roof_basis: Basis, origin: Vector3, center: Vector3, base_w: float, roof_h: float,
		length: float, eave_y: float) -> void:
	var hx: float = base_w * 0.5
	var slope_len: float = Vector2(hx, roof_h).length()
	for sx: float in [-1.0, 1.0]:
		var along := Vector3(0.0, 0.0, sx)
		var n := Vector3(sx * roof_h, hx, 0.0).normalized()
		var up_slope: Vector3 = along.cross(n)
		var mb := Basis(along, n, up_slope)
		# 雪稜柱的下緣落在斜面上的那條線（房子座標，旋轉前）
		var edge := Vector3(sx * hx * ROOF_SNOW, eave_y + roof_h * (1.0 - ROOF_SNOW), 0.0)
		var count: int = maxi(2, int(ceil(length / 1.5)))
		var step: float = length / float(count)
		for i: int in count:
			var key: Vector3 = center + Vector3(sx * 3.1, 0.0, float(i) * 1.7)
			var z: float = -length * 0.5 + step * (float(i) + 0.5) + step * lerpf(-0.2, 0.2, _house_hash(key, 401.0))
			var mound_l: float = minf(step * lerpf(1.1, 1.45, _house_hash(key, 402.0)), length - absf(z) * 2.0 + step * 0.4)
			var mound_w: float = lerpf(0.55, 0.9, _house_hash(key, 403.0))
			# 往下伸出多少（沿斜面，0＝剛好在直邊上）；雪堆的上半埋在雪稜柱底下
			var reach: float = lerpf(0.06, 0.45, _house_hash(key, 404.0))
			reach = minf(reach, slope_len * (1.0 - ROOF_SNOW) - 0.35)
			var p: Vector3 = edge - up_slope * (reach - mound_w * 0.5) + Vector3(0.0, 0.0, z)
			var mound: ArrayMesh = SnowMound.build(mound_l, mound_w, lerpf(0.08, 0.12, _house_hash(key, 405.0)),
				_house_hash(key, 406.0) * 97.0, Vector2(0.0, 0.4))
			batch.add_mesh(mound, Transform3D(roof_basis * mb, origin + roof_basis * p), look.snow())
			roof_snow_lips += 1


## 房子裝飾用的位置雜湊（0～1，不動 _rng）。
static func _house_hash(p: Vector3, salt: float) -> float:
	return fposmod(sin(p.x * 12.9898 + p.y * 4.1414 + p.z * 78.233 + salt * 37.719) * 43758.5453, 1.0)


## 陷落後的屋頂（D-091）：完整的三角屋頂陷下去以後是一大片平的淺色斜面（第二輪盤點第 9 項）。
## 這裡蓋一份「破掉的」版本（房子自己的座標）：朝街的那面斷成 3～4 片——一片整個掉進屋裡
## （露出斷掉的椽子、屋脊梁和黑洞洞的屋內）、其他片往屋裡塌陷或往下滑開（上緣露出椽子）；
## 每片上的雪只蓋住一部分，邊緣露出深色屋瓦；背面那面完整、有雪；兩端補上山牆。
## 亂數一律用位置雜湊（不動 _rng，整個鎮的配置不變）。回傳 {"segments", "holes", "rafters"} 給測試。
func _roof_ruin(batch: StaticBatch, center: Vector3, w: float, depth: float, h: float, roof_h: float,
		dir: Vector3, face: Vector3, prism_basis: Basis) -> Dictionary:
	var roof_mat := look.mat(FrostbridgeLook.ROOF)
	# 斷開的屋面與掉下來的碎片用跟完整屋頂同一套屋瓦（D-110）：RoofMesh.slab 的頂面 UV 是公尺
	var tiles := look.roof_tiles()
	var wood := look.mat(FrostbridgeLook.WOOD)
	var snow := look.snow()
	var up := Vector3.UP
	var y0: float = h + 0.25
	var s: float = (depth + 0.7) * 0.5
	var span: float = w + 0.5
	var t: float = 0.16
	var ridge: Vector3 = up * (y0 + roof_h)
	var slope_len: float = sqrt(s * s + roof_h * roof_h)
	var a: float = atan2(roof_h, s)
	# 屋內：屋簷板上一層近黑的底（從洞看進去是暗的）
	batch.add_box_at(_axis_size(dir, face, w - 0.2, depth - 0.2, 0.02), up * (h + 0.255),
		look.mat(Color(0.018, 0.016, 0.015)), false)
	# 背面（不朝街）：完整的一片＋雪
	var back_info: Array = _slope_frame(-face, a)
	var bu: Vector3 = back_info[0]
	var bn: Vector3 = back_info[1]
	var bb := Basis(bu, bn, bu.cross(bn))
	var back_c: Vector3 = ridge - bu * (slope_len * 0.5) + bn * (t * 0.5)
	batch.add_mesh(RoofMesh.slab(slope_len, t, span), Transform3D(bb, back_c), tiles)
	batch.add_box(Vector3(slope_len * 0.78, 0.1, span * 0.97), Transform3D(bb, back_c + bu * (slope_len * 0.08) + bn * (t * 0.5 + 0.05)), snow, false)
	# 兩端山牆（三角形，深色）＋屋脊梁
	for side: float in [-1.0, 1.0]:
		var gable := PrismMesh.new()
		gable.size = Vector3(s * 2.0 * 0.96, roof_h * 0.96, 0.18)
		batch.add_mesh(gable, Transform3D(prism_basis, up * (y0 + roof_h * 0.48) + dir * side * (w * 0.5 - 0.09)), roof_mat)
	batch.add_box_at(_axis_size(dir, face, span, 0.17, 0.17), ridge - up * 0.1, wood, false)
	# 朝街那面：斷成 k 片
	var k: int = 3 if span < 5.8 else 4
	var gap: float = 0.18
	var seg_w: float = (span - gap * float(k - 1)) / float(k)
	var hole: int = int(_ruin_hash(center, 0, 1.0) * float(k)) % k
	var front_info: Array = _slope_frame(face, a)
	var fu: Vector3 = front_info[0]
	var fn: Vector3 = front_info[1]
	var kinds: Array[String] = []
	var ruin_tiles: int = 1
	for i: int in k:
		var along: float = -span * 0.5 + seg_w * (float(i) + 0.5) + gap * float(i)
		if i == hole:
			kinds.append("hole")
			# 洞底（屋內地板上）：掉下來的屋瓦碎片與一團雪
			for d: int in 4:
				var dp: Vector3 = up * (h + 0.3) + dir * (along + seg_w * lerpf(-0.4, 0.4, _ruin_hash(center, d, 21.0))) \
					+ face * (s * lerpf(0.05, 0.75, _ruin_hash(center, d, 22.0)))
				var db := Basis(up, _ruin_hash(center, d, 23.0) * TAU) * Basis(Vector3.RIGHT, lerpf(-0.3, 0.3, _ruin_hash(center, d, 24.0)))
				batch.add_mesh(RoofMesh.slab(lerpf(0.3, 0.6, _ruin_hash(center, d, 25.0)), 0.06, lerpf(0.2, 0.4, _ruin_hash(center, d, 26.0))),
					Transform3D(db, dp), tiles)
			batch.add_mesh(SnowMound.build(0.75, 0.62, 0.2, _ruin_hash(center, i, 28.0) * 97.0),
				Transform3D(Basis(up, _ruin_hash(center, i, 27.0) * TAU), up * (h + 0.27) + dir * along + face * (s * 0.4)), snow)
			continue
		var sag: bool = _ruin_hash(center, i, 2.0) < 0.5
		kinds.append("sag" if sag else "slide")
		var hinge: Vector3 = ridge + dir * along
		# 塌陷：以屋脊為軸、屋簷那端往屋裡掉；滑開：整片往下滑、稍微翹起（架在椽子上）
		var tilt: float = deg_to_rad(lerpf(10.0, 24.0, _ruin_hash(center, i, 3.0))) if sag else -deg_to_rad(lerpf(1.0, 3.0, _ruin_hash(center, i, 3.0)))
		var plen: float = slope_len * (lerpf(0.82, 0.95, _ruin_hash(center, i, 4.0)) if sag else 1.0)
		if not sag:
			hinge -= fu * lerpf(0.4, 0.75, _ruin_hash(center, i, 5.0))
		var fr: Array = _slope_frame(face, a + tilt)
		var u2: Vector3 = fr[0]
		var n2: Vector3 = fr[1]
		var pb := Basis(u2, n2, u2.cross(n2))
		pb = Basis(u2, deg_to_rad(lerpf(-1.0, 1.0, _ruin_hash(center, i, 6.0)) * (4.0 if sag else 1.5))) * pb
		var pc: Vector3 = hinge - u2 * (plen * 0.5) + n2 * (t * 0.5)
		batch.add_mesh(RoofMesh.slab(plen, t, seg_w), Transform3D(pb, pc), tiles)
		ruin_tiles += 1
		# 雪只蓋住一部分：上下緣與斷口露出屋瓦。一大塊薄的＋一塊偏一邊的厚一點＋屋簷那端一小團（正要滑下去）。
		# 都是中間厚、邊緣薄到 0 的低面數雪堆（SnowMound，D-102），不再是直邊的雪板
		var snow_len: float = plen * lerpf(0.5, 0.72, _ruin_hash(center, i, 7.0))
		var shift: float = (plen - snow_len) * 0.5 * (_ruin_hash(center, i, 8.0) * 2.0 - 1.0) * 0.8
		var top: Vector3 = pc + pb.y * (t * 0.5)
		batch.add_mesh(SnowMound.build(snow_len, seg_w * lerpf(0.78, 0.95, _ruin_hash(center, i, 9.0)), 0.1, _ruin_hash(center, i, 10.0) * 97.0),
			Transform3D(pb, top + pb.x * shift), snow)
		var side: float = 1.0 if _ruin_hash(center, i, 15.0) < 0.5 else -1.0
		var p2_len: float = plen * lerpf(0.25, 0.42, _ruin_hash(center, i, 16.0))
		var p2_w: float = seg_w * lerpf(0.35, 0.6, _ruin_hash(center, i, 17.0))
		batch.add_mesh(SnowMound.build(p2_len, p2_w, 0.14, _ruin_hash(center, i, 11.0) * 97.0),
			Transform3D(pb, top + pb.x * (shift - side * snow_len * 0.35) + pb.z * side * (seg_w * 0.5 - p2_w * 0.5 - 0.05)), snow)
		batch.add_mesh(SnowMound.build(0.42, 0.48, 0.16, _ruin_hash(center, i, 12.0) * 97.0),
			Transform3D(pb, top - pb.x * (plen * 0.5 - 0.3) + pb.z * (seg_w * lerpf(-0.3, 0.3, _ruin_hash(center, i, 18.0)))), snow)
	# 椽子：每 0.75 m 一根。洞裡的斷成兩截（屋脊那截往屋裡垂、屋簷那截翹起來），
	# 往下滑開的那片底下是完整的（上緣的縫看得到），塌陷的那片底下沒有（已經跟著塌了）。
	var rafters: int = 0
	var j: int = 0
	var along_r: float = -span * 0.5 + 0.35
	while along_r < span * 0.5 - 0.2:
		var seg: int = clampi(int((along_r + span * 0.5) / (seg_w + gap)), 0, k - 1)
		var kind: String = kinds[seg]
		var line: Vector3 = dir * along_r
		if kind == "slide":
			var rb := Basis(fu, fn, fu.cross(fn))
			batch.add_box(Vector3(slope_len * 0.98, 0.12, 0.09), Transform3D(rb, ridge + line - fu * (slope_len * 0.5) - fn * 0.08), wood, false)
			rafters += 1
		elif kind == "hole":
			# 屋脊那截：往屋裡垂
			var droop: float = deg_to_rad(lerpf(22.0, 48.0, _ruin_hash(center, j, 11.0)))
			var l1: float = slope_len * lerpf(0.3, 0.55, _ruin_hash(center, j, 12.0))
			var f1: Array = _slope_frame(face, a + droop)
			var u1: Vector3 = f1[0]
			var n1: Vector3 = f1[1]
			batch.add_box(Vector3(l1, 0.12, 0.09), Transform3D(Basis(u1, n1, u1.cross(n1)), ridge + line - u1 * (l1 * 0.5) - n1 * 0.06), wood, false)
			# 屋簷那截：從屋簷往上翹出屋面
			var lift: float = deg_to_rad(lerpf(8.0, 26.0, _ruin_hash(center, j, 13.0)))
			var l2: float = slope_len * lerpf(0.22, 0.42, _ruin_hash(center, j, 14.0))
			var eave: Vector3 = face * s + up * y0 + line
			var e_dir: Vector3 = -face * cos(a + lift) + up * sin(a + lift)
			var e_n: Vector3 = face * sin(a + lift) + up * cos(a + lift)
			batch.add_box(Vector3(l2, 0.12, 0.09), Transform3D(Basis(e_dir, e_n, e_dir.cross(e_n)), eave + e_dir * (l2 * 0.5)), wood, false)
			rafters += 2
		j += 1
		along_r += 0.75
	return {"segments": k, "holes": kinds.count("hole"), "kinds": kinds, "rafters": rafters, "tiled": ruin_tiles}


## 破屋頂用的位置雜湊（0～1）：同一棟房子、同一個 i／salt 永遠同一個值。
static func _ruin_hash(c: Vector3, i: int, salt: float) -> float:
	return fposmod(sin(c.x * 12.9898 + c.z * 78.233 + float(i) * 37.719 + salt * 4.123) * 43758.5453, 1.0)


## 斜面座標：朝 out 方向往下的屋面，傾角 angle（弧度），回傳 [往屋脊的方向 u, 屋面法線 n]。
## u 從屋簷指向屋脊；n 朝外朝上。angle 越大越陡（往屋裡塌陷就是加大）。
static func _slope_frame(out: Vector3, angle: float) -> Array:
	var u: Vector3 = -out * cos(angle) + Vector3.UP * sin(angle)
	var n: Vector3 = out * sin(angle) + Vector3.UP * cos(angle)
	return [u, n]


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
	_cage_bars(batch, out + Vector3(0, 2.23, 0), 0.105, 0.3, iron)
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


## 井（D-077）：石砌井身＋淺色井沿石、井口積雪、木架＋小屋頂、吊著的水桶與繩子，
## 木架東側掛一盞小燈（不投影、範圍小），從廣場另一頭也看得出井在那裡。
var well_light: OmniLight3D


func _build_well(pos: Vector3) -> void:
	var stone := look.stone_wall(1.0)  # 跟石階燈柱同一個材質（不多一個 draw call）
	var curb := look.mat(FrostbridgeLook.STONE.lightened(0.28), 0.55)  # 跟廣場石緣同一個
	var groove := look.mat(Color(0.05, 0.055, 0.065), 0.35)
	_batch.add_cylinder(1.1, 1.2, 0.8, pos + Vector3(0, 0.4, 0), stone, true, 20)
	_batch.add_cylinder(1.18, 1.18, 0.1, pos + Vector3(0, 0.83, 0), curb, false, 20)
	_batch.add_cylinder(0.85, 0.85, 0.05, pos + Vector3(0, 0.87, 0), groove, false, 20)
	_batch.add_cylinder(1.14, 1.2, 0.05, pos + Vector3(0, 0.9, 0), look.snow(), false, 20)
	var wood := look.mat(FrostbridgeLook.WOOD)
	for sx: float in [-1.0, 1.0]:
		_batch.add_box_at(Vector3(0.14, 2.2, 0.14), pos + Vector3(sx * 1.0, 1.1, 0), wood, false)
	_batch.add_box_at(Vector3(2.3, 0.14, 0.14), pos + Vector3(0, 2.2, 0), wood, false)
	# 小屋頂：兩片斜板＋一條雪
	var roof := look.mat(FrostbridgeLook.ROOF)
	for sz: float in [-1.0, 1.0]:
		var b := Basis(Vector3.RIGHT, sz * 0.62)
		_batch.add_box(Vector3(2.6, 0.06, 0.8), Transform3D(b, pos + Vector3(0, 2.5, sz * 0.27)), roof, false)
		_batch.add_box(Vector3(2.6, 0.03, 0.7), Transform3D(b, pos + Vector3(0, 2.54, sz * 0.25)), look.snow(), false)
	# 繩子與水桶
	_batch.add_box_at(Vector3(0.03, 0.75, 0.03), pos + Vector3(0, 1.8, 0), roof, false)
	_batch.add_cylinder(0.17, 0.14, 0.26, pos + Vector3(0, 1.3, 0), wood, false, 12)
	_batch.add_cylinder(0.175, 0.175, 0.03, pos + Vector3(0, 1.36, 0), groove, false, 12)
	# 小燈（燈罩是發光小方塊＋上下兩片蓋）
	var lamp_pos: Vector3 = pos + Vector3(1.0, 1.72, 0.16)
	_batch.add_box_at(Vector3(0.16, 0.2, 0.16), lamp_pos, look.glow(FrostbridgeLook.LAMP, 6.0), false)
	_batch.add_box_at(Vector3(0.22, 0.04, 0.22), lamp_pos + Vector3(0, 0.12, 0), roof, false)
	_batch.add_box_at(Vector3(0.2, 0.03, 0.2), lamp_pos + Vector3(0, -0.11, 0), roof, false)
	well_light = OmniLight3D.new()
	well_light.name = "WellLight"
	well_light.light_color = FrostbridgeLook.LAMP
	well_light.light_energy = 1.1
	well_light.omni_range = 3.4
	well_light.shadow_enabled = false
	well_light.light_specular = LAMP_SPECULAR
	well_light.light_volumetric_fog_energy = 0.8
	well_light.position = lamp_pos + Vector3(0, -0.05, 0.05)
	add_child(well_light)
	light_count += 1


var street_lanterns: int = 0


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


## 燈罩的鐵框：四個角各一根細鐵條（燈罩不再是一顆發光的方塊／球，D-080）。
func _cage_bars(batch: StaticBatch, center: Vector3, half: float, height: float, iron: Material) -> void:
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		batch.add_box_at(Vector3(0.025, height, 0.025), center + Vector3(c.x * half, 0, c.y * half), iron, false)


## 路燈：柱子頂上一盞方形燈籠（鐵底座、發光玻璃、四角鐵條、八角形尖頂＋一小片雪），D-080。
func _lamp_post(pos: Vector3, shadows: bool) -> void:
	var roof := look.mat(FrostbridgeLook.ROOF)
	var iron := look.mat(Color(0.07, 0.07, 0.08), 0.5)  # 跟門邊掛燈的鐵件同一個材質
	_batch.add_box_at(Vector3(0.14, 3.2, 0.14), pos + Vector3(0, 1.6, 0), roof)
	var c: Vector3 = pos + Vector3(0, 3.4, 0)
	_batch.add_box_at(Vector3(0.3, 0.05, 0.3), c + Vector3(0, -0.2, 0), iron, false)
	_batch.add_box_at(Vector3(0.24, 0.34, 0.24), c, look.glow(FrostbridgeLook.LAMP, 6.0), false)
	_cage_bars(_batch, c, 0.125, 0.36, iron)
	_batch.add_box_at(Vector3(0.32, 0.04, 0.32), c + Vector3(0, 0.19, 0), iron, false)
	_batch.add_cylinder(0.02, 0.26, 0.2, c + Vector3(0, 0.31, 0), roof, false, 8)
	_batch.add_cylinder(0.01, 0.2, 0.06, c + Vector3(0, 0.36, 0), look.snow(), false, 8)
	street_lanterns += 1
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
	_batch.add_box_at(Vector3(0.08, 3.2, 5.0), pos + Vector3(0, 19.65, 0), look.snow(), false)
	# 塔門與塔窗的暖光
	_batch.add_box_at(Vector3(1.4, 2.4, 0.1), pos + Vector3(0, 1.2, 2.52), look.glow(FrostbridgeLook.LAMP, 2.5), false)
	var tower_window: Vector3 = pos + Vector3(0, 9.5, 2.52)
	var tower_tint: Color = FrostbridgeLook.window_tint(true, tower_window, 4.0)
	tower_tint.b = 0.0  # 塔窗不拉窗簾
	_batch.add_box_tinted(Vector3(1.0, 1.6, 0.1), tower_window, look.window(), tower_tint)
	window_count += 1
	lit_window_count += 1
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
	# 鐘室的木構：屋頂底下的格柵（看得出是木頭撐著，不是一塊平板）＋背面與兩側的百葉擋板
	# （鐘的背後是暖光照著的斜木條，不再是一片灰霧；正面留空，從街上看得到鐘）。D-081
	_build_belfry_timber(pos)
	# 廢鐘：掛在鐘室正中的橫梁下，鐘口朝下（會擺動，不進合併）
	_batch.add_box_at(Vector3(4.2, 0.2, 0.2), pos + Vector3(0, 17.2, 0), look.mat(FrostbridgeLook.WOOD), false)
	_bell = Node3D.new()
	_bell.name = "Bell"
	_bell.position = pos + Vector3(0, 17.1, 0)
	add_child(_bell)
	_build_bell_body(_bell)


const BELL_HEIGHT: float = 1.5
const BELL_MOUTH: float = 0.95
## 鐘頂到鐘架之間留給鐘鈕的高度（D-121）：鐘身、紋帶往下移這麼多，鐘鈕的兩個環穿過鐘架
const BELL_DROP: float = 0.22
## 鐘身上的紋帶：[高度比例, 那個高度的鐘身半徑比例]（Lathe.bell_profiles 的外側剖面）
const BELL_BANDS := [Vector2(0.12, 0.50), Vector2(0.62, 0.62), Vector2(0.86, 0.80)]


## 鐘身：車床旋轉出來的鐘形（肩、細腰、外翻的鐘口、厚唇、中空）＋三道凸起的紋帶＋
## 頂上的木頭鐘架與兩條鐵箍。全部掛在 bell 底下，敲鐘時一起擺。D-081
func _build_bell_body(bell: Node3D) -> void:
	# 舊青銅：金屬度不能太高——夜裡沒有可反射的環境，高金屬度的鐘在敲鐘鏡頭裡只剩一個黑影
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.46, 0.34, 0.2)
	bronze.roughness = 0.42
	bronze.metallic = 0.35
	bronze.rim_enabled = true
	bronze.rim = 0.35
	bronze.rim_tint = 0.6
	var body := MeshInstance3D.new()
	body.name = "BellBody"
	body.mesh = Lathe.bell_mesh(BELL_HEIGHT, BELL_MOUTH)
	body.position = Vector3(0, -BELL_DROP, 0)
	body.material_override = bronze
	bell.add_child(body)
	_build_bell_crown(bell, bronze)
	# 紋帶：磨亮一點的青銅，凸出鐘面，燈一照就有一圈一圈的高光
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.58, 0.44, 0.27)
	band_mat.roughness = 0.3
	band_mat.metallic = 0.45
	band_mat.rim_enabled = true
	band_mat.rim = 0.4
	band_mat.rim_tint = 0.6
	var i: int = 0
	for b: Vector2 in BELL_BANDS:
		var r: float = b.y * BELL_MOUTH
		var ring := MeshInstance3D.new()
		ring.name = "BellBand%d" % i
		var torus := TorusMesh.new()
		torus.inner_radius = r - 0.012
		torus.outer_radius = r + 0.04
		torus.rings = 40
		torus.ring_segments = 8
		ring.mesh = torus
		ring.position = Vector3(0, -BELL_DROP - b.x * BELL_HEIGHT, 0)
		ring.material_override = band_mat
		bell.add_child(ring)
		i += 1
	# 鐘架（深色木塊包住橫梁）與兩條鐵箍：鐘是吊在木頭上的，不是浮在半空
	var yoke := MeshInstance3D.new()
	yoke.name = "BellYoke"
	var yoke_mesh := BoxMesh.new()
	yoke_mesh.size = Vector3(1.0, 0.34, 0.38)
	yoke.mesh = yoke_mesh
	yoke.position = Vector3(0, 0.12, 0)
	yoke.material_override = look.mat(FrostbridgeLook.WOOD)
	bell.add_child(yoke)
	var iron := look.mat(Color(0.07, 0.07, 0.08), 0.5)
	# 鐵箍從鐘架往下伸到鐘肩（鐘往下移了 BELL_DROP，D-121）
	for x: float in [-0.3, 0.3]:
		var strap := MeshInstance3D.new()
		var strap_mesh := BoxMesh.new()
		strap_mesh.size = Vector3(0.06, 0.48, 0.42)
		strap.mesh = strap_mesh
		strap.position = Vector3(x, -0.08, 0)
		strap.material_override = iron
		bell.add_child(strap)


## 鐘鈕（D-121）：鐘頂一個圓的鐘冠（蓋住平的鐘頂）＋兩個交叉的青銅環往上穿過鐘架。
## 之前鐘頂直接頂著橫樑，看起來是平的、像黏在木頭上。
func _build_bell_crown(bell: Node3D, bronze: Material) -> void:
	var top: float = -BELL_DROP
	var cap := MeshInstance3D.new()
	cap.name = "BellCrown"
	var lathe := Lathe.new(32)
	# 外側從上往下描：圓頂 → 落到鐘頂上（鐘頂在 0.3 倍鐘口半徑內幾乎是平的）
	lathe.add_profile(PackedVector2Array([
		Vector2(0.0, 0.12), Vector2(0.09, 0.114), Vector2(0.17, 0.09),
		Vector2(0.23, 0.05), Vector2(0.27, 0.015), Vector2(0.29, -0.006),
	]))
	cap.mesh = lathe.commit()
	cap.position = Vector3(0, top, 0)
	cap.material_override = bronze
	bell.add_child(cap)
	for i: int in 2:
		var loop := MeshInstance3D.new()
		loop.name = "BellLoop%d" % i
		var torus := TorusMesh.new()
		torus.inner_radius = 0.09
		torus.outer_radius = 0.165
		torus.rings = 20
		torus.ring_segments = 8
		loop.mesh = torus
		# TorusMesh 躺在 XZ 平面：繞 X 轉 90° 立起來，第二個再繞 Y 轉 90°（兩個環交叉）
		loop.basis = Basis(Vector3.UP, PI * 0.5 * i) * Basis(Vector3.RIGHT, PI * 0.5)
		loop.position = Vector3(0, top + 0.1 + 0.09, 0)
		loop.material_override = bronze
		bell.add_child(loop)


## 鐘室木構（進合併，沿用木頭材質，小鎮 mesh 數不變）：屋頂下四根格柵，背面與東西兩側
## 各一排往外斜的百葉板。pos 是鐘樓底部中心。D-081
var belfry_louvres: int = 0


func _build_belfry_timber(pos: Vector3) -> void:
	var wood := look.mat(FrostbridgeLook.WOOD)
	for x: float in [-1.0, 1.0]:
		_batch.add_box_at(Vector3(0.18, 0.22, 4.4), pos + Vector3(x, 17.39, 0), wood, false)
	for z: float in [-1.4, 1.4]:
		_batch.add_box_at(Vector3(4.4, 0.22, 0.18), pos + Vector3(0, 17.39, z), wood, false)
	var tilt: float = deg_to_rad(38.0)
	var y: float = 14.8
	while y < 17.25:
		# 背面（-Z）：板子沿 X，外緣（-Z）往下斜
		var back := Basis(Vector3.RIGHT, -tilt)
		_batch.add_box(Vector3(3.2, 0.05, 0.38), Transform3D(back, pos + Vector3(0, y, -1.9)), wood, false)
		# 兩側（±X）：板子沿 Z，外緣往下斜
		for sx: float in [-1.0, 1.0]:
			var side := Basis(Vector3.BACK, sx * tilt)
			_batch.add_box(Vector3(0.38, 0.05, 3.2), Transform3D(side, pos + Vector3(sx * 1.9, y, 0)), wood, false)
		belfry_louvres += 3
		y += 0.34


## 梨販的攤子：木桌、布篷、一盞暖燈、一個披斗篷的人影（之後換成角色）。正面朝 +Z（出生點）。
var stall_crates: int = 0


func _build_pear_stall(pos: Vector3) -> void:
	var wood := look.mat(FrostbridgeLook.WOOD)
	# 攤桌與旁邊疊著的木箱：橫排木板＋角條（door.gdshader 的木箱模式，D-077），不再是素面方塊
	var crates := look.door()
	var table_pos: Vector3 = pos + Vector3(0, 0.45, 0)
	_batch.add_box_tinted(Vector3(1.6, 0.9, 0.8), table_pos, crates, FrostbridgeLook.crate_tint(table_pos), true)
	stall_crates = 1
	for c: Array in [[Vector3(1.25, 0.3, -0.15), 0.6], [Vector3(1.3, 0.24, 0.55), 0.48], [Vector3(1.22, 0.82, -0.12), 0.44]]:
		var cpos: Vector3 = pos + (c[0] as Vector3)
		var side: float = float(c[1])
		_batch.add_box_tinted(Vector3(side, side, side), cpos, crates, FrostbridgeLook.crate_tint(cpos), true)
		stall_crates += 1
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
	# 攤桌正面的小補光（第二輪盤點第 6 項，D-089）：布篷下那盞只照到桌面，從廣場走過來看到的正面與木箱一片黑。
	# 低低地放在桌前、不投影、範圍小、不進體積霧，只把木板紋和梨子的輪廓帶出來
	var fill := OmniLight3D.new()
	fill.name = "StallFill"
	fill.light_color = FrostbridgeLook.LAMP
	fill.light_energy = 0.55
	fill.omni_range = 2.2
	fill.omni_attenuation = 1.6
	fill.light_specular = 0.2
	fill.light_volumetric_fog_energy = 0.0
	fill.shadow_enabled = false
	fill.position = pos + Vector3(-0.2, 0.75, 1.25)
	add_child(fill)
	light_count += 1
