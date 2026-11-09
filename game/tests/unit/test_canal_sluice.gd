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
