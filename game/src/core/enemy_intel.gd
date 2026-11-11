class_name EnemyIntel
extends RefCounted
## 看穿（docs/design/02-gameplay.md「看穿」）：諾恩「已知」的敵人資訊，資料在 res://data/combat/intel.json。
## 資訊可能是錯的：verified=false 顯示「未證實？」；觀察後由劇情或戰鬥改成已證實（overrides）。
## 這裡只管資料與文字，不碰場景；弱點是否打得到也是純函式（方便測試、席菈的「打弱點」共用）。

const PATH: String = "res://data/combat/intel.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed as Dictionary
		else:
			push_error("EnemyIntel: %s 不是 JSON 物件" % PATH)
	return _data


static func entry(enemy_id: String) -> Dictionary:
	var e: Variant = data().get(enemy_id, {})
	return e as Dictionary if e is Dictionary else {}


static func weakpoints(enemy_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Variant in entry(enemy_id).get("weakpoints", []):
		if w is Dictionary:
			out.append(w as Dictionary)
	return out


static func weakpoint(enemy_id: String, weak_id: String) -> Dictionary:
	for w: Dictionary in weakpoints(enemy_id):
		if str(w.get("id", "")) == weak_id:
			return w
	return {}


## 某一項資訊目前是否已證實：overrides（id → bool）優先，否則用資料檔。
static func is_verified(item: Dictionary, overrides: Dictionary = {}) -> bool:
	var id: String = str(item.get("id", ""))
	if overrides.has(id):
		return bool(overrides[id])
	return bool(item.get("verified", false))


## 看穿顯示的文字（已翻譯）：名字、弱點、招式。current_move 非空時在該招式前加「▶」。
static func lines(enemy_id: String, overrides: Dictionary = {}, current_move: String = "") -> PackedStringArray:
	var e: Dictionary = entry(enemy_id)
	var out: PackedStringArray = []
	if e.is_empty():
		out.append(TranslationServer.translate("INSIGHT_UNKNOWN"))
		return out
	out.append(TranslationServer.translate(str(e.get("name", enemy_id))))
	for w: Dictionary in weakpoints(enemy_id):
		out.append(TranslationServer.translate("INSIGHT_WEAK").format([_label(w, overrides)]))
	for m: Variant in e.get("moves", []):
		if not m is Dictionary:
			continue
		var md: Dictionary = m as Dictionary
		# hidden：攻略沒寫的招（南街守衛的噴毒），出現過（overrides 有這個 id）才顯示
		if bool(md.get("hidden", false)) and not overrides.has(str(md.get("id", ""))):
			continue
		var line: String = TranslationServer.translate("INSIGHT_MOVE").format([_label(md, overrides)])
		if current_move != "" and str(md.get("id", "")) == current_move:
			line = TranslationServer.translate("INSIGHT_CURRENT").format([line])
		out.append(line)
	return out


## 看穿小卡（InsightCard）用的分列資料：每列 {kind: "name"|"weak"|"move"|"unknown", text: 已翻譯的名稱（不含已證實標記）,
## verified: bool, current: bool（正在出的招）}。順序跟 lines() 一樣：名字、弱點、招式（隱藏招出現過才列）。
static func rows(enemy_id: String, overrides: Dictionary = {}, current_move: String = "") -> Array[Dictionary]:
	var e: Dictionary = entry(enemy_id)
	var out: Array[Dictionary] = []
	if e.is_empty():
		out.append({"kind": "unknown", "text": TranslationServer.translate("INSIGHT_UNKNOWN"), "verified": false, "current": false})
		return out
	out.append({"kind": "name", "text": TranslationServer.translate(str(e.get("name", enemy_id))), "verified": true, "current": false})
	for w: Dictionary in weakpoints(enemy_id):
		out.append({"kind": "weak", "text": TranslationServer.translate(str(w.get("label", ""))), "verified": is_verified(w, overrides), "current": false})
	for m: Variant in e.get("moves", []):
		if not m is Dictionary:
			continue
		var md: Dictionary = m as Dictionary
		if bool(md.get("hidden", false)) and not overrides.has(str(md.get("id", ""))):
			continue
		var cur: bool = current_move != "" and str(md.get("id", "")) == current_move
		out.append({"kind": "move", "text": TranslationServer.translate(str(md.get("label", ""))), "verified": is_verified(md, overrides), "current": cur})
	return out


static func _label(item: Dictionary, overrides: Dictionary) -> String:
	var tag: String = "INSIGHT_VERIFIED" if is_verified(item, overrides) else "INSIGHT_UNVERIFIED"
	return TranslationServer.translate(str(item.get("label", ""))) + TranslationServer.translate(tag)


## 攻擊者是否在弱點露出的那一側。enemy_forward 是敵人面向（水平），exposed_arc 是度數範圍，
## 角度＝敵人正面轉到攻擊者方向的帶號角（繞 +Y，正值＝敵人的左側）。純函式。
static func is_exposed(enemy_pos: Vector3, enemy_forward: Vector3, attacker_pos: Vector3, exposed_arc: Vector2) -> bool:
	var f := Vector3(enemy_forward.x, 0.0, enemy_forward.z)
	var d := Vector3(attacker_pos.x - enemy_pos.x, 0.0, attacker_pos.z - enemy_pos.z)
	if f.length() < 0.001 or d.length() < 0.001:
		return false
	var ang: float = rad_to_deg(f.signed_angle_to(d, Vector3.UP))
	if exposed_arc.x > exposed_arc.y:
		# 跨過 ±180°（背後）
		return ang >= exposed_arc.x or ang <= exposed_arc.y
	return ang >= exposed_arc.x and ang <= exposed_arc.y


static func arc_of(w: Dictionary) -> Vector2:
	var a: Variant = w.get("exposed_arc", [])
	if a is Array and (a as Array).size() == 2:
		return Vector2(float((a as Array)[0]), float((a as Array)[1]))
	return Vector2(-180.0, 180.0)
