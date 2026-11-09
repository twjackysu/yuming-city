class_name JournalView
extends CanvasLayer
## 日記畫面（docs/design/02-gameplay.md「記憶與日記」）：
## - Tab／View 打開（暫停遊戲），再按一次或 Esc／B 闔上。最上面是目前目標（Tab 原本的「再看一次目標」）。
## - 被付出的記憶：標題與前後文保留，內文變成一塊被整齊剪掉的空白，下面是殘留的一句。
## - 九息預覽中（Game.journal.highlighted）：不暫停，在畫面右側只顯示那一張卡（「九息的代價」）。

## 預覽卡（畫面右側、深色半透明底）用的亮色字
const INK: Color = Color(0.86, 0.84, 0.8)
const INK_DIM: Color = Color(0.62, 0.62, 0.64)
const WARM: Color = Color(0.95, 0.72, 0.42)
## 日記本身是一張暖色舊紙（D-073）：深褐墨水、紅褐標題、細線分隔；被剪掉的地方是挖空的洞，透出後面的夜色
const PAPER: Color = Color(0.86, 0.8, 0.68)
const PAPER_INK: Color = Color(0.17, 0.13, 0.1)
const PAPER_INK_DIM: Color = Color(0.4, 0.33, 0.26)
const PAPER_WARM: Color = Color(0.52, 0.22, 0.1)
const PAPER_RULE: Color = Color(0.45, 0.36, 0.26, 0.45)
const CUT: Color = Color(0.06, 0.065, 0.08)

## 紙紋理只畫一次（每次進關卡都會建一個 JournalView）
static var _paper_cache: ImageTexture = null

var _root: Control
var _list: VBoxContainer
## 還沒有任何條目時的提示
var _empty: Label
var _hint: Label
var _objective: Label
var _peek: PanelContainer
var _peek_id: String = ""
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()
	_peek.hide()
	# 截圖用：`--open=journal`（可配 `--arch=spent` 看被剪掉的樣子；`--guide-demo` 寫下攻略筆記、推翻兩條）
	var args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	if args.has("guide-demo"):
		guide_demo(Game.session)
	if str(args.get("open", "")) == "journal":
		open.call_deferred()


## 截圖與測試用：寫下全部攻略筆記，標兩條「我不確定」，推翻其中一條標了的、一條沒標的。
static func guide_demo(s: GameSession) -> void:
	GuideNotes.write(s.state, s.guide.ids())
	GuideNotes.set_unsure(s.state, "stair_arrows", true)
	GuideNotes.set_unsure(s.state, "purifier", true)
	s.state.set_flag("ch1.stair_trap_sprung", true)
	s.state.set_flag("ch1.met_kord", true)
	s.guide.evaluate(s.state)


func is_open() -> bool:
	return _root.visible


func is_peeking() -> bool:
	return _peek.visible


## 目前日記裡顯示的記憶條目數（測試用；不含攻略筆記）。
func shown_entry_count() -> int:
	var n: int = 0
	for c: Node in _list.get_children():
		if not str(c.name).begins_with("Guide"):
			n += 1
	return n


## 攻略筆記那一段顯示的條目：[{id, status}]（測試用）。
var guide_rows_shown: Array[Dictionary] = []


func open() -> void:
	if is_open() or Game.is_player_locked():
		return
	_refresh()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_root.show()


func close() -> void:
	if not is_open():
		return
	_root.hide()
	get_tree().paused = false
	Input.mouse_mode = _mouse_before


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if is_open():
			close()
		elif not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()
	elif is_open() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var j: Journal = Game.journal
	var want: String = j.highlighted if j != null and not is_open() else ""
	if want == _peek_id:
		return
	_peek_id = want
	for c: Node in _peek.get_children():
		c.queue_free()
	if want == "" or not j.has_entry(want):
		_peek.hide()
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var head := Label.new()
	head.text = "JOURNAL_PEEK"
	head.add_theme_color_override("font_color", WARM)
	head.add_theme_font_size_override("font_size", 18)
	box.add_child(head)
	box.add_child(_card(j.view(want, Game.session.state), false))
	_peek.add_child(box)
	_peek.show()


func _refresh() -> void:
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	# Tab 原本是「再看一次目前目標」：日記最上面也放目前目標
	_objective.text = Game.session.objective_key()
	var j: Journal = Game.journal
	if j == null:
		return
	for id: String in j.visible_ids(Game.session.state):
		_list.add_child(_card(j.view(id, Game.session.state), true))
	_add_guide_section(Game.session.state, Game.session.guide)
	_empty.visible = _list.get_child_count() == 0
	_hint.text = TranslationServer.translate("JOURNAL_HINT_CLOSE").format({"key": InputGlyphs.label_for_action("journal", App.last_device)})


