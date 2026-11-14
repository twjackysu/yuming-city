extends Node
## 全域入口：解析命令列（截圖模式、benchmark 等開發工具）。
##
## 用法（引數放在 `--` 之後）：
##   godot --path game -- --screenshot=/tmp/shot.png --frames=60
##   → 跑 60 幀後把畫面存成 PNG 並結束（給 xvfb-run 畫面驗證用）。

## 最後使用的輸入裝置（InputGlyphs.Device）；切換時發 device_changed，提示文字跟著換鍵名。
signal device_changed(device: int)

var last_device: int = InputGlyphs.Device.KBM
## 最後動過的手把編號（右搖桿鏡頭讀這支；沒有手把事件前是 0）
var last_pad: int = 0
var screenshot_path: String = ""
var screenshot_frames: int = 60
## 連拍（docs/design/04-architecture.md「開發工具」；scripts/burst.sh 在用）：
##   -- --burst=/tmp/b --burst-from=100 --burst-every=6 --burst-count=8
##   → 第 100 幀起每 6 幀存一張 /tmp/b-0.png…b-7.png，存完結束。搭配 --fixed-fps 60 就是每 0.1 秒一張。
var burst_prefix: String = ""
var burst_from: int = 60
var burst_every: int = 6
var burst_count: int = 8
var _burst_saved: int = 0
## 連拍只畫要存的那幾幀（`--burst-lazy`，scripts/burst.sh 的 BURST_LAZY=1；第 99 輪）：軟體算圖一秒只畫一兩幀，
## 等「第一次愣住」這種開場好幾秒之後才發生的事要等三四分鐘——沒有要存的幀不畫，遊戲照 --fixed-fps 走。
## 開機的前 BURST_LAZY_BOOT 幀照常畫（載入、編 shader），要存的那一幀與它前面 BURST_LAZY_WARM 幀也畫
## （體積霧要前幾幀的結果；用 --burst-on 觸發的第一張來不及暖，霧會粗一點）。
var burst_lazy: bool = false
const BURST_LAZY_BOOT: int = 20
const BURST_LAZY_WARM: int = 2
var _frame: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暫停中也要能截圖
	var theme: Theme = UiFonts.build_theme()
	get_tree().root.theme = theme
	# root.theme 傳不過 Node3D／CanvasLayer（關卡裡的 HUD、對話框、暫停選單都在那底下），
	# 所以也併進引擎的預設 Theme：沒有 theme 來源的 Control 都會用到同一套字型與焦點樣式
	ThemeDB.get_default_theme().merge_with(theme)
	InputSetup.ensure_actions()
	var args: Dictionary = parse_user_args(OS.get_cmdline_user_args())
	screenshot_path = str(args.get("screenshot", ""))
	screenshot_frames = int(args.get("frames", 60))
	if str(args.get("device", "")) == "pad":
		last_device = InputGlyphs.Device.PAD
	burst_prefix = str(args.get("burst", ""))
	burst_from = int(args.get("burst-from", burst_from))
	burst_every = maxi(int(args.get("burst-every", burst_every)), 1)
	burst_count = maxi(int(args.get("burst-count", burst_count)), 1)
	burst_lazy = args.has("burst-lazy")
	set_process(screenshot_path != "" or burst_prefix != "")


func _input(event: InputEvent) -> void:
	var d: int = InputGlyphs.device_of_event(event)
	if d == InputGlyphs.Device.PAD and event.device >= 0:
		last_pad = event.device
	if d >= 0:
		set_device(d)
	# 開發用：F5 重新載入戰鬥數值（user://tuning.json 覆寫）
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F5:
		CombatTuning.load_tuning()


func set_device(device: int) -> void:
	if device == last_device:
		return
	last_device = device
	device_changed.emit(device)


static func parse_user_args(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for raw: String in argv:
		if not raw.begins_with("--"):
			continue
		var body: String = raw.substr(2)
		var eq: int = body.find("=")
		if eq < 0:
			out[body] = true
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out


## 連拍改成「從現在起第 delay 幀」開始拍（開發用）：要拍的事情什麼時候發生每場不一樣（例如敵人變紅），
## 就把 --burst-from 設成很大的數字、事情發生的那一刻叫這個（戰鬥場的 --burst-on=brace）。印出實際的幀數，改前的版本用同一個數字拍。
func burst_start_in(delay: int) -> void:
	burst_from = _frame + maxi(delay, 1)
	print("[App] burst from frame %d" % burst_from)
	if burst_lazy:
		RenderingServer.render_loop_enabled = true


## 這一幀是不是連拍要存的那一幀。純函式。
static func burst_index(frame: int, from: int, every: int, count: int) -> int:
	if frame < from or (frame - from) % every != 0:
		return -1
	var i: int = (frame - from) / every
	return i if i < count else -1


## 離下一張要存的幀還有幾幀（0＝就是這一幀）。純函式。
static func burst_wait(frame: int, from: int, every: int) -> int:
	if frame <= from:
		return from - frame
	return (every - (frame - from) % every) % every


func _process(_delta: float) -> void:
	_frame += 1
	if burst_prefix != "":
		if burst_lazy and _frame > BURST_LAZY_BOOT:
			RenderingServer.render_loop_enabled = burst_wait(_frame, burst_from, burst_every) <= BURST_LAZY_WARM
		var i: int = burst_index(_frame, burst_from, burst_every, burst_count)
		if i < 0:
			return
		await RenderingServer.frame_post_draw
		var shot: Image = get_viewport().get_texture().get_image()
		var e: Error = shot.save_png("%s-%d.png" % [burst_prefix, i])
		_burst_saved += 1
		if e != OK or _burst_saved >= burst_count:
			print("[App] burst -> %s-0..%d.png (%s)" % [burst_prefix, _burst_saved - 1, error_string(e)])
			set_process(false)
			get_tree().quit(0 if e == OK else 1)
		return
	if _frame < screenshot_frames:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(screenshot_path)
	print("[App] screenshot -> %s (%s)" % [screenshot_path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
