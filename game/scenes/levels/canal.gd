extends StoryLevel
## 第 3 章「不准替我答應」：乾運河（白盒，D-163；08-chapter2-3.md）。
## 第 2 章看完窗外的眼睛 → 第 3 章章節卡 → 這裡。第四夜，地底城離穹頂最遠的地方：
## 上方鐘院的白光從一排排石樑的縫透下來，斜斜地切成一條條——**整座地底城只有這裡有影子**（光是斜的，一盞投影子的方向光；
## 第 1 章的規則是「只有油燈投影子」，這裡是第一個例外，D-163）。運河早就乾了，河床比岸邊低 BED_Y，
## 一根橫跨運河的舊吊樑上掛著一隻送葬者（胸口一點銅光＝鐘舌，跟心跳一樣一下一下地亮）；吊樑在亮處，縫裡的光一條條切過牠。
## 再往北一座石橋、更遠是閘道（剪影）。
## 段落 1 乾涸的運河：走到東岸的說話點 → 席菈「我去引開牠。」→「不行。」／（沉默）→「那你有什麼方案？」→ 我說不出來 →
## 攻略筆記多一條**空白**「攻略沒有寫」（guide_blank，D-163）→ 彌夏蹲在渠邊：「牠跟著什麼走？」「心跳。」「多快？」→
## 檢查點 ch3_bank → 段落 2「趴在水溝裡（觀察）」（D-164）：吊樑旁邊的東岸有一道淺水溝（`Drain`）→ 走進去，三個人趴下 →
## 對話 ch3_rhythm：席菈用布包著小石頭隔著銅片敲，**玩家選節奏**（很慢／慢一點／不快不慢／快一點／很快／忽快忽慢，試過的消失）→
## 「敲」那一句出現時判定（RhythmTrial）、送葬者照結果演：不動／偏頭／轉頭（轉頭之前鏈子先響＝觀察提示音，設定可關）→
## 不快不慢＝人的心跳 → 轉頭 →「就是這個速度。」→ 攻略筆記的空白條目變成證實（自己看到的）→ 檢查點 ch3_rhythm →
## 段落 3 假心臟待續。
##
## 座標：運河沿 Z（南 Z_SOUTH → 北 Z_NORTH），河道 x -CANAL_HALF_W～CANAL_HALF_W，兩岸各寬 BANK_W、岸頂 y＝0；
## 諾恩從東岸南端進來，岸邊有矮牆（不會掉下去）。北邊有一座閘道（段落 3 把送葬者引進去的地方，現在只是剪影）。

const QUEST: String = "ch3_main"
const STAGES: PackedStringArray = ["canal_bank", "observe", "decoy"]
const BED_Y: float = -4.5
const CANAL_HALF_W: float = 3.0
const BANK_W: float = 6.0
const Z_SOUTH: float = 12.0
const Z_NORTH: float = -40.0
const SPAWN: Vector3 = Vector3(5.6, 0.0, 9.0)
## 岸邊的矮牆：看得到的高度、擋人的高度
## （第 45 輪截圖：0.8 m 的矮牆從岸上把掛著的送葬者整隻擋住）
const PARAPET_H: float = 0.45
const PARAPET_BLOCK_H: float = 1.8
## 石橋：橋面在岸頂高度、厚 DECK_T
const BRIDGE_Z: float = -20.0
const BRIDGE_W: float = 2.4
const DECK_T: float = 0.5
## 吊樑：擱在兩岸的矮牆上（第 45 輪截圖：掛在橋下整隻在橋的影子裡，看不到）
const HANG_Z: float = -14.5
## 掛點偏東岸一點（從東岸看得到）
const HANG_X: float = 0.7
## 吊樑比岸頂高一截（第 45 輪截圖：掛得太低，從岸上看下去整隻被河道的牆緣擋住）
const BEAM_Y: float = 2.6
## 掛著的送葬者：鏈子多長、怎麼晃
const CHAIN_LEN: float = 1.0
const SWAY_DEG: float = 2.2
const SWAY_RATE: float = 0.55
## 胸口的鐘舌：銅光一下一下地亮，像心跳（每分鐘 HEART_BPM 下，一次兩拍）
const HEART_BPM: float = 46.0
const CLAPPER_ENERGY: float = 1.7
## 段落 1：走到東岸這裡 → 岸邊的對話
const BANK_POS: Vector3 = Vector3(3.9, 0.0, -11.0)
const BANK_RANGE: float = 1.8
const BANK_TALK: String = "ch3_bank"
## 岸邊對話時鏡頭往下看多少（弧度）
const LOOK_DOWN_PITCH: float = -0.55
const BLANK_ENTRY: String = "clapper_heartbeat"
## 段落 2：吊樑旁邊東岸的淺水溝（沿 Z 長 DRAIN_LEN、寬 DRAIN_W，兩側低低的石緣）；走進 DRAIN_RANGE 就趴下開始觀察。
## 三個人沿 Z 並排趴著、頭朝運河（第 46 輪截圖：溝只有 0.9 m 寬，橫著趴的人整個伸出溝外）
const DRAIN_POS: Vector3 = Vector3(4.6, 0.0, -14.2)
const DRAIN_LEN: float = 4.2
const DRAIN_W: float = 2.3
const DRAIN_RANGE: float = 1.4
const RHYTHM_TALK: String = "ch3_rhythm"
const KNOCK_LINE: String = "DLG_CH3_RHY_KNOCK"
## 銅片插在水溝前端的泥裡（席菈敲的地方）
const PLATE_POS: Vector3 = Vector3(3.7, 0.0, -15.5)
## 一次敲幾下；第幾下之後送葬者開始反應
const KNOCK_COUNT: int = 7
const REACT_AFTER: int = 3
## 送葬者的反應：偏頭（上半身繞 Z 歪一點又回來）、轉頭（上半身轉向銅片，停在那裡）
const TILT_DEG: float = 13.0
const TURN_DEG: float = 62.0
## 觀察提示音比轉頭早多久響
const CUE_LEAD: float = 0.7
## 北邊的閘道（段落 3 用）
const SLUICE_Z: float = -29.0
## 頭頂的石樑：一排排橫跨運河，縫裡透下鐘院的光
const SLAT_Y: float = 13.0
const SLAT_PITCH: float = 2.4
const SLAT_GAP: float = 0.85
const OUTER_WALL_H: float = 13.6
## 從縫裡斜斜照下來的白光（投影子）
const SLIT_LIGHT_ROT: Vector3 = Vector3(-57.0, 28.0, 0.0)
const SLIT_LIGHT_ENERGY: float = 1.5
const SLIT_LIGHT_FOG: float = 2.4
const SLIT_COLOR: Color = Color(0.85, 0.9, 1.0)
const SLIT_SPOT_ENERGY: float = 5.0
const LAMP_RANGE: float = 7.0
const LAMP_ENERGY: float = 2.6
const MISHA_GAP: float = 2.2
const MISHA_SPEED: float = 3.6

