extends Node
## 遊戲流程外殼：持有 GameSession，負責新遊戲／繼續／切換關卡。
## 邏輯都在 GameSession（res://src/core/game_session.gd），這裡只做場景切換。
##
## 開發用：`godot --path game -- --level=frostbridge [--rb-at=…]` 直接進入關卡（截圖驗證用）；
## `--level=market --rb-at=arrive|street|shop|board|board_read|deal|demo|demo_end|fight|demo_won|bracer|bracer_ask|bracer_read|trial|trial_fight|trial_hold|trial_won` 是地下市場；
## `-- --benchmark` 跑效能測試後結束（結果在 user://benchmark/）。

signal level_loaded(level_id: String)
signal dialogue_started(runner: DialogueRunner)
signal dialogue_ended(dialogue_id: String)
signal player_died

## 倒下到自動重試的時間（真實時間）
const RETRY_DELAY_SEC: float = 2.2
## 遊戲時間一幀最多加幾秒（D-179）
const PLAYTIME_MAX_STEP: float = 0.25

## 關卡 id -> 場景。前十分鐘的檢查點都在霜橋鎮；貨梯下去之後是地下市場（market）。
const LEVELS: Dictionary = {
	"frostbridge": "res://scenes/levels/frostbridge.tscn",
	"market": "res://scenes/levels/underground_market.tscn",
	"benchmark": "res://scenes/bench/benchmark.tscn",
}
## 檢查點 -> 關卡 id（沒列的都在霜橋鎮）
const CHECKPOINT_LEVELS: Dictionary = {
	# 新版前十分鐘（劇情重寫，D-204）：都在霜橋鎮
	"rb_start": "frostbridge",
	"rb_before_mist": "frostbridge",
	"rb_sheila": "frostbridge",
	"rb_guardian": "frostbridge",
	"rb_portable": "frostbridge",
	"rb_market": "frostbridge",
	# 地下市場（第二段 A，任務 rb_market）
	"rb2_arrive": "market",
	"rb2_street": "market",
	"rb2_shop": "market",
	# 黑市示範場（第二段 B，任務 rb_demo）：同一個關卡
	"rb2_demo": "market",
	"rb2_demo_fight": "market",
	"rb2_bracer": "market",
	"rb2_bracer_board": "market",
	"rb2_trial": "market",
	"rb2_trial_fight": "market",
}
const DEFAULT_LEVEL: String = "frostbridge"
## 戰鬥場用哪個關卡（地下市場示範台前的街）
const ARENA_LEVEL: String = "market"
## `--level=…` 開發旗標用的存檔資料夾（實際寫到 user://saves_dev_reboot）
const DEV_SAVE_DIR: String = "user://saves_dev"
const TITLE_SCENE: String = "res://scenes/boot/boot.tscn"

## 戰鬥場（docs/design/11-combat-first.md 3.1，D-238）：true＝地下市場不掛劇情、掛 Arena；不讀不寫劇情存檔。
## 開發旗標：`-- --arena [--wave=1..4] [--bot=idle|mash|skilled] [--runs=20]`（機器人跑完印 ARENA_SUMMARY 後結束；用法見 scripts/arena_bots.sh）
var arena_mode: bool = false:
	set(v):
		arena_mode = v
		# 戰鬥場用自己的一套數值（tuning.json 的 profiles.arena，D-239）；離開就還原
		CombatTuning.set_profile(CombatTuning.PROFILE_ARENA if v else "")
var arena_wave: int = 0
var arena_bot: String = ""
var arena_runs: int = 0

var session: GameSession
var dialogues: DialogueDB
## 進行中的對話（沒有則為 null）
var dialogue: DialogueRunner


func _ready() -> void:
	session = GameSession.new(QuestDB.load_default())
	dialogues = DialogueDB.load_default()
	for e: String in dialogues.errors:
		push_error("Game: 對話資料錯誤 " + e)
	var args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	var level: String = str(args.get("level", ""))
	# 開發用：`-- --char-lit`＝角色模型改成吃場景的光（給 Jacky 選受光方式的對照圖用，D-254）
	Puppet.lit_models = args.has("char-lit")
	if args.has("benchmark"):
		level = "benchmark"
	if args.has("arena"):
		arena_bot = str(args.get("bot", ""))
		arena_runs = int(args.get("runs", 0))
		start_arena.call_deferred(true, int(args.get("wave", 1)) - 1)
		level = ""
	if level != "":
		# 開發用：`-- --level=frostbridge` 直接開新遊戲；`--rb-at=start|mist|guardian|market…` 推到那一段（D-204）
		# benchmark 不開新遊戲（只飛過空的霜橋鎮，也不會寫到玩家的存檔）
		if not args.has("benchmark"):
			_dev_story_start.call_deferred(str(args.get("rb-at", "")), level)
		go_to_level.call_deferred(level)
	# 截圖用：`-- --level=frostbridge --rb-at=market --dialogue=rb_ada_wages --dialogue-steps=2`
	if args.has("dialogue"):
		var dlg: String = str(args["dialogue"])
		var steps: int = int(args.get("dialogue-steps", 0))
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			start_dialogue(dlg)
			for i: int in steps:
				dialogue.advance())


## 開發旗標開的遊戲存在另一個資料夾（DEV_SAVE_DIR），不會蓋掉玩家真正的進度。
func _dev_story_start(at: String, level: String = DEFAULT_LEVEL) -> void:
	session.save_dir = DEV_SAVE_DIR
	session.new_game()
	if level == "market":
		UndergroundMarketStory.dev_advance(session, at)
	else:
		FrostbridgeOpening.dev_advance(session, at)


