extends TestCase
## 在地化規則：
## - i18n/*.csv 每個 key 都要有非空的 en 與 zh_TW，key 不可跨檔重複
## - 場景檔裡的 text / tooltip_text / placeholder_text 只能是翻譯 key（大寫底線），不准寫死句子
## - 場景用到的 key 都要存在於 CSV
## - 玩家看到的字要白話：原作的難懂用詞不可出現（docs/design/06-terminology.md）

const CSV_DIR: String = "res://i18n"
const KEY_PATTERN: String = "^[A-Z][A-Z0-9_]*$"


func _load_table() -> Dictionary:
	var table: Dictionary = {}
	for file: String in DirAccess.get_files_at(CSV_DIR):
		if not file.ends_with(".csv"):
			continue
		var path: String = CSV_DIR.path_join(file)
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			fail("讀不到 " + path)
			continue
		var header: PackedStringArray = f.get_csv_line()
		assert_eq(header, PackedStringArray(["keys", "en", "zh_TW"]), path + " 欄位")
		while not f.eof_reached():
			var row: PackedStringArray = f.get_csv_line()
			if row.size() == 1 and row[0] == "":
				continue
			if table.has(row[0]):
				fail("key 重複：%s（%s）" % [row[0], path])
			table[row[0]] = row
	return table


func test_csv_files_are_registered() -> void:
	var registered: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	for file: String in DirAccess.get_files_at(CSV_DIR):
		if not file.ends_with(".csv"):
			continue
		var base: String = CSV_DIR.path_join(file.get_basename())
		for loc: String in ["en", "zh_TW"]:
			assert_true(registered.has("%s.%s.translation" % [base, loc]), "%s 的 %s 翻譯沒有註冊到 project.godot" % [file, loc])


func test_quest_keys_exist() -> void:
	var table: Dictionary = _load_table()
	var db := QuestDB.load_default()
	for key: String in db.translation_keys():
		assert_true(table.has(key), "任務用到不存在的翻譯 key：" + key)


func test_every_key_has_both_languages() -> void:
	var table: Dictionary = _load_table()
	assert_true(table.size() > 0, "CSV 不應為空")
	var re := RegEx.create_from_string(KEY_PATTERN)
	for key: String in table:
		var row: PackedStringArray = table[key]
		assert_true(re.search(key) != null, "key 格式不符：" + key)
		assert_eq(row.size(), 3, key + " 欄位數")
		if row.size() == 3:
			assert_true(row[1].strip_edges() != "", key + " 缺英文")
			assert_true(row[2].strip_edges() != "", key + " 缺繁中")


func test_scenes_use_translation_keys_only() -> void:
	var table: Dictionary = _load_table()
	var scenes: PackedStringArray = []
	_collect("res://scenes", scenes)
	var re_prop := RegEx.create_from_string("^(text|tooltip_text|placeholder_text) = \"(.*)\"$")
	var re_key := RegEx.create_from_string(KEY_PATTERN)
	for path: String in scenes:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for line: String in lines:
			var m: RegExMatch = re_prop.search(line)
			if m == null:
				continue
			var value: String = m.get_string(2)
			if value == "":
				continue
			if re_key.search(value) == null:
				fail("%s 寫死了文字：%s" % [path, value])
			elif not table.has(value):
				fail("%s 用到不存在的 key：%s" % [path, value])


## docs/design/06-terminology.md 左欄的詞：只能留在設計文件與程式識別碼，玩家畫面一律用白話。
const OBSCURE_ZH: PackedStringArray = ["九息", "弔鐘", "薪火", "巡界", "廢鐘", "下城", "噬日", "歸時核", "爹"]
const OBSCURE_EN: PackedStringArray = ["Nine Breaths", "Bellmourner", "Kindling", "Preservable"]


func test_no_obscure_terms() -> void:
	var table: Dictionary = _load_table()
	for key: String in table:
		var row: PackedStringArray = table[key] as PackedStringArray
		if row.size() < 3:
			continue
		for w: String in OBSCURE_ZH:
			assert_false(row[2].contains(w), "%s 的中文用了難懂的「%s」：%s" % [key, w, row[2]])
		for w: String in OBSCURE_EN:
			assert_false(row[1].containsn(w), "%s 的英文用了「%s」：%s" % [key, w, row[1]])


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.ends_with(".tscn"):
			out.append(dir_path.path_join(file))
