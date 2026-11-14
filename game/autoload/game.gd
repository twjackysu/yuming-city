extends Node
## 遊戲流程外殼：持有 GameSession，負責新遊戲／繼續／切換關卡。
## 邏輯都在 GameSession（res://src/core/game_session.gd），這裡只做場景切換。
##
## 開發用：`godot --path game -- --level=corrupt_forest` 直接開新遊戲進關卡（截圖驗證用，存檔寫到 DEV_SAVE_DIR）；
## `-- --benchmark` 跑效能測試後結束（結果在 user://benchmark/）。

signal level_loaded(level_id: String)
signal dialogue_started(runner: DialogueRunner)
signal dialogue_ended(dialogue_id: String)
signal player_died

## 倒下到自動重試的時間（真實時間）
const RETRY_DELAY_SEC: float = 2.2
## 遊戲時間一幀最多加幾秒
const PLAYTIME_MAX_STEP: float = 0.25

## 關卡 id -> 場景
const LEVELS: Dictionary = {
	"corrupt_forest": "res://scenes/levels/corrupt_forest.tscn",
	"benchmark": "res://scenes/bench/benchmark.tscn",
}
## 檢查點 -> 關卡 id（沒列的都在 DEFAULT_LEVEL）
const CHECKPOINT_LEVELS: Dictionary = {
	"ch1_forest_gate": "corrupt_forest",
	"ch1_slimes": "corrupt_forest",
	"ch1_after_slimes": "corrupt_forest",
}
const DEFAULT_LEVEL: String = "corrupt_forest"
## `--level=…` 開發旗標用的存檔資料夾：不會蓋掉玩家真正的進度
const DEV_SAVE_DIR: String = "user://saves_dev"
const TITLE_SCENE: String = "res://scenes/boot/boot.tscn"

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
	if args.has("benchmark"):
		level = "benchmark"
	if level != "":
		# benchmark 不開新遊戲（只飛過關卡，也不會寫存檔）
		if not args.has("benchmark"):
			session.save_dir = DEV_SAVE_DIR
			session.new_game.call_deferred()
		go_to_level.call_deferred(level)


## 標題畫面的「新遊戲／繼續」。load_level=false 給測試用（只改狀態、不換場景）。
func has_continue() -> bool:
	return session.has_save(GameSession.AUTO_SLOT)


func new_game(load_level: bool = true) -> void:
	session.new_game()
	if load_level:
		go_to_level(level_for_checkpoint(session.state.checkpoint))


func continue_game(load_level: bool = true) -> bool:
	if session.load_slot(GameSession.AUTO_SLOT) != SaveCodec.Status.OK:
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
	await get_tree().create_timer(RETRY_DELAY_SEC, true, false, true).timeout
	if _player_dead:
		retry()


func is_player_dead() -> bool:
	return _player_dead


## 遊戲時間這一幀加多少：用真實時間（打擊停頓的慢動作不少算）；一幀最多 PLAYTIME_MAX_STEP（換場景卡住的那一幀不算進去）。
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
	Engine.time_scale = 1.0
	_player_dead = false
	dialogue = null
	get_tree().change_scene_to_file(TITLE_SCENE)
