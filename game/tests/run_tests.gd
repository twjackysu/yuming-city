extends SceneTree
## 測試入口：
##   godot --headless --path game -s res://tests/run_tests.gd
## 依序：1) 所有 GDScript 都能載入（警告視為錯誤的設定會讓未加型別的腳本失敗）
##       2) 執行 res://tests/unit/ 與 res://tests/flow/ 下所有 test_*.gd（環境變數 TEST_FILTER 可只跑部分檔案）
## 任何失敗都以非 0 結束碼離開，CI 據此判定。

const TEST_DIRS: PackedStringArray = ["res://tests/unit", "res://tests/flow"]
const SKIP_DIRS: PackedStringArray = ["res://.godot", "res://addons"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var problems: PackedStringArray = []
	var passed: int = 0
	# 1) 腳本載入檢查
	var scripts: PackedStringArray = []
	_collect("res://", ".gd", scripts)
	for path: String in scripts:
		var script: Script = load(path) as Script
		if script == null or not script.can_instantiate():
			problems.append("腳本無法載入：%s" % path)
	print("[tests] 檢查 %d 個腳本" % scripts.size())

	# 2) 測試
	var test_files: PackedStringArray = []
	for dir: String in TEST_DIRS:
		_collect(dir, ".gd", test_files)
	# 開發用：TEST_FILTER=gamepad 只跑檔名含這段字的測試檔（CI 不設，全部跑）
	var only: String = OS.get_environment("TEST_FILTER")
	for path: String in test_files:
		if not path.get_file().begins_with("test_"):
			continue
		if only != "" and not path.get_file().contains(only):
			continue
		var script: GDScript = load(path) as GDScript
		if script == null:
			problems.append("測試無法載入：%s" % path)
			continue
		for method: Dictionary in script.get_script_method_list():
			var name: String = str(method.get("name", ""))
			if not name.begins_with("test_"):
				continue
			var case: TestCase = script.new() as TestCase
			if case == null:
				problems.append("%s 沒有繼承 TestCase" % path)
				break
			case.tree = self
			case.current_test = "%s::%s" % [path.get_file(), name]
			case.before_each()
			await case.call(name)
			case.after_each()
			if case.failures.is_empty():
				passed += 1
				print("  ok   %s" % case.current_test)
			else:
				for f: String in case.failures:
					problems.append(f)
				print("  FAIL %s" % case.current_test)

	print("[tests] 通過 %d 個測試，問題 %d 個" % [passed, problems.size()])
	for p: String in problems:
		printerr("  - " + p)
	await _silence()
	quit(0 if problems.is_empty() else 1)


## 結束前把還在播的音效停掉、等兩幀：不然流程測試最後一聲（AudioStreamPlaybackWAV）會在結束時被算成
## 「2 ObjectDB instances were leaked at exit」（第 49 輪起的警告，不影響結果）。
func _silence() -> void:
	for cls: String in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for n: Node in root.find_children("*", cls, true, false):
			n.call("stop")
	await create_timer(0.25).timeout
	await process_frame


func _collect(dir_path: String, ext: String, out: PackedStringArray) -> void:
	if SKIP_DIRS.has(dir_path.trim_suffix("/")):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), ext, out)
	for file: String in dir.get_files():
		if file.ends_with(ext):
			out.append(dir_path.path_join(file))
