extends TestCase
## 第 3 章段落 4：送葬者穿過閘道（D-166）——目標在閘道另一邊時先走向石牆中間的出口；石牆那一段河道比較窄。

const CANAL: String = "res://scenes/levels/canal.gd"


func test_steers_through_the_sluice_when_target_is_beyond() -> void:
	var c: Script = load(CANAL) as Script
	var sz: float = float(c.get("SLUICE_Z"))
	var target: Vector3 = Vector3(2.4, -4.5, sz - 5.0)
	var aim: Vector3 = c.call("steer_through_sluice", Vector3(2.0, -4.5, sz + 2.4), target) as Vector3
	assert_true(aim != target, "心臟在閘道另一邊：先往出口走")
	assert_true(absf(aim.x - float(c.get("SLUICE_PASS_X"))) < 0.001, "出口在石牆中間")
	assert_true(aim.z < sz, "出口在閘道北邊")
	var passed: Vector3 = c.call("steer_through_sluice", Vector3(0.4, -4.5, aim.z - 0.01), target) as Vector3
	assert_eq(passed, target, "穿過出口之後直接走向心臟")


func test_no_steer_on_the_same_side() -> void:
	var c: Script = load(CANAL) as Script
	var sz: float = float(c.get("SLUICE_Z"))
	var target: Vector3 = Vector3(2.4, -4.5, sz + 1.4)
	assert_eq(c.call("steer_through_sluice", Vector3(2.0, -4.5, sz + 6.0), target), target, "同一邊：直接走")
	var back: Vector3 = c.call("steer_through_sluice", Vector3(1.0, -4.5, sz - 4.0), target) as Vector3
	assert_true(back.z > sz, "從北邊拉回南邊：先往南邊的出口走")


func test_sluice_is_narrow() -> void:
	var c: Script = load(CANAL) as Script
	var sz: float = float(c.get("SLUICE_Z"))
	assert_eq(float(c.call("bed_limit_x", sz)), float(c.get("SLUICE_HALF")), "石牆中間比較窄")
	assert_eq(float(c.call("bed_limit_x", sz + 3.0)), float(c.get("BED_LIMIT_X")), "閘道外照河道寬度")


## 掙脫戰（D-169）：牠爬上東岸的位置跟著牠在哪裡，離諾恩太近就往牠那一側讓開，而且不會落到東岸外面。
func test_struggle_land_keeps_a_gap_from_noen() -> void:
	var c: Script = load(CANAL) as Script
	var gap: float = float(c.get("STRUGGLE_MIN_GAP"))
	var sz: float = float(c.get("SLUICE_Z"))
	assert_true(absf(float(c.call("struggle_land_z", sz + 6.0, sz - 1.2)) - (sz + 6.0)) < 0.001, "離得夠遠：照牠的位置")
	var south: float = float(c.call("struggle_land_z", sz + 0.5, sz - 1.2))
	assert_true(south - (sz - 1.2) >= gap - 0.001, "太早（還在南邊）：往南讓開")
	var north: float = float(c.call("struggle_land_z", sz - 2.0, sz - 1.2))
	assert_true((sz - 1.2) - north >= gap - 0.001, "太晚（走過頭）：往北讓開")
	var far_north: float = float(c.call("struggle_land_z", float(c.get("Z_NORTH")) - 5.0, 0.0))
	assert_true(far_north >= float(c.get("Z_NORTH")) + 2.9, "夾在運河範圍內")
	assert_true(float(c.get("STRUGGLE_LAND_X")) > float(c.get("CANAL_HALF_W")) + 1.0, "落在東岸上、離矮牆有一段")


## 掙脫戰中彌夏躲到諾恩背後（離牠那一側的反方向）、外側岩壁邊（D-169）。
func test_misha_hides_behind_noen() -> void:
	var c: Script = load(CANAL) as Script
	var sz: float = float(c.get("SLUICE_Z"))
	var noen: Vector3 = Vector3(4.0, 0.0, sz - 2.0)
	var south_spot: Vector3 = c.call("misha_hide_spot", noen, Vector3(5.6, 0.0, sz + 1.5)) as Vector3
	assert_true(south_spot.z < noen.z, "牠在南邊：彌夏躲到北邊")
	var north_spot: Vector3 = c.call("misha_hide_spot", noen, Vector3(5.6, 0.0, sz - 6.0)) as Vector3
	assert_true(north_spot.z > noen.z, "牠在北邊：彌夏躲到南邊")
	assert_true(south_spot.x > float(c.get("STRUGGLE_LAND_X")), "貼著外側岩壁")