const STONE: Color = Color(0.36, 0.35, 0.34)
const STONE_LIGHT: Color = Color(0.52, 0.5, 0.47)
const MUD: Color = Color(0.13, 0.11, 0.1)
const ROCK: Color = Color(0.1, 0.1, 0.11)
const WOOD: Color = Color(0.25, 0.19, 0.13)
const IRON: Color = Color(0.17, 0.16, 0.16)
const COPPER: Color = Color(0.95, 0.55, 0.28)

var _misha: Puppet
var _pivot: Node3D
var _undertaker: Undertaker
var _clapper_light: OmniLight3D
var _clapper_mat: StandardMaterial3D
var _t: float = 0.0
var _continued_shown: bool = false
## 段落 2：趴在水溝裡（觀察中）、上一次敲的反應（測試讀）、反應的補間
var in_drain: bool = false
var last_reaction: String = ""
var _drain_armed: bool = true
var _reaction_tweens: Array[Tween] = []
var _torso: Node3D
var _plate: Node3D
## 截圖用（`--canal-at=edge`）：站在岸邊不開對話、彌夏不跟
var _dev_hold_edge: bool = false


func _ready() -> void:
	_rng.seed = 3006
	# 開發用：`-- --level=canal` 直接進來 → 照正式流程把第 2 章走完、開始第 3 章
	if not Game.session.state.quests.has(QUEST):
		dev_start_chapter3(Game.session)
	_build_environment()
	_build_canal()
	_build_bridge()
	_build_sluice()
	_build_ceiling()
	_build_undertaker()
	_build_drain()
	_init_story()
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player != null:
		_put(player, SPAWN, 0.0)
	_set_up_lamp()
	_build_people()
	_start_ambience()
	Game.dialogue_ended.connect(_on_dialogue_ended)
	Game.dialogue_started.connect(_on_dialogue_started)
	# 截圖用：`--canal-at=bank` 站在岸邊、對話第一句；`--canal-at=edge` 站在岸邊（不開對話）；`--canal-at=after` 岸邊的對話講完
	var dev_args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	var at: String = str(dev_args.get("canal-at", ""))
	if at == "after":
		Game.session.set_flag("ch3.bank_talked", true)
	if at in ["bank", "edge", "after"] and player != null:
		_put(player, BANK_POS + Vector3(0.9, 0.0, 1.6), deg_to_rad(28.0))
		_place_company()
		_look_into_canal()
		(player as PlayerController).snap_camera()
	if at == "bank":
		talk_bank.call_deferred()
	elif at == "edge":
		_dev_hold_edge = true
	# 截圖用：`--canal-at=drain` 走進水溝、對話第一句；`--canal-at=turn` 趴在水溝裡、送葬者已經轉頭（不開對話）
	if at in ["drain", "turn"]:
		if not bool(Game.session.state.get_flag("ch3.bank_talked", false)):
			StoryLogic.apply({"guide_blank": [BLANK_ENTRY]}, Game.session.state)
			Game.session.set_flag("ch3.bank_talked", true)
		if at == "drain":
			enter_drain.call_deferred()
		else:
			_dev_hold_edge = true
			_lie_down()
			_play_reaction("steady", RhythmTrial.TURN)
			skip_reaction()
	if Game.session.quests.stage_of(QUEST) == "decoy":
		_continued_shown = true
		_banner.call_deferred("CH1_TO_BE_CONTINUED", 6.0)


