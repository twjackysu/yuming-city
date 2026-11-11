class_name SaveCodec
extends RefCounted
## 存檔格式：JSON，最外層 {"version": int, "saved_at": String, "state": {...}}。
## 每次改格式：CURRENT_VERSION +1，並在 _migrate_step 加一段舊版 → 新版的轉換與測試。
## 寫檔先寫 .tmp 再改名，舊檔保留為 .bak，避免當機時毀掉存檔。
## v3 以前（v0～v2）是已經刪掉的舊劇情的存檔：不遷移、不刪檔，讀到回 TOO_OLD（當成沒有存檔，D-224）。

const CURRENT_VERSION: int = 3
## 還讀得懂的最舊版本
const MIN_VERSION: int = 3

enum Status { OK, NOT_FOUND, CORRUPT, TOO_NEW, TOO_OLD }


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
	if version < MIN_VERSION:
		return {"status": Status.TOO_OLD, "state": null, "from_version": version}
	var migrated: Dictionary = migrate(root)
	var state_v: Variant = migrated.get("state", null)
	if not (state_v is Dictionary):
		return {"status": Status.CORRUPT, "state": null, "from_version": version}
	return {"status": Status.OK, "state": GameState.from_dict(state_v as Dictionary), "from_version": version}


## 逐版遷移到 CURRENT_VERSION。輸入不會被修改。
static func migrate(root: Dictionary) -> Dictionary:
	var data: Dictionary = root.duplicate(true)
	var version: int = maxi(int(data.get("version", 0)), MIN_VERSION)
	while version < CURRENT_VERSION:
		data = _migrate_step(version, data)
		version += 1
		data["version"] = version
	return data


## 一版一段：`match from_version:` 裡加 `3:`（v3 → v4）……。現在只有一個版本，沒有東西要轉。
static func _migrate_step(_from_version: int, data: Dictionary) -> Dictionary:
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
