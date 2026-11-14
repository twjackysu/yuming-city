extends Node3D
## Benchmark：載入腐敗之森入口，鏡頭沿固定路徑從出生點飛過瘴氣到林間空地，結束後把統計寫到 user://benchmark/*.json。
## 用法：YumingCity.exe ++ --benchmark [--bench-seconds=30]（`++` 與 `--` 相同，但 PowerShell 不會吃掉）
## 結果檔路徑會印在主控台與畫面上；Windows 在 %APPDATA%\YumingCity\benchmark\。

const LEVEL: String = "res://scenes/levels/corrupt_forest.tscn"
const OUT_DIR: String = "user://benchmark"
## 鏡頭路徑（世界座標）：沿著路從出生點到空地後面
const PATH_POINTS: Array[Vector3] = [
	Vector3(0.0, 1.8, 18.0), Vector3(-2.0, 1.7, 9.0), Vector3(1.5, 2.2, 0.0),
	Vector3(-1.0, 2.4, -8.0), Vector3(0.8, 2.8, -16.0), Vector3(0.0, 3.5, -24.0),
]
const LOOK_AHEAD: float = 0.06

var run: BenchmarkRun
var result_path: String = ""
var quit_when_done: bool = true
var _camera: Camera3D
var _label: Label


func _ready() -> void:
	var args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	run = BenchmarkRun.new(float(args.get("bench-seconds", 30.0)))
	var level: Node = (load(LEVEL) as PackedScene).instantiate()
	add_child(level)
	var player: Node = level.get_node_or_null("Player")
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	_camera = Camera3D.new()
	_camera.fov = 70.0
	add_child(_camera)
	_camera.make_current.call_deferred()
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(24, 980)
	_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(_label)
	add_child(layer)
	_place_camera(0.0)


static func sample_path(t: float) -> Vector3:
	var n: int = PATH_POINTS.size() - 1
	var f: float = clampf(t, 0.0, 1.0) * float(n)
	var i: int = mini(int(floor(f)), n - 1)
	var local: float = f - float(i)
	var a: Vector3 = PATH_POINTS[maxi(i - 1, 0)]
	var b: Vector3 = PATH_POINTS[i]
	var c: Vector3 = PATH_POINTS[i + 1]
	var d: Vector3 = PATH_POINTS[mini(i + 2, n)]
	return b.cubic_interpolate(c, a, d, local)


func _place_camera(t: float) -> void:
	var pos: Vector3 = sample_path(t)
	var ahead: Vector3 = sample_path(minf(t + LOOK_AHEAD, 1.0))
	if t + LOOK_AHEAD >= 1.0:
		ahead = Vector3(0.0, 8.0, -50.0)  # 最後抬頭看樹梢
	_camera.global_position = pos
	if not pos.is_equal_approx(ahead):
		_camera.look_at(ahead, Vector3.UP)


func _process(delta: float) -> void:
	if result_path != "":
		return
	var done: bool = run.push(delta)
	_place_camera(run.progress())
	_label.text = "BENCHMARK %d%%" % int(run.progress() * 100.0)
	if done:
		_finish()


func _finish() -> void:
	var perf: Node = get_node_or_null("/root/Perf")
	var meta: Dictionary = {
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"date": Time.get_datetime_string_from_system(),
		"os": OS.get_name(),
		"cpu": OS.get_processor_name(),
	}
	if perf != null:
		var snap: Dictionary = perf.call("snapshot")
		for key: String in ["driver", "method", "adapter", "resolution", "vram_mb", "draw_calls"]:
			meta[key] = snap.get(key)
	var report: Dictionary = run.to_dict(meta)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	result_path = OUT_DIR.path_join("bench-%s.json" % stamp)
	var f := FileAccess.open(result_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	var abs_path: String = ProjectSettings.globalize_path(result_path)
	var s: Dictionary = report["stats"]
	_label.text = "BENCHMARK DONE  avg %.1f fps  1%% low %.1f fps\n%s" % [float(s["avg_fps"]), float(s["low1_fps"]), abs_path]
	print("[Benchmark] %s" % JSON.stringify(s))
	print("[Benchmark] -> %s" % abs_path)
	if quit_when_done:
		await get_tree().create_timer(2.0).timeout
		get_tree().quit(0)
