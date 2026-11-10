class_name SaveCodec
extends RefCounted
## 存檔格式：JSON，最外層 {"version": int, "saved_at": String, "state": {...}}。
## 每次改格式：CURRENT_VERSION +1，並在 _migrate_step 加一段舊版 → 新版的轉換與測試。
## 寫檔先寫 .tmp 再改名，舊檔保留為 .bak，避免當機時毀掉存檔。

const CURRENT_VERSION: int = 3

enum Status { OK, NOT_FOUND, CORRUPT, TOO_NEW }


static func encode(state: GameState, saved_at: String = "") -> String:
	var root: Dictionary = {
		"version": CURRENT_VERSION,
		"saved_at": saved_at if saved_at != "" else Time.get_datetime_string_from_system(true),
		"state": state.to_dict(),
	}
	return JSON.stringify(root, "\t")


## 回傳 {"status": Status, "state": GameState 或 null, "from_version": int}
static func decode(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:  # 用實例解析，壞檔不會在 log 印出引擎錯誤
		return {"status": Status.CORRUPT, "state": null, "from_version": -1}
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return {"status": Status.CORRUPT, "state": null, "from_version": -1}
	var root: Dictionary = parsed as Dictionary
	var version: int = int(root.get("version", 0))
	if version > CURRENT_VERSION:
		return {"status": Status.TOO_NEW, "state": null, "from_version": version}
	var migrated: Dictionary = migrate(root)
	var state_v: Variant = migrated.get("state", null)
	if not (state_v is Dictionary):
		return {"status": Status.CORRUPT, "state": null, "from_version": version}
	return {"status": Status.OK, "state": GameState.from_dict(state_v as Dictionary), "from_version": version}


## 逐版遷移到 CURRENT_VERSION。輸入不會被修改。
static func migrate(root: Dictionary) -> Dictionary:
	var data: Dictionary = root.duplicate(true)
	var version: int = int(data.get("version", 0))
	while version < CURRENT_VERSION:
		data = _migrate_step(version, data)
		version += 1
		data["version"] = version
	return data


static func _migrate_step(from_version: int, data: Dictionary) -> Dictionary:
	match from_version:
		0:
			# v0：原型期的扁平格式 {"chapter", "flags", ...}，沒有 "state" 包裝。
			var state: Dictionary = {}
			for key: String in ["chapter", "checkpoint", "playtime_sec", "flags", "quests", "memories_paid"]:
				if data.has(key):
					state[key] = data[key]
					data.erase(key)
			data["state"] = state
		1:
			# v1 → v2（第 36 輪，D-148）：多了攻略筆記 state.guide。切片的存檔還沒寫下任何條目。
			var st: Variant = data.get("state", null)
			if st is Dictionary and not (st as Dictionary).has("guide"):
				(st as Dictionary)["guide"] = {}
		2:
			# v2 → v3（第 66 輪，D-202）：新版劇情重寫的欄位。v2 以前一定是舊版（classic），
			# 新欄位全空；memories_paid 照舊留著、不映射成新版任何資源。
			var st3: Variant = data.get("state", null)
			if st3 is Dictionary:
				var sd: Dictionary = st3 as Dictionary
				sd["mode"] = "classic"
				for key: String in ["statuses", "grants"]:
					if not sd.has(key):
						sd[key] = []
				for key: String in ["reversal", "items", "vitals"]:
					if not sd.has(key):
						sd[key] = {}
	return data


static func write_file(path: String, state: GameState) -> Error:
	var tmp_path: String = path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(encode(state))
	f.close()
	if FileAccess.file_exists(path):
		var bak_err: Error = DirAccess.copy_absolute(path, path + ".bak")
		if bak_err != OK:
			push_warning("存檔備份失敗：%s" % error_string(bak_err))
	return DirAccess.rename_absolute(tmp_path, path)


## 讀檔；主檔壞掉時自動改讀 .bak。
static func read_file(path: String) -> Dictionary:
	var result: Dictionary = _read_one(path)
	if int(result["status"]) == Status.CORRUPT and FileAccess.file_exists(path + ".bak"):
		var backup: Dictionary = _read_one(path + ".bak")
		if int(backup["status"]) == Status.OK:
			backup["recovered_from_backup"] = true
			return backup
	return result


static func _read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": Status.NOT_FOUND, "state": null, "from_version": -1}
	return decode(FileAccess.get_file_as_string(path))
