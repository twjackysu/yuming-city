extends Node
## 全域入口：解析命令列（截圖模式、benchmark 等開發工具）。
##
## 用法（引數放在 `--` 之後）：
##   godot --path game -- --screenshot=/tmp/shot.png --frames=60
##   → 跑 60 幀後把畫面存成 PNG 並結束（給 xvfb-run 畫面驗證用）。

var screenshot_path: String = ""
var screenshot_frames: int = 60
var _frame: int = 0


func _ready() -> void:
	var args: Dictionary = parse_user_args(OS.get_cmdline_user_args())
	screenshot_path = str(args.get("screenshot", ""))
	screenshot_frames = int(args.get("frames", 60))
	set_process(screenshot_path != "")


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


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < screenshot_frames:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(screenshot_path)
	print("[App] screenshot -> %s (%s)" % [screenshot_path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