## 開發旗標與測試用：照正式流程把第 2 章走完（第 3 章跟著開始）。已經開始第 3 章就不動。
static func dev_start_chapter3(s: GameSession) -> void:
	if s.state.quests.has(QUEST):
		return
	var ach: AchievementTracker = s.achievements
	s.achievements = null
	var hall: Resource = load("res://scenes/levels/bell_hall.gd")
	hall.call("dev_start_chapter2", s)
	hall.call("dev_reach_inner_room", s, true)
	for i: int in 4:
		s.state.set_flag("ch2.carving_%d" % i, true)
	s.set_flag("ch2.read_wall_carvings", true)
	s.state.set_flag("ch2.plan_break", true)
	s.set_flag("ch2.curtain_talked", true)
	s.set_flag("ch2.curtain_opened", true)
	s.attach_achievements(ach)


func _put(node: Node3D, p: Vector3, yaw: float) -> void:
	node.global_position = p + Vector3(0, 0.05, 0)
	node.rotation.y = yaw
	if node is PlayerController:
		(node as PlayerController).yaw = yaw
		(node as PlayerController).velocity = Vector3.ZERO
		(node as PlayerController).snap_camera()


func _set_up_lamp() -> void:
	var light: OmniLight3D = lamp_light()
	if light != null:
		light.omni_range = LAMP_RANGE
		light.light_energy = LAMP_ENERGY
		light.shadow_enabled = true


## 地底的環境音（空洞的低風、有回音的滴水、吊樑的嘎吱；10 秒循環，照 daylight 的做法）。
func _start_ambience() -> void:
	var src: AudioStreamWAV = Sfx.stream("canal_ambience") as AudioStreamWAV
	if src == null:
		return
	var s: AudioStreamWAV = src.duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * float(s.mix_rate))
	var p := AudioStreamPlayer.new()
	p.name = "Ambience"
	p.stream = s
	p.bus = &"SFX"
	p.volume_db = -10.0
	add_child(p)
	p.play()


func lamp_light() -> OmniLight3D:
	var player: Node3D = get_node_or_null("Player") as Node3D
	return player.find_child("LanternLight", true, false) as OmniLight3D if player != null else null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------- 流程

func _physics_process(delta: float) -> void:
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if player == null:
		return
	_follow_misha(player, delta)
	if Game.is_player_locked() or _dev_hold_edge:
		return
	var stage: String = Game.session.quests.stage_of(QUEST)
	if stage == "canal_bank" and _flat(player.global_position, BANK_POS) <= BANK_RANGE:
		talk_bank()
	elif stage == "observe" and not in_drain:
		var d: float = _flat(player.global_position, DRAIN_POS)
		if d > DRAIN_RANGE + 0.6:
			_drain_armed = true
		elif d <= DRAIN_RANGE and _drain_armed:
			enter_drain()


func _process(delta: float) -> void:
	_t += delta
	if _pivot != null:
		_pivot.rotation.z = deg_to_rad(SWAY_DEG) * sin(_t * SWAY_RATE)
		_pivot.rotation.x = deg_to_rad(SWAY_DEG * 0.45) * sin(_t * SWAY_RATE * 0.71 + 1.3)
	var beat: float = heartbeat(_t)
	if _clapper_light != null:
		_clapper_light.light_energy = CLAPPER_ENERGY * (0.35 + 0.65 * beat)
	if _clapper_mat != null:
		_clapper_mat.emission_energy_multiplier = 1.2 + 4.0 * beat


## 鐘舌的光：一次心跳兩拍（咚、咚——停），0～1。
static func heartbeat(t: float) -> float:
	var period: float = 60.0 / HEART_BPM
	var p: float = fposmod(t, period) / period
	var first: float = exp(-pow((p - 0.06) / 0.045, 2.0))
	var second: float = 0.6 * exp(-pow((p - 0.24) / 0.05, 2.0))
	return clampf(first + second, 0.0, 1.0)


## 走到岸邊（測試也用）：岸邊的對話。只開一次。
func talk_bank() -> void:
	if Game.is_in_dialogue() or bool(Game.session.state.get_flag("ch3.bank_talked", false)):
		return
	_place_company()
	_look_into_canal()
	Game.start_dialogue(BANK_TALK)


## 對話開始時鏡頭轉向橋下、往下看（從岸邊看得到掛著的送葬者和胸口的銅光）。
func _look_into_canal() -> void:
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if player == null:
		return
	var to: Vector3 = Vector3(HANG_X, 0.0, HANG_Z) - player.global_position
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = LOOK_DOWN_PITCH


