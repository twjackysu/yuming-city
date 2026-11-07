extends Node
## 遊戲流程外殼：持有 GameSession，負責新遊戲／繼續／切換關卡。
## 邏輯都在 GameSession（res://src/core/game_session.gd），這裡只做場景切換。
##
## 開發用：`godot --path game -- --level=sandbox` 直接進入關卡（截圖驗證用）；
## `-- --benchmark` 跑效能測試後結束（結果在 user://benchmark/）。

signal level_loaded(level_id: String)
signal dialogue_started(runner: DialogueRunner)
signal dialogue_ended(dialogue_id: String)
signal cutscene_started(runner: CutsceneRunner)
signal cutscene_ended(cutscene_id: String, skipped: bool)
signal player_died

## 倒下到自動重試的時間（真實時間）
const RETRY_DELAY_SEC: float = 2.2

## 關卡 id -> 場景。切片場景完成前，所有檢查點都在 sandbox。
const LEVELS: Dictionary = {
	"sandbox": "res://scenes/dev/sandbox.tscn",
	"benchmark": "res://scenes/bench/benchmark.tscn",
}
## 檢查點 -> 關卡 id
const CHECKPOINT_LEVELS: Dictionary = {}
const DEFAULT_LEVEL: String = "sandbox"
const TITLE_SCENE: String = "res://scenes/boot/boot.tscn"

var session: GameSession
var dialogues: DialogueDB
## 進行中的對話（沒有則為 null）
var dialogue: DialogueRunner
## 進行中的過場（沒有則為 null）；時間由這裡推進，暫停時跟著停
var cutscene: CutsceneRunner


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
		session.new_game.call_deferred()
		go_to_level.call_deferred(level)
	# 截圖用：`-- --level=sandbox --dialogue=slice_pear_seller --dialogue-steps=2`
	if args.has("dialogue"):
		var dlg: String = str(args["dialogue"])
		var steps: int = int(args.get("dialogue-steps", 0))
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			start_dialogue(dlg)
			for i: int in steps:
				dialogue.advance())
	# 截圖用：`-- --level=sandbox --cutscene=slice_bell_nine --cutscene-steps=3`（跳過開場鏡頭後敲 N 下）
	if args.has("cutscene"):
		var cs_id: String = str(args["cutscene"])
		var presses: int = int(args.get("cutscene-steps", 0))
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if not play_cutscene(cs_id):
				return
			cutscene.update(100.0)
			for i: int in presses:
				cutscene.press(cutscene.awaited_action())
			if not cutscene.is_waiting():
				cutscene.update(0.0))


func has_continue() -> bool:
	return session.has_save(GameSession.AUTO_SLOT)


func new_game() -> void:
	session.new_game()
	go_to_level(level_for_checkpoint(session.state.checkpoint))


func continue_game() -> bool:
	if session.load_slot(GameSession.AUTO_SLOT) != SaveCodec.Status.OK:
		return false
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


## 開始一段過場；已有過場或對話進行中時回傳 false。
func play_cutscene(cutscene_id: String) -> bool:
	if is_in_cutscene() or is_in_dialogue():
		return false
	var r := CutsceneRunner.new(session.state)
	r.state_changed.connect(_on_dialogue_state_changed)
	r.finished.connect(_on_cutscene_finished)
	cutscene = r
	cutscene_started.emit(r)
	if not r.start(cutscene_id):
		cutscene = null
		cutscene_ended.emit(cutscene_id, true)
		return false
	return true


func is_in_cutscene() -> bool:
	return cutscene != null and cutscene.is_running()


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


## 從最近的自動存檔重來；沒有存檔時重新開始。reload_level=false 給測試用（只重設狀態）。
func retry(reload_level: bool = true) -> void:
	_player_dead = false
	Engine.time_scale = 1.0
	dialogue = null
	cutscene = null
	if session.retry_from_checkpoint() != SaveCodec.Status.OK:
		session.new_game()
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


## 玩家角色不能移動（對話或過場中）。
func is_player_locked() -> bool:
	return is_in_dialogue() or is_in_cutscene() or _player_dead


func _process(delta: float) -> void:
	if cutscene != null and cutscene.is_running():
		cutscene.update(delta)


func _on_cutscene_finished(cutscene_id: String, skipped: bool) -> void:
	cutscene = null
	cutscene_ended.emit(cutscene_id, skipped)


func _on_dialogue_state_changed() -> void:
	session.advance()


func _on_dialogue_finished(dialogue_id: String) -> void:
	dialogue = null
	dialogue_ended.emit(dialogue_id)


func back_to_title() -> void:
	Engine.time_scale = 1.0
	_player_dead = false
	dialogue = null
	cutscene = null
	get_tree().change_scene_to_file(TITLE_SCENE)