## 攻略筆記（D-148）：記憶卡下面一段「攻略筆記」，每條一列——可信度小標＋攻略寫的那句；
## 被推翻的那句整句劃掉（一條墨線），下面是現實裡看到的事。還沒寫下任何條目時整段不出現（切片）。
func _add_guide_section(state: GameState, guide: GuideNotes) -> void:
	guide_rows_shown.clear()
	if guide == null:
		return
	var rows: Array[Dictionary] = []
	for id: String in guide.ids():
		var st: String = GuideNotes.status(state, id)
		if st != GuideNotes.UNWRITTEN:
			rows.append({"id": id, "status": st})
	if rows.is_empty():
		return
	guide_rows_shown = rows
	var head := Label.new()
	head.name = "GuideHead"
	head.text = "JOURNAL_TAB_GUIDE"
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", PAPER_WARM)
	_list.add_child(head)
	for r: Dictionary in rows:
		_list.add_child(_guide_row(str(r["id"]), str(r["status"])))


func _guide_row(id: String, status: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Guide_" + id
	box.add_theme_constant_override("separation", 2)
	var tag := Label.new()
	tag.name = "Status"
	tag.text = "GUIDE_STATUS_" + status.to_upper()
	tag.add_theme_font_size_override("font_size", 14)
	var tag_col: Color = PAPER_INK_DIM
	if status == GuideNotes.WRONG:
		tag_col = PAPER_WARM
	elif status == GuideNotes.CONFIRMED:
		tag_col = Color(0.2, 0.32, 0.22)
	tag.add_theme_color_override("font_color", tag_col)
	box.add_child(tag)
	var line := Label.new()
	line.name = "Text"
	line.text = GuideNotes.text_key(id)
	line.add_theme_font_size_override("font_size", 19)
	line.add_theme_color_override("font_color", PAPER_INK_DIM if status == GuideNotes.WRONG else PAPER_INK)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(620, 0)
	box.add_child(line)
	if status == GuideNotes.UNSURE:
		line.add_theme_color_override("font_color", PAPER_INK_DIM)
	if status == GuideNotes.WRONG:
		# 一條稍微斜的墨線劃過整句（跟著字的實際寬度）
		var strike := ColorRect.new()
		strike.name = "Strike"
		strike.color = Color(PAPER_WARM, 0.85)
		strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(strike)
		line.resized.connect(_fit_strike.bind(line, strike))
		_fit_strike.call_deferred(line, strike)
		var real := Label.new()
		real.name = "Real"
		real.text = GuideNotes.wrong_key(id)
		real.add_theme_font_size_override("font_size", 19)
		real.add_theme_color_override("font_color", PAPER_INK)
		real.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		real.custom_minimum_size = Vector2(620, 0)
		box.add_child(real)
	return box


func _fit_strike(line: Label, strike: ColorRect) -> void:
	if not is_instance_valid(line) or not is_instance_valid(strike):
		return
	var font: Font = line.get_theme_font("font")
	var fs: int = line.get_theme_font_size("font_size")
	var w: float = minf(font.get_string_size(line.text if line.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else tr(line.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, line.size.x)
	strike.size = Vector2(w + 8.0, 2.0)
	strike.position = Vector2(-4.0, line.size.y * 0.55)
	strike.rotation = -0.012


## 一張記憶卡：標題、前後文、內文（或被剪掉的空白＋殘留）。
## on_paper：日記本裡（紙上、深色墨水、上方一條細線分隔）；false：預覽卡（深色底、亮色字）。
func _card(v: Dictionary, on_paper: bool) -> PanelContainer:
	var hl: bool = bool(v.get("highlighted", false))
	var ink: Color = PAPER_INK if on_paper else INK
	var dim: Color = PAPER_INK_DIM if on_paper else INK_DIM
	var warm: Color = PAPER_WARM if on_paper else WARM
	var card := PanelContainer.new()
	card.name = "Card_" + str(v.get("id", ""))
	var sb := StyleBoxFlat.new()
	if on_paper:
		# 紙上不畫底色：上方一條細線分隔；正在預覽的那張左邊多一道紅褐色細條
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_width_top = 1
		sb.border_color = PAPER_RULE
		sb.content_margin_top = 16
		sb.content_margin_bottom = 6
		sb.content_margin_left = 14 if hl else 0
		if hl:
			sb.border_width_left = 3
			sb.border_color = PAPER_WARM
	else:
		sb.bg_color = Color(0.1, 0.105, 0.12, 0.98)
		sb.set_content_margin_all(18)
		sb.set_border_width_all(2 if hl else 0)
		sb.border_color = WARM
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var title := Label.new()
	title.text = str(v.get("title", ""))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", warm if (hl or on_paper) else ink)
	box.add_child(title)
	if str(v.get("context", "")) != "":
		box.add_child(_para(str(v["context"]), dim))
	if bool(v.get("cut", false)):
		# 被整齊剪掉的空白：紙上挖掉一塊、透出後面的夜色（邊緣一圈剪口的淺色）；預覽卡上是比底稍亮的空格
		var gap := Panel.new()
		gap.name = "CutGap"
		gap.custom_minimum_size = Vector2(0, 76)
		var gs := StyleBoxFlat.new()
		gs.bg_color = CUT
		if on_paper:
			gs.set_border_width_all(1)
			gs.border_color = Color(0.96, 0.92, 0.82)
			gs.shadow_color = Color(0, 0, 0, 0.35)
			gs.shadow_size = 3
		else:
			gs.bg_color = Color(0.13, 0.135, 0.15)
			gs.border_width_top = 1
			gs.border_width_bottom = 1
			gs.border_color = Color(0.3, 0.31, 0.34)
		gap.add_theme_stylebox_override("panel", gs)
		gap.tooltip_text = "JOURNAL_CUT"
		box.add_child(gap)
		if str(v.get("residue", "")) != "":
			box.add_child(_para(str(v["residue"]), ink))
	else:
		box.add_child(_para(str(v.get("body", "")), ink))
	return card


func _para(key: String, color: Color) -> Label:
	var l := Label.new()
	l.text = key
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", color)
	l.custom_minimum_size = Vector2(560, 0)
	return l


## 程式畫的舊紙紋理（不進 git 的圖檔）：暖色底、低頻的深淺斑駁、細纖維、四邊微暗。
static func paper_texture(size: int = 256) -> ImageTexture:
	if _paper_cache != null and _paper_cache.get_width() == size:
		return _paper_cache
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var blot := FastNoiseLite.new()
	blot.seed = 9
	blot.frequency = 0.012
	blot.fractal_octaves = 3
	var fiber := FastNoiseLite.new()
	fiber.seed = 23
	fiber.frequency = 0.09
	for y: int in size:
		for x: int in size:
			var b: float = blot.get_noise_2d(x, y)  # -1..1，大塊的深淺
			var f: float = fiber.get_noise_2d(x * 0.35, y * 2.2)  # 橫向拉長＝纖維
			var k: float = 1.0 + b * 0.05 + f * 0.025
			img.set_pixel(x, y, Color(PAPER.r * k, PAPER.g * k, PAPER.b * (k - 0.01)))
	_paper_cache = ImageTexture.create_from_image(img)
	return _paper_cache


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var paper := PanelContainer.new()
	paper.name = "Paper"
	var ps := StyleBoxTexture.new()
	ps.texture = paper_texture()
	ps.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	ps.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	ps.set_content_margin_all(40)
	paper.add_theme_stylebox_override("panel", ps)
	paper.custom_minimum_size = Vector2(760, 560)
	center.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	paper.add_child(col)
	var title := Label.new()
	title.text = "JOURNAL_TITLE"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", PAPER_INK)
	col.add_child(title)
	# 標題下兩條細線（像筆記本的頁首）
	var rule := Panel.new()
	rule.custom_minimum_size = Vector2(0, 4)
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0)
	rs.border_width_top = 1
	rs.border_width_bottom = 1
	rs.border_color = PAPER_RULE
	rule.add_theme_stylebox_override("panel", rs)
	col.add_child(rule)
	var obj_head := Label.new()
	obj_head.text = "HUD_OBJECTIVE"
	obj_head.add_theme_font_size_override("font_size", 14)
	obj_head.add_theme_color_override("font_color", PAPER_WARM)
	col.add_child(obj_head)
	_objective = Label.new()
	_objective.name = "Objective"
	_objective.add_theme_font_size_override("font_size", 20)
	_objective.add_theme_color_override("font_color", PAPER_INK)
	col.add_child(_objective)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 16)
	scroll.add_child(_list)
	_empty = Label.new()
	_empty.name = "Empty"
	_empty.text = "JOURNAL_EMPTY"
	_empty.add_theme_font_size_override("font_size", 19)
	_empty.add_theme_color_override("font_color", PAPER_INK_DIM)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size = Vector2(560, 0)
	col.add_child(_empty)
	col.move_child(_empty, scroll.get_index())
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", PAPER_INK_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_hint)

	_peek = PanelContainer.new()
	_peek.name = "Peek"
	var pk := StyleBoxFlat.new()
	pk.bg_color = Color(0.05, 0.055, 0.07, 0.82)
	pk.set_content_margin_all(16)
	_peek.add_theme_stylebox_override("panel", pk)
	_peek.anchor_left = 1.0
	_peek.anchor_right = 1.0
	_peek.anchor_top = 0.18
	_peek.anchor_bottom = 0.18
	_peek.offset_left = -660.0
	_peek.offset_right = -40.0
	_peek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_peek)