func _on_dialogue_ended(dialogue_id: String) -> void:
	if dialogue_id == RHYTHM_TALK:
		_on_rhythm_ended()
		return
	if dialogue_id != BANK_TALK or bool(Game.session.state.get_flag("ch3.bank_talked", false)):
		return
	# 跳過也一樣：攻略筆記多一條空白（「攻略沒有寫」）→ 檢查點 ch3_bank → 段落 2 待續
	StoryLogic.apply({"guide_blank": [BLANK_ENTRY]}, Game.session.state)
	Game.session.set_flag("ch3.bank_talked", true)
	_banner("GUIDE_BLANK_NOTE", 4.0)
	if not _continued_shown:
		_continued_shown = true
		get_tree().create_timer(4.3).timeout.connect(_banner.bind("CH1_TO_BE_CONTINUED", 6.0))


# ---------------------------------------------------------------- 段落 2：趴在水溝裡（觀察）

## 走進水溝（測試也用）：三個人趴下、鏡頭對著掛著的送葬者 → 對話 ch3_rhythm（選節奏）。
func enter_drain() -> void:
	if in_drain or Game.is_in_dialogue() or Game.session.quests.stage_of(QUEST) != "observe":
		return
	in_drain = true
	_drain_armed = false
	_lie_down()
	Game.start_dialogue(RHYTHM_TALK)


## 趴下：諾恩在水溝中段、席菈在前端（伸手就碰得到銅片）、彌夏在後面；都面向吊樑。
func _lie_down() -> void:
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	var face_at: Vector3 = Vector3(HANG_X, 0.0, HANG_Z)
	var spots: Array[Vector3] = [DRAIN_POS, DRAIN_POS + Vector3(-0.1, 0.0, -1.25), DRAIN_POS + Vector3(0.1, 0.0, 1.25)]
	var people: Array[Node3D] = [player, get_node_or_null("Sheila") as Node3D, _misha]
	for i: int in people.size():
		var who: Node3D = people[i]
		if who == null:
			continue
		var to: Vector3 = face_at - spots[i]
		var yaw: float = atan2(-to.x, -to.z)
		who.global_position = spots[i] + Vector3(0.0, 0.03, 0.0)
		var pup: Puppet = _puppet_of(who)
		if who is PlayerController:
			var pc: PlayerController = who as PlayerController
			pc.rotation.y = 0.0
			pc.velocity = Vector3.ZERO
			var body: Node3D = pc.get_node_or_null("Body") as Node3D
			if body != null:
				body.rotation.y = yaw
			pc.yaw = yaw + 0.22
			pc.pitch = -0.2
			pc.snap_camera()
		else:
			who.rotation.y = yaw
		if pup != null:
			pup.lying = "front"


func _stand_up() -> void:
	for who: Node3D in [get_node_or_null("Player") as Node3D, get_node_or_null("Sheila") as Node3D, _misha]:
		var pup: Puppet = _puppet_of(who)
		if pup != null:
			pup.lying = ""


func _puppet_of(who: Node3D) -> Puppet:
	if who == null:
		return null
	if who is Puppet:
		return who as Puppet
	if who.has_method("puppet"):
		return who.call("puppet") as Puppet
	return null


func is_lying(who: Node3D) -> bool:
	var pup: Puppet = _puppet_of(who)
	return pup != null and pup.lying == "front"


func _on_dialogue_started(runner: DialogueRunner) -> void:
	if runner != null and runner.dialogue_id == RHYTHM_TALK and not runner.line_shown.is_connected(_on_rhythm_line):
		runner.line_shown.connect(_on_rhythm_line)


## 「敲」那一句出現：照剛剛選的節奏判定（寫進 ch3.react，下一句讀它），送葬者照結果演。
func _on_rhythm_line(_speaker_key: String, text_key: String) -> void:
	if text_key != KNOCK_LINE:
		return
	var tempo: String = str(Game.session.state.get_flag(RhythmTrial.FLAG_LAST, ""))
	var r: String = RhythmTrial.try_last(Game.session.state)
	if r != "":
		_play_reaction(tempo, r)


