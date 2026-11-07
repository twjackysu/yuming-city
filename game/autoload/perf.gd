extends CanvasLayer
## 效能 overlay（F3 切換；啟動參數 `-- --perf` 預設開啟）。
## 開發／實機量測工具：顯示 FPS、幀時間、1% low、CPU／GPU 渲染時間、draw calls、VRAM、
## 渲染驅動與顯示卡名稱。內容是技術縮寫，不走翻譯（玩家設定選單不會出現）。

const REFRESH_SEC: float = 0.25

var stats := FrameStats.new(1000)
var _label: Label
var _panel: PanelContainer
var _accum: float = 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.72)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.91, 0.89, 0.84))
	_panel.add_child(_label)
	add_child(_panel)
	var args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	set_overlay_visible(args.has("perf"))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func set_overlay_visible(value: bool) -> void:
	_panel.visible = value


func is_overlay_visible() -> bool:
	return _panel.visible


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		set_overlay_visible(not _panel.visible)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	stats.push(delta * 1000.0)
	if not _panel.visible:
		return
	_accum += delta
	if _accum < REFRESH_SEC:
		return
	_accum = 0.0
	_label.text = snapshot_text()


func render_times_ms() -> Vector2:
	var rid: RID = get_viewport().get_viewport_rid()
	return Vector2(
		RenderingServer.viewport_get_measured_render_time_cpu(rid),
		RenderingServer.viewport_get_measured_render_time_gpu(rid))


func snapshot() -> Dictionary:
	var rt: Vector2 = render_times_ms()
	var d: Dictionary = stats.to_dict()
	d["render_cpu_ms"] = snappedf(rt.x, 0.01)
	d["render_gpu_ms"] = snappedf(rt.y, 0.01)
	d["draw_calls"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	d["objects"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	d["vram_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)
	d["mem_mb"] = snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)
	d["driver"] = RenderingServer.get_current_rendering_driver_name()
	d["method"] = RenderingServer.get_current_rendering_method()
	d["adapter"] = RenderingServer.get_video_adapter_name()
	var win: Vector2i = DisplayServer.window_get_size()
	d["resolution"] = "%dx%d" % [win.x, win.y]
	return d


func snapshot_text() -> String:
	var d: Dictionary = snapshot()
	return "\n".join([
		"FPS %.0f   1%% low %.0f" % [float(d["avg_fps"]), float(d["low1_fps"])],
		"frame %.2f ms (max %.1f)   >16.7ms %.1f%%" % [float(d["avg_ms"]), float(d["max_ms"]), float(d["over_16_7ms_ratio"]) * 100.0],
		"render CPU %.2f ms   GPU %.2f ms" % [float(d["render_cpu_ms"]), float(d["render_gpu_ms"])],
		"draw calls %d   objects %d" % [int(d["draw_calls"]), int(d["objects"])],
		"VRAM %.0f MB   RAM %.0f MB" % [float(d["vram_mb"]), float(d["mem_mb"])],
		"%s / %s / %s" % [str(d["method"]), str(d["driver"]), str(d["resolution"])],
		str(d["adapter"]),
	])