## 標題畫面的「新遊戲／繼續」（D-211）；存檔在 GameSession.STORY_SAVE_DIR。load_level=false 給測試用（只改狀態、不換場景）。
func has_continue() -> bool:
	return session.has_story_save(GameSession.AUTO_SLOT)


## 標題畫面的「戰鬥場」：換一個沒有開劇情的 session（in_story() 是 false：不恢復也不寫生命、藥、存檔），
## 存檔資料夾照舊——回標題之後「新遊戲／繼續」讀寫的還是原本的地方。load_level=false 給測試用。
func start_arena(load_level: bool = true, wave: int = 0) -> void:
	arena_mode = true
	arena_wave = maxi(wave, 0)
	_player_dead = false
	dialogue = null
	session = GameSession.new(session.db, session.save_dir)
	if load_level:
		go_to_level(ARENA_LEVEL)


## 戰鬥場原地重來：Arena 把人扶起來之後叫這個（不重讀檢查點、不換場景）
func arena_revived() -> void:
	_player_dead = false
	Engine.time_scale = 1.0


func new_game(load_level: bool = true) -> void:
	arena_mode = false
	session.new_game()
	if load_level:
		go_to_level(level_for_checkpoint(session.state.checkpoint))


func continue_game(load_level: bool = true) -> bool:
	arena_mode = false
	if session.load_story_slot(GameSession.AUTO_SLOT) != SaveCodec.Status.OK:
		return false
	if load_level:
		go_to_level(level_for_checkpoint(session.state.checkpoint))
	return true


static func level_for_checkpoint(checkpoint_id: String) -> String:
	return str(CHECKPOINT_LEVELS.get(checkpoint_id, DEFAULT_LEVEL))


func go_to_level(level_id: String) -> void:
	var path: String = str(LEVELS.get(level_id, ""))
	if path == "":
		push_error("Game: 沒有關卡 %s" % level_id)
		return
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Game: 載入 %s 失敗：%s" % [path, error_string(err)])
		return
	level_loaded.emit(level_id)


## 開始一段對話；效果套用後讓任務推進。已有對話進行中時回傳 false。
func start_dialogue(dialogue_id: String) -> bool:
	if is_in_dialogue():
		return false
	var r := DialogueRunner.new(dialogues, session.state)
	r.state_changed.connect(_on_dialogue_state_changed)
	r.finished.connect(_on_dialogue_finished)
	dialogue = r
	if not r.start(dialogue_id):
		dialogue = null
		return false
	dialogue_started.emit(r)
	return true


func is_in_dialogue() -> bool:
	return dialogue != null and dialogue.is_running()


var _hit_stop_token: int = 0
var _player_dead: bool = false


## 玩家倒下：發訊號（HUD 顯示「你倒下了」），稍後從最近的檢查點重來。
func on_player_died() -> void:
	if _player_dead:
		return
	_player_dead = true
	player_died.emit()
	# 戰鬥場：不重讀檢查點，Arena 自己原地重來這一波
	if arena_mode:
		return
	await get_tree().create_timer(RETRY_DELAY_SEC, true, false, true).timeout
	if _player_dead:
		retry()


func is_player_dead() -> bool:
	return _player_dead


## 遊戲時間這一幀加多少（D-179）：用真實時間（打擊停頓的慢動作不少算）；一幀最多 PLAYTIME_MAX_STEP（換場景卡住的那一幀不算進去）。
## 暫停時 Game 跟著暫停、_process 不跑，標題畫面不在關卡裡，都不算。
static func playtime_step(delta: float, time_scale: float) -> float:
	return clampf(delta / maxf(time_scale, 0.01), 0.0, PLAYTIME_MAX_STEP)


## 從最近的自動存檔重來；沒有存檔時重新開始。reload_level=false 給測試用（只重設狀態）。
## 遊戲時間不跟著退回檢查點（倒下重來的那幾分鐘也是玩的時間）。
func retry(reload_level: bool = true) -> void:
	_player_dead = false
	Engine.time_scale = 1.0
	dialogue = null
	var played: float = session.state.playtime_sec
	if session.retry_from_checkpoint() != SaveCodec.Status.OK:
		session.new_game()
	session.state.playtime_sec = maxf(session.state.playtime_sec, played)
	if reload_level:
		go_to_level(level_for_checkpoint(session.state.checkpoint))


## 打擊停頓：短暫把時間放慢，用真實時間計時後恢復（重疊時以最後一次為準）。
func hit_stop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_hit_stop_token += 1
	var token: int = _hit_stop_token
	Engine.time_scale = CombatTuning.num("feel.hit_stop_time_scale", 0.05)
	await get_tree().create_timer(seconds, true, false, true).timeout
	if token == _hit_stop_token:
		Engine.time_scale = 1.0


func is_hit_stopped() -> bool:
	return Engine.time_scale < 1.0


## 玩家角色不能移動（對話中、倒下）。
func is_player_locked() -> bool:
	return is_in_dialogue() or _player_dead


func _process(delta: float) -> void:
	if session != null and get_tree().current_scene is StoryLevel:
		session.state.playtime_sec += playtime_step(delta, Engine.time_scale)


func _on_dialogue_state_changed() -> void:
	session.advance()


func _on_dialogue_finished(dialogue_id: String) -> void:
	dialogue = null
	dialogue_ended.emit(dialogue_id)


func back_to_title() -> void:
	arena_mode = false
	Engine.time_scale = 1.0
	_player_dead = false
	dialogue = null
	get_tree().change_scene_to_file(TITLE_SCENE)