## 席菈照 tempo 敲 KNOCK_COUNT 下（悶悶的布包石頭敲銅片）；第 REACT_AFTER 下之後送葬者反應。
## 轉頭：先回到正面 → 提示音（設定可關）→ 上半身轉向銅片、停住；胸口的銅光跟著敲的速度亮。
func _play_reaction(tempo: String, r: String) -> void:
	skip_reaction()
	last_reaction = r
	if _torso == null:
		return
	_torso.rotation = Vector3.ZERO
	var times: PackedFloat32Array = RhythmTrial.knock_times(tempo, KNOCK_COUNT)
	var knocks := create_tween()
	var prev: float = 0.0
	for i: int in times.size():
		knocks.tween_interval(maxf(times[i] - prev, 0.001))
		knocks.tween_callback(_knock)
		prev = times[i]
	var react_at: float = times[mini(REACT_AFTER, times.size() - 1)]
	var tw := create_tween()
	tw.tween_interval(react_at)
	match r:
		RhythmTrial.TURN:
			if Settings.observe_cue:
				tw.tween_callback(_cue)
			tw.tween_interval(CUE_LEAD)
			tw.tween_property(_torso, "rotation:y", deg_to_rad(_turn_sign() * TURN_DEG), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		RhythmTrial.TILT:
			tw.tween_property(_torso, "rotation:z", deg_to_rad(TILT_DEG), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_interval(1.1)
			tw.tween_property(_torso, "rotation:z", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_:
			if RhythmTrial.bpm(tempo) <= 0.0 and _pivot != null:
				# 不規則：鏈子抖一下又靜下來（沒有提示音：牠沒有要轉頭）
				tw.tween_property(_pivot, "position:y", BEAM_Y + 0.04, 0.08)
				tw.tween_property(_pivot, "position:y", BEAM_Y, 0.25)
	_reaction_tweens = [knocks, tw]


## 測試、截圖用：反應直接跳到結果（轉頭的停在轉過去的樣子）。
func skip_reaction() -> void:
	for t: Tween in _reaction_tweens:
		if t != null and t.is_valid():
			t.kill()
	_reaction_tweens.clear()
	if _torso == null:
		return
	_torso.rotation = Vector3(0.0, deg_to_rad(_turn_sign() * TURN_DEG) if last_reaction == RhythmTrial.TURN else 0.0, 0.0)
	if _pivot != null:
		_pivot.position.y = BEAM_Y


## 上半身往哪邊轉才是對著銅片（牠面朝東南，銅片在東岸）。
func _turn_sign() -> float:
	if _undertaker == null:
		return 1.0
	var to: Vector3 = PLATE_POS - _undertaker.global_position
	var fwd: Vector3 = -_undertaker.global_basis.z
	return 1.0 if fwd.cross(Vector3(to.x, 0.0, to.z)).y >= 0.0 else -1.0


## 送葬者上半身現在轉了多少度（測試讀）。
func torso_turn_deg() -> float:
	return rad_to_deg(_torso.rotation.y) if _torso != null else 0.0


func _knock() -> void:
	if _plate != null:
		Sfx.play_at(self, "cloth_knock", _plate.global_position + Vector3(0, 0.25, 0), -2.0, 0.03)


func _cue() -> void:
	if _pivot != null:
		Sfx.play_at(self, "chain_creak", _pivot.global_position + Vector3(0, -CHAIN_LEN * 0.5, 0), 0.0, 0.02, 9.0)


## 觀察的對話結束：找到速度 → 站起來、攻略筆記提示（空白條目已經由旗標變成證實）→ 段落 3 待續。
func _on_rhythm_ended() -> void:
	in_drain = false
	_stand_up()
	if not bool(Game.session.state.get_flag(RhythmTrial.FLAG_FOUND, false)):
		return
	_banner("GUIDE_SELF_NOTE", 4.0)
	if not _continued_shown:
		_continued_shown = true
		get_tree().create_timer(4.3).timeout.connect(_banner.bind("CH1_TO_BE_CONTINUED", 6.0))


## 水溝：東岸上一道沿 Z 的淺溝（兩側低低的石緣、底下爛泥），前端插著一片銅片。
func _build_drain() -> void:
	var drain := Node3D.new()
	drain.name = "Drain"
	drain.position = DRAIN_POS
	add_child(drain)
	var curb: StandardMaterial3D = _mat(STONE_LIGHT, 0.9)
	for side: float in [-1.0, 1.0]:
		_solid("DrainCurb%d" % int(side), Vector3(DRAIN_W + 0.32, 0.18, 0.16), Vector3(0.0, 0.09, side * (DRAIN_LEN * 0.5 + 0.08)), curb, false, drain)
		_solid("DrainSide%d" % int(side), Vector3(0.16, 0.12, DRAIN_LEN), Vector3(side * (DRAIN_W * 0.5 + 0.08), 0.06, 0.0), curb, false, drain)
	var mud: StandardMaterial3D = _mat(Color(0.07, 0.06, 0.055), 0.35)
	mud.metallic_specular = 0.6
	_solid("DrainMud", Vector3(DRAIN_W, 0.02, DRAIN_LEN), Vector3(0.0, 0.012, 0.0), mud, false, drain)
	_plate = Node3D.new()
	_plate.name = "CopperPlate"
	_plate.position = PLATE_POS - DRAIN_POS
	drain.add_child(_plate)
	var copper := _mat(Color(0.55, 0.33, 0.18), 0.4)
	copper.metallic = 0.85
	var sheet: MeshInstance3D = _solid("Sheet", Vector3(0.36, 0.42, 0.02), Vector3(0.0, 0.2, 0.0), copper, false, _plate)
	sheet.rotation.y = 0.5
	if _undertaker != null:
		_torso = _undertaker.find_child("Torso", true, false) as Node3D


## 對話開始時：席菈站在諾恩東北邊（不擋往橋下看的視線）、彌夏在諾恩左手邊的渠邊（往橋那邊看）。
func _place_company() -> void:
	var ally: Node3D = get_node_or_null("Sheila") as Node3D
	if ally != null:
		ally.global_position = BANK_POS + Vector3(2.3, 0.05, -1.6)
	if _misha != null:
		_misha.global_position = BANK_POS + Vector3(-0.4, -0.05, 1.3)
		var to: Vector3 = Vector3(0.0, 0.0, HANG_Z) - _misha.global_position
		_misha.rotation.y = atan2(-to.x, -to.z)


func _follow_misha(player: Node3D, delta: float) -> void:
	if _misha == null or Game.is_player_locked() or _dev_hold_edge:
		if _misha != null:
			_misha.set_move_speed(0.0)
		return
	var gap: Vector3 = Vector3(_misha.global_position.x - player.global_position.x, 0.0, _misha.global_position.z - player.global_position.z)
	var dist: float = gap.length()
	var mstep: float = clampf(dist - MISHA_GAP, 0.0, MISHA_SPEED * delta)
	if dist - MISHA_GAP > 10.0:
		mstep = dist - MISHA_GAP
	if mstep > 0.001 and dist > 0.001:
		_misha.global_position -= gap / dist * mstep
		_misha.rotation.y = atan2(gap.x, gap.z)
	_misha.set_move_speed(mstep / maxf(delta, 0.0001))


func undertaker() -> Undertaker:
	return _undertaker


func clapper_light() -> OmniLight3D:
	return _clapper_light


# ---------------------------------------------------------------- 場景

func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


## 地底城的夜：幾乎全黑的背景、很弱的冷色環境光、體積霧（斜光切成一條條就是靠它看得到）、SSAO 開著（這裡有影子）。
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.008, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.55, 0.7)
	env.ambient_light_energy = 0.07
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.024
	env.volumetric_fog_albedo = Color(0.82, 0.86, 0.92)
	env.volumetric_fog_emission = Color(0.003, 0.004, 0.006)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 64.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "SlitLight"
	sun.rotation_degrees = SLIT_LIGHT_ROT
	sun.light_color = SLIT_COLOR
	sun.light_energy = SLIT_LIGHT_ENERGY
	sun.light_volumetric_fog_energy = SLIT_LIGHT_FOG
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = 60.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)


func _solid(node_name: String, size: Vector3, pos: Vector3, mat: Material, collide: bool = true, parent: Node3D = null) -> MeshInstance3D:
	var host: Node3D = parent if parent != null else self
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	host.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.name = node_name + "Body"
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		body.add_child(cs)
		body.position = pos
		host.add_child(body)
	return mi


func _blocker(node_name: String, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	body.position = pos
	add_child(body)


## 兩岸（岸頂 y＝0）、河床（爛泥＋中間一條還沒乾的淺水）、岸邊的壓頂石與矮牆、最外側的岩壁、南北兩端的牆。
func _build_canal() -> void:
	var length: float = Z_SOUTH - Z_NORTH
	var mid_z: float = (Z_SOUTH + Z_NORTH) * 0.5
	var stone: StandardMaterial3D = _mat(STONE, 0.9)
	var coping: StandardMaterial3D = _mat(STONE_LIGHT, 0.85)
	var rock: StandardMaterial3D = _mat(ROCK, 1.0)
	var bank_depth: float = -BED_Y + 0.5
	for side: float in [-1.0, 1.0]:
		var cx: float = side * (CANAL_HALF_W + BANK_W * 0.5)
		var tag: String = "E" if side > 0.0 else "W"
		_solid("Bank" + tag, Vector3(BANK_W, bank_depth, length), Vector3(cx, -bank_depth * 0.5, mid_z), stone)
		_solid("Coping" + tag, Vector3(0.5, 0.12, length), Vector3(side * (CANAL_HALF_W + 0.25), 0.06, mid_z), coping, false)
		_solid("Parapet" + tag, Vector3(0.35, PARAPET_H, length), Vector3(side * (CANAL_HALF_W + 0.22), PARAPET_H * 0.5, mid_z), stone, false)
		_blocker("Parapet" + tag + "Block", Vector3(0.35, PARAPET_BLOCK_H, length), Vector3(side * (CANAL_HALF_W + 0.22), PARAPET_BLOCK_H * 0.5, mid_z))
		_solid("OuterWall" + tag, Vector3(1.0, OUTER_WALL_H - BED_Y, length + 2.0), Vector3(side * (CANAL_HALF_W + BANK_W + 0.5), (OUTER_WALL_H + BED_Y) * 0.5, mid_z), rock)
		# 河道兩側的石牆上一道道接縫（看得出是砌的）
		for i: int in int(length / 3.2):
			var z: float = Z_SOUTH - 1.6 - i * 3.2
			_solid("Seam%s%d" % [tag, i], Vector3(0.04, -BED_Y - 0.2, 0.06), Vector3(side * (CANAL_HALF_W - 0.005), BED_Y * 0.5, z), _mat(ROCK, 1.0), false)
	var mud: StandardMaterial3D = _mat(MUD, 0.95)
	_solid("CanalBed", Vector3(CANAL_HALF_W * 2.0, 0.4, length), Vector3(0.0, BED_Y - 0.2, mid_z), mud)
	# 河床中間一條還沒乾的淺水：低粗糙度，接得到從縫裡下來的光
	var water := _mat(Color(0.05, 0.055, 0.06), 0.08)
	water.metallic_specular = 0.8
	_solid("Puddle", Vector3(1.1, 0.02, length * 0.8), Vector3(-0.3, BED_Y + 0.01, mid_z - 2.0), water, false)
	# 河床上的碎石與爛木頭
	for i: int in 26:
		var size := Vector3(_rng.randf_range(0.2, 0.7), _rng.randf_range(0.1, 0.35), _rng.randf_range(0.2, 0.8))
		var p := Vector3(_rng.randf_range(-CANAL_HALF_W + 0.4, CANAL_HALF_W - 0.4), BED_Y + size.y * 0.5, _rng.randf_range(Z_NORTH + 2.0, Z_SOUTH - 2.0))
		var debris: MeshInstance3D = _solid("Debris%d" % i, size, p, _mat(STONE if i % 3 else WOOD, 1.0), false)
		debris.rotation.y = _rng.randf_range(-PI, PI)
	for z: float in [Z_SOUTH + 0.5, Z_NORTH - 0.5]:
		_solid("EndWall%d" % int(z), Vector3((CANAL_HALF_W + BANK_W + 1.0) * 2.0, OUTER_WALL_H - BED_Y, 1.0), Vector3(0.0, (OUTER_WALL_H + BED_Y) * 0.5, z), rock)
	var edge := Node3D.new()
	edge.name = "BankEdge"
	edge.position = BANK_POS
	add_child(edge)


## 石橋：橋面、兩側欄杆、兩座橋墩貼在河道牆上。
func _build_bridge() -> void:
	var stone: StandardMaterial3D = _mat(STONE, 0.9)
	var span: float = CANAL_HALF_W * 2.0 + 0.8
	_solid("BridgeDeck", Vector3(span, DECK_T, BRIDGE_W), Vector3(0.0, -DECK_T * 0.5, BRIDGE_Z), stone)
	for side: float in [-1.0, 1.0]:
		_solid("BridgeRail%d" % int(side), Vector3(span, 0.7, 0.25), Vector3(0.0, 0.35, BRIDGE_Z + side * (BRIDGE_W * 0.5 - 0.125)), stone)
		_solid("BridgeHaunch%d" % int(side), Vector3(0.6, 0.9, BRIDGE_W), Vector3(side * (CANAL_HALF_W - 0.3), -DECK_T - 0.45, BRIDGE_Z), stone, false)


## 北邊的閘道：河道裡兩座石墩、上面一根木樑、一扇拉起來的木閘門（段落 3 把送葬者引進來的地方）。
func _build_sluice() -> void:
	var stone: StandardMaterial3D = _mat(STONE, 0.9)
	var wood: StandardMaterial3D = _mat(WOOD, 0.9)
	var h: float = -BED_Y + 2.2
	for side: float in [-1.0, 1.0]:
		_solid("SluicePier%d" % int(side), Vector3(0.9, h, 1.4), Vector3(side * 1.7, BED_Y + h * 0.5, SLUICE_Z), stone, false)
	_solid("SluiceBeam", Vector3(4.4, 0.45, 0.5), Vector3(0.0, BED_Y + h + 0.22, SLUICE_Z), wood, false)
	_solid("SluiceGate", Vector3(2.5, 1.6, 0.18), Vector3(0.0, BED_Y + h - 1.0, SLUICE_Z + 0.3), wood, false)


## 頭頂的石樑：一排排橫跨整個運河（含兩岸），之間留縫——鐘院的光從縫裡透下來。
func _build_ceiling() -> void:
	var rock: StandardMaterial3D = _mat(ROCK, 1.0)
	var width: float = (CANAL_HALF_W + BANK_W + 1.0) * 2.0
	var depth: float = SLAT_PITCH - SLAT_GAP
	var ceiling := Node3D.new()
	ceiling.name = "CeilingSlats"
	add_child(ceiling)
	var i: int = 0
	var z: float = Z_SOUTH + 1.0
	while z > Z_NORTH - 1.0:
		_solid("Slat%d" % i, Vector3(width, 1.2, depth), Vector3(0.0, SLAT_Y + 0.6, z - depth * 0.5), rock, false, ceiling)
		z -= SLAT_PITCH
		i += 1


## 掛著的送葬者：重用 Undertaker 的外觀，但不動、不打、不在敵人名單裡（段落 2 才醒）。
## 兩條鐵鏈從鐵架掛到吊樑；整個掛點慢慢晃。胸口一點銅光＝鐘舌（像心跳一樣亮）。
func _build_undertaker() -> void:
	var wood: StandardMaterial3D = _mat(WOOD, 0.9)
	_solid("HangBeam", Vector3(CANAL_HALF_W * 2.0 + 1.4, 0.32, 0.36), Vector3(0.0, BEAM_Y + 0.16, HANG_Z), wood, false)
	for side: float in [-1.0, 1.0]:
		_solid("HangBeamPost%d" % int(side), Vector3(0.3, BEAM_Y - PARAPET_H, 0.3), Vector3(side * (CANAL_HALF_W + 0.22), PARAPET_H + (BEAM_Y - PARAPET_H) * 0.5, HANG_Z), wood, false)
	_pivot = Node3D.new()
	_pivot.name = "HangPivot"
	_pivot.position = Vector3(HANG_X, BEAM_Y, HANG_Z)
	add_child(_pivot)
	var u := Undertaker.new()
	u.name = "ClapperUndertaker"
	# 鐵架頂（約 2.6 m）掛在鏈子下；腳懸在河床上方三公尺多
	u.position = Vector3(0.0, -CHAIN_LEN - 2.6, 0.0)
	# 面朝東南（從東岸的說話點看得到胸口）
	u.rotation.y = atan2(-0.55, -0.83)
	_pivot.add_child(u)
	u.remove_from_group("enemies")
	u.remove_from_group("damageable")
	u.process_mode = Node.PROCESS_MODE_DISABLED
	u.set_physics_process(false)
	_undertaker = u
	var iron: StandardMaterial3D = _mat(IRON, 0.6)
	iron.metallic = 0.7
	for side: float in [-1.0, 1.0]:
		var chain := MeshInstance3D.new()
		chain.name = "Chain%d" % int(side)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.035
		cm.height = CHAIN_LEN + 0.15
		chain.mesh = cm
		chain.material_override = iron
		chain.position = Vector3(side * 0.42, -(CHAIN_LEN + 0.15) * 0.5, 0.15)
		_pivot.add_child(chain)
	# 鐘舌：一根短短的銅棒斜插在胸口，自己會發光；旁邊一盞小小的銅色點光（不投影子）
	_clapper_mat = StandardMaterial3D.new()
	_clapper_mat.albedo_color = Color(0.55, 0.32, 0.16)
	_clapper_mat.metallic = 0.8
	_clapper_mat.roughness = 0.35
	_clapper_mat.emission_enabled = true
	_clapper_mat.emission = COPPER
	_clapper_mat.emission_energy_multiplier = 2.0
	var rod := MeshInstance3D.new()
	rod.name = "Clapper"
	var rm := CylinderMesh.new()
	rm.top_radius = 0.035
	rm.bottom_radius = 0.07
	rm.height = 0.42
	rod.mesh = rm
	rod.material_override = _clapper_mat
	rod.position = Vector3(0.0, 1.5, -0.4)
	rod.rotation_degrees = Vector3(70.0, 0.0, 18.0)
	u.add_child(rod)
	_clapper_light = OmniLight3D.new()
	_clapper_light.name = "ClapperLight"
	_clapper_light.light_color = COPPER
	_clapper_light.light_energy = CLAPPER_ENERGY
	_clapper_light.omni_range = 2.2
	_clapper_light.shadow_enabled = false
	_clapper_light.light_volumetric_fog_energy = 0.4
	_clapper_light.position = Vector3(0.0, 1.5, -0.55)
	u.add_child(_clapper_light)
	# 正好有一道縫的光落在牠身上：跟斜光同一個方向的窄聚光（不投影子；第 45 輪截圖：只靠斜光，暗色大衣在河道裡看不出來）
	var spot := SpotLight3D.new()
	spot.name = "SlitOnUndertaker"
	spot.light_color = SLIT_COLOR
	spot.light_energy = SLIT_SPOT_ENERGY
	spot.light_volumetric_fog_energy = 1.2
	spot.spot_range = 9.0
	spot.spot_angle = 16.0
	spot.shadow_enabled = false
	var target: Vector3 = _pivot.position + Vector3(0.0, -CHAIN_LEN - 1.4, 0.0)
	var dir: Vector3 = Basis.from_euler(SLIT_LIGHT_ROT * PI / 180.0) * Vector3.FORWARD
	add_child(spot)
	spot.look_at_from_position(target - dir * 5.5, target)


# ---------------------------------------------------------------- 人：席菈、彌夏跟著

func _build_people() -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	var from: Vector3 = player.global_position if player != null else SPAWN
	_misha = Puppet.new()
	_misha.name = "Misha"
	_misha.coat_color = Color(0.16, 0.27, 0.21)
	_misha.trim_color = Color(0.3, 0.26, 0.2)
	add_child(_misha)
	var hammer: Node = _misha.hand("R").get_node_or_null("BellHammer") if _misha.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()
	_misha.global_position = from + Vector3(1.6, -0.05, -1.4)
	var ally := Sheila.new()
	ally.name = "Sheila"
	ally.position = from + Vector3(-1.0, 0.0, -1.2)
	add_child(ally)
