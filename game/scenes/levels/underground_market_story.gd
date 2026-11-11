class_name UndergroundMarketStory
extends Node
## 地下市場的劇情（第二段 A，docs/design/10-reboot-underground-market.md）：任務 rb_market。
## arrive：貨梯下來 → 走下坡道到街上（席菈說這裡的規矩）→ find_shop：走到街底的藥店門口 →
## test_board：（還沒做：彌夏與測試板）——現在走到門口就是「待續」→ 回標題。
## 掛在 UndergroundMarket 底下（`Game.session.in_story()` 時）。沒有戰鬥，不會倒下；讀檔回到三個檢查點之一。

const QUEST: String = GameSession.MARKET_QUEST
## 檢查點 → 諾恩出生的位置與朝向（度；180＝面向南）
const SPAWNS: Dictionary = {
	"rb2_arrive": [Vector3(0.0, 0.0, -2.6), 180.0],
	"rb2_street": [Vector3(0.0, 0.0, UndergroundMarket.RAMP_S + 1.6), 180.0],
	"rb2_shop": [Vector3(-0.9, 0.0, UndergroundMarket.SHOP_Z - 7.0), 180.0],
}
## 走過這條線＝到街上了
const STREET_LINE_Z: float = UndergroundMarket.RAMP_S + 0.6
## 離藥店的門多近算「到了」
const SHOP_RANGE: float = 2.4
## 「待續」的配樂（D-219）：卡出來時慢慢進來，回標題時跟著關卡一起收掉
const END_MUSIC: String = "part_end_theme"
const END_MUSIC_DB: float = -14.0
const END_MUSIC_FADE: float = 2.5
## 截圖旗標 `--level=market --rb-at=arrive|street|shop`：就是三個檢查點的出生位置（arrive＝貨梯下來的第一眼，固定鏡頭 60）

var level: UndergroundMarket
var player: PlayerController
## 「待續」那張卡出來了（之後不再觸發任何東西）
var ending: bool = false
## 「待續」播完之後做什麼；空的＝回標題。測試換成自己的（不要真的換場景）
var end_done: Callable = Callable()
var end_music: AudioStreamPlayer


func _ready() -> void:
	level = get_parent() as UndergroundMarket
	player = level.get_node_or_null("Player") as PlayerController
	# 前十分鐘做完的舊存檔在 GameSession.load_slot 已經補開這條任務；這裡再保險一次（已經開了就不動）
	if Game.session.quests.is_done(GameSession.MAIN_QUEST):
		Game.session.quests.start(QUEST)
	if player != null:
		_place_player(Game.session.state.checkpoint)
		# 席菈站在他斜前方（已經在往街上看）：不擋在鏡頭與街之間
		_spawn_sheila(player.global_position + Vector3(1.7, 0.0, 1.1))
		player.snap_camera()


## 截圖、測試用：照正式流程設旗標，推到地下市場的那一段。arrive＝剛下貨梯；street＝走到街上了；shop＝到藥店門口了。
static func dev_advance(s: GameSession, at: String) -> void:
	FrostbridgeOpening.dev_advance(s, "lift")
	s.set_flag("rb.market_reached", true)
	if at in ["street", "shop"]:
		s.set_flag("rb2.street_reached", true)
		s.set_flag("rb2.rules_heard", true)
	if at == "shop":
		s.set_flag("rb2.shop_reached", true)


func stage() -> String:
	return Game.session.quests.stage_of(QUEST)


func _physics_process(_delta: float) -> void:
	if player == null or ending or Game.is_player_locked():
		return
	var st: GameState = Game.session.state
	var pos: Vector3 = player.global_position
	match stage():
		"arrive":
			if pos.z >= STREET_LINE_Z:
				Game.session.set_flag("rb2.street_reached", true)
		"find_shop":
			# 第一次走到街上：席菈說這裡的規矩（讀檔回來不會再講一次）
			if not bool(st.get_flag("rb2.rules_heard", false)):
				Game.start_dialogue("rb2_sheila_rules")
			elif FrostbridgeOpening.flat_distance(pos, UndergroundMarket.SHOP_DOOR) <= SHOP_RANGE:
				Game.session.set_flag("rb2.shop_reached", true)
		"test_board":
			if FrostbridgeOpening.flat_distance(pos, UndergroundMarket.SHOP_DOOR) <= SHOP_RANGE:
				play_end_card()


## 目前做到的地方的結尾：畫面淡成黑 →「待續／彌夏的藥店」→ 回標題。諾恩停住（黑幕底下不會被按鍵推著走）。
func play_end_card() -> ChapterCard:
	if ending:
		return level.get_node_or_null("ChapterCard") as ChapterCard
	ending = true
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	end_music = Ambience.music(level, END_MUSIC, END_MUSIC_DB, END_MUSIC_FADE, "RbEndMusic")
	return ChapterCard.play(level, "RB_END_NUMBER", "RB2_END_TITLE", _on_end_card_done)


func _on_end_card_done() -> void:
	if end_done.is_valid():
		end_done.call()
	else:
		Game.back_to_title()


func _place_player(checkpoint: String) -> void:
	var spec: Array = SPAWNS.get(checkpoint, SPAWNS["rb2_arrive"]) as Array
	var pos: Vector3 = spec[0] as Vector3
	pos.y = level.ground_y(pos) + 0.05
	player.global_position = pos
	player.rotation.y = deg_to_rad(float(spec[1]))
	player.yaw = player.rotation.y


func _spawn_sheila(pos: Vector3) -> void:
	if level.has_node("Sheila"):
		return
	var ally := Sheila.new()
	ally.name = "Sheila"
	ally.position = Vector3(pos.x, level.ground_y(pos), pos.z)
	ally.rotation_degrees.y = 180.0
	level.add_child(ally)
