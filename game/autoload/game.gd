extends Node
## 遊戲流程外殼：持有 GameSession，負責新遊戲／繼續／切換關卡。
## 邏輯都在 GameSession（res://src/core/game_session.gd），這裡只做場景切換。
##
## 開發用：`godot --path game -- --level=sandbox` 直接進入關卡（截圖驗證用）。

signal level_loaded(level_id: String)

## 關卡 id -> 場景。切片場景完成前，所有檢查點都在 sandbox。
const LEVELS: Dictionary = {
	"sandbox": "res://scenes/dev/sandbox.tscn",
}
## 檢查點 -> 關卡 id
const CHECKPOINT_LEVELS: Dictionary = {}
const DEFAULT_LEVEL: String = "sandbox"
const TITLE_SCENE: String = "res://scenes/boot/boot.tscn"

var session: GameSession


func _ready() -> void:
	session = GameSession.new(QuestDB.load_default())
	var args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	var level: String = str(args.get("level", ""))
	if level != "":
		session.new_game.call_deferred()
		go_to_level.call_deferred(level)


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


func back_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
